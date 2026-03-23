"""Tests for COMP-1 (single-precision) and COMP-2 (double-precision) float support."""

import os
import struct

os.environ["USE_IN_MEMORY_DB"] = "1"

import pytest
from decimal import Decimal
from cobol_types import CobolFloat, _encode_comp1, _decode_comp1, _encode_comp2, _decode_comp2


class TestCobolFloat:
    def test_comp1_precision(self):
        """COMP-1 truncates to single precision (~7 significant digits)."""
        f = CobolFloat(1.23456789012345, precision='single')
        # Single precision rounds to ~7 significant digits
        assert abs(float(f.value) - 1.2345679) < 1e-5

    def test_comp2_precision(self):
        """COMP-2 maintains double precision (~15 significant digits)."""
        f = CobolFloat(1.23456789012345, precision='double')
        assert abs(float(f.value) - 1.23456789012345) < 1e-14

    def test_comp1_arithmetic(self):
        """COMPUTE with COMP-1 field — 100/3 truncated to single precision."""
        f = CobolFloat(0.0, precision='single')
        f.store(100.0 / 3.0)
        # 33.333... truncated to single precision
        assert abs(float(f.value) - 33.333332) < 1e-3

    def test_comp1_encode_decode(self):
        """Round-trip COMP-1 encode/decode."""
        encoded = _encode_comp1(3.14)
        assert len(encoded) == 4  # 4 bytes for single
        decoded = _decode_comp1(encoded)
        assert abs(float(decoded) - 3.14) < 1e-5

    def test_comp2_encode_decode(self):
        """Round-trip COMP-2 encode/decode."""
        encoded = _encode_comp2(3.141592653589793)
        assert len(encoded) == 8  # 8 bytes for double
        decoded = _decode_comp2(encoded)
        assert abs(float(decoded) - 3.141592653589793) < 1e-14

    def test_comp2_in_shadow_diff(self):
        """Parse COMP-2 field from raw bytes (as Shadow Diff would)."""
        raw = struct.pack('>d', 123.456)
        result = _decode_comp2(raw)
        assert abs(float(result) - 123.456) < 1e-10

    def test_analyzer_detects_comp1_comp2(self):
        """Analyzer detects COMP-1/COMP-2 storage type and extracts name (no PIC)."""
        from cobol_analyzer_api import analyze_cobol
        source = (
            "       IDENTIFICATION DIVISION.\n"
            "       PROGRAM-ID. FLOATTEST.\n"
            "       DATA DIVISION.\n"
            "       WORKING-STORAGE SECTION.\n"
            "       01  WS-RATE    COMP-1.\n"
            "       01  WS-FACTOR  COMP-2.\n"
            "       PROCEDURE DIVISION.\n"
            "       0000-MAIN.\n"
            "           STOP RUN.\n"
        )
        result = analyze_cobol(source)
        vars_by_name = {v["name"]: v for v in result["variables"] if v["name"]}
        # Name extraction works without PIC clause
        assert "WS-RATE" in vars_by_name
        assert "WS-FACTOR" in vars_by_name
        # Storage type correctly identified
        assert vars_by_name["WS-RATE"]["storage_type"] == "COMP-1"
        assert vars_by_name["WS-FACTOR"]["storage_type"] == "COMP-2"
        # PIC info is None (no PIC clause for COMP-1/COMP-2)
        assert vars_by_name["WS-RATE"]["pic_info"] is None
        assert vars_by_name["WS-FACTOR"]["pic_info"] is None
        # Boolean flags
        assert vars_by_name["WS-RATE"]["comp1"] is True
        assert vars_by_name["WS-FACTOR"]["comp2"] is True

    def test_cobol_float_store_from_decimal(self):
        """CobolFloat can store from Decimal values."""
        f = CobolFloat(0.0, precision='double')
        f.store(Decimal('99.99'))
        assert abs(float(f.value) - 99.99) < 1e-10

    def test_cobol_float_comparisons(self):
        """CobolFloat comparison operators work correctly."""
        f1 = CobolFloat(10.0, precision='double')
        f2 = CobolFloat(20.0, precision='double')
        assert f1 < f2
        assert f1 <= f2
        assert f2 > f1
        assert f2 >= f1
        assert f1 != f2
        f3 = CobolFloat(10.0, precision='double')
        assert f1 == f3

    def test_cobol_float_no_overflow(self):
        """COMP-1/COMP-2 don't report overflow."""
        f = CobolFloat(0.0, precision='single')
        assert f.check_overflow(1e38) is False
