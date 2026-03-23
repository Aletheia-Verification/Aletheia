"""
test_odo.py — OCCURS DEPENDING ON (ODO) tests.

12 tests covering:
  - Analyzer detection of ODO metadata in variable dict (4)
  - CobolMemoryRegion.resize() grow/shrink with data preservation (5)
  - Boundary enforcement: access beyond shrunken buffer raises error (3)

Run: pytest test_odo.py -v
"""

import os
import pytest
from decimal import Decimal

os.environ["USE_IN_MEMORY_DB"] = "1"

from cobol_types import CobolMemoryRegion, CobolFieldProxy, CobolDecimal
from compiler_config import reset_config


@pytest.fixture(autouse=True)
def _reset():
    reset_config()
    yield
    reset_config()


# ══════════════════════════════════════════════════════════════════════
# 1. ANALYZER DETECTION
# ══════════════════════════════════════════════════════════════════════


class TestODODetection:
    """Verify that analyze_cobol() stores ODO metadata in variable dicts."""

    def _find_var(self, variables, name):
        """Find a variable by name (case-insensitive)."""
        for v in variables:
            if v.get("name") and v["name"].upper() == name.upper():
                return v
        return None

    def test_odo_detected_in_variable_dict(self):
        """OCCURS 1 TO 100 TIMES DEPENDING ON WS-COUNT → occurs_min=1, occurs_max=100."""
        from cobol_analyzer_api import analyze_cobol

        source = (
            "       IDENTIFICATION DIVISION.\n"
            "       PROGRAM-ID. ODO-TEST.\n"
            "       DATA DIVISION.\n"
            "       WORKING-STORAGE SECTION.\n"
            "       01 WS-COUNT PIC 9(3).\n"
            "       01 WS-TABLE.\n"
            "          05 WS-ITEM OCCURS 1 TO 100 TIMES\n"
            "             DEPENDING ON WS-COUNT PIC X(10).\n"
            "       PROCEDURE DIVISION.\n"
            "           MOVE 5 TO WS-COUNT.\n"
            "           STOP RUN.\n"
        )
        result = analyze_cobol(source)
        var = self._find_var(result["variables"], "WS-ITEM")
        assert var is not None, "WS-ITEM not found in variables"
        assert var["occurs"] == 100, "occurs should be max capacity"
        assert var["occurs_min"] == 1
        assert var["occurs_max"] == 100
        assert var["depending_on"] == "WS-COUNT"

    def test_fixed_occurs_no_odo_metadata(self):
        """Fixed OCCURS 10 → occurs_min=0, occurs_max=0, depending_on=None."""
        from cobol_analyzer_api import analyze_cobol

        source = (
            "       IDENTIFICATION DIVISION.\n"
            "       PROGRAM-ID. FIXED-TEST.\n"
            "       DATA DIVISION.\n"
            "       WORKING-STORAGE SECTION.\n"
            "       01 WS-TABLE.\n"
            "          05 WS-AMT OCCURS 10 TIMES PIC 9(5)V99.\n"
            "       PROCEDURE DIVISION.\n"
            "           STOP RUN.\n"
        )
        result = analyze_cobol(source)
        var = self._find_var(result["variables"], "WS-AMT")
        assert var is not None, "WS-AMT not found in variables"
        assert var["occurs"] == 10
        assert var["occurs_min"] == 0
        assert var["occurs_max"] == 0
        assert var["depending_on"] is None

    def test_odo_without_times_keyword(self):
        """OCCURS 5 TO 50 DEPENDING ON WS-N (no TIMES keyword)."""
        from cobol_analyzer_api import analyze_cobol

        source = (
            "       IDENTIFICATION DIVISION.\n"
            "       PROGRAM-ID. ODO-NO-TIMES.\n"
            "       DATA DIVISION.\n"
            "       WORKING-STORAGE SECTION.\n"
            "       01 WS-N PIC 9(2).\n"
            "       01 WS-TABLE.\n"
            "          05 WS-ENTRY OCCURS 5 TO 50\n"
            "             DEPENDING ON WS-N PIC X(20).\n"
            "       PROCEDURE DIVISION.\n"
            "           STOP RUN.\n"
        )
        result = analyze_cobol(source)
        var = self._find_var(result["variables"], "WS-ENTRY")
        assert var is not None, "WS-ENTRY not found in variables"
        assert var["occurs_min"] == 5
        assert var["occurs_max"] == 50
        assert var["depending_on"] == "WS-N"
        assert var["occurs"] == 50, "occurs should default to max"

    def test_odo_exec_dependency_preserved(self):
        """exec_dependencies still contains ODO entry (existing behavior)."""
        from cobol_analyzer_api import analyze_cobol

        source = (
            "       IDENTIFICATION DIVISION.\n"
            "       PROGRAM-ID. ODO-DEP.\n"
            "       DATA DIVISION.\n"
            "       WORKING-STORAGE SECTION.\n"
            "       01 WS-COUNT PIC 9(3).\n"
            "       01 WS-TABLE.\n"
            "          05 WS-ITEM OCCURS 1 TO 100 TIMES\n"
            "             DEPENDING ON WS-COUNT PIC X(10).\n"
            "       PROCEDURE DIVISION.\n"
            "           STOP RUN.\n"
        )
        result = analyze_cobol(source)
        odo_deps = [d for d in result["exec_dependencies"] if d["type"] == "ODO"]
        assert len(odo_deps) == 1
        assert odo_deps[0]["depending_on"] == "WS-COUNT"
        assert "VARIABLE-LENGTH RECORDS DETECTED" in odo_deps[0]["flag"]


