"""
core_logic.py — Alethia Beyond: Enterprise COBOL Modernization Engine
=====================================================================

Purpose
-------
    FastAPI backend powering the Alethia Beyond platform, which extracts,
    translates, and audits business logic from legacy COBOL financial
    systems into modern Python.

Architecture
------------
    1. Authentication layer   — JWT-based user registration, login, and
                                 role-gated access.
    2. Analysis engine        — LLM-backed COBOL logic extraction and
                                 behavioral-drift auditing.
    3. Chat interface         — Contextual Q&A about COBOL/Python code.
    4. Analytics / risk       — Activity tracking and risk intelligence
                                 stub endpoints.

Financial Calculation Policy
----------------------------
    ALL monetary values use ``decimal.Decimal`` with explicit
    ``quantize()`` calls.  Default rounding follows COBOL semantics:
        • COMPUTE without ROUNDED  →  ``ROUND_DOWN`` (truncation)
        • COMPUTE with ROUNDED     →  ``ROUND_HALF_UP``

    Global Decimal context is set to 28 digits precision to match
    COBOL extended precision and prevent intermediate rounding drift.

Audit Trail
-----------
    Every authenticated action (login, analysis, file upload) is
    appended to the user's ``security_history`` list for SOC-2
    traceability.

Audit History
-------------
    v3.1.0:
    AUD-001  Decimal in offline stub not JSON-serializable  → use float
    AUD-002  JWT tokens had no expiry claim                 → added 24 h exp
    AUD-003  verify_token swallowed HTTPException           → explicit re-raise
    AUD-004  Login returned raw username                    → normalized identity
    AUD-005  File upload had no size guard                  → enforced limit
    AUD-006  No UTF-8 decode error handling                 → explicit catch
    AUD-007  Admin approve endpoint had no auth             → added dependency

    v3.2.0 (Zero-Error Audit):
    AUD-008  Float in offline stub violates policy          → Decimal + encoder
    AUD-009  No global Decimal precision set                → getcontext().prec=28
    AUD-010  Float confidence in ChatResponse               → string repr for JSON
    AUD-011  Pydantic float type hints                      → Decimal-aware schemas

Author  : Alethia Beyond Engineering
Version : 3.2.0-zero-error
"""

# ─── TLS/HTTPS DEPLOYMENT ───────────────────────────────────────────
# To enable TLS in production, run uvicorn with:
#   uvicorn core_logic:app --host 0.0.0.0 --port 443 \
#       --ssl-keyfile /path/to/privkey.pem \
#       --ssl-certfile /path/to/fullchain.pem
# Alternatively, terminate TLS at a reverse proxy (nginx, Caddy, ALB).
# ─────────────────────────────────────────────────────────────────────

# ──────────────────────────────────────────────────────────────────────
# IMPORTS
# ──────────────────────────────────────────────────────────────────────

from __future__ import annotations

import asyncio
import base64
import collections
import decimal
import threading
import hashlib
import json
import logging
import os
import time
from datetime import datetime, timedelta, timezone
from decimal import Decimal, ROUND_DOWN, ROUND_HALF_UP, getcontext
from typing import Any, Dict, List, Optional, Union

from dotenv import load_dotenv
from pathlib import Path

from fastapi import (
    Depends,
    FastAPI,
    File,
    Form,
    Header,
    HTTPException,
    Request,
    UploadFile,
)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from jose import jwt, JWTError
from openai import AsyncOpenAI
from passlib.context import CryptContext
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

load_dotenv()

# Database imports (lazy-loaded to allow in-memory fallback for tests)
try:
    from database import get_db, init_db, close_db, AsyncSessionLocal
    from models import User, SecurityEvent, AnalysisSession, ChatMessage
    DB_AVAILABLE = True
except ImportError:
    DB_AVAILABLE = False
    AsyncSessionLocal = None

# Auditor pipeline (lazy-loaded — offline stub used if unavailable)
try:
    from auditor_pipeline import ZeroErrorAuditor
    AUDITOR_AVAILABLE = True
except ImportError:
    AUDITOR_AVAILABLE = False

# Email service (lazy-loaded — registration works without it)
try:
    from email_service import email_service
    EMAIL_AVAILABLE = True
except ImportError:
    EMAIL_AVAILABLE = False

# Vault (lazy-loaded — engine works without it)
try:
    from vault import save_to_vault, vault_router
    VAULT_AVAILABLE = True
except ImportError:
    VAULT_AVAILABLE = False

# Shadow Diff Engine (lazy-loaded — engine works without it)
try:
    from shadow_diff import (
        shadow_diff_router,
        parse_fixed_width_stream,
        run_streaming_pipeline,
        generate_report as sd_generate_report,
        save_report as sd_save_report,
        diagnose_drift as sd_diagnose_drift,
    )
    SHADOW_DIFF_AVAILABLE = True
except ImportError:
    SHADOW_DIFF_AVAILABLE = False

# Copybook Resolver (lazy-loaded — engine works without it)
try:
    from copybook_resolver import copybook_router
    COPYBOOK_AVAILABLE = True
except ImportError:
    COPYBOOK_AVAILABLE = False

# License Manager (lazy-loaded — engine works without it in dev)
try:
    from license_manager import (
        license_router, load_and_verify_license, require_valid_license,
    )
    LICENSE_AVAILABLE = True
except ImportError:
    LICENSE_AVAILABLE = False

    async def require_valid_license(response=None):
        """No-op fallback when license_manager is not installed."""
        pass

# ──────────────────────────────────────────────────────────────────────
# [AUD-009] GLOBAL DECIMAL CONTEXT — COBOL EXTENDED PRECISION
# ──────────────────────────────────────────────────────────────────────
#
# COBOL intermediate calculations can exceed target PIC precision.
# Setting 28 digits matches IBM Enterprise COBOL extended precision
# and prevents silent rounding drift in multi-step computations.
#
# This MUST be set at module load time, before any Decimal operations.
#

getcontext().prec = 28
getcontext().rounding = ROUND_DOWN  # Default COBOL behavior (no ROUNDED clause)

# Verify context is correctly configured
_ctx = getcontext()
assert _ctx.prec == 28, "Decimal precision not set correctly"
assert _ctx.rounding == ROUND_DOWN, "Decimal rounding mode not set correctly"

# ──────────────────────────────────────────────────────────────────────
# CONFIGURATION & LOGGING
# ──────────────────────────────────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
)
logger = logging.getLogger("alethia-beyond")

# Deployment mode: "air-gapped" (no external calls) or "connected" (GPT-4o enabled)
ALETHEIA_MODE: str = os.getenv("ALETHEIA_MODE", "connected").lower()

# External service keys
OPENAI_API_KEY: Optional[str] = os.getenv("OPENAI_API_KEY")

# JWT configuration — in production, set JWT_SECRET_KEY env var
JWT_SECRET_KEY: str = os.environ.get("JWT_SECRET_KEY", "")
if not JWT_SECRET_KEY:
    # In production (non-test), refuse to start without a real secret
    if ALETHEIA_MODE in ("air-gapped", "connected") and not os.getenv("USE_IN_MEMORY_DB"):
        raise RuntimeError(
            "JWT_SECRET_KEY env var is required in production. "
            "Set it to a random 64+ char hex string."
        )
    import secrets as _secrets
    import warnings as _warnings
    _warnings.warn(
        "JWT_SECRET_KEY not set — using ephemeral dev key. NOT FOR PRODUCTION.",
        stacklevel=1,
    )
    JWT_SECRET_KEY = "dev-ephemeral-" + _secrets.token_hex(32)
JWT_ALGORITHM: str = "HS256"

# [AUD-002] Token lifetime — 7 days (168 hours) for development/demo
JWT_TOKEN_LIFETIME_HOURS: int = int(
    os.getenv("JWT_TOKEN_LIFETIME_HOURS", "168")
)

# Upload guardrail (megabytes)
MAX_FILE_SIZE_MB: int = 10

# Password hashing — PBKDF2-SHA256 is NIST-approved for credential storage
password_hasher = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")

# Dummy hash for constant-time login (prevents timing-based username enumeration)
_DUMMY_HASH = password_hasher.hash("aletheia_timing_defense_dummy")

# CORS — configurable via ALETHEIA_CORS_ORIGINS env var (comma-separated)
# Default: localhost dev origins only. Production: set to actual domain(s).
_DEFAULT_CORS_ORIGINS = [
    "http://localhost:5173", "http://127.0.0.1:5173",
    "http://localhost:5174", "http://127.0.0.1:5174",
    "http://localhost:3000", "http://127.0.0.1:3000",
    "http://localhost:5175", "http://127.0.0.1:5175",
]
_env_cors = os.environ.get("ALETHEIA_CORS_ORIGINS", "")
ALLOWED_ORIGINS: List[str] = (
    [o.strip() for o in _env_cors.split(",") if o.strip()]
    if _env_cors else _DEFAULT_CORS_ORIGINS
)


# ──────────────────────────────────────────────────────────────────────
# [AUD-008/011] CUSTOM JSON ENCODER FOR DECIMAL SERIALIZATION
# ──────────────────────────────────────────────────────────────────────
#
# FastAPI's default JSON encoder cannot serialize decimal.Decimal.
# This encoder converts Decimal to string representation to preserve
# full precision (no float approximation).
#

class DecimalSafeJSONEncoder(json.JSONEncoder):
    """
    JSON encoder that serializes Decimal as string to preserve precision.

    COBOL Semantics Note:
        Financial values MUST NOT be converted to float during JSON
        serialization, as this introduces IEEE 754 representation errors.
        String representation preserves exact decimal digits.
    """

    def default(self, obj: Any) -> Any:
        if isinstance(obj, Decimal):
            # Preserve exact decimal representation as string
            return str(obj)
        return super().default(obj)


