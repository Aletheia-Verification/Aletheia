# PVR Report — 100-Program Hardened Corpus
**Date**: 2026-03-15
**Corpus**: 40 original + 60 hardened corpus programs (every corpus file injects MR-triggering constructs)

---

## Summary

| Metric | Count | Pct |
|--------|-------|-----|
| Programs tested | 100 | — |
| Parse success | 99 | 99.0% |
| Generate success | 100 | 100.0% |
| Compile success | 94 | 94.0% |
| Clean verified (0 MR) | 61 | 61.0% |
| MANUAL REVIEW programs | 33 | 33.0% |
| Compile errors | 6 | 6.0% |
| Total MR flags | 116 | — |
| **PVR** | **61.0%** | — |

Previous PVR (easy corpus): 89.0%. Drop of 28 points = the hardened corpus found real gaps.

---

## Compile Errors (6 programs — engine bugs)

| Program | Error | Root Cause | Fixability |
|---------|-------|------------|------------|
| EVAL-NESTED-WHEN | `invalid decimal` | EVALUATE ALSO generates malformed Decimal literal | Medium — fix ALSO codegen |
| EVAL-WHEN-RANGE | `invalid decimal` | EVALUATE ALSO generates malformed Decimal literal | Medium — same fix |
| STRESS-NAME-COLLISION | `invalid decimal` | EVALUATE ALSO + name collision triggers bad Decimal | Medium — same fix |
| STRESS-PIC-OVERFLOW | `invalid decimal` | EVALUATE ALSO + ALTER combo triggers bad Decimal | Medium — same fix |
| STRESS-GOTO-THRU | `unexpected indent` | SORT INPUT/OUTPUT PROCEDURE generates broken indentation | Medium — fix SORT codegen indent |
| STRESS-INIT-GROUP | `unexpected indent` | Multiple INSPECT TALLYING variants generate broken indentation | Medium — fix INSPECT indent |

**Pattern**: 4/6 compile errors are the same bug (EVALUATE ALSO → invalid Decimal). Fixing 2 bugs would eliminate all 6 compile errors and add 4+ to PVR.

---

## MR Flag Frequency Table (116 flags across 33 programs)

### Ranked by frequency — this is the build priority list

| # | Construct | Flags | Programs | Fixability | Effort | Priority |
|---|-----------|-------|----------|------------|--------|----------|
| 1 | **INSPECT TALLYING (CHARACTERS/LEADING/BEFORE/AFTER)** | 30 | 10 | Doable — extend existing TALLYING FOR ALL handler | 1-2 weeks | **P0** |
| 2 | **ALTER** | 12 | 6 | Hard — requires runtime paragraph-target mutation | 2-3 weeks | P2 |
| 3 | **INSPECT REPLACING (FIRST/CHARACTERS/BEFORE/AFTER)** | 12 | 5 | Doable — extend existing REPLACING ALL handler | 1 week | **P0** |
| 4 | **UNSTRING (OR/POINTER/TALLYING/DELIMITER-IN/COUNT-IN)** | 10 | 8 | Doable — extend existing simple UNSTRING handler | 1-2 weeks | **P1** |
| 5 | **SORT (INPUT/OUTPUT PROCEDURE)** | 10 | 5 | Medium — need SD file, RELEASE/RETURN, procedure refs | 2-3 weeks | P2 |
| 6 | **DISPLAY inside IF branch** | 8 | 5 | Easy — DISPLAY-in-branch detection already works, likely parser edge case | 2-3 days | **P0** |
| 7 | **STRING (OVERFLOW/POINTER non-SIZE)** | 6 | 4 | Doable — extend existing STRING DELIMITED BY SIZE handler | 1 week | **P1** |
| 8 | **INSPECT REPLACING (complex: CHARACTERS BEFORE/AFTER)** | 4 | 1 | Doable — same work as #3 | included in #3 | **P0** |
| 9 | **READ KEY / REWRITE / OPEN I-O** | 4 | 2 | Medium — extends file I/O system | 1-2 weeks | P2 |
| 10 | **SORT codegen indent bug** | 2 | 2 | Easy — fix indentation in SORT handler | 1 day | **P0** |

