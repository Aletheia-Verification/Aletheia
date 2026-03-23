"""
security_scan.py — OWASP-style security self-assessment for Aletheia.

Probes all endpoints for:
  A. Auth bypass (missing/invalid token → 401)
  B. SQL injection (payloads in string fields → no 500)
  C. Path traversal (../../ in paths → no file leak)
  D. XSS reflection (script tags in inputs → not echoed raw)
  E. Rate limiting (burst → 429)
  F. CORS header validation

Run:  "venv\\Scripts\\python.exe" scripts/security_scan.py
Output: security_scan_report.md
"""

import asyncio
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

# Ensure project root is on path and DB is in-memory
PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))
os.environ["USE_IN_MEMORY_DB"] = "1"

from httpx import AsyncClient, ASGITransport  # noqa: E402

from core_logic import (  # noqa: E402
    app,
    create_access_token,
    login_limiter,
    engine_limiter,
    password_hasher,
    users_db,
)

# ── Endpoint catalog ────────────────────────────────────────────────
# (method, path, auth_required, sample_body_or_None)

ENDPOINTS = [
    # Public
    ("GET",  "/api/health",              False, None),
    ("GET",  "/api/v1/heartbeat",        False, None),
    ("POST", "/auth/login",              False, {"username": "x", "password": "x"}),
    ("POST", "/auth/register",           False, {"username": "scanuser", "password": "Str0ng!",
                                                  "institution": "Scan Corp", "city": "Zurich",
                                                  "country": "CH", "role": "Tester"}),
    ("GET",  "/verify/public-key",       False, None),
    ("GET",  "/license/status",          False, None),
    # Auth required
    ("GET",  "/auth/profile",            True,  None),
    ("POST", "/engine/analyze",          True,  {"cobol_code": "IDENTIFICATION DIVISION."}),
    ("POST", "/engine/analyze-batch",    True,  {"programs": []}),
    ("POST", "/engine/verify-full",      True,  {"cobol_code": "IDENTIFICATION DIVISION."}),
    ("POST", "/engine/compiler-matrix",  True,  {"cobol_code": "IDENTIFICATION DIVISION."}),
    ("POST", "/engine/risk-heatmap",     True,  {"programs": []}),
    ("POST", "/engine/trace-compare",    True,  {"cobol_code": "x", "trace_a": [], "trace_b": []}),
    ("POST", "/engine/generate-layout",  True,  {"cobol_code": "IDENTIFICATION DIVISION."}),
    ("POST", "/engine/parse-jcl",        True,  {"jcl_text": "//JOB"}),
    ("POST", "/engine/generate-sbom",    True,  {"cobol_code": "IDENTIFICATION DIVISION."}),
    ("POST", "/engine/generate-poison-pills", True, {"cobol_code": "IDENTIFICATION DIVISION."}),
    ("POST", "/engine/run-poison-pills", True,  {"cobol_code": "x", "test_cases": []}),
    ("GET",  "/vault",                   True,  None),
    ("POST", "/analyze",                 True,  {"cobol_code": "IDENTIFICATION DIVISION."}),
    ("GET",  "/analytics",               True,  None),
    ("POST", "/chat",                    True,  {"message": "hello", "context": ""}),
    ("POST", "/parse",                   True,  {"cobol_code": "IDENTIFICATION DIVISION."}),
    ("POST", "/generate",               True,  {"cobol_code": "IDENTIFICATION DIVISION."}),
    # Satellite routers
    ("GET",  "/vault/list",              True,  None),
    ("POST", "/vault/verify-chain",      True,  None),
    ("GET",  "/vault/export",            True,  None),
    ("POST", "/license/reload",          True,  None),
    ("GET",  "/audit/log",               True,  None),
    ("GET",  "/copybook/list",           True,  None),
    ("POST", "/copybook/preprocess",     True,  {"source": "x", "copybook_dirs": []}),
    ("POST", "/dependency/analyze",      True,  {"programs": {}}),
    ("POST", "/dependency/upload",       True,  None),
    ("POST", "/dependency/tree",         True,  {"programs": {}}),
    ("GET",  "/config/compiler",         True,  None),
]

SQL_PAYLOADS = [
    "' OR '1'='1",
    "'; DROP TABLE users;--",
    '" OR ""="',
    "1; SELECT * FROM users",
    "1 UNION SELECT username,password FROM users--",
]

