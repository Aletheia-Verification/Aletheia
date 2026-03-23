# Aletheia PVR Report — 100 Programs
**Date**: 2026-03-15
**Engine version**: 567 tests passing, 0 failures
**Corpus**: 25 embedded + 15 existing .cbl + 60 new corpus programs = 100 total

---

## Summary

| Metric | Value |
|--------|-------|
| Programs tested | 100 |
| Parse success | 99/100 (99.0%) |
| Generate success | 100/100 (100.0%) |
| Compile success | 100/100 (100.0%) |
| Clean VERIFIED (0 MR) | **89/100** |
| With MANUAL REVIEW | 11 programs, 20 flags |
| **PVR** | **89.0%** |

---

## MANUAL REVIEW Reason Frequency

| Reason | Count | Programs |
|--------|-------|----------|
| ALTER statement (hard block) | 4 | ALTER-DANGER, ALTER-TEST |
| DISPLAY inside IF branch (literal-only) | 5 | STRESS-DISPLAY-MIX, STRESS-EXEC-SQL, STRESS-INIT-GROUP, EXEC-SQL-TEST, BATCH-MONTHLY |
| STRING with ON OVERFLOW | 2 | STRESS-STRING-OVERFLOW |
| INSPECT TALLYING (complex multi-target) | 2 | STRESS-INSPECT-BOTH |
| UNSTRING with OR/POINTER/TALLYING/DELIMITER-IN | 2 | UNSTR-COMPLEX |
| MULTIPLY parse gap (nested IF context) | 2 | BATCH-PAYMENT |
| EXEC SQL host variable display | 1 | STRESS-EXEC-SQL |

**Top MR triggers to address next**:
1. DISPLAY inside IF branches with literal-only args (5 flags across 4 programs) — low-hanging fruit
2. INSPECT TALLYING multi-target (2 flags) — complex but high ROI
3. STRING ON OVERFLOW (2 flags) — needs overflow handler emission

---

## Per-Program Status (100 programs)

### VERIFIED (89 programs)

