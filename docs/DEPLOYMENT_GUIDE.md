# ALETHEIA Deployment Guide

Version 3.2.0 | Behavioral Verification Engine

---

## 1. Prerequisites

| Component | Minimum Version | Purpose |
|-----------|----------------|---------|
| Python | 3.12+ | Backend runtime |
| Node.js | 18+ | Frontend build |
| Docker | 24+ | Container deployment |
| Docker Compose | v2+ | Multi-service orchestration |

For manual (non-Docker) deployment, Python and Node.js are required directly on the host.

---

## 2. Quick Start (Docker)

```bash
# 1. Generate a JWT secret
export JWT_SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")

# 2. Build the frontend (required before Docker build)
cd frontend && npm ci && npm run build && cd ..

# 3. Build and run
docker compose up --build
```

The application is available at `http://localhost:8000`.

Default mode is **air-gapped** — no external API calls, no internet required.

---

## 3. Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `JWT_SECRET_KEY` | **Yes** | *(none)* | HS256 signing key for JWT tokens (24h expiry) |
| `ALETHEIA_MODE` | No | `air-gapped` | `air-gapped` (no LLM calls) or `connected` (GPT-4o for explanations) |
| `OPENAI_API_KEY` | No | *(empty)* | Required only if `ALETHEIA_MODE=connected` |
| `DATABASE_URL` | No | *(in-memory)* | PostgreSQL: `postgresql+asyncpg://user:pass@host:5432/aletheia` |
| `USE_IN_MEMORY_DB` | No | `false` | `true` for testing (in-memory store, no persistence) |
| `ALETHEIA_LICENSE_MODE` | No | `strict` | `strict` (hard block without license) or `grace` (warn, 50 analyses, 7-day limit) |
| `ALETHEIA_LICENSE_DIR` | No | `./license` | Path to directory containing `license.json` + `license.sig` |
| `MAX_FILE_SIZE_MB` | No | `10` | Maximum COBOL file upload size in MB |
| `LOG_LEVEL` | No | `INFO` | Python logging level: `DEBUG`, `INFO`, `WARNING`, `ERROR` |
| `SMTP_USER` | No | *(empty)* | SMTP sender address for email notifications |
| `SMTP_PASSWORD` | No | *(empty)* | SMTP password or app-specific token |
| `JWT_TOKEN_LIFETIME_HOURS` | No | `24` | JWT token expiry in hours |
| `PYTHONUNBUFFERED` | No | `1` | Real-time stdout/stderr (set in Dockerfile) |
| `DO_NOT_TRACK` | No | `1` | Disables all telemetry (set in Dockerfile) |
| `SIGNING_KEY_PASSPHRASE` | No | *(empty)* | Passphrase to encrypt/decrypt RSA private key PEM |
| `CUSTOMER_SIGNING_KEY` | No | *(empty)* | Path to customer-provided RSA private key PEM. If set, overrides auto-generated keys in `aletheia_keys/`. Public key is extracted from the private key. |
| `ALETHEIA_CORS_ORIGINS` | No | *(localhost dev ports)* | Comma-separated allowed origins for CORS. Overrides default localhost list. Example: `https://app.example.com,https://admin.example.com` |
| `ALETHEIA_ACCEPT_DATE` | No | *(zeros)* | Fixed date for COBOL `ACCEPT FROM DATE` in YYYYMMDD format (e.g. `20260322`). If unset, date/time fields default to zeros. |
| `ALETHEIA_EXEC_MODE` | No | `subprocess` | Execution mode for generated Python: `subprocess` (production, sandboxed) or `inline` (tests only, faster). |

**Generate a secure JWT secret:**
```bash
python3 -c "import secrets; print(secrets.token_hex(32))"
```

**Example `.env` file:**
```bash
JWT_SECRET_KEY=your-secret-key-change-in-production
ALETHEIA_MODE=air-gapped
DATABASE_URL=postgresql+asyncpg://postgres:password@localhost:5432/aletheia
USE_IN_MEMORY_DB=false
ALETHEIA_LICENSE_MODE=grace
LOG_LEVEL=INFO
MAX_FILE_SIZE_MB=10
ALETHEIA_CORS_ORIGINS=https://app.example.com
```

---

## 3.1 Timeouts

| Layer | Default | Notes |
|-------|---------|-------|
| Uvicorn keep-alive | 300s | Idle connection timeout. Set in `uvicorn.run()`. Prevents drops during long batch analyses. |
| Shadow Diff per-record exec | 5s | Per-record execution timeout in `execute_generated_python()`. |
| Shadow Diff I/O program exec | 30s | Single-program execution timeout in `execute_io_program()`. |
| Reverse proxy (nginx/ALB) | Varies | Configure upstream timeout ≥ 300s to match keep-alive. |

