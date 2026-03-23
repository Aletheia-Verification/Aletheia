import logging
import re
from parse_conditions import parse_if_statement, parse_evaluate_statement, _convert_condition, _resolve_value, _is_string_operand, _resolve_subscripted_name, _subscript_index, _resolve_refmod_expr

logger = logging.getLogger(__name__)
from verb_handlers import (
    emit_stop_run, emit_exit_program, emit_goback, emit_simple_perform, emit_goto,
    emit_display, emit_initialize_single, emit_set_true, emit_accept,
    emit_move_single, emit_file_open, emit_file_read, emit_file_write,
    emit_file_close, emit_file_rewrite,
)


def to_python_name(name):
    """WS-DAILY-RATE -> ws_daily_rate"""
    return name.lower().replace("-", "_")


def extract_var_name(raw):
    """Extract clean variable name from raw parser output."""
    match = re.match(r'^\d{2}([A-Z][A-Z0-9\-]+?)(?:PIC|VALUE|OCCURS|\.)', raw.upper())
    if match:
        return match.group(1)
    return None


def _display_length(info):
    """Compute DISPLAY byte width from a var_info entry."""
    if info["is_string"]:
        return info.get("pic_length", 0) or 1
    return info.get("integers", 0) + info.get("decimals", 0) + (1 if info.get("signed") else 0)


def _get_level(raw):
    """Extract level number from raw variable text. Returns 999 on failure."""
    try:
        m = re.match(r'^(\d{2})', raw.upper())
        return int(m.group(1)) if m else 999
    except (ValueError, AttributeError):
        return 999


def _pic_display_length(pic_raw):
    """Compute display byte length from raw PIC string (for FILLER)."""
    if not pic_raw:
        return 0
    upper = pic_raw.upper()
    # PIC X(n) or PIC A(n)
    m = re.search(r'[XA]\((\d+)\)', upper)
    if m:
        return int(m.group(1))
    x_count = upper.count('X') + upper.count('A')
    if x_count > 0:
        return x_count
    # Numeric PIC: count 9s, Zs, etc.
    m = re.search(r'[9Z]\((\d+)\)', upper)
    if m:
        return int(m.group(1))
    return sum(1 for c in upper if c in '9ZVPB0*$+-.,')


def _build_group_concat(group_name, var_list, var_info, string_vars):
    """Build concat expression parts for a group, including FILLER byte gaps."""
    parts = []
    # Find the group in var_list
    grp_idx = None
    grp_level = 999
    for i, v in enumerate(var_list):
        vn = extract_var_name(v["raw"])
        if vn and vn.upper() == group_name.upper():
            grp_level = _get_level(v["raw"])
            grp_idx = i
            break
    if grp_idx is None:
        return parts
    # Walk children
    for j in range(grp_idx + 1, len(var_list)):
        child_raw = var_list[j]["raw"]
        child_level = _get_level(child_raw)
        if child_level <= grp_level:
            break
        child_name = extract_var_name(child_raw)
        child_pic = var_list[j].get("pic_raw", "")
        if not child_pic:
            continue  # sub-group header, skip
        if child_name and child_name.upper() == "FILLER":
            flen = _pic_display_length(child_pic)
            if flen > 0:
                # Use FILLER's VALUE if set, else spaces
                filler_val = var_list[j].get("initial_value")
                if filler_val and (filler_val.startswith("'") or filler_val.startswith('"')):
                    inner = filler_val.strip("'\"")
                    parts.append(f"{repr(inner * flen)}[:{flen}]")
                else:
                    parts.append(f"' ' * {flen}")
            continue
        if "REDEFINES" in child_raw.upper():
            continue  # skip REDEFINES overlays
        info = var_info.get(child_name)
        if not info:
            continue
        dlen = _display_length(info)
        py = info["python_name"]
        if info["is_string"]:
            parts.append(f"str({py}).ljust({dlen})")
        else:
            parts.append(f"{py}.to_display().ljust({dlen})")
    return parts


def _emit_search_body(body, text, known_vars, string_vars, indent=12):
    """Emit Python for a single statement inside SEARCH WHEN or AT END.
    known_vars is a set of COBOL names (uppercase). Compare COBOL names, not Python names.
    getText() strips all whitespace, so we match against spaceless patterns."""
    pad = " " * indent
    upper = text.upper()

    # MOVE literal/var TO target — getText() produces MOVE<src>TO<tgt>
    # Try longest known_vars match for source and target
    if upper.startswith("MOVE"):
        rest = upper[4:]  # after MOVE
        # Try literal first: MOVE'xxx'TO or MOVEnnnTO
        lit_m = re.match(r"('.*?'|\".*?\"|SPACES?|ZEROS?|ZEROES|\d+(?:\.\d+)?)(TO)(.+)", rest)
        if lit_m:
            src_cobol = lit_m.group(1)
            tgt_cobol = lit_m.group(3).strip(".")
            py_tgt = to_python_name(tgt_cobol)
            py_src = _resolve_value(src_cobol, known_vars, string_vars=string_vars, use_value=True)
            is_numeric = tgt_cobol in known_vars and tgt_cobol not in {v.upper() for v in string_vars}
            if is_numeric:
                body.append(f"{pad}{py_tgt}.store({py_src})")
            else:
                body.append(f"{pad}{py_tgt} = {py_src}")
            return
        # Try variable source: longest match against known_vars
        # Account for subscripts: WS-VAL(WS-IDX)
        for var in sorted(known_vars, key=len, reverse=True):
            if rest.startswith(var):
                after_var = rest[len(var):]
                # Skip subscript if present
                src_full = var
                if after_var.startswith("("):
                    close = after_var.find(")")
                    if close >= 0:
                        src_full = var + after_var[:close + 1]
                        after_var = after_var[close + 1:]
                if after_var.startswith("TO"):
                    tgt_cobol = after_var[2:].strip(".")
                    # Target might also have subscript
                    tgt_base = tgt_cobol.split("(")[0] if "(" in tgt_cobol else tgt_cobol
                    py_tgt = to_python_name(tgt_base)
                    py_src = _resolve_value(src_full, known_vars, string_vars=string_vars, use_value=True)
                    is_numeric = tgt_base in known_vars and tgt_base not in {v.upper() for v in string_vars}
                    if is_numeric:
                        body.append(f"{pad}{py_tgt}.store({py_src})")
                    else:
                        body.append(f"{pad}{py_tgt} = {py_src}")
                    return
        body.append(f"{pad}pass  # MANUAL REVIEW: {text[:80]}")
        return

    if upper.startswith("PERFORM"):
        para = upper[7:].strip(".")
        if para:
            body.append(f"{pad}para_{to_python_name(para)}()")
            return

    if upper.startswith("SET"):
        m = re.match(r'SET(.+?)TOTRUE', upper)
        if m:
            var = m.group(1).strip()
            py_var = to_python_name(var)
            body.append(f"{pad}{py_var} = True")
            return

    if upper.startswith("DISPLAY"):
        val = upper[7:].strip(".")
        py_val = _resolve_value(val, known_vars, string_vars=string_vars, use_value=True)
        body.append(f"{pad}print({py_val})")
        return

    body.append(f"{pad}pass  # MANUAL REVIEW: {text[:80]}")


def _emit_search_at_end(body, text, known_vars, string_vars, indent=8):
    """Emit Python for AT END block. text is raw getText() of atEndPhrase.
    getText() strips spaces, so we get ATENDMOVE99999TOWS-RESULT."""
    upper = text.upper()
    if upper.startswith("ATEND"):
        text = text[5:]
    elif upper.startswith("AT END"):
        text = text[6:]
    # Split on statement boundaries (MOVE, PERFORM, SET, DISPLAY, GO)
    stmts = re.split(r'(?=MOVE|PERFORM|SET|DISPLAY|GO)', text, flags=re.IGNORECASE)
    for s in stmts:
        s = s.strip()
        if s:
            _emit_search_body(body, s, known_vars, string_vars, indent=indent)


def get_pic_info(raw):
    """Extract decimal places from PIC clause."""
    raw_upper = raw.upper()
    v_match = re.search(r'V9\((\d+)\)', raw_upper)
    if v_match:
        return int(v_match.group(1))
    v_match = re.search(r'V(9+)', raw_upper)
    if v_match:
        return len(v_match.group(1))
    return 0


# ── Arithmetic Risk Analysis ─────────────────────────────────────

def _build_var_pic_map(analysis):
    """Build {VARIABLE-NAME-UPPER: pic_dict} from enriched analysis variables."""
    pic_map = {}
    for v in analysis.get("variables", []):
        name = v.get("name")
        pic_info = v.get("pic_info")
        if name and pic_info:
            pic_map[name.upper()] = {
                **pic_info,
                "pic_raw": v.get("pic_raw", ""),
                "name": name,
            }
    return pic_map


def _get_operation_and_operands(expr_text, pic_map):
    """
    Classify the dominant operation in a COMPUTE expression and collect
    operands (variables with known PIC info).
    Returns (operation_str, operands_list).
    """
    upper = expr_text.upper()

    if "FUNCTION" in upper:
        # FUNCTION INTEGER, FUNCTION MAX, etc. — can't do simple worst-case
        operands = [
            {"name": info["name"], "pic_raw": info["pic_raw"], "pic": info}
            for nm, info in pic_map.items() if nm in upper
        ]
        return "COMPLEX", operands

    has_mult = "*" in expr_text
    has_div = "/" in expr_text

    # To detect standalone +/- (not hyphens in variable names), strip known vars
    stripped = upper
    for nm in sorted(pic_map.keys(), key=len, reverse=True):
        stripped = stripped.replace(nm, "")
    # Also strip digits, parens, operators already known
    stripped_clean = re.sub(r'[\d\(\)\*\/\.]', '', stripped)
    has_minus = "-" in stripped_clean
    has_plus = "+" in stripped_clean

    if has_div and not has_mult:
        op = "DIVIDE"
    elif has_mult and not has_div:
        op = "MULTIPLY"
    elif (has_plus or has_minus) and not has_mult and not has_div:
        op = "ADD_SUB"
    elif has_mult and has_div:
        op = "COMPLEX"
    else:
        op = "COMPLEX"

    operands = [
        {"name": info["name"], "pic_raw": info["pic_raw"], "pic": info}
        for nm, info in pic_map.items() if nm in upper
    ]
    return op, operands


def _worst_case(operation, operands, target_pic):
    """
    Calculate worst-case integer/decimal digits for the operation result
    and classify SAFE / WARN / CRITICAL vs the target variable's PIC.
    """
    numeric_ops = [op for op in operands if op.get("pic")]

    if operation == "COMPLEX" or not numeric_ops:
        return {
            "status": "WARN",
            "reason": "Complex expression — manual precision review required",
            "description": "N/A",
            "result_integers": None,
            "result_decimals": None,
        }

    if operation == "DIVIDE":
        result_int = numeric_ops[0]["pic"]["integers"]   # numerator integer digits
        result_dec = None                                 # indeterminate
        desc = (
            f"{numeric_ops[0]['pic']['max_value']} / 1"
            " (denominator may approach 0 — result unbounded)"
        )

    elif operation == "MULTIPLY":
        result_int = sum(op["pic"]["integers"] for op in numeric_ops)
        result_dec = sum(op["pic"]["decimals"] for op in numeric_ops)
        parts = " x ".join(op["pic"]["max_value"] for op in numeric_ops)
        desc = parts

    else:  # ADD_SUB
        result_int = max(op["pic"]["integers"] for op in numeric_ops) + 1
        result_dec = max(op["pic"]["decimals"] for op in numeric_ops)
        vals = ", ".join(op["pic"]["max_value"] for op in numeric_ops)
        desc = f"max({vals}) + carry"

    t_int = target_pic["integers"]
    t_dec = target_pic["decimals"]

    if result_int is not None and result_int > t_int:
        status = "CRITICAL"
        reason = (
            f"Integer overflow: result needs {result_int} digit(s), "
            f"target holds {t_int}"
        )
    elif result_dec is None or result_dec > t_dec:
        status = "WARN"
        reason = (
            f"Decimal precision loss: result needs "
            f"{result_dec if result_dec is not None else '?'} place(s), "
            f"target holds {t_dec}"
        )
    else:
        status = "SAFE"
        reason = (
            f"Fits target "
            f"({result_int}i {result_dec}d <= {t_int}i {t_dec}d)"
        )

    return {
        "status": status,
        "reason": reason,
        "description": desc,
        "result_integers": result_int,
        "result_decimals": result_dec if result_dec is not None else "indeterminate",
    }


def compute_arithmetic_risks(analysis):
    """
    Analyse all COMPUTE statements in an analysis dict for integer overflow
    and decimal precision loss.

    Returns:
        {
            "risks":   [list of risk dicts],
            "summary": {"total":n, "safe":n, "warn":n, "critical":n}
        }
    """
    pic_map = _build_var_pic_map(analysis)
    risks = []

    for c in analysis.get("computes", []):
        stmt = c["statement"]   # getText() blob, e.g. "COMPUTEWS-DAILY-RATE=..."
        para = c.get("paragraph", "")

        if not stmt.upper().startswith("COMPUTE"):
            continue
        remainder = stmt[7:]    # strip "COMPUTE"
        if "=" not in remainder:
            continue

        eq_idx = remainder.index("=")
        target_name = remainder[:eq_idx].upper()
        expr = remainder[eq_idx + 1:]

        target_pic = pic_map.get(target_name)
        operation, operands = _get_operation_and_operands(expr, pic_map)

        if target_pic:
            wc = _worst_case(operation, operands, target_pic)
        else:
            wc = {
                "status": "WARN",
                "reason": "Target variable PIC unknown",
                "description": "N/A",
                "result_integers": None,
                "result_decimals": None,
            }

        risks.append({
            "compute": f"{target_name} = {expr[:65]}",
            "paragraph": para,
            "target": {
                "name": target_name,
                "pic": pic_map[target_name]["pic_raw"] if target_name in pic_map else "?",
                "integers": target_pic["integers"] if target_pic else None,
                "decimals": target_pic["decimals"] if target_pic else None,
                "max_value": target_pic["max_value"] if target_pic else "?",
            },
            "operands": [
                {
                    "name": op["name"],
                    "pic": op["pic_raw"],
                    "max_value": op["pic"]["max_value"],
                }
                for op in operands
                if op.get("pic")
            ],
            "operation": operation,
            "worst_case": wc["description"],
            "result_integers": wc["result_integers"],
            "result_decimals": wc["result_decimals"],
            "status": wc["status"],
            "reason": wc["reason"],
        })

    summary = {
        "total": len(risks),
        "safe": sum(1 for r in risks if r["status"] == "SAFE"),
        "warn": sum(1 for r in risks if r["status"] == "WARN"),
        "critical": sum(1 for r in risks if r["status"] == "CRITICAL"),
    }
    return {"risks": risks, "summary": summary}


def _parse_ose_handler(handler_text, known_variables, string_vars):
    """Convert ON SIZE ERROR / NOT ON SIZE ERROR handler getText() blob to Python lines.

    Handles common handler statements: MOVE literal/var TO var, PERFORM paragraph.
    Returns list of Python code strings, or None if handler cannot be parsed.
    """
    if not handler_text or not handler_text.strip():
        return []

    lines = []
    text = handler_text.strip()
    upper_string_vars = {s.upper() for s in string_vars} if string_vars else set()

    while text:
        upper = text.upper()

        # Try MOVE with literal value: MOVE'Y'TOWS-FLAG or MOVE0TOWS-RESULT
        m = re.match(
            r"MOVE('(?:[^']*)'|\"[^\"]*\"|\d+(?:\.\d+)?|SPACES?|ZEROS?|ZEROES)"
            r"TO([A-Z][A-Z0-9\-]*)(.*)",
            upper,
        )
        if m:
            val_len = len(m.group(1))
            tgt_name = m.group(2)
            # Extract original-case value from the raw text
            val_raw = text[4:4 + val_len]
            rest = text[4 + val_len + 2 + len(tgt_name):]
            py_tgt = to_python_name(tgt_name)
            is_str = tgt_name in upper_string_vars

            val_upper = val_raw.upper()
            if val_raw.startswith("'") or val_raw.startswith('"'):
                inner = val_raw[1:-1]
                if is_str:
                    lines.append(f"{py_tgt} = {repr(inner)}")
                else:
                    lines.append(f"{py_tgt}.store(Decimal({repr(inner)}))")
            elif val_upper in ("SPACES", "SPACE"):
                lines.append(f"{py_tgt} = ' '")
            elif val_upper in ("ZEROS", "ZEROES", "ZERO"):
                lines.append(f"{py_tgt}.store(Decimal('0'))")
            else:
                # Numeric literal
                lines.append(f"{py_tgt}.store(Decimal({repr(val_raw)}))")
            text = rest.strip()
            continue

        # Try MOVE variable TO variable (longest match)
        if upper.startswith("MOVE"):
            found = False
            for var in sorted(known_variables, key=len, reverse=True):
                prefix = f"MOVE{var.upper()}TO"
                if upper.startswith(prefix):
                    rest_after = text[len(prefix):]
                    tgt_m = re.match(r"([A-Z][A-Z0-9\-]*)(.*)", rest_after, re.IGNORECASE)
                    if tgt_m:
                        tgt_name = tgt_m.group(1).upper()
                        rest = tgt_m.group(2)
                        py_src = to_python_name(var)
                        py_tgt = to_python_name(tgt_name)
                        is_str = tgt_name in upper_string_vars
                        src_is_str = var.upper() in upper_string_vars
                        if is_str:
                            if src_is_str:
                                lines.append(f"{py_tgt} = {py_src}")
                            else:
                                lines.append(f"{py_tgt} = str({py_src}.value)")
                        else:
                            if src_is_str:
                                lines.append(f"{py_tgt}.store({py_src})")
                            else:
                                lines.append(f"{py_tgt}.store({py_src}.value)")
                        text = rest.strip()
                        found = True
                        break
            if found:
                continue
            return None  # Unparseable MOVE

        # Try PERFORM paragraph
        if upper.startswith("PERFORM"):
            rest = text[7:]
            pm = re.match(r"([A-Z][A-Z0-9\-]*)(.*)", rest, re.IGNORECASE)
            if pm:
                para = pm.group(1)
                text = pm.group(2).strip()
                lines.append(f"para_{to_python_name(para)}()")
                continue
            return None

        # Try DISPLAY (emit as print)
        if upper.startswith("DISPLAY"):
            rest = text[7:]
            dm = re.match(r"('(?:[^']*)'|\"[^\"]*\"|[A-Z][A-Z0-9\-]*)(.*)", rest, re.IGNORECASE)
            if dm:
                operand = dm.group(1)
                text = dm.group(2).strip()
                if operand.startswith("'") or operand.startswith('"'):
                    lines.append(f"print({operand})")
                else:
                    py_op = to_python_name(operand)
                    if operand.upper() in upper_string_vars:
                        lines.append(f"print({py_op})")
                    else:
                        lines.append(f"print({py_op}.value)")
                continue
            return None

        # Can't parse remaining text
        return None

    return lines


def _extract_ose_clauses(text, end_verb=""):
    """Extract ON SIZE ERROR and NOT ON SIZE ERROR handler text from getText() blob.

    Returns (clean_text, ose_text_or_None, nose_text_or_None).
    clean_text has the clauses stripped.
    """
    upper = text.upper()

    # Find NOTONSIZEERROR first (it contains ONSIZEERROR as substring)
    nose_idx = upper.find("NOTONSIZEERROR")
    ose_idx = -1

    # Find ONSIZEERROR that is NOT part of NOTONSIZEERROR
    search_start = 0
    while True:
        idx = upper.find("ONSIZEERROR", search_start)
        if idx == -1:
            break
        # Check it's not preceded by NOT
        if idx >= 3 and upper[idx - 3:idx] == "NOT":
            search_start = idx + 11
            continue
        ose_idx = idx
        break

    if ose_idx == -1 and nose_idx == -1:
        return text, None, None

    # Strip END-verb from the end
    clean_end = text
    if end_verb:
        for suffix in [f"END-{end_verb}", f"END{end_verb}"]:
            idx = upper.rfind(suffix.upper())
            if idx != -1:
                clean_end = text[:idx]
                break

    ose_text = None
    nose_text = None

    if ose_idx != -1 and nose_idx != -1:
        # Both present: ONSIZEERROR<ose>NOTONSIZEERROR<nose>END-VERB
        ose_raw = text[ose_idx + 11:nose_idx]
        nose_raw = text[nose_idx + 14:]
        # Strip END-verb from nose
        nose_upper = nose_raw.upper()
        if end_verb:
            for suffix in [f"END-{end_verb}", f"END{end_verb}"]:
                eidx = nose_upper.rfind(suffix.upper())
                if eidx != -1:
                    nose_raw = nose_raw[:eidx]
                    break
        ose_text = ose_raw.strip() or None
        nose_text = nose_raw.strip() or None
        clean_text = text[:ose_idx].strip()
    elif ose_idx != -1:
        # Only ON SIZE ERROR
        ose_raw = text[ose_idx + 11:]
        ose_upper = ose_raw.upper()
        if end_verb:
            for suffix in [f"END-{end_verb}", f"END{end_verb}"]:
                eidx = ose_upper.rfind(suffix.upper())
                if eidx != -1:
                    ose_raw = ose_raw[:eidx]
                    break
        ose_text = ose_raw.strip() or None
        clean_text = text[:ose_idx].strip()
    else:
        # Only NOT ON SIZE ERROR
        nose_raw = text[nose_idx + 14:]
        nose_upper = nose_raw.upper()
        if end_verb:
            for suffix in [f"END-{end_verb}", f"END{end_verb}"]:
                eidx = nose_upper.rfind(suffix.upper())
                if eidx != -1:
                    nose_raw = nose_raw[:eidx]
                    break
        nose_text = nose_raw.strip() or None
        clean_text = text[:nose_idx].strip()

    return clean_text, ose_text, nose_text


def _emit_ose_block(py_target, py_expr, ose_lines, nose_lines, has_ose):
    """Build Python code for ON SIZE ERROR / NOT ON SIZE ERROR control flow.

    has_ose: True if ON SIZE ERROR clause was present (controls store-on-overflow).
    Returns multi-line Python string.
    """
    lines = []
    lines.append(f"_ose_val = {py_expr}")

    if has_ose:
        lines.append(f"if {py_target}.check_overflow(_ose_val):")
        if ose_lines:
            for ln in ose_lines:
                lines.append(f"    {ln}")
        else:
            lines.append(f"    pass")
        lines.append(f"else:")
        lines.append(f"    {py_target}.store(_ose_val)")
        if nose_lines:
            for ln in nose_lines:
                lines.append(f"    {ln}")
    else:
        # Only NOT ON SIZE ERROR (no ON SIZE ERROR) — value always stored
        lines.append(f"{py_target}.store(_ose_val)")
        lines.append(f"if not {py_target}.check_overflow(_ose_val):")
        if nose_lines:
            for ln in nose_lines:
                lines.append(f"    {ln}")
        else:
            lines.append(f"    pass")

    return "\n".join(lines)


