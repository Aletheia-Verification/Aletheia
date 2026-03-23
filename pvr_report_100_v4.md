# PVR Report v4 — INSPECT TALLYING/REPLACING Expansion
**Date**: 2026-03-15
**Corpus**: 100 hardened programs (40 original + 60 corpus with MR triggers)

---

## Summary

| Metric | v3 | v4 | Delta |
|--------|-----|-----|-------|
| Programs tested | 100 | 100 | — |
| Compile success | 100 | 100 | — |
| Clean verified | 63 | 72 | **+9** |
| MANUAL REVIEW programs | 37 | 28 | -9 |
| Total MR flags | 116 | 58 | **-58** |
| **PVR** | **63.0%** | **72.0%** | **+9.0** |

**Tests**: 645 passed, 0 failures (640 existing + 5 new INSPECT tests)

---

## What was fixed

### INSPECT TALLYING expansion
- **FOR CHARACTERS** (no BA) → `len(str(field))`
- **FOR CHARACTERS BEFORE INITIAL** → `field.find(delim)` (parsed from getText() blob)
- **FOR CHARACTERS AFTER INITIAL** → `len(field) - field.find(delim) - len(delim)`
- **FOR ALL with BEFORE/AFTER** → `.count()` on relevant portion
- **FOR LEADING** (single-char, no BA) → inline loop counting consecutive matches
- **FOR LEADING with BEFORE** → leading loop on portion before delimiter
- **Multiple counters** → loop over all entries (removed `len==1` gate)
- **Figurative constants** (SPACES, ZEROS) → resolved to `' '`, `'0'`

### INSPECT REPLACING expansion
- **FIRST** (no BA) → `.replace(from, to, 1)`
- **FIRST with BEFORE/AFTER** → `.replace()` on relevant portion
- **CHARACTERS BY** (no BA) → `replacement * len(field)` (parsed BY from getText())
- **CHARACTERS BY with BEFORE/AFTER** → replace chars in portion only
- **ALL with BEFORE/AFTER** → `.replace()` on relevant portion
- **LEADING** (single-char, no BA) → inline loop replacing leading chars
- **Multiple replacements** → loop over all entries (removed `len==1` gate)

### Existing tests updated
- `TestInspectTallyingLeading`: now asserts emit (was MR)
- `TestInspectReplacingFirst`: now asserts emit (was MR)

---

## Programs recovered (9 newly VERIFIED)

| Program | Was | Now | What fixed it |
|---------|-----|-----|---------------|
| BATCH-TOTAL-VARY | 2 MR | VERIFIED | INSPECT TALLYING LEADING |
| COMPUTE-COMPOUND | 4 MR | VERIFIED | INSPECT TALLYING LEADING + CHARACTERS BEFORE |
| MOVE-CORR-EMPTY | 4 MR | VERIFIED | INSPECT TALLYING CHARACTERS BEFORE + LEADING (figurative SPACES) |
| PERF-THRU-SEQ | 2 MR | VERIFIED | INSPECT REPLACING FIRST |
| PERF-TIMES-NEST | 6 MR | VERIFIED | INSPECT TALLYING CHARACTERS + LEADING (x3) |
| PERF-UNTIL-88 | 4 MR | VERIFIED | INSPECT REPLACING CHARACTERS BY with BEFORE/AFTER |
| REFMOD-DATE-PARSE | 4 MR | VERIFIED | INSPECT REPLACING FIRST (x2) |
| RPT-SUMMARY | 4 MR | VERIFIED | INSPECT REPLACING FIRST + TALLYING CHARACTERS |
| STRESS-INSPECT-BOTH | 12 MR | VERIFIED | Full INSPECT expansion (multi-counter, LEADING, FIRST, CHARS BY, ALL w/ BA) |

---

## Remaining MR flags (58 total across 28 programs)

| Construct | Flags | Programs | Notes |
|-----------|-------|----------|-------|
| ALTER | 12 | 6 | Intentionally hard — runtime paragraph mutation |
| UNSTRING complex (OR/POINTER/TALLYING/DELIMITER-IN) | 12 | 7 | Next priority |
| SORT (INPUT/OUTPUT PROCEDURE) | 10 | 5 | Architecturally complex |
| DISPLAY inside IF branch | 8 | 5 | Parser edge case |
| STRING with OVERFLOW | 6 | 3 | Next priority |
| READ KEY / REWRITE | 4 | 2 | Indexed file I/O |
| MULTIPLY inside IF (parser edge) | 2 | 1 | Parser edge case |
| INSPECT TALLYING LEADING (figurative) | 2 | 1 | STRESS-INIT-GROUP still has DISPLAY MR |

---

## PVR progression

| Version | Date | PVR | Key change |
|---------|------|-----|------------|
| v1 (easy corpus) | 2026-03-14 | 89.0% | Initial 100-program run |
| v2 (hardened) | 2026-03-15 | 61.0% | Rewrote all 60 corpus files with MR triggers |
| v3 (bug fixes) | 2026-03-15 | 63.0% | Fixed EVALUATE ALSO+THRU + newline bugs |
| **v4 (INSPECT)** | **2026-03-15** | **72.0%** | **INSPECT TALLYING/REPLACING expansion** |

## Next priorities (from remaining 58 flags)
1. **UNSTRING expansion** (OR delimiters, POINTER, TALLYING, DELIMITER-IN) — 12 flags, 7 programs
2. **STRING with OVERFLOW** — 6 flags, 3 programs
3. **DISPLAY inside IF branch** — 8 flags, 5 programs (parser edge case)
4. **SORT INPUT/OUTPUT PROCEDURE** — 10 flags, 5 programs
5. **ALTER** — 12 flags, 6 programs (may remain MR permanently)
