"""Tests for Portfolio Risk Heatmap feature."""

import os

os.environ.setdefault("USE_IN_MEMORY_DB", "1")

import pytest
from httpx import AsyncClient, ASGITransport

from core_logic import app, users_db, password_hasher, create_access_token
from risk_heatmap import generate_risk_heatmap


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


# ── Helper: minimal analysis dict ────────────────────────────────────

def _make_analysis(
    exec_deps=None,
    summary_overrides=None,
    variables=None,
    copybook_issues=None,
):
    """Build a minimal analysis dict for unit testing."""
    summary = {
        "paragraphs": 2,
        "variables": 5,
        "comp3_variables": 0,
        "perform_calls": 2,
        "compute_statements": 1,
        "move_statements": 3,
        "goto_statements": 0,
        "stop_statements": 1,
        "business_rules": 1,
        "evaluate_statements": 0,
        "arithmetic_statements": 0,
        "perform_until_statements": 0,
        "string_statements": 0,
        "unstring_statements": 0,
        "inspect_statements": 0,
        "initialize_statements": 0,
        "display_statements": 0,
        "set_statements": 0,
        "cycles": 0,
        "unreachable": 0,
    }
    if summary_overrides:
        summary.update(summary_overrides)

    return {
        "success": True,
        "parse_errors": 0,
        "summary": summary,
        "variables": variables or [],
        "exec_dependencies": exec_deps or [],
        "copybook_issues": copybook_issues or [],
        "redefines": {},
        "compiler_options_detected": {},
        "gotos": [],
        "computes": [],
        "arithmetics": [],
        "file_operations": [],
        "sort_statements": [],
    }


# ── Test 1: Green program ────────────────────────────────────────────

class TestRiskHeatmap:

    def test_heatmap_green_program(self):
        """Clean program with no risk triggers → green, VERIFIED."""
        programs = [
            {"filename": "CLEAN-PROG.cbl", "lines": 100, "analysis": _make_analysis()},
        ]
        result = generate_risk_heatmap(programs)
        prog = result["programs"][0]

        assert prog["status"] == "green"
        assert prog["predicted_outcome"] == "VERIFIED"
        assert prog["risk_factors"] == []
        assert prog["name"] == "CLEAN-PROG"

    # ── Test 2: Red program (ALTER) ──────────────────────────────────

    def test_heatmap_red_program(self):
        """Program with ALTER → red, MANUAL_REVIEW."""
        analysis = _make_analysis(exec_deps=[
            {"type": "ALTER", "source_paragraph": "P1", "target_paragraph": "P2",
             "body_preview": "ALTER P1 TO PROCEED TO P2",
             "flag": "RUNTIME MUTATION DETECTED", "line": 50, "paragraph": "MAIN"},
        ])
        programs = [
            {"filename": "ALTER-PROG.cbl", "lines": 80, "analysis": analysis},
        ]
        result = generate_risk_heatmap(programs)
        prog = result["programs"][0]

        assert prog["status"] == "red"
        assert prog["predicted_outcome"] == "MANUAL_REVIEW"
        assert any("ALTER" in f for f in prog["risk_factors"])

    # ── Test 3: Complexity score ordering ────────────────────────────

    def test_heatmap_complexity_score(self):
        """Complex program scores higher than simple one."""
        simple_analysis = _make_analysis()
        complex_analysis = _make_analysis(
            summary_overrides={
                "comp3_variables": 10,
                "goto_statements": 5,
                "compute_statements": 8,
                "evaluate_statements": 4,
                "arithmetic_statements": 6,
                "string_statements": 3,
                "inspect_statements": 2,
                "perform_calls": 12,
            },
        )
        programs = [
            {"filename": "SIMPLE.cbl", "lines": 50, "analysis": simple_analysis},
            {"filename": "COMPLEX.cbl", "lines": 500, "analysis": complex_analysis},
        ]
        result = generate_risk_heatmap(programs)
        simple = result["programs"][0]
        complex_prog = result["programs"][1]

        assert complex_prog["complexity_score"] > simple["complexity_score"]

    # ── Test 4: Summary counts ───────────────────────────────────────

    def test_heatmap_summary(self):
        """3 programs (green, yellow, red) → correct summary counts."""
        green_analysis = _make_analysis()
        yellow_analysis = _make_analysis(exec_deps=[
            {"type": "ODO", "field_name": "WS-TBL", "max_occurs": 100,
             "depending_on": "WS-COUNT", "body_preview": "OCCURS 100 DEPENDING ON",
             "flag": "VARIABLE-LENGTH RECORDS"},
        ])
        red_analysis = _make_analysis(exec_deps=[
            {"type": "ALTER", "source_paragraph": "P1", "target_paragraph": "P2",
             "body_preview": "ALTER P1", "flag": "RUNTIME MUTATION", "line": 10,
             "paragraph": "MAIN"},
        ])

        programs = [
            {"filename": "GREEN.cbl", "lines": 100, "analysis": green_analysis},
            {"filename": "YELLOW.cbl", "lines": 100, "analysis": yellow_analysis},
            {"filename": "RED.cbl", "lines": 100, "analysis": red_analysis},
        ]
        result = generate_risk_heatmap(programs)
        s = result["summary"]

        assert s["total"] == 3
        assert s["green"] == 1
        assert s["yellow"] == 1
        assert s["red"] == 1
        assert isinstance(s["predicted_pvr"], str)
        assert len(s["predicted_pvr"]) > 0

    # ── Test 5: Endpoint integration ─────────────────────────────────

    @pytest.mark.anyio
    async def test_heatmap_endpoint(self, async_client, admin_token):
        """POST /engine/risk-heatmap with 2 programs → valid response."""
        cobol_green = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. GREENPROG.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-RESULT PIC 9(5).
       PROCEDURE DIVISION.
           MOVE 100 TO WS-RESULT.
           STOP RUN.
"""
        cobol_red = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. REDPROG.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-X PIC 9(5).
       PROCEDURE DIVISION.
       MAIN-PARA.
           ALTER MAIN-PARA TO PROCEED TO OTHER-PARA.
           STOP RUN.
       OTHER-PARA.
           MOVE 1 TO WS-X.
"""
        resp = await async_client.post(
            "/engine/risk-heatmap",
            json={
                "programs": [
                    {"cobol_code": cobol_green, "filename": "GREENPROG.cbl"},
                    {"cobol_code": cobol_red, "filename": "REDPROG.cbl"},
                ]
            },
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        assert "heatmap" in data
        assert "programs" in data["heatmap"]
        assert "summary" in data["heatmap"]
        assert len(data["heatmap"]["programs"]) == 2
        assert data["heatmap"]["summary"]["total"] == 2
