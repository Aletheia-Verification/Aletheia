"""Tests for Compiler Option Matrix Report feature."""

import os

os.environ.setdefault("USE_IN_MEMORY_DB", "1")

import pytest
from httpx import AsyncClient, ASGITransport

from core_logic import (
    app, users_db, password_hasher, create_access_token,
    generate_compiler_matrix,
)


# ── Fixtures ──────────────────────────────────────────────────────────

@pytest.fixture(autouse=True)
def reset_users_db():
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
    return create_access_token({"sub": "admin"})


@pytest.fixture
def async_client():
    transport = ASGITransport(app=app)
    return AsyncClient(transport=transport, base_url="http://test")


# ── Test 1: Detects TRUNC from CBL card ──────────────────────────────

class TestCompilerMatrix:

    def test_compiler_matrix_detects_trunc(self):
        """CBL TRUNC(STD) in source → detected, not defaulted."""
        parser_output = {
            "compiler_options_detected": {"trunc_mode": "STD"},
            "variables": [],
            "arithmetics": [],
            "computes": [],
        }
        matrix = generate_compiler_matrix(parser_output)
        assert matrix["detected_options"]["TRUNC"] == "STD"
        assert "TRUNC" not in matrix["defaults_applied"]

    # ── Test 2: All defaults when no CBL card ────────────────────────

    def test_compiler_matrix_defaults(self):
        """No CBL card → all options default to IBM values."""
        parser_output = {
            "compiler_options_detected": {},
            "variables": [],
            "arithmetics": [],
            "computes": [],
        }
        matrix = generate_compiler_matrix(parser_output)
        # All detected_options should be None
        for val in matrix["detected_options"].values():
            assert val is None
        # All 4 defaults applied
        assert "TRUNC" in matrix["defaults_applied"]
        assert "ARITH" in matrix["defaults_applied"]
        assert "NUMPROC" in matrix["defaults_applied"]
        assert "DECIMAL-POINT" in matrix["defaults_applied"]
        assert matrix["defaults_applied"]["TRUNC"] == "STD"
        assert matrix["defaults_applied"]["ARITH"] == "COMPAT"

    # ── Test 3: Constructs map to correct options ────────────────────

    def test_compiler_matrix_constructs(self):
        """COMP-3 signed fields + COMPUTE → correct construct mappings."""
        parser_output = {
            "compiler_options_detected": {},
            "variables": [
                {
                    "name": "WS-AMOUNT",
                    "pic_raw": "S9(5)V99",
                    "pic_info": {"signed": True, "integers": 5, "decimals": 2, "max_value": "99999.99"},
                    "comp3": True,
                    "storage_type": "COMP-3",
                    "occurs": 0,
                    "storage_section": "WORKING",
                    "raw": "05 WS-AMOUNT PIC S9(5)V99 COMP-3.",
                },
                {
                    "name": "WS-RATE",
                    "pic_raw": "9(3)V99",
                    "pic_info": {"signed": False, "integers": 3, "decimals": 2, "max_value": "999.99"},
                    "comp3": True,
                    "storage_type": "COMP-3",
                    "occurs": 0,
                    "storage_section": "WORKING",
                    "raw": "05 WS-RATE PIC 9(3)V99 COMP-3.",
                },
            ],
            "arithmetics": [],
            "computes": [
                {"raw": "COMPUTE WS-AMOUNT = WS-RATE * 100"},
            ],
        }
        matrix = generate_compiler_matrix(parser_output)

        # TRUNC constructs: 2 COMP-3 fields
        trunc_constructs = " ".join(matrix["constructs_requiring_options"]["TRUNC"])
        assert "COMP-3" in trunc_constructs
        assert "2" in trunc_constructs

        # NUMPROC constructs: 1 signed COMP-3 field
        numproc_constructs = " ".join(matrix["constructs_requiring_options"]["NUMPROC"])
        assert "signed COMP-3" in numproc_constructs
        assert "1" in numproc_constructs

        # ARITH constructs: 1 COMPUTE
        arith_constructs = " ".join(matrix["constructs_requiring_options"]["ARITH"])
        assert "COMPUTE" in arith_constructs

        # Warnings should flag TRUNC, ARITH, NUMPROC (none detected)
        assert len(matrix["warnings"]) == 3

    # ── Test 4: Endpoint integration ─────────────────────────────────

    @pytest.mark.anyio
    async def test_compiler_matrix_endpoint(self, async_client, admin_token):
        """POST /engine/compiler-matrix returns matrix with expected keys."""
        cobol_code = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TESTPROG.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-AMOUNT PIC S9(5)V99 COMP-3.
       01 WS-RESULT PIC 9(7)V99.
       PROCEDURE DIVISION.
           COMPUTE WS-RESULT = WS-AMOUNT * 2.
           STOP RUN.
"""
        resp = await async_client.post(
            "/engine/compiler-matrix",
            json={"cobol_code": cobol_code, "filename": "TESTPROG.cbl"},
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert data["filename"] == "TESTPROG.cbl"
        assert "detected_options" in data["matrix"]
        assert "defaults_applied" in data["matrix"]
        assert "constructs_requiring_options" in data["matrix"]
        assert "warnings" in data["matrix"]
        assert isinstance(data["matrix"]["recommendation"], str)
        assert len(data["matrix"]["recommendation"]) > 0
