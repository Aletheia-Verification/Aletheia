"""Tests for cross-type MOVE: numeric↔string, figurative constants."""

import os
import threading
os.environ["USE_IN_MEMORY_DB"] = "1"

from decimal import Decimal
from cobol_analyzer_api import analyze_cobol
from generate_full_python import generate_python_module, to_python_name


def _run(source, inputs=None):
    """Parse → generate → execute → return namespace."""
    analysis = analyze_cobol(source)
    assert analysis["success"], f"Parse failed: {analysis.get('message')}"
    result = generate_python_module(analysis)
    code = result["code"]
    ns = {}
    exec(code, ns)
    if inputs:
        for cobol_name, value in inputs.items():
            py = to_python_name(cobol_name)
            existing = ns.get(py)
            if existing is not None and hasattr(existing, "store"):
                existing.store(Decimal(str(value)))
            else:
                ns[py] = value
    err = [None]
    def _go():
        try:
            ns["main"]()
        except Exception as e:
            err[0] = e
    t = threading.Thread(target=_go, daemon=True)
    t.start()
    t.join(timeout=5)
    assert not t.is_alive(), "Execution timed out"
    assert err[0] is None, f"Execution error: {err[0]}"
    return ns


class TestMoveSpacesToNumeric:
    def test_move_spaces_to_numeric(self):
        """MOVE SPACES TO PIC 9(5) should produce 0 (not crash)."""
        source = (
            "       IDENTIFICATION DIVISION.\n"
            "       PROGRAM-ID. XTYPE.\n"
            "       DATA DIVISION.\n"
            "       WORKING-STORAGE SECTION.\n"
            "       01  WS-NUM   PIC 9(5).\n"
            "       PROCEDURE DIVISION.\n"
            "       0000-MAIN.\n"
            "           MOVE 42 TO WS-NUM.\n"
            "           MOVE SPACES TO WS-NUM.\n"
            "           STOP RUN.\n"
        )
        ns = _run(source)
        assert ns["ws_num"].value == Decimal("0")


class TestMoveNumericToString:
    def test_move_numeric_var_to_string(self):
        """MOVE WS-NUM (PIC 9(5), value=123) TO PIC X(10) → '00123     '."""
        source = (
            "       IDENTIFICATION DIVISION.\n"
            "       PROGRAM-ID. XTYPE2.\n"
            "       DATA DIVISION.\n"
            "       WORKING-STORAGE SECTION.\n"
            "       01  WS-NUM   PIC 9(5).\n"
            "       01  WS-STR   PIC X(10).\n"
            "       PROCEDURE DIVISION.\n"
            "       0000-MAIN.\n"
            "           MOVE 123 TO WS-NUM.\n"
            "           MOVE WS-NUM TO WS-STR.\n"
            "           STOP RUN.\n"
        )
        ns = _run(source)
        assert ns["ws_str"] == "00123     "

    def test_move_numeric_literal_to_string(self):
        """MOVE 42 TO PIC X(5) → '42   ' (literal, no display format)."""
        source = (
            "       IDENTIFICATION DIVISION.\n"
            "       PROGRAM-ID. XTYPE3.\n"
            "       DATA DIVISION.\n"
            "       WORKING-STORAGE SECTION.\n"
            "       01  WS-STR   PIC X(5).\n"
            "       PROCEDURE DIVISION.\n"
            "       0000-MAIN.\n"
            "           MOVE 42 TO WS-STR.\n"
            "           STOP RUN.\n"
        )
        ns = _run(source)
        assert ns["ws_str"] == "42   "


class TestMoveZerosToString:
    def test_move_zeros_to_string(self):
        """MOVE ZEROS TO PIC X(5) → '0    '."""
        source = (
            "       IDENTIFICATION DIVISION.\n"
            "       PROGRAM-ID. XTYPE4.\n"
            "       DATA DIVISION.\n"
            "       WORKING-STORAGE SECTION.\n"
            "       01  WS-STR   PIC X(5).\n"
            "       PROCEDURE DIVISION.\n"
            "       0000-MAIN.\n"
            "           MOVE ZEROS TO WS-STR.\n"
            "           STOP RUN.\n"
        )
        ns = _run(source)
        assert ns["ws_str"] == "0    "