For large batch jobs (500+ programs), ensure your reverse proxy timeout exceeds the expected batch duration. A 500-program batch at ~0.5s/program takes ~4 minutes.

---

## 4. Docker Deployment

### 4.1 Main Image (`aletheia:latest`)

Two-stage build: Stage 1 compiles 18 core Python modules to `.so` via Cython for IP protection. Stage 2 copies only compiled binaries + frontend assets into a clean runtime image.

**Build:**
```bash
# Linux/macOS
./scripts/build.sh

# Windows (PowerShell)
.\scripts\build.ps1
```

Both scripts verify 20 required source files exist, build the frontend, then run `docker build`.

**Run:**
```bash
# Air-gapped (default)
docker run -p 8000:8000 \
  -e JWT_SECRET_KEY=your-secret \
  -v ./vault.db:/app/vault.db \
  aletheia:latest

# Connected mode (GPT-4o explanations enabled)
docker run -p 8000:8000 \
  -e JWT_SECRET_KEY=your-secret \
  -e ALETHEIA_MODE=connected \
  -e OPENAI_API_KEY=sk-... \
  -v ./vault.db:/app/vault.db \
  aletheia:latest
```

### 4.2 Gatekeeper Image (`aletheia-gatekeeper`)

Headless CI/CD image — engine + CLI only, no frontend, no web server.

**Build:**
```bash
docker build -f docker/Dockerfile.gatekeeper -t aletheia-gatekeeper .
```

**Run:**
```bash
docker run --rm \
  -v $(pwd):/data \
  aletheia-gatekeeper \
    --source /data/program.cbl \
    --input /data/input.dat \
    --output /data/output.dat
```

**Exit codes:**
| Code | Meaning |
|------|---------|
| `0` | VERIFIED (zero drift) |
| `1` | DRIFT DETECTED or REQUIRES_MANUAL_REVIEW |
| `2` | ERROR (missing file, parse failure) |

### 4.3 Docker Compose

```bash
# Create vault.db if it doesn't exist
touch vault.db

# Start (air-gapped)
JWT_SECRET_KEY=your-secret docker compose up

# Start (connected mode)
ALETHEIA_MODE=connected OPENAI_API_KEY=sk-... JWT_SECRET_KEY=your-secret docker compose up
```

**Volumes managed by docker-compose.yml:**

| Mount | Type | Purpose |
|-------|------|---------|
| `./vault.db:/app/vault.db` | Bind mount | SQLite audit trail — persists verification records |
| `copybook-lib:/app/copybooks` | Named volume | COBOL copybook library (uploaded via API) |
| `./license:/app/license:ro` | Bind mount (optional) | License files for strict mode |

---

## 5. Manual Deployment (No Docker)

### 5.1 Backend

```bash
# Create virtual environment
python3.12 -m venv venv
source venv/bin/activate    # Linux/macOS
# venv\Scripts\activate     # Windows

# Install dependencies
pip install -r requirements.txt

# Set environment
export JWT_SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")
export ALETHEIA_MODE=air-gapped

# Start server
uvicorn core_logic:app --host 0.0.0.0 --port 8000
```

### 5.2 Frontend

```bash
cd frontend
npm ci
npm run build    # Production build → frontend/dist/
cd ..
```

The FastAPI backend serves the built frontend from `frontend/dist/` automatically.

For development with hot reload:
```bash
cd frontend
npm run dev      # Dev server on port 5173, proxies API to :8000
```

### 5.3 Windows

```powershell
# Use full paths for venv
"venv\Scripts\python.exe" -m uvicorn core_logic:app --host 0.0.0.0 --port 8000
```

---

## 6. Air-Gapped Deployment

Air-gapped mode is the **default**. No internet connectivity required.

- `ALETHEIA_MODE=air-gapped` (or unset — defaults to air-gapped)
- LLM explanation endpoints return offline stubs
- All COBOL analysis, Python generation, and behavioral verification run deterministically with zero external calls
- No telemetry: `DO_NOT_TRACK=1` set in Dockerfile

This is the recommended mode for bank environments with network restrictions.

---

## 7. Connected Mode

Enables GPT-4o for formatting English explanations of analysis results. The LLM is **never** used for correctness — all verification verdicts are deterministic.

```bash
export ALETHEIA_MODE=connected
export OPENAI_API_KEY=sk-...
```

If the OpenAI API is unreachable, the system falls back to offline stubs silently.

---

## 8. TLS/HTTPS

### Option A: uvicorn with TLS

```bash
uvicorn core_logic:app --host 0.0.0.0 --port 443 \
    --ssl-keyfile /path/to/privkey.pem \
    --ssl-certfile /path/to/fullchain.pem
```

### Option B: Reverse Proxy (Recommended)

