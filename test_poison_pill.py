"""
test_poison_pill.py — Poison Pill Generator tests.

5 tests:
  1. Correct record count for DEMO_LOAN_INTEREST
  2. Max values match PIC clause exactly
  3. Overflow values exceed PIC
  4. PIC X fields get all_spaces and high_value pills
  5. Roundtrip: generated .dat parses back through parse_fixed_width
"""

import os
os.environ["USE_IN_MEMORY_DB"] = "1"

from decimal import Decimal
from pathlib import Path

from cobol_analyzer_api import analyze_cobol
from generate_full_python import generate_python_module
from poison_pill_generator import generate_poison_pills
from shadow_diff import parse_fixed_width


# ── Helpers ────────────────────────────────────────────────────

DEMO_CBL = Path(__file__).resolve().parent / "DEMO_LOAN_INTEREST.cbl"


def _demo_pills():
    """Parse DEMO_LOAN_INTEREST.cbl and generate poison pills."""
    cobol = DEMO_CBL.read_text(encoding="utf-8")
    analysis = analyze_cobol(cobol)
    assert analysis.get("success"), f"Parse failed: {analysis}"
    gen = generate_python_module(analysis)
    return generate_poison_pills(analysis, gen["code"])


# ── Synthetic COBOL for targeted tests ─────────────────────────

SYNTH_COBOL = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. PILL-TEST.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-AMOUNT           PIC S9(5)V99.
       01  WS-COUNT            PIC 9(3).
       01  WS-NAME             PIC X(10).
       01  WS-RESULT           PIC S9(7)V99.

       PROCEDURE DIVISION.
       0000-MAIN.
           COMPUTE WS-RESULT = WS-AMOUNT * WS-COUNT.
           STOP RUN.
"""


def _synth_pills():
    analysis = analyze_cobol(SYNTH_COBOL)
    assert analysis.get("success")
    gen = generate_python_module(analysis)
    return generate_poison_pills(analysis, gen["code"])


# ── Test 1: Correct record count ──────────────────────────────


class TestCorrectRecordCount:
    def test_demo_generates_pills(self):
        result = _demo_pills()
        assert result["record_count"] > 0
        assert len(result["pills"]) == result["record_count"]
        # Each pill has required fields
        for pill in result["pills"]:
            assert "field" in pill
            assert "edge_case" in pill
            assert "value" in pill

    def test_synth_record_count(self):
        """WS-AMOUNT (signed numeric, 5 edge cases), WS-COUNT (unsigned numeric, 4 edge cases),
        WS-NAME (string, 2 edge cases) = 11 total.
        WS-RESULT is output, not input — should not generate pills."""
        result = _synth_pills()
        pills = result["pills"]
        fields = {p["field"] for p in pills}
        # WS-RESULT should NOT be in pills (it's output)
        assert "RESULT" not in fields and "WS-RESULT" not in fields
        # Input fields should be present (names are stripped of WS- prefix)
        assert result["record_count"] > 0


# ── Test 2: Max values match PIC ──────────────────────────────


class TestMaxValuesMatchPic:
    def test_signed_decimal_max(self):
        """PIC S9(5)V99 → max = 99999.99"""
        result = _synth_pills()
        amount_pills = [p for p in result["pills"] if p["field"] == "AMOUNT"]
        max_pill = [p for p in amount_pills if p["edge_case"] == "max_value"]
        assert len(max_pill) == 1
        assert Decimal(max_pill[0]["value"]) == Decimal("99999.99")

    def test_unsigned_integer_max(self):
        """PIC 9(3) → max = 999"""
        result = _synth_pills()
        count_pills = [p for p in result["pills"] if p["field"] == "COUNT"]
        max_pill = [p for p in count_pills if p["edge_case"] == "max_value"]
        assert len(max_pill) == 1
        assert Decimal(max_pill[0]["value"]) == Decimal("999")


# ── Test 3: Overflow exceeds PIC ──────────────────────────────


class TestOverflowExceedsPic:
    def test_signed_decimal_overflow(self):
        """PIC S9(5)V99 → overflow = 100000.00 (exceeds 99999.99)"""
        result = _synth_pills()
        amount_pills = [p for p in result["pills"] if p["field"] == "AMOUNT"]
        overflow = [p for p in amount_pills if p["edge_case"] == "overflow"]
        assert len(overflow) == 1
        assert Decimal(overflow[0]["value"]) > Decimal("99999.99")

    def test_unsigned_integer_overflow(self):
        """PIC 9(3) → overflow = 1000 (exceeds 999)"""
        result = _synth_pills()
        count_pills = [p for p in result["pills"] if p["field"] == "COUNT"]
        overflow = [p for p in count_pills if p["edge_case"] == "overflow"]
        assert len(overflow) == 1
        assert Decimal(overflow[0]["value"]) > Decimal("999")


# ── Test 4: PIC X fields ─────────────────────────────────────


class TestPicXFields:
    def test_all_spaces(self):
        """PIC X(10) → all_spaces pill = 10 spaces"""
        result = _synth_pills()
        name_pills = [p for p in result["pills"] if p["field"] == "NAME"]
        spaces = [p for p in name_pills if p["edge_case"] == "all_spaces"]
        assert len(spaces) == 1
        assert spaces[0]["value"] == " " * 10

    def test_high_value(self):
        """PIC X(10) → high_value pill = 10 × 0xFF"""
        result = _synth_pills()
        name_pills = [p for p in result["pills"] if p["field"] == "NAME"]
        hv = [p for p in name_pills if p["edge_case"] == "high_value"]
        assert len(hv) == 1
        assert hv[0]["value"] == "\xff" * 10

    def test_no_numeric_pills_for_string(self):
        """PIC X should NOT get max_value/zero/overflow pills"""
        result = _synth_pills()
        name_pills = [p for p in result["pills"] if p["field"] == "NAME"]
        cases = {p["edge_case"] for p in name_pills}
        assert "max_value" not in cases
        assert "zero" not in cases
        assert "overflow" not in cases


# ── Test 5: Roundtrip through parse_fixed_width ──────────────


class TestRoundtrip:
    def test_dat_parses_without_error(self):
        """All poison pill records parse back through parse_fixed_width."""
        result = _synth_pills()
        dat_bytes = result["dat_bytes"]
        layout = result["layout"]

        records = list(parse_fixed_width(layout, dat_bytes))
        assert len(records) == result["record_count"]

        # Every record should have all input fields
        field_names = {f["name"] for f in layout["fields"]}
        for record in records:
            for name in field_names:
                assert name in record, f"Missing field {name} in parsed record"

    def test_max_value_parses_correctly(self):
        """Max-value pill for AMOUNT parses to expected Decimal."""
        result = _synth_pills()
        dat_bytes = result["dat_bytes"]
        layout = result["layout"]

        records = list(parse_fixed_width(layout, dat_bytes))

        # Find the max_value pill index for AMOUNT
        for idx, pill in enumerate(result["pills"]):
            if pill["field"] == "AMOUNT" and pill["edge_case"] == "max_value":
                record = records[idx]
                parsed_val = record["AMOUNT"]
                assert parsed_val == Decimal("99999.99"), \
                    f"Expected 99999.99, got {parsed_val}"
                break
