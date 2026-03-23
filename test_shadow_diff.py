"""
Tests for Shadow Diff Engine — Mainframe I/O Replay & Comparison

14 tests covering:
  - COMP-3 packed decimal decoding
  - Fixed-width file parsing
  - Execution harness
  - Comparator logic
  - Report generation
  - Full pipeline end-to-end with demo data
"""

import json
import os
from decimal import Decimal, getcontext

import pytest

from shadow_diff import (
    compare_outputs,
    decode_comp3,
    execute_generated_python,
    execute_io_program,
    generate_demo_data,
    generate_report,
    parse_fixed_width,
    parse_fixed_width_stream,
    run_streaming_pipeline,
    MAX_MISMATCH_DETAILS,
)


# ============================================================
# Fixture: set Decimal precision for shadow_diff tests,
# then restore it so other test modules are not affected.
# ============================================================

@pytest.fixture(autouse=True, scope="module")
def _shadow_diff_decimal_context():
    """Set precision=31 for shadow_diff tests, restore original after."""
    original = getcontext().prec
    getcontext().prec = 31
    yield
    getcontext().prec = original


# ============================================================
# COMP-3 Packed Decimal Tests
# ============================================================


class TestDecodeComp3:
    def test_positive(self):
        """0x12 0x34 0x5C → +12345 → with 2 decimals → 123.45"""
        raw = bytes([0x12, 0x34, 0x5C])
        result = decode_comp3(raw, decimals=2)
        assert result == Decimal("123.45")

    def test_negative(self):
        """0x12 0x34 0x5D → -12345 → with 2 decimals → -123.45"""
        raw = bytes([0x12, 0x34, 0x5D])
        result = decode_comp3(raw, decimals=2)
        assert result == Decimal("-123.45")

    def test_unsigned(self):
        """0x12 0x34 0x5F → +12345 → with 2 decimals → 123.45"""
        raw = bytes([0x12, 0x34, 0x5F])
        result = decode_comp3(raw, decimals=2)
        assert result == Decimal("123.45")

    def test_zero_decimals(self):
        """0x01 0x0C → +10 → with 0 decimals → 10"""
        raw = bytes([0x01, 0x0C])
        result = decode_comp3(raw, decimals=0)
        assert result == Decimal("10")

    def test_empty_bytes(self):
        result = decode_comp3(b"", decimals=2)
        assert result == Decimal("0")

    def test_single_byte(self):
        """0x5C → digit 5, sign C (positive) → 5 with 0 decimals"""
        raw = bytes([0x5C])
        result = decode_comp3(raw, decimals=0)
        assert result == Decimal("5")

    def test_large_value(self):
        """0x99 0x99 0x99 0x99 0x9C → +999999999 → with 2 decimals → 9999999.99"""
        raw = bytes([0x99, 0x99, 0x99, 0x99, 0x9C])
        result = decode_comp3(raw, decimals=2)
        assert result == Decimal("9999999.99")


# ============================================================
# COMP-3 Dirty Sign Nibbles (IBM NUMPROC)
# ============================================================


class TestComp3DirtySign:
    """IBM NUMPROC(NOPFD) accepts 'dirty' sign nibbles beyond C/D/F."""

    def test_comp3_dirty_sign_c(self):
        """Standard positive sign nibble 0xC."""
        raw = bytes([0x12, 0x3C])
        assert decode_comp3(raw) == Decimal("123")

    def test_comp3_dirty_sign_a(self):
        """Dirty positive sign nibble 0xA (valid under NUMPROC(NOPFD))."""
        raw = bytes([0x12, 0x3A])
        assert decode_comp3(raw) == Decimal("123")

    def test_comp3_dirty_sign_e(self):
        """Dirty positive sign nibble 0xE (valid under NUMPROC(NOPFD))."""
        raw = bytes([0x12, 0x3E])
        assert decode_comp3(raw) == Decimal("123")

    def test_comp3_dirty_sign_f(self):
        """Unsigned positive sign nibble 0xF."""
        raw = bytes([0x12, 0x3F])
        assert decode_comp3(raw) == Decimal("123")

    def test_comp3_dirty_sign_b(self):
        """Dirty NEGATIVE sign nibble 0xB (valid under NUMPROC(NOPFD))."""
        raw = bytes([0x12, 0x3B])
        assert decode_comp3(raw) == Decimal("-123")

    def test_comp3_dirty_sign_d(self):
        """Standard negative sign nibble 0xD."""
        raw = bytes([0x12, 0x3D])
        assert decode_comp3(raw) == Decimal("-123")


