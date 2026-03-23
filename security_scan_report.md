# Aletheia Security Self-Assessment Report
Generated: 2026-03-21 16:33:29 UTC

## Summary

| Category | Passed | Failed | Warnings | Total |
|----------|--------|--------|----------|-------|
| Auth Bypass | 64 | 0 | 0 | 64 |
| SQL Injection | 35 | 0 | 0 | 35 |
| Path Traversal | 20 | 0 | 0 | 20 |
| XSS Reflection | 20 | 0 | 0 | 20 |
| Rate Limiting | 3 | 0 | 0 | 3 |
| CORS Headers | 4 | 0 | 0 | 4 |
| **TOTAL** | **146** | **0** | **0** | **146** |

> **VERDICT: ALL CHECKS PASSED**

## Detailed Findings

### Auth Bypass

| # | Endpoint | Test | Result | Detail |
|---|----------|------|--------|--------|
| 1 | `GET /api/health` | Public (no 401) | **PASS** | Got 200 |
| 2 | `GET /api/v1/heartbeat` | Public (no 401) | **PASS** | Got 200 |
| 3 | `POST /auth/login` | Public (no 401) | **PASS** | Got 401 |
| 4 | `POST /auth/register` | Public (no 401) | **PASS** | Got 400 |
| 5 | `GET /verify/public-key` | Public (no 401) | **PASS** | Got 200 |
| 6 | `GET /license/status` | Public (no 401) | **PASS** | Got 200 |
| 7 | `GET /auth/profile` | No token → 401 | **PASS** |  |
| 8 | `GET /auth/profile` | Bad token → 401 | **PASS** |  |
| 9 | `POST /engine/analyze` | No token → 401 | **PASS** |  |
| 10 | `POST /engine/analyze` | Bad token → 401 | **PASS** |  |
| 11 | `POST /engine/analyze-batch` | No token → 401 | **PASS** |  |
| 12 | `POST /engine/analyze-batch` | Bad token → 401 | **PASS** |  |
| 13 | `POST /engine/verify-full` | No token → 401 | **PASS** |  |
| 14 | `POST /engine/verify-full` | Bad token → 401 | **PASS** |  |
| 15 | `POST /engine/compiler-matrix` | No token → 401 | **PASS** |  |
| 16 | `POST /engine/compiler-matrix` | Bad token → 401 | **PASS** |  |
| 17 | `POST /engine/risk-heatmap` | No token → 401 | **PASS** |  |
| 18 | `POST /engine/risk-heatmap` | Bad token → 401 | **PASS** |  |
| 19 | `POST /engine/trace-compare` | No token → 401 | **PASS** |  |
| 20 | `POST /engine/trace-compare` | Bad token → 401 | **PASS** |  |
| 21 | `POST /engine/generate-layout` | No token → 401 | **PASS** |  |
| 22 | `POST /engine/generate-layout` | Bad token → 401 | **PASS** |  |
| 23 | `POST /engine/parse-jcl` | No token → 401 | **PASS** |  |
| 24 | `POST /engine/parse-jcl` | Bad token → 401 | **PASS** |  |
| 25 | `POST /engine/generate-sbom` | No token → 401 | **PASS** |  |
| 26 | `POST /engine/generate-sbom` | Bad token → 401 | **PASS** |  |
| 27 | `POST /engine/generate-poison-pills` | No token → 401 | **PASS** |  |
| 28 | `POST /engine/generate-poison-pills` | Bad token → 401 | **PASS** |  |
| 29 | `POST /engine/run-poison-pills` | No token → 401 | **PASS** |  |
| 30 | `POST /engine/run-poison-pills` | Bad token → 401 | **PASS** |  |
| 31 | `GET /vault` | No token → 401 | **PASS** |  |
| 32 | `GET /vault` | Bad token → 401 | **PASS** |  |
| 33 | `POST /analyze` | No token → 401 | **PASS** |  |
| 34 | `POST /analyze` | Bad token → 401 | **PASS** |  |
| 35 | `GET /analytics` | No token → 401 | **PASS** |  |
| 36 | `GET /analytics` | Bad token → 401 | **PASS** |  |
| 37 | `POST /chat` | No token → 401 | **PASS** |  |
| 38 | `POST /chat` | Bad token → 401 | **PASS** |  |
| 39 | `POST /parse` | No token → 401 | **PASS** |  |
| 40 | `POST /parse` | Bad token → 401 | **PASS** |  |
| 41 | `POST /generate` | No token → 401 | **PASS** |  |
| 42 | `POST /generate` | Bad token → 401 | **PASS** |  |
| 43 | `GET /vault/list` | No token → 401 | **PASS** |  |
| 44 | `GET /vault/list` | Bad token → 401 | **PASS** |  |
| 45 | `POST /vault/verify-chain` | No token → 401 | **PASS** |  |
| 46 | `POST /vault/verify-chain` | Bad token → 401 | **PASS** |  |
| 47 | `GET /vault/export` | No token → 401 | **PASS** |  |
| 48 | `GET /vault/export` | Bad token → 401 | **PASS** |  |
| 49 | `POST /license/reload` | No token → 401 | **PASS** |  |
| 50 | `POST /license/reload` | Bad token → 401 | **PASS** |  |
| 51 | `GET /audit/log` | No token → 401 | **PASS** |  |
| 52 | `GET /audit/log` | Bad token → 401 | **PASS** |  |
| 53 | `GET /copybook/list` | No token → 401 | **PASS** |  |
| 54 | `GET /copybook/list` | Bad token → 401 | **PASS** |  |
| 55 | `POST /copybook/preprocess` | No token → 401 | **PASS** |  |
| 56 | `POST /copybook/preprocess` | Bad token → 401 | **PASS** |  |
| 57 | `POST /dependency/analyze` | No token → 401 | **PASS** |  |
| 58 | `POST /dependency/analyze` | Bad token → 401 | **PASS** |  |
| 59 | `POST /dependency/upload` | No token → 401 | **PASS** |  |
| 60 | `POST /dependency/upload` | Bad token → 401 | **PASS** |  |
| 61 | `POST /dependency/tree` | No token → 401 | **PASS** |  |
| 62 | `POST /dependency/tree` | Bad token → 401 | **PASS** |  |
| 63 | `GET /config/compiler` | No token → 401 | **PASS** |  |
| 64 | `GET /config/compiler` | Bad token → 401 | **PASS** |  |

