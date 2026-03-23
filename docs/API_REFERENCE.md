# Aletheia API Reference

**Version:** 3.2.0
**Base URL:** `http://localhost:8000` (dev) or `https://your-domain.com` (prod)
**Content-Type:** `application/json` (unless noted)

---

## Authentication

All authenticated endpoints require a JWT token in the `Authorization` header:

```
Authorization: Bearer <token>
```

Tokens are HS256-signed, expire after 24 hours, and are obtained via `POST /auth/login`.

**Rate Limiting:**
| Scope | Limit | Key |
|-------|-------|-----|
| `/auth/login` | 5 req/min | Per IP |
| `/engine/*` | 30 req/min | Per authenticated user |

Exceeded limits return `429 Too Many Requests` with `retry-after` header.

---

## Error Codes

| Code | Meaning |
|------|---------|
| 400 | Bad request (empty input, invalid config, missing field) |
| 401 | Unauthorized (invalid credentials, expired/missing token) |
| 403 | Forbidden (not approved, license invalid, feature disabled) |
| 404 | Not found (record, copybook, report) |
| 413 | Payload too large (file exceeds size limit) |
| 429 | Too many requests (rate limited) |
| 500 | Internal server error |
| 501 | Module unavailable |
| 503 | Service unavailable (parser not configured) |
| 507 | Insufficient storage (disk space) |

---

## 1. Auth

### POST /auth/register

Register a new user. Account requires institutional approval before full access.

**Auth:** None

**Request:**
```json
{
  "username": "string",
  "password": "string",
  "email": "string (optional)",
  "institution": "string",
  "city": "string",
  "country": "string",
  "role": "string"
}
```

**Response (200):**
```json
{
  "message": "Registration received. Pending institutional verification."
}
```

---

### POST /auth/login

Authenticate and receive a JWT token.

**Auth:** None | **Rate limit:** 5/min per IP

**Request:**
```json
{
  "username": "string",
  "password": "string"
}
```

**Response (200):**
```json
{
  "access_token": "eyJ...",
  "token_type": "bearer",
  "is_approved": true,
  "corporate_id": "USR-A1B2C3"
}
```

**Example:**
```bash
curl -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "analyst", "password": "s3cure"}'
```

---

### GET /auth/profile

Get the authenticated user's profile and security audit history.

**Auth:** JWT

**Response (200):**
```json
{
  "username": "analyst",
  "institution": "Acme Bank",
  "city": "New York",
  "country": "US",
  "role": "engineer",
  "is_approved": true,
  "security_history": [
    {
      "event": "login",
      "timestamp": "2026-03-18T10:00:00Z",
      "ip": "192.168.1.1"
    }
  ]
}
```

---

## 2. Engine

### POST /engine/analyze

Full COBOL analysis pipeline: ANTLR4 parse, deterministic Python generation, arithmetic risk analysis, dead code detection, and verification verdict.

**Auth:** JWT + License | **Rate limit:** 30/min

**Request:**
```json
{
  "cobol_code": "string (required)",
  "filename": "string (optional, default: 'source.cbl')",
  "compiler_config": {
    "trunc_mode": "STD|BIN|OPT (optional)",
    "arith_mode": "COMPAT|EXTEND (optional)"
  }
}
```

**Response (200):**
```json
{
  "verification_status": "VERIFIED",
  "vault_id": 42,
  "filename": "LOAN-CALC.cbl",
  "parser_output": {
    "success": true,
    "summary": {
      "paragraphs": 8,
      "variables": 25,
      "comp3_variables": 6,
      "lines_of_code": 180
    },
    "paragraphs": [],
    "variables": [],
    "computes": [],
    "conditions": [],
    "parse_errors": 0,
    "compiler_options_detected": {}
  },
  "generated_python": "from decimal import Decimal...",
  "arithmetic_summary": {
    "total": 12,
    "safe": 10,
    "warn": 2,
    "critical": 0
  },
  "arithmetic_risks": [],
  "dead_code": {
    "unreachable_paragraphs": [],
    "total_paragraphs": 8,
    "reachable_paragraphs": 8,
    "dead_percentage": 0.0,
    "has_alter": false
  },
  "verification": {
    "executive_summary": "All constructs verified...",
    "human_review_items": [],
    "checklist": [
      {"item": "ANTLR4 parse", "status": "PASS", "note": "0 errors"},
      {"item": "Python generation", "status": "PASS", "note": "Clean compile"}
    ]
  }
}
```

