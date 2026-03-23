# PVR Experiment Report — 2026-03-14 v2

## Post-Fix Re-Run (INSPECT CONVERTING + STRING in branches)

**Previous PVR**: 75.0% (30/40)
**Current PVR**: 80.0% (32/40)

## Summary

| Metric              | Count | Percentage |
|---------------------|-------|------------|
| Programs tested     | 40    | —          |
| Parse success       | 39    | 97.5%      |
| Generate success    | 40    | 100.0%     |
| Compile success     | 40    | 100.0%     |
| **VERIFIED (clean)**| **32**| **80.0%**  |
| MANUAL REVIEW       | 8     | 20.0%      |
| CRASH               | 0     | 0.0%       |

**PVR = 80.0%** (32 clean verified / 40 tested)

---

## Status Changes from Previous Run (v1 → v2)

| Program | Old Status | New Status | Fix Applied |
|---------|-----------|------------|-------------|
| INSPECT-CONV | MANUAL REVIEW | **VERIFIED** | INSPECT CONVERTING → `str.maketrans()` + `str.translate()` in generator |
| WIRE-VALIDATE | MANUAL REVIEW | **VERIFIED** | STRING handler added to `_convert_single_statement` for branch resolution |

**Net effect**: +2 programs verified, MR count dropped from 10 to 8.

---

## Per-Program Results

### VERIFIED (32 programs)

| Program | Lines | Parse | Notes |
|---------|-------|-------|-------|
| ACCT-INTEREST | 124 | OK | Complex interest calculation |
| ACCT-REDEFINE | 22 | OK | REDEFINES with group items |
| APPLY-PENALTY | 23 | OK | — |
| ARITHMETIC-STRESS | 102 | OK | Heavy arithmetic mix |
| CALC-INT | 18 | OK | — |
| COMPOUND-INT | 27 | OK | COMPUTE with ** exponentiation |
| CREDIT-SCORE | 180 | OK | Large mixed program |
| CSV-PARSER | 21 | OK | Simple UNSTRING |
| DATA-CLEANER | 20 | OK | INSPECT TALLYING + REPLACING |
| DEEP-NEST | 34 | OK | 5-level nested IF/ELSE |
| DEMO-WITH-COPY | 36 | OK | COPY statement (resolved) |
| DEMO_LOAN_INTEREST | 93 | OK | Primary demo file |
| DISPLAY-MIX | 18 | OK | DISPLAY with mixed operands |
| DIV-REMAINDER | 18 | OK | DIVIDE with REMAINDER |
| DYNAMIC-TABLE | 25 | OK | OCCURS DEPENDING ON |
| EVAL-VARIABLE | 36 | OK | EVALUATE variable (not TRUE) |
| EVALUATE-TEST | 60 | OK | EVALUATE test battery |
| GOTO-FLOW | 26 | OK | GO TO with paragraph flow |
| INIT-TEST | 22 | OK | INITIALIZE group items |
| INSPECT-CONV | 12 | OK | **NEW**: INSPECT CONVERTING now emitted as `str.maketrans` + `translate` |
| INTR-CALC-3270 | 37 | FAIL* | Parse warnings but generator recovers |
| INVOICE-GEN | 59 | OK | Mixed: PERFORM VARYING + EVALUATE + STRING |
| MAIN-LOAN | 34 | OK | — |
| MONTHLY-TOTALS | 28 | OK | OCCURS + PERFORM VARYING + subscripts |
| MSG-BUILDER | 18 | OK | STRING DELIMITED BY SIZE |
| NESTED-EVAL | 38 | OK | Nested EVALUATE inside IF |
| PAYROLL-CALC | 47 | OK | PERFORM THRU + mixed arithmetic |
| PERFORM-VARYING-TEST | 71 | OK | PERFORM VARYING battery |
| REPEAT-TIMES | 16 | OK | PERFORM TIMES |
| STATUS-CHECKER | 35 | OK | 88-levels with THRU ranges + EVALUATE TRUE |
| TYPE-CHECKER | 25 | OK | IS NUMERIC / IS ALPHABETIC |
| WIRE-VALIDATE | 130 | OK | **NEW**: STRING inside EVALUATE branch now resolved via lookup dict |

