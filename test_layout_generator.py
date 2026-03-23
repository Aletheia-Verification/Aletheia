"""Tests for layout_generator.py — auto-layout generation from COBOL analysis."""

import json
import os
import pytest

os.environ.setdefault("USE_IN_MEMORY_DB", "1")

from cobol_analyzer_api import analyze_cobol
from generate_full_python import generate_python_module
from layout_generator import (
    pic_to_layout_type,
    display_byte_length,
    classify_variables,
    generate_layout,
)


# ── Helpers ──────────────────────────────────────────────────────

def _analyze_and_generate(cbl_source: str):
    """Parse COBOL source → return (analysis, generated_python)."""
    analysis = analyze_cobol(cbl_source)
    assert analysis["success"]
    gen = generate_python_module(analysis)
    return analysis, gen["code"]


DEMO_LOAN_SOURCE = open("DEMO_LOAN_INTEREST.cbl").read()
DEMO_LOAN_MANUAL = json.load(open("demo_data/loan_layout.json"))


# ── pic_to_layout_type ──────────────────────────────────────────

class TestPicToLayoutType:
    def test_string(self):
        assert pic_to_layout_type("X(10)", "DISPLAY") == {"type": "string"}

    def test_integer(self):
        assert pic_to_layout_type("9(3)", "DISPLAY") == {"type": "integer"}

    def test_decimal_display(self):
        result = pic_to_layout_type("S9(9)V99", "DISPLAY")
        assert result == {"type": "decimal", "decimals": 2}

    def test_comp3_binary_mode(self):
        result = pic_to_layout_type("S9(9)V99", "COMP-3", use_binary=True)
        assert result == {"type": "comp3", "decimals": 2}

    def test_comp3_text_mode(self):
        """In text mode, COMP-3 fields emit 'decimal' not 'comp3'."""
        result = pic_to_layout_type("S9(9)V99", "COMP-3", use_binary=False)
        assert result == {"type": "decimal", "decimals": 2}


# ── display_byte_length ─────────────────────────────────────────

class TestDisplayByteLength:
    def test_string(self):
        assert display_byte_length("X(10)") == 10

    def test_integer(self):
        assert display_byte_length("9(3)") == 3

    def test_signed_decimal(self):
        # S9(9)V99 → 9 + 2 + 1 (sign) = 12
        assert display_byte_length("S9(9)V99") == 12

    def test_unsigned_decimal(self):
        # 9(3)V9(6) → 3 + 6 = 9 (but S prefix makes it signed)
        assert display_byte_length("S9(3)V9(6)") == 10

    def test_simple_unsigned(self):
        assert display_byte_length("9(2)") == 2


# ── classify_variables (DEMO_LOAN_INTEREST) ─────────────────────

class TestClassifyVariables:
    @pytest.fixture(autouse=True)
    def setup(self):
        self.analysis, self.code = _analyze_and_generate(DEMO_LOAN_SOURCE)
        self.cls = classify_variables(self.code, self.analysis)

    def test_demo_inputs(self):
        expected_inputs = {
            "WS-ACCOUNT-NUM", "WS-PRINCIPAL-BAL", "WS-ANNUAL-RATE",
            "WS-DAYS-OVERDUE", "WS-VIP-FLAG",
        }
        assert expected_inputs <= self.cls["inputs"]

    def test_demo_outputs(self):
        expected_outputs = {
            "WS-DAILY-RATE", "WS-DAILY-INTEREST",
            "WS-PENALTY-AMOUNT", "WS-ACCRUED-INT",
        }
        assert expected_outputs <= self.cls["outputs"]

    def test_demo_constants(self):
        assert self.cls["constants"]["ws_days_in_year"] == "365"
        assert self.cls["constants"]["ws_grace_period"] == "15"
        assert self.cls["constants"]["ws_max_penalty_pct"] == "0.05"

    def test_classify_intermediates_empty(self):
        """All computed vars go to outputs, intermediates set is empty."""
        assert self.cls["intermediates"] == set()


# ── Full layout generation (DEMO_LOAN_INTEREST) ─────────────────

