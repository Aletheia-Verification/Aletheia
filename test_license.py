"""
test_license.py — License Manager Tests

Tests RSA-PSS license validation, grace/strict modes, feature flags, daily limits.
"""

import base64
import json
import os
import shutil
import tempfile

import pytest

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa

os.environ["USE_IN_MEMORY_DB"] = "true"


# ── Helpers ──────────────────────────────────────────────────────────

def _generate_test_keypair():
    """Generate a fresh RSA-2048 key pair for testing."""
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    public_key = private_key.public_key()
    pub_pem = public_key.public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    ).decode("utf-8")
    return private_key, public_key, pub_pem


def _sign_license_bytes(license_bytes: bytes, private_key) -> str:
    """Sign license.json bytes, return base64 signature."""
    sig = private_key.sign(
        license_bytes,
        padding.PSS(
            mgf=padding.MGF1(hashes.SHA256()),
            salt_length=padding.PSS.MAX_LENGTH,
        ),
        hashes.SHA256(),
    )
    return base64.b64encode(sig).decode("utf-8")


def _write_license(tmpdir: str, license_data: dict, private_key):
    """Write license.json + license.sig to tmpdir."""
    license_json = json.dumps(license_data, indent=2)
    license_bytes = license_json.encode("utf-8")

    with open(os.path.join(tmpdir, "license.json"), "wb") as f:
        f.write(license_bytes)

    sig_b64 = _sign_license_bytes(license_bytes, private_key)
    with open(os.path.join(tmpdir, "license.sig"), "w") as f:
        f.write(sig_b64)


# ── Fixtures ─────────────────────────────────────────────────────────

@pytest.fixture
def test_keys():
    """Generate a test key pair."""
    return _generate_test_keypair()


@pytest.fixture
def tmp_license_dir():
    """Temporary directory for license files."""
    d = tempfile.mkdtemp(prefix="aletheia_test_license_")
    yield d
    shutil.rmtree(d, ignore_errors=True)


@pytest.fixture(autouse=True)
def reset_license_state(test_keys, monkeypatch):
    """Reset module state before each test and patch the public key."""
    import license_manager

    _, _, pub_pem = test_keys

    # Patch the embedded public key to our test key
    monkeypatch.setattr(license_manager, "EMBEDDED_PUBLIC_KEY", pub_pem)
    monkeypatch.setattr(license_manager, "LICENSE_MODE", "strict")

    # Reset singleton state
    from license_manager import LicenseState, GraceCounter
    license_manager._LICENSE_STATE = LicenseState()
    license_manager._GRACE_COUNTER = GraceCounter()
    license_manager._DAILY_COUNTS = {"date": None, "count": 0}

    yield


# ══════════════════════════════════════════════════════════════════════
# Test: Key Management & Signing
# ══════════════════════════════════════════════════════════════════════


class TestKeyManagement:

    def test_generate_keypair(self, test_keys):
        private_key, public_key, pub_pem = test_keys
        assert "BEGIN PUBLIC KEY" in pub_pem
        assert "END PUBLIC KEY" in pub_pem
        assert private_key.key_size == 2048

    def test_sign_and_verify(self, test_keys):
        private_key, public_key, _ = test_keys
        data = b'{"test": "data"}'
        sig_b64 = _sign_license_bytes(data, private_key)
        sig_bytes = base64.b64decode(sig_b64)

        # Should not raise
        public_key.verify(
            sig_bytes, data,
            padding.PSS(mgf=padding.MGF1(hashes.SHA256()), salt_length=padding.PSS.MAX_LENGTH),
            hashes.SHA256(),
        )

    def test_wrong_key_rejects(self):
        """Sign with one key, verify with another — must fail."""
        key1, _, _ = _generate_test_keypair()
        _, pub2, _ = _generate_test_keypair()

        data = b'{"test": "data"}'
        sig_b64 = _sign_license_bytes(data, key1)
        sig_bytes = base64.b64decode(sig_b64)

        with pytest.raises(Exception):
            pub2.verify(
                sig_bytes, data,
                padding.PSS(mgf=padding.MGF1(hashes.SHA256()), salt_length=padding.PSS.MAX_LENGTH),
                hashes.SHA256(),
            )


