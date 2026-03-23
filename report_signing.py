"""
report_signing.py — Cryptographic Report Signing for Aletheia

RSA 2048-bit digital signatures over verification reports.
Creates a tamper-proof chain: COBOL hash + Python hash + report hash → chain hash → signature.

Components:
  1. get_or_create_keys()         — RSA key pair management
  2. build_verification_chain()   — SHA-256 hashing pipeline
  3. sign_report()                — RSA-PSS digital signature
  4. verify_report()              — Signature verification
"""

import base64
import hashlib
import json
import logging
import os
from datetime import datetime, timezone

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa

logger = logging.getLogger("aletheia.signing")

# ── Key storage directory ────────────────────────────────────────────
KEYS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "aletheia_keys")


# ══════════════════════════════════════════════════════════════════════
# Component 1: Key Management
# ══════════════════════════════════════════════════════════════════════


def get_or_create_keys(keys_dir: str = None) -> tuple:
    """
    Load or generate RSA 2048-bit key pair.

    Returns (private_key, public_key).
    Keys stored as PEM files in keys_dir (default: aletheia_keys/).
    """
    kd = keys_dir or KEYS_DIR
    os.makedirs(kd, exist_ok=True)

    private_path = os.path.join(kd, "private.pem")
    public_path = os.path.join(kd, "public.pem")

    passphrase = os.environ.get("SIGNING_KEY_PASSPHRASE")
    pw_bytes = passphrase.encode("utf-8") if passphrase else None

    # Customer-managed signing key: load from external PEM path
    customer_key_path = os.environ.get("CUSTOMER_SIGNING_KEY")
    if customer_key_path:
        logger.info("Loading customer-managed signing key from %s", customer_key_path)
        with open(customer_key_path, "rb") as f:
            private_key = serialization.load_pem_private_key(f.read(), password=pw_bytes)
        public_key = private_key.public_key()
        return private_key, public_key

    if os.path.exists(private_path) and os.path.exists(public_path):
        # Load existing keys
        with open(private_path, "rb") as f:
            private_key = serialization.load_pem_private_key(f.read(), password=pw_bytes)
        with open(public_path, "rb") as f:
            public_key = serialization.load_pem_public_key(f.read())
        return private_key, public_key

    # Generate new key pair
    private_key = rsa.generate_private_key(
        public_exponent=65537,
        key_size=2048,
    )
    public_key = private_key.public_key()

    # Save private key — encrypt if passphrase provided
    if passphrase:
        enc_algo = serialization.BestAvailableEncryption(pw_bytes)
    else:
        logger.warning("SIGNING_KEY_PASSPHRASE not set — private key stored unencrypted")
        enc_algo = serialization.NoEncryption()

    with open(private_path, "wb") as f:
        f.write(private_key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=enc_algo,
        ))

    # Save public key
    with open(public_path, "wb") as f:
        f.write(public_key.public_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PublicFormat.SubjectPublicKeyInfo,
        ))

    logger.info("Generated new RSA 2048-bit key pair in %s", kd)
    return private_key, public_key


def get_public_key_pem(keys_dir: str = None) -> str:
    """Return public key as PEM string."""
    _, public_key = get_or_create_keys(keys_dir)
    return public_key.public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    ).decode("utf-8")


def get_public_key_fingerprint(keys_dir: str = None) -> str:
    """Return SHA-256 fingerprint of public key DER bytes."""
    _, public_key = get_or_create_keys(keys_dir)
    der_bytes = public_key.public_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    return "sha256:" + hashlib.sha256(der_bytes).hexdigest()


# ══════════════════════════════════════════════════════════════════════
# Component 2: Report Hashing
# ══════════════════════════════════════════════════════════════════════


