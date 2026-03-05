"""
test_generator_edge_cases.py — Edge case tests for generate_full_python.py

Tests the generator against deliberately nasty COBOL patterns:
MOVE-only paragraphs, GO TO inside IF, STOP RUN mid-paragraph,
multi-target MOVE, MOVE CORRESPONDING, nested PERFORM in IF,
empty paragraphs, mixed statement order, GO TO DEPENDING ON.
"""

import pytest
from cobol_analyzer_api import analyze_cobol
from generate_full_python import generate_python_module


def _generate(cobol_source):
    """Helper: analyze + generate in one call."""
    analysis = analyze_cobol(cobol_source)
    assert analysis["success"], f"Parse failed: {analysis.get('parse_warning')}"
    return generate_python_module(analysis)["code"]


# ── 1. Paragraph with only MOVEs (no COMPUTE) ─────────────────

class TestMoveOnlyParagraph:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. MOVEONLY.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-A  PIC S9(5)V99.\n"
        "       01  WS-B  PIC S9(5)V99.\n"
        "       PROCEDURE DIVISION.\n"
        "       MOVE-PARA.\n"
        "           MOVE 100 TO WS-A.\n"
        "           MOVE WS-A TO WS-B.\n"
        "           STOP RUN.\n"
    )

    def test_paragraph_with_only_moves(self):
        code = _generate(self.SOURCE)
        assert "ws_a.store(Decimal('100'))" in code
        assert "ws_b.store(ws_a.value)" in code
        # Should NOT have pass — paragraph has real statements
        lines = code.split("\n")
        move_para_body = []
        capture = False
        for line in lines:
            if "def para_move_para" in line:
                capture = True
            elif capture and line.startswith("def "):
                break
            elif capture:
                move_para_body.append(line)
        body_text = "\n".join(move_para_body)
        assert "pass  # No statements" not in body_text


# ── 2. GO TO inside an IF branch ──────────────────────────────

class TestGoToInsideIf:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. GOTOIF.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-X  PIC S9(3).\n"
        "       PROCEDURE DIVISION.\n"
        "       CHECK-PARA.\n"
        "           IF WS-X > 0\n"
        "               GO TO DONE-PARA\n"
        "           END-IF.\n"
        "           STOP RUN.\n"
        "       DONE-PARA.\n"
        "           STOP RUN.\n"
    )

    def test_goto_inside_if_branch(self):
        code = _generate(self.SOURCE)
        assert "para_done_para()" in code
        assert "return" in code


# ── 3. Multiple GO TOs in sequence ────────────────────────────

class TestMultipleGoTos:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. MULTIGOTO.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-X  PIC S9(3).\n"
        "       PROCEDURE DIVISION.\n"
        "       START-PARA.\n"
        "           GO TO PARA-A.\n"
        "       PARA-A.\n"
        "           GO TO PARA-B.\n"
        "       PARA-B.\n"
        "           COMPUTE WS-X = 42.\n"
        "           STOP RUN.\n"
    )

    def test_multiple_gotos_in_sequence(self):
        code = _generate(self.SOURCE)
        assert "para_para_a()  # GO TO PARA-A" in code
        assert "para_para_b()  # GO TO PARA-B" in code
        # Source order: GO TO PARA-A appears before GO TO PARA-B
        idx_a = code.index("para_para_a()  # GO TO PARA-A")
        idx_b = code.index("para_para_b()  # GO TO PARA-B")
        assert idx_a < idx_b


# ── 4. STOP RUN in the middle of a paragraph ──────────────────

class TestStopRunMidParagraph:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. MIDSTOP.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-A  PIC S9(5).\n"
        "       01  WS-B  PIC S9(5).\n"
        "       PROCEDURE DIVISION.\n"
        "       CALC-PARA.\n"
        "           COMPUTE WS-A = 1.\n"
        "           STOP RUN.\n"
        "           COMPUTE WS-B = 2.\n"
    )

    def test_stop_run_mid_paragraph(self):
        code = _generate(self.SOURCE)
        # All three statements present
        assert "ws_a.store(" in code
        assert "return  # STOP RUN" in code
        assert "ws_b.store(" in code
        # Source order: COMPUTE WS-A before STOP RUN before COMPUTE WS-B
        idx_a = code.index("ws_a.store(")
        idx_stop = code.index("return  # STOP RUN")
        idx_b = code.index("ws_b.store(")
        assert idx_a < idx_stop < idx_b