Run uvicorn on `127.0.0.1:8000` behind a reverse proxy that terminates TLS:

- **nginx**: `proxy_pass http://127.0.0.1:8000;`
- **Caddy**: automatic HTTPS with Let's Encrypt
- **AWS ALB / Azure Application Gateway**: target group on port 8000

This is the recommended approach for production — the reverse proxy handles TLS certificates, connection pooling, and static asset caching.

---

## 9. Database

### SQLite (Default)

The audit trail is stored in `vault.db` (SQLite). No additional database setup required.

- Location: project root (or `/app/vault.db` in Docker)
- Backup: copy the file while the server is stopped, or use `sqlite3 .backup`
- Mount in Docker: `-v ./vault.db:/app/vault.db`

### PostgreSQL (Optional)

For production with multiple workers or high concurrency:

```bash
export DATABASE_URL=postgresql+asyncpg://user:password@localhost:5432/aletheia
```

Alembic migrations run automatically on startup. Migration scripts are in `alembic/`.

---

## 10. Health Checks

Two unauthenticated endpoints for load balancers and monitoring:

### GET /api/health

```json
{
  "status": "ok",
  "version": "3.2.0"
}
```

### GET /api/v1/heartbeat

```json
{
  "status": "alive",
  "engine": "v3.2.0-zero-error",
  "timestamp_utc": "2026-03-18T12:00:00Z",
  "decimal_precision": 28
}
```

**Load balancer configuration:**
- Health check path: `/api/health`
- Expected status: `200`
- Interval: 30s
- Timeout: 5s
- Unhealthy threshold: 3

---

## 11. Rate Limiting

Built-in sliding-window rate limiter (in-memory, no external dependencies):

| Endpoint | Limit | Key | Purpose |
|----------|-------|-----|---------|
| `/auth/login` | 5 req/min | Client IP | Brute-force protection |
| `/engine/*` | 30 req/min | Authenticated user | Abuse prevention |

When exceeded, the API returns `429 Too Many Requests` with a `retry-after` header indicating seconds until the window resets.

---

## 12. License System

Aletheia uses RSA-PSS signed license files for enterprise deployment.

### Files Required

- `license/license.json` — license metadata (customer, expiry, features, limits)
- `license/license.sig` — RSA-PSS signature

### Modes

| Mode | Behavior |
|------|----------|
| `strict` | All `/engine/*` endpoints return 403 without a valid license |
| `grace` | Engine works with warnings. Limited to 50 analyses, 7-day expiry after first use |

### Docker Volume Mount

```bash
docker run -p 8000:8000 \
  -e ALETHEIA_LICENSE_MODE=strict \
  -v ./license:/app/license:ro \
  aletheia:latest
```

The license directory is mounted read-only (`:ro`). The private signing key is never included in the container — only the embedded public key is used for validation.

---

## 13. CLI Reference

The CLI (`aletheia_cli.py`, invoked via `cli_entry.py`) provides headless batch automation without HTTP.

```bash
# Analyze a single COBOL file
python cli_entry.py analyze program.cbl \
  --compiler-trunc STD \
  --output json

# Batch analysis (directory)
python cli_entry.py analyze-batch ./cobol_programs/ \
  --recursive \
  --output-dir ./results

# Full behavioral verification (COBOL + Shadow Diff)
python cli_entry.py verify \
  --source program.cbl \
  --input input.dat \
  --output mainframe_output.dat \
  --layout layout.json

# Shadow Diff only
python cli_entry.py shadow-diff \
  --layout layout.json \
  --input input.dat \
  --expected output.dat \
  --python generated.py

# Dependency tree
python cli_entry.py dependency ./cobol_programs/ --analyze

# Export audit trail
python cli_entry.py export-vault --format json --output vault_export.json

# Verify report signature
python cli_entry.py verify-signature report.json

# Version
python cli_entry.py version
```

**Docker CLI usage:**
```bash
docker run --rm aletheia:latest python cli_entry.py analyze /app/DEMO_LOAN_INTEREST.cbl
```

---

## 14. CI/CD Integration (Gatekeeper)

### Jenkins

```groovy
stage('Behavioral Verification') {
    steps {
        sh '''
            docker run --rm \
                -v ${WORKSPACE}:/data \
                aletheia-gatekeeper \
                    --source /data/src/${COBOL_PROGRAM}.cbl \
                    --input /data/testdata/${COBOL_PROGRAM}_input.dat \
                    --output /data/testdata/${COBOL_PROGRAM}_output.dat
        '''
    }
}
```

### GitLab CI

```yaml
behavioral-verification:
    stage: test
    image: aletheia-gatekeeper
    script:
        - python cli_entry.py verify
            --source src/LOAN_INTEREST.cbl
            --input testdata/LOAN_INTEREST_input.dat
            --output testdata/LOAN_INTEREST_output.dat
```

