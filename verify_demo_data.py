"""
verify_demo_data.py — Pre-demo verification of all 3 scenarios.
Run: "venv\\Scripts\\python.exe" verify_demo_data.py
"""

import base64
import json
import os
import sys

os.environ["USE_IN_MEMORY_DB"] = "true"

from fastapi.testclient import TestClient
from core_logic import app, create_access_token

# Override license check
try:
    from license_manager import require_valid_license
except ImportError:
    from core_logic import require_valid_license
app.dependency_overrides[require_valid_license] = lambda: None

TOKEN = create_access_token({"sub": "admin"})
AUTH = {"Authorization": f"Bearer {TOKEN}"}
client = TestClient(app)

PASS = 0
FAIL = 0


def check(label, condition, detail=""):
    global PASS, FAIL
    if condition:
        PASS += 1
        print(f"  [PASS] {label}")
    else:
        FAIL += 1
        print(f"  [FAIL] {label} — {detail}")


def verify_full(cobol_path, layout_path, input_path, output_path, compiler_config=None):
    with open(cobol_path, "r") as f:
        cobol_code = f.read()
    with open(layout_path, "r") as f:
        layout = json.load(f)
    with open(input_path, "rb") as f:
        input_b64 = base64.b64encode(f.read()).decode()
    with open(output_path, "rb") as f:
        output_b64 = base64.b64encode(f.read()).decode()
    body = {
        "cobol_code": cobol_code,
        "layout": layout,
        "input_data": input_b64,
        "output_data": output_b64,
    }
    if compiler_config:
        body["compiler_config"] = compiler_config
    resp = client.post("/engine/verify-full", json=body, headers=AUTH)
    return resp


# ─── SCENARIO 1: ACCT-INTEREST (zero drift) ─────────────────────────────

print("\n" + "=" * 70)
print("SCENARIO 1: ACCT-INTEREST — Full Pipeline (Zero Drift Expected)")
print("=" * 70)

resp = verify_full(
    "demo_data/ACCT-INTEREST.cbl",
    "demo_data/acct_interest_layout.json",
    "demo_data/acct_interest_input.dat",
    "demo_data/acct_interest_output.dat",
)

check("HTTP 200", resp.status_code == 200, f"got {resp.status_code}")
if resp.status_code == 200:
    body = resp.json()
    check("Unified verdict = FULLY VERIFIED",
          body["unified_verdict"] == "FULLY VERIFIED",
          f"got '{body['unified_verdict']}'")

    eng = body["engine_result"]
    check("Engine: VERIFIED", eng["verification_status"] == "VERIFIED",
          f"got '{eng['verification_status']}'")
    check("Engine: generated Python present", eng["generated_python"] is not None)
    check("Engine: vault_id assigned", eng.get("vault_id") is not None)

    sd = body["shadow_diff_result"]
    check("Shadow Diff: returned", sd is not None)
    if sd:
        check("Shadow Diff: 0 mismatches", sd["mismatches"] == 0,
              f"got {sd['mismatches']}")
        check("Shadow Diff: 100 records", sd["total_records"] == 100,
              f"got {sd['total_records']}")
        check("Shadow Diff: ZERO DRIFT in verdict", "ZERO DRIFT" in sd["verdict"],
              f"got '{sd['verdict']}'")
        check("Shadow Diff: SHA-256 fingerprints present",
              sd.get("input_fingerprint", "").startswith("sha256:"))

# ─── SCENARIO 2: DEMO_LOAN_INTEREST (zero drift) ────────────────────────

print("\n" + "=" * 70)
print("SCENARIO 2: DEMO_LOAN_INTEREST — Full Pipeline (Zero Drift Expected)")
print("=" * 70)

resp = verify_full(
    "DEMO_LOAN_INTEREST.cbl",
    "demo_data/loan_layout.json",
    "demo_data/loan_input.dat",
    "demo_data/loan_mainframe_output.dat",
)

check("HTTP 200", resp.status_code == 200, f"got {resp.status_code}")
if resp.status_code == 200:
    body = resp.json()
    check("Unified verdict = FULLY VERIFIED",
          body["unified_verdict"] == "FULLY VERIFIED",
          f"got '{body['unified_verdict']}'")

    eng = body["engine_result"]
    check("Engine: VERIFIED", eng["verification_status"] == "VERIFIED",
          f"got '{eng['verification_status']}'")
    check("Engine: generated Python present", eng["generated_python"] is not None)

    sd = body["shadow_diff_result"]
    check("Shadow Diff: returned", sd is not None)
    if sd:
        check("Shadow Diff: 0 mismatches", sd["mismatches"] == 0,
              f"got {sd['mismatches']}")
        check("Shadow Diff: 100 records", sd["total_records"] == 100,
              f"got {sd['total_records']}")
        check("Shadow Diff: ZERO DRIFT in verdict", "ZERO DRIFT" in sd["verdict"],
              f"got '{sd['verdict']}'")

