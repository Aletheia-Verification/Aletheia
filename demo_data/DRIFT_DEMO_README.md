# Drift Demo — Intentional Mismatches

`loan_mainframe_output_WITH_DRIFT.dat` is a copy of `loan_mainframe_output.dat` with **5 intentional mutations** introduced to demonstrate Shadow Diff failure-mode detection and the `diagnose_drift` root-cause analysis.

Use with the same `loan_layout.json` and `loan_input.dat` as the original demo.

---

## Mutations

| Record | Field | Original Value | Mutated Value | Failure Mode |
|--------|-------|---------------|---------------|-------------|
| 3 | DAILY-INTEREST | `0` | `0.01` | **Rounding divergence** — off by 1 cent, simulates ROUND vs TRUNCATE mismatch between COBOL and Python |
| 12 | PENALTY-AMOUNT | `0.000000` | `999.99` | **PIC precision overflow** — wildly wrong value, simulates a field that overflowed its PIC capacity on the mainframe |
| 25 | DAILY-RATE | `0.00003021369863013698630136986301` | `0.00003021379863013698630136986301` | **TRUNC flag mismatch** — 6th decimal place changed (6→7), simulates TRUNC(STD) vs TRUNC(BIN) divergence |
| 50 | ACCRUED-INT | `0.00` | `BADDATA` | **S0C7 abend (dirty data)** — non-numeric string in a decimal field, simulates corrupted mainframe output |
| 75 | DAILY-INTEREST | `2.37` | `-2.37` | **COMP-3 sign nibble mismatch** — positive value negated, simulates incorrect sign nibble (0xD vs 0xC) in packed decimal |

---

## Expected Shadow Diff Output

- **Total records**: 100
- **Matches**: 95
- **Mismatches**: 5
- **Verdict**: DRIFT DETECTED — 5 RECORDS

Each mismatch should appear in `diagnosed_mismatches` with a `likely_cause` and `suggested_fix` matching the failure mode above.
