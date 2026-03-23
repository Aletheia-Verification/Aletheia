"""Tests for /engine/parse-jcl, /engine/generate-sbom endpoints,
and ReverseKey injection in generated Python exec namespace."""

import os

os.environ.setdefault("USE_IN_MEMORY_DB", "1")

import pytest
from decimal import Decimal
from httpx import AsyncClient, ASGITransport

from core_logic import app, users_db, password_hasher, create_access_token


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


# ── Test 1: POST /engine/parse-jcl — happy path ──────────────────────

class TestParseJclEndpoint:
    @pytest.mark.anyio
    async def test_parse_jcl_endpoint(self, async_client, admin_token):
        jcl_text = """\
//MYJOB   JOB (ACCT),'TEST JOB',CLASS=A
//STEP1   EXEC PGM=IEFBR14
//INFILE  DD DSN=MY.INPUT,DISP=SHR
//OUTFILE DD DSN=MY.OUTPUT,DISP=(NEW,CATLG,DELETE)
"""
        resp = await async_client.post(
            "/engine/parse-jcl",
            json={"jcl_text": jcl_text},
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["job_name"] == "MYJOB"
        assert len(data["steps"]) == 1
        assert data["steps"][0]["name"] == "STEP1"
        assert data["steps"][0]["program"] == "IEFBR14"
        assert "summary" in data


# ── Test 2: POST /engine/parse-jcl — bad input ───────────────────────

class TestParseJclBadInput:
    @pytest.mark.anyio
    async def test_parse_jcl_endpoint_bad_input(self, async_client, admin_token):
        resp = await async_client.post(
            "/engine/parse-jcl",
            json={"jcl_text": ""},
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 400


# ── Test 3: POST /engine/generate-sbom — happy path ──────────────────

class TestGenerateSbomEndpoint:
    @pytest.mark.anyio
    async def test_generate_sbom_endpoint(self, async_client, admin_token):
        analysis = {
            "program_name": "LOAN-CALC",
            "copybooks": ["COPY-A"],
            "calls": [],
            "exec_dependencies": [],
            "dead_code": {
                "unreachable_paragraphs": [],
                "total_paragraphs": 5,
                "dead_percentage": 0.0,
            },
        }
        resp = await async_client.post(
            "/engine/generate-sbom",
            json=analysis,
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["bomFormat"] == "CycloneDX"
        assert data["specVersion"] == "1.4"
        assert len(data["components"]) == 1
        assert data["components"][0]["name"] == "COPY-A"


# ── Test 4: POST /engine/generate-sbom — bad input ───────────────────

class TestGenerateSbomBadInput:
    @pytest.mark.anyio
    async def test_generate_sbom_endpoint_bad_input(self, async_client, admin_token):
        resp = await async_client.post(
            "/engine/generate-sbom",
            json={},
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 400


# ── Test 5: ReverseKey in exec namespace ──────────────────────────────

class TestReverseKeyInExecNamespace:
    def test_reverse_key_in_exec_namespace(self):
        """Generate Python for SORT DESCENDING, exec it, assert no NameError."""
        from cobol_analyzer_api import analyze_cobol
        from generate_full_python import generate_python_module
        from cobol_file_io import CobolFileManager, StreamBackend, ReverseKey

        cobol = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SORT-DESC.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT INPUT-FILE ASSIGN TO 'INPUT.DAT'.
           SELECT OUTPUT-FILE ASSIGN TO 'OUTPUT.DAT'.
           SELECT SORT-WORK ASSIGN TO 'SORT.TMP'.
       DATA DIVISION.
       FILE SECTION.
       FD INPUT-FILE.
       01 INPUT-RECORD.
           05 IN-KEY           PIC 9(5).
           05 IN-NAME          PIC X(10).
       FD OUTPUT-FILE.
       01 OUTPUT-RECORD.
           05 OUT-KEY          PIC 9(5).
           05 OUT-NAME         PIC X(10).
       SD SORT-WORK.
       01 SORT-RECORD.
           05 SORT-KEY         PIC 9(5).
           05 SORT-NAME        PIC X(10).
       WORKING-STORAGE SECTION.
       01 WS-EOF              PIC 9 VALUE 0.
       PROCEDURE DIVISION.
       MAIN-PARA.
           SORT SORT-WORK
               ON DESCENDING KEY SORT-KEY
               USING INPUT-FILE
               GIVING OUTPUT-FILE.
           STOP RUN.
"""
        analysis = analyze_cobol(cobol)
        gen = generate_python_module(analysis)
        code = gen["code"]

        # Verify ReverseKey is imported in the generated code
        assert "ReverseKey" in code

        # Execute without NameError
        output_collector = []
        backend = StreamBackend(
            input_streams={"INPUT-FILE": iter([
                {"SORT-KEY": Decimal("10"), "SORT-NAME": "ALICE"},
                {"SORT-KEY": Decimal("30"), "SORT-NAME": "CHARLIE"},
                {"SORT-KEY": Decimal("20"), "SORT-NAME": "BOB"},
            ])},
            output_collectors={"OUTPUT-FILE": output_collector},
        )

        ns = {}
        exec(code, ns)

        file_meta = ns.get("_FILE_META", {})
        mgr = CobolFileManager(file_meta, ns, backend)

        ns["_io_open"] = mgr.open
        ns["_io_read"] = mgr.read
        ns["_io_write"] = mgr.write
        ns["_io_write_record"] = mgr.write_record
        ns["_io_close"] = mgr.close
        ns["_io_populate"] = mgr.populate
        ns["ReverseKey"] = ReverseKey

        # Must not raise NameError
        ns["main"]()

        keys = [r["SORT-KEY"] for r in output_collector]
        assert keys == [Decimal("30"), Decimal("20"), Decimal("10")]
