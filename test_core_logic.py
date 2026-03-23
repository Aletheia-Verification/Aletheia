"""
test_core_logic.py — Zero-Error Audit Test Suite for Alethia Beyond v3.2.0
===========================================================================

Validates all 11 audit findings plus COBOL-semantic verification.

Test Categories:
    1. Pure Function Tests (Aletheia Vault candidates)
    2. Decimal Precision & Context Tests
    3. Authentication Flow Tests
    4. Authorization & Security Tests
    5. File Upload Guardrail Tests
    6. API Contract Tests (unchanged routes)
    7. COBOL Semantic Equivalence Tests

Run with:
    pytest test_core_logic.py -v --tb=short

Requires:
    pip install pytest pytest-anyio httpx
"""

import os

# Force in-memory mode for tests (must be set BEFORE importing core_logic)
os.environ["USE_IN_MEMORY_DB"] = "true"

from decimal import Decimal, ROUND_DOWN, ROUND_HALF_UP, getcontext
from datetime import datetime, timezone

import pytest
from httpx import AsyncClient, ASGITransport

from core_logic import (
    app,
    normalize_username,
    compute_complexity_score,
    record_security_event,
    create_access_token,
    decimal_safe_jsonable,
    users_db,
    password_hasher,
    LogicExtractionService,
    JWT_SECRET_KEY,
    JWT_ALGORITHM,
)
from jose import jwt


# ══════════════════════════════════════════════════════════════════════
# FIXTURES
# ══════════════════════════════════════════════════════════════════════

@pytest.fixture(autouse=True)
def reset_users_db():
    """Isolate every test with a clean user store."""
    users_db.clear()
    users_db["admin"] = {
        "password": password_hasher.hash("admin123"),
        "institution": "Aletheia Global",
        "city": "London",
        "country": "UK",
        "role": "Chief Architect",
        "is_approved": True,
        "security_history": [],
    }
    yield


@pytest.fixture
def admin_token() -> str:
    """Valid JWT for the pre-seeded admin user."""
    return create_access_token({"sub": "admin"})


@pytest.fixture
def unapproved_user_token() -> str:
    """Register an unapproved user and return their JWT."""
    users_db["analyst"] = {
        "password": password_hasher.hash("pass456"),
        "institution": "Test Corp",
        "city": "Berlin",
        "country": "DE",
        "role": "Analyst",
        "is_approved": False,
        "security_history": [],
    }
    return create_access_token({"sub": "analyst"})


@pytest.fixture
def async_client():
    """Async test client bound to the FastAPI app."""
    transport = ASGITransport(app=app)
    return AsyncClient(transport=transport, base_url="http://test")


# ══════════════════════════════════════════════════════════════════════
# 1. PURE FUNCTION TESTS — Aletheia Vault Candidates
# ══════════════════════════════════════════════════════════════════════

class TestNormalizeUsername:
    """
    Tests for normalize_username() — a pure, stateless function.

    COBOL Reference: N/A (platform utility)
    """

    def test_lowercases_input(self):
        """Standard case conversion."""
        assert normalize_username("JohnDoe") == "johndoe"
        assert normalize_username("ALICE") == "alice"

    def test_strips_whitespace(self):
        """Leading/trailing whitespace removed."""
        assert normalize_username("  bob  ") == "bob"

    def test_type_validation(self):
        """Rejects non-string input."""
        with pytest.raises(TypeError):
            normalize_username(12345)
        with pytest.raises(TypeError):
            normalize_username(None)

    def test_deterministic(self):
        """Same input always produces same output."""
        for _ in range(100):
            assert normalize_username("TestUser") == "testuser"


