"""Tests for dead_code_analyzer.py — paragraph-level reachability."""

import os
import sys
import pytest

# Ensure project root is on the path
sys.path.insert(0, os.path.dirname(__file__))

from dead_code_analyzer import analyze_dead_code


# ── Helpers ──────────────────────────────────────────────────────


def _make_parser_output(
    paragraphs=None,
    paragraph_lines=None,
    control_flow=None,
    gotos=None,
    stops=None,
    exec_dependencies=None,
):
    """Build a minimal parser_output dict for testing."""
    paras = paragraphs or []
    return {
        "success": True,
        "paragraphs": paras,
        "paragraph_lines": paragraph_lines or {p: i * 10 for i, p in enumerate(paras)},
        "control_flow": control_flow or [],
        "gotos": gotos or [],
        "stops": stops or [],
        "exec_dependencies": exec_dependencies or [],
    }


# ── Unit Tests ───────────────────────────────────────────────────


class TestBasicCases:

    def test_empty_program(self):
        """No paragraphs → zeros."""
        result = analyze_dead_code(_make_parser_output())
        assert result["total_paragraphs"] == 0
        assert result["reachable_paragraphs"] == 0
        assert result["dead_percentage"] == 0.0
        assert result["unreachable_paragraphs"] == []
        assert result["has_alter"] is False

    def test_single_paragraph(self):
        """One paragraph → 100% reachable."""
        result = analyze_dead_code(_make_parser_output(
            paragraphs=["MAIN-PARA"],
        ))
        assert result["total_paragraphs"] == 1
        assert result["reachable_paragraphs"] == 1
        assert result["dead_percentage"] == 0.0
        assert result["unreachable_paragraphs"] == []

    def test_all_reachable_via_perform(self):
        """Entry performs all paragraphs → 0% dead."""
        result = analyze_dead_code(_make_parser_output(
            paragraphs=["MAIN", "CALC", "PRINT"],
            control_flow=[
                {"from": "MAIN", "to": "CALC", "line": 10, "statement": "PERFORM CALC"},
                {"from": "MAIN", "to": "PRINT", "line": 11, "statement": "PERFORM PRINT"},
            ],
            stops=[{"paragraph": "MAIN", "line": 12}],
        ))
        assert result["total_paragraphs"] == 3
        assert result["reachable_paragraphs"] == 3
        assert result["dead_percentage"] == 0.0

    def test_simple_dead_paragraph(self):
        """One paragraph never performed or fallen through to."""
        result = analyze_dead_code(_make_parser_output(
            paragraphs=["MAIN", "USED", "DEAD"],
            paragraph_lines={"MAIN": 5, "USED": 15, "DEAD": 25},
            control_flow=[
                {"from": "MAIN", "to": "USED", "line": 6, "statement": "PERFORM USED"},
            ],
            stops=[
                {"paragraph": "MAIN", "line": 7},
                {"paragraph": "USED", "line": 16},
            ],
        ))
        assert result["total_paragraphs"] == 3
        assert result["reachable_paragraphs"] == 2
        assert result["dead_percentage"] == pytest.approx(33.3, abs=0.1)
        assert len(result["unreachable_paragraphs"]) == 1
        assert result["unreachable_paragraphs"][0]["name"] == "DEAD"
        assert result["unreachable_paragraphs"][0]["line"] == 25


class TestGoTo:

    def test_goto_makes_reachable(self):
        """Paragraph reachable only via GO TO is not dead."""
        result = analyze_dead_code(_make_parser_output(
            paragraphs=["MAIN", "ERROR-HANDLER"],
            paragraph_lines={"MAIN": 5, "ERROR-HANDLER": 20},
            gotos=[{"paragraph": "MAIN", "targets": ["ERROR-HANDLER"], "depending_on": None, "line": 8}],
            stops=[
                {"paragraph": "MAIN", "line": 9},
                {"paragraph": "ERROR-HANDLER", "line": 22},
            ],
        ))
        assert result["reachable_paragraphs"] == 2
        assert result["dead_percentage"] == 0.0

    def test_goto_depending_on(self):
        """All GO TO DEPENDING ON targets are reachable."""
        result = analyze_dead_code(_make_parser_output(
            paragraphs=["MAIN", "PATH-A", "PATH-B", "PATH-C"],
            gotos=[
                {"paragraph": "MAIN", "targets": ["PATH-A", "PATH-B", "PATH-C"],
                 "depending_on": "WS-SELECTOR", "line": 8},
            ],
            stops=[{"paragraph": "MAIN", "line": 9}],
        ))
        assert result["reachable_paragraphs"] == 4
        assert result["dead_percentage"] == 0.0


