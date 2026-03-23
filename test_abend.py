"""
test_abend.py -- S0C7 Data Exception Emulation Tests

11 tests covering:
  - Non-numeric data detection in numeric fields
  - Message format validation
  - Null byte (0x00) handling
  - Embedded space detection
  - HIGH-VALUES (0xFF) handling
  - Valid numeric passthrough
  - Signed field support
  - Shadow Diff pipeline continuation after S0C7
  - S0C7 count in comparison report
  - CobolDecimal.store() S0C7 raising
  - Full pipeline with dirty data
"""

from decimal import Decimal

import pytest

from abend_handler import (
    S0C7DataException, validate_numeric_field, validate_string_field,
    decode_zoned_decimal, encode_zoned_decimal,
    _POSITIVE_OVERPUNCH, _NEGATIVE_OVERPUNCH,
)


# ============================================================
# TestS0C7Detection — Core Validator Tests
# ============================================================


class TestS0C7Detection:
    def test_s0c7_letter_in_numeric(self):
        """Letters in a numeric field must raise S0C7."""
        with pytest.raises(S0C7DataException) as exc_info:
            validate_numeric_field("A2B", 3, 0, "WS-AMOUNT", 0)
        assert "S0C7 DATA EXCEPTION" in str(exc_info.value)
        assert exc_info.value.field_name == "WS-AMOUNT"
        assert exc_info.value.invalid_value == "A2B"

    def test_s0c7_message_format(self):
        """Message must contain field name, PIC clause, value, and record number."""
        with pytest.raises(S0C7DataException) as exc_info:
            validate_numeric_field("XYZ", 5, 2, "WS-BALANCE", 4521)
        msg = str(exc_info.value)
        assert "WS-BALANCE" in msg
        assert "PIC 9(5)V9(2)" in msg
        assert "XYZ" in msg
        assert "4521" in msg

    def test_s0c7_null_bytes_as_zero(self):
        """Null bytes (0x00) should be replaced with '0', not abend."""
        result = validate_numeric_field(
            "\x00\x003",
            3, 0, "WS-COUNT", 0,
            raw_bytes=b"\x00\x003",
        )
        assert result == Decimal("3")

    def test_s0c7_spaces_in_numeric(self):
        """Leading spaces are OK (stripped). Embedded spaces must raise S0C7."""
        # Leading spaces — should pass
        result = validate_numeric_field("  123", 3, 0, "WS-NUM", 0)
        assert result == Decimal("123")

        # Embedded spaces — should abend
        with pytest.raises(S0C7DataException):
            validate_numeric_field("1 2 3", 3, 0, "WS-NUM", 0)

    def test_s0c7_high_values(self):
        """HIGH-VALUES (all 0xFF) should return max PIC value, not abend."""
        result = validate_numeric_field(
            "\xff\xff\xff",
            3, 0, "WS-MAX", 0,
            raw_bytes=b"\xff\xff\xff",
        )
        assert result == Decimal("999")

    def test_valid_numeric_passes(self):
        """Clean numeric value should pass through without error."""
        result = validate_numeric_field("12345", 5, 0, "WS-CLEAN", 0)
        assert result == Decimal("12345")

    def test_valid_signed_field(self):
        """Signed numeric value with leading sign should pass."""
        assert validate_numeric_field("-42.50", 3, 2, "WS-SIGNED", 0) == Decimal("-42.50")
        assert validate_numeric_field("+100", 3, 0, "WS-POS", 0) == Decimal("100")


# ============================================================
# TestS0C7InShadowDiff — Integration with Shadow Diff
# ============================================================


class TestS0C7InShadowDiff:
    def test_shadow_diff_continues_after_s0c7(self):
        """Pipeline should not halt on S0C7 -- record is flagged, processing continues."""
        from shadow_diff import parse_fixed_width

        layout = {
            "fields": [
                {"name": "NUM", "start": 0, "length": 5, "type": "integer"},
            ],
            "record_length": None,
        }
        # Record 0: valid, Record 1: dirty (letters), Record 2: valid
        data = "00100\nAB1CD\n00300"
        records = list(parse_fixed_width(layout, data))
        assert len(records) == 3
        # Record 1 should have S0C7 abend info
        assert len(records[1].get("_s0c7_abends", [])) > 0
        assert records[1]["NUM"] is None
        # Records 0 and 2 should be clean
        assert records[0]["NUM"] == Decimal("100")
        assert records[2]["NUM"] == Decimal("300")
        assert len(records[0]["_s0c7_abends"]) == 0

    def test_s0c7_count_in_report(self):
        """Comparison report must include s0c7_abends count."""
        from shadow_diff import compare_outputs

        a_outputs = [
            {"val": "100", "_s0c7_abends": []},
            {"val": None, "_s0c7_abends": [
                {"field": "NUM", "message": "S0C7...", "invalid_value": "ABC"}
            ]},
            {"val": "300", "_s0c7_abends": []},
        ]
        m_outputs = [
            {"val": "100"},
            {"val": "200"},
            {"val": "300"},
        ]
        result = compare_outputs(a_outputs, m_outputs, ["val"])
        assert result["mismatches"] >= 1
        assert result["s0c7_abends"] >= 1
        # Verify S0C7 details are recorded
        s0c7_in_details = [d for d in result["mismatch_details"]
                           if d.get("difference") == "S0C7_ABEND"]
        assert len(s0c7_in_details) >= 1


