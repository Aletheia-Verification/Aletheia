"""Tests for MERGE, nested programs, GLOBAL/EXTERNAL, DECLARATIVES detection."""

import pytest
from cobol_analyzer_api import analyze_cobol


# ═══════════════════════════════════════════════════════════════
# Helper — minimal COBOL wrapper
# ═══════════════════════════════════════════════════════════════

def _wrap(procedure_lines, data_lines="", ws_lines="", extra_divisions=""):
    """Build a minimal COBOL program around procedure/data lines."""
    ws = ""
    if ws_lines:
        ws = f"""       WORKING-STORAGE SECTION.
{ws_lines}"""
    data = ""
    if ws or data_lines:
        data = f"""       DATA DIVISION.
{data_lines}
{ws}"""
    return f"""       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEST-PROG.
{extra_divisions}
{data}
       PROCEDURE DIVISION.
       MAIN-PARA.
{procedure_lines}
           STOP RUN.
"""


# ═══════════════════════════════════════════════════════════════
# 1. MERGE detection
# ═══════════════════════════════════════════════════════════════


class TestMergeDetection:

    def test_merge_detected(self):
        cobol = """       IDENTIFICATION DIVISION.
       PROGRAM-ID. MERGE-TEST.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT MERGE-FILE ASSIGN TO 'MERGE.DAT'.
           SELECT IN-FILE-1 ASSIGN TO 'IN1.DAT'.
           SELECT IN-FILE-2 ASSIGN TO 'IN2.DAT'.
           SELECT OUT-FILE ASSIGN TO 'OUT.DAT'.
       DATA DIVISION.
       FILE SECTION.
       SD MERGE-FILE.
       01 MERGE-REC.
          05 MERGE-KEY PIC 9(5).
       FD IN-FILE-1.
       01 IN-REC-1.
          05 IN-KEY-1 PIC 9(5).
       FD IN-FILE-2.
       01 IN-REC-2.
          05 IN-KEY-2 PIC 9(5).
       FD OUT-FILE.
       01 OUT-REC.
          05 OUT-KEY PIC 9(5).
       PROCEDURE DIVISION.
       MAIN-PARA.
           MERGE MERGE-FILE
               ON ASCENDING KEY MERGE-KEY
               USING IN-FILE-1 IN-FILE-2
               GIVING OUT-FILE.
           STOP RUN.
"""
        result = analyze_cobol(cobol)
        assert len(result["merge_statements"]) >= 1
        merge = result["merge_statements"][0]
        assert merge["merge_file"] is not None
        assert merge["paragraph"] == "MAIN-PARA"

    def test_no_merge_empty(self):
        cobol = _wrap("           DISPLAY 'HELLO'.")
        result = analyze_cobol(cobol)
        assert result["merge_statements"] == []


# ═══════════════════════════════════════════════════════════════
# 2. Nested program detection
# ═══════════════════════════════════════════════════════════════


class TestNestedProgramDetection:

    def test_nested_program_detected(self):
        cobol = """       IDENTIFICATION DIVISION.
       PROGRAM-ID. OUTER-PROG.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-RESULT PIC 9(5).
       PROCEDURE DIVISION.
       MAIN-PARA.
           DISPLAY 'OUTER'.
           STOP RUN.
       IDENTIFICATION DIVISION.
       PROGRAM-ID. INNER-PROG.
       PROCEDURE DIVISION.
       INNER-PARA.
           DISPLAY 'INNER'.
       END PROGRAM INNER-PROG.
       END PROGRAM OUTER-PROG.
"""
        result = analyze_cobol(cobol)
        assert result["has_nested_programs"] is True
        assert len(result["program_ids"]) >= 2
        names = [p["name"] for p in result["program_ids"]]
        assert "OUTER-PROG" in names or "outer-prog" in [n.lower() for n in names]

    def test_single_program_not_nested(self):
        cobol = _wrap("           DISPLAY 'SINGLE'.")
        result = analyze_cobol(cobol)
        assert result["has_nested_programs"] is False
        assert len(result["program_ids"]) == 1


# ═══════════════════════════════════════════════════════════════
# 3. GLOBAL / EXTERNAL variable detection
# ═══════════════════════════════════════════════════════════════


class TestGlobalExternalDetection:

    def test_global_variable_detected(self):
        cobol = _wrap(
            "           DISPLAY WS-SHARED.",
            ws_lines="       01 WS-SHARED PIC X(10) GLOBAL."
        )
        result = analyze_cobol(cobol)
        shared = [v for v in result["variables"] if v.get("name") == "WS-SHARED"]
        assert len(shared) == 1
        assert shared[0]["global_var"] is True
        assert shared[0]["external_var"] is False

    def test_external_variable_detected(self):
        cobol = _wrap(
            "           DISPLAY WS-EXT.",
            ws_lines="       01 WS-EXT PIC X(10) EXTERNAL."
        )
        result = analyze_cobol(cobol)
        ext = [v for v in result["variables"] if v.get("name") == "WS-EXT"]
        assert len(ext) == 1
        assert ext[0]["external_var"] is True
        assert ext[0]["global_var"] is False

    def test_normal_variable_not_flagged(self):
        cobol = _wrap(
            "           DISPLAY WS-AMOUNT.",
            ws_lines="       05 WS-AMOUNT PIC 9(5)V99."
        )
        result = analyze_cobol(cobol)
        amt = [v for v in result["variables"] if v.get("name") == "WS-AMOUNT"]
        assert len(amt) == 1
        assert amt[0]["global_var"] is False
        assert amt[0]["external_var"] is False


# ═══════════════════════════════════════════════════════════════
# 4. DECLARATIVES detection
# ═══════════════════════════════════════════════════════════════


class TestDeclarativesDetection:

    def test_declaratives_detected(self):
        cobol = """       IDENTIFICATION DIVISION.
       PROGRAM-ID. DECL-TEST.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT IN-FILE ASSIGN TO 'INPUT.DAT'
               FILE STATUS IS WS-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD IN-FILE.
       01 IN-REC PIC X(80).
       WORKING-STORAGE SECTION.
       01 WS-STATUS PIC XX.
       PROCEDURE DIVISION.
       DECLARATIVES.
       ERROR-SECTION SECTION.
           USE AFTER STANDARD ERROR PROCEDURE ON IN-FILE.
       ERROR-PARA.
           DISPLAY 'FILE ERROR: ' WS-STATUS.
       END DECLARATIVES.
       MAIN-SECTION SECTION.
       MAIN-PARA.
           OPEN INPUT IN-FILE.
           STOP RUN.
"""
        result = analyze_cobol(cobol)
        assert result["has_declaratives"] is True

    def test_no_declaratives(self):
        cobol = _wrap("           DISPLAY 'NO DECL'.")
        result = analyze_cobol(cobol)
        assert result["has_declaratives"] is False
