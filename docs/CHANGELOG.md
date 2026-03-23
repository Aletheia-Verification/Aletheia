# Changelog

## 2026-03-22: Launch Sprint

### Engine
- **FUNCTION EXP/SQRT** — Added to intrinsic function map (14 total). EXP uses IEEE 754 with compiler warning. SQRT uses native Decimal.sqrt().
- **INSPECT CONVERTING BEFORE/AFTER INITIAL** — Full support with length guard.
- **INSPECT REPLACING LEADING multi-char** — While-loop for multi-character leading replacement. Same-length validation.
- **ACCEPT FROM ENVIRONMENT-NAME/VALUE** — Stateful `_env_name` tracker with `os.environ.get()`.
- **SET 88-level with subscript** — `SET WS-FLAG(IDX) TO TRUE` strips subscript and applies indexed assignment.
- **In-memory SORT on OCCURS table** — Zip/sort/unzip parallel arrays for table-level SORT without USING/GIVING.
- **SORT DUPLICATES IN ORDER** — Detection + comment in generated code. Warning if not specified.
- **Nested programs** — `has_nested_programs` detection with compiler warning + MR flag.
- **Level 78 constants** — Preprocessor substitution with collision detection.
- **EBCDIC comparison audit** — Fixed 4 ASCII bypass bugs (88-level THRU, compound conditions, CobolFieldProxy, EVALUATE first-subject THRU).
- **Indexed file I/O** — START, READ NEXT, DELETE for StreamBackend/RealFileBackend/CobolFileManager.
- **Relative file I/O** — Position-based read/write/delete with FILE STATUS codes.

### Security
- Shadow Diff truncated record warning (instead of silent zero).
- Poison pill generator empty list guard.
- Console.log gated with `import.meta.env.DEV` across 4 frontend files.

### Testing
- **1006 tests, 0 failures** (up from 912).
- **PVR 94.3%** on 459 programs (433 VERIFIED, 26 MANUAL REVIEW).
- Arithmetic intermediate precision tests (prec=18 vs prec=31).

### Documentation
- Final launch audit: `docs/AUDIT_FINAL_LAUNCH.md`.
- EBCDIC comparison audit: `docs/EBCDIC_COMPARISON_AUDIT.md`.
- Unified PVR claims across all docs.
- README rewritten.
- CI workflow updated with all test files.

---

## 2026-03-19: Mega Session

### New Features
- **Execution Trace Comparison** — `execution_trace.py`, `POST /engine/trace-compare`. Step-by-step divergence detection with root-cause diagnosis (rounding, TRUNC mismatch, PIC overflow, sign reversal).
- **Trace Emission in Generator** — `trace_mode=True` parameter on `generate_python_module()`. Captures old/new values around every MOVE, COMPUTE, and arithmetic operation.
- **ScopedNamespace** — Qualified variable name disambiguation. Duplicate field names across groups get `parent__field` Python names. OF qualifier resolution in tokenizers. Unqualified aliases for backward compat.
- **FUNCTION Intrinsics (12)** — LENGTH, MAX, MIN, ABS, MOD, UPPER-CASE, LOWER-CASE, TRIM, REVERSE, ORD, CURRENT-DATE, INTEGER. Unknown functions → MANUAL REVIEW. Multi-arg comma injection for ANTLR getText() blobs.
- **SIGN IS LEADING/TRAILING SEPARATE** — Full sign clause support in analyzer, generator, and CobolDecimal. 11 tests.
- **PIC P Scaling** — PP999 (leading implied zeros) and 999PP (trailing implied zeros). Descale→truncate→rescale in CobolDecimal.store(). 8 tests.
- **BLANK WHEN ZERO, JUSTIFIED RIGHT** — Analyzer detection, metadata in var_info.
- **COMP-1/COMP-2** — IEEE 754 single/double precision float in CobolDecimal.
- **COMP-3 Dirty Signs** — 0xA-0xF sign nibble normalization during decode.
- **Level 66 RENAMES** — Detection and metadata storage.
- **ACCEPT FROM DATE/TIME/DAY** — Deterministic placeholder emission.
- **MOVE CORRESPONDING** — Field-name matching between group structures.
- **GO TO inside PERFORM THRU** — Correct paragraph range execution.
- **PERFORM VARYING inside IF/EVALUATE** — Regex-based while loop generation in `_convert_single_statement()`.
- **Corpus Hardening** — 28 new dense programs (154-337 lines, 8-15 constructs). PVR 82.5% on 200 programs.

### Bug Fixes (compile failures)
- MANUAL REVIEW comment breaking `if`/`elif` syntax (stripped inline `#` comments)
- Comment-only IF/ELIF body missing `pass` (3 locations)
- PERFORM VARYING inside branch producing garbled paragraph call

### Security Fixes (6 critical audit findings)
- **C1:** PIC P `_max_int` used `pic_integers=0` for PP999 → all values overflowed. Fixed: use total stored digits.
- **C2:** exec() constants — added `_SAFE_CONST_TYPES` validation (Decimal/int/float/str/None only).
- **C3:** `is_approved` hardcoded True in login — now returns actual user approval status.
- **C4:** Rate limiter used raw JWT token as key — now decodes `sub` claim for per-user limiting.
- **C5:** SQL f-string in vault.py ALTER TABLE — added `_SAFE_MIGRATION_COLS` frozenset + column name validation.
- **C6:** Level 77/66 pushed onto `_level_stack` as group parents — changed `level < 88` to `level < 50`.

### Docs
- Security Whitepaper V2 — 13 sections, exec() model, data flow diagram, dependency audit, ISO 27001, pentest status.
- Post-session code audit — 45 findings across 14 files (6 critical, 10 high, 18 medium, 11 low).
- Deployment Guide

### Frontend
- Mobile responsive breakpoints on all pages
- Dashboard 30s live polling with trend indicators
- Loading spinner on initial load, gold dot on background refresh

### CI/CD
- `.github/workflows/test.yml` — 3 parallel jobs (pytest, eslint, vite build)
- `.github/workflows/pvr.yml` — manual PVR measurement, posts as PR comment

### Docker
- Two-stage Cython build (18 .py → .so), non-root user
- Air-gapped default, connected mode opt-in
- License volume mount (strict/grace modes)

### Test Suite Growth
- Started: 630 tests
- Ended: 696+ tests across 36+ files + 50 semantic corpus entries
- 200-program dense corpus for PVR measurement
