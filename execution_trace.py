"""
execution_trace.py — Execution Trace Comparison Engine

Compares step-by-step execution traces from two COBOL verification runs
and finds the FIRST point of divergence with root-cause diagnosis.

Trace format (list of dicts):
    {"line": 45, "verb": "COMPUTE", "variable": "WS-BALANCE",
     "old_value": "1500.00", "new_value": "1499.99", "expression": "..."}
"""

import logging
from dataclasses import dataclass, asdict
from decimal import Decimal, InvalidOperation

logger = logging.getLogger(__name__)


@dataclass
class TraceEvent:
    """A single state-change event from executing generated Python."""
    line: int
    verb: str
    variable: str
    old_value: str
    new_value: str
    expression: str | None = None

    def to_dict(self) -> dict:
        return asdict(self)


def parse_trace(trace_json: list[dict]) -> list[TraceEvent]:
    """Convert raw JSON list to TraceEvent objects.

    Validates that required fields (line, verb, variable, old_value, new_value)
    are present. Skips malformed entries with a warning.
    """
    events = []
    required = {"line", "verb", "variable", "old_value", "new_value"}
    for i, entry in enumerate(trace_json):
        missing = required - set(entry.keys())
        if missing:
            logger.warning("Trace entry %d missing fields: %s — skipped", i, missing)
            continue
        events.append(TraceEvent(
            line=int(entry["line"]),
            verb=str(entry["verb"]).upper(),
            variable=str(entry["variable"]),
            old_value=str(entry["old_value"]),
            new_value=str(entry["new_value"]),
            expression=entry.get("expression"),
        ))
    return events


def diagnose_divergence(event_a: TraceEvent, event_b: TraceEvent) -> str:
    """Heuristic root-cause analysis on the first divergence point.

    Returns a human-readable diagnosis string.
    """
    verb = event_a.verb
    variable = event_a.variable

    # Try numeric comparison for magnitude-based diagnosis
    try:
        val_a = Decimal(event_a.new_value)
        val_b = Decimal(event_b.new_value)
        magnitude = abs(val_a - val_b)

        # Sign reversal
        if val_a != 0 and val_b != 0 and val_a == -val_b:
            return (
                f"Sign reversal on {variable} at line {event_a.line} — "
                f"COMP-3 sign nibble mismatch or unsigned field treated as signed"
            )

        # Sub-cent rounding divergence
        if magnitude < Decimal("0.01") and magnitude > 0:
            if verb == "DIVIDE":
                return (
                    f"Rounding divergence on {variable} at line {event_a.line} — "
                    f"TRUNC mode mismatch (STD vs BIN). "
                    f"Reference: {event_a.new_value}, migration: {event_b.new_value}"
                )
            return (
                f"Rounding divergence on {variable} at line {event_a.line} — "
                f"check ROUNDED keyword on {verb}. "
                f"Reference: {event_a.new_value}, migration: {event_b.new_value}"
            )

        # Large magnitude — precision overflow
        if magnitude > Decimal("100"):
            return (
                f"PIC precision overflow on {variable} at line {event_a.line} — "
                f"value exceeds field capacity. "
                f"Reference: {event_a.new_value}, migration: {event_b.new_value}"
            )

        # Whole-number truncation
        if magnitude == magnitude.to_integral_value():
            return (
                f"Decimal truncation on {variable} at line {event_a.line} — "
                f"PIC integer digits exceeded. "
                f"Reference: {event_a.new_value}, migration: {event_b.new_value}"
            )

    except (InvalidOperation, ValueError):
        pass

    # String length mismatch (MOVE)
    if verb == "MOVE" and len(event_a.new_value) != len(event_b.new_value):
        return (
            f"PIC length mismatch on {variable} at line {event_a.line} — "
            f"target field too short or padding differs. "
            f"Reference length: {len(event_a.new_value)}, migration length: {len(event_b.new_value)}"
        )

    # Generic divergence
    return (
        f"Value divergence at {verb} on {variable} (line {event_a.line}) — "
        f"reference: {event_a.new_value}, migration: {event_b.new_value}"
    )


def compare_traces(trace_a: list[dict], trace_b: list[dict]) -> dict:
    """Compare two execution traces and find the first divergence.

    Args:
        trace_a: Trace from reference execution (list of event dicts).
        trace_b: Trace from migration execution (list of event dicts).

    Returns:
        Dict with divergence report:
        - diverged: bool
        - divergence_index: int | None
        - event_a, event_b: dict | None (the divergent events)
        - total_events_a, total_events_b: int
        - matching_events: int
        - diagnosis: str | None
    """
    events_a = parse_trace(trace_a)
    events_b = parse_trace(trace_b)

    result = {
        "diverged": False,
        "divergence_index": None,
        "event_a": None,
        "event_b": None,
        "total_events_a": len(events_a),
        "total_events_b": len(events_b),
        "matching_events": 0,
        "diagnosis": None,
    }

    # Walk both traces in parallel
    min_len = min(len(events_a), len(events_b))
    for i in range(min_len):
        ea = events_a[i]
        eb = events_b[i]

        if ea.new_value != eb.new_value:
            result["diverged"] = True
            result["divergence_index"] = i
            result["event_a"] = ea.to_dict()
            result["event_b"] = eb.to_dict()
            result["matching_events"] = i
            result["diagnosis"] = diagnose_divergence(ea, eb)
            return result

        result["matching_events"] = i + 1

    # Check for length mismatch (one trace is longer)
    if len(events_a) != len(events_b):
        result["diverged"] = True
        result["divergence_index"] = min_len
        result["matching_events"] = min_len
        if len(events_a) > min_len:
            result["event_a"] = events_a[min_len].to_dict()
        if len(events_b) > min_len:
            result["event_b"] = events_b[min_len].to_dict()
        result["diagnosis"] = (
            f"Trace length mismatch — reference has {len(events_a)} events, "
            f"migration has {len(events_b)} events. "
            f"Divergence starts at event {min_len}."
        )
        return result

    return result
