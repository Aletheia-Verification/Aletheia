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


# ── 4b. EXIT PROGRAM / GOBACK ──────────────────────────────────

class TestExitProgramGoback:
    def test_exit_program(self):
        """EXIT PROGRAM emits return."""
        source = (
            "       IDENTIFICATION DIVISION.\n"
            "       PROGRAM-ID. SUBPROG.\n"
            "       DATA DIVISION.\n"
            "       WORKING-STORAGE SECTION.\n"
            "       01  WS-A PIC 9(3).\n"
            "       PROCEDURE DIVISION.\n"
            "       0000-MAIN.\n"
            "           MOVE 1 TO WS-A.\n"
            "           EXIT PROGRAM.\n"
        )
        analysis = analyze_cobol(source)
        result = generate_python_module(analysis)
        code = result["code"]
        assert "return  # EXIT PROGRAM" in code

    def test_goback(self):
        """GOBACK emits return."""
        source = (
            "       IDENTIFICATION DIVISION.\n"
            "       PROGRAM-ID. SUBPROG.\n"
            "       DATA DIVISION.\n"
            "       WORKING-STORAGE SECTION.\n"
            "       01  WS-A PIC 9(3).\n"
            "       PROCEDURE DIVISION.\n"
            "       0000-MAIN.\n"
            "           MOVE 1 TO WS-A.\n"
            "           GOBACK.\n"
        )
        analysis = analyze_cobol(source)
        result = generate_python_module(analysis)
        code = result["code"]
        assert "return  # GOBACK" in code

    def test_stop_run_regression(self):
        """Regression: STOP RUN still emits return."""
        source = (
            "       IDENTIFICATION DIVISION.\n"
            "       PROGRAM-ID. TESTPROG.\n"
            "       DATA DIVISION.\n"
            "       WORKING-STORAGE SECTION.\n"
            "       01  WS-A PIC 9(3).\n"
            "       PROCEDURE DIVISION.\n"
            "       0000-MAIN.\n"
            "           MOVE 1 TO WS-A.\n"
            "           STOP RUN.\n"
        )
        analysis = analyze_cobol(source)
        result = generate_python_module(analysis)
        code = result["code"]
        assert "return  # STOP RUN" in code


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
        assert "MOVE CORRESPONDING" in code
        assert "no matching fields" in code
        assert "[FAIL]" not in code
        assert "[OK]" in code


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
        # Should emit if/elif chain, not MANUAL REVIEW
        proc_section = code.split("# PROCEDURE DIVISION")[1] if "# PROCEDURE DIVISION" in code else code
        assert "# MANUAL REVIEW" not in proc_section.split("# ─")[0]
        assert "if int(ws_idx.value) == 1:" in code
        assert "para_para_a()" in code
        assert "para_para_b()" in code
        assert "para_para_c()" in code


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
        # Should generate compound conditions, not MANUAL REVIEW
        proc_section = code.split("# PROCEDURE DIVISION")[1] if "# PROCEDURE DIVISION" in code else code
        assert "MANUAL REVIEW" not in proc_section.split("# ─")[0]
        assert "ws_x" in code
        assert "ws_y" in code
        assert " and " in code


# ── 23. PERFORM VARYING simple (paragraph-level) ──────────────

class TestPerformVaryingSimple:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. PERFVAR.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-I      PIC 9(3).\n"
        "       01  WS-TOTAL  PIC S9(7)V99.\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-LOGIC.\n"
        "           PERFORM CALC-PARA VARYING WS-I\n"
        "               FROM 1 BY 1 UNTIL WS-I > 10.\n"
        "           STOP RUN.\n"
        "       CALC-PARA.\n"
        "           ADD WS-I TO WS-TOTAL.\n"
    )

    def test_perform_varying_simple(self):
        code = _generate(self.SOURCE)
        # Should emit while loop, not one-shot call
        assert "while not (" in code
        # Initialize from 1
        assert "ws_i.store(Decimal('1'))" in code
        # Call paragraph inside loop
        assert "para_calc_para()" in code
        # Increment by 1
        assert "ws_i.store(ws_i.value + Decimal('1'))" in code
        # Condition should be inverted (UNTIL → while not)
        assert "ws_i.value > Decimal('10')" in code


# ── 24. PERFORM VARYING BY 2 ──────────────────────────────────

class TestPerformVaryingBy2:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. PERFVAR2.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-I      PIC 9(3).\n"
        "       01  WS-TOTAL  PIC S9(7)V99.\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-LOGIC.\n"
        "           PERFORM CALC-PARA VARYING WS-I\n"
        "               FROM 2 BY 2 UNTIL WS-I > 20.\n"
        "           STOP RUN.\n"
        "       CALC-PARA.\n"
        "           ADD WS-I TO WS-TOTAL.\n"
    )

    def test_perform_varying_by_2(self):
        code = _generate(self.SOURCE)
        # FROM 2
        assert "ws_i.store(Decimal('2'))" in code
        # BY 2
        assert "ws_i.store(ws_i.value + Decimal('2'))" in code
        # UNTIL WS-I > 20
        assert "ws_i.value > Decimal('20')" in code


# ── 25. PERFORM TIMES (inline, captured by analyzer) ──────────

class TestPerformTimes:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. PERFTIMES.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-X  PIC S9(5)V99.\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-LOGIC.\n"
        "           PERFORM 5 TIMES\n"
        "               ADD 1 TO WS-X\n"
        "           END-PERFORM.\n"
        "           STOP RUN.\n"
    )

    def test_perform_times_captured(self):
        """PERFORM TIMES should be captured by the analyzer."""
        from cobol_analyzer_api import analyze_cobol
        analysis = analyze_cobol(self.SOURCE)
        assert analysis["success"]
        assert len(analysis["perform_times"]) >= 1
        pt = analysis["perform_times"][0]
        assert pt["count"] == "5"


# ── 26. STRING DELIMITED BY SIZE ──────────────────────────────

class TestStringDelimitedBySize:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. STRSIZE.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-FIRST  PIC X(10).\n"
        "       01  WS-LAST   PIC X(10).\n"
        "       01  WS-FULL   PIC X(20).\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           STRING WS-FIRST DELIMITED BY SIZE\n"
        "                  WS-LAST  DELIMITED BY SIZE\n"
        "                  INTO WS-FULL.\n"
        "           STOP RUN.\n"
    )

    def test_string_delimited_by_size(self):
        code = _generate(self.SOURCE)
        assert "ws_full = str(ws_first) + str(ws_last)" in code
        assert "[OK]" in code


# ── 27. STRING multiple sources ───────────────────────────────

class TestStringMultipleSources:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. STRMULTI.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-A  PIC X(5).\n"
        "       01  WS-B  PIC X(5).\n"
        "       01  WS-C  PIC X(5).\n"
        "       01  WS-D  PIC X(20).\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           STRING WS-A DELIMITED BY SIZE\n"
        "                  WS-B DELIMITED BY SIZE\n"
        "                  WS-C DELIMITED BY SIZE\n"
        "                  INTO WS-D.\n"
        "           STOP RUN.\n"
    )

    def test_string_multiple_sources(self):
        code = _generate(self.SOURCE)
        assert "ws_d = str(ws_a) + str(ws_b) + str(ws_c)" in code


