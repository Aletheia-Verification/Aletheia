"""
test_integration.py — End-to-end pipeline integration tests.

7 tests covering the full path:
  Raw COBOL source → ANTLR parse → analyze → generate Python → execute → verify output

Each test is self-contained with embedded COBOL source, no external files.

Run with:
    pytest test_integration.py -v
"""

import threading
from decimal import Decimal

import pytest

from cobol_analyzer_api import analyze_cobol
from generate_full_python import generate_python_module, to_python_name


# ── Helpers ──────────────────────────────────────────────────────


def _run_cobol(source, inputs=None):
    """Parse → generate → execute → return namespace."""
    analysis = analyze_cobol(source)
    assert analysis["success"], f"Parse failed: {analysis.get('message')}"
    result = generate_python_module(analysis)
    code = result["code"]
    namespace = {}
    exec(code, namespace)
    if inputs:
        for cobol_name, value in inputs.items():
            py_name = to_python_name(cobol_name)
            existing = namespace.get(py_name)
            if existing is not None and hasattr(existing, "store"):
                existing.store(Decimal(str(value)))
            else:
                namespace[py_name] = value
    err = [None]
    def _go():
        try:
            namespace["main"]()
        except Exception as e:
            err[0] = e
    t = threading.Thread(target=_go, daemon=True)
    t.start()
    t.join(timeout=5)
    assert not t.is_alive(), "Execution timed out"
    assert err[0] is None, f"Execution error: {err[0]}"
    return namespace


def _get(namespace, cobol_name):
    """Extract output value from namespace."""
    val = namespace.get(to_python_name(cobol_name))
    if hasattr(val, "value"):
        return val.value
    return val


# ══════════════════════════════════════════════════════════════════
# E2E Tests
# ══════════════════════════════════════════════════════════════════


class TestE2ESimpleCompute:
    """COMPUTE with ROUNDED through full pipeline."""

    SOURCE = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TCOMPUTE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-PRINCIPAL    PIC 9(7)V99.
       01 WS-RATE          PIC 9(3)V99.
       01 WS-INTEREST      PIC 9(7)V99.
       PROCEDURE DIVISION.
       0000-MAIN.
           COMPUTE WS-INTEREST ROUNDED =
               WS-PRINCIPAL * WS-RATE / 100.
           STOP RUN.
"""

    def test_e2e_simple_compute(self):
        """10000 * 5.75 / 100 = 575.00."""
        ns = _run_cobol(self.SOURCE, {
            "WS-PRINCIPAL": 10000,
            "WS-RATE": "5.75",
        })
        assert _get(ns, "WS-INTEREST") == Decimal("575.00")


class TestE2EIfElseBranch:
    """IF/ELSE with compound AND condition."""

    SOURCE = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TIFELSE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-AMOUNT       PIC 9(7)V99.
       01 WS-STATUS        PIC X(1).
       01 WS-RESULT        PIC 9(1).
       PROCEDURE DIVISION.
       0000-MAIN.
           IF WS-AMOUNT > 1000 AND WS-STATUS = 'A'
               MOVE 1 TO WS-RESULT
           ELSE
               MOVE 2 TO WS-RESULT
           END-IF.
           STOP RUN.
"""

    def test_true_branch(self):
        """Amount > 1000 AND status = 'A' → result = 1."""
        ns = _run_cobol(self.SOURCE, {
            "WS-AMOUNT": 1500,
            "WS-STATUS": "A",
        })
        assert _get(ns, "WS-RESULT") == Decimal("1")

    def test_false_branch(self):
        """Amount <= 1000 → result = 2 (else branch)."""
        ns = _run_cobol(self.SOURCE, {
            "WS-AMOUNT": 500,
            "WS-STATUS": "A",
        })
        assert _get(ns, "WS-RESULT") == Decimal("2")


