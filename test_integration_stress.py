"""
Integration stress tests for the full Aletheia pipeline.

Chains: COBOL source → ANTLR4 parse → Python generation → execution → Shadow Diff comparison.
Tests resilience against malformed input and extreme precision requirements.
"""

import json
import os
import re
import threading
import time
from decimal import Decimal, getcontext

import pytest

from cobol_analyzer_api import analyze_cobol
from generate_full_python import generate_python_module
from shadow_diff import (
    compare_outputs,
    execute_generated_python,
    generate_report,
    parse_fixed_width,
)
from dependency_crawler import analyze_batch

BASE_DIR = os.path.dirname(os.path.abspath(__file__))


@pytest.fixture(autouse=True, scope="module")
def _decimal_precision():
    """Set precision=31 for integration tests, restore after."""
    original = getcontext().prec
    getcontext().prec = 31
    yield
    getcontext().prec = original


# ── Helpers ──────────────────────────────────────────────────────────────────


def _load_demo_cobol() -> str:
    """Load DEMO_LOAN_INTEREST.cbl from project root."""
    path = os.path.join(BASE_DIR, "DEMO_LOAN_INTEREST.cbl")
    with open(path, "r") as f:
        return f.read()


def _load_layout() -> dict:
    """Load loan_layout.json."""
    path = os.path.join(BASE_DIR, "demo_data", "loan_layout.json")
    with open(path, "r") as f:
        return json.load(f)


def _load_demo_data_file(filename: str) -> str:
    """Load a file from demo_data/."""
    path = os.path.join(BASE_DIR, "demo_data", filename)
    with open(path, "r") as f:
        return f.read()


def _load_demo_cobol_file(filename: str) -> str:
    """Load a COBOL file from demo_data/."""
    path = os.path.join(BASE_DIR, "demo_data", filename)
    with open(path, "r") as f:
        return f.read()


def _analyze_and_generate(cobol_source: str) -> tuple:
    """Analyze COBOL and generate Python. Returns (analysis, code)."""
    analysis = analyze_cobol(cobol_source)
    gen_result = generate_python_module(analysis)
    return analysis, gen_result["code"]


def _execute_generated_cobol_decimal(
    source: str,
    input_records,
    input_mapping: dict,
    output_fields: list,
    constants: dict | None = None,
    timeout_seconds: int = 5,
):
    """Execute CobolDecimal-based generated Python against input records.

    Unlike shadow_diff.execute_generated_python (which overwrites variables
    with plain Decimal), this uses .store() on CobolDecimal objects so the
    generated code's .value accessors work correctly.
    """
    from cobol_types import CobolDecimal

    for rec_idx, record in enumerate(input_records):
        result = {"_record_index": rec_idx}
        try:
            namespace = {}
            exec(source, namespace)

            # Inject constants via .store() if CobolDecimal, else overwrite
            if constants:
                for k, v in constants.items():
                    existing = namespace.get(k)
                    if isinstance(existing, CobolDecimal):
                        existing.store(Decimal(str(v)))
                    else:
                        namespace[k] = Decimal(str(v)) if not isinstance(v, Decimal) else v

            # Inject input values via .store() for CobolDecimal vars
            for layout_name, python_name in input_mapping.items():
                if layout_name in record:
                    value = record[layout_name]
                    existing = namespace.get(python_name)
                    if isinstance(existing, CobolDecimal):
                        existing.store(Decimal(str(value)))
                    elif isinstance(value, str):
                        namespace[python_name] = value
                    else:
                        namespace[python_name] = Decimal(str(value))

            # Execute main()
            exec_error = [None]

            def _run():
                try:
                    namespace["main"]()
                except Exception as e:
                    exec_error[0] = e

            thread = threading.Thread(target=_run, daemon=True)
            thread.start()
            thread.join(timeout=timeout_seconds)

            if thread.is_alive():
                result["_error"] = f"Timeout after {timeout_seconds}s"
                yield result
                continue

            if exec_error[0]:
                result["_error"] = str(exec_error[0])
                yield result
                continue

            # Capture outputs — use .value for CobolDecimal
            for field in output_fields:
                val = namespace.get(field)
                if val is not None:
                    raw = val.value if isinstance(val, CobolDecimal) else val
                    # Fix zero exponential notation: 0E-8 → 0
                    if isinstance(raw, Decimal) and raw == 0:
                        raw = Decimal('0')
                    result[field] = str(raw)
                else:
                    result[field] = None

        except Exception as e:
            result["_error"] = str(e)

        yield result