# ============================================================
# NUMPROC Compiler Config
# ============================================================


class TestNumproc:
    def test_numproc_default_nopfd(self):
        """Default CompilerConfig has numproc=NOPFD."""
        from compiler_config import CompilerConfig
        cfg = CompilerConfig()
        assert cfg.numproc == "NOPFD"

    def test_numproc_pfd_valid(self):
        """CompilerConfig accepts PFD."""
        from compiler_config import set_config, reset_config
        try:
            cfg = set_config(numproc="PFD")
            assert cfg.numproc == "PFD"
        finally:
            reset_config()

    def test_numproc_invalid_raises(self):
        """Invalid NUMPROC raises ValueError."""
        from compiler_config import set_config
        with pytest.raises(ValueError, match="Invalid numproc"):
            set_config(numproc="INVALID")


# ============================================================
# Fixed-Width Reader Tests
# ============================================================


class TestParseFixedWidth:
    def test_string_field(self):
        layout = {
            "fields": [
                {"name": "NAME", "start": 0, "length": 10, "type": "string"},
            ],
            "record_length": None,
        }
        data = "JOHN SMITH"
        records = list(parse_fixed_width(layout, data))
        assert len(records) == 1
        assert records[0]["NAME"] == "JOHN SMITH"

    def test_string_strips_trailing_spaces(self):
        layout = {
            "fields": [
                {"name": "NAME", "start": 0, "length": 10, "type": "string"},
            ],
            "record_length": None,
        }
        data = "JOHN      "
        records = list(parse_fixed_width(layout, data))
        assert records[0]["NAME"] == "JOHN"

    def test_decimal_field(self):
        layout = {
            "fields": [
                {"name": "AMOUNT", "start": 0, "length": 10, "type": "decimal", "decimals": 2},
            ],
            "record_length": None,
        }
        data = "   1234.56"
        records = list(parse_fixed_width(layout, data))
        assert records[0]["AMOUNT"] == Decimal("1234.56")

    def test_integer_field(self):
        layout = {
            "fields": [
                {"name": "COUNT", "start": 0, "length": 5, "type": "integer"},
            ],
            "record_length": None,
        }
        data = "  042"
        records = list(parse_fixed_width(layout, data))
        assert records[0]["COUNT"] == Decimal("42")

    def test_multiple_fields(self):
        layout = {
            "fields": [
                {"name": "NAME", "start": 0, "length": 10, "type": "string"},
                {"name": "BAL", "start": 10, "length": 10, "type": "decimal", "decimals": 2},
                {"name": "DAYS", "start": 20, "length": 3, "type": "integer"},
            ],
            "record_length": None,
        }
        data = "ACCT000001  50000.00 30"
        records = list(parse_fixed_width(layout, data))
        assert records[0]["NAME"] == "ACCT000001"
        assert records[0]["BAL"] == Decimal("50000.00")
        assert records[0]["DAYS"] == Decimal("30")

    def test_multiple_records(self):
        layout = {
            "fields": [
                {"name": "ID", "start": 0, "length": 3, "type": "string"},
                {"name": "VAL", "start": 3, "length": 5, "type": "decimal", "decimals": 1},
            ],
            "record_length": None,
        }
        data = "AAA 10.5\nBBB 20.3\nCCC  5.0"
        records = list(parse_fixed_width(layout, data))
        assert len(records) == 3
        assert records[0]["ID"] == "AAA"
        assert records[1]["VAL"] == Decimal("20.3")
        assert records[2]["ID"] == "CCC"


# ============================================================
# Execution Harness Tests
# ============================================================