class TestE2EPerformVarying:
    """PERFORM VARYING loop accumulating a total."""

    SOURCE = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TVARY.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-I             PIC 9(3).
       01 WS-TOTAL         PIC 9(5).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 0 TO WS-TOTAL.
           PERFORM 1000-ACCUM
               VARYING WS-I FROM 1 BY 1
               UNTIL WS-I > 5.
           STOP RUN.
       1000-ACCUM.
           ADD WS-I TO WS-TOTAL.
"""

    def test_e2e_perform_varying(self):
        """1+2+3+4+5 = 15."""
        ns = _run_cobol(self.SOURCE)
        assert _get(ns, "WS-TOTAL") == Decimal("15")


class TestE2EEvaluateWhen:
    """EVALUATE TRUE with range-based WHEN branches."""

    SOURCE = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEVAL.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-SCORE         PIC 9(3).
       01 WS-RESULT        PIC 9(1).
       PROCEDURE DIVISION.
       0000-MAIN.
           EVALUATE TRUE
               WHEN WS-SCORE >= 90
                   MOVE 1 TO WS-RESULT
               WHEN WS-SCORE >= 70
                   MOVE 2 TO WS-RESULT
               WHEN OTHER
                   MOVE 3 TO WS-RESULT
           END-EVALUATE.
           STOP RUN.
"""

    def test_e2e_evaluate_good(self):
        """Score 85 → second branch (>= 70), result = 2."""
        ns = _run_cobol(self.SOURCE, {"WS-SCORE": 85})
        assert _get(ns, "WS-RESULT") == Decimal("2")

    def test_e2e_evaluate_excellent(self):
        """Score 95 → first branch (>= 90), result = 1."""
        ns = _run_cobol(self.SOURCE, {"WS-SCORE": 95})
        assert _get(ns, "WS-RESULT") == Decimal("1")

    def test_e2e_evaluate_other(self):
        """Score 50 → OTHER branch, result = 3."""
        ns = _run_cobol(self.SOURCE, {"WS-SCORE": 50})
        assert _get(ns, "WS-RESULT") == Decimal("3")


class TestE2EStringDelimited:
    """STRING DELIMITED BY SIZE concatenation."""

    SOURCE = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TSTRING.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-FIRST         PIC X(10).
       01 WS-LAST          PIC X(10).
       01 WS-FULL          PIC X(25).
       PROCEDURE DIVISION.
       0000-MAIN.
           STRING WS-FIRST DELIMITED BY SIZE
                  ' ' DELIMITED BY SIZE
                  WS-LAST DELIMITED BY SIZE
                  INTO WS-FULL.
           STOP RUN.
"""

    def test_e2e_string_delimited(self):
        """STRING concatenates first + space + last."""
        ns = _run_cobol(self.SOURCE, {
            "WS-FIRST": "JOHN",
            "WS-LAST": "DOE",
        })
        result = _get(ns, "WS-FULL")
        assert "JOHN" in result
        assert "DOE" in result


class TestE2EInspectReplacingAll:
    """INSPECT REPLACING ALL character substitution."""

    SOURCE = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TINSPECT.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-TEXT           PIC X(20).
       PROCEDURE DIVISION.
       0000-MAIN.
           INSPECT WS-TEXT REPLACING ALL '-' BY '/'.
           STOP RUN.
"""

    def test_e2e_inspect_replacing_all(self):
        """INSPECT REPLACING ALL '-' BY '/' in date string."""
        ns = _run_cobol(self.SOURCE, {"WS-TEXT": "2026-03-15"})
        result = _get(ns, "WS-TEXT")
        assert result.startswith("2026/03/15")


class TestE2EComp3Overflow:
    """COMP-3 packed decimal with TRUNC(STD) overflow."""

    SOURCE = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TCOMP3.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-COUNTER       PIC S9(3) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN.
           ADD 10 TO WS-COUNTER.
           STOP RUN.
