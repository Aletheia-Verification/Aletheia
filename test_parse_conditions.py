"""
test_parse_conditions.py — Tests for AND/OR compound conditions and EVALUATE WHEN THRU.
Phase 1 of post-audit critical fixes.
"""

import unittest
from parse_conditions import (
    _convert_condition, parse_evaluate_statement, _convert_single_statement,
    _split_inline_perform_body, _resolve_subscripted_name,
)


# ── Shared fixtures ──────────────────────────────────────────────

KNOWN_VARS = {
    "WS-A", "WS-B", "WS-C", "WS-NAME", "WS-FLAG", "WS-CITY",
    "WS-RATE", "WS-CODE", "WS-X", "WS-Y", "WS-STATUS",
}

LEVEL_88 = {
    "VALID-STATUS": {
        "parent": "WS-STATUS",
        "value": "1",
        "values": ["1"],
    },
}

STRING_VARS = {"WS-NAME", "WS-FLAG", "WS-CITY"}


# ── AND/OR compound condition tests ─────────────────────────────

class TestCompoundConditions(unittest.TestCase):

    def test_compound_and(self):
        """IF WS-A > 10 AND WS-B < 5 → Python has 'and'."""
        # ANTLR getText() strips spaces: "WS-A>10ANDWS-B<5"
        cond = "WS-A>10ANDWS-B<5"
        result, issues = _convert_condition(cond, KNOWN_VARS, LEVEL_88)
        self.assertIn(" and ", result)
        self.assertIn("ws_a", result)
        self.assertIn("ws_b", result)
        self.assertEqual(len(issues), 0)

    def test_compound_or(self):
        """IF WS-A = 1 OR WS-A = 2 → Python has 'or'."""
        cond = "WS-A=1ORWS-A=2"
        result, issues = _convert_condition(cond, KNOWN_VARS, LEVEL_88)
        self.assertIn(" or ", result)
        self.assertEqual(len(issues), 0)

    def test_compound_not(self):
        """IF NOT WS-A > 10 → Python has 'not'."""
        cond = "NOTWS-A>10"
        result, issues = _convert_condition(cond, KNOWN_VARS, LEVEL_88)
        self.assertIn("not", result)
        self.assertEqual(len(issues), 0)

    def test_compound_mixed_precedence(self):
        """IF WS-A > 10 AND WS-B < 5 OR WS-C = 0 → AND binds tighter."""
        cond = "WS-A>10ANDWS-B<5ORWS-C=0"
        result, issues = _convert_condition(cond, KNOWN_VARS, LEVEL_88)
        self.assertIn(" and ", result)
        self.assertIn(" or ", result)
        # AND group should be parenthesized
        self.assertIn("(", result)
        self.assertEqual(len(issues), 0)

    def test_compound_parenthesized(self):
        """IF (WS-A > 10 OR WS-B < 5) AND WS-C = 0 → parens respected."""
        # ANTLR may or may not preserve parens — this tests the case
        # where condition arrives without explicit parens (flat)
        cond = "WS-A>10ORWS-B<5ANDWS-C=0"
        result, issues = _convert_condition(cond, KNOWN_VARS, LEVEL_88)
        # Should have both and/or
        self.assertIn(" and ", result)
        self.assertIn(" or ", result)
        self.assertEqual(len(issues), 0)

    def test_simple_condition_regression(self):
        """IF WS-A > 10 → unchanged behavior (regression guard)."""
        cond = "WS-A>10"
        result, issues = _convert_condition(cond, KNOWN_VARS, LEVEL_88)
        self.assertIn("ws_a", result)
        self.assertIn(">", result)
        self.assertNotIn(" and ", result)
        self.assertNotIn(" or ", result)
        self.assertEqual(len(issues), 0)

    def test_compound_with_string_containing_and(self):
        """IF WS-NAME = 'ANDERSON' AND WS-FLAG = 'Y' → 'ANDERSON' intact."""
        cond = "WS-NAME='ANDERSON'ANDWS-FLAG='Y'"
        result, issues = _convert_condition(cond, KNOWN_VARS, LEVEL_88, string_vars=STRING_VARS)
        self.assertIn(" and ", result)
        self.assertIn("ANDERSON", result)
        self.assertEqual(len(issues), 0)

    def test_compound_with_string_containing_or(self):
        """IF WS-CITY = 'ORLANDO' OR WS-CITY = 'PORTLAND' → strings intact."""
        cond = "WS-CITY='ORLANDO'ORWS-CITY='PORTLAND'"
        result, issues = _convert_condition(cond, KNOWN_VARS, LEVEL_88, string_vars=STRING_VARS)
        self.assertIn(" or ", result)
        self.assertIn("ORLANDO", result)
        self.assertIn("PORTLAND", result)
        self.assertEqual(len(issues), 0)

    def test_88_level_still_works(self):
        """88-level condition lookup → regression guard."""
        cond = "VALID-STATUS"
        result, issues = _convert_condition(cond, KNOWN_VARS, LEVEL_88)
        self.assertIn("ws_status", result)
        self.assertNotIn("MANUAL REVIEW", result)

    def test_abbreviated_combined_relation(self):
        """IF WS-A = 1 OR 2 → expands to WS-A = 1 OR WS-A = 2."""
        cond = "WS-A=1OR2"
        result, issues = _convert_condition(cond, KNOWN_VARS, LEVEL_88)
        self.assertIn(" or ", result)
        # Both comparisons should reference ws_a
        self.assertEqual(result.count("ws_a"), 2)


