# Aletheia Post-Session Code Audit

**Date:** 2026-03-19
**Scope:** 14 Python source files (non-test, non-corpus)
**Categories:** Bugs, Stale Code, Security, Inconsistencies

---

## CRITICAL (6)

### C1. cobol_types.py:107-113 — PIC P scaling descale/rescale order
**Type:** Logic Bug
The store() method applies descale → truncate → rescale for PIC P fields. When overflow occurs during truncation at the wrong scale, data is destroyed. Example: `PIC PP999` with input `999.99` → descale produces `99999000` → truncate mod 1000 → `0` → rescale → `0.00000`. Complete data loss.
**Fix:** Apply PIC constraints to the original scaled value before descaling, or validate that truncation at the descaled scale preserves the intended range.

### C2. shadow_diff.py:351-357 — exec() constants injection unsanitized
**Type:** Security
Constants dict is injected into the exec() namespace without type validation. If constants contain callables or objects with `__getattr__` overrides, they persist across the exec boundary. While constants are currently application-controlled (not user input), the pattern is dangerous.
**Fix:** Validate that all constant values are Decimal, int, str, or None before injection.

### C3. core_logic.py:2058,2099,2120,2145 — is_approved hardcoded True in login
**Type:** Auth Bypass
Login endpoint returns `"is_approved": True` unconditionally for all authenticated users. The approval gate (`/admin/approve/{corporate_id}`) sets a flag, but login ignores it. Unapproved users bypass institutional verification.
**Fix:** Return actual `user.is_approved` status from the user record, not hardcoded True.

### C4. core_logic.py:1601-1603 — Rate limiter uses JWT token as key, not username
**Type:** Rate Limit Bypass
Engine rate limiter extracts the raw JWT token via `auth.split()[-1]` and uses it as the rate limit key. An attacker with multiple valid tokens for the same user can bypass per-user rate limiting by rotating tokens.
**Fix:** Decode the JWT, extract `sub` (username), and use that as the rate limit key.

### C5. vault.py:89 — f-string in ALTER TABLE column name
**Type:** SQL Injection Pattern
`conn.execute(f"ALTER TABLE verifications ADD COLUMN {col} TEXT")` — the column list is currently hardcoded in a constant set, so exploitation requires modifying the constant. Pattern is dangerous for maintenance.
**Fix:** Already safe via constant whitelist, but add an explicit assertion: `assert col in SAFE_COLS` before the f-string.

### C6. cobol_analyzer_api.py:596 — Level 77/66 treated as group items
**Type:** Logic Bug
The condition `if name and not pic_raw and level < 88` pushes level 77 (standalone) and level 66 (RENAMES) items onto `_level_stack` as if they were group parents. Subsequent variables get incorrect `parent_group` values.
**Fix:** Change to `if name and not pic_raw and level not in (66, 77, 88):`.

---

## HIGH (10)

### H1. cobol_types.py:163-170 — COMP byte boundary uses total_digits, not pic_integers
COMP allocation should use integer digits only, not total_digits (integers + decimals). `PIC S9(4)V99 COMP` → total_digits=6 → 4 bytes, but IBM allocates 2 bytes (only 4 integer digits).
**Fix:** Use `pic_integers` for the halfword/fullword/doubleword boundary check.

### H2. cobol_types.py:127-149 — Inconsistent abs() application across TRUNC modes
TRUNC(OPT) and TRUNC(BIN)+COMP apply `abs()` for unsigned fields early, but TRUNC(STD) relies on a final catch-all. If the final check is ever refactored away, negative values leak into unsigned fields.
**Fix:** Remove early abs() calls from OPT/BIN paths; let the final check on line 149 handle all cases uniformly.

### H3. cobol_file_io.py:222-248 — populate() silently skips missing fields
If a record dict is missing a required field, the namespace variable retains its value from the previous record. This causes silent data corruption in Shadow Diff verification.
**Fix:** Initialize missing fields to zero/blank instead of skipping.

### H4. cobol_file_io.py:119-150 — RealFileBackend file handles leak on write error
If `fh.write()` raises OSError, the file handle stays in `_handles` but may be in an inconsistent state. No cleanup occurs.
**Fix:** Wrap write in try/finally, close handle on error.

