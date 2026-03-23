"""
test_scoped_namespace.py — Tests for qualified variable name disambiguation.

When two COBOL groups contain fields with the same name (e.g., TOTAL-AMOUNT
in both DEBIT-HEADER and CREDIT-FOOTER), the generator must produce distinct
Python variable names and resolve "OF" qualifiers correctly.
"""

import pytest
from cobol_analyzer_api import analyze_cobol
from generate_full_python import generate_python_module


def _generate(source):
    analysis = analyze_cobol(source)
    assert analysis["success"], f"Parse failed: {analysis.get('parse_warning')}"
    return generate_python_module(analysis)["code"]


class TestUniqueNameNoQualifier:
    """Unique field names → plain Python names, no __ qualifier."""

    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. UNIQ.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-REC.\n"
        "           05  WS-AMOUNT  PIC S9(5)V99.\n"
        "           05  WS-NAME   PIC X(20).\n"
        "       01  WS-RESULT     PIC S9(5)V99.\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           MOVE 100 TO WS-AMOUNT.\n"
        "           STOP RUN.\n"
    )

    def test_no_double_underscore(self):
        code = _generate(self.SOURCE)
        assert "__" not in code.split("# ")[0]  # Before validation report

    def test_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")


class TestDuplicateNameQualified:
    """Two groups with same field name → qualified Python names."""

    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. DUPL.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  GROUP-A.\n"
        "           05  TOTAL-AMT   PIC S9(5)V99.\n"
        "           05  STATUS-CD   PIC X(2).\n"
        "       01  GROUP-B.\n"
        "           05  TOTAL-AMT   PIC S9(5)V99.\n"
        "           05  OTHER-FLD   PIC 9(3).\n"
        "       01  WS-RESULT      PIC S9(5)V99.\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           MOVE 100 TO TOTAL-AMT.\n"
        "           STOP RUN.\n"
    )

    def test_qualified_names_in_code(self):
        code = _generate(self.SOURCE)
        # Both qualified versions should be declared
        assert "group_a__total_amt" in code
        assert "group_b__total_amt" in code

    def test_unqualified_alias_exists(self):
        code = _generate(self.SOURCE)
        # Unqualified alias for backward compat
        assert "total_amt = " in code  # alias line

    def test_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")

    def test_executes(self):
        code = _generate(self.SOURCE)
        namespace = {}
        exec(code, namespace)
        namespace["main"]()
        # The unqualified MOVE goes to the alias (last group's version)
        from decimal import Decimal
        assert namespace["total_amt"].value == Decimal("100")


class TestOfResolution:
    """TOTAL-AMT OF GROUP-A → resolves to group_a__total_amt."""

    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. OFRES.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  GROUP-A.\n"
        "           05  TOTAL-AMT   PIC S9(5)V99.\n"
        "       01  GROUP-B.\n"
        "           05  TOTAL-AMT   PIC S9(5)V99.\n"
        "       01  WS-RESULT      PIC S9(5)V99.\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           COMPUTE WS-RESULT =\n"
        "               TOTAL-AMT OF GROUP-A + 10.\n"
        "           STOP RUN.\n"
    )

    def test_of_resolves_in_compute(self):
        code = _generate(self.SOURCE)
        assert "group_a__total_amt" in code

    def test_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")


class TestAmbiguousUnqualifiedStillWorks:
    """Ambiguous TOTAL-AMT without OF → uses alias (last definition). Not MANUAL REVIEW."""

    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. AMBIG.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  GROUP-A.\n"
        "           05  TOTAL-AMT   PIC S9(5)V99.\n"
        "       01  GROUP-B.\n"
        "           05  TOTAL-AMT   PIC S9(5)V99.\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           MOVE 500 TO TOTAL-AMT.\n"
        "           STOP RUN.\n"
    )

    def test_compiles_and_executes(self):
        """Ambiguous reference compiles via alias — no crash."""
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")
        namespace = {}
        exec(code, namespace)
        namespace["main"]()
