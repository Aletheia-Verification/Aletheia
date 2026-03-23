"""
vault.py — SQLite-backed verification audit trail for Aletheia.

Stores every /engine/analyze result with full provenance (file hash,
verification status, generated code, complete report JSON).
"""

import base64
import hashlib
import json
import logging
import os
import sqlite3
from datetime import datetime, timezone

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from fastapi import APIRouter, Depends, Header, HTTPException
from fastapi.responses import StreamingResponse

logger = logging.getLogger("aletheia.vault")

# ── Field-level AES-256-GCM encryption at rest ──────────────────────

_VAULT_KEY = None  # 32-byte AES key, loaded once at module init
_ENC_PREFIX = "ENC:"


def _load_vault_key():
    """Load encryption key from VAULT_ENCRYPTION_KEY env var (base64-encoded 32 bytes)."""
    global _VAULT_KEY
    raw = os.environ.get("VAULT_ENCRYPTION_KEY", "")
    if not raw:
        logger.warning(
            "VAULT_ENCRYPTION_KEY not set — vault data stored unencrypted"
        )
        return
    try:
        key_bytes = base64.b64decode(raw)
    except Exception:
        logger.error(
            "VAULT_ENCRYPTION_KEY is not valid base64 — vault encryption disabled"
        )
        return
    if len(key_bytes) != 32:
        raise ValueError(
            f"VAULT_ENCRYPTION_KEY must be 32 bytes base64 (got {len(key_bytes)} bytes)"
        )
    _VAULT_KEY = key_bytes
    logger.info("Vault encryption enabled (AES-256-GCM)")


def encrypt_field(plaintext: str) -> str:
    """AES-256-GCM encrypt a string field.

    Returns 'ENC:' + base64(nonce || ciphertext || tag).
    If no key is set, returns plaintext unchanged.
    """
    if _VAULT_KEY is None or not plaintext:
        return plaintext
    nonce = os.urandom(12)
    ct = AESGCM(_VAULT_KEY).encrypt(nonce, plaintext.encode("utf-8"), None)
    return _ENC_PREFIX + base64.b64encode(nonce + ct).decode("ascii")


def decrypt_field(stored: str) -> str:
    """Decrypt an AES-256-GCM encrypted field.

    Detects 'ENC:' prefix. Plaintext passthrough for legacy records.
    """
    if not stored or not stored.startswith(_ENC_PREFIX):
        return stored  # Unencrypted legacy record
    if _VAULT_KEY is None:
        return "[ENCRYPTED — key not available]"
    raw = base64.b64decode(stored[len(_ENC_PREFIX):])
    nonce, ct = raw[:12], raw[12:]
    return AESGCM(_VAULT_KEY).decrypt(nonce, ct, None).decode("utf-8")


_load_vault_key()

# ── Database path ────────────────────────────────────────────────────
DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "vault.db")

# ── Summary columns returned by /vault/list (no heavy blobs) ────────
_SUMMARY_COLS = (
    "id", "timestamp", "filename", "file_hash", "verification_status",
    "paragraphs_count", "variables_count", "comp3_count", "python_chars",
    "arithmetic_safe", "arithmetic_warn", "arithmetic_critical",
    "human_review_flags", "checklist_pass", "checklist_total",
    "prev_hash", "record_hash",
    "signature", "public_key_fp", "verification_chain",
)

_ALL_COLS = _SUMMARY_COLS + ("executive_summary", "generated_python", "full_report_json")

# Safety: verify all SQL column names are valid identifiers (defense against injection)
import re as _re
for _col in _ALL_COLS:
    assert _re.match(r'^[a-z_][a-z0-9_]*$', _col), f"Unsafe SQL column name: {_col}"
del _re, _col

# Pre-built constant SQL fragments — no dynamic column interpolation at query time
_SUMMARY_SELECT = "SELECT " + ", ".join(_SUMMARY_COLS) + " FROM verifications"
_ALL_SELECT = "SELECT " + ", ".join(_ALL_COLS) + " FROM verifications"


# ── Auth dependency (lazy import to avoid circular imports) ──────────

