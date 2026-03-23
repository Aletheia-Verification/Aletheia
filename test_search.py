"""Tests for SEARCH and SEARCH ALL table lookup support."""
import os, sys, pytest
from decimal import Decimal

os.environ.setdefault("USE_IN_MEMORY_DB", "1")

from cobol_analyzer_api import analyze_cobol
from generate_full_python import generate_python_module


# ── Helper ────────────────────────────────────────────────────────────

def _gen(cobol_src: str) -> str:
    """Analyze COBOL and return generated Python code string."""
    analysis = analyze_cobol(cobol_src)
    result = generate_python_module(analysis)
    return result["code"]


# ── Test COBOL sources ────────────────────────────────────────────────

SEARCH_FOUND_CBL = (
    "       IDENTIFICATION DIVISION.\n"
    "       PROGRAM-ID. SEARCH-TEST.\n"
    "       DATA DIVISION.\n"
    "       WORKING-STORAGE SECTION.\n"
    "       01  WS-TABLE.\n"
    "           05  WS-ENTRY OCCURS 5 TIMES.\n"
    "               10  WS-KEY     PIC 9(3).\n"
    "               10  WS-VAL     PIC 9(5).\n"
    "       01  WS-IDX        PIC 9(3) VALUE 0.\n"
    "       01  WS-LOOKUP     PIC 9(3) VALUE 3.\n"
    "       01  WS-RESULT     PIC 9(5) VALUE 0.\n"
    "       PROCEDURE DIVISION.\n"
    "       MAIN-PARA.\n"
    "           MOVE 1 TO WS-KEY(1).\n"
    "           MOVE 100 TO WS-VAL(1).\n"
    "           MOVE 2 TO WS-KEY(2).\n"
    "           MOVE 200 TO WS-VAL(2).\n"
    "           MOVE 3 TO WS-KEY(3).\n"
    "           MOVE 300 TO WS-VAL(3).\n"
    "           MOVE 4 TO WS-KEY(4).\n"
    "           MOVE 400 TO WS-VAL(4).\n"
    "           MOVE 5 TO WS-KEY(5).\n"
    "           MOVE 500 TO WS-VAL(5).\n"
    "           PERFORM SEARCH-PARA.\n"
    "           STOP RUN.\n"
    "       SEARCH-PARA.\n"
    "           SEARCH WS-ENTRY VARYING WS-IDX\n"
    "               AT END MOVE 99999 TO WS-RESULT\n"
    "               WHEN WS-KEY(WS-IDX) = WS-LOOKUP\n"
    "                   MOVE WS-VAL(WS-IDX) TO WS-RESULT\n"
    "           END-SEARCH.\n"
)

SEARCH_NOT_FOUND_CBL = (
    "       IDENTIFICATION DIVISION.\n"
    "       PROGRAM-ID. SEARCH-NOTFOUND.\n"
    "       DATA DIVISION.\n"
    "       WORKING-STORAGE SECTION.\n"
    "       01  WS-TABLE.\n"
    "           05  WS-ENTRY OCCURS 3 TIMES.\n"
    "               10  WS-KEY     PIC 9(3).\n"
    "               10  WS-VAL     PIC 9(5).\n"
    "       01  WS-IDX        PIC 9(3) VALUE 0.\n"
    "       01  WS-LOOKUP     PIC 9(3) VALUE 9.\n"
    "       01  WS-RESULT     PIC 9(5) VALUE 0.\n"
    "       PROCEDURE DIVISION.\n"
    "       MAIN-PARA.\n"
    "           MOVE 1 TO WS-KEY(1).\n"
    "           MOVE 100 TO WS-VAL(1).\n"
    "           MOVE 2 TO WS-KEY(2).\n"
    "           MOVE 200 TO WS-VAL(2).\n"
    "           MOVE 3 TO WS-KEY(3).\n"
    "           MOVE 300 TO WS-VAL(3).\n"
    "           PERFORM SEARCH-PARA.\n"
    "           STOP RUN.\n"
    "       SEARCH-PARA.\n"
    "           SEARCH WS-ENTRY VARYING WS-IDX\n"
    "               AT END MOVE 99999 TO WS-RESULT\n"
    "               WHEN WS-KEY(WS-IDX) = WS-LOOKUP\n"
    "                   MOVE WS-VAL(WS-IDX) TO WS-RESULT\n"
    "           END-SEARCH.\n"
)

