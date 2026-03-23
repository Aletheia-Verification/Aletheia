"""
poison_pill_generator.py — Edge-case input record generator for boundary testing.

For each INPUT field in the auto-generated layout, produces edge-case values:
  Numeric: max_value, zero, negative_max (signed), overflow, half_cent (V99+)
  String:  all_spaces, high_value

Each poison pill record sets ONE field to its edge value and all others to safe defaults.
Output: fixed-width ASCII .dat file matching the layout byte positions.
"""

from decimal import Decimal
from layout_generator import generate_layout, parse_pic_clause


# ── Edge case generators ───────────────────────────────────────


def _numeric_pills(field: dict) -> list[dict]:
    """Generate edge-case pills for a numeric (integer/decimal) field."""
    decimals = field.get("decimals", 0)
    name = field["name"]

    # Use PIC-derived integers/signed if enriched, else fall back to length
    signed = field.get("pic_signed", False)
    integers = field.get("pic_integers", 0)
    if not integers:
        length = field["length"]
        integers = length - decimals - (1 if signed else 0)
        if integers <= 0:
            integers = length - decimals

    max_int_part = "9" * integers
    max_dec_part = "9" * decimals if decimals else ""
    max_str = max_int_part + ("." + max_dec_part if decimals else "")
    max_val = Decimal(max_str)

    pills = [
        {
            "field": name,
            "edge_case": "max_value",
            "value": str(max_val),
            "description": f"Maximum: {'S' if signed else ''}9({integers})"
                           + (f"V{'9' * decimals}" if decimals else ""),
        },
        {
            "field": name,
            "edge_case": "zero",
            "value": "0",
            "description": "Zero value",
        },
    ]

    if signed:
        pills.append({
            "field": name,
            "edge_case": "negative_max",
            "value": str(-max_val),
            "description": f"Negative maximum: -{max_val}",
        })

    # Overflow: one integer digit beyond max
    overflow_int = "1" + "0" * integers
    overflow_str = overflow_int + (".00" if decimals else "")
    pills.append({
        "field": name,
        "edge_case": "overflow",
        "value": overflow_str,
        "description": f"Overflow: exceeds PIC by 1 integer digit",
    })

    if decimals > 0:
        # Half-cent boundary: X.XX5 for rounding edge
        half = "1." + "0" * (decimals - 1) + "5"
        pills.append({
            "field": name,
            "edge_case": "half_cent",
            "value": half,
            "description": f"Rounding boundary: {half}",
        })

    return pills


def _string_pills(field: dict) -> list[dict]:
    """Generate edge-case pills for a string (PIC X) field."""
    length = field["length"]
    name = field["name"]

    return [
        {
            "field": name,
            "edge_case": "all_spaces",
            "value": " " * length,
            "description": f"All spaces ({length} bytes)",
        },
        {
            "field": name,
            "edge_case": "high_value",
            "value": "\xff" * length,
            "description": f"HIGH-VALUE (0xFF x {length})",
        },
    ]


# ── Record formatting ─────────────────────────────────────────


def _format_numeric(value_str: str, length: int) -> str:
    """Format numeric value right-justified in `length` chars."""
    return value_str.rjust(length)


def _format_string(value_str: str, length: int) -> str:
    """Format string value left-justified, space-padded to `length` chars."""
    return value_str.ljust(length)[:length]


def _safe_default(field: dict) -> str:
    """Return a safe default value string for a field."""
    if field["type"] == "string":
        return "A" * field["length"]
    # Numeric: small valid value
    decimals = field.get("decimals", 0)
    if decimals > 0:
        return "1." + "0" * decimals
    return "1"


def _build_record(fields: list[dict], target_field: str,
                  target_value: str, record_length: int) -> str:
    """Build one fixed-width record line.

    Sets `target_field` to `target_value`, all others to safe defaults.
    """
    buf = [" "] * record_length

    for field in fields:
        name = field["name"]
        start = field["start"]
        length = field["length"]
        ftype = field["type"]

        if name == target_field:
            raw = target_value
        else:
            raw = _safe_default(field)

        if ftype == "string":
            formatted = _format_string(raw, length)
        else:
            formatted = _format_numeric(raw, length)

        # Write into buffer
        for i, ch in enumerate(formatted[:length]):
            buf[start + i] = ch

    return "".join(buf)


# ── Main generator ─────────────────────────────────────────────


def generate_poison_pills(analysis: dict, generated_python: str,
                          layout: dict | None = None) -> dict:
    """Generate edge-case poison pill input records.

    Args:
        analysis:         Parser analysis dict (from analyze_cobol).
        generated_python: Generated Python code string.
        layout:           Optional layout dict. Auto-generated if None.

    Returns:
        Dict with dat_bytes, record_count, pills metadata, layout, record_length.
    """
    if layout is None:
        layout = generate_layout(analysis, generated_python)

    fields = layout.get("fields", [])
    if not fields:
        return {
            "dat_bytes": b"",
            "record_count": 0,
            "pills": [],
            "layout": layout,
            "record_length": 0,
        }

    # Enrich layout fields with PIC info from analysis variables
    input_mapping = layout.get("input_mapping", {})
    var_lookup = {}
    for v in analysis.get("variables", []):
        name = v.get("name")
        if name:
            var_lookup[name.upper()] = v

    enriched_fields = []
    for field in fields:
        ef = dict(field)
        short_name = field["name"].upper()
        # Try exact match, then WS- prefixed, then LS- prefixed
        candidates = [short_name, f"WS-{short_name}", f"LS-{short_name}"]
        for candidate in candidates:
            v = var_lookup.get(candidate)
            if v:
                pic_info = v.get("pic_info")
                if pic_info:
                    ef["pic_integers"] = pic_info.get("integers", 0)
                    ef["pic_signed"] = pic_info.get("signed", False)
                break
        enriched_fields.append(ef)

    # Guard: no fields to generate pills for
    if not enriched_fields:
        return []

    # Compute record length from fields
    record_length = max(f["start"] + f["length"] for f in enriched_fields)

    # Generate pills per field
    all_pills = []
    for field in enriched_fields:
        ftype = field["type"]
        if ftype == "string":
            all_pills.extend(_string_pills(field))
        elif ftype in ("integer", "decimal"):
            all_pills.extend(_numeric_pills(field))

    # Build .dat lines
    lines = []
    for pill in all_pills:
        line = _build_record(fields, pill["field"], pill["value"], record_length)
        lines.append(line)

    dat_content = "\n".join(lines) + "\n" if lines else ""
    dat_bytes = dat_content.encode("ascii", errors="replace")

    return {
        "dat_bytes": dat_bytes,
        "record_count": len(all_pills),
        "pills": all_pills,
        "layout": layout,
        "record_length": record_length,
    }
