# MANUAL REVIEW Root Cause Analysis — PVR 84.0% (168/200)

32 programs, 103 flags. Every flag categorized below.

---

## Intentional (not fixable)

### 1. ALTER statement (hard stop)
- **Construct:** `ALTER paragraph-name TO PROCEED TO paragraph-name`
- **Programs (7):** ALTER-DANGER, ALTER-SQL-HYBRID, ALTER-TEST, LEGACY-ALTER-DISPATCH, MR-ALTER-DISPATCH-V2, MR-ALTER-FALLBACK, MR-ALTER-RECOVERY
- **Flags:** 58 (each ALTER emits ~2-3 flags: getText blob + structured text + validation entry)
- **Status:** Intentional. ALTER is obsolete, untranslatable, and correctly flagged. Never fix.

---

## Fixable root causes (ordered by PVR impact)

### 2. Compound OR of 88-level condition names
- **Construct:** `IF WS-LATE OR WS-DEFAULT` where both are 88-level names
- **getText blob:** `WS-LATEORWS-DEFAULT` — OR concatenated without spaces
- **Programs (6):** FRAUD-LINK-ANALYZE, LOAN-PMI-REMOVAL, PAY-ADDENDA-PARSE, PAY-LIMIT-ENFORCE, PAY-SAME-DAY-ACH, REG-CRA-GEOCODE
- **Flags:** 12
- **Fix:** `parse_conditions.py:_convert_condition()` — detect `OR` between two 88-level names in getText() blob, split and emit `cond_a or cond_b`
- **PVR impact:** All 6 have ONLY this root cause. Fix = **+6 VERIFIED → PVR 87.0%**