# ── 28. STRING with POINTER (MANUAL REVIEW) ──────────────────

class TestStringWithPointer:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. STRPTR.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-A    PIC X(10).\n"
        "       01  WS-B    PIC X(20).\n"
        "       01  WS-PTR  PIC 9(3).\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           STRING WS-A DELIMITED BY SIZE\n"
        "                  INTO WS-B\n"
        "                  WITH POINTER WS-PTR.\n"
        "           STOP RUN.\n"
    )

    def test_string_with_pointer(self):
        code = _generate(self.SOURCE)
        proc = code.split("# PROCEDURE DIVISION")[1] if "# PROCEDURE DIVISION" in code else code
        assert "MANUAL REVIEW" not in proc.split("# ─")[0]
        assert "_pos = int(ws_ptr.value) - 1" in code
        assert "_concat" in code


# ── 29. UNSTRING simple delimiter ─────────────────────────────

class TestUnstringSimpleDelimiter:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. UNSTRSIMPLE.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-INPUT  PIC X(30).\n"
        "       01  WS-PART1  PIC X(10).\n"
        "       01  WS-PART2  PIC X(10).\n"
        "       01  WS-PART3  PIC X(10).\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           UNSTRING WS-INPUT DELIMITED BY ','\n"
        "                  INTO WS-PART1 WS-PART2 WS-PART3.\n"
        "           STOP RUN.\n"
    )

    def test_unstring_simple_delimiter(self):
        code = _generate(self.SOURCE)
        assert ".split(" in code
        assert "ws_part1 = _unstring_parts[0]" in code
        assert "ws_part2 = _unstring_parts[1]" in code
        assert "ws_part3 = _unstring_parts[2]" in code
        assert "[OK]" in code


# ── 30. UNSTRING with OR (MANUAL REVIEW) ─────────────────────

class TestUnstringWithOr:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. UNSTROR.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-INPUT  PIC X(30).\n"
        "       01  WS-PART1  PIC X(10).\n"
        "       01  WS-PART2  PIC X(10).\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           UNSTRING WS-INPUT DELIMITED BY ',' OR ';'\n"
        "                  INTO WS-PART1 WS-PART2.\n"
        "           STOP RUN.\n"
    )

    def test_unstring_with_or(self):
        code = _generate(self.SOURCE)
        assert "MANUAL REVIEW" not in code
        assert "re.split" in code
        assert "ws_part1" in code
        assert "ws_part2" in code
        assert "[OK]" in code


# ── 31. UNSTRING with TALLYING ───────────────────────────────

class TestUnstringWithTallying:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. UNSTRTALLY.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-INPUT  PIC X(30).\n"
        "       01  WS-PART1  PIC X(10).\n"
        "       01  WS-COUNT  PIC 9(3).\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           UNSTRING WS-INPUT DELIMITED BY ','\n"
        "                  INTO WS-PART1\n"
        "                  TALLYING IN WS-COUNT.\n"
        "           STOP RUN.\n"
    )

    def test_unstring_with_tallying(self):
        code = _generate(self.SOURCE)
        assert "MANUAL REVIEW" not in code
        assert "ws_count" in code
        assert "ws_part1" in code
        assert "[OK]" in code


# ── 32. INSPECT TALLYING ALL ─────────────────────────────────

class TestInspectTallyingAll:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. INSPTALLY.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-TEXT   PIC X(20).\n"
        "       01  WS-COUNT  PIC 9(3).\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           INSPECT WS-TEXT TALLYING WS-COUNT\n"
        "               FOR ALL 'X'.\n"
        "           STOP RUN.\n"
    )

    def test_inspect_tallying_all(self):
        code = _generate(self.SOURCE)
        assert ".count(" in code
        assert "ws_count.store(" in code
        assert "[OK]" in code


# ── 33. INSPECT TALLYING LEADING (MANUAL REVIEW) ─────────────

class TestInspectTallyingLeading:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. INSPLEAD.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-TEXT   PIC X(20).\n"
        "       01  WS-COUNT  PIC 9(3).\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           INSPECT WS-TEXT TALLYING WS-COUNT\n"
        "               FOR LEADING '0'.\n"
        "           STOP RUN.\n"
    )

    def test_inspect_tallying_leading(self):
        code = _generate(self.SOURCE)
        assert "MANUAL REVIEW" not in code
        assert "_cnt" in code
        assert "for _ch in _src" in code
        assert "[OK]" in code


# ── 34. INSPECT REPLACING ALL ────────────────────────────────

class TestInspectReplacingAll:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. INSPREP.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-TEXT  PIC X(20).\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           INSPECT WS-TEXT REPLACING ALL 'X' BY 'Y'.\n"
        "           STOP RUN.\n"
    )

    def test_inspect_replacing_all(self):
        code = _generate(self.SOURCE)
        assert ".replace(" in code
        assert "ws_text = ws_text.replace(" in code
        assert "[OK]" in code


# ── 35. INSPECT REPLACING FIRST (MANUAL REVIEW) ──────────────

class TestInspectReplacingFirst:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. INSPFIRST.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-TEXT  PIC X(20).\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           INSPECT WS-TEXT REPLACING FIRST 'X' BY 'Y'.\n"
        "           STOP RUN.\n"
    )

    def test_inspect_replacing_first(self):
        code = _generate(self.SOURCE)
        assert "MANUAL REVIEW" not in code
        assert ".replace('X', 'Y', 1)" in code
        assert "[OK]" in code


# ── 36. INSPECT CONVERTING (now emitted) ─────────────────────

class TestInspectConverting:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. INSPCONV.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-TEXT  PIC X(20).\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           INSPECT WS-TEXT CONVERTING\n"
        "               'abcdefghijklmnopqrstuvwxyz' TO\n"
        "               'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.\n"
        "           STOP RUN.\n"
    )

    def test_inspect_converting(self):
        code = _generate(self.SOURCE)
        assert "str.maketrans(" in code
        assert ".translate(_tbl)" in code


# ── 37. INSPECT TALLYING + REPLACING (MANUAL REVIEW) ─────────

class TestInspectTallyingReplacing:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. INSPTALLREP.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-TEXT   PIC X(20).\n"
        "       01  WS-COUNT  PIC 9(3).\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           INSPECT WS-TEXT TALLYING WS-COUNT\n"
        "               FOR ALL 'X'\n"
        "               REPLACING ALL 'X' BY 'Y'.\n"
        "           STOP RUN.\n"
    )

    def test_inspect_tallying_replacing(self):
        code = _generate(self.SOURCE)
        assert "MANUAL REVIEW" in code


# ── 38. INSPECT TALLYING FOR CHARACTERS (no BA) ────────────────

class TestInspectTallyingCharacters:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. INSPCHARS.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-TEXT   PIC X(20).\n"
        "       01  WS-COUNT  PIC 9(3).\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           INSPECT WS-TEXT TALLYING WS-COUNT\n"
        "               FOR CHARACTERS.\n"
        "           STOP RUN.\n"
    )

    def test_inspect_tallying_characters(self):
        code = _generate(self.SOURCE)
        assert "MANUAL REVIEW" not in code
        assert "len(str(ws_text))" in code
        assert "[OK]" in code
        compile(code, "<test>", "exec")


