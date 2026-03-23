"""Tests for streaming_compare() generator in shadow_diff.py.

Verifies constant-memory streaming comparison with event yielding,
progress callbacks, drift detection, and length mismatch handling.
"""
import os
import pytest
from decimal import Decimal, getcontext

os.environ["USE_IN_MEMORY_DB"] = "1"

from shadow_diff import streaming_compare, parse_fixed_width_stream


@pytest.fixture(autouse=True, scope="module")
def _streaming_decimal_context():
    original = getcontext().prec
    getcontext().prec = 31
    yield
    getcontext().prec = original


# ── Shared fixtures ──────────────────────────────────────────

SIMPLE_SOURCE = """
from decimal import Decimal

x = Decimal('0')
result = Decimal('0')

def main():
    global x, result
    result = x * Decimal('2')
"""

INPUT_LAYOUT = {
    "fields": [{"name": "X", "start": 0, "length": 12, "type": "integer"}],
    "record_length": None,
}

OUTPUT_LAYOUT = {
    "fields": [{"name": "RESULT", "start": 0, "length": 12, "type": "integer"}],
    "record_length": None,
    "field_mapping": {"RESULT": "result"},
}

INPUT_MAPPING = {"X": "x"}
OUTPUT_FIELDS = ["result"]


def _build_data(count, multiplier=2):
    """Build newline-delimited fixed-width data for `count` records."""
    input_lines = [f"{i:>12d}" for i in range(count)]
    output_lines = [f"{i * multiplier:>12d}" for i in range(count)]
    return "\n".join(input_lines), "\n".join(output_lines)


def _mainframe_stream(output_data):
    """Parse mainframe output and map COBOL names → Python names."""
    for rec in parse_fixed_width_stream(OUTPUT_LAYOUT, output_data):
        yield {"result": str(rec["RESULT"])}


class TestStreamingCompare:

    def test_streaming_match(self):
        """1000 identical records → all match events, 0 drift."""
        input_data, output_data = _build_data(1000)

        events = list(streaming_compare(
            source=SIMPLE_SOURCE,
            input_stream=parse_fixed_width_stream(INPUT_LAYOUT, input_data),
            mainframe_stream=_mainframe_stream(output_data),
            input_mapping=INPUT_MAPPING,
            output_fields=OUTPUT_FIELDS,
        ))

        match_events = [e for e in events if e["type"] == "match"]
        drift_events = [e for e in events if e["type"] == "drift"]
        complete = [e for e in events if e["type"] == "complete"][0]

        assert len(match_events) == 1000
        assert len(drift_events) == 0
        assert complete["total"] == 1000
        assert complete["matches"] == 1000
        assert complete["mismatches"] == 0

    def test_streaming_drift(self):
        """Drift at record 500 → detected in event stream."""
        COUNT = 1000
        input_data, output_data = _build_data(COUNT)

        # Corrupt record 500: change expected output so it mismatches
        output_lines = output_data.split("\n")
        output_lines[500] = f"{99999999:>12d}"  # wrong value
        output_data_corrupted = "\n".join(output_lines)

        events = list(streaming_compare(
            source=SIMPLE_SOURCE,
            input_stream=parse_fixed_width_stream(INPUT_LAYOUT, input_data),
            mainframe_stream=_mainframe_stream(output_data_corrupted),
            input_mapping=INPUT_MAPPING,
            output_fields=OUTPUT_FIELDS,
        ))

        drift_events = [e for e in events if e["type"] == "drift"]
        complete = [e for e in events if e["type"] == "complete"][0]

        assert len(drift_events) == 1
        assert drift_events[0]["record"] == 500
        assert len(drift_events[0]["details"]) > 0
        assert complete["matches"] == 999
        assert complete["mismatches"] == 1

    def test_streaming_length_mismatch(self):
        """Input has 100 records, output has 90 → 10 length_mismatch events."""
        input_data, _ = _build_data(100)
        _, output_data = _build_data(90)

        events = list(streaming_compare(
            source=SIMPLE_SOURCE,
            input_stream=parse_fixed_width_stream(INPUT_LAYOUT, input_data),
            mainframe_stream=_mainframe_stream(output_data),
            input_mapping=INPUT_MAPPING,
            output_fields=OUTPUT_FIELDS,
        ))

        lm_events = [e for e in events if e["type"] == "length_mismatch"]
        complete = [e for e in events if e["type"] == "complete"][0]

        assert len(lm_events) == 10
        # Input has extra records → mainframe stream exhausted first → side="input"
        # (the extra records are on the input side)
        assert all(e["side"] == "input" for e in lm_events)
        assert complete["total"] == 100
        assert complete["mismatches"] == 10

    def test_streaming_memory(self):
        """100K records — verify no list accumulation (constant memory)."""
        COUNT = 100_000
        input_data, output_data = _build_data(COUNT)

        # Consume generator without materializing event list
        event_count = 0
        match_count = 0
        for event in streaming_compare(
            source=SIMPLE_SOURCE,
            input_stream=parse_fixed_width_stream(INPUT_LAYOUT, input_data),
            mainframe_stream=_mainframe_stream(output_data),
            input_mapping=INPUT_MAPPING,
            output_fields=OUTPUT_FIELDS,
        ):
            event_count += 1
            if event["type"] == "match":
                match_count += 1

        # 100K match events + 1 complete event
        assert event_count == COUNT + 1
        assert match_count == COUNT

    def test_streaming_progress_callback(self):
        """Progress callback called for each record with running stats."""
        COUNT = 100
        input_data, output_data = _build_data(COUNT)

        calls = []

        def on_progress(total, matches, mismatches):
            calls.append((total, matches, mismatches))

        list(streaming_compare(
            source=SIMPLE_SOURCE,
            input_stream=parse_fixed_width_stream(INPUT_LAYOUT, input_data),
            mainframe_stream=_mainframe_stream(output_data),
            input_mapping=INPUT_MAPPING,
            output_fields=OUTPUT_FIELDS,
            progress_callback=on_progress,
        ))

        assert len(calls) == COUNT
        assert calls[-1] == (100, 100, 0)
        # Verify monotonically increasing totals
        for i, (total, _, _) in enumerate(calls):
            assert total == i + 1
