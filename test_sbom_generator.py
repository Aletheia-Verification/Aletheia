"""Tests for sbom_generator.py — CycloneDX 1.4 SBOM generation from COBOL analysis."""

import hashlib
import json
from datetime import datetime, timezone

import pytest

from sbom_generator import generate_sbom, validate_sbom


FIXED_TS = datetime(2026, 3, 14, 12, 0, 0, tzinfo=timezone.utc)


def _base_input(**overrides):
    """Build a minimal analysis_result dict with optional overrides."""
    result = {
        "program_name": "LOAN-CALC",
        "copybooks": [],
        "calls": [],
        "exec_dependencies": [],
        "dead_code": {
            "unreachable_paragraphs": [],
            "total_paragraphs": 10,
            "reachable_paragraphs": 10,
            "dead_percentage": 0.0,
            "has_alter": False,
        },
    }
    result.update(overrides)
    return result


# ── Test 1: Program with no COPYBOOKs ────────────────────────────

class TestNoCopybooks:
    def test_no_copybooks(self):
        sbom = generate_sbom(_base_input(), timestamp=FIXED_TS)

        assert sbom["bomFormat"] == "CycloneDX"
        assert sbom["specVersion"] == "1.4"
        assert sbom["components"] == []
        assert len(sbom["dependencies"]) == 1
        assert sbom["dependencies"][0]["dependsOn"] == []
        assert sbom["metadata"]["component"]["name"] == "LOAN-CALC"


# ── Test 2: Program with 3 COPYBOOKs ─────────────────────────────

class TestThreeCopybooks:
    def test_three_copybooks(self):
        inp = _base_input(copybooks=["COPY-RATES", "COPY-FIELDS", "COPY-DATES"])
        sbom = generate_sbom(inp, timestamp=FIXED_TS)

        assert len(sbom["components"]) == 3
        for comp in sbom["components"]:
            assert comp["type"] == "library"
            assert comp["group"] == "copybook"
            assert comp["purl"].startswith("pkg:cobol-copybook/")
            assert "bom-ref" in comp

        names = {c["name"] for c in sbom["components"]}
        assert names == {"COPY-RATES", "COPY-FIELDS", "COPY-DATES"}

        dep_refs = sbom["dependencies"][0]["dependsOn"]
        assert len(dep_refs) == 3


# ── Test 3: Program with CALL dependencies ────────────────────────

class TestCallDependencies:
    def test_call_dependencies(self):
        inp = _base_input(calls=[
            {"target": "SUB-CALC", "type": "static", "parameters": [], "line": 100},
            {"target": "SUB-PRINT", "type": "static", "parameters": [], "line": 200},
        ])
        sbom = generate_sbom(inp, timestamp=FIXED_TS)

        subprogram_comps = [c for c in sbom["components"] if c["group"] == "subprogram"]
        assert len(subprogram_comps) == 2
        names = {c["name"] for c in subprogram_comps}
        assert names == {"SUB-CALC", "SUB-PRINT"}
        for comp in subprogram_comps:
            assert comp["purl"].startswith("pkg:cobol-subprogram/")

    def test_dynamic_calls_flagged(self):
        """FIX 3: dynamic CALLs must leave a trace in properties."""
        inp = _base_input(calls=[
            {"target": "WS-PROG-NAME", "type": "dynamic", "parameters": [], "line": 50},
            {"target": "SUB-CALC", "type": "static", "parameters": [], "line": 100},
        ])
        sbom = generate_sbom(inp, timestamp=FIXED_TS)

        main_comp = sbom["metadata"]["component"]
        props = {p["name"]: p["value"] for p in main_comp.get("properties", [])}
        assert props["aletheia:dynamic_calls"] == "true"
        assert "incomplete" in props["aletheia:dynamic_calls_note"]


# ── Test 4: Dead code properly flagged in properties ──────────────

class TestDeadCodeProperties:
    def test_dead_code_properties(self):
        inp = _base_input(dead_code={
            "unreachable_paragraphs": [
                {"name": "DEAD-PARA-1", "line": 500},
                {"name": "DEAD-PARA-2", "line": 600},
            ],
            "total_paragraphs": 10,
            "reachable_paragraphs": 8,
            "dead_percentage": 20.0,
            "has_alter": False,
        })
        sbom = generate_sbom(inp, timestamp=FIXED_TS)

        main_comp = sbom["metadata"]["component"]
        props = {p["name"]: p["value"] for p in main_comp.get("properties", [])}

        assert props["aletheia:dead_code"] == "true"
        assert props["aletheia:dead_percentage"] == "20.0"
        assert "DEAD-PARA-1" in props["aletheia:dead_paragraphs"]
        assert "DEAD-PARA-2" in props["aletheia:dead_paragraphs"]


# ── Test 5: Output passes schema validation ───────────────────────

class TestSchemaValidation:
    def test_full_sbom_validates(self):
        inp = _base_input(
            copybooks=["COPY-A", "COPY-B"],
            calls=[{"target": "SUB-X", "type": "static", "parameters": [], "line": 10}],
            exec_dependencies=[{
                "type": "EXEC SQL",
                "verb": "SELECT",
                "body_preview": "SELECT ACCT_NO FROM ACCOUNTS WHERE STATUS = :WS-STATUS",
                "flag": "EXTERNAL DEPENDENCY",
            }],
            dead_code={
                "unreachable_paragraphs": [{"name": "OLD-PARA", "line": 999}],
                "total_paragraphs": 5,
                "reachable_paragraphs": 4,
                "dead_percentage": 20.0,
                "has_alter": False,
            },
        )
        sbom = generate_sbom(inp, timestamp=FIXED_TS)
        assert validate_sbom(sbom) is True

    def test_invalid_bom_format_rejected(self):
        """FIX 4: bomFormat value must be 'CycloneDX', not just present."""
        sbom = generate_sbom(_base_input(), timestamp=FIXED_TS)
        sbom["bomFormat"] = "SPDX"
        assert validate_sbom(sbom) is False

    def test_missing_key_rejected(self):
        sbom = generate_sbom(_base_input(), timestamp=FIXED_TS)
        del sbom["specVersion"]
        assert validate_sbom(sbom) is False