# ── 39. INSPECT TALLYING MULTI-COUNTER ─────────────────────────

class TestInspectTallyingMulti:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. INSPMULTI.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-TEXT       PIC X(20).\n"
        "       01  WS-DASH-CNT   PIC 9(3).\n"
        "       01  WS-SPACE-CNT  PIC 9(3).\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           INSPECT WS-TEXT TALLYING\n"
        "               WS-DASH-CNT FOR ALL '-'\n"
        "               WS-SPACE-CNT FOR ALL ' '.\n"
        "           STOP RUN.\n"
    )

    def test_inspect_tallying_multi(self):
        code = _generate(self.SOURCE)
        assert "MANUAL REVIEW" not in code
        assert "ws_dash_cnt" in code
        assert "ws_space_cnt" in code
        assert "[OK]" in code
        compile(code, "<test>", "exec")


# ── 40. INSPECT REPLACING CHARACTERS BY ────────────────────────

class TestInspectReplacingCharactersBy:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. INSPREPCHR.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-TEXT  PIC X(20).\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           INSPECT WS-TEXT REPLACING CHARACTERS BY '*'.\n"
        "           STOP RUN.\n"
    )

    def test_inspect_replacing_characters_by(self):
        code = _generate(self.SOURCE)
        assert "MANUAL REVIEW" not in code
        assert "'*' * len" in code
        assert "[OK]" in code
        compile(code, "<test>", "exec")


# ── 41. INSPECT TALLYING FOR CHARACTERS BEFORE INITIAL ─────────

class TestInspectTallyingCharsBefore:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. INSPCHBA.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-TEXT   PIC X(20).\n"
        "       01  WS-COUNT  PIC 9(3).\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           INSPECT WS-TEXT TALLYING WS-COUNT\n"
        "               FOR CHARACTERS BEFORE INITIAL '.'.\n"
        "           STOP RUN.\n"
    )

    def test_inspect_tallying_chars_before(self):
        code = _generate(self.SOURCE)
        assert "MANUAL REVIEW" not in code
        assert ".find('.')" in code
        assert "[OK]" in code
        compile(code, "<test>", "exec")


# ── 42. INSPECT REPLACING LEADING ──────────────────────────────

class TestInspectReplacingLeading:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. INSPLEADR.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-TEXT  PIC X(20).\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           INSPECT WS-TEXT REPLACING LEADING '0' BY ' '.\n"
        "           STOP RUN.\n"
    )

    def test_inspect_replacing_leading(self):
        code = _generate(self.SOURCE)
        assert "MANUAL REVIEW" not in code
        assert "_result = list" in code
        assert "for _i, _ch" in code
        assert "[OK]" in code
        compile(code, "<test>", "exec")


# ── PERFORM UNTIL (without VARYING) ─────────────────────────────

class TestPerformUntilSimple:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. PUNTIL.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-EOF          PIC X VALUE 'N'.\n"
        "       01  WS-COUNT        PIC 9(3) VALUE 0.\n"
        "       PROCEDURE DIVISION.\n"
        "       1000-MAIN.\n"
        "           PERFORM 2000-READ-NEXT UNTIL WS-EOF = 'Y'.\n"
        "           STOP RUN.\n"
        "       2000-READ-NEXT.\n"
        "           ADD 1 TO WS-COUNT.\n"
    )

    def test_perform_until_simple(self):
        code = _generate(self.SOURCE)
        assert "while not (" in code
        assert "para_2000_read_next()" in code
        # Should NOT have a .store() init line (no FROM clause)
        assert "ws_eof.store" not in code.split("while")[0] if "while" in code else True


class TestPerformUntilWith88Level:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. PUNTIL88.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-STATUS        PIC X VALUE 'N'.\n"
        "           88  END-OF-FILE  VALUE 'Y'.\n"
        "       01  WS-COUNT         PIC 9(3) VALUE 0.\n"
        "       PROCEDURE DIVISION.\n"
        "       1000-MAIN.\n"
        "           PERFORM 2000-PROCESS UNTIL END-OF-FILE.\n"
        "           STOP RUN.\n"
        "       2000-PROCESS.\n"
        "           ADD 1 TO WS-COUNT.\n"
    )

    def test_perform_until_88_level(self):
        code = _generate(self.SOURCE)
        assert "while not (" in code
        assert "para_2000_process()" in code


# ── 41. PERFORM A THRU C — calls all paragraphs in range ──

class TestPerformThru:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. PERFTHRU.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-A  PIC S9(5)V99.\n"
        "       01  WS-B  PIC S9(5)V99.\n"
        "       01  WS-C  PIC S9(5)V99.\n"
        "       PROCEDURE DIVISION.\n"
        "       0000-MAIN.\n"
        "           PERFORM 1000-STEP-A THRU 3000-STEP-C.\n"
        "           STOP RUN.\n"
        "       1000-STEP-A.\n"
        "           MOVE 10 TO WS-A.\n"
        "       2000-STEP-B.\n"
        "           MOVE 20 TO WS-B.\n"
        "       3000-STEP-C.\n"
        "           MOVE 30 TO WS-C.\n"
    )

    def test_thru_emits_all_three(self):
        """PERFORM A THRU C must call A, B, and C in order."""
        code = _generate(self.SOURCE)
        assert "para_1000_step_a()" in code
        assert "para_2000_step_b()" in code
        assert "para_3000_step_c()" in code

    def test_thru_order(self):
        """Calls must appear in source order: A before B before C."""
        code = _generate(self.SOURCE)
        pos_a = code.index("para_1000_step_a()")
        pos_b = code.index("para_2000_step_b()")
        pos_c = code.index("para_3000_step_c()")
        assert pos_a < pos_b < pos_c


# ── 42. DIVIDE REMAINDER with negative dividend ───────────────

class TestDivideRemainder:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. DIVREM.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-DIVIDEND   PIC S9(5).\n"
        "       01  WS-DIVISOR    PIC S9(5).\n"
        "       01  WS-QUOTIENT   PIC S9(5).\n"
        "       01  WS-REMAINDER  PIC S9(5).\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           MOVE -17 TO WS-DIVIDEND.\n"
        "           MOVE 5 TO WS-DIVISOR.\n"
        "           DIVIDE WS-DIVIDEND BY WS-DIVISOR\n"
        "               GIVING WS-QUOTIENT\n"
        "               REMAINDER WS-REMAINDER.\n"
        "           STOP RUN.\n"
    )

    def test_remainder_formula_in_code(self):
        """Generated code must NOT use Python % for remainder."""
        code = _generate(self.SOURCE)
        # Should not contain the naive modulo pattern
        assert "%" not in code.split("# ")[0]  # ignore comments

    def test_remainder_negative_dividend(self):
        """DIVIDE -17 BY 5: quotient=-3, remainder=-2 (COBOL truncation)."""
        from decimal import Decimal
        code = _generate(self.SOURCE)
        ns = {}
        exec(code, ns)
        ns["ws_dividend"].store(Decimal("-17"))
        ns["ws_divisor"].store(Decimal("5"))
        ns["para_main_para"]()
        assert int(ns["ws_quotient"].value) == -3
        assert int(ns["ws_remainder"].value) == -2