class TestExecuteHarness:
    SIMPLE_SOURCE = """
from decimal import Decimal

x = Decimal('0')
y = Decimal('0')
result = Decimal('0')

def main():
    global x, y, result
    result = x + y
"""

    def test_basic_execution(self):
        records = [{"X": Decimal("10"), "Y": Decimal("20")}]
        mapping = {"X": "x", "Y": "y"}
        outputs = list(execute_generated_python(
            self.SIMPLE_SOURCE, records, mapping, ["result"]
        ))
        assert len(outputs) == 1
        assert outputs[0]["result"] == "30"

    def test_multiple_records(self):
        records = [
            {"X": Decimal("1"), "Y": Decimal("2")},
            {"X": Decimal("100"), "Y": Decimal("200")},
        ]
        mapping = {"X": "x", "Y": "y"}
        outputs = list(execute_generated_python(
            self.SIMPLE_SOURCE, records, mapping, ["result"]
        ))
        assert len(outputs) == 2
        assert outputs[0]["result"] == "3"
        assert outputs[1]["result"] == "300"

    def test_error_handling_continues_batch(self):
        """Bad code for one record shouldn't stop the batch."""
        bad_source = """
from decimal import Decimal

x = Decimal('0')
result = Decimal('0')

def main():
    global x, result
    result = Decimal('1') / x  # Will fail when x=0
"""
        records = [
            {"X": Decimal("0")},   # Will cause ZeroDivisionError
            {"X": Decimal("5")},   # Should still work
        ]
        mapping = {"X": "x"}
        outputs = list(execute_generated_python(bad_source, records, mapping, ["result"]))
        assert len(outputs) == 2
        assert "_error" in outputs[0]
        # Second record divides 1/5 = 0.2
        assert outputs[1]["result"] == "0.2"

    def test_constants_applied(self):
        source = """
from decimal import Decimal

x = Decimal('0')
c = Decimal('0')
result = Decimal('0')

def main():
    global x, c, result
    result = x * c
"""
        records = [{"X": Decimal("10")}]
        outputs = list(execute_generated_python(
            source, records, {"X": "x"}, ["result"],
            constants={"c": Decimal("365")},
        ))
        assert outputs[0]["result"] == "3650"


# ============================================================
# Comparator Tests
# ============================================================


class TestComparator:
    def test_exact_match(self):
        a = [{"val": "123.45"}, {"val": "678.90"}]
        m = [{"val": "123.45"}, {"val": "678.90"}]
        result = compare_outputs(a, m, ["val"])
        assert result["total_records"] == 2
        assert result["matches"] == 2
        assert result["mismatches"] == 0
        assert result["mismatch_details"] == []

    def test_mismatch_detected(self):
        a = [{"val": "12.34"}]
        m = [{"val": "12.35"}]
        result = compare_outputs(a, m, ["val"])
        assert result["mismatches"] == 1
        assert len(result["mismatch_details"]) == 1
        detail = result["mismatch_details"][0]
        assert detail["record"] == 0
        assert detail["field"] == "val"
        assert detail["aletheia_value"] == "12.34"
        assert detail["mainframe_value"] == "12.35"
        assert detail["difference"] == "0.01"

    def test_decimal_precision_normalization(self):
        """12.34 and 12.340 should match — same Decimal value."""
        a = [{"val": "12.34"}]
        m = [{"val": "12.340"}]
        result = compare_outputs(a, m, ["val"])
        assert result["matches"] == 1
        assert result["mismatches"] == 0

    def test_zero_variants_match(self):
        """0, 0.00, 0E-7 should all match as zero."""
        a = [{"val": "0"}]
        m = [{"val": "0.00"}]
        result = compare_outputs(a, m, ["val"])
        assert result["matches"] == 1

    def test_multiple_fields_partial_mismatch(self):
        a = [{"f1": "100", "f2": "200"}]
        m = [{"f1": "100", "f2": "999"}]
        result = compare_outputs(a, m, ["f1", "f2"])
        assert result["mismatches"] == 1  # one record has a mismatch
        assert len(result["mismatch_details"]) == 1
        assert result["mismatch_details"][0]["field"] == "f2"

    def test_execution_error_flagged(self):
        a = [{"_error": "ZeroDivisionError", "_record_index": 0}]
        m = [{"val": "100"}]
        result = compare_outputs(a, m, ["val"])
        assert result["mismatches"] == 1
        assert result["mismatch_details"][0]["difference"] == "EXECUTION_ERROR"


# ============================================================
# Report Generation Tests
# ============================================================


