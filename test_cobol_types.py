"""
test_cobol_types.py — IBM Compiler Flag Emulation Tests

11 tests covering:
  - TRUNC(STD) overflow behavior (mod to PIC capacity)
  - TRUNC(BIN) binary vs display handling
  - Decimal truncation to PIC scale
  - Signed field wrapping
  - to_display() mainframe formatting
  - CompilerConfig defaults and overrides
  - Generated Python uses CobolDecimal

Run with:
    pytest test_cobol_types.py -v
"""

from decimal import Decimal

import pytest

from cobol_types import CobolDecimal
from compiler_config import get_config, set_config, reset_config


@pytest.fixture(autouse=True)
def _reset_compiler_config():
    """Ensure each test starts with default STD config."""
    reset_config()
    yield
    reset_config()


# ══════════════════════════════════════════════════════════════════════
# TRUNC(STD) — Standard COBOL Truncation
# ══════════════════════════════════════════════════════════════════════


class TestTruncSTD:
    def test_pic_9_3_overflow_std(self):
        """PIC 9(3): 999 + 1 = 1000 → mod 1000 = 000."""
        c = CobolDecimal('0', pic_integers=3, pic_decimals=0)
        c.store(Decimal('1000'))
        assert c.value == Decimal('0')

    def test_pic_9_3_no_overflow(self):
        """PIC 9(3): 501 fits — no truncation."""
        c = CobolDecimal('0', pic_integers=3, pic_decimals=0)
        c.store(Decimal('501'))
        assert c.value == Decimal('501')

    def test_pic_s9_3_negative_wrap(self):
        """PIC S9(3): -1000 wraps → -000."""
        c = CobolDecimal('0', pic_integers=3, pic_decimals=0, is_signed=True)
        c.store(Decimal('-1000'))
        assert c.value == Decimal('0')

    def test_pic_9_3v99_decimal_truncation(self):
        """PIC 9(3)V99: 12.3456 → 12.34 (truncate to 2 decimals)."""
        c = CobolDecimal('0', pic_integers=3, pic_decimals=2)
        c.store(Decimal('12.3456'))
        assert c.value == Decimal('12.34')

    def test_multiply_overflow(self):
        """PIC 9(3): 500 * 3 = 1500 → mod 1000 = 500."""
        c = CobolDecimal('0', pic_integers=3, pic_decimals=0)
        c.store(Decimal('500') * Decimal('3'))
        assert c.value == Decimal('500')

    def test_division_precision(self):
        """PIC 9(3)V99: 10 / 3 = 3.33... → truncated to 3.33."""
        c = CobolDecimal('0', pic_integers=3, pic_decimals=2)
        c.store(Decimal('10') / Decimal('3'))
        assert c.value == Decimal('3.33')


# ══════════════════════════════════════════════════════════════════════
# Cross-PIC MOVE — Decimal Alignment
# ══════════════════════════════════════════════════════════════════════


class TestCrossPicMove:
    """Cross-PIC MOVE: store() truncates/pads when source PIC != target PIC."""

    def test_cross_pic_move_truncates(self):
        """PIC 9(5)V9: 123.45 → 123.4 (truncate extra decimal, no rounding)."""
        target = CobolDecimal('0', pic_integers=5, pic_decimals=1)
        target.store(Decimal('123.45'))
        assert target.value == Decimal('123.4')

    def test_cross_pic_move_zero_fills(self):
        """PIC 9(5)V99: 12.3 → value 12.3, display '0001230'."""
        target = CobolDecimal('0', pic_integers=5, pic_decimals=2)
        target.store(Decimal('12.3'))
        assert target.value == Decimal('12.3')
        assert target.to_display() == "0001230"

    def test_cross_pic_integer_expansion(self):
        """PIC 9(5): 42 → value 42, display '00042'."""
        target = CobolDecimal('0', pic_integers=5, pic_decimals=0)
        target.store(Decimal('42'))
        assert target.value == Decimal('42')
        assert target.to_display() == "00042"


# ══════════════════════════════════════════════════════════════════════
# TRUNC(BIN) — Binary Mode
# ══════════════════════════════════════════════════════════════════════


class TestTruncBIN:
    def test_pic_9_3_overflow_bin_display(self):
        """TRUNC(BIN) + DISPLAY item: still truncates to PIC size."""
        set_config(trunc_mode="BIN")
        c = CobolDecimal('0', pic_integers=3, pic_decimals=0, is_comp=False)
        c.store(Decimal('1000'))
        assert c.value == Decimal('0')

    def test_comp_item_no_truncate_bin(self):
        """TRUNC(BIN) + COMP item: keeps full binary range."""
        set_config(trunc_mode="BIN")
        c = CobolDecimal('0', pic_integers=3, pic_decimals=0, is_comp=True)
        c.store(Decimal('1000'))
        assert c.value == Decimal('1000')