# ── EVALUATE TRUE + compound WHEN tests ───────────────────────────


class TestEvaluateTrueCompound(unittest.TestCase):
    """EVALUATE TRUE with compound AND/OR in WHEN conditions."""

    def _make_eval_data(self, when_clauses, when_other=None):
        return {
            "subject": "TRUE",
            "has_also": False,
            "when_clauses": when_clauses,
            "when_other_statements": when_other or [],
        }

    def test_evaluate_when_compound_and(self):
        """WHEN WS-A > 10 AND WS-FLAG = 'Y' → if ... and ..."""
        eval_data = self._make_eval_data([
            {"conditions": ["WS-A>10ANDWS-FLAG='Y'"],
             "body_statements": ["MOVE1TOWS-X"]},
        ])
        result, issues = parse_evaluate_statement(
            eval_data, KNOWN_VARS, LEVEL_88, string_vars=STRING_VARS
        )
        assert " and " in result
        assert "ws_a" in result
        assert "ws_flag" in result
        compile(result, "<test>", "exec")

    def test_evaluate_when_compound_or(self):
        """WHEN WS-A = 1 OR WS-A = 2 → if ... or ..."""
        eval_data = self._make_eval_data([
            {"conditions": ["WS-A=1ORWS-A=2"],
             "body_statements": ["MOVE1TOWS-X"]},
        ])
        result, issues = parse_evaluate_statement(
            eval_data, KNOWN_VARS, LEVEL_88, string_vars=set()
        )
        assert " or " in result
        assert result.count("ws_a") == 2
        compile(result, "<test>", "exec")

    def test_evaluate_when_simple_unchanged(self):
        """WHEN WS-A > 10 (no compound) → regression guard."""
        eval_data = self._make_eval_data([
            {"conditions": ["WS-A>10"],
             "body_statements": ["MOVE1TOWS-X"]},
        ], when_other=["MOVE0TOWS-X"])
        result, issues = parse_evaluate_statement(
            eval_data, KNOWN_VARS, LEVEL_88, string_vars=set()
        )
        assert "ws_a" in result
        assert " and " not in result
        assert " or " not in result
        assert "else:" in result
        compile(result, "<test>", "exec")


# ── EVALUATE WHEN THRU tests ────────────────────────────────────

