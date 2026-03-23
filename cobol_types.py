"""
cobol_types.py — COBOL Data Type System

CobolDecimal:  PIC-enforcing Decimal wrapper for standalone fields.
CobolMemoryRegion: Byte-backed shared storage for REDEFINES groups.
CobolFieldProxy:   Duck-types CobolDecimal, reads/writes through a region.

Wraps Python's Decimal to match IBM z/OS COBOL truncation behavior.

COBOL COMPUTE semantics: full-precision intermediates, truncation only
on store to the target variable. This class enforces PIC constraints
via the .store() method, not during intermediate arithmetic.

Usage in generated Python:
    ws_balance = CobolDecimal('0', pic_integers=5, pic_decimals=2, is_signed=True)
    ws_balance.store(ws_principal.value * (Decimal('1') + ws_rate.value))

Truncation modes (set via compiler_config):
    STD: result mod PIC capacity (standard COBOL rules)
    BIN: COMP items keep full binary range; DISPLAY items truncate
    OPT: no truncation (compiler trusts programmer)
"""

import logging
import struct
from decimal import Decimal, ROUND_DOWN

_logger = logging.getLogger(__name__)


def _expand_pic_pattern(pattern: str) -> str:
    """Expand PIC repetition notation: Z(4) → ZZZZ, 9(2) → 99, etc."""
    result = []
    i = 0
    while i < len(pattern):
        if i + 1 < len(pattern) and pattern[i + 1] == '(':
            c = pattern[i]
            close = pattern.find(')', i + 2)
            if close == -1:
                # Malformed PIC — missing close paren, return remainder as-is
                result.append(pattern[i:])
                break
            count = int(pattern[i + 2:close])
            result.append(c * count)
            i = close + 1
        else:
            result.append(pattern[i])
            i += 1
    return ''.join(result)


