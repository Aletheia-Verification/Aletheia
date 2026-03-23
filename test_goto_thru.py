"""
test_goto_thru.py — GO TO inside PERFORM THRU range tests.

3 tests:
  - GO TO EXIT skips intermediate paragraphs
  - GO TO outside THRU range still calls target
  - Normal THRU without GO TO still works
"""

import os
os.environ["USE_IN_MEMORY_DB"] = "1"

import pytest
from decimal import Decimal
from cobol_analyzer_api import analyze_cobol
from generate_full_python import generate_python_module


def _run(cobol_src):
    """Analyze, generate, exec, return namespace."""
    analysis = analyze_cobol(cobol_src)
    result = generate_python_module(analysis)
    code = result["code"]
    compile(code, "<test>", "exec")
    ns = {}
    exec(code, ns)
    ns["main"]()
    return ns


class TestGotoInsideThru:

    def test_goto_skips_intermediate_paragraph(self):
        """GO TO EXIT inside THRU range skips intermediate paragraphs."""
        src = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEST-GOTO-THRU.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-FLAG    PIC 9(1).
       01 WS-COUNT   PIC 9(3).
       01 WS-RESULT  PIC 9(3).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 1 TO WS-FLAG.
           PERFORM 1000-START THRU 1000-EXIT.
           STOP RUN.
       1000-START.
           IF WS-FLAG = 1
               GO TO 1000-EXIT.
           ADD 1 TO WS-COUNT.
       1000-PROCESS.
           MOVE 99 TO WS-RESULT.
       1000-EXIT.
           EXIT.
"""
        ns = _run(src)
        # GO TO 1000-EXIT should skip ADD and 1000-PROCESS entirely
        assert ns["ws_count"].value == Decimal("0")
        assert ns["ws_result"].value == Decimal("0")

    def test_goto_outside_thru_calls_target(self):
        """GO TO to paragraph outside THRU range still calls target."""
        src = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEST-GOTO-OUT.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-FLAG    PIC 9(1).
       01 WS-MARKER  PIC 9(3).
       01 WS-SKIP    PIC 9(3).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 1 TO WS-FLAG.
           PERFORM 2000-START THRU 2000-EXIT.
           STOP RUN.
       2000-START.
           IF WS-FLAG = 1
               GO TO 9000-ERROR-HANDLER.
           ADD 1 TO WS-SKIP.
       2000-EXIT.
           EXIT.
       9000-ERROR-HANDLER.
           MOVE 42 TO WS-MARKER.
"""
        ns = _run(src)
        # GO TO 9000-ERROR-HANDLER is outside the THRU range
        # It should call 9000-ERROR-HANDLER (MOVE 42) and skip rest of THRU
        assert ns["ws_marker"].value == Decimal("42")
        assert ns["ws_skip"].value == Decimal("0")

    def test_perform_thru_no_goto_regression(self):
        """Normal PERFORM THRU without GO TO still works correctly."""
        src = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEST-THRU-REG.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-A  PIC 9(3) VALUE 0.
       01 WS-B  PIC 9(3) VALUE 0.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 3000-FIRST THRU 3000-LAST.
           STOP RUN.
       3000-FIRST.
           ADD 10 TO WS-A.
       3000-MIDDLE.
           ADD 20 TO WS-A.
       3000-LAST.
           MOVE WS-A TO WS-B.
"""
        ns = _run(src)
        # All three paragraphs should execute in order
        assert ns["ws_a"].value == Decimal("30")
        assert ns["ws_b"].value == Decimal("30")