# ══════════════════════════════════════════════════════════════════════
# Test: License Validation
# ══════════════════════════════════════════════════════════════════════


class TestLicenseValidation:

    def test_valid_license(self, test_keys, tmp_license_dir):
        import license_manager
        private_key, _, _ = test_keys

        _write_license(tmp_license_dir, {
            "license_id": "TEST-001",
            "customer": "Test Bank",
            "issued": "2026-01-01T00:00:00Z",
            "expires": "2030-12-31T00:00:00Z",
            "features": ["engine", "shadow_diff"],
            "max_analyses_per_day": 100,
        }, private_key)

        state = license_manager.load_and_verify_license(tmp_license_dir)
        assert state.valid is True
        assert state.license_data["customer"] == "Test Bank"
        assert state.features == {"engine", "shadow_diff"}
        assert state.error is None

    def test_expired_license(self, test_keys, tmp_license_dir):
        import license_manager
        private_key, _, _ = test_keys

        _write_license(tmp_license_dir, {
            "license_id": "TEST-EXP",
            "customer": "Expired Bank",
            "issued": "2020-01-01T00:00:00Z",
            "expires": "2020-12-31T00:00:00Z",
            "features": ["engine"],
            "max_analyses_per_day": 0,
        }, private_key)

        state = license_manager.load_and_verify_license(tmp_license_dir)
        assert state.valid is False
        assert "expired" in state.error.lower()

    def test_tampered_license(self, test_keys, tmp_license_dir):
        import license_manager
        private_key, _, _ = test_keys

        _write_license(tmp_license_dir, {
            "license_id": "TEST-TAMP",
            "customer": "Tampered Bank",
            "issued": "2026-01-01T00:00:00Z",
            "expires": "2030-12-31T00:00:00Z",
            "features": ["engine"],
            "max_analyses_per_day": 0,
        }, private_key)

        # Tamper with license.json after signing
        lpath = os.path.join(tmp_license_dir, "license.json")
        with open(lpath, "r") as f:
            data = json.load(f)
        data["customer"] = "Hacked Bank"
        with open(lpath, "w") as f:
            json.dump(data, f)

        state = license_manager.load_and_verify_license(tmp_license_dir)
        assert state.valid is False
        assert "signature" in state.error.lower() or "verification" in state.error.lower()

    def test_missing_license_json(self, tmp_license_dir):
        import license_manager

        state = license_manager.load_and_verify_license(tmp_license_dir)
        assert state.valid is False
        assert "not found" in state.error.lower()

    def test_missing_signature_file(self, test_keys, tmp_license_dir):
        import license_manager

        # Write only license.json, no .sig
        with open(os.path.join(tmp_license_dir, "license.json"), "w") as f:
            json.dump({"test": True}, f)

        state = license_manager.load_and_verify_license(tmp_license_dir)
        assert state.valid is False
        assert "sig" in state.error.lower()

    def test_wrong_signing_key(self, test_keys, tmp_license_dir):
        """License signed with a different private key than the embedded public key."""
        import license_manager
        wrong_private, _, _ = _generate_test_keypair()

        _write_license(tmp_license_dir, {
            "license_id": "TEST-WRONG",
            "customer": "Wrong Key Bank",
            "issued": "2026-01-01T00:00:00Z",
            "expires": "2030-12-31T00:00:00Z",
            "features": ["engine"],
            "max_analyses_per_day": 0,
        }, wrong_private)  # Signed with wrong key!

        state = license_manager.load_and_verify_license(tmp_license_dir)
        assert state.valid is False
        assert "signature" in state.error.lower() or "verification" in state.error.lower()


# ══════════════════════════════════════════════════════════════════════
# Test: Feature Flags
# ══════════════════════════════════════════════════════════════════════


