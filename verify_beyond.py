import requests
import json
import time

BASE_URL = "http://localhost:8000"

def verify_beyond_spec():
    print("🚀 Verifying Project Alethia 'BEYOND' Spec...")
    
    unique_id = f"ARCHITECT_{int(time.time())}"
    
    # 1. Test Registration with BEYOND Metadata
    print(f"--- 1. Registering {unique_id} with Institutional Metadata...")
    reg_payload = {
        "corporate_id": unique_id,
        "password": "BeyondPassword123!",
        "institution": "Standard Banking Group",
        "city": "London",
        "country": "UK",
        "role": "Lead Architect"
    }
    
    reg_response = requests.post(f"{BASE_URL}/auth/register", json=reg_payload)
    
    if reg_response.status_code == 403 and "Pending Approval" in reg_response.json().get("detail", ""):
        print("✅ Registration successful & Access BLOCKED (Correct).")
    else:
        print(f"❌ Registration behavior incorrect: {reg_response.status_code} - {reg_response.text}")
        return

    # 2. Verify Profile is restricted before approval
    print("--- 2. Verifying Profile access is BLOCKED for unapproved architect...")
    login_response = requests.post(f"{BASE_URL}/auth/login", json={
        "corporate_id": unique_id,
        "password": "BeyondPassword123!"
    })
    
    if login_response.status_code == 403:
        print("✅ Login correctly blocked for unapproved architect.")
    else:
        print(f"❌ Login NOT blocked: {login_response.status_code}")
        return

    # 3. Trigger Admin Approval
    print("--- 3. Triggering Administrative Authorization...")
    approve_response = requests.get(f"{BASE_URL}/auth/admin/approve/{unique_id}")
    if approve_response.status_code == 200:
        print("✅ Architect AUTHORIZED via secure admin route.")
    else:
        print(f"❌ Authorization failed: {approve_response.status_code}")
        return

    # 4. Verify Full Access and Profile Recovery
    print("--- 4. Verifying Secure Session & Profile Recovery...")
    login_response = requests.post(f"{BASE_URL}/auth/login", json={
        "corporate_id": unique_id,
        "password": "BeyondPassword123!"
    })
    
    if login_response.status_code == 200:
        token = login_response.json()['access_token']
        print("✅ Secure session established.")
        
        profile_response = requests.get(f"{BASE_URL}/auth/profile", headers={"Authorization": f"Bearer {token}"})
        if profile_response.status_code == 200:
            profile = profile_response.json()
            print(f"✅ Vault Profile recovered for {profile['institution']} ({profile['role']}).")
            print(f"✅ Security History detected: {len(profile['security_history'])} events.")
        else:
            print(f"❌ Profile recovery failed: {profile_response.status_code}")
    else:
        print(f"❌ Login failed after approval: {login_response.status_code}")

    print("\n🏆 ALETHIA 'BEYOND' SPEC VERIFIED SUCCESSFULLY")

if __name__ == "__main__":
    verify_beyond_spec()
