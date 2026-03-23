"""
test_dependency.py — CALL Dependency Crawler Tests

20 tests covering:
  - CALL statement detection (static, dynamic, USING parameters)
  - Dependency tree building (simple, chain, circular, unresolved)
  - LINKAGE SECTION parsing and parameter mapping
  - Multi-file analysis with aggregate results
  - End-to-end demo pipeline
  - Batch analysis with Python generation + cross-file CALL resolution

Run with:
    pytest test_dependency.py -v
"""

import os
import re

import pytest

from dependency_crawler import (
    detect_calls,
    build_dependency_tree,
    parse_linkage_section,
    map_parameters,
    analyze_multi_program,
    analyze_batch,
)


# ══════════════════════════════════════════════════════════════════════
# Component 1: CALL Statement Detector
# ══════════════════════════════════════════════════════════════════════


class TestCallDetector:
    def test_detect_static_call(self):
        """CALL 'CALCINT' detected as static."""
        source = """\
       PROCEDURE DIVISION.
       MAIN-LOGIC.
           CALL 'CALCINT'.
           STOP RUN.
"""
        calls = detect_calls(source)
        assert len(calls) == 1
        assert calls[0]["target"] == "CALCINT"
        assert calls[0]["type"] == "static"

    def test_detect_dynamic_call(self):
        """CALL WS-PROG-NAME detected as dynamic."""
        source = """\
       PROCEDURE DIVISION.
       MAIN-LOGIC.
           CALL WS-PROG-NAME.
           STOP RUN.
"""
        calls = detect_calls(source)
        assert len(calls) == 1
        assert calls[0]["target"] == "WS-PROG-NAME"
        assert calls[0]["type"] == "dynamic"

    def test_detect_call_using(self):
        """CALL 'X' USING A B C extracts parameters."""
        source = """\
       PROCEDURE DIVISION.
       MAIN-LOGIC.
           CALL 'CALCINT' USING WS-PRINCIPAL
                                WS-RATE
                                WS-RESULT.
           STOP RUN.
"""
        calls = detect_calls(source)
        assert len(calls) == 1
        assert calls[0]["target"] == "CALCINT"
        assert "WS-PRINCIPAL" in calls[0]["parameters"]
        assert "WS-RATE" in calls[0]["parameters"]
        assert "WS-RESULT" in calls[0]["parameters"]


# ══════════════════════════════════════════════════════════════════════
# Component 2: Dependency Tree Builder
# ══════════════════════════════════════════════════════════════════════


class TestDependencyTree:
    def test_build_tree_simple(self):
        """Two programs, one calls the other."""
        programs = {
            "MAIN": "       PROCEDURE DIVISION.\n       M. CALL 'SUB1'.\n           STOP RUN.\n",
            "SUB1": "       PROCEDURE DIVISION.\n       S. DISPLAY 'HI'.\n           GOBACK.\n",
        }
        tree = build_dependency_tree(programs)
        assert "SUB1" in tree["tree"]["MAIN"]["calls"]
        assert "MAIN" in tree["tree"]["SUB1"]["called_by"]
        assert tree["root"] == "MAIN"

    def test_build_tree_chain(self):
        """A calls B calls C — topological order is C, B, A."""
        programs = {
            "A": "       PROCEDURE DIVISION.\n       M. CALL 'B'.\n           STOP RUN.\n",
            "B": "       PROCEDURE DIVISION.\n       M. CALL 'C'.\n           GOBACK.\n",
            "C": "       PROCEDURE DIVISION.\n       M. DISPLAY 'END'.\n           GOBACK.\n",
        }
        tree = build_dependency_tree(programs)
        order = tree["order"]
        assert order.index("C") < order.index("B")
        assert order.index("B") < order.index("A")

    def test_circular_dependency(self):
        """A calls B, B calls A — detected, no crash."""
        programs = {
            "A": "       PROCEDURE DIVISION.\n       M. CALL 'B'.\n           GOBACK.\n",
            "B": "       PROCEDURE DIVISION.\n       M. CALL 'A'.\n           GOBACK.\n",
        }
        tree = build_dependency_tree(programs)
        assert len(tree["circular"]) > 0

    def test_unresolved_program(self):
        """CALL to program not in uploaded files."""
        programs = {
            "MAIN": "       PROCEDURE DIVISION.\n       M. CALL 'MISSING'.\n           STOP RUN.\n",
        }
        tree = build_dependency_tree(programs)
        assert "MISSING" in tree["unresolved"]


# ══════════════════════════════════════════════════════════════════════
# Component 3 & 4: LINKAGE SECTION + Parameter Mapping
# ══════════════════════════════════════════════════════════════════════


