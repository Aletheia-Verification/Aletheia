"""Tests for HIGH audit findings H1–H5 (AUDIT_POST_MEGA_SESSION.md)."""

import os
import logging
from decimal import Decimal
from unittest.mock import MagicMock, patch

os.environ["USE_IN_MEMORY_DB"] = "1"

import pytest
from cobol_types import CobolDecimal
from compiler_config import set_config, reset_config


# ── H1: COMP byte boundary uses pic_integers, not total_digits ──


class TestH1CompByteBoundary:
    def setup_method(self):
        set_config(trunc_mode="BIN")

    def teardown_method(self):
        reset_config()

    def test_comp_s9_4_v99_is_halfword(self):
        """PIC S9(4)V99 COMP → halfword (4 integer digits ≤ 4)."""
        d = CobolDecimal('0', pic_integers=4, pic_decimals=2,
                         is_signed=True, is_comp=True)
        # Halfword max = 32767, with V99 → 327.67
        assert d.effective_max() == Decimal('327.67')

    def test_comp_s9_5_is_fullword(self):
        """PIC S9(5) COMP → fullword (5 integer digits > 4)."""
        d = CobolDecimal('0', pic_integers=5, pic_decimals=0,
                         is_signed=True, is_comp=True)
        assert d.effective_max() == Decimal('2147483647')

    def test_comp_s9_3_v99_is_halfword(self):
        """PIC S9(3)V99 COMP → halfword (3 integer digits ≤ 4)."""
        d = CobolDecimal('0', pic_integers=3, pic_decimals=2,
                         is_signed=True, is_comp=True)
        assert d.effective_max() == Decimal('327.67')

    def test_comp_s9_9_v99_is_fullword(self):
        """PIC S9(9)V99 COMP → fullword (9 integer digits > 4, ≤ 9)."""
        d = CobolDecimal('0', pic_integers=9, pic_decimals=2,
                         is_signed=True, is_comp=True)
        # Fullword max = 2147483647, with V99 → 21474836.47
        assert d.effective_max() == Decimal('21474836.47')


# ── H2: File handle leak on write error ─────────────────────────


class TestH2FileHandleLeak:
    def test_write_error_closes_handle(self):
        """OSError on write closes the file handle and removes from _handles."""
        from cobol_file_io import RealFileBackend
        backend = RealFileBackend()
        # Create a mock file handle that raises on write
        mock_fh = MagicMock()
        mock_fh.write.side_effect = OSError("disk full")
        backend._handles["TEST-FILE"] = mock_fh
        status = backend.write("TEST-FILE", b"data")
        assert status == "48"
        mock_fh.close.assert_called_once()
        assert "TEST-FILE" not in backend._handles

    def test_write_success_keeps_handle(self):
        """Successful write keeps handle open."""
        from cobol_file_io import RealFileBackend
        backend = RealFileBackend()
        mock_fh = MagicMock()
        backend._handles["TEST-FILE"] = mock_fh
        status = backend.write("TEST-FILE", b"data")
        assert status == "00"
        assert "TEST-FILE" in backend._handles
        mock_fh.close.assert_not_called()


# ── H3: populate() stale data ───────────────────────────────────


class TestH3PopulateStaleData:
    def test_populate_resets_missing_numeric_field(self):
        """Missing field in record resets CobolDecimal to zero."""
        from cobol_file_io import CobolFileManager
        namespace = {
            "ws_amount": CobolDecimal('999', pic_integers=5),
        }
        meta = {
            "TEST-FILE": {
                "fields": [{"name": "WS-AMOUNT", "python_name": "ws_amount"}],
            }
        }
        mgr = CobolFileManager(meta, namespace, MagicMock())
        # Populate with record that's missing WS-AMOUNT
        mgr.populate("TEST-FILE", {})
        assert namespace["ws_amount"].value == Decimal("0")

    def test_populate_resets_missing_string_field(self):
        """Missing string field in record resets to empty string."""
        from cobol_file_io import CobolFileManager
        namespace = {
            "ws_name": "STALE DATA",
        }
        meta = {
            "TEST-FILE": {
                "fields": [{"name": "WS-NAME", "python_name": "ws_name"}],
            }
        }
        mgr = CobolFileManager(meta, namespace, MagicMock())
        mgr.populate("TEST-FILE", {})
        assert namespace["ws_name"] == ""


# ── H4: REDEFINES forward reference ─────────────────────────────


class TestH4RedefinesForwardRef:
    def test_forward_ref_raises(self):
        """REDEFINES with unknown target raises ValueError."""
        from copybook_resolver import resolve_redefines
        variables = [
            {"raw": "01WS-OVERLAYREDEFINESWS-UNKNOWNPICX(10).", "name": "WS-OVERLAY",
             "pic_raw": "X(10)", "pic_info": None, "comp3": False, "storage_type": "DISPLAY"},
            {"raw": "01WS-UNKNOWNPICX(10).", "name": "WS-UNKNOWN",
             "pic_raw": "X(10)", "pic_info": None, "comp3": False, "storage_type": "DISPLAY"},
        ]
        with pytest.raises(ValueError, match="not found"):
            resolve_redefines(variables)

    def test_valid_redefines_works(self):
        """REDEFINES with valid target succeeds."""
        from copybook_resolver import resolve_redefines
        variables = [
            {"raw": "01WS-BASEPICX(10).", "name": "WS-BASE",
             "pic_raw": "X(10)", "pic_info": None, "comp3": False, "storage_type": "DISPLAY"},
            {"raw": "01WS-OVERLAYREDEFINESWS-BASEPIC9(10).", "name": "WS-OVERLAY",
             "pic_raw": "9(10)", "pic_info": {"signed": False, "integers": 10, "decimals": 0},
             "comp3": False, "storage_type": "DISPLAY"},
        ]
        result = resolve_redefines(variables)
        assert result["memory_map"][1]["redefines"] == "WS-BASE"
        assert result["memory_map"][1]["offset"] == 0  # same as base


# ── H5: Daemon thread leak logging ──────────────────────────────


class TestH5DaemonThreadLeak:
    def test_timeout_logs_warning(self, caplog):
        """Timeout on exec logs a warning about orphan thread."""
        from shadow_diff import _execute_one_record
        # Code that runs forever
        infinite_code = (
            "def main():\n"
            "    while True:\n"
            "        pass\n"
        )
        with caplog.at_level(logging.WARNING, logger="shadow_diff"):
            result = _execute_one_record(
                source=infinite_code,
                record={},
                rec_idx=0,
                input_mapping={},
                output_fields=[],
                timeout_seconds=1,
            )
        assert "Timeout" in result.get("_error", "")
        assert any("orphan daemon thread" in r.message for r in caplog.records)