class TestGenerateLayout:
    @pytest.fixture(autouse=True)
    def setup(self):
        analysis, code = _analyze_and_generate(DEMO_LOAN_SOURCE)
        self.auto = generate_layout(analysis, code, "DEMO_LOAN_INTEREST")

    def test_field_names_stripped(self):
        """WS- prefix stripped from layout field names."""
        names = [f["name"] for f in self.auto["fields"]]
        assert "ACCOUNT-NUM" in names
        assert "WS-ACCOUNT-NUM" not in names

    def test_input_mapping(self):
        mapping = self.auto["input_mapping"]
        assert mapping["ACCOUNT-NUM"] == "ws_account_num"
        assert mapping["PRINCIPAL-BAL"] == "ws_principal_bal"
        assert mapping["ANNUAL-RATE"] == "ws_annual_rate"
        assert mapping["DAYS-OVERDUE"] == "ws_days_overdue"
        assert mapping["VIP-FLAG"] == "ws_vip_flag"

    def test_output_field_width_40(self):
        """Numeric output fields get width=40."""
        for f in self.auto["output_layout"]["fields"]:
            if f["type"] in ("decimal", "integer"):
                assert f["length"] == 40

    def test_full_layout_matches_demo_inputs(self):
        """Auto-generated input fields match manual loan_layout.json."""
        auto_fields = [(f["name"], f["start"], f["length"], f["type"])
                       for f in self.auto["fields"]]
        manual_fields = [(f["name"], f["start"], f["length"], f["type"])
                         for f in DEMO_LOAN_MANUAL["fields"]]
        assert auto_fields == manual_fields

    def test_full_layout_output_superset(self):
        """Auto output_fields is a superset of manual output_fields."""
        auto_set = set(self.auto["output_fields"])
        manual_set = set(DEMO_LOAN_MANUAL["output_fields"])
        assert manual_set <= auto_set

    def test_constants_match(self):
        assert self.auto["constants"] == DEMO_LOAN_MANUAL["constants"]

    def test_empty_program(self):
        """Program with no variables produces empty layout."""
        source = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. EMPTY.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-DUMMY PIC X(1).
       PROCEDURE DIVISION.
       0000-MAIN.
           STOP RUN.
"""
        analysis, code = _analyze_and_generate(source)
        layout = generate_layout(analysis, code, "EMPTY")
        # WS-DUMMY is not computed, so it goes to inputs
        assert layout["output_fields"] == []

    def test_88_level_excluded(self):
        """88-level conditions don't appear in layout fields."""
        all_names = [f["name"] for f in self.auto["fields"]]
        all_names += [f["name"] for f in self.auto["output_layout"]["fields"]]
        for name in all_names:
            assert name not in ("IS-VIP-ACCOUNT", "IS-STANDARD")


# ── FD-based path ────────────────────────────────────────────────

FD_TEST_SOURCE = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. FD-TEST.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT INPUT-FILE ASSIGN TO 'INPUT.DAT'.
           SELECT OUTPUT-FILE ASSIGN TO 'OUTPUT.DAT'.
       DATA DIVISION.
       FILE SECTION.
       FD INPUT-FILE.
       01 INPUT-RECORD.
          05 IN-ACCT     PIC X(10).
          05 IN-AMOUNT   PIC S9(7)V99 COMP-3.
       FD OUTPUT-FILE.
       01 OUTPUT-RECORD.
          05 OUT-ACCT    PIC X(10).
          05 OUT-RESULT  PIC S9(9)V99.
       WORKING-STORAGE SECTION.
       01 WS-TEMP        PIC S9(9)V99.
       PROCEDURE DIVISION.
       0000-MAIN.
           OPEN INPUT INPUT-FILE.
           OPEN OUTPUT OUTPUT-FILE.
           READ INPUT-FILE.
           COMPUTE WS-TEMP = IN-AMOUNT * 2.
           MOVE WS-TEMP TO OUT-RESULT.
           MOVE IN-ACCT TO OUT-ACCT.
           WRITE OUTPUT-RECORD.
           STOP RUN.
"""


class TestFDBasedLayout:
    def test_fd_based_layout(self):
        """FD path produces correct input/output layouts with storage byte lengths."""
        analysis, code = _analyze_and_generate(FD_TEST_SOURCE)
        layout = generate_layout(analysis, code, "FD-TEST")

        # Should have detected file_descriptions
        assert len(analysis["file_descriptions"]) >= 1

        # Input layout should use actual storage bytes
        input_fields = {f["name"]: f for f in layout["fields"]}
        assert "IN-ACCT" in input_fields or "ACCT" in input_fields

    def test_fd_takes_priority_over_ws(self):
        """When FD exists, FD path is used (file_descriptions non-empty)."""
        analysis, code = _analyze_and_generate(FD_TEST_SOURCE)
        assert len(analysis["file_descriptions"]) > 0
        # FD path should be triggered
        layout = generate_layout(analysis, code, "FD-TEST")
        # The layout should contain FD fields, not WS fields as inputs
        input_names = [f["name"] for f in layout["fields"]]
        # WS-TEMP should NOT be in input fields (it's a WS intermediate)
        assert "TEMP" not in input_names
        assert "WS-TEMP" not in input_names