**Example:**
```bash
curl -X POST http://localhost:8000/engine/analyze \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"cobol_code": "       IDENTIFICATION DIVISION.\n       PROGRAM-ID. TEST.\n       DATA DIVISION.\n       WORKING-STORAGE SECTION.\n       01 WS-AMT PIC S9(7)V99 COMP-3.\n       PROCEDURE DIVISION.\n       0000-MAIN.\n           COMPUTE WS-AMT = 100.50 + 200.25.\n           STOP RUN."}'
```

---

### POST /engine/verify-full

Combined Engine + Shadow Diff verification. Runs the full analysis pipeline AND compares generated Python output against real mainframe data.

**Auth:** JWT + License | **Rate limit:** 30/min

**Request:**
```json
{
  "cobol_code": "string (required)",
  "input_data": "string (required, base64-encoded mainframe input file)",
  "output_data": "string (required, base64-encoded mainframe output file)",
  "layout": {
    "name": "string",
    "fields": [{"name": "str", "start": 0, "length": 10, "type": "string"}],
    "input_mapping": {},
    "output_fields": [],
    "record_length": 80
  },
  "filename": "string (optional)",
  "compiler_config": {}
}
```

If `layout` is omitted, it is auto-generated from the COBOL DATA DIVISION.

**Response (200):**
```json
{
  "unified_verdict": "FULLY VERIFIED",
  "engine_result": {},
  "shadow_diff_result": {
    "verdict": "ZERO DRIFT CONFIRMED",
    "total_records": 100,
    "matches": 100,
    "mismatches": 0,
    "mismatch_details": [],
    "drift_diagnoses": [],
    "input_fingerprint": "sha256:abc...",
    "output_fingerprint": "sha256:def..."
  },
  "auto_layout": null,
  "vault_id": 43
}
```

---

### POST /engine/analyze-batch

Batch analysis of multiple COBOL programs with cross-file CALL resolution. Programs are processed in topological order.

**Auth:** JWT + License | **Rate limit:** 30/min

**Request:**
```json
{
  "programs": [
    {"filename": "MAIN.cbl", "cobol_code": "..."},
    {"filename": "SUB-CALC.cbl", "cobol_code": "..."}
  ],
  "copybooks": [
    {"name": "CUSTOMER-REC", "content": "..."}
  ],
  "compiler_config": {}
}
```

**Response (200):**
```json
{
  "success": true,
  "results": [
    {"filename": "MAIN.cbl", "verification_status": "VERIFIED", "generated_python": "..."},
    {"filename": "SUB-CALC.cbl", "verification_status": "VERIFIED", "generated_python": "..."}
  ],
  "combined_verdict": "VERIFIED"
}
```

Combined verdict uses AND-gate logic: all programs must pass for batch VERIFIED.

---

### POST /engine/generate-layout

Auto-generate a Shadow Diff layout from COBOL DATA DIVISION. Uses FD-based layout (packed binary) if FILE SECTION present, otherwise WORKING-STORAGE (display text).

**Auth:** JWT

**Request:**
```json
{
  "cobol_code": "string (required)",
  "filename": "string (optional)"
}
```

**Response (200):**
```json
{
  "name": "LOAN-CALC",
  "fields": [
    {"name": "WS-AMOUNT", "start": 0, "length": 5, "type": "decimal", "decimals": 2}
  ],
  "record_length": 80,
  "input_mapping": {"WS-AMOUNT": "WS-AMOUNT"},
  "output_fields": ["WS-RESULT"],
  "constants": {},
  "output_layout": {
    "fields": [],
    "field_mapping": {}
  }
}
```

---

### POST /engine/compiler-matrix

Detect IBM z/OS compiler options in COBOL source and report which are explicit vs defaulted.

**Auth:** JWT

**Request:**
```json
{
  "cobol_code": "string (required)",
  "filename": "string (optional)"
}
```

**Response (200):**
```json
{
  "success": true,
  "filename": "LOAN-CALC.cbl",
  "matrix": {
    "detected_options": {
      "TRUNC": "STD",
      "ARITH": null,
      "NUMPROC": null,
      "DECIMAL-POINT": null
    },
    "defaults_applied": {
      "ARITH": "COMPAT",
      "NUMPROC": "NOPFD"
    },
    "constructs_requiring_options": {},
    "warnings": [],
    "recommendation": "Verify TRUNC mode matches production JCL"
  }
}
```

---

### POST /engine/risk-heatmap

Color-coded portfolio risk analysis across multiple programs.

**Auth:** JWT

