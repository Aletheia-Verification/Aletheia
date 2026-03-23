"""
test_verify_full.py -- Tests for POST /engine/verify-full endpoint + layout generation.

Combined Engine + Shadow Diff in one call (8 endpoint tests).
Layout auto-generation from layout_generator.py (7 unit tests).
"""

import base64
import json
import os

os.environ["USE_IN_MEMORY_DB"] = "true"


import pytest
from fastapi.testclient import TestClient
from core_logic import app, create_access_token

from copybook_resolver import resolve_redefines, _pic_byte_length
from layout_generator import generate_layout
from cobol_analyzer_api import parse_pic_clause


# Override license check for tests
try:
    from license_manager import require_valid_license
except ImportError:
    from core_logic import require_valid_license

app.dependency_overrides[require_valid_license] = lambda: None

TOKEN = create_access_token({"sub": "admin"})
AUTH = {"Authorization": f"Bearer {TOKEN}"}


def _load_demo():
    with open("DEMO_LOAN_INTEREST.cbl", "r") as f:
        cobol_code = f.read()
    with open("demo_data/loan_layout.json", "r") as f:
        layout = json.load(f)
    with open("demo_data/loan_input.dat", "rb") as f:
        input_b64 = base64.b64encode(f.read()).decode()
    with open("demo_data/loan_mainframe_output.dat", "rb") as f:
        output_b64 = base64.b64encode(f.read()).decode()
    return cobol_code, layout, input_b64, output_b64


def _drift_output_b64():
    with open("demo_data/loan_mainframe_output_WITH_DRIFT.dat", "rb") as f:
        return base64.b64encode(f.read()).decode()


class TestVerifyFull:
    """All verify-full tests in a single class to share one TestClient lifecycle."""

    @classmethod
    def setup_class(cls):
        cls.client = TestClient(app)

    @classmethod
    def teardown_class(cls):
        cls.client.close()

    def _post(self, cobol_code, layout, input_b64, output_b64, **overrides):
        body = {
            "cobol_code": cobol_code,
            "layout": layout,
            "input_data": input_b64,
            "output_data": output_b64,
        }
        body.update(overrides)
        return self.client.post("/engine/verify-full", json=body, headers=AUTH)

    # ── Happy path ───────────────────────────────────────────────────

    def test_zero_drift_fully_verified(self):
        cobol, layout, inp, out = _load_demo()
        resp = self._post(cobol, layout, inp, out)
        assert resp.status_code == 200, resp.text
        body = resp.json()
        assert body["unified_verdict"] == "FULLY VERIFIED"
        eng = body["engine_result"]
        assert eng["verification_status"] == "VERIFIED"
        assert eng["generated_python"] is not None
        sd = body["shadow_diff_result"]
        assert sd is not None
        assert sd["mismatches"] == 0
        assert sd["total_records"] > 0
        assert "ZERO DRIFT" in sd["verdict"]

    def test_drift_detected(self):
        cobol, layout, inp, _ = _load_demo()
        drift = _drift_output_b64()
        resp = self._post(cobol, layout, inp, drift)
        assert resp.status_code == 200
        body = resp.json()
        assert body["unified_verdict"] != "FULLY VERIFIED"
        sd = body["shadow_diff_result"]
        assert sd["mismatches"] > 0
        assert "DRIFT DETECTED" in sd["verdict"]
        assert len(sd.get("drift_diagnoses", [])) > 0

    # ── Edge cases ───────────────────────────────────────────────────

    def test_bad_cobol_skips_shadow_diff(self):
        _, layout, inp, out = _load_demo()
        resp = self._post("THIS IS NOT VALID COBOL", layout, inp, out)
        assert resp.status_code == 200
        body = resp.json()
        assert body["engine_result"]["generated_python"] is None
        assert body["shadow_diff_result"] is None

    # ── Validation ───────────────────────────────────────────────────

    def test_empty_cobol_returns_400(self):
        _, layout, inp, out = _load_demo()
        resp = self._post("   ", layout, inp, out)
        assert resp.status_code == 400

    def test_bad_base64_returns_400(self):
        cobol, layout, _, _ = _load_demo()
        resp = self._post(cobol, layout, "NOT-BASE64!!!", "ALSO-BAD!!!")
        assert resp.status_code == 400
        assert "base64" in resp.json()["detail"].lower()

    def test_missing_input_mapping_returns_400(self):
        cobol, layout, inp, out = _load_demo()
        bad_layout = dict(layout)
        del bad_layout["input_mapping"]
        resp = self._post(cobol, bad_layout, inp, out)
        assert resp.status_code == 400

    def test_no_auth_returns_401(self):
        cobol, layout, inp, out = _load_demo()
        resp = self.client.post("/engine/verify-full", json={
            "cobol_code": cobol, "layout": layout,
            "input_data": inp, "output_data": out,
        })
        assert resp.status_code in (401, 403)

    # ── Response shape ───────────────────────────────────────────────

    def test_response_has_all_keys(self):
        cobol, layout, inp, out = _load_demo()
        resp = self._post(cobol, layout, inp, out)
        body = resp.json()
        assert "unified_verdict" in body
        assert "engine_result" in body
        assert "shadow_diff_result" in body
        eng = body["engine_result"]
        for key in ("parser_output", "generated_python", "verification",
                     "formatted_output", "arithmetic_risks", "arithmetic_summary",
                     "emit_counts", "vault_id"):
            assert key in eng, f"Missing engine_result.{key}"
        sd = body["shadow_diff_result"]
        for key in ("verdict", "total_records", "matches", "mismatches",
                     "mismatch_details", "drift_diagnoses",
                     "input_fingerprint", "output_fingerprint"):
            assert key in sd, f"Missing shadow_diff_result.{key}"

    # ── Auto-generate layout (no layout in request) ──────────────────

    def test_auto_layout_generates_without_error(self):
        """Omit layout from request — backend auto-generates layout and runs shadow diff."""
        cobol, _, inp, out = _load_demo()
        resp = self._post(cobol, None, inp, out)
        assert resp.status_code == 200, resp.text
        body = resp.json()
        # Auto-layout runs: shadow_diff_result is present (not None)
        assert body["shadow_diff_result"] is not None
        assert body["shadow_diff_result"]["total_records"] > 0


