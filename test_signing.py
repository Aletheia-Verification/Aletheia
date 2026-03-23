"""
test_signing.py — Cryptographic Report Signing Tests

19 tests covering:
  - Key generation and persistence (2)
  - Verification chain hashing (3)
  - Digital signing and verification (3)
  - Integration with vault and endpoints (3)
  - Chain-of-custody hashing (3)
  - Full-field record hash + chain verification (5)

Run with:
    pytest test_signing.py -v
"""

import base64
import json
import os
import shutil
import tempfile

import pytest

from report_signing import (
    get_or_create_keys,
    get_public_key_pem,
    get_public_key_fingerprint,
    build_verification_chain,
    build_record_hash,
    sign_report,
    verify_report,
)


@pytest.fixture
def tmp_keys_dir():
    """Temporary directory for test keys."""
    d = tempfile.mkdtemp(prefix="aletheia_test_keys_")
    yield d
    shutil.rmtree(d, ignore_errors=True)


# Sample analysis result for testing
SAMPLE_ANALYSIS = {
    "verification_status": "VERIFIED",
    "generated_python": "from decimal import Decimal\nresult = Decimal('100.00') * Decimal('0.05')",
    "parser_output": {
        "filename": "TEST.cbl",
        "summary": {"paragraphs": 2, "variables": 3},
    },
    "verification": {
        "executive_summary": "Test program verified.",
        "checklist": [{"item": "test", "status": "PASS"}],
    },
}

SAMPLE_COBOL = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEST-PROG.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-AMOUNT PIC S9(13)V99.
       PROCEDURE DIVISION.
       MAIN-LOGIC.
           MOVE 100.00 TO WS-AMOUNT.
           STOP RUN.
