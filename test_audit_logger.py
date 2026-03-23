"""Tests for audit_logger.py — SQLite-backed audit trail."""
import json
import os
import sqlite3
import pytest

os.environ["USE_IN_MEMORY_DB"] = "1"

from audit_logger import log_event, get_recent, _get_conn


class TestAuditLogger:

    def test_log_event_creates_entry(self):
        """log_event() inserts a row into audit_log."""
        log_event("testuser", "ANALYZE", {"filename": "TEST.cbl"})
        entries = get_recent(1)
        assert len(entries) >= 1
        assert entries[0]["username"] == "testuser"
        assert entries[0]["action"] == "ANALYZE"

    def test_log_entry_fields(self):
        """Entry has all required fields populated."""
        log_event("admin", "LOGIN", {"ip": "127.0.0.1"}, ip_address="127.0.0.1")
        entry = get_recent(1)[0]
        assert entry["timestamp"] is not None
        assert entry["username"] == "admin"
        assert entry["action"] == "LOGIN"
        assert entry["ip_address"] == "127.0.0.1"
        assert entry["request_id"] is not None

    def test_get_recent_limit(self):
        """get_recent respects the limit parameter."""
        for i in range(5):
            log_event(f"user{i}", "TEST_LIMIT")
        entries = get_recent(3)
        assert len(entries) == 3

    def test_details_json(self):
        """Details dict is stored as JSON and retrievable."""
        log_event("analyst", "ANALYZE", {"filename": "LOAN.cbl", "verdict": "VERIFIED"})
        entry = get_recent(1)[0]
        details = json.loads(entry["details"])
        assert details["verdict"] == "VERIFIED"
        assert details["filename"] == "LOAN.cbl"

    def test_log_without_details(self):
        """log_event works with details=None."""
        log_event("user", "LOGIN")
        entry = get_recent(1)[0]
        assert entry["details"] is None
        assert entry["action"] == "LOGIN"

    def test_entries_ordered_newest_first(self):
        """get_recent returns entries in reverse chronological order."""
        log_event("a", "FIRST")
        log_event("b", "SECOND")
        entries = get_recent(2)
        assert entries[0]["action"] == "SECOND"
        assert entries[1]["action"] == "FIRST"

    def test_worm_update_blocked(self):
        """WORM: UPDATE on audit_log is blocked by trigger."""
        log_event("worm_test", "WORM_CHECK")
        conn = _get_conn()
        with pytest.raises(sqlite3.IntegrityError, match="immutable"):
            conn.execute("UPDATE audit_log SET action='HACKED' WHERE username='worm_test'")
        conn.close()

    def test_worm_delete_blocked(self):
        """WORM: DELETE on audit_log is blocked by trigger."""
        log_event("worm_del", "WORM_DEL_CHECK")
        conn = _get_conn()
        with pytest.raises(sqlite3.IntegrityError, match="immutable"):
            conn.execute("DELETE FROM audit_log WHERE username='worm_del'")
        conn.close()

    def test_worm_insert_allowed(self):
        """WORM: INSERT still works (write-once is allowed)."""
        log_event("worm_ins", "WORM_INSERT_OK")
        entries = get_recent(1)
        assert entries[0]["username"] == "worm_ins"
