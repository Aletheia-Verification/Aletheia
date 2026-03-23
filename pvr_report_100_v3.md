# PVR Report v3 — 100-Program Hardened Corpus (Post Bug Fixes)
**Date**: 2026-03-15
**Corpus**: 40 original + 60 hardened corpus programs
**Fixes applied**: EVALUATE ALSO + THRU codegen bug, body_preview newline sanitization

---

## Summary

| Metric | v2 (pre-fix) | v3 (post-fix) | Delta |
|--------|-------------|---------------|-------|
| Programs tested | 100 | 100 | — |
| Parse success | 99 | 99 | — |
| Generate success | 100 | 100 | — |
| **Compile success** | **94** | **100** | **+6** |
| Clean verified | 61 | 63 | +2 |
| MANUAL REVIEW | 33 | 37 | +4 (former crashes now MR) |
| Compile errors | 6 | 0 | **-6** |
| Total MR flags | 116 | 116 | — |
| **PVR** | **61.0%** | **63.0%** | **+2.0** |

The 4 former compile-error programs (STRESS-NAME-COLLISION, STRESS-PIC-OVERFLOW, STRESS-GOTO-THRU, STRESS-INIT-GROUP) now compile but still have MR flags from other constructs (ALTER, INSPECT TALLYING, SORT). 2 programs (EVAL-NESTED-WHEN, EVAL-WHEN-RANGE) are now fully VERIFIED.

---

## Bugs Fixed

### Bug 1: EVALUATE ALSO + THRU range → "invalid decimal" (4 programs → 0)
- **File**: `parse_conditions.py:953-981`
- **Root cause**: ALSO subject path called `_resolve_value()` on raw `"1THRU3"` text. Non-ALSO path (lines 1044-1075) already had THRU regex matching.
- **Fix**: Added numeric, string, and variable THRU range detection to both first-subject and ALSO-subject paths, matching existing non-ALSO patterns.

### Bug 2: Newline in body_preview → "unexpected indent" (2 programs → 0)
- **File**: `generate_full_python.py:1719`
- **Root cause**: `body_preview` from multi-line COBOL (e.g., OCCURS DEPENDING ON) contained `\n`, breaking Python string literal.
- **Fix**: Added `.replace(chr(10), ' ')` matching existing pattern at line 1678.

---

## Tests Added
- `test_parse_conditions.py::TestEvaluateAlsoThru::test_also_thru_numeric_compiles` — EVALUATE ALSO with THRU range in second subject
- `test_parse_conditions.py::TestEvaluateAlsoThru::test_also_thru_first_subject` — THRU range in first subject
- `test_parse_conditions.py::TestBodyPreviewNewline::test_newline_in_preview_compiles` — multi-line OCCURS DEPENDING ON body_preview

**Full suite**: 478 passed, 0 failures (475 existing + 3 new)

---

## Per-Program Status (100 programs)

### VERIFIED (63 programs)
ACCT-BALANCE-ADD, ACCT-BALANCE-SUB, ACCT-FEE-CALC, ACCT-INTEREST, ACCT-REDEFINE, APPLY-PENALTY, ARITHMETIC-STRESS, BATCH-RATE-TABLE, CALC-INT, COMPOUND-INT, COMPUTE-CHAIN, COMPUTE-MULTI-TARGET, CREDIT-SCORE, CSV-PARSER, DATA-CLEANER, DEEP-NEST, DEMO-WITH-COPY, DEMO_LOAN_INTEREST, DISPLAY-MIX, DIV-REMAINDER, DYNAMIC-TABLE, EVAL-88-LEVEL, EVAL-88-MULTI, EVAL-88-NESTED, EVAL-ALSO, EVAL-IN-VARY, **EVAL-NESTED-WHEN** (NEW), EVAL-VARIABLE, EVAL-WHEN-COMPOUND, **EVAL-WHEN-RANGE** (NEW), EVALUATE-TEST, GOTO-DEPEND, GOTO-FLOW, INIT-TEST, INSPECT-CONV, INTR-CALC-3270, INVOICE-GEN, LOAN-AMORT-CALC, LOAN-SIMPLE-INT, MAIN-LOAN, MONTHLY-TOTALS, MOVE-CORR-ACCT, MOVE-CORR-MIXED, MSG-BUILDER, NESTED-EVAL, PAYROLL-CALC, PERF-THRU-BRANCH, PERF-UNTIL-OR, PERFORM-VARYING-TEST, REFMOD-CONDITION, REPEAT-TIMES, RPT-STRING-HDR, STATUS-CHECKER, STRESS-DISPLAY-MIX, STRING-PTR, TXN-APPROVE-FLOW, TXN-BATCH-CHECK, TXN-VALIDATE-IF, TYPE-CHECKER, VARY-AFTER-ACCUM, VARY-AFTER-MATRIX, VARY-AFTER-STEP, WIRE-VALIDATE