| Program | Lines | Source | Constructs |
|---------|-------|--------|------------|
| ACCT-BALANCE-ADD | 47 | corpus | ADD GIVING |
| ACCT-BALANCE-SUB | 53 | corpus | SUBTRACT, ON SIZE ERROR |
| ACCT-FEE-CALC | 46 | corpus | EVALUATE TRUE, SUBTRACT GIVING |
| ACCT-INTEREST | 124 | demo_data | COMP-3, nested IF, COMPUTE |
| ACCT-REDEFINE | 22 | embedded | REDEFINES |
| APPLY-PENALTY | 23 | demo_data | IF/ELSE, COMPUTE |
| ARITHMETIC-STRESS | 102 | demo_data | mixed arithmetic |
| BATCH-RATE-TABLE | 62 | corpus | OCCURS, PERFORM VARYING |
| BATCH-TOTAL-VARY | 52 | corpus | PERFORM VARYING, ADD |
| CALC-INT | 18 | demo_data | COMPUTE |
| COMPOUND-INT | 27 | embedded | COMPUTE with ** |
| COMPUTE-CHAIN | 21 | corpus | chained COMPUTE ROUNDED |
| COMPUTE-COMPOUND | 23 | corpus | COMPUTE ROUNDED |
| COMPUTE-MULTI-TARGET | 33 | corpus | multi-step COMPUTE, IF |
| CREDIT-SCORE | 180 | demo_data | nested EVALUATE, COMP-3 |
| CSV-PARSER | 21 | embedded | UNSTRING simple |
| DATA-CLEANER | 20 | embedded | INSPECT TALLYING + REPLACING |
| DEEP-NEST | 34 | embedded | 5-level nested IF |
| DEMO-WITH-COPY | 36 | demo_data | COPY statement |
| DEMO_LOAN_INTEREST | 93 | root | COMP-3, 88-level, nested IF |
| DISPLAY-MIX | 18 | embedded | DISPLAY mixed operands |
| DIV-REMAINDER | 18 | embedded | DIVIDE REMAINDER |
| DYNAMIC-TABLE | 25 | embedded | OCCURS DEPENDING ON |
| EVAL-88-LEVEL | 48 | corpus | EVALUATE TRUE with 88-levels |
| EVAL-88-MULTI | 45 | corpus | 88-levels, SET TO TRUE |
| EVAL-88-NESTED | 61 | corpus | nested EVALUATE + IF with 88s |
| EVAL-ALSO | 22 | embedded | EVALUATE ALSO |
| EVAL-IN-VARY | 43 | corpus | EVALUATE inside PERFORM VARYING |
| EVAL-NESTED-WHEN | 33 | corpus | nested EVALUATE |
| EVAL-VARIABLE | 36 | embedded | EVALUATE variable |
| EVAL-VARY-ACCUM | 51 | corpus | VARYING + EVALUATE + accumulate |
| EVAL-VARY-STRING | 54 | corpus | VARYING + EVALUATE + STRING |
| EVAL-WHEN-COMPOUND | 27 | corpus | EVALUATE with compound AND |
| EVAL-WHEN-RANGE | 27 | corpus | EVALUATE TRUE range conditions |
| EVALUATE-TEST | 60 | demo_data | EVALUATE patterns |
| GOTO-DEPEND | 21 | embedded | GO TO DEPENDING ON |
| GOTO-FLOW | 26 | embedded | GO TO paragraph flow |
| INIT-TEST | 22 | embedded | INITIALIZE |
| INSPECT-CONV | 12 | embedded | INSPECT CONVERTING |
| INTR-CALC-3270 | 37 | root | COMP-3 (parse warnings, recovers) |
| INVOICE-GEN | 59 | embedded | PERFORM VARYING + EVALUATE + STRING |
| LOAN-AMORT-CALC | 52 | corpus | COMPUTE ROUNDED, multi-step |
| LOAN-PENALTY | 52 | corpus | nested IF, COMP-3 |
| LOAN-SIMPLE-INT | 38 | corpus | simple interest, COMP-3 |
| MAIN-LOAN | 34 | demo_data | COMPUTE |
| MONTHLY-TOTALS | 28 | embedded | OCCURS, PERFORM VARYING |
| MOVE-CORR-ACCT | 26 | corpus | MOVE CORRESPONDING |
| MOVE-CORR-EMPTY | 20 | corpus | MOVE CORR no overlap |
| MOVE-CORR-MIXED | 30 | corpus | MOVE CORR mixed types |
| MSG-BUILDER | 18 | embedded | STRING DELIMITED BY SIZE |
| NESTED-EVAL | 38 | embedded | nested EVALUATE inside IF |
| PAYROLL-CALC | 47 | embedded | PERFORM THRU, arithmetic |
| PERF-THRU-BRANCH | 48 | corpus | PERFORM THRU with IF inside |
| PERF-THRU-GOTO | 36 | corpus | PERFORM THRU with GO TO |
| PERF-THRU-SEQ | 35 | corpus | PERFORM THRU sequential |
| PERF-TIMES-COND | 34 | corpus | PERFORM TIMES with IF/GO TO |
| PERF-TIMES-NEST | 31 | corpus | nested PERFORM TIMES |
| PERF-TIMES-PARA | 31 | corpus | PERFORM TIMES paragraph |
| PERF-UNTIL-88 | 34 | corpus | PERFORM UNTIL 88-level |
| PERF-UNTIL-AND | 28 | corpus | PERFORM UNTIL compound AND |
| PERF-UNTIL-OR | 29 | corpus | PERFORM UNTIL compound OR |
| PERFORM-VARYING-TEST | 71 | demo_data | PERFORM VARYING patterns |
| REFMOD-CONDITION | 26 | corpus | reference modification in IF |
| REFMOD-DATE-PARSE | 23 | corpus | refmod read + STRING |
| REFMOD-WRITE | 21 | corpus | refmod write targets |
| REPEAT-TIMES | 16 | embedded | PERFORM TIMES |
| RPT-LINE-BUILD | 41 | corpus | STRING multi-source |
| RPT-STRING-HDR | 44 | corpus | STRING building header |
| RPT-SUMMARY | 81 | corpus | STRING + COMPUTE for report |
| STATUS-CHECKER | 35 | embedded | 88-level THRU ranges |
| STRESS-DEEP-NEST | 80 | corpus | 21-level nested IF |
| STRESS-DIV-REMAINDER | 27 | corpus | DIVIDE REMAINDER + SIZE ERROR |
| STRESS-EVAL-PERFORM | 37 | corpus | EVALUATE after PERFORM |
| STRESS-GOTO-THRU | 32 | corpus | GO TO inside PERFORM THRU |
| STRESS-MIXED-COMP | 33 | corpus | COMP + COMP-3 + COMP-5 + DISPLAY |
| STRESS-NAME-COLLISION | 38 | corpus | 4 groups, repeated field names |
| STRESS-PIC-OVERFLOW | 28 | corpus | PIC boundary overflow tests |
| STRESS-REDEFINES-COMP3 | 22 | corpus | REDEFINES COMP-3 / PIC X |
| STRESS-THRU-GOTO-OUT | 32 | corpus | THRU range with GO TO outside |
| STRESS-UNSTRING | 18 | corpus | UNSTRING simple delimiter |
| STRING-PTR | 16 | embedded | STRING with POINTER |
| TXN-APPROVE-FLOW | 71 | corpus | nested IF, compound AND |
| TXN-BATCH-CHECK | 56 | corpus | PERFORM VARYING + IF validation |
| TXN-VALIDATE-IF | 59 | corpus | 4-level nested IF |
| TYPE-CHECKER | 25 | embedded | IS NUMERIC / IS ALPHABETIC |
| VARY-AFTER-ACCUM | 22 | corpus | PERFORM VARYING AFTER |
| VARY-AFTER-MATRIX | 19 | corpus | VARYING AFTER matrix |
| VARY-AFTER-STEP | 19 | corpus | VARYING AFTER custom step |
| WIRE-VALIDATE | 130 | demo_data | STRING in branches |