class TestReport:
    def test_zero_drift_verdict(self):
        comparison = {
            "total_records": 100,
            "matches": 100,
            "mismatches": 0,
            "mismatch_details": [],
        }
        report = generate_report(comparison, "sha256:abc", "sha256:def")
        assert report["verdict"] == "SHADOW DIFF: ZERO DRIFT CONFIRMED"
        assert "ZERO DRIFT CONFIRMED" in report["human_readable"]
        assert report["total_records"] == 100
        assert report["matches"] == 100

    def test_drift_detected_verdict(self):
        comparison = {
            "total_records": 1000,
            "matches": 998,
            "mismatches": 2,
            "mismatch_details": [
                {
                    "record": 45,
                    "field": "INTEREST",
                    "aletheia_value": "12.34",
                    "mainframe_value": "12.35",
                    "difference": "0.01",
                },
                {
                    "record": 99,
                    "field": "PENALTY",
                    "aletheia_value": "5.00",
                    "mainframe_value": "5.01",
                    "difference": "0.01",
                },
            ],
        }
        report = generate_report(comparison, "sha256:abc", "sha256:def")
        assert report["verdict"] == "SHADOW DIFF: DRIFT DETECTED \u2014 2 RECORDS"
        assert "DRIFT DETECTED" in report["human_readable"]
        assert report["mismatches"] == 2
        assert len(report["mismatch_log"]) == 2

    def test_report_includes_hashes(self):
        comparison = {
            "total_records": 1,
            "matches": 1,
            "mismatches": 0,
            "mismatch_details": [],
        }
        report = generate_report(comparison, "sha256:aaa", "sha256:bbb", "DEMO")
        assert report["input_file_hash"] == "sha256:aaa"
        assert report["output_file_hash"] == "sha256:bbb"
        assert report["layout_name"] == "DEMO"
        assert report["timestamp"]  # non-empty


# ============================================================
# Full Pipeline — End-to-End with Demo Data
# ============================================================


class TestFullPipeline:
    def test_demo_data_zero_drift(self):
        """Full round-trip: generate demo data → parse → execute → compare → ZERO DRIFT."""
        # Load layout
        base_dir = os.path.dirname(os.path.abspath(__file__))
        layout_path = os.path.join(base_dir, "demo_data", "loan_layout.json")

        with open(layout_path, "r") as f:
            layout = json.load(f)

        # Load input data
        input_path = os.path.join(base_dir, "demo_data", "loan_input.dat")
        with open(input_path, "r") as f:
            input_data = f.read()

        # Load mainframe output data
        output_path = os.path.join(base_dir, "demo_data", "loan_mainframe_output.dat")
        with open(output_path, "r") as f:
            output_data = f.read()

        # Generate Python live from DEMO_LOAN_INTEREST.cbl
        from cobol_analyzer_api import analyze_cobol
        from generate_full_python import generate_python_module

        cobol_path = os.path.join(base_dir, "DEMO_LOAN_INTEREST.cbl")
        with open(cobol_path, "r") as f:
            cobol_source = f.read()
        analysis = analyze_cobol(cobol_source)
        generated_source = generate_python_module(analysis)["code"]

        # 1. Parse input
        input_layout = {"fields": layout["fields"], "record_length": layout.get("record_length")}
        input_records = list(parse_fixed_width(input_layout, input_data))
        assert len(input_records) == 100

        # 2. Parse mainframe output
        output_layout = layout["output_layout"]
        mainframe_raw = list(parse_fixed_width(output_layout, output_data))
        assert len(mainframe_raw) == 100

        # Map to python names
        field_mapping = output_layout["field_mapping"]
        mainframe_outputs = []
        for rec in mainframe_raw:
            mapped = {}
            for cobol_name, python_name in field_mapping.items():
                if cobol_name in rec:
                    mapped[python_name] = str(rec[cobol_name])
            mainframe_outputs.append(mapped)

        # 3. Execute generated Python
        input_mapping = layout["input_mapping"]
        output_fields = layout["output_fields"]
        constants = {k: Decimal(v) for k, v in layout["constants"].items()}

        aletheia_outputs = list(execute_generated_python(
            source=generated_source,
            input_records=input_records,
            input_mapping=input_mapping,
            output_fields=output_fields,
            constants=constants,
        ))
        assert len(aletheia_outputs) == 100

        # Verify no execution errors
        errors = [r for r in aletheia_outputs if "_error" in r]
        assert len(errors) == 0, f"Execution errors: {errors}"

        # 4. Compare
        comparison = compare_outputs(aletheia_outputs, mainframe_outputs, output_fields)

        # 5. Assert ZERO DRIFT
        assert comparison["total_records"] == 100
        assert comparison["matches"] == 100
        assert comparison["mismatches"] == 0, (
            f"Mismatches found: {comparison['mismatch_details']}"
        )

        # 6. Generate report and verify verdict
        report = generate_report(
            comparison,
            input_file_hash="sha256:test",
            output_file_hash="sha256:test",
            layout_name="DEMO_LOAN_INTEREST",
        )
        assert report["verdict"] == "SHADOW DIFF: ZERO DRIFT CONFIRMED"