### 3. CONTINUE statement not handled
- **Construct:** `CONTINUE` (COBOL no-op, equivalent to Python `pass`)
- **Programs (5):** EMBEDDED-SQL-BATCH, FRAUD-RULE-ENGINE, INS-CLAIM-ADJUDIC, MR-EXEC-SQL-UPDATE, REG-HMDA-EXTRACT
- **Flags:** 7
- **Fix:** `parse_conditions.py:_convert_single_statement()` — add handler: `if upper == "CONTINUE": return f"{indent}pass", issues`
- **PVR impact:** 4 of 5 have ONLY this root cause. Fix = **+4 VERIFIED → PVR 89.0%** (cumulative with #2)

### 4. WRITE statement in IF branch
- **Construct:** `WRITE record-name` inside IF/EVALUATE branch
- **getText blob:** `WRITERPT-RECORD`
- **Programs (3):** DEP-UNCLM-PROP, MISC-AUDIT-TRAIL, TAX-1099-INT-GEN
- **Flags:** 3
- **Fix:** `parse_conditions.py:_convert_single_statement()` — add WRITE handler: emit `_io_write('RECORD-NAME')` (same pattern as existing I/O verbs)
- **PVR impact:** All 3 have ONLY this root cause. Fix = **+3 VERIFIED → PVR 90.5%**

### 5. Nested IF without structured data (inside EVALUATE WHEN)
- **Construct:** `IF condition ... END-IF` inside EVALUATE WHEN branch — analyzer doesn't capture as structured condition
- **Programs (3):** LOAN-GRACE-PERIOD-CALC, MR-EXEC-SQL-UPDATE, PAY-NSF-FEE-CALC
- **Flags:** 5
- **Fix:** `parse_conditions.py:_convert_single_statement()` — when nested IF not in `all_conditions_by_text`, try text-based parsing instead of MANUAL REVIEW
- **PVR impact:** 1 has only this root cause (PAY-NSF-FEE-CALC). 2 overlap with OR/CONTINUE. Fix all three: **+3 VERIFIED → PVR 92.0%** (cumulative)

### 6. Subscripted 88-level as bare condition
- **Construct:** `IF WS-TAXABLE(WS-IDX)` — 88-level name with subscript used as sole condition
- **Programs (2):** MR-ODO-INVOICE, TRADE-TAX-LOT-CALC
- **Flags:** 3
- **Fix:** `parse_conditions.py:_convert_condition()` — detect `VARNAME(SUBSCRIPT)` pattern, look up base name in level_88_map, emit subscripted parent comparison
- **PVR impact:** Both have ONLY this root cause. Fix = **+2 VERIFIED → PVR 93.0%**

### 7. IS NUMERIC on substring/unknown variable
- **Construct:** `IF WS-FIELD(1:1) IS NUMERIC` or `IF WS-TIN-VALUE IS NUMERIC` (variable not in known_vars)
- **Programs (3):** ACCT-TITLE-CHANGE, PAY-PRENOTE-VALID, REG-TIN-VALIDATOR
- **Flags:** 4
- **Fix:** `parse_conditions.py:_convert_condition()` — handle reference modification in IS NUMERIC; fall back to `to_python_name()` for unknown variables
- **PVR impact:** 2 have ONLY this root cause. Fix = **+2 VERIFIED → PVR 94.0%**

### 8. UNSTRING in IF branch (complex delimiters)
- **Construct:** `UNSTRING WS-NAME DELIMITED BY ' ' INTO WS-FIRST WS-LAST`
- **Programs (2):** MISC-LETTER-GEN, TAX-W8BEN-VALID
- **Flags:** 2
- **Fix:** `parse_conditions.py:_convert_single_statement()` — add UNSTRING handler for simple single-delimiter splits (emit `re.split()` or `.split()`)
- **PVR impact:** 1 has only this root cause (MISC-LETTER-GEN). Fix = **+1 VERIFIED → PVR 94.5%**

### 9. INSPECT TALLYING in IF branch
- **Construct:** `INSPECT WS-FIELD TALLYING WS-COUNT FOR ALL 'X'`
- **Programs (3):** REG-OFAC-MATCH, REG-TIN-VALIDATOR, TAX-W8BEN-VALID
- **Flags:** 4
- **Fix:** `parse_conditions.py:_convert_single_statement()` — add INSPECT TALLYING FOR ALL handler (emit `.count()`)
- **PVR impact:** 0 have ONLY this root cause (all overlap). But enables compound fixes below.

### 10. Inline PERFORM VARYING body (multi-statement)
- **Construct:** PERFORM VARYING inside IF with complex body (nested IF/INSPECT)
- **Programs (3):** REG-OFAC-MATCH, REG-TIN-VALIDATOR, TRADE-CUSTODY-FEE
- **Flags:** 3
- **Fix:** `parse_conditions.py:_convert_single_statement()` — split multi-statement body into individual statements and emit each
- **PVR impact:** 1 has only this root cause (TRADE-CUSTODY-FEE). Fix = **+1 VERIFIED → PVR 95.0%**

---

## Compound fix unlocks

Some programs need MULTIPLE root causes fixed to become VERIFIED:

| Program | Root causes | Becomes VERIFIED when... |
|---------|------------|-------------------------|
| LOAN-GRACE-PERIOD-CALC | OR + Nested IF | #2 + #5 both fixed |
| MR-EXEC-SQL-UPDATE | CONTINUE + Nested IF | #3 + #5 both fixed |
| REG-OFAC-MATCH | INSPECT + inline PV | #9 + #10 both fixed |
| REG-TIN-VALIDATOR | IS NUMERIC + INSPECT + inline PV | #7 + #9 + #10 all fixed |
| TAX-W8BEN-VALID | UNSTRING + INSPECT | #8 + #9 both fixed |

---

## PVR projection

| Fix applied (cumulative) | Programs recovered | New PVR |
|--------------------------|-------------------|---------|
| Baseline | 0 | 84.0% |
| + Compound OR (#2) | +6 | **87.0%** |
| + CONTINUE (#3) | +4 | **89.0%** |
| + WRITE in branch (#4) | +3 | **90.5%** |
| + Nested IF (#5) | +3 (compound unlocks) | **92.0%** |
| + Subscripted 88 (#6) | +2 | **93.0%** |
| + IS NUMERIC (#7) | +2 | **94.0%** |
| + UNSTRING (#8) | +1 | **94.5%** |
| + Inline PV body (#10) | +1 | **95.0%** |
| + INSPECT (#9) | +3 (compound unlocks) | **96.5%** |
| **All fixable** | **+25** | **96.5%** |
| Remaining (ALTER) | 7 programs | Intentional — never fix |

---

## Priority order (bang for buck)

1. **Compound OR** — 6 programs, ~20 lines in parse_conditions.py
2. **CONTINUE** — 4 programs, 2 lines (trivial `pass` emit)
3. **WRITE in branch** — 3 programs, ~5 lines (reuse emit_file_write)
4. **Nested IF text parsing** — 3 programs, ~30 lines (medium complexity)
5. **Subscripted 88-level** — 2 programs, ~15 lines
6. **IS NUMERIC variants** — 2 programs, ~10 lines
7. **UNSTRING in branch** — 1 program, ~15 lines
8. **INSPECT TALLYING** — unlocks 3 compounds, ~20 lines
9. **Inline PV multi-stmt** — unlocks 1 compound, ~30 lines

Fixes 1-3 alone push PVR from 84.0% to 90.5% with minimal code.