class CobolDecimal:
    """
    A Decimal value bound to a COBOL PIC clause.

    Enforces PIC-based truncation on every .store() call,
    matching IBM z/OS TRUNC behavior exactly.
    """

    __slots__ = ('value', 'pic_integers', 'pic_decimals', 'is_signed', 'is_comp',
                 '_scale', '_max_int', 'blank_when_zero',
                 'sign_position', 'sign_separate',
                 'p_leading', 'p_trailing', '_scale_factor',
                 'edit_pattern', 'is_native_binary')

    def __init__(self, value='0', pic_integers=1, pic_decimals=0,
                 is_signed=False, is_comp=False, blank_when_zero=False,
                 sign_position='trailing', sign_separate=False,
                 p_leading=0, p_trailing=0, edit_pattern=None,
                 is_native_binary=False):
        self.edit_pattern = edit_pattern
        self.is_native_binary = is_native_binary
        self.pic_integers = pic_integers
        self.pic_decimals = pic_decimals
        self.is_signed = is_signed
        self.is_comp = is_comp
        self.blank_when_zero = blank_when_zero
        self.sign_position = sign_position
        self.sign_separate = sign_separate
        self.p_leading = p_leading
        self.p_trailing = p_trailing

        # Precompute scale and max integer for truncation
        self._scale = Decimal(10) ** -pic_decimals if pic_decimals > 0 else Decimal(1)
        self._max_int = Decimal(10) ** pic_integers

        # PIC P scaling factor:
        #   PIC PP999: p_leading=2, stored 123 = value 0.00123 = 123 * 10^-(2+3)
        #   PIC 999PP: p_trailing=2, stored 123 = value 12300 = 123 * 10^2
        if p_trailing > 0:
            self._scale_factor = Decimal(10) ** p_trailing
        elif p_leading > 0:
            self._scale_factor = Decimal(10) ** -(p_leading + pic_integers + pic_decimals)
        else:
            self._scale_factor = None

        # For PIC P fields, adjust _max_int to reflect the total stored digits
        # after descaling. PIC PP999 stores 3-digit integers internally.
        if self._scale_factor is not None:
            total_stored_digits = pic_integers + pic_decimals
            if total_stored_digits > 0:
                self._max_int = Decimal(10) ** total_stored_digits

        # Initial store applies truncation
        self.value = Decimal('0')
        self.store(value)

    def store(self, value):
        """
        Store a value, applying PIC truncation per the active TRUNC mode.

        This is the critical method — COBOL COMPUTE does full-precision
        arithmetic, then truncates when storing to the target field.
        Raises S0C7DataException if a non-numeric string is stored.
        """
        if isinstance(value, Decimal):
            raw = value
        elif isinstance(value, (int, float)):
            raw = Decimal(str(value))
        elif isinstance(value, CobolDecimal):
            raw = value.value
        elif isinstance(value, str):
            stripped = value.strip()
            if not stripped:
                raw = Decimal("0")
            else:
                try:
                    raw = Decimal(stripped)
                except Exception:
                    from abend_handler import S0C7DataException
                    pic = f"PIC {'S' if self.is_signed else ''}9({self.pic_integers})"
                    if self.pic_decimals:
                        pic += f"V9({self.pic_decimals})"
                    raise S0C7DataException(
                        field_name="unknown",
                        pic_clause=pic,
                        invalid_value=stripped,
                        record_number=-1,
                    )
        else:
            raw = Decimal(str(value))
        # PIC P descale: convert external value to internal stored digits
        if self._scale_factor is not None:
            raw = raw / self._scale_factor
        self.value = self._apply_truncation(raw)
        # PIC P rescale: convert internal stored digits back to external value
        if self._scale_factor is not None:
            self.value = self.value * self._scale_factor
        return self

    def _apply_truncation(self, raw):
        """Enforce PIC constraints based on compiler TRUNC mode."""
        from compiler_config import get_config
        config = get_config()

        # Step 1: Quantize to PIC decimal places (all modes)
        raw = raw.quantize(self._scale, rounding=ROUND_DOWN)

        # Step 2: Mode-specific integer truncation
        if config.trunc_mode == "OPT":
            # TRUNC(OPT): compiler assumes no overflow — pass through
            if not self.is_signed and raw < 0:
                raw = abs(raw)
            return raw

        if self.is_native_binary or (config.trunc_mode == "BIN" and self.is_comp):
            # COMP-5 (native binary) or TRUNC(BIN) + COMP: full binary range
            if not self.is_signed and raw < 0:
                raw = abs(raw)
            return raw

        # TRUNC(STD) — or TRUNC(BIN) on DISPLAY items: mod to PIC capacity
        if abs(raw) >= self._max_int or (raw != Decimal('0') and abs(raw) // 1 >= self._max_int):
            sign = Decimal('-1') if raw < 0 else Decimal('1')
            abs_val = abs(raw)
            integer_part = abs_val // 1
            decimal_part = abs_val % 1
            truncated_int = integer_part % self._max_int
            raw = sign * (truncated_int + decimal_part)
            raw = raw.quantize(self._scale, rounding=ROUND_DOWN)

        # Unsigned fields cannot hold negative values
        if not self.is_signed and raw < 0:
            raw = abs(raw)

        return raw

    def effective_max(self):
        """Maximum absolute value this field can hold before overflow.

        COMP-5: binary capacity (halfword=32767, fullword=2147483647, doubleword=9223372036854775807)
        COMP with TRUNC(BIN): same as COMP-5
        All others: PIC capacity = 10^pic_integers - 10^(-pic_decimals)
        """
        from compiler_config import get_config
        config = get_config()
        # COMP with TRUNC(BIN) uses full binary range
        # IBM uses integer digits only for halfword/fullword/doubleword boundary
        if self.is_comp and config.trunc_mode == "BIN":
            total_digits = self.pic_integers
            if total_digits <= 4:
                int_max = Decimal('32767')
            elif total_digits <= 9:
                int_max = Decimal('2147483647')
            else:
                int_max = Decimal('9223372036854775807')
            if self.pic_decimals > 0:
                return int_max / (Decimal(10) ** self.pic_decimals)
            return int_max
        # PIC capacity: 10^integers - smallest unit
        scale = Decimal(10) ** -self.pic_decimals if self.pic_decimals > 0 else Decimal(1)
        return Decimal(10) ** self.pic_integers - scale

    def to_display(self):
        """
        Format value as the mainframe would display it.

        PIC 9(3)V99 with value 12.30 → "01230"
        PIC S9(5) with value -42 → "00042-"  (trailing sign)
        BLANK WHEN ZERO: zero → spaces for full display width.
        """
        if self.blank_when_zero and self.value == 0:
            total_len = self.pic_integers + self.pic_decimals
            if self.is_signed:
                total_len += 1
            return " " * total_len

        abs_val = abs(self.value)
        if self.pic_decimals > 0:
            # Split integer and decimal parts
            int_part = int(abs_val // 1)
            dec_part = int((abs_val % 1) * (10 ** self.pic_decimals))
            display = f"{int_part:0{self.pic_integers}d}{dec_part:0{self.pic_decimals}d}"
        else:
            int_val = int(abs_val)
            display = f"{int_val:0{self.pic_integers}d}"

        if not self.is_signed:
            return display

        sign_char = "-" if self.value < 0 else "+"

        if self.sign_separate:
            # SEPARATE CHARACTER: explicit +/- byte
            if self.sign_position == "leading":
                return sign_char + display
            else:
                return display + sign_char
        else:
            # Overpunch: sign appended only when negative (display convenience)
            if self.value < 0:
                if self.sign_position == "leading":
                    return "-" + display
                else:
                    return display + "-"
            return display

    def to_zoned_display(self):
        """
        Format value as IBM zoned decimal with overpunch sign encoding.

        PIC S9(3) with value +123 → "12C"
        PIC S9(3) with value -123 → "12L"
        PIC S9(3)V99 with value +1.23 → "0012C"

        Only meaningful for signed DISPLAY fields (PIC S9).
        Unsigned fields fall back to to_display().
        """
        if not self.is_signed:
            return self.to_display()
        from abend_handler import encode_zoned_decimal
        total_digits = self.pic_integers + self.pic_decimals
        return encode_zoned_decimal(self.value, total_digits, self.pic_decimals)

    def to_edited_display(self):
        """Format value with numeric edited PIC characters (Z, *, $, +, -, etc.).

        Uses a two-pass algorithm:
          Pass 1 — find the first significant digit position.
          Pass 2 — build output left-to-right, suppressing leading zeros.

        Falls back to to_display() if edit_pattern is None or on error.
        """
        if self.edit_pattern is None:
            return self.to_display()
        try:
            return self._format_edited()
        except Exception:
            _logger.warning("to_edited_display fallback for pattern %s",
                            self.edit_pattern)
            return self.to_display()

    # ── Edited PIC formatting internals ───────────────────────────

    _DIGIT_SLOTS = frozenset('9Z*$+-')

    def _format_edited(self):
        pattern = self.edit_pattern.upper().strip()
        if pattern.startswith('S'):
            pattern = pattern[1:]

        # Handle CR/DB suffix
        cr_db = ''
        if pattern.endswith('CR'):
            cr_db = 'CR' if self.value < 0 else '  '
            pattern = pattern[:-2]
        elif pattern.endswith('DB'):
            cr_db = 'DB' if self.value < 0 else '  '
            pattern = pattern[:-2]

        expanded = _expand_pic_pattern(pattern)
        negative = self.value < 0
        abs_val = abs(self.value)

        # Split at '.' or 'V' for integer/decimal separation
        if '.' in expanded:
            int_pat, dec_pat = expanded.split('.', 1)
            has_period = True
        elif 'V' in expanded:
            int_pat, dec_pat = expanded.split('V', 1)
            has_period = False
        else:
            int_pat = expanded
            dec_pat = ''
            has_period = False

        DS = self._DIGIT_SLOTS
        n_int = sum(1 for c in int_pat if c in DS)
        n_dec = sum(1 for c in dec_pat if c in DS)

        # Build zero-padded digit string
        int_val = int(abs_val)
        int_str = str(int_val).zfill(n_int)
        if len(int_str) > n_int:
            int_str = int_str[-n_int:]

        if n_dec > 0:
            dec_val = int((abs_val % 1) * (10 ** n_dec))
            dec_str = str(dec_val).zfill(n_dec)
            if len(dec_str) > n_dec:
                dec_str = dec_str[-n_dec:]
        else:
            dec_str = ''

        all_digits = int_str + dec_str
        total = len(all_digits)

        # Detect float character and fill character
        float_char = None
        fill_char = ' '
        for c in expanded:
            if c == '*':
                fill_char = '*'
                break
        for c in expanded:
            if c in '$+-':
                float_char = c
                break

        # ── Pass 1: find significance boundary ──
        sig = total  # default: nothing significant
        digit_idx = 0
        for c in expanded:
            if c in DS:
                d = all_digits[digit_idx] if digit_idx < total else '0'
                if d != '0' or c == '9':
                    sig = digit_idx
                    break
                digit_idx += 1

        # ── Pass 2: build output ──
        result = []
        digit_idx = 0

        for c in expanded:
            if c in DS:
                d = all_digits[digit_idx] if digit_idx < total else '0'

                if digit_idx < sig:
                    # Before significance: suppress
                    if (float_char and c in '$+-'
                            and digit_idx + 1 == sig):
                        # Float anchor — place symbol here
                        if c == '$':
                            result.append('$')
                        elif c == '-':
                            result.append('-' if negative else ' ')
                        elif c == '+':
                            result.append('-' if negative else '+')
                    else:
                        result.append(fill_char)
                else:
                    # At/after significance: show digit
                    result.append(d)

                digit_idx += 1

            elif c == '.':
                # Suppress period if still in suppression zone
                if digit_idx <= sig:
                    result.append(fill_char)
                else:
                    result.append('.')

            elif c == ',':
                if digit_idx <= sig:
                    result.append(fill_char)
                else:
                    result.append(',')

            elif c == 'B':
                result.append(' ')

            elif c == '/':
                result.append('/')

            elif c == '0':
                result.append('0')

            elif c == 'V':
                pass  # Implied decimal — no output character

            else:
                result.append(c)

        return ''.join(result) + cr_db

    # ── Comparison operators (compare .value) ─────────────────────

    def __eq__(self, other):
        if isinstance(other, CobolDecimal):
            return self.value == other.value
        return self.value == Decimal(str(other))

    def __ne__(self, other):
        return not self.__eq__(other)

    def __lt__(self, other):
        if isinstance(other, CobolDecimal):
            return self.value < other.value
        return self.value < Decimal(str(other))

    def __le__(self, other):
        if isinstance(other, CobolDecimal):
            return self.value <= other.value
        return self.value <= Decimal(str(other))

    def __gt__(self, other):
        if isinstance(other, CobolDecimal):
            return self.value > other.value
        return self.value > Decimal(str(other))

    def __ge__(self, other):
        if isinstance(other, CobolDecimal):
            return self.value >= other.value
        return self.value >= Decimal(str(other))

    def __repr__(self):
        sign = "S" if self.is_signed else ""
        comp = " COMP" if self.is_comp else ""
        sign_clause = ""
        if self.is_signed and (self.sign_position != "trailing" or self.sign_separate):
            sign_clause = f" SIGN {self.sign_position.upper()}"
            if self.sign_separate:
                sign_clause += " SEPARATE"
        return (
            f"CobolDecimal({self.value}, "
            f"PIC {sign}9({self.pic_integers})"
            f"{'V' + '9(' + str(self.pic_decimals) + ')' if self.pic_decimals else ''}"
            f"{comp}{sign_clause})"
        )

    def __str__(self):
        return str(self.value)

    # ── ON SIZE ERROR support ─────────────────────────────────────

    def check_overflow(self, value):
        """Return True if storing `value` would cause a size error.

        ON SIZE ERROR fires when the result exceeds the field's effective
        capacity BEFORE truncation is applied.
        Unsigned fields cannot hold negative values — that's also overflow.
        """
        if isinstance(value, CobolDecimal):
            value = value.value
        elif not isinstance(value, Decimal):
            value = Decimal(str(value))

        quantized = value.quantize(self._scale, rounding=ROUND_DOWN)
        # Unsigned fields cannot hold negative values
        if not self.is_signed and quantized < 0:
            return True
        return abs(quantized) > self.effective_max()


# ══════════════════════════════════════════════════════════════════
# COMP-1 / COMP-2  —  IEEE 754 FLOATING POINT
# ══════════════════════════════════════════════════════════════════

class CobolFloat:
    """IEEE 754 floating-point value for COMP-1 (single) and COMP-2 (double).

    COMP-1: 4 bytes, single precision (~7 significant digits)
    COMP-2: 8 bytes, double precision (~15 significant digits)

    No PIC clause — COMP-1/COMP-2 don't use PIC in standard COBOL.
    Stores .value as Decimal for interop with CobolDecimal comparisons.
    """

    __slots__ = ('value', 'precision', '_struct_fmt')

    def __init__(self, value=0.0, precision='single'):
        self.precision = precision  # 'single' or 'double'
        self._struct_fmt = 'f' if precision == 'single' else 'd'
        self.value = Decimal('0')
        self.store(value)

    def store(self, value):
        """Store value, truncating to IEEE 754 precision."""
        if isinstance(value, CobolFloat):
            fval = float(value.value)
        elif isinstance(value, CobolDecimal):
            fval = float(value.value)
        elif isinstance(value, Decimal):
            fval = float(value)
        elif isinstance(value, (int, float)):
            fval = float(value)
        elif isinstance(value, str):
            fval = float(value.strip() or '0')
        else:
            fval = float(value)

        # Truncate to IEEE 754 precision via struct round-trip
        truncated = struct.unpack(self._struct_fmt,
                                  struct.pack(self._struct_fmt, fval))[0]
        self.value = Decimal(str(truncated))
        return self

    def check_overflow(self, value):
        """COMP-1/COMP-2 don't overflow in the COBOL sense (they go to Inf)."""
        return False

    def __eq__(self, other):
        if isinstance(other, (CobolFloat, CobolDecimal)):
            return self.value == other.value
        return self.value == Decimal(str(other))

    def __ne__(self, other):
        return not self.__eq__(other)

    def __lt__(self, other):
        if isinstance(other, (CobolFloat, CobolDecimal)):
            return self.value < other.value
        return self.value < Decimal(str(other))

    def __le__(self, other):
        if isinstance(other, (CobolFloat, CobolDecimal)):
            return self.value <= other.value
        return self.value <= Decimal(str(other))

    def __gt__(self, other):
        if isinstance(other, (CobolFloat, CobolDecimal)):
            return self.value > other.value
        return self.value > Decimal(str(other))

    def __ge__(self, other):
        if isinstance(other, (CobolFloat, CobolDecimal)):
            return self.value >= other.value
        return self.value >= Decimal(str(other))

    def __repr__(self):
        p = "COMP-1" if self.precision == "single" else "COMP-2"
        return f"CobolFloat({self.value}, {p})"

    def __str__(self):
        return str(self.value)


# ══════════════════════════════════════════════════════════════════
# REDEFINES BYTE-BACKED MEMORY MODEL
# ══════════════════════════════════════════════════════════════════

# ── Encode/Decode Helpers ─────────────────────────────────────────
#
# PERFORMANCE NOTE: Each .value read or .store() call goes through
# encode/decode. In tight PERFORM loops (thousands of iterations),
# this adds ~2-5µs per field access vs ~0.1µs for CobolDecimal.value.
# Acceptable for verification; not for production hot-paths.
#
# All DISPLAY/PIC X encoding uses EBCDIC Code Page 037 (US/Canada),
# matching IBM z/OS mainframe byte representation.

_EBCDIC_CODEC = 'cp037'
_EBCDIC_SPACE = b'\x40'  # EBCDIC space character


def _encode_pic_x(value: str, length: int) -> bytes:
    """Encode string to PIC X bytes — EBCDIC cp037, left-justified, space-padded."""
    encoded = value.encode(_EBCDIC_CODEC, errors='replace')
    if len(encoded) >= length:
        return encoded[:length]
    return encoded + _EBCDIC_SPACE * (length - len(encoded))


def _decode_pic_x(raw: bytes, length: int) -> str:
    """Decode PIC X bytes from EBCDIC cp037 to string."""
    return raw[:length].decode(_EBCDIC_CODEC, errors='replace').rstrip()


def _encode_display_numeric(value: Decimal, pic_integers: int,
                            pic_decimals: int, is_signed: bool) -> bytes:
    """Encode Decimal to DISPLAY (zoned) byte representation.

    Uses EBCDIC cp037 encoding:
      Unsigned digits 0-9 → 0xF0-0xF9 in EBCDIC.
      Signed: overpunch on last byte (positive → 0xC0-0xC9,
              negative → 0xD0-0xD9 in EBCDIC zone nibble).
    """
    total_digits = pic_integers + pic_decimals

    if is_signed:
        from abend_handler import encode_zoned_decimal
        zoned_str = encode_zoned_decimal(value, total_digits, pic_decimals)
        return zoned_str.encode(_EBCDIC_CODEC)
    else:
        abs_val = abs(value)
        if pic_decimals:
            scaled = int(abs_val * (Decimal(10) ** pic_decimals))
        else:
            scaled = int(abs_val)
        digit_str = str(scaled).zfill(total_digits)[-total_digits:]
        return digit_str.encode(_EBCDIC_CODEC)


def _decode_display_numeric(raw: bytes, pic_integers: int,
                            pic_decimals: int, is_signed: bool) -> Decimal:
    """Decode DISPLAY bytes (EBCDIC cp037) to Decimal."""
    text = raw.decode(_EBCDIC_CODEC, errors='replace').strip()
    if not text:
        return Decimal('0')

    if is_signed:
        from abend_handler import decode_zoned_decimal
        return decode_zoned_decimal(text, pic_decimals)
    else:
        try:
            int_val = int(text)
        except ValueError:
            return Decimal('0')
        if pic_decimals:
            return Decimal(int_val) / (Decimal(10) ** pic_decimals)
        return Decimal(int_val)


def _encode_comp3(value: Decimal, pic_integers: int, pic_decimals: int) -> bytes:
    """Encode Decimal to COMP-3 packed BCD.

    Reverse of shadow_diff.decode_comp3.
    Each byte holds two BCD digit nibbles (high=tens, low=ones).
    Last byte: high nibble = last digit, low nibble = sign.
    Sign nibbles: 0x0C = positive, 0x0D = negative (IBM convention).
    """
    is_negative = value < 0
    abs_val = abs(value)
    total_digits = pic_integers + pic_decimals

    if pic_decimals:
        scaled = int(abs_val * (Decimal(10) ** pic_decimals))
    else:
        scaled = int(abs_val)

    digit_str = str(scaled).zfill(total_digits)
    if len(digit_str) > total_digits:
        digit_str = digit_str[-total_digits:]

    # IBM COMP-3 sign: 0x0C = positive, 0x0D = negative
    sign_nibble = 0x0D if is_negative else 0x0C

    # Build nibble list: digits + sign
    nibbles = [int(d) for d in digit_str] + [sign_nibble]

    # Pad to even number of nibbles (pack into whole bytes)
    if len(nibbles) % 2 != 0:
        nibbles = [0] + nibbles

    result = bytearray()
    for i in range(0, len(nibbles), 2):
        byte = (nibbles[i] << 4) | (nibbles[i + 1] & 0x0F)
        result.append(byte)

    return bytes(result)


def _decode_comp3(raw: bytes, pic_decimals: int) -> Decimal:
    """Decode COMP-3 packed BCD bytes to Decimal."""
    from shadow_diff import decode_comp3
    return decode_comp3(raw, pic_decimals)


def _encode_comp_binary(value: Decimal, byte_length: int,
                        pic_decimals: int, is_signed: bool) -> bytes:
    """Encode Decimal to COMP/COMP-4 big-endian binary (IBM convention).

    IBM binary sizes: 1-4 digits = 2 bytes (halfword),
    5-9 digits = 4 bytes (fullword), 10-18 digits = 8 bytes (doubleword).
    Max 18 digits (fits in 8-byte signed integer).
    """
    if pic_decimals:
        int_val = int(value * (Decimal(10) ** pic_decimals))
    else:
        int_val = int(value)
    # Guard: IBM COMP supports max 18 digits (fits in 8-byte int64)
    if byte_length > 8:
        raise ValueError(f"COMP binary byte_length={byte_length} exceeds 8 (max 18 digits)")
    return int_val.to_bytes(byte_length, byteorder='big', signed=is_signed)


def _decode_comp_binary(raw: bytes, pic_decimals: int,
                        is_signed: bool) -> Decimal:
    """Decode COMP/COMP-4 big-endian binary to Decimal."""
    int_val = int.from_bytes(raw, byteorder='big', signed=is_signed)
    if pic_decimals:
        return Decimal(int_val) / (Decimal(10) ** pic_decimals)
    return Decimal(int_val)


# ── COMP-1 / COMP-2 encode/decode ────────────────────────────────

def _encode_comp1(value) -> bytes:
    """Encode to COMP-1 (IEEE 754 single-precision, 4 bytes big-endian)."""
    return struct.pack('>f', float(value))


def _decode_comp1(raw: bytes) -> Decimal:
    """Decode COMP-1 (4 bytes big-endian) to Decimal."""
    return Decimal(str(struct.unpack('>f', raw)[0]))


def _encode_comp2(value) -> bytes:
    """Encode to COMP-2 (IEEE 754 double-precision, 8 bytes big-endian)."""
    return struct.pack('>d', float(value))


def _decode_comp2(raw: bytes) -> Decimal:
    """Decode COMP-2 (8 bytes big-endian) to Decimal."""
    return Decimal(str(struct.unpack('>d', raw)[0]))


# ── CobolMemoryRegion ─────────────────────────────────────────────

class CobolMemoryRegion:
    """Shared byte-backed storage for COBOL REDEFINES groups.

    A bytearray of fixed size with named field views. Multiple fields
    can overlap the same byte range — writes to one field are visible
    when reading another (COBOL REDEFINES semantics).

    Performance: each get()/put() call encodes/decodes through the byte
    buffer (~2-5µs per call). In tight PERFORM loops, this is ~20-50x
    slower than direct CobolDecimal.value access. Acceptable for
    behavioral verification; not intended for production workloads.

    Group-level MOVEs use get_bytes()/put_bytes() for raw byte transfer
    between regions, bypassing per-field encode/decode overhead.
    """

    __slots__ = ('_buffer', '_fields')

    def __init__(self, size: int):
        self._buffer = bytearray(b'\x00' * size)
        self._fields = {}

    def register_field(self, name, offset, length,
                       pic_integers=0, pic_decimals=0,
                       is_signed=False, storage_type='DISPLAY',
                       is_string=False):
        """Register a named field view over the shared buffer."""
        self._fields[name] = {
            'offset': offset,
            'length': length,
            'pic_integers': pic_integers,
            'pic_decimals': pic_decimals,
            'is_signed': is_signed,
            'storage_type': storage_type,
            'is_string': is_string,
        }

    def get(self, name):
        """Decode a field's current value from shared bytes."""
        info = self._fields[name]
        if info['offset'] + info['length'] > len(self._buffer):
            raise IndexError(
                f"Field '{name}' (offset={info['offset']}, length={info['length']}) "
                f"exceeds buffer size ({len(self._buffer)})")
        raw = bytes(self._buffer[info['offset']:info['offset'] + info['length']])
        st = info['storage_type']

        if info['is_string']:
            return _decode_pic_x(raw, info['length'])

        if st == 'COMP-3':
            return _decode_comp3(raw, info['pic_decimals'])
        elif st == 'COMP':
            return _decode_comp_binary(raw, info['pic_decimals'], info['is_signed'])
        else:
            return _decode_display_numeric(
                raw, info['pic_integers'], info['pic_decimals'], info['is_signed'])

    def put(self, name, value):
        """Encode a value into the shared buffer at the field's position."""
        info = self._fields[name]
        if info['offset'] + info['length'] > len(self._buffer):
            raise IndexError(
                f"Field '{name}' (offset={info['offset']}, length={info['length']}) "
                f"exceeds buffer size ({len(self._buffer)})")
        st = info['storage_type']

        if info['is_string']:
            if isinstance(value, CobolFieldProxy):
                value = value.value
            encoded = _encode_pic_x(str(value), info['length'])
        else:
            if isinstance(value, (CobolDecimal, CobolFieldProxy)):
                dec_val = value.value
            elif isinstance(value, Decimal):
                dec_val = value
            elif isinstance(value, str):
                stripped = value.strip()
                dec_val = Decimal(stripped) if stripped else Decimal('0')
            else:
                dec_val = Decimal(str(value))

            if st == 'COMP-3':
                encoded = _encode_comp3(dec_val, info['pic_integers'], info['pic_decimals'])
            elif st == 'COMP':
                encoded = _encode_comp_binary(
                    dec_val, info['length'], info['pic_decimals'], info['is_signed'])
            else:
                encoded = _encode_display_numeric(
                    dec_val, info['pic_integers'], info['pic_decimals'], info['is_signed'])

        # Write exactly len(encoded) bytes — prevents silent buffer resize
        # from bytearray slice assignment when encoder produces fewer bytes
        # than the registered field length (common in REDEFINES overlays)
        self._buffer[info['offset']:info['offset'] + len(encoded)] = encoded

    def get_bytes(self, offset=0, length=None):
        """Raw byte access for group-level MOVEs."""
        if length is None:
            length = len(self._buffer) - offset
        return bytes(self._buffer[offset:offset + length])

    def put_bytes(self, data, offset=0):
        """Raw byte write for group-level MOVEs."""
        end = offset + len(data)
        self._buffer[offset:end] = data[:len(self._buffer) - offset]

    def resize(self, new_size: int):
        """Resize buffer for OCCURS DEPENDING ON.

        Preserves existing data up to min(old_size, new_size).
        Growing appends zero bytes. Shrinking truncates.
        """
        if new_size < 0:
            raise ValueError(f"Cannot resize to negative size: {new_size}")
        old_size = len(self._buffer)
        if new_size == old_size:
            return
        if new_size > old_size:
            self._buffer.extend(b'\x00' * (new_size - old_size))
        else:
            self._buffer = self._buffer[:new_size]


# ── CobolFieldProxy ───────────────────────────────────────────────

class CobolFieldProxy:
    """Proxy that reads/writes through a CobolMemoryRegion.

    Duck-types CobolDecimal: same .store()/.value/comparison interface.
    Generated code can use proxy.store(val) and proxy.value identically
    to CobolDecimal — the proxy transparently encodes/decodes through
    the shared bytearray.
    """

    __slots__ = ('_region', '_field_name', 'pic_integers', 'pic_decimals',
                 'is_signed', 'is_comp', '_is_string', '_scale', '_max_int')

    def __init__(self, region, field_name):
        self._region = region
        self._field_name = field_name
        info = region._fields[field_name]
        self.pic_integers = info['pic_integers']
        self.pic_decimals = info['pic_decimals']
        self.is_signed = info['is_signed']
        self.is_comp = info['storage_type'] in ('COMP', 'COMP-4', 'COMP-5', 'BINARY')
        self._is_string = info['is_string']
        self._scale = Decimal(10) ** -info['pic_decimals'] if info['pic_decimals'] > 0 else Decimal(1)
        self._max_int = Decimal(10) ** info['pic_integers'] if info['pic_integers'] > 0 else Decimal(1)

    @property
    def value(self):
        """Decode current value from shared bytes."""
        return self._region.get(self._field_name)

    def store(self, value):
        """Encode value into shared bytes (applies PIC truncation first)."""
        if self._is_string:
            if isinstance(value, (CobolDecimal, CobolFieldProxy)):
                value = str(value.value)
            self._region.put(self._field_name, str(value))
        else:
            # Coerce to Decimal
            if isinstance(value, (CobolDecimal, CobolFieldProxy)):
                raw = value.value if isinstance(value.value, Decimal) else Decimal(str(value.value))
            elif isinstance(value, Decimal):
                raw = value
            elif isinstance(value, str):
                stripped = value.strip()
                raw = Decimal(stripped) if stripped else Decimal('0')
            else:
                raw = Decimal(str(value))

            # Apply PIC truncation (same rules as CobolDecimal)
            raw = self._apply_truncation(raw)
            self._region.put(self._field_name, raw)
        return self

    def _apply_truncation(self, raw):
        """Enforce PIC constraints — mirrors CobolDecimal._apply_truncation."""
        from compiler_config import get_config
        config = get_config()

        raw = raw.quantize(self._scale, rounding=ROUND_DOWN)

        if config.trunc_mode == "OPT":
            if not self.is_signed and raw < 0:
                raw = abs(raw)
            return raw

        if config.trunc_mode == "BIN" and self.is_comp:
            if not self.is_signed and raw < 0:
                raw = abs(raw)
            return raw

        if abs(raw) >= self._max_int or (raw != Decimal('0') and abs(raw) // 1 >= self._max_int):
            sign = Decimal('-1') if raw < 0 else Decimal('1')
            abs_val = abs(raw)
            integer_part = abs_val // 1
            decimal_part = abs_val % 1
            truncated_int = integer_part % self._max_int
            raw = sign * (truncated_int + decimal_part)
            raw = raw.quantize(self._scale, rounding=ROUND_DOWN)

        if not self.is_signed and raw < 0:
            raw = abs(raw)

        return raw

    def effective_max(self):
        """Maximum absolute value this field can hold before overflow.

        Same logic as CobolDecimal.effective_max().
        """
        from compiler_config import get_config
        config = get_config()
        if self.is_comp and config.trunc_mode == "BIN":
            total_digits = self.pic_integers + self.pic_decimals
            if total_digits <= 4:
                int_max = Decimal('32767')
            elif total_digits <= 9:
                int_max = Decimal('2147483647')
            else:
                int_max = Decimal('9223372036854775807')
            if self.pic_decimals > 0:
                return int_max / (Decimal(10) ** self.pic_decimals)
            return int_max
        scale = Decimal(10) ** -self.pic_decimals if self.pic_decimals > 0 else Decimal(1)
        return Decimal(10) ** self.pic_integers - scale

    def to_display(self):
        """Format value as the mainframe would display it."""
        if self._is_string:
            return str(self.value)
        val = self.value
        abs_val = abs(val)
        if self.pic_decimals > 0:
            int_part = int(abs_val // 1)
            dec_part = int((abs_val % 1) * (10 ** self.pic_decimals))
            display = f"{int_part:0{self.pic_integers}d}{dec_part:0{self.pic_decimals}d}"
        else:
            display = f"{int(abs_val):0{self.pic_integers}d}"
        if self.is_signed and val < 0:
            display = display + "-"
        return display

    def to_zoned_display(self):
        """Format value as IBM zoned decimal with overpunch sign encoding."""
        if self._is_string or not self.is_signed:
            return self.to_display()
        from abend_handler import encode_zoned_decimal
        total_digits = self.pic_integers + self.pic_decimals
        return encode_zoned_decimal(self.value, total_digits, self.pic_decimals)

    # ── Comparison operators (duck-type CobolDecimal) ──────────────

    def __eq__(self, other):
        v = self.value
        if isinstance(other, (CobolDecimal, CobolFieldProxy)):
            return v == other.value
        if self._is_string:
            return v == other
        return v == Decimal(str(other))

    def __ne__(self, other):
        return not self.__eq__(other)

    def __lt__(self, other):
        v = self.value
        if isinstance(other, (CobolDecimal, CobolFieldProxy)):
            return v < other.value
        if self._is_string:
            from ebcdic_utils import ebcdic_compare
            return ebcdic_compare(v, other, "cp037") < 0
        return v < Decimal(str(other))

    def __le__(self, other):
        v = self.value
        if isinstance(other, (CobolDecimal, CobolFieldProxy)):
            return v <= other.value
        if self._is_string:
            from ebcdic_utils import ebcdic_compare
            return ebcdic_compare(v, other, "cp037") <= 0
        return v <= Decimal(str(other))

    def __gt__(self, other):
        v = self.value
        if isinstance(other, (CobolDecimal, CobolFieldProxy)):
            return v > other.value
        if self._is_string:
            from ebcdic_utils import ebcdic_compare
            return ebcdic_compare(v, other, "cp037") > 0
        return v > Decimal(str(other))

    def __ge__(self, other):
        v = self.value
        if isinstance(other, (CobolDecimal, CobolFieldProxy)):
            return v >= other.value
        if self._is_string:
            from ebcdic_utils import ebcdic_compare
            return ebcdic_compare(v, other, "cp037") >= 0
        return v >= Decimal(str(other))

    # ── ON SIZE ERROR support ─────────────────────────────────────

    def check_overflow(self, value):
        """Return True if storing `value` would cause a size error."""
        if isinstance(value, (CobolDecimal, CobolFieldProxy)):
            value = value.value
        elif not isinstance(value, Decimal):
            value = Decimal(str(value))

        quantized = value.quantize(self._scale, rounding=ROUND_DOWN)
        return abs(quantized) > self.effective_max()

    def __repr__(self):
        return f"CobolFieldProxy({self._field_name}, value={self.value})"

    def __str__(self):
        return str(self.value)