# ─── SCENARIO 3: DRIFT DETECTION ────────────────────────────────────────

print("\n" + "=" * 70)
print("SCENARIO 3: DEMO_LOAN_INTEREST — Drift Detection (3-5 corrupted records)")
print("=" * 70)

# Create drift file: corrupt records 5, 22, 47, 71, 93 (0-indexed)
# Change interest values by small amounts
print("  Creating loan_output_WITH_DRIFT.dat ...")
with open("demo_data/loan_mainframe_output.dat", "r") as f:
    lines = f.readlines()

corrupt_indices = [4, 21, 46, 70, 92]  # 0-indexed
corrupted = 0
for idx in corrupt_indices:
    if idx < len(lines):
        line = lines[idx]
        # Each line has 4 fields of 40 chars each
        # Corrupt the DAILY-INTEREST field (chars 40-79) by tweaking a digit
        if len(line) >= 80:
            chars = list(line)
            # Find the last non-space digit in the DAILY-INTEREST field
            field_start = 40
            field_end = 80
            field = line[field_start:field_end]
            # Replace last significant digit
            for i in range(field_end - 1, field_start - 1, -1):
                if chars[i] in '123456789':
                    # Decrease by 1
                    chars[i] = str(int(chars[i]) - 1)
                    corrupted += 1
                    break
                elif chars[i] == '0' and i > field_start:
                    # Change 0 → 1
                    chars[i] = '1'
                    corrupted += 1
                    break
            lines[idx] = ''.join(chars)

print(f"  Corrupted {corrupted} records at indices {corrupt_indices}")

drift_path = "demo_data/loan_output_WITH_DRIFT.dat"
with open(drift_path, "w", newline='') as f:
    f.writelines(lines)

resp = verify_full(
    "DEMO_LOAN_INTEREST.cbl",
    "demo_data/loan_layout.json",
    "demo_data/loan_input.dat",
    drift_path,
)

check("HTTP 200", resp.status_code == 200, f"got {resp.status_code}")
if resp.status_code == 200:
    body = resp.json()
    check("Unified verdict != FULLY VERIFIED",
          body["unified_verdict"] != "FULLY VERIFIED",
          f"got '{body['unified_verdict']}'")

    eng = body["engine_result"]
    check("Engine: still VERIFIED (code is correct)",
          eng["verification_status"] == "VERIFIED",
          f"got '{eng['verification_status']}'")

    sd = body["shadow_diff_result"]
    check("Shadow Diff: returned", sd is not None)
    if sd:
        check(f"Shadow Diff: mismatches > 0", sd["mismatches"] > 0,
              f"got {sd['mismatches']}")
        check(f"Shadow Diff: mismatches in range 3-5",
              3 <= sd["mismatches"] <= 5,
              f"got {sd['mismatches']}")
        check("Shadow Diff: DRIFT DETECTED in verdict",
              "DRIFT DETECTED" in sd["verdict"],
              f"got '{sd['verdict']}'")
        diagnoses = sd.get("drift_diagnoses", [])
        check("Shadow Diff: drift diagnoses present",
              len(diagnoses) > 0,
              f"got {len(diagnoses)} diagnoses")
        if diagnoses:
            d = diagnoses[0]
            check("Diagnosis has field + likely_cause",
                  "field" in d and "likely_cause" in d,
                  f"keys: {list(d.keys())}")
            print(f"\n  Sample diagnosis:")
            print(f"    Record: {d.get('record', '?')}")
            print(f"    Field: {d.get('field', '?')}")
            print(f"    Expected: {d.get('mainframe_value', '?')}")
            print(f"    Got: {d.get('aletheia_value', '?')}")
            print(f"    Cause: {d.get('likely_cause', '?')}")
            print(f"    Fix: {d.get('suggested_fix', '?')}")

# ─── SUMMARY ─────────────────────────────────────────────────────────────

print("\n" + "=" * 70)
print(f"DEMO VERIFICATION COMPLETE: {PASS} passed, {FAIL} failed")
print("=" * 70)

client.close()
sys.exit(1 if FAIL > 0 else 0)