# ══════════════════════════════════════════════════════════════════════
# Display Format
# ══════════════════════════════════════════════════════════════════════


class TestCobolDecimalDisplay:
    def test_display_format(self):
        """to_display() matches mainframe: PIC 9(3)V99 value 12.30 → '01230'."""
        c = CobolDecimal('12.30', pic_integers=3, pic_decimals=2)
        assert c.to_display() == "01230"

    def test_display_signed_negative(self):
        """PIC S9(3) value -42 → '042-'."""
        c = CobolDecimal('-42', pic_integers=3, pic_decimals=0, is_signed=True)
        assert c.to_display() == "042-"


# ══════════════════════════════════════════════════════════════════════
# CompilerConfig
# ══════════════════════════════════════════════════════════════════════


class TestCompilerConfig:
    def test_default_is_std(self):
        """Default trunc_mode is STD."""
        config = get_config()
        assert config.trunc_mode == "STD"
        assert config.arith_mode == "COMPAT"
        assert config.precision == 18

    def test_override_to_bin(self):
        """Can switch to BIN mode."""
        config = set_config(trunc_mode="BIN")
        assert config.trunc_mode == "BIN"
        # Verify it affects CobolDecimal
        c = CobolDecimal('0', pic_integers=3, pic_decimals=0, is_comp=True)
        c.store(Decimal('1000'))
        assert c.value == Decimal('1000')

    def test_invalid_trunc_mode_rejected(self):
        """Invalid trunc mode raises ValueError."""
        with pytest.raises(ValueError, match="Invalid trunc_mode"):
            set_config(trunc_mode="INVALID")


# ══════════════════════════════════════════════════════════════════════
# Generated Python Uses CobolDecimal
# ══════════════════════════════════════════════════════════════════════


class TestGeneratedPython:
    def test_uses_cobol_decimal(self):
        """generate_python_module emits CobolDecimal for numeric variables."""
        from cobol_analyzer_api import analyze_cobol
        from generate_full_python import generate_python_module
        with open("DEMO_LOAN_INTEREST.cbl") as f:
            source = f.read()
        result = analyze_cobol(source)
        code = generate_python_module(result)["code"]
        assert "CobolDecimal" in code
        assert "from cobol_types import CobolDecimal" in code
        assert ".store(" in code
        assert ".value" in code
        assert "set_config(trunc_mode=" in code


# ══════════════════════════════════════════════════════════════════════
# CobolFieldProxy.is_comp — excludes COMP-3
# ══════════════════════════════════════════════════════════════════════


class TestCobolFieldProxyIsComp:
    """is_comp must be True only for true binary types, not COMP-3."""

    def _make_proxy(self, storage_type):
        from cobol_types import CobolMemoryRegion, CobolFieldProxy
        region = CobolMemoryRegion(4)
        region.register_field('F', offset=0, length=4,
                              pic_integers=5, pic_decimals=0,
                              is_signed=True, storage_type=storage_type,
                              is_string=False)
        return CobolFieldProxy(region, 'F')

    def test_comp3_not_is_comp(self):
        proxy = self._make_proxy('COMP-3')
        assert proxy.is_comp is False

    def test_comp_is_comp(self):
        proxy = self._make_proxy('COMP')
        assert proxy.is_comp is True

    def test_comp5_is_comp(self):
        proxy = self._make_proxy('COMP-5')
        assert proxy.is_comp is True

    def test_display_not_is_comp(self):
        proxy = self._make_proxy('DISPLAY')
        assert proxy.is_comp is False


class TestSpacesAsZero:
    """IBM COBOL: blank numeric fields are implicitly zero."""

    def test_spaces_become_zero(self):
        """All-spaces string stored as Decimal(0)."""
        d = CobolDecimal(pic_integers=5, pic_decimals=0)
        d.store("     ")
        assert d.value == Decimal("0")

    def test_mixed_spaces_digits(self):
        """Space-padded digits stripped and stored correctly."""
        d = CobolDecimal(pic_integers=5, pic_decimals=0)
        d.store(" 123 ")
        assert d.value == Decimal("123")

    def test_normal_store_unchanged(self):
        """Clean digit string still works."""
        d = CobolDecimal(pic_integers=5, pic_decimals=0)
        d.store("456")
        assert d.value == Decimal("456")

    def test_spaces_in_comparison(self):
        """Space-filled field equals zero in numeric comparison."""
        d = CobolDecimal(pic_integers=5, pic_decimals=0)
        d.store("     ")
        assert d.value == Decimal("0")
        assert d.value == 0