### MANUAL REVIEW (37 programs, 116 flags)
| Program | MR | Trigger |
|---------|-----|---------|
| ALTER-DANGER | 2 | ALTER |
| ALTER-TEST | 2 | ALTER |
| BATCH-MONTHLY | 1 | DISPLAY inside IF |
| BATCH-PAYMENT | 2 | MULTIPLY inside IF (parser edge) |
| BATCH-TOTAL-VARY | 2 | INSPECT TALLYING LEADING |
| COMPUTE-COMPOUND | 4 | INSPECT TALLYING LEADING + CHARACTERS |
| EVAL-VARY-ACCUM | 4 | UNSTRING complex + INSPECT TALLYING |
| EVAL-VARY-STRING | 2 | STRING OVERFLOW |
| EXEC-SQL-TEST | 1 | DISPLAY inside IF |
| LOAN-PENALTY | 2 | UNSTRING DELIMITER-IN/COUNT-IN |
| MOVE-CORR-EMPTY | 4 | INSPECT TALLYING CHARACTERS + LEADING |
| PERF-THRU-GOTO | 2 | ALTER |
| PERF-THRU-SEQ | 2 | INSPECT REPLACING FIRST |
| PERF-TIMES-COND | 2 | UNSTRING with OR |
| PERF-TIMES-NEST | 6 | INSPECT TALLYING (x3) |
| PERF-TIMES-PARA | 2 | STRING OVERFLOW |
| PERF-UNTIL-88 | 4 | INSPECT REPLACING complex |
| PERF-UNTIL-AND | 2 | SORT INPUT/OUTPUT PROCEDURE |
| REFMOD-DATE-PARSE | 4 | INSPECT REPLACING FIRST (x2) |
| REFMOD-WRITE | 2 | SORT INPUT/OUTPUT PROCEDURE |
| RPT-LINE-BUILD | 2 | UNSTRING with OR |
| RPT-SUMMARY | 4 | INSPECT REPLACING FIRST + TALLYING |
| STRESS-DEEP-NEST | 2 | ALTER |
| STRESS-DIV-REMAINDER | 4 | SORT + READ + REWRITE |
| STRESS-EVAL-PERFORM | 2 | SORT INPUT/OUTPUT PROCEDURE |
| STRESS-EXEC-SQL | 3 | DISPLAY inside EXEC SQL |
| STRESS-GOTO-THRU | 2 | SORT INPUT/OUTPUT PROCEDURE |
| STRESS-INIT-GROUP | 9 | INSPECT TALLYING (x4) + DISPLAY |
| STRESS-INSPECT-BOTH | 12 | INSPECT TALLYING + REPLACING (all) |
| STRESS-MIXED-COMP | 2 | READ KEY + REWRITE |
| STRESS-NAME-COLLISION | 2 | DISPLAY inside IF |
| STRESS-PIC-OVERFLOW | 2 | ALTER |
| STRESS-REDEFINES-COMP3 | 2 | UNSTRING complex |
| STRESS-STRING-OVERFLOW | 10 | STRING OVERFLOW + UNSTRING + INSPECT |
| STRESS-THRU-GOTO-OUT | 2 | ALTER |
| STRESS-UNSTRING | 2 | UNSTRING complex |
| UNSTR-COMPLEX | 2 | UNSTRING complex |

---

## Remaining MR Frequency (build priority unchanged)

| Construct | Flags | Programs | Priority |
|-----------|-------|----------|----------|
| INSPECT TALLYING (CHARACTERS/LEADING/BEFORE/AFTER) | ~30 | 10 | **P0** |
| ALTER | 12 | 6 | P2 |
| INSPECT REPLACING (FIRST/CHARACTERS/BEFORE/AFTER) | 12 | 5 | **P0** |
| UNSTRING (OR/POINTER/TALLYING/DELIMITER-IN/COUNT-IN) | 10 | 8 | **P1** |
| SORT (INPUT/OUTPUT PROCEDURE) | 10 | 5 | P2 |
| DISPLAY inside IF branch | 8 | 5 | **P0** |
| STRING (OVERFLOW/POINTER) | 6 | 4 | **P1** |
| READ KEY / REWRITE / OPEN I-O | 4 | 2 | P2 |

**PVR = 63.0% — compile errors eliminated, 2 programs recovered to VERIFIED.**
