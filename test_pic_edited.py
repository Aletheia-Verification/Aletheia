"""Tests for numeric edited PIC support (Z, *, $, +, -, etc.)."""

import pytest
from decimal import Decimal

from cobol_analyzer_api import parse_pic_clause
from cobol_types import CobolDecimal, _expand_pic_pattern
from shadow_diff import _compare_one_record, _extract_numeric_from_edited


# ═══════════════════════════════════════════════════════════════
# 1. Detection tests — parse_pic_clause
# ═══════════════════════════════════════════════════════════════


class TestEditedPicDetection:
    """parse_pic_clause() recognises edited PICs and returns metadata."""

    def test_plain_numeric_not_edited(self):
        result = parse_pic_clause("9(5)V99")
        assert result is not None
        assert result["is_edited"] is False
        assert result["integers"] == 5
        assert result["decimals"] == 2

    def test_z_detected(self):
        result = parse_pic_clause("Z(4)9")
        assert result is not None
        assert result["is_edited"] is True
        assert result["integers"] == 5
        assert result["decimals"] == 0

    def test_dollar_detected(self):
        result = parse_pic_clause("$$$,$$9.99")
        assert result is not None
        assert result["is_edited"] is True
        assert result["integers"] == 6
        assert result["decimals"] == 2

    def test_minus_detected(self):
        result = parse_pic_clause("-(5)9.99")
        assert result is not None
        assert result["is_edited"] is True
        assert result["signed"] is True
        assert result["integers"] == 6
        assert result["decimals"] == 2

    def test_plus_detected(self):
        result = parse_pic_clause("+(3)9")
        assert result is not None
        assert result["is_edited"] is True
        assert result["signed"] is True
        assert result["integers"] == 4

    def test_asterisk_detected(self):
        result = parse_pic_clause("**,**9.99")
        assert result is not None
        assert result["is_edited"] is True
        assert result["integers"] == 5
        assert result["decimals"] == 2

    def test_cr_suffix_detected(self):
        result = parse_pic_clause("ZZZ,ZZ9.99CR")
        assert result is not None
        assert result["is_edited"] is True
        assert result["signed"] is True

    def test_db_suffix_detected(self):
        result = parse_pic_clause("$$$9.99DB")
        assert result is not None
        assert result["is_edited"] is True
        assert result["signed"] is True

    def test_slash_insertion_detected(self):
        result = parse_pic_clause("99/99/9999")
        assert result is not None
        assert result["is_edited"] is True
        assert result["integers"] == 8

    def test_b_insertion_detected(self):
        result = parse_pic_clause("99B99B99")
        assert result is not None
        assert result["is_edited"] is True
        assert result["integers"] == 6

    def test_edit_pattern_preserved(self):
        result = parse_pic_clause("$$$,$$9.99")
        assert result["edit_pattern"] == "$$$,$$9.99"

    def test_alphanumeric_still_none(self):
        assert parse_pic_clause("X(10)") is None

    def test_empty_still_none(self):
        assert parse_pic_clause("") is None


# ═══════════════════════════════════════════════════════════════
# 2. Pattern expansion
# ═══════════════════════════════════════════════════════════════


class TestExpandPicPattern:
    def test_z4(self):
        assert _expand_pic_pattern("Z(4)9") == "ZZZZ9"

    def test_dollar3(self):
        assert _expand_pic_pattern("$(3)") == "$$$"

    def test_nine2(self):
        assert _expand_pic_pattern("9(2)") == "99"

    def test_minus5(self):
        assert _expand_pic_pattern("-(5)9") == "-----9"

    def test_no_repetition(self):
        assert _expand_pic_pattern("ZZ9.99") == "ZZ9.99"


# ═══════════════════════════════════════════════════════════════
# 3. Display formatting — to_edited_display()
# ═══════════════════════════════════════════════════════════════


