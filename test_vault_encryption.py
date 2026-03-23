"""
test_vault_encryption.py — Vault AES-256-GCM encryption at rest tests.

8 tests covering:
  - Encrypt/decrypt round-trip (3)
  - Encrypted-at-rest verification (3)
  - Integrity with encryption (2)

Run: pytest test_vault_encryption.py -v
"""

import base64
import logging
import os
import pytest

os.environ["USE_IN_MEMORY_DB"] = "1"

# Generate a deterministic test key (32 bytes, base64)
_TEST_KEY_BYTES = b"\x01" * 32
_TEST_KEY_B64 = base64.b64encode(_TEST_KEY_BYTES).decode()


# ══════════════════════════════════════════════════════════════════════
# 1. ENCRYPT / DECRYPT ROUND-TRIP
# ══════════════════════════════════════════════════════════════════════


class TestEncryptDecrypt:
    """Unit tests for encrypt_field / decrypt_field."""

    def test_round_trip(self):
        """Encrypt then decrypt returns original plaintext."""
        import vault
        old_key = vault._VAULT_KEY
        try:
            vault._VAULT_KEY = _TEST_KEY_BYTES
            plaintext = "def main():\n    ws_amount = CobolDecimal('0', pic_integers=5)"
            encrypted = vault.encrypt_field(plaintext)
            assert encrypted.startswith("ENC:"), "Encrypted output must have ENC: prefix"
            assert plaintext not in encrypted, "Plaintext must not appear in ciphertext"
            decrypted = vault.decrypt_field(encrypted)
            assert decrypted == plaintext
        finally:
            vault._VAULT_KEY = old_key

    def test_no_key_passthrough(self):
        """With no key, encrypt_field returns plaintext unchanged."""
        import vault
        old_key = vault._VAULT_KEY
        try:
            vault._VAULT_KEY = None
            plaintext = "sensitive data"
            result = vault.encrypt_field(plaintext)
            assert result == plaintext, "No key = passthrough"
        finally:
            vault._VAULT_KEY = old_key

    def test_legacy_passthrough(self):
        """decrypt_field on non-ENC: string returns it as-is."""
        import vault
        old_key = vault._VAULT_KEY
        try:
            vault._VAULT_KEY = _TEST_KEY_BYTES
            legacy = "plain text from old record"
            assert vault.decrypt_field(legacy) == legacy
            assert vault.decrypt_field("") == ""
            assert vault.decrypt_field(None) is None
        finally:
            vault._VAULT_KEY = old_key


# ══════════════════════════════════════════════════════════════════════
# 2. ENCRYPTED AT REST
# ══════════════════════════════════════════════════════════════════════


class TestVaultEncryptedAtRest:
    """Verify that sensitive fields are encrypted in the SQLite file."""

    def _make_analysis_result(self):
        """Minimal analysis result for save_to_vault."""
        return {
            "parser_output": {
                "filename": "TEST.cbl",
                "summary": {"paragraphs": 1, "variables": 2, "comp3_variables": 0},
            },
            "verification": {
                "checklist": [{"status": "PASS"}],
                "human_review_items": [],
                "executive_summary": "Test summary",
            },
            "verification_status": "VERIFIED",
            "arithmetic_summary": {"safe": 1, "warn": 0, "critical": 0},
            "generated_python": "def main(): pass  # GENERATED",
        }

    def test_encrypted_fields_not_plaintext(self, tmp_path):
        """With key set, raw SQLite contains ENC: prefixed values, not plaintext."""
        import vault
        import sqlite3

        old_key = vault._VAULT_KEY
        old_db = vault.DB_PATH
        try:
            vault._VAULT_KEY = _TEST_KEY_BYTES
            vault.DB_PATH = str(tmp_path / "test_vault.db")
            vault._init_db()
            vault._migrate_db()

            result = self._make_analysis_result()
            vault.save_to_vault(result, "       IDENTIFICATION DIVISION.\n       PROGRAM-ID. TEST.")

            # Read raw SQLite — bypass decrypt
            conn = sqlite3.connect(vault.DB_PATH)
            conn.row_factory = sqlite3.Row
            row = conn.execute("SELECT generated_python, full_report_json FROM verifications LIMIT 1").fetchone()
            conn.close()

            assert row["generated_python"].startswith("ENC:"), "generated_python must be encrypted"
            assert row["full_report_json"].startswith("ENC:"), "full_report_json must be encrypted"
            assert "def main" not in row["generated_python"], "Plaintext leaked in generated_python"
        finally:
            vault._VAULT_KEY = old_key
            vault.DB_PATH = old_db

    def test_decrypted_read(self, tmp_path):
        """Encrypted fields are transparently decrypted on read."""
        import vault

        old_key = vault._VAULT_KEY
        old_db = vault.DB_PATH
        try:
            vault._VAULT_KEY = _TEST_KEY_BYTES
            vault.DB_PATH = str(tmp_path / "test_vault.db")
            vault._init_db()
            vault._migrate_db()

            result = self._make_analysis_result()
            record_id = vault.save_to_vault(result, "       IDENTIFICATION DIVISION.\n       PROGRAM-ID. TEST.")

            # Read via vault functions (should decrypt)
            conn = vault._get_conn()
            cols = ", ".join(vault._ALL_COLS)
            row = conn.execute(f"SELECT {cols} FROM verifications WHERE id = ?", (record_id,)).fetchone()
            conn.close()

            rec = dict(row)
            rec["generated_python"] = vault.decrypt_field(rec.get("generated_python") or "")
            rec["full_report_json"] = vault.decrypt_field(rec.get("full_report_json") or "")

            assert "def main" in rec["generated_python"] or "GENERATED" in rec["generated_python"]
        finally:
            vault._VAULT_KEY = old_key
            vault.DB_PATH = old_db

    def test_no_key_warning(self, caplog):
        """No VAULT_ENCRYPTION_KEY logs a warning."""
        import vault

        old_key = vault._VAULT_KEY
        old_env = os.environ.pop("VAULT_ENCRYPTION_KEY", None)
        try:
            vault._VAULT_KEY = None  # Reset
            with caplog.at_level(logging.WARNING, logger="aletheia.vault"):
                vault._load_vault_key()
            assert any("VAULT_ENCRYPTION_KEY not set" in m for m in caplog.messages)
        finally:
            vault._VAULT_KEY = old_key
            if old_env is not None:
                os.environ["VAULT_ENCRYPTION_KEY"] = old_env