PATH_TRAVERSAL_PAYLOADS = [
    "../../etc/passwd",
    "..\\..\\windows\\system32\\config\\sam",
    "....//....//etc/passwd",
    "%2e%2e%2f%2e%2e%2fetc%2fpasswd",
    "..%252f..%252fetc%252fpasswd",
]

XSS_PAYLOADS = [
    '<script>alert("XSS")</script>',
    '<img src=x onerror=alert(1)>',
    'javascript:alert(document.cookie)',
    '"><svg onload=alert(1)>',
]


# ── Helpers ─────────────────────────────────────────────────────────

def _setup_test_user():
    """Seed an approved admin user for authenticated requests."""
    users_db.clear()
    users_db["admin"] = {
        "password": password_hasher.hash("Admin!234"),
        "institution": "Aletheia QA",
        "city": "London",
        "country": "UK",
        "role": "Security Scan",
        "is_approved": True,
        "security_history": [],
    }


def _get_token() -> str:
    return create_access_token({"sub": "admin"})


def _reset_limiters():
    login_limiter.reset()
    engine_limiter.reset()


async def _request(client, method, path, body=None, headers=None):
    """Fire a request and return (status_code, response_body_text, content_type)."""
    kw = {"headers": headers or {}}
    if method == "POST":
        if body is not None:
            resp = await client.post(path, json=body, **kw)
        else:
            resp = await client.post(path, **kw)
    elif method == "GET":
        resp = await client.get(path, **kw)
    elif method == "DELETE":
        resp = await client.delete(path, **kw)
    else:
        resp = await client.request(method, path, **kw)
    ct = resp.headers.get("content-type", "")
    return resp.status_code, resp.text, ct


# ── Result collector ────────────────────────────────────────────────

class ScanResults:
    def __init__(self):
        self.categories: dict[str, list[dict]] = {}

    def add(self, category: str, endpoint: str, test: str,
            result: str, detail: str = ""):
        self.categories.setdefault(category, [])
        self.categories[category].append({
            "endpoint": endpoint,
            "test": test,
            "result": result,
            "detail": detail,
        })

    def summary(self) -> dict[str, dict[str, int]]:
        out = {}
        for cat, items in self.categories.items():
            counts = {"PASS": 0, "FAIL": 0, "WARN": 0}
            for item in items:
                counts[item["result"]] = counts.get(item["result"], 0) + 1
            counts["total"] = len(items)
            out[cat] = counts
        return out


# ── Category A: Auth Bypass ─────────────────────────────────────────

async def scan_auth_bypass(client: AsyncClient, results: ScanResults):
    """Every auth-required endpoint must return 401 without a valid token."""
    cat = "Auth Bypass"

    for method, path, auth_required, body in ENDPOINTS:
        if auth_required:
            # No token at all
            status, text, _ = await _request(client, method, path, body)
            if status == 401:
                results.add(cat, f"{method} {path}", "No token → 401", "PASS")
            else:
                results.add(cat, f"{method} {path}", "No token → 401", "FAIL",
                            f"Got {status}")

            _reset_limiters()

            # Garbage token
            bad_headers = {"Authorization": "Bearer garbage.token.here"}
            status, text, _ = await _request(client, method, path, body, bad_headers)
            if status == 401:
                results.add(cat, f"{method} {path}", "Bad token → 401", "PASS")
            else:
                results.add(cat, f"{method} {path}", "Bad token → 401", "FAIL",
                            f"Got {status}")

            _reset_limiters()

        else:
            # Public endpoints should be reachable without a token.
            # /auth/login returns 401 for wrong credentials — that's the
            # login flow itself, NOT a JWT-auth gate, so it counts as
            # reachable (public).
            status, text, _ = await _request(client, method, path, body)
            is_login_401 = (path == "/auth/login" and status == 401)
            if status != 401 or is_login_401:
                results.add(cat, f"{method} {path}", "Public (no 401)", "PASS",
                            f"Got {status}")
            else:
                results.add(cat, f"{method} {path}", "Public (no 401)", "FAIL",
                            "Got 401 on public endpoint")

            _reset_limiters()


# ── Category B: SQL Injection ───────────────────────────────────────