### H5. copybook_resolver.py:414-453 — REDEFINES forward-reference offset wrong
If a REDEFINES target hasn't been defined yet (forward reference), offset falls back to `current_offset` instead of the target's offset. Standard COBOL requires REDEFINES target before the REDEFINES clause, but the code should raise an error, not silently use the wrong offset.
**Fix:** Raise ValueError if REDEFINES target is not found in `name_to_entry`.

### H6. shadow_diff.py:382-388 — Daemon threads leak on timeout
When exec() times out, the daemon thread is left running. In a long-running FastAPI service, orphaned threads accumulate. Python has no mechanism to kill threads.
**Fix:** Use `concurrent.futures.ThreadPoolExecutor` with proper cancellation, or log warnings for operators to monitor.

### H7. generate_full_python.py:1181-1182 — Collision alias overwrites var_info entry
For duplicate field names, `var_info[name] = var_info[var_key]` overwrites with the LAST duplicate's metadata. If 3+ groups share a field name, intermediate entries are lost. The reverse map `cobol_to_qualified` correctly tracks all entries, but direct `var_info[name]` lookups get wrong metadata.
**Fix:** Don't overwrite — only store under qualified keys. Use `cobol_to_qualified` for all unqualified lookups.

### H8. core_logic.py:2010-2024 — Timing attack enables username enumeration
Login checks `if username not in users_db` and fails immediately. Password hashing path is different for non-existent users vs wrong passwords. Response time difference reveals whether a username exists.
**Fix:** Always hash a dummy password even if user not found, so timing is constant.

### H9. core_logic.py:3666-3680 — Path traversal in SPA fallback and demo data
`serve_spa` and `serve_demo_data` check `is_file()` but don't verify the resolved path is within the expected directory. Symlinks could expose files outside the frontend/demo directories.
**Fix:** Use `.resolve()` and verify `str(file_path).startswith(str(expected_dir.resolve()))`.

### H10. vault.py:291,323 — Chain hash fallback silently masks errors
If `verification_chain` JSON is malformed or `chain_hash` key is missing, code falls back without logging. Chain integrity degrades silently.
**Fix:** Log warnings on every fallback path.

---

## MEDIUM (18)

### M1. cobol_analyzer_api.py:560-566 — OCCURS DEPENDING ON name not validated
`depending_on` extracted via regex without validating it's a legal COBOL identifier. Garbage input silently stored.

### M2. generate_full_python.py:645-673 — Multi-arg function comma injection fragile
The argument grouping heuristic for `FUNCTION MAX(A+B, C*D)` doesn't track parenthesis nesting. Complex expressions inside function arguments may get split at wrong boundaries.

### M3. parse_conditions.py:78-88 — OF resolution matches "OF" inside variable names
`upper.find("OF")` matches "OF" in names like "PROFILE" (position 2). The `of_idx > 0` check prevents position 0 but not mid-name matches.
**Fix:** Use word-boundary regex: `re.search(r'(?<=[A-Z0-9\-])OF(?=[A-Z])', upper)`.

### M4. shadow_diff.py:753-754 — S0C7 abends short-circuit ALL field comparisons
If ANY input field has an S0C7 abend during parsing, the entire record is flagged as abend and no drift detection occurs for other valid fields.

### M5. shadow_diff.py:1249 — Upload file path collision between concurrent users
File paths use `f"{prefix}_{layout_name}"` without user ID or UUID. Two concurrent uploads for the same layout overwrite each other.

### M6. shadow_diff.py:1441 — No exception handling for missing DEMO_LOAN_INTEREST.cbl
`generate_demo_data()` assumes the demo file exists and analysis succeeds. Missing file crashes with unhelpful 500 error.

### M7. cobol_types.py:661-664 — put_bytes() silently truncates oversized data
`CobolMemoryRegion.put_bytes()` truncates data that exceeds buffer size without error. Contrast with `put()` which raises IndexError.

### M8. cobol_file_io.py:74-82 — StreamBackend conflates "file not found" with EOF
Both return `None` as the record, but different status codes (35 vs 10). Callers may not distinguish properly.

### M9. ebcdic_utils.py:55-62 — No bytes-vs-string input validation
`ebcdic_compare()` assumes string input but doesn't validate. Passing bytes would silently produce wrong comparisons.