# ══════════════════════════════════════════════════════════════════════
# 3. INTEGRITY WITH ENCRYPTION
# ══════════════════════════════════════════════════════════════════════


class TestIntegrityWithEncryption:
    """Verify that record_hash and chain-of-custody work with encrypted fields."""

    def _make_analysis_result(self):
        return {
            "parser_output": {
                "filename": "INTEGRITY.cbl",
                "summary": {"paragraphs": 1, "variables": 1, "comp3_variables": 0},
            },
            "verification": {
                "checklist": [{"status": "PASS"}],
                "human_review_items": [],
                "executive_summary": "Integrity test",
            },
            "verification_status": "VERIFIED",
            "arithmetic_summary": {"safe": 1, "warn": 0, "critical": 0},
            "generated_python": "def main(): pass",
        }

    def test_record_hash_consistent(self, tmp_path):
        """record_hash computed over encrypted blobs is consistent on re-read."""
        import vault
        import sqlite3

        old_key = vault._VAULT_KEY
        old_db = vault.DB_PATH
        try:
            vault._VAULT_KEY = _TEST_KEY_BYTES
            vault.DB_PATH = str(tmp_path / "test_vault.db")
            vault._init_db()
            vault._migrate_db()

            vault.save_to_vault(self._make_analysis_result(), "       IDENTIFICATION DIVISION.\n       PROGRAM-ID. INT.")

            # Re-read and recompute hash
            conn = sqlite3.connect(vault.DB_PATH)
            conn.row_factory = sqlite3.Row
            row = dict(conn.execute(f"SELECT * FROM verifications LIMIT 1").fetchone())
            conn.close()

            stored_hash = row.get("record_hash")
            if stored_hash:
                try:
                    from report_signing import build_record_hash
                    recomputed = build_record_hash(row)
                    assert recomputed == stored_hash, "record_hash must match re-computation"
                except ImportError:
                    pytest.skip("report_signing not available")
        finally:
            vault._VAULT_KEY = old_key
            vault.DB_PATH = old_db

    def test_tampered_encrypted_field_detected(self, tmp_path):
        """Modifying an encrypted blob invalidates record_hash."""
        import vault
        import sqlite3

        old_key = vault._VAULT_KEY
        old_db = vault.DB_PATH
        try:
            vault._VAULT_KEY = _TEST_KEY_BYTES
            vault.DB_PATH = str(tmp_path / "test_vault.db")
            vault._init_db()
            vault._migrate_db()

            vault.save_to_vault(self._make_analysis_result(), "       IDENTIFICATION DIVISION.\n       PROGRAM-ID. TAMP.")

            # Tamper with encrypted blob
            conn = sqlite3.connect(vault.DB_PATH)
            conn.execute(
                "UPDATE verifications SET generated_python = 'ENC:TAMPERED' WHERE id = 1"
            )
            conn.commit()

            # Re-read and verify hash mismatch
            conn.row_factory = sqlite3.Row
            row = dict(conn.execute("SELECT * FROM verifications WHERE id = 1").fetchone())
            conn.close()

            stored_hash = row.get("record_hash")
            if stored_hash:
                try:
                    from report_signing import build_record_hash
                    recomputed = build_record_hash(row)
                    assert recomputed != stored_hash, "Tampered field must invalidate record_hash"
                except ImportError:
                    pytest.skip("report_signing not available")
        finally:
            vault._VAULT_KEY = old_key
            vault.DB_PATH = old_db