def build_verification_chain(analysis_result: dict, cobol_code: str, prev_hash: str = None) -> dict:
    """
    Build SHA-256 verification chain over analysis artifacts.

    Hashes: COBOL source, generated Python, full report JSON.
    If prev_hash provided, includes it in chain computation for chain-of-custody linking.
    """
    cobol_hash = hashlib.sha256(cobol_code.encode("utf-8")).hexdigest()

    generated_python = analysis_result.get("generated_python", "")
    python_hash = hashlib.sha256(generated_python.encode("utf-8")).hexdigest()

    report_json = json.dumps(analysis_result, sort_keys=True, default=str)
    report_hash = hashlib.sha256(report_json.encode("utf-8")).hexdigest()

    chain_input = cobol_hash + python_hash + report_hash
    if prev_hash is not None:
        chain_input += prev_hash
    chain_hash = hashlib.sha256(chain_input.encode("utf-8")).hexdigest()

    result = {
        "cobol_hash": cobol_hash,
        "python_hash": python_hash,
        "report_hash": report_hash,
        "chain_hash": chain_hash,
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
    if prev_hash is not None:
        result["prev_hash"] = prev_hash
    return result


# ══════════════════════════════════════════════════════════════════════
# Component 2b: Full-Field Record Hash
# ══════════════════════════════════════════════════════════════════════


# Ordered list of non-signature columns to include in record hash
_RECORD_HASH_FIELDS = (
    "id", "timestamp", "filename", "file_hash", "verification_status",
    "paragraphs_count", "variables_count", "comp3_count", "python_chars",
    "arithmetic_safe", "arithmetic_warn", "arithmetic_critical",
    "human_review_flags", "checklist_pass", "checklist_total",
    "executive_summary", "generated_python", "full_report_json",
    "prev_hash", "verification_chain",
)


def build_record_hash(record_fields: dict) -> str:
    """
    SHA-256 over ALL non-signature columns for full-field tamper detection.

    Uses pipe separator between fields to prevent boundary ambiguity.
    """
    parts = []
    for field in _RECORD_HASH_FIELDS:
        val = record_fields.get(field)
        parts.append(str(val) if val is not None else "")
    payload = "|".join(parts)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


# ══════════════════════════════════════════════════════════════════════
# Component 3: Digital Signature
# ══════════════════════════════════════════════════════════════════════


def sign_report(verification_chain: dict, record_hash: str = None, keys_dir: str = None) -> dict:
    """
    Sign with RSA-PSS + SHA-256.

    If record_hash provided, signs the full-field record hash (new behavior).
    Otherwise signs chain_hash (backward compat for legacy records).
    """
    private_key, _ = get_or_create_keys(keys_dir)

    if record_hash:
        data_to_sign = record_hash
        signed_field = "record_hash"
    elif verification_chain and "chain_hash" in verification_chain:
        data_to_sign = verification_chain["chain_hash"]
        signed_field = "chain_hash"
    else:
        raise ValueError(
            "sign_report requires either record_hash or "
            "verification_chain with chain_hash"
        )

    signature_bytes = private_key.sign(
        data_to_sign.encode("utf-8"),
        padding.PSS(
            mgf=padding.MGF1(hashes.SHA256()),
            salt_length=padding.PSS.MAX_LENGTH,
        ),
        hashes.SHA256(),
    )

    return {
        "signature": base64.b64encode(signature_bytes).decode("utf-8"),
        "public_key_fingerprint": get_public_key_fingerprint(keys_dir),
        "algorithm": "RSA-PSS-SHA256",
        "signed_field": signed_field,
        "verification_chain": verification_chain,
    }


# ══════════════════════════════════════════════════════════════════════
# Component 4: Signature Verification
# ══════════════════════════════════════════════════════════════════════


def verify_report(signature_data: dict, record_hash: str = None, keys_dir: str = None) -> dict:
    """
    Verify a signed report's integrity.

    If signed_field is "record_hash", verifies against the provided record_hash.
    Otherwise falls back to chain_hash verification (backward compat).
    Returns {"valid": bool, "details": str, "verified_at": str}.
    """
    verified_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    try:
        _, public_key = get_or_create_keys(keys_dir)
    except Exception as e:
        return {
            "valid": False,
            "details": f"Key load failed: {e}",
            "verified_at": verified_at,
        }

    try:
        signature_b64 = signature_data.get("signature", "")
        signature_bytes = base64.b64decode(signature_b64)

        signed_field = signature_data.get("signed_field", "chain_hash")

        if signed_field == "record_hash" and record_hash:
            data_to_verify = record_hash
        else:
            chain = signature_data.get("verification_chain", {})
            data_to_verify = chain.get("chain_hash", "")

        if not data_to_verify:
            return {
                "valid": False,
                "details": "Missing hash data for verification",
                "verified_at": verified_at,
            }

        public_key.verify(
            signature_bytes,
            data_to_verify.encode("utf-8"),
            padding.PSS(
                mgf=padding.MGF1(hashes.SHA256()),
                salt_length=padding.PSS.MAX_LENGTH,
            ),
            hashes.SHA256(),
        )

        return {
            "valid": True,
            "details": f"Signature verified — {signed_field} integrity confirmed",
            "verified_at": verified_at,
        }

    except Exception as e:
        return {
            "valid": False,
            "details": f"Verification failed: {e}",
            "verified_at": verified_at,
        }