# ── Test Class 1: Full Round-Trip ────────────────────────────────────────────


class TestFullRoundTrip:
    """End-to-end pipeline: COBOL → parse → generate → execute → Shadow Diff."""

    def test_analyze_generate_shadow_diff_zero_drift(self):
        """
        Full pipeline round-trip with real demo data.

        DEMO_LOAN_INTEREST.cbl → analyze_cobol() → generate_python_module()
        → verify generated code executes all 100 records without errors
        → compare reference implementation output against mainframe data
        → assert ZERO DRIFT.

        Note: generate_python_module() emits CobolDecimal-based code which
        truncates intermediate values to PIC specification (correct COBOL behavior).
        The demo mainframe output was generated to match this precise behavior.
        We verify the generated code executes all records cleanly and achieves
        ZERO DRIFT against the mainframe output.
        """
        # ── Stage 1: COBOL → Analysis ──
        cobol_source = _load_demo_cobol()
        analysis = analyze_cobol(cobol_source)
        assert analysis["success"], (
            f"ANTLR4 parse failed: {analysis.get('parse_warning')}"
        )

        # ── Stage 2: Analysis → Generated Python ──
        gen_result = generate_python_module(analysis)
        generated_code = gen_result["code"]
        assert generated_code, "Generator returned empty code"
        assert "# PARSE ERROR" not in generated_code, "Generator flagged parse error"
        assert "def main():" in generated_code, "No main() entry point"

        # ── Stage 3: Load demo data ──
        layout = _load_layout()
        input_data = _load_demo_data_file("loan_input.dat")
        output_data = _load_demo_data_file("loan_mainframe_output.dat")

        input_layout = {
            "fields": layout["fields"],
            "record_length": layout.get("record_length"),
        }
        input_records = list(parse_fixed_width(input_layout, input_data))
        assert len(input_records) == 100

        output_layout = layout["output_layout"]
        mainframe_raw = list(parse_fixed_width(output_layout, output_data))
        assert len(mainframe_raw) == 100

        field_mapping = output_layout["field_mapping"]
        mainframe_outputs = []
        for rec in mainframe_raw:
            mapped = {}
            for cobol_name, python_name in field_mapping.items():
                if cobol_name in rec:
                    mapped[python_name] = str(rec[cobol_name])
            mainframe_outputs.append(mapped)

        input_mapping = layout["input_mapping"]
        output_fields = layout["output_fields"]
        constants = {k: Decimal(v) for k, v in layout["constants"].items()}

        # ── Stage 4a: Verify generated (CobolDecimal) code executes all 100 records ──
        generated_outputs = list(_execute_generated_cobol_decimal(
            source=generated_code,
            input_records=input_records,
            input_mapping=input_mapping,
            output_fields=output_fields,
            constants=constants,
        ))
        assert len(generated_outputs) == 100
        gen_errors = [r for r in generated_outputs if "_error" in r]
        assert len(gen_errors) == 0, (
            f"Generated code execution errors: {gen_errors[:3]}"
        )

        # ── Stage 5: Compare generated output against mainframe — ZERO DRIFT ──
        comparison = compare_outputs(generated_outputs, mainframe_outputs, output_fields)
        assert comparison["total_records"] == 100
        assert comparison["matches"] == 100
        assert comparison["mismatches"] == 0, (
            f"Drift detected: {comparison['mismatch_details']}"
        )

        # ── Stage 6: Report verdict ──
        report = generate_report(
            comparison,
            input_file_hash="sha256:integration_test",
            output_file_hash="sha256:integration_test",
            layout_name="DEMO_LOAN_INTEREST",
        )
        assert report["verdict"] == "SHADOW DIFF: ZERO DRIFT CONFIRMED"

    def test_batch_multi_file_round_trip(self):
        """
        Multi-file batch: MAIN-LOAN + CALC-INT + APPLY-PENALTY.

        analyze_batch() should resolve cross-file CALL dependencies
        and produce VERIFIED verdict for all three programs.
        """
        programs = {
            "MAIN-LOAN": _load_demo_cobol_file("MAIN-LOAN.cbl"),
            "CALC-INT": _load_demo_cobol_file("CALC-INT.cbl"),
            "APPLY-PENALTY": _load_demo_cobol_file("APPLY-PENALTY.cbl"),
        }

        result = analyze_batch(programs)

        # All 3 programs present in results
        assert "program_results" in result
        pr = result["program_results"]
        for name in ("MAIN-LOAN", "CALC-INT", "APPLY-PENALTY"):
            assert name in pr, f"Missing program: {name}"
            assert pr[name]["generated_python"] is not None, (
                f"{name}: no generated Python"
            )
            assert pr[name]["verification_status"] == "VERIFIED", (
                f"{name}: expected VERIFIED, got {pr[name]['verification_status']}"
            )

        # Combined verdict
        assert result["combined_verdict"] == "VERIFIED"