"""


# ══════════════════════════════════════════════════════════════════════
# Component 1: Key Management
# ══════════════════════════════════════════════════════════════════════


class TestKeyManagement:
    def test_key_generation(self, tmp_keys_dir):
        """Keys created, PEM format valid."""
        private_key, public_key = get_or_create_keys(tmp_keys_dir)
        assert private_key is not None
        assert public_key is not None

        # PEM files exist
        assert os.path.exists(os.path.join(tmp_keys_dir, "private.pem"))
        assert os.path.exists(os.path.join(tmp_keys_dir, "public.pem"))

        # Public key PEM string is valid
        pem = get_public_key_pem(tmp_keys_dir)
        assert pem.startswith("-----BEGIN PUBLIC KEY-----")
        assert pem.strip().endswith("-----END PUBLIC KEY-----")

    def test_key_persistence(self, tmp_keys_dir):
        """Keys survive reload — same fingerprint."""
        get_or_create_keys(tmp_keys_dir)
        fp1 = get_public_key_fingerprint(tmp_keys_dir)

        # Load again
        get_or_create_keys(tmp_keys_dir)
        fp2 = get_public_key_fingerprint(tmp_keys_dir)

        assert fp1 == fp2
        assert fp1.startswith("sha256:")
        assert len(fp1) == 7 + 64  # "sha256:" + 64 hex chars


# ══════════════════════════════════════════════════════════════════════
# Component 2: Report Hashing
# ══════════════════════════════════════════════════════════════════════


class TestReportHashing:
    def test_verification_chain(self):
        """All 4 hashes present, 64-char hex each."""
        chain = build_verification_chain(SAMPLE_ANALYSIS, SAMPLE_COBOL)
        assert len(chain["cobol_hash"]) == 64
        assert len(chain["python_hash"]) == 64
        assert len(chain["report_hash"]) == 64
        assert len(chain["chain_hash"]) == 64
        assert "timestamp" in chain

    def test_chain_deterministic(self):
        """Same input produces same chain hash."""
        chain1 = build_verification_chain(SAMPLE_ANALYSIS, SAMPLE_COBOL)
        chain2 = build_verification_chain(SAMPLE_ANALYSIS, SAMPLE_COBOL)
        assert chain1["cobol_hash"] == chain2["cobol_hash"]
        assert chain1["python_hash"] == chain2["python_hash"]
        assert chain1["report_hash"] == chain2["report_hash"]
        assert chain1["chain_hash"] == chain2["chain_hash"]

    def test_chain_changes_on_modification(self):
        """Different input produces different hash."""
        chain1 = build_verification_chain(SAMPLE_ANALYSIS, SAMPLE_COBOL)

        modified_cobol = SAMPLE_COBOL.replace("100.00", "200.00")
        chain2 = build_verification_chain(SAMPLE_ANALYSIS, modified_cobol)

        assert chain1["cobol_hash"] != chain2["cobol_hash"]
        assert chain1["chain_hash"] != chain2["chain_hash"]
        # Python hash should be same (same analysis result)
        assert chain1["python_hash"] == chain2["python_hash"]


# ══════════════════════════════════════════════════════════════════════
# Component 3: Signing and Verification
# ══════════════════════════════════════════════════════════════════════


class TestSigning:
    def test_sign_report(self, tmp_keys_dir):
        """Signature returned, base64 valid."""
        chain = build_verification_chain(SAMPLE_ANALYSIS, SAMPLE_COBOL)
        sig = sign_report(chain, keys_dir=tmp_keys_dir)

        assert "signature" in sig
        assert "public_key_fingerprint" in sig
        assert sig["algorithm"] == "RSA-PSS-SHA256"
        assert "verification_chain" in sig

        # Signature is valid base64
        decoded = base64.b64decode(sig["signature"])
        assert len(decoded) > 0

    def test_verify_valid(self, tmp_keys_dir):
        """Valid signature verifies True."""
        chain = build_verification_chain(SAMPLE_ANALYSIS, SAMPLE_COBOL)
        sig = sign_report(chain, keys_dir=tmp_keys_dir)
        result = verify_report(sig, keys_dir=tmp_keys_dir)

        assert result["valid"] is True
        assert "verified_at" in result

    def test_verify_tampered(self, tmp_keys_dir):
        """Modified chain_hash causes verification failure."""
        chain = build_verification_chain(SAMPLE_ANALYSIS, SAMPLE_COBOL)
        sig = sign_report(chain, keys_dir=tmp_keys_dir)

        # Tamper with the chain hash
        sig["verification_chain"]["chain_hash"] = "a" * 64

        result = verify_report(sig, keys_dir=tmp_keys_dir)
        assert result["valid"] is False

    def test_sign_report_none_args_raises(self, tmp_keys_dir):
        """C2 audit fix: sign_report with no data must raise ValueError."""
        with pytest.raises(ValueError, match="sign_report requires"):
            sign_report(None, None, keys_dir=tmp_keys_dir)

    def test_sign_report_empty_chain_raises(self, tmp_keys_dir):
        """C2 audit fix: chain without chain_hash must raise ValueError."""
        with pytest.raises(ValueError, match="sign_report requires"):
            sign_report({}, None, keys_dir=tmp_keys_dir)


# ══════════════════════════════════════════════════════════════════════
# Component 4: Integration
# ══════════════════════════════════════════════════════════════════════


class TestIntegration:
    def test_vault_save_with_signature(self, tmp_keys_dir, monkeypatch):
        """save_to_vault stores signature columns."""
        # Patch KEYS_DIR so we use temp keys
        import report_signing
        monkeypatch.setattr(report_signing, "KEYS_DIR", tmp_keys_dir)

        # Use a temporary vault.db
        import vault
        tmp_db = os.path.join(tempfile.mkdtemp(), "test_vault.db")
        monkeypatch.setattr(vault, "DB_PATH", tmp_db)
        vault._init_db()
        vault._migrate_db()

        record_id = vault.save_to_vault(SAMPLE_ANALYSIS, SAMPLE_COBOL)
        assert record_id > 0

        # Read back and check signature fields
        conn = vault._get_conn()
        row = conn.execute(
            "SELECT signature, public_key_fp, verification_chain FROM verifications WHERE id = ?",
            (record_id,),
        ).fetchone()
        conn.close()

        assert row["signature"] is not None
        assert row["public_key_fp"].startswith("sha256:")
        chain = json.loads(row["verification_chain"])
        assert len(chain["chain_hash"]) == 64

    def test_verify_endpoint(self, tmp_keys_dir, monkeypatch):
        """POST /verify with record_id returns valid."""
        from fastapi.testclient import TestClient
        import report_signing
        import vault

        monkeypatch.setattr(report_signing, "KEYS_DIR", tmp_keys_dir)

        tmp_db = os.path.join(tempfile.mkdtemp(), "test_vault.db")
        monkeypatch.setattr(vault, "DB_PATH", tmp_db)
        vault._init_db()
        vault._migrate_db()

        record_id = vault.save_to_vault(SAMPLE_ANALYSIS, SAMPLE_COBOL)

        from core_logic import app, create_access_token
        client = TestClient(app)
        token = create_access_token({"sub": "admin"})

        res = client.post(
            "/verify",
            json={"record_id": record_id},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert res.status_code == 200
        data = res.json()
        assert data["valid"] is True

    def test_public_key_endpoint(self, tmp_keys_dir, monkeypatch):
        """GET /verify/public-key returns PEM."""
        from fastapi.testclient import TestClient
        import report_signing

        monkeypatch.setattr(report_signing, "KEYS_DIR", tmp_keys_dir)

        from core_logic import app
        client = TestClient(app)

        res = client.get("/verify/public-key")
        assert res.status_code == 200
        data = res.json()
        assert data["public_key_pem"].startswith("-----BEGIN PUBLIC KEY-----")
        assert data["fingerprint"].startswith("sha256:")


# ══════════════════════════════════════════════════════════════════════
# Component 5: Chain-of-Custody Hashing
# ══════════════════════════════════════════════════════════════════════


class TestChainOfCustody:
    def test_chain_hash_includes_prev_hash(self):
        """chain_hash differs when prev_hash is included vs omitted."""
        chain_without = build_verification_chain(SAMPLE_ANALYSIS, SAMPLE_COBOL)
        chain_with = build_verification_chain(SAMPLE_ANALYSIS, SAMPLE_COBOL, prev_hash="a" * 64)

        assert chain_without["chain_hash"] != chain_with["chain_hash"]
        assert "prev_hash" not in chain_without
        assert chain_with["prev_hash"] == "a" * 64

    def test_genesis_prev_hash(self):
        """First record uses all-zeros genesis hash."""
        genesis = "0" * 64
        chain = build_verification_chain(SAMPLE_ANALYSIS, SAMPLE_COBOL, prev_hash=genesis)
        assert chain["prev_hash"] == genesis
        assert len(chain["chain_hash"]) == 64

    def test_chain_linking(self):
        """Record 2's prev_hash = Record 1's chain_hash creates valid link."""
        genesis = "0" * 64
        chain1 = build_verification_chain(SAMPLE_ANALYSIS, SAMPLE_COBOL, prev_hash=genesis)
        chain2 = build_verification_chain(SAMPLE_ANALYSIS, SAMPLE_COBOL, prev_hash=chain1["chain_hash"])

        assert chain2["prev_hash"] == chain1["chain_hash"]
        assert chain1["chain_hash"] != chain2["chain_hash"]


# ══════════════════════════════════════════════════════════════════════
# Component 6: Full-Field Record Hash + Chain Verification
# ══════════════════════════════════════════════════════════════════════


class TestFullFieldSignature:
    SAMPLE_ROW = {
        "id": 1, "timestamp": "2026-03-04T12:00:00Z",
        "filename": "TEST.cbl", "file_hash": "abc123",
        "verification_status": "VERIFIED",
        "paragraphs_count": 2, "variables_count": 3,
        "comp3_count": 0, "python_chars": 100,
        "arithmetic_safe": 2, "arithmetic_warn": 0,
        "arithmetic_critical": 0,
        "human_review_flags": 0, "checklist_pass": 5,
        "checklist_total": 5,
        "executive_summary": "Test verified.",
        "generated_python": "from decimal import Decimal",
        "full_report_json": '{"status": "ok"}',
        "prev_hash": "0" * 64,
        "verification_chain": '{"chain_hash": "def456"}',
    }

    def test_record_hash_deterministic(self):
        """Same fields produce same record_hash."""
        h1 = build_record_hash(self.SAMPLE_ROW)
        h2 = build_record_hash(self.SAMPLE_ROW)
        assert h1 == h2
        assert len(h1) == 64

    def test_record_hash_changes_on_any_field(self):
        """Changing any single field changes the record_hash."""
        original = build_record_hash(self.SAMPLE_ROW)
        for field in ("filename", "verification_status", "paragraphs_count",
                       "executive_summary", "prev_hash"):
            modified = dict(self.SAMPLE_ROW)
            modified[field] = "TAMPERED"
            assert build_record_hash(modified) != original, f"Field {field} didn't change hash"

    def test_sign_and_verify_record_hash(self, tmp_keys_dir):
        """record_hash signature round-trips through sign + verify."""
        chain = build_verification_chain(SAMPLE_ANALYSIS, SAMPLE_COBOL, prev_hash="0" * 64)
        rec_hash = build_record_hash(self.SAMPLE_ROW)
        sig = sign_report(chain, record_hash=rec_hash, keys_dir=tmp_keys_dir)

        assert sig["signed_field"] == "record_hash"

        result = verify_report(sig, record_hash=rec_hash, keys_dir=tmp_keys_dir)
        assert result["valid"] is True

    def test_verify_chain_clean(self, tmp_keys_dir, monkeypatch):
        """3 sequential vault records produce chain_intact=True."""
        import vault
        import report_signing

        monkeypatch.setattr(report_signing, "KEYS_DIR", tmp_keys_dir)

        tmp_db = os.path.join(tempfile.mkdtemp(), "test_chain.db")
        monkeypatch.setattr(vault, "DB_PATH", tmp_db)
        vault._init_db()
        vault._migrate_db()

        # Insert 3 records
        for _ in range(3):
            vault.save_to_vault(SAMPLE_ANALYSIS, SAMPLE_COBOL)

        from fastapi.testclient import TestClient
        from core_logic import app, create_access_token
        client = TestClient(app)
        token = create_access_token({"sub": "admin"})

        res = client.post("/vault/verify-chain",
                          headers={"Authorization": f"Bearer {token}"})
        assert res.status_code == 200
        data = res.json()
        assert data["total_records"] == 3
        assert data["chain_intact"] is True
        assert data["valid_signatures"] == 3
        assert data["invalid_signatures"] == 0
        assert len(data["chain_breaks"]) == 0

    def test_backward_compat_null_prev_hash(self, tmp_keys_dir, monkeypatch):
        """Legacy record with NULL prev_hash treated as genesis (no chain break)."""
        import vault
        import report_signing

        monkeypatch.setattr(report_signing, "KEYS_DIR", tmp_keys_dir)

        tmp_db = os.path.join(tempfile.mkdtemp(), "test_legacy.db")
        monkeypatch.setattr(vault, "DB_PATH", tmp_db)
        vault._init_db()
        vault._migrate_db()

        # Insert a legacy record (no prev_hash, no record_hash — simulate pre-upgrade)
        conn = vault._get_conn()
        conn.execute(
            """INSERT INTO verifications (timestamp, filename, file_hash, verification_status,
               paragraphs_count, variables_count, comp3_count, python_chars,
               arithmetic_safe, arithmetic_warn, arithmetic_critical,
               human_review_flags, checklist_pass, checklist_total,
               executive_summary, generated_python, full_report_json, username)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            ("2026-01-01T00:00:00Z", "LEGACY.cbl", "abc", "VERIFIED",
             1, 1, 0, 50, 1, 0, 0, 0, 1, 1, "Legacy", "pass", "{}", "admin"),
        )
        conn.commit()
        conn.close()

        # Now insert a new record through save_to_vault
        vault.save_to_vault(SAMPLE_ANALYSIS, SAMPLE_COBOL)

        from fastapi.testclient import TestClient
        from core_logic import app, create_access_token
        client = TestClient(app)
        token = create_access_token({"sub": "admin"})

        res = client.post("/vault/verify-chain",
                          headers={"Authorization": f"Bearer {token}"})
        assert res.status_code == 200
        data = res.json()
        assert data["total_records"] == 2
        # Legacy record has NULL prev_hash — treated as genesis, no break
        assert len(data["chain_breaks"]) == 0