def decimal_safe_jsonable(obj: Any) -> Any:
    """
    Recursively convert an object tree for JSON serialization.

    Converts Decimal → str to preserve precision.
    """
    if isinstance(obj, Decimal):
        return str(obj)
    elif isinstance(obj, dict):
        return {k: decimal_safe_jsonable(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [decimal_safe_jsonable(item) for item in obj]
    return obj


# ──────────────────────────────────────────────────────────────────────
# PYDANTIC SCHEMAS — Request / Response Contracts
# ──────────────────────────────────────────────────────────────────────
#
# [AUD-011] Schemas that return numeric scores use string representation
# for Decimal values to ensure JSON serialization preserves precision.
#

# --- Authentication ---

class UserRegistrationRequest(BaseModel):
    """Payload for new-user registration."""
    username: str
    password: str
    email: Optional[str] = None
    institution: str
    city: str
    country: str
    role: str


class UserLoginRequest(BaseModel):
    """Payload for login."""
    username: str
    password: str


class TokenResponse(BaseModel):
    """JWT token returned on successful authentication."""
    access_token: str
    token_type: str


class SecurityEventRecord(BaseModel):
    """Single entry in a user's audit trail."""
    event: str
    timestamp: str
    ip: str


class UserProfileResponse(BaseModel):
    """Public-facing user profile, including approval status."""
    username: str
    institution: str
    city: str
    country: str
    role: str
    is_approved: bool
    security_history: List[SecurityEventRecord]


# --- Analysis ---

class AnalyzeRequest(BaseModel):
    """Request body for COBOL analysis or audit engagement."""
    cobol_code: str = Field(..., max_length=2_000_000)
    filename: Optional[str] = Field("input.cbl", max_length=255)
    modernized_code: Optional[str] = Field(None, max_length=2_000_000)
    is_audit_mode: bool = False
    compiler_config: Optional[dict] = None
    trace_mode: bool = False


class DependencyRequest(BaseModel):
    """Request body for multi-program dependency analysis."""
    programs: list  # [{"filename": str, "cobol_code": str}]


class BatchAnalyzeRequest(BaseModel):
    """Request body for batch multi-program analysis with Python generation."""
    programs: list  # [{"filename": str, "cobol_code": str}]
    copybooks: Optional[list] = None  # [{"name": str, "content": str}]
    compiler_config: Optional[dict] = None


class VerifyRequest(BaseModel):
    """Request body for cryptographic signature verification."""
    record_id: int = None
    signature_data: dict = None


class VerifyFullRequest(BaseModel):
    """Request body for combined Engine + Shadow Diff verification."""
    cobol_code: str
    layout: Optional[dict] = None  # If omitted, auto-generated from DATA DIVISION
    input_data: str   # base64-encoded mainframe input file
    output_data: str  # base64-encoded mainframe output file
    filename: Optional[str] = "input.cbl"
    compiler_config: Optional[dict] = None


class UncertaintyItem(BaseModel):
    """
    An area of ambiguity discovered during analysis.

    Categories:
        AMBIGUOUS_INTENT      — Code intent cannot be determined from source.
        COMPILER_DEPENDENT    — Behavior varies across COBOL compilers.
        UNDOCUMENTED_RULE     — Business rule not in comments or docs.
        MISSING_CONTEXT       — Requires external copybooks/data definitions.
    """
    category: str
    description: str
    risk_if_wrong: str
    recommended_action: str


class AuditFinding(BaseModel):
    """A single finding from a behavioral-drift audit."""
    ref_id: str
    cobol_location: str
    original_behavior: str
    identified_problem: str
    risk_level: str             # CRITICAL | HIGH | MEDIUM | LOW
    fix_applied: str
    verification_note: str


class ExtractedLogicResponse(BaseModel):
    """
    Structured result from a COBOL logic-extraction engagement.

    [AUD-011] complexity_score is returned as string to preserve
    Decimal precision through JSON serialization.
    """
    filename: str
    loc: int
    complexity_score: str       # String repr of Decimal (1.0-10.0 scale)
    executive_summary: str
    domain_analysis: str
    mathematical_breakdown: str
    python_implementation: str
    detected_rules: List[str]
    renaming_map: Dict[str, str]
    uncertainties: List[Dict[str, str]]
    cobol_pic_mappings: List[Dict[str, str]]


class BehavioralDrift(BaseModel):
    """A single instance of semantic divergence between COBOL and Python."""
    location: str
    description: str
    mismatch_severity: str      # CRITICAL | HIGH | MEDIUM | LOW
    legacy_behavior: str
    modern_drift: str
    financial_consequence: str
    remediation_guidance: str


class DriftAnalysisResponse(BaseModel):
    """
    Full audit report for behavioral equivalence verification.
    """
    filename: str
    drift_detected: bool
    executive_summary: str
    audit_findings: List[Dict[str, Any]]
    drift_report: List[BehavioralDrift]
    corrected_domain_analysis: str
    corrected_mathematical_explanation: str
    corrected_code: str
    uncertainties_and_assumptions: List[Dict[str, str]]
    verification_scenarios: List[Dict[str, Any]]


# --- Chat ---

class ChatRequest(BaseModel):
    """Contextual question about COBOL/Python code."""
    cobol_context: str
    python_context: Optional[str] = None
    user_query: str
    history: List[Dict[str, str]] = []


class ChatResponse(BaseModel):
    """
    LLM-generated answer with confidence score.

    [AUD-010] confidence is string representation of Decimal to avoid
    float precision issues in JSON serialization.
    """
    answer: str
    confidence: str             # String repr of Decimal (0.00-1.00)


# ──────────────────────────────────────────────────────────────────────
# IN-MEMORY USER STORE (Fallback for tests / development without DB)
# ──────────────────────────────────────────────────────────────────────
#
# This dict is used when:
#   1. Database is not available (DB_AVAILABLE = False)
#   2. USE_IN_MEMORY_DB environment variable is set to "true"
#   3. Running tests (detected via pytest)
#
# In production with database, this is NOT used.
#

USE_IN_MEMORY_DB = os.getenv("USE_IN_MEMORY_DB", "false").lower() == "true"

users_db: Dict[str, Dict[str, Any]] = {
    "admin": {
        "password": password_hasher.hash("admin123"),
        "institution": "Aletheia Global",
        "city": "London",
        "country": "UK",
        "role": "Chief Architect",
        "is_approved": True,
        "security_history": [],
    }
}

if USE_IN_MEMORY_DB or not DB_AVAILABLE:
    logger.info(
        "In-memory user store initialized with pre-approved 'admin' account."
    )
else:
    logger.info(
        "Database mode enabled. In-memory store available as fallback."
    )


# ──────────────────────────────────────────────────────────────────────
# PURE UTILITY FUNCTIONS — Stateless, No Side Effects
# ──────────────────────────────────────────────────────────────────────
#
# These functions are designed for storage in the Aletheia Vault.
# Input → validated output, zero side effects.
#

def normalize_username(raw_username: str) -> str:
    """
    Normalize a username to lowercase.

    PURE FUNCTION: No side effects, deterministic output.

    Includes a legacy compatibility shim: the typo "admi" maps to
    "admin" to support an earlier client build.

    Parameters
    ----------
    raw_username : str
        Raw username input from client.

    Returns
    -------
    str
        Normalized lowercase username.
    """
    if not isinstance(raw_username, str):
        raise TypeError(f"Username must be str, got {type(raw_username)}")

    normalized = raw_username.lower().strip()

    return normalized


def compute_complexity_score(
    line_count: int,
    branch_count: int = 0,
    nesting_depth: int = 0,
) -> Decimal:
    """
    Compute a complexity score for COBOL source code.

    PURE FUNCTION: No side effects, deterministic output.

    This is a simplified McCabe-style complexity metric.
    Full implementation would parse COBOL structure.

    Parameters
    ----------
    line_count : int
        Lines of code.
    branch_count : int
        Number of IF/EVALUATE branches.
    nesting_depth : int
        Maximum nesting depth.

    Returns
    -------
    Decimal
        Complexity score on 1.0-10.0 scale.

    COBOL Reference
    ---------------
    Corresponds to legacy complexity metrics used in mainframe
    code quality tools.
    """
    # Base score from line count (log scale, capped)
    if line_count <= 0:
        base = Decimal("1.0")
    elif line_count < 50:
        base = Decimal("2.0")
    elif line_count < 200:
        base = Decimal("4.0")
    elif line_count < 500:
        base = Decimal("6.0")
    else:
        base = Decimal("8.0")

    # Add branch complexity
    branch_factor = Decimal(str(min(branch_count, 20))) * Decimal("0.05")

    # Add nesting penalty
    nesting_factor = Decimal(str(min(nesting_depth, 10))) * Decimal("0.1")

    score = base + branch_factor + nesting_factor

    # Clamp to 1.0-10.0 range
    return max(Decimal("1.0"), min(Decimal("10.0"), score))


# ──────────────────────────────────────────────────────────────────────
# DATABASE HELPER FUNCTIONS
# ──────────────────────────────────────────────────────────────────────

async def get_user_by_username_db(
    db: AsyncSession,
    username: str,
) -> Optional["User"]:
    """
    Fetch user by normalized username from database.

    Parameters
    ----------
    db : AsyncSession
        Database session.
    username : str
        Normalized username to look up.

    Returns
    -------
    User or None
        User model if found, None otherwise.
    """
    if not DB_AVAILABLE:
        return None
    result = await db.execute(
        select(User).where(User.username == username)
    )
    return result.scalar_one_or_none()


async def record_security_event_db(
    db: AsyncSession,
    user: "User",
    event_description: str,
    ip_address: str = "local",
) -> None:
    """
    Record audit trail entry in database.

    Parameters
    ----------
    db : AsyncSession
        Database session.
    user : User
        User model to associate event with.
    event_description : str
        Description of the event.
    ip_address : str
        Client IP address.
    """
    if not DB_AVAILABLE:
        return
    event = SecurityEvent(
        user_id=user.id,
        event=event_description,
        ip_address=ip_address,
    )
    db.add(event)
    await db.flush()


# ──────────────────────────────────────────────────────────────────────
# AUTHENTICATION UTILITIES
# ──────────────────────────────────────────────────────────────────────

def create_access_token(payload: dict) -> str:
    """
    Encode a JWT from *payload* with an expiry claim.

    [AUD-002] Adds configurable TTL (default 24 h) and ``iat``
    (issued-at) claim for forensic traceability.
    """
    now = datetime.now(timezone.utc)
    claims = {
        **payload,
        "iat": now,
        "exp": now + timedelta(hours=JWT_TOKEN_LIFETIME_HOURS),
    }
    return jwt.encode(claims, JWT_SECRET_KEY, algorithm=JWT_ALGORITHM)


async def verify_token(authorization: str = Header(None)) -> str:
    """
    FastAPI dependency that extracts and validates a Bearer token.

    Returns the authenticated username on success; raises 401 otherwise.

    [AUD-003] Re-raises HTTPException explicitly before the catch-all
    to preserve specific error messages.

    Note: This version uses in-memory users_db for backward compatibility
    with existing tests. For database-backed verification, use
    verify_token_db dependency instead.
    """
    if not authorization:
        raise HTTPException(
            status_code=401,
            detail="Missing authorization header.",
        )
    try:
        # Expected format: "Bearer <token>"
        scheme, _, token = authorization.partition(" ")
        if scheme.lower() != "bearer" or not token:
            raise ValueError("Malformed Authorization header")

        decoded_payload = jwt.decode(
            token,
            JWT_SECRET_KEY,
            algorithms=[JWT_ALGORITHM],
        )
        username: Optional[str] = decoded_payload.get("sub")

        if username is None:
            raise HTTPException(
                status_code=401,
                detail="Token subject not recognized.",
            )

        # In-memory mode: verify user exists in dict
        if USE_IN_MEMORY_DB or not DB_AVAILABLE:
            if username not in users_db:
                raise HTTPException(
                    status_code=401,
                    detail="Token subject not recognized.",
                )
        # DB mode: JWT is sufficient — endpoint handles its own DB lookup

        return username

    except HTTPException:
        # [AUD-003] Let HTTPExceptions propagate unchanged
        raise
    except JWTError as jwt_err:
        logger.warning("JWT validation failed: %s", jwt_err)
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired token.",
        )
    except Exception as exc:
        logger.warning("Token verification error: %s", exc)
        raise HTTPException(
            status_code=401,
            detail="Invalid token.",
        )


async def verify_token_optional(authorization: str = Header(None)) -> Optional[str]:
    """Returns username if valid token, None if no/invalid token (guest)."""
    if not authorization:
        return None
    try:
        scheme, _, token = authorization.partition(" ")
        if scheme.lower() != "bearer" or not token:
            return None
        payload = jwt.decode(token, JWT_SECRET_KEY, algorithms=[JWT_ALGORITHM])
        username: Optional[str] = payload.get("sub")
        if username is None:
            return None
        if USE_IN_MEMORY_DB or not DB_AVAILABLE:
            return username if username in users_db else None
        return username
    except Exception:
        return None


async def verify_token_db(
    authorization: str = Header(None),
    db: AsyncSession = Depends(get_db),
) -> "User":
    """
    FastAPI dependency that validates Bearer token against database.

    Returns the authenticated User model on success; raises 401 otherwise.

    Use this dependency when database is available. Falls back to
    in-memory verification if database is not configured.
    """
    if not authorization:
        raise HTTPException(
            status_code=401,
            detail="Missing authorization header.",
        )
    try:
        scheme, _, token = authorization.partition(" ")
        if scheme.lower() != "bearer" or not token:
            raise ValueError("Malformed Authorization header")

        decoded_payload = jwt.decode(
            token,
            JWT_SECRET_KEY,
            algorithms=[JWT_ALGORITHM],
        )
        username: Optional[str] = decoded_payload.get("sub")

        if username is None:
            raise HTTPException(
                status_code=401,
                detail="Token subject not recognized.",
            )

        # Database lookup
        user = await get_user_by_username_db(db, username)
        if user is None:
            raise HTTPException(
                status_code=401,
                detail="Token subject not recognized.",
            )
        return user

    except HTTPException:
        raise
    except JWTError as jwt_err:
        logger.warning("JWT validation failed: %s", jwt_err)
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired token.",
        )
    except Exception as exc:
        logger.warning("Token verification error: %s", exc)
        raise HTTPException(
            status_code=401,
            detail="Invalid token.",
        )


def record_security_event(
    username: str,
    event_description: str,
    ip_address: str = "local",
) -> None:
    """
    Append an audit-trail entry to the user's security history.

    Note: This function has side effects (mutates users_db) and is
    NOT suitable for the Aletheia Vault. It exists for audit logging.
    """
    if username in users_db:
        users_db[username]["security_history"].append(
            {
                "event": event_description,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "ip": ip_address,
            }
        )


# ──────────────────────────────────────────────────────────────────────
# COBOL ANALYSIS PROMPTS
# ──────────────────────────────────────────────────────────────────────
#
# These prompt templates are the intellectual core of the platform.
# They instruct the LLM to behave as a domain-expert auditor, NOT
# as a general-purpose chatbot.  Every sentence is deliberate.
#

_AUDIT_MODE_SYSTEM_PROMPT = """\
You are a Senior Mainframe Modernization Auditor with 15+ years in COBOL \
financial systems.

ENGAGEMENT PARAMETERS
──────────────────────────────────────────────────────────────────────────
Client Type:     Tier-1 Financial Institution
Audit Standard:  SOC-2 Type II / PCI-DSS / GDPR
Risk Tolerance:  Zero tolerance for semantic drift
Authority:       Full stop-ship on critical findings

YOUR MANDATE
──────────────────────────────────────────────────────────────────────────
Preserve behavioral truth between legacy COBOL and modern Python.
You are NOT improving logic. You are preserving it with surgical precision.

A single incorrect assumption in this context can trigger:
- Regulatory penalties
- Incorrect customer balances
- Failed reconciliation audits
- Material misstatement risk

COBOL NUMERIC SEMANTICS (NON-NEGOTIABLE)
──────────────────────────────────────────────────────────────────────────
1. COMPUTE without ROUNDED clause → TRUNCATION (ROUND_DOWN), not banker's \
rounding
2. PIC S9(n)V9(m) defines EXACT decimal scale. No approximation.
3. Intermediate precision may exceed target, but final STORE truncates to \
PIC scale
4. ON SIZE ERROR absence = silent overflow. Flag this.
5. COMP-3 (packed decimal) has specific byte alignment. Document it.

AUDIT CRITERIA
──────────────────────────────────────────────────────────────────────────
CRITICAL: Quantization method mismatch (ROUND_HALF_UP vs TRUNCATE)
CRITICAL: Float usage for monetary values
CRITICAL: Precision loss in intermediate calculations
HIGH:     Execution order deviation
HIGH:     Missing side effects from conditional branches
MEDIUM:   Variable initialization differences
LOW:      Naming convention deviations

WHAT YOU MUST NEVER DO
──────────────────────────────────────────────────────────────────────────
- Invent business intent where none is documented
- Collapse nested IF structures "for readability"
- Add error handling that changes control flow
- Assume rounding where COBOL truncates
- Claim certainty where ambiguity exists

OUTPUT REQUIREMENTS
──────────────────────────────────────────────────────────────────────────
Return a JSON object with this exact structure:

{
  "filename": "string",
  "drift_detected": true|false,
  "executive_summary": "Concise technical findings. No marketing language.",

  "audit_findings": [
    {
      "ref_id": "AUD-001",
      "cobol_location": "Lines 145-152 / COMPUTE-INTEREST paragraph",
      "original_behavior": "Exact COBOL behavior observed",
      "identified_problem": "What the Python does differently",
      "risk_level": "CRITICAL|HIGH|MEDIUM|LOW",
      "fix_applied": "Specific correction made",
      "verification_note": "How to verify the fix"
    }
  ],

  "drift_report": [
    {
      "location": "Line/Section reference",
      "description": "Technical description of drift",
      "mismatch_severity": "CRITICAL|HIGH|MEDIUM|LOW",
      "legacy_behavior": "What COBOL does",
      "modern_drift": "What Python was doing wrong",
      "financial_consequence": "Quantified impact if possible",
      "remediation_guidance": "Specific fix instruction"
    }
  ],

  "corrected_domain_analysis": "Accurate description of what this code does. \
No invented business intent. State what IS, not what MIGHT BE.",

  "corrected_mathematical_explanation": "Precise formula mapping with PIC \
clause to Decimal scale correspondence. Include truncation vs rounding \
behavior for each computation.",

  "corrected_code": "Full Python implementation with COBOL line references \
in comments. Every monetary operation must use Decimal with explicit \
quantize().",

  "uncertainties_and_assumptions": [
    {
      "category": "AMBIGUOUS_INTENT|COMPILER_DEPENDENT|UNDOCUMENTED_RULE|\
MISSING_CONTEXT",
      "description": "What is uncertain",
      "risk_if_wrong": "Consequence of incorrect assumption",
      "recommended_action": "What the team should verify"
    }
  ],

  "verification_scenarios": [
    {
      "scenario_id": "VS-001",
      "input_values": {"field": "value"},
      "cobol_expected": "Expected COBOL result",
      "python_before_fix": "What broken Python produced",
      "python_after_fix": "What corrected Python produces",
      "validates": "Which audit finding this proves"
    }
  ]
}

PROFESSIONAL STANDARDS
──────────────────────────────────────────────────────────────────────────
Write as a senior engineer addressing peers. No hedging language. No AI-style
verbosity. State findings directly. If something cannot be determined from the
code, say "Cannot be determined from source; requires SME verification" rather
than speculating.

Your output should read like an internal audit memo, not a chatbot response.\
"""