# ══════════════════════════════════════════════════════════════════════
# LAYOUT GENERATOR UNIT TESTS
# ══════════════════════════════════════════════════════════════════════


def _make_var(level, name, pic_raw, storage_type="DISPLAY", comp3=False, value=None):
    """Build a variable dict matching cobol_analyzer_api format."""
    raw = f"{level:02d} {name}"
    if pic_raw:
        raw += f" PIC {pic_raw}"
    if storage_type == "COMP-3":
        raw += " COMP-3"
        comp3 = True
    elif storage_type == "COMP":
        raw += " COMP"
    if value is not None:
        raw += f" VALUE {value}"
    raw += "."
    pic_info = parse_pic_clause(pic_raw) if pic_raw else None
    return {
        "raw": raw,
        "name": name,
        "pic_raw": pic_raw,
        "pic_info": pic_info,
        "comp3": comp3,
        "storage_type": storage_type,
    }


def _build_analysis(variables):
    """Build minimal analysis dict for generate_layout."""
    return {
        "variables": variables,
        "redefines": resolve_redefines(variables),
    }


class TestLayoutBasicOffsets:
    """PIC X(10) at 0, PIC 9(5)V99 at 10 → offsets accumulate exactly."""

    def test_offsets_accumulate(self):
        variables = [
            _make_var(1, "WS-RECORD", "", storage_type="DISPLAY"),
            _make_var(5, "WS-NAME", "X(10)"),
            _make_var(5, "WS-AMOUNT", "9(5)V99"),
        ]
        gen_python = "ws_amount.store(ws_name.value)\n"
        analysis = _build_analysis(variables)
        layout = generate_layout(analysis, gen_python, "TEST")

        fields = layout["fields"]
        name_field = next((f for f in fields if "NAME" in f["name"].upper()), None)
        assert name_field is not None, f"Expected NAME field, got {[f['name'] for f in fields]}"
        assert name_field["start"] == 0
        assert name_field["length"] == 10
        assert name_field["type"] == "string"