# ── 43. OCCURS with subscript access (simple ADD) ────────────

class TestOccursSimpleSubscript:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. OCCURSADD.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-TABLE.\n"
        "           05  WS-AMOUNT  PIC S9(9)V99 COMP-3\n"
        "                   OCCURS 12 TIMES.\n"
        "       01  WS-TOTAL      PIC S9(11)V99 COMP-3.\n"
        "       01  WS-IDX        PIC 9(2).\n"
        "       PROCEDURE DIVISION.\n"
        "       0000-MAIN.\n"
        "           MOVE 0 TO WS-TOTAL.\n"
        "           PERFORM 1000-SUM\n"
        "               VARYING WS-IDX FROM 1 BY 1\n"
        "               UNTIL WS-IDX > 12.\n"
        "           STOP RUN.\n"
        "       1000-SUM.\n"
        "           ADD WS-AMOUNT(WS-IDX) TO WS-TOTAL.\n"
    )

    def test_occurs_emits_list(self):
        code = _generate(self.SOURCE)
        assert "ws_amount = [CobolDecimal(" in code
        assert "range(12)" in code

    def test_subscript_access_in_add(self):
        code = _generate(self.SOURCE)
        assert "ws_amount[int(ws_idx.value) - 1]" in code

    def test_perform_varying_loop(self):
        code = _generate(self.SOURCE)
        assert "ws_idx.store(Decimal('1'))" in code
        assert "while not (" in code

    def test_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")


# ── 44. OCCURS with MOVE subscript target ──────────────────────

class TestOccursMoveTarget:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. OCCURSMOV.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-TABLE.\n"
        "           05  WS-ITEM  PIC S9(5)V99\n"
        "                   OCCURS 5 TIMES.\n"
        "       01  WS-IDX   PIC 9(2).\n"
        "       01  WS-VAL   PIC S9(5)V99.\n"
        "       PROCEDURE DIVISION.\n"
        "       0000-MAIN.\n"
        "           MOVE 100 TO WS-ITEM(3).\n"
        "           MOVE WS-ITEM(3) TO WS-VAL.\n"
        "           STOP RUN.\n"
    )

    def test_move_to_subscripted(self):
        code = _generate(self.SOURCE)
        assert "ws_item[2].store(Decimal('100'))" in code

    def test_move_from_subscripted(self):
        code = _generate(self.SOURCE)
        assert "ws_item[2].value" in code

    def test_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")


# ── 45. OCCURS with MULTIPLY subscript ────────────────────────

class TestOccursMultiply:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. OCCURSMUL.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-QTY    PIC 9(5) OCCURS 10 TIMES.\n"
        "       01  WS-PRICE  PIC S9(7)V99 OCCURS 10 TIMES.\n"
        "       01  WS-TOTAL  PIC S9(9)V99 COMP-3.\n"
        "       01  WS-IDX   PIC 9(2).\n"
        "       PROCEDURE DIVISION.\n"
        "       0000-MAIN.\n"
        "           MULTIPLY WS-QTY(WS-IDX) BY WS-PRICE(WS-IDX)\n"
        "               GIVING WS-TOTAL.\n"
        "           STOP RUN.\n"
    )

    def test_subscripted_multiply(self):
        code = _generate(self.SOURCE)
        assert "ws_qty[int(ws_idx.value) - 1]" in code
        assert "ws_price[int(ws_idx.value) - 1]" in code

    def test_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")


# ── 46. OCCURS in IF condition ────────────────────────────────

class TestOccursInCondition:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. OCCURSIF.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-AMT    PIC S9(9)V99 OCCURS 12 TIMES.\n"
        "       01  WS-IDX    PIC 9(2).\n"
        "       01  WS-HIGH   PIC S9(9)V99.\n"
        "       PROCEDURE DIVISION.\n"
        "       0000-MAIN.\n"
        "           IF WS-AMT(WS-IDX) > WS-HIGH\n"
        "               MOVE WS-AMT(WS-IDX) TO WS-HIGH\n"
        "           END-IF.\n"
        "           STOP RUN.\n"
    )

    def test_subscript_in_if_condition(self):
        code = _generate(self.SOURCE)
        assert "ws_amt[int(ws_idx.value) - 1].value" in code

    def test_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")


# ── MULTIPLY A BY <literal> (ANTLR grammar gap) ──────────

class TestMultiplyByLiteralInIf:
    """MULTIPLY A BY 2 (no GIVING) inside IF — ANTLR Format 1 drops the literal."""
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. MULLIT.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-FEE   PIC S9(5)V99.\n"
        "       01  WS-FLAG  PIC 9.\n"
        "       PROCEDURE DIVISION.\n"
        "       0000-MAIN.\n"
        "           MOVE 100 TO WS-FEE.\n"
        "           IF WS-FLAG = 1\n"
        "               MULTIPLY WS-FEE BY 2\n"
        "           END-IF.\n"
        "           STOP RUN.\n"
    )

    def test_no_manual_review(self):
        code = _generate(self.SOURCE)
        assert "MANUAL REVIEW" not in code

    def test_multiply_emits_store(self):
        code = _generate(self.SOURCE)
        assert "ws_fee.store(ws_fee.value * Decimal('2'))" in code

    def test_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")


class TestMultiplyByDecimalLiteralInIf:
    """MULTIPLY A BY 1.5 (decimal literal) inside IF."""
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. MULDEC.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-PAY   PIC S9(7)V99.\n"
        "       01  WS-HOURS PIC 9(3).\n"
        "       PROCEDURE DIVISION.\n"
        "       0000-MAIN.\n"
        "           MOVE 500 TO WS-PAY.\n"
        "           IF WS-HOURS > 40\n"
        "               MULTIPLY WS-PAY BY 1.5\n"
        "           END-IF.\n"
        "           STOP RUN.\n"
    )

    def test_no_manual_review(self):
        code = _generate(self.SOURCE)
        assert "MANUAL REVIEW" not in code

    def test_multiply_emits_store(self):
        code = _generate(self.SOURCE)
        assert "ws_pay.store(ws_pay.value * Decimal('1.5'))" in code

    def test_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")


# ── FUNCTION keyword tests ────────────────────────────────────

class TestFunctionLength:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. FUNCLEN.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-NAME  PIC X(20).\n"
        "       01  WS-LEN   PIC 9(5).\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           COMPUTE WS-LEN = FUNCTION LENGTH(WS-NAME).\n"
        "           STOP RUN.\n"
    )

    def test_emits_cobol_length(self):
        code = _generate(self.SOURCE)
        assert "_cobol_length" in code

    def test_no_manual_review(self):
        code = _generate(self.SOURCE)
        assert "MANUAL REVIEW" not in code

    def test_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")