### Constructs that PASSED despite being on the MR list (engine is stronger than documented)

| Construct | Programs Using It | Result |
|-----------|-------------------|--------|
| EVALUATE ALSO | 9 | Mostly VERIFIED (4 compile errors from Decimal bug, not MR) |
| 88-level THRU range | 9 | All VERIFIED |
| 88-level multiple values | ~5 | All VERIFIED |
| GO TO DEPENDING ON | 5 | All VERIFIED |
| OCCURS DEPENDING ON | 5 | All VERIFIED |
| INSPECT CONVERTING | 5 | All VERIFIED |
| STRING POINTER (basic) | 8 | Mostly VERIFIED (some flagged when combined with OVERFLOW) |

**Key insight**: The engine already handles EVALUATE ALSO, 88-level THRU/multi-value, GO TO DEPENDING ON, OCCURS DEPENDING ON, and INSPECT CONVERTING. CLAUDE.md Section 18 needs updating — these should move from "Flagged MANUAL REVIEW" to "Fully emitted."

---

## 4-Week Build Priority Roadmap

### Week 1 — Low-hanging fruit (+8-10 PVR points)
1. **Fix EVALUATE ALSO Decimal codegen bug** (compile errors → 4 programs recover)
2. **Fix DISPLAY-inside-IF-branch** edge case (5 programs)
3. **Fix SORT/INSPECT indent bugs** (2 programs)

### Week 2 — INSPECT expansion (+10-12 PVR points)
4. **INSPECT TALLYING CHARACTERS/LEADING/BEFORE/AFTER** — extend `_emit_inspect_tallying`
5. **INSPECT REPLACING FIRST/CHARACTERS/BEFORE/AFTER** — extend `_emit_inspect_replacing`

### Week 3 — STRING/UNSTRING completion (+6-8 PVR points)
6. **STRING with OVERFLOW clause** — add ON OVERFLOW / NOT ON OVERFLOW branches
7. **STRING with non-SIZE delimiters** (DELIMITED BY SPACES, DELIMITED BY literal)
8. **UNSTRING with OR delimiter** — split on multiple delimiters
9. **UNSTRING POINTER/TALLYING/DELIMITER-IN/COUNT-IN** — extend existing handler

### Week 4 — Hard constructs (+4-6 PVR points)
10. **ALTER** — runtime paragraph dispatch mutation (consider: intentional MR may be acceptable)
11. **SORT with INPUT/OUTPUT PROCEDURE** — SD file, RELEASE, RETURN
12. **READ KEY / REWRITE / OPEN I-O** — indexed file operations

**Projected PVR after 4 weeks: 85-95%** (assuming ~30 of the 39 failing programs become clean)

---

## Per-Program Status

### VERIFIED (61 programs)
ACCT-BALANCE-ADD, ACCT-BALANCE-SUB, ACCT-FEE-CALC, ACCT-INTEREST, ACCT-REDEFINE, APPLY-PENALTY, ARITHMETIC-STRESS, BATCH-RATE-TABLE, CALC-INT, COMPOUND-INT, COMPUTE-CHAIN, COMPUTE-MULTI-TARGET, CREDIT-SCORE, CSV-PARSER, DATA-CLEANER, DEEP-NEST, DEMO-WITH-COPY, DEMO_LOAN_INTEREST, DISPLAY-MIX, DIV-REMAINDER, DYNAMIC-TABLE, EVAL-88-LEVEL, EVAL-88-MULTI, EVAL-88-NESTED, EVAL-ALSO, EVAL-IN-VARY, EVAL-VARIABLE, EVAL-WHEN-COMPOUND, EVALUATE-TEST, GOTO-DEPEND, GOTO-FLOW, INIT-TEST, INSPECT-CONV, INTR-CALC-3270, INVOICE-GEN, LOAN-AMORT-CALC, LOAN-SIMPLE-INT, MAIN-LOAN, MONTHLY-TOTALS, MOVE-CORR-ACCT, MOVE-CORR-MIXED, MSG-BUILDER, NESTED-EVAL, PAYROLL-CALC, PERF-THRU-BRANCH, PERF-UNTIL-OR, PERFORM-VARYING-TEST, REFMOD-CONDITION, REPEAT-TIMES, RPT-STRING-HDR, STATUS-CHECKER, STRESS-DISPLAY-MIX, STRING-PTR, TXN-APPROVE-FLOW, TXN-BATCH-CHECK, TXN-VALIDATE-IF, TYPE-CHECKER, VARY-AFTER-ACCUM, VARY-AFTER-MATRIX, VARY-AFTER-STEP, WIRE-VALIDATE