# ============================================================
# Streaming Pipeline — 100K Records
# ============================================================


class TestStreamingPipeline:
    def test_streaming_large_file(self):
        """100,000 records processed via streaming without loading all into memory."""
        RECORD_COUNT = 100_000

        # Simple generated Python: result = x * 2
        source = """
from decimal import Decimal

x = Decimal('0')
result = Decimal('0')

def main():
    global x, result
    result = x * Decimal('2')
"""
        input_mapping = {"X": "x"}
        output_fields = ["result"]

        # Build input data as newline-delimited fixed-width (X is 12 chars)
        input_lines = []
        for i in range(RECORD_COUNT):
            val = f"{i:>12d}"
            input_lines.append(val)
        input_data = "\n".join(input_lines)

        # Build expected output data (result = x * 2, 12 chars)
        output_lines = []
        for i in range(RECORD_COUNT):
            val = f"{i * 2:>12d}"
            output_lines.append(val)
        expected_data = "\n".join(output_lines)

        input_layout = {
            "fields": [{"name": "X", "start": 0, "length": 12, "type": "integer"}],
            "record_length": None,
        }
        output_layout = {
            "fields": [{"name": "RESULT", "start": 0, "length": 12, "type": "integer"}],
            "record_length": None,
            "field_mapping": {"RESULT": "result"},
        }

        # Map mainframe output records to python names via generator
        def _mainframe_stream():
            for rec in parse_fixed_width_stream(output_layout, expected_data):
                yield {"result": str(rec["RESULT"])}

        # Run full streaming pipeline
        comparison = run_streaming_pipeline(
            source=source,
            input_stream=parse_fixed_width_stream(input_layout, input_data),
            mainframe_stream=_mainframe_stream(),
            input_mapping=input_mapping,
            output_fields=output_fields,
        )

        assert comparison["total_records"] == RECORD_COUNT
        assert comparison["matches"] == RECORD_COUNT
        assert comparison["mismatches"] == 0
        assert comparison["mismatch_details"] == []
        assert comparison["mismatch_details_capped"] is False

    def test_mismatch_cap_at_10k(self):
        """Mismatch details list is capped at MAX_MISMATCH_DETAILS."""
        # Every record mismatches: result should be x*2 but expected is x*3
        CAP_TEST_COUNT = 15_000

        source = """
from decimal import Decimal

x = Decimal('0')
result = Decimal('0')

def main():
    global x, result
    result = x * Decimal('2')
"""

        def _input_stream():
            for i in range(1, CAP_TEST_COUNT + 1):  # Start at 1 so 0*2 vs 0*3 doesn't match
                yield {"X": Decimal(str(i))}

        def _mainframe_stream():
            for i in range(1, CAP_TEST_COUNT + 1):
                yield {"result": str(i * 3)}  # Wrong on purpose (2*i != 3*i for i>0)

        comparison = run_streaming_pipeline(
            source=source,
            input_stream=_input_stream(),
            mainframe_stream=_mainframe_stream(),
            input_mapping={"X": "x"},
            output_fields=["result"],
        )

        assert comparison["total_records"] == CAP_TEST_COUNT
        assert comparison["mismatches"] == CAP_TEST_COUNT
        assert len(comparison["mismatch_details"]) == MAX_MISMATCH_DETAILS
        assert comparison["mismatch_details_capped"] is True


# ══════════════════════════════════════════════════════════════════════
# Record Count Mismatch Detection
# ══════════════════════════════════════════════════════════════════════


