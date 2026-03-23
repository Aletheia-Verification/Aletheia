# Pre-Launch Audit — 2026-03-20

26 source files, ~10,800 lines, line-by-line. **55 findings: 5 critical, 8 high, 30 medium, 12 low.**

---

## CRITICAL

| # | File:Line | Issue | Fix |
|---|-----------|-------|-----|
| C1 | core_logic.py:2526 | `AnalysisSession.username` doesn't exist — model has `user_id`. Crashes in DB mode. | Filter by `user_id` after user lookup. |
| C2 | report_signing.py:186 | `sign_report(None, None)` → KeyError on `verification_chain["chain_hash"]`. | Guard both params, raise ValueError. |
| C3 | license_manager.py:170 | `_GRACE_COUNTER.count += 1` not thread-safe — concurrent requests bypass limit. | Add `threading.Lock`. |
| C4 | report_signing.py:64-69 | Private key saved with `NoEncryption()` — disk compromise = forged reports. | Encrypt with env-var passphrase or enforce 0o600. |
| C5 | cobol_types.py:38 | `pattern.index(')')` on malformed PIC `Z(4` — unhandled ValueError crashes analysis. | try/except ValueError, return pattern as-is. |

## HIGH

| # | File:Line | Issue | Fix |
|---|-----------|-------|-----|
| H1 | core_logic.py:210-219 | JWT secret falls back to random key silently. Tokens die on restart. | Hard-fail in production if `JWT_SECRET_KEY` unset. |
| H2 | shadow_diff.py:554 | `exec()` in-process — no CPU/memory limits. Infinite loop = server hang. | Default to subprocess mode with timeout. |
| H3 | vault.py:37 | Invalid `VAULT_ENCRYPTION_KEY` base64 → `binascii.Error` at import, cryptic crash. | try/except with clear message. |
| H4 | vault.py:286-289 | SQL columns via f-string. Validated at import but fragile for future edits. | Use constant query strings. |
| H5 | dead_code_analyzer.py:68-81 | PERFORM THRU needs `len(targets) >= 2` but single THRU creates 1 entry. Never fires. | Detect from single entry with `from`+`to`. |
| H6 | generate_full_python.py:1014 | `except (IndexError, KeyError)` eats error — no logging, root cause lost. | `logger.exception()` + error type in comment. |
| H7 | layout_generator.py:200 | VALUE regex misses negatives (`VALUE -100`). Minus dropped silently. | `r'VALUE\s*(-?[\d.]+)'` |
| H8 | layout_generator.py:475-507 | FD-to-record heuristic breaks on multiple FDs or interleaved defs. | Match by record name explicitly. |

## MEDIUM

| # | File:Line | Issue |
|---|-----------|-------|
| M1 | core_logic.py:726-730 | `verify_token()` rejects deleted users with generic 401 instead of "user deleted". |
| M2 | core_logic.py:738-749 | `except Exception` in token verify catches memory/DB errors — masks real failures. |
| M3 | core_logic.py:1609 | `auth.split()[-1]` breaks on malformed Authorization headers. |
| M4 | core_logic.py:1688-1689 | `LogicExtractionService()` global singleton — state leak risk. |
| M5 | core_logic.py:2698-2703 | `/parse` returns output without checking success — no 400 on errors. |
| M6 | core_logic.py:2746-2774 | `/generate` catches all Exception — memory errors returned as "failed". |
| M7 | core_logic.py:3165-3181 | Empty `input_mapping={}`/`output_fields=[]` pass validation → downstream crash. |
| M8 | parse_conditions.py:418-428 | 88-level subscript regex fails on nested parens `COND(VAR(IDX))`. |
| M9 | cobol_types.py:167 | Redundant truncation condition — `abs(raw) // 1` check adds nothing. |
| M10 | cobol_types.py:889-890 | PIC V99 (`pic_integers=0`): `_max_int=1` but max integer part is 0 — wrong truncation. |
| M11 | shadow_diff.py:276 | Unknown field type kills entire stream instead of per-record error. |
| M12 | cobol_file_io.py:238-243 | PIC X reset to `""` not spaces — breaks fixed-width layouts. |
| M13 | cobol_analyzer_api.py:673-675 | ODO `min > max` not validated — silently creates invalid table. |
| M14 | copybook_resolver.py:310 | `PIC X(00)` produces length 0 — no positive-length validation. |
| M15 | copybook_resolver.py:428-431 | Forward REDEFINES hard-errors but GnuCOBOL allows them — too strict. |
| M16 | vault.py:52 | Encryption silently off when key unset — plaintext data, log-only warning. |
| M17 | vault.py:68-70 | Decrypt slices `raw[:12]` without length check — corrupted data → cryptic error. |
| M18 | vault.py:189 | Malformed chain JSON falls back to genesis silently — corruption undetected. |
| M19 | report_signing.py:118 | `sort_keys=True` only top-level — nested dict order may vary, breaking hashes. |
| M20 | report_signing.py:154-165 | `\|` separator in hash — **ACCEPTED RISK**. Requires attacker control of both `filename` AND `executive_summary` to forge collision. Breaking existing chain verification to change format is higher risk than the theoretical attack. Documented for future hardening if threat model changes. |
| M21 | license_manager.py:140 | Timezone-naive `expires_str` vs aware `datetime.now(UTC)` → TypeError. |
| M22 | license_manager.py:192 | Daily count reset by wall-clock date — NTP backward jump skips reset. |
| M23 | abend_handler.py:91 | Empty `raw_bytes` passes `all(0xFF)` (vacuous truth) → ValueError on empty Decimal. |
| M24 | abend_handler.py:271 | `zfill` doesn't truncate oversize values — `digit_str[-1]` takes wrong digit. |
| M25 | exec_sql_parser.py:42 | INTO regex stops at first FROM — fails on nested subqueries. |
| M26 | dependency_crawler.py:207-209 | Cycle detection via unbounded recursion — deep trees hit stack limit. |
| M27 | dependency_crawler.py:102 | 500-char lookahead — long USING clauses silently truncated. |
| M28 | aletheia_cli.py:278 | UTF-8 hardcoded — EBCDIC source files crash on open. |
| M29 | aletheia_cli.py:513/403 | Binary vs text mode inconsistency across commands. |
| M30 | jcl_parser.py:373-394 | Dependency graph ignores COND-based conditional execution. |

