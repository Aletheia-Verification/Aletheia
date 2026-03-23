"""
license_manager.py — License Key Validation for Aletheia

RSA-PSS signed license files control access to the verification engine.
Aletheia HQ holds the private key; customers receive license.json + license.sig.

Modes (ALETHEIA_LICENSE_MODE env var):
  strict  — 403 on all /engine/* without valid license (default)
  grace   — engine works, logs warnings; locks after 50 analyses or 7 days
"""

import base64
import json
import logging
import os
import threading
from dataclasses import dataclass, field
from datetime import datetime, timezone, timedelta
from typing import Optional, Set

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding
from fastapi import APIRouter, Depends, Header, HTTPException, Response

logger = logging.getLogger("aletheia.license")


# ── Embedded master public key (used to verify license signatures) ───
# This is the PUBLIC key only — the private key never leaves Aletheia HQ.

EMBEDDED_PUBLIC_KEY = """\
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA139+zBKMR8OmnWuyaLFX
7GCfDieo+ynD5ojPvOyAF85kFsxaNHE9VhNFIy77gA1zPvZondJs8d3BIHentgsd
yzccDS1gCZN+qZFfBoEMT5L0q3FJQNDpS+qzccv3i8TTQa4wdP2asyqwGvDmU+5S
+xEV81+91eS5mgR8c074vW6oIyFUuDTGElKpb8rv4SIEEH3hcAlFFaIS9rd5I56H
bEeh5iALScckZF+U103JEGTet23e6O7u+NHdm2BZT4iSdRaJoqolWLvoFYKbNRSI
eY3MPy0wROGRgNGmUiGs7XFR0vjLbwy7S9I3rpCA1b7zay30J0LL9Ll/A6RbYi4S
EQIDAQAB
-----END PUBLIC KEY-----
"""

# ── Configuration ────────────────────────────────────────────────────

LICENSE_DIR = os.environ.get("ALETHEIA_LICENSE_DIR",
                             os.path.join(os.path.dirname(os.path.abspath(__file__)), "license"))
LICENSE_MODE = os.environ.get("ALETHEIA_LICENSE_MODE", "strict")

# Grace-mode limits
_GRACE_MAX_ANALYSES = 50
_GRACE_MAX_DAYS = 7


# ── License state ────────────────────────────────────────────────────

@dataclass
class LicenseState:
    valid: bool = False
    license_data: Optional[dict] = None
    error: Optional[str] = None
    features: Set[str] = field(default_factory=set)


@dataclass
class GraceCounter:
    first_use: Optional[datetime] = None
    count: int = 0


_LICENSE_STATE = LicenseState()
_GRACE_COUNTER = GraceCounter()
_DAILY_COUNTS: dict = {"date": None, "count": 0}


# ── Core validation ──────────────────────────────────────────────────

def _load_public_key():
    """Load the embedded RSA public key."""
    return serialization.load_pem_public_key(EMBEDDED_PUBLIC_KEY.encode("utf-8"))


def load_and_verify_license(license_dir: str = None) -> LicenseState:
    """
    Read license.json + license.sig, verify RSA-PSS signature, check expiry.
    Updates the module-level _LICENSE_STATE singleton.
    """
    global _LICENSE_STATE
    ld = license_dir or LICENSE_DIR

    # Read license.json
    license_path = os.path.join(ld, "license.json")
    sig_path = os.path.join(ld, "license.sig")

    if not os.path.exists(license_path):
        _LICENSE_STATE = LicenseState(valid=False, error="license.json not found")
        return _LICENSE_STATE

    if not os.path.exists(sig_path):
        _LICENSE_STATE = LicenseState(valid=False, error="license.sig not found")
        return _LICENSE_STATE

    try:
        with open(license_path, "rb") as f:
            license_bytes = f.read()

        with open(sig_path, "r") as f:
            sig_b64 = f.read().strip()

        sig_bytes = base64.b64decode(sig_b64)
    except Exception as e:
        _LICENSE_STATE = LicenseState(valid=False, error=f"Failed to read license files: {e}")
        return _LICENSE_STATE

    # Verify RSA-PSS signature
    try:
        public_key = _load_public_key()
        public_key.verify(
            sig_bytes,
            license_bytes,
            padding.PSS(
                mgf=padding.MGF1(hashes.SHA256()),
                salt_length=padding.PSS.MAX_LENGTH,
            ),
            hashes.SHA256(),
        )
    except Exception as e:
        _LICENSE_STATE = LicenseState(valid=False, error=f"Signature verification failed: {e}")
        return _LICENSE_STATE

    # Parse and validate JSON
    try:
        data = json.loads(license_bytes.decode("utf-8"))
    except Exception as e:
        _LICENSE_STATE = LicenseState(valid=False, error=f"Invalid license JSON: {e}")
        return _LICENSE_STATE

    # Check expiry
    expires_str = data.get("expires")
    if expires_str:
        try:
            expires = datetime.fromisoformat(expires_str.replace("Z", "+00:00"))
            if datetime.now(timezone.utc) > expires:
                _LICENSE_STATE = LicenseState(valid=False, error="License expired",
                                              license_data=data)
                return _LICENSE_STATE
        except ValueError as e:
            _LICENSE_STATE = LicenseState(valid=False, error=f"Invalid expiry date: {e}")
            return _LICENSE_STATE

    features = set(data.get("features", []))

    _LICENSE_STATE = LicenseState(valid=True, license_data=data, features=features)
    logger.info("License valid: %s (expires %s)", data.get("customer", "unknown"), expires_str)
    return _LICENSE_STATE