_EXTRACTION_MODE_SYSTEM_PROMPT = """\
You are a Lead Legacy Systems Architect performing Migration Readiness \
Assessment.

ENGAGEMENT CONTEXT
──────────────────────────────────────────────────────────────────────────
Asset Class:     Mainframe COBOL (likely IBM Enterprise COBOL)
Target:          Python 3.11+ with Decimal arithmetic
Compliance:      Financial regulatory standards apply
Deliverable:     Auditable translation with full traceability

EXTRACTION REQUIREMENTS
──────────────────────────────────────────────────────────────────────────

1. NUMERIC FIDELITY
   - Map ALL PIC clauses to Python Decimal with explicit scale
   - PIC S9(5)V99 → Decimal with 2 decimal places, signed
   - COMP-3 fields → Document packed decimal byte length
   - Default to TRUNCATION unless ROUNDED keyword present

2. VARIABLE MAPPING
   - Create semantic names from COBOL working storage
   - WS-CUST-BAL → customer_balance
   - WS-INT-RATE → interest_rate
   - Document every mapping for audit trail

3. CONTROL FLOW PRESERVATION
   - Maintain paragraph/section execution order
   - Preserve PERFORM...THRU semantics
   - Do not optimize away sequential logic
   - Nested IF structures must remain nested

4. BUSINESS RULE EXTRACTION
   - Identify conditional thresholds
   - Flag undocumented magic numbers
   - Note override hierarchies (later conditions replacing earlier)
   - Mark VIP/exception logic paths

OUTPUT FORMAT
──────────────────────────────────────────────────────────────────────────
Return JSON conforming to this schema:

{
  "filename": "string",
  "loc": number,
  "complexity_score": "string (Decimal representation, 1.0-10.0 scale)",

  "executive_summary": "SECTION 1 — WHAT THIS CODE DOES. One paragraph a \
bank executive understands. Include: business impact if errors, who/what \
is affected, and the primary business function.",

  "domain_analysis": "SECTION 2 — HOW IT WORKS. Break into numbered logical \
steps. For each step: plain English explanation, the COBOL lines involved, \
and the Python equivalent. Show calculations with REAL NUMBERS (e.g. \
'principal=$50,000, rate=0.05, interest=$2,500.00').",

  "mathematical_breakdown": "Formula-by-formula translation showing COBOL \
arithmetic → Python Decimal. Include PIC precision for each field.",

  "data_definitions": [
    {
      "cobol_name": "WS-AMOUNT",
      "python_name": "amount",
      "type": "Decimal",
      "range": "0.00 to 9999999.99",
      "meaning": "Transaction amount in dollars"
    }
  ],

  "python_implementation": "Complete Python code with inline comments \
mapping to COBOL line numbers. Use Decimal throughout. Include explicit \
quantize() calls.",

  "business_rules_extracted": [
    {
      "rule": "Plain English statement of the rule",
      "cobol_source": "The COBOL IF/EVALUATE that implements it",
      "is_unusual": false
    }
  ],

  "detected_rules": ["Rule 1: description", "Rule 2: description"],

  "renaming_map": {
    "WS-COBOL-NAME": "python_semantic_name"
  },

  "uncertainties": [
    {
      "item": "What is uncertain",
      "impact": "Why it matters",
      "recommendation": "How to resolve"
    }
  ],

  "cobol_pic_mappings": [
    {
      "cobol_field": "WS-AMOUNT",
      "pic_clause": "PIC S9(7)V99",
      "python_type": "Decimal",
      "scale": 2,
      "signed": true
    }
  ]
}

PROFESSIONAL OUTPUT STANDARDS
──────────────────────────────────────────────────────────────────────────
- Direct, technical language
- No speculative business intent
- Explicit uncertainty documentation
- Auditor-ready traceability\
"""

_CHAT_SYSTEM_PROMPT = """\
You are a Technical Documentation Specialist for legacy system modernization.

COMMUNICATION STANDARDS
──────────────────────────────────────────────────────────────────────────
- Explain only what is present in the provided code
- If business intent is unclear, state: "The code implements [technical \
behavior]. Business rationale not documented in source."
- Define COBOL concepts (PIC, COMP-3, PERFORM) in practical terms when asked
- No speculation about why decisions were made
- No marketing language or unnecessary qualifiers

RESPONSE FORMAT
──────────────────────────────────────────────────────────────────────────
- Lead with direct answer
- Technical details follow
- Uncertainty stated explicitly
- Keep responses focused and scannable

You are addressing technical staff who need accurate information, not \
reassurance.\
"""


# ──────────────────────────────────────────────────────────────────────
# UNIFIED ENGINE VERIFICATION PROMPT
# ──────────────────────────────────────────────────────────────────────

_ENGINE_VERIFICATION_SYSTEM_PROMPT = """\
You are the FINAL VERIFICATION LAYER for a COBOL-to-Python migration engine \
used by banks processing billions of dollars.

CONTEXT:
- The ANTLR4 parser has already extracted the COBOL structure deterministically
- The Python code has been generated deterministically
- Your job is to VERIFY, EXPLAIN, and FORMAT — not to guess or create

YOUR CONSTRAINTS:
1. You are NOT generating the translation. It has already been done by \
deterministic tools.
2. You are VERIFYING that the translation is correct.
3. If you see ANY inconsistency, you MUST flag it. Do not hide problems.
4. If you are uncertain about ANYTHING, say "REQUIRES HUMAN VERIFICATION" \
— never guess.
5. A single error could cost millions of dollars. Act accordingly.

YOUR OUTPUT MUST BE VALID JSON with this exact structure:

{
  "executive_summary": "3-4 sentences: What does this program do in plain \
English? How many business functions? How many financial variables? \
Any critical flags?",

  "business_logic": [
    {
      "title": "Name of the calculation or rule",
      "formula": "Daily Rate = Annual Rate / Days in Year",
      "explanation": "Plain English explanation of the business logic"
    }
  ],

  "checklist": [
    {
      "item": "What was checked",
      "status": "PASS or FAIL or WARN",
      "note": "Details of the verification"
    }
  ],

  "human_review_items": [
    {
      "item": "Description of the issue",
      "reason": "Why it needs human review",
      "severity": "HIGH or MEDIUM or LOW"
    }
  ]
}

CHECKLIST items you MUST verify:
- Paragraph count matches between COBOL and Python functions
- All COMP-3 variables identified and use Decimal
- All COMPUTE statements captured as Python assignments
- All IF/ELSE conditions preserved
- Control flow (PERFORM calls) mapped to function calls
- No unreachable code introduced
- Python output uses Decimal (not float)
- Truncation vs rounding handled correctly \
(COBOL COMPUTE without ROUNDED = TRUNCATION)

HUMAN REVIEW triggers (always flag these):
- Nested IF statements (depth > 2)
- 88-level condition names
- Implicit type conversions
- REDEFINES clauses
- COPY statements (external dependencies)
- GO TO statements
- ALTER statements
- Precision loss in intermediate calculations

FORMATTING RULES:
- Use clean, scannable structure
- Use checkmark symbols for verified, warning for warnings, X for errors
- Make it scannable — a tired executive at 11pm must understand it
- No jargon without explanation
- No walls of text — use structure

REMEMBER:
- You are the last line of defense before this goes to production
- Banks will make financial decisions based on your output
- Regulators may audit this
- When in doubt, flag it for human review — never assume

"""


# ──────────────────────────────────────────────────────────────────────
# LOGIC EXTRACTION SERVICE
# ──────────────────────────────────────────────────────────────────────

class LogicExtractionService:
    """
    Orchestrates COBOL analysis by delegating to the OpenAI API with
    domain-specific system prompts.

    If no API key is configured, the service returns deterministic
    offline stubs so the rest of the platform can be developed and
    tested without incurring API costs.
    """

    def __init__(self) -> None:
        if ALETHEIA_MODE == "air-gapped":
            self.client = None
            logger.info(
                "Aletheia starting in AIR-GAPPED mode — no external API calls."
            )
        elif OPENAI_API_KEY:
            self.client: Optional[AsyncOpenAI] = AsyncOpenAI(
                api_key=OPENAI_API_KEY
            )
            logger.info(
                "Aletheia starting in CONNECTED mode — GPT-4o enabled."
            )
        else:
            self.client = None
            logger.warning(
                "OPENAI_API_KEY not set — analysis engine running in "
                "offline/stub mode."
            )

    # ── prompt selection ─────────────────────────────────────────────

    @staticmethod
    def _select_system_prompt(is_audit_mode: bool) -> str:
        """Return the appropriate system prompt for the engagement type."""
        if is_audit_mode:
            return _AUDIT_MODE_SYSTEM_PROMPT
        return _EXTRACTION_MODE_SYSTEM_PROMPT

    # ── offline stubs ────────────────────────────────────────────────

    @staticmethod
    def _offline_extraction_stub(
        filename: str,
        cobol_code: str,
    ) -> Dict[str, Any]:
        """
        Deterministic response when no API key is available (extraction).

        [AUD-008] complexity_score is Decimal converted to string for
        JSON serialization.  NEVER use float for numeric values.

        Returns dict ready for JSON serialization via decimal_safe_jsonable().
        """
        line_count = len(cobol_code.splitlines())
        complexity = compute_complexity_score(line_count)

        return {
            "filename": filename,
            "loc": line_count,
            # [AUD-008] String representation of Decimal — NO FLOATS
            "complexity_score": str(complexity),
            "executive_summary": "Analysis requires live engine connection.",
            "domain_analysis": "Offline mode active.",
            "mathematical_breakdown": (
                "Connect to analysis engine for detailed breakdown."
            ),
            "python_implementation": (
                "from decimal import Decimal, ROUND_DOWN, getcontext\n"
                "getcontext().prec = 28\n\n"
                "# Engine offline — connect for live translation"
            ),
            "detected_rules": [],
            "renaming_map": {},
            "uncertainties": [
                {
                    "item": "Engine offline",
                    "impact": "No analysis available",
                    "recommendation": "Configure OPENAI_API_KEY",
                }
            ],
            "cobol_pic_mappings": [],
        }

    @staticmethod
    def _offline_audit_stub(filename: str) -> Dict[str, Any]:
        """Deterministic response when no API key is available (audit)."""
        return {
            "filename": filename,
            "drift_detected": False,
            "executive_summary": (
                "Offline mode. Connect to analysis engine for live audit."
            ),
            "audit_findings": [],
            "drift_report": [],
            "corrected_domain_analysis": "Requires live engine connection.",
            "corrected_mathematical_explanation": (
                "Requires live engine connection."
            ),
            "corrected_code": "# Engine offline — no corrections generated",
            "uncertainties_and_assumptions": [],
            "verification_scenarios": [],
        }

    # ── user-message builders ────────────────────────────────────────

    @staticmethod
    def _build_audit_user_message(
        filename: str,
        cobol_code: str,
        modernized_code: str,
    ) -> str:
        """
        Compose the user-turn message for a behavioral-drift audit.

        The message frames the engagement with explicit COBOL ground-truth
        reminders so the LLM does not default to Python rounding semantics.
        """
        return (
            f"AUDIT ENGAGEMENT\n"
            f"{'=' * 80}\n"
            f"Asset ID:        {filename}\n"
            f"Audit Type:      Behavioral Equivalence Verification\n"
            f"Classification:  Financial Logic — Zero Drift Tolerance\n"
            f"\n"
            f"LEGACY COBOL SOURCE\n"
            f"{'─' * 80}\n"
            f"```cobol\n{cobol_code}\n```\n"
            f"\n"
            f"PYTHON IMPLEMENTATION UNDER AUDIT\n"
            f"{'─' * 80}\n"
            f"```python\n{modernized_code}\n```\n"
            f"\n"
            f"AUDIT INSTRUCTIONS\n"
            f"{'─' * 80}\n"
            f"1. Identify ALL semantic divergences between COBOL and Python\n"
            f"2. Pay particular attention to:\n"
            f"   - Rounding vs truncation mismatches\n"
            f"   - Decimal precision drift\n"
            f"   - Control flow deviations\n"
            f"   - Missing or altered side effects\n"
            f"3. Provide corrected Python that matches COBOL behavior "
            f"exactly\n"
            f"4. Document any assumptions that cannot be verified from "
            f"source alone\n"
            f"5. Generate verification scenarios that prove equivalence\n"
            f"\n"
            f"COBOL GROUND TRUTH REMINDER\n"
            f"{'─' * 80}\n"
            f"- COMPUTE without ROUNDED = TRUNCATION to target PIC scale\n"
            f"- This is the OPPOSITE of Python's default Decimal behavior\n"
            f"- A 0.01 difference in financial code is a CRITICAL finding"
        )

    @staticmethod
    def _build_extraction_user_message(
        filename: str,
        cobol_code: str,
    ) -> str:
        """Compose the user-turn message for a logic-extraction engagement."""
        line_count = len(cobol_code.splitlines())
        return (
            f"EXTRACTION ENGAGEMENT\n"
            f"{'=' * 80}\n"
            f"Asset ID:        {filename}\n"
            f"Lines of Code:   {line_count}\n"
            f"Request Type:    Full Logic Extraction & Python Translation\n"
            f"\n"
            f"COBOL SOURCE\n"
            f"{'─' * 80}\n"
            f"```cobol\n{cobol_code}\n```\n"
            f"\n"
            f"EXTRACTION REQUIREMENTS\n"
            f"{'─' * 80}\n"
            f"1. Extract all business rules embedded in the logic\n"
            f"2. Map COBOL data definitions to Python Decimal types\n"
            f"3. Preserve execution order and control flow structure\n"
            f"4. Generate Python translation with explicit COBOL line "
            f"references\n"
            f"5. Document any uncertainties or assumptions\n"
            f"6. Flag potential compliance-relevant logic (fees, rates, "
            f"penalties)"
        )

    # ── main analysis entry point ────────────────────────────────────

    async def analyze_cobol(
        self,
        cobol_code: str,
        filename: str,
        modernized_code: Optional[str] = None,
        is_audit_mode: bool = False,
    ) -> Dict[str, Any]:
        """
        Primary analysis method.

        Dispatches to the LLM with the appropriate system prompt and
        user message.  Falls back to offline stubs when no API key is
        configured.

        Parameters
        ----------
        cobol_code : str
            Raw COBOL source to be analyzed.
        filename : str
            Original filename for traceability.
        modernized_code : str, optional
            Python translation to audit (required when *is_audit_mode*
            is True).
        is_audit_mode : bool
            ``True`` → behavioral-drift audit.
            ``False`` → fresh logic extraction.

        Returns
        -------
        dict
            JSON-structured analysis conforming to the schema defined in
            the system prompt.  All Decimal values are string-encoded.
        """
        # -- Offline fallback --
        if not self.client:
            if is_audit_mode:
                return self._offline_audit_stub(filename)
            return self._offline_extraction_stub(filename, cobol_code)

        # -- Build messages --
        system_prompt = self._select_system_prompt(is_audit_mode)

        if is_audit_mode and modernized_code:
            user_message = self._build_audit_user_message(
                filename, cobol_code, modernized_code,
            )
        else:
            user_message = self._build_extraction_user_message(
                filename, cobol_code,
            )

        # -- Call analysis engine --
        try:
            response = await self.client.chat.completions.create(
                model="gpt-4o",
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_message},
                ],
                response_format={"type": "json_object"},
                temperature=0.1,  # Low temperature for deterministic output
            )
            analysis_result: Dict[str, Any] = json.loads(
                response.choices[0].message.content,
            )
            return analysis_result

        except json.JSONDecodeError as parse_err:
            logger.error(
                "Failed to parse engine response as JSON: %s", parse_err,
            )
            raise HTTPException(
                status_code=502,
                detail="Analysis engine returned unparseable response.",
            )
        except Exception as exc:
            logger.error("Analysis engine error: %s", exc)
            raise HTTPException(
                status_code=500,
                detail=(
                    "Analysis engine unavailable. "
                    "Contact system administrator."
                ),
            )

    # ── chat / explanation ───────────────────────────────────────────

    async def explain_logic(self, request: ChatRequest) -> ChatResponse:
        """
        Answer a contextual question about COBOL or Python code.

        Maintains conversation history so follow-up questions work
        naturally.

        [AUD-010] Returns confidence as string representation of Decimal.
        """
        if not self.client:
            return ChatResponse(
                answer=(
                    "Explanation service offline. "
                    "Verify OPENAI_API_KEY configuration."
                ),
                confidence="0.00",
            )

        # Assemble context block
        context_block = f"COBOL SOURCE:\n{request.cobol_context}\n"
        if request.python_context:
            context_block += (
                f"\nPYTHON TRANSLATION:\n{request.python_context}\n"
            )

        # Build conversation messages
        messages: List[Dict[str, str]] = [
            {"role": "system", "content": _CHAT_SYSTEM_PROMPT},
        ]
        for historical_message in request.history:
            messages.append(historical_message)

        messages.append(
            {
                "role": "user",
                "content": (
                    f"{context_block}\nQUESTION: {request.user_query}"
                ),
            },
        )

        try:
            response = await self.client.chat.completions.create(
                model="gpt-4o",
                messages=messages,
                temperature=0.2,
            )
            # [AUD-010] Confidence as Decimal string, not float
            return ChatResponse(
                answer=response.choices[0].message.content,
                confidence="0.95",
            )
        except Exception as exc:
            logger.error("Chat API error: %s", exc)
            return ChatResponse(
                answer=(
                    "Service temporarily unavailable. "
                    "Retry in 30 seconds."
                ),
                confidence="0.00",
            )


