"""
EBCDIC String Comparison Library

IBM mainframes use EBCDIC encoding where the collating sequence differs
from ASCII. This module provides EBCDIC-aware comparison functions so
Aletheia's generated Python matches mainframe IF/ELSE behavior on
PIC X (alphanumeric) fields.

Key ordering differences (cp037):
  ASCII:  space < '0'-'9' < 'A'-'Z' < 'a'-'z'
  EBCDIC: space < 'a'-'z' < 'A'-'Z' < '0'-'9'

Supported code pages:
  cp037  — US/Canada (default for most US banks)
  cp500  — International Latin-1
"""


# ============================================================
# COMPONENT 1 — EBCDIC Translation (via Python codecs)
# ============================================================
#
# Python's codecs module natively supports EBCDIC code pages.
# No hand-coded 256-byte tables needed:
#   "A".encode("cp037") → b'\xc1'
#   b'\xc1'.decode("cp037") → "A"
#
# We use this directly for byte-level ordering comparisons.

SUPPORTED_CODEPAGES = ("cp037", "cp500", "cp1047")


def ebcdic_encode(text: str, codepage: str = "cp037") -> bytes:
    """Encode a string to EBCDIC bytes."""
    return text.encode(codepage)


def ebcdic_decode(data: bytes, codepage: str = "cp037") -> str:
    """Decode EBCDIC bytes to a string."""
    return data.decode(codepage)


# ============================================================
# COMPONENT 2 — EBCDIC-Aware Comparison Functions
# ============================================================

def ebcdic_compare(a: str, b: str, codepage: str = "cp037") -> int:
    """Compare two strings using EBCDIC byte ordering.

    Returns:
        -1 if a < b in EBCDIC order
         0 if a == b
         1 if a > b in EBCDIC order
    """
    max_len = max(len(a), len(b))
    a_bytes = a.ljust(max_len).encode(codepage)
    b_bytes = b.ljust(max_len).encode(codepage)
    if a_bytes < b_bytes:
        return -1
    if a_bytes > b_bytes:
        return 1
    return 0


def ebcdic_less_than(a: str, b: str, codepage: str = "cp037") -> bool:
    """True if a < b in EBCDIC collating sequence."""
    return ebcdic_compare(a, b, codepage) < 0


def ebcdic_greater_than(a: str, b: str, codepage: str = "cp037") -> bool:
    """True if a > b in EBCDIC collating sequence."""
    return ebcdic_compare(a, b, codepage) > 0


def ebcdic_equal(a: str, b: str, codepage: str = "cp037") -> bool:
    """True if strings are equal. Encoding-independent for same content."""
    return a == b


def ebcdic_sort(items: list[str], codepage: str = "cp037") -> list[str]:
    """Sort a list of strings using EBCDIC collating sequence."""
    return sorted(items, key=lambda s: s.encode(codepage))


# ============================================================
# COMPONENT 3 — Integration Hook
# ============================================================

def get_ebcdic_comparator(codepage: str = "cp037") -> dict:
    """Return a dict of EBCDIC comparison functions for a given code page.

    Usage in generated Python:
        cmp = get_ebcdic_comparator("cp037")
        if cmp["gt"](var_a, var_b): ...
    """
    return {
        "compare": lambda a, b: ebcdic_compare(a, b, codepage),
        "lt": lambda a, b: ebcdic_less_than(a, b, codepage),
        "gt": lambda a, b: ebcdic_greater_than(a, b, codepage),
        "eq": ebcdic_equal,
        "sort": lambda items: ebcdic_sort(items, codepage),
    }