# ── 5. MOVE with multiple receiving fields ─────────────────────

class TestMoveMultipleReceivers:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. MULTIMOVE.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-A  PIC S9(5).\n"
        "       01  WS-B  PIC S9(5).\n"
        "       01  WS-C  PIC S9(5).\n"
        "       PROCEDURE DIVISION.\n"
        "       INIT-PARA.\n"
        "           MOVE 0 TO WS-A WS-B WS-C.\n"
        "           STOP RUN.\n"
    )

    def test_move_multiple_receiving_fields(self):
        code = _generate(self.SOURCE)
        assert "ws_a.store(" in code
        assert "ws_b.store(" in code
        assert "ws_c.store(" in code


# ── 6. MOVE CORRESPONDING ─────────────────────────────────────

class TestMoveCorresponding:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. MOVECORR.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-INPUT.\n"
        "           05  WS-FIELD-A  PIC S9(5).\n"
        "       01  WS-OUTPUT.\n"
        "           05  WS-FIELD-B  PIC S9(5).\n"
        "       PROCEDURE DIVISION.\n"
        "       CORR-PARA.\n"
        "           MOVE CORRESPONDING WS-INPUT TO WS-OUTPUT.\n"
        "           STOP RUN.\n"
    )

    def test_move_corresponding(self):
        code = _generate(self.SOURCE)
        assert "# MANUAL REVIEW: MOVE CORRESPONDING" in code
        assert "[FAIL]" in code


# ── 7. Nested IF containing PERFORM ───────────────────────────

class TestNestedIfWithPerform:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. IFPERF.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-X  PIC S9(3).\n"
        "       01  WS-Y  PIC S9(5).\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           IF WS-X > 0\n"
        "               PERFORM CALC-PARA\n"
        "           END-IF.\n"
        "           STOP RUN.\n"
        "       CALC-PARA.\n"
        "           COMPUTE WS-Y = WS-X + 1.\n"
    )

    def test_nested_if_containing_perform(self):
        code = _generate(self.SOURCE)
        # PERFORM inside IF should emit para_calc_para() call
        assert "para_calc_para()" in code
        # CALC-PARA should have its own function with the COMPUTE
        assert "def para_calc_para" in code
        assert "ws_y.store(" in code


# ── 8. Empty paragraph ────────────────────────────────────────

class TestEmptyParagraph:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. EMPTYPARA.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-X  PIC S9(3).\n"
        "       PROCEDURE DIVISION.\n"
        "       FIRST-PARA.\n"
        "           COMPUTE WS-X = 1.\n"
        "       EMPTY-PARA.\n"
        "       LAST-PARA.\n"
        "           STOP RUN.\n"
    )

    def test_empty_paragraph(self):
        code = _generate(self.SOURCE)
        # Extract EMPTY-PARA body
        lines = code.split("\n")
        empty_body = []
        capture = False
        for line in lines:
            if "def para_empty_para" in line:
                capture = True
            elif capture and line.startswith("def "):
                break
            elif capture:
                empty_body.append(line)
        body_text = "\n".join(empty_body)
        assert "pass  # No statements captured" in body_text


# ── 9. Mixed statement order (MOVE → COMPUTE → IF → PERFORM) ──

class TestMixedStatementOrder:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. MIXORDER.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-A      PIC S9(5)V99.\n"
        "       01  WS-RESULT PIC S9(7)V99.\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-LOGIC.\n"
        "           MOVE 500 TO WS-A.\n"
        "           COMPUTE WS-RESULT = WS-A + 1.\n"
        "           IF WS-RESULT > 0\n"
        "               COMPUTE WS-RESULT = WS-RESULT + 1\n"
        "           END-IF.\n"
        "           PERFORM FINAL-PARA.\n"
        "           STOP RUN.\n"
        "       FINAL-PARA.\n"
        "           COMPUTE WS-A = 0.\n"
    )

    def test_mixed_statement_order(self):
        code = _generate(self.SOURCE)
        # All statement types present
        assert "ws_a.store(" in code
        assert "ws_result.store(" in code
        assert "if " in code
        assert "para_final_para()" in code
        assert "return  # STOP RUN" in code

        # Extract MAIN-LOGIC body to check ordering
        lines = code.split("\n")
        main_body = []
        capture = False
        for line in lines:
            if "def para_main_logic" in line:
                capture = True
            elif capture and line.startswith("def "):
                break
            elif capture:
                main_body.append(line)
        body = "\n".join(main_body)

        # Source order: MOVE before COMPUTE before IF before PERFORM
        idx_move = body.index("ws_a.store(")
        idx_compute = body.index("ws_result.store(")
        idx_if = body.index("if ")
        idx_perform = body.index("para_final_para()")
        assert idx_move < idx_compute < idx_if < idx_perform