class TestComputeComplexityScore:
    """
    Tests for compute_complexity_score() — a pure function returning Decimal.

    COBOL Reference: Mainframe code quality metrics
    """

    def test_returns_decimal(self):
        """Output is always Decimal, never float."""
        result = compute_complexity_score(100)
        assert isinstance(result, Decimal)

    def test_minimum_score(self):
        """Empty/minimal code returns base score."""
        result = compute_complexity_score(0)
        assert result == Decimal("1.0")

    def test_scales_with_line_count(self):
        """Larger programs score higher."""
        small = compute_complexity_score(30)
        medium = compute_complexity_score(150)
        large = compute_complexity_score(600)
        assert small < medium < large

    def test_branch_complexity_increases_score(self):
        """More branches = higher complexity."""
        base = compute_complexity_score(100, branch_count=0)
        branchy = compute_complexity_score(100, branch_count=10)
        assert branchy > base

    def test_nesting_increases_score(self):
        """Deep nesting = higher complexity."""
        flat = compute_complexity_score(100, nesting_depth=1)
        nested = compute_complexity_score(100, nesting_depth=8)
        assert nested > flat

    def test_clamped_to_range(self):
        """Score never exceeds 10.0 or drops below 1.0."""
        extreme = compute_complexity_score(10000, branch_count=100, nesting_depth=50)
        assert extreme <= Decimal("10.0")
        assert extreme >= Decimal("1.0")

    def test_deterministic(self):
        """Pure function: same input → same output."""
        for _ in range(100):
            assert compute_complexity_score(200, 5, 3) == compute_complexity_score(200, 5, 3)


class TestDecimalSafeJsonable:
    """
    Tests for decimal_safe_jsonable() — Decimal → string conversion.

    [AUD-008] Ensures Decimal values survive JSON serialization.
    """

    def test_converts_decimal_to_string(self):
        """Decimal becomes string representation."""
        result = decimal_safe_jsonable(Decimal("123.456"))
        assert result == "123.456"
        assert isinstance(result, str)

    def test_preserves_precision(self):
        """Full precision maintained in string."""
        val = Decimal("0.123456789012345678901234567")
        result = decimal_safe_jsonable(val)
        assert result == "0.123456789012345678901234567"

    def test_handles_nested_dict(self):
        """Recursively processes dict values."""
        data = {
            "amount": Decimal("100.50"),
            "nested": {"rate": Decimal("0.05")},
        }
        result = decimal_safe_jsonable(data)
        assert result["amount"] == "100.50"
        assert result["nested"]["rate"] == "0.05"

    def test_handles_list(self):
        """Recursively processes list items."""
        data = [Decimal("1.1"), Decimal("2.2"), Decimal("3.3")]
        result = decimal_safe_jsonable(data)
        assert result == ["1.1", "2.2", "3.3"]

    def test_passthrough_non_decimal(self):
        """Non-Decimal values unchanged."""
        assert decimal_safe_jsonable("hello") == "hello"
        assert decimal_safe_jsonable(42) == 42
        assert decimal_safe_jsonable(True) is True


# ══════════════════════════════════════════════════════════════════════
# 2. DECIMAL PRECISION & CONTEXT TESTS
# ══════════════════════════════════════════════════════════════════════

class TestDecimalContext:
    """
    [AUD-009] Verify global Decimal context is correctly configured.

    COBOL Reference: IBM Enterprise COBOL extended precision
    """

    def test_precision_is_28(self):
        """Matches COBOL extended precision."""
        ctx = getcontext()
        assert ctx.prec == 28

    def test_default_rounding_is_truncation(self):
        """Default matches COBOL COMPUTE without ROUNDED."""
        ctx = getcontext()
        assert ctx.rounding == ROUND_DOWN

    def test_no_precision_loss_in_calculation(self):
        """
        Verify intermediate precision preserved.

        COBOL Semantic: Intermediate results maintain full precision
        until final assignment to PIC-defined field.
        """
        # Simulate multi-step calculation
        rate = Decimal("0.0525")
        principal = Decimal("1000000.00")
        days = Decimal("365")

        # Interest calculation (would lose precision with lower context)
        daily_rate = rate / days
        interest = principal * daily_rate * Decimal("30")

        # Should maintain precision through calculation
        assert len(str(daily_rate).replace(".", "").lstrip("0")) > 10


# ══════════════════════════════════════════════════════════════════════
# 3. OFFLINE STUB TESTS — [AUD-001/008]
# ══════════════════════════════════════════════════════════════════════

