# Aletheia Security Whitepaper

**Version 1.0 | March 2026**
**Classification: Public**

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Deployment Architecture](#2-deployment-architecture)
3. [Data Handling](#3-data-handling)
4. [Cryptographic Integrity](#4-cryptographic-integrity)
5. [Key Management](#5-key-management)
6. [Access Control](#6-access-control)
7. [Compliance Alignment](#7-compliance-alignment)
8. [Threat Model](#8-threat-model)
9. [Known Limitations](#9-known-limitations)
10. [Contact](#10-contact)

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

**Container configuration:**

| Parameter | Value | Notes |
|-----------|-------|-------|
| Exposed port | 8000 (HTTP) | TLS termination expected upstream (nginx, ALB, etc.) |
| Vault storage | Volume mount (`vault.db`) | SQLite file, persisted across restarts |
| Copybook library | Volume mount (`/app/copybooks`) | Customer-provided COBOL copybooks |
| License files | Read-only mount (`/app/license:ro`) | Signed license + signature |

### Network Isolation Recommendation

For production deployments in regulated environments, Aletheia should be deployed on an isolated network segment with no egress rules. The container requires no outbound connectivity. Inbound access should be restricted to authorized workstations via network policy or firewall rules. TLS 1.2+ termination should be handled by a reverse proxy (nginx, HAProxy, or cloud load balancer) in front of the container.

---

## 3. Data Handling

### Processing Model

COBOL source code submitted for analysis is processed entirely in memory within a single HTTP request lifecycle. The processing pipeline is:

1. **Upload:** COBOL source received as file upload or text payload.
2. **Preprocessing:** COPY statements resolved, REPLACING clauses applied (in-memory string operations).
3. **Parsing:** ANTLR4 lexer/parser produces an in-memory parse tree. No intermediate files are written.
4. **Generation:** Deterministic Python code generated from the parse tree. All operations use `decimal.Decimal` with 28-digit precision and `ROUND_DOWN` truncation to match IBM mainframe behavior.
5. **Analysis:** Arithmetic risk analysis, EXEC SQL/CICS detection, dependency crawling — all in-memory.
6. **Response:** JSON response returned to client. Parse tree and intermediate structures are garbage-collected.

### What the Vault Stores

The Vault (`vault.db`, SQLite) is an append-only audit trail. Each record contains:

- **Metadata:** Timestamp (ISO-8601 UTC), original filename, paragraph/variable/COMP-3 counts.
- **Hashes:** SHA-256 of the original COBOL source (`file_hash`), SHA-256 of the generated Python (`python_hash`), SHA-256 of the full report JSON (`report_hash`).
- **Verification status:** The binary verdict (VERIFIED or REQUIRES_MANUAL_REVIEW).
- **Chain linkage:** Previous record's `chain_hash` (see Section 4).
- **Cryptographic signature:** RSA-PSS signature over the record hash, plus the signing key's fingerprint.
- **Generated Python and report JSON:** Stored for reproducibility and audit.

**Important note on data retention:** The Vault does store the generated Python code and the full analysis report JSON. It also stores the original filename but hashes the COBOL source (SHA-256) rather than storing it in a separate indexed field. Organizations with strict data retention requirements should implement volume-level encryption (LUKS, BitLocker, or cloud KMS-backed encryption) on the `vault.db` mount and establish a retention/purge schedule consistent with their data governance policies.

### Shadow Diff Data

The Shadow Diff engine processes mainframe flat-file output data for field-by-field comparison. This data is streamed from disk and processed record-by-record in constant memory, enabling verification of files up to 50 GB without loading entire datasets into RAM. Shadow Diff input files are not persisted in the Vault — only the drift verdict and record-level results are stored.

---

## 4. Cryptographic Integrity

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

**Tamper detection:** A separate `record_hash` is computed as SHA-256 over all 20 non-signature columns of the database record, using a pipe separator. This detects modification of any stored field — metadata, verdicts, or hashes — independent of the chain linkage.

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

## 5. Key Management

### Report Signing Keys

Report signing keys are generated locally on the Aletheia server at first startup or on demand:

- **Algorithm:** RSA-2048
- **Public exponent:** 65537
- **Storage location:** `aletheia_keys/` directory (`private.pem`, `public.pem`)
- **Private key format:** PKCS#8, PEM-encoded, no passphrase encryption
- **Public key format:** SubjectPublicKeyInfo, PEM-encoded

**Current limitation:** Private keys are stored unencrypted on the filesystem. This is adequate for air-gapped deployments with restricted filesystem access but does not meet the standards expected for HSM-backed key management in production banking environments. See Section 9 for planned improvements.

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

**Limitation:** There is no automated key rotation mechanism, no key expiry enforcement, and no revocation list. These are planned features. See Section 9.

---

## 6. Access Control

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

### Password Storage

User passwords are hashed using PBKDF2-SHA256 (NIST SP 800-132 compliant) via the `passlib` library with automatic hash migration support. Plaintext passwords are never stored or logged.

### Authorization Model

Aletheia implements a two-tier authorization model:

1. **Authentication gate:** All API endpoints (except `/auth/login` and `/auth/register`) require a valid JWT.
2. **Approval gate:** Analysis endpoints (`/engine/analyze`, `/engine/analyze-batch`) require the user's `is_approved` flag to be set by an administrator via `/admin/approve/{corporate_id}`.

Each user record includes a `role` field. The infrastructure for role-based access control is in place, though granular per-endpoint role enforcement is not yet fully implemented (see Section 9).

### License-Based Access Control

In addition to user authentication, the license system enforces:

- **Feature gating:** License files specify an array of enabled features. Endpoints can require specific features via `require_feature()`.
- **Daily rate limits:** Each license specifies `max_analyses_per_day`. Exceeding this limit returns HTTP 429.
- **Strict mode:** Invalid or expired licenses return HTTP 403 on all `/engine/*` endpoints.
- **Grace mode:** Allows 50 analyses or 7 days of operation without a valid license, then enforces a hard block.

---

## 7. Compliance Alignment

### GDPR Article 28 (Processor Obligations)

Aletheia's architecture supports GDPR compliance for organizations acting as data processors:

- **Data minimization:** COBOL source is processed in memory and not persisted beyond the request lifecycle (the Vault stores hashes and analysis artifacts, not raw source in a searchable index).
- **Air-gapped deployment:** In the default configuration, no data leaves the deployment environment. There are no external API calls, no telemetry, and no cloud dependencies.
- **Audit trail:** The Vault provides a cryptographically signed, tamper-evident record of all processing activities, supporting the accountability requirements of Article 5(2).
- **Right to erasure:** Vault records can be purged in compliance with data retention policies. The hash chain's integrity can be maintained through tombstone records that preserve chain linkage while removing content.

**Caveat:** Aletheia itself does not implement data subject access request (DSAR) workflows or automated retention policies. These must be implemented at the organizational level.

### SOC 2 Readiness

Aletheia's design addresses several SOC 2 Trust Service Criteria:

| Criterion | Aletheia Capability |
|-----------|-------------------|
| **CC6.1** (Logical access) | JWT authentication, approval gates, license-based feature gating |
| **CC6.3** (Access removal) | User deactivation invalidates all tokens (sub claim verified against user DB) |
| **CC7.2** (System monitoring) | Vault provides immutable, signed audit trail of all verification activities |
| **CC8.1** (Change management) | Cython-compiled binaries prevent runtime code modification |
| **PI1.3** (Processing integrity) | Deterministic pipeline, Decimal arithmetic, binary verdicts, no probabilistic outputs |

**Caveat:** Aletheia has not undergone a SOC 2 audit. The above describes architectural alignment, not certified compliance. A Type II audit is a planned milestone.

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

---

## 8. Threat Model

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

**If they tamper with the Vault database:**
- Modifications are detectable via `/vault/verify-chain`, which recomputes hashes and verifies signatures.
- However, an attacker with access to both the database and the private key could forge valid signatures on modified records.
- Chain breaks (deleted or reordered records) are always detectable.

### What an Attacker Could NOT Do

**Influence verification verdicts remotely:** The verification pipeline is deterministic and runs locally. There is no external service that could be compromised to alter verdicts. No AI model, cloud API, or external dependency participates in correctness decisions.

**Exfiltrate data via the application in air-gapped mode:** There are no outbound network calls. No DNS, no HTTPS, no telemetry. Data leaves only through the HTTP response to the local client.

**Forge Vault records without the private key:** RSA-PSS signatures are computationally infeasible to forge without the 2048-bit private key.

**Bypass license enforcement without the master private key:** License files are verified against an embedded public key. Creating a valid license requires the master private key, which is held offline and never shipped.

**Silently insert or reorder Vault records:** The hash chain links each record to its predecessor. Insertion, deletion, or reordering breaks the chain and is detected by `/vault/verify-chain`.

---

## 9. Known Limitations

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
- **Default JWT secret.** The application ships with a default `JWT_SECRET_KEY` value. Deployers must override this via environment variable. The application does not enforce this at startup.

### Operational

- **No penetration test.** Aletheia has not been subjected to a third-party penetration test. This is a planned milestone before production deployment at customer sites.
- **No SAST/DAST in CI.** Static and dynamic application security testing are not integrated into the build pipeline.
- **No rate limiting beyond license quotas.** There is no per-IP or per-endpoint rate limiting to prevent brute-force attacks on the login endpoint.
- **HTTP only.** The application serves HTTP. TLS must be configured externally. There is no built-in certificate management.
- **SQLite limitations.** The Vault uses SQLite, which does not support row-level encryption, fine-grained access control, or concurrent write scaling. For multi-user production deployments, migration to PostgreSQL with TDE (Transparent Data Encryption) is recommended.
- **No backup/restore tooling.** Vault backup and disaster recovery procedures are the deployer's responsibility.

### Verification Scope

- **Not all COBOL constructs are supported.** Certain constructs (EVALUATE ALSO, ALTER, GO TO DEPENDING ON, complex STRING/UNSTRING variants) are flagged as MANUAL REVIEW rather than verified. The full support matrix is documented in the project's CLAUDE.md.
- **Verification is behavioral, not formal.** Aletheia proves behavioral equivalence under test inputs, not mathematical equivalence for all possible inputs. The strength of the verification is bounded by the quality and coverage of the test data.

---

## 10. Contact

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

*This document describes the security architecture of Aletheia as of March 2026. It is updated with each major release. The most current version is maintained alongside the product source code.*

*Aletheia is a product of Aletheia Technologies. All cryptographic claims in this document are verifiable against the open-source components of the codebase.*