**Request:**
```json
{
  "programs": [
    {"cobol_code": "...", "filename": "PROG1.cbl"},
    {"cobol_code": "...", "filename": "PROG2.cbl"}
  ]
}
```

Max 100 programs per request.

**Response (200):**
```json
{
  "success": true,
  "heatmap": {}
}
```

---

### POST /engine/generate-poison-pills

Generate adversarial edge-case input records for stress testing the generated Python.

**Auth:** JWT + License | **Rate limit:** 30/min

**Request:**
```json
{
  "cobol_code": "string (required)",
  "filename": "string (optional)",
  "compiler_config": {}
}
```

**Response (200):**
```json
{
  "dat_base64": "base64-encoded binary data",
  "record_count": 50,
  "pills": [
    {"field": "WS-AMOUNT", "edge_case": "max_value", "value": "9999999.99"}
  ],
  "layout": {},
  "record_length": 80
}
```

---

### POST /engine/run-poison-pills

Execute generated Python against poison pill records and report results.

**Auth:** JWT + License | **Rate limit:** 30/min

**Request:**
```json
{
  "cobol_code": "string (required)",
  "dat_base64": "string (base64, from generate-poison-pills)",
  "pills": [],
  "layout": {},
  "filename": "string (optional)",
  "compiler_config": {}
}
```

**Response (200):**
```json
{
  "total": 50,
  "clean": 48,
  "abends": 1,
  "errors": 1,
  "details": [
    {
      "record_idx": 12,
      "field": "WS-AMOUNT",
      "edge_case": "max_value",
      "status": "abend",
      "error_message": "S0C7: non-numeric data in WS-AMOUNT"
    }
  ]
}
```

---

### POST /engine/parse-jcl

Parse IBM JCL (Job Control Language) into structured job/step/DD representation.

**Auth:** JWT

**Request:**
```json
{
  "jcl_text": "string (required, JCL source)"
}
```

**Response (200):**
```json
{
  "job_name": "PAYROLL",
  "steps": [
    {
      "name": "STEP01",
      "pgm": "PAYROLL",
      "dd_statements": [
        {"name": "SYSOUT", "dsn": "*.STEP01.OUTPUT"}
      ]
    }
  ],
  "summary": {}
}
```

---

### POST /engine/generate-sbom

Generate a CycloneDX 1.4 Software Bill of Materials for a COBOL program.

**Auth:** JWT

**Request:**
```json
{
  "program_name": "string (required)",
  "...": "additional analysis fields"
}
```

**Response (200):** CycloneDX 1.4 JSON/XML SBOM document.

---

## 3. Parser & Generator

### POST /parse

Run the ANTLR4 parser on COBOL source without generating Python. Returns structured AST data.

**Auth:** JWT

**Request:**
```json
{
  "cobol_code": "string (required)",
  "filename": "string (optional, default: 'input.cbl')"
}
```

**Response (200):**
```json
{
  "success": true,
  "filename": "input.cbl",
  "parser": "ANTLR4",
  "engine": "deterministic",
  "summary": {
    "paragraphs": 5,
    "variables": 12,
    "comp3_variables": 3,
    "lines_of_code": 80
  },
  "paragraphs": [],
  "variables": [],
  "control_flow": [],
  "computes": [],
  "conditions": [],
  "cycles": [],
  "unreachable": [],
  "parse_errors": 0,
  "compiler_options_detected": {}
}
```

---

### POST /generate

Generate deterministic Python from COBOL source. Returns only the Python code, not the full analysis.

**Auth:** JWT

**Request:**
```json
{
  "cobol_code": "string (required)",
  "filename": "string (optional)"
}
```

**Response (200):**
```json
{
  "success": true,
  "python_code": "from decimal import Decimal, ROUND_DOWN...",
  "error": null
}
```

---

## 4. Shadow Diff

The Shadow Diff engine proves behavioral equivalence by replaying real mainframe I/O through generated Python and comparing results field-by-field.

### POST /shadow-diff/upload-layout

Upload a fixed-width record layout definition.

**Auth:** JWT

**Request:**
```json
{
  "name": "loan_layout",
  "fields": [
    {"name": "ACCT-NUM", "start": 0, "length": 10, "type": "string"},
    {"name": "BALANCE", "start": 10, "length": 10, "type": "decimal", "decimals": 2}
  ],
  "record_length": 80,
  "input_mapping": {"ACCT-NUM": "WS-ACCT-NUM", "BALANCE": "WS-BALANCE"},
  "output_fields": ["WS-INTEREST", "WS-NEW-BALANCE"],
  "constants": {},
  "output_layout": {},
  "codepage": "CP037"
}
```