class TestFeatureFlags:

    def test_feature_present(self, test_keys, tmp_license_dir):
        import license_manager
        private_key, _, _ = test_keys

        _write_license(tmp_license_dir, {
            "license_id": "TEST-FEAT",
            "customer": "Feature Bank",
            "expires": "2030-12-31T00:00:00Z",
            "features": ["engine", "shadow_diff", "vault"],
            "max_analyses_per_day": 0,
        }, private_key)

        license_manager.load_and_verify_license(tmp_license_dir)
        state = license_manager.get_license_state()
        assert "engine" in state.features
        assert "shadow_diff" in state.features
        assert "vault" in state.features

    def test_feature_missing(self, test_keys, tmp_license_dir):
        import license_manager
        private_key, _, _ = test_keys

        _write_license(tmp_license_dir, {
            "license_id": "TEST-NOFEAT",
            "customer": "Limited Bank",
            "expires": "2030-12-31T00:00:00Z",
            "features": ["engine"],
            "max_analyses_per_day": 0,
        }, private_key)

        license_manager.load_and_verify_license(tmp_license_dir)
        state = license_manager.get_license_state()
        assert "engine" in state.features
        assert "shadow_diff" not in state.features

    def test_require_feature_dependency(self, test_keys, tmp_license_dir):
        """Test the require_feature() FastAPI dependency factory."""
        import asyncio
        import license_manager
        private_key, _, _ = test_keys

        _write_license(tmp_license_dir, {
            "license_id": "TEST-RF",
            "customer": "Feature Bank",
            "expires": "2030-12-31T00:00:00Z",
            "features": ["engine"],
            "max_analyses_per_day": 0,
        }, private_key)

        license_manager.load_and_verify_license(tmp_license_dir)

        # engine feature should pass
        check_engine = license_manager.require_feature("engine")
        asyncio.run(check_engine())  # Should not raise

        # shadow_diff feature should fail
        check_shadow = license_manager.require_feature("shadow_diff")
        with pytest.raises(Exception) as exc_info:
            asyncio.run(check_shadow())
        assert exc_info.value.status_code == 403


# ══════════════════════════════════════════════════════════════════════
# Test: Daily Limit
# ══════════════════════════════════════════════════════════════════════


class TestDailyLimit:

    def test_within_limit(self, test_keys, tmp_license_dir):
        import license_manager
        private_key, _, _ = test_keys

        _write_license(tmp_license_dir, {
            "license_id": "TEST-LIMIT",
            "customer": "Limited Bank",
            "expires": "2030-12-31T00:00:00Z",
            "features": ["engine"],
            "max_analyses_per_day": 100,
        }, private_key)

        license_manager.load_and_verify_license(tmp_license_dir)

        # 5 calls should be fine
        for _ in range(5):
            license_manager._check_daily_limit()

    def test_exceeds_limit(self, test_keys, tmp_license_dir):
        import license_manager
        private_key, _, _ = test_keys

        _write_license(tmp_license_dir, {
            "license_id": "TEST-EXCEED",
            "customer": "Strict Bank",
            "expires": "2030-12-31T00:00:00Z",
            "features": ["engine"],
            "max_analyses_per_day": 3,
        }, private_key)

        license_manager.load_and_verify_license(tmp_license_dir)

        license_manager._check_daily_limit()  # 1
        license_manager._check_daily_limit()  # 2
        license_manager._check_daily_limit()  # 3

        with pytest.raises(Exception) as exc_info:
            license_manager._check_daily_limit()  # 4 — should fail
        assert exc_info.value.status_code == 429

    def test_unlimited(self, test_keys, tmp_license_dir):
        """max_analyses_per_day=0 means unlimited."""
        import license_manager
        private_key, _, _ = test_keys

        _write_license(tmp_license_dir, {
            "license_id": "TEST-UNLIM",
            "customer": "Unlimited Bank",
            "expires": "2030-12-31T00:00:00Z",
            "features": ["engine"],
            "max_analyses_per_day": 0,
        }, private_key)

        license_manager.load_and_verify_license(tmp_license_dir)

        # Should never raise
        for _ in range(200):
            license_manager._check_daily_limit()