class TestFunctionMax:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. FUNCMAX.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-A     PIC S9(5)V99.\n"
        "       01  WS-B     PIC S9(5)V99.\n"
        "       01  WS-BIG   PIC S9(5)V99.\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           COMPUTE WS-BIG = FUNCTION MAX(WS-A, WS-B).\n"
        "           STOP RUN.\n"
    )

    def test_emits_cobol_max(self):
        code = _generate(self.SOURCE)
        assert "_cobol_max" in code

    def test_comma_separates_args(self):
        code = _generate(self.SOURCE)
        assert "ws_a.value," in code or "_cobol_max(ws_a.value, ws_b.value)" in code

    def test_no_manual_review(self):
        code = _generate(self.SOURCE)
        assert "MANUAL REVIEW" not in code

    def test_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")


class TestFunctionMin:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. FUNCMIN.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-A      PIC S9(5)V99.\n"
        "       01  WS-B      PIC S9(5)V99.\n"
        "       01  WS-SMALL  PIC S9(5)V99.\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           COMPUTE WS-SMALL = FUNCTION MIN(WS-A, WS-B).\n"
        "           STOP RUN.\n"
    )

    def test_emits_cobol_min(self):
        code = _generate(self.SOURCE)
        assert "_cobol_min" in code

    def test_no_manual_review(self):
        code = _generate(self.SOURCE)
        assert "MANUAL REVIEW" not in code

    def test_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")


class TestFunctionCurrentDate:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. FUNCDATE.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-TIMESTAMP  PIC X(21).\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           MOVE FUNCTION CURRENT-DATE TO WS-TIMESTAMP.\n"
        "           STOP RUN.\n"
    )

    def test_emits_cobol_current_date(self):
        code = _generate(self.SOURCE)
        assert "_cobol_current_date()" in code

    def test_no_manual_review(self):
        code = _generate(self.SOURCE)
        assert "MANUAL REVIEW" not in code

    def test_placeholder_not_datetime_now(self):
        """Must NOT call datetime.now() — deterministic placeholder."""
        code = _generate(self.SOURCE)
        assert "datetime.now" not in code

    def test_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")


class TestFunctionUpperCase:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. FUNCUPPER.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-NAME  PIC X(20).\n"
        "       01  WS-UP    PIC X(20).\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           COMPUTE WS-UP = FUNCTION UPPER-CASE(WS-NAME).\n"
        "           STOP RUN.\n"
    )

    def test_emits_cobol_upper(self):
        code = _generate(self.SOURCE)
        assert "_cobol_upper" in code

    def test_no_manual_review(self):
        code = _generate(self.SOURCE)
        assert "MANUAL REVIEW" not in code

    def test_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")


class TestFunctionAbs:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. FUNCABS.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-NUM  PIC S9(5)V99.\n"
        "       01  WS-ABS  PIC S9(5)V99.\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           COMPUTE WS-ABS = FUNCTION ABS(WS-NUM).\n"
        "           STOP RUN.\n"
    )

    def test_emits_cobol_abs(self):
        code = _generate(self.SOURCE)
        assert "_cobol_abs" in code

    def test_no_manual_review(self):
        code = _generate(self.SOURCE)
        assert "MANUAL REVIEW" not in code

    def test_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")


class TestFunctionMod:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. FUNCMOD.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-A    PIC 9(5).\n"
        "       01  WS-B    PIC 9(5).\n"
        "       01  WS-MOD  PIC 9(5).\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           COMPUTE WS-MOD = FUNCTION MOD(WS-A, WS-B).\n"
        "           STOP RUN.\n"
    )

    def test_emits_cobol_mod(self):
        code = _generate(self.SOURCE)
        assert "_cobol_mod" in code

    def test_no_manual_review(self):
        code = _generate(self.SOURCE)
        assert "MANUAL REVIEW" not in code

    def test_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")


class TestFunctionUnknownManualReview:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. FUNCUNK.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-A  PIC 9(5).\n"
        "       01  WS-B  PIC 9(5).\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           COMPUTE WS-B = FUNCTION ANNUITY(WS-A).\n"
        "           STOP RUN.\n"
    )

    def test_manual_review_flagged(self):
        code = _generate(self.SOURCE)
        assert "MANUAL REVIEW" in code


class TestFunctionIntegerRegression:
    """FUNCTION INTEGER must still work after changes."""
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. FUNCINT.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-AMT     PIC S9(7)V99.\n"
        "       01  WS-RESULT  PIC S9(7)V99.\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           COMPUTE WS-RESULT =\n"
        "               FUNCTION INTEGER(WS-AMT * 100) / 100.\n"
        "           STOP RUN.\n"
    )

    def test_emits_int(self):
        code = _generate(self.SOURCE)
        assert "int(" in code or "int (" in code

    def test_no_manual_review(self):
        code = _generate(self.SOURCE)
        assert "MANUAL REVIEW" not in code

    def test_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")


class TestComputeNoFunctionRegression:
    """Plain COMPUTE without FUNCTION must still work."""
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. NOFUNC.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-A  PIC S9(5)V99.\n"
        "       01  WS-B  PIC S9(5)V99.\n"
        "       01  WS-C  PIC S9(5)V99.\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           COMPUTE WS-C = WS-A + WS-B * 2.\n"
        "           STOP RUN.\n"
    )

    def test_emits_store(self):
        code = _generate(self.SOURCE)
        assert "ws_c.store(" in code

    def test_no_function_helpers(self):
        code = _generate(self.SOURCE)
        assert "_cobol_length" not in code
        assert "_cobol_max" not in code

    def test_no_manual_review(self):
        code = _generate(self.SOURCE)
        assert "MANUAL REVIEW" not in code

    def test_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")


# ── Compile failure bug fixes ─────────────────────────────────

class TestMRFallbackCompiles:
    """Bug 1: MANUAL REVIEW inline comment must not break if/elif syntax."""
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. MRFALL.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-A     PIC 9(3).\n"
        "       01  WS-B     PIC 9(3).\n"
        "       01  WS-FLAG  PIC 9(1).\n"
        "           88 FLAG-ON  VALUE 1.\n"
        "           88 FLAG-OFF VALUE 0.\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           IF FLAG-ON OR FLAG-OFF OR WS-A > WS-B\n"
        "               MOVE 1 TO WS-FLAG\n"
        "           END-IF.\n"
        "           STOP RUN.\n"
    )

    def test_compiles(self):
        """Generated code must compile even with MANUAL REVIEW fallback."""
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")

    def test_no_broken_if_true_hash(self):
        """if True # ... is invalid Python — must be if True: with comment on separate line."""
        code = _generate(self.SOURCE)
        for line in code.splitlines():
            stripped = line.strip()
            if stripped.startswith("if ") or stripped.startswith("elif "):
                assert stripped.endswith(":"), f"Missing colon: {stripped}"


class TestCommentOnlyBodyCompiles:
    """Bug 2: Comment-only IF/ELIF body must include pass."""
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. CMTONLY.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-CODE  PIC 9(3).\n"
        "       01  WS-AMT   PIC S9(7)V99.\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           EVALUATE TRUE\n"
        "               WHEN WS-CODE = 1\n"
        "                   MOVE 100 TO WS-AMT\n"
        "               WHEN WS-CODE = 2\n"
        "                   MOVE 200 TO WS-AMT\n"
        "               WHEN OTHER\n"
        "                   MOVE 0 TO WS-AMT\n"
        "           END-EVALUATE.\n"
        "           STOP RUN.\n"
    )

    def test_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")