### GitHub Actions

```yaml
- name: Behavioral Verification
  run: |
    docker run --rm \
      -v ${{ github.workspace }}:/data \
      aletheia-gatekeeper \
        --source /data/src/LOAN_INTEREST.cbl \
        --input /data/testdata/LOAN_INTEREST_input.dat \
        --output /data/testdata/LOAN_INTEREST_output.dat
```

**Exit codes:** `0` = VERIFIED, `1` = DRIFT/MANUAL_REVIEW, `2` = ERROR.

---

## 15. Logging

Aletheia uses Python's `logging` module throughout (zero `print()` calls). All log entries include timestamps.

**Configure log level:**
```bash
export LOG_LEVEL=DEBUG    # DEBUG, INFO, WARNING, ERROR
```

**Docker logs:**
```bash
# Follow logs
docker compose logs -f aletheia

# Last 100 lines
docker logs <container_id> --tail 100
```

`PYTHONUNBUFFERED=1` is set by default in the Dockerfile, ensuring real-time log output without buffering.

---

## 16. Production Checklist

- [ ] Generate and set `JWT_SECRET_KEY` (never commit to git)
- [ ] Set `ALETHEIA_MODE` (`air-gapped` for bank environments)
- [ ] Configure TLS via reverse proxy or uvicorn flags
- [ ] Create `vault.db`: `touch vault.db` before first run
- [ ] Mount license files if using `ALETHEIA_LICENSE_MODE=strict`
- [ ] Set `DATABASE_URL` for PostgreSQL (optional, for multi-worker setups)
- [ ] Configure Docker restart policy: `restart: unless-stopped`
- [ ] Point load balancer health check to `GET /api/health`
- [ ] Set up log collection (Docker logging driver or syslog)
- [ ] Verify non-root execution: container runs as `appuser`

---

## 17. Troubleshooting

### JWT_SECRET_KEY not set
**Symptom:** Container exits immediately or 500 errors on login.
**Fix:** Set `JWT_SECRET_KEY` environment variable. Generate one with:
```bash
python3 -c "import secrets; print(secrets.token_hex(32))"
```

### vault.db not found
**Symptom:** Audit trail writes fail, 500 errors on vault operations.
**Fix:** Create the file before starting: `touch vault.db`. In Docker, ensure the bind mount exists: `-v ./vault.db:/app/vault.db`.

### License validation fails (403 on /engine/*)
**Symptom:** All engine endpoints return 403 Forbidden.
**Fix:** Either mount valid license files (`-v ./license:/app/license:ro`) or switch to grace mode (`ALETHEIA_LICENSE_MODE=grace`).

### Connected mode returns stubs
**Symptom:** Explanations are placeholder text instead of GPT-4o output.
**Fix:** Verify `ALETHEIA_MODE=connected` and `OPENAI_API_KEY` is set and valid. The system silently falls back to offline stubs if the API is unreachable.

### Rate limited (429 Too Many Requests)
**Symptom:** API returns 429 after rapid requests.
**Fix:** Wait for the sliding window to clear (60 seconds). Login: 5 req/min per IP. Engine: 30 req/min per user.

### Frontend not loading
**Symptom:** Browser shows blank page or 404 on `/`.
**Fix:** Ensure frontend was built before Docker build: `cd frontend && npm ci && npm run build`. The `frontend/dist/` directory must exist.

### ANTLR4 parse errors
**Symptom:** Analysis returns `parse_errors > 0` and REQUIRES_MANUAL_REVIEW.
**Fix:** This is expected for some COBOL constructs. The engine flags unsupported patterns as MANUAL REVIEW rather than producing incorrect output. Check the analysis response for specific construct details.

---

## Appendix: Ports

| Port | Protocol | Service |
|------|----------|---------|
| 8000 | HTTP | uvicorn (FastAPI + frontend SPA) |
| 443 | HTTPS | Optional — via uvicorn TLS or reverse proxy |
| 5432 | TCP | PostgreSQL (if configured via DATABASE_URL) |

## Appendix: Docker Image Contents

**Compiled to `.so` (IP protected):**
core_logic, vault, shadow_diff, ebcdic_utils, copybook_resolver, cobol_analyzer_api, generate_full_python, parse_conditions, compiler_config, cobol_types, exec_sql_parser, dependency_crawler, report_signing, aletheia_cli, abend_handler, ANTLR4 lexer/parser/listener

**Readable `.py` in final image:**
license_manager.py, auditor_pipeline.py, email_service.py, database.py, models.py, cli_entry.py

**Assets:**
frontend/dist/ (React SPA), demo_data/, alembic/, DEMO_LOAN_INTEREST.cbl, sbom.json