def parse_compute(statement, known_variables, string_vars=None, var_info=None):
    """Turn COBOL COMPUTE getText() blob into Python assignment.

    Uses CobolDecimal .store() for target and .value for variable refs.
    Emits ON SIZE ERROR / NOT ON SIZE ERROR control flow when present.
    """
    if string_vars is None:
        string_vars = set()
    if var_info is None:
        var_info = {}

    stmt = statement[7:].strip()  # strip 'COMPUTE'

    if "=" not in stmt:
        return None

    parts = stmt.split("=", 1)
    target = parts[0].strip()
    # Detect ROUNDED keyword before stripping — ANTLR getText() strips whitespace,
    # so "WS-RESULT ROUNDED" arrives as "WS-RESULTROUNDED"
    compute_rounded = bool(re.search(r'ROUNDED$', target, flags=re.IGNORECASE))
    target = re.sub(r'ROUNDED$', '', target, flags=re.IGNORECASE).strip()
    expr = parts[1].strip()

    # Extract ON SIZE ERROR / NOT ON SIZE ERROR clauses
    expr, ose_text, nose_text = _extract_ose_clauses(expr, end_verb="COMPUTE")

    def tokenize_expr(text, known_vars):
        tokens = []
        i = 0
        while i < len(text):
            if text[i].isspace():
                i += 1
                continue
            if text[i] == '*' and i + 1 < len(text) and text[i + 1] == '*':
                tokens.append('**')
                i += 2
                continue
            if text[i] in "*/+(),":
                tokens.append(text[i])
                i += 1
                continue
            if text[i].isdigit():
                j = i
                while j < len(text) and (text[j].isdigit() or text[j] == '.'):
                    j += 1
                tokens.append(f"Decimal('{text[i:j]}')")
                i = j
                continue
            if text[i:i + 8].upper() == "FUNCTION":
                i += 8
                # Skip whitespace after FUNCTION
                while i < len(text) and text[i].isspace():
                    i += 1
                # Match function name
                j = i
                while j < len(text) and (text[j].isalnum() or text[j] == '-'):
                    j += 1
                func_name = text[i:j].upper()
                i = j

                # Map function names to Python helpers
                _FUNC_MAP = {
                    "INTEGER": "int", "LENGTH": "_cobol_length",
                    "MAX": "_cobol_max", "MIN": "_cobol_min",
                    "ABS": "_cobol_abs", "MOD": "_cobol_mod",
                    "UPPER-CASE": "_cobol_upper", "UPPER": "_cobol_upper",
                    "LOWER-CASE": "_cobol_lower", "LOWER": "_cobol_lower",
                    "TRIM": "_cobol_trim", "REVERSE": "_cobol_reverse",
                    "ORD": "_cobol_ord",
                    "EXP": "_cobol_exp", "SQRT": "_cobol_sqrt",
                }
                # Multi-arg functions need comma injection (ANTLR strips commas)
                _MULTI_ARG = {"MAX", "MIN", "MOD"}

                if func_name in ("CURRENT-DATE", "CURRENT"):
                    tokens.append("_cobol_current_date()")
                elif func_name in _FUNC_MAP:
                    py_func = _FUNC_MAP[func_name]
                    if func_name in _MULTI_ARG and i < len(text) and text[i] == '(':
                        # Parse argument list: consume (...) and split on var boundaries
                        close = text.find(')', i)
                        if close > i:
                            arg_text = text[i + 1:close]
                            i = close + 1
                            # Tokenize each arg, inject commas between value groups
                            arg_tokens = tokenize_expr(arg_text, known_vars)
                            tokens.append(py_func)
                            tokens.append("(")
                            arg_groups = []
                            current_arg = []
                            for at in arg_tokens:
                                if at in "+-*/" or at == "**":
                                    current_arg.append(at)
                                else:
                                    has_value = any(t not in "+-*/()" and t != "**" for t in current_arg)
                                    if has_value and at not in "()":
                                        arg_groups.append(current_arg)
                                        current_arg = [at]
                                    else:
                                        current_arg.append(at)
                            if current_arg:
                                arg_groups.append(current_arg)
                            for gi, grp in enumerate(arg_groups):
                                if gi > 0:
                                    tokens.append(",")
                                tokens.extend(grp)
                            tokens.append(")")
                        else:
                            tokens.append(py_func)
                    else:
                        # For LENGTH: inject PIC capacity as second arg if argument is known variable
                        if func_name == "LENGTH" and i < len(text) and text[i] == '(':
                            close = text.find(')', i)
                            if close > i:
                                arg_name = text[i + 1:close].strip()
                                i = close + 1
                                py_arg = to_python_name(arg_name) if arg_name.upper() in {v.upper() for v in known_vars} else arg_name
                                _len_info = var_info.get(arg_name.upper(), {}) if var_info else {}
                                _pic_len = _len_info.get("pic_length", 0)
                                if not _pic_len and _len_info:
                                    _pic_len = _len_info.get("pic_integers", 0) + _len_info.get("pic_decimals", 0)
                                    if _len_info.get("is_signed") and _len_info.get("sign_separate"):
                                        _pic_len += 1
                                if _pic_len:
                                    tokens.append(f"{py_func}({py_arg}, {_pic_len})")
                                else:
                                    tokens.append(f"{py_func}({py_arg})")
                                continue
                        tokens.append(py_func)
                else:
                    tokens.append(f"_cobol_unknown_func('{func_name}')")
                continue
            if text[i].isalpha():
                best_match = None
                for var in known_vars:
                    if text[i:i + len(var)].upper() == var.upper():
                        if best_match is None or len(var) > len(best_match):
                            best_match = var
                if best_match:
                    py_name = to_python_name(best_match)
                    i += len(best_match)
                    # Check for OF qualifier: VAR OF GROUP → qualified name
                    if i + 2 < len(text) and text[i:i+2].upper() == "OF":
                        of_pos = i + 2
                        group_match = None
                        for var in known_vars:
                            vlen = len(var)
                            if of_pos + vlen <= len(text) and text[of_pos:of_pos+vlen].upper() == var.upper():
                                if group_match is None or vlen > len(group_match):
                                    group_match = var
                        if group_match:
                            qkey = f"{group_match}__{best_match}"
                            if qkey.upper() in {k.upper() for k in known_vars}:
                                py_name = to_python_name(qkey)
                                i = of_pos + len(group_match)
                    # Check for subscript: VAR(INDEX)
                    if i < len(text) and text[i] == '(':
                        close = text.find(')', i)
                        if close > i:
                            subscript = text[i + 1:close]
                            idx_expr = _subscript_index(subscript, known_vars, string_vars)
                            py_name = f"{py_name}[{idx_expr}]"
                            i = close + 1
                    # Numeric CobolDecimal vars need .value in expressions
                    if best_match.upper() not in {s.upper() for s in string_vars}:
                        tokens.append(f"{py_name}.value")
                    else:
                        tokens.append(py_name)
                else:
                    j = i
                    while j < len(text) and (text[j].isalnum() or text[j] == '-'):
                        j += 1
                    py_name = to_python_name(text[i:j])
                    tokens.append(f"{py_name}.value")
                    i = j
                continue
            if text[i] == '-':
                tokens.append('-')
                i += 1
                continue
            i += 1
        return tokens

    py_target = to_python_name(target)
    tokens = tokenize_expr(expr, known_variables)

    py_expr = ""
    for tok in tokens:
        if tok == "**" or tok in "*/+-":
            py_expr += f" {tok} "
        elif tok == "(":
            py_expr += "("
        elif tok == ")":
            py_expr += ")"
        elif tok == ",":
            py_expr += ", "
        else:
            py_expr += tok

    py_expr = " ".join(py_expr.split())

    # If ON SIZE ERROR or NOT ON SIZE ERROR present, emit control flow
    if ose_text is not None or nose_text is not None:
        ose_lines = _parse_ose_handler(ose_text, known_variables, string_vars) if ose_text else []
        nose_lines = _parse_ose_handler(nose_text, known_variables, string_vars) if nose_text else []
        # If handler can't be parsed, fall back to MANUAL REVIEW
        if (ose_text and ose_lines is None) or (nose_text and nose_lines is None):
            return None
        return _emit_ose_block(py_target, py_expr, ose_lines or [], nose_lines or [], has_ose=ose_text is not None)

    if compute_rounded:
        decimals = var_info.get(target.upper(), {}).get("decimals", 0)
        if decimals > 0:
            quant = f"Decimal('1e-{decimals}')"
        else:
            quant = "Decimal('1')"
        py_expr = f"({py_expr}).quantize({quant}, rounding=ROUND_HALF_UP)"
    return f"{py_target}.store({py_expr})"


def parse_arithmetic(verb, statement, known_variables, string_vars=None, var_info=None):
    """Turn standalone COBOL arithmetic (ADD/SUBTRACT/MULTIPLY/DIVIDE) into Python.

    Parses the getText() blob from ANTLR4 and emits CobolDecimal .store()/.value code.
    Emits ON SIZE ERROR / NOT ON SIZE ERROR control flow when present.
    Returns a Python statement string, or None if unparseable.
    """
    if string_vars is None:
        string_vars = set()
    if var_info is None:
        var_info = {}

    raw = statement[len(verb):]

    # Extract ON SIZE ERROR / NOT ON SIZE ERROR clauses before stripping
    raw, ose_text, nose_text = _extract_ose_clauses(raw, end_verb=verb)

    def _match_var(text, pos):
        """Match a variable at pos, consuming any subscript. Returns (name, upper, subscript, length) or None."""
        best = None
        for var in known_variables:
            vup = var.upper()
            if text[pos:pos + len(vup)].upper() == vup:
                if best is None or len(vup) > len(best[0]):
                    best = (var, vup)
        if not best:
            return None
        end = pos + len(best[1])
        subscript = None
        consumed = len(best[1])
        # Check for subscript: VAR(INDEX)
        if end < len(text) and text[end] == '(':
            close = text.find(')', end)
            if close > end:
                subscript = text[end + 1:close]
                consumed = close + 1 - pos
        return (best[0], best[1], subscript, consumed)

    def _resolve_operand(name, subscript=None):
        py = to_python_name(name)
        if subscript:
            idx = _subscript_index(subscript, known_variables, string_vars)
            return f"{py}[{idx}].value"
        return f"{py}.value"

    def _store(target, expr, subscript=None, rounded=False):
        py = to_python_name(target)
        if rounded:
            decimals = var_info.get(target.upper(), {}).get("decimals", 0)
            if decimals > 0:
                quant = f"Decimal('1e-{decimals}')"
            else:
                quant = "Decimal('1')"
            expr = f"({expr}).quantize({quant}, rounding=ROUND_HALF_UP)"
        if subscript:
            idx = _subscript_index(subscript, known_variables, string_vars)
            return f"{py}[{idx}].store({expr})"
        return f"{py}.store({expr})"

    keywords = ["GIVING", "REMAINDER", "ROUNDED", "TO", "FROM", "BY", "INTO"]
    tokens = []
    i = 0
    text = raw

    while i < len(text):
        # Try variable match first (longest match wins)
        best_var = _match_var(text, i)

        # Try keyword match
        matched_kw = None
        for kw in keywords:
            if text[i:i + len(kw)].upper() == kw:
                matched_kw = kw
                break

        # Variable match takes priority if it's longer than keyword
        if best_var and (not matched_kw or len(best_var[1]) >= len(matched_kw)):
            tokens.append(("VAR", best_var[0], best_var[2]))  # name, subscript
            i += best_var[3]  # consumed length includes subscript
            continue

        if matched_kw:
            tokens.append(("KW", matched_kw))
            i += len(matched_kw)
            continue

        # Unary minus: if '-' precedes a digit and previous token is not a number/variable
        if text[i] == '-' and i + 1 < len(text) and text[i + 1].isdigit():
            prev_is_value = tokens and tokens[-1][0] in ("NUM", "VAR")
            if not prev_is_value:
                j = i + 1
                while j < len(text) and (text[j].isdigit() or text[j] == '.'):
                    j += 1
                tokens.append(("NUM", text[i:j]))
                i = j
                continue

        if text[i].isdigit() or (text[i] == '.' and i + 1 < len(text) and text[i + 1].isdigit()):
            j = i
            while j < len(text) and (text[j].isdigit() or text[j] == '.'):
                j += 1
            tokens.append(("NUM", text[i:j]))
            i = j
            continue

        i += 1

    kws = [t[1] for t in tokens if t[0] == "KW"]

    def _val(operand):
        if operand[0] == "NUM":
            return f"Decimal('{operand[1]}')"
        return _resolve_operand(operand[1], operand[2] if len(operand) > 2 else None)

    # Track which variable targets have ROUNDED after them
    rounded_targets = set()

    def _store_target(operand, expr):
        if operand[0] == "VAR":
            is_rounded = operand[1].upper() in rounded_targets
            return _store(operand[1], expr, operand[2] if len(operand) > 2 else None, rounded=is_rounded)
        return None

    has_giving = "GIVING" in kws
    has_remainder = "REMAINDER" in kws

    groups = {}
    current_group = "BEFORE"
    groups[current_group] = []
    last_var = None
    for t in tokens:
        if t[0] == "KW" and t[1] in ("TO", "FROM", "BY", "INTO", "GIVING", "REMAINDER"):
            current_group = t[1]
            groups.setdefault(current_group, [])
            last_var = None
        elif t[0] == "KW" and t[1] == "ROUNDED":
            # ROUNDED follows the target it applies to
            if last_var:
                rounded_targets.add(last_var.upper())
        elif t[0] in ("VAR", "NUM"):
            groups.setdefault(current_group, []).append(t)
            last_var = t[1] if t[0] == "VAR" else None

    bare_result = None

    try:
        if verb == "ADD":
            if has_giving:
                before = groups.get("BEFORE", [])
                to_ops = groups.get("TO", [])
                giving_ops = groups.get("GIVING", [])
                if not giving_ops:
                    return None
                summands = before + to_ops
                expr = " + ".join(_val(op) for op in summands)
                bare_result = _store_target(giving_ops[0], expr)
            else:
                before = groups.get("BEFORE", [])
                to_ops = groups.get("TO", [])
                if not to_ops:
                    return None
                addend_expr = " + ".join(_val(op) for op in before)
                # Store to ALL targets after TO
                results = []
                for target in to_ops:
                    results.append(_store_target(target, f"{_val(target)} + {addend_expr}"))
                bare_result = "\n".join(r for r in results if r)

        elif verb == "SUBTRACT":
            if has_giving:
                before = groups.get("BEFORE", [])
                from_ops = groups.get("FROM", [])
                giving_ops = groups.get("GIVING", [])
                if not from_ops or not giving_ops:
                    return None
                sub_expr = " - ".join(_val(op) for op in before)
                bare_result = _store_target(giving_ops[0], f"{_val(from_ops[0])} - {sub_expr}")
            else:
                before = groups.get("BEFORE", [])
                from_ops = groups.get("FROM", [])
                if not from_ops:
                    return None
                sub_expr = " - ".join(_val(op) for op in before)
                # Store to ALL targets after FROM
                results = []
                for target in from_ops:
                    results.append(_store_target(target, f"{_val(target)} - {sub_expr}"))
                bare_result = "\n".join(r for r in results if r)

        elif verb == "MULTIPLY":
            if has_giving:
                before = groups.get("BEFORE", [])
                by_ops = groups.get("BY", [])
                giving_ops = groups.get("GIVING", [])
                if not by_ops or not giving_ops:
                    return None
                operand_a = before[0] if before else by_ops[0]
                operand_b = by_ops[0] if before else (by_ops[1] if len(by_ops) > 1 else before[0])
                bare_result = _store_target(giving_ops[0], f"{_val(operand_a)} * {_val(operand_b)}")
            else:
                before = groups.get("BEFORE", [])
                by_ops = groups.get("BY", [])
                if not by_ops:
                    return None
                operand_a = before[0] if before else None
                target = by_ops[0]
                if operand_a:
                    # MULTIPLY A BY B stores into B. If B is a literal,
                    # the variable A is the real target: A = A * B
                    if target[0] != "VAR" and operand_a[0] == "VAR":
                        bare_result = _store_target(operand_a, f"{_val(operand_a)} * {_val(target)}")
                    else:
                        bare_result = _store_target(target, f"{_val(target)} * {_val(operand_a)}")

        elif verb == "DIVIDE":
            # When ON SIZE ERROR is present, the OSE wrapper already catches ZeroDivisionError.
            # When bare (no OSE), we wrap to silently keep target unchanged (IBM spec).
            _has_ose = ose_text is not None or nose_text is not None

            def _div_store(tgt_op, dividend_expr, divisor_expr, rem_op=None):
                """Emit DIVIDE with safe zero-division handling when no OSE."""
                store_line = _store_target(tgt_op, f"{dividend_expr} / {divisor_expr}")
                if store_line is None:
                    return None
                rem_line = None
                if rem_op:
                    rem_line = _store_target(rem_op, f"{dividend_expr} - Decimal(int({dividend_expr} / {divisor_expr})) * {divisor_expr}")
                if _has_ose:
                    # OSE wrapper will catch ZeroDivisionError
                    result = store_line
                    if rem_line:
                        result += f"\n{rem_line}"
                    return result
                # No OSE: wrap to keep target unchanged on zero divisor (IBM spec)
                lines = [
                    f"try:",
                    f"    {store_line}",
                ]
                if rem_line:
                    lines.append(f"    {rem_line}")
                lines.extend([
                    f"except (ZeroDivisionError, InvalidOperation):",
                    f"    pass  # IBM: target unchanged on divide-by-zero",
                ])
                return "\n".join(lines)

            if "INTO" in kws:
                if has_giving:
                    before = groups.get("BEFORE", [])
                    into_ops = groups.get("INTO", [])
                    giving_ops = groups.get("GIVING", [])
                    remainder_ops = groups.get("REMAINDER", [])
                    if not into_ops or not giving_ops or not before:
                        return None
                    divisor = before[0]
                    dividend = into_ops[0]
                    rem_op = remainder_ops[0] if has_remainder and remainder_ops else None
                    bare_result = _div_store(giving_ops[0], _val(dividend), _val(divisor), rem_op)
                else:
                    before = groups.get("BEFORE", [])
                    into_ops = groups.get("INTO", [])
                    if not into_ops or not before:
                        return None
                    divisor = before[0]
                    target = into_ops[0]
                    bare_result = _div_store(target, _val(target), _val(divisor))
            elif "BY" in kws:
                before = groups.get("BEFORE", [])
                by_ops = groups.get("BY", [])
                giving_ops = groups.get("GIVING", [])
                remainder_ops = groups.get("REMAINDER", [])
                if not by_ops or not giving_ops or not before:
                    return None
                dividend = before[0]
                divisor = by_ops[0]
                rem_op = remainder_ops[0] if has_remainder and remainder_ops else None
                bare_result = _div_store(giving_ops[0], _val(dividend), _val(divisor), rem_op)

    except (IndexError, KeyError) as exc:
        logger.warning("emit_arithmetic parse error: %s: %s", type(exc).__name__, exc)
        return None

    if bare_result is None:
        return None

    # If ON SIZE ERROR or NOT ON SIZE ERROR present, wrap with overflow check
    if ose_text is not None or nose_text is not None:
        store_match = re.match(r'([\w\[\]\.\(\)]+)\.store\((.+)\)$', bare_result.split("\n")[0])
        if not store_match:
            return None
        py_target = store_match.group(1)
        py_expr = store_match.group(2)

        ose_lines = _parse_ose_handler(ose_text, known_variables, string_vars) if ose_text else []
        nose_lines = _parse_ose_handler(nose_text, known_variables, string_vars) if nose_text else []
        if (ose_text and ose_lines is None) or (nose_text and nose_lines is None):
            return None

        remainder_line = None
        result_lines = bare_result.split("\n")
        if len(result_lines) > 1:
            remainder_line = result_lines[1]

        lines = []
        lines.append("try:")
        lines.append(f"    _ose_val = {py_expr}")
        lines.append("except (ZeroDivisionError, InvalidOperation):")
        lines.append("    _ose_val = None")
        if ose_text is not None:
            lines.append(f"if _ose_val is None or {py_target}.check_overflow(_ose_val):")
            if ose_lines:
                for ln in ose_lines:
                    lines.append(f"    {ln}")
            else:
                lines.append(f"    pass")
            lines.append(f"else:")
            lines.append(f"    {py_target}.store(_ose_val)")
            if remainder_line:
                lines.append(f"    {remainder_line}")
            if nose_lines:
                for ln in nose_lines:
                    lines.append(f"    {ln}")
        else:
            lines.append("if _ose_val is not None:")
            lines.append(f"    {py_target}.store(_ose_val)")
            if remainder_line:
                lines.append(f"    {remainder_line}")
            lines.append(f"if _ose_val is not None and not {py_target}.check_overflow(_ose_val):")
            if nose_lines:
                for ln in nose_lines:
                    lines.append(f"    {ln}")
            else:
                lines.append(f"    pass")
        return "\n".join(lines)

    return bare_result