**Response (200):**
```json
{
  "status": "stored",
  "name": "loan_layout",
  "field_count": 2
}
```

---

### POST /shadow-diff/upload-mainframe-data

Upload mainframe input and output flat files. Supports streaming for files up to 50GB.

**Auth:** JWT

**Request:** multipart/form-data
| Field | Type | Description |
|-------|------|-------------|
| layout_name | string (query) | Layout to associate with |
| input_file | file | Mainframe input .dat file |
| output_file | file | Mainframe output .dat file |

**Response (200):**
```json
{
  "status": "stored",
  "layout_name": "loan_layout",
  "input_size": 8000,
  "output_size": 8000
}
```

---

### POST /shadow-diff/run

Execute the Shadow Diff pipeline: parse input records, run generated Python, compare to mainframe output.

**Auth:** JWT

**Request:**
```json
{
  "layout_name": "loan_layout",
  "generated_python": "from decimal import Decimal...",
  "input_mapping": {},
  "output_fields": [],
  "constants": {}
}
```

**Response (200):**
```json
{
  "verdict": "ZERO DRIFT CONFIRMED",
  "total_records": 100,
  "matches": 100,
  "mismatches": 0,
  "mismatch_log": [],
  "diagnosed_mismatches": [],
  "input_fingerprint": "sha256:abc123...",
  "output_fingerprint": "sha256:def456...",
  "id": 7
}
```

If mismatches exist, `diagnosed_mismatches` includes root cause analysis:
```json
{
  "record_idx": 5,
  "field": "WS-INTEREST",
  "expected": "125.75",
  "actual": "125.74",
  "root_cause": "Rounding mode mismatch (ROUND_HALF_UP vs ROUND_DOWN)",
  "suggested_fix": "Check COMPUTE ROUNDED clause"
}
```

---

### GET /shadow-diff/report/{report_id}

Retrieve a stored Shadow Diff report by ID.

**Auth:** JWT

**Response (200):**
```json
{
  "id": 7,
  "timestamp": "2026-03-18T10:30:00Z",
  "username": "analyst",
  "layout_name": "loan_layout",
  "total_records": 100,
  "matches": 100,
  "mismatches": 0,
  "verdict": "ZERO DRIFT CONFIRMED",
  "report": {}
}
```

---

### GET /shadow-diff/reports

List all Shadow Diff reports.

**Auth:** JWT

**Response (200):**
```json
[
  {
    "id": 7,
    "timestamp": "2026-03-18T10:30:00Z",
    "username": "analyst",
    "layout_name": "loan_layout",
    "total_records": 100,
    "matches": 100,
    "mismatches": 0,
    "verdict": "ZERO DRIFT CONFIRMED"
  }
]
```

---

## 5. Vault (Audit Trail)

The Vault stores every verification result with full provenance, RSA-PSS signatures, and hash-chain integrity.

### GET /vault/list

List all vault records (summary columns, no heavy blobs).

**Auth:** JWT

**Response (200):**
```json
{
  "records": [
    {
      "id": 42,
      "timestamp": "2026-03-18T10:00:00Z",
      "filename": "LOAN-CALC.cbl",
      "file_hash": "sha256:...",
      "verification_status": "VERIFIED",
      "paragraphs_count": 8,
      "variables_count": 25,
      "comp3_count": 6,
      "python_chars": 3200,
      "arithmetic_safe": 10,
      "arithmetic_warn": 2,
      "arithmetic_critical": 0,
      "human_review_flags": 0,
      "checklist_pass": 5,
      "checklist_total": 5,
      "signature": "base64...",
      "public_key_fp": "sha256:...",
      "verification_chain": "sha256:...",
      "prev_hash": "sha256:...",
      "record_hash": "sha256:..."
    }
  ]
}
```

---

### GET /vault/record/{record_id}

Retrieve a single vault record with all fields including generated Python and full report JSON.

**Auth:** JWT

**Response (200):** Same as list entry, plus:
```json
{
  "executive_summary": "string",
  "generated_python": "from decimal import...",
  "full_report_json": "{...}"
}
```

---

### DELETE /vault/record/{record_id}

Delete a vault record.

**Auth:** JWT

**Response (200):**
```json
{
  "deleted": true,
  "id": 42
}
```

---

### POST /vault/verify-chain

Walk the hash chain and verify all RSA-PSS signatures. Detects tampering and chain breaks.