# ══════════════════════════════════════════════════════════════════════
# 2. MEMORY REGION RESIZE
# ══════════════════════════════════════════════════════════════════════


class TestCobolMemoryRegionResize:
    """Verify CobolMemoryRegion.resize() for OCCURS DEPENDING ON."""

    def test_resize_grow_preserves_data(self):
        """Growing the buffer preserves existing field data."""
        region = CobolMemoryRegion(8)
        region.register_field('F1', offset=0, length=5, is_string=True)
        region.put('F1', 'HELLO')
        assert region.get('F1') == 'HELLO'

        region.resize(16)
        assert len(region._buffer) == 16
        assert region.get('F1') == 'HELLO'

    def test_resize_grow_zero_fills(self):
        """New bytes from growth are zero-filled."""
        region = CobolMemoryRegion(4)
        region.resize(8)
        assert region._buffer[4:8] == b'\x00\x00\x00\x00'

    def test_resize_shrink_preserves_head(self):
        """Shrinking preserves data within the new size."""
        region = CobolMemoryRegion(16)
        region.register_field('F1', offset=0, length=5, is_string=True)
        region.put('F1', 'WORLD')

        region.resize(8)
        assert len(region._buffer) == 8
        assert region.get('F1') == 'WORLD'

    def test_resize_noop_same_size(self):
        """Resizing to the same size is a no-op."""
        region = CobolMemoryRegion(10)
        region.register_field('F1', offset=0, length=5, is_string=True)
        region.put('F1', 'TEST ')
        region.resize(10)
        assert len(region._buffer) == 10
        assert region.get('F1') == 'TEST'

    def test_resize_negative_raises(self):
        """Negative size raises ValueError."""
        region = CobolMemoryRegion(10)
        with pytest.raises(ValueError, match="negative"):
            region.resize(-1)


# ══════════════════════════════════════════════════════════════════════
# 3. BOUNDARY ACCESS
# ══════════════════════════════════════════════════════════════════════


class TestODOBoundaryAccess:
    """Verify that accessing fields beyond the shrunken buffer raises IndexError."""

    def test_access_beyond_shrunk_buffer_raises(self):
        """get() on a field past the buffer end raises IndexError."""
        region = CobolMemoryRegion(16)
        region.register_field('F1', offset=0, length=4, is_string=True)
        region.register_field('F2', offset=8, length=8, is_string=True)
        region.put('F1', 'OK  ')
        region.put('F2', 'FARFIELD')

        region.resize(4)
        # F1 is still accessible
        assert region.get('F1') == 'OK'
        # F2 is beyond the buffer
        with pytest.raises(IndexError, match="exceeds buffer size"):
            region.get('F2')

    def test_put_beyond_shrunk_buffer_raises(self):
        """put() on a field past the buffer end raises IndexError."""
        region = CobolMemoryRegion(16)
        region.register_field('N1', offset=8, length=4,
                              pic_integers=5, pic_decimals=0,
                              is_signed=False, storage_type='DISPLAY')
        region.resize(4)
        with pytest.raises(IndexError, match="exceeds buffer size"):
            region.put('N1', Decimal('12345'))

    def test_proxy_access_beyond_shrunk_raises(self):
        """CobolFieldProxy.value on a field past the buffer raises IndexError."""
        region = CobolMemoryRegion(16)
        region.register_field('PX', offset=12, length=4,
                              pic_integers=3, pic_decimals=0,
                              is_signed=False, storage_type='DISPLAY')
        proxy = CobolFieldProxy(region, 'PX')

        region.resize(4)
        with pytest.raises(IndexError, match="exceeds buffer size"):
            _ = proxy.value