class TestLayoutComp3Length:
    """COMP-3 byte length uses integer arithmetic."""

    def test_comp3_s9_9_v99(self):
        """PIC S9(9)V99 COMP-3 → (9+2+1)//2 = 6 bytes."""
        assert _pic_byte_length("S9(9)V99", is_comp3=True, is_comp=False) == 6

    def test_comp3_s9_5(self):
        """PIC S9(5) COMP-3 → (5+1)//2 = 3 bytes."""
        assert _pic_byte_length("S9(5)", is_comp3=True, is_comp=False) == 3


class TestLayoutCompBinary:
    """COMP binary: S9(4)→2 bytes (halfword), S9(9)→4 bytes (fullword)."""

    def test_comp_halfword(self):
        assert _pic_byte_length("S9(4)", is_comp3=False, is_comp=True) == 2

    def test_comp_fullword(self):
        assert _pic_byte_length("S9(9)", is_comp3=False, is_comp=True) == 4


class TestLayoutFillerOffset:
    """FILLER PIC X(5) advances offset by 5 but is NOT in layout fields."""

    def test_filler_excluded_but_advances(self):
        variables = [
            _make_var(1, "WS-REC", "", storage_type="DISPLAY"),
            _make_var(5, "WS-ID", "X(3)"),
            _make_var(5, "FILLER", "X(5)"),
            _make_var(5, "WS-VAL", "9(4)"),
        ]
        gen_python = "ws_val.store(ws_id.value)\n"
        analysis = _build_analysis(variables)
        layout = generate_layout(analysis, gen_python, "TEST")

        fields = layout["fields"]
        field_names = [f["name"] for f in fields]
        assert not any("FILLER" in n.upper() for n in field_names), \
            f"FILLER should not be in layout fields: {field_names}"

        id_field = next((f for f in fields if "ID" in f["name"].upper()), None)
        assert id_field is not None
        assert id_field["start"] == 0
        assert id_field["length"] == 3


class TestLayoutRedefinesNoAdvance:
    """REDEFINES field uses base offset, does NOT advance cumulative offset."""

    def test_redefines_no_advance(self):
        variables = [
            _make_var(1, "WS-REC", "", storage_type="DISPLAY"),
            _make_var(5, "WS-DATE-NUM", "9(8)"),
            {
                "raw": "05 WS-DATE-STR REDEFINES WS-DATE-NUM PIC X(8).",
                "name": "WS-DATE-STR",
                "pic_raw": "X(8)",
                "pic_info": {"integers": 0, "decimals": 0, "signed": False},
                "comp3": False,
                "storage_type": "DISPLAY",
            },
            _make_var(5, "WS-AMOUNT", "9(5)V99"),
        ]
        redefines = resolve_redefines(variables)
        mm = redefines["memory_map"]

        date_num = next(e for e in mm if e["name"] == "WS-DATE-NUM")
        date_str = next(e for e in mm if e["name"] == "WS-DATE-STR")
        amount = next(e for e in mm if e["name"] == "WS-AMOUNT")

        assert date_str["offset"] == date_num["offset"], \
            f"REDEFINES should share base offset: {date_str['offset']} != {date_num['offset']}"
        assert amount["offset"] == date_num["offset"] + date_num["length"], \
            f"REDEFINES should not advance offset: amount at {amount['offset']}"