### M10. ebcdic_utils.py:75-77 — ebcdic_equal() ignores codepage parameter
Function accepts `codepage` parameter but never uses it. Misleading API.

### M11. copybook_resolver.py:292-340 — _pic_byte_length missing COMP-5
COMP-5 uses minimal byte length, not the standard halfword/fullword boundaries. Currently treated same as COMP.

### M12. copybook_resolver.py:375-378 — FILLER counter names may collide
Generated names like `FILLER-1` could collide with actual user-defined field names.

### M13. copybook_resolver.py:455-477 — REDEFINES validation only checks type mismatch
Length mismatches between base and overlay (e.g., 5-byte numeric vs 4-byte COMP) are not flagged.

### M14. core_logic.py:1544-1554 — RateLimiter not thread-safe
`is_allowed()` mutates `_hits` defaultdict without locks. Two concurrent coroutines could both pass the check.

### M15. core_logic.py:1680-1684 — set_compiler_config unpacks unvalidated dict
`set_config(**body)` passes user-supplied keys directly. Unexpected kwargs could cause undefined behavior.

### M16. execution_trace.py:47 — parse_trace() no type validation on line number
`int(entry["line"])` crashes on non-integer values. Missing try/except.

### M17. execution_trace.py:67-68 — diagnose_divergence() empty string → InvalidOperation
Empty `new_value` strings cause `Decimal("")` to raise. Caught by except but loses diagnostic value.

### M18. vault.py:174 — lastrowid race condition in concurrent inserts
`cur.lastrowid` after INSERT is not atomic with the subsequent UPDATE. Two concurrent requests could get same ID.

---

## LOW (11)

### L1. cobol_analyzer_api.py:586 — Level regex assumes exactly 2 digits
`r'^(\d{2})'` won't match single-digit levels like `5` (ANTLR normalizes to `05`, so likely safe).

### L2. generate_full_python.py:18 — extract_var_name missing parenthesis in boundary
Regex doesn't treat `(` as a name terminator for subscripted declarations.

### L3. compiler_config.py:46-69 — Missing context cleanup documentation
No guidance on when/how to call `reset_config()` in long-running services.

### L4. shadow_diff.py:646-651 — Inconsistent mismatch detail key names
Record-missing entries use `expected`/`actual` while field-missing entries use `aletheia_value`/`mainframe_value`.

### L5. core_logic.py:210 — Ephemeral JWT secret not enforced in production
Dev key generated via `secrets.token_hex(32)` with warning, but no hard block when `ENVIRONMENT=production`.

### L6. core_logic.py:1892,1906 — Health/heartbeat return decimal precision
Information disclosure of internal configuration via unauthenticated endpoints.

### L7. core_logic.py:227 — No minimum file size check
Zero-byte COBOL files accepted, could cause parser edge cases.

### L8. risk_heatmap.py:145 — No underflow protection on negative complexity inputs
Negative `branch_count` or `nesting_depth` could produce unexpected scores.

### L9. layout_generator.py:35-36 — parse_pic_clause None return not handled everywhere
Some callers do `pic_info.get(...)` without checking for None first.

### L10. layout_generator.py:67-69 — PIC X(10)X(5) multi-repetition not summed
Regex finds first `X(N)` only, doesn't sum multiple occurrences.

### L11. vault.py:323 — Overly broad exception catch in verify_chain
`except (ImportError, Exception)` catches all exceptions including KeyboardInterrupt.

---

## Summary

| Severity | Count | Action |
|----------|-------|--------|
| CRITICAL | 6 | Fix before any customer pilot |
| HIGH | 10 | Fix before GA release |
| MEDIUM | 18 | Fix in next sprint |
| LOW | 11 | Address during maintenance |
| **Total** | **45** | |

### Top 5 Priority Fixes

1. **C3** — `is_approved` hardcoded True (auth bypass) — trivial fix, massive security impact
2. **C1** — PIC P scaling data corruption — affects COMP-3 packed decimal programs
3. **C4** — Rate limiter bypass via token rotation — defeats brute-force protection
4. **C6** — Level 77/66 in _level_stack — corrupts qualified name resolution
5. **H1** — COMP byte boundary — wrong max values for V99 fields

---

*This audit was performed by reading every function in all 14 files. No source files were modified.*