class TestRecordCountMismatch:
    """zip_longest detects when input/output record counts differ."""

    def test_record_count_mismatch_detected(self):
        """3 input records, 2 output records → extra input flagged."""
        inputs = [{"x": "1"}, {"x": "2"}, {"x": "3"}]
        outputs = [{"x": "1"}, {"x": "2"}]
        result = compare_outputs(inputs, outputs, ["x"])
        assert result["total_records"] == 3
        assert result["mismatches"] >= 1
        assert result.get("record_count_mismatch") is True
        missing = [d for d in result["mismatch_details"]
                   if "Record missing" in d.get("difference", "")]
        assert len(missing) == 1
        assert "input" in missing[0]["difference"]

    def test_extra_output_records_flagged(self):
        """2 input records, 3 output records → extra output flagged."""
        inputs = [{"x": "1"}, {"x": "2"}]
        outputs = [{"x": "1"}, {"x": "2"}, {"x": "3"}]
        result = compare_outputs(inputs, outputs, ["x"])
        assert result["total_records"] == 3
        assert result["mismatches"] >= 1
        missing = [d for d in result["mismatch_details"]
                   if "Record missing" in d.get("difference", "")]
        assert len(missing) == 1
        assert "output" in missing[0]["difference"]

    def test_equal_records_no_mismatch_flag(self):
        """3 input, 3 output (all matching) → no record_count_mismatch."""
        inputs = [{"x": "1"}, {"x": "2"}, {"x": "3"}]
        outputs = [{"x": "1"}, {"x": "2"}, {"x": "3"}]
        result = compare_outputs(inputs, outputs, ["x"])
        assert result["total_records"] == 3
        assert result["mismatches"] == 0
        assert "record_count_mismatch" not in result


class TestEbcdicDecode:
    """EBCDIC codepage decoding in parse_fixed_width."""

    def test_ebcdic_mainframe_decode(self):
        """EBCDIC CP037 bytes should decode to correct text."""
        layout = {
            "fields": [{"name": "CODE", "start": 0, "length": 3, "type": "string"}],
            "record_length": None,
            "codepage": "cp037",
        }
        # b'\xC1\xC2\xC3' = "ABC" in CP037
        data = b"\xC1\xC2\xC3\n"
        records = list(parse_fixed_width(layout, data))
        assert len(records) == 1
        assert records[0]["CODE"] == "ABC"

    def test_codepage_override(self):
        """Layout codepage='cp500' should use CP500 decoding."""
        layout = {
            "fields": [{"name": "CODE", "start": 0, "length": 3, "type": "string"}],
            "record_length": None,
            "codepage": "cp500",
        }
        data = "ABC".encode("cp500") + b"\n"
        records = list(parse_fixed_width(layout, data))
        assert len(records) == 1
        assert records[0]["CODE"] == "ABC"

    def test_generated_output_still_utf8(self):
        """String input (Aletheia-generated) still uses ASCII path."""
        layout = {
            "fields": [{"name": "VAL", "start": 0, "length": 5, "type": "string"}],
            "record_length": None,
            "codepage": "cp037",
        }
        data = "HELLO\n"
        records = list(parse_fixed_width(layout, data))
        assert len(records) == 1
        assert records[0]["VAL"] == "HELLO"


class TestCompBinaryField:
    """COMP/COMP-4 big-endian binary field parsing."""

    def test_comp_binary_field_parse(self):
        """4-byte big-endian signed integer = 1000."""
        layout = {
            "fields": [{"name": "AMT", "start": 0, "length": 4, "type": "comp"}],
            "record_length": 4,
        }
        data = (1000).to_bytes(4, "big", signed=True)
        records = list(parse_fixed_width(layout, data))
        assert len(records) == 1
        assert records[0]["AMT"] == Decimal("1000")

    def test_comp_signed_negative(self):
        """4-byte two's complement big-endian = -500."""
        layout = {
            "fields": [{"name": "AMT", "start": 0, "length": 4, "type": "comp"}],
            "record_length": 4,
        }
        data = (-500).to_bytes(4, "big", signed=True)
        records = list(parse_fixed_width(layout, data))
        assert len(records) == 1
        assert records[0]["AMT"] == Decimal("-500")

    def test_comp_halfword(self):
        """2-byte PIC S9(4) COMP halfword."""
        layout = {
            "fields": [{"name": "CODE", "start": 0, "length": 2, "type": "comp"}],
            "record_length": 2,
        }
        data = (12345).to_bytes(2, "big", signed=True)
        records = list(parse_fixed_width(layout, data))
        assert len(records) == 1
        assert records[0]["CODE"] == Decimal("12345")

    def test_comp_with_decimals(self):
        """Implied decimal: 15075 with decimals=2 → 150.75."""
        layout = {
            "fields": [{"name": "RATE", "start": 0, "length": 4, "type": "comp", "decimals": 2}],
            "record_length": 4,
        }
        data = (15075).to_bytes(4, "big", signed=True)
        records = list(parse_fixed_width(layout, data))
        assert len(records) == 1
        assert records[0]["RATE"] == Decimal("150.75")