class TestLayoutFDClassification:
    """FD path: INPUT file → input_fields, OUTPUT file → output_layout."""

    def test_fd_input_output_classification(self):
        variables = [
            _make_var(1, "INPUT-REC", "", storage_type="DISPLAY"),
            _make_var(5, "IN-ID", "X(5)"),
            _make_var(5, "IN-AMT", "9(7)V99"),
            _make_var(1, "OUTPUT-REC", "", storage_type="DISPLAY"),
            _make_var(5, "OUT-RESULT", "9(9)V99"),
            _make_var(1, "WS-WORK", "", storage_type="DISPLAY"),
            _make_var(5, "WS-TEMP", "9(5)"),
        ]

        analysis = _build_analysis(variables)
        analysis["file_descriptions"] = [
            {"name": "INPUT-FILE", "record": "INPUT-REC"},
            {"name": "OUTPUT-FILE", "record": "OUTPUT-REC"},
        ]
        analysis["file_operations"] = [
            {"file_name": "INPUT-FILE", "direction": "INPUT"},
            {"file_name": "OUTPUT-FILE", "direction": "OUTPUT"},
        ]

        gen_python = "out_result.store(in_amt.value + ws_temp.value)\n"
        layout = generate_layout(analysis, gen_python, "FD-TEST")

        assert layout["name"] == "FD-TEST"
        assert len(layout["fields"]) > 0 or len(layout["input_mapping"]) > 0
        assert len(layout["output_layout"]["fields"]) > 0 or len(layout["output_fields"]) > 0


class TestLayoutDemoLoanIntegration:
    """generate_layout() on DEMO_LOAN_INTEREST.cbl matches demo_data/loan_layout.json."""

    def test_demo_data_layout_matches(self):
        project_root = os.path.dirname(os.path.abspath(__file__))
        cbl_path = os.path.join(project_root, "DEMO_LOAN_INTEREST.cbl")
        layout_path = os.path.join(project_root, "demo_data", "loan_layout.json")

        if not os.path.exists(cbl_path):
            pytest.skip("DEMO_LOAN_INTEREST.cbl not found")
        if not os.path.exists(layout_path):
            pytest.skip("demo_data/loan_layout.json not found")

        with open(cbl_path, "r") as f:
            cobol_code = f.read()
        with open(layout_path, "r") as f:
            expected_layout = json.load(f)

        from cobol_analyzer_api import analyze_cobol
        parser_output = analyze_cobol(cobol_code)
        assert parser_output.get("success"), "ANTLR parse failed"

        from generate_full_python import generate_python_module
        gen_result = generate_python_module(parser_output)
        generated_python = gen_result["code"]

        layout = generate_layout(dict(parser_output), generated_python, "DEMO_LOAN_INTEREST")

        # Input fields: names, offsets, lengths
        assert len(layout["fields"]) == len(expected_layout["fields"]), \
            f"Input field count: {len(layout['fields'])} != {len(expected_layout['fields'])}"
        for auto_f, exp_f in zip(layout["fields"], expected_layout["fields"]):
            assert auto_f["name"] == exp_f["name"], \
                f"Field name: {auto_f['name']} != {exp_f['name']}"
            assert auto_f["start"] == exp_f["start"], \
                f"{auto_f['name']} start: {auto_f['start']} != {exp_f['start']}"
            assert auto_f["length"] == exp_f["length"], \
                f"{auto_f['name']} length: {auto_f['length']} != {exp_f['length']}"

        # Input mapping
        assert layout["input_mapping"] == expected_layout["input_mapping"]

        # Output fields: auto-generated may include intermediates, so check superset
        for exp_f in expected_layout["output_fields"]:
            assert exp_f in layout["output_fields"], \
                f"Expected output field {exp_f} missing from auto-generated: {layout['output_fields']}"

        # Output layout: every expected field present with correct length
        auto_out = {f["name"]: f for f in layout["output_layout"]["fields"]}
        for exp_f in expected_layout["output_layout"]["fields"]:
            assert exp_f["name"] in auto_out, \
                f"Expected output layout field {exp_f['name']} missing"
            assert auto_out[exp_f["name"]]["length"] == exp_f["length"], \
                f"{exp_f['name']} length: {auto_out[exp_f['name']]['length']} != {exp_f['length']}"

        # Constants
        assert layout["constants"] == expected_layout["constants"]