## LOW

| # | File:Line | Issue |
|---|-----------|-------|
| L1 | shadow_diff.py:61-65 | `_auth_dep()` dead code — never called. |
| L2 | generate_full_python.py:2993,3629 | TODO comments in production (POINTER, AT END incomplete). |
| L3 | cobol_analyzer_api.py:1884 | `float('inf')` for line boundary — use `sys.maxsize`. |
| L4 | cobol_types.py:87 | `_scale_factor` name misleading — it's a divisor. |
| L5 | compiler_config.py:59 | Unknown kwargs → generic TypeError — typos hard to debug. |
| L6 | ebcdic_utils.py:100 | `ebcdic_equal` not lambda-wrapped like other comparators. |
| L7 | vault.py:153 | Redundant assert inside already-filtered loop. |
| L8 | sbom_generator.py:51-64 | Table names not uppercased before blacklist check. |
| L9 | audit_logger.py:63 | `_init_db()` at import time — fragile in concurrent tests. |
| L10 | poison_pill_generator.py:228 | Empty `enriched_fields` → `max()` on empty seq → ValueError. |
| L11 | aletheia_cli.py:305 | Import inside exception handler — move to top. |
| L12 | exec_sql_parser.py:182-184 | Redundant `var not in seen_used` checked twice. |

---

## Systemic Issues

1. **Exception swallowing** — `except Exception` with no `logger.exception()` across cobol_analyzer_api, generate_full_python, parse_conditions, core_logic, shadow_diff. Production debugging blind.
2. **None-handling gaps** — `.get()` without defaults, then methods called on result. One missing key → cascade AttributeError.
3. **No input size limits** — `analyze_cobol()`, `parse_fixed_width()` accept unbounded input. Multi-GB upload = OOM.

## Security Rejects

1. Unencrypted signing key on disk (report_signing.py:64)
2. `exec()` in-process without isolation (shadow_diff.py:554)
3. JWT secret auto-generated in prod (core_logic.py:210)
4. Vault encryption silently off (vault.py:52)
5. SQL via f-string (vault.py:286)

## Would Break on Real Bank Programs

1. Nested subscripts `FIELD(VAR(IDX))` → malformed Python
2. PIC V99 truncation wrong
3. Negative VALUE constants dropped
4. PERFORM THRU ranges missed
5. Long CALL USING truncated at 500 chars
6. EBCDIC files crash CLI

## Missing Constructs

EVALUATE ALSO, INSPECT CONVERTING, SEARCH (no VARYING), GO TO DEPENDING ON, ODO runtime, REWRITE/READ KEY, WRITE ADVANCING, Level 78 constants, COPY pseudo-text `==old== BY ==new==`.

## Fix Order

C1 → C5 → C2 → H1 → H7 → H5 → C3 → H3 → H6 → rest by severity.