class TestPerformThru:

    def test_perform_thru_range(self):
        """PERFORM A THRU C marks A, B, C all reachable."""
        result = analyze_dead_code(_make_parser_output(
            paragraphs=["MAIN", "STEP-A", "STEP-B", "STEP-C"],
            paragraph_lines={"MAIN": 5, "STEP-A": 10, "STEP-B": 15, "STEP-C": 20},
            control_flow=[
                # Parser produces two entries with same from+line for THRU
                {"from": "MAIN", "to": "STEP-A", "line": 6, "statement": "PERFORM STEP-A THRU STEP-C"},
                {"from": "MAIN", "to": "STEP-C", "line": 6, "statement": "PERFORM STEP-A THRU STEP-C"},
            ],
            stops=[{"paragraph": "MAIN", "line": 7}],
        ))
        assert result["reachable_paragraphs"] == 4
        assert result["dead_percentage"] == 0.0


class TestFallThrough:

    def test_fall_through_reachability(self):
        """Consecutive paragraphs reachable via fall-through (no GO TO/STOP)."""
        result = analyze_dead_code(_make_parser_output(
            paragraphs=["MAIN", "NEXT", "AFTER"],
            # MAIN has no STOP/GOTO → falls through to NEXT → falls through to AFTER
        ))
        assert result["reachable_paragraphs"] == 3
        assert result["dead_percentage"] == 0.0

    def test_stop_blocks_fall_through(self):
        """STOP RUN prevents fall-through to next paragraph."""
        result = analyze_dead_code(_make_parser_output(
            paragraphs=["MAIN", "REACHABLE", "DEAD"],
            paragraph_lines={"MAIN": 5, "REACHABLE": 15, "DEAD": 25},
            control_flow=[
                {"from": "MAIN", "to": "REACHABLE", "line": 6, "statement": "PERFORM REACHABLE"},
            ],
            stops=[
                {"paragraph": "MAIN", "line": 7},
                {"paragraph": "REACHABLE", "line": 18},
            ],
        ))
        assert result["reachable_paragraphs"] == 2
        assert len(result["unreachable_paragraphs"]) == 1
        assert result["unreachable_paragraphs"][0]["name"] == "DEAD"

    def test_goto_blocks_fall_through(self):
        """GO TO at end of paragraph prevents fall-through."""
        result = analyze_dead_code(_make_parser_output(
            paragraphs=["MAIN", "DEAD"],
            paragraph_lines={"MAIN": 5, "DEAD": 15},
            gotos=[{"paragraph": "MAIN", "targets": ["MAIN"], "depending_on": None, "line": 8}],
        ))
        assert result["reachable_paragraphs"] == 1
        assert result["unreachable_paragraphs"][0]["name"] == "DEAD"


class TestAdvanced:

    def test_indirect_reachability(self):
        """A → B → C: C is reachable from A."""
        result = analyze_dead_code(_make_parser_output(
            paragraphs=["A", "B", "C"],
            control_flow=[
                {"from": "A", "to": "B", "line": 5, "statement": "PERFORM B"},
                {"from": "B", "to": "C", "line": 15, "statement": "PERFORM C"},
            ],
            stops=[
                {"paragraph": "A", "line": 6},
                {"paragraph": "B", "line": 16},
                {"paragraph": "C", "line": 25},
            ],
        ))
        assert result["reachable_paragraphs"] == 3

    def test_cyclic_performs(self):
        """A ↔ B: both reachable despite cycle."""
        result = analyze_dead_code(_make_parser_output(
            paragraphs=["A", "B"],
            control_flow=[
                {"from": "A", "to": "B", "line": 5, "statement": "PERFORM B"},
                {"from": "B", "to": "A", "line": 15, "statement": "PERFORM A"},
            ],
        ))
        assert result["reachable_paragraphs"] == 2

    def test_multiple_dead_paragraphs(self):
        """Multiple unreachable paragraphs counted correctly."""
        result = analyze_dead_code(_make_parser_output(
            paragraphs=["MAIN", "DEAD1", "DEAD2", "DEAD3"],
            paragraph_lines={"MAIN": 5, "DEAD1": 15, "DEAD2": 25, "DEAD3": 35},
            stops=[{"paragraph": "MAIN", "line": 6}],
        ))
        assert result["total_paragraphs"] == 4
        assert result["reachable_paragraphs"] == 1
        assert result["dead_percentage"] == 75.0
        assert len(result["unreachable_paragraphs"]) == 3

    def test_dead_percentage_calculation(self):
        """Verify percentage math: 2 dead out of 8 = 25.0."""
        paras = [f"P{i}" for i in range(8)]
        # PERFORM P0-P5, stop there; P6, P7 are dead
        cflow = [{"from": paras[0], "to": paras[i], "line": i + 10, "statement": f"PERFORM {paras[i]}"}
                 for i in range(1, 6)]
        stops_list = [{"paragraph": p, "line": i * 10} for i, p in enumerate(paras)]
        result = analyze_dead_code(_make_parser_output(
            paragraphs=paras,
            control_flow=cflow,
            stops=stops_list,
        ))
        assert result["dead_percentage"] == 25.0

    def test_unreachable_sorted_by_line(self):
        """Unreachable paragraphs are sorted by line number."""
        result = analyze_dead_code(_make_parser_output(
            paragraphs=["MAIN", "DEAD-Z", "DEAD-A"],
            paragraph_lines={"MAIN": 5, "DEAD-Z": 30, "DEAD-A": 15},
            stops=[{"paragraph": "MAIN", "line": 6}],
        ))
        names = [p["name"] for p in result["unreachable_paragraphs"]]
        assert names == ["DEAD-A", "DEAD-Z"]

    def test_result_structure(self):
        """Verify all required keys are present."""
        result = analyze_dead_code(_make_parser_output(paragraphs=["MAIN"]))
        assert "unreachable_paragraphs" in result
        assert "total_paragraphs" in result
        assert "reachable_paragraphs" in result
        assert "dead_percentage" in result
        assert "has_alter" in result