async def scan_sql_injection(client: AsyncClient, token: str,
                             results: ScanResults):
    """Inject SQL payloads in string fields — no 500 allowed."""
    cat = "SQL Injection"
    auth = {"Authorization": f"Bearer {token}"}

    # Targets: endpoints with string body fields
    injection_targets = [
        ("POST", "/engine/analyze", "cobol_code"),
        ("POST", "/engine/parse-jcl", "jcl_text"),
        ("POST", "/engine/generate-sbom", "cobol_code"),
        ("POST", "/parse", "cobol_code"),
        ("POST", "/generate", "cobol_code"),
        ("POST", "/chat", "message"),
    ]

    for method, path, field in injection_targets:
        for payload in SQL_PAYLOADS:
            body = {field: payload}
            # Add required fields for specific endpoints
            if path == "/chat":
                body["context"] = ""
            status, text, _ = await _request(client, method, path, body, auth)
            _reset_limiters()

            if status == 500:
                results.add(cat, f"{method} {path}", f"SQLi in {field}",
                            "FAIL", f"500 with payload: {payload[:30]}")
            elif "syntax error" in text.lower() or "sql" in text.lower():
                results.add(cat, f"{method} {path}", f"SQLi in {field}",
                            "WARN", f"SQL-related text in response: {payload[:30]}")
            else:
                results.add(cat, f"{method} {path}", f"SQLi in {field}",
                            "PASS", f"Got {status}")

    # Login endpoint (unauthenticated)
    for payload in SQL_PAYLOADS:
        body = {"username": payload, "password": payload}
        status, text, _ = await _request(client, "POST", "/auth/login", body)
        _reset_limiters()

        if status == 500:
            results.add(cat, "POST /auth/login", "SQLi in credentials",
                        "FAIL", f"500 with payload: {payload[:30]}")
        else:
            results.add(cat, "POST /auth/login", "SQLi in credentials",
                        "PASS", f"Got {status}")


# ── Category C: Path Traversal ──────────────────────────────────────

async def scan_path_traversal(client: AsyncClient, token: str,
                              results: ScanResults):
    """Inject traversal sequences in path parameters — no file content leak."""
    cat = "Path Traversal"
    auth = {"Authorization": f"Bearer {token}"}

    path_targets = [
        ("/demo-data/{}", False),
        ("/copybook/{}", True),
        ("/vault/record/{}", True),
        ("/shadow-diff/report/{}", True),
    ]

    # Real file content markers — NOT generic HTML (SPA fallback serves
    # index.html for unknown routes, which is expected, not a leak).
    sensitive_markers = [
        "root:x:0:",            # /etc/passwd
        "[boot loader]",        # Windows boot.ini
        "SAM\\Domains",         # Windows SAM hive
        "[extensions]",         # Windows system.ini
    ]

    for url_template, needs_auth in path_targets:
        headers = auth if needs_auth else {}
        for payload in PATH_TRAVERSAL_PAYLOADS:
            url = url_template.format(payload)
            status, text, ct = await _request(client, "GET", url, headers=headers)
            _reset_limiters()

            leaked = any(marker in text for marker in sensitive_markers)
            if status == 500:
                results.add(cat, f"GET {url_template}", "Traversal",
                            "FAIL", f"500 with: {payload}")
            elif leaked:
                results.add(cat, f"GET {url_template}", "Traversal",
                            "FAIL", f"File content leaked with: {payload}")
            elif status in (400, 401, 403, 404, 422):
                results.add(cat, f"GET {url_template}", "Traversal",
                            "PASS", f"Got {status}")
            elif status == 200 and "text/html" in ct:
                # SPA catch-all returning index.html — not a real traversal
                results.add(cat, f"GET {url_template}", "Traversal",
                            "PASS", f"SPA fallback (HTML), no file leak")
            else:
                results.add(cat, f"GET {url_template}", "Traversal",
                            "WARN", f"Unexpected {status} with: {payload}")


# ── Category D: XSS ─────────────────────────────────────────────────