### SQL Injection

| # | Endpoint | Test | Result | Detail |
|---|----------|------|--------|--------|
| 1 | `POST /engine/analyze` | SQLi in cobol_code | **PASS** | Got 403 |
| 2 | `POST /engine/analyze` | SQLi in cobol_code | **PASS** | Got 403 |
| 3 | `POST /engine/analyze` | SQLi in cobol_code | **PASS** | Got 403 |
| 4 | `POST /engine/analyze` | SQLi in cobol_code | **PASS** | Got 403 |
| 5 | `POST /engine/analyze` | SQLi in cobol_code | **PASS** | Got 403 |
| 6 | `POST /engine/parse-jcl` | SQLi in jcl_text | **PASS** | Got 200 |
| 7 | `POST /engine/parse-jcl` | SQLi in jcl_text | **PASS** | Got 200 |
| 8 | `POST /engine/parse-jcl` | SQLi in jcl_text | **PASS** | Got 200 |
| 9 | `POST /engine/parse-jcl` | SQLi in jcl_text | **PASS** | Got 200 |
| 10 | `POST /engine/parse-jcl` | SQLi in jcl_text | **PASS** | Got 200 |
| 11 | `POST /engine/generate-sbom` | SQLi in cobol_code | **PASS** | Got 400 |
| 12 | `POST /engine/generate-sbom` | SQLi in cobol_code | **PASS** | Got 400 |
| 13 | `POST /engine/generate-sbom` | SQLi in cobol_code | **PASS** | Got 400 |
| 14 | `POST /engine/generate-sbom` | SQLi in cobol_code | **PASS** | Got 400 |
| 15 | `POST /engine/generate-sbom` | SQLi in cobol_code | **PASS** | Got 400 |
| 16 | `POST /parse` | SQLi in cobol_code | **PASS** | Got 200 |
| 17 | `POST /parse` | SQLi in cobol_code | **PASS** | Got 200 |
| 18 | `POST /parse` | SQLi in cobol_code | **PASS** | Got 200 |
| 19 | `POST /parse` | SQLi in cobol_code | **PASS** | Got 200 |
| 20 | `POST /parse` | SQLi in cobol_code | **PASS** | Got 200 |
| 21 | `POST /generate` | SQLi in cobol_code | **PASS** | Got 200 |
| 22 | `POST /generate` | SQLi in cobol_code | **PASS** | Got 200 |
| 23 | `POST /generate` | SQLi in cobol_code | **PASS** | Got 200 |
| 24 | `POST /generate` | SQLi in cobol_code | **PASS** | Got 200 |
| 25 | `POST /generate` | SQLi in cobol_code | **PASS** | Got 200 |
| 26 | `POST /chat` | SQLi in message | **PASS** | Got 422 |
| 27 | `POST /chat` | SQLi in message | **PASS** | Got 422 |
| 28 | `POST /chat` | SQLi in message | **PASS** | Got 422 |
| 29 | `POST /chat` | SQLi in message | **PASS** | Got 422 |
| 30 | `POST /chat` | SQLi in message | **PASS** | Got 422 |
| 31 | `POST /auth/login` | SQLi in credentials | **PASS** | Got 401 |
| 32 | `POST /auth/login` | SQLi in credentials | **PASS** | Got 401 |
| 33 | `POST /auth/login` | SQLi in credentials | **PASS** | Got 401 |
| 34 | `POST /auth/login` | SQLi in credentials | **PASS** | Got 401 |
| 35 | `POST /auth/login` | SQLi in credentials | **PASS** | Got 401 |

### Path Traversal