def get_license_state() -> LicenseState:
    """Return current license state (read-only access to singleton)."""
    return _LICENSE_STATE


# ── Grace mode logic ─────────────────────────────────────────────────

_grace_lock = threading.Lock()


def _check_grace_exhausted() -> bool:
    """Return True if grace period is exhausted."""
    with _grace_lock:
        now = datetime.now(timezone.utc)

        if _GRACE_COUNTER.first_use is None:
            _GRACE_COUNTER.first_use = now

        _GRACE_COUNTER.count += 1

        days_elapsed = (now - _GRACE_COUNTER.first_use).days
        if days_elapsed >= _GRACE_MAX_DAYS:
            return True
        if _GRACE_COUNTER.count > _GRACE_MAX_ANALYSES:
            return True
        return False


# ── Daily analysis limit ─────────────────────────────────────────────

def _check_daily_limit():
    """Enforce max_analyses_per_day if set in license."""
    if not _LICENSE_STATE.valid or not _LICENSE_STATE.license_data:
        return

    max_per_day = _LICENSE_STATE.license_data.get("max_analyses_per_day", 0)
    if max_per_day <= 0:
        return

    today = datetime.now(timezone.utc).date()
    if _DAILY_COUNTS["date"] != today:
        _DAILY_COUNTS["date"] = today
        _DAILY_COUNTS["count"] = 0

    _DAILY_COUNTS["count"] += 1
    if _DAILY_COUNTS["count"] > max_per_day:
        raise HTTPException(
            status_code=429,
            detail=f"Daily analysis limit ({max_per_day}) exceeded. Resets at midnight UTC.",
        )


# ── FastAPI dependencies ─────────────────────────────────────────────

async def require_valid_license(response: Response):
    """
    FastAPI dependency — gates protected endpoints based on license state + mode.

    strict mode: 403 if no valid license
    grace mode:  warns via header, eventually 403 after limits exceeded
    """
    mode = LICENSE_MODE

    if _LICENSE_STATE.valid:
        _check_daily_limit()
        return

    # No valid license
    if mode == "grace":
        if _check_grace_exhausted():
            raise HTTPException(
                status_code=403,
                detail="Grace period expired. A valid license is required.",
            )
        response.headers["X-Aletheia-License"] = "missing"
        logger.warning("License missing — grace mode (%d/%d analyses, %s)",
                       _GRACE_COUNTER.count, _GRACE_MAX_ANALYSES,
                       _LICENSE_STATE.error or "no license")
        return

    # strict mode (default)
    raise HTTPException(
        status_code=403,
        detail=f"Valid license required. {_LICENSE_STATE.error or 'No license found.'}",
    )


def require_feature(feature_name: str):
    """Factory — returns a FastAPI dependency that checks for a specific feature."""
    async def _check_feature():
        if not _LICENSE_STATE.valid:
            return  # require_valid_license handles this
        if feature_name not in _LICENSE_STATE.features:
            raise HTTPException(
                status_code=403,
                detail=f"License does not include the '{feature_name}' feature.",
            )
    return _check_feature


# ── Auth dependency (lazy import to avoid circular imports) ──────────

async def _verify_token(authorization: str = Header(None)) -> str:
    """Proxy to core_logic.verify_token_optional, returns 'guest' if no token."""
    from core_logic import verify_token_optional
    username = await verify_token_optional(authorization)
    return username or "guest"


# ── Router ───────────────────────────────────────────────────────────

license_router = APIRouter()


@license_router.get("/status")
async def license_status():
    """Return license status. NOT gated — frontend needs this to display messaging."""
    state = _LICENSE_STATE
    if state.valid and state.license_data:
        return {
            "valid": True,
            "customer": state.license_data.get("customer"),
            "license_id": state.license_data.get("license_id"),
            "expires": state.license_data.get("expires"),
            "features": sorted(state.features),
            "mode": LICENSE_MODE,
        }
    return {
        "valid": False,
        "error": state.error,
        "mode": LICENSE_MODE,
    }


@license_router.post("/reload")
async def license_reload(username: str = Depends(_verify_token)):
    """Re-verify license from disk. Admin use — hot reload without restart."""
    state = load_and_verify_license()
    return {
        "valid": state.valid,
        "customer": state.license_data.get("customer") if state.license_data else None,
        "error": state.error,
    }
