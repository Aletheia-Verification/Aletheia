import requests

url = "http://localhost:8000/process-legacy"
files = {'file': ('test.cbl', 'IDENTIFICATION DIVISION.\nNOTE: This is a test file.')}

try:
    response = requests.post(url, files=files)
    print(f"Status Code: {response.status_code}")
    print("Response JSON:")
    print(response.json())
except Exception as e:
    print(f"Error: {e}")