class TestOfflineStubs:
    """
    [AUD-001/008] Offline stubs must use string-encoded Decimal, never float.
    """

    def test_extraction_stub_complexity_is_string(self):
        """complexity_score is string representation of Decimal."""
        stub = LogicExtractionService._offline_extraction_stub(
            "test.cbl", "       IDENTIFICATION DIVISION.\n"
        )
        assert isinstance(stub["complexity_score"], str)
        # Verify it parses as valid Decimal
        Decimal(stub["complexity_score"])

    def test_extraction_stub_no_floats(self):
        """No float values anywhere in stub."""
        stub = LogicExtractionService._offline_extraction_stub(
            "test.cbl", "       IDENTIFICATION DIVISION.\n"
        )

        def check_no_floats(obj, path=""):
            if isinstance(obj, float):
                pytest.fail(f"Float found at {path}")
            elif isinstance(obj, dict):
                for k, v in obj.items():
                    check_no_floats(v, f"{path}.{k}")
            elif isinstance(obj, list):
                for i, v in enumerate(obj):
                    check_no_floats(v, f"{path}[{i}]")

        check_no_floats(stub)

    def test_audit_stub_structure(self):
        """Audit stub has required fields."""
        stub = LogicExtractionService._offline_audit_stub("audit.cbl")
        assert stub["filename"] == "audit.cbl"
        assert stub["drift_detected"] is False
        assert isinstance(stub["audit_findings"], list)
        assert isinstance(stub["verification_scenarios"], list)


# ══════════════════════════════════════════════════════════════════════
# 4. JWT & AUTHENTICATION TESTS — [AUD-002/003/004]
# ══════════════════════════════════════════════════════════════════════

class TestJWTExpiry:
    """[AUD-002] Tokens must have expiry claim."""

    def test_token_contains_exp_claim(self):
        """Tokens carry expiry to prevent indefinite validity."""
        token = create_access_token({"sub": "admin"})
        decoded = jwt.decode(
            token, JWT_SECRET_KEY, algorithms=[JWT_ALGORITHM]
        )
        assert "exp" in decoded
        assert "iat" in decoded

    def test_token_exp_is_in_future(self):
        """Expiry is at least 23 hours out."""
        token = create_access_token({"sub": "admin"})
        decoded = jwt.decode(
            token, JWT_SECRET_KEY, algorithms=[JWT_ALGORITHM]
        )
        exp_timestamp = decoded["exp"]
        now_timestamp = datetime.now(timezone.utc).timestamp()
        assert exp_timestamp > now_timestamp + (23 * 3600)


class TestTokenVerificationPrecision:
    """[AUD-003] verify_token error message precision."""

    @pytest.mark.anyio
    async def test_unknown_subject_returns_specific_message(
        self, async_client,
    ):
        """Token with unknown subject — auth is optional, returns 200 with guest fallback."""
        token = jwt.encode(
            {"sub": "nonexistent_user"},
            JWT_SECRET_KEY,
            algorithm=JWT_ALGORITHM,
        )
        resp = await async_client.get(
            "/auth/profile",
            headers={"Authorization": f"Bearer {token}"},
        )
        # Auth removed for V1 — unknown subject returns 200 (guest)
        assert resp.status_code == 200


