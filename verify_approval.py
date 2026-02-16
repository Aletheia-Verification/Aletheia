import requests
import json
import time

BASE_URL = "http://localhost:8000"

def test_approval_workflow():
    print("🚀 Starting Admin Approval Workflow Verification...")
    
    # 1. Register a new user
    corporate_id = f"TEST_USER_{int(time.time())}"
    password = "SecurePassword123!"
    
    print(f"--- 1. Registering {corporate_id}...")
    reg_response = requests.post(f"{BASE_URL}/auth/register", json={
        "corporate_id": corporate_id,
        "password": password
    })
    
    if reg_response.status_code == 403 and "Pending Approval" in reg_response.json().get("detail", ""):
        print("✅ Registration successful & Access BLOCKED (Correct).")
    elif reg_response.status_code == 200:
        print("❌ Registration succeeded with bypass (Token issuance detected!).")
        return
    else:
        print(f"❌ Registration failed with unexpected error: {reg_response.text}")
        return

    # 2. Attempt to login (should be blocked by Gatekeeper)
    print(f"--- 2. Attempting login for unapproved user...")
    login_response = requests.post(f"{BASE_URL}/auth/login", json={
        "corporate_id": corporate_id,
        "password": password
    })
    
    if login_response.status_code == 403 and "Pending Approval" in login_response.json().get("detail", ""):
        print("✅ Login correctly blocked by Admin Gatekeeper.")
    else:
        print(f"❌ Login NOT correctly blocked (Status: {login_response.status_code}): {login_response.text}")
        return

    # 3. Use hidden Admin Route to approve
    print(f"--- 3. Triggering Administrative Approval...")
    approve_response = requests.get(f"{BASE_URL}/auth/admin/approve/{corporate_id}")
    
    if approve_response.status_code == 200:
        print("✅ User APPROVED via admin route.")
    else:
        print(f"❌ Admin approval failed: {approve_response.text}")
        return

    # 4. Attempt login again (should succeed)
    print(f"--- 4. Attempting login after approval...")
    final_login_response = requests.post(f"{BASE_URL}/auth/login", json={
        "corporate_id": corporate_id,
        "password": password
    })
    
    if final_login_response.status_code == 200 and "access_token" in final_login_response.json():
        print("✅ Login SUCCESSFUL after Admin Approval.")
        print("\n🏆 FULL WORKFLOW VERIFIED SUCCESSFULLY")
    else:
        print(f"❌ Login failed after approval: {final_login_response.text}")

if __name__ == "__main__":
    test_approval_workflow()