# ── 10. GO TO DEPENDING ON ────────────────────────────────────

class TestGoToDependingOn:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. GOTODEP.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-IDX  PIC 9(1).\n"
        "       01  WS-X    PIC S9(3).\n"
        "       PROCEDURE DIVISION.\n"
        "       DISPATCH-PARA.\n"
        "           GO TO PARA-A PARA-B PARA-C\n"
        "               DEPENDING ON WS-IDX.\n"
        "           STOP RUN.\n"
        "       PARA-A.\n"
        "           COMPUTE WS-X = 1.\n"
        "       PARA-B.\n"
        "           COMPUTE WS-X = 2.\n"
        "       PARA-C.\n"
        "           COMPUTE WS-X = 3.\n"
    )

    def test_goto_depending_on(self):
        code = _generate(self.SOURCE)
        assert "# MANUAL REVIEW: GO TO DEPENDING ON" in code
        assert "[FAIL]" in code


# ── 11. Figurative constants (SPACES, ZEROS) ────────────────

class TestFigurativeConstants:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. FIGCONST.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-NAME  PIC X(20).\n"
        "       01  WS-AMT   PIC S9(5)V99.\n"
        "       PROCEDURE DIVISION.\n"
        "       INIT-PARA.\n"
        "           MOVE SPACES TO WS-NAME.\n"
        "           MOVE ZEROS TO WS-AMT.\n"
        "           STOP RUN.\n"
    )

    def test_figurative_constants(self):
        code = _generate(self.SOURCE)
        # Both MOVE statements should be emitted
        assert "ws_name" in code
        assert "ws_amt" in code
        # SPACES before ZEROS in source order
        idx_name = code.index("ws_name")
        idx_amt = code.index("ws_amt")
        assert idx_name < idx_amt


# ── 12. PERFORM THRU ────────────────────────────────────────

class TestPerformThru:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. PERFTHRU.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-X  PIC S9(3).\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           PERFORM PARA-A THRU PARA-C.\n"
        "           STOP RUN.\n"
        "       PARA-A.\n"
        "           COMPUTE WS-X = 1.\n"
        "       PARA-B.\n"
        "           COMPUTE WS-X = 2.\n"
        "       PARA-C.\n"
        "           COMPUTE WS-X = 3.\n"
    )

    def test_perform_thru(self):
        code = _generate(self.SOURCE)
        # PERFORM THRU emits calls to first and last paragraph
        assert "para_para_a()" in code
        assert "para_para_c()" in code
        # Source order: PARA-A call before PARA-C call
        idx_a = code.index("para_para_a()")
        idx_c = code.index("para_para_c()")
        assert idx_a < idx_c
        # All three paragraphs should have their own functions
        assert "def para_para_a" in code
        assert "def para_para_b" in code
        assert "def para_para_c" in code


# ── 13. Paragraph with only ALTER ────────────────────────────

class TestParagraphWithOnlyAlter:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. ALTERONLY.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-X  PIC S9(3).\n"
        "       PROCEDURE DIVISION.\n"
        "       SETUP-PARA.\n"
        "           ALTER DISPATCH-PARA TO PROCEED TO CALC-PARA.\n"
        "           STOP RUN.\n"
        "       DISPATCH-PARA.\n"
        "           GO TO DEFAULT-PARA.\n"
        "       CALC-PARA.\n"
        "           COMPUTE WS-X = 42.\n"
        "       DEFAULT-PARA.\n"
        "           COMPUTE WS-X = 0.\n"
    )

    def test_paragraph_with_only_alter(self):
        code = _generate(self.SOURCE)
        # ALTER should emit MANUAL REVIEW comment
        assert "# MANUAL REVIEW: ALTER" in code
        # Extract SETUP-PARA body — should NOT have pass
        lines = code.split("\n")
        setup_body = []
        capture = False
        for line in lines:
            if "def para_setup_para" in line:
                capture = True
            elif capture and line.startswith("def "):
                break
            elif capture:
                setup_body.append(line)
        body_text = "\n".join(setup_body)
        assert "pass  # No statements" not in body_text
        # ALTER comment appears before STOP RUN return
        idx_alter = code.index("# MANUAL REVIEW: ALTER")
        idx_stop = code.index("return  # STOP RUN")
        assert idx_alter < idx_stop


