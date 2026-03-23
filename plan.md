# H-11: Shadow Diff decodes ASCII instead of EBCDIC

## Problem
shadow_diff.py uses raw.decode("ascii", errors="replace") when parsing mainframe output files. Real mainframe QSAM files are EBCDIC (CP037/CP500). Characters outside ASCII silently become replacement characters. String comparisons against mainframe data are wrong.

## All .decode("ascii") locations in shadow_diff.py
All in parse_fixed_width_stream():
- Line 137: data.encode("ascii") — string input re-encoding
- Line 157: raw.decode("ascii", errors="replace") — fixed-length record decode
- Line 163: raw_line.decode("ascii", errors="replace") — newline-delimited decode
- Line 165: text.encode("ascii") — re-encode for line_bytes

These are ALL mainframe data paths. Aletheia-generated output is Python strings (UTF-8), untouched.

## Fix

### Step 1 — Extract codepage from layout
After record_length = layout.get("record_length"), add:
codepage = layout.get("codepage", "cp037")

### Step 2 — Replace all ASCII decode/encode calls
- Line 137: data.encode("ascii") to data.encode(codepage)
- Line 157: raw.decode("ascii", errors="replace") to raw.decode(codepage, errors="replace")
- Line 163: raw_line.decode("ascii", errors="replace") to raw_line.decode(codepage, errors="replace")
- Line 165: text.encode("ascii") to text.encode(codepage)

### Step 3 — Tests (test_shadow_diff.py)
Add TestEbcdicDecode class:
1. test_ebcdic_mainframe_decode — EBCDIC bytes b'\xC1\xC2\xC3' decoded as "ABC"
2. test_codepage_override — layout with codepage="cp500" uses CP500
3. test_generated_output_still_utf8 — execute_generated_python() returns Python strings, unaffected

## Verification
Run full test suite: 520+ tests, zero failures.
