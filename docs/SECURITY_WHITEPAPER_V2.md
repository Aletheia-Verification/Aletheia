# Aletheia Security Whitepaper

**Version 2.0 | March 2026**
**Classification: Public**

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Deployment Architecture](#2-deployment-architecture)
3. [Data Handling](#3-data-handling)
4. [Code Execution Model](#4-code-execution-model)
5. [Cryptographic Integrity](#5-cryptographic-integrity)
6. [Key Management](#6-key-management)
7. [Access Control](#7-access-control)
8. [Compliance Alignment](#8-compliance-alignment)
9. [Threat Model](#9-threat-model)
10. [Dependency Audit](#10-dependency-audit)
11. [Penetration Testing Status](#11-penetration-testing-status)
12. [Known Limitations](#12-known-limitations)
13. [Contact](#13-contact)

---

## 1. Executive Summary

Aletheia is a deterministic behavioral verification engine for COBOL-to-Python legacy system migration, designed for tier-1 banks and regulated financial institutions.

**What Aletheia is:** A verification tool that proves whether a Python translation of COBOL behaves identically to the original mainframe program. It parses COBOL source using an ANTLR4 grammar, generates a deterministic Python model, and compares execution results field-by-field against actual mainframe output. The verdict is binary: VERIFIED or REQUIRES_MANUAL_REVIEW. There are no percentages, no confidence scores, and no probabilistic outputs.

**What Aletheia is not:** Aletheia is not a transpiler, not an AI translator, and not a code generator for production use. The generated Python is a *verification model* — a mathematical proof artifact, not a deployment target.

**The role of AI in the pipeline: None.** The core verification pipeline — parsing, code generation, arithmetic analysis, and behavioral comparison — is entirely deterministic. No large language model, neural network, or statistical model participates in any correctness decision. An optional LLM integration (GPT-4o) exists solely for formatting human-readable explanations of results. This integration is disabled by default (air-gapped mode) and can be permanently excluded at the infrastructure level. Even when enabled, LLM output never influences verification verdicts.

**Why this matters for banks:** Legacy COBOL systems process trillions of dollars daily. Migration projects fail not because the translation is wrong, but because institutions cannot *prove* the translation is right. Aletheia provides that proof — a cryptographically signed, immutable audit trail demonstrating that the migrated system produces identical outputs to the mainframe for every tested input record. This is not a claim of correctness; it is a demonstration of behavioral equivalence under test.

---

## 2. Deployment Architecture

### Air-Gapped by Default

Aletheia ships in air-gapped mode (`ALETHEIA_MODE=air-gapped`). In this configuration:

- **Zero outbound network calls.** No API requests, no telemetry, no analytics, no DNS lookups to external services.
- **Zero inbound network requirements.** The application runs on `localhost:8000` and requires no internet connectivity.
- **Explicit telemetry opt-out.** The environment variable `DO_NOT_TRACK=1` is set in the container image at build time.
- **LLM services disabled.** All calls to external language models return deterministic offline stubs. The verification pipeline operates identically whether connected or air-gapped.

A "connected" mode exists (`ALETHEIA_MODE=connected`) that enables GPT-4o for explanation formatting. This mode requires an explicit `OPENAI_API_KEY` environment variable and is intended only for non-regulated environments where human-readable summaries are desired. Connected mode does not alter any verification logic.

### Docker Deployment

Aletheia is distributed as a Docker container built via a two-stage process:

**Stage 1 (Builder):** Compiles 18 core Python modules into native `.so` binaries via Cython. This provides intellectual property protection and prevents runtime modification of verification logic. Compilation failures are handled per-file with fallback to interpreted Python.

**Stage 2 (Runtime):** A minimal image containing only compiled binaries, the ANTLR4 runtime, and essential Python packages. Build tools (gcc, Cython, pip) are not present in the final image. Select files remain as readable `.py` for customer auditability: `license_manager.py`, `cli_entry.py`, and database integration modules.

**Container hardening:**

| Parameter | Value | Notes |
|-----------|-------|-------|
| Runtime user | `appuser` (non-root) | Created via `adduser --disabled-password` |
| Exposed port | 8000 (HTTP) | TLS termination expected upstream (nginx, ALB, etc.) |
| Vault storage | Volume mount (`vault.db`) | SQLite file, persisted across restarts |
| Copybook library | Volume mount (`/app/copybooks`) | Customer-provided COBOL copybooks |
| License files | Read-only mount (`/app/license:ro`) | Signed license + signature |
| File upload limit | 10 MB | Hard-coded `MAX_FILE_SIZE_MB`, enforced server-side |

### Network Isolation Recommendation

For production deployments in regulated environments, Aletheia should be deployed on an isolated network segment with no egress rules. The container requires no outbound connectivity. Inbound access should be restricted to authorized workstations via network policy or firewall rules. TLS 1.2+ termination should be handled by a reverse proxy (nginx, HAProxy, or cloud load balancer) in front of the container.

---

## 3. Data Handling

### Processing Model

COBOL source code submitted for analysis is processed entirely in memory within a single HTTP request lifecycle. The processing pipeline is:

1. **Upload:** COBOL source received as file upload or text payload. File size validated against 10 MB limit; oversized uploads rejected with HTTP 413.
2. **Preprocessing:** COPY statements resolved, REPLACING clauses applied (in-memory string operations).
3. **Parsing:** ANTLR4 lexer/parser produces an in-memory parse tree. No intermediate files are written.
4. **Generation:** Deterministic Python code generated from the parse tree. All operations use `decimal.Decimal` with 28-digit precision and `ROUND_DOWN` truncation to match IBM mainframe behavior.
5. **Analysis:** Arithmetic risk analysis, EXEC SQL/CICS detection, dependency crawling — all in-memory.
6. **Response:** JSON response returned to client. Parse tree and intermediate structures are garbage-collected.

**No customer COBOL is persisted.** The Vault stores hashes of the COBOL source (SHA-256), the generated Python verification model, and analysis metadata. The original COBOL source code is not stored in any database, file, or cache beyond the request lifecycle.

### Post-Processing Data Handling

After the `/engine/verify-full` endpoint returns its response, intermediate data structures (engine results, generated Python) are explicitly dereferenced and garbage collected. This is a defense-in-depth measure — it ensures sensitive data is not held in memory longer than necessary.

**Honest limitation:** Python's garbage collector frees memory back to the operating system but does not cryptographically zero the underlying bytes. A memory forensics tool with access to server RAM could theoretically recover fragments of processed COBOL until the memory pages are reused by other allocations. This is an inherent limitation of managed-memory languages.

**Real protection** comes from the deployment model:
- **Air-gapped deployment** (default) ensures no remote access to server memory
- **Vault encryption at rest** (AES-256-GCM) protects persisted data
- **No COBOL source persistence** — only SHA-256 hashes are stored
- **Container isolation** (non-root, read-only filesystem) limits attack surface

### Data Flow Diagram

```
                            ALETHEIA DATA FLOW
    ================================================================

    ANALYSIS PIPELINE
    ─────────────────

    Client                    Aletheia Server                    Storage
    ──────                    ──────────────                    ───────

    COBOL source  ─────────►  [Upload + Size Check]
    (file/text)                      │
                              [COPY/REPLACING Preprocessor]
                                     │
                              [ANTLR4 Parser]
                                     │                     (in memory only)
                              [Python Generator]
                                     │
                              [Arithmetic Risk Analyzer]
                                     │
                              [SHA-256 Hashing]  ──────────►  vault.db
                                     │                     (hash chain +
                              [RSA-PSS Signing]            RSA-PSS sig)
                                     │
    JSON response  ◄──────────  [HTTP Response]


    SHADOW DIFF PIPELINE
    ────────────────────

    Mainframe output  ────►  [Stream from disk]
    (flat file)                    │
                              [Parse record-by-record]      (constant RAM)
                                   │
                              [exec() generated Python]     (isolated namespace)
                                   │
                              [Field-by-field compare]
                                   │
    Drift report  ◄────────  [ZERO DRIFT / DRIFT DETECTED]


    VAULT CHAIN
    ───────────

    Record N-1               Record N                Record N+1
    ┌──────────┐            ┌──────────┐            ┌──────────┐
    │chain_hash├──────────► │prev_hash │            │prev_hash │
    │          │            │chain_hash├──────────► │chain_hash│
    │signature │            │signature │            │signature │
    └──────────┘            └──────────┘            └──────────┘
```

### What the Vault Stores

The Vault (`vault.db`, SQLite) is an append-only audit trail. Each record contains:

- **Metadata:** Timestamp (ISO-8601 UTC), original filename, paragraph/variable/COMP-3 counts.
- **Hashes:** SHA-256 of the original COBOL source (`file_hash`), SHA-256 of the generated Python (`python_hash`), SHA-256 of the full report JSON (`report_hash`).
- **Verification status:** The binary verdict (VERIFIED or REQUIRES_MANUAL_REVIEW).
- **Chain linkage:** Previous record's `chain_hash` (see Section 5).
- **Cryptographic signature:** RSA-PSS signature over the record hash, plus the signing key's fingerprint.
- **Generated Python and report JSON:** Stored for reproducibility and audit.

**Important note on data retention:** The Vault stores the generated Python code and the full analysis report JSON. Organizations with strict data retention requirements should implement volume-level encryption (LUKS, BitLocker, or cloud KMS-backed encryption) on the `vault.db` mount and establish a retention/purge schedule consistent with their data governance policies.

### Shadow Diff Data

The Shadow Diff engine processes mainframe flat-file output data for field-by-field comparison. This data is streamed from disk and processed record-by-record in constant memory, enabling verification of files up to 50 GB without loading entire datasets into RAM. Shadow Diff input files are not persisted in the Vault — only the drift verdict and record-level results are stored.

---

## 4. Code Execution Model

### Overview

The Shadow Diff verification engine executes generated Python code to compare its outputs against mainframe reference data. This execution uses Python's `exec()` built-in. Because `exec()` is a security-sensitive operation, this section documents the controls, boundaries, and limitations in detail.

### What Gets Executed

The code executed by `exec()` is **deterministically generated by Aletheia's own code generator** from a parsed COBOL abstract syntax tree. It is never user-supplied code. The generation pipeline is:

```
COBOL source → ANTLR4 parser → Abstract Syntax Tree → Python generator → exec()
```

The Python generator emits only:
- `decimal.Decimal` arithmetic operations
- CobolDecimal `.store()` and `.value` accessors
- `if`/`while`/`for` control flow
- `print()` for DISPLAY statements
- Function calls to generated paragraph functions

It does not emit `import`, `open()`, `os.system()`, `subprocess`, network calls, or filesystem operations beyond the abstract I/O layer.

### Isolation Controls

| Control | Implementation | Limitation |
|---------|---------------|------------|
| **Namespace isolation** | Fresh `dict` created per record (`namespace = {}`) | No cross-record state leakage |
| **Source origin** | Only Aletheia-generated code is executed | No path for user-supplied code injection |
| **Timeout protection** | Execution runs in a separate thread with configurable timeout | Prevents infinite loops from consuming resources |
| **Memory control** | Stream processing (generator pattern) — one record at a time | Constant RAM regardless of file size |
| **No network access** | Generated code contains no networking constructs | No data exfiltration via executed code |
| **No filesystem access** | I/O abstracted through StreamBackend (in-memory) or RealFileBackend (CLI only) | File paths controlled by the application, not the executed code |

### Current Limitations

- **No OS-level sandbox.** The `exec()` call runs within the same Python process without seccomp, AppArmor, or namespace isolation. A sufficiently crafted malicious COBOL program could theoretically generate Python that escapes the namespace boundary — though this would require the COBOL source to exploit the deterministic code generator in a way that produces executable Python containing escape vectors. This is a theoretical risk with no known exploit path.
- **No restricted builtins.** The executed namespace has access to Python's full built-in scope. Restricting `__builtins__` is a planned hardening step.
- **Same-process execution.** Executed code shares the process memory space. A crash in executed code (e.g., stack overflow) affects the parent process.

### Roadmap

1. **Restricted builtins** — Remove dangerous builtins (`__import__`, `open`, `eval`, `exec`, `compile`) from the execution namespace.
2. **Subprocess isolation** — Execute generated Python in a separate subprocess with restricted capabilities.
3. **seccomp profiles** — For Linux deployments, apply seccomp-bpf filters to restrict system calls available to the execution environment.

---

## 5. Cryptographic Integrity

### Hash Chain Architecture

Every verification record in the Vault is linked to its predecessor via a cryptographic hash chain, creating an append-only ledger analogous to a blockchain but without the distributed consensus overhead.

**Hash construction:**

```
cobol_hash   = SHA-256(COBOL source code)
python_hash  = SHA-256(generated Python code)
report_hash  = SHA-256(JSON report, deterministic key ordering)
chain_hash   = SHA-256(cobol_hash || python_hash || report_hash || prev_hash)
```

The genesis record uses `prev_hash = "0" * 64` (64 zero characters). Each subsequent record's `prev_hash` is the `chain_hash` of the immediately preceding record.

**Tamper detection:** A separate `record_hash` is computed as SHA-256 over all 20 non-signature columns of the database record, using a pipe separator to prevent boundary ambiguity. This detects modification of any stored field — metadata, verdicts, or hashes — independent of the chain linkage.

### RSA-PSS Digital Signatures

Each Vault record is signed using RSA-PSS (Probabilistic Signature Scheme):

| Parameter | Value |
|-----------|-------|
| Key size | 2048 bits |
| Hash algorithm | SHA-256 |
| Mask generation function | MGF1 with SHA-256 |
| Salt length | PSS.MAX_LENGTH (maximized) |
| Signature encoding | Base64 |

The signature covers the `record_hash` (full-field tamper protection). Legacy records sign the `chain_hash` for backward compatibility. Both modes are verified during chain validation.

### Chain Verification Endpoint

The `/vault/verify-chain` API endpoint performs a full integrity audit:

1. Walks all records in insertion order.
2. Verifies chain linkage (`prev_hash` matches previous record's `chain_hash`).
3. Recomputes `record_hash` from stored fields and compares against the stored value.
4. Verifies the RSA-PSS signature on each record using the stored public key fingerprint.
5. Returns a structured report: counts of valid, invalid, unsigned, tampered records, and any chain breaks.

This endpoint enables automated compliance checks without manual inspection of the database.

### Public Key Fingerprinting

Each signing key is identified by its fingerprint: `sha256:<hex-digest>`, computed as SHA-256 over the public key's DER-encoded bytes. This allows key attribution without exposing key material and enables detection of unauthorized signing keys.

---

## 6. Key Management

### Report Signing Keys

Report signing keys are generated locally on the Aletheia server at first startup or on demand:

- **Algorithm:** RSA-2048
- **Public exponent:** 65537
- **Storage location:** `aletheia_keys/` directory (`private.pem`, `public.pem`)
- **Private key format:** PKCS#8, PEM-encoded, no passphrase encryption
- **Public key format:** SubjectPublicKeyInfo, PEM-encoded

**Current limitation:** Private keys are stored unencrypted on the filesystem. This is adequate for air-gapped deployments with restricted filesystem access but does not meet the standards expected for HSM-backed key management in production banking environments. See Section 12 for planned improvements.

### License Master Keys

The license system uses a separate RSA-2048 key pair:

- **Master private key:** Held offline at Aletheia headquarters. Used exclusively to sign license files via `tools/generate_license.py`. Never shipped to customers.
- **Master public key:** Embedded directly in `license_manager.py` source code (and compiled into the Cython binary). Used for offline license verification without network access.
- **Key generation:** `tools/generate_license.py --generate-master-key` produces a new 2048-bit RSA pair in `aletheia_keys/`.

This separation ensures that license validation works in fully air-gapped environments — the public key is baked into the application binary, and license files are verified locally against it.

### Key Rotation

Key rotation is currently a manual process:

1. Generate a new key pair.
2. Re-sign all future reports with the new key.
3. Existing Vault records retain their original signatures and remain verifiable against the original public key (fingerprint-matched).

**Limitation:** There is no automated key rotation mechanism, no key expiry enforcement, and no revocation list. These are planned features. See Section 12.

---

## 7. Access Control

### Authentication

Aletheia uses JSON Web Token (JWT) authentication with the following configuration:

| Parameter | Value |
|-----------|-------|
| Algorithm | HS256 (HMAC-SHA256) |
| Token lifetime | Configurable via `JWT_TOKEN_LIFETIME_HOURS` (default: 168 hours / 7 days) |
| Secret key | Configurable via `JWT_SECRET_KEY` environment variable |
| Transport | `Authorization: Bearer <token>` header |

**Token claims:**
- `sub` (subject): Username
- `iat` (issued at): UTC timestamp for forensic traceability
- `exp` (expiration): Computed from `iat` + configured lifetime

**Token verification:** Every protected endpoint extracts and validates the JWT. Invalid, expired, or tampered tokens return HTTP 401. The username in the `sub` claim is verified against the user database — a valid token for a deleted user is rejected.

**JWT secret management:** The JWT secret is configurable via the `JWT_SECRET_KEY` environment variable. When this variable is not set, the application generates an ephemeral random secret at startup (suitable for development but not for multi-instance deployments). Deployers are responsible for providing a cryptographically strong secret in production.

### Password Storage

User passwords are hashed using PBKDF2-SHA256 (NIST SP 800-132 compliant) via the `passlib` library with automatic hash migration support. Plaintext passwords are never stored or logged.

### Rate Limiting

Aletheia implements in-memory sliding-window rate limiting to prevent brute-force attacks and resource abuse:

| Endpoint | Limit | Scope | Response |
|----------|-------|-------|----------|
| `/auth/login` | 5 requests / 60 seconds | Per source IP | HTTP 429 with `retry-after` header |
| `/engine/*` | 30 requests / 60 seconds | Per authenticated user | HTTP 429 with `retry-after` header |

The `RateLimiter` class uses `time.monotonic()` for precision and a sliding-window algorithm that prunes expired entries on each call. Rate limiting is enforced via FastAPI middleware and runs before endpoint logic — rejected requests consume no processing resources.

**Limitation:** Rate limit state is in-memory and per-process. In a multi-instance deployment behind a load balancer, each instance maintains independent counters. For shared rate limiting across instances, an external store (Redis) would be required.

### Authorization Model

Aletheia implements a two-tier authorization model:

1. **Authentication gate:** All API endpoints (except `/auth/login`, `/auth/register`, `/api/health`, and `/api/v1/heartbeat`) require a valid JWT.
2. **Approval gate:** Analysis endpoints (`/engine/analyze`, `/engine/analyze-batch`) require the user's `is_approved` flag to be set by an administrator via `/admin/approve/{corporate_id}`.

Each user record includes a `role` field. The infrastructure for role-based access control is in place, though granular per-endpoint role enforcement is not yet fully implemented (see Section 12).

### License-Based Access Control

In addition to user authentication, the license system enforces:

- **Feature gating:** License files specify an array of enabled features. Endpoints can require specific features via `require_feature()`.
- **Daily rate limits:** Each license specifies `max_analyses_per_day`. Exceeding this limit returns HTTP 429.
- **Strict mode:** Invalid or expired licenses return HTTP 403 on all `/engine/*` endpoints.
- **Grace mode:** Allows 50 analyses or 7 days of operation without a valid license, then enforces a hard block.

### Upload Validation

File uploads are subject to a hard-coded 10 MB size limit (`MAX_FILE_SIZE_MB`). Oversized uploads are rejected with HTTP 413 before any processing begins. This prevents denial-of-service via large file uploads.

---

## 8. Compliance Alignment

### GDPR Article 28 (Processor Obligations)

Aletheia's architecture supports GDPR compliance for organizations acting as data processors:

- **Data minimization:** COBOL source is processed in memory and not persisted beyond the request lifecycle. The Vault stores hashes and analysis artifacts, not raw source in a searchable index.
- **Air-gapped deployment:** In the default configuration, no data leaves the deployment environment. There are no external API calls, no telemetry, and no cloud dependencies.
- **Audit trail:** The Vault provides a cryptographically signed, tamper-evident record of all processing activities, supporting the accountability requirements of Article 5(2).
- **Right to erasure:** Vault records can be purged in compliance with data retention policies. The hash chain's integrity can be maintained through tombstone records that preserve chain linkage while removing content.

**Caveat:** Aletheia itself does not implement data subject access request (DSAR) workflows or automated retention policies. These must be implemented at the organizational level.

### SOC 2 Readiness

Aletheia's design addresses several SOC 2 Trust Service Criteria:

| Criterion | Aletheia Capability |
|-----------|-------------------|
| **CC6.1** (Logical access) | JWT authentication, approval gates, license-based feature gating, rate limiting |
| **CC6.3** (Access removal) | User deactivation invalidates all tokens (sub claim verified against user DB) |
| **CC6.6** (System boundaries) | Rate limiting on login (5/min) and engine (30/min), file upload size guard (10 MB) |
| **CC7.2** (System monitoring) | Vault provides immutable, signed audit trail of all verification activities |
| **CC8.1** (Change management) | Cython-compiled binaries prevent runtime code modification |
| **PI1.3** (Processing integrity) | Deterministic pipeline, Decimal arithmetic, binary verdicts, no probabilistic outputs |

**Caveat:** Aletheia has not undergone a SOC 2 audit. The above describes architectural alignment, not certified compliance. A Type II audit is a planned milestone.

### ISO 27001 Readiness

Aletheia's architecture maps to several ISO 27001 Annex A controls:

| Control | Aletheia Capability |
|---------|-------------------|
| **A.5.15** (Access control) | JWT authentication, role fields, approval gates, per-user rate limiting |
| **A.8.1** (User endpoint devices) | Non-root container execution, no shell access in production image |
| **A.8.9** (Configuration management) | Environment variable configuration, no hardcoded secrets in source |
| **A.8.24** (Use of cryptography) | SHA-256 hash chains, RSA-PSS signatures (2048-bit), PBKDF2-SHA256 password hashing |
| **A.8.25** (Secure development) | Deterministic pipeline, 630+ automated tests, zero-regression policy |
| **A.8.31** (Separation of environments) | `USE_IN_MEMORY_DB` separates test and production data paths |
| **A.5.23** (Cloud services) | Air-gapped default eliminates cloud dependency; connected mode explicit opt-in |

**Caveat:** Aletheia has not undergone ISO 27001 certification. The above describes architectural alignment with Annex A controls, not certified compliance. Certification readiness depends on organizational ISMS implementation.

### Air-Gapped = No Data Exfiltration Vector

In air-gapped mode, Aletheia presents no network-based data exfiltration surface:

- No outbound connections of any kind.
- No DNS resolution required.
- No package manager calls, update checks, or heartbeat pings.
- `DO_NOT_TRACK=1` set at the container level.

The only data path out of the system is the HTTP response to the client on `localhost:8000`. Restricting client access to authorized workstations via network policy eliminates all remote exfiltration vectors.

### Financial Precision Compliance

For institutions subject to regulatory requirements around financial calculation accuracy:

- All monetary and arithmetic values use Python's `decimal.Decimal` with 28-digit precision.
- Rounding mode is `ROUND_DOWN` (truncation), matching IBM mainframe COBOL behavior.
- IEEE 754 floating-point is never used for financial values.
- Custom JSON serialization converts Decimal to string representation, preserving exact digits.
- The `compiler_config.py` module supports per-request `TRUNC` mode configuration (STD/BIN/OPT) matching IBM Enterprise COBOL compiler options.
- ARITH mode (COMPAT/EXTEND) is configurable per-request using thread-safe `contextvars.ContextVar`.

---

## 9. Threat Model

### What an Attacker Could Do

**If they compromise the host machine:**
- Read the RSA private key (`aletheia_keys/private.pem`) and forge Vault signatures. The private key is stored unencrypted on disk.
- Read the JWT secret key from the environment variable and forge authentication tokens.
- Modify or delete the `vault.db` SQLite file directly, bypassing application-level integrity checks.
- Read COBOL source code processed during active requests (in-memory, but accessible to a root-level attacker).

**If they compromise the network (man-in-the-middle):**
- Intercept COBOL source code and analysis results in transit if TLS is not configured upstream. Aletheia serves HTTP, not HTTPS — TLS termination is the deployer's responsibility.
- Replay or modify API requests if TLS is absent.

**If they obtain valid credentials:**
- Access all verification results and Vault contents for the authenticated user.
- Submit arbitrary COBOL for analysis (consuming license quota).
- If the compromised account is an administrator, approve other users for analysis access.
- Rate limiting restricts the blast radius: 30 requests/minute per user on engine endpoints.

**If they tamper with the Vault database:**
- Modifications are detectable via `/vault/verify-chain`, which recomputes hashes and verifies signatures.
- However, an attacker with access to both the database and the private key could forge valid signatures on modified records.
- Chain breaks (deleted or reordered records) are always detectable.

**If they submit adversarial COBOL source:**
- The ANTLR4 parser may encounter parsing errors, but these are caught and reported (never crash the server).
- Unrecognized constructs are flagged as MANUAL REVIEW, not silently accepted.
- The generated Python is deterministic and does not include user-controlled strings in executable positions.
- File upload size limit (10 MB) prevents resource exhaustion via oversized payloads.
- Rate limiting prevents automated abuse.

### What an Attacker Could NOT Do

**Influence verification verdicts remotely:** The verification pipeline is deterministic and runs locally. There is no external service that could be compromised to alter verdicts. No AI model, cloud API, or external dependency participates in correctness decisions.

**Exfiltrate data via the application in air-gapped mode:** There are no outbound network calls. No DNS, no HTTPS, no telemetry. Data leaves only through the HTTP response to the local client.

**Forge Vault records without the private key:** RSA-PSS signatures are computationally infeasible to forge without the 2048-bit private key.

**Bypass license enforcement without the master private key:** License files are verified against an embedded public key. Creating a valid license requires the master private key, which is held offline and never shipped.

**Silently insert or reorder Vault records:** The hash chain links each record to its predecessor. Insertion, deletion, or reordering breaks the chain and is detected by `/vault/verify-chain`.

**Brute-force the login endpoint:** Rate limiting (5 requests/minute per IP) makes credential stuffing impractical. After 5 failed attempts, the attacker must wait 60 seconds before the next attempt.

---

## 10. Dependency Audit

### Pinned Dependencies

All dependencies are version-pinned in `requirements.txt` for reproducible builds. The following table lists each dependency, its purpose, and security assessment as of March 2026.

| Package | Version | Purpose | Security Notes |
|---------|---------|---------|---------------|
| `fastapi` | 0.128.2 | Web framework | Active maintenance, regular security patches |
| `uvicorn[standard]` | 0.40.0 | ASGI server | Production-grade, no known CVEs at pinned version |
| `pydantic` | 2.12.5 | Data validation | Input validation layer, actively maintained |
| `python-multipart` | 0.0.22 | File upload parsing | Required by FastAPI for file uploads |
| `python-dotenv` | 1.2.1 | Environment variable loading | Dev convenience, no security surface |
| `python-jose[cryptography]` | 3.5.0 | JWT encoding/decoding | Uses `cryptography` backend (not native-python) |
| `cryptography` | >=43.0.0 | RSA, SHA-256, PBKDF2 | Core crypto library, pinned to recent major version |
| `passlib[bcrypt]` | 1.7.4 | Password hashing (PBKDF2-SHA256) | Stable, NIST-compliant, no known CVEs |
| `bcrypt` | 5.0.0 | Password hashing backend | Rust-based implementation, actively maintained |
| `antlr4-python3-runtime` | 4.13.2 | COBOL parser runtime | Parser-only, no network/crypto surface |
| `networkx` | 3.6.1 | Dependency graph analysis | Graph algorithms only, no network/IO |
| `openai` | 2.17.0 | LLM API client (optional) | Only used in connected mode; disabled by default |
| `sqlalchemy[asyncio]` | 2.0.25 | Database ORM | Parameterized queries prevent SQL injection |
| `asyncpg` | 0.29.0 | PostgreSQL async driver | Production database driver |
| `alembic` | 1.13.1 | Database migrations | Schema management, no runtime security surface |
| `aiosqlite` | 0.19.0 | SQLite async driver | Local database driver for Vault |
| `greenlet` | 3.0.3 | Async/coroutine support | Required by SQLAlchemy async |
| `aiosmtplib` | 2.0.2 | Email sending (optional) | Only used if email notifications configured |

### Key Security Observations

1. **`cryptography>=43.0.0`** — The minimum version constraint ensures recent security patches. The `cryptography` package is the most security-critical dependency and receives frequent updates for CVE remediation.

2. **`python-jose` 3.5.0** — This package has had historical CVEs related to algorithm confusion attacks. Aletheia mitigates this by explicitly specifying `HS256` and using the `cryptography` backend (not the vulnerable `native-python` backend).

3. **No `eval()`/`exec()` in dependencies** — None of the listed dependencies use `eval()` or `exec()` on user-supplied input. The only `exec()` usage is in Aletheia's own Shadow Diff engine on deterministically generated code (see Section 4).

4. **Minimal attack surface** — 10 of 17 packages are pure application logic (framework, ORM, parser) with no cryptographic or network security surface.

### Planned Improvements

- **Automated vulnerability scanning:** Integration of Dependabot or Snyk into the CI pipeline to flag CVEs in pinned dependencies.
- **SBOM generation:** The `/engine/generate-sbom` endpoint already produces a Software Bill of Materials. Automated SBOM-to-CVE cross-referencing is planned.

---

## 11. Penetration Testing Status

### Current State

**Aletheia has not undergone a third-party penetration test.** This is acknowledged as a gap and is a planned milestone before production deployment at customer sites.

### Internal Security Review

The following internal security measures have been performed:

| Assessment | Status | Scope |
|-----------|--------|-------|
| OWASP Top 10 code review | Performed internally | All HTTP endpoints, input validation, auth flows |
| SQL injection review | Mitigated | SQLAlchemy parameterized queries throughout |
| XSS review | Not applicable | API-only backend, no server-rendered HTML |
| CSRF review | Mitigated | JWT Bearer token auth (not cookie-based) |
| Authentication bypass review | Performed | Token verification on all protected endpoints |
| File upload abuse review | Mitigated | 10 MB size limit, content-type validation |
| Rate limiting verification | Implemented | Login (5/min/IP), engine (30/min/user) |
| Dependency audit | Performed | All 17 packages reviewed (see Section 10) |

### What Has NOT Been Tested

- **Adversarial fuzzing** of the ANTLR4 COBOL parser with malformed inputs
- **Memory safety** analysis of the Cython-compiled binaries
- **Container escape** testing in the Docker deployment
- **Side-channel attacks** on the cryptographic operations
- **Social engineering** vectors (phishing, credential theft)

### Planned

1. **Pre-GA penetration test** by an independent security firm, scoped to: authentication, authorization, input validation, API abuse, and container security.
2. **SAST integration** (Bandit for Python, Semgrep) in the CI pipeline.
3. **DAST integration** (OWASP ZAP) for automated API security scanning.
4. **Parser fuzzing** using AFL or similar tools against the ANTLR4 COBOL grammar.

---

## 12. Known Limitations

Transparency builds trust. The following limitations are acknowledged and documented honestly.

### Cryptographic

- **No HSM integration.** Private keys are stored as PEM files on disk, not in a Hardware Security Module. For banking deployments, HSM-backed key storage (AWS CloudHSM, Azure Dedicated HSM, or on-premises Thales/Entrust) is strongly recommended. This is a planned feature.
- **No automated key rotation.** Key rotation is manual. There is no key expiry enforcement, no automated rollover, and no certificate revocation list (CRL) or OCSP equivalent.
- **HS256 JWT signing.** The JWT secret is a symmetric key shared between all application instances. RS256 (asymmetric) would be more appropriate for multi-instance deployments. Migration to RS256 is planned.
- **Unencrypted private key storage.** The report signing private key (`private.pem`) has no passphrase protection. Filesystem permissions are the only access control.

### Access Control

- **Role-based access control is incomplete.** The `role` field exists on user records, but granular per-endpoint role enforcement is not fully implemented. Currently, the primary access control is the binary `is_approved` flag.
- **No multi-factor authentication (MFA).** Authentication relies solely on username/password + JWT. TOTP or hardware key (FIDO2/WebAuthn) support is not implemented.
- **No session revocation.** There is no token blacklist or forced logout mechanism. A compromised token remains valid until expiry (default: 7 days).

### Code Execution

- **No OS-level sandbox for exec().** Generated Python is executed via `exec()` in an isolated namespace but within the same OS process. See Section 4 for full analysis and roadmap.
- **No restricted builtins.** The execution namespace has access to Python's full built-in scope. Planned: restrict `__builtins__` to a safe subset.

### Operational

- **No penetration test.** See Section 11 for full status and planned timeline.
- **No SAST/DAST in CI.** Static and dynamic application security testing are not integrated into the build pipeline. Planned for pre-GA.
- **HTTP only.** The application serves HTTP. TLS must be configured externally. There is no built-in certificate management.
- **SQLite limitations.** The Vault uses SQLite, which does not support row-level encryption, fine-grained access control, or concurrent write scaling. For multi-user production deployments, migration to PostgreSQL with TDE (Transparent Data Encryption) is recommended.
- **In-memory rate limiting.** Rate limit counters are per-process. Multi-instance deployments behind a load balancer require an external rate limiting layer (Redis, API gateway).
- **No backup/restore tooling.** Vault backup and disaster recovery procedures are the deployer's responsibility.

### Verification Scope

- **Not all COBOL constructs are supported.** Certain constructs (EVALUATE ALSO, ALTER, GO TO DEPENDING ON, complex STRING/UNSTRING variants) are flagged as MANUAL REVIEW rather than verified. The full support matrix is documented in the project's CLAUDE.md.
- **Verification is behavioral, not formal.** Aletheia proves behavioral equivalence under test inputs, not mathematical equivalence for all possible inputs. The strength of the verification is bounded by the quality and coverage of the test data.

---

## 13. Contact

**Security Inquiries**

For security-related questions, vulnerability reports, or compliance documentation requests:

- **Email:** security@aletheia.dev
- **Response SLA:** Security inquiries receive a response within 48 hours.

**Vulnerability Disclosure**

Aletheia follows a responsible disclosure policy. If you discover a security vulnerability:

1. Do not publicly disclose the vulnerability before it has been addressed.
2. Email security@aletheia.dev with a detailed description, reproduction steps, and potential impact assessment.
3. We will acknowledge receipt within 48 hours and provide a remediation timeline within 5 business days.

**Documentation**

- Product documentation: Available upon request.
- API specification: OpenAPI/Swagger at `/docs` when the application is running.
- Source code audit: Available under NDA for enterprise customers.

---

*This document describes the security architecture of Aletheia as of March 2026 (v2.0). It is updated with each major release. The most current version is maintained alongside the product source code.*

*Aletheia is a product of Aletheia Technologies. All cryptographic claims in this document are verifiable against the open-source components of the codebase.*
