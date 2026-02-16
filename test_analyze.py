import requests
import json

def test_analyze():
    print("🧪 Testing /analyze endpoint...")
    
    # 1. Login to get token (using an existing user or creating one)
    # I'll use the one from verify_beyond.py if it still exists in users.json
    # Or I'll just register a new one for this test
    # Actually, I'll just use the mock data approach since I'm testing the endpoint logic.
    
    # Let's try to register a temporary test user first
    unique_id = "TESTER_ANALYZE"
    reg_payload = {
        "corporate_id": unique_id,
        "password": "BeyondPassword123!",
        "institution": "QA Lab",
        "city": "Berlin",
        "country": "Germany",
        "role": "QA Engineer"
    }
    
    requests.post("http://localhost:8000/auth/register", json=reg_payload)
    requests.get(f"http://localhost:8000/auth/admin/approve/{unique_id}") # Auto-approve
    
    login_res = requests.post("http://localhost:8000/auth/login", json={
        "corporate_id": unique_id,
        "password": "BeyondPassword123!"
    })
    
    if login_res.status_code != 200:
        print(f"❌ Login failed: {login_res.text}")
        return

    token = login_res.json()['access_token']
    
    # 2. Test /analyze with JSON
    analyze_payload = {
        "cobol_code": "000100 COMPUTE WS-TOTAL = WS-AMT1 + WS-AMT2.",
        "filename": "test.cbl"
    }
    
    print("--- Sending /analyze request...")
    res = requests.post("http://localhost:8000/analyze", 
                         json=analyze_payload,
                         headers={"Authorization": f"Bearer {token}"})
    
    if res.status_code == 200:
        print("✅ /analyze endpoint is WORKING.")
        print(json.dumps(res.json(), indent=2))
    else:
        print(f"❌ /analyze endpoint FAILED: {res.status_code} - {res.text}")

if __name__ == "__main__":
    test_analyze()
