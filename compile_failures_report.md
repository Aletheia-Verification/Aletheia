# Compile Failures Report — 200-Program Viability Experiment

19 programs fail at Python `compile()`. All parse and generate successfully — the bugs are in the **generated Python**, not the COBOL source. Three root causes account for all 19 failures.

---

## Root Cause 1: Compound OR conditions with 88-level names → `if True # MANUAL REVIEW`

**Bug:** When an `IF` statement uses `OR` to combine two 88-level condition names (e.g., `IF WS-LATE OR WS-DEFAULT`), the generator cannot resolve the compound condition. It emits `if True  # MANUAL REVIEW: WS-LATEORWS-DEFAULT:` — but the `# MANUAL REVIEW` comment is placed **before the colon**, producing invalid Python syntax: `if True  # comment:` instead of `if True:  # comment`.

**File to fix:** `generate_full_python.py` — the condition-to-Python emitter. The `# MANUAL REVIEW` fallback for unrecognized conditions needs the colon placed before the comment, or `parse_conditions.py` needs to handle compound `OR` of 88-levels.

**Affected programs (12):**

| # | Program | Generated Python (line) | COBOL Construct |
|---|---------|------------------------|-----------------|
| 1 | ACCT-TITLE-CHANGE.cbl | `if True  # MANUAL REVIEW: WS-NEW-FIRST(1:1)ISNUMERIC:` (line 100) | `IF WS-NEW-FIRST(1:1) IS NUMERIC` (substring reference in condition) |
| 2 | LOAN-GRACE-PERIOD-CALC.cbl | `if True  # MANUAL REVIEW: WS-LATEORWS-DEFAULT:` (line 138) | `IF WS-LATE OR WS-DEFAULT` |
| 3 | LOAN-PMI-REMOVAL.cbl | `if True  # MANUAL REVIEW: WS-PMI-AUTO-REMOVEORWS-PMI-ELIGIBLE:` (line 148) | `IF WS-PMI-AUTO-REMOVE OR WS-PMI-ELIGIBLE` |
| 4 | MR-ODO-INVOICE.cbl | `if True  # MANUAL REVIEW: WS-IL-TAXABLE(WS-IDX):` (line 101) | `IF WS-IL-TAXABLE(WS-IDX)` (bare 88-level with subscript) |
| 5 | PAY-ADDENDA-PARSE.cbl | `if True  # MANUAL REVIEW: WS-RETURNSORWS-PAYMENT-RELORWS-ADDENDA-CTX:` (line 101) | `IF WS-RETURNS OR WS-PAYMENT-REL OR WS-ADDENDA-CTX` |
| 6 | PAY-LIMIT-ENFORCE.cbl | `if True  # MANUAL REVIEW: WS-APPROVEDORWS-PENDING-REVIEW:` (line 121) | `IF WS-APPROVED OR WS-PENDING-REVIEW` |
| 7 | PAY-PRENOTE-VALID.cbl | `if True  # MANUAL REVIEW: WS-ACCT-NUM(1:1)ISNUMERIC:` (line 124) | `IF WS-ACCT-NUM(1:1) IS NUMERIC` (substring IS NUMERIC) |
| 8 | PAY-SAME-DAY-ACH.cbl | `if True  # MANUAL REVIEW: WS-CREDIT-TXNORWS-DEBIT-TXNORWS-PAYROLL-TXN:` (line 116) | `IF WS-CREDIT-TXN OR WS-DEBIT-TXN OR WS-PAYROLL-TXN` |
| 9 | REG-CRA-GEOCODE.cbl | `if True  # MANUAL REVIEW: WS-LOW-INCOMEORWS-MODERATE:` (line 100) | `IF WS-LOW-INCOME OR WS-MODERATE` |
| 10 | REG-TIN-VALIDATOR.cbl | `if True  # MANUAL REVIEW: WS-TIN-VALUEISNUMERIC:` (line 85) | `IF WS-TIN-VALUE IS NUMERIC` (IS NUMERIC on non-working-storage field) |
| 11 | TRADE-TAX-LOT-CALC.cbl | `if True  # MANUAL REVIEW: WS-LT-LONG(WS-LT-IDX):` (line 90) | `IF WS-LT-LONG(WS-LT-IDX)` (bare 88-level with subscript) |
| 12 | FRAUD-LINK-ANALYZE.cbl | `if True  # MANUAL REVIEW: WS-BLOCKORWS-REVIEW:` (line 99) | `IF WS-BLOCK OR WS-REVIEW` |

