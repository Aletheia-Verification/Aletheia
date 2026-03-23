"""
abend_handler.py -- S0C7 Data Exception Emulation

Replicates IBM mainframe S0C7 abend behavior for dirty data.
When a numeric field contains non-numeric characters, the mainframe
crashes with System Completion Code 0C7 (Data Exception).

This module validates field data at parse time and raises
S0C7DataException to replicate that behavior deterministically.
"""

import logging
import re
from decimal import Decimal

logger = logging.getLogger("aletheia.abend")


class S0C7DataException(Exception):
    """IBM S0C7 Data Exception -- non-numeric data in numeric field.

    Attributes:
        field_name:    COBOL field name (e.g., 'WS-AMOUNT')
        pic_clause:    PIC description (e.g., 'PIC 9(3)V99')
        invalid_value: The offending value (string representation)
        record_number: 0-based record index in the input stream
        raw_bytes:     Original bytes from the flat file (or None)
    """

    def __init__(
        self,
        field_name: str,
        pic_clause: str,
        invalid_value: str,
        record_number: int,
        raw_bytes: bytes | None = None,
    ):
        self.field_name = field_name
        self.pic_clause = pic_clause
        self.invalid_value = invalid_value
        self.record_number = record_number
        self.raw_bytes = raw_bytes
        super().__init__(
            f"S0C7 DATA EXCEPTION: Field '{field_name}' ({pic_clause}) "
            f"received non-numeric value '{invalid_value}' at record {record_number}"
        )


# Regex: optional leading sign, digits, optional decimal point + digits
_VALID_NUMERIC = re.compile(r"^[+-]?\d+\.?\d*$")


def validate_numeric_field(
    value: str,
    pic_integers: int,
    pic_decimals: int,
    field_name: str,
    record_number: int,
    raw_bytes: bytes | None = None,
) -> Decimal:
    """Validate and convert a raw string value to Decimal per COBOL PIC rules.

    Behavior:
    - Strips leading/trailing spaces from the value.
    - Empty string after stripping -> Decimal("0").
    - Null bytes (0x00) in raw_bytes: replaced with '0', logged as warning.
    - HIGH-VALUES (all 0xFF bytes): treated as max value for the PIC.
    - Embedded spaces (space chars between digits): raises S0C7.
    - Any non-numeric character (letter, punctuation): raises S0C7.

    Returns:
        Decimal value.

    Raises:
        S0C7DataException: If value contains non-numeric data.
    """
    pic_clause = _build_pic_clause(pic_integers, pic_decimals)

    # --- Null byte handling (0x00) ---
    if raw_bytes is not None and b"\x00" in raw_bytes:
        logger.warning(
            "Null bytes (0x00) in field '%s' at record %d -- treating as zeros",
            field_name,
            record_number,
        )
        cleaned = raw_bytes.replace(b"\x00", b"0")
        value = cleaned.decode("ascii", errors="replace")

    # --- HIGH-VALUES handling (0xFF) ---
    if raw_bytes is not None and b"\xff" in raw_bytes:
        if all(b == 0xFF for b in raw_bytes):
            max_val = Decimal("9" * pic_integers)
            if pic_decimals > 0:
                max_val += Decimal("0." + "9" * pic_decimals)
            logger.warning(
                "HIGH-VALUES (0xFF) in field '%s' at record %d -- using max PIC value %s",
                field_name,
                record_number,
                max_val,
            )
            return max_val
        # Partial HIGH-VALUES mixed with data -> abend
        raise S0C7DataException(
            field_name, pic_clause, repr(raw_bytes), record_number, raw_bytes
        )

    # --- Strip and check empty ---
    stripped = value.strip()
    if not stripped:
        return Decimal("0")

    # --- Embedded spaces check ---
    if " " in stripped:
        raise S0C7DataException(
            field_name, pic_clause, stripped, record_number, raw_bytes
        )

    # --- Zoned decimal overpunch check ---
    last_char = stripped[-1] if stripped else ""
    if last_char in _POSITIVE_OVERPUNCH or last_char in _NEGATIVE_OVERPUNCH:
        try:
            return decode_zoned_decimal(stripped, pic_decimals)
        except S0C7DataException:
            raise S0C7DataException(
                field_name, pic_clause, stripped, record_number, raw_bytes
            )

    # --- Non-numeric character check ---
    if not _VALID_NUMERIC.match(stripped):
        raise S0C7DataException(
            field_name, pic_clause, stripped, record_number, raw_bytes
        )

    return Decimal(stripped)