### MANUAL REVIEW (33 programs, 116 flags)
| Program | MR Count | Trigger Constructs |
|---------|----------|--------------------|
| ALTER-DANGER | 2 | ALTER |
| ALTER-TEST | 2 | ALTER |
| BATCH-MONTHLY | 1 | DISPLAY inside IF |
| BATCH-PAYMENT | 2 | MULTIPLY inside IF (parser edge) |
| BATCH-TOTAL-VARY | 2 | INSPECT TALLYING LEADING |
| COMPUTE-COMPOUND | 4 | INSPECT TALLYING LEADING + CHARACTERS |
| EVAL-VARY-ACCUM | 4 | UNSTRING complex + INSPECT TALLYING LEADING |
| EVAL-VARY-STRING | 2 | STRING with OVERFLOW |
| EXEC-SQL-TEST | 1 | DISPLAY inside IF (EXEC SQL context) |
| LOAN-PENALTY | 2 | UNSTRING DELIMITER-IN/COUNT-IN |
| MOVE-CORR-EMPTY | 4 | INSPECT TALLYING CHARACTERS + LEADING |
| PERF-THRU-GOTO | 2 | ALTER |
| PERF-THRU-SEQ | 2 | INSPECT REPLACING FIRST |
| PERF-TIMES-COND | 2 | UNSTRING with OR |
| PERF-TIMES-NEST | 6 | INSPECT TALLYING CHARACTERS + LEADING (x3) |
| PERF-TIMES-PARA | 2 | STRING with OVERFLOW |
| PERF-UNTIL-88 | 4 | INSPECT REPLACING CHARACTERS BEFORE/AFTER |
| PERF-UNTIL-AND | 2 | SORT INPUT/OUTPUT PROCEDURE |
| REFMOD-DATE-PARSE | 4 | INSPECT REPLACING FIRST (x2) |
| REFMOD-WRITE | 2 | SORT INPUT/OUTPUT PROCEDURE |
| RPT-LINE-BUILD | 2 | UNSTRING with OR |
| RPT-SUMMARY | 4 | INSPECT REPLACING FIRST + TALLYING CHARACTERS |
| STRESS-DEEP-NEST | 2 | ALTER |
| STRESS-DIV-REMAINDER | 4 | SORT + READ + REWRITE |
| STRESS-EVAL-PERFORM | 2 | SORT INPUT/OUTPUT PROCEDURE |
| STRESS-EXEC-SQL | 3 | DISPLAY inside EXEC SQL context |
| STRESS-INSPECT-BOTH | 12 | INSPECT TALLYING + REPLACING (all variants) |
| STRESS-MIXED-COMP | 2 | READ KEY + REWRITE |
| STRESS-REDEFINES-COMP3 | 2 | UNSTRING complex |
| STRESS-STRING-OVERFLOW | 10 | STRING OVERFLOW + UNSTRING OR + INSPECT TALLYING |
| STRESS-THRU-GOTO-OUT | 2 | ALTER |
| STRESS-UNSTRING | 2 | UNSTRING complex |
| UNSTR-COMPLEX | 2 | UNSTRING complex |