# ── 14. EVALUATE variable (value-based) ────────────────────────

class TestEvaluateSimple:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. EVALSIMPLE.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-ACCOUNT-TYPE  PIC X(1).\n"
        "       01  WS-TIER          PIC 9(1).\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-LOGIC.\n"
        "           EVALUATE WS-ACCOUNT-TYPE\n"
        "               WHEN 'S'\n"
        "                   MOVE 1 TO WS-TIER\n"
        "               WHEN 'C'\n"
        "                   MOVE 2 TO WS-TIER\n"
        "               WHEN OTHER\n"
        "                   MOVE 0 TO WS-TIER\n"
        "           END-EVALUATE\n"
        "           STOP RUN.\n"
    )

    def test_evaluate_simple(self):
        code = _generate(self.SOURCE)
        assert 'if ws_account_type == "S":' in code
        assert 'elif ws_account_type == "C":' in code
        assert "else:" in code
        assert "ws_tier.store(Decimal('1'))" in code
        assert "ws_tier.store(Decimal('2'))" in code
        assert "ws_tier.store(Decimal('0'))" in code


# ── 15. EVALUATE TRUE (condition-based) ────────────────────────

class TestEvaluateTrue:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. EVALTRUE.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-BALANCE  PIC S9(7)V99.\n"
        "       01  WS-RATE     PIC 9V9(4).\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-LOGIC.\n"
        "           EVALUATE TRUE\n"
        "               WHEN WS-BALANCE > 100000\n"
        "                   MOVE 0.0250 TO WS-RATE\n"
        "               WHEN WS-BALANCE > 50000\n"
        "                   MOVE 0.0375 TO WS-RATE\n"
        "               WHEN OTHER\n"
        "                   MOVE 0.0500 TO WS-RATE\n"
        "           END-EVALUATE\n"
        "           STOP RUN.\n"
    )

    def test_evaluate_true(self):
        code = _generate(self.SOURCE)
        # Should use condition-based if/elif
        assert "if " in code
        assert "elif " in code
        assert "else:" in code
        # Should have rate assignments
        assert "ws_rate.store(Decimal('0.0250'))" in code
        assert "ws_rate.store(Decimal('0.0375'))" in code
        assert "ws_rate.store(Decimal('0.0500'))" in code


# ── 16. EVALUATE with WHEN OTHER body ─────────────────────────

class TestEvaluateWithWhenOther:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. EVALOTHER.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-REGION    PIC X(2).\n"
        "       01  WS-TAX-RATE  PIC 9V9(4).\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-LOGIC.\n"
        "           EVALUATE WS-REGION\n"
        "               WHEN 'NE'\n"
        "                   MOVE 0.0625 TO WS-TAX-RATE\n"
        "               WHEN 'SW'\n"
        "                   MOVE 0.0500 TO WS-TAX-RATE\n"
        "               WHEN OTHER\n"
        "                   MOVE 0.0600 TO WS-TAX-RATE\n"
        "           END-EVALUATE\n"
        "           STOP RUN.\n"
    )

    def test_evaluate_with_when_other(self):
        code = _generate(self.SOURCE)
        assert 'if ws_region == "NE":' in code
        assert 'elif ws_region == "SW":' in code
        assert "else:" in code
        assert "ws_tax_rate.store(Decimal('0.0600'))" in code


# ── 17. ADD TO ───────────────────────────────────────────────

class TestAddToStatement:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. ADDTO.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-A  PIC S9(5)V99.\n"
        "       01  WS-B  PIC S9(5)V99.\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-LOGIC.\n"
        "           MOVE 100 TO WS-A.\n"
        "           MOVE 200 TO WS-B.\n"
        "           ADD WS-A TO WS-B.\n"
        "           STOP RUN.\n"
    )

    def test_add_to(self):
        code = _generate(self.SOURCE)
        assert "ws_b.store(ws_b.value + ws_a.value)" in code