def validate_string_field(
    value: bytes | str,
    pic_length: int,
    field_name: str,
    record_number: int,
) -> str:
    """Validate a string (PIC X) field. Accepts any content.

    - Truncates to pic_length if longer.
    - Right-pads with spaces if shorter.
    - Strips trailing spaces (matching existing behavior).
    """
    if isinstance(value, bytes):
        text = value.decode("ascii", errors="replace")
    else:
        text = value

    if len(text) > pic_length:
        text = text[:pic_length]

    return text.rstrip()


def _build_pic_clause(pic_integers: int, pic_decimals: int) -> str:
    """Build a human-readable PIC clause string."""
    clause = f"PIC 9({pic_integers})"
    if pic_decimals > 0:
        clause += f"V9({pic_decimals})"
    return clause


# ============================================================
# Zoned Decimal Overpunch Decoding
# ============================================================
#
# IBM mainframes encode the sign of PIC S9 DISPLAY fields into the
# last byte using "overpunch" encoding.  When data is dumped to a
# flat file the overpunch character appears as a letter.

# Last-digit → (digit, sign_multiplier)
_POSITIVE_OVERPUNCH = {
    "{": 0, "A": 1, "B": 2, "C": 3, "D": 4,
    "E": 5, "F": 6, "G": 7, "H": 8, "I": 9,
}
_NEGATIVE_OVERPUNCH = {
    "}": 0, "J": 1, "K": 2, "L": 3, "M": 4,
    "N": 5, "O": 6, "P": 7, "Q": 8, "R": 9,
}

# Reverse maps for encoding (digit, sign → overpunch char)
_ENCODE_POSITIVE = {v: k for k, v in _POSITIVE_OVERPUNCH.items()}
_ENCODE_NEGATIVE = {v: k for k, v in _NEGATIVE_OVERPUNCH.items()}


def decode_zoned_decimal(raw: str, pic_decimals: int = 0) -> Decimal:
    """Decode an IBM zoned decimal (overpunch) string to Decimal.

    If the last character is an overpunch letter, the digit and sign are
    extracted.  Otherwise the value is treated as unsigned and passed
    through to Decimal.

    Args:
        raw:           Raw string from fixed-width field (may contain
                       leading spaces — they are stripped).
        pic_decimals:  Implied decimal places (e.g. PIC S9(5)V99 → 2).

    Returns:
        Decimal value with correct sign and decimal placement.

    Examples:
        decode_zoned_decimal("12C")          → Decimal('123')
        decode_zoned_decimal("12L")          → Decimal('-123')
        decode_zoned_decimal("12C", 2)       → Decimal('1.23')
        decode_zoned_decimal("00{", 0)       → Decimal('0')
    """
    stripped = raw.strip()
    if not stripped:
        return Decimal("0")

    last = stripped[-1]
    prefix = stripped[:-1]

    if last in _POSITIVE_OVERPUNCH:
        digit = _POSITIVE_OVERPUNCH[last]
        digits = prefix + str(digit)
        sign = Decimal(1)
    elif last in _NEGATIVE_OVERPUNCH:
        digit = _NEGATIVE_OVERPUNCH[last]
        digits = prefix + str(digit)
        sign = Decimal(-1)
    else:
        # No overpunch — treat as plain unsigned number
        return Decimal(stripped) / (Decimal(10) ** pic_decimals) if pic_decimals else Decimal(stripped)

    # All characters before the overpunch must be digits
    if not digits.isdigit():
        raise S0C7DataException(
            field_name="unknown",
            pic_clause=f"PIC S9({len(digits)})" + (f"V9({pic_decimals})" if pic_decimals else ""),
            invalid_value=stripped,
            record_number=-1,
        )

    integer_value = Decimal(digits)
    if pic_decimals:
        integer_value = integer_value / (Decimal(10) ** pic_decimals)

    result = sign * integer_value
    # Negative zero → zero
    if result == 0:
        return Decimal("0")
    return result


def encode_zoned_decimal(value: Decimal, pic_digits: int, pic_decimals: int = 0) -> str:
    """Encode a Decimal value to IBM zoned decimal (overpunch) string.

    Args:
        value:        Decimal value to encode.
        pic_digits:   Total display digits (integer + decimal).
        pic_decimals: Implied decimal places.

    Returns:
        Overpunch-encoded string, zero-padded to pic_digits length.
    """
    is_negative = value < 0
    abs_val = abs(value)

    # Scale up by decimal places to get pure integer
    if pic_decimals:
        scaled = int(abs_val * (Decimal(10) ** pic_decimals))
    else:
        scaled = int(abs_val)

    digit_str = str(scaled).zfill(pic_digits)

    # Take last digit, encode with overpunch
    last_digit = int(digit_str[-1])
    prefix = digit_str[:-1]

    if is_negative:
        overpunch = _ENCODE_NEGATIVE[last_digit]
    else:
        overpunch = _ENCODE_POSITIVE[last_digit]

    return prefix + overpunch