async def scan_xss(client: AsyncClient, token: str, results: ScanResults):
    """Inject XSS payloads — response must not echo them unescaped."""
    cat = "XSS Reflection"
    auth = {"Authorization": f"Bearer {token}"}

    xss_targets = [
        ("POST", "/engine/analyze", {"cobol_code": ""}, "cobol_code"),
        ("POST", "/parse", {"cobol_code": ""}, "cobol_code"),
        ("POST", "/chat", {"message": "", "context": ""}, "message"),
        ("POST", "/engine/parse-jcl", {"jcl_text": ""}, "jcl_text"),
    ]

    for method, path, template, field in xss_targets:
        for payload in XSS_PAYLOADS:
            body = dict(template)
            body[field] = payload
            status, text, ct = await _request(client, method, path, body, auth)
            _reset_limiters()

            # Only a real XSS risk if the response is HTML and reflects
            # the payload unescaped.  JSON APIs naturally include input
            # text in error messages — that's not exploitable XSS.
            is_html = "text/html" in ct
            if payload in text and is_html:
                results.add(cat, f"{method} {path}", f"XSS in {field}",
                            "FAIL", f"HTML response reflects payload: {payload[:30]}")
            elif status == 500:
                results.add(cat, f"{method} {path}", f"XSS in {field}",
                            "FAIL", f"500 with XSS payload")
            else:
                results.add(cat, f"{method} {path}", f"XSS in {field}",
                            "PASS", f"Got {status}, safe ({ct.split(';')[0]})")

    # Registration endpoint (unauthenticated)
    for payload in XSS_PAYLOADS:
        body = {
            "username": f"xss_{hash(payload) % 9999}",
            "password": "Str0ng!Pass",
            "institution": payload,
            "city": payload,
            "country": "XX",
            "role": "Tester",
        }
        status, text, ct = await _request(client, "POST", "/auth/register", body)
        _reset_limiters()

        if status == 500:
            results.add(cat, "POST /auth/register", "XSS in registration",
                        "FAIL", f"500 with XSS payload")
        else:
            results.add(cat, "POST /auth/register", "XSS in registration",
                        "PASS", f"Got {status}")


# ── Category E: Rate Limiting ───────────────────────────────────────

async def scan_rate_limiting(client: AsyncClient, token: str,
                             results: ScanResults):
    """Verify rate limits actually block after threshold."""
    cat = "Rate Limiting"
    _reset_limiters()

    # Login: 5/min per IP
    blocked = False
    for i in range(7):
        status, text, _ = await _request(
            client, "POST", "/auth/login",
            {"username": "nobody", "password": "wrong"},
        )
        if status == 429:
            blocked = True
            break

    if blocked:
        results.add(cat, "POST /auth/login", "Login rate limit (5/min)",
                    "PASS", f"Blocked at request #{i + 1}")
    else:
        results.add(cat, "POST /auth/login", "Login rate limit (5/min)",
                    "FAIL", "Never got 429 after 7 requests")

    _reset_limiters()

    # Engine: 30/min per user
    auth = {"Authorization": f"Bearer {token}"}
    blocked = False
    for i in range(33):
        status, text, _ = await _request(
            client, "POST", "/engine/analyze",
            {"cobol_code": "IDENTIFICATION DIVISION."},
            auth,
        )
        if status == 429:
            blocked = True
            break

    if blocked:
        results.add(cat, "POST /engine/analyze", "Engine rate limit (30/min)",
                    "PASS", f"Blocked at request #{i + 1}")
    else:
        results.add(cat, "POST /engine/analyze", "Engine rate limit (30/min)",
                    "FAIL", "Never got 429 after 33 requests")

    _reset_limiters()

    # Verify 429 response format
    for _ in range(6):
        await _request(client, "POST", "/auth/login",
                       {"username": "x", "password": "x"})
    status, text, _ = await _request(client, "POST", "/auth/login",
                                     {"username": "x", "password": "x"})
    if status == 429 and "Rate limit exceeded" in text:
        results.add(cat, "POST /auth/login", "429 response format",
                    "PASS", "Contains 'Rate limit exceeded'")
    elif status == 429:
        results.add(cat, "POST /auth/login", "429 response format",
                    "WARN", f"429 but unexpected body: {text[:80]}")
    else:
        results.add(cat, "POST /auth/login", "429 response format",
                    "FAIL", f"Expected 429, got {status}")

    _reset_limiters()


# ── Category F: CORS Headers ───────────────────────────────────────

