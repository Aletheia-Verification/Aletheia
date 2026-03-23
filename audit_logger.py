"""
audit_logger.py — SQLite-backed audit trail for Aletheia.

Logs WHO ran WHAT verification WHEN. Separate from vault.db
(which stores verification results). This stores operational
audit events for SOC-2 compliance.

Schema:
    audit_log(id, timestamp, username, action, details, ip_address, request_id)

Actions:
    LOGIN, ANALYZE, VERIFY_FULL, COMPILER_MATRIX, RISK_HEATMAP,
    PARSE_JCL, GENERATE_SBOM, EXPORT_PDF
"""

import json
import logging
import os
import sqlite3
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Header

logger = logging.getLogger("aletheia.audit")

DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "audit_log.db")


# ── Lazy auth proxy (same pattern as vault.py) ───────────────────

async def _verify_token(authorization: str = Header(None)) -> str:
    """Proxy to core_logic.verify_token_optional, returns 'guest' if no token."""
    from core_logic import verify_token_optional
    username = await verify_token_optional(authorization)
    return username or "guest"


# ── DB helpers ───────────────────────────────────────────────────

def _get_conn() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def _init_db():
    # WORM: Write-Once-Read-Many. Audit entries cannot be
    # modified or deleted. This is required for SOC 2 compliance.
    conn = _get_conn()
    conn.execute("""
        CREATE TABLE IF NOT EXISTS audit_log (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp   TEXT    NOT NULL,
            username    TEXT    NOT NULL,
            action      TEXT    NOT NULL,
            details     TEXT,
            ip_address  TEXT,
            request_id  TEXT
        )
    """)
    conn.execute("""
        CREATE TRIGGER IF NOT EXISTS no_update_audit
        BEFORE UPDATE ON audit_log BEGIN
            SELECT RAISE(ABORT, 'Audit log is immutable');
        END
    """)
    conn.execute("""
        CREATE TRIGGER IF NOT EXISTS no_delete_audit
        BEFORE DELETE ON audit_log BEGIN
            SELECT RAISE(ABORT, 'Audit log is immutable');
        END
    """)
    conn.commit()
    conn.close()


_init_db()


# ── Public API ───────────────────────────────────────────────────

def log_event(
    username: str,
    action: str,
    details: dict | None = None,
    ip_address: str = "local",
    request_id: str | None = None,
) -> None:
    """Insert an audit log entry. Thread-safe (each call opens its own connection)."""
    conn = _get_conn()
    try:
        conn.execute(
            "INSERT INTO audit_log (timestamp, username, action, details, ip_address, request_id) "
            "VALUES (?, ?, ?, ?, ?, ?)",
            (
                datetime.now(timezone.utc).isoformat(),
                username,
                action,
                json.dumps(details) if details else None,
                ip_address,
                request_id or uuid.uuid4().hex[:12],
            ),
        )
        conn.commit()
    finally:
        conn.close()


def get_recent(limit: int = 100) -> list[dict]:
    """Return recent audit entries, newest first."""
    conn = _get_conn()
    try:
        rows = conn.execute(
            "SELECT * FROM audit_log ORDER BY id DESC LIMIT ?", (limit,)
        ).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


# ── API Router ───────────────────────────────────────────────────

audit_router = APIRouter()


@audit_router.get("/log")
async def get_audit_log(limit: int = 100, username: str = Depends(_verify_token)):
    """Return recent audit log entries."""
    entries = get_recent(limit=min(limit, 1000))
    return {"entries": entries, "count": len(entries)}