class TestLinkageSection:
    def test_linkage_section_parsed(self):
        """LINKAGE SECTION variables detected."""
        source = """\
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-TEMP              PIC S9(13)V99.

       LINKAGE SECTION.
       01  LS-PRINCIPAL         PIC S9(13)V99.
       01  LS-RATE              PIC S9(3)V9(4).
       01  LS-RESULT            PIC S9(13)V99.

       PROCEDURE DIVISION USING LS-PRINCIPAL LS-RATE LS-RESULT.
"""
        linkage = parse_linkage_section(source)
        assert len(linkage) == 3
        names = [v["name"] for v in linkage]
        assert "LS-PRINCIPAL" in names
        assert "LS-RATE" in names
        assert "LS-RESULT" in names

    def test_parameter_mapping(self):
        """CALL USING maps to LINKAGE SECTION positionally."""
        caller_call = {
            "target": "CALCINT",
            "type": "static",
            "parameters": ["WS-PRINCIPAL", "WS-RATE", "WS-RESULT"],
        }
        callee_linkage = [
            {"name": "LS-PRINCIPAL", "pic": "PIC S9(13)V99", "level": "01"},
            {"name": "LS-RATE", "pic": "PIC S9(3)V9(4)", "level": "01"},
            {"name": "LS-RESULT", "pic": "PIC S9(13)V99", "level": "01"},
        ]
        mappings = map_parameters(caller_call, callee_linkage)
        assert len(mappings) == 3
        assert mappings[0]["caller_var"] == "WS-PRINCIPAL"
        assert mappings[0]["callee_var"] == "LS-PRINCIPAL"
        assert mappings[2]["caller_var"] == "WS-RESULT"
        assert mappings[2]["callee_var"] == "LS-RESULT"


# ══════════════════════════════════════════════════════════════════════
# Component 5: Multi-File Analyzer
# ══════════════════════════════════════════════════════════════════════


DEMO_DIR = os.path.join(os.path.dirname(__file__), "demo_data")


class TestMultiFileAnalyze:
    def test_multi_file_analyze(self):
        """3 demo programs analyzed, aggregate result correct."""
        programs = {}
        for fname in ("MAIN-LOAN.cbl", "CALC-INT.cbl", "APPLY-PENALTY.cbl"):
            path = os.path.join(DEMO_DIR, fname)
            with open(path, "r") as f:
                programs[fname.replace(".cbl", "").upper()] = f.read()

        # Use just the tree builder for this test (no full analysis)
        tree = build_dependency_tree(programs)
        assert tree["root"] == "MAIN-LOAN"
        assert "CALC-INT" in tree["tree"]["MAIN-LOAN"]["calls"]
        assert "APPLY-PENALTY" in tree["tree"]["MAIN-LOAN"]["calls"]
        assert len(tree["unresolved"]) == 0

    def test_aggregate_status(self):
        """One MANUAL REVIEW makes whole system MANUAL REVIEW."""
        # Create a simple program with an EXEC SQL to trigger manual review
        programs = {
            "MAIN": """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. MAIN.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-VAL PIC 9(3).
       PROCEDURE DIVISION.
       MAIN-LOGIC.
           EXEC SQL
               SELECT X INTO :WS-VAL FROM T
           END-EXEC.
           STOP RUN.
""",
            "SUB": """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SUB.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-A PIC 9(3).
       PROCEDURE DIVISION.
       SUB-LOGIC.
           MOVE 1 TO WS-A.
           GOBACK.
""",
        }
        result = analyze_multi_program(programs)
        agg = result["aggregate"]
        assert agg["verification_status"] == "REQUIRES_MANUAL_REVIEW"

    def test_demo_pipeline(self):
        """End-to-end with demo data files."""
        programs = {}
        for fname in ("MAIN-LOAN.cbl", "CALC-INT.cbl", "APPLY-PENALTY.cbl"):
            path = os.path.join(DEMO_DIR, fname)
            with open(path, "r") as f:
                source = f.read()
            # Extract program ID from source
            import re
            match = re.search(r'PROGRAM-ID\.\s+([A-Z0-9\-]+)', source, re.IGNORECASE)
            prog_id = match.group(1).upper() if match else fname
            programs[prog_id] = source

        result = analyze_multi_program(programs)

        # Verify structure
        assert "dependency_tree" in result
        assert "program_results" in result
        assert "aggregate" in result

        agg = result["aggregate"]
        assert agg["total_programs"] == 3
        assert agg["total_variables"] > 0
        assert agg["total_paragraphs"] > 0
        assert agg["verification_status"] == "VERIFIED"

        # Verify dependency tree
        tree = result["dependency_tree"]
        assert tree["root"] == "MAIN-LOAN"
        assert len(tree["unresolved"]) == 0

        # Verify parameter mappings exist
        main_result = result["program_results"]["MAIN-LOAN"]
        assert len(main_result["parameter_mappings"]) == 2  # CALC-INT + APPLY-PENALTY

        # Verify linkage sections parsed
        calc_result = result["program_results"]["CALC-INT"]
        assert len(calc_result["linkage"]) == 3  # LS-PRINCIPAL, LS-RATE, LS-RESULT