async def _verify_token(authorization: str = Header(None)) -> str:
    """Proxy to core_logic.verify_token_optional, returns 'guest' if no token."""
    from core_logic import verify_token_optional
    username = await verify_token_optional(authorization)
    return username or "guest"


# ── DB helpers ───────────────────────────────────────────────────────

def _get_conn() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def _init_db():
    conn = _get_conn()
    conn.execute("""
        CREATE TABLE IF NOT EXISTS verifications (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp           TEXT    NOT NULL,
            filename            TEXT    NOT NULL,
            file_hash           TEXT    NOT NULL,
            verification_status TEXT    NOT NULL,
            paragraphs_count    INTEGER DEFAULT 0,
            variables_count     INTEGER DEFAULT 0,
            comp3_count         INTEGER DEFAULT 0,
            python_chars        INTEGER DEFAULT 0,
            arithmetic_safe     INTEGER DEFAULT 0,
            arithmetic_warn     INTEGER DEFAULT 0,
            arithmetic_critical INTEGER DEFAULT 0,
            human_review_flags  INTEGER DEFAULT 0,
            checklist_pass      INTEGER DEFAULT 0,
            checklist_total     INTEGER DEFAULT 0,
            executive_summary   TEXT,
            generated_python    TEXT,
            full_report_json    TEXT,
            signature           TEXT,
            public_key_fp       TEXT,
            verification_chain  TEXT
        )
    """)
    conn.commit()
    conn.close()


_SAFE_MIGRATION_COLS = frozenset({"signature", "public_key_fp", "verification_chain", "prev_hash", "record_hash", "username"})


def _migrate_db():
    """Add new columns to existing databases (idempotent)."""
    conn = _get_conn()
    existing = {row["name"] for row in conn.execute("PRAGMA table_info(verifications)").fetchall()}
    for col in _SAFE_MIGRATION_COLS:
        if col not in existing:
            assert col in _SAFE_MIGRATION_COLS, f"Unsafe column name: {col}"
            conn.execute(f"ALTER TABLE verifications ADD COLUMN {col} TEXT")
    # Assign legacy records to admin
    if "username" in _SAFE_MIGRATION_COLS:
        conn.execute("UPDATE verifications SET username = 'admin' WHERE username IS NULL OR username = ''")
    conn.commit()
    conn.close()


_init_db()
_migrate_db()


# ── Public save function (called from core_logic.py) ────────────────

