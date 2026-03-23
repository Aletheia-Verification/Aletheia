"""
Large-program stress tests for the Aletheia pipeline.

Generates synthetic COBOL programs at 3000 and 5000 lines, then runs them
through analyze_cobol() + generate_python_module() + compile() to surface
recursion limits, memory issues, or performance bottlenecks.
"""

import os
import time

import pytest

os.environ.setdefault("USE_IN_MEMORY_DB", "1")
os.environ.setdefault("ALETHEIA_EXEC_MODE", "inline")

from cobol_analyzer_api import analyze_cobol
from generate_full_python import generate_python_module


# ── Synthetic COBOL generator ───────────────────────────────────────


def _generate_cobol_program(num_paragraphs: int, num_variables: int,
                            lines_target: int) -> str:
    """Build a synthetic COBOL program with the requested scale."""
    lines = []

    # ── IDENTIFICATION DIVISION
    lines.append("       IDENTIFICATION DIVISION.")
    lines.append("       PROGRAM-ID. STRESS-TEST.")
    lines.append("       ENVIRONMENT DIVISION.")
    lines.append("       DATA DIVISION.")
    lines.append("       WORKING-STORAGE SECTION.")

    # ── Variables: mix of PIC 9, PIC X, PIC S9 COMP-3
    for i in range(1, num_variables + 1):
        if i % 3 == 0:
            lines.append(f"       01  WS-ALPHA-{i:04d}       PIC X(20) VALUE SPACES.")
        elif i % 3 == 1:
            lines.append(f"       01  WS-NUM-{i:04d}         PIC 9(7)V99 VALUE 0.")
        else:
            lines.append(f"       01  WS-COMP3-{i:04d}       PIC S9(7)V99 COMP-3 VALUE 0.")

    # Counter for PERFORM VARYING
    lines.append("       01  WS-IDX              PIC 9(4) VALUE 0.")
    lines.append("       01  WS-LIMIT            PIC 9(4) VALUE 10.")
    lines.append("       01  WS-TEMP             PIC 9(9)V99 VALUE 0.")

    # ── PROCEDURE DIVISION
    lines.append("       PROCEDURE DIVISION.")
    lines.append("       MAIN-PROGRAM.")

    # Call each paragraph
    for i in range(1, num_paragraphs + 1):
        lines.append(f"           PERFORM PARA-{i:04d}.")

    lines.append("           STOP RUN.")

    # ── Paragraphs: pad to reach lines_target
    lines_per_para = max(8, (lines_target - len(lines)) // num_paragraphs)

    for i in range(1, num_paragraphs + 1):
        lines.append(f"       PARA-{i:04d}.")

        # Pick variables to reference (cycle through available)
        v1 = ((i * 3 - 2) % num_variables) + 1
        v2 = ((i * 3 - 1) % num_variables) + 1
        v3 = ((i * 3) % num_variables) + 1

        # Numeric var names
        def _nvar(n):
            if n % 3 == 1:
                return f"WS-NUM-{n:04d}"
            elif n % 3 == 2:
                return f"WS-COMP3-{n:04d}"
            else:
                return f"WS-ALPHA-{n:04d}"

        nv1, nv2, nv3 = _nvar(v1), _nvar(v2), _nvar(v3)

        # MOVE
        lines.append(f"           MOVE {i} TO WS-TEMP.")

        # COMPUTE (only with numeric vars)
        num_a = f"WS-NUM-{(v1 if v1 % 3 == 1 else 1):04d}"
        num_b = f"WS-COMP3-{(v2 if v2 % 3 == 2 else 2):04d}"
        lines.append(f"           COMPUTE WS-TEMP = {num_a} + {num_b}.")

        # Nested IF (3 levels)
        lines.append(f"           IF WS-TEMP > {i}")
        lines.append(f"               MOVE {i * 10} TO WS-TEMP")
        lines.append(f"               IF WS-TEMP > {i * 5}")
        lines.append(f"                   MOVE 0 TO WS-TEMP")
        lines.append(f"                   IF WS-IDX > 0")
        lines.append(f"                       DISPLAY 'PARA-{i:04d} DEEP'")
        lines.append(f"                   END-IF")
        lines.append(f"               ELSE")
        lines.append(f"                   MOVE 1 TO WS-IDX")
        lines.append(f"               END-IF")
        lines.append(f"           ELSE")
        lines.append(f"               MOVE 0 TO WS-IDX")
        lines.append(f"           END-IF.")

        # PERFORM VARYING
        lines.append("           PERFORM VARYING WS-IDX FROM 1 BY 1")
        lines.append("               UNTIL WS-IDX > WS-LIMIT")
        lines.append(f"               COMPUTE WS-TEMP = WS-TEMP + WS-IDX")
        lines.append("           END-PERFORM.")

        # DISPLAY
        lines.append(f"           DISPLAY 'PARA-{i:04d} DONE'.")

        # Pad with additional MOVE/DISPLAY to reach target
        extra = lines_per_para - 16  # 16 lines already emitted per paragraph
        for j in range(max(0, extra)):
            if j % 2 == 0:
                lines.append(f"           MOVE {i + j} TO WS-TEMP.")
            else:
                lines.append(f"           DISPLAY WS-TEMP.")

    return "\n".join(lines) + "\n"


# ── Tests ────────────────────────────────────────────────────────────


class TestLargeProgram:
    """Stress tests for large synthetic COBOL programs."""

    def test_3000_line_program(self):
        """3000-line program: 100 paragraphs, 50 variables."""
        cobol = _generate_cobol_program(100, 50, 3000)
        line_count = len(cobol.splitlines())
        assert line_count >= 2500, f"Generated only {line_count} lines"

        t0 = time.perf_counter()

        result = analyze_cobol(cobol)
        assert result["success"], f"Parser failed: {result.get('error')}"
        assert result["summary"]["paragraphs"] >= 100

        gen = generate_python_module(result)
        assert gen["code"], "No Python code generated"

        # Must compile without errors (recursion limit, too many locals, etc.)
        compile(gen["code"], "<stress-3000>", "exec")

        elapsed = time.perf_counter() - t0
        assert elapsed < 120, f"Took {elapsed:.1f}s — exceeds 120s limit"

        # Report
        print(f"\n  3000-line stress test:")
        print(f"    Input:    {line_count} lines")
        print(f"    Paragraphs parsed: {result['summary']['paragraphs']}")
        print(f"    Variables parsed:  {result['summary']['variables']}")
        print(f"    Generated Python:  {len(gen['code'])} chars")
        print(f"    MR flags:  {len(gen['mr_flags'])}")
        print(f"    Time:      {elapsed:.1f}s")

    def test_5000_line_program(self):
        """5000-line program: 200 paragraphs, 100 variables."""
        cobol = _generate_cobol_program(200, 100, 5000)
        line_count = len(cobol.splitlines())
        assert line_count >= 4000, f"Generated only {line_count} lines"

        t0 = time.perf_counter()

        result = analyze_cobol(cobol)
        assert result["success"], f"Parser failed: {result.get('error')}"
        assert result["summary"]["paragraphs"] >= 200

        gen = generate_python_module(result)
        assert gen["code"], "No Python code generated"

        # Must compile — this is where "too many locals" could surface
        compile(gen["code"], "<stress-5000>", "exec")

        elapsed = time.perf_counter() - t0
        assert elapsed < 240, f"Took {elapsed:.1f}s — exceeds 240s limit"

        print(f"\n  5000-line stress test:")
        print(f"    Input:    {line_count} lines")
        print(f"    Paragraphs parsed: {result['summary']['paragraphs']}")
        print(f"    Variables parsed:  {result['summary']['variables']}")
        print(f"    Generated Python:  {len(gen['code'])} chars")
        print(f"    MR flags:  {len(gen['mr_flags'])}")
        print(f"    Time:      {elapsed:.1f}s")
