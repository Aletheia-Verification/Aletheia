# EBCDIC Comparison Audit

**Date:** 2026-03-22
**Scope:** Every comparison emission in `parse_conditions.py`, `generate_full_python.py`, `verb_handlers.py`, `cobol_types.py`

## Background

EBCDIC orders: `space < a-z < A-Z < 0-9`. ASCII orders: `space < 0-9 < A-Z < a-z`. Any string ordering comparison (`>`, `<`, `>=`, `<=`) using Python native operators produces wrong results for mixed-case or alpha-digit ranges.

## Sites Using ebcdic_compare (CORRECT — 6 sites)

| File | Line | What |
|------|------|------|
| `parse_conditions.py` | 582 | Simple IF `>` `<` `>=` `<=` on string operands |
| `parse_conditions.py` | 1644-1645 | EVALUATE ALSO string literal THRU |
| `parse_conditions.py` | 1657-1658 | EVALUATE ALSO string variable THRU |
| `parse_conditions.py` | 1783-1784 | EVALUATE single-subject string literal THRU |
| `parse_conditions.py` | 1800-1801 | EVALUATE single-subject string variable THRU |
| `parse_conditions.py` | 1828 | EVALUATE WHEN prefix operators on string subject |

## Sites Correctly Using ASCII (no fix needed — 10 sites)

| File | Line | What | Why Safe |
|------|------|------|----------|
| `parse_conditions.py` | 280, 294 | 88-level `==`/`!=`/`in` | Equality — EBCDIC and ASCII agree |
| `parse_conditions.py` | 584 | Simple IF `==` on strings | Equality |
| `parse_conditions.py` | 530-536 | IS NUMERIC/ALPHABETIC | Class test, not value comparison |
| `parse_conditions.py` | 1623, 1665 | EVALUATE ALSO `==` | Equality |
| `parse_conditions.py` | 1835, 1837, 1841 | EVALUATE WHEN `==` | Equality |
| `cobol_types.py` | 430-456 | CobolDecimal `__lt__` etc | Numeric — compares `.value` (Decimal) |
| `cobol_types.py` | 540-566 | CobolFloat `__lt__` etc | Numeric — compares `.value` (Decimal) |
| `generate_full_python.py` | SORT keys | `str.encode('cp037')` | Pre-encodes to EBCDIC bytes |
| `verb_handlers.py` | N/A | No comparisons emitted | Only handles DISPLAY/MOVE/IO |

## Bugs Found and Fixed

### Bug 1: 88-level THRU on string fields (CRITICAL)

**File:** `parse_conditions.py:269`

Before:
```python
expr = f"{repr(low)} <= {py_name} <= {repr(high)}"
```

After:
```python
expr = (f"ebcdic_compare({repr(low)}, {py_name}, _CODEPAGE) <= 0 and "
        f"ebcdic_compare({py_name}, {repr(high)}, _CODEPAGE) <= 0")
```

**Impact:** Any 88-level with `VALUE 'A' THRU 'Z'` on a PIC X field would use ASCII collation. Mixed-case ranges (e.g., `'a' THRU 'Z'`) produce wrong results — empty in ASCII but matches letters in EBCDIC.

### Bug 2: Compound condition bypass (MEDIUM)

**File:** `parse_conditions.py:559`

Before: When the right operand of a comparison ended with an 88-level name (e.g., `WS-CODE > WS-OTHER OR WS-IS-MATCH`), the compound handler built the comparison using plain Python operators, skipping the ebcdic_compare block.

After: Added the same ebcdic_compare check used in the main comparison path (line 577-582).

### Bug 3: CobolFieldProxy ordering operators (LOW — defense-in-depth)

**File:** `cobol_types.py:1019-1049`

Before: `__lt__`, `__le__`, `__gt__`, `__ge__` used Python's native `<`, `<=`, `>`, `>=` for string fields.

After: Lazy-imports `ebcdic_compare` and uses EBCDIC ordering for string comparisons.

### Bug 4: EVALUATE ALSO first-subject missing string/variable THRU (MEDIUM)

**File:** `parse_conditions.py:1615-1640`

Before: First subject in EVALUATE ALSO only handled numeric THRU. String THRU (`'A'THRU'C'`) and variable THRU on the first subject fell through to equality `==`.

After: Added string THRU and variable THRU handlers mirroring the ALSO-subject handlers, with ebcdic_compare for string subjects.

## Test Coverage

12 new tests in `test_ebcdic.py`:
- `TestBug1_88LevelThruUsesEbcdic` (3 tests): string THRU emits ebcdic_compare, numeric stays Decimal, negated works
- `TestBug2_CompoundConditionEbcdic` (1 test): compound condition with string `>` uses ebcdic_compare
- `TestBug3_CobolFieldProxyOrdering` (5 tests): proxy `<`/`<=`/`>`/`>=` uses EBCDIC for strings, Decimal for numerics
- `TestBug4_EvalAlsoFirstSubjectStringThru` (1 test): EVALUATE with string THRU emits ebcdic_compare