class TestPerformVaryingInIfBranch:
    """Bug 3: PERFORM VARYING inside IF must emit while loop, not garbled para call."""
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. PVARYIF.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-IDX   PIC 9(3).\n"
        "       01  WS-MAX   PIC 9(3).\n"
        "       01  WS-FLAG  PIC 9(1).\n"
        "       01  WS-TOTAL PIC S9(7)V99.\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           IF WS-FLAG = 1\n"
        "               PERFORM 1000-CALC VARYING WS-IDX\n"
        "                   FROM 1 BY 1 UNTIL WS-IDX > WS-MAX\n"
        "           END-IF.\n"
        "           STOP RUN.\n"
        "       1000-CALC.\n"
        "           ADD WS-IDX TO WS-TOTAL.\n"
    )

    def test_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")

    def test_emits_while_loop(self):
        code = _generate(self.SOURCE)
        assert "while not" in code

    def test_emits_loop_init_and_increment(self):
        code = _generate(self.SOURCE)
        assert "ws_idx.store(" in code


# ── PERFORM VARYING negative BY (decrement loops) ─────────────

class TestPerformVaryingNegativeBy:
    """PERFORM VARYING FROM 10 BY -1 UNTIL < 1 → decrement loop."""
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. DECLOOP.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-I      PIC 9(3).\n"
        "       01  WS-TOTAL  PIC 9(5).\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           MOVE 0 TO WS-TOTAL.\n"
        "           PERFORM 1000-ADD-UP VARYING WS-I\n"
        "               FROM 10 BY -1 UNTIL WS-I < 1.\n"
        "           STOP RUN.\n"
        "       1000-ADD-UP.\n"
        "           ADD WS-I TO WS-TOTAL.\n"
    )

    def test_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")

    def test_negative_by_in_code(self):
        """Generated code should contain Decimal('-1') for BY -1."""
        code = _generate(self.SOURCE)
        assert "Decimal('-1')" in code or "-1" in code

    def test_executes_correct_sum(self):
        """10 + 9 + 8 + ... + 1 = 55."""
        code = _generate(self.SOURCE)
        ns = {}
        exec(code, ns)
        ns["main"]()
        from decimal import Decimal
        assert ns["ws_total"].value == Decimal("55")


class TestPerformVaryingPositiveRegression:
    """Normal PERFORM VARYING FROM 1 BY 1 still works after negative BY support."""
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. INCLOOP.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-I      PIC 9(3).\n"
        "       01  WS-TOTAL  PIC 9(5).\n"
        "       PROCEDURE DIVISION.\n"
        "       MAIN-PARA.\n"
        "           MOVE 0 TO WS-TOTAL.\n"
        "           PERFORM 1000-ADD-UP VARYING WS-I\n"
        "               FROM 1 BY 1 UNTIL WS-I > 5.\n"
        "           STOP RUN.\n"
        "       1000-ADD-UP.\n"
        "           ADD WS-I TO WS-TOTAL.\n"
    )

    def test_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")

    def test_executes_correct_sum(self):
        """1 + 2 + 3 + 4 + 5 = 15."""
        code = _generate(self.SOURCE)
        ns = {}
        exec(code, ns)
        ns["main"]()
        from decimal import Decimal
        assert ns["ws_total"].value == Decimal("15")


# ── INITIALIZE: group hierarchy, REDEFINES skip, FILLER skip ──


class TestInitializeGroupMixed:
    """INITIALIZE on group with mixed PIC X + PIC 9 children."""

    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. TESTINIT.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-REC.\n"
        "           05  WS-NAME   PIC X(10).\n"
        "           05  WS-AMT    PIC 9(5)V99.\n"
        "       PROCEDURE DIVISION.\n"
        "       0000-MAIN.\n"
        "           MOVE 'HELLO' TO WS-NAME.\n"
        "           MOVE 123.45 TO WS-AMT.\n"
        "           INITIALIZE WS-REC.\n"
        "           STOP RUN.\n"
    )

    def test_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")

    def test_strings_reset_numerics_zeroed(self):
        """Strings → SPACES, numerics → Decimal('0')."""
        code = _generate(self.SOURCE)
        assert "ws_name = ' '" in code
        assert "ws_amt.store(Decimal('0'))" in code


class TestInitializeSkipsRedefines:
    """INITIALIZE must skip REDEFINES overlays."""

    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. TESTREDEFS.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-REC.\n"
        "           05  WS-CODE   PIC X(5).\n"
        "           05  WS-NUM    PIC 9(5).\n"
        "           05  WS-ALT    REDEFINES WS-NUM PIC X(5).\n"
        "       PROCEDURE DIVISION.\n"
        "       0000-MAIN.\n"
        "           INITIALIZE WS-REC.\n"
        "           STOP RUN.\n"
    )

    def test_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")

    def test_redefines_not_initialized(self):
        """WS-ALT (REDEFINES) must not appear in INITIALIZE output."""
        code = _generate(self.SOURCE)
        assert "ws_code = ' '" in code or "ws_code" in code
        assert "ws_num" in code
        assert "ws_alt" not in code.split("# INITIALIZE")[1].split("\n# ")[0] if "# INITIALIZE" in code else "ws_alt" not in code


class TestInitializeNestedGroup:
    """INITIALIZE on group with nested subgroup."""

    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. TESTNEST.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-OUTER.\n"
        "           05  WS-A      PIC X(5).\n"
        "           05  WS-INNER.\n"
        "               10  WS-B  PIC 9(3).\n"
        "               10  WS-C  PIC X(2).\n"
        "       PROCEDURE DIVISION.\n"
        "       0000-MAIN.\n"
        "           INITIALIZE WS-OUTER.\n"
        "           STOP RUN.\n"
    )

    def test_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")

    def test_all_leaves_initialized(self):
        """All leaf children (WS-A, WS-B, WS-C) must be initialized."""
        code = _generate(self.SOURCE)
        assert "ws_a = ' '" in code
        assert "ws_b.store(Decimal('0'))" in code
        assert "ws_c = ' '" in code


# ── GROUP MOVE — byte-level copy tests ───────────────────────

class TestGroupMoveCopiesBytes:
    """MOVE GROUP-A TO GROUP-B should emit byte-level copy, not field-by-field."""

    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. GRPMOV.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-SRC.\n"
        "           05  WS-S1  PIC X(5).\n"
        "           05  WS-S2  PIC 9(3).\n"
        "       01  WS-TGT.\n"
        "           05  WS-T1  PIC X(5).\n"
        "           05  WS-T2  PIC 9(3).\n"
        "       PROCEDURE DIVISION.\n"
        "       0000-MAIN.\n"
        "           MOVE WS-SRC TO WS-TGT.\n"
        "           STOP RUN.\n"
    )

    def test_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")

    def test_byte_level_concat_and_slice(self):
        """Should concat source children, then slice into target children."""
        code = _generate(self.SOURCE)
        assert "_grp =" in code
        assert "_grp_padded" in code
        assert "ws_t1 = _grp_padded[0:5]" in code
        assert "ws_t2.store(Decimal(_grp_padded[5:8]" in code