# ── Test Class 2: Resilience ─────────────────────────────────────────────────


class TestResilience:
    """Engine must not crash on malformed or empty COBOL input."""

    def test_malformed_cobol_missing_identification(self):
        """Missing IDENTIFICATION DIVISION — should parse with errors, not crash."""
        source = (
            "       DATA DIVISION.\n"
            "       WORKING-STORAGE SECTION.\n"
            "       01 WS-A PIC 9(5).\n"
            "       PROCEDURE DIVISION.\n"
            "       MAIN-LOGIC.\n"
            "           STOP RUN.\n"
        )
        result = analyze_cobol(source)
        assert isinstance(result, dict)
        # Generator must not crash — returns string with error marker when analysis fails
        gen = generate_python_module(result)
        if isinstance(gen, dict):
            assert "code" in gen
        else:
            assert isinstance(gen, str)
            assert "PARSE ERROR" in gen or "MANUAL REVIEW" in gen

    def test_malformed_cobol_unclosed_if(self):
        """Unclosed IF statement — should flag error, not hang or crash."""
        source = (
            "       IDENTIFICATION DIVISION.\n"
            "       PROGRAM-ID. BAD-IF.\n"
            "       DATA DIVISION.\n"
            "       WORKING-STORAGE SECTION.\n"
            "       01 WS-A PIC 9(5).\n"
            "       PROCEDURE DIVISION.\n"
            "       MAIN-LOGIC.\n"
            "           IF WS-A = 1\n"
            "               DISPLAY 'OPEN'\n"
            "           STOP RUN.\n"
        )
        result = analyze_cobol(source)
        assert isinstance(result, dict)
        gen = generate_python_module(result)
        if isinstance(gen, dict):
            assert "code" in gen
        else:
            assert isinstance(gen, str)

    def test_malformed_cobol_garbage_column_7(self):
        """Non-standard characters in column 7 — parser should handle gracefully."""
        source = (
            "      *THIS IS A COMMENT\n"
            "      /PAGE BREAK INDICATOR\n"
            "       IDENTIFICATION DIVISION.\n"
            "       PROGRAM-ID. COL7-TEST.\n"
            "       PROCEDURE DIVISION.\n"
            "       MAIN-LOGIC.\n"
            "           STOP RUN.\n"
        )
        result = analyze_cobol(source)
        assert isinstance(result, dict)
        gen = generate_python_module(result)
        if isinstance(gen, dict):
            assert "code" in gen
        else:
            assert isinstance(gen, str)

    def test_malformed_cobol_invalid_pic(self):
        """PIC clause with invalid syntax — should flag, not crash."""
        source = (
            "       IDENTIFICATION DIVISION.\n"
            "       PROGRAM-ID. BAD-PIC.\n"
            "       DATA DIVISION.\n"
            "       WORKING-STORAGE SECTION.\n"
            "       01 WS-X PIC ZZZZ(INVALID).\n"
            "       PROCEDURE DIVISION.\n"
            "       MAIN-LOGIC.\n"
            "           STOP RUN.\n"
        )
        result = analyze_cobol(source)
        assert isinstance(result, dict)
        gen = generate_python_module(result)
        if isinstance(gen, dict):
            assert "code" in gen
        else:
            assert isinstance(gen, str)

    def test_empty_file_graceful(self):
        """Empty string input must return success=False, never crash."""
        result = analyze_cobol("")
        assert isinstance(result, dict)
        assert result.get("success") is False

        # Generator returns error string for failed analysis
        gen = generate_python_module(result)
        if isinstance(gen, dict):
            assert "code" in gen
            assert gen["code"].strip() != ""
        else:
            # Returns raw error string like "# PARSE ERROR: ..."
            assert isinstance(gen, str)
            assert "PARSE ERROR" in gen


# ── Test Class 3: Stress ─────────────────────────────────────────────────────


