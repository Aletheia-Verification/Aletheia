# Aletheia — Privacy Policy

**DRAFT — Subject to revision by customer legal counsel**

Effective Date: [DATE]
Last Updated: March 2026

---

## 1. Introduction

This Privacy Policy describes how Aletheia Technologies ("Provider," "we," "us") handles data when you use the Aletheia Behavioral Verification Engine ("Service"). We are committed to protecting the confidentiality of your data, particularly given the sensitive nature of banking and financial services code.

## 2. Data We Process

### 2.1. COBOL Source Code and Copybooks

- **Purpose**: Parsed and analyzed to generate Verification Models for behavioral comparison.
- **Retention**: Processed in-memory during analysis. **Not stored permanently** unless the Customer explicitly enables vault storage.
- **Air-gapped mode**: Source code never leaves the Customer's network. The Provider has zero access.
- **Connected mode**: Source code is **not** sent to any external API. Only non-sensitive analysis metadata (construct counts, paragraph names) may be sent to OpenAI for explanation formatting, if enabled.

### 2.2. Mainframe Output Data

- **Purpose**: Used by Shadow Diff for field-by-field comparison against Verification Model output.
- **Retention**: Processed in-memory during comparison. Stored only in the local vault if Customer enables vault persistence.
- **Sensitivity**: May contain financial transaction data. Handled with the same protections as source code.

### 2.3. Verification Results

- **Purpose**: Audit trail of all analyses performed.
- **Retention**: Stored in vault.db on Customer's infrastructure. Encrypted at rest when `VAULT_ENCRYPTION_KEY` is configured.
- **Contents**: Verification status, file hashes, arithmetic analysis, generated Python code, executive summary, cryptographic chain-of-custody (SHA-256 hash chain + RSA-PSS signatures).

### 2.4. Authentication Data

- **Purpose**: User authentication and access control.
- **Contents**: Username, corporate ID, hashed password (PBKDF2-SHA256). JWT tokens (HS256, 24-hour expiry).
- **Retention**: Stored in local database. Passwords are never stored in plaintext.
- **Transmission**: JWT secret key is configured via environment variable. No authentication data is transmitted to third parties.

### 2.5. Operational Logs

- **Purpose**: Debugging, performance monitoring, audit compliance.
- **Contents**: Timestamps, endpoint paths, usernames, error messages. **No COBOL source code or financial data** appears in logs.
- **Retention**: Managed by Customer's infrastructure (Docker logging driver, syslog, etc.).

## 3. Data We Do NOT Collect

- We do **not** collect usage analytics or telemetry. `DO_NOT_TRACK=1` is set by default.
- We do **not** collect browser fingerprints, cookies, or tracking identifiers.
- We do **not** access Customer's COBOL source code in air-gapped deployments.
- We do **not** share any Customer Data with third parties, advertisers, or data brokers.
- We do **not** use Customer Data to train machine learning models.

## 4. Air-Gapped Deployment

Aletheia supports fully air-gapped deployment for regulated environments:

- **Zero external network calls**: The Service operates entirely within the Customer's network boundary.
- **No internet required**: All parsing, generation, and verification runs locally.
- **No telemetry**: No data is transmitted to the Provider or any third party.
- **Docker isolation**: Non-root container user, no host network access required.
- **Cython-compiled binaries**: Core logic compiled to .so files; source code not accessible in the Docker image.

In air-gapped mode, this Privacy Policy is effectively moot — no data flows to the Provider.

## 5. Connected Mode (Optional)

If Customer opts into connected mode (`ALETHEIA_MODE=connected`):

- **What is sent**: Non-sensitive analysis metadata (construct types, paragraph counts, verification status) to OpenAI's GPT-4o API for human-readable explanation formatting.
- **What is NOT sent**: COBOL source code, variable names, business logic, mainframe data, or financial information.
- **OpenAI's role**: Data processor only. Subject to OpenAI's enterprise data processing agreement. OpenAI does not use API inputs for model training.
- **Customer control**: Connected mode is disabled by default. Customer explicitly enables it via environment variable.

## 6. Data Security

### 6.1. Encryption