# ============================================================
# EBCDIC Auto-Detect
# ============================================================


class TestEbcdicAutoDetect:
    """Tests for codepage='auto' detection and codepage propagation."""

    def test_ebcdic_string_decode_cp037(self):
        """EBCDIC-encoded string field decoded correctly with codepage=cp037."""
        layout = {
            "fields": [{"name": "NAME", "start": 0, "length": 5, "type": "string"}],
            "record_length": None,
            "codepage": "cp037",
        }
        data = "HELLO".encode("cp037") + b"\n"
        records = list(parse_fixed_width(layout, data))
        assert len(records) == 1
        assert records[0]["NAME"] == "HELLO"

    def test_auto_codepage_detects_ebcdic(self):
        """codepage='auto' detects EBCDIC from high-byte string field patterns."""
        from shadow_diff import detect_codepage
        layout = {
            "fields": [{"name": "NAME", "start": 0, "length": 5, "type": "string"}],
            "record_length": None,
            "codepage": "auto",
        }
        data = "HELLO".encode("cp037") + b"\n"
        records = list(parse_fixed_width(layout, data))
        assert len(records) == 1
        assert records[0]["NAME"] == "HELLO"

    def test_auto_codepage_ascii_fallback(self):
        """codepage='auto' falls back to ASCII for normal ASCII files."""
        layout = {
            "fields": [{"name": "NAME", "start": 0, "length": 5, "type": "string"}],
            "record_length": None,
            "codepage": "auto",
        }
        data = b"HELLO\n"
        records = list(parse_fixed_width(layout, data))
        assert len(records) == 1
        assert records[0]["NAME"] == "HELLO"

    def test_ascii_default_unchanged(self):
        """Default (no codepage key) still works as ASCII."""
        layout = {
            "fields": [{"name": "NAME", "start": 0, "length": 5, "type": "string"}],
            "record_length": None,
        }
        data = b"HELLO\n"
        records = list(parse_fixed_width(layout, data))
        assert len(records) == 1
        assert records[0]["NAME"] == "HELLO"

    def test_detect_codepage_ignores_binary_fields(self):
        """detect_codepage only samples string fields, not comp3/comp."""
        from shadow_diff import detect_codepage
        fields = [
            {"name": "AMT", "start": 0, "length": 4, "type": "comp3"},
            {"name": "NAME", "start": 4, "length": 5, "type": "string"},
        ]
        # Build: 4 bytes comp3 (high bytes) + "HELLO" in ASCII
        sample = bytes([0x00, 0x12, 0x34, 0x5C]) + b"HELLO"
        result = detect_codepage(sample, fields)
        assert result == "ascii"  # String bytes are ASCII, comp3 ignored

    def test_ebcdic_binary_full_pipeline(self):
        """EBCDIC cp037 binary data → parse_fixed_width_stream → correct field values."""
        from shadow_diff import parse_fixed_width_stream

        # Build a raw EBCDIC record: 10-byte name + 6-byte zoned decimal
        name_bytes = "SMITH".encode("cp037").ljust(10, b'\x40')   # \x40 = EBCDIC space
        amount_bytes = "001500".encode("cp037")                   # raw zoned "001500"
        record = name_bytes + amount_bytes
        assert len(record) == 16

        layout = {
            "fields": [
                {"name": "CUST-NAME", "start": 0, "length": 10, "type": "string"},
                {"name": "AMOUNT", "start": 10, "length": 6, "type": "decimal"},
            ],
            "record_length": 16,
            "codepage": "cp037",
        }

        records = list(parse_fixed_width_stream(layout, record))
        assert len(records) == 1
        assert records[0]["CUST-NAME"].strip() == "SMITH"
        # Parser returns raw decoded value; scaling is done by generated Python
        assert Decimal(records[0]["AMOUNT"]) == Decimal("1500")

    def test_ebcdic_binary_multiple_records(self):
        """Multiple EBCDIC records parsed in sequence."""
        from shadow_diff import parse_fixed_width_stream

        def _make_record(name, amount):
            return name.encode("cp037").ljust(10, b'\x40') + amount.encode("cp037")

        data = _make_record("JONES", "002350") + _make_record("CLARK", "000099")

        layout = {
            "fields": [
                {"name": "NAME", "start": 0, "length": 10, "type": "string"},
                {"name": "AMT", "start": 10, "length": 6, "type": "decimal"},
            ],
            "record_length": 16,
            "codepage": "cp037",
        }

        records = list(parse_fixed_width_stream(layout, data))
        assert len(records) == 2
        assert records[0]["NAME"].strip() == "JONES"
        assert Decimal(records[0]["AMT"]) == Decimal("2350")
        assert records[1]["NAME"].strip() == "CLARK"
        assert Decimal(records[1]["AMT"]) == Decimal("99")