# ══════════════════════════════════════════════════════════════════════
# Test: Grace Mode
# ══════════════════════════════════════════════════════════════════════


class TestGraceMode:

    def test_grace_allows_without_license(self, tmp_license_dir, monkeypatch):
        """Grace mode should allow analyses without a license (up to limits)."""
        import asyncio
        import license_manager
        from unittest.mock import MagicMock

        monkeypatch.setattr(license_manager, "LICENSE_MODE", "grace")
        license_manager.load_and_verify_license(tmp_license_dir)  # No license

        response = MagicMock()
        response.headers = {}

        # Should not raise in grace mode
        asyncio.run(
            license_manager.require_valid_license(response)
        )
        assert response.headers.get("X-Aletheia-License") == "missing"

    def test_grace_exhausted_by_count(self, tmp_license_dir, monkeypatch):
        """Grace mode should lock after _GRACE_MAX_ANALYSES."""
        import asyncio
        import license_manager
        from unittest.mock import MagicMock

        monkeypatch.setattr(license_manager, "LICENSE_MODE", "grace")
        monkeypatch.setattr(license_manager, "_GRACE_MAX_ANALYSES", 3)
        license_manager.load_and_verify_license(tmp_license_dir)  # No license

        response = MagicMock()
        response.headers = {}

        # First 3 should pass (counter increments inside _check_grace_exhausted)
        for _ in range(3):
            license_manager._GRACE_COUNTER.count = 0  # Reset for this test
        # Actually let's just exhaust it properly
        license_manager._GRACE_COUNTER.count = 0
        license_manager._GRACE_COUNTER.first_use = None

        # Calls 1-3 should work
        for _ in range(3):
            asyncio.run(
                license_manager.require_valid_license(response)
            )

        # Call 4 should fail (count > 3)
        with pytest.raises(Exception) as exc_info:
            asyncio.run(
                license_manager.require_valid_license(response)
            )
        assert exc_info.value.status_code == 403
        assert "grace" in exc_info.value.detail.lower()

    def test_strict_rejects_without_license(self, tmp_license_dir, monkeypatch):
        """Strict mode should immediately 403 without a license."""
        import asyncio
        import license_manager
        from unittest.mock import MagicMock

        monkeypatch.setattr(license_manager, "LICENSE_MODE", "strict")
        license_manager.load_and_verify_license(tmp_license_dir)  # No license

        response = MagicMock()

        with pytest.raises(Exception) as exc_info:
            asyncio.run(
                license_manager.require_valid_license(response)
            )
        assert exc_info.value.status_code == 403


# ══════════════════════════════════════════════════════════════════════
# Test: Integration (license_status endpoint)
# ══════════════════════════════════════════════════════════════════════


class TestStatusEndpoint:

    def test_status_valid(self, test_keys, tmp_license_dir):
        import asyncio
        import license_manager
        private_key, _, _ = test_keys

        _write_license(tmp_license_dir, {
            "license_id": "TEST-STATUS",
            "customer": "Status Bank",
            "expires": "2030-12-31T00:00:00Z",
            "features": ["engine", "vault"],
            "max_analyses_per_day": 500,
        }, private_key)

        license_manager.load_and_verify_license(tmp_license_dir)

        result = asyncio.run(
            license_manager.license_status()
        )
        assert result["valid"] is True
        assert result["customer"] == "Status Bank"
        assert "engine" in result["features"]

    def test_status_invalid(self, tmp_license_dir):
        import asyncio
        import license_manager

        license_manager.load_and_verify_license(tmp_license_dir)

        result = asyncio.run(
            license_manager.license_status()
        )
        assert result["valid"] is False
        assert result["error"] is not None
