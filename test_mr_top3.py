"""
test_mr_top3.py — Tests for top 3 MANUAL REVIEW root cause fixes.

1. Compound OR of 88-level names → correct expansion
2. CONTINUE statement → pass
3. WRITE in IF branch → _io_write call
"""

import os
os.environ["USE_IN_MEMORY_DB"] = "1"

import pytest
from decimal import Decimal
from cobol_analyzer_api import analyze_cobol
from generate_full_python import generate_python_module
from parse_conditions import _convert_condition, _convert_single_statement


class TestCompound88Or:
    """Fix 1: OR-separated 88-level condition names."""

    LEVEL_88 = {
        "WS-BLOCK": {"parent": "WS-STATUS", "value": "B", "values": ["B"]},
        "WS-REVIEW": {"parent": "WS-STATUS", "value": "R", "values": ["R"]},
        "WS-CLEAN": {"parent": "WS-STATUS", "value": "C", "values": ["C"]},
    }
    KNOWN = {"WS-STATUS"}
    STRINGS = {"WS-STATUS"}

    def test_two_88_levels_with_or(self):
        """WS-BLOCKORWS-REVIEW → ws_status == 'B' or ws_status == 'R'."""
        result, issues = _convert_condition(
            "WS-BLOCKORWS-REVIEW", self.KNOWN, self.LEVEL_88, string_vars=self.STRINGS
        )
        assert " or " in result
        assert "ws_status" in result
        assert "MANUAL REVIEW" not in result

    def test_triple_88_or(self):
        """WS-BLOCKORWS-REVIEWORWS-CLEAN → three-way or."""
        result, issues = _convert_condition(
            "WS-BLOCKORWS-REVIEWORWS-CLEAN", self.KNOWN, self.LEVEL_88, string_vars=self.STRINGS
        )
        assert result.count(" or ") == 2
        assert "MANUAL REVIEW" not in result

    def test_e2e_compound_or_compiles(self):
        """Full pipeline: COBOL with 88-level OR generates compilable Python."""
        src = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEST-OR88.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-STATUS PIC X.
           88 WS-ACTIVE VALUE 'A'.
           88 WS-CLOSED VALUE 'C'.
       01 WS-RESULT PIC 9(1).
       PROCEDURE DIVISION.
       0000-MAIN.
           IF WS-ACTIVE OR WS-CLOSED
               MOVE 1 TO WS-RESULT.
           STOP RUN.
"""
        analysis = analyze_cobol(src)
        result = generate_python_module(analysis)
        code = result["code"]
        compile(code, "<test-or88>", "exec")
        assert " or " in code
        assert "MANUAL REVIEW" not in code


class TestContinue:
    """Fix 2: CONTINUE statement → pass."""

    def test_continue_emits_pass(self):
        code, issues = _convert_single_statement(
            "CONTINUE", {"WS-X"}, {}, {}, indent_level=1, string_vars=set(),
        )
        assert "pass" in code
        assert "CONTINUE" in code
        assert "MANUAL REVIEW" not in code

    def test_e2e_continue_compiles(self):
        src = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEST-CONT.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-X PIC 9(1).
       PROCEDURE DIVISION.
       0000-MAIN.
           IF WS-X = 0
               CONTINUE
           ELSE
               MOVE 1 TO WS-X.
           STOP RUN.
"""
        analysis = analyze_cobol(src)
        result = generate_python_module(analysis)
        code = result["code"]
        compile(code, "<test-continue>", "exec")
        assert "MANUAL REVIEW" not in code


class TestWriteInBranch:
    """Fix 3: WRITE inside IF branch → _io_write call."""

    def test_write_emits_io_write(self):
        code, issues = _convert_single_statement(
            "WRITERPT-RECORD", {"WS-X"}, {}, {}, indent_level=1, string_vars=set(),
        )
        assert "_io_write" in code
        assert "RPT-RECORD" in code
        assert "MANUAL REVIEW" not in code

    def test_e2e_write_in_if_compiles(self):
        """WRITE inside IF branch generates compilable Python."""
        src = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEST-WRITE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-FLAG PIC 9(1).
       PROCEDURE DIVISION.
       0000-MAIN.
           IF WS-FLAG = 1
               WRITE RPT-RECORD.
           STOP RUN.
"""
        analysis = analyze_cobol(src)
        result = generate_python_module(analysis)
        code = result["code"]
        compile(code, "<test-write>", "exec")
        assert "MANUAL REVIEW" not in code

    def test_write_in_if_not_double_emitted(self):
        """WRITE inside IF must emit exactly one _io_write, not two."""
        src = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEST-WRITE2.
       DATA DIVISION.
       FILE SECTION.
       FD RPT-FILE.
       01 RPT-RECORD PIC X(80).
       WORKING-STORAGE SECTION.
       01 WS-FLAG PIC 9(1).
       PROCEDURE DIVISION.
       0000-MAIN.
           IF WS-FLAG = 1
               WRITE RPT-RECORD
           END-IF.
           STOP RUN.
"""
        analysis = analyze_cobol(src)
        result = generate_python_module(analysis)
        code = result["code"]
        compile(code, "<test-write-dedup>", "exec")
        assert code.count("_io_write") == 1, (
            f"Expected 1 _io_write call but found {code.count('_io_write')}"
        )