**Auth:** JWT

**Response (200):**
```json
{
  "total_records": 42,
  "valid_signatures": 40,
  "invalid_signatures": 0,
  "unsigned_records": 2,
  "chain_breaks": [],
  "tampered_records": [],
  "chain_intact": true,
  "verified_at": "2026-03-18T10:15:00Z"
}
```

---

### GET /vault/export

Download all vault records as a JSON file.

**Auth:** JWT

**Response:** StreamingResponse
**Content-Type:** `application/json`
**Content-Disposition:** `attachment; filename="aletheia_vault_export_20260318_101500.json"`

---

## 6. Copybook Management

### POST /copybook/upload

Upload a single copybook (.cpy file).

**Auth:** JWT

**Request:** multipart/form-data
| Field | Type | Description |
|-------|------|-------------|
| file | file | .cpy copybook file |

**Response (200):**
```json
{
  "status": "stored",
  "name": "CUSTOMER-REC",
  "filename": "CUSTOMER-REC.cpy"
}
```

---

### POST /copybook/upload-zip

Upload a ZIP archive of copybooks.

**Auth:** JWT

**Request:** multipart/form-data
| Field | Type | Description |
|-------|------|-------------|
| file | file | ZIP archive containing .cpy files |

**Response (200):**
```json
{
  "status": "stored",
  "count": 5,
  "copybooks": ["CUSTOMER-REC", "RATE-TABLE", "ACCT-LAYOUT", "ERROR-CODES", "DATE-FIELDS"]
}
```

---

### GET /copybook/list

List all copybooks in the library.

**Auth:** JWT

**Response (200):**
```json
{
  "copybooks": [
    {
      "name": "CUSTOMER-REC",
      "filename": "CUSTOMER-REC.cpy",
      "size_bytes": 1234,
      "modified": "2026-03-18T09:00:00Z"
    }
  ]
}
```

---

### GET /copybook/{name}

Get a copybook's source text.

**Auth:** JWT

**Response (200):**
```json
{
  "name": "CUSTOMER-REC",
  "content": "       01  CUSTOMER-RECORD.\n           05  CUST-ID    PIC X(10).\n..."
}
```

---

### DELETE /copybook/{name}

Delete a copybook from the library.

**Auth:** JWT

**Response (200):**
```json
{
  "status": "deleted",
  "name": "CUSTOMER-REC"
}
```

---

### POST /copybook/preprocess

Expand COPY statements in COBOL source using the copybook library.

**Auth:** JWT

**Request:**
```json
{
  "source": "string (COBOL source with COPY statements)"
}
```

**Response (200):**
```json
{
  "expanded_source": "string (resolved source)",
  "issues": [],
  "copy_statements_found": 3
}
```

---

## 7. Dependency Analysis

### POST /dependency/analyze

Analyze CALL dependencies across multiple COBOL programs.

**Auth:** JWT

**Request:**
```json
{
  "programs": [
    {"filename": "MAIN.cbl", "cobol_code": "..."},
    {"filename": "SUB-CALC.cbl", "cobol_code": "..."}
  ]
}
```

**Response (200):**
```json
{
  "programs": {"MAIN": "...", "SUB-CALC": "..."},
  "dependencies": {"MAIN": ["SUB-CALC"]},
  "root_program": "MAIN",
  "cycles": [],
  "missing_deps": []
}
```

---

### POST /dependency/upload

Upload multiple COBOL files for dependency analysis.

**Auth:** JWT

**Request:** multipart/form-data
| Field | Type | Description |
|-------|------|-------------|
| files | file[] | Multiple .cbl files |

**Response (200):** Same as `/dependency/analyze`.

---

### POST /dependency/tree

Build dependency tree visualization data.

**Auth:** JWT

**Request:** Same as `/dependency/analyze`.

**Response (200):**
```json
{
  "nodes": [
    {"id": "MAIN", "label": "MAIN", "type": "PROGRAM"}
  ],
  "edges": [
    {"source": "MAIN", "target": "SUB-CALC", "type": "CALL"}
  ]
}
```

---

## 8. Compiler Configuration

### GET /config/compiler

Get the current compiler configuration defaults.

**Auth:** JWT

**Response (200):**
```json
{
  "trunc_mode": "STD",
  "arith_mode": "COMPAT",
  "numproc": "NOPFD",
  "decimal_point": "PERIOD"
}
```

---

### POST /config/compiler

Set compiler configuration for the session.

**Auth:** JWT

