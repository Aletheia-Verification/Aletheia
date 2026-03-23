"""
test_execution_trace.py — Tests for execution trace comparison engine.
"""

import pytest
from execution_trace import compare_traces, parse_trace, diagnose_divergence, TraceEvent


def _make_event(line, verb, variable, old_value, new_value, expression=None):
    """Helper: build a trace event dict."""
    d = {"line": line, "verb": verb, "variable": variable,
         "old_value": old_value, "new_value": new_value}
    if expression:
        d["expression"] = expression
    return d


class TestIdenticalTraces:
    """Two identical traces → no divergence."""

    def test_no_divergence(self):
        trace = [
            _make_event(10, "MOVE", "WS-A", "0", "100"),
            _make_event(15, "COMPUTE", "WS-B", "0", "200.50"),
            _make_event(20, "ADD", "WS-C", "100", "300.50"),
        ]
        result = compare_traces(trace, list(trace))
        assert result["diverged"] is False
        assert result["matching_events"] == 3
        assert result["divergence_index"] is None
        assert result["diagnosis"] is None


class TestFirstDivergence:
    """Traces diverge at a specific index."""

    def test_diverges_at_index_2(self):
        trace_a = [
            _make_event(10, "MOVE", "WS-A", "0", "100"),
            _make_event(15, "COMPUTE", "WS-B", "0", "200.50"),
            _make_event(20, "ADD", "WS-C", "100", "300.50"),
            _make_event(25, "MOVE", "WS-D", "0", "400"),
        ]
        trace_b = [
            _make_event(10, "MOVE", "WS-A", "0", "100"),
            _make_event(15, "COMPUTE", "WS-B", "0", "200.50"),
            _make_event(20, "ADD", "WS-C", "100", "299.50"),  # different
            _make_event(25, "MOVE", "WS-D", "0", "400"),
        ]
        result = compare_traces(trace_a, trace_b)
        assert result["diverged"] is True
        assert result["divergence_index"] == 2
        assert result["matching_events"] == 2
        assert result["event_a"]["new_value"] == "300.50"
        assert result["event_b"]["new_value"] == "299.50"
        assert result["diagnosis"] is not None


class TestRoundingDiagnosis:
    """COMPUTE divergence < 0.01 → rounding diagnosis."""

    def test_rounding_keyword(self):
        event_a = TraceEvent(line=45, verb="COMPUTE", variable="WS-BALANCE",
                             old_value="0", new_value="1500.00")
        event_b = TraceEvent(line=45, verb="COMPUTE", variable="WS-BALANCE",
                             old_value="0", new_value="1499.995")
        diagnosis = diagnose_divergence(event_a, event_b)
        assert "Rounding" in diagnosis or "rounding" in diagnosis.lower()

    def test_rounding_via_compare(self):
        trace_a = [_make_event(45, "COMPUTE", "WS-BAL", "0", "1500.00")]
        trace_b = [_make_event(45, "COMPUTE", "WS-BAL", "0", "1499.995")]
        result = compare_traces(trace_a, trace_b)
        assert result["diverged"] is True
        assert "ounding" in result["diagnosis"]


class TestEmptyTraces:
    """Empty inputs → no divergence."""

    def test_both_empty(self):
        result = compare_traces([], [])
        assert result["diverged"] is False
        assert result["matching_events"] == 0

    def test_one_empty(self):
        trace = [_make_event(10, "MOVE", "WS-A", "0", "100")]
        result = compare_traces(trace, [])
        assert result["diverged"] is True
        assert result["divergence_index"] == 0
        assert "length" in result["diagnosis"].lower()


# ── Generator trace emission tests ────────────────────────────

from cobol_analyzer_api import analyze_cobol
from generate_full_python import generate_python_module

_SIMPLE_COBOL = (
    "       IDENTIFICATION DIVISION.\n"
    "       PROGRAM-ID. TRACTEST.\n"
    "       DATA DIVISION.\n"
    "       WORKING-STORAGE SECTION.\n"
    "       01  WS-A  PIC S9(5)V99.\n"
    "       01  WS-B  PIC S9(5)V99.\n"
    "       PROCEDURE DIVISION.\n"
    "       MAIN-PARA.\n"
    "           MOVE 100 TO WS-A.\n"
    "           COMPUTE WS-B = WS-A + 50.\n"
    "           STOP RUN.\n"
)


class TestTraceModeEmitsTraceList:
    """trace_mode=True → _trace list in generated code."""

    def test_trace_list_present(self):
        analysis = analyze_cobol(_SIMPLE_COBOL)
        result = generate_python_module(analysis, trace_mode=True)
        code = result["code"]
        assert "_trace = []" in code
        assert "_trace.append(" in code

    def test_compiles(self):
        analysis = analyze_cobol(_SIMPLE_COBOL)
        result = generate_python_module(analysis, trace_mode=True)
        compile(result["code"], "<test>", "exec")


class TestTraceModeDefaultNoTrace:
    """Default (trace_mode=False) → no _trace in code."""

    def test_no_trace_list(self):
        analysis = analyze_cobol(_SIMPLE_COBOL)
        result = generate_python_module(analysis, trace_mode=False)
        code = result["code"]
        assert "_trace = []" not in code
        assert "_trace.append(" not in code


class TestTraceCapturesValues:
    """Execute generated code with trace_mode and verify old/new values."""

    def test_move_and_compute_traced(self):
        analysis = analyze_cobol(_SIMPLE_COBOL)
        result = generate_python_module(analysis, trace_mode=True)
        code = result["code"]

        # Execute
        namespace = {}
        exec(code, namespace)
        trace = namespace["main"]()

        assert isinstance(trace, list)
        assert len(trace) >= 2  # at least MOVE + COMPUTE

        # Find the MOVE 100 TO WS-A event
        move_events = [e for e in trace if e["verb"] == "MOVE"]
        assert len(move_events) >= 1
        move_a = move_events[0]
        # PIC S9(5)V99 → old_value is "0.00", new_value is "100.00"
        from decimal import Decimal
        assert Decimal(move_a["old_value"]) == 0
        assert Decimal(move_a["new_value"]) == 100

        # Find the COMPUTE WS-B = WS-A + 50 event
        compute_events = [e for e in trace if e["verb"] == "COMPUTE"]
        assert len(compute_events) >= 1
        compute_b = compute_events[0]
        assert Decimal(compute_b["old_value"]) == 0
        assert Decimal(compute_b["new_value"]) == 150