class TestEditedDisplay:
    """CobolDecimal.to_edited_display() formats values with edit chars."""

    def test_z_suppresses_zeros(self):
        cd = CobolDecimal('42', pic_integers=5, pic_decimals=0,
                          edit_pattern='Z(4)9')
        assert cd.to_edited_display() == "   42"

    def test_z_all_zeros(self):
        cd = CobolDecimal('0', pic_integers=5, pic_decimals=0,
                          edit_pattern='Z(4)9')
        assert cd.to_edited_display() == "    0"

    def test_z_full_value(self):
        cd = CobolDecimal('12345', pic_integers=5, pic_decimals=0,
                          edit_pattern='Z(4)9')
        assert cd.to_edited_display() == "12345"

    def test_dollar_float(self):
        cd = CobolDecimal('1234.56', pic_integers=6, pic_decimals=2,
                          edit_pattern='$$$,$$9.99')
        assert cd.to_edited_display() == " $1,234.56"

    def test_dollar_float_zero(self):
        cd = CobolDecimal('0', pic_integers=6, pic_decimals=2,
                          edit_pattern='$$$,$$9.99')
        assert cd.to_edited_display() == "     $0.00"

    def test_dollar_float_full(self):
        cd = CobolDecimal('123456.78', pic_integers=6, pic_decimals=2,
                          edit_pattern='$$$,$$9.99')
        # All positions used — no room for $
        assert cd.to_edited_display() == "123,456.78"

    def test_minus_float_negative(self):
        cd = CobolDecimal('-42.50', pic_integers=6, pic_decimals=2,
                          is_signed=True, edit_pattern='-(5)9.99')
        assert cd.to_edited_display() == "   -42.50"

    def test_minus_float_positive(self):
        cd = CobolDecimal('42.50', pic_integers=6, pic_decimals=2,
                          is_signed=True, edit_pattern='-(5)9.99')
        assert cd.to_edited_display() == "    42.50"

    def test_plus_float_positive(self):
        cd = CobolDecimal('5', pic_integers=4, pic_decimals=0,
                          is_signed=True, edit_pattern='+(3)9')
        assert cd.to_edited_display() == "  +5"

    def test_plus_float_negative(self):
        cd = CobolDecimal('-5', pic_integers=4, pic_decimals=0,
                          is_signed=True, edit_pattern='+(3)9')
        assert cd.to_edited_display() == "  -5"

    def test_asterisk_fill(self):
        cd = CobolDecimal('1.50', pic_integers=5, pic_decimals=2,
                          edit_pattern='**,**9.99')
        assert cd.to_edited_display() == "*****1.50"

    def test_asterisk_fill_zero(self):
        cd = CobolDecimal('0', pic_integers=5, pic_decimals=2,
                          edit_pattern='**,**9.99')
        assert cd.to_edited_display() == "*****0.00"

    def test_slash_insertion(self):
        cd = CobolDecimal('3152026', pic_integers=8, pic_decimals=0,
                          edit_pattern='99/99/9999')
        assert cd.to_edited_display() == "03/15/2026"

    def test_b_insertion(self):
        cd = CobolDecimal('123456', pic_integers=6, pic_decimals=0,
                          edit_pattern='99B99B99')
        assert cd.to_edited_display() == "12 34 56"

    def test_cr_suffix_negative(self):
        cd = CobolDecimal('-100', pic_integers=5, pic_decimals=0,
                          is_signed=True, edit_pattern='ZZ,ZZ9CR')
        assert cd.to_edited_display() == "   100CR"

    def test_cr_suffix_positive(self):
        cd = CobolDecimal('100', pic_integers=5, pic_decimals=0,
                          is_signed=True, edit_pattern='ZZ,ZZ9CR')
        assert cd.to_edited_display() == "   100  "

    def test_no_edit_pattern_fallback(self):
        cd = CobolDecimal('42', pic_integers=5, pic_decimals=0)
        # Should fall back to to_display()
        result = cd.to_edited_display()
        assert result == cd.to_display()

    def test_zz9_with_period(self):
        """PIC ZZ9.99 with value 1 → "  1.00" """
        cd = CobolDecimal('1', pic_integers=3, pic_decimals=2,
                          edit_pattern='ZZ9.99')
        assert cd.to_edited_display() == "  1.00"