**Request:**
```json
{
  "trunc_mode": "BIN",
  "arith_mode": "EXTEND"
}
```

All fields optional; omitted fields keep current values.

**Response (200):** Updated config (same shape as GET).

---

## 9. Verification

### POST /verify

Verify an RSA-PSS signature on a vault record.

**Auth:** JWT

**Request:**
```json
{
  "record_id": 42
}
```

Or:
```json
{
  "signature_data": {"signature": "base64...", "payload": "..."}
}
```

**Response (200):**
```json
{
  "valid": true,
  "details": "Signature verified",
  "verified_at": "2026-03-18T10:20:00Z"
}
```

---

### GET /verify/public-key

Get the RSA-PSS public key for independent verification.

**Auth:** None

**Response (200):**
```json
{
  "public_key_pem": "-----BEGIN PUBLIC KEY-----\nMIIBI...",
  "fingerprint": "sha256:abc123..."
}
```

---

## 10. System

### GET /api/health

Health check endpoint. No authentication required.

**Auth:** None

**Response (200):**
```json
{
  "status": "online",
  "version": "3.2.0",
  "mode": "connected",
  "decimal_precision": "28"
}
```

---

### GET /api/v1/heartbeat

Uptime probe with UTC timestamp and decimal context. No authentication required.

**Auth:** None

**Response (200):**
```json
{
  "status": "operational",
  "timestamp": "2026-03-18T10:00:00Z",
  "engine": "v3.2.0-zero-error",
  "decimal_context": {
    "precision": 28,
    "rounding": "ROUND_DOWN"
  }
}
```

---

## 11. Other

### GET /analytics

Platform analytics dashboard data.

**Auth:** JWT

**Response (200):**
```json
{
  "metrics": {
    "total_lines": 15000,
    "risk_anomalies": 3,
    "precision_score": null
  },
  "active_analyses": [],
  "risk_alerts": [],
  "recent_activity": []
}
```

---

### POST /chat

Contextual Q&A about COBOL/Python code. Uses GPT-4o in connected mode, offline stub in air-gapped mode.

**Auth:** JWT

**Request:**
```json
{
  "cobol_context": "string (required, COBOL source)",
  "python_context": "string (optional, generated Python)",
  "user_query": "string (required)",
  "history": []
}
```

**Response (200):**
```json
{
  "answer": "The COMPUTE statement on line 45 calculates...",
  "confidence": "0.92"
}
```

---

### POST /admin/approve/{corporate_id}

Approve a registered user for full platform access.

**Auth:** JWT (admin)

**Response (200):**
```json
{
  "message": "Clearance granted: USR-A1B2C3"
}
```

---

### GET /demo-data/{filename}

Serve demo files for the frontend.

**Auth:** None

Available files: `DEMO_LOAN_INTEREST.cbl`, `loan_input.dat`, `loan_mainframe_output.dat`, `loan_mainframe_output_WITH_DRIFT.dat`

**Response:** Raw file contents (FileResponse).

---

## Appendix: Pydantic Models

```python
class UserRegistrationRequest(BaseModel):
    username: str
    password: str
    email: Optional[str] = None
    institution: str
    city: str
    country: str
    role: str

class UserLoginRequest(BaseModel):
    username: str
    password: str

class AnalyzeRequest(BaseModel):
    cobol_code: str
    filename: Optional[str] = "input.cbl"
    modernized_code: Optional[str] = None
    is_audit_mode: bool = False
    compiler_config: Optional[dict] = None

class VerifyFullRequest(BaseModel):
    cobol_code: str
    layout: Optional[dict] = None
    input_data: str
    output_data: str
    filename: Optional[str] = "input.cbl"
    compiler_config: Optional[dict] = None

class BatchAnalyzeRequest(BaseModel):
    programs: list
    copybooks: Optional[list] = None
    compiler_config: Optional[dict] = None

class ChatRequest(BaseModel):
    cobol_context: str
    python_context: Optional[str] = None
    user_query: str
    history: List[Dict[str, str]] = []

class LayoutUpload(BaseModel):
    name: str
    fields: list[dict]
    record_length: int | None = None
    input_mapping: dict | None = None
    output_fields: list[str] | None = None
    constants: dict | None = None
    output_layout: dict | None = None
    codepage: str | None = None

class RunRequest(BaseModel):
    layout_name: str
    generated_python: str
    input_mapping: dict | None = None
    output_fields: list[str] | None = None
    constants: dict | None = None

class PreprocessRequest(BaseModel):
    source: str
```