class TestEvaluateWhenThru(unittest.TestCase):

    def _make_eval_data(self, subject, when_clauses, when_other=None):
        """Helper to build eval_data dict."""
        data = {
            "subject": subject,
            "has_also": False,
            "when_clauses": when_clauses,
            "when_other_statements": when_other or [],
        }
        return data

    def test_evaluate_when_thru_numeric_match(self):
        """WHEN 1 THRU 5, subject=3 → range check in generated code."""
        eval_data = self._make_eval_data("WS-CODE", [
            {"conditions": ["1THRU5"], "body_statements": ["MOVE1TOWS-X"]},
        ])
        result, issues = parse_evaluate_statement(
            eval_data, KNOWN_VARS, LEVEL_88, string_vars=set()
        )
        self.assertIn("<=", result)
        self.assertIn("Decimal('1')", result)
        self.assertIn("Decimal('5')", result)

    def test_evaluate_when_thru_boundary_low(self):
        """WHEN 1 THRU 5 → inclusive low boundary (uses <=)."""
        eval_data = self._make_eval_data("WS-CODE", [
            {"conditions": ["1THRU5"], "body_statements": ["MOVE1TOWS-X"]},
        ])
        result, issues = parse_evaluate_statement(
            eval_data, KNOWN_VARS, LEVEL_88, string_vars=set()
        )
        # Should generate: Decimal('1') <= ws_code.value <= Decimal('5')
        self.assertIn("Decimal('1') <=", result)

    def test_evaluate_when_thru_boundary_high(self):
        """WHEN 1 THRU 5 → inclusive high boundary (uses <=)."""
        eval_data = self._make_eval_data("WS-CODE", [
            {"conditions": ["1THRU5"], "body_statements": ["MOVE1TOWS-X"]},
        ])
        result, issues = parse_evaluate_statement(
            eval_data, KNOWN_VARS, LEVEL_88, string_vars=set()
        )
        self.assertIn("<= Decimal('5')", result)

    def test_evaluate_when_thru_miss(self):
        """WHEN 1 THRU 5 followed by WHEN OTHER → else branch exists."""
        eval_data = self._make_eval_data("WS-CODE", [
            {"conditions": ["1THRU5"], "body_statements": ["MOVE1TOWS-X"]},
        ], when_other=["MOVE0TOWS-X"])
        result, issues = parse_evaluate_statement(
            eval_data, KNOWN_VARS, LEVEL_88, string_vars=set()
        )
        self.assertIn("else:", result)

    def test_evaluate_when_thru_with_regular(self):
        """Mix of WHEN THRU and WHEN simple-value in same EVALUATE."""
        eval_data = self._make_eval_data("WS-CODE", [
            {"conditions": ["1THRU5"], "body_statements": ["MOVE1TOWS-X"]},
            {"conditions": ["10"], "body_statements": ["MOVE2TOWS-X"]},
        ])
        result, issues = parse_evaluate_statement(
            eval_data, KNOWN_VARS, LEVEL_88, string_vars=set()
        )
        # First clause: range check
        self.assertIn("Decimal('1') <=", result)
        # Second clause: equality check
        self.assertIn("Decimal('10')", result)

    def test_evaluate_when_other_regression(self):
        """WHEN OTHER still works as default → regression guard."""
        eval_data = self._make_eval_data("WS-CODE", [
            {"conditions": ["1"], "body_statements": ["MOVE1TOWS-X"]},
        ], when_other=["MOVE0TOWS-X"])
        result, issues = parse_evaluate_statement(
            eval_data, KNOWN_VARS, LEVEL_88, string_vars=set()
        )
        self.assertIn("else:", result)

    def test_evaluate_thru_string_ebcdic(self):
        """WHEN 'A' THRU 'Z' on PIC X subject → ebcdic_compare, not native <=."""
        eval_data = self._make_eval_data("WS-NAME", [
            {"conditions": ["'A'THRU'Z'"], "body_statements": ["MOVE1TOWS-X"]},
        ])
        result, issues = parse_evaluate_statement(
            eval_data, KNOWN_VARS, LEVEL_88, string_vars=STRING_VARS
        )
        self.assertIn("ebcdic_compare", result)
        # Must NOT use native <= for string range
        self.assertNotIn('"A" <= ws_name <= "Z"', result)

    def test_evaluate_thru_numeric_no_ebcdic(self):
        """WHEN 1 THRU 5 on numeric subject → no ebcdic_compare (regression)."""
        eval_data = self._make_eval_data("WS-A", [
            {"conditions": ["1THRU5"], "body_statements": ["MOVE1TOWS-X"]},
        ])
        result, issues = parse_evaluate_statement(
            eval_data, KNOWN_VARS, LEVEL_88, string_vars=STRING_VARS
        )
        self.assertNotIn("ebcdic_compare", result)
        self.assertIn("Decimal('1') <=", result)


# ── EVALUATE ALSO + THRU tests ──────────────────────────────────