# ── 18. ADD GIVING ──────────────────────────────────────────

class TestAddGivingStatement:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. ADDGIVING.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-A  PIC S9(5)V99.\n"
        "       01  WS-B  PIC S9(5)V99.\n"
        "       01  WS-C  PIC S9(5)V99.\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-LOGIC.\n"
        "           MOVE 100 TO WS-A.\n"
        "           MOVE 200 TO WS-B.\n"
        "           ADD WS-A TO WS-B GIVING WS-C.\n"
        "           STOP RUN.\n"
    )

    def test_add_giving(self):
        code = _generate(self.SOURCE)
        assert "ws_c.store(ws_a.value + ws_b.value)" in code


# ── 19. SUBTRACT FROM ──────────────────────────────────────

class TestSubtractFromStatement:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. SUBFROM.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-A  PIC S9(5)V99.\n"
        "       01  WS-B  PIC S9(5)V99.\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-LOGIC.\n"
        "           MOVE 100 TO WS-A.\n"
        "           MOVE 200 TO WS-B.\n"
        "           SUBTRACT WS-A FROM WS-B.\n"
        "           STOP RUN.\n"
    )

    def test_subtract_from(self):
        code = _generate(self.SOURCE)
        assert "ws_b.store(ws_b.value - ws_a.value)" in code


# ── 20. MULTIPLY BY ────────────────────────────────────────

class TestMultiplyByStatement:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. MULBY.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-A  PIC S9(5)V99.\n"
        "       01  WS-B  PIC S9(5)V99.\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-LOGIC.\n"
        "           MOVE 100 TO WS-A.\n"
        "           MOVE 200 TO WS-B.\n"
        "           MULTIPLY WS-A BY WS-B.\n"
        "           STOP RUN.\n"
    )

    def test_multiply_by(self):
        code = _generate(self.SOURCE)
        assert "ws_b.store(ws_b.value * ws_a.value)" in code


# ── 21. DIVIDE INTO ────────────────────────────────────────

class TestDivideIntoStatement:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. DIVINTO.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-A  PIC S9(5)V99.\n"
        "       01  WS-B  PIC S9(5)V99.\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-LOGIC.\n"
        "           MOVE 10 TO WS-A.\n"
        "           MOVE 200 TO WS-B.\n"
        "           DIVIDE WS-A INTO WS-B.\n"
        "           STOP RUN.\n"
    )

    def test_divide_into(self):
        code = _generate(self.SOURCE)
        assert "ws_b.store(ws_b.value / ws_a.value)" in code


# ── 22. DIVIDE GIVING REMAINDER ────────────────────────────

class TestDivideGivingRemainder:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. DIVREM.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-A  PIC S9(5)V99.\n"
        "       01  WS-B  PIC S9(5)V99.\n"
        "       01  WS-C  PIC S9(5)V99.\n"
        "       01  WS-D  PIC S9(5)V99.\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-LOGIC.\n"
        "           MOVE 10 TO WS-A.\n"
        "           MOVE 200 TO WS-B.\n"
        "           DIVIDE WS-A INTO WS-B GIVING WS-C\n"
        "               REMAINDER WS-D.\n"
        "           STOP RUN.\n"
    )

    def test_divide_giving_remainder(self):
        code = _generate(self.SOURCE)
        assert "ws_c.store(" in code
        assert "ws_d.store(" in code


# ── 17. EVALUATE ALSO (unsupported → MANUAL REVIEW) ───────────

class TestEvaluateAlso:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. EVALALSO.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-X  PIC 9(1).\n"
        "       01  WS-Y  PIC 9(1).\n"
        "       01  WS-R  PIC 9(1).\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-LOGIC.\n"
        "           EVALUATE WS-X ALSO WS-Y\n"
        "               WHEN 1 ALSO 2\n"
        "                   MOVE 3 TO WS-R\n"
        "               WHEN OTHER\n"
        "                   MOVE 0 TO WS-R\n"
        "           END-EVALUATE\n"
        "           STOP RUN.\n"
    )

    def test_evaluate_also(self):
        code = _generate(self.SOURCE)
        assert "MANUAL REVIEW" in code
        # Should NOT have generated if/elif for this block
        assert 'if ws_x' not in code