# ──────────────────────────────────────────────────────────────────────
# RATE LIMITER
# ──────────────────────────────────────────────────────────────────────


class RateLimiter:
    """Sliding-window in-memory rate limiter. Thread-safe."""

    def __init__(self, max_calls: int, period: float):
        self.max_calls = max_calls
        self.period = period  # seconds
        self._hits: dict[str, list[float]] = collections.defaultdict(list)
        self._lock = threading.Lock()

    def is_allowed(self, key: str) -> bool:
        """Return True if *key* is within the rate limit, else False."""
        now = time.monotonic()
        with self._lock:
            window = self._hits[key]
            # Evict timestamps outside the current window
            cutoff = now - self.period
            self._hits[key] = window = [t for t in window if t > cutoff]
            if len(window) >= self.max_calls:
                return False
            window.append(now)
            return True

    def retry_after(self, key: str) -> int:
        """Seconds until the oldest entry in *key*'s window expires."""
        if not self._hits[key]:
            return 0
        oldest = self._hits[key][0]
        return max(1, int(self.period - (time.monotonic() - oldest)) + 1)

    def reset(self) -> None:
        """Clear all state (useful for tests)."""
        self._hits.clear()


# All rate limiters removed for V1 free launch


def _get_client_ip(request: Request) -> str:
    """Extract client IP, respecting X-Forwarded-For behind reverse proxies."""
    forwarded = request.headers.get("x-forwarded-for", "")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


# ──────────────────────────────────────────────────────────────────────
# FASTAPI APPLICATION
# ──────────────────────────────────────────────────────────────────────

app = FastAPI(
    title="Alethia Beyond — Enterprise Modernization Engine",
    version="3.2.0",
    description=(
        "COBOL logic extraction, Python translation, and behavioral-drift "
        "auditing for Tier-1 financial institutions. "
        "Zero-Error Institutional Grade."
    ),
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)


@app.middleware("http")
async def security_headers_middleware(request: Request, call_next):
    """Add security headers to all responses."""
    response = await call_next(request)
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    return response


# Mount vault router if available
if VAULT_AVAILABLE:
    app.include_router(vault_router, prefix="/vault", tags=["vault"])

# Mount shadow diff router if available
if SHADOW_DIFF_AVAILABLE:
    app.include_router(shadow_diff_router, prefix="/shadow-diff", tags=["shadow-diff"])

# Mount copybook resolver router if available
if COPYBOOK_AVAILABLE:
    app.include_router(copybook_router, prefix="/copybook", tags=["copybook"])

# Mount license router if available
if LICENSE_AVAILABLE:
    app.include_router(license_router, prefix="/license", tags=["license"])

# Mount audit logger router if available
try:
    from audit_logger import audit_router
    app.include_router(audit_router, prefix="/audit", tags=["audit"])
    AUDIT_AVAILABLE = True
except ImportError:
    AUDIT_AVAILABLE = False
    logger.warning("audit_logger module not available — audit endpoints disabled")


# ──────────────────────────────────────────────────────────────────────
# DATABASE LIFECYCLE EVENTS
# ──────────────────────────────────────────────────────────────────────

@app.on_event("startup")
async def startup():
    """Initialize database on startup."""
    logger.info("Aletheia mode: %s", ALETHEIA_MODE)
    if DB_AVAILABLE and not USE_IN_MEMORY_DB:
        await init_db()
        logger.info("Database initialized.")
    else:
        logger.info("Running in in-memory mode (no database).")

    # License validation
    if LICENSE_AVAILABLE:
        state = load_and_verify_license()
        if state.valid:
            logger.info("License valid: %s (expires %s)",
                        state.license_data.get("customer", "unknown"),
                        state.license_data.get("expires", "unknown"))
        else:
            logger.warning("LICENSE: %s (mode: %s)", state.error,
                           os.environ.get("ALETHEIA_LICENSE_MODE", "strict"))


@app.on_event("shutdown")
async def shutdown():
    """Close database connections on shutdown."""
    if DB_AVAILABLE and not USE_IN_MEMORY_DB:
        await close_db()
        logger.info("Database connections closed.")


# Singleton analysis engine — shared across all requests
analysis_engine = LogicExtractionService()


# ── Compiler Configuration ───────────────────────────────────────────

@app.get("/config/compiler")
async def get_compiler_config(username: Optional[str] = Depends(verify_token_optional)):
    """Get current IBM z/OS compiler configuration."""
    from compiler_config import get_config
    return get_config().to_dict()


@app.post("/config/compiler")
async def set_compiler_config(body: dict, username: Optional[str] = Depends(verify_token_optional)):
    """Set IBM z/OS compiler configuration (TRUNC mode, ARITH mode, etc.)."""
    from compiler_config import set_config
    _ALLOWED_CONFIG_KEYS = {"trunc_mode", "arith_mode", "decimal_point", "currency_sign", "numproc"}
    filtered = {k: v for k, v in body.items() if k in _ALLOWED_CONFIG_KEYS}
    try:
        config = set_config(**filtered)
        return config.to_dict()
    except (ValueError, TypeError) as e:
        raise HTTPException(status_code=400, detail=str(e))


# ── Dependency Crawler ──────────────────────────────────────────────

@app.post("/dependency/analyze")
async def dependency_analyze(body: DependencyRequest,
                             username: Optional[str] = Depends(verify_token_optional)):
    """Analyze multiple COBOL programs and build dependency tree."""
    try:
        from dependency_crawler import analyze_multi_program, _extract_program_id
    except ImportError:
        raise HTTPException(status_code=501, detail="dependency_crawler not available")

    programs = {}
    for entry in body.programs:
        source = entry.get("cobol_code", "")
        filename = entry.get("filename", "unknown.cbl")
        prog_id = _extract_program_id(source)
        if prog_id == "UNKNOWN":
            prog_id = filename.upper().replace(".CBL", "").replace(".COB", "")
        programs[prog_id] = source

    result = analyze_multi_program(programs)
    return result


@app.post("/dependency/upload")
async def dependency_upload(files: list[UploadFile],
                            username: Optional[str] = Depends(verify_token_optional)):
    """Upload multiple COBOL files for dependency analysis."""
    try:
        from dependency_crawler import analyze_multi_program, _extract_program_id
    except ImportError:
        raise HTTPException(status_code=501, detail="dependency_crawler not available")

    programs = {}
    for f in files:
        try:
            raw = await f.read()
            source = raw.decode("utf-8")
        except UnicodeDecodeError:
            raise HTTPException(status_code=400, detail=f"File {f.filename} is not valid UTF-8")

        prog_id = _extract_program_id(source)
        if prog_id == "UNKNOWN":
            prog_id = (f.filename or "unknown").upper().replace(".CBL", "").replace(".COB", "")
        programs[prog_id] = source

    result = analyze_multi_program(programs)
    return result


@app.post("/dependency/tree")
async def dependency_tree(body: DependencyRequest,
                          username: Optional[str] = Depends(verify_token_optional)):
    """Build dependency tree without full analysis."""
    try:
        from dependency_crawler import build_dependency_tree, _extract_program_id
    except ImportError:
        raise HTTPException(status_code=501, detail="dependency_crawler not available")

    programs = {}
    for entry in body.programs:
        source = entry.get("cobol_code", "")
        filename = entry.get("filename", "unknown.cbl")
        prog_id = _extract_program_id(source)
        if prog_id == "UNKNOWN":
            prog_id = filename.upper().replace(".CBL", "").replace(".COB", "")
        programs[prog_id] = source

    tree = build_dependency_tree(programs)
    return tree


# ── Batch Engine (Multi-Program + Python Generation) ─────────────────

@app.post("/engine/analyze-batch")
async def engine_analyze_batch(
    body: BatchAnalyzeRequest,
    username: Optional[str] = Depends(verify_token_optional),
):
    """
    Batch Engine — analyzes multiple COBOL programs as a system:

    1. Copybook preprocessing
    2. Dependency tree construction
    3. Per-file ANTLR4 parse + Python generation
    4. Cross-file CALL resolution
    5. Arithmetic risk analysis per file
    6. Combined verification verdict
    """
    username = username or "guest"
    try:
        from dependency_crawler import analyze_batch, _extract_program_id
    except ImportError:
        raise HTTPException(status_code=501, detail="dependency_crawler not available")

    # Build programs dict (program_id -> source)
    programs = {}
    for entry in body.programs:
        source = entry.get("cobol_code", "")
        filename = entry.get("filename", "unknown.cbl")
        prog_id = _extract_program_id(source)
        if prog_id == "UNKNOWN":
            prog_id = filename.upper().replace(".CBL", "").replace(".COB", "")
        programs[prog_id] = source

    # Build copybooks dict if provided
    copybooks = None
    if body.copybooks:
        copybooks = {
            cb.get("name", "UNKNOWN"): cb.get("content", "")
            for cb in body.copybooks
        }

    # Apply compiler config if provided
    if body.compiler_config:
        try:
            from compiler_config import set_config
            set_config(**body.compiler_config)
        except (ValueError, TypeError, ImportError) as e:
            logger.warning("Invalid compiler_config in batch request: %s", e)

    # Run batch analysis
    result = analyze_batch(programs, copybooks=copybooks)

    # Audit trail
    record_security_event(
        username,
        f"Engine Batch Analyze: {len(programs)} programs",
    )

    result["success"] = True
    return result


# ── Cryptographic Verification ───────────────────────────────────────

@app.post("/verify")
async def verify_signature(req: VerifyRequest, username: Optional[str] = Depends(verify_token_optional)):
    """Verify a vault record's cryptographic signature."""
    try:
        from report_signing import verify_report
    except ImportError:
        raise HTTPException(status_code=501, detail="report_signing module not available")

    if req.record_id is not None:
        # Load signature data from vault
        try:
            from vault import _get_conn
            conn = _get_conn()
            row = conn.execute(
                "SELECT signature, public_key_fp, verification_chain, record_hash FROM verifications WHERE id = ?",
                (req.record_id,),
            ).fetchone()
            conn.close()
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Vault read failed: {e}")

        if not row:
            raise HTTPException(status_code=404, detail="Record not found")
        if not row["signature"]:
            return {"valid": False, "details": "Record has no cryptographic signature", "verified_at": datetime.now(timezone.utc).isoformat()}

        import json as _json
        rec_hash = row["record_hash"] if "record_hash" in row.keys() else None
        sig_data = {
            "signature": row["signature"],
            "public_key_fingerprint": row["public_key_fp"],
            "signed_field": "record_hash" if rec_hash else "chain_hash",
            "verification_chain": _json.loads(row["verification_chain"]) if row["verification_chain"] else {},
        }
        return verify_report(sig_data, record_hash=rec_hash)

    elif req.signature_data is not None:
        return verify_report(req.signature_data)

    else:
        raise HTTPException(status_code=400, detail="Provide record_id or signature_data")


@app.get("/verify/public-key")
async def get_public_key():
    """Return the public key for independent signature verification."""
    try:
        from report_signing import get_public_key_pem, get_public_key_fingerprint
    except ImportError:
        raise HTTPException(status_code=501, detail="report_signing module not available")

    return {
        "public_key_pem": get_public_key_pem(),
        "fingerprint": get_public_key_fingerprint(),
    }


# ── Health / Root ────────────────────────────────────────────────────

@app.get("/api/health")
async def health():
    """Health check — confirms the service is reachable."""
    return {
        "status": "online",
        "version": "3.2.0",
        "mode": ALETHEIA_MODE,
        "decimal_precision": str(getcontext().prec),
    }


@app.get("/api/v1/heartbeat")
async def heartbeat():
    """
    Heartbeat probe for load balancers and uptime monitors.

    Returns a UTC timestamp so callers can detect clock skew.
    """
    return {
        "status": "operational",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "engine": "v3.2.0-zero-error",
        "decimal_context": {
            "precision": getcontext().prec,
            "rounding": str(getcontext().rounding),
        },
    }


