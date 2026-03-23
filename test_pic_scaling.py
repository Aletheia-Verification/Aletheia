"""
test_pic_scaling.py — PIC P scaling digit tests.

8 tests covering:
  - parse_pic_clause P digit detection (3)
  - CobolDecimal P scaling store/read (3)
  - Arithmetic and regression (2)

Run: pytest test_pic_scaling.py -v
"""

import os
import pytest
from decimal import Decimal

os.environ["USE_IN_MEMORY_DB"] = "1"

from cobol_types import CobolDecimal
from compiler_config import reset_config


@pytest.fixture(autouse=True)
def _reset():
    reset_config()
    yield
    reset_config()


# ══════════════════════════════════════════════════════════════════════
# 1. PIC CLAUSE PARSING
# ══════════════════════════════════════════════════════════════════════


class TestPicParseP:
    """Verify parse_pic_clause detects P scaling digits."""

    def test_parse_pp999(self):
        """PIC PP999 → 3 stored digits, 2 leading P (scale down)."""
        from cobol_analyzer_api import parse_pic_clause

        result = parse_pic_clause("PP999")
        assert result is not None
        assert result["integers"] == 3
        assert result["decimals"] == 0
        assert result["p_leading"] == 2
        assert result["p_trailing"] == 0

    def test_parse_999pp(self):
        """PIC 999PP → 3 stored digits, 2 trailing P (scale up)."""
        from cobol_analyzer_api import parse_pic_clause

        result = parse_pic_clause("999PP")
        assert result is not None
        assert result["integers"] == 3
        assert result["decimals"] == 0
        assert result["p_leading"] == 0
        assert result["p_trailing"] == 2

    def test_parse_s9v9pp(self):
        """PIC S9V9PP → signed, 1 integer, 1 decimal, 2 leading P in dec_part."""
        from cobol_analyzer_api import parse_pic_clause

        result = parse_pic_clause("S9V9PP")
        assert result is not None
        assert result["signed"] is True
        assert result["integers"] == 1
        assert result["decimals"] == 1
        assert result["p_leading"] == 2
        assert result["p_trailing"] == 0


# ══════════════════════════════════════════════════════════════════════
# 2. COBOL DECIMAL P SCALING
# ══════════════════════════════════════════════════════════════════════


class TestPicPScaling:
    """Verify CobolDecimal descale/truncate/rescale for PIC P fields."""

    def test_pic_pp999_scaling(self):
        """PIC PP999 (p_leading=2): store(0.00123) → value 0.00123.

        Scale factor = 10^-(2+3) = 10^-5.
        Descale: 0.00123 / 10^-5 = 123. Truncate to PIC 999 → 123.
        Rescale: 123 * 10^-5 = 0.00123.
        """
        cd = CobolDecimal('0', pic_integers=3, pic_decimals=0, p_leading=2)
        cd.store(Decimal('0.00123'))
        assert cd.value == Decimal('0.00123')

    def test_pic_999pp_scaling(self):
        """PIC 999PP (p_trailing=2): store(12300) → value 12300.

        Scale factor = 10^2.
        Descale: 12300 / 100 = 123. Truncate to PIC 999 → 123.
        Rescale: 123 * 100 = 12300.
        """
        cd = CobolDecimal('0', pic_integers=3, pic_decimals=0, p_trailing=2)
        cd.store(Decimal('12300'))
        assert cd.value == Decimal('12300')

    def test_pic_p_truncation(self):
        """PIC 999PP (p_trailing=2): store(999999) → truncated to 99900.

        Descale: 999999 / 100 = 9999.99. Truncate to PIC 999 → 999.
        Rescale: 999 * 100 = 99900.
        """
        cd = CobolDecimal('0', pic_integers=3, pic_decimals=0, p_trailing=2)
        cd.store(Decimal('999999'))
        assert cd.value == Decimal('99900')


# ══════════════════════════════════════════════════════════════════════
# 3. ARITHMETIC AND REGRESSION
# ══════════════════════════════════════════════════════════════════════


class TestPicPArithmetic:
    """Verify P-scaled fields work correctly in arithmetic."""

    def test_pic_p_add(self):
        """Two P-scaled fields: values add correctly via .value."""
        a = CobolDecimal('0', pic_integers=3, pic_decimals=0, p_trailing=2)
        a.store(Decimal('12300'))
        b = CobolDecimal('0', pic_integers=3, pic_decimals=0, p_trailing=2)
        b.store(Decimal('45600'))
        assert a.value + b.value == Decimal('57900')

    def test_no_p_regression(self):
        """Normal PIC 9(5)V99 (no P) is completely unaffected."""
        cd = CobolDecimal('0', pic_integers=5, pic_decimals=2)
        cd.store(Decimal('12345.67'))
        assert cd.value == Decimal('12345.67')
        assert cd.p_leading == 0
        assert cd.p_trailing == 0
        assert cd._scale_factor is None