# ══════════════════════════════════════════════════════════════════════
# Component 6: Batch Analyzer (Python generation + cross-file CALLs)
# ══════════════════════════════════════════════════════════════════════


def _load_demo_programs():
    """Load the 3 demo COBOL programs from demo_data/."""
    programs = {}
    for fname in ("MAIN-LOAN.cbl", "CALC-INT.cbl", "APPLY-PENALTY.cbl"):
        path = os.path.join(DEMO_DIR, fname)
        with open(path, "r") as f:
            source = f.read()
        match = re.search(r'PROGRAM-ID\.\s+([A-Z0-9\-]+)', source, re.IGNORECASE)
        prog_id = match.group(1).upper() if match else fname
        programs[prog_id] = source
    return programs


class TestBatchAnalysis:
    def test_batch_generates_python(self):
        """Batch analysis generates Python for each file."""
        programs = _load_demo_programs()
        result = analyze_batch(programs)
        for prog_name, prog_data in result["program_results"].items():
            assert prog_data["generated_python"] is not None, f"{prog_name} has no Python"
            assert "CobolDecimal" in prog_data["generated_python"]

    def test_batch_per_file_verdict(self):
        """Each file gets its own verification status."""
        programs = _load_demo_programs()
        result = analyze_batch(programs)
        for prog_name, prog_data in result["program_results"].items():
            assert prog_data["verification_status"] in (
                "VERIFIED", "REQUIRES_MANUAL_REVIEW"
            ), f"{prog_name} has invalid verdict"

    def test_batch_combined_verdict(self):
        """All clean demo programs produce VERIFIED combined verdict."""
        programs = _load_demo_programs()
        result = analyze_batch(programs)
        assert result["combined_verdict"] == "VERIFIED"

    def test_batch_cross_file_resolution(self):
        """MAIN-LOAN generated Python contains CALL resolution block."""
        programs = _load_demo_programs()
        result = analyze_batch(programs)
        main_code = result["program_results"]["MAIN-LOAN"]["generated_python"]
        assert "CROSS-FILE CALL RESOLUTION" in main_code
        assert "CALC-INT" in main_code
        assert "APPLY-PENALTY" in main_code
        assert "manual wiring" in main_code

    def test_batch_arithmetic_risks(self):
        """Batch includes arithmetic risk analysis per file."""
        programs = _load_demo_programs()
        result = analyze_batch(programs)
        for prog_name, prog_data in result["program_results"].items():
            assert "arithmetic_risks" in prog_data
            assert "arithmetic_summary" in prog_data

    def test_batch_unresolved_forces_manual_review(self):
        """Unresolved CALL targets force REQUIRES_MANUAL_REVIEW."""
        programs = {
            "MAIN": """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. MAIN.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-VAL PIC 9(3).
       PROCEDURE DIVISION.
       MAIN-LOGIC.
           CALL 'MISSING-PROG' USING WS-VAL.
           STOP RUN.
""",
        }
        result = analyze_batch(programs)
        assert result["combined_verdict"] == "REQUIRES_MANUAL_REVIEW"

    def test_batch_topological_order(self):
        """Leaves (CALC-INT, APPLY-PENALTY) come before caller (MAIN-LOAN)."""
        programs = _load_demo_programs()
        result = analyze_batch(programs)
        order = result["dependency_tree"]["order"]
        main_idx = order.index("MAIN-LOAN")
        calc_idx = order.index("CALC-INT")
        penalty_idx = order.index("APPLY-PENALTY")
        assert calc_idx < main_idx
        assert penalty_idx < main_idx

    def test_batch_single_file(self):
        """Single file to batch endpoint returns valid result with no cross-file block."""
        programs = {
            "SIMPLE": """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SIMPLE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-X PIC S9(5).
       PROCEDURE DIVISION.
       MAIN-PARA.
           COMPUTE WS-X = 42.
           STOP RUN.
""",
        }
        result = analyze_batch(programs)
        assert result["combined_verdict"] == "VERIFIED"
        assert len(result["program_results"]) == 1
        prog_data = result["program_results"]["SIMPLE"]
        assert prog_data["verification_status"] == "VERIFIED"
        assert prog_data["generated_python"] is not None
        assert "CROSS-FILE CALL RESOLUTION" not in prog_data["generated_python"]
