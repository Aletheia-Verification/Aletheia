import json

with open('DEMO_LOAN_INTEREST.cbl', 'r') as f:
    cobol = f.read()

req = {'cobol_code': cobol, 'filename': 'DEMO_LOAN_INTEREST.cbl'}

with open('test_full.json', 'w') as f:
    json.dump(req, f)

print('Created test_full.json')