"""

    def test_e2e_comp3_overflow(self):
        """995 + 10 = 1005 → mod 1000 = 5 under TRUNC(STD)."""
        ns = _run_cobol(self.SOURCE, {"WS-COUNTER": 995})
        assert _get(ns, "WS-COUNTER") == Decimal("5")


# ══════════════════════════════════════════════════════════════════
# Reference Modification — substring access
# ══════════════════════════════════════════════════════════════════


class TestE2ERefMod:
    """Reference modification — WS-FIELD(start:length) substring access."""

    SOURCE_READ = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TREFMOD.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-RECORD        PIC X(10).
       01 WS-PART           PIC X(3).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE WS-RECORD(5:3) TO WS-PART.
           STOP RUN.
"""

    def test_refmod_read(self):
        """WS-RECORD(5:3) extracts 3 chars from position 5."""
        ns = _run_cobol(self.SOURCE_READ, {"WS-RECORD": "ABCDEFGHIJ"})
        assert _get(ns, "WS-PART").startswith("EFG")

    SOURCE_WRITE = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TREFMOD2.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-FIELD          PIC X(10).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 'XYZ' TO WS-FIELD(1:3).
           STOP RUN.
"""

    def test_refmod_write(self):
        """MOVE 'XYZ' TO WS-FIELD(1:3) writes to first 3 positions."""
        ns = _run_cobol(self.SOURCE_WRITE, {"WS-FIELD": "ABCDEFGHIJ"})
        result = _get(ns, "WS-FIELD")
        assert result.startswith("XYZ")
        assert result[3:].startswith("DEFG")

    SOURCE_CONDITION = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TREFMOD3.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CODE           PIC X(5).
       01 WS-RESULT         PIC 9(1).
       PROCEDURE DIVISION.
       0000-MAIN.
           IF WS-CODE(1:2) = 'AB'
               MOVE 1 TO WS-RESULT
           ELSE
               MOVE 2 TO WS-RESULT
           END-IF.
           STOP RUN.
"""

    def test_refmod_in_condition(self):
        """IF WS-CODE(1:2) = 'AB' matches first 2 chars."""
        ns = _run_cobol(self.SOURCE_CONDITION, {"WS-CODE": "ABCDE"})
        assert _get(ns, "WS-RESULT") == Decimal("1")

    SOURCE_VAR_POS = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TREFMOD4.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-REC            PIC X(10).
       01 WS-POS            PIC 9(2).
       01 WS-OUT            PIC X(3).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE WS-REC(WS-POS:3) TO WS-OUT.
           STOP RUN.
"""

    def test_refmod_variable_position(self):
        """WS-REC(WS-POS:3) with variable start position."""
        ns = _run_cobol(self.SOURCE_VAR_POS, {
            "WS-REC": "ABCDEFGHIJ",
            "WS-POS": 4,
        })
        assert _get(ns, "WS-OUT").startswith("DEF")

    def test_no_refmod_regression(self):
        """Plain variable access still works (regression guard)."""
        source = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TPLAIN.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-A              PIC X(5).
       01 WS-B              PIC X(5).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE WS-A TO WS-B.
           STOP RUN.
"""
        ns = _run_cobol(source, {"WS-A": "HELLO"})
        assert _get(ns, "WS-B").startswith("HELLO")


# ══════════════════════════════════════════════════════════════════
# PERFORM VARYING AFTER — nested loops
# ══════════════════════════════════════════════════════════════════


class TestE2EPerformVaryingAfter:
    """PERFORM VARYING ... AFTER ... nested loop."""

    SOURCE = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TAFTER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-I             PIC 9(3).
       01 WS-J             PIC 9(3).
       01 WS-TOTAL         PIC 9(5).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 0 TO WS-TOTAL.
           PERFORM 1000-COUNT
               VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 3
               AFTER WS-J FROM 1 BY 1 UNTIL WS-J > 2.
           STOP RUN.
       1000-COUNT.
           ADD 1 TO WS-TOTAL.