SEARCH_ALL_CBL = (
    "       IDENTIFICATION DIVISION.\n"
    "       PROGRAM-ID. SEARCH-ALL-TEST.\n"
    "       DATA DIVISION.\n"
    "       WORKING-STORAGE SECTION.\n"
    "       01  WS-TABLE.\n"
    "           05  WS-ENTRY OCCURS 4 TIMES.\n"
    "               10  WS-KEY     PIC 9(3).\n"
    "               10  WS-VAL     PIC X(10).\n"
    "       01  WS-IDX        PIC 9(3) VALUE 0.\n"
    "       01  WS-LOOKUP     PIC 9(3) VALUE 2.\n"
    "       01  WS-RESULT     PIC X(10) VALUE SPACES.\n"
    "       PROCEDURE DIVISION.\n"
    "       MAIN-PARA.\n"
    "           MOVE 1 TO WS-KEY(1).\n"
    "           MOVE 'ALPHA' TO WS-VAL(1).\n"
    "           MOVE 2 TO WS-KEY(2).\n"
    "           MOVE 'BETA' TO WS-VAL(2).\n"
    "           MOVE 3 TO WS-KEY(3).\n"
    "           MOVE 'GAMMA' TO WS-VAL(3).\n"
    "           MOVE 4 TO WS-KEY(4).\n"
    "           MOVE 'DELTA' TO WS-VAL(4).\n"
    "           PERFORM SEARCH-PARA.\n"
    "           STOP RUN.\n"
    "       SEARCH-PARA.\n"
    "           SEARCH ALL WS-ENTRY VARYING WS-IDX\n"
    "               AT END MOVE 'NONE' TO WS-RESULT\n"
    "               WHEN WS-KEY(WS-IDX) = WS-LOOKUP\n"
    "                   MOVE WS-VAL(WS-IDX) TO WS-RESULT\n"
    "           END-SEARCH.\n"
)

SIMPLE_NO_SEARCH_CBL = (
    "       IDENTIFICATION DIVISION.\n"
    "       PROGRAM-ID. NO-SEARCH.\n"
    "       DATA DIVISION.\n"
    "       WORKING-STORAGE SECTION.\n"
    "       01  WS-A PIC 9(5) VALUE 10.\n"
    "       01  WS-B PIC 9(5) VALUE 20.\n"
    "       PROCEDURE DIVISION.\n"
    "       MAIN-PARA.\n"
    "           ADD WS-A TO WS-B.\n"
    "           STOP RUN.\n"
)


# ── Tests ─────────────────────────────────────────────────────────────

class TestSearch:
    """SEARCH and SEARCH ALL table lookup tests."""

    def test_search_found(self):
        """SEARCH with WHEN match -> analyzer detects, generator emits loop."""
        analysis = analyze_cobol(SEARCH_FOUND_CBL)
        assert analysis["success"]
        assert len(analysis["search_statements"]) == 1
        ss = analysis["search_statements"][0]
        assert ss["table_name"].upper() == "WS-ENTRY"
        assert ss["varying"].upper() == "WS-IDX"
        assert ss["is_all"] is False
        assert len(ss["whens"]) == 1

        code = _gen(SEARCH_FOUND_CBL)
        assert "_search_found" in code
        assert "for _si in range" in code
        # Should compile cleanly
        compile(code, "<search_found>", "exec")

    def test_search_not_found(self):
        """SEARCH with no match -> AT END branch emitted."""
        analysis = analyze_cobol(SEARCH_NOT_FOUND_CBL)
        assert analysis["success"]
        assert len(analysis["search_statements"]) == 1
        ss = analysis["search_statements"][0]
        assert ss["at_end"] is not None

        code = _gen(SEARCH_NOT_FOUND_CBL)
        assert "_search_found" in code
        assert "if not _search_found" in code
        compile(code, "<search_not_found>", "exec")

    def test_search_all_found(self):
        """SEARCH ALL emits same linear scan with SEARCH ALL comment."""
        analysis = analyze_cobol(SEARCH_ALL_CBL)
        assert analysis["success"]
        assert len(analysis["search_statements"]) == 1
        ss = analysis["search_statements"][0]
        assert ss["is_all"] is True

        code = _gen(SEARCH_ALL_CBL)
        assert "SEARCH ALL" in code
        assert "_search_found" in code
        compile(code, "<search_all>", "exec")

    def test_search_regression(self):
        """Program without SEARCH -> no search code emitted."""
        analysis = analyze_cobol(SIMPLE_NO_SEARCH_CBL)
        assert analysis["success"]
        assert len(analysis.get("search_statements", [])) == 0

        code = _gen(SIMPLE_NO_SEARCH_CBL)
        assert "_search_found" not in code