class TestGroupMoveTruncates:
    """Longer source group → truncated to target length."""

    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. GRPTRUNC.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-LONG.\n"
        "           05  WS-L1  PIC X(10).\n"
        "           05  WS-L2  PIC X(10).\n"
        "       01  WS-SHORT.\n"
        "           05  WS-S1  PIC X(8).\n"
        "       PROCEDURE DIVISION.\n"
        "       0000-MAIN.\n"
        "           MOVE WS-LONG TO WS-SHORT.\n"
        "           STOP RUN.\n"
    )

    def test_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")

    def test_truncation(self):
        """Target is 8 bytes; source is 20. Should truncate via [:8].ljust(8)."""
        code = _generate(self.SOURCE)
        assert "_grp_padded = _grp[:8].ljust(8)" in code
        assert "ws_s1 = _grp_padded[0:8]" in code


class TestGroupMovePads:
    """Shorter source group → space-padded to target length."""

    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. GRPPAD.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-TINY.\n"
        "           05  WS-T1  PIC X(3).\n"
        "       01  WS-BIG.\n"
        "           05  WS-B1  PIC X(5).\n"
        "           05  WS-B2  PIC X(5).\n"
        "       PROCEDURE DIVISION.\n"
        "       0000-MAIN.\n"
        "           MOVE WS-TINY TO WS-BIG.\n"
        "           STOP RUN.\n"
    )

    def test_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")

    def test_padding(self):
        """Target is 10 bytes; source is 3. Should pad via [:10].ljust(10)."""
        code = _generate(self.SOURCE)
        assert "_grp_padded = _grp[:10].ljust(10)" in code
        assert "ws_b1 = _grp_padded[0:5]" in code
        assert "ws_b2 = _grp_padded[5:10]" in code


class TestElementaryMoveUnchanged:
    """Normal elementary MOVE must NOT emit group-move logic."""

    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. ELEMMOV.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-A  PIC 9(5).\n"
        "       01  WS-B  PIC 9(5).\n"
        "       PROCEDURE DIVISION.\n"
        "       0000-MAIN.\n"
        "           MOVE WS-A TO WS-B.\n"
        "           STOP RUN.\n"
    )

    def test_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")

    def test_no_group_logic(self):
        """Should use .store(), not _grp byte concat."""
        code = _generate(self.SOURCE)
        assert "ws_b.store(ws_a.value)" in code
        assert "_grp" not in code


# ── INITIALIZE: group with mixed PIC X + PIC 9 children ────────

class TestInitializeGroupMixed:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. TESTINIT.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-REC.\n"
        "           05  WS-NAME   PIC X(10).\n"
        "           05  WS-AMT    PIC 9(5)V99.\n"
        "       PROCEDURE DIVISION.\n"
        "       0000-MAIN.\n"
        "           INITIALIZE WS-REC.\n"
        "           STOP RUN.\n"
    )

    def test_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")

    def test_string_child_gets_spaces(self):
        code = _generate(self.SOURCE)
        assert "ws_name = ''" in code or "ws_name = ' '" in code

    def test_numeric_child_gets_zeros(self):
        code = _generate(self.SOURCE)
        assert "ws_amt.store(Decimal('0'))" in code


# ── INITIALIZE: REDEFINES child must be skipped ─────────────────

class TestInitializeSkipsRedefines:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. TESTINIT2.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-REC.\n"
        "           05  WS-CODE   PIC X(5).\n"
        "           05  WS-NUM    PIC 9(5).\n"
        "           05  WS-ALT    REDEFINES WS-NUM PIC X(5).\n"
        "       PROCEDURE DIVISION.\n"
        "       0000-MAIN.\n"
        "           INITIALIZE WS-REC.\n"
        "           STOP RUN.\n"
    )

    def test_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")

    def test_redefines_excluded(self):
        code = _generate(self.SOURCE)
        # Look only at lines inside the INITIALIZE block
        init_lines = [l.strip() for l in code.split("\n")
                      if "INITIALIZE" in l or "ws_code" in l or "ws_num" in l or "ws_alt =" in l
                      or "ws_alt.store" in l]
        init_block = "\n".join(init_lines)
        assert "ws_code" in init_block, "WS-CODE should be initialized"
        assert "ws_num" in init_block, "WS-NUM should be initialized"
        # WS-ALT (REDEFINES) must NOT have its own init line
        assert "ws_alt =" not in code, "WS-ALT (REDEFINES) should NOT be initialized"
        assert "ws_alt.store" not in code, "WS-ALT (REDEFINES) should NOT be initialized"


# ── INITIALIZE: nested subgroup children should be initialized ──

class TestInitializeNestedGroup:
    SOURCE = (
        "       IDENTIFICATION DIVISION.\n"
        "       PROGRAM-ID. TESTINIT3.\n"
        "       DATA DIVISION.\n"
        "       WORKING-STORAGE SECTION.\n"
        "       01  WS-OUTER.\n"
        "           05  WS-A      PIC X(5).\n"
        "           05  WS-INNER.\n"
        "               10  WS-B  PIC 9(3).\n"
        "               10  WS-C  PIC X(2).\n"
        "       PROCEDURE DIVISION.\n"
        "       0000-MAIN.\n"
        "           INITIALIZE WS-OUTER.\n"
        "           STOP RUN.\n"
    )

    def test_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")

    def test_all_leaf_children_initialized(self):
        code = _generate(self.SOURCE)
        assert "ws_a" in code, "WS-A should be initialized"
        assert "ws_b" in code, "WS-B should be initialized"
        assert "ws_c" in code, "WS-C should be initialized"


# ══════════════════════════════════════════════════════════════════════
# Item 18: Nested Programs — detect + emit MR
# ══════════════════════════════════════════════════════════════════════


class TestNestedPrograms:
    NESTED_SOURCE = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. MAIN-PGM.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-X  PIC 9(3).
       PROCEDURE DIVISION.
       MAIN-PARA.
           MOVE 1 TO WS-X.
           STOP RUN.
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SUB-PGM.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-Y  PIC 9(3).
       PROCEDURE DIVISION.
       SUB-PARA.
           MOVE 2 TO WS-Y.
           STOP RUN.
       END PROGRAM SUB-PGM.
       END PROGRAM MAIN-PGM.
"""

    def test_nested_program_emits_compiler_warning(self):
        result = generate_python_module(analyze_cobol(self.NESTED_SOURCE))
        warnings = result.get("compiler_warnings", [])
        assert any("PROGRAM-ID" in w for w in warnings)

    def test_nested_program_emits_mr_flag(self):
        result = generate_python_module(analyze_cobol(self.NESTED_SOURCE))
        mr = result.get("mr_flags", [])
        assert any(f.get("construct") == "NESTED PROGRAMS" for f in mr)


# ══════════════════════════════════════════════════════════════════════
# Item 16: INSPECT CONVERTING BEFORE/AFTER + length guard
# ══════════════════════════════════════════════════════════════════════


class TestInspectConvertingBeforeAfter:
    BEFORE_SOURCE = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CONVBA.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-DATA              PIC X(20).
       PROCEDURE DIVISION.
       MAIN-PARA.
           MOVE 'hello.WORLD' TO WS-DATA.
           INSPECT WS-DATA CONVERTING 'abcdefghijklmnopqrstuvwxyz'
               TO 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' BEFORE INITIAL '.'.
           STOP RUN.
"""
    AFTER_SOURCE = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CONVAF.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-DATA              PIC X(20).
       PROCEDURE DIVISION.
       MAIN-PARA.
           MOVE 'hello.world' TO WS-DATA.
           INSPECT WS-DATA CONVERTING 'abcdefghijklmnopqrstuvwxyz'
               TO 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' AFTER INITIAL '.'.
           STOP RUN.