# ── Test 6: Deterministic output ──────────────────────────────────

class TestDeterministicOutput:
    def test_deterministic_hash(self):
        inp = _base_input(
            copybooks=["COPY-X", "COPY-Y"],
            calls=[{"target": "SUB-Z", "type": "static", "parameters": [], "line": 1}],
        )

        sbom1 = generate_sbom(inp, timestamp=FIXED_TS)
        sbom2 = generate_sbom(inp, timestamp=FIXED_TS)

        json1 = json.dumps(sbom1, sort_keys=True)
        json2 = json.dumps(sbom2, sort_keys=True)

        hash1 = hashlib.sha256(json1.encode()).hexdigest()
        hash2 = hashlib.sha256(json2.encode()).hexdigest()

        assert hash1 == hash2

    def test_different_content_different_serial(self):
        """FIX 1: different components must produce different serialNumbers."""
        sbom_a = generate_sbom(
            _base_input(copybooks=["COPY-A"]),
            timestamp=FIXED_TS,
        )
        sbom_b = generate_sbom(
            _base_input(copybooks=["COPY-B"]),
            timestamp=FIXED_TS,
        )
        assert sbom_a["serialNumber"] != sbom_b["serialNumber"]

    def test_serial_number_includes_dead_code(self):
        """Dead paragraphs change the serialNumber."""
        sbom_with = generate_sbom(
            _base_input(dead_code={
                "unreachable_paragraphs": [
                    {"name": "PARA-A", "line": 10},
                    {"name": "PARA-B", "line": 20},
                ],
                "total_paragraphs": 4, "reachable_paragraphs": 2,
                "dead_percentage": 50.0, "has_alter": False,
            }),
            timestamp=FIXED_TS,
        )
        sbom_without = generate_sbom(
            _base_input(),  # dead_code has empty unreachable_paragraphs
            timestamp=FIXED_TS,
        )
        assert sbom_with["serialNumber"] != sbom_without["serialNumber"]

    def test_serial_number_deterministic_with_dead_code(self):
        """Identical inputs including dead_paragraphs produce identical serialNumbers."""
        dc = {
            "unreachable_paragraphs": [
                {"name": "PARA-A", "line": 10},
                {"name": "PARA-B", "line": 20},
            ],
            "total_paragraphs": 4, "reachable_paragraphs": 2,
            "dead_percentage": 50.0, "has_alter": False,
        }
        sbom1 = generate_sbom(_base_input(dead_code=dc), timestamp=FIXED_TS)
        sbom2 = generate_sbom(_base_input(dead_code=dc), timestamp=FIXED_TS)
        assert sbom1["serialNumber"] == sbom2["serialNumber"]

    def test_serial_number_seed_ordering(self):
        """Dead paragraph order doesn't matter — sorted internally."""
        dc_ab = {
            "unreachable_paragraphs": [
                {"name": "PARA-A", "line": 10},
                {"name": "PARA-B", "line": 20},
            ],
            "total_paragraphs": 4, "reachable_paragraphs": 2,
            "dead_percentage": 50.0, "has_alter": False,
        }
        dc_ba = {
            "unreachable_paragraphs": [
                {"name": "PARA-B", "line": 20},
                {"name": "PARA-A", "line": 10},
            ],
            "total_paragraphs": 4, "reachable_paragraphs": 2,
            "dead_percentage": 50.0, "has_alter": False,
        }
        sbom1 = generate_sbom(_base_input(dead_code=dc_ab), timestamp=FIXED_TS)
        sbom2 = generate_sbom(_base_input(dead_code=dc_ba), timestamp=FIXED_TS)
        assert sbom1["serialNumber"] == sbom2["serialNumber"]


# ── Test 7: DB2 extraction property ─────────────────────────────

class TestDb2ExtractionProperty:
    def test_db2_property_present_when_exec_deps(self):
        """exec_dependencies non-empty → aletheia:db2_extraction property added."""
        inp = _base_input(exec_dependencies=[{
            "type": "EXEC SQL",
            "verb": "SELECT",
            "body_preview": "SELECT * FROM ACCOUNTS",
            "flag": "EXTERNAL DEPENDENCY",
        }])
        sbom = generate_sbom(inp, timestamp=FIXED_TS)

        main_comp = sbom["metadata"]["component"]
        props = {p["name"]: p["value"] for p in main_comp.get("properties", [])}
        assert props["aletheia:db2_extraction"] == "partial_preview_only"

    def test_db2_property_absent_when_no_exec_deps(self):
        """exec_dependencies empty → no aletheia:db2_extraction property."""
        sbom = generate_sbom(_base_input(), timestamp=FIXED_TS)

        main_comp = sbom["metadata"]["component"]
        prop_names = [p["name"] for p in main_comp.get("properties", [])]
        assert "aletheia:db2_extraction" not in prop_names