*INTR-CALC-3270: ANTLR reports parse errors (non-standard syntax) but error recovery extracts enough data for clean generation.

### MANUAL REVIEW (8 programs, 15 total flags)

| Program | MR Flags | Reason |
|---------|----------|--------|
| ALTER-DANGER | 2 | ALTER statement (forces MR — correct behavior) |
| ALTER-TEST | 2 | ALTER statement (forces MR — correct behavior) |
| BATCH-PAYMENT | 2 | MULTIPLY parse issue: `MULTIPLYWS-LATE-FEEBY` — ANTLR drops literal `2` from getText() |
| EVAL-ALSO | 2 | EVALUATE ALSO multi-subject (unsupported) |
| EXEC-SQL-TEST | 1 | DISPLAY after EXEC SQL block not fully resolved |
| GOTO-DEPEND | 2 | GO TO DEPENDING ON (unsupported) |
| STRING-PTR | 2 | STRING with POINTER (unsupported) |
| UNSTR-COMPLEX | 2 | UNSTRING with DELIMITER IN / COUNT IN (unsupported) |

---

## Fixes Applied in This Run

### Fix 1: INSPECT CONVERTING (generate_full_python.py)

Added `elif variant == "converting":` handler that:
- Parses FROM/TO from ANTLR getText() statement via regex
- Handles quoted literals (`'abc...'`), figurative constants (SPACES, ZEROS), and variable references
- Emits `str.maketrans(from, to)` + `str.translate(_tbl)` — exact Python equivalent of COBOL INSPECT CONVERTING

### Fix 2: STRING in branches (parse_conditions.py + generate_full_python.py)

Added STRING handler to `_convert_single_statement()`:
- Built `_all_strings_by_text` lookup dict in generator (same pattern as `_all_evaluates_by_text`)
- Threaded through full call chain: `generate_python_module` → `parse_if_statement`/`parse_evaluate_statement` → `_convert_if_block` → `_convert_single_statement`
- STRING DELIMITED BY SIZE in branches now resolves to concatenation
- STRING with POINTER/OVERFLOW/non-SIZE still correctly flagged as MANUAL REVIEW

---

## Remaining MR Reason Frequency

| Reason | Programs Affected | Effort | PVR Impact |
|--------|-------------------|--------|------------|
| ALTER statement | 2 (ALTER-DANGER, ALTER-TEST) | Hard — intentionally blocked (self-modifying code) | +5.0% but risky |
| EVALUATE ALSO (multi-subject) | 1 (EVAL-ALSO) | Medium — need multi-subject condition matching | +2.5% |
| GO TO DEPENDING ON | 1 (GOTO-DEPEND) | Medium — computed GO TO to indexed dispatch | +2.5% |
| STRING with POINTER | 1 (STRING-PTR) | Medium — track POINTER position variable | +2.5% |
| UNSTRING DELIMITER IN / COUNT IN | 1 (UNSTR-COMPLEX) | Medium — capture delimiter and length info | +2.5% |
| Arithmetic in nested IF (ANTLR parse error) | 1 (BATCH-PAYMENT) | Not fixable in generator — ANTLR limitation | +2.5% |
| DISPLAY after EXEC SQL | 1 (EXEC-SQL-TEST) | Easy — but legitimate EXEC SQL blocks | +2.5% |

---

## Test Suite Status

- **465 tests passing** across 21 test modules + semantic corpus
- Zero regressions from both fixes
- 3 new tests added for STRING in branches
- 3 tests added for INSPECT CONVERTING (in prior checkpoint)

---

*Generated 2026-03-14 by Aletheia viability experiment re-run (post INSPECT CONVERTING + STRING branch fixes)*
