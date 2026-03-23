"""Tests for ACCEPT FROM DATE/TIME/DAY support.

Verifies that ACCEPT FROM DATE/TIME/DAY statements produce
deterministic placeholder values in the generated Python.
"""
import os
import pytest

os.environ["USE_IN_MEMORY_DB"] = "1"

from cobol_analyzer_api import analyze_cobol
from generate_full_python import generate_python_module


def _analyze_and_generate(cobol_src: str) -> dict:
    """Helper: parse COBOL → generate Python → return result dict."""
    analysis = analyze_cobol(cobol_src)
    return generate_python_module(analysis)


ACCEPT_DATE_COBOL = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCEPT-DATE-TEST.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-DATE         PIC X(6).
       PROCEDURE DIVISION.
       0000-MAIN.
           ACCEPT WS-DATE FROM DATE.
           DISPLAY WS-DATE.
           STOP RUN.
"""

ACCEPT_DATE_YYYYMMDD_COBOL = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCEPT-YYYYMMDD-TEST.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-FULL-DATE    PIC X(8).
       PROCEDURE DIVISION.
       0000-MAIN.
           ACCEPT WS-FULL-DATE FROM DATE YYYYMMDD.
           DISPLAY WS-FULL-DATE.
           STOP RUN.
"""

ACCEPT_TIME_COBOL = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCEPT-TIME-TEST.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-TIME         PIC X(8).
       PROCEDURE DIVISION.
       0000-MAIN.
           ACCEPT WS-TIME FROM TIME.
           DISPLAY WS-TIME.
           STOP RUN.
"""

ACCEPT_DAY_COBOL = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCEPT-DAY-TEST.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-DAY          PIC X(5).
       PROCEDURE DIVISION.
       0000-MAIN.
           ACCEPT WS-DAY FROM DAY.
           DISPLAY WS-DAY.
           STOP RUN.
"""

ACCEPT_DAY_YYYYDDD_COBOL = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCEPT-YYYYDDD-TEST.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-FULL-DAY     PIC X(7).
       PROCEDURE DIVISION.
       0000-MAIN.
           ACCEPT WS-FULL-DAY FROM DAY YYYYDDD.
           DISPLAY WS-FULL-DAY.
           STOP RUN.
"""

ACCEPT_IN_IF_COBOL = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCEPT-IN-IF-TEST.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-FLAG         PIC X(1) VALUE 'Y'.
       01  WS-DATE         PIC X(6).
       PROCEDURE DIVISION.
       0000-MAIN.
           IF WS-FLAG = 'Y'
               ACCEPT WS-DATE FROM DATE
           END-IF.
           DISPLAY WS-DATE.
           STOP RUN.
"""


class TestAcceptFromDate:
    def test_accept_from_date(self):
        """ACCEPT WS-DATE FROM DATE assigns '000000' placeholder."""
        result = _analyze_and_generate(ACCEPT_DATE_COBOL)
        code = result["code"]
        assert "'000000'" in code, f"Expected '000000' placeholder in:\n{code}"
        assert "ws_date" in code

    def test_accept_from_date_yyyymmdd(self):
        """ACCEPT WS-FULL-DATE FROM DATE YYYYMMDD assigns '00000000' placeholder."""
        result = _analyze_and_generate(ACCEPT_DATE_YYYYMMDD_COBOL)
        code = result["code"]
        assert "'00000000'" in code, f"Expected '00000000' placeholder in:\n{code}"

    def test_accept_from_time(self):
        """ACCEPT WS-TIME FROM TIME assigns '00000000' placeholder."""
        result = _analyze_and_generate(ACCEPT_TIME_COBOL)
        code = result["code"]
        assert "'00000000'" in code, f"Expected '00000000' placeholder in:\n{code}"
        assert "ws_time" in code

    def test_accept_from_day(self):
        """ACCEPT WS-DAY FROM DAY assigns '00000' placeholder."""
        result = _analyze_and_generate(ACCEPT_DAY_COBOL)
        code = result["code"]
        assert "'00000'" in code, f"Expected '00000' placeholder in:\n{code}"

    def test_accept_from_day_yyyyddd(self):
        """ACCEPT WS-FULL-DAY FROM DAY YYYYDDD assigns '0000000' placeholder."""
        result = _analyze_and_generate(ACCEPT_DAY_YYYYDDD_COBOL)
        code = result["code"]
        assert "'0000000'" in code, f"Expected '0000000' placeholder in:\n{code}"

    def test_accept_compiler_warning(self):
        """compiler_warnings includes ACCEPT placeholder notice."""
        result = _analyze_and_generate(ACCEPT_DATE_COBOL)
        warnings = result.get("compiler_warnings", [])
        assert any("ACCEPT" in w for w in warnings), \
            f"Expected ACCEPT warning in: {warnings}"

    def test_accept_inside_if(self):
        """ACCEPT inside IF branch still produces placeholder."""
        result = _analyze_and_generate(ACCEPT_IN_IF_COBOL)
        code = result["code"]
        assert "'000000'" in code, f"Expected '000000' placeholder in:\n{code}"

    def test_accept_compiles_clean(self):
        """Generated Python from ACCEPT compiles without errors."""
        for src in [ACCEPT_DATE_COBOL, ACCEPT_DATE_YYYYMMDD_COBOL,
                     ACCEPT_TIME_COBOL, ACCEPT_DAY_COBOL,
                     ACCEPT_DAY_YYYYDDD_COBOL, ACCEPT_IN_IF_COBOL]:
            result = _analyze_and_generate(src)
            code = result["code"]
            compile(code, "<accept-test>", "exec")