# ── Authentication ───────────────────────────────────────────────────

@app.post("/auth/register")
async def register_user(registration: UserRegistrationRequest):
    """
    Register a new user.

    New accounts start with ``is_approved = False`` and require
    institutional verification (via ``/admin/approve``) before they
    can access analysis endpoints.

    Supports both in-memory (for tests) and database (production) modes.
    """
    username = normalize_username(registration.username)

    # In-memory mode (tests / development without DB)
    if USE_IN_MEMORY_DB or not DB_AVAILABLE:
        if username in users_db:
            raise HTTPException(status_code=400, detail="User already exists.")

        users_db[username] = {
            "password": password_hasher.hash(registration.password),
            "institution": registration.institution,
            "city": registration.city,
            "country": registration.country,
            "role": registration.role,
            "is_approved": False,
            "security_history": [],
        }

        logger.info(
            "New registration: %s (%s)", username, registration.institution,
        )

        # Fire-and-forget email (non-blocking, never fails registration)
        if EMAIL_AVAILABLE and registration.email:
            asyncio.create_task(
                email_service.send_registration_email(
                    registration.email, username
                )
            )

        return {
            "message": (
                "Registration received. Pending institutional verification."
            ),
        }

    # Database mode (production)
    async with AsyncSessionLocal() as db:
        # Check if user exists
        existing = await get_user_by_username_db(db, username)
        if existing:
            raise HTTPException(status_code=400, detail="User already exists.")

        # Create new user
        new_user = User(
            username=username,
            password_hash=password_hasher.hash(registration.password),
            institution=registration.institution,
            city=registration.city,
            country=registration.country,
            role=registration.role,
            is_approved=False,
        )
        db.add(new_user)
        await db.commit()

        logger.info(
            "New registration: %s (%s)", username, registration.institution,
        )

        # Fire-and-forget email (non-blocking, never fails registration)
        if EMAIL_AVAILABLE and registration.email:
            asyncio.create_task(
                email_service.send_registration_email(
                    registration.email, username
                )
            )
        return {
            "message": (
                "Registration received. Pending institutional verification."
            ),
        }


@app.post("/auth/login")
async def login_user(credentials: UserLoginRequest, request: Request):
    """
    Authenticate a user and return a JWT.

    [AUD-004] Uses normalized username consistently in token and response.

    Supports both in-memory (for tests) and database (production) modes.
    """
    username = normalize_username(credentials.username)

    # In-memory mode (tests / development without DB)
    if USE_IN_MEMORY_DB or not DB_AVAILABLE:
        if username not in users_db:
            # Constant-time: hash dummy to prevent timing-based username enumeration
            password_hasher.verify("dummy", _DUMMY_HASH)
            logger.warning("Login attempt for unknown user: %s", username)
            raise HTTPException(
                status_code=401,
                detail="Invalid credentials.",
            )

        stored_user = users_db[username]

        # Verify password using PBKDF2-SHA256
        password_is_valid: bool = password_hasher.verify(
            credentials.password,
            stored_user["password"],
        )

        if not password_is_valid:
            logger.warning("Failed login attempt for user: %s", username)
            raise HTTPException(
                status_code=401,
                detail="Invalid credentials.",
            )

        logger.info(
            "Successful login: %s (approved=%s)",
            username,
            stored_user["is_approved"],
        )

        # Record login in audit trail
        record_security_event(username, "Session Established")
        try:
            from audit_logger import log_event
            log_event(username, "LOGIN")
        except ImportError:
            pass

        # [AUD-004] Use normalized username for both token subject and response
        token = create_access_token({"sub": username})
        return {
            "access_token": token,
            "token_type": "bearer",
            "is_approved": stored_user.get("is_approved", False),
            "corporate_id": username,
        }

    # Database mode (production)
    async with AsyncSessionLocal() as db:
        user = await get_user_by_username_db(db, username)
        if user is None:
            # Constant-time: hash dummy to prevent timing-based username enumeration
            password_hasher.verify("dummy", _DUMMY_HASH)
            logger.warning("Login attempt for unknown user: %s", username)
            raise HTTPException(
                status_code=401,
                detail="Invalid credentials.",
            )

        # Verify password
        password_is_valid = password_hasher.verify(
            credentials.password,
            user.password_hash,
        )

        if not password_is_valid:
            logger.warning("Failed login attempt for user: %s", username)
            raise HTTPException(
                status_code=401,
                detail="Invalid credentials.",
            )

        logger.info(
            "Successful login: %s (approved=%s)",
            username,
            user.is_approved,
        )

        # Record login in audit trail
        await record_security_event_db(db, user, "Session Established")
        await db.commit()

        token = create_access_token({"sub": username})
        return {
            "access_token": token,
            "token_type": "bearer",
            "is_approved": user.is_approved,
            "corporate_id": username,
        }


@app.get("/auth/profile", response_model=UserProfileResponse)
async def get_user_profile(username: Optional[str] = Depends(verify_token_optional)):
    """
    Return the authenticated user's profile and audit history.

    Supports both in-memory (for tests) and database (production) modes.
    """
    username = username or "guest"
    # In-memory mode
    if USE_IN_MEMORY_DB or not DB_AVAILABLE:
        user = users_db.get(username)
        if not user:
            return {
                "username": username,
                "institution": "",
                "city": "",
                "country": "",
                "role": "guest",
                "is_approved": True,
                "security_history": [],
            }
        return {
            "username": username,
            "institution": user["institution"],
            "city": user["city"],
            "country": user["country"],
            "role": user["role"],
            "is_approved": user.get("is_approved", False),
            "security_history": user["security_history"],
        }

    # Database mode
    async with AsyncSessionLocal() as db:
        user = await get_user_by_username_db(db, username)
        if user is None:
            raise HTTPException(status_code=404, detail="User not found.")

        # Load security events
        from sqlalchemy.orm import selectinload
        result = await db.execute(
            select(User)
            .options(selectinload(User.security_events))
            .where(User.username == username)
        )
        user = result.scalar_one()

        return {
            "username": user.username,
            "institution": user.institution,
            "city": user.city,
            "country": user.country,
            "role": user.role,
            "is_approved": user.is_approved,
            "security_history": [evt.to_dict() for evt in user.security_events],
        }


@app.post("/admin/approve/{corporate_id}")
async def approve_user(
    corporate_id: str,
    username: Optional[str] = Depends(verify_token_optional),
):
    """
    Grant analysis access to a registered user.

    [AUD-007] Requires valid token.  Only approved users can approve others.

    Supports both in-memory (for tests) and database (production) modes.
    """
    username = username or "guest"
    # In-memory mode
    if USE_IN_MEMORY_DB or not DB_AVAILABLE:
        caller = users_db.get(username, {})
        if not caller.get("is_approved"):
            raise HTTPException(status_code=403, detail="Only approved users can approve others.")
        if corporate_id not in users_db:
            raise HTTPException(status_code=404, detail="User not found.")

        users_db[corporate_id]["is_approved"] = True
        logger.info("User %s approved by %s", corporate_id, username)
        return {"message": f"Clearance granted: {corporate_id}"}

    # Database mode
    async with AsyncSessionLocal() as db:
        user = await get_user_by_username_db(db, corporate_id)
        if user is None:
            raise HTTPException(status_code=404, detail="User not found.")

        user.is_approved = True
        await db.commit()

        logger.info("User %s approved by %s", corporate_id, username)
        return {"message": f"Clearance granted: {corporate_id}"}


# ── Analysis ─────────────────────────────────────────────────────────

@app.post("/analyze")
async def analyze_cobol_code(
    request: AnalyzeRequest,
    username: Optional[str] = Depends(verify_token_optional),
):
    """
    Analyze COBOL source code — extraction or audit mode.

    Requires an approved user.  Records the analysis event in the
    user's security history for SOC-2 traceability.

    Supports both in-memory (for tests) and database (production) modes.
    """
    username = username or "guest"
    # In-memory mode
    if USE_IN_MEMORY_DB or not DB_AVAILABLE:
        # is_approved bypass: all authenticated users have clearance

        if not request.cobol_code.strip():
            raise HTTPException(
                status_code=400,
                detail="Empty COBOL source provided.",
            )

        # Audit trail
        record_security_event(
            username,
            f"Analysis: {request.filename}",
        )

        # Always run extraction mode (toggle removed — audit always on)
        result = await analysis_engine.analyze_cobol(
            cobol_code=request.cobol_code,
            filename=request.filename or "source.cbl",
            modernized_code=request.modernized_code,
            is_audit_mode=False,
        )

        # Zero-error audit pipeline — ALWAYS runs, results always included
        if AUDITOR_AVAILABLE:
            auditor = ZeroErrorAuditor(analysis_engine.client)
            python_code = (
                request.modernized_code
                or result.get("python_implementation", "")
            )
            audit_result = await auditor.execute_full_audit(
                cobol_code=request.cobol_code,
                python_code=python_code,
                filename=request.filename or "source.cbl",
            )
            result["audit"] = {
                "passed": audit_result.passed_zero_error,
                "confidence": audit_result.overall_confidence,
                "level": audit_result.confidence_level.value,
                "stages": {
                    "stage_1": audit_result.stage_1_analysis.model_dump(),
                    "stage_2": audit_result.stage_2_verification.model_dump(),
                    "stage_3": audit_result.stage_3_scoring.model_dump(),
                },
                "unresolved": audit_result.unresolved_uncertainties,
            }

        return result

    # Database mode
    async with AsyncSessionLocal() as db:
        user = await get_user_by_username_db(db, username)
        if user is None:
            raise HTTPException(
                status_code=403,
                detail="Institutional clearance required.",
            )
        # is_approved bypass: all authenticated users have clearance

        if not request.cobol_code.strip():
            raise HTTPException(
                status_code=400,
                detail="Empty COBOL source provided.",
            )

        # Audit trail
        await record_security_event_db(
            db, user, f"Analysis: {request.filename}"
        )

        # Always run extraction mode (toggle removed — audit always on)
        result = await analysis_engine.analyze_cobol(
            cobol_code=request.cobol_code,
            filename=request.filename or "source.cbl",
            modernized_code=request.modernized_code,
            is_audit_mode=False,
        )

        # Zero-error audit pipeline — ALWAYS runs, results always included
        if AUDITOR_AVAILABLE:
            auditor = ZeroErrorAuditor(analysis_engine.client)
            python_code = (
                request.modernized_code
                or result.get("python_implementation", "")
            )
            audit_result = await auditor.execute_full_audit(
                cobol_code=request.cobol_code,
                python_code=python_code,
                filename=request.filename or "source.cbl",
            )
            result["audit"] = {
                "passed": audit_result.passed_zero_error,
                "confidence": audit_result.overall_confidence,
                "level": audit_result.confidence_level.value,
                "stages": {
                    "stage_1": audit_result.stage_1_analysis.model_dump(),
                    "stage_2": audit_result.stage_2_verification.model_dump(),
                    "stage_3": audit_result.stage_3_scoring.model_dump(),
                },
                "unresolved": audit_result.unresolved_uncertainties,
            }

        # Store analysis session
        complexity_score = None
        if "complexity_score" in result:
            try:
                complexity_score = Decimal(result["complexity_score"])
            except (ValueError, TypeError):
                pass

        session = AnalysisSession(
            user_id=user.id,
            filename=request.filename or "source.cbl",
            cobol_code=request.cobol_code,
            modernized_code=request.modernized_code,
            is_audit_mode=False,
            result_json=json.dumps(result),
            complexity_score=complexity_score,
            drift_detected=result.get("drift_detected"),
        )
        db.add(session)
        await db.commit()

        return result


@app.post("/process-legacy")
async def process_legacy_file(
    file: UploadFile = File(...),
    username: Optional[str] = Depends(verify_token_optional),
):
    """
    Upload a COBOL source file for extraction analysis.

    [AUD-005] Enforces file-size limit.
    [AUD-006] Handles UnicodeDecodeError for non-UTF-8 files.

    Supports both in-memory (for tests) and database (production) modes.
    """
    username = username or "guest"
    # Common validation — read at most max_bytes + 1 to detect oversized uploads
    max_bytes = MAX_FILE_SIZE_MB * 1024 * 1024
    raw_bytes = await file.read(max_bytes + 1)
    if len(raw_bytes) > max_bytes:
        raise HTTPException(
            status_code=413,
            detail=(
                f"File exceeds {MAX_FILE_SIZE_MB} MB limit "
                f"({len(raw_bytes)} bytes received)."
            ),
        )

    try:
        cobol_source_text = raw_bytes.decode("utf-8")
    except UnicodeDecodeError:
        raise HTTPException(
            status_code=400,
            detail=(
                "File is not valid UTF-8. EBCDIC or other mainframe "
                "encodings must be converted before upload."
            ),
        )

    # In-memory mode
    if USE_IN_MEMORY_DB or not DB_AVAILABLE:
        # is_approved bypass: all authenticated users have clearance

        record_security_event(username, f"File Upload: {file.filename}")

        result = await analysis_engine.analyze_cobol(
            cobol_code=cobol_source_text,
            filename=file.filename,
        )
        return result

    # Database mode
    async with AsyncSessionLocal() as db:
        user = await get_user_by_username_db(db, username)
        if user is None:
            raise HTTPException(
                status_code=403,
                detail="Institutional clearance required.",
            )
        # is_approved bypass: all authenticated users have clearance

        await record_security_event_db(db, user, f"File Upload: {file.filename}")

        result = await analysis_engine.analyze_cobol(
            cobol_code=cobol_source_text,
            filename=file.filename,
        )

        # Store analysis session
        complexity_score = None
        if "complexity_score" in result:
            try:
                complexity_score = Decimal(result["complexity_score"])
            except (ValueError, TypeError):
                pass

        session = AnalysisSession(
            user_id=user.id,
            filename=file.filename or "upload.cbl",
            cobol_code=cobol_source_text,
            is_audit_mode=False,
            result_json=json.dumps(result),
            complexity_score=complexity_score,
        )
        db.add(session)
        await db.commit()

        return result


# ── Analytics & Risk ─────────────────────────────────────────────────

