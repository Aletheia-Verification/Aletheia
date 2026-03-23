"""
test_generator_wiring.py — Verify deferred generator flags appear in generated Python.

7 tests: one per wiring (BLANK WHEN ZERO, JUSTIFIED RIGHT, SIGN IS,
PIC P, COMP-1/COMP-2, ODO, Level 66 RENAMES).
"""

import os
os.environ["USE_IN_MEMORY_DB"] = "1"

import pytest
from cobol_analyzer_api import analyze_cobol
from generate_full_python import generate_python_module


def _gen(cobol_src):
    """Analyze + generate Python from COBOL source. Returns code string."""
    analysis = analyze_cobol(cobol_src)
    result = generate_python_module(analysis)
    return result["code"]


class TestBlankWhenZero:
    def test_blank_when_zero_in_generated_code(self):
        src = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEST-BWZ.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-AMOUNT PIC 9(5)V99 BLANK WHEN ZERO.
       PROCEDURE DIVISION.
       0000-MAIN.
           STOP RUN.
"""
        code = _gen(src)
        assert "blank_when_zero=True" in code


class TestJustifiedRight:
    def test_justified_right_move_uses_rjust(self):
        src = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEST-JUST.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-NAME PIC X(20) JUSTIFIED RIGHT.
       01 WS-SRC  PIC X(10).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE WS-SRC TO WS-NAME.
           STOP RUN.
"""
        code = _gen(src)
        assert "rjust" in code


class TestSignIs:
    def test_sign_leading_separate_in_generated_code(self):
        src = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEST-SIGN.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-AMT PIC S9(5)V99 SIGN IS LEADING SEPARATE.
       PROCEDURE DIVISION.
       0000-MAIN.
           STOP RUN.
"""
        code = _gen(src)
        assert "sign_position='leading'" in code
        assert "sign_separate=True" in code


class TestPicP:
    def test_pic_p_scaling_in_generated_code(self):
        src = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEST-PICP.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-SCALED PIC PP999.
       PROCEDURE DIVISION.
       0000-MAIN.
           STOP RUN.
"""
        code = _gen(src)
        assert "p_leading=" in code


class TestCompFloat:
    def test_comp1_emits_cobol_float(self):
        src = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEST-CF.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-SINGLE COMP-1.
       01 WS-DOUBLE COMP-2.
       PROCEDURE DIVISION.
       0000-MAIN.
           STOP RUN.
"""
        code = _gen(src)
        assert "CobolFloat" in code
        assert "precision='single'" in code
        assert "precision='double'" in code


class TestODO:
    def test_odo_comment_in_generated_code(self):
        src = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEST-ODO.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-COUNT PIC 9(2).
       01 WS-TABLE.
           05 WS-ITEM PIC X(10)
              OCCURS 1 TO 20 TIMES DEPENDING ON WS-COUNT.
       PROCEDURE DIVISION.
       0000-MAIN.
           STOP RUN.
"""
        code = _gen(src)
        assert "ODO" in code
        assert "WS-COUNT" in code


class TestRenames:
    def test_renames_alias_in_generated_code(self):
        src = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEST-REN.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-DATA.
           05 WS-FIELD-A PIC X(10).
           05 WS-FIELD-B PIC X(10).
       66 WS-ALIAS RENAMES WS-FIELD-A.
       PROCEDURE DIVISION.
       0000-MAIN.
           STOP RUN.
"""
        code = _gen(src)
        assert "ws_alias" in code
        assert "RENAMES" in code