class TestBlankWhenZero:
    """BLANK WHEN ZERO clause: zero displays as spaces."""

    def test_blank_when_zero_display(self):
        """Zero field with BLANK WHEN ZERO → spaces."""
        d = CobolDecimal(pic_integers=5, pic_decimals=0, blank_when_zero=True)
        d.store(0)
        assert d.to_display() == "     "

    def test_blank_when_zero_nonzero(self):
        """Non-zero field with BLANK WHEN ZERO → normal display."""
        d = CobolDecimal(pic_integers=5, pic_decimals=0, blank_when_zero=True)
        d.store(42)
        assert d.to_display() == "00042"

    def test_blank_when_zero_with_decimals(self):
        """Zero with BLANK WHEN ZERO + V99 → spaces for full width."""
        d = CobolDecimal(pic_integers=3, pic_decimals=2, blank_when_zero=True)
        d.store(0)
        assert d.to_display() == "     "

    def test_blank_when_zero_false(self):
        """Without BLANK WHEN ZERO, zero displays normally."""
        d = CobolDecimal(pic_integers=5, pic_decimals=0)
        d.store(0)
        assert d.to_display() == "00000"


class TestAnalyzerClauseDetection:
    """Analyzer detects BLANK WHEN ZERO and JUSTIFIED RIGHT."""

    def test_blank_when_zero_detected(self):
        import os; os.environ["USE_IN_MEMORY_DB"] = "1"
        from cobol_analyzer_api import analyze_cobol
        cobol = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TESTPROG.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-AMT         PIC 9(5) BLANK WHEN ZERO.
       PROCEDURE DIVISION.
       0000-MAIN.
           STOP RUN.
"""
        result = analyze_cobol(cobol)
        var = next((v for v in result["variables"] if v["name"] == "WS-AMT"), None)
        assert var is not None, "WS-AMT not found in variables"
        assert var["blank_when_zero"] is True

    def test_justified_right_detected(self):
        import os; os.environ["USE_IN_MEMORY_DB"] = "1"
        from cobol_analyzer_api import analyze_cobol
        cobol = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TESTPROG.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-NAME        PIC X(10) JUSTIFIED RIGHT.
       PROCEDURE DIVISION.
       0000-MAIN.
           STOP RUN.
"""
        result = analyze_cobol(cobol)
        var = next((v for v in result["variables"] if v["name"] == "WS-NAME"), None)
        assert var is not None, "WS-NAME not found in variables"
        assert var["justified_right"] is True

    def test_no_clauses_default_false(self):
        import os; os.environ["USE_IN_MEMORY_DB"] = "1"
        from cobol_analyzer_api import analyze_cobol
        cobol = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TESTPROG.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-VAL         PIC 9(5).
       PROCEDURE DIVISION.
       0000-MAIN.
           STOP RUN.
"""
        result = analyze_cobol(cobol)
        var = next((v for v in result["variables"] if v["name"] == "WS-VAL"), None)
        assert var is not None
        assert var["blank_when_zero"] is False
        assert var["justified_right"] is False


class TestRenamesDetection:
    """Level 66 RENAMES detection in analyzer."""

    def test_renames_single_detected(self):
        """66 X RENAMES Y → detected in analysis."""
        import os; os.environ["USE_IN_MEMORY_DB"] = "1"
        from cobol_analyzer_api import analyze_cobol
        cobol = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TESTPROG.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-GROUP.
           05  WS-FIRST        PIC X(10).
           05  WS-LAST         PIC X(10).
       66  WS-ALIAS RENAMES WS-FIRST.
       PROCEDURE DIVISION.
       0000-MAIN.
           STOP RUN.
"""
        result = analyze_cobol(cobol)
        assert len(result["renames"]) >= 1
        r = result["renames"][0]
        assert "WS-ALIAS" in r["name"].upper()
        assert "WS-FIRST" in r["from_field"].upper()
        assert r["thru_field"] is None

    def test_renames_thru_detected(self):
        """66 X RENAMES Y THRU Z → both fields recorded."""
        import os; os.environ["USE_IN_MEMORY_DB"] = "1"
        from cobol_analyzer_api import analyze_cobol
        cobol = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TESTPROG.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-GROUP.
           05  WS-STREET       PIC X(20).
           05  WS-CITY         PIC X(15).
           05  WS-ZIP          PIC X(5).
       66  WS-FULL-ADDR RENAMES WS-STREET THRU WS-ZIP.
       PROCEDURE DIVISION.
       0000-MAIN.
           STOP RUN.