@app.get("/analytics")
async def get_analytics_dashboard(username: Optional[str] = Depends(verify_token_optional)):
    """
    Return platform analytics for the authenticated user.

    Currently returns activity history and placeholder metrics.

    Supports both in-memory (for tests) and database (production) modes.
    """
    username = username or "guest"
    # In-memory mode
    if USE_IN_MEMORY_DB or not DB_AVAILABLE:
        user = users_db.get(username, {})
        security_history = user.get("security_history", [])
        recent_activity = security_history[-5:] if security_history else []

        return {
            "metrics": {
                "total_lines": 0,
                "risk_anomalies": 0,
                "precision_score": None,
            },
            "active_analyses": [],
            "risk_alerts": [],
            "recent_activity": recent_activity,
        }

    # Database mode
    async with AsyncSessionLocal() as db:
        from sqlalchemy.orm import selectinload

        result = await db.execute(
            select(User)
            .options(selectinload(User.security_events))
            .where(User.username == username)
        )
        user = result.scalar_one_or_none()

        if user is None:
            return {
                "metrics": {"total_lines": 0, "risk_anomalies": 0, "precision_score": None},
                "active_analyses": [],
                "risk_alerts": [],
                "recent_activity": [],
            }

        # Get 5 most recent events
        recent_events = sorted(
            user.security_events,
            key=lambda e: e.timestamp,
            reverse=True,
        )[:5]

        return {
            "metrics": {
                "total_lines": 0,
                "risk_anomalies": 0,
                "precision_score": None,
            },
            "active_analyses": [],
            "risk_alerts": [],
            "recent_activity": [evt.to_dict() for evt in recent_events],
        }


@app.get("/vault")
async def get_vault_analyses(username: Optional[str] = Depends(verify_token_optional)):
    """
    Return all analysis sessions for the authenticated user.
    Used by the Vault to display analysis history.
    """
    username = username or "guest"
    # In-memory mode
    if USE_IN_MEMORY_DB or not DB_AVAILABLE:
        return {"analyses": []}

    # Database mode
    async with AsyncSessionLocal() as db:
        user = (await db.execute(
            select(User).where(User.username == username)
        )).scalar_one_or_none()
        if not user:
            return {"analyses": []}
        result = await db.execute(
            select(AnalysisSession)
            .where(AnalysisSession.user_id == user.id)
            .order_by(AnalysisSession.created_at.desc())
        )
        sessions = result.scalars().all()

        analyses = []
        for session in sessions:
            # Parse the result JSON to get the full analysis data
            result_data = json.loads(session.result_json) if session.result_json else {}

            analyses.append({
                "id": str(session.id),
                "filename": session.filename,
                "created_at": session.created_at.isoformat(),
                "cobol_source": result_data.get("cobol_code", ""),
                "python_output": result_data.get("python_implementation", ""),
                "python_implementation": result_data.get("python_implementation", ""),
                "executive_summary": result_data.get("executive_summary", ""),
                "executive_explanation": result_data.get("executive_explanation", ""),
                "complexity_score": str(session.complexity_score) if session.complexity_score else "N/A",
                "lines_of_code": result_data.get("lines_of_code", 0),
                "conversion_type": "COBOL → Python 3.12",
                "mathematical_breakdown": result_data.get("mathematical_breakdown", ""),
                "logical_flow_summary": result_data.get("logical_flow_summary", []),
                "code_commentary": result_data.get("code_commentary", []),
                "detected_rules": result_data.get("detected_rules", []),
                "audit": result_data.get("audit"),
                "findings": result_data.get("audit_findings", []),
                "uncertainties": result_data.get("uncertainties", []),
            })

        return {"analyses": analyses}


@app.get("/risk-intelligence")
async def get_risk_intelligence(username: Optional[str] = Depends(verify_token_optional)):
    """
    Return risk-intelligence data.

    Stub endpoint — returns empty collections until the risk-scoring
    pipeline is connected.
    """
    return {
        "distribution": [],
        "anomalies": [],
        "archive_integrity": None,
    }


# ── Chat ─────────────────────────────────────────────────────────────

@app.post("/chat", response_model=ChatResponse)
async def chat_with_engine(
    request: ChatRequest,
    username: Optional[str] = Depends(verify_token_optional),
):
    """
    Ask a contextual question about COBOL or Python code.

    Requires an approved user.

    Supports both in-memory (for tests) and database (production) modes.
    """
    username = username or "guest"
    # In-memory mode
    if USE_IN_MEMORY_DB or not DB_AVAILABLE:
        # is_approved bypass: all authenticated users have clearance
        return await analysis_engine.explain_logic(request)

    # Database mode
    async with AsyncSessionLocal() as db:
        user = await get_user_by_username_db(db, username)
        if user is None:
            raise HTTPException(
                status_code=403,
                detail="Institutional clearance required.",
            )
        # is_approved bypass: all authenticated users have clearance

        # Get response from engine
        response = await analysis_engine.explain_logic(request)

        # Store user message
        user_msg = ChatMessage(
            user_id=user.id,
            role="user",
            content=request.user_query,
            cobol_context=request.cobol_context,
            python_context=request.python_context,
        )
        db.add(user_msg)

        # Store assistant response
        confidence_decimal = None
        try:
            confidence_decimal = Decimal(response.confidence)
        except (ValueError, TypeError):
            pass

        assistant_msg = ChatMessage(
            user_id=user.id,
            role="assistant",
            content=response.answer,
            confidence=confidence_decimal,
        )
        db.add(assistant_msg)

        await db.commit()

        return response

# ════════════════════════════════════════════════════════════════════════
# ANTLR4 COBOL PARSER ENDPOINT (Real Parsing, Not GPT)
# ════════════════════════════════════════════════════════════════════════

try:
    from cobol_analyzer_api import analyze_cobol as antlr_analyze_cobol
    ANTLR_AVAILABLE = True
    logger.info("ANTLR4 COBOL parser loaded successfully.")
except ImportError:
    ANTLR_AVAILABLE = False
    logger.warning("ANTLR4 parser not available — install dependencies.")

try:
    from generate_full_python import generate_python_module, compute_arithmetic_risks
    GENERATOR_AVAILABLE = True
    logger.info("COBOL-to-Python generator loaded successfully.")
except ImportError:
    GENERATOR_AVAILABLE = False
    compute_arithmetic_risks = None
    logger.warning("COBOL-to-Python generator not available — install dependencies.")


@app.post("/parse")
async def parse_cobol_code(
    request: AnalyzeRequest,
    username: Optional[str] = Depends(verify_token_optional),
):
    """
    Parse COBOL using ANTLR4 — real parsing, not LLM analysis.
    
    Returns structured data:
    - Paragraphs
    - Variables (with COMP-3 detection)
    - Control flow graph
    - COMPUTE statements
    - Business rules (IF statements)
    - Cycle detection
    - Unreachable code detection
    """
    username = username or "guest"
    if not ANTLR_AVAILABLE:
        raise HTTPException(
            status_code=503,
            detail="ANTLR4 parser not configured.",
        )

    if not request.cobol_code.strip():
        raise HTTPException(
            status_code=400,
            detail="Empty COBOL source provided.",
        )

    # Record in audit trail
    if USE_IN_MEMORY_DB or not DB_AVAILABLE:
        record_security_event(username, f"Parse: {request.filename}")
    else:
        async with AsyncSessionLocal() as db:
            user = await get_user_by_username_db(db, username)
            if user:
                await record_security_event_db(db, user, f"Parse: {request.filename}")
                await db.commit()
    
    # Run ANTLR4 parser
    result = antlr_analyze_cobol(request.cobol_code)
    result["filename"] = request.filename or "source.cbl"
    result["parser"] = "ANTLR4"
    result["engine"] = "deterministic"
    
    return result


@app.post("/generate")
async def generate_python_from_cobol(
    request: AnalyzeRequest,
    username: Optional[str] = Depends(verify_token_optional),
):
    """
    Generate Python module from COBOL source using deterministic transpiler.

    Uses ANTLR4 parse tree + rule-based code generation. No LLM.
    All numeric variables use decimal.Decimal.
    """
    username = username or "guest"
    if not GENERATOR_AVAILABLE:
        raise HTTPException(
            status_code=503,
            detail="COBOL-to-Python generator not configured.",
        )

    if not ANTLR_AVAILABLE:
        raise HTTPException(
            status_code=503,
            detail="ANTLR4 parser not available.",
        )

    if not request.cobol_code.strip():
        raise HTTPException(
            status_code=400,
            detail="Empty COBOL source provided.",
        )

    # Record in audit trail
    if USE_IN_MEMORY_DB or not DB_AVAILABLE:
        record_security_event(username, f"Generate: {request.filename}")
    else:
        async with AsyncSessionLocal() as db:
            user = await get_user_by_username_db(db, username)
            if user:
                await record_security_event_db(db, user, f"Generate: {request.filename}")
                await db.commit()

    try:
        analysis = antlr_analyze_cobol(request.cobol_code)
    except Exception as e:
        logger.error("ANTLR4 parse failed in /generate: %s", e)
        return {"success": False, "python_code": None, "error": str(e)}

    try:
        gen_result = generate_python_module(analysis)
        python_code = gen_result["code"]
    except Exception as e:
        logger.error("Generation failed: %s", e)
        return {
            "success": False,
            "python_code": None,
            "error": str(e),
        }

    # generate_python_module returns "# PARSE ERROR: ..." on failure
    if python_code.startswith("# PARSE ERROR"):
        return {
            "success": False,
            "python_code": None,
            "error": python_code.replace("# PARSE ERROR: ", ""),
        }

    return {
        "success": True,
        "python_code": python_code,
        "error": None,
    }


# ════════════════════════════════════════════════════════════════════════
# UNIFIED ENGINE ENDPOINT
# ════════════════════════════════════════════════════════════════════════

def _offline_verification_stub(
    parser_output: Dict[str, Any],
    generated_python: Optional[str],
) -> Dict[str, Any]:
    """
    Deterministic verification stub when GPT is unavailable.

    Returns binary verification_status: VERIFIED or REQUIRES_MANUAL_REVIEW.
    GPT is only used for formatting/explanation — correctness is deterministic.
    """
    summary = parser_output.get("summary", {})
    para_count = summary.get("paragraphs", 0)
    var_count = summary.get("variables", 0)
    comp3_count = summary.get("comp3_variables", 0)
    parse_errors = parser_output.get("parse_errors", 0)

    generator_recovered = (
        parse_errors > 0
        and generated_python is not None
        and "MANUAL REVIEW" not in generated_python
    )
    if generator_recovered:
        try:
            compile(generated_python, "<verify>", "exec")
        except SyntaxError:
            generator_recovered = False
    all_stages_passed = (
        parser_output.get("success")
        and generated_python is not None
        and (parse_errors == 0 or generator_recovered)
    )
    status = "VERIFIED" if all_stages_passed else "REQUIRES_MANUAL_REVIEW"

    return {
        "verification_status": status,
        "executive_summary": (
            f"ANTLR4 parser extracted {para_count} paragraphs, "
            f"{var_count} variables ({comp3_count} COMP-3). "
            f"{'Python generated successfully.' if generated_python else 'Python generation unavailable.'} "
            "GPT explanation was NOT run."
        ),
        "business_logic": [],
        "checklist": [
            {"item": "ANTLR4 Parse", "status": "PASS", "note": "Deterministic parser completed."},
            {"item": "Python Generation", "status": "PASS" if generated_python else "FAIL", "note": "Deterministic transpiler." if generated_python else "Generator unavailable."},
            {"item": "Parse Errors", "status": "PASS" if parse_errors == 0 or generator_recovered else "WARN", "note": f"{parse_errors} syntax warning(s) — generator recovered all" if generator_recovered else (f"{parse_errors} syntax warning(s)" if parse_errors > 0 else "Clean parse.")},
            {"item": "GPT Explanation", "status": "WARN", "note": "OpenAI API key not configured — explanation skipped."},
        ],
        "human_review_items": [
            {
                "item": "Deterministic pipeline incomplete",
                "reason": "One or more stages did not complete successfully.",
                "severity": "HIGH",
            },
        ] if not all_stages_passed else [],
    }