async def scan_cors(client: AsyncClient, results: ScanResults):
    """Verify CORS allows legitimate origins and blocks unknown ones."""
    cat = "CORS Headers"

    # Allowed origin
    resp = await client.options(
        "/api/health",
        headers={
            "Origin": "http://localhost:5173",
            "Access-Control-Request-Method": "GET",
        },
    )
    acao = resp.headers.get("access-control-allow-origin", "")
    if acao == "http://localhost:5173":
        results.add(cat, "OPTIONS /api/health", "Allowed origin reflected",
                    "PASS")
    else:
        results.add(cat, "OPTIONS /api/health", "Allowed origin reflected",
                    "FAIL", f"ACAO header: {acao!r}")

    # Credentials header
    acac = resp.headers.get("access-control-allow-credentials", "")
    if acac.lower() == "true":
        results.add(cat, "OPTIONS /api/health", "Allow-Credentials: true",
                    "PASS")
    else:
        results.add(cat, "OPTIONS /api/health", "Allow-Credentials: true",
                    "FAIL", f"Got: {acac!r}")

    # Evil origin must NOT be reflected
    resp = await client.options(
        "/api/health",
        headers={
            "Origin": "https://evil.com",
            "Access-Control-Request-Method": "GET",
        },
    )
    acao = resp.headers.get("access-control-allow-origin", "")
    if acao == "" or acao != "https://evil.com":
        results.add(cat, "OPTIONS /api/health", "Evil origin blocked",
                    "PASS", f"ACAO: {acao!r}")
    else:
        results.add(cat, "OPTIONS /api/health", "Evil origin blocked",
                    "FAIL", "Evil origin reflected in ACAO")

    # Another allowed origin (127.0.0.1 variant)
    resp = await client.get(
        "/api/health",
        headers={"Origin": "http://127.0.0.1:5173"},
    )
    acao = resp.headers.get("access-control-allow-origin", "")
    if acao == "http://127.0.0.1:5173":
        results.add(cat, "GET /api/health", "127.0.0.1 origin allowed",
                    "PASS")
    else:
        results.add(cat, "GET /api/health", "127.0.0.1 origin allowed",
                    "FAIL", f"ACAO: {acao!r}")


# ── Report Writer ───────────────────────────────────────────────────

def write_report(results: ScanResults):
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    lines = [
        "# Aletheia Security Self-Assessment Report",
        f"Generated: {ts}",
        "",
        "## Summary",
        "",
        "| Category | Passed | Failed | Warnings | Total |",
        "|----------|--------|--------|----------|-------|",
    ]

    summary = results.summary()
    total_pass = total_fail = total_warn = total_total = 0
    for cat, counts in summary.items():
        lines.append(
            f"| {cat} | {counts['PASS']} | {counts['FAIL']} | "
            f"{counts['WARN']} | {counts['total']} |"
        )
        total_pass += counts["PASS"]
        total_fail += counts["FAIL"]
        total_warn += counts["WARN"]
        total_total += counts["total"]

    lines.append(
        f"| **TOTAL** | **{total_pass}** | **{total_fail}** | "
        f"**{total_warn}** | **{total_total}** |"
    )
    lines.append("")

    if total_fail == 0:
        lines.append("> **VERDICT: ALL CHECKS PASSED**")
    else:
        lines.append(f"> **VERDICT: {total_fail} FAILURE(S) REQUIRE ATTENTION**")
    lines.append("")

    # Detailed findings
    lines.append("## Detailed Findings")
    lines.append("")

    for cat, items in results.categories.items():
        lines.append(f"### {cat}")
        lines.append("")
        lines.append("| # | Endpoint | Test | Result | Detail |")
        lines.append("|---|----------|------|--------|--------|")
        for i, item in enumerate(items, 1):
            detail = item["detail"].replace("|", "\\|")[:80] if item["detail"] else ""
            lines.append(
                f"| {i} | `{item['endpoint']}` | {item['test']} | "
                f"**{item['result']}** | {detail} |"
            )
        lines.append("")

    report_path = PROJECT_ROOT / "security_scan_report.md"
    report_path.write_text("\n".join(lines), encoding="utf-8")
    return report_path


# ── Main ────────────────────────────────────────────────────────────

async def run_scan():
    _setup_test_user()
    token = _get_token()
    results = ScanResults()

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://scan") as client:
        print("[1/6] Auth Bypass ...")
        await scan_auth_bypass(client, results)

        print("[2/6] SQL Injection ...")
        _setup_test_user()
        await scan_sql_injection(client, token, results)

        print("[3/6] Path Traversal ...")
        _setup_test_user()
        await scan_path_traversal(client, token, results)

        print("[4/6] XSS Reflection ...")
        _setup_test_user()
        await scan_xss(client, token, results)

        print("[5/6] Rate Limiting ...")
        _setup_test_user()
        await scan_rate_limiting(client, token, results)

        print("[6/6] CORS Headers ...")
        await scan_cors(client, results)

    report_path = write_report(results)

    summary = results.summary()
    total_fail = sum(c["FAIL"] for c in summary.values())
    total_pass = sum(c["PASS"] for c in summary.values())
    total_warn = sum(c["WARN"] for c in summary.values())

    print()
    print(f"Done. {total_pass} passed, {total_fail} failed, {total_warn} warnings.")
    print(f"Report: {report_path}")

    return total_fail


def main():
    failures = asyncio.run(run_scan())
    sys.exit(1 if failures > 0 else 0)


if __name__ == "__main__":
    main()
