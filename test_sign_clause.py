"""Tests for SIGN IS LEADING/TRAILING SEPARATE support."""

import os
os.environ["USE_IN_MEMORY_DB"] = "1"

from cobol_analyzer_api import analyze_cobol
from cobol_types import CobolDecimal


def _find_var(result, name):
    """Find a variable by name in analyzer result."""
    for v in result["variables"]:
        if v["name"] == name:
            return v
    raise KeyError(f"Variable {name} not found")


class TestSignClauseDetection:
    def test_sign_trailing_default(self):
        """No SIGN clause → trailing, not separate (IBM default)."""
        source = (
            "       IDENTIFICATION DIVISION.\n"
            "       PROGRAM-ID. SIGNTEST.\n"
            "       DATA DIVISION.\n"
            "       WORKING-STORAGE SECTION.\n"
            "       01  WS-AMT  PIC S9(5).\n"
            "       PROCEDURE DIVISION.\n"
            "       0000-MAIN.\n"
            "           STOP RUN.\n"
        )
        result = analyze_cobol(source)
        v = _find_var(result, "WS-AMT")
        assert v["sign_position"] == "trailing"
        assert v["sign_separate"] is False

    def test_sign_leading(self):
        """SIGN IS LEADING → sign_position='leading'."""
        source = (
            "       IDENTIFICATION DIVISION.\n"
            "       PROGRAM-ID. SIGNTEST.\n"
            "       DATA DIVISION.\n"
            "       WORKING-STORAGE SECTION.\n"
            "       01  WS-AMT  PIC S9(5) SIGN IS LEADING.\n"
            "       PROCEDURE DIVISION.\n"
            "       0000-MAIN.\n"
            "           STOP RUN.\n"
        )
        result = analyze_cobol(source)
        v = _find_var(result, "WS-AMT")
        assert v["sign_position"] == "leading"
        assert v["sign_separate"] is False

    def test_sign_trailing_separate(self):
        """SIGN IS TRAILING SEPARATE CHARACTER → separate=True."""
        source = (
            "       IDENTIFICATION DIVISION.\n"
            "       PROGRAM-ID. SIGNTEST.\n"
            "       DATA DIVISION.\n"
            "       WORKING-STORAGE SECTION.\n"
            "       01  WS-BAL  PIC S9(5) SIGN IS TRAILING\n"
            "           SEPARATE CHARACTER.\n"
            "       PROCEDURE DIVISION.\n"
            "       0000-MAIN.\n"
            "           STOP RUN.\n"
        )
        result = analyze_cobol(source)
        v = _find_var(result, "WS-BAL")
        assert v["sign_position"] == "trailing"
        assert v["sign_separate"] is True

    def test_sign_leading_separate(self):
        """SIGN IS LEADING SEPARATE → leading + separate."""
        source = (
            "       IDENTIFICATION DIVISION.\n"
            "       PROGRAM-ID. SIGNTEST.\n"
            "       DATA DIVISION.\n"
            "       WORKING-STORAGE SECTION.\n"
            "       01  WS-VAL  PIC S9(5) SIGN IS LEADING\n"
            "           SEPARATE CHARACTER.\n"
            "       PROCEDURE DIVISION.\n"
            "       0000-MAIN.\n"
            "           STOP RUN.\n"
        )
        result = analyze_cobol(source)
        v = _find_var(result, "WS-VAL")
        assert v["sign_position"] == "leading"
        assert v["sign_separate"] is True


class TestSignClauseDisplay:
    def test_display_trailing_default_negative(self):
        """Default trailing overpunch — negative appends '-'."""
        d = CobolDecimal('-42', pic_integers=5, is_signed=True)
        assert d.to_display() == "00042-"

    def test_display_trailing_default_positive(self):
        """Default trailing overpunch — positive has no sign char."""
        d = CobolDecimal('42', pic_integers=5, is_signed=True)
        assert d.to_display() == "00042"

    def test_display_leading_negative(self):
        """LEADING overpunch — negative prepends '-'."""
        d = CobolDecimal('-42', pic_integers=5, is_signed=True,
                         sign_position='leading')
        assert d.to_display() == "-00042"

    def test_display_trailing_separate_positive(self):
        """TRAILING SEPARATE — positive shows '+' suffix."""
        d = CobolDecimal('42', pic_integers=5, is_signed=True,
                         sign_position='trailing', sign_separate=True)
        assert d.to_display() == "00042+"

    def test_display_trailing_separate_negative(self):
        """TRAILING SEPARATE — negative shows '-' suffix."""
        d = CobolDecimal('-42', pic_integers=5, is_signed=True,
                         sign_position='trailing', sign_separate=True)
        assert d.to_display() == "00042-"

    def test_display_leading_separate_positive(self):
        """LEADING SEPARATE — positive shows '+' prefix."""
        d = CobolDecimal('42', pic_integers=5, is_signed=True,
                         sign_position='leading', sign_separate=True)
        assert d.to_display() == "+00042"

    def test_display_leading_separate_negative(self):
        """LEADING SEPARATE — negative shows '-' prefix."""
        d = CobolDecimal('-42', pic_integers=5, is_signed=True,
                         sign_position='leading', sign_separate=True)
        assert d.to_display() == "-00042"