"""
        result = analyze_cobol(cobol)
        assert len(result["renames"]) >= 1
        r = result["renames"][0]
        assert "WS-FULL-ADDR" in r["name"].upper()
        assert "WS-STREET" in r["from_field"].upper()
        assert r["thru_field"] is not None
        assert "WS-ZIP" in r["thru_field"].upper()

    def test_no_renames_empty_list(self):
        """Program without 66 → empty renames list."""
        import os; os.environ["USE_IN_MEMORY_DB"] = "1"
        from cobol_analyzer_api import analyze_cobol
        cobol = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TESTPROG.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-VAL         PIC 9(5).
       PROCEDURE DIVISION.
       0000-MAIN.
           STOP RUN.
"""
        result = analyze_cobol(cobol)
        assert result["renames"] == []


class TestExpandPicMalformed:
    """C5 audit fix: malformed PIC patterns must not crash."""

    def test_missing_close_paren(self):
        from cobol_types import _expand_pic_pattern
        result = _expand_pic_pattern("Z(4")
        assert isinstance(result, str)

    def test_valid_pattern_still_works(self):
        from cobol_types import _expand_pic_pattern
        assert _expand_pic_pattern("9(3)V9(2)") == "999V99"
        assert _expand_pic_pattern("Z(4)9") == "ZZZZ9"


class TestPicV99Truncation:
    """M10 audit verification: PIC V99 (no integer digits) truncation is correct."""

    def test_pic_v99_stores_fractional(self):
        c = CobolDecimal('0', pic_integers=0, pic_decimals=2)
        c.store(Decimal('0.75'))
        assert c.value == Decimal('0.75')

    def test_pic_v99_overflow_truncates(self):
        """Values >= 1 overflow — integer part discarded (mod 1)."""
        c = CobolDecimal('0', pic_integers=0, pic_decimals=2)
        c.store(Decimal('1.50'))
        assert c.value == Decimal('0.50')


# ══════════════════════════════════════════════════════════════════════
# Arithmetic Intermediate Precision — ARITH(COMPAT) vs ARITH(EXTEND)
# ══════════════════════════════════════════════════════════════════════


class TestArithIntermediatePrecision:
    """Prove that getcontext().prec controls intermediate arithmetic precision.

    CobolDecimal has no __add__/__mul__ — generated Python does raw Decimal
    arithmetic at getcontext().prec, then truncates on store(). prec=18
    (COMPAT) limits intermediates to 18 significant digits.
    """

    def test_compat_18_digit_truncation(self):
        """1234567891^2 = 1524157877488187881 (19 non-zero digits).
        At prec=18, the 19th digit is lost in the Decimal intermediate."""
        from decimal import getcontext
        getcontext().prec = 18

        a = Decimal('1234567891')
        intermediate = a * a
        # Exact: 1524157877488187881 — 19 sig digits, last is non-zero
        exact = Decimal('1524157877488187881')

        # prec=18 rounds to 18 sig digits — last digit lost
        assert intermediate != exact

        # Verify with prec=31 the exact value IS preserved
        getcontext().prec = 31
        exact_check = Decimal('1234567891') * Decimal('1234567891')
        assert exact_check == exact

    def test_extend_31_digit_preserves(self):
        """Same multiply at prec=31 preserves all 19 digits."""
        from decimal import getcontext
        getcontext().prec = 31

        a = Decimal('1234567890')
        b = Decimal('1234567890')
        intermediate = a * b
        exact = Decimal('1524157875019052100')

        set_config(trunc_mode="OPT", arith_mode="EXTEND")
        target = CobolDecimal('0', pic_integers=19, pic_decimals=0)
        target.store(intermediate)
        assert target.value == exact

    def test_compat_chained_arithmetic_drift(self):
        """Chained arithmetic with large values at prec=18 vs prec=31.
        Each step's 18-digit rounding accumulates drift."""
        from decimal import getcontext

        # prec=18 (COMPAT) — intermediate products exceed 18 sig digits
        getcontext().prec = 18
        val_18 = Decimal('123456789012345678')  # 18 digits
        for _ in range(10):
            val_18 = val_18 * Decimal('1.000000001')  # adds 19th+ digit each time

        # prec=31 (EXTEND) — preserves all digits
        getcontext().prec = 31
        val_31 = Decimal('123456789012345678')
        for _ in range(10):
            val_31 = val_31 * Decimal('1.000000001')

        # The raw Decimal intermediates must differ
        assert val_18 != val_31