def save_to_vault(analysis_result: dict, cobol_code: str, username: str = "admin") -> int:
    """Extract fields from an /engine/analyze response and persist to vault.db."""
    file_hash = hashlib.sha256(cobol_code.encode("utf-8")).hexdigest()
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    parser = analysis_result.get("parser_output") or {}
    summary = parser.get("summary") or {}
    verification = analysis_result.get("verification") or {}
    checklist = verification.get("checklist") or []
    review_items = verification.get("human_review_items") or []
    arith = analysis_result.get("arithmetic_summary") or {}
    gen_py = analysis_result.get("generated_python") or ""

    checklist_pass = sum(1 for c in checklist if c.get("status") == "PASS")

    conn = _get_conn()

    # ── Chain-of-custody: get previous record's chain_hash ────────────
    prev_hash = "0" * 64  # genesis default
    try:
        last_row = conn.execute(
            "SELECT verification_chain FROM verifications ORDER BY id DESC LIMIT 1"
        ).fetchone()
        if last_row and last_row["verification_chain"]:
            last_chain = json.loads(last_row["verification_chain"])
            prev_hash = last_chain.get("chain_hash", "0" * 64)
    except (json.JSONDecodeError, KeyError):
        pass  # genesis

    # ── Build verification chain with prev_hash linkage ───────────────
    chain_json = None
    try:
        from report_signing import build_verification_chain
        chain = build_verification_chain(analysis_result, cobol_code, prev_hash=prev_hash)
        chain_json = json.dumps(chain)
    except ImportError:
        chain = None

    # ── INSERT with prev_hash and verification_chain ──────────────────
    filename = parser.get("filename", "unknown.cbl")
    status = analysis_result.get("verification_status", "REQUIRES_MANUAL_REVIEW")
    para_count = summary.get("paragraphs", 0)
    var_count = summary.get("variables", 0)
    comp3 = summary.get("comp3_variables", 0)
    py_chars = len(gen_py)
    safe = arith.get("safe", 0)
    warn = arith.get("warn", 0)
    critical = arith.get("critical", 0)
    flags = len(review_items)
    cl_total = len(checklist)
    exec_summary = verification.get("executive_summary", "")
    report_json = json.dumps(analysis_result, default=str)

    # ── Encrypt sensitive fields at rest ────────────────────────────
    gen_py = encrypt_field(gen_py)
    report_json = encrypt_field(report_json)

    cur = conn.execute(
        """
        INSERT INTO verifications (
            timestamp, filename, file_hash, verification_status,
            paragraphs_count, variables_count, comp3_count, python_chars,
            arithmetic_safe, arithmetic_warn, arithmetic_critical,
            human_review_flags, checklist_pass, checklist_total,
            executive_summary, generated_python, full_report_json,
            prev_hash, verification_chain, username
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            ts, filename, file_hash, status,
            para_count, var_count, comp3, py_chars,
            safe, warn, critical,
            flags, checklist_pass, cl_total,
            exec_summary, gen_py, report_json,
            prev_hash, chain_json, username,
        ),
    )
    conn.commit()
    record_id = cur.lastrowid

    # ── Full-field record hash + signature ────────────────────────────
    try:
        from report_signing import build_record_hash, sign_report
        row_fields = {
            "id": record_id, "timestamp": ts, "filename": filename,
            "file_hash": file_hash, "verification_status": status,
            "paragraphs_count": para_count, "variables_count": var_count,
            "comp3_count": comp3, "python_chars": py_chars,
            "arithmetic_safe": safe, "arithmetic_warn": warn,
            "arithmetic_critical": critical,
            "human_review_flags": flags, "checklist_pass": checklist_pass,
            "checklist_total": cl_total,
            "executive_summary": exec_summary, "generated_python": gen_py,
            "full_report_json": report_json,
            "prev_hash": prev_hash, "verification_chain": chain_json,
        }
        rec_hash = build_record_hash(row_fields)
        sig = sign_report(chain, record_hash=rec_hash)
        conn.execute(
            "UPDATE verifications SET record_hash=?, signature=?, public_key_fp=? WHERE id=?",
            (rec_hash, sig["signature"], sig["public_key_fingerprint"], record_id),
        )
        conn.commit()
    except ImportError:
        pass  # report_signing not available

    conn.close()
    logger.info("Vault: saved record #%d for %s (%s)",
                record_id, filename, file_hash[:12])
    return record_id


# ── FastAPI Router ───────────────────────────────────────────────────

vault_router = APIRouter()


@vault_router.get("/list")
async def vault_list(username: str = Depends(_verify_token)):
    """Return summary-only records for the authenticated user, newest first."""
    conn = _get_conn()
    rows = conn.execute(
        _SUMMARY_SELECT + " WHERE username = ? ORDER BY timestamp DESC",
        (username,),
    ).fetchall()
    conn.close()
    return {"records": [dict(r) for r in rows]}


@vault_router.get("/record/{record_id}")
async def vault_record(record_id: int, username: str = Depends(_verify_token)):
    """Return a single full record owned by the authenticated user."""
    conn = _get_conn()
    row = conn.execute(
        _ALL_SELECT + " WHERE id = ? AND username = ?", (record_id, username)
    ).fetchone()
    conn.close()
    if not row:
        raise HTTPException(status_code=404, detail="Record not found")
    rec = dict(row)
    rec["generated_python"] = decrypt_field(rec.get("generated_python") or "")
    rec["full_report_json"] = decrypt_field(rec.get("full_report_json") or "")
    return rec


@vault_router.delete("/record/{record_id}")
async def vault_delete(record_id: int, username: str = Depends(_verify_token)):
    """Delete a single record."""
    conn = _get_conn()
    row = conn.execute("SELECT id FROM verifications WHERE id = ? AND username = ?", (record_id, username)).fetchone()
    if not row:
        conn.close()
        raise HTTPException(status_code=404, detail="Record not found")
    conn.execute("DELETE FROM verifications WHERE id = ? AND username = ?", (record_id, username))
    conn.commit()
    conn.close()
    return {"deleted": True, "id": record_id}


@vault_router.post("/verify-chain")
async def vault_verify_chain(username: str = Depends(_verify_token)):
    """Walk user's records and verify chain-of-custody linkage + signatures."""
    verified_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    conn = _get_conn()
    rows = conn.execute(
        _ALL_SELECT + " WHERE username = ? ORDER BY id ASC",
        (username,),
    ).fetchall()
    conn.close()

    total = len(rows)
    valid_sigs = 0
    invalid_sigs = 0
    unsigned = 0
    chain_breaks = []
    tampered = []
    prev_chain_hash = "0" * 64  # genesis

    for row in rows:
        rec = dict(row)
        rec_id = rec["id"]

        # ── Chain linkage check ───────────────────────────────────
        row_prev_hash = rec.get("prev_hash")
        if row_prev_hash is None:
            # Legacy record (pre-upgrade) — treat as valid genesis
            pass
        elif row_prev_hash != prev_chain_hash:
            chain_breaks.append({
                "record_id": rec_id,
                "expected_prev_hash": prev_chain_hash[:16] + "...",
                "actual_prev_hash": (row_prev_hash or "NULL")[:16] + "...",
            })

        # Extract current record's chain_hash for next iteration
        try:
            vc = json.loads(rec.get("verification_chain") or "{}")
            current_chain_hash = vc.get("chain_hash", prev_chain_hash)
        except (json.JSONDecodeError, TypeError) as e:
            logger.warning("Chain verify: malformed verification_chain for record %d: %s", rec_id, e)
            current_chain_hash = prev_chain_hash

        # ── Record hash verification ──────────────────────────────
        stored_record_hash = rec.get("record_hash")
        if stored_record_hash:
            try:
                from report_signing import build_record_hash
                recomputed = build_record_hash(rec)
                if recomputed != stored_record_hash:
                    tampered.append({
                        "record_id": rec_id,
                        "detail": "record_hash mismatch — field tampering detected",
                    })
            except ImportError:
                logger.warning("Chain verify: report_signing module not available — tamper check skipped for record %d", rec_id)

        # ── Signature verification ────────────────────────────────
        if rec.get("signature"):
            try:
                from report_signing import verify_report
                sig_data = {
                    "signature": rec["signature"],
                    "signed_field": "record_hash" if stored_record_hash else "chain_hash",
                    "verification_chain": json.loads(rec.get("verification_chain") or "{}"),
                }
                result = verify_report(sig_data, record_hash=stored_record_hash)
                if result["valid"]:
                    valid_sigs += 1
                else:
                    invalid_sigs += 1
            except (ImportError, Exception) as e:
                logger.warning("Chain verify: signature verification failed for record %d: %s", rec_id, e)
                invalid_sigs += 1
        else:
            unsigned += 1

        prev_chain_hash = current_chain_hash

    return {
        "total_records": total,
        "valid_signatures": valid_sigs,
        "invalid_signatures": invalid_sigs,
        "unsigned_records": unsigned,
        "chain_breaks": chain_breaks,
        "tampered_records": tampered,
        "chain_intact": len(chain_breaks) == 0 and len(tampered) == 0,
        "verified_at": verified_at,
    }


@vault_router.get("/export")
async def vault_export(username: str = Depends(_verify_token)):
    """Download user's records as a JSON file."""
    conn = _get_conn()
    rows = conn.execute(
        _ALL_SELECT + " WHERE username = ? ORDER BY timestamp DESC",
        (username,),
    ).fetchall()
    conn.close()

    records = []
    for r in rows:
        rec = dict(r)
        rec["generated_python"] = decrypt_field(rec.get("generated_python") or "")
        rec["full_report_json"] = decrypt_field(rec.get("full_report_json") or "")
        records.append(rec)
    data = json.dumps(records, indent=2, default=str)
    ts = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")

    return StreamingResponse(
        iter([data]),
        media_type="application/json",
        headers={
            "Content-Disposition": f'attachment; filename="aletheia_vault_export_{ts}.json"'
        },
    )