def generate_python_module(analysis, compiler_config=None, trace_mode=False):
    """
    Generate a complete Python module from an analysis dict (from analyze_cobol).

    Returns clean Python code. If conversion confidence < 95%, prepends
    a REQUIRES MANUAL REVIEW header. Always appends a side-by-side
    COBOL ↔ Python validation report as a comment block.

    compiler_config: optional CompilerConfig (from compiler_config module).
                     If None, uses default STD/EXTEND.
    """
    if not analysis.get("success"):
        error_code = f"# PARSE ERROR: {analysis.get('message', 'Parser returned no data')}"
        return {"code": error_code, "emit_counts": {}, "compiler_warnings": [], "db2_tainted_fields": []}

    # Resolve compiler config
    if compiler_config is None:
        from compiler_config import get_config
        compiler_config = get_config()
    trunc_mode = compiler_config.trunc_mode
    arith_mode = compiler_config.arith_mode
    arith_prec = compiler_config.precision

    compiler_warnings = []
    if trunc_mode == "OPT":
        compiler_warnings.append(
            "TRUNC(OPT) detected. Behavior depends on runtime data. "
            "Aletheia defaults to TRUNC(STD) semantics. Results may differ "
            "for COMP fields receiving values beyond PIC capacity."
        )

    if analysis.get("has_multiple_sections"):
        sections = analysis.get("sections", [])
        compiler_warnings.append(
            f"Program contains {len(sections)} SECTIONs ({', '.join(sections[:5])}). "
            "Implicit fall-through between sections is not modeled. "
            "Verify control flow manually."
        )

    if analysis.get("has_nested_programs"):
        prog_ids = analysis.get("program_ids", [])
        prog_names = ", ".join(p["name"] for p in prog_ids[:3])
        compiler_warnings.append(
            f"Program contains {len(prog_ids)} PROGRAM-ID entries ({prog_names}). "
            "Nested programs have separate DATA DIVISIONs and namespaces. "
            "Cross-program verification not supported."
        )

    db2_tainted_fields = []
    mr_flags = []

    if analysis.get("has_nested_programs"):
        mr_flags.append({
            "construct": "NESTED PROGRAMS",
            "detail": f"{len(analysis.get('program_ids', []))} PROGRAM-ID entries",
            "reason": "Nested programs have separate DATA DIVISIONs and namespaces.",
            "recommendation": "Verify each nested program independently.",
            "severity": "HIGH",
        })

    # ── Variable info ────────────────────────────────────────────
    known_vars = set()
    var_info = {}

    # Step 1: Count name occurrences to detect collisions
    from collections import Counter as _Counter
    _name_counts = _Counter()
    for v in analysis["variables"]:
        name = extract_var_name(v["raw"])
        if name:
            _name_counts[name] += 1

    for v in analysis["variables"]:
        raw = v["raw"]
        name = extract_var_name(raw)
        if name:
            # Determine var_info key: qualify duplicates with parent group
            parent_group = v.get("parent_group")
            if _name_counts[name] > 1 and parent_group:
                var_key = f"{parent_group}__{name}"
                py_name = to_python_name(var_key)
                known_vars.add(name)      # unqualified for backward compat
                known_vars.add(var_key)   # qualified for OF resolution
            else:
                var_key = name
                py_name = to_python_name(name)
                known_vars.add(name)
            _is_duplicate = (_name_counts[name] > 1 and parent_group is not None)

            pic_raw = v.get("pic_raw", "")
            is_string = bool(pic_raw and ("X" in pic_raw.upper() or "A" in pic_raw.upper() or "N" in pic_raw.upper()))
            # Fallback: pic_raw sometimes empty when JUSTIFIED/BLANK WHEN ZERO follows PIC
            if not is_string and not pic_raw:
                raw_upper = raw.upper()
                if "PICX" in raw_upper or "PIC X" in raw_upper or "PICA" in raw_upper or "PIC A" in raw_upper or "PICN" in raw_upper or "PIC N" in raw_upper:
                    is_string = True
                    # Extract pic_raw from raw for length calculation
                    pm = re.search(r'PIC\s*(X\(\d+\)|X+|A\(\d+\)|A+|N\(\d+\)|N+)', raw_upper)
                    if pm:
                        pic_raw = pm.group(1)
            pic_info = v.get("pic_info") or {}
            # Compute PIC X/A length for string padding
            pic_length = 0
            if is_string:
                pic_upper = pic_raw.upper()
                xl_match = re.search(r'X\((\d+)\)', pic_upper)
                if xl_match:
                    pic_length = int(xl_match.group(1))
                else:
                    pic_length = pic_upper.count("X")
                    if pic_length == 0:
                        al_match = re.search(r'A\((\d+)\)', pic_upper)
                        if al_match:
                            pic_length = int(al_match.group(1))
                        else:
                            pic_length = pic_upper.count("A")
            var_info[var_key] = {
                "comp3": v["comp3"],
                "storage_type": v.get("storage_type", "COMP-3" if v["comp3"] else "DISPLAY"),
                "decimals": get_pic_info(raw),
                "integers": pic_info.get("integers", 0),
                "signed": pic_info.get("signed", False),
                "python_name": py_name,
                "cobol_name": name,       # original unqualified COBOL name
                "parent_group": parent_group,
                "is_string": is_string,
                "pic_length": pic_length,
                "occurs": v.get("occurs", 0),
                "storage_section": v.get("storage_section", "WORKING"),
                # ── Deferred wiring flags ──
                "blank_when_zero": v.get("blank_when_zero", False),
                "justified_right": v.get("justified_right", False),
                "sign_position": v.get("sign_position", "trailing"),
                "sign_separate": v.get("sign_separate", False),
                "p_leading": pic_info.get("p_leading", 0),
                "p_trailing": pic_info.get("p_trailing", 0),
                "depending_on": v.get("depending_on"),
                "occurs_min": v.get("occurs_min", 0),
                "occurs_max": v.get("occurs_max", 0),
                "is_edited": pic_info.get("is_edited", False),
                "edit_pattern": pic_info.get("edit_pattern"),
                "initial_value": v.get("initial_value"),
            }
            # For duplicates, also store under the unqualified name (backward compat)
            # Last entry wins — preserves prior behavior where var_info[name] was overwritten
            if _is_duplicate:
                var_info[name] = var_info[var_key]

    # Track which var_info keys are unqualified aliases (skip during declaration)
    _alias_keys = set()
    for key, info in var_info.items():
        cobol_name = info.get("cobol_name", key)
        if key == cobol_name and "__" not in key and _name_counts.get(cobol_name, 1) > 1:
            _alias_keys.add(key)

    # Reverse lookup: COBOL name → list of var_info keys (for disambiguation)
    cobol_to_qualified = {}
    for key, info in var_info.items():
        cobol_name = info.get("cobol_name", key).upper()
        cobol_to_qualified.setdefault(cobol_name, []).append(key)

    def _lookup_var_info(name):
        """Look up var_info by exact key, then fall back to reverse map for unqualified names."""
        if name in var_info:
            return var_info[name]
        upper = name.upper()
        if upper in var_info:
            return var_info[upper]
        # Try reverse map: unqualified COBOL name → first qualified entry
        candidates = cobol_to_qualified.get(upper, [])
        if candidates:
            return var_info[candidates[0]]
        return None

    # PIC X/A variable names — needed for EBCDIC-aware comparisons
    string_vars = {name for name, info in var_info.items() if info["is_string"]}

    # ── Group → children map (for INITIALIZE) ────────────────────
    group_children: dict[str, list[str]] = {}
    var_list = analysis["variables"]
    for idx, v in enumerate(var_list):
        raw = v["raw"]
        vname = extract_var_name(raw)
        if not vname:
            continue
        level_match = re.match(r'^(\d{2})', raw.upper())
        if not level_match:
            continue
        level = int(level_match.group(1))
        pic_raw = v.get("pic_raw", "")
        if not pic_raw and level < 88:
            children = []
            skip_until_level = None  # track REDEFINES subtree to skip
            for j in range(idx + 1, len(var_list)):
                child_raw = var_list[j]["raw"]
                child_name = extract_var_name(child_raw)
                child_level_match = re.match(r'^(\d{2})', child_raw.upper())
                if not child_level_match:
                    continue
                child_level = int(child_level_match.group(1))
                if child_level <= level:
                    break
                if child_level == 88:
                    continue
                # Exit REDEFINES subtree when we reach same or lower level
                if skip_until_level is not None:
                    if child_level <= skip_until_level:
                        skip_until_level = None  # exited, fall through
                    else:
                        continue  # still inside REDEFINES subtree
                # Skip FILLER items
                if child_name and child_name.upper() == "FILLER":
                    continue
                # Skip REDEFINES overlays and their subordinate children
                if "REDEFINES" in child_raw.upper():
                    skip_until_level = child_level
                    continue
                if child_name and var_list[j].get("pic_raw"):
                    children.append(child_name)
            if children:
                group_children[vname] = children

    # ── REDEFINES detection ──────────────────────────────────────
    redefines_info = analysis.get("redefines", {})
    redefines_groups = redefines_info.get("redefines_groups", [])
    memory_map = redefines_info.get("memory_map", [])
    memory_map_by_name = {e["name"]: e for e in memory_map}

    redefines_field_set = set()       # field names needing byte-backed storage
    redefines_group_bases = set()     # group-level names (no PIC, have children)

    for group in redefines_groups:
        base = group["base"]
        redefines_field_set.add(base)
        redefines_field_set.update(group["overlays"])
        # Include children of base and overlay groups
        for parent_name in [base] + group["overlays"]:
            if parent_name in group_children:
                redefines_field_set.update(group_children[parent_name])
                redefines_group_bases.add(parent_name)

    # ── 88-level condition map ───────────────────────────────────
    level_88_map = {}
    for item in analysis.get("level_88", []):
        level_88_map[item["name"].upper()] = {
            "parent": item["parent"],
            "value": item["value"],
            "values": item.get("values") or [item["value"]],
            "thru": item.get("thru"),
        }

    # ── Identify statements nested inside IF branches ────────────
    # (to avoid emitting them twice — once inline, once recursively)
    statements_in_branches = set()
    for c in analysis["conditions"]:
        for stmt in c.get("then_statements", []) + c.get("else_statements", []):
            statements_in_branches.add(stmt)
    for ev in analysis.get("evaluates", []):
        for wc in ev["when_clauses"]:
            for stmt in wc["body_statements"]:
                statements_in_branches.add(stmt)
        for stmt in ev.get("when_other_statements", []):
            statements_in_branches.add(stmt)
    # Statements inside ON SIZE ERROR / NOT ON SIZE ERROR clauses
    for c in analysis.get("computes", []):
        for stmt in c.get("on_size_error", []) + c.get("not_on_size_error", []):
            statements_in_branches.add(stmt)
    for a in analysis.get("arithmetics", []):
        for stmt in a.get("on_size_error", []) + a.get("not_on_size_error", []):
            statements_in_branches.add(stmt)
    # Statements inside READ AT END / NOT AT END clauses
    for fop in analysis.get("file_operations", []):
        if fop.get("verb") == "READ":
            for stmt in fop.get("at_end", []) + fop.get("not_at_end", []):
                statements_in_branches.add(stmt)
    # Statements inside STRING/UNSTRING ON OVERFLOW / NOT ON OVERFLOW
    for s in analysis.get("strings", []):
        for stmt in s.get("on_overflow", []) + s.get("not_on_overflow", []):
            statements_in_branches.add(stmt)
    for u in analysis.get("unstrings", []):
        for stmt in u.get("on_overflow", []) + u.get("not_on_overflow", []):
            statements_in_branches.add(stmt)

    nested_condition_texts = set()
    for c in analysis["conditions"]:
        cstmt = c["statement"]
        if cstmt in statements_in_branches:
            nested_condition_texts.add(cstmt)
        else:
            # Also skip conditions embedded inside branch statements
            # (e.g. nested IF inside PERFORM VARYING inside another IF)
            for branch_stmt in statements_in_branches:
                if cstmt in branch_stmt and cstmt != branch_stmt:
                    nested_condition_texts.add(cstmt)
                    break

    # ── Build ordered statement list per paragraph ───────────────
    # Each entry is (line_number, type_string, data) — sorted by line
    stmts_by_para: dict[str, list] = {}

    # MOVEs (not those inside IF branches)
    for m in analysis.get("moves", []):
        if m["statement"] in statements_in_branches:
            continue
        para = m["paragraph"]
        stmts_by_para.setdefault(para, []).append((m.get("line", 0), "move", m))

    # Top-level COMPUTEs only (not those inside IF branches)
    for c in analysis["computes"]:
        if c["statement"] in statements_in_branches:
            continue
        para = c["paragraph"]
        stmts_by_para.setdefault(para, []).append((c.get("line", 0), "compute", c["statement"]))

    # Top-level IFs only (nested handled recursively in parse_if_statement)
    for c in analysis["conditions"]:
        if c["statement"] in nested_condition_texts:
            continue
        para = c["paragraph"]
        stmts_by_para.setdefault(para, []).append((c.get("line", 0), "condition", c))

    # EVALUATEs (not those nested inside IF branches)
    nested_evaluate_texts = {
        ev["statement"] for ev in analysis.get("evaluates", [])
        if ev["statement"] in statements_in_branches
    }
    for ev in analysis.get("evaluates", []):
        if ev["statement"] in statements_in_branches:
            continue
        para = ev["paragraph"]
        stmts_by_para.setdefault(para, []).append((ev.get("line", 0), "evaluate", ev))

    # ── PERFORM VARYING lookup (keyed by line number) ────────────
    _varying_by_line: dict[int, list] = {}
    for pv in analysis.get("perform_varyings", []):
        _varying_by_line.setdefault(pv["line"], []).append(pv)

    # PERFORMs (not those inside IF branches)
    # Collect raw performs first, then detect THRU pairs (same from + same line)
    _raw_performs: list[dict] = []
    for p in analysis.get("control_flow", []):
        if p.get("statement", "") in statements_in_branches:
            continue
        para = p["from"]
        if para:
            _raw_performs.append(p)

    # Detect THRU: two consecutive performs with same from-paragraph and same line
    _used_thru = set()
    for i in range(len(_raw_performs) - 1):
        a, b = _raw_performs[i], _raw_performs[i + 1]
        if a["from"] == b["from"] and a.get("line", -1) == b.get("line", -2) and a["to"] != b["to"]:
            thru_entry = {"from": a["from"], "to": a["to"], "thru_end": b["to"],
                          "line": a.get("line", 0), "statement": a.get("statement", "")}
            para = a["from"]
            stmts_by_para.setdefault(para, []).append((a.get("line", 0), "perform_thru", thru_entry))
            _used_thru.add(i)
            _used_thru.add(i + 1)

    # Build set of all paragraphs that appear in any THRU range (for GO TO awareness)
    _thru_para_set: set[str] = set()
    _para_order = analysis.get("paragraphs", [])
    for _stmts in stmts_by_para.values():
        for _line, _type, _stmt in _stmts:
            if _type == "perform_thru":
                try:
                    _si = _para_order.index(_stmt["to"])
                    _ei = _para_order.index(_stmt["thru_end"])
                    _thru_para_set.update(_para_order[_si:_ei + 1])
                except ValueError:
                    pass

    # Add remaining non-THRU performs — check for VARYING
    _used_varying_lines = set()
    for i, p in enumerate(_raw_performs):
        if i not in _used_thru:
            line = p.get("line", 0)
            para = p["from"]
            if line in _varying_by_line and line not in _used_varying_lines:
                _used_varying_lines.add(line)
                pv_list = _varying_by_line[line]
                pv = next((v for v in pv_list if not v.get("is_after")), pv_list[0])
                after_clauses = [v for v in pv_list if v.get("is_after")]
                stmts_by_para.setdefault(para, []).append(
                    (line, "perform_varying", {**p, **pv, "after_clauses": after_clauses})
                )
            else:
                stmts_by_para.setdefault(para, []).append((line, "perform", p))

    # ── Inline PERFORM VARYING not in control_flow ──────────────
    # enterPerformStatement only adds paragraph-target PERFORMs to
    # control_flow.  Inline PERFORMs (with END-PERFORM) are missing,
    # so the merge above never fires.  Catch them here directly from
    # perform_varyings with target=None.
    for pv in analysis.get("perform_varyings", []):
        if pv.get("target") is not None or pv.get("is_after"):
            continue
        line = pv["line"]
        if line in _used_varying_lines:
            continue  # already merged via control_flow path
        para = pv["paragraph"]
        if not para:
            continue
        _used_varying_lines.add(line)
        pv_list = _varying_by_line.get(line, [pv])
        after_clauses = [v for v in pv_list if v.get("is_after")]
        stmts_by_para.setdefault(para, []).append(
            (line, "perform_varying", {**pv, "after_clauses": after_clauses})
        )

    # GO TOs (not those inside IF branches)
    for g in analysis.get("gotos", []):
        if g["statement"] in statements_in_branches:
            continue
        para = g["paragraph"]
        stmts_by_para.setdefault(para, []).append((g.get("line", 0), "goto", g))

    # STOP RUNs (not those inside IF branches)
    for s in analysis.get("stops", []):
        if s["statement"] in statements_in_branches:
            continue
        para = s["paragraph"]
        stmts_by_para.setdefault(para, []).append((s.get("line", 0), "stop", s))

    # EXIT PROGRAMs (not those inside IF branches)
    for s in analysis.get("exit_programs", []):
        if s["statement"] in statements_in_branches:
            continue
        para = s["paragraph"]
        stmts_by_para.setdefault(para, []).append((s.get("line", 0), "exit_program", s))

    # GOBACKs (not those inside IF branches)
    for s in analysis.get("gobacks", []):
        if s["statement"] in statements_in_branches:
            continue
        para = s["paragraph"]
        stmts_by_para.setdefault(para, []).append((s.get("line", 0), "goback", s))

    # ALTERs (from exec_dependencies, assigned to paragraphs in Phase 1c)
    for dep in analysis.get("exec_dependencies", []):
        if dep.get("type") == "ALTER" and dep.get("paragraph"):
            stmts_by_para.setdefault(dep["paragraph"], []).append(
                (dep.get("line", 0), "alter", dep)
            )

    # Standalone arithmetic (ADD, SUBTRACT, MULTIPLY, DIVIDE)
    for a in analysis.get("arithmetics", []):
        if a["statement"] in statements_in_branches:
            continue
        para = a["paragraph"]
        stmts_by_para.setdefault(para, []).append((a.get("line", 0), "arithmetic", a))

    # INITIALIZE statements (not those inside IF branches)
    for ini in analysis.get("initializes", []):
        if ini["statement"] in statements_in_branches:
            continue
        para = ini["paragraph"]
        stmts_by_para.setdefault(para, []).append((ini.get("line", 0), "initialize", ini))

    # DISPLAY statements (not those inside IF branches)
    for disp in analysis.get("displays", []):
        if disp["statement"] in statements_in_branches:
            continue
        para = disp["paragraph"]
        stmts_by_para.setdefault(para, []).append((disp.get("line", 0), "display", disp))

    # ACCEPT FROM DATE/TIME statements (not those inside IF branches)
    for acc in analysis.get("accepts", []):
        if acc["statement"] in statements_in_branches:
            continue
        para = acc["paragraph"]
        stmts_by_para.setdefault(para, []).append((acc.get("line", 0), "accept", acc))

    # STRING statements (not those inside IF branches)
    for s in analysis.get("strings", []):
        if s["statement"] in statements_in_branches:
            continue
        para = s["paragraph"]
        stmts_by_para.setdefault(para, []).append((s.get("line", 0), "string", s))

    # UNSTRING statements (not those inside IF branches)
    for u in analysis.get("unstrings", []):
        if u["statement"] in statements_in_branches:
            continue
        para = u["paragraph"]
        stmts_by_para.setdefault(para, []).append((u.get("line", 0), "unstring", u))

    # INSPECT statements (not those inside IF branches)
    for ins in analysis.get("inspects", []):
        if ins["statement"] in statements_in_branches:
            continue
        para = ins["paragraph"]
        stmts_by_para.setdefault(para, []).append((ins.get("line", 0), "inspect", ins))

    # SET condition-name TO TRUE statements (not those inside IF branches)
    for s in analysis.get("sets", []):
        if s["statement"] in statements_in_branches:
            continue
        para = s["paragraph"]
        stmts_by_para.setdefault(para, []).append((s.get("line", 0), "set_true", s))

    # File I/O operations (OPEN/READ/WRITE/CLOSE) — skip those inside IF/EVALUATE
    for fop in analysis.get("file_operations", []):
        if fop.get("statement", "") in statements_in_branches:
            continue
        para = fop.get("paragraph")
        if not para:
            continue
        verb = fop.get("verb", "")
        _fio_type_map = {"OPEN": "file_open", "READ": "file_read",
                         "WRITE": "file_write", "CLOSE": "file_close",
                         "REWRITE": "file_rewrite"}
        fio_stmt_type = _fio_type_map.get(verb)
        if fio_stmt_type:
            stmts_by_para.setdefault(para, []).append(
                (fop.get("line", 0), fio_stmt_type, fop))

    # SORT statements
    for sort_stmt in analysis.get("sort_statements", []):
        para = sort_stmt.get("paragraph")
        if para:
            stmts_by_para.setdefault(para, []).append(
                (sort_stmt.get("line", 0), "sort", sort_stmt))

    # MERGE statements → MANUAL REVIEW
    for merge_stmt in analysis.get("merge_statements", []):
        para = merge_stmt.get("paragraph")
        if para:
            stmts_by_para.setdefault(para, []).append(
                (merge_stmt.get("line", 0), "merge", merge_stmt))

    # RELEASE statements (sort input procedure)
    for rel_stmt in analysis.get("release_statements", []):
        para = rel_stmt.get("paragraph")
        if para:
            stmts_by_para.setdefault(para, []).append(
                (rel_stmt.get("line", 0), "release", rel_stmt))

    # RETURN statements (sort output procedure)
    for ret_stmt in analysis.get("return_statements", []):
        para = ret_stmt.get("paragraph")
        if para:
            stmts_by_para.setdefault(para, []).append(
                (ret_stmt.get("line", 0), "return_sort", ret_stmt))

    # SEARCH statements
    for search_stmt in analysis.get("search_statements", []):
        para = search_stmt.get("paragraph")
        if para:
            stmts_by_para.setdefault(para, []).append(
                (search_stmt.get("line", 0), "search", search_stmt))

    # CALL statements
    for call_stmt in analysis.get("call_statements", []):
        para = call_stmt.get("paragraph")
        if para:
            stmts_by_para.setdefault(para, []).append(
                (call_stmt.get("line", 0), "call", call_stmt))

    # CANCEL statements
    for cancel_stmt in analysis.get("cancel_statements", []):
        para = cancel_stmt.get("paragraph")
        if para:
            stmts_by_para.setdefault(para, []).append(
                (cancel_stmt.get("line", 0), "cancel", cancel_stmt))

    # PERFORM UNTIL statements (not VARYING — those are handled above)
    _until_by_line: dict[int, dict] = {}
    for pu in analysis.get("perform_untils", []):
        _until_by_line[pu["line"]] = pu
    # Patch existing perform entries that have a matching UNTIL
    for para_key in stmts_by_para:
        new_list = []
        for entry in stmts_by_para[para_key]:
            ln, stype, sdata = entry
            if stype == "perform" and ln in _until_by_line:
                pu = _until_by_line[ln]
                new_list.append((ln, "perform_until", {**sdata, **pu}))
            else:
                new_list.append(entry)
        stmts_by_para[para_key] = new_list

    # PERFORM TIMES statements (procedure-level: PERFORM para N TIMES)
    _times_by_line: dict[int, dict] = {}
    for pt in analysis.get("perform_times", []):
        _times_by_line[pt["line"]] = pt
    # Patch existing perform entries that have a matching TIMES
    for para_key in stmts_by_para:
        new_list = []
        for entry in stmts_by_para[para_key]:
            ln, stype, sdata = entry
            if stype == "perform" and ln in _times_by_line:
                pt = _times_by_line[ln]
                new_list.append((ln, "perform_times", {**sdata, **pt}))
            else:
                new_list.append(entry)
        stmts_by_para[para_key] = new_list

    # Sort each paragraph's statements by source line number
    for para in stmts_by_para:
        stmts_by_para[para].sort(key=lambda x: x[0])

    # ── Absorb inline PERFORM VARYING body statements ─────────────
    # Statements whose line falls within an inline PV's (line, end_line)
    # range get moved into the PV entry as inline_body_stmts instead of
    # being emitted as separate paragraph-level statements.
    for para in stmts_by_para:
        pv_ranges = []
        for ln, stype, sdata in stmts_by_para[para]:
            if stype == "perform_varying" and sdata.get("target") is None:
                end_ln = sdata.get("end_line")
                if end_ln and end_ln > ln:
                    pv_ranges.append((ln, end_ln, sdata))

        if pv_ranges:
            absorbed = set()
            for pv_start, pv_end, pv_data in pv_ranges:
                pv_body = []
                for i, (ln, stype, sdata) in enumerate(stmts_by_para[para]):
                    if ln > pv_start and ln < pv_end and stype != "perform_varying":
                        pv_body.append((ln, stype, sdata))
                        absorbed.add(i)
                pv_data["inline_body_stmts"] = pv_body

            if absorbed:
                stmts_by_para[para] = [
                    entry for i, entry in enumerate(stmts_by_para[para])
                    if i not in absorbed
                ]

    # ── Conversion tracking ──────────────────────────────────────
    all_issues: list[dict] = []
    validation_entries: list[tuple] = []  # (cobol_repr, py_repr, status_char)
    total_stmts = 0
    fail_count = 0
    emit_counts = {"move": 0, "compute": 0, "condition": 0, "perform": 0, "goto": 0, "stop": 0, "evaluate": 0, "arithmetic": 0, "initialize": 0, "display": 0, "io": 0}

    # ── File I/O metadata ─────────────────────────────────────────
    # Determine if this is a file I/O program and build metadata
    has_file_io = bool(analysis.get("file_operations"))

    # Build FILE STATUS variable lookup: file_name → python_name
    _file_status_map = {}
    for fs in analysis.get("file_statuses", []):
        fn = fs.get("file_name")
        sv = fs.get("status_variable")
        if fn and sv:
            _file_status_map[fn.upper()] = to_python_name(sv)

    # Build record_name → file_name map from WRITE operations + FD
    _record_to_file = {}
    for fop in analysis.get("file_operations", []):
        if fop.get("verb") == "WRITE" and fop.get("record_name"):
            rn = fop["record_name"].upper()
            # Find which FD owns this record (heuristic: first FD)
            for fd in analysis.get("file_descriptions", []):
                _record_to_file[rn] = fd["name"].upper()
                break

    # Build file_meta: maps file_name → {record_name, fields, status_var, direction}
    # Fields come from memory_map (same logic as layout_generator._get_fd_record_fields)
    _file_meta = {}
    memory_map = analysis.get("redefines", {}).get("memory_map", [])
    fd_entries = analysis.get("file_descriptions", [])
    sd_entries = analysis.get("sort_descriptions", [])
    # Merge SD entries into FD list so they get field resolution too.
    # SD record fields define the sort key layout.
    _sd_names = {sd["name"].upper() for sd in sd_entries}
    all_file_entries = fd_entries + sd_entries
    # Sort by source line to maintain variable partitioning order
    all_file_entries.sort(key=lambda e: e.get("line", 0))

    has_sort = bool(analysis.get("sort_statements"))
    has_file_io = has_file_io or has_sort

    # Determine direction per file from file_operations
    _file_directions = {}
    for fop in analysis.get("file_operations", []):
        fn = fop.get("file_name", "").upper()
        d = fop.get("direction")
        if fn and d:
            _file_directions[fn] = d
    # Mark SD files as SORT direction
    for sd_name in _sd_names:
        _file_directions.setdefault(sd_name, "SORT")

    if has_file_io and all_file_entries:
        # Build a list of all FD record names (01-levels following FD entries).
        # Strategy: the variables list is in source order. FD records appear
        # before WORKING-STORAGE. We partition the variables list into FD groups
        # by finding consecutive 01-level entries at the start of the list.
        all_vars = analysis.get("variables", [])

        # Find FD record boundaries: each FD owns the next 01-level + its children
        fd_record_groups = []  # [(fd_name, record_name, [child_vars])]
        fd_idx = 0
        var_idx = 0

        while fd_idx < len(all_file_entries) and var_idx < len(all_vars):
            fd = all_file_entries[fd_idx]
            fd_name = fd["name"].upper()

            # Find the next 01-level variable (the FD record)
            record_name = None
            record_children = []
            found_01 = False

            while var_idx < len(all_vars):
                v = all_vars[var_idx]
                raw = v.get("raw", "")
                vname = v.get("name", "")
                if not vname:
                    var_idx += 1
                    continue
                level_match = re.match(r'^(\d{2})', raw.upper())
                level = int(level_match.group(1)) if level_match else 0

                if not found_01:
                    if level == 1:
                        record_name = vname
                        found_01 = True
                        var_idx += 1
                        continue
                    var_idx += 1
                    continue

                # Inside the FD record — collect children until next 01-level
                if level <= 1:
                    break  # Don't consume this variable — it belongs to the next FD
                if level == 88:
                    var_idx += 1
                    continue
                record_children.append(v)
                var_idx += 1

            fd_record_groups.append((fd_name, record_name, record_children))
            fd_idx += 1

        for fd_name, record_name, children in fd_record_groups:
            fd_fields = []
            current_offset = 0

            for v in children:
                vname = v.get("name", "")
                pic_raw = v.get("pic_raw", "")
                if not pic_raw:
                    continue

                is_string = bool("X" in pic_raw.upper() or "A" in pic_raw.upper() or "N" in pic_raw.upper())
                pic_info = v.get("pic_info") or {}
                integers = pic_info.get("integers", 0)
                decimals_count = pic_info.get("decimals", 0)

                # Calculate byte length
                if v.get("comp3"):
                    total_digits = integers + decimals_count
                    byte_len = (total_digits + 2) // 2
                elif v.get("storage_type") in ("COMP", "COMP-4"):
                    total_digits = integers + decimals_count
                    if total_digits <= 4:
                        byte_len = 2
                    elif total_digits <= 9:
                        byte_len = 4
                    else:
                        byte_len = 8
                else:
                    # DISPLAY: one byte per digit/char
                    signed = pic_info.get("signed", False)
                    byte_len = integers + decimals_count + (1 if signed and not v.get("comp3") else 0)
                    if is_string:
                        length_match = re.search(r'X\((\d+)\)', pic_raw.upper())
                        if length_match:
                            byte_len = int(length_match.group(1))
                        else:
                            byte_len = pic_raw.upper().count("X")
                            if byte_len == 0:
                                byte_len = pic_raw.upper().count("A")

                if byte_len <= 0:
                    byte_len = 1  # Minimum 1 byte

                field_type = "string" if is_string else "decimal"
                fd_fields.append({
                    "name": vname,
                    "python_name": to_python_name(vname),
                    "start": current_offset,
                    "length": byte_len,
                    "type": field_type,
                    "decimals": decimals_count,
                })
                current_offset += byte_len

            direction = _file_directions.get(fd_name, "INPUT")
            _file_meta[fd_name] = {
                "record_name": record_name,
                "fields": fd_fields,
                "record_length": current_offset if current_offset > 0 else None,
                "status_var": _file_status_map.get(fd_name),
                "direction": direction,
            }

    # ── Generate code body ───────────────────────────────────────
    body: list[str] = []

    body.append('"""')
    body.append("Auto-generated Python from COBOL")
    body.append(f"Paragraphs : {len(analysis['paragraphs'])}")
    body.append(f"Variables  : {len(analysis['variables'])}")
    body.append(f"COMP-3     : {analysis['summary']['comp3_variables']}")
    body.append(f"88-levels  : {len(level_88_map)}")
    body.append('"""')
    body.append("")
    body.append("from decimal import Decimal, ROUND_DOWN, ROUND_HALF_UP, InvalidOperation, getcontext")
    # Detect COMP-1/COMP-2 variables that need CobolFloat
    _has_comp_float = any(
        info.get("storage_type") in ("COMP-1", "COMP-2")
        for info in var_info.values()
    )
    _cobol_imports = ["CobolDecimal"]
    if redefines_field_set:
        _cobol_imports.extend(["CobolMemoryRegion", "CobolFieldProxy"])
    if _has_comp_float:
        _cobol_imports.append("CobolFloat")
    body.append(f"from cobol_types import {', '.join(_cobol_imports)}")
    body.append("from compiler_config import set_config")
    if string_vars:
        body.append("from ebcdic_utils import ebcdic_compare")
        body.append(f"_CODEPAGE = '{compiler_config.codepage}'")
    if has_sort:
        body.append("from cobol_file_io import ReverseKey")
    # ACCEPT FROM ENVIRONMENT support
    has_env_accept = any(
        a.get("type", "").startswith("ENVIRONMENT")
        for a in analysis.get("accepts", [])
    )
    if has_env_accept:
        body.append("import os as _os")
        body.append("_env_name = ''")

    # Detect FUNCTION keywords in COMPUTE/MOVE statements
    _has_functions = False
    _all_stmts_text = " ".join(
        c.get("statement", "") for c in analysis.get("computes", [])
    ) + " ".join(
        m.get("from", "") for m in analysis.get("moves", [])
    )
    if "FUNCTION" in _all_stmts_text.upper():
        _has_functions = True
        if "FUNCTIONEXP(" in _all_stmts_text.upper().replace(" ", ""):
            compiler_warnings.append(
                "FUNCTION EXP uses IEEE 754 double precision (15-17 sig digits). "
                "IBM Enterprise COBOL EXP may differ at the 15th+ digit. "
                "Verify EXP results manually if precision is critical."
            )
        body.append("")
        body.append("# " + "=" * 60)
        body.append("# COBOL INTRINSIC FUNCTION HELPERS")
        body.append("# " + "=" * 60)
        body.append("")
        body.append("def _cobol_length(val, _byte_len=None):")
        body.append("    if _byte_len is not None:")
        body.append("        return Decimal(_byte_len)")
        body.append("    if hasattr(val, 'value'):")
        body.append("        return Decimal(len(str(val)))")
        body.append("    return Decimal(len(str(val)))")
        body.append("")
        body.append("def _cobol_max(*args):")
        body.append("    vals = [a.value if hasattr(a, 'value') else Decimal(str(a)) for a in args]")
        body.append("    return max(vals)")
        body.append("")
        body.append("def _cobol_min(*args):")
        body.append("    vals = [a.value if hasattr(a, 'value') else Decimal(str(a)) for a in args]")
        body.append("    return min(vals)")
        body.append("")
        body.append("def _cobol_abs(val):")
        body.append("    v = val.value if hasattr(val, 'value') else Decimal(str(val))")
        body.append("    return abs(v)")
        body.append("")
        body.append("def _cobol_mod(a, b):")
        body.append("    av = a.value if hasattr(a, 'value') else Decimal(str(a))")
        body.append("    bv = b.value if hasattr(b, 'value') else Decimal(str(b))")
        body.append("    return av % bv")
        body.append("")
        body.append("def _cobol_upper(val):")
        body.append("    return str(val).upper()")
        body.append("")
        body.append("def _cobol_lower(val):")
        body.append("    return str(val).lower()")
        body.append("")
        body.append("def _cobol_trim(val):")
        body.append("    return str(val).strip()")
        body.append("")
        body.append("def _cobol_reverse(val):")
        body.append("    return str(val)[::-1]")
        body.append("")
        body.append("def _cobol_ord(val):")
        body.append("    s = str(val)")
        body.append("    return Decimal(ord(s[0])) if s else Decimal(0)")
        body.append("")
        body.append("def _cobol_exp(val):")
        body.append("    import math")
        body.append("    v = val.value if hasattr(val, 'value') else Decimal(str(val))")
        body.append("    return Decimal(str(math.exp(float(v))))")
        body.append("")
        body.append("def _cobol_sqrt(val):")
        body.append("    v = val.value if hasattr(val, 'value') else Decimal(str(val))")
        body.append("    return v.sqrt()")
        body.append("")
        body.append("def _cobol_current_date(_timestamp=None):")
        body.append("    if _timestamp is not None:")
        body.append("        return _timestamp")
        body.append("    return '0000000000000000'")
        body.append("")
        body.append("def _cobol_unknown_func(name):")
        body.append("    raise NotImplementedError(f'COBOL FUNCTION {name} not implemented')")

    body.append("")
    body.append(f"# Compiler: TRUNC({trunc_mode}), ARITH({arith_mode})")
    body.append(f"set_config(trunc_mode='{trunc_mode}', arith_mode='{arith_mode}')")
    body.append(f"getcontext().prec = {arith_prec}")
    if trace_mode:
        body.append("")
        body.append("_trace = []")
    body.append("")

    # File I/O flag and metadata
    body.append(f"_IS_IO_PROGRAM = {has_file_io}")
    if _thru_para_set:
        body.append("_thru_goto = None  # NOTE: Nested PERFORM THRU with GO TO may interfere (single global). Rare in real COBOL.")
    if has_file_io and _file_meta:
        body.append("")
        body.append("# " + "=" * 60)
        body.append("# FILE I/O METADATA")
        body.append("# " + "=" * 60)
        # Use repr() for Python-valid output (None instead of null)
        import json as _json
        meta_str = _json.dumps(_file_meta, indent=2)
        # Convert JSON null/true/false to Python None/True/False
        meta_str = meta_str.replace(": null", ": None")
        meta_str = meta_str.replace(": true", ": True")
        meta_str = meta_str.replace(": false", ": False")
        body.append(f"_FILE_META = {meta_str}")
        body.append("")

    # Sort procedure buffer/iterator (module-level init for global access)
    _has_sort_proc = any(
        s.get("input_procedure") or s.get("output_procedure")
        for s in analysis.get("sort_statements", [])
    )
    if _has_sort_proc:
        body.append("_sort_buffer = []")
        body.append("_sort_iter = iter([])")
        body.append("")

    body.append("# " + "=" * 60)
    body.append("# WORKING-STORAGE VARIABLES")
    body.append("# " + "=" * 60)
    body.append("")

    # ── REDEFINES memory regions (byte-backed) ─────────────────
    if redefines_field_set:
        body.append("# ── REDEFINES MEMORY REGIONS (byte-backed) ──")
        body.append("")

        for group in redefines_groups:
            base = group["base"]
            overlays = group["overlays"]
            base_entry = memory_map_by_name.get(base, {})
            base_offset = base_entry.get("offset", 0)

            # Region size = MAX of base and all overlays (correction 5)
            sizes = [base_entry.get("length", 0)]
            for ov in overlays:
                ov_entry = memory_map_by_name.get(ov, {})
                sizes.append(ov_entry.get("length", 0))
            region_size = max(sizes) if sizes else 0

            if region_size == 0:
                # WARNING: memory_map incomplete (correction 10)
                body.append(f"# WARNING: REDEFINES region for {base} has size 0 — memory_map incomplete")
                continue

            region_var = f"_region_{to_python_name(base)}"
            body.append(f"{region_var} = CobolMemoryRegion({region_size})")

            # Collect all fields: base children + overlay children + leaf items
            all_fields = []

            def _collect_fields(parent_name):
                """Collect leaf fields under a group, or the leaf itself."""
                if parent_name in group_children:
                    for child in group_children[parent_name]:
                        all_fields.append(child)
                elif parent_name in var_info:
                    all_fields.append(parent_name)

            _collect_fields(base)
            for ov in overlays:
                _collect_fields(ov)

            # Also register group-level names for group MOVEs (correction 7)
            group_names = []
            if base in redefines_group_bases:
                group_names.append(base)
            for ov in overlays:
                if ov in redefines_group_bases:
                    group_names.append(ov)

            # Register group-level fields (for get_bytes/put_bytes)
            for gname in group_names:
                g_entry = memory_map_by_name.get(gname, {})
                rel_offset = g_entry.get("offset", base_offset) - base_offset
                g_length = g_entry.get("length", 0)
                py_g = to_python_name(gname)
                body.append(
                    f"{region_var}.register_field('{gname}', "
                    f"{rel_offset}, {g_length}, "
                    f"is_string=True)"
                )

            # Register leaf fields
            for field_name in all_fields:
                f_entry = memory_map_by_name.get(field_name, {})
                f_info = var_info.get(field_name, {})
                rel_offset = f_entry.get("offset", base_offset) - base_offset
                f_length = f_entry.get("length", 0)
                if f_length == 0 and not f_info:
                    continue  # Skip unresolved fields

                f_integers = f_info.get("integers", 0) or 1
                f_decimals = f_info.get("decimals", 0)
                f_signed = f_info.get("signed", False)
                f_is_string = f_info.get("is_string", False)
                f_storage = f_info.get("storage_type", f_entry.get("storage_type", "DISPLAY"))

                body.append(
                    f"{region_var}.register_field('{field_name}', "
                    f"{rel_offset}, {f_length}, "
                    f"pic_integers={f_integers}, pic_decimals={f_decimals}, "
                    f"is_signed={f_signed}, storage_type='{f_storage}', "
                    f"is_string={f_is_string})"
                )

            # Emit CobolFieldProxy for each field
            for gname in group_names:
                py_g = to_python_name(gname)
                body.append(f"{py_g} = CobolFieldProxy({region_var}, '{gname}')")
            for field_name in all_fields:
                if field_name in var_info:
                    py_f = var_info[field_name]["python_name"]
                    body.append(f"{py_f} = CobolFieldProxy({region_var}, '{field_name}')")

            body.append("")

    # ── Standard variables (non-REDEFINES) ─────────────────────
    for name, info in var_info.items():
        if name in redefines_field_set:
            continue  # Already emitted as byte-backed proxy
        if name in _alias_keys:
            continue  # Unqualified alias for duplicate — emit alias below
        py_name = info["python_name"]
        occurs = info.get("occurs", 0)
        depending_on = info.get("depending_on")
        if info["is_string"]:
            str_init_val = info.get("initial_value")
            if str_init_val and str_init_val.upper() in ("SPACES", "SPACE"):
                str_init = '" "'
            elif str_init_val and str_init_val.startswith("'"):
                str_init = repr(str_init_val.strip("'\""))
            else:
                str_init = '""'
            if occurs > 0:
                if depending_on:
                    body.append(f'{py_name} = [{str_init} for _ in range({occurs})]'
                                f'  # ODO: depends on {depending_on}, range {info.get("occurs_min", 0)}-{occurs}')
                else:
                    body.append(f'{py_name} = [{str_init} for _ in range({occurs})]')
            else:
                body.append(f'{py_name} = {str_init}')
        else:
            storage = info.get("storage_type", "COMP-3" if info["comp3"] else "DISPLAY")

            # COMP-1/COMP-2 → CobolFloat (IEEE 754)
            if storage in ("COMP-1", "COMP-2"):
                precision = "'single'" if storage == "COMP-1" else "'double'"
                decl = f"CobolFloat(0.0, precision={precision})"
                comment = f"  # {storage} float"
                if occurs > 0:
                    body.append(f"{py_name} = [{decl} for _ in range({occurs})]  # OCCURS {occurs}")
                else:
                    body.append(f"{py_name} = {decl}{comment}")
                continue

            integers = info["integers"] or 1
            decimals = info["decimals"]
            signed = info["signed"]
            is_comp = storage in ('COMP', 'COMP-4', 'COMP-5', 'BINARY')

            # Build CobolDecimal constructor with all flags
            params = [
                f"pic_integers={integers}",
                f"pic_decimals={decimals}",
                f"is_signed={signed}",
                f"is_comp={is_comp}",
            ]
            if info.get("blank_when_zero"):
                params.append("blank_when_zero=True")
            if info.get("sign_position", "trailing") != "trailing":
                params.append(f"sign_position='{info['sign_position']}'")
            if info.get("sign_separate"):
                params.append("sign_separate=True")
            if info.get("p_leading", 0) > 0:
                params.append(f"p_leading={info['p_leading']}")
            if info.get("p_trailing", 0) > 0:
                params.append(f"p_trailing={info['p_trailing']}")
            if info.get("edit_pattern"):
                params.append(f"edit_pattern='{info['edit_pattern']}'")
            if storage == "COMP-5":
                params.append("is_native_binary=True")

            init_val = info.get("initial_value")
            if init_val and init_val.upper() not in ("ZERO", "ZEROS", "ZEROES", "SPACES", "SPACE", ""):
                # Strip surrounding quotes from COBOL literal
                cleaned = init_val.strip("'\"")
                init_repr = repr(cleaned)
            else:
                init_repr = "'0'"
            decl = f"CobolDecimal({init_repr}, {', '.join(params)})"
            comment = f"  # {storage} packed decimal" if storage == "COMP-3" else (f"  # {storage} binary" if is_comp else "")

            if occurs > 0:
                odo_comment = ""
                if depending_on:
                    odo_comment = f"  # ODO: depends on {depending_on}, range {info.get('occurs_min', 0)}-{occurs}"
                body.append(
                    f"{py_name} = [{decl} for _ in range({occurs})]"
                    f"  # OCCURS {occurs}{odo_comment}"
                )
            else:
                body.append(f"{py_name} = {decl}{comment}")

    # ── Unqualified aliases for duplicate variable names ──────
    # When CUST-ID exists in both WS-SRC and WS-TGT, the unqualified
    # name `cust_id` is an alias to the last-defined qualified version.
    # This preserves backward compatibility: MOVE 12345 TO CUST-ID works.
    if _alias_keys:
        for alias_name in sorted(_alias_keys):
            info = var_info[alias_name]
            qualified_py = info["python_name"]
            unqualified_py = to_python_name(alias_name)
            if unqualified_py != qualified_py:
                body.append(f"{unqualified_py} = {qualified_py}  # alias for unqualified reference")

    # ── Level 66 RENAMES ──────────────────────────────────────
    renames_list = analysis.get("renames", [])
    if renames_list:
        body.append("")
        body.append("# RENAMES aliases")
        for ren in renames_list:
            alias = ren.get("name", "")
            from_field = ren.get("from_field", "")
            thru_field = ren.get("thru_field")
            py_alias = to_python_name(alias)
            py_from = to_python_name(from_field)
            if thru_field:
                body.append(f"# MANUAL REVIEW: 66 {alias} RENAMES {from_field} THRU {thru_field}")
                body.append(f"{py_alias} = {py_from}  # range alias — byte-level RENAMES deferred")
            else:
                body.append(f"{py_alias} = {py_from}  # RENAMES {from_field}")

    # ── ODO variable-length warning ─────────────────────────────
    if any(v.get("depending_on") for v in analysis["variables"]):
        compiler_warnings.append(
            "Program contains OCCURS DEPENDING ON — variable-length "
            "records may affect Shadow Diff comparison"
        )

    # ── Figurative constants ─────────────────────────────────────
    _all_texts = set()
    for m in analysis.get("moves", []):
        _all_texts.add(m.get("from", "").upper())
        _all_texts.update(t.upper() for t in m.get("to", []))
    for c in analysis.get("computes", []):
        _all_texts.add(c.get("statement", "").upper())
    for c in analysis.get("conditions", []):
        _all_texts.add(c.get("statement", "").upper())
    for ev in analysis.get("evaluates", []):
        _all_texts.add(ev.get("statement", "").upper())
    _all_joined = " ".join(_all_texts)
    needs_spaces = "SPACES" in _all_joined or "SPACE" in _all_joined
    needs_zeros = "ZEROS" in _all_joined or "ZEROES" in _all_joined
    needs_high_value = "HIGH-VALUE" in _all_joined or "HIGH-VALUES" in _all_joined
    needs_low_value = "LOW-VALUE" in _all_joined or "LOW-VALUES" in _all_joined
    needs_quote = "QUOTE" in _all_joined or "QUOTES" in _all_joined
    has_figuratives = needs_spaces or needs_zeros or needs_high_value or needs_low_value or needs_quote
    if has_figuratives:
        body.append("")
        body.append("# COBOL figurative constants")
        if needs_spaces:
            body.append("spaces = ' '")
            body.append("space = ' '")
        if needs_zeros:
            body.append("zeros = Decimal('0')")
            body.append("zeroes = Decimal('0')")
        if needs_high_value:
            body.append("high_value = chr(255)")
            body.append("high_values = chr(255)")
        if needs_low_value:
            body.append("low_value = chr(0)")
            body.append("low_values = chr(0)")
        if needs_quote:
            body.append("quote = '\"'")
            body.append("quotes = '\"'")

    if level_88_map:
        body.append("")
        body.append("# 88-level condition map")
        for name, info in level_88_map.items():
            vals = info.get("values") or [info["value"]]
            thru = info.get("thru")
            if thru:
                body.append(f"# {name} -> {to_python_name(info['parent'])} in [{thru['low']}..{thru['high']}]")
            elif len(vals) > 1:
                body.append(f"# {name} -> {to_python_name(info['parent'])} in {vals}")
            else:
                body.append(f"# {name} -> {to_python_name(info['parent'])} == \"{info['value']}\"")


    # ── EXEC SQL / CICS dependency warnings ─────────────────────
    exec_deps = analysis.get("exec_dependencies", [])
    exec_analysis = analysis.get("exec_analysis")
    if exec_deps:
        body.append("")
        body.append("# " + "=" * 60)
        body.append("# EXTERNAL DEPENDENCY — REQUIRES MANUAL REVIEW")
        body.append("# The following EXEC blocks were stripped from the source.")
        body.append("# The generated Python does NOT replicate their behavior.")
        body.append("# " + "=" * 60)
        for dep in exec_deps:
            if dep["type"] == "ALTER":
                continue  # ALTERs are emitted inline in paragraph bodies
            verb = dep.get('verb', '')
            preview = dep.get('body_preview', dep.get('flag', ''))[:80].replace('\n', ' ')
            body.append(f"# {dep['type']} {verb}: {preview}" if verb else f"# {dep['type']}: {preview}")

        # Enhanced taint tracking comments
        if exec_analysis and exec_analysis.get("variable_taint"):
            taint = exec_analysis["variable_taint"]
            if taint.get("tainted"):
                db2_tainted_fields = [t["var"] for t in taint["tainted"]]
                body.append("#")
                body.append("# TAINTED VARIABLES (populated by external source):")
                for t in taint["tainted"]:
                    body.append(f"#   {t['var']} <- {t['source']}: {t['detail']}")
            if taint.get("used"):
                body.append("#")
                body.append("# USED VARIABLES (sent to external source):")
                for u in taint["used"]:
                    body.append(f"#   {u['var']} -> {u['source']}: {u['detail']}")
            if taint.get("control"):
                body.append("#")
                body.append("# CONTROL VARIABLES (affect program flow):")
                for c in taint["control"]:
                    body.append(f"#   {c['var']} -- {c['detail']}")
        if exec_analysis and exec_analysis.get("sqlcode_branches"):
            body.append("#")
            body.append("# SQLCODE BRANCH MAPPING:")
            for br in exec_analysis["sqlcode_branches"]:
                body.append(f"#   {br['condition']} -> {br['meaning']}")

        body.append("")
        for dep in exec_deps:
            if dep["type"] == "ALTER":
                continue  # ALTERs counted inline in paragraph bodies
            taint_detail = ""
            if exec_analysis:
                taint = exec_analysis.get("variable_taint", {})
                tainted_names = [t["var"] for t in taint.get("tainted", [])]
                if tainted_names:
                    taint_detail = f" | Tainted: {', '.join(tainted_names[:3])}"
            all_issues.append({
                "status": "MANUAL REVIEW",
                "reason": f"External dependency stripped{taint_detail}",
                "cobol": f"{dep['type']} {dep.get('verb', '')}: {dep.get('body_preview', dep.get('flag', '')).replace(chr(10), ' ')[:50]}",
            })
            total_stmts += 1
            fail_count += 1

        if db2_tainted_fields:
            field_list = ", ".join(db2_tainted_fields[:10])
            compiler_warnings.append(
                f"Program contains EXEC SQL. Fields populated by database queries "
                f"cannot be verified: {field_list}"
            )

    if analysis.get("accepts"):
        compiler_warnings.append(
            "ACCEPT FROM DATE/TIME returns placeholder values. "
            "Date/time fields will not match mainframe output."
        )

    body.append("")
    body.append("# " + "=" * 60)
    body.append("# PROCEDURE DIVISION")
    body.append("# " + "=" * 60)
    body.append("")

    _all_py_names = set(v["python_name"] for v in var_info.values())
    # Add unqualified alias names to globals
    for alias_name in _alias_keys:
        _all_py_names.add(to_python_name(alias_name))
    global_vars = ", ".join(sorted(_all_py_names))
    if _has_sort_proc:
        global_vars += ", _sort_buffer, _sort_iter"
    if _thru_para_set:
        global_vars += ", _thru_goto"

    # Build evaluate lookup for nested EVALUATE resolution
    _all_evaluates_by_text = {
        ev["statement"]: ev for ev in analysis.get("evaluates", [])
    }

    # Build string lookup for nested STRING resolution
    _all_strings_by_text = {
        s["statement"]: s for s in analysis.get("strings", [])
    }

    for para in analysis["paragraphs"]:
        func_name = "para_" + to_python_name(para)
        body.append(f"def {func_name}():")
        body.append(f'    """COBOL Paragraph: {para}"""')
        body.append(f"    global {global_vars}")
        body.append("")

        if para in stmts_by_para:
            for _line_num, stmt_type, stmt in stmts_by_para[para]:
                total_stmts += 1

                if stmt_type == "compute":
                    py_stmt = parse_compute(stmt, known_vars, string_vars=string_vars, var_info=var_info)
                    if py_stmt and '_cobol_unknown_func' in py_stmt:
                        body.append(f"    # MANUAL REVIEW: {stmt[:55]}")
                        body.append(f"    pass")
                        cobol_repr = ("COMPUTE " + stmt[7:])[:45]
                        validation_entries.append((cobol_repr, "# MANUAL REVIEW (unknown FUNCTION)", "[FAIL]"))
                        fail_count += 1
                    elif py_stmt:
                        _first_line = py_stmt.split("\n")[0]
                        _trace_target = None
                        if trace_mode and ".store(" in _first_line:
                            _trace_target = _first_line.split(".store(")[0].strip()
                            body.append(f"    _old_val = str({_trace_target}.value)")
                        for line in py_stmt.split("\n"):
                            body.append(f"    {line}")
                        if trace_mode and _trace_target:
                            _cobol_var = stmt[7:].split("=")[0].strip() if "=" in stmt[7:] else stmt[7:30]
                            body.append(f"    _trace.append({{'line': {_line_num}, 'verb': 'COMPUTE', 'variable': {repr(_cobol_var)}, 'old_value': _old_val, 'new_value': str({_trace_target}.value)}})")
                        cobol_repr = ("COMPUTE " + stmt[7:])[:45]
                        validation_entries.append((cobol_repr, py_stmt.split("\n")[0][:45], "[OK]  "))
                        emit_counts["compute"] += 1
                    else:
                        body.append(f"    # MANUAL REVIEW: {stmt[:55]}")
                        validation_entries.append((stmt[:45], "# MANUAL REVIEW", "[FAIL]"))
                        fail_count += 1

                elif stmt_type == "condition":
                    py_code, issues = parse_if_statement(
                        stmt, known_vars, level_88_map, analysis["conditions"],
                        string_vars=string_vars,
                        all_evaluates=analysis.get("evaluates", []),
                        all_strings=analysis.get("strings", []),
                        thru_paras=_thru_para_set if para in _thru_para_set else None,
                    )
                    all_issues.extend(issues)

                    has_fails = any(i["status"] == "fail" for i in issues)
                    has_warns = any(i["status"] == "warn" for i in issues)
                    if has_fails:
                        fail_count += 1
                        status_char = "[FAIL]"
                    elif has_warns:
                        status_char = "[WARN]"
                    else:
                        status_char = "[OK]  "

                    cobol_repr = f"IF {stmt['condition']}"[:45]
                    py_repr = (py_code.split("\n")[0] if py_code else "# MANUAL REVIEW")[:45]
                    validation_entries.append((cobol_repr, py_repr, status_char))

                    if not has_fails:
                        emit_counts["condition"] += 1

                    for line in py_code.split("\n"):
                        body.append(f"    {line}")

                elif stmt_type == "move":
                    if stmt.get("corresponding"):
                        # MOVE CORRESPONDING — match fields by name across groups
                        source_group = stmt["from"].upper().rstrip('.')
                        target_groups = [t.upper().rstrip('.') for t in stmt["to"]]

                        for tgt_group in target_groups:
                            src_children = group_children.get(source_group)
                            tgt_children = group_children.get(tgt_group)

                            if src_children is None or tgt_children is None:
                                body.append(f"    # MANUAL REVIEW: MOVE CORRESPONDING {source_group} TO {tgt_group} (group not resolved)")
                                body.append(f"    pass")
                                fail_count += 1
                                validation_entries.append((f"MOVE CORR {source_group}"[:45], "# MANUAL REVIEW", "[FAIL]"))
                                continue

                            tgt_set = set(tgt_children)
                            matching = [c for c in src_children if c in tgt_set]

                            if not matching:
                                body.append(f"    # MOVE CORRESPONDING {source_group} TO {tgt_group}: no matching fields")
                            else:
                                body.append(f"    # MOVE CORRESPONDING {source_group} TO {tgt_group} ({len(matching)} fields)")
                                for field_name in matching:
                                    info = var_info.get(field_name)
                                    if info is None:
                                        continue
                                    py_name = info["python_name"]
                                    if info["is_string"]:
                                        pl = info.get("pic_length", 0)
                                        if pl > 0:
                                            body.append(f"    {py_name} = str({py_name})[:{pl}].ljust({pl})")
                                        else:
                                            body.append(f"    {py_name} = {py_name}")
                                    else:
                                        body.append(f"    {py_name}.store({py_name}.value)")

                            cobol_repr = f"MOVE CORR {source_group} TO {tgt_group}"[:45]
                            py_repr = f"{len(matching)} fields matched"[:45]
                            validation_entries.append((cobol_repr, py_repr, "[OK]  "))

                        emit_counts["move"] += 1
                    else:
                        move_from = stmt["from"]
                        move_to_list = stmt["to"]

                        # Handle MOVE FUNCTION CURRENT-DATE TO target
                        if move_from.upper().strip().startswith("FUNCTION"):
                            func_part = move_from.upper().replace("FUNCTION", "", 1).strip()
                            if func_part in ("CURRENT-DATE", "CURRENT"):
                                for target_name in move_to_list:
                                    py_tgt = to_python_name(target_name)
                                    body.append(f"    {py_tgt} = _cobol_current_date()")
                                    body.append(f"    # WARNING: FUNCTION CURRENT-DATE returns placeholder — inject _timestamp for real values")
                                cobol_repr = f"MOVE FUNCTION CURRENT-DATE"[:45]
                                validation_entries.append((cobol_repr, "_cobol_current_date()"[:45], "[OK]  "))
                                emit_counts["move"] += 1
                                _has_functions = True
                                continue
                            else:
                                body.append(f"    # MANUAL REVIEW: MOVE FUNCTION {func_part}")
                                body.append(f"    pass")
                                fail_count += 1
                                validation_entries.append((f"MOVE FUNCTION {func_part}"[:45], "# MANUAL REVIEW", "[FAIL]"))
                                continue

                        # ── GROUP REFMOD SOURCE — MOVE WS-GROUP(5:3) TO target ──
                        if '(' in move_from and ':' in move_from:
                            _paren = move_from.find('(')
                            _close = move_from.rfind(')')
                            if _close > _paren:
                                _base = move_from[:_paren].strip().upper()
                                _rm_text = move_from[_paren + 1:_close]
                                _rm_parts = _rm_text.split(':', 1)
                                if len(_rm_parts) == 2 and _base in group_children:
                                    _children = group_children[_base]
                                    _concat_parts = []
                                    for _child in _children:
                                        _ci = var_info.get(_child)
                                        if not _ci:
                                            continue
                                        _dl = _display_length(_ci)
                                        _py = _ci["python_name"]
                                        if _ci["is_string"]:
                                            _concat_parts.append(f"str({_py}).ljust({_dl})")
                                        else:
                                            _concat_parts.append(f"{_py}.to_display().ljust({_dl})")
                                    _src_expr = " + ".join(_concat_parts) if _concat_parts else "''"
                                    _start_e, _len_e = _resolve_refmod_expr(
                                        _rm_parts[0].strip(), _rm_parts[1].strip(), known_vars, string_vars
                                    )
                                    body.append(f"    _grp_src = ({_src_expr})[{_start_e}:{_start_e} + {_len_e}]")
                                    for target_name in move_to_list:
                                        _tgt_upper = target_name.upper().rstrip('.')
                                        _tgt_info = var_info.get(_tgt_upper)
                                        _py_tgt = to_python_name(target_name)
                                        if _tgt_info and _tgt_info["is_string"]:
                                            body.append(f"    {_py_tgt} = _grp_src")
                                        elif _tgt_info:
                                            body.append(f"    {_py_tgt}.store(Decimal(_grp_src.strip() or '0'))")
                                        else:
                                            body.append(f"    {_py_tgt} = _grp_src")
                                    cobol_repr = f"MOVE {move_from}"[:45]
                                    py_repr = f"_grp_src = ...slice"[:45]
                                    validation_entries.append((cobol_repr, py_repr, "[OK]  "))
                                    emit_counts["move"] += 1
                                    continue

                        # ── GROUP MOVE — byte-level copy ───────────────
                        src_upper = move_from.upper().rstrip('.')
                        src_children_list = group_children.get(src_upper)
                        any_tgt_group = any(
                            t.upper().rstrip('.') in group_children for t in move_to_list
                        )

                        if src_children_list or any_tgt_group:
                            # Build source display string (including FILLER bytes)
                            if src_children_list:
                                concat_parts = _build_group_concat(
                                    src_upper, var_list, var_info, string_vars
                                )
                                src_expr = " + ".join(concat_parts) if concat_parts else "''"
                            else:
                                # Elementary source → its string value
                                py_src = to_python_name(move_from)
                                s_info = var_info.get(src_upper, {})
                                src_expr = (
                                    f"str({py_src})"
                                    if s_info.get("is_string")
                                    else f"{py_src}.to_display()"
                                )

                            body.append(f"    _grp = {src_expr}")

                            for target_name in move_to_list:
                                tgt_upper = target_name.upper().rstrip('.')
                                tgt_children_list = group_children.get(tgt_upper)
                                if tgt_children_list:
                                    # Build target field map with correct offsets (including FILLER gaps)
                                    tgt_total = 0
                                    tgt_fields = []
                                    _tgt_idx = next((i for i, v in enumerate(var_list) if extract_var_name(v["raw"]) and extract_var_name(v["raw"]).upper() == tgt_upper), None)
                                    if _tgt_idx is not None:
                                        _tgt_level = _get_level(var_list[_tgt_idx]["raw"])
                                        for _j in range(_tgt_idx + 1, len(var_list)):
                                            _cr = var_list[_j]["raw"]
                                            _cl = _get_level(_cr)
                                            if _cl <= _tgt_level:
                                                break
                                            _cn = extract_var_name(_cr)
                                            _cp = var_list[_j].get("pic_raw", "")
                                            if not _cp:
                                                continue
                                            if _cn and _cn.upper() == "FILLER":
                                                tgt_total += _pic_display_length(_cp)
                                                continue
                                            if "REDEFINES" in _cr.upper():
                                                continue
                                            _ci = var_info.get(_cn)
                                            if _ci:
                                                _dl = _display_length(_ci)
                                                tgt_fields.append((_ci, _dl, tgt_total))
                                                tgt_total += _dl
                                    else:
                                        # Fallback: use group_children without FILLER offsets
                                        for child in tgt_children_list:
                                            _ci = var_info.get(child)
                                            if not _ci:
                                                continue
                                            _dl = _display_length(_ci)
                                            tgt_fields.append((_ci, _dl, tgt_total))
                                            tgt_total += _dl
                                    body.append(f"    _grp_padded = _grp[:{tgt_total}].ljust({tgt_total})")
                                    for _ci, _dl, _off in tgt_fields:
                                        py = _ci["python_name"]
                                        if _ci["is_string"]:
                                            body.append(f"    {py} = _grp_padded[{_off}:{_off + _dl}]")
                                        else:
                                            body.append(f"    {py}.store(Decimal(_grp_padded[{_off}:{_off + _dl}].strip() or '0'))")
                                else:
                                    # Target is elementary — move group as string
                                    py_tgt = to_python_name(target_name)
                                    t_info = var_info.get(tgt_upper, {})
                                    if t_info.get("is_string"):
                                        pl = t_info.get("pic_length", 0)
                                        if pl:
                                            body.append(f"    {py_tgt} = _grp[:{pl}].ljust({pl})")
                                        else:
                                            body.append(f"    {py_tgt} = _grp")
                                    else:
                                        body.append(f"    {py_tgt}.store(Decimal(_grp.strip() or '0'))")

                            cobol_repr = f"MOVE {move_from} TO {', '.join(move_to_list)}"[:45]
                            validation_entries.append((cobol_repr, "group byte-level copy"[:45], "[OK]  "))
                            emit_counts["move"] += 1
                            continue

                        for target_name in move_to_list:
                            # Reference modification on target: MOVE 'X' TO VAR(5:3)
                            if '(' in target_name and ':' in target_name:
                                paren_idx = target_name.find('(')
                                close_idx = target_name.rfind(')')
                                if close_idx > paren_idx:
                                    base_part = target_name[:paren_idx].strip()
                                    refmod_text = target_name[paren_idx + 1:close_idx]
                                    parts = refmod_text.split(':', 1)
                                    base_upper = base_part.upper()
                                    base_matched = next((v for v in known_vars if v.upper() == base_upper), None)
                                    if base_matched and len(parts) == 2:
                                        start_expr, length_expr = _resolve_refmod_expr(
                                            parts[0].strip(), parts[1].strip(), known_vars, string_vars
                                        )
                                        py_base = to_python_name(base_matched)
                                        py_value = _resolve_value(
                                            move_from, known_vars,
                                            string_vars=string_vars,
                                            use_value=False,
                                        )
                                        body.append(
                                            f"    {py_base} = {py_base}[:{start_expr}] + "
                                            f"str({py_value})[:{length_expr}].ljust({length_expr}) + "
                                            f"{py_base}[{start_expr} + {length_expr}:]"
                                        )
                                        continue
                            is_string = _is_string_operand(target_name, string_vars)
                            py_value = _resolve_value(
                                move_from, known_vars,
                                string_vars=string_vars,
                                use_value=not is_string,
                            )
                            # Numeric→string MOVE: use to_display() or to_edited_display()
                            if is_string and not _is_string_operand(move_from, string_vars):
                                src_info = var_info.get(move_from.upper(), {})
                                if src_info and not src_info.get("is_string", False):
                                    if src_info.get("is_edited") and src_info.get("edit_pattern"):
                                        py_value = f"{to_python_name(move_from)}.to_edited_display()"
                                    else:
                                        py_value = f"{to_python_name(move_from)}.to_display()"
                            # Handle subscripted target: VAR(IDX) → var[idx]
                            sub_target, base_var = _resolve_subscripted_name(
                                target_name, known_vars, string_vars
                            )
                            py_target = sub_target if sub_target else to_python_name(target_name)
                            pl = var_info.get(target_name.upper(), {}).get("pic_length", 0) if is_string else 0
                            if trace_mode and not is_string:
                                body.append(f"    _old_val = str({py_target}.value)")
                            elif trace_mode and is_string:
                                body.append(f"    _old_val = str({py_target})")
                            just_r = var_info.get(target_name.upper(), {}).get("justified_right", False)
                            code, _ = emit_move_single(py_value, py_target, is_string, indent="    ", pic_length=pl, justified_right=just_r)
                            body.append(code)
                            if trace_mode:
                                _new_expr = f"str({py_target}.value)" if not is_string else f"str({py_target})"
                                body.append(f"    _trace.append({{'line': {_line_num}, 'verb': 'MOVE', 'variable': {repr(target_name)}, 'old_value': _old_val, 'new_value': {_new_expr}}})")
                        cobol_repr = f"MOVE {move_from} TO {', '.join(move_to_list)}"[:45]
                        py_repr = f"{to_python_name(move_to_list[0])}.store(...)"[:45]
                        validation_entries.append((cobol_repr, py_repr, "[OK]  "))
                        emit_counts["move"] += 1

                elif stmt_type == "perform":
                    code, _ = emit_simple_perform(stmt["to"], indent="    ")
                    body.append(code)
                    target_func = "para_" + to_python_name(stmt["to"])
                    cobol_repr = f"PERFORM {stmt['to']}"[:45]
                    validation_entries.append((cobol_repr, f"{target_func}()"[:45], "[OK]  "))
                    emit_counts["perform"] += 1

                elif stmt_type == "perform_times":
                    # PERFORM para N TIMES — call paragraph N times
                    target_func = "para_" + to_python_name(stmt["to"])
                    count = stmt.get("count", "1")
                    body.append(f"    for _pt_i in range({count}):")
                    body.append(f"        {target_func}()")
                    cobol_repr = f"PERFORM {stmt['to']} {count} TIMES"[:45]
                    validation_entries.append((cobol_repr, f"for _ in range({count}): {target_func}()"[:45], "[OK]  "))
                    emit_counts["perform"] += 1

                elif stmt_type == "perform_varying":
                    # PERFORM para VARYING var FROM val BY val UNTIL cond
                    # Supports AFTER clauses for nested loops
                    varying_var = stmt.get("variable", "")
                    from_val = stmt.get("from", "1")
                    by_val = stmt.get("by", "1")
                    until_cond = stmt.get("until", "")
                    target_para = stmt.get("target")
                    after_clauses = stmt.get("after_clauses", [])

                    py_var = to_python_name(varying_var)
                    py_from = _resolve_value(from_val, known_vars, string_vars=string_vars, use_value=False)
                    py_by = _resolve_value(by_val, known_vars, string_vars=string_vars, use_value=True)

                    py_until = _convert_condition(until_cond, known_vars, level_88_map, string_vars)[0] if until_cond else "True"
                    is_test_after = stmt.get("test_after", False)

                    # Outer loop: primary VARYING
                    body.append(f"    {py_var}.store({py_from})")
                    if is_test_after:
                        body.append(f"    while True:")
                    else:
                        body.append(f"    while not ({py_until}):")

                    if after_clauses:
                        # Nested AFTER loops
                        indent = "        "  # 8 spaces (inside outer while)
                        for ac in after_clauses:
                            ac_var = to_python_name(ac["variable"])
                            ac_from = _resolve_value(ac["from"], known_vars, string_vars=string_vars, use_value=False)
                            ac_by = _resolve_value(ac["by"], known_vars, string_vars=string_vars, use_value=True)
                            ac_until = _convert_condition(ac["until"], known_vars, level_88_map, string_vars)[0] if ac.get("until") else "True"
                            body.append(f"{indent}{ac_var}.store({ac_from})")
                            body.append(f"{indent}while not ({ac_until}):")
                            indent += "    "  # Add 4 spaces for each nesting level

                        # Innermost body: call target paragraph
                        if target_para:
                            target_func = "para_" + to_python_name(target_para)
                            body.append(f"{indent}{target_func}()")
                        else:
                            body.append(f"{indent}pass  # inline PERFORM VARYING body")

                        # Increment AFTER variables (innermost first, then outer)
                        for ac in reversed(after_clauses):
                            ac_var = to_python_name(ac["variable"])
                            ac_by = _resolve_value(ac["by"], known_vars, string_vars=string_vars, use_value=True)
                            body.append(f"{indent}{ac_var}.store({ac_var}.value + {ac_by})")
                            indent = indent[:-4]  # Dedent for next outer increment

                        # TEST AFTER: check condition BEFORE increment
                        if is_test_after:
                            body.append(f"{indent}if {py_until}:")
                            body.append(f"{indent}    break")
                        # Increment primary VARYING (inside outer while, after AFTER loops)
                        body.append(f"{indent}{py_var}.store({py_var}.value + {py_by})")
                    else:
                        # No AFTER — existing single-loop behavior
                        if target_para:
                            target_func = "para_" + to_python_name(target_para)
                            body.append(f"        {target_func}()")
                        else:
                            # Emit inline body statements absorbed from the PV's line range
                            _pv_body = stmt.get("inline_body_stmts", [])
                            if _pv_body:
                                for _bln, _btype, _bdata in _pv_body:
                                    if _btype == "condition":
                                        _bcode, _biss = parse_if_statement(
                                            _bdata, known_vars, level_88_map, analysis["conditions"],
                                            string_vars=string_vars,
                                            all_evaluates=analysis.get("evaluates", []),
                                            all_strings=analysis.get("strings", []),
                                        )
                                        all_issues.extend(_biss)
                                        for _bl in _bcode.split("\n"):
                                            body.append(f"        {_bl}")
                                        if not any(i["status"] == "fail" for i in _biss):
                                            emit_counts["condition"] += 1
                                    elif _btype == "move":
                                        # Simple MOVE inside PV body
                                        _mfrom = _bdata["from"]
                                        _mto_list = _bdata["to"]
                                        _mpy_from = _resolve_value(_mfrom, known_vars, string_vars=string_vars, use_value=True)
                                        for _mt in _mto_list:
                                            _mt_name = _mt.upper().rstrip('.')
                                            _mt_py = to_python_name(_mt_name)
                                            _mt_info = var_info.get(_mt_name)
                                            if _mt_info and _mt_info["is_string"]:
                                                body.append(f"        {_mt_py} = str({_mpy_from})")
                                            elif _mt_info:
                                                body.append(f"        {_mt_py}.store({_mpy_from})")
                                            else:
                                                body.append(f"        {_mt_py} = {_mpy_from}")
                                        emit_counts["move"] += 1
                                    elif _btype == "inspect":
                                        # INSPECT TALLYING FOR ALL inside PV body
                                        _ins = _bdata
                                        _ins_type = _ins.get("type", "")
                                        _ins_src = to_python_name(_ins.get("source", ""))
                                        if _ins_type == "TALLYING" and _ins.get("tallying_for_all"):
                                            _tgt = to_python_name(_ins.get("tallying_target", ""))
                                            _pattern = _ins.get("tallying_for_all", "")
                                            if _ins_src and _tgt:
                                                _src_expr = f"str({_ins_src})" if _ins_src not in string_vars else _ins_src
                                                body.append(f"        {_tgt}.store(Decimal(str({_src_expr}.count({repr(_pattern)}))))")
                                        else:
                                            body.append(f"        pass  # INSPECT {_ins_type} (inline PV)")
                                    elif _btype == "arithmetic":
                                        _arith_py = parse_arithmetic(
                                            _bdata["verb"], _bdata["statement"], known_vars,
                                            string_vars=string_vars, var_info=var_info,
                                        )
                                        if _arith_py:
                                            for _al in _arith_py.split("\n"):
                                                body.append(f"        {_al}")
                                            emit_counts["arithmetic"] += 1
                                        else:
                                            body.append(f"        pass  # inline PV: {_bdata['verb']} (unparsed)")
                                    elif _btype == "display":
                                        _disp_text = _bdata.get("text", "")
                                        body.append(f"        print({repr(_disp_text)})")
                                    elif _btype == "compute":
                                        _cpy = parse_compute(_bdata["statement"], known_vars, string_vars=string_vars)
                                        if _cpy:
                                            for _cl in _cpy.split("\n"):
                                                body.append(f"        {_cl}")
                                            emit_counts["compute"] += 1
                                        else:
                                            body.append(f"        pass  # inline PV: COMPUTE (unparsed)")
                                    else:
                                        body.append(f"        pass  # inline PV body: {_btype}")
                            else:
                                body.append(f"        pass  # inline PERFORM VARYING body")
                        if is_test_after:
                            body.append(f"        if {py_until}:")
                            body.append(f"            break")
                        body.append(f"        {py_var}.store({py_var}.value + {py_by})")

                    cobol_repr = f"PERFORM VARYING {varying_var}"[:45]
                    validation_entries.append((cobol_repr, f"while not ({py_until})"[:45], "[OK]  "))
                    emit_counts["perform"] += 1

                elif stmt_type == "perform_thru":
                    # PERFORM A THRU B — call all paragraphs from A to B in source order
                    # Uses loop + _thru_goto flag so GO TO within the range can skip paragraphs
                    start_name = stmt["to"]
                    end_name = stmt["thru_end"]
                    para_order = analysis.get("paragraphs", [])
                    try:
                        si = para_order.index(start_name)
                        ei = para_order.index(end_name)
                        thru_range = para_order[si:ei + 1]
                    except ValueError:
                        thru_range = [start_name, end_name]
                    pairs = ", ".join(
                        f"('{tp}', para_{to_python_name(tp)})" for tp in thru_range
                    )
                    body.append(f"    _thru_goto = None")
                    body.append(f"    for _tn, _tf in [{pairs}]:")
                    body.append(f"        if _thru_goto is not None:")
                    body.append(f"            if _tn == _thru_goto:")
                    body.append(f"                _thru_goto = None")
                    body.append(f"            else:")
                    body.append(f"                continue")
                    body.append(f"        _tf()")
                    body.append(f"    _thru_goto = None")
                    cobol_repr = f"PERFORM {start_name} THRU {end_name}"[:45]
                    validation_entries.append((cobol_repr, f"{len(thru_range)} paragraph calls"[:45], "[OK]  "))
                    emit_counts["perform"] += 1

                elif stmt_type == "goto":
                    if stmt.get("depending_on"):
                        dep_var = stmt["depending_on"]
                        py_dep = to_python_name(dep_var)
                        targets = stmt.get("targets", [])
                        for i, tgt in enumerate(targets, start=1):
                            tgt_func = "para_" + to_python_name(tgt)
                            keyword = "if" if i == 1 else "elif"
                            body.append(f"    {keyword} int({py_dep}.value) == {i}:")
                            body.append(f"        {tgt_func}()  # GO TO {tgt}")
                            body.append(f"        return")
                        cobol_repr = f"GO TO ... DEPENDING ON {dep_var}"[:45]
                        py_repr = f"if/elif on {py_dep}.value"[:45]
                        validation_entries.append((cobol_repr, py_repr, "[OK]  "))
                        emit_counts["goto"] += 1
                    elif para in _thru_para_set:
                        # GO TO inside THRU range — use flag-based jump
                        target = stmt["targets"][0]
                        body.append(f"    _thru_goto = '{target}'")
                        _thru_upper = {p.upper() for p in _thru_para_set}
                        if target.upper() not in _thru_upper:
                            tf = "para_" + to_python_name(target)
                            body.append(f"    {tf}()  # GO TO {target} (outside THRU range)")
                        body.append(f"    return")
                        target_func = "para_" + to_python_name(target)
                        validation_entries.append((f"GO TO {target}"[:45], f"_thru_goto='{target}'"[:45], "[OK]  "))
                        emit_counts["goto"] += 1
                    else:
                        target = stmt["targets"][0]
                        code, _ = emit_goto(target, indent="    ")
                        for line in code.split("\n"):
                            body.append(line)
                        target_func = "para_" + to_python_name(target)
                        validation_entries.append((f"GO TO {target}"[:45], f"{target_func}(); return"[:45], "[OK]  "))
                        emit_counts["goto"] += 1

                elif stmt_type == "stop":
                    code, _ = emit_stop_run(indent="    ")
                    body.append(code)
                    validation_entries.append(("STOP RUN", "return", "[OK]  "))
                    emit_counts["stop"] += 1

                elif stmt_type == "exit_program":
                    code, _ = emit_exit_program(indent="    ")
                    body.append(code)
                    validation_entries.append(("EXIT PROGRAM", "return", "[OK]  "))
                    emit_counts["stop"] += 1

                elif stmt_type == "goback":
                    code, _ = emit_goback(indent="    ")
                    body.append(code)
                    validation_entries.append(("GOBACK", "return", "[OK]  "))
                    emit_counts["stop"] += 1

                elif stmt_type == "alter":
                    src = stmt.get("source_paragraph", "?")
                    tgt = stmt.get("target_paragraph", "?")
                    body.append(f"    # MANUAL REVIEW: ALTER {src} TO PROCEED TO {tgt}")
                    validation_entries.append((f"ALTER {src}"[:45], "# MANUAL REVIEW", "[FAIL]"))
                    fail_count += 1

                elif stmt_type == "evaluate":
                    py_code, eval_issues = parse_evaluate_statement(
                        stmt, known_vars, level_88_map, analysis["conditions"],
                        string_vars=string_vars,
                        all_evaluates_by_text=_all_evaluates_by_text,
                        all_strings_by_text=_all_strings_by_text,
                    )
                    all_issues.extend(eval_issues)

                    has_fails = any(i["status"] == "fail" for i in eval_issues)
                    has_warns = any(i["status"] == "warn" for i in eval_issues)
                    if has_fails:
                        fail_count += 1
                        status_char = "[FAIL]"
                    elif has_warns:
                        status_char = "[WARN]"
                    else:
                        status_char = "[OK]  "

                    cobol_repr = f"EVALUATE {stmt['subject']}"[:45]
                    py_repr = (py_code.split("\n")[0] if py_code else "# MANUAL REVIEW")[:45]
                    validation_entries.append((cobol_repr, py_repr, status_char))

                    if not has_fails:
                        emit_counts["evaluate"] += 1

                    for line in py_code.split("\n"):
                        body.append(f"    {line}")

                elif stmt_type == "arithmetic" and stmt["verb"] in ("ADD", "SUBTRACT") and "CORRESPONDING" in stmt["statement"].upper():
                    # ADD/SUBTRACT CORRESPONDING — match numeric fields by name
                    _arith_verb = stmt["verb"]
                    _arith_op = "+" if _arith_verb == "ADD" else "-"
                    _text = stmt["statement"].upper()
                    _corr_match = re.match(r"(ADD|SUBTRACT)\s+CORR(?:ESPONDING)?\s+(\S+)\s+(?:TO|FROM)\s+(\S+)", _text, re.IGNORECASE)
                    if _corr_match:
                        _src_grp = _corr_match.group(2).upper().rstrip('.')
                        _tgt_grp = _corr_match.group(3).upper().rstrip('.')
                        _src_ch = group_children.get(_src_grp)
                        _tgt_ch = group_children.get(_tgt_grp)
                        if _src_ch and _tgt_ch:
                            _tgt_set = set(_tgt_ch)
                            _matching = [c for c in _src_ch if c in _tgt_set]
                            body.append(f"    # {_arith_verb} CORRESPONDING {_src_grp} TO {_tgt_grp} ({len(_matching)} fields)")
                            for _fn in _matching:
                                _fi = var_info.get(_fn)
                                if _fi and not _fi["is_string"]:
                                    _pn = _fi["python_name"]
                                    # Both groups share field name — same Python var
                                    body.append(f"    {_pn}.store({_pn}.value {_arith_op} {_pn}.value)")
                            compiler_warnings.append(
                                f"{_arith_verb} CORRESPONDING: ON SIZE ERROR not checked per-field."
                            )
                            cobol_repr = f"{_arith_verb} CORR {_src_grp} TO {_tgt_grp}"[:45]
                            validation_entries.append((cobol_repr, f"{len(_matching)} fields", "[OK]  "))
                            emit_counts["arithmetic"] += 1
                        else:
                            body.append(f"    # MANUAL REVIEW: {_arith_verb} CORRESPONDING {_src_grp} TO {_tgt_grp} (group not resolved)")
                            body.append(f"    pass")
                            fail_count += 1
                            validation_entries.append((f"{_arith_verb} CORR"[:45], "# MANUAL REVIEW", "[FAIL]"))
                    else:
                        body.append(f"    # MANUAL REVIEW: {stmt['statement'][:55]}")
                        fail_count += 1

                elif stmt_type == "arithmetic":
                    py_stmt = parse_arithmetic(
                        stmt["verb"], stmt["statement"], known_vars, string_vars=string_vars, var_info=var_info
                    )
                    if py_stmt:
                        _first_line = py_stmt.split("\n")[0]
                        _trace_target = None
                        if trace_mode and ".store(" in _first_line:
                            _trace_target = _first_line.split(".store(")[0].strip()
                            body.append(f"    _old_val = str({_trace_target}.value)")
                        for line in py_stmt.split("\n"):
                            body.append(f"    {line}")
                        if trace_mode and _trace_target:
                            body.append(f"    _trace.append({{'line': {_line_num}, 'verb': {repr(stmt['verb'])}, 'variable': {repr(stmt['statement'][:40])}, 'old_value': _old_val, 'new_value': str({_trace_target}.value)}})")
                        cobol_repr = f"{stmt['verb']} ..."[:45]
                        validation_entries.append((cobol_repr, py_stmt.split("\n")[0][:45], "[OK]  "))
                        emit_counts["arithmetic"] += 1
                    else:
                        body.append(f"    # MANUAL REVIEW: {stmt['statement'][:55]}")
                        validation_entries.append((stmt['statement'][:45], "# MANUAL REVIEW", "[FAIL]"))
                        fail_count += 1

                elif stmt_type == "initialize":
                    targets = stmt.get("targets", [])
                    for tgt in targets:
                        tgt_upper = tgt.upper()
                        children = group_children.get(tgt_upper)
                        if children:
                            body.append(f"    # INITIALIZE {tgt}")
                            for child in children:
                                info = var_info.get(child)
                                if info:
                                    code, _ = emit_initialize_single(child, info["is_string"], indent="    ")
                                    body.append(code)
                        elif tgt_upper in var_info:
                            info = var_info[tgt_upper]
                            code, _ = emit_initialize_single(tgt, info["is_string"], indent="    ")
                            body.append(code)
                        else:
                            body.append(f"    # MANUAL REVIEW: INITIALIZE {tgt} (unknown variable)")
                            body.append(f"    pass")
                            fail_count += 1
                            validation_entries.append((f"INITIALIZE {tgt}"[:45], "# MANUAL REVIEW", "[FAIL]"))
                            continue
                        cobol_repr = f"INITIALIZE {tgt}"[:45]
                        validation_entries.append((cobol_repr, f"reset {to_python_name(tgt)}"[:45], "[OK]  "))
                    emit_counts["initialize"] += 1

                elif stmt_type == "set_true":
                    # SET condition-name TO TRUE → assign first value of 88-level to parent
                    cond_name = stmt.get("condition_name", "")
                    # Strip subscript: WS-CHK-PASS(1) → WS-CHK-PASS, subscript = "1"
                    set_subscript = None
                    if "(" in cond_name:
                        base, sub = cond_name.split("(", 1)
                        set_subscript = sub.rstrip(")")
                        cond_name = base
                    code, _ = emit_set_true(cond_name, level_88_map, string_vars, indent="    ", subscript=set_subscript)
                    if code:
                        body.append(code)
                        py_parent = to_python_name(level_88_map[cond_name]["parent"])
                        first_val = (level_88_map[cond_name].get("values") or [level_88_map[cond_name]["value"]])[0]
                        cobol_repr = f"SET {cond_name} TO TRUE"[:45]
                        validation_entries.append((cobol_repr, f"{py_parent} = {first_val}"[:45], "[OK]  "))
                        emit_counts.setdefault("set", 0)
                        emit_counts["set"] += 1
                    else:
                        body.append(f"    # MANUAL REVIEW: SET {cond_name} TO TRUE — 88-level not found")
                        validation_entries.append((f"SET {cond_name} TO TRUE"[:45], "# MANUAL REVIEW", "[FAIL]"))
                        fail_count += 1

                elif stmt_type == "display":
                    operands = stmt.get("operands", [])
                    _edited_vars = {name for name, info in var_info.items() if info.get("is_edited")}
                    code, _ = emit_display(operands, known_vars, string_vars, indent="    ", edited_vars=_edited_vars)
                    body.append(code)
                    cobol_repr = f"DISPLAY {' '.join(operands)}"[:45]
                    validation_entries.append((cobol_repr, "print(...)"[:45], "[OK]  "))
                    emit_counts["display"] += 1

                elif stmt_type == "accept":
                    target_cobol = stmt["target"]
                    target_py = to_python_name(target_cobol)
                    accept_type = stmt["type"]
                    is_string = target_cobol.upper() in {v.upper() for v in string_vars}
                    code, _ = emit_accept(target_py, accept_type, is_string, indent="    ")
                    body.append(code)
                    cobol_repr = f"ACCEPT {target_cobol} FROM {accept_type}"[:45]
                    validation_entries.append((cobol_repr, f"{target_py} = ..."[:45], "[OK]  "))
                    emit_counts["accept"] = emit_counts.get("accept", 0) + 1

                elif stmt_type == "string":
                    # STRING — concatenation with optional POINTER and delimiter handling
                    has_pointer = stmt.get("has_pointer", False)
                    has_overflow = stmt.get("has_overflow", False)
                    sources = stmt.get("sources", [])
                    target = stmt.get("target")

                    py_target = to_python_name(target)
                    # Build sender expressions with delimiter handling
                    sender_exprs = []
                    for s in sources:
                        for sender in s.get("senders", []):
                            py_sender = to_python_name(sender)
                            if s.get("delimited_by_size"):
                                sender_exprs.append(f"str({py_sender})")
                            else:
                                delim = s.get("delimiter")
                                if delim and delim.upper() in ("SPACES", "SPACE"):
                                    sender_exprs.append(f"str({py_sender}).split(' ', 1)[0]")
                                elif delim and delim.startswith("'") and delim.endswith("'"):
                                    sender_exprs.append(f"str({py_sender}).split({delim}, 1)[0]")
                                elif delim:
                                    py_delim = to_python_name(delim)
                                    sender_exprs.append(f"str({py_sender}).split(str({py_delim}), 1)[0]")
                                else:
                                    sender_exprs.append(f"str({py_sender})")

                    concat_expr = " + ".join(sender_exprs)

                    if has_pointer:
                        ptr_var = stmt.get("pointer_var")
                        py_ptr = to_python_name(ptr_var)
                        body.append(f"    _concat = {concat_expr}")
                        body.append(f"    _pos = int({py_ptr}.value) - 1")
                        body.append(f"    {py_target} = str({py_target})[:_pos] + _concat + str({py_target})[_pos + len(_concat):]")
                        body.append(f"    {py_ptr}.store(Decimal(str(_pos + 1 + len(_concat))))")
                    else:
                        body.append(f"    {py_target} = {concat_expr}")

                    if has_overflow:
                        overflow_stmts = stmt.get("on_overflow", [])
                        not_overflow_stmts = stmt.get("not_on_overflow", [])
                        if overflow_stmts:
                            body.append(f"    # ON OVERFLOW")
                            for ovf_stmt in overflow_stmts:
                                ovf_lines = _parse_ose_handler(ovf_stmt, known_vars, string_vars)
                                if ovf_lines:
                                    for ln in ovf_lines:
                                        body.append(f"    {ln}")
                                else:
                                    body.append(f"    # MANUAL REVIEW: OVERFLOW body: {ovf_stmt[:60]}")
                                    fail_count += 1
                        if not_overflow_stmts:
                            body.append(f"    # NOT ON OVERFLOW")
                            for novf_stmt in not_overflow_stmts:
                                novf_lines = _parse_ose_handler(novf_stmt, known_vars, string_vars)
                                if novf_lines:
                                    for ln in novf_lines:
                                        body.append(f"    {ln}")
                                else:
                                    body.append(f"    # MANUAL REVIEW: NOT ON OVERFLOW body: {novf_stmt[:60]}")
                                    fail_count += 1

                    cobol_repr = f"STRING ... INTO {target}"[:45]
                    py_repr = f"{py_target} = ..."[:45]
                    validation_entries.append((cobol_repr, py_repr, "[OK]  "))

                elif stmt_type == "unstring":
                    # UNSTRING — full implementation with OR/POINTER/TALLYING/DELIMITER-IN/COUNT-IN
                    source = stmt.get("source")
                    delimiter = stmt.get("delimiter")
                    targets = stmt.get("targets", [])
                    has_or = stmt.get("has_or", False)
                    or_delimiters = stmt.get("or_delimiters", [])
                    has_pointer = stmt.get("has_pointer", False)
                    pointer_var = stmt.get("pointer_var")
                    has_tallying = stmt.get("has_tallying", False)
                    tallying_var = stmt.get("tallying_var")
                    has_overflow = stmt.get("has_overflow", False)
                    has_complex = any(t.get("has_delimiter_in") or t.get("has_count_in") for t in targets)

                    py_source = to_python_name(source) if source else "unknown"

                    # Determine if we need capture group split (for DELIMITER IN)
                    _capture_split = has_complex and (has_or or any(t.get("has_delimiter_in") for t in targets))

                    # Build delimiter pattern and split
                    if has_or and or_delimiters:
                        all_delims = [delimiter] + or_delimiters if delimiter else or_delimiters
                        escaped = [re.escape(d.strip("'\"")) for d in all_delims]
                        pattern = "|".join(escaped)
                        body.append(f"    import re")
                        if _capture_split:
                            body.append(f"    _unstring_parts = re.split({repr('(' + pattern + ')')}, str({py_source}))")
                        else:
                            body.append(f"    _unstring_parts = re.split({repr(pattern)}, str({py_source}))")
                    else:
                        delim_str = delimiter.strip("'\"") if delimiter else ","
                        if _capture_split:
                            body.append(f"    import re")
                            body.append(f"    _unstring_parts = re.split({repr('(' + re.escape(delim_str) + ')')}, str({py_source}))")
                        else:
                            body.append(f"    _unstring_parts = str({py_source}).split({repr(delim_str)})")

                    # Distribute to targets
                    step = 2 if _capture_split else 1
                    for idx, tgt in enumerate(targets):
                        tgt_name = tgt.get("name")
                        if tgt_name:
                            py_tgt = to_python_name(tgt_name)
                            part_idx = idx * step
                            body.append(f"    {py_tgt} = _unstring_parts[{part_idx}] if {part_idx} < len(_unstring_parts) else ''")
                            if tgt.get("delimiter_in_var"):
                                py_di = to_python_name(tgt["delimiter_in_var"])
                                di_idx = idx * 2 + 1
                                body.append(f"    {py_di} = _unstring_parts[{di_idx}] if {di_idx} < len(_unstring_parts) else ''")
                            if tgt.get("count_in_var"):
                                py_ci = to_python_name(tgt["count_in_var"])
                                body.append(f"    {py_ci}.store(Decimal(str(len({py_tgt}))))")

                    # POINTER: advance by chars consumed
                    if has_pointer and pointer_var:
                        py_ptr = to_python_name(pointer_var)
                        n_targets = len(targets)
                        if _capture_split:
                            limit = n_targets * 2 - 1
                            body.append(f"    _consumed = sum(len(str(p)) for p in _unstring_parts[:min({limit}, len(_unstring_parts))])")
                        else:
                            body.append(f"    _consumed = sum(len(str(p)) for p in _unstring_parts[:min({n_targets}, len(_unstring_parts))]) + {n_targets - 1}")
                        body.append(f"    {py_ptr}.store(Decimal(str(int({py_ptr}.value) + _consumed)))")
                        body.append(f"    # TODO: POINTER advancement is best-effort — may differ for edge cases")

                    # TALLYING: count filled fields
                    if has_tallying and tallying_var:
                        py_tally = to_python_name(tallying_var)
                        n_targets = len(targets)
                        if _capture_split:
                            body.append(f"    {py_tally}.store(Decimal(str(min((len(_unstring_parts) + 1) // 2, {n_targets}))))")
                        else:
                            body.append(f"    {py_tally}.store(Decimal(str(min(len(_unstring_parts), {n_targets}))))")

                    # ON OVERFLOW / NOT ON OVERFLOW body
                    if has_overflow:
                        u_overflow_stmts = stmt.get("on_overflow", [])
                        u_not_overflow_stmts = stmt.get("not_on_overflow", [])
                        if u_overflow_stmts:
                            body.append(f"    # ON OVERFLOW")
                            for ovf_stmt in u_overflow_stmts:
                                ovf_lines = _parse_ose_handler(ovf_stmt, known_vars, string_vars)
                                if ovf_lines:
                                    for ln in ovf_lines:
                                        body.append(f"    {ln}")
                                else:
                                    body.append(f"    # MANUAL REVIEW: OVERFLOW body: {ovf_stmt[:60]}")
                                    fail_count += 1
                        if u_not_overflow_stmts:
                            body.append(f"    # NOT ON OVERFLOW")
                            for novf_stmt in u_not_overflow_stmts:
                                novf_lines = _parse_ose_handler(novf_stmt, known_vars, string_vars)
                                if novf_lines:
                                    for ln in novf_lines:
                                        body.append(f"    {ln}")
                                else:
                                    body.append(f"    # MANUAL REVIEW: NOT ON OVERFLOW body: {novf_stmt[:60]}")
                                    fail_count += 1

                    cobol_repr = f"UNSTRING {source}"[:45]
                    validation_entries.append((cobol_repr, f"_unstring_parts = re.split/split(...)"[:45], "[OK]  "))

                elif stmt_type == "inspect":
                    variant = stmt.get("variant")
                    field = stmt.get("field")
                    py_field = to_python_name(field) if field else "unknown"
                    stmt_text = stmt.get("statement", "")

                    def _parse_inspect_ba(txt):
                        """Parse BEFORE/AFTER INITIAL from getText() blob (no spaces)."""
                        upper = txt.upper()
                        m = re.search(r"BEFOREINITIAL(['\"][^'\"]+['\"])", upper)
                        if m:
                            s = m.start(1)
                            return ("BEFORE", txt[s:s+len(m.group(1))])
                        m = re.search(r"AFTERINITIAL(['\"][^'\"]+['\"])", upper)
                        if m:
                            s = m.start(1)
                            return ("AFTER", txt[s:s+len(m.group(1))])
                        return None

                    def _strip_quotes(lit):
                        """Strip surrounding quotes from a literal."""
                        if lit and len(lit) >= 2 and lit[0] in ("'", '"') and lit[-1] in ("'", '"'):
                            return lit[1:-1]
                        return lit

                    def _resolve_figurative(val):
                        """Resolve COBOL figurative constants to Python string literals."""
                        if not val:
                            return val
                        upper = val.upper()
                        if upper in ("SPACES", "SPACE"):
                            return "' '"
                        if upper in ("ZEROS", "ZEROES", "ZERO"):
                            return "'0'"
                        if upper in ("LOW-VALUES", "LOW-VALUE"):
                            return r"'\x00'"
                        if upper in ("HIGH-VALUES", "HIGH-VALUE"):
                            return r"'\xff'"
                        if upper in ("QUOTES", "QUOTE"):
                            return "'\"'"
                        return val  # already a quoted literal or variable

                    def _emit_tallying_one(td, ba_info):
                        """Emit Python for one TALLYING entry. Returns True if emitted, False if MR."""
                        counter = td.get("counter")
                        tally_type = td.get("tally_type")
                        tally_value = _resolve_figurative(td.get("tally_value"))
                        has_chars = td.get("has_characters", False)
                        py_counter = to_python_name(counter) if counter else "unknown"

                        if has_chars:
                            # TALLYING FOR CHARACTERS
                            if ba_info and ba_info[0] == "BEFORE":
                                delim = _strip_quotes(ba_info[1])
                                body.append(f"    _pos = str({py_field}).find('{delim}')")
                                body.append(f"    {py_counter}.store(Decimal(_pos if _pos >= 0 else len(str({py_field}))))")
                            elif ba_info and ba_info[0] == "AFTER":
                                delim = _strip_quotes(ba_info[1])
                                body.append(f"    _pos = str({py_field}).find('{delim}')")
                                body.append(f"    {py_counter}.store(Decimal(len(str({py_field})) - _pos - {len(delim)} if _pos >= 0 else 0))")
                            else:
                                body.append(f"    {py_counter}.store(Decimal(len(str({py_field}))))")
                            return True

                        if tally_type == "ALL" and tally_value:
                            if ba_info and ba_info[0] == "BEFORE":
                                delim = _strip_quotes(ba_info[1])
                                body.append(f"    _pos = str({py_field}).find('{delim}')")
                                body.append(f"    _portion = str({py_field})[:_pos] if _pos >= 0 else str({py_field})")
                                body.append(f"    {py_counter}.store(Decimal(_portion.count({tally_value})))")
                            elif ba_info and ba_info[0] == "AFTER":
                                delim = _strip_quotes(ba_info[1])
                                body.append(f"    _pos = str({py_field}).find('{delim}')")
                                body.append(f"    _portion = str({py_field})[_pos + {len(delim)}:] if _pos >= 0 else ''")
                                body.append(f"    {py_counter}.store(Decimal(_portion.count({tally_value})))")
                            else:
                                body.append(f"    {py_counter}.store(Decimal({py_field}.count({tally_value})))")
                            return True

                        if tally_type == "LEADING" and tally_value:
                            raw_val = _strip_quotes(tally_value)
                            if len(raw_val) > 1:
                                return False  # multi-char LEADING → MR
                            if ba_info and ba_info[0] == "BEFORE":
                                delim = _strip_quotes(ba_info[1])
                                body.append(f"    _pos = str({py_field}).find('{delim}')")
                                body.append(f"    _src = str({py_field})[:_pos] if _pos >= 0 else str({py_field})")
                            else:
                                body.append(f"    _src = str({py_field})")
                            body.append(f"    _cnt = 0")
                            body.append(f"    for _ch in _src:")
                            body.append(f"        if _ch == {tally_value}:")
                            body.append(f"            _cnt += 1")
                            body.append(f"        else:")
                            body.append(f"            break")
                            body.append(f"    {py_counter}.store(Decimal(_cnt))")
                            return True

                        return False  # unhandled variant

                    if variant == "tallying":
                        tallying = stmt.get("tallying", [])
                        ba_info = _parse_inspect_ba(stmt_text)
                        all_ok = True
                        for td in tallying:
                            if not _emit_tallying_one(td, ba_info):
                                ttype = td.get("tally_type") or "CHARACTERS"
                                body.append(f"    # MANUAL REVIEW: INSPECT TALLYING {ttype}")
                                cobol_repr = f"INSPECT {field} TALLYING"[:45]
                                validation_entries.append((cobol_repr, "# MANUAL REVIEW", "[FAIL]"))
                                fail_count += 1
                                all_ok = False
                        if all_ok and tallying:
                            cobol_repr = f"INSPECT {field} TALLYING"[:45]
                            validation_entries.append((cobol_repr, f"tallying {len(tallying)} counter(s)"[:45], "[OK]  "))
                        elif not tallying:
                            body.append(f"    # MANUAL REVIEW: INSPECT TALLYING (empty)")
                            cobol_repr = f"INSPECT {field} TALLYING"[:45]
                            validation_entries.append((cobol_repr, "# MANUAL REVIEW", "[FAIL]"))
                            fail_count += 1

                    elif variant == "replacing":
                        replacing = stmt.get("replacing", {})
                        replacements = replacing.get("replacements", [])
                        has_chars = replacing.get("has_characters", False)
                        ba_info = _parse_inspect_ba(stmt_text)

                        if has_chars:
                            # REPLACING CHARACTERS BY 'X' — parse BY value from getText()
                            m_by = re.search(r"CHARACTERSBY(['\"][^'\"]+['\"])", stmt_text.upper())
                            if m_by:
                                s = m_by.start(1)
                                by_val = stmt_text[s:s+len(m_by.group(1))]
                                raw_by = _strip_quotes(by_val)
                                if ba_info and ba_info[0] == "BEFORE":
                                    delim = _strip_quotes(ba_info[1])
                                    body.append(f"    _pos = str({py_field}).find('{delim}')")
                                    body.append(f"    {py_field} = '{raw_by}' * (max(_pos, 0)) + str({py_field})[max(_pos, 0):]")
                                elif ba_info and ba_info[0] == "AFTER":
                                    delim = _strip_quotes(ba_info[1])
                                    body.append(f"    _pos = str({py_field}).find('{delim}')")
                                    body.append(f"    if _pos >= 0:")
                                    body.append(f"        {py_field} = str({py_field})[:_pos + {len(delim)}] + '{raw_by}' * (len(str({py_field})) - _pos - {len(delim)})")
                                else:
                                    body.append(f"    {py_field} = '{raw_by}' * len(str({py_field}))")
                                cobol_repr = f"INSPECT {field} REPLACING CHARACTERS"[:45]
                                validation_entries.append((cobol_repr, f"{py_field} = ..."[:45], "[OK]  "))
                            else:
                                body.append(f"    # MANUAL REVIEW: INSPECT REPLACING CHARACTERS (unparseable)")
                                cobol_repr = f"INSPECT {field} REPLACING"[:45]
                                validation_entries.append((cobol_repr, "# MANUAL REVIEW", "[FAIL]"))
                                fail_count += 1
                        else:
                            all_ok = True
                            for rep in replacements:
                                rep_type = rep.get("type")
                                from_val = rep.get("from")
                                to_val = rep.get("to")
                                has_ba = rep.get("has_before_after", False)
                                rep_ba = ba_info if has_ba else None

                                if rep_type == "ALL" and from_val and to_val and not rep_ba:
                                    body.append(f"    {py_field} = {py_field}.replace({from_val}, {to_val})")
                                elif rep_type == "ALL" and from_val and to_val and rep_ba:
                                    delim = _strip_quotes(rep_ba[1])
                                    if rep_ba[0] == "BEFORE":
                                        body.append(f"    _pos = str({py_field}).find('{delim}')")
                                        body.append(f"    if _pos >= 0:")
                                        body.append(f"        {py_field} = str({py_field})[:_pos].replace({from_val}, {to_val}) + str({py_field})[_pos:]")
                                        body.append(f"    else:")
                                        body.append(f"        {py_field} = {py_field}.replace({from_val}, {to_val})")
                                    else:
                                        body.append(f"    _pos = str({py_field}).find('{delim}')")
                                        body.append(f"    if _pos >= 0:")
                                        body.append(f"        {py_field} = str({py_field})[:_pos + {len(delim)}] + str({py_field})[_pos + {len(delim)}:].replace({from_val}, {to_val})")
                                elif rep_type == "FIRST" and from_val and to_val and not rep_ba:
                                    body.append(f"    {py_field} = {py_field}.replace({from_val}, {to_val}, 1)")
                                elif rep_type == "FIRST" and from_val and to_val and rep_ba:
                                    delim = _strip_quotes(rep_ba[1])
                                    if rep_ba[0] == "BEFORE":
                                        body.append(f"    _pos = str({py_field}).find('{delim}')")
                                        body.append(f"    if _pos >= 0:")
                                        body.append(f"        {py_field} = str({py_field})[:_pos].replace({from_val}, {to_val}, 1) + str({py_field})[_pos:]")
                                        body.append(f"    else:")
                                        body.append(f"        {py_field} = {py_field}.replace({from_val}, {to_val}, 1)")
                                    else:
                                        body.append(f"    _pos = str({py_field}).find('{delim}')")
                                        body.append(f"    if _pos >= 0:")
                                        body.append(f"        {py_field} = str({py_field})[:_pos + {len(delim)}] + str({py_field})[_pos + {len(delim)}:].replace({from_val}, {to_val}, 1)")
                                elif rep_type == "LEADING" and from_val and to_val and not rep_ba:
                                    raw_from = _strip_quotes(from_val)
                                    raw_to = _strip_quotes(to_val)
                                    # Same-length check: COBOL requires REPLACING operands
                                    # to be same length to preserve byte positions
                                    if len(raw_from) != len(raw_to):
                                        body.append(f"    # MANUAL REVIEW: INSPECT REPLACING LEADING with unequal from/to lengths")
                                        cobol_repr = f"INSPECT {field} REPLACING"[:45]
                                        validation_entries.append((cobol_repr, "# MANUAL REVIEW (unequal lengths)", "[FAIL]"))
                                        fail_count += 1
                                        all_ok = False
                                        continue
                                    if len(raw_from) > 1:
                                        # Multi-char LEADING: replace leading chunks
                                        chunk_len = len(raw_from)
                                        body.append(f"    _s = str({py_field})")
                                        body.append(f"    _i = 0")
                                        body.append(f"    while _s[_i:_i+{chunk_len}] == {from_val}:")
                                        body.append(f"        _i += {chunk_len}")
                                        body.append(f"    {py_field} = {to_val} * (_i // {chunk_len}) + _s[_i:]")
                                    else:
                                        # Single-char LEADING: char-by-char loop
                                        body.append(f"    _result = list(str({py_field}))")
                                        body.append(f"    for _i, _ch in enumerate(_result):")
                                        body.append(f"        if _ch == {from_val}:")
                                        body.append(f"            _result[_i] = {to_val}")
                                        body.append(f"        else:")
                                        body.append(f"            break")
                                        body.append(f"    {py_field} = ''.join(_result)")
                                else:
                                    body.append(f"    # MANUAL REVIEW: INSPECT REPLACING {rep_type}")
                                    cobol_repr = f"INSPECT {field} REPLACING"[:45]
                                    validation_entries.append((cobol_repr, "# MANUAL REVIEW", "[FAIL]"))
                                    fail_count += 1
                                    all_ok = False
                                    continue

                            if all_ok and replacements:
                                cobol_repr = f"INSPECT {field} REPLACING"[:45]
                                validation_entries.append((cobol_repr, f"{py_field} = ..."[:45], "[OK]  "))
                            elif not replacements and not has_chars:
                                body.append(f"    # MANUAL REVIEW: INSPECT REPLACING (empty)")
                                cobol_repr = f"INSPECT {field} REPLACING"[:45]
                                validation_entries.append((cobol_repr, "# MANUAL REVIEW", "[FAIL]"))
                                fail_count += 1

                    elif variant == "converting":
                        # INSPECT X CONVERTING 'from' TO 'to' → str.maketrans + translate
                        stmt_text = stmt.get("statement", "")
                        # Parse FROM/TO from getText() blob: INSPECT<field>CONVERTING<from>TO<to>
                        conv_match = re.search(
                            r"CONVERTING(.+?)TO(.+)$",
                            stmt_text.upper(),
                        )
                        if conv_match:
                            raw_from = conv_match.group(1).strip()
                            raw_to = conv_match.group(2).strip()

                            def _resolve_converting_arg(raw):
                                """Resolve a CONVERTING arg to a Python expression."""
                                if raw.startswith("'") and raw.endswith("'"):
                                    return raw  # already a quoted literal
                                elif raw in ("SPACES", "SPACE"):
                                    return "' '"
                                elif raw in ("ZEROS", "ZEROES", "ZERO"):
                                    return "'0'"
                                elif raw in ("LOW-VALUES", "LOW-VALUE"):
                                    return r"'\x00'"
                                elif raw in ("HIGH-VALUES", "HIGH-VALUE"):
                                    return r"'\xff'"
                                elif raw in ("QUOTES", "QUOTE"):
                                    return "'\"'"
                                else:
                                    # Variable reference — use original case from stmt
                                    idx = stmt_text.upper().index(raw)
                                    orig = stmt_text[idx:idx+len(raw)]
                                    py_var = to_python_name(orig)
                                    return f"str({py_var})"

                            # Parse BEFORE/AFTER INITIAL from raw_to
                            ba_conv = re.search(
                                r"(BEFORE|AFTER)\s*(?:INITIAL)?\s*(.+)$",
                                raw_to, re.IGNORECASE,
                            )
                            if ba_conv:
                                raw_to = raw_to[:ba_conv.start()].strip()
                                ba_mode = ba_conv.group(1).upper()
                                ba_delim = _resolve_converting_arg(ba_conv.group(2).strip())

                            py_from = _resolve_converting_arg(raw_from)
                            py_to = _resolve_converting_arg(raw_to)

                            # Length guard: maketrans requires equal-length strings
                            # Strip only outer wrapping quotes (not inner content)
                            from_literal = py_from[1:-1] if len(py_from) >= 2 and py_from[0] in "'\"\\" else py_from
                            to_literal = py_to[1:-1] if len(py_to) >= 2 and py_to[0] in "'\"\\" else py_to
                            if not py_from.startswith("str(") and not py_to.startswith("str(") and len(from_literal) != len(to_literal):
                                body.append(f"    # MANUAL REVIEW: INSPECT CONVERTING with unequal from/to lengths")
                                cobol_repr = f"INSPECT {field} CONVERTING"[:45]
                                validation_entries.append((cobol_repr, "# MANUAL REVIEW (unequal lengths)", "[FAIL]"))
                                fail_count += 1
                            elif ba_conv:
                                if ba_mode == "BEFORE":
                                    body.append(f"    _pos = str({py_field}).find({ba_delim})")
                                    body.append(f"    _tbl = str.maketrans({py_from}, {py_to})")
                                    body.append(f"    if _pos >= 0:")
                                    body.append(f"        {py_field} = str({py_field})[:_pos].translate(_tbl) + str({py_field})[_pos:]")
                                    body.append(f"    else:")
                                    body.append(f"        {py_field} = str({py_field}).translate(_tbl)")
                                else:  # AFTER
                                    body.append(f"    _pos = str({py_field}).find({ba_delim})")
                                    body.append(f"    _tbl = str.maketrans({py_from}, {py_to})")
                                    body.append(f"    if _pos >= 0:")
                                    body.append(f"        _start = _pos + len({ba_delim})")
                                    body.append(f"        {py_field} = str({py_field})[:_start] + str({py_field})[_start:].translate(_tbl)")
                                cobol_repr = f"INSPECT {field} CONVERTING"[:45]
                                validation_entries.append((cobol_repr, f"{py_field} = ...translate(_tbl)"[:45], "[OK]  "))
                                emit_counts["inspect"] = emit_counts.get("inspect", 0) + 1
                            else:
                                body.append(f"    _tbl = str.maketrans({py_from}, {py_to})")
                                body.append(f"    {py_field} = str({py_field}).translate(_tbl)")
                                cobol_repr = f"INSPECT {field} CONVERTING"[:45]
                                validation_entries.append((cobol_repr, f"{py_field} = ...translate(_tbl)"[:45], "[OK]  "))
                                emit_counts["inspect"] = emit_counts.get("inspect", 0) + 1
                        else:
                            body.append(f"    # MANUAL REVIEW: INSPECT CONVERTING (unparseable)")
                            cobol_repr = f"INSPECT {field} CONVERTING"[:45]
                            validation_entries.append((cobol_repr, "# MANUAL REVIEW", "[FAIL]"))
                            fail_count += 1

                    else:
                        # tallying_replacing or unknown
                        body.append(f"    # MANUAL REVIEW: INSPECT {variant.upper() if variant else 'UNKNOWN'}")
                        cobol_repr = f"INSPECT {field}"[:45]
                        validation_entries.append((cobol_repr, "# MANUAL REVIEW", "[FAIL]"))
                        fail_count += 1

                elif stmt_type == "perform_until":
                    # PERFORM para UNTIL cond — while loop
                    until_cond = stmt.get("until", "")
                    target_para = stmt.get("target")

                    # Parse UNTIL condition using _convert_condition (supports AND/OR)
                    py_until, _until_issues = _convert_condition(
                        until_cond, known_vars, level_88_map, string_vars=string_vars
                    )

                    body.append(f"    while not ({py_until}):")
                    if target_para:
                        target_func = "para_" + to_python_name(target_para)
                        body.append(f"        {target_func}()")
                    else:
                        body.append(f"        pass  # inline PERFORM UNTIL body")

                    cobol_repr = f"PERFORM UNTIL {until_cond}"[:45]
                    validation_entries.append((cobol_repr, f"while not ({py_until})"[:45], "[OK]  "))
                    emit_counts["perform"] += 1

                # ── CALL / CANCEL ────────────────────────────────
                elif stmt_type == "call":
                    target = stmt.get("target", "?")
                    is_dynamic = stmt.get("is_dynamic", False)
                    params = stmt.get("using_params", [])
                    if is_dynamic:
                        body.append(f"    # MANUAL REVIEW: CALL {target} — dynamic subprogram not analyzed")
                    else:
                        body.append(f"    # MANUAL REVIEW: CALL '{target}' — subprogram not analyzed")
                    body.append(f"    pass")
                    if params:
                        param_names = ", ".join(p.get("name", "?") for p in params)
                        body.append(f"    # USING: {param_names}")
                    cobol_repr = f"CALL {target}"[:45]
                    validation_entries.append((cobol_repr, "# MANUAL REVIEW", "[FAIL]"))
                    fail_count += 1

                elif stmt_type == "cancel":
                    targets = stmt.get("targets", [])
                    target_str = ", ".join(targets) if targets else "?"
                    body.append(f"    # MANUAL REVIEW: CANCEL {target_str} — subprogram state not tracked")
                    body.append(f"    pass")
                    cobol_repr = f"CANCEL {target_str}"[:45]
                    validation_entries.append((cobol_repr, "# MANUAL REVIEW", "[FAIL]"))
                    fail_count += 1

                # ── FILE I/O ──────────────────────────────────────
                elif stmt_type == "file_open":
                    file_name = stmt.get("file_name", "")
                    direction = stmt.get("direction", "INPUT")
                    if direction == "IO":
                        mode = "rw"
                    elif direction == "INPUT":
                        mode = "r"
                    else:
                        mode = "w"
                    body.append(f"    _io_open('{file_name}', '{mode}')")
                    cobol_repr = f"OPEN {direction} {file_name}"[:45]
                    validation_entries.append((cobol_repr, f"_io_open('{file_name}', '{mode}')"[:45], "[OK]  "))
                    emit_counts["io"] += 1

                elif stmt_type == "file_read":
                    file_name = stmt.get("file_name", "")
                    into = stmt.get("into")
                    at_end = stmt.get("at_end", [])
                    not_at_end = stmt.get("not_at_end", [])
                    key_field = stmt.get("key_field")

                    if key_field:
                        py_key = to_python_name(key_field)
                        key_info = var_info.get(key_field.upper())
                        if key_info and not key_info.get("is_string"):
                            key_val_expr = f"str({py_key}.value)"
                        else:
                            key_val_expr = f"str({py_key})"
                        body.append(f"    _record = _io_read_by_key('{file_name}', '{key_field}', {key_val_expr})")
                    else:
                        body.append(f"    _record = _io_read('{file_name}')")

                    if at_end or not_at_end:
                        body.append(f"    if _record is None:")
                        # AT END branch
                        if at_end:
                            _emitted_at_end = False
                            for ae_text in at_end:
                                ae_upper = ae_text.upper()
                                # Pattern: MOVE literal TO variable
                                move_match = re.match(r"MOVE['\"]?([^'\"]+)['\"]?TO([A-Z0-9\-]+)", ae_upper.replace(" ", ""))
                                if move_match:
                                    val = move_match.group(1).strip()
                                    target = move_match.group(2).strip()
                                    py_target = to_python_name(target)
                                    target_info = var_info.get(target)
                                    if target_info and target_info["is_string"]:
                                        body.append(f"        {py_target} = {repr(val)}")
                                    else:
                                        body.append(f"        {py_target}.store(Decimal({repr(val)}))")
                                    _emitted_at_end = True
                                    continue
                                # Pattern: SET condition-name TO TRUE
                                set_match = re.match(r"SET([A-Z0-9\-]+)TOTRUE", ae_upper.replace(" ", ""))
                                if set_match:
                                    cond_name = set_match.group(1).strip()
                                    info_88 = level_88_map.get(cond_name)
                                    if info_88:
                                        parent = info_88["parent"]
                                        py_parent = to_python_name(parent)
                                        first_val = (info_88.get("values") or [info_88["value"]])[0]
                                        # Strip surrounding quotes from COBOL literal
                                        first_val = first_val.strip("'\"")
                                        parent_info = var_info.get(parent)
                                        if parent_info and parent_info["is_string"]:
                                            body.append(f"        {py_parent} = {repr(first_val)}")
                                        else:
                                            body.append(f"        {py_parent}.store(Decimal({repr(first_val)}))")
                                        _emitted_at_end = True
                                        continue
                                # Pattern: PERFORM paragraph-name
                                perf_match = re.match(r"PERFORM([A-Z0-9\-]+)", ae_upper.replace(" ", ""))
                                if perf_match:
                                    perf_target = perf_match.group(1).strip()
                                    perf_func = "para_" + to_python_name(perf_target)
                                    body.append(f"        {perf_func}()")
                                    _emitted_at_end = True
                                    continue
                                # Unrecognized AT END statement
                                body.append(f"        # MANUAL REVIEW: AT END — {ae_text[:60]}")
                                fail_count += 1
                                _emitted_at_end = True
                            if not _emitted_at_end:
                                body.append(f"        pass")
                        else:
                            body.append(f"        pass")

                        body.append(f"    else:")
                        body.append(f"        _io_populate('{file_name}', _record)")
                        if not_at_end:
                            for nae_text in not_at_end:
                                nae_upper = nae_text.upper()
                                perf_match = re.match(r"PERFORM([A-Z0-9\-]+)", nae_upper.replace(" ", ""))
                                if perf_match:
                                    perf_target = perf_match.group(1).strip()
                                    perf_func = "para_" + to_python_name(perf_target)
                                    body.append(f"        {perf_func}()")
                                else:
                                    body.append(f"        # MANUAL REVIEW: NOT AT END — {nae_text[:60]}")
                                    fail_count += 1
                    else:
                        # Simple READ without AT END
                        body.append(f"    if _record is not None:")
                        body.append(f"        _io_populate('{file_name}', _record)")

                    cobol_repr = f"READ {file_name}"[:45]
                    validation_entries.append((cobol_repr, f"_io_read('{file_name}')"[:45], "[OK]  "))
                    emit_counts["io"] += 1

                elif stmt_type == "file_write":
                    record_name = stmt.get("record_name", "")
                    from_source = stmt.get("from_source")
                    advancing = stmt.get("advancing")
                    advancing_type = stmt.get("advancing_type", "AFTER")
                    # Handle ADVANCING: prepend/append newlines or formfeed
                    if advancing:
                        if advancing == "PAGE":
                            adv_bytes = "b'\\x0c'"
                        else:
                            try:
                                n = int(advancing)
                            except (ValueError, TypeError):
                                n = 1
                            adv_bytes = f"b'\\n' * {n}"
                        if advancing_type == "BEFORE":
                            body.append(f"    _io_write('{record_name}'{', from_source=' + repr(from_source) if from_source else ''})")
                            body.append(f"    _io_backend.write('{record_name}', {adv_bytes})")
                        else:
                            body.append(f"    _io_backend.write('{record_name}', {adv_bytes})")
                            body.append(f"    _io_write('{record_name}'{', from_source=' + repr(from_source) if from_source else ''})")
                        cobol_repr = f"WRITE {record_name} {advancing_type} ADVANCING"[:45]
                    elif from_source:
                        body.append(f"    _io_write('{record_name}', from_source='{from_source}')")
                        cobol_repr = f"WRITE {record_name} FROM {from_source}"[:45]
                    else:
                        body.append(f"    _io_write('{record_name}')")
                        cobol_repr = f"WRITE {record_name}"[:45]
                    validation_entries.append((cobol_repr, f"_io_write('{record_name}')"[:45], "[OK]  "))
                    emit_counts["io"] += 1

                elif stmt_type == "file_close":
                    file_name = stmt.get("file_name", "")
                    body.append(f"    _io_close('{file_name}')")
                    cobol_repr = f"CLOSE {file_name}"[:45]
                    validation_entries.append((cobol_repr, f"_io_close('{file_name}')"[:45], "[OK]  "))
                    emit_counts["io"] += 1

                # ── REWRITE ──────────────────────────────────
                elif stmt_type == "file_rewrite":
                    record_name = stmt.get("record_name", "")
                    body.append(f"    _io_rewrite('{record_name}')")
                    cobol_repr = f"REWRITE {record_name}"[:45]
                    validation_entries.append((cobol_repr, f"_io_rewrite('{record_name}')"[:45], "[OK]  "))
                    emit_counts["io"] += 1

                # ── SORT ─────────────────────────────────────
                elif stmt_type == "sort":
                    sort_file = stmt.get("sort_file", "")
                    keys = stmt.get("keys", [])
                    using_files = stmt.get("using", [])
                    giving_files = stmt.get("giving", [])
                    input_proc = stmt.get("input_procedure")
                    output_proc = stmt.get("output_procedure")

                    if input_proc or output_proc:
                        # ── SORT with INPUT/OUTPUT PROCEDURE ──
                        sort_meta = _file_meta.get(sort_file.upper(), {})
                        sd_fields = sort_meta.get("fields", [])
                        sd_field_lookup = {f["name"].upper(): f for f in sd_fields}

                        body.append(f"    # SORT {sort_file} INPUT/OUTPUT PROCEDURE")
                        body.append(f"    _sort_buffer = []")
                        if input_proc:
                            input_func = "para_" + to_python_name(input_proc)
                            body.append(f"    {input_func}()")

                        # Build sort key (same logic as USING/GIVING path)
                        key_parts = []
                        for key_spec in keys:
                            direction = key_spec["direction"]
                            for field_name in key_spec["fields"]:
                                fu = field_name.upper()
                                sd_info = sd_field_lookup.get(fu)
                                field_type = sd_info.get("type", "string") if sd_info else "string"
                                if field_type == "decimal":
                                    val_expr = f"Decimal(str(r.get('{fu}', '0')))"
                                else:
                                    val_expr = f"str(r.get('{fu}', '') or '').encode('cp037')"
                                if direction == "DESCENDING":
                                    key_parts.append(f"ReverseKey({val_expr})")
                                else:
                                    key_parts.append(val_expr)

                        if len(key_parts) == 1:
                            key_expr = f"lambda r: {key_parts[0]}"
                        else:
                            key_expr = f"lambda r: ({', '.join(key_parts)})"

                        body.append(f"    _sort_buffer.sort(key={key_expr})")
                        if stmt.get("has_duplicates"):
                            body.append(f"    # WITH DUPLICATES IN ORDER — Python sort is stable (preserved)")
                        body.append(f"    _sort_iter = iter(_sort_buffer)")
                        if output_proc:
                            output_func = "para_" + to_python_name(output_proc)
                            body.append(f"    {output_func}()")

                        cobol_repr = f"SORT {sort_file} PROCEDURE"[:45]
                        validation_entries.append((cobol_repr, f"sort() INPUT/OUTPUT PROC"[:45], "[OK]  "))
                        emit_counts["io"] += 1
                    elif using_files and giving_files:
                        # NOTE: multi-file USING is not yet supported. Only first file used.
                        using_file = using_files[0]
                        # NOTE: multi-file GIVING is not yet supported. Only first file used.
                        giving_file = giving_files[0]

                        # Build sort key from SD field metadata
                        sort_meta = _file_meta.get(sort_file.upper(), {})
                        sd_fields = sort_meta.get("fields", [])
                        sd_field_lookup = {f["name"].upper(): f for f in sd_fields}

                        body.append(f"    # SORT {sort_file} USING {using_file} GIVING {giving_file}")
                        body.append(f"    _io_open('{using_file}', 'r')")
                        body.append(f"    _sort_records = []")
                        body.append(f"    while True:")
                        body.append(f"        _rec = _io_read('{using_file}')")
                        body.append(f"        if _rec is None:")
                        body.append(f"            break")
                        body.append(f"        _sort_records.append(_rec)")
                        body.append(f"    _io_close('{using_file}')")

                        # Build key lambda using ReverseKey for DESCENDING
                        # Consult sd_field_lookup for type; default unknown to string
                        key_parts = []
                        for key_spec in keys:
                            direction = key_spec["direction"]
                            for field_name in key_spec["fields"]:
                                fu = field_name.upper()
                                sd_info = sd_field_lookup.get(fu)
                                field_type = sd_info.get("type", "string") if sd_info else "string"
                                if field_type == "decimal":
                                    val_expr = f"Decimal(str(r.get('{fu}', '0')))"
                                else:
                                    val_expr = f"str(r.get('{fu}', '') or '').encode('cp037')"
                                if direction == "DESCENDING":
                                    key_parts.append(f"ReverseKey({val_expr})")
                                else:
                                    key_parts.append(val_expr)

                        if len(key_parts) == 1:
                            key_expr = f"lambda r: {key_parts[0]}"
                        else:
                            key_expr = f"lambda r: ({', '.join(key_parts)})"

                        body.append(f"    _sort_records.sort(key={key_expr})")
                        if stmt.get("has_duplicates"):
                            body.append(f"    # WITH DUPLICATES IN ORDER — Python sort is stable (preserved)")
                        body.append(f"    _io_open('{giving_file}', 'w')")
                        body.append(f"    for _rec in _sort_records:")
                        body.append(f"        _io_write_record('{giving_file}', _rec)")
                        body.append(f"    _io_close('{giving_file}')")

                        cobol_repr = f"SORT {sort_file}"[:45]
                        validation_entries.append((cobol_repr, f"sorted() USING/GIVING"[:45], "[OK]  "))
                        emit_counts["io"] += 1
                    elif not using_files and not giving_files and not input_proc:
                        # In-memory SORT on OCCURS table (no file I/O)
                        py_table = to_python_name(sort_file)
                        # Find sibling fields in the same OCCURS group
                        sort_upper = sort_file.upper()
                        occurs_siblings = []
                        in_group = False
                        for v in analysis.get("variables", []):
                            vn = v.get("name", "").upper()
                            if vn == sort_upper:
                                in_group = True
                                continue
                            if in_group and v.get("pic_raw"):
                                occurs_siblings.append(to_python_name(v["name"]))
                            elif in_group and not v.get("pic_raw"):
                                break  # next group level
                        if keys and occurs_siblings:
                            # Build sort key
                            key_field_py = to_python_name(keys[0]["fields"][0])
                            direction = keys[0].get("direction", "ASCENDING")
                            body.append(f"    # In-memory SORT on OCCURS table {sort_file}")
                            all_arrays = [py_table] + occurs_siblings
                            body.append(f"    _sort_zip = list(zip({', '.join(all_arrays)}))")
                            if direction == "DESCENDING":
                                body.append(f"    _sort_zip.sort(key=lambda t: t[{occurs_siblings.index(key_field_py) + 1}].value if hasattr(t[{occurs_siblings.index(key_field_py) + 1}], 'value') else t[{occurs_siblings.index(key_field_py) + 1}], reverse=True)")
                            else:
                                body.append(f"    _sort_zip.sort(key=lambda t: t[{occurs_siblings.index(key_field_py) + 1}].value if hasattr(t[{occurs_siblings.index(key_field_py) + 1}], 'value') else t[{occurs_siblings.index(key_field_py) + 1}])")
                            for idx, arr in enumerate(all_arrays):
                                body.append(f"    for _j, _t in enumerate(_sort_zip): {arr}[_j] = _t[{idx}]")
                            cobol_repr = f"SORT {sort_file} (in-memory)"[:45]
                            validation_entries.append((cobol_repr, f"zip+sort {py_table}"[:45], "[OK]  "))
                            emit_counts["io"] = emit_counts.get("io", 0) + 1
                        else:
                            body.append(f"    # MANUAL REVIEW: SORT {sort_file} — in-memory table sort (no sibling fields found)")
                            cobol_repr = f"SORT {sort_file}"[:45]
                            validation_entries.append((cobol_repr, "# MANUAL REVIEW"[:45], "[FAIL]"))
                            fail_count += 1
                    else:
                        body.append(f"    # MANUAL REVIEW: SORT — missing USING/GIVING")
                        cobol_repr = f"SORT {sort_file}"[:45]
                        validation_entries.append((cobol_repr, "# MANUAL REVIEW"[:45], "[FAIL]"))
                        fail_count += 1

                    if not stmt.get("has_duplicates") and keys:
                        compiler_warnings.append(
                            f"SORT on {sort_file} does not specify WITH DUPLICATES IN ORDER. "
                            "Python sort is stable, but mainframe sort stability is "
                            "compiler-dependent."
                        )

                # ── MERGE ─────────────────────────────────────
                elif stmt_type == "merge":
                    merge_file = stmt.get("merge_file", "UNKNOWN")
                    body.append(f"    # MANUAL REVIEW: MERGE {merge_file} (rare construct — not emitted)")
                    body.append(f"    pass")
                    fail_count += 1
                    validation_entries.append((f"MERGE {merge_file}"[:45], "# MANUAL REVIEW", "[FAIL]"))

                # ── RELEASE (sort input) ────────────────────────
                elif stmt_type == "release":
                    record_name = stmt.get("record_name", "").upper()
                    # Find SD file that owns this record
                    sort_file_for_rec = None
                    for sf_name, sf_meta in _file_meta.items():
                        if sf_meta.get("record_name", "").upper() == record_name:
                            sort_file_for_rec = sf_name
                            break
                    sd_meta = _file_meta.get(sort_file_for_rec, {}) if sort_file_for_rec else {}
                    sd_fields = sd_meta.get("fields", [])

                    field_parts = []
                    for f in sd_fields:
                        py_name = f["python_name"]
                        fu = f["name"].upper()
                        if f.get("type") == "string":
                            field_parts.append(f"'{fu}': str({py_name})")
                        else:
                            field_parts.append(f"'{fu}': Decimal(str({py_name}.value))")

                    body.append(f"    _sort_buffer.append({{{', '.join(field_parts)}}})")
                    cobol_repr = f"RELEASE {record_name}"[:45]
                    validation_entries.append((cobol_repr, "_sort_buffer.append()"[:45], "[OK]  "))
                    emit_counts["io"] += 1

                # ── RETURN (sort output) ────────────────────────
                elif stmt_type == "return_sort":
                    file_name = stmt.get("file_name", "").upper()
                    into_var = stmt.get("into_var")
                    at_end = stmt.get("at_end", [])
                    sd_meta = _file_meta.get(file_name, {})
                    sd_fields = sd_meta.get("fields", [])

                    body.append(f"    _sort_rec = next(_sort_iter, None)")
                    body.append(f"    if _sort_rec is None:")

                    # AT END branch
                    if at_end:
                        _emitted_at_end = False
                        for ae_text in at_end:
                            ae_upper = ae_text.upper().replace(" ", "")
                            if ae_upper == "CONTINUE":
                                body.append(f"        pass")
                                _emitted_at_end = True
                            elif ae_upper == "EXITPERFORM":
                                body.append(f"        break")
                                _emitted_at_end = True
                            else:
                                # Safe fallback for unrecognized AT END statements
                                body.append(f"        pass  # TODO: AT END {ae_text[:60]}")
                                _emitted_at_end = True
                        if not _emitted_at_end:
                            body.append(f"        pass")
                    else:
                        body.append(f"        pass")

                    body.append(f"    else:")
                    # Populate SD fields from _sort_rec
                    for f in sd_fields:
                        py_name = f["python_name"]
                        fu = f["name"].upper()
                        if f.get("type") == "string":
                            body.append(f"        {py_name} = _sort_rec['{fu}']")
                        else:
                            body.append(f"        {py_name}.store(_sort_rec['{fu}'])")

                    # INTO clause: copy SD fields to target variable (group move)
                    if into_var:
                        into_py = to_python_name(into_var)
                        into_upper = into_var.upper()
                        into_info = var_info.get(into_upper)
                        if into_info and into_info.get("is_string"):
                            concat_parts = []
                            for f in sd_fields:
                                py_name = f["python_name"]
                                length = f.get("length", 10)
                                if f.get("type") == "string":
                                    concat_parts.append(f"str({py_name}).ljust({length})")
                                else:
                                    concat_parts.append(f"str({py_name}.value).zfill({length})")
                            body.append(f"        {into_py} = {' + '.join(concat_parts)}")

                    cobol_repr = f"RETURN {file_name}"[:45]
                    validation_entries.append((cobol_repr, "next(_sort_iter)"[:45], "[OK]  "))
                    emit_counts["io"] += 1

                # ── SEARCH / SEARCH ALL ─────────────────────────
                elif stmt_type == "search":
                    table_name = stmt.get("table_name", "UNKNOWN")
                    is_all = stmt.get("is_all", False)
                    varying = stmt.get("varying")
                    at_end_text = stmt.get("at_end")
                    whens = stmt.get("whens", [])
                    py_table = to_python_name(table_name)

                    # Index variable MUST come from VARYING clause
                    if not varying:
                        body.append(f"    pass  # MANUAL REVIEW: SEARCH without VARYING — index variable unknown for {table_name}")
                        all_issues.append({"status": "fail", "reason": f"SEARCH without VARYING — index unknown for {table_name}", "cobol": f"SEARCH {table_name}"})
                        search_kind = "SEARCH ALL" if is_all else "SEARCH"
                        cobol_repr = f"{search_kind} {table_name}"[:45]
                        validation_entries.append((cobol_repr, "# MANUAL REVIEW"[:45], "[FAIL]"))
                        fail_count += 1
                    else:
                        py_idx = to_python_name(varying)

                        # Determine table size from analysis variables
                        table_size = None
                        for v in analysis.get("variables", []):
                            if v["name"].upper() == table_name.upper() and v.get("occurs", 0) > 0:
                                table_size = v["occurs"]
                                break

                        search_kind = "SEARCH ALL" if is_all else "SEARCH"
                        body.append(f"    # {search_kind} {table_name}")
                        body.append(f"    _search_found = False")

                        if table_size:
                            body.append(f"    for _si in range(1, {table_size} + 1):")
                        else:
                            body.append(f"    for _si in range(1, len({py_table}) + 1):")

                        body.append(f"        {py_idx}.store(Decimal(_si))")

                        # WHEN clauses
                        for wi, when in enumerate(whens):
                            cond_text = when.get("condition", "")
                            if cond_text:
                                py_cond, _ = _convert_condition(
                                    cond_text, known_vars, level_88_map, string_vars
                                )
                                prefix = "if" if wi == 0 else "elif"
                                body.append(f"        {prefix} {py_cond}:")

                                # Body statements (MOVE, PERFORM, SET, etc.)
                                for body_text in when.get("body", []):
                                    _emit_search_body(body, body_text, known_vars, string_vars, indent=12)

                                body.append(f"            _search_found = True")
                                body.append(f"            break")

                        # AT END
                        if at_end_text:
                            body.append(f"    if not _search_found:")
                            _emit_search_at_end(body, at_end_text, known_vars, string_vars, indent=8)

                        cobol_repr = f"{search_kind} {table_name}"[:45]
                        validation_entries.append((cobol_repr, f"for loop + break"[:45], "[OK]  "))
                        emit_counts["control"] = emit_counts.get("control", 0) + 1

        else:
            body.append("    pass  # No statements captured")

        body.append("")

    body.append("# " + "=" * 60)
    body.append("# MAIN EXECUTION")
    body.append("# " + "=" * 60)
    body.append("")
    body.append("def main():")

    # LOCAL-STORAGE variables reinitialize on every call (unlike WORKING-STORAGE)
    local_vars = [info for info in var_info.values()
                  if info.get("storage_section") == "LOCAL"]
    if local_vars:
        local_py_names = sorted(info["python_name"] for info in local_vars)
        body.append(f"    global {', '.join(local_py_names)}")
        for info in sorted(local_vars, key=lambda i: i["python_name"]):
            py_name = info["python_name"]
            occurs = info.get("occurs", 0)
            if info["is_string"]:
                if occurs > 0:
                    body.append(f'    {py_name} = ["" for _ in range({occurs})]')
                else:
                    body.append(f'    {py_name} = ""')
            else:
                integers = info["integers"] or 1
                decimals = info["decimals"]
                signed = info["signed"]
                storage = info.get("storage_type", "COMP-3" if info["comp3"] else "DISPLAY")
                is_comp = storage in ('COMP', 'COMP-4', 'COMP-5', 'BINARY')
                decl = (
                    f"CobolDecimal('0', "
                    f"pic_integers={integers}, pic_decimals={decimals}, "
                    f"is_signed={signed}, is_comp={is_comp})"
                )
                if occurs > 0:
                    body.append(f"    {py_name} = [{decl} for _ in range({occurs})]")
                else:
                    body.append(f"    {py_name} = {decl}")
        body.append("")

    if analysis["paragraphs"]:
        entry = "para_" + to_python_name(analysis["paragraphs"][0])
        body.append(f"    {entry}()")
    else:
        body.append("    pass")
    if trace_mode:
        body.append("    return _trace")

    body.append("")
    body.append("")
    body.append('if __name__ == "__main__":')
    body.append("    main()")

    # ── Confidence ───────────────────────────────────────────────
    confidence_pct = (
        max(0, int(100 * (total_stmts - fail_count) / total_stmts))
        if total_stmts > 0 else 100
    )

    # ── Side-by-side validation report ──────────────────────────
    W = 46
    report: list[str] = []
    report.append("")
    report.append("# " + "=" * (W * 2 + 10))
    report.append("# VALIDATION REPORT — COBOL <-> PYTHON SIDE-BY-SIDE")
    report.append(
        f"# Confidence: {confidence_pct}%  |  "
        f"{fail_count} of {total_stmts} statements flagged"
    )
    report.append("# " + "=" * (W * 2 + 10))
    report.append(f"# {'COBOL':<{W}} {'PYTHON':<{W}} STATUS")
    report.append(f"# {'-' * W} {'-' * W} ------")
    for cobol_r, py_r, status in validation_entries:
        report.append(f"# {cobol_r:<{W}} {py_r:<{W}} {status}")

    if all_issues:
        report.append("#")
        report.append("# FLAGGED ITEMS:")
        for iss in all_issues:
            report.append(
                f"#   [{iss['status'].upper()}] {iss['reason']}: {iss['cobol'][:60]}"
            )

    # ── Assemble final output ────────────────────────────────────
    output: list[str] = []

    if confidence_pct < 95:
        output.append("# " + "=" * 70)
        output.append("# REQUIRES MANUAL REVIEW — NOT PRODUCTION READY")
        output.append(f"# Conversion confidence: {confidence_pct}%")
        output.append(f"# Statements with issues: {fail_count} of {total_stmts}")
        output.append("# " + "=" * 70)
        output.append("")

    output.extend(body)
    output.extend(report)

    # ── Arithmetic Risk Analysis (comment block) ──────────────────
    arith = compute_arithmetic_risks(analysis)
    s = arith["summary"]
    arith_lines: list[str] = []
    arith_lines.append("")
    arith_lines.append("# " + "=" * 70)
    arith_lines.append("# ARITHMETIC RISK ANALYSIS")
    arith_lines.append(
        f"# {s['safe']} SAFE  {s['warn']} WARN  {s['critical']} CRITICAL"
        f"  (of {s['total']} COMPUTE statements)"
    )
    arith_lines.append("# " + "=" * 70)
    for r in arith["risks"]:
        tag = f"[{r['status']}]"
        arith_lines.append("#")
        arith_lines.append(f"# COMPUTE {r['compute'][:65]}")
        arith_lines.append(f"#   Paragraph  : {r['paragraph']}")
        tgt = r["target"]
        if tgt["pic"] != "?":
            arith_lines.append(
                f"#   Target     : {tgt['name']:<22} PIC {tgt['pic']:<14} max {tgt['max_value']}"
            )
        for op in r["operands"]:
            arith_lines.append(
                f"#   Operand    : {op['name']:<22} PIC {op['pic']:<14} max {op['max_value']}"
            )
        arith_lines.append(f"#   Operation  : {r['operation']}")
        arith_lines.append(f"#   Worst-case : {r['worst_case']}")
        arith_lines.append(f"#   Status     : {tag} {r['reason']}")
    output.extend(arith_lines)

    # ── Extract MR flags from generated code ─────────────────────
    import re as _re
    _MR_REASONS = {
        "NESTED PROGRAMS": {
            "reason": "Nested programs have separate DATA DIVISIONs and namespaces.",
            "recommendation": "Verify each nested program independently.",
            "severity": "HIGH",
        },
        "ALTER": {
            "reason": "Self-modifying control flow — static verification impossible.",
            "recommendation": "Refactor to EVALUATE or conditional PERFORM. IBM recommends avoiding ALTER.",
            "severity": "HIGH",
        },
        "EXEC SQL": {
            "reason": "External database dependency stripped from verification model.",
            "recommendation": "Verify SQL logic separately. Check SQLCODE handling and variable taint.",
            "severity": "HIGH",
        },
        "EXEC CICS": {
            "reason": "External transaction dependency stripped from verification model.",
            "recommendation": "Verify CICS logic separately. Check RESP/RESP2 handling.",
            "severity": "HIGH",
        },
        "INSPECT CONVERTING": {
            "reason": "INSPECT CONVERTING clause could not be fully parsed (unequal lengths or unparseable syntax).",
            "recommendation": "Check that FROM/TO strings have equal length. Verify conversion logic manually.",
            "severity": "MEDIUM",
        },
        "INSPECT TALLYING": {
            "reason": "TALLYING clause could not be fully parsed.",
            "recommendation": "Simplify INSPECT to use ALL/LEADING or verify count logic manually.",
            "severity": "MEDIUM",
        },
        "INSPECT REPLACING": {
            "reason": "REPLACING clause could not be fully parsed.",
            "recommendation": "Simplify INSPECT or verify replacement logic manually.",
            "severity": "MEDIUM",
        },
        "INSPECT": {
            "reason": "INSPECT variant not recognized by generator.",
            "recommendation": "Check if this is an IBM extension. Manual verification needed.",
            "severity": "MEDIUM",
        },
        "COMPUTE": {
            "reason": "Arithmetic expression could not be parsed or uses unsupported FUNCTION.",
            "recommendation": "Check for nested functions or non-standard syntax. Simplify if possible.",
            "severity": "MEDIUM",
        },
        "MOVE CORRESPONDING": {
            "reason": "Group structure not found in DATA DIVISION for MOVE CORRESPONDING.",
            "recommendation": "Verify copybook includes group definition. Check COPY/REPLACING.",
            "severity": "MEDIUM",
        },
        "MOVE FUNCTION": {
            "reason": "Function in MOVE not supported by generator.",
            "recommendation": "Verify function output manually or replace with COMPUTE.",
            "severity": "MEDIUM",
        },
        "RENAMES": {
            "reason": "Byte-level RENAMES THRU range cannot be resolved at compile time.",
            "recommendation": "Map byte offsets manually. Consider replacing with explicit fields.",
            "severity": "MEDIUM",
        },
        "SEARCH": {
            "reason": "Index variable unknown — cannot determine table subscript for SEARCH.",
            "recommendation": "Add VARYING clause or verify index initialization manually.",
            "severity": "MEDIUM",
        },
        "SORT": {
            "reason": "SORT statement missing required USING or GIVING clause.",
            "recommendation": "Add USING and GIVING clauses to the SORT statement.",
            "severity": "MEDIUM",
        },
        "SET": {
            "reason": "88-level condition name not found in parsed definitions.",
            "recommendation": "Verify 88-level is defined in copybook. Check COPY/REPLACING.",
            "severity": "MEDIUM",
        },
        "INITIALIZE": {
            "reason": "Target variable not found in DATA DIVISION for INITIALIZE.",
            "recommendation": "Verify variable is defined in copybook or LINKAGE SECTION.",
            "severity": "LOW",
        },
        "AT END": {
            "reason": "AT END or NOT AT END handler could not be parsed.",
            "recommendation": "Simplify AT END block or verify error handling manually.",
            "severity": "LOW",
        },
        "OVERFLOW": {
            "reason": "ON OVERFLOW or NOT ON OVERFLOW handler could not be parsed.",
            "recommendation": "Simplify overflow handling or verify manually.",
            "severity": "LOW",
        },
    }

    _mr_pattern = _re.compile(r"# MANUAL REVIEW:?\s*(.+)")
    _seen_constructs = set()
    for line in output:
        m = _mr_pattern.search(line)
        if m:
            flag_text = m.group(1).strip()
            # Match to known construct
            matched = None
            for key in _MR_REASONS:
                if key in flag_text.upper():
                    matched = key
                    break
            if matched and matched not in _seen_constructs:
                _seen_constructs.add(matched)
                info = _MR_REASONS[matched]
                mr_flags.append({
                    "construct": matched,
                    "detail": flag_text[:80],
                    "reason": info["reason"],
                    "recommendation": info["recommendation"],
                    "severity": info["severity"],
                })
            elif not matched and flag_text[:40] not in _seen_constructs:
                _seen_constructs.add(flag_text[:40])
                mr_flags.append({
                    "construct": "Unhandled statement",
                    "detail": flag_text[:80],
                    "reason": "Statement type not recognized by generator.",
                    "recommendation": "Check if statement is IBM extension or dialect-specific.",
                    "severity": "LOW",
                })

    return {"code": "\n".join(output), "emit_counts": emit_counts, "compiler_warnings": compiler_warnings, "db2_tainted_fields": db2_tainted_fields, "mr_flags": mr_flags}


# ── CLI entry point ──────────────────────────────────────────────

if __name__ == "__main__":
    from cobol_analyzer_api import analyze_cobol

    with open("DEMO_LOAN_INTEREST.cbl", "r") as f:
        cobol_source = f.read()

    analysis = analyze_cobol(cobol_source)
    python_code = generate_python_module(analysis)

    with open("converted_loan_interest.py", "w", encoding="utf-8") as f:
        f.write(python_code)

    print("Generated: converted_loan_interest.py")
    print()
    print(python_code)
