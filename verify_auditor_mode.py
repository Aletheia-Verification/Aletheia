import requests
import json
import time

BASE_URL = "http://localhost:8000"

def verify_auditor_mode():
    print("🕵️ Verifying Alethia 'BEYOND' Auditor Mode...")
    
    unique_id = f"auditor_{int(time.time())}"
    
    # 1. Register & Approve
    reg_payload = {
        "username": unique_id,
        "password": "BeyondPassword123!",
        "institution": "Audit Authority",
        "city": "Geneva",
        "country": "Switzerland",
        "role": "Senior Auditor"
    }
    print(f"--- Registering user: {unique_id}")
    reg_res = requests.post(f"{BASE_URL}/auth/register", json=reg_payload)
    print(f"Registration response: {reg_res.json()}")

    approve_res = requests.post(f"{BASE_URL}/admin/approve/{unique_id}")
    print(f"Approval response: {approve_res.json()}")
    
    login_res = requests.post(f"{BASE_URL}/auth/login", json={
        "username": unique_id,
        "password": "BeyondPassword123!"
    })
    token = login_res.json()['access_token']
    headers = {"Authorization": f"Bearer {token}"}

    # 2. Audit Engagement Payload
    # 1500.00 * 0.05255 = 78.825
    # COBOL COMPUTE truncates to 2 decimals (PIC 9(10)V99) -> 78.82
    cobol_code = """
       01 WS-PRINCIPAL PIC 9(10)V99 VALUE 1500.00.
       01 WS-INT-RATE PIC V99999 VALUE .05255.
       01 WS-INTEREST PIC 9(10)V99.
       
       COMPUTE WS-INTEREST = WS-PRINCIPAL * WS-INT-RATE.
    """
    
    # Deliberately incorrect implementation (using ROUND_HALF_UP -> 78.83)
    modern_code = """
from decimal import Decimal, ROUND_HALF_UP
principal = Decimal('1500.00')
rate = Decimal('0.05255')
# INCORRECT: result is 78.825. This rounds up to 78.83. COBOL would truncate to 78.82.
interest = (principal * rate).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
print(f"Interest: {interest}")
    """

    print("--- Initiating Audit Engagement (Comparative Analysis)...")
    payload = {
        "cobol_code": cobol_code,
        "modernized_code": modern_code,
        "is_audit_mode": True,
        "filename": "interest_accrual.cbl"
    }
    
    response = requests.post(f"{BASE_URL}/analyze", json=payload, headers=headers)
    
    if response.status_code == 200:
        data = response.json()
        print("✅ Auditor Mode Response Received.")
        print(f"Executive Summary: {data.get('executive_summary', 'N/A')}")
        
        drift_report = data.get('drift_report', [])
        print(f"\n--- Behavior Drift Report ({len(drift_report)} issues found) ---")
        for drift in drift_report:
            print(f"[{drift['mismatch_severity']} RISK] Location: {drift.get('location', 'N/A')}")
            print(f"  Description: {drift['description']}")
            print(f"  Legacy Behavior: {drift['legacy_behavior']}")
            print(f"  Modern Drift: {drift['modern_drift']}")
            print(f"  Financial Consequence: {drift['financial_consequence']}")
            print(f"  Remediation: {drift['remediation_guidance']}")
            
        if any(d['mismatch_severity'] == 'HIGH' for d in drift_report):
            print("\n✅ SUCCESS: Engine correctly detected HIGH RISK drift.")
        else:
            print("\n❌ FAILURE: Engine missed the rounding drift (or classified it as LOW/MEDIUM).")
            
        print("\n--- Corrected Implementation (Truth Preservation) ---")
        print(data.get('corrected_code', 'No code provided'))
        
    else:
        print(f"❌ Audit request failed: {response.status_code} - {response.text}")

if __name__ == "__main__":
    verify_auditor_mode()