- **At rest**: Vault fields encrypted with AES-256-GCM when `VAULT_ENCRYPTION_KEY` is configured.
- **In transit**: TLS 1.2+ recommended (via uvicorn SSL flags or reverse proxy). Not enforced by default in development.
- **Passwords**: PBKDF2-SHA256 hashing (never stored in plaintext).
- **Report signing**: RSA-PSS 2048-bit digital signatures on verification records.

### 6.2. Access Control

- **Authentication**: JWT (HS256) with configurable expiry (default 24 hours).
- **Authorization**: All engine and vault endpoints require valid JWT.
- **Rate limiting**: 5 requests/minute per IP on login (brute-force protection), 30 requests/minute per user on engine endpoints.
- **Secret management**: JWT secret and encryption key via environment variables (never hardcoded).

### 6.3. Integrity

- **Hash chain**: Each vault record links to the previous via SHA-256 chain-of-custody.
- **Record hashing**: Full-field SHA-256 hash detects tampering of any column.
- **Digital signatures**: RSA-PSS signatures on record hashes for non-repudiation.
- **Chain verification**: `/vault/verify-chain` endpoint validates the entire audit trail.

## 7. Data Retention and Deletion

7.1. **Customer controls retention.** Verification records persist in vault.db until explicitly deleted by the Customer.

7.2. **Deletion**: Individual records can be deleted via the vault API. Deletion is immediate and permanent (no soft delete).

7.3. **Export**: The full vault can be exported as JSON via `/vault/export` for backup or migration purposes.

7.4. **Post-termination**: Upon contract termination, the Customer retains their vault.db and all verification reports. The Provider has no copies of Customer Data in air-gapped deployments.

## 8. GDPR Considerations

For customers subject to the EU General Data Protection Regulation:

8.1. **Data controller**: The Customer is the data controller. The Provider is a data processor (or sub-processor if deployed on Customer's infrastructure).

8.2. **Lawful basis**: Processing is performed under the Customer's legitimate interest in verifying software migration correctness, or under contract with the Customer.

8.3. **Data minimization**: The Service processes only the data necessary for verification. No personal data is required for COBOL analysis.

8.4. **Right to erasure**: Customers can delete individual vault records or the entire vault database at any time.

8.5. **Data portability**: Vault data can be exported as JSON at any time.

8.6. **Cross-border transfers**: In air-gapped mode, no data crosses any border. In connected mode, analysis metadata may be processed by OpenAI in the United States, subject to OpenAI's data processing agreement and applicable transfer mechanisms (SCCs or adequacy decisions).

8.7. **Data Protection Impact Assessment (DPIA)**: Customers processing COBOL programs containing personal data (e.g., customer records, account numbers) should conduct a DPIA. The Service's encryption-at-rest, hash chains, and air-gapped mode support compliance with DPIA requirements.

## 9. Subprocessors

| Subprocessor | Purpose | Data Accessed | When Active |
|-------------|---------|--------------|-------------|
| OpenAI | Explanation formatting | Analysis metadata only (no source code) | Connected mode only (opt-in) |

No other subprocessors are used. In air-gapped mode, zero subprocessors are active.

## 10. Breach Notification

10.1. In the event of a data breach affecting Customer Data, Provider will notify Customer within seventy-two (72) hours of becoming aware of the breach, in accordance with GDPR Article 33.

10.2. In air-gapped deployments, the Provider cannot experience a breach of Customer Data because the Provider has no access to it. Breach notification obligations in such deployments rest with the Customer.

## 11. Children's Privacy

The Service is designed for enterprise use by business professionals. We do not knowingly collect data from individuals under the age of 16.

## 12. Changes to This Policy

We may update this Privacy Policy with thirty (30) days' notice. Material changes will be communicated via the Service interface or email. Continued use after the notice period constitutes acceptance.

## 13. Contact

For privacy-related inquiries:

- Email: [PRIVACY_EMAIL]
- Address: [COMPANY_ADDRESS]
- Data Protection Officer: [DPO_NAME] (if applicable)

---

*DRAFT DOCUMENT — NOT LEGAL ADVICE. This document should be reviewed by qualified legal counsel before execution. Bracketed items [LIKE THIS] require company-specific values.*