### COMPILE ERROR (6 programs)
| Program | Error | MR Count |
|---------|-------|----------|
| EVAL-NESTED-WHEN | invalid decimal (EVALUATE ALSO Decimal bug) | 0 |
| EVAL-WHEN-RANGE | invalid decimal (EVALUATE ALSO Decimal bug) | 0 |
| STRESS-GOTO-THRU | unexpected indent (SORT codegen) | 2 |
| STRESS-INIT-GROUP | unexpected indent (INSPECT codegen) | 9 |
| STRESS-NAME-COLLISION | invalid decimal (EVALUATE ALSO Decimal bug) | 2 |
| STRESS-PIC-OVERFLOW | invalid decimal (EVALUATE ALSO Decimal bug) | 2 |

---

## Construct Coverage Matrix (what the corpus now tests)

| Construct | # Programs | Engine Status |
|-----------|-----------|---------------|
| MOVE | 87 | Fully supported |
| DISPLAY | 63 | Supported (edge case in IF branches) |
| IF/ELSE | 46 | Fully supported |
| COMPUTE | 42 | Fully supported |
| ADD | 40 | Fully supported |
| PERFORM | 39 | Fully supported |
| COMP-3 | 33 | Fully supported |
| 88-level | 20 | **Fully supported (including THRU + multi-value)** |
| STRING | 15 | Partial (SIZE ok, POINTER/OVERFLOW = MR) |
| SUBTRACT | 14 | Fully supported |
| EVALUATE TRUE | 13 | Fully supported |
| GO TO | 13 | Fully supported |
| PERFORM TIMES | 12 | Fully supported |
| OCCURS | 11 | **Fully supported (including DEPENDING ON)** |
| MULTIPLY | 11 | Fully supported |
| EVALUATE variable | 10 | Fully supported |
| INSPECT TALLYING | 10 | Partial (ALL ok, CHARACTERS/LEADING/BEFORE/AFTER = MR) |
| UNSTRING | 10 | Partial (simple ok, OR/POINTER/TALLYING/DELIMITER-IN = MR) |
| PERFORM VARYING | 9 | Fully supported |
| EVALUATE ALSO | 9 | **Mostly works (Decimal codegen bug in some combos)** |
| 88 THRU | 9 | **Fully supported** |
| DIVIDE | 8 | Fully supported |
| STRING POINTER | 8 | Partial (some combos trigger MR) |
| ALTER | 6 | MR (intentional — runtime mutation) |
| INITIALIZE | 6 | Fully supported |
| PERFORM THRU | 6 | Fully supported |
| OCCURS DEPENDING | 5 | **Fully supported** |
| INSPECT CONVERTING | 5 | **Fully supported** |
| GO TO DEPENDING | 5 | **Fully supported** |
| INSPECT REPLACING | 4 | Partial (ALL ok, FIRST/CHARACTERS/BEFORE/AFTER = MR) |
| SORT | ~5 | MR (INPUT/OUTPUT PROCEDURE not supported) |
| REDEFINES | 3 | Detected, no codegen issues |
| DIVIDE REMAINDER | 3 | Fully supported |
| EXEC SQL | 2 | Detected + flagged (intentional MR) |
| READ KEY / REWRITE | 2 | MR (indexed I/O not supported) |

---

## Key Findings

1. **The engine is stronger than documented.** EVALUATE ALSO, 88-level THRU/multi-value, GO TO DEPENDING ON, OCCURS DEPENDING ON, and INSPECT CONVERTING all work but are listed as MR in CLAUDE.md.

2. **Two bugs cause 6 compile errors.** EVALUATE ALSO has a Decimal literal codegen bug, and SORT/INSPECT have indentation bugs. Fixing these recovers 4-6 programs immediately.

3. **INSPECT is the #1 gap.** TALLYING CHARACTERS/LEADING/BEFORE/AFTER and REPLACING FIRST/CHARACTERS/BEFORE/AFTER account for 42+ of 116 MR flags. This is the highest-ROI fix.

4. **UNSTRING extensions are #2.** OR delimiters, POINTER, TALLYING, DELIMITER-IN, COUNT-IN account for 10 flags across 8 programs.

5. **ALTER is intentionally hard** and may remain MR permanently (runtime paragraph mutation is rare and dangerous in real COBOL).

6. **SORT with INPUT/OUTPUT PROCEDURE** is a real gap for batch processing programs but is architecturally complex (needs SD work file, RELEASE/RETURN verbs).