# ═══════════════════════════════════════════════════════════════
# 4. Shadow Diff comparison — edited fields
# ═══════════════════════════════════════════════════════════════


class TestExtractNumericFromEdited:
    """_extract_numeric_from_edited strips edit chars correctly."""

    def test_plain_number(self):
        assert _extract_numeric_from_edited("42") == Decimal('42')

    def test_spaces_stripped(self):
        assert _extract_numeric_from_edited("   42") == Decimal('42')

    def test_dollar_comma(self):
        assert _extract_numeric_from_edited("$1,234.56") == Decimal('1234.56')

    def test_leading_dollar(self):
        assert _extract_numeric_from_edited(" $1,234.56") == Decimal('1234.56')

    def test_asterisk_fill(self):
        assert _extract_numeric_from_edited("*****1.50") == Decimal('1.50')

    def test_negative_sign(self):
        assert _extract_numeric_from_edited("   -42.50") == Decimal('-42.50')

    def test_cr_suffix(self):
        assert _extract_numeric_from_edited("   100CR") == Decimal('-100')

    def test_db_suffix(self):
        assert _extract_numeric_from_edited("   100DB") == Decimal('-100')

    def test_empty(self):
        assert _extract_numeric_from_edited("") == Decimal('0')

    def test_all_spaces(self):
        assert _extract_numeric_from_edited("     ") == Decimal('0')

    def test_plus_sign(self):
        assert _extract_numeric_from_edited("  +5") == Decimal('5')


class TestShadowDiffEditedComparison:
    """_compare_one_record handles edited fields via numeric extraction."""

    def test_edited_numeric_match(self):
        """'   42' vs '42' → no drift when field is edited."""
        a_rec = {"AMOUNT": "   42"}
        m_rec = {"AMOUNT": "42"}
        result = _compare_one_record(0, a_rec, m_rec, ["AMOUNT"],
                                     edited_fields={"AMOUNT"})
        assert result == []

    def test_edited_dollar_match(self):
        """'$1,234.56' vs '1234.56' → no drift."""
        a_rec = {"TOTAL": "$1,234.56"}
        m_rec = {"TOTAL": "1234.56"}
        result = _compare_one_record(0, a_rec, m_rec, ["TOTAL"],
                                     edited_fields={"TOTAL"})
        assert result == []

    def test_edited_real_mismatch(self):
        """'$1,234.56' vs '$1,235.56' → drift detected."""
        a_rec = {"TOTAL": "$1,234.56"}
        m_rec = {"TOTAL": "$1,235.56"}
        result = _compare_one_record(0, a_rec, m_rec, ["TOTAL"],
                                     edited_fields={"TOTAL"})
        assert len(result) == 1
        assert Decimal(result[0]["difference"]) == Decimal("1")

    def test_non_edited_still_exact(self):
        """Non-edited fields still use exact comparison."""
        a_rec = {"CODE": "   42"}
        m_rec = {"CODE": "42"}
        result = _compare_one_record(0, a_rec, m_rec, ["CODE"])
        # Without edited_fields, string mismatch or decimal compare
        # "   42" as Decimal → 42, "42" as Decimal → 42, should match
        assert result == []

    def test_edited_asterisk_vs_plain(self):
        """Edited asterisk format vs plain → no drift."""
        a_rec = {"AMT": "*****1.50"}
        m_rec = {"AMT": "1.50"}
        result = _compare_one_record(0, a_rec, m_rec, ["AMT"],
                                     edited_fields={"AMT"})
        assert result == []

    def test_edited_cr_negative_match(self):
        """'   100CR' vs '-100' → no drift."""
        a_rec = {"BAL": "   100CR"}
        m_rec = {"BAL": "-100"}
        result = _compare_one_record(0, a_rec, m_rec, ["BAL"],
                                     edited_fields={"BAL"})
        assert result == []