**Sub-variants within this root cause:**
- **Compound OR of 88-levels** (8 programs): `IF cond-A OR cond-B` where both are 88-level names
- **Substring reference in IS NUMERIC** (2 programs): `IF WS-FIELD(1:1) IS NUMERIC`
- **Bare 88-level with subscript** (2 programs): `IF WS-CONDITION(IDX)` — subscripted 88-level as sole condition

---

## Root Cause 2: Nested IF inside EVALUATE WHEN → empty `if` body

**Bug:** When `EVALUATE TRUE / WHEN condition / IF nested-condition / statement / END-IF` appears, the generator sometimes emits the nested IF as a comment-only block (no executable statement), producing `if ...:` followed by only a comment, then `elif`. Python requires at least one statement in an `if` body.

**File to fix:** `generate_full_python.py` — the EVALUATE/WHEN emitter. When a nested IF inside a WHEN branch falls back to `# MANUAL REVIEW`, the generator should emit `pass` as a placeholder body.

**Affected programs (2):**

| # | Program | Generated Python (line) | COBOL Construct |
|---|---------|------------------------|-----------------|
| 13 | MR-EXEC-SQL-UPDATE.cbl | Empty body after `if` (line 117→120) — `# MANUAL REVIEW: Nested IF` then `elif` | `EVALUATE TRUE / WHEN WS-SAVINGS / IF WS-INT-AMOUNT < 0.01 ... END-IF` |
| 14 | PAY-NSF-FEE-CALC.cbl | Empty body after `if` (line 98→101) — `# MANUAL REVIEW: Nested IF` then `elif` | `EVALUATE TRUE / WHEN WS-PREMIUM / IF WS-SHORTFALL <= 500 ... ELSE ... END-IF` |

---

## Root Cause 3: PERFORM VARYING inside IF/EVALUATE → inline spaghetti

**Bug:** When a `PERFORM VARYING ... END-PERFORM` loop appears **inside** an IF branch or EVALUATE WHEN branch (rather than at paragraph level), the generator fails to emit a proper Python `while` loop. Instead, it concatenates the entire PERFORM body into a single garbled line like `para_varyingws_al_idxfrom1by1until...end_perform()`.

**File to fix:** `generate_full_python.py` — the PERFORM VARYING emitter. It currently only handles PERFORM VARYING at paragraph/statement level. When encountered inside an IF or EVALUATE branch, it falls back to dumping the raw text as a pseudo-function call.

**Affected programs (5):**

| # | Program | Generated Python (line) | COBOL Construct |
|---|---------|------------------------|-----------------|
| 15 | PAY-RECUR-SCHED.cbl | `para_varyingws_up_idxfrom1by1until...end_perform()` (line 145) | `PERFORM VARYING` inside IF branch (display loop) |
| 16 | TRADE-CUSTODY-FEE.cbl | `para_varyingws_as_idxfrom1by1until...end_perform()` (line 68) | `PERFORM VARYING` inside EVALUATE WHEN branch |
| 17 | TREAS-POOL-ALLOC.cbl | `para_varyingws_al_idxfrom1by1until...end_perform()` (line 110) | `PERFORM VARYING` inside IF branch |
| 18 | INS-COINSURE-SPLIT.cbl | `para_varyingws_cr_idxfrom1by1until...end_perform()` (line 100) | `PERFORM VARYING` inside IF branch (display loop) |
| 19 | REG-OFAC-MATCH.cbl | `para_varyingws_sdn_idxfrom1by1until...end_perform()` (line 96) | `PERFORM VARYING` inside IF with nested IF/INSPECT |

---

## Summary

| Root Cause | Count | File to Fix | Fix Complexity |
|-----------|-------|-------------|----------------|
| 1. Compound OR / substring / subscripted 88-level in IF condition | 12 | `parse_conditions.py` + `generate_full_python.py` | Medium — need to handle OR-combined 88-levels and substring IS NUMERIC |
| 2. Nested IF inside EVALUATE WHEN → empty body | 2 | `generate_full_python.py` | Easy — emit `pass` when nested IF produces only comments |
| 3. PERFORM VARYING inside IF/EVALUATE → inline dump | 5 | `generate_full_python.py` | Medium — need to recognize inline PERFORM VARYING and emit proper while loop |

**Fixing root causes 1-3 would eliminate all 19 compile failures, pushing PVR from 82.5% to ~92%.**