class TestStress:
    """Performance and precision stress tests."""

    def test_extreme_pic_precision(self):
        """
        PIC S9(18)V9(12) — 30-digit precision.

        COBOL allows up to 18 integer + 18 decimal digits.
        Generated Python must use Decimal throughout, no float contamination.
        """
        source = (
            "       IDENTIFICATION DIVISION.\n"
            "       PROGRAM-ID. PRECISION-TEST.\n"
            "       DATA DIVISION.\n"
            "       WORKING-STORAGE SECTION.\n"
            "       01 WS-BIG-A    PIC S9(18)V9(12).\n"
            "       01 WS-BIG-B    PIC S9(18)V9(12).\n"
            "       01 WS-RESULT   PIC S9(18)V9(12).\n"
            "       PROCEDURE DIVISION.\n"
            "       MAIN-LOGIC.\n"
            "           MOVE 123456789012345678.123456789012\n"
            "               TO WS-BIG-A.\n"
            "           MOVE 0.000000000001 TO WS-BIG-B.\n"
            "           COMPUTE WS-RESULT = WS-BIG-A * WS-BIG-B.\n"
            "           COMPUTE WS-RESULT = WS-RESULT + WS-BIG-A.\n"
            "           STOP RUN.\n"
        )
        analysis = analyze_cobol(source)
        assert analysis["success"], (
            f"Parse failed: {analysis.get('parse_warning')}"
        )

        gen_result = generate_python_module(analysis)
        code = gen_result["code"]
        assert code, "Generator returned empty code"

        # No float contamination in generated code
        # Allow "float" in comments but not in executable code
        executable_lines = [
            line for line in code.split("\n")
            if line.strip() and not line.strip().startswith("#")
        ]
        executable_code = "\n".join(executable_lines)
        assert "float(" not in executable_code, (
            "Float contamination detected in generated Python"
        )

        # Execute the generated code — must not raise
        exec_globals = {}
        exec(compile(code, "<precision-test>", "exec"), exec_globals)

    def test_large_synthetic_cobol_performance(self):
        """
        500-paragraph synthetic COBOL — full pipeline must complete in < 60s.

        Generates ~10,000 lines of COBOL with MOVE + COMPUTE per paragraph.
        Verifies the analyzer and generator scale linearly, not quadratically.
        """
        num_paragraphs = 500

        # Build synthetic COBOL source
        lines = [
            "       IDENTIFICATION DIVISION.",
            "       PROGRAM-ID. STRESS-TEST.",
            "       DATA DIVISION.",
            "       WORKING-STORAGE SECTION.",
            "       01 WS-COUNTER    PIC S9(9)V99.",
            "       01 WS-TOTAL      PIC S9(15)V99.",
            "       01 WS-TEMP       PIC S9(15)V99.",
            "       PROCEDURE DIVISION.",
            "       0000-MAIN-PROCESS.",
        ]

        # Main paragraph PERFORMs all 500
        for i in range(1, num_paragraphs + 1):
            lines.append(f"           PERFORM {i:04d}-PARA-{i}.")
        lines.append("           STOP RUN.")

        # 500 paragraphs, each with MOVE + COMPUTE
        for i in range(1, num_paragraphs + 1):
            lines.append(f"       {i:04d}-PARA-{i}.")
            lines.append(f"           MOVE {i} TO WS-COUNTER.")
            lines.append(
                "           COMPUTE WS-TOTAL = WS-TOTAL + WS-COUNTER."
            )

        source = "\n".join(lines) + "\n"

        # Time the full pipeline
        start = time.perf_counter()

        analysis = analyze_cobol(source)
        assert analysis["success"], (
            f"Parse failed on synthetic COBOL: {analysis.get('parse_warning')}"
        )

        gen_result = generate_python_module(analysis)
        code = gen_result["code"]

        elapsed = time.perf_counter() - start

        assert elapsed < 60, (
            f"Pipeline took {elapsed:.1f}s — exceeds 60s limit"
        )
        assert code, "Generator returned empty code"
        assert "# PARSE ERROR" not in code

        # Verify all 500 paragraphs generated Python functions
        # Paragraph names get lowercased and normalized in generated code
        para_count = code.count("def para_")
        assert para_count >= num_paragraphs, (
            f"Expected {num_paragraphs} paragraph functions, found {para_count}"
        )

        # Generated code must be syntactically valid Python
        compile(code, "<stress-test>", "exec")