"""

    def test_e2e_perform_varying_after(self):
        """3 outer × 2 inner = 6 iterations."""
        ns = _run_cobol(self.SOURCE)
        assert _get(ns, "WS-TOTAL") == Decimal("6")

    def test_e2e_varying_after_values(self):
        """Post-loop: WS-I = 4 (first > 3), WS-J = 3 (first > 2)."""
        ns = _run_cobol(self.SOURCE)
        assert _get(ns, "WS-I") == Decimal("4")
        assert _get(ns, "WS-J") == Decimal("3")


class TestE2ESingleVaryingRegression:
    """Plain PERFORM VARYING (no AFTER) still works after nested loop changes."""

    SOURCE = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TREGRESS.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-I             PIC 9(3).
       01 WS-TOTAL         PIC 9(5).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 0 TO WS-TOTAL.
           PERFORM 1000-ACCUM
               VARYING WS-I FROM 1 BY 1
               UNTIL WS-I > 5.
           STOP RUN.
       1000-ACCUM.
           ADD WS-I TO WS-TOTAL.
"""

    def test_e2e_single_varying_regression(self):
        """1+2+3+4+5 = 15 — same as existing test, regression guard."""
        ns = _run_cobol(self.SOURCE)
        assert _get(ns, "WS-TOTAL") == Decimal("15")


# ══════════════════════════════════════════════════════════════════
# MOVE CORRESPONDING — field name matching
# ══════════════════════════════════════════════════════════════════


class TestE2EMoveCorresponding:
    """MOVE CORRESPONDING with overlapping group fields."""

    SOURCE = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TCORR.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-SRC.
          05 CUST-ID      PIC 9(5).
          05 CUST-NAME    PIC X(10).
          05 SRC-ONLY     PIC 9(3).
       01 WS-TGT.
          05 CUST-ID      PIC 9(5).
          05 CUST-NAME    PIC X(10).
          05 TGT-ONLY     PIC 9(3).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 12345 TO CUST-ID.
           MOVE 'SMITH' TO CUST-NAME.
           MOVE 100 TO SRC-ONLY.
           MOVE 200 TO TGT-ONLY.
           MOVE CORRESPONDING WS-SRC TO WS-TGT.
           STOP RUN.
"""

    def test_e2e_move_corresponding(self):
        """Matching fields retain values, non-matching untouched."""
        ns = _run_cobol(self.SOURCE)
        assert _get(ns, "CUST-ID") == Decimal("12345")
        assert _get(ns, "CUST-NAME").startswith("SMITH")
        assert _get(ns, "SRC-ONLY") == Decimal("100")
        assert _get(ns, "TGT-ONLY") == Decimal("200")


class TestE2EMoveCorrespondingNoOverlap:
    """MOVE CORRESPONDING with zero matching field names."""

    SOURCE = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TNOCORR.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-A.
          05 FIELD-X      PIC 9(3).
       01 WS-B.
          05 FIELD-Y      PIC 9(3).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 111 TO FIELD-X.
           MOVE 222 TO FIELD-Y.
           MOVE CORRESPONDING WS-A TO WS-B.
           STOP RUN.
"""

    def test_e2e_move_corr_no_overlap(self):
        """No matching fields — values unchanged, no crash."""
        ns = _run_cobol(self.SOURCE)
        assert _get(ns, "FIELD-X") == Decimal("111")
        assert _get(ns, "FIELD-Y") == Decimal("222")


class TestE2EMoveCorrespondingRegression:
    """Plain MOVE still works after CORRESPONDING changes."""

    SOURCE = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TPLAIN.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-VAL1        PIC 9(5).
       01 WS-VAL2        PIC 9(5).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 42 TO WS-VAL1.
           MOVE WS-VAL1 TO WS-VAL2.
           STOP RUN.
"""

    def test_move_corresponding_regression(self):
        """Plain MOVE A TO B still works."""
        ns = _run_cobol(self.SOURCE)
        assert _get(ns, "WS-VAL2") == Decimal("42")