class TestEvaluateAlsoThru(unittest.TestCase):
    """Regression: EVALUATE ALSO with THRU ranges must not produce invalid Decimal literals."""

    ALSO_KNOWN = {"WS-DEPT", "WS-LEVEL", "WS-CODE"}

    def _make_also_eval(self, subject, also_subjects, when_clauses, when_other=None):
        return {
            "subject": subject,
            "has_also": True,
            "also_subjects": also_subjects,
            "when_clauses": when_clauses,
            "when_other_statements": when_other or [],
        }

    def test_also_thru_numeric_compiles(self):
        """EVALUATE WS-DEPT ALSO WS-LEVEL, WHEN 10 ALSO 1 THRU 3 → valid Python."""
        eval_data = self._make_also_eval("WS-DEPT", ["WS-LEVEL"], [
            {
                "conditions": ["10"],
                "also_conditions": [["1THRU3"]],
                "body_statements": ["MOVE1TOWS-CODE"],
            },
            {
                "conditions": ["20"],
                "also_conditions": [["ANY"]],
                "body_statements": ["MOVE2TOWS-CODE"],
            },
        ])
        result, issues = parse_evaluate_statement(
            eval_data, self.ALSO_KNOWN, {}, string_vars=set()
        )
        # Must produce a range check, not an invalid literal
        self.assertIn("Decimal('1') <=", result)
        self.assertIn("<= Decimal('3')", result)
        # Must compile
        compile(result, "<test>", "exec")

    def test_also_thru_first_subject(self):
        """THRU range on the first subject of EVALUATE ALSO."""
        eval_data = self._make_also_eval("WS-DEPT", ["WS-LEVEL"], [
            {
                "conditions": ["1THRU5"],
                "also_conditions": [["10"]],
                "body_statements": ["MOVE1TOWS-CODE"],
            },
        ])
        result, issues = parse_evaluate_statement(
            eval_data, self.ALSO_KNOWN, {}, string_vars=set()
        )
        self.assertIn("Decimal('1') <=", result)
        self.assertIn("<= Decimal('5')", result)
        compile(result, "<test>", "exec")


# ── body_preview newline sanitization ───────────────────────────

class TestBodyPreviewNewline(unittest.TestCase):
    """Regression: multi-line body_preview in EXEC deps must not break generated Python."""

    def test_newline_in_preview_compiles(self):
        """Pipeline on COBOL with multi-line OCCURS DEPENDING ON produces compilable Python."""
        from cobol_analyzer_api import analyze_cobol
        from generate_full_python import generate_python_module
        source = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. NEWLINE-TEST.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-COUNT         PIC 9(2).
       01 WS-TABLE.
          05 WS-ROW         OCCURS 1 TO 30 TIMES
                             DEPENDING ON WS-COUNT
                             PIC X(10).
       01 WS-RESULT        PIC X(20).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 5 TO WS-COUNT.
           MOVE 'HELLO' TO WS-ROW(1).
           DISPLAY WS-ROW(1).
           STOP RUN.