### MANUAL REVIEW (11 programs)

| Program | Lines | MR Flags | Reason |
|---------|-------|----------|--------|
| ALTER-DANGER | 18 | 2 | ALTER statement (hard block) |
| ALTER-TEST | 25 | 2 | ALTER statement (hard block) |
| BATCH-MONTHLY | 49 | 1 | DISPLAY with literal in IF branch |
| BATCH-PAYMENT | 192 | 2 | MULTIPLY parse gap in nested IF |
| EXEC-SQL-TEST | 45 | 1 | DISPLAY with DB error variable |
| STRESS-DISPLAY-MIX | 27 | 2 | DISPLAY literal-only in IF branches |
| STRESS-EXEC-SQL | 25 | 3 | EXEC SQL + DISPLAY with host vars |
| STRESS-INIT-GROUP | 28 | 1 | DISPLAY literal in IF branch |
| STRESS-INSPECT-BOTH | 21 | 2 | INSPECT TALLYING multi-target |
| STRESS-STRING-OVERFLOW | 26 | 2 | STRING with ON OVERFLOW |
| UNSTR-COMPLEX | 20 | 2 | UNSTRING with OR/POINTER/TALLYING |

### CRASH (0 programs)

None.

---

## Construct Coverage (34 constructs detected)

| Construct | Programs Using |
|-----------|---------------|
| STOP RUN | 97 |
| MOVE | 86 |
| DISPLAY | 63 |
| COMPUTE | 40 |
| IF/ELSE | 40 |
| ADD | 38 |
| PERFORM | 36 |
| COMP-3 | 33 |
| EVALUATE TRUE | 17 |
| SUBTRACT | 13 |
| 88-level | 11 |
| MULTIPLY | 11 |
| PERFORM TIMES | 10 |
| STRING | 9 |
| DIVIDE | 8 |
| GO TO | 8 |
| PERFORM VARYING | 8 |
| EVALUATE variable | 6 |
| PERFORM THRU | 6 |
| OCCURS | 5 |
| INITIALIZE | 4 |
| UNSTRING | 4 |
| REDEFINES | 3 |
| DIVIDE REMAINDER | 3 |
| ALTER | 2 |
| EXEC SQL | 2 |
| COPY | 1 |
| EVALUATE ALSO | 1 |
| 88 THRU | 1 |
| INSPECT TALLYING | 1 |
| INSPECT REPLACING | 1 |
| STRING POINTER | 1 |
| IS ALPHABETIC | 1 |
| IS NUMERIC | 1 |

---

## Notes
- Parse failure on INTR-CALC-3270 is a known issue (3270 screen formatting) — generator recovers
- ALTER is a hard stop by design (forces REQUIRES_MANUAL_REVIEW per CLAUDE.md)
- DISPLAY-in-IF-branch MR flags are the #1 low-hanging fruit for PVR improvement
- BATCH-PAYMENT MULTIPLY parse gap is a pre-existing issue in the embedded programs
- All 60 new corpus programs: 55 VERIFIED, 5 with MR flags (as designed for stress testing)