| # | Endpoint | Test | Result | Detail |
|---|----------|------|--------|--------|
| 1 | `GET /demo-data/{}` | Traversal | **PASS** | SPA fallback (HTML), no file leak |
| 2 | `GET /demo-data/{}` | Traversal | **PASS** | Got 404 |
| 3 | `GET /demo-data/{}` | Traversal | **PASS** | SPA fallback (HTML), no file leak |
| 4 | `GET /demo-data/{}` | Traversal | **PASS** | SPA fallback (HTML), no file leak |
| 5 | `GET /demo-data/{}` | Traversal | **PASS** | Got 404 |
| 6 | `GET /copybook/{}` | Traversal | **PASS** | SPA fallback (HTML), no file leak |
| 7 | `GET /copybook/{}` | Traversal | **PASS** | Got 404 |
| 8 | `GET /copybook/{}` | Traversal | **PASS** | SPA fallback (HTML), no file leak |
| 9 | `GET /copybook/{}` | Traversal | **PASS** | SPA fallback (HTML), no file leak |
| 10 | `GET /copybook/{}` | Traversal | **PASS** | Got 404 |
| 11 | `GET /vault/record/{}` | Traversal | **PASS** | SPA fallback (HTML), no file leak |
| 12 | `GET /vault/record/{}` | Traversal | **PASS** | Got 422 |
| 13 | `GET /vault/record/{}` | Traversal | **PASS** | SPA fallback (HTML), no file leak |
| 14 | `GET /vault/record/{}` | Traversal | **PASS** | SPA fallback (HTML), no file leak |
| 15 | `GET /vault/record/{}` | Traversal | **PASS** | Got 422 |
| 16 | `GET /shadow-diff/report/{}` | Traversal | **PASS** | SPA fallback (HTML), no file leak |
| 17 | `GET /shadow-diff/report/{}` | Traversal | **PASS** | Got 422 |
| 18 | `GET /shadow-diff/report/{}` | Traversal | **PASS** | SPA fallback (HTML), no file leak |
| 19 | `GET /shadow-diff/report/{}` | Traversal | **PASS** | SPA fallback (HTML), no file leak |
| 20 | `GET /shadow-diff/report/{}` | Traversal | **PASS** | Got 422 |

### XSS Reflection

| # | Endpoint | Test | Result | Detail |
|---|----------|------|--------|--------|
| 1 | `POST /engine/analyze` | XSS in cobol_code | **PASS** | Got 403, safe (application/json) |
| 2 | `POST /engine/analyze` | XSS in cobol_code | **PASS** | Got 403, safe (application/json) |
| 3 | `POST /engine/analyze` | XSS in cobol_code | **PASS** | Got 403, safe (application/json) |
| 4 | `POST /engine/analyze` | XSS in cobol_code | **PASS** | Got 403, safe (application/json) |
| 5 | `POST /parse` | XSS in cobol_code | **PASS** | Got 200, safe (application/json) |
| 6 | `POST /parse` | XSS in cobol_code | **PASS** | Got 200, safe (application/json) |
| 7 | `POST /parse` | XSS in cobol_code | **PASS** | Got 200, safe (application/json) |
| 8 | `POST /parse` | XSS in cobol_code | **PASS** | Got 200, safe (application/json) |
| 9 | `POST /chat` | XSS in message | **PASS** | Got 422, safe (application/json) |
| 10 | `POST /chat` | XSS in message | **PASS** | Got 422, safe (application/json) |
| 11 | `POST /chat` | XSS in message | **PASS** | Got 422, safe (application/json) |
| 12 | `POST /chat` | XSS in message | **PASS** | Got 422, safe (application/json) |
| 13 | `POST /engine/parse-jcl` | XSS in jcl_text | **PASS** | Got 200, safe (application/json) |
| 14 | `POST /engine/parse-jcl` | XSS in jcl_text | **PASS** | Got 200, safe (application/json) |
| 15 | `POST /engine/parse-jcl` | XSS in jcl_text | **PASS** | Got 200, safe (application/json) |
| 16 | `POST /engine/parse-jcl` | XSS in jcl_text | **PASS** | Got 200, safe (application/json) |
| 17 | `POST /auth/register` | XSS in registration | **PASS** | Got 200 |
| 18 | `POST /auth/register` | XSS in registration | **PASS** | Got 200 |
| 19 | `POST /auth/register` | XSS in registration | **PASS** | Got 200 |
| 20 | `POST /auth/register` | XSS in registration | **PASS** | Got 200 |

### Rate Limiting

| # | Endpoint | Test | Result | Detail |
|---|----------|------|--------|--------|
| 1 | `POST /auth/login` | Login rate limit (5/min) | **PASS** | Blocked at request #6 |
| 2 | `POST /engine/analyze` | Engine rate limit (30/min) | **PASS** | Blocked at request #31 |
| 3 | `POST /auth/login` | 429 response format | **PASS** | Contains 'Rate limit exceeded' |

### CORS Headers

| # | Endpoint | Test | Result | Detail |
|---|----------|------|--------|--------|
| 1 | `OPTIONS /api/health` | Allowed origin reflected | **PASS** |  |
| 2 | `OPTIONS /api/health` | Allow-Credentials: true | **PASS** |  |
| 3 | `OPTIONS /api/health` | Evil origin blocked | **PASS** | ACAO: '' |
| 4 | `GET /api/health` | 127.0.0.1 origin allowed | **PASS** |  |