# ══════════════════════════════════════════════════════════════════════
# Level 78 Constants — Preprocessor
# ══════════════════════════════════════════════════════════════════════


class TestLevel78Constants:
    """Level 78 constant substitution in the analyzer preprocessor."""

    def test_level_78_numeric_substituted(self):
        from cobol_analyzer_api import analyze_cobol
        cobol = (
            "       IDENTIFICATION DIVISION.\n"
            "       PROGRAM-ID. TEST78.\n"
            "       DATA DIVISION.\n"
            "       WORKING-STORAGE SECTION.\n"
            "       78  MAX-SIZE              VALUE 100.\n"
            "       01  WS-RESULT             PIC 9(5).\n"
            "       PROCEDURE DIVISION.\n"
            "       MAIN-PARA.\n"
            "           COMPUTE WS-RESULT = MAX-SIZE + 1.\n"
            "           STOP RUN.\n"
        )
        result = analyze_cobol(cobol)
        assert result["success"]
        consts = result.get("level_78_constants", [])
        assert len(consts) == 1
        assert consts[0]["name"] == "MAX-SIZE"
        assert consts[0]["value"] == "100"

    def test_level_78_string_substituted(self):
        from cobol_analyzer_api import analyze_cobol
        cobol = (
            "       IDENTIFICATION DIVISION.\n"
            "       PROGRAM-ID. TEST78S.\n"
            "       DATA DIVISION.\n"
            "       WORKING-STORAGE SECTION.\n"
            "       78  WS-LABEL              VALUE 'HELLO'.\n"
            "       01  WS-OUT                PIC X(10).\n"
            "       PROCEDURE DIVISION.\n"
            "       MAIN-PARA.\n"
            "           MOVE WS-LABEL TO WS-OUT.\n"
            "           STOP RUN.\n"
        )
        result = analyze_cobol(cobol)
        assert result["success"]
        consts = result.get("level_78_constants", [])
        assert len(consts) == 1
        assert consts[0]["value"] == "HELLO"

    def test_level_78_not_in_variables(self):
        from cobol_analyzer_api import analyze_cobol
        cobol = (
            "       IDENTIFICATION DIVISION.\n"
            "       PROGRAM-ID. TEST78V.\n"
            "       DATA DIVISION.\n"
            "       WORKING-STORAGE SECTION.\n"
            "       78  TAX-RATE              VALUE 15.\n"
            "       01  WS-AMOUNT             PIC 9(5).\n"
            "       PROCEDURE DIVISION.\n"
            "       MAIN-PARA.\n"
            "           STOP RUN.\n"
        )
        result = analyze_cobol(cobol)
        names = [v["name"] for v in result["variables"] if v["name"]]
        assert "TAX-RATE" not in names

    def test_no_level_78_empty_list(self):
        from cobol_analyzer_api import analyze_cobol
        cobol = (
            "       IDENTIFICATION DIVISION.\n"
            "       PROGRAM-ID. NOLEV78.\n"
            "       DATA DIVISION.\n"
            "       WORKING-STORAGE SECTION.\n"
            "       01  WS-X                  PIC 9(3).\n"
            "       PROCEDURE DIVISION.\n"
            "       MAIN-PARA.\n"
            "           STOP RUN.\n"
        )
        result = analyze_cobol(cobol)
        assert result.get("level_78_constants", []) == []

    def test_level_78_collision_skipped(self):
        """If a level 78 name matches a variable, skip substitution."""
        from cobol_analyzer_api import analyze_cobol
        cobol = (
            "       IDENTIFICATION DIVISION.\n"
            "       PROGRAM-ID. TEST78C.\n"
            "       DATA DIVISION.\n"
            "       WORKING-STORAGE SECTION.\n"
            "       78  WS-RATE               VALUE 5.\n"
            "       01  WS-RATE               PIC 9(3).\n"
            "       01  WS-OUT                PIC 9(5).\n"
            "       PROCEDURE DIVISION.\n"
            "       MAIN-PARA.\n"
            "           COMPUTE WS-OUT = WS-RATE + 1.\n"
            "           STOP RUN.\n"
        )
        result = analyze_cobol(cobol)
        assert result["success"]
        consts = result.get("level_78_constants", [])
        assert len(consts) == 1
        assert consts[0].get("skipped") is True
        # WS-RATE should still be a variable (not substituted)
        names = [v["name"] for v in result["variables"] if v["name"]]
        assert "WS-RATE" in names