"""
        analysis = analyze_cobol(source)
        result = generate_python_module(analysis)
        code = result["code"]
        # Must compile without indent errors
        compile(code, "<test>", "exec")


# ── DISPLAY in branches ─────────────────────────────────────────

class TestDisplayInBranches(unittest.TestCase):
    """DISPLAY inside IF/EVALUATE should emit print(), not MANUAL REVIEW."""

    def test_display_string_literal_in_branch(self):
        """DISPLAY 'ERROR' inside a branch → print('ERROR'), no MR."""
        # ANTLR getText() blob: no spaces
        stmt = "DISPLAY'ERROR: Invalid input'"
        code, issues = _convert_single_statement(
            stmt, KNOWN_VARS, LEVEL_88, {}, indent_level=2, string_vars=STRING_VARS,
        )
        self.assertIn("print(", code)
        self.assertIn("'ERROR: Invalid input'", code)
        self.assertNotIn("MANUAL REVIEW", code)
        self.assertEqual(len(issues), 0)

    def test_display_variable_in_branch(self):
        """DISPLAY WS-A (numeric var) → print(ws_a.value)."""
        stmt = "DISPLAYWS-A"
        code, issues = _convert_single_statement(
            stmt, KNOWN_VARS, LEVEL_88, {}, indent_level=1, string_vars=STRING_VARS,
        )
        self.assertIn("print(", code)
        self.assertIn("ws_a.value", code)
        self.assertNotIn("MANUAL REVIEW", code)

    def test_display_string_variable_in_branch(self):
        """DISPLAY WS-NAME (string var) → print(ws_name) without .value."""
        stmt = "DISPLAYWS-NAME"
        code, issues = _convert_single_statement(
            stmt, KNOWN_VARS, LEVEL_88, {}, indent_level=1, string_vars=STRING_VARS,
        )
        self.assertIn("print(ws_name)", code)
        self.assertNotIn(".value", code)

    def test_display_bare(self):
        """DISPLAY with no operands → print()."""
        stmt = "DISPLAY"
        code, issues = _convert_single_statement(
            stmt, KNOWN_VARS, LEVEL_88, {}, indent_level=1, string_vars=STRING_VARS,
        )
        self.assertIn("print()", code)


class TestInlinePerformVarying(unittest.TestCase):
    """Regression tests for inline PERFORM VARYING inside IF/EVALUATE branches."""

    def test_split_simple_add_body(self):
        """UNTIL cond + ADD body + END-PERFORM splits correctly."""
        text = "WS-AL-IDX>8ADDWS-REMAINDERTOWS-AL-ACTUAL(WS-AL-IDX)END-PERFORM"
        cond, body = _split_inline_perform_body(text)
        self.assertEqual(cond, "WS-AL-IDX>8")
        self.assertTrue(body.upper().startswith("ADD"))
        self.assertNotIn("END-PERFORM", body.upper())

    def test_split_display_body(self):
        """UNTIL cond + DISPLAY body + END-PERFORM splits correctly."""
        text = "WS-CR-IDX>WS-CARRIER-COUNTDISPLAY'  'WS-CR-NAME(WS-CR-IDX)END-PERFORM"
        cond, body = _split_inline_perform_body(text)
        self.assertEqual(cond, "WS-CR-IDX>WS-CARRIER-COUNT")
        self.assertTrue(body.upper().startswith("DISPLAY"))

    def test_split_no_end_perform(self):
        """Without END-PERFORM, returns condition and empty body."""
        text = "WS-IDX>10"
        cond, body = _split_inline_perform_body(text)
        self.assertEqual(cond, "WS-IDX>10")
        self.assertEqual(body, "")

    def test_split_if_body(self):
        """UNTIL cond + IF body + END-IF + END-PERFORM splits at IF."""
        text = "WS-IA-IDX>5IFWS-AREA=WS-INVALID(WS-IA-IDX)MOVE'N'TOWS-FLAGEND-IFEND-PERFORM"
        cond, body = _split_inline_perform_body(text)
        self.assertEqual(cond, "WS-IA-IDX>5")
        self.assertTrue(body.upper().startswith("IF"))

    def test_split_or_in_condition(self):
        """OR in UNTIL condition is not mistaken for a body verb."""
        text = "WS-IDX>WS-COUNTORWS-IS-MATCHMOVE0TOWS-XEND-PERFORM"
        cond, body = _split_inline_perform_body(text)
        self.assertEqual(cond, "WS-IDX>WS-COUNTORWS-IS-MATCH")
        self.assertTrue(body.upper().startswith("MOVE"))

    def test_inline_perform_compiles(self):
        """Inline PERFORM VARYING with simple body emits compilable Python."""
        stmt = "PERFORMVARYINGWS-IDXFROM1BY1UNTILWS-IDX>5ADDWS-XTOWS-YEND-PERFORM"
        known = {"WS-IDX", "WS-X", "WS-Y"}
        code, issues = _convert_single_statement(
            stmt, known, {}, {}, indent_level=0, string_vars=set(),
        )
        compile(code, "<test-inline-pv>", "exec")
        self.assertIn("while not", code)
        self.assertIn("ws_idx.store", code)

    def test_inline_perform_nested_if_compiles(self):
        """Nested IF inside inline PERFORM body — now correctly parsed."""
        stmt = ("PERFORMVARYINGWS-IDXFROM1BY1UNTILWS-IDX>5"
                "IFWS-A>0MOVE1TOWS-BEND-IFEND-PERFORM")
        known = {"WS-IDX", "WS-A", "WS-B"}
        code, issues = _convert_single_statement(
            stmt, known, {}, {}, indent_level=0, string_vars=set(),
        )
        compile(code, "<test-inline-pv-if>", "exec")
        self.assertIn("while not", code)
        self.assertIn("if ", code)
        self.assertIn("ws_b.store", code)


class TestRefmodUnknownVariable(unittest.TestCase):
    """Regression: reference modification for variables not in known_variables."""

    def test_refmod_unknown_var_produces_slice(self):
        """WS-FIELD(1:3) with WS-FIELD not in known_vars → still emits py_base[0:3]."""
        result, base = _resolve_subscripted_name(
            "WS-TIN-VALUE(1:3)", {"WS-OTHER-VAR"}, set()
        )
        self.assertIsNotNone(result)
        self.assertIn("[0:3]", result)
        self.assertIn("ws_tin_value", result)

    def test_refmod_known_var_still_works(self):
        """WS-FIELD(1:3) with WS-FIELD in known_vars → normal refmod path."""
        result, base = _resolve_subscripted_name(
            "WS-FIELD(1:3)", {"WS-FIELD"}, set()
        )
        self.assertIsNotNone(result)
        self.assertIn("[0:3]", result)
        self.assertIn("ws_field", result)


if __name__ == "__main__":
    unittest.main()