"""

    def test_converting_before_emits_translate(self):
        code = _generate(self.BEFORE_SOURCE)
        assert "translate(_tbl)" in code
        assert "find(" in code
        assert "MANUAL REVIEW" not in code or "CONVERTING" not in code.split("MANUAL REVIEW")[0]

    def test_converting_after_emits_translate(self):
        code = _generate(self.AFTER_SOURCE)
        assert "translate(_tbl)" in code
        assert "find(" in code

    def test_converting_before_compiles(self):
        code = _generate(self.BEFORE_SOURCE)
        compile(code, "<test>", "exec")

    def test_converting_after_compiles(self):
        code = _generate(self.AFTER_SOURCE)
        compile(code, "<test>", "exec")


    def test_single_program_no_warning(self):
        source = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SOLO-PGM.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-X  PIC 9(3).
       PROCEDURE DIVISION.
       MAIN-PARA.
           STOP RUN.
"""
        result = generate_python_module(analyze_cobol(source))
        warnings = result.get("compiler_warnings", [])
        assert not any("PROGRAM-ID" in w for w in warnings)
        mr = result.get("mr_flags", [])
        assert not any(f.get("construct") == "NESTED PROGRAMS" for f in mr)


# ══════════════════════════════════════════════════════════════════════
# Item 17: INSPECT REPLACING LEADING multi-char
# ══════════════════════════════════════════════════════════════════════


class TestInspectReplacingLeadingMultiChar:
    SOURCE = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. REPLD.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-DATA              PIC X(20).
       PROCEDURE DIVISION.
       MAIN-PARA.
           MOVE '0000001234' TO WS-DATA.
           INSPECT WS-DATA REPLACING LEADING '00' BY '  '.
           STOP RUN.
"""

    def test_leading_multi_char_no_mr(self):
        code = _generate(self.SOURCE)
        assert "MANUAL REVIEW" not in code

    def test_leading_multi_char_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")

    def test_leading_multi_char_emits_while_loop(self):
        code = _generate(self.SOURCE)
        assert "while" in code
        assert "_i" in code


# ══════════════════════════════════════════════════════════════════════
# Item 21: ACCEPT FROM ENVIRONMENT
# ══════════════════════════════════════════════════════════════════════


class TestAcceptFromEnvironment:
    ENV_NAME_SOURCE = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. ENVNAME.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-ENV-NAME          PIC X(30).
       01  WS-ENV-VAL           PIC X(50).
       PROCEDURE DIVISION.
       MAIN-PARA.
           MOVE 'PATH' TO WS-ENV-NAME.
           ACCEPT WS-ENV-NAME FROM ENVIRONMENT-NAME.
           ACCEPT WS-ENV-VAL FROM ENVIRONMENT-VALUE.
           STOP RUN.
"""

    def test_env_name_emits_env_name_tracker(self):
        code = _generate(self.ENV_NAME_SOURCE)
        assert "_env_name" in code
        assert "ENVIRONMENT-NAME" in code or "ENVIRONMENT_NAME" in code

    def test_env_value_emits_os_environ(self):
        code = _generate(self.ENV_NAME_SOURCE)
        assert "_os.environ.get" in code or "os.environ.get" in code

    def test_env_preamble_has_import_os(self):
        code = _generate(self.ENV_NAME_SOURCE)
        assert "import os" in code

    def test_env_accept_compiles(self):
        code = _generate(self.ENV_NAME_SOURCE)
        compile(code, "<test>", "exec")


# ══════════════════════════════════════════════════════════════════════
# FUNCTION EXP and SQRT
# ══════════════════════════════════════════════════════════════════════


class TestFunctionExpSqrt:
    EXP_SOURCE = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. EXPTEST.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT             PIC S9(5)V9(4) COMP-3.
       01  WS-RESULT            PIC S9(5)V9(8) COMP-3.
       PROCEDURE DIVISION.
       MAIN-PARA.
           MOVE 1.0 TO WS-INPUT.
           COMPUTE WS-RESULT = FUNCTION EXP(WS-INPUT).
           STOP RUN.
"""
    SQRT_SOURCE = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SQRTTEST.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT             PIC S9(9)V9(4) COMP-3.
       01  WS-RESULT            PIC S9(9)V9(8) COMP-3.
       PROCEDURE DIVISION.
       MAIN-PARA.
           MOVE 144.0 TO WS-INPUT.
           COMPUTE WS-RESULT = FUNCTION SQRT(WS-INPUT).
           STOP RUN.
"""

    def test_exp_emits_helper(self):
        code = _generate(self.EXP_SOURCE)
        assert "_cobol_exp" in code
        assert "MANUAL REVIEW" not in code

    def test_exp_compiles(self):
        code = _generate(self.EXP_SOURCE)
        compile(code, "<test>", "exec")

    def test_exp_emits_compiler_warning(self):
        result = generate_python_module(analyze_cobol(self.EXP_SOURCE))
        warnings = result.get("compiler_warnings", [])
        assert any("EXP" in w and "IEEE 754" in w for w in warnings)

    def test_sqrt_emits_helper(self):
        code = _generate(self.SQRT_SOURCE)
        assert "_cobol_sqrt" in code
        assert "MANUAL REVIEW" not in code

    def test_sqrt_compiles(self):
        code = _generate(self.SQRT_SOURCE)
        compile(code, "<test>", "exec")

    def test_sqrt_no_exp_warning(self):
        result = generate_python_module(analyze_cobol(self.SQRT_SOURCE))
        warnings = result.get("compiler_warnings", [])
        assert not any("IEEE 754" in w for w in warnings)


# ══════════════════════════════════════════════════════════════════════
# SET 88-level with subscript
# ══════════════════════════════════════════════════════════════════════


class TestSet88WithSubscript:
    SOURCE = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SETIDX.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-TABLE.
           05  WS-ENTRY OCCURS 5.
               10  WS-STATUS    PIC X(1).
                   88  WS-PASS  VALUE 'Y'.
                   88  WS-FAIL  VALUE 'N'.
       PROCEDURE DIVISION.
       MAIN-PARA.
           SET WS-PASS(1) TO TRUE.
           SET WS-FAIL(3) TO TRUE.
           STOP RUN.
"""

    def test_set_subscript_no_mr(self):
        code = _generate(self.SOURCE)
        # Should NOT flag MANUAL REVIEW for SET with subscript
        lines_with_mr = [l for l in code.split('\n') if 'MANUAL REVIEW' in l and 'SET' in l]
        assert len(lines_with_mr) == 0

    def test_set_subscript_compiles(self):
        code = _generate(self.SOURCE)
        compile(code, "<test>", "exec")