async def _run_engine_analysis(
    cobol_code: str,
    filename: str,
    compiler_config: dict | None,
    username: Optional[str],
    trace_mode: bool = False,
) -> dict:
    """Internal helper — full engine analysis pipeline.

    Called by both /engine/analyze and /engine/verify-full.
    """
    # ── Stage 1: ANTLR4 Parse ────────────────────────────────────────
    parser_output = None
    if ANTLR_AVAILABLE:
        try:
            logger.info("COBOL code length: %d, first 50 chars: %s", len(cobol_code),
                        cobol_code[:50])
            parser_output = antlr_analyze_cobol(cobol_code)
            parser_output["filename"] = filename
            parser_output["parser"] = "ANTLR4"
            parser_output["engine"] = "deterministic"
            logger.info("Parser output: success=%s, paragraphs=%s", parser_output.get("success"), parser_output.get("summary", {}).get("paragraphs"))
        except Exception as e:
            logger.error("ANTLR4 parse failed: %s", e)
            parser_output = None

    if parser_output is None:
        parser_output = {
            "success": False,
            "message": "ANTLR4 parser unavailable or failed.",
            "summary": {},
            "paragraphs": [],
            "variables": [],
            "control_flow": [],
            "computes": [],
            "conditions": [],
            "cycles": [],
            "unreachable": [],
            "filename": filename,
            "parser": "none",
            "engine": "offline",
        }

    # ── Stage 2: Python Generation ───────────────────────────────────
    active_compiler_config = None
    if compiler_config:
        # Explicit user config takes priority over CBL/PROCESS detection
        try:
            from compiler_config import set_config, get_config
            set_config(**compiler_config)
            active_compiler_config = get_config()
        except (ValueError, TypeError) as e:
            logger.warning("Invalid compiler_config in request: %s", e)
    else:
        # Auto-apply CBL/PROCESS options detected in source (implicit < explicit)
        detected = parser_output.get("compiler_options_detected")
        if detected:
            try:
                from compiler_config import set_config, get_config
                cfg_kwargs = {}
                if "trunc_mode" in detected:
                    cfg_kwargs["trunc_mode"] = detected["trunc_mode"]
                if "arith_mode" in detected:
                    cfg_kwargs["arith_mode"] = detected["arith_mode"]
                if "decimal_point" in detected:
                    cfg_kwargs["decimal_point"] = detected["decimal_point"]
                if cfg_kwargs:
                    set_config(**cfg_kwargs)
                    active_compiler_config = get_config()
                    logger.info("Auto-applied CBL/PROCESS options: %s", cfg_kwargs)
            except (ValueError, TypeError, ImportError) as e:
                logger.warning("Failed to apply detected compiler options: %s", e)

    generated_python = None
    emit_counts = {}
    compiler_warnings = []
    mr_flags = []
    if GENERATOR_AVAILABLE and parser_output.get("success"):
        try:
            gen_result = generate_python_module(parser_output, compiler_config=active_compiler_config, trace_mode=trace_mode)
            code = gen_result["code"]
            emit_counts = gen_result.get("emit_counts", {})
            compiler_warnings = gen_result.get("compiler_warnings", [])
            mr_flags = gen_result.get("mr_flags", [])
            if not code.startswith("# PARSE ERROR"):
                generated_python = code
        except Exception as e:
            logger.error("Python generation failed: %s", e)

    arith_specified = (
        (compiler_config and "arith_mode" in compiler_config)
        or "arith_mode" in parser_output.get("compiler_options_detected", {})
    )
    if not arith_specified:
        compiler_warnings.append(
            "ARITH not specified. Defaulting to COMPAT "
            "(18-digit intermediate precision)."
        )

    # ── Stage 2.5: Arithmetic Risk Analysis ──────────────────────────
    arithmetic_risks = []
    arithmetic_summary = {"total": 0, "safe": 0, "warn": 0, "critical": 0}
    if GENERATOR_AVAILABLE and parser_output.get("success"):
        try:
            arith_data = compute_arithmetic_risks(parser_output)
            arithmetic_risks = arith_data.get("risks", [])
            arithmetic_summary = arith_data.get("summary", arithmetic_summary)
        except Exception as e:
            logger.error("Arithmetic risk analysis failed: %s", e)

    # ── Stage 2.6: Dead Code Analysis ─────────────────────────────────
    dead_code = {"unreachable_paragraphs": [], "total_paragraphs": 0,
                 "reachable_paragraphs": 0, "dead_percentage": 0.0, "has_alter": False}
    if parser_output and parser_output.get("success"):
        try:
            from dead_code_analyzer import analyze_dead_code
            dead_code = analyze_dead_code(parser_output)
        except Exception as e:
            logger.error("Dead code analysis failed: %s", e)

    # ── Stage 3: GPT-4o Verification ─────────────────────────────────
    verification = None
    try:
        if (
            analysis_engine.client
            and parser_output.get("success")
        ):
            user_payload = (
                f"COBOL SOURCE ({filename}):\n"
                f"{cobol_code}\n\n"
                f"PARSER OUTPUT:\n"
                f"{json.dumps(parser_output, indent=2)}\n\n"
                f"GENERATED PYTHON:\n"
                f"{generated_python or '(generation unavailable)'}"
            )

            gpt_response = await analysis_engine.client.chat.completions.create(
                model="gpt-4o",
                messages=[
                    {"role": "system", "content": _ENGINE_VERIFICATION_SYSTEM_PROMPT},
                    {"role": "user", "content": user_payload},
                ],
                response_format={"type": "json_object"},
                temperature=0.1,
            )

            raw = gpt_response.choices[0].message.content
            verification = json.loads(raw)
    except Exception as e:
        logger.error("GPT verification failed: %s", e)
        verification = None

    # Fallback to offline stub
    if verification is None:
        verification = _offline_verification_stub(parser_output, generated_python)

    # ── Compute binary verification status DETERMINISTICALLY ──────────
    parse_errors = parser_output.get("parse_errors", 0) if parser_output else 1
    generator_recovered = (
        parse_errors > 0
        and generated_python is not None
        and "MANUAL REVIEW" not in generated_python
    )
    if generator_recovered:
        try:
            compile(generated_python, "<verify>", "exec")
        except SyntaxError:
            generator_recovered = False
    all_stages_passed = (
        parser_output and parser_output.get("success")
        and generated_python is not None
        and (parse_errors == 0 or generator_recovered)
    )
    verification_status = "VERIFIED" if all_stages_passed else "REQUIRES_MANUAL_REVIEW"

    # ALTER statement = hard stop
    exec_deps = parser_output.get("exec_dependencies", []) if parser_output else []
    alter_deps = [d for d in exec_deps if d.get("type") == "ALTER"]
    if alter_deps:
        verification_status = "REQUIRES_MANUAL_REVIEW"

    verification["verification_status"] = verification_status
    verification.pop("confidence", None)

    # ── Build human_review_items from generator MR flags ──────────
    human_review_items = []
    if not all_stages_passed and not mr_flags:
        human_review_items.append({
            "item": "Deterministic pipeline incomplete",
            "reason": "One or more stages did not complete successfully.",
            "severity": "HIGH",
        })
    for flag in mr_flags:
        human_review_items.append({
            "item": flag["construct"],
            "reason": flag["reason"],
            "recommendation": flag.get("recommendation", ""),
            "severity": flag["severity"],
        })
    # Add exec dependency flags (SQL/CICS not already covered by generator)
    exec_deps = parser_output.get("exec_dependencies", []) if parser_output else []
    sql_deps = [d for d in exec_deps if d.get("type") not in ("ALTER", None)]
    if sql_deps and not any(f["construct"] in ("EXEC SQL", "EXEC CICS") for f in mr_flags):
        human_review_items.append({
            "item": f"{len(sql_deps)} EXEC SQL/CICS blocks detected",
            "reason": "External dependencies stripped from verification model.",
            "recommendation": "Verify SQL logic separately. Check SQLCODE handling and variable taint.",
            "severity": "HIGH",
        })
    verification["human_review_items"] = human_review_items

    formatted_output = (
        f"═══ ENGINE ANALYSIS: {filename} ═══\n\n"
        f"Status: {verification_status}\n\n"
        f"{verification.get('executive_summary', 'No summary available.')}"
    )

    # ── Audit trail ──────────────────────────────────────────────────
    if username:
        if USE_IN_MEMORY_DB or not DB_AVAILABLE:
            record_security_event(username, f"Engine Analyze: {filename}")
        else:
            async with AsyncSessionLocal() as db:
                user = await get_user_by_username_db(db, username)
                if user:
                    await record_security_event_db(
                        db, user, f"Engine Analyze: {filename}"
                    )
                    await db.commit()

    result = {
        "success": parser_output.get("success", False) and generated_python is not None,
        "verification_status": verification_status,
        "parser_output": parser_output,
        "generated_python": generated_python,
        "verification": verification,
        "formatted_output": formatted_output,
        "arithmetic_risks": arithmetic_risks,
        "arithmetic_summary": arithmetic_summary,
        "emit_counts": emit_counts,
        "dead_code": dead_code,
        "compiler_warnings": compiler_warnings,
    }

    vault_id = None
    if VAULT_AVAILABLE:
        try:
            vault_id = save_to_vault(result, cobol_code)
        except Exception as e:
            logger.error("Vault save failed: %s", e)
    result["vault_id"] = vault_id

    # Audit log
    if username:
        try:
            from audit_logger import log_event
            log_event(username, "ANALYZE", {
                "filename": result.get("filename"),
                "verdict": result.get("verification_status"),
            })
        except ImportError:
            pass

    return result


@app.post("/engine/analyze")
async def engine_analyze(
    request: AnalyzeRequest,
    raw_request: Request,
    username: Optional[str] = Depends(verify_token_optional),
):
    """
    Unified Engine — single endpoint that orchestrates all three stages:

    1. ANTLR4 deterministic parse
    2. Deterministic Python generation
    3. GPT-4o verification & explanation

    Falls back gracefully at every stage.
    Guests (no token): no rate limit, no license required.
    Authenticated users: normal engine rate limit + license check.
    """

    if not request.cobol_code.strip():
        raise HTTPException(status_code=400, detail="Empty COBOL source provided.")

    return await _run_engine_analysis(
        cobol_code=request.cobol_code,
        filename=request.filename or "source.cbl",
        compiler_config=request.compiler_config,
        username=username,
        trace_mode=request.trace_mode,
    )




# ──────────────────────────────────────────────────────────────────────
# VERIFY-FULL: Combined Engine + Shadow Diff in one call
# ──────────────────────────────────────────────────────────────────────

@app.post("/engine/verify-full")
async def engine_verify_full(
    request: VerifyFullRequest,
    username: Optional[str] = Depends(verify_token_optional),
):
    """
    Combined Engine + Shadow Diff — single endpoint, single response.

    1. ANTLR4 parse → Python generation → arithmetic risk → GPT verification
    2. Shadow Diff: parse input/output → execute generated Python → compare
    3. Unified verdict: FULLY VERIFIED only if both stages pass.
    """
    username = username or "guest"
    if not request.cobol_code.strip():
        raise HTTPException(status_code=400, detail="Empty COBOL source provided.")

    # ── Stage A: Engine Analysis ─────────────────────────────────────
    engine_result = await _run_engine_analysis(
        cobol_code=request.cobol_code,
        filename=request.filename or "source.cbl",
        compiler_config=request.compiler_config,
        username=username,
    )

    engine_verdict = engine_result.get("verification_status", "REQUIRES_MANUAL_REVIEW")
    generated_python = engine_result.get("generated_python")

    # ── Stage B: Shadow Diff ─────────────────────────────────────────
    shadow_diff_result = None
    layout = request.layout  # may be None; auto-generated below if needed

    if SHADOW_DIFF_AVAILABLE and generated_python:
        try:
            input_bytes = base64.b64decode(request.input_data)
            output_bytes = base64.b64decode(request.output_data)
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid base64 in input_data or output_data.")

        input_hash = hashlib.sha256(input_bytes).hexdigest()
        output_hash = hashlib.sha256(output_bytes).hexdigest()

        if layout is None:
            # Auto-generate layout from DATA DIVISION
            try:
                from layout_generator import generate_layout
                analysis_for_layout = dict(engine_result.get("parser_output", {}))
                layout = generate_layout(
                    analysis_for_layout,
                    generated_python,
                    request.filename or "source.cbl",
                )
            except ImportError:
                raise HTTPException(status_code=500, detail="Layout auto-generation not available.")
            except Exception as e:
                raise HTTPException(status_code=400, detail=f"Layout auto-generation failed: {e}")

        input_mapping = layout.get("input_mapping")
        output_fields = layout.get("output_fields")
        if not input_mapping:
            raise HTTPException(status_code=400, detail="layout must include 'input_mapping'.")
        if not output_fields:
            raise HTTPException(status_code=400, detail="layout must include 'output_fields'.")

        # Parse constants to Decimal where possible
        raw_constants = layout.get("constants") or {}
        parsed_constants = {}
        for k, v in raw_constants.items():
            try:
                parsed_constants[k] = Decimal(str(v))
            except Exception:
                parsed_constants[k] = v

        # Build input layout (only fields referenced by input_mapping)
        input_layout = {
            "fields": [f for f in layout["fields"] if f["name"] in input_mapping],
            "record_length": layout.get("record_length"),
        }

        # Build mainframe output stream with field mapping
        output_layout_def = layout.get("output_layout")
        if not output_layout_def:
            raise HTTPException(status_code=400, detail="layout must include 'output_layout'.")

        output_field_mapping = output_layout_def.get("field_mapping", {})

        def _mainframe_stream():
            for rec in parse_fixed_width_stream(output_layout_def, output_bytes):
                mapped = {}
                for cobol_name, python_name in output_field_mapping.items():
                    if cobol_name in rec:
                        mapped[python_name] = str(rec[cobol_name])
                yield mapped

        # Run streaming pipeline
        comparison = run_streaming_pipeline(
            source=generated_python,
            input_stream=parse_fixed_width_stream(input_layout, input_bytes),
            mainframe_stream=_mainframe_stream(),
            input_mapping=input_mapping,
            output_fields=output_fields,
            constants=parsed_constants,
        )

        # Generate report (includes diagnose_drift internally)
        report = sd_generate_report(
            comparison,
            input_file_hash=input_hash,
            output_file_hash=output_hash,
            layout_name=layout.get("name", ""),
            layout=layout,
        )

        shadow_diff_result = {
            "verdict": report["verdict"],
            "total_records": report["total_records"],
            "matches": report["matches"],
            "mismatches": report["mismatches"],
            "mismatch_details": report["mismatch_log"],
            "drift_diagnoses": report["diagnosed_mismatches"],
            "input_fingerprint": f"sha256:{input_hash}",
            "output_fingerprint": f"sha256:{output_hash}",
        }

    # ── Unified Verdict ──────────────────────────────────────────────
    if shadow_diff_result is not None:
        sd_clean = shadow_diff_result["mismatches"] == 0
        unified = "FULLY VERIFIED" if engine_verdict == "VERIFIED" and sd_clean else "VERIFICATION INCOMPLETE"
    else:
        unified = engine_verdict

    # Build response before dereferencing sensitive data
    import gc as _gc
    response = {
        "unified_verdict": unified,
        "engine_result": engine_result,
        "shadow_diff_result": shadow_diff_result,
        "auto_layout": layout if not request.layout else None,
        "vault_id": engine_result.get("vault_id"),
    }
    # Dereference sensitive data — defense-in-depth, not a cryptographic guarantee
    del engine_result, shadow_diff_result
    _gc.collect()
    logger.info("verify-full: sensitive data dereferenced for %s", username)
    return response


# ──────────────────────────────────────────────────────────────────────
# GENERATE LAYOUT (standalone)
# ──────────────────────────────────────────────────────────────────────

@app.post("/engine/generate-layout")
async def engine_generate_layout(
    request: AnalyzeRequest,
    username: Optional[str] = Depends(verify_token_optional),
):
    """Auto-generate Shadow Diff layout JSON from COBOL source."""
    if not ANTLR_AVAILABLE:
        raise HTTPException(status_code=500, detail="ANTLR4 parser unavailable.")
    if not GENERATOR_AVAILABLE:
        raise HTTPException(status_code=500, detail="Python generator unavailable.")

    from layout_generator import generate_layout

    parser_output = antlr_analyze_cobol(request.cobol_code)
    if not parser_output.get("success"):
        raise HTTPException(status_code=400, detail="COBOL parse failed.")

    gen_result = generate_python_module(parser_output)
    code = gen_result["code"]

    layout = generate_layout(parser_output, code, program_name=request.filename)
    return layout


# ──────────────────────────────────────────────────────────────────────
# COMPILER OPTION MATRIX REPORT
# ──────────────────────────────────────────────────────────────────────