# ============================================================
# TestS0C7InCobolDecimal — Type Layer
# ============================================================


class TestS0C7InCobolDecimal:
    def test_s0c7_in_cobol_decimal(self):
        """CobolDecimal.store() with non-numeric string must raise S0C7."""
        from cobol_types import CobolDecimal

        cd = CobolDecimal("0", pic_integers=5, pic_decimals=2)
        with pytest.raises(S0C7DataException):
            cd.store("ABC")


# ============================================================
# TestFullPipelineDirtyData — End-to-End
# ============================================================


class TestFullPipelineDirtyData:
    def test_full_pipeline_dirty_data(self):
        """End-to-end: dirty records produce S0C7 flags, clean records still compare."""
        from shadow_diff import parse_fixed_width_stream, run_streaming_pipeline

        layout = {
            "fields": [
                {"name": "AMT", "start": 0, "length": 10, "type": "decimal", "decimals": 2},
            ],
            "record_length": None,
        }

        # Simple Python source that just passes through the AMT value
        python_src = (
            "from decimal import Decimal\n"
            "result_amt = amt if amt is not None else Decimal('0')\n"
        )

        # 3 input records: clean, dirty, clean
        input_data = "0000100.00\nABCDEFGHIJ\n0000300.00"
        mainframe_data = "0000100.00\n0000200.00\n0000300.00"

        # Parse mainframe output layout (same shape)
        mainframe_layout = {
            "fields": [
                {"name": "AMT", "start": 0, "length": 10, "type": "decimal", "decimals": 2},
            ],
            "record_length": None,
        }

        input_stream = parse_fixed_width_stream(layout, input_data)
        mainframe_stream = parse_fixed_width_stream(mainframe_layout, mainframe_data)

        # Map both ways: input AMT → python var amt, output captures result_amt
        result = run_streaming_pipeline(
            source=python_src,
            input_stream=input_stream,
            mainframe_stream=mainframe_stream,
            input_mapping={"AMT": "amt"},
            output_fields=["result_amt"],
        )

        assert result["total_records"] == 3
        assert result["s0c7_abends"] >= 1
        # The dirty record should be a mismatch
        assert result["mismatches"] >= 1


# ============================================================
# TestZonedDecimal — Overpunch Encoding/Decoding
# ============================================================


class TestZonedDecimal:
    def test_positive_overpunch(self):
        """'12C' → Decimal('123') (C = +3)."""
        assert decode_zoned_decimal("12C") == Decimal("123")

    def test_negative_overpunch(self):
        """'12L' → Decimal('-123') (L = -3)."""
        assert decode_zoned_decimal("12L") == Decimal("-123")

    def test_zero_overpunch_positive(self):
        """'00{' → Decimal('0') ({ = +0)."""
        assert decode_zoned_decimal("00{") == Decimal("0")

    def test_zero_overpunch_negative(self):
        """'00}' → Decimal('0') (negative zero = zero)."""
        assert decode_zoned_decimal("00}") == Decimal("0")

    def test_overpunch_with_decimals(self):
        """'12C' with pic_decimals=2 → Decimal('1.23')."""
        assert decode_zoned_decimal("12C", pic_decimals=2) == Decimal("1.23")

    def test_no_overpunch_passthrough(self):
        """'123' (no overpunch char) → Decimal('123')."""
        assert decode_zoned_decimal("123") == Decimal("123")

    def test_all_positive_chars(self):
        """Each positive overpunch character maps to the correct digit."""
        expected = {"{": 0, "A": 1, "B": 2, "C": 3, "D": 4,
                    "E": 5, "F": 6, "G": 7, "H": 8, "I": 9}
        for char, digit in expected.items():
            result = decode_zoned_decimal(f"0{char}")
            assert result == Decimal(digit), f"Char '{char}' should decode to {digit}, got {result}"

    def test_all_negative_chars(self):
        """Each negative overpunch character maps to the correct digit."""
        expected = {"}": 0, "J": 1, "K": 2, "L": 3, "M": 4,
                    "N": 5, "O": 6, "P": 7, "Q": 8, "R": 9}
        for char, digit in expected.items():
            result = decode_zoned_decimal(f"1{char}")
            if digit == 0:
                assert result == Decimal("-10"), f"Char '{char}' should decode to -10, got {result}"
            else:
                expected_val = Decimal(f"-1{digit}")
                assert result == expected_val, f"Char '{char}' should decode to {expected_val}, got {result}"

    def test_shadow_diff_with_overpunch(self):
        """End-to-end: signed_display field with overpunch data parses correctly."""
        from shadow_diff import parse_fixed_width

        layout = {
            "fields": [
                {"name": "AMT", "start": 0, "length": 5, "type": "integer",
                 "signed_display": True},
            ],
            "record_length": None,
        }
        # "012C" = +123, "045L" = -453
        data = " 012C\n 045L"
        records = list(parse_fixed_width(layout, data))
        assert len(records) == 2
        assert records[0]["AMT"] == Decimal("123")
        assert records[1]["AMT"] == Decimal("-453")