class TestImplicitMain:

    def test_implicit_main_performs(self):
        """Paragraphs performed from implicit main section (from=None) are reachable."""
        result = analyze_dead_code(_make_parser_output(
            paragraphs=["CALC", "PRINT", "DEAD"],
            paragraph_lines={"CALC": 10, "PRINT": 20, "DEAD": 30},
            control_flow=[
                # Implicit main section performs
                {"from": None, "to": "CALC", "line": 5, "statement": "PERFORM CALC"},
                {"from": None, "to": "PRINT", "line": 6, "statement": "PERFORM PRINT"},
            ],
            stops=[
                {"paragraph": "CALC", "line": 12},
                {"paragraph": "PRINT", "line": 22},
            ],
        ))
        assert result["reachable_paragraphs"] == 2
        assert result["unreachable_paragraphs"][0]["name"] == "DEAD"

    def test_implicit_main_goto(self):
        """GO TO from implicit main section (paragraph=None) seeds reachability."""
        result = analyze_dead_code(_make_parser_output(
            paragraphs=["ENTRY", "DEAD"],
            paragraph_lines={"ENTRY": 10, "DEAD": 20},
            gotos=[{"paragraph": None, "targets": ["ENTRY"], "depending_on": None, "line": 5}],
            stops=[
                {"paragraph": "ENTRY", "line": 12},
            ],
        ))
        assert result["reachable_paragraphs"] == 1
        assert result["unreachable_paragraphs"][0]["name"] == "DEAD"


class TestAlterSafety:

    def test_alter_makes_all_reachable(self):
        """ALTER present → conservatively mark all paragraphs reachable."""
        result = analyze_dead_code(_make_parser_output(
            paragraphs=["MAIN", "APPARENTLY-DEAD"],
            paragraph_lines={"MAIN": 5, "APPARENTLY-DEAD": 15},
            stops=[{"paragraph": "MAIN", "line": 6}],
            exec_dependencies=[{"type": "ALTER", "line": 7, "paragraph": "MAIN"}],
        ))
        assert result["has_alter"] is True
        assert result["reachable_paragraphs"] == 2
        assert result["dead_percentage"] == 0.0
        assert result["unreachable_paragraphs"] == []


class TestIntegration:

    def test_demo_loan_interest(self):
        """Integration: parse DEMO_LOAN_INTEREST.cbl and verify dead code analysis."""
        demo_path = os.path.join(os.path.dirname(__file__), "DEMO_LOAN_INTEREST.cbl")
        if not os.path.exists(demo_path):
            pytest.skip("DEMO_LOAN_INTEREST.cbl not found")

        try:
            from cobol_analyzer_api import analyze_cobol
        except ImportError:
            pytest.skip("cobol_analyzer_api not available")

        with open(demo_path, "r") as f:
            cobol_source = f.read()

        parser_output = analyze_cobol(cobol_source)
        result = analyze_dead_code(parser_output)

        # Structure checks
        assert result["total_paragraphs"] > 0
        assert result["reachable_paragraphs"] > 0
        assert result["reachable_paragraphs"] <= result["total_paragraphs"]
        assert 0.0 <= result["dead_percentage"] <= 100.0
        assert isinstance(result["unreachable_paragraphs"], list)
        assert isinstance(result["has_alter"], bool)

        # Each unreachable entry has name + line
        for entry in result["unreachable_paragraphs"]:
            assert "name" in entry
            assert "line" in entry