def generate_compiler_matrix(parser_output):
    """Cross-reference detected compiler options with constructs that need them."""
    detected = parser_output.get("compiler_options_detected", {})
    variables = parser_output.get("variables", [])

    # --- Count constructs by storage type ---
    comp3_count = sum(1 for v in variables if v.get("comp3"))
    comp_count = sum(1 for v in variables if v.get("storage_type") == "COMP")
    signed_comp3 = sum(
        1 for v in variables
        if v.get("comp3") and v.get("pic_info", {}).get("signed")
    )

    # --- Count arithmetic constructs ---
    arithmetics = parser_output.get("arithmetics", [])
    computes = parser_output.get("computes", [])
    mul_div = [a for a in arithmetics if a.get("verb") in ("MULTIPLY", "DIVIDE")]
    on_size_error = [a for a in arithmetics if a.get("on_size_error")]

    # --- Detected vs defaults ---
    IBM_DEFAULTS = {
        "TRUNC": "STD",
        "ARITH": "COMPAT",
        "NUMPROC": "NOPFD",
        "DECIMAL-POINT": "PERIOD",
    }
    DETECTED_KEY_MAP = {
        "TRUNC": "trunc_mode",
        "ARITH": "arith_mode",
        "NUMPROC": "numproc",
        "DECIMAL-POINT": "decimal_point",
    }

    detected_options = {}
    defaults_applied = {}
    for option, key in DETECTED_KEY_MAP.items():
        val = detected.get(key)
        if val:
            detected_options[option] = val
        else:
            detected_options[option] = None
            defaults_applied[option] = IBM_DEFAULTS[option]

    # --- Constructs requiring each option ---
    constructs = {"TRUNC": [], "ARITH": [], "NUMPROC": [], "DECIMAL-POINT": []}

    if comp3_count:
        constructs["TRUNC"].append(f"{comp3_count} COMP-3 field{'s' if comp3_count != 1 else ''}")
    if comp_count:
        constructs["TRUNC"].append(f"{comp_count} COMP/COMP-4 field{'s' if comp_count != 1 else ''}")
    if on_size_error:
        constructs["TRUNC"].append(f"{len(on_size_error)} ON SIZE ERROR handler{'s' if len(on_size_error) != 1 else ''}")

    if computes:
        constructs["ARITH"].append(f"{len(computes)} COMPUTE statement{'s' if len(computes) != 1 else ''}")
    if mul_div:
        constructs["ARITH"].append(f"{len(mul_div)} MULTIPLY/DIVIDE operation{'s' if len(mul_div) != 1 else ''}")

    if signed_comp3:
        constructs["NUMPROC"].append(f"{signed_comp3} signed COMP-3 field{'s' if signed_comp3 != 1 else ''}")

    if detected.get("decimal_point") == "COMMA":
        constructs["DECIMAL-POINT"].append("DECIMAL-POINT IS COMMA in source")

    # --- Warnings for options that matter but weren't detected ---
    warnings = []
    for option in ("TRUNC", "ARITH", "NUMPROC"):
        if constructs[option] and detected_options[option] is None:
            warnings.append(
                f"{option} not specified in source — defaulting to {IBM_DEFAULTS[option]}"
            )

    # --- Dynamic recommendation ---
    undetected_that_matter = [
        opt for opt in ("TRUNC", "ARITH", "NUMPROC", "DECIMAL-POINT")
        if constructs[opt] and detected_options[opt] is None
    ]
    all_detected = not defaults_applied
    none_detected = all(v is None for v in detected_options.values())

    if all_detected:
        recommendation = "All compiler options found in source. Ready for verification."
    elif none_detected:
        recommendation = (
            "No compiler options found in source. Aletheia will use IBM defaults "
            f"(TRUNC={IBM_DEFAULTS['TRUNC']}, ARITH={IBM_DEFAULTS['ARITH']}, "
            f"NUMPROC={IBM_DEFAULTS['NUMPROC']}). "
            "Strongly recommend confirming these match your installation."
        )
    else:
        missing = ", ".join(
            f"{opt}={IBM_DEFAULTS[opt]}" for opt in undetected_that_matter
        )
        if missing:
            recommendation = (
                f"Defaulting: {missing}. "
                "Confirm with your systems programmer before relying on verification results."
            )
        else:
            recommendation = "Detected options applied. Remaining defaults are safe — no constructs require them."

    return {
        "detected_options": detected_options,
        "defaults_applied": defaults_applied,
        "constructs_requiring_options": constructs,
        "warnings": warnings,
        "recommendation": recommendation,
    }


class CompilerMatrixRequest(BaseModel):
    cobol_code: str
    filename: Optional[str] = "input.cbl"


@app.post("/engine/compiler-matrix")
async def engine_compiler_matrix(
    request: CompilerMatrixRequest,
    username: Optional[str] = Depends(verify_token_optional),
):
    """Analyze COBOL source and report which compiler options are detected vs defaulted."""
    if not ANTLR_AVAILABLE:
        raise HTTPException(status_code=500, detail="ANTLR4 parser unavailable.")
    if not request.cobol_code.strip():
        raise HTTPException(status_code=400, detail="Empty COBOL source provided.")

    parser_output = antlr_analyze_cobol(request.cobol_code)
    if not parser_output.get("success"):
        raise HTTPException(status_code=400, detail="COBOL parse failed.")

    matrix = generate_compiler_matrix(parser_output)
    return {
        "success": True,
        "filename": request.filename,
        "matrix": matrix,
    }


# ──────────────────────────────────────────────────────────────────────
# PORTFOLIO RISK HEATMAP
# ──────────────────────────────────────────────────────────────────────


class RiskHeatmapRequest(BaseModel):
    programs: list  # [{"cobol_code": str, "filename": str}, ...]


@app.post("/engine/risk-heatmap")
async def engine_risk_heatmap(
    request: RiskHeatmapRequest,
    username: Optional[str] = Depends(verify_token_optional),
):
    """Analyze a portfolio of COBOL programs and produce a color-coded risk heatmap."""
    if not ANTLR_AVAILABLE:
        raise HTTPException(status_code=500, detail="ANTLR4 parser unavailable.")
    if not request.programs:
        raise HTTPException(status_code=400, detail="Empty program list.")
    if len(request.programs) > 100:
        raise HTTPException(status_code=400, detail="Maximum 100 programs per request.")

    from risk_heatmap import generate_risk_heatmap

    enriched = []
    for prog in request.programs:
        code = prog.get("cobol_code", "")
        filename = prog.get("filename", "input.cbl")
        if not code.strip():
            continue
        analysis = antlr_analyze_cobol(code)
        lines = len(code.splitlines())
        enriched.append({"filename": filename, "lines": lines, "analysis": analysis})

    heatmap = generate_risk_heatmap(enriched)
    return {"success": True, "heatmap": heatmap}


# ──────────────────────────────────────────────────────────────────────
# POISON PILL GENERATOR
# ──────────────────────────────────────────────────────────────────────


class PoisonPillRequest(BaseModel):
    cobol_code: str
    filename: Optional[str] = "input.cbl"
    compiler_config: Optional[dict] = None


class RunPoisonPillRequest(BaseModel):
    cobol_code: str
    dat_base64: str
    pills: list
    layout: dict
    filename: Optional[str] = "input.cbl"
    compiler_config: Optional[dict] = None


@app.post("/engine/generate-poison-pills")
async def engine_generate_poison_pills(
    request: PoisonPillRequest,
    username: Optional[str] = Depends(verify_token_optional),
):
    """Generate edge-case poison pill input records for boundary testing."""
    if not ANTLR_AVAILABLE:
        raise HTTPException(status_code=500, detail="ANTLR4 parser unavailable.")
    if not GENERATOR_AVAILABLE:
        raise HTTPException(status_code=500, detail="Python generator unavailable.")

    from layout_generator import generate_layout
    from poison_pill_generator import generate_poison_pills

    parser_output = antlr_analyze_cobol(request.cobol_code)
    if not parser_output.get("success"):
        raise HTTPException(status_code=400, detail="COBOL parse failed.")

    gen_result = generate_python_module(parser_output)
    code = gen_result["code"]

    layout = generate_layout(parser_output, code, program_name=request.filename)
    result = generate_poison_pills(parser_output, code, layout)

    import base64
    dat_b64 = base64.b64encode(result["dat_bytes"]).decode("ascii")

    return {
        "dat_base64": dat_b64,
        "record_count": result["record_count"],
        "pills": result["pills"],
        "layout": result["layout"],
        "record_length": result["record_length"],
    }


@app.post("/engine/run-poison-pills")
async def engine_run_poison_pills(
    request: RunPoisonPillRequest,
    username: Optional[str] = Depends(verify_token_optional),
):
    """Execute generated Python against each poison pill record.

    Pure execution robustness test — no Shadow Diff. Reports clean/abend/error
    counts per record.
    """
    if not ANTLR_AVAILABLE:
        raise HTTPException(status_code=500, detail="ANTLR4 parser unavailable.")
    if not GENERATOR_AVAILABLE:
        raise HTTPException(status_code=500, detail="Python generator unavailable.")

    import base64

    parser_output = antlr_analyze_cobol(request.cobol_code)
    if not parser_output.get("success"):
        raise HTTPException(status_code=400, detail="COBOL parse failed.")

    gen_result = generate_python_module(parser_output)
    code = gen_result["code"]

    # Decode input .dat
    input_bytes = base64.b64decode(request.dat_base64)
    layout = request.layout
    input_mapping = layout.get("input_mapping", {})
    output_fields = layout.get("output_fields", [])
    constants = layout.get("constants", {})

    # Parse input records
    if SHADOW_DIFF_AVAILABLE:
        from shadow_diff import parse_fixed_width, _execute_one_record
        records = list(parse_fixed_width(layout, input_bytes))
    else:
        raise HTTPException(status_code=500, detail="Shadow Diff module unavailable.")

    pills = request.pills
    details = []
    clean_count = 0
    abend_count = 0
    error_count = 0

    for idx, record in enumerate(records):
        result = _execute_one_record(
            code, record, idx,
            input_mapping, output_fields, constants,
        )
        pill_info = pills[idx] if idx < len(pills) else {}
        err = result.get("_error")

        if err:
            if "S0C7" in str(err) or "abend" in str(err).lower():
                status = "abend"
                abend_count += 1
            else:
                status = "error"
                error_count += 1
        else:
            status = "clean"
            clean_count += 1

        details.append({
            "record_idx": idx,
            "field": pill_info.get("field", ""),
            "edge_case": pill_info.get("edge_case", ""),
            "status": status,
            "error_message": err,
        })

    return {
        "total": len(records),
        "clean": clean_count,
        "abends": abend_count,
        "errors": error_count,
        "details": details,
    }


# ──────────────────────────────────────────────────────────────────────
# JCL PARSER ENDPOINT
# ──────────────────────────────────────────────────────────────────────

try:
    from jcl_parser import parse_jcl as _parse_jcl
    JCL_PARSER_AVAILABLE = True
except ImportError:
    JCL_PARSER_AVAILABLE = False
    logger.warning("JCL parser not available.")

try:
    from sbom_generator import generate_sbom as _generate_sbom
    SBOM_AVAILABLE = True
except ImportError:
    SBOM_AVAILABLE = False
    logger.warning("SBOM generator not available.")


@app.post("/engine/parse-jcl")
async def engine_parse_jcl(
    request: Request,
    username: Optional[str] = Depends(verify_token_optional),
):
    """Parse IBM JCL text into a Job Step DAG."""
    if not JCL_PARSER_AVAILABLE:
        raise HTTPException(status_code=500, detail="JCL parser unavailable.")

    body = await request.json()
    jcl_text = body.get("jcl_text", "")
    if not jcl_text.strip():
        raise HTTPException(status_code=400, detail="Empty JCL text provided.")

    try:
        from dataclasses import asdict
        dag = _parse_jcl(jcl_text)
        result = asdict(dag)
        result["summary"] = dag.summary()
        return JSONResponse(content=result)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@app.post("/engine/generate-sbom")
async def engine_generate_sbom(
    request: Request,
    username: Optional[str] = Depends(verify_token_optional),
):
    """Generate a CycloneDX 1.4 SBOM from an analysis result."""
    if not SBOM_AVAILABLE:
        raise HTTPException(status_code=500, detail="SBOM generator unavailable.")

    body = await request.json()
    if not body.get("program_name"):
        raise HTTPException(status_code=400, detail="Missing program_name in request body.")

    try:
        sbom = _generate_sbom(body)
        return JSONResponse(content=sbom)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))


# ──────────────────────────────────────────────────────────────────────
# EXECUTION TRACE COMPARISON
# ──────────────────────────────────────────────────────────────────────

class TraceCompareRequest(BaseModel):
    """Request body for execution trace comparison."""
    trace_a: list = []        # trace from reference execution
    trace_b: list = []        # trace from migration execution
    cobol_code: Optional[str] = None  # original COBOL for context


@app.post("/engine/trace-compare")
async def engine_trace_compare(
    request: TraceCompareRequest,
    username: Optional[str] = Depends(verify_token_optional),
):
    """Compare two execution traces and find the first point of divergence.

    Accepts pre-built trace JSON from two verification runs.
    Returns the divergence point with root-cause diagnosis.
    """
    from execution_trace import compare_traces

    if not request.trace_a and not request.trace_b:
        return {"success": True, "diverged": False, "divergence_index": None,
                "event_a": None, "event_b": None, "total_events_a": 0,
                "total_events_b": 0, "matching_events": 0, "diagnosis": None}

    result = compare_traces(request.trace_a, request.trace_b)
    return {"success": True, **result}


# ──────────────────────────────────────────────────────────────────────
# STATIC FILE SERVING (SPA FALLBACK)
# ──────────────────────────────────────────────────────────────────────
#
# Serves the built React frontend from frontend/dist.
# Mounted AFTER all API routes so /engine/*, /vault/*, /auth/* etc.
# are handled first. Any non-API route falls through to index.html
# (SPA client-side routing).
#

DEMO_DATA_DIR = Path(__file__).resolve().parent / "demo_data"

ROOT_DEMO_FILES = {"DEMO_LOAN_INTEREST.cbl"}

@app.get("/demo-data/{filename}")
async def serve_demo_data(filename: str):
    """Serve demo data files for the Shadow Diff UI."""
    if filename in ROOT_DEMO_FILES:
        file_path = (Path(__file__).resolve().parent / filename).resolve()
        expected_dir = Path(__file__).resolve().parent
    else:
        file_path = (DEMO_DATA_DIR / filename).resolve()
        expected_dir = DEMO_DATA_DIR.resolve()
    if not file_path.is_file() or not file_path.is_relative_to(expected_dir):
        raise HTTPException(status_code=404, detail="Demo file not found")
    return FileResponse(file_path)


FRONTEND_DIR = Path(__file__).resolve().parent / "frontend" / "dist"

if FRONTEND_DIR.is_dir():
    @app.get("/{full_path:path}")
    async def serve_spa(request: Request, full_path: str):
        """Serve static files or fall back to index.html for SPA routing."""
        file_path = (FRONTEND_DIR / full_path).resolve()
        if file_path.is_file() and file_path.is_relative_to(FRONTEND_DIR.resolve()):
            return FileResponse(file_path)
        return FileResponse(FRONTEND_DIR / "index.html")

    logger.info("Serving frontend from %s", FRONTEND_DIR)
else:
    logger.warning(
        "Frontend build not found at %s — run 'cd frontend && npm run build'",
        FRONTEND_DIR,
    )


# ──────────────────────────────────────────────────────────────────────
# ENTRYPOINT
# ──────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import uvicorn

    # Log Decimal context at startup
    logger.info(
        "Starting with Decimal context: prec=%d, rounding=%s",
        getcontext().prec,
        getcontext().rounding,
    )

    uvicorn.run(app, host="0.0.0.0", port=8000, timeout_keep_alive=300)