# ============================================================
# Session Isolation (Thread Safety)
# ============================================================


class TestSessionIsolation:
    """ShadowDiffSession isolates per-user state."""

    def test_session_isolation(self):
        """Two sessions don't share state."""
        from shadow_diff import ShadowDiffSession
        s1 = ShadowDiffSession()
        s2 = ShadowDiffSession()
        s1.layouts["test"] = {"fields": []}
        assert "test" not in s2.layouts

    def test_backward_compat(self):
        """Module-level _layouts alias still works."""
        from shadow_diff import _layouts, _default_session
        assert _layouts is _default_session.layouts

    def test_get_session_creates_new(self):
        """get_session returns isolated session per username."""
        from shadow_diff import get_session
        s1 = get_session("test_user_a")
        s2 = get_session("test_user_b")
        s1.layouts["private"] = {"fields": []}
        assert "private" not in s2.layouts

    def test_get_session_reuses_existing(self):
        """get_session returns same session for same username."""
        from shadow_diff import get_session
        s1 = get_session("test_user_c")
        s2 = get_session("test_user_c")
        assert s1 is s2


class TestIoWriteRecord:
    """_io_write_record injected into exec namespace for SORT programs."""

    def test_sort_via_execute_io_program(self):
        """SORT USING/GIVING executes through execute_io_program without NameError."""
        from cobol_analyzer_api import analyze_cobol
        from generate_full_python import generate_python_module

        cobol = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SORT-IO.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT IN-FILE ASSIGN TO 'IN.DAT'.
           SELECT OUT-FILE ASSIGN TO 'OUT.DAT'.
           SELECT SORT-WK ASSIGN TO 'SORT.TMP'.
       DATA DIVISION.
       FILE SECTION.
       FD IN-FILE.
       01 IN-REC.
           05 IN-KEY    PIC 9(5).
       FD OUT-FILE.
       01 OUT-REC.
           05 OUT-KEY   PIC 9(5).
       SD SORT-WK.
       01 SORT-REC.
           05 SORT-KEY  PIC 9(5).
       WORKING-STORAGE SECTION.
       01 WS-EOF        PIC 9 VALUE 0.
       PROCEDURE DIVISION.
       MAIN-PARA.
           SORT SORT-WK
               ON ASCENDING KEY SORT-KEY
               USING IN-FILE
               GIVING OUT-FILE.
           STOP RUN.
"""
        analysis = analyze_cobol(cobol)
        gen = generate_python_module(analysis)
        code = gen["code"]
        assert "_io_write_record" in code

        input_recs = [
            {"SORT-KEY": Decimal("30")},
            {"SORT-KEY": Decimal("10")},
            {"SORT-KEY": Decimal("20")},
        ]

        results = list(execute_io_program(
            source=code,
            input_streams={"IN-FILE": iter(input_recs)},
            output_file_name="OUT-FILE",
            output_fields=["SORT-KEY"],
        ))

        assert len(results) == 3
        keys = [r["SORT-KEY"] for r in results]
        assert keys == ["10", "20", "30"]