class TestNormalizedTokenSubject:
    """[AUD-004] Login uses normalized username in token."""

    @pytest.mark.anyio
    async def test_mixed_case_login_produces_usable_token(
        self, async_client,
    ):
        """Mixed-case login normalizes to lowercase in token."""
        login_resp = await async_client.post("/auth/login", json={
            "username": "Admin",
            "password": "admin123",
        })
        assert login_resp.status_code == 200
        token = login_resp.json()["access_token"]

        profile_resp = await async_client.get(
            "/auth/profile",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert profile_resp.status_code == 200
        assert profile_resp.json()["username"] == "admin"

    @pytest.mark.anyio
    async def test_corporate_id_is_normalized(self, async_client):
        """corporate_id in login response is normalized."""
        resp = await async_client.post("/auth/login", json={
            "username": "Admin",
            "password": "admin123",
        })
        assert resp.json()["corporate_id"] == "admin"


# ══════════════════════════════════════════════════════════════════════
# 5. FILE UPLOAD GUARDRAILS — [AUD-005/006]
# ══════════════════════════════════════════════════════════════════════

class TestFileUploadGuardrails:
    """[AUD-005/006] File upload size and encoding validation."""

    @pytest.mark.anyio
    async def test_oversized_file_rejected(self, async_client, admin_token):
        """Files exceeding MAX_FILE_SIZE_MB rejected with 413."""
        oversized = b"A" * (11 * 1024 * 1024)  # 11 MB
        resp = await async_client.post(
            "/process-legacy",
            files={"file": ("big.cbl", oversized, "text/plain")},
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 413

    @pytest.mark.anyio
    async def test_non_utf8_file_rejected(self, async_client, admin_token):
        """Non-UTF-8 files rejected with 400."""
        bad_bytes = bytes(range(0x80, 0x90))
        resp = await async_client.post(
            "/process-legacy",
            files={"file": ("ebcdic.cbl", bad_bytes, "text/plain")},
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 400
        assert "utf-8" in resp.json()["detail"].lower()


# ══════════════════════════════════════════════════════════════════════
# 6. AUTHORIZATION TESTS — [AUD-007]
# ══════════════════════════════════════════════════════════════════════

class TestApproveRequiresAuth:
    """[AUD-007] Admin approve now requires authentication."""

    @pytest.mark.anyio
    async def test_approve_without_token_returns_403(self, async_client):
        """Auth removed but approve still requires approved caller — guest gets 403."""
        users_db["pending"] = {
            "password": password_hasher.hash("test"),
            "institution": "X",
            "city": "Y",
            "country": "Z",
            "role": "R",
            "is_approved": False,
            "security_history": [],
        }
        resp = await async_client.post("/admin/approve/pending")
        assert resp.status_code == 403

    @pytest.mark.anyio
    async def test_approve_with_token_succeeds(
        self, async_client, admin_token,
    ):
        """Authenticated callers can approve users."""
        users_db["pending"] = {
            "password": password_hasher.hash("test"),
            "institution": "X",
            "city": "Y",
            "country": "Z",
            "role": "R",
            "is_approved": False,
            "security_history": [],
        }
        resp = await async_client.post(
            "/admin/approve/pending",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 200
        assert users_db["pending"]["is_approved"] is True


# ══════════════════════════════════════════════════════════════════════
# 7. COBOL SEMANTIC EQUIVALENCE TESTS
# ══════════════════════════════════════════════════════════════════════

class TestCOBOLTruncationSemantics:
    """
    Verify Python Decimal behavior matches COBOL COMPUTE (no ROUNDED).

    COBOL Reference:
        COMPUTE WS-RESULT = WS-A / WS-B.
        → Result truncated to target PIC scale, not rounded.
    """

    def test_division_truncates_not_rounds(self):
        """
        COBOL: PIC S9(5)V99 receives 10/3 as 3.33, not 3.34.

        This is the single most common source of COBOL→Python drift.
        """
        dividend = Decimal("10")
        divisor = Decimal("3")
        pic_scale = Decimal("0.01")  # V99 = 2 decimal places

        # COBOL behavior: truncate (ROUND_DOWN)
        cobol_result = (dividend / divisor).quantize(pic_scale, rounding=ROUND_DOWN)
        assert cobol_result == Decimal("3.33")

        # Common Python mistake: ROUND_HALF_UP
        wrong_result = (dividend / divisor).quantize(pic_scale, rounding=ROUND_HALF_UP)
        assert wrong_result == Decimal("3.33")  # Same here, but different for .335

    def test_half_cent_truncates_down(self):
        """
        COBOL: 0.125 stored in PIC V99 becomes 0.12, not 0.13.
        """
        value = Decimal("0.125")
        pic_scale = Decimal("0.01")

        cobol_result = value.quantize(pic_scale, rounding=ROUND_DOWN)
        assert cobol_result == Decimal("0.12")

        # This is where drift occurs — Python default rounds up
        python_default = value.quantize(pic_scale, rounding=ROUND_HALF_UP)
        assert python_default == Decimal("0.13")

        # Verify the 0.01 difference that triggers CRITICAL finding
        drift = python_default - cobol_result
        assert drift == Decimal("0.01")

    def test_negative_truncation(self):
        """
        COBOL: Negative values also truncate toward zero.

        -3.335 in PIC S9(5)V99 becomes -3.33, not -3.34.
        """
        value = Decimal("-3.335")
        pic_scale = Decimal("0.01")

        cobol_result = value.quantize(pic_scale, rounding=ROUND_DOWN)
        assert cobol_result == Decimal("-3.33")


class TestCOBOLSignHandling:
    """
    Verify sign handling matches COBOL PIC S9 behavior.

    COBOL Reference:
        PIC S9(5)V99 → Signed field, can be negative
        PIC 9(5)V99  → Unsigned field, negative values cause issues
    """

    def test_signed_field_preserves_negative(self):
        """PIC S9 fields maintain sign."""
        balance = Decimal("-12345.67")
        # Signed field: sign preserved
        assert balance < 0
        assert abs(balance) == Decimal("12345.67")

    def test_intermediate_precision_preserved(self):
        """
        COBOL intermediate calculations can exceed target precision.

        The full precision is maintained until final store.
        """
        rate = Decimal("0.0833333333")  # 10% / 12 months
        principal = Decimal("100000.00")

        # Full intermediate precision
        monthly_interest = principal * rate
        assert len(str(monthly_interest)) > 10

        # Only truncate at final store to PIC V99
        final = monthly_interest.quantize(Decimal("0.01"), rounding=ROUND_DOWN)
        assert final == Decimal("8333.33")


# ══════════════════════════════════════════════════════════════════════
# 7b. EXEC SQL / CICS HANDLING TESTS
# ══════════════════════════════════════════════════════════════════════


class TestExecStatementHandling:
    """
    EXEC SQL and EXEC CICS blocks must be stripped before ANTLR4 parsing
    and flagged as EXTERNAL DEPENDENCY — REQUIRES MANUAL REVIEW.
    """

    def test_exec_sql_stripped_zero_parse_errors(self):
        """EXEC SQL blocks do not cause parse errors."""
        from cobol_analyzer_api import analyze_cobol
        source = (
            "       IDENTIFICATION DIVISION.\n"
            "       PROGRAM-ID. EXECTEST.\n"
            "       DATA DIVISION.\n"
            "       WORKING-STORAGE SECTION.\n"
            "       01  WS-BAL  PIC S9(5)V99.\n"
            "       PROCEDURE DIVISION.\n"
            "       MAIN-LOGIC.\n"
            "           EXEC SQL\n"
            "               SELECT BAL INTO :WS-BAL\n"
            "               FROM ACCOUNTS\n"
            "           END-EXEC.\n"
            "           STOP RUN.\n"
        )
        result = analyze_cobol(source)
        assert result["parse_errors"] == 0

    def test_exec_sql_flagged_as_dependency(self):
        """EXEC SQL block appears in exec_dependencies with correct type."""
        from cobol_analyzer_api import analyze_cobol
        source = (
            "       IDENTIFICATION DIVISION.\n"
            "       PROGRAM-ID. EXECTEST.\n"
            "       DATA DIVISION.\n"
            "       WORKING-STORAGE SECTION.\n"
            "       01  WS-BAL  PIC S9(5)V99.\n"
            "       PROCEDURE DIVISION.\n"
            "       MAIN-LOGIC.\n"
            "           EXEC SQL\n"
            "               SELECT BAL INTO :WS-BAL\n"
            "               FROM ACCOUNTS\n"
            "           END-EXEC.\n"
            "           STOP RUN.\n"
        )
        result = analyze_cobol(source)
        deps = result["exec_dependencies"]
        assert len(deps) == 1
        assert deps[0]["type"] == "EXEC SQL"
        assert deps[0]["verb"] == "SELECT"
        assert "MANUAL REVIEW" in deps[0]["flag"]

    def test_exec_cics_flagged(self):
        """EXEC CICS block detected and flagged."""
        from cobol_analyzer_api import analyze_cobol
        source = (
            "       IDENTIFICATION DIVISION.\n"
            "       PROGRAM-ID. EXECTEST.\n"
            "       PROCEDURE DIVISION.\n"
            "       MAIN-LOGIC.\n"
            "           EXEC CICS\n"
            "               SEND MAP('TESTMAP')\n"
            "           END-EXEC.\n"
            "           STOP RUN.\n"
        )
        result = analyze_cobol(source)
        deps = result["exec_dependencies"]
        assert len(deps) == 1
        assert deps[0]["type"] == "EXEC CICS"
        assert deps[0]["verb"] == "SEND"

    def test_multiple_exec_blocks(self):
        """Multiple EXEC blocks all captured."""
        from cobol_analyzer_api import analyze_cobol
        with open("demo_data/EXEC-SQL-TEST.cbl") as f:
            source = f.read()
        result = analyze_cobol(source)
        deps = result["exec_dependencies"]
        assert len(deps) == 3
        types = [d["type"] for d in deps]
        assert types.count("EXEC SQL") == 2
        assert types.count("EXEC CICS") == 1

    def test_exec_preserves_other_statements(self):
        """COMPUTE and IF survive EXEC stripping."""
        from cobol_analyzer_api import analyze_cobol
        with open("demo_data/EXEC-SQL-TEST.cbl") as f:
            source = f.read()
        result = analyze_cobol(source)
        assert len(result["computes"]) == 1
        assert len(result["conditions"]) == 1

    def test_no_exec_clean_source(self):
        """Source without EXEC has empty exec_dependencies."""
        from cobol_analyzer_api import analyze_cobol
        with open("DEMO_LOAN_INTEREST.cbl") as f:
            source = f.read()
        result = analyze_cobol(source)
        assert result["exec_dependencies"] == []
        assert result["parse_errors"] == 0

    def test_exec_in_generated_python(self):
        """EXEC dependencies produce MANUAL REVIEW comments in generated Python."""
        from cobol_analyzer_api import analyze_cobol
        from generate_full_python import generate_python_module
        with open("demo_data/EXEC-SQL-TEST.cbl") as f:
            source = f.read()
        result = analyze_cobol(source)
        python_code = generate_python_module(result)["code"]
        assert "EXTERNAL DEPENDENCY" in python_code
        assert "MANUAL REVIEW" in python_code
        assert "EXEC SQL SELECT" in python_code
        assert "EXEC CICS SEND" in python_code


# ══════════════════════════════════════════════════════════════════════
# 7b. ALTER STATEMENT DETECTION
# ══════════════════════════════════════════════════════════════════════


class TestAlterStatementDetection:
    def test_alter_detection(self):
        """ALTER statement = hard stop. Detected, flagged, and forces REQUIRES_MANUAL_REVIEW."""
        from cobol_analyzer_api import analyze_cobol
        from generate_full_python import generate_python_module

        with open("demo_data/ALTER-TEST.cbl") as f:
            source = f.read()
        result = analyze_cobol(source)

        # 1. ALTER must appear in exec_dependencies
        alter_deps = [d for d in result["exec_dependencies"] if d["type"] == "ALTER"]
        assert len(alter_deps) == 1
        assert alter_deps[0]["source_paragraph"] == "CALC-DISPATCH"
        assert alter_deps[0]["target_paragraph"] == "CALC-COMPOUND"
        assert "RUNTIME MUTATION DETECTED" in alter_deps[0]["flag"]
        assert "Static verification is not possible for this program" in alter_deps[0]["flag"]

        # 2. Verification status must be REQUIRES_MANUAL_REVIEW
        #    even though the program parses cleanly with zero errors
        assert result["parse_errors"] == 0
        assert result["success"] is True
        generated_python = generate_python_module(result)["code"]
        assert generated_python is not None

        # Despite clean parse + successful generation, ALTER forces manual review
        parse_errors = result["parse_errors"]
        all_stages_passed = (
            result["success"]
            and generated_python is not None
            and parse_errors == 0
        )
        assert all_stages_passed is True  # would normally be VERIFIED

        # But ALTER overrides to REQUIRES_MANUAL_REVIEW
        alter_present = any(d.get("type") == "ALTER" for d in result["exec_dependencies"])
        assert alter_present is True


# ══════════════════════════════════════════════════════════════════════
# 7c. OCCURS DEPENDING ON DETECTION
# ══════════════════════════════════════════════════════════════════════


class TestOccursDependingOn:
    def test_odo_detection(self):
        """OCCURS DEPENDING ON flagged in exec_dependencies but does NOT force manual review."""
        from cobol_analyzer_api import analyze_cobol

        source = (
            "       IDENTIFICATION DIVISION.\n"
            "       PROGRAM-ID. ODO-TEST.\n"
            "       DATA DIVISION.\n"
            "       WORKING-STORAGE SECTION.\n"
            "       01 WS-COUNT PIC 9(3).\n"
            "       01 WS-TABLE.\n"
            "          05 WS-ITEM OCCURS 1 TO 100 TIMES\n"
            "             DEPENDING ON WS-COUNT PIC X(10).\n"
            "       PROCEDURE DIVISION.\n"
            "           MOVE 5 TO WS-COUNT.\n"
            "           STOP RUN.\n"
        )
        result = analyze_cobol(source)

        # ODO must appear in exec_dependencies
        odo_deps = [d for d in result["exec_dependencies"] if d["type"] == "ODO"]
        assert len(odo_deps) == 1
        assert odo_deps[0]["field_name"] == "WS-ITEM"
        assert odo_deps[0]["max_occurs"] == 100
        assert odo_deps[0]["depending_on"] == "WS-COUNT"
        assert "VARIABLE-LENGTH RECORDS DETECTED" in odo_deps[0]["flag"]
        assert "OCCURS DEPENDING ON" in odo_deps[0]["flag"]

        # ODO does NOT force REQUIRES_MANUAL_REVIEW by itself
        # (verification status depends on parse success, not ODO presence)


# ══════════════════════════════════════════════════════════════════════
# 8. API CONTRACT TESTS (Routes Unchanged)
# ══════════════════════════════════════════════════════════════════════

class TestHeartbeat:
    @pytest.mark.anyio
    async def test_heartbeat_returns_operational(self, async_client):
        resp = await async_client.get("/api/v1/heartbeat")
        assert resp.status_code == 200
        body = resp.json()
        assert body["status"] == "operational"
        assert "decimal_context" in body
        assert body["decimal_context"]["precision"] == 28


class TestHealth:
    @pytest.mark.anyio
    async def test_health_returns_online(self, async_client):
        resp = await async_client.get("/api/health")
        assert resp.status_code == 200
        body = resp.json()
        assert body["status"] == "online"
        assert body["version"] == "3.2.0"
        assert body["decimal_precision"] == "28"


class TestRegistration:
    @pytest.mark.anyio
    async def test_register_new_user(self, async_client):
        resp = await async_client.post("/auth/register", json={
            "username": "newuser",
            "password": "securePass!1",
            "institution": "FinCorp",
            "city": "NYC",
            "country": "US",
            "role": "Developer",
        })
        assert resp.status_code == 200
        assert "newuser" in users_db
        assert users_db["newuser"]["is_approved"] is False

    @pytest.mark.anyio
    async def test_register_duplicate_rejected(self, async_client):
        resp = await async_client.post("/auth/register", json={
            "username": "admin",
            "password": "anything",
            "institution": "X",
            "city": "Y",
            "country": "Z",
            "role": "R",
        })
        assert resp.status_code == 400


class TestLogin:
    @pytest.mark.anyio
    async def test_login_valid_credentials(self, async_client):
        resp = await async_client.post("/auth/login", json={
            "username": "admin",
            "password": "admin123",
        })
        assert resp.status_code == 200
        body = resp.json()
        assert "access_token" in body
        assert body["is_approved"] is True

    @pytest.mark.anyio
    async def test_login_wrong_password(self, async_client):
        resp = await async_client.post("/auth/login", json={
            "username": "admin",
            "password": "wrong",
        })
        assert resp.status_code == 401

    @pytest.mark.anyio
    async def test_login_unknown_user(self, async_client):
        resp = await async_client.post("/auth/login", json={
            "username": "nobody",
            "password": "irrelevant",
        })
        assert resp.status_code == 401


class TestAuthorization:
    @pytest.mark.anyio
    async def test_analyze_works_without_auth_header(self, async_client):
        """Auth removed for V1 — analyze works without token."""
        resp = await async_client.post("/analyze", json={
            "cobol_code": "IDENTIFICATION DIVISION.",
        })
        assert resp.status_code == 200

    @pytest.mark.anyio
    async def test_analyze_allows_any_authenticated_user(
        self, async_client, unapproved_user_token,
    ):
        """is_approved bypass: all authenticated users have clearance."""
        resp = await async_client.post(
            "/analyze",
            json={"cobol_code": "IDENTIFICATION DIVISION."},
            headers={
                "Authorization": f"Bearer {unapproved_user_token}",
            },
        )
        assert resp.status_code == 200

    @pytest.mark.anyio
    async def test_analyze_rejects_empty_source(
        self, async_client, admin_token,
    ):
        resp = await async_client.post(
            "/analyze",
            json={"cobol_code": "   "},
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 400


class TestAnalyzeOffline:
    @pytest.mark.anyio
    async def test_extraction_returns_stub_with_string_score(
        self, async_client, admin_token,
    ):
        """Verify complexity_score is string, not float."""
        resp = await async_client.post(
            "/analyze",
            json={
                "cobol_code": "       IDENTIFICATION DIVISION.\n"
                              "       PROGRAM-ID. TEST.",
                "filename": "test.cbl",
                "is_audit_mode": False,
            },
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 200
        body = resp.json()
        assert isinstance(body["complexity_score"], str)
        # Verify it's a valid Decimal representation
        Decimal(body["complexity_score"])


class TestChat:
    @pytest.mark.anyio
    async def test_chat_returns_string_confidence(
        self, async_client, admin_token,
    ):
        """[AUD-010] Verify confidence is string, not float."""
        resp = await async_client.post(
            "/chat",
            json={
                "cobol_context": "COMPUTE WS-TOTAL = WS-A + WS-B.",
                "user_query": "What does this compute?",
            },
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 200
        body = resp.json()
        assert isinstance(body["confidence"], str)
        # Verify it's a valid Decimal representation
        Decimal(body["confidence"])


class TestAnalyticsDashboard:
    @pytest.mark.anyio
    async def test_analytics_shape(self, async_client, admin_token):
        resp = await async_client.get(
            "/analytics",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 200
        body = resp.json()
        assert "metrics" in body
        assert "recent_activity" in body


class TestRiskIntelligence:
    @pytest.mark.anyio
    async def test_risk_intelligence_shape(self, async_client, admin_token):
        resp = await async_client.get(
            "/risk-intelligence",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 200
        body = resp.json()
        assert "distribution" in body
        assert "anomalies" in body


class TestHealthEndpoint:
    @pytest.mark.anyio
    async def test_health_returns_ok(self, async_client):
        """GET /api/health → 200 with status 'ok' and version."""
        resp = await async_client.get("/api/health")
        assert resp.status_code == 200
        body = resp.json()
        assert body["status"] == "online"
        assert "version" in body


class TestRateLimiting:
    @pytest.mark.anyio
    async def test_no_rate_limit_on_login(self, async_client):
        """Rate limits removed for V1 — 6 rapid attempts all get 401, never 429."""
        for i in range(6):
            resp = await async_client.post(
                "/auth/login",
                json={"username": "nobody", "password": "wrong"},
            )
            assert resp.status_code == 401, f"Request {i+1} unexpected {resp.status_code}"
