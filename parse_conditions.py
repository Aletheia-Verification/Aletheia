"""
parse_conditions.py — Honest COBOL IF/ELSE → Python converter

Accepts STRUCTURED data from the ANTLR analyzer (condition, then_statements,
else_statements) instead of raw getText() blobs. Uses known_variables for
word boundary detection and level_88_map for 88-level condition lookups.

Returns (python_code, issues_list) — issues feed the side-by-side report.
"""

import re


def to_python_name(name):
    """WS-DAILY-RATE -> ws_daily_rate"""
    return name.lower().replace("-", "_")


def _extract_subscript(text):
    """Extract parenthesized subscript from text, handling nested parens.

    Returns the inner content of the outermost parentheses, or None.
    E.g. 'COND(VAR(IDX))' → 'VAR(IDX)', 'COND(X)' → 'X'.
    """
    start = text.find('(')
    if start == -1:
        return None
    depth = 0
    for i in range(start, len(text)):
        if text[i] == '(':
            depth += 1
        elif text[i] == ')':
            depth -= 1
            if depth == 0:
                return text[start + 1:i]
    return None


def _strip_subscript(text):
    """Remove outermost parenthesized subscript from text, handling nesting."""
    start = text.find('(')
    if start == -1:
        return text
    depth = 0
    for i in range(start, len(text)):
        if text[i] == '(':
            depth += 1
        elif text[i] == ')':
            depth -= 1
            if depth == 0:
                return (text[:start] + text[i + 1:]).strip()
    return text


def _find_variable_at_end(text, known_variables, prefix="TO"):
    """
    Find a known variable at the end of text preceded by prefix.
    Uses longest-match-first to avoid false matches when variable
    names contain the prefix as a substring.
    """
    upper = text.upper()
    for var in sorted(known_variables, key=len, reverse=True):
        suffix = (prefix + var).upper()
        if upper.endswith(suffix):
            return var, text[:len(text) - len(suffix)]
    return None, text


def _resolve_value(text, known_variables, string_vars=None, use_value=False):
    """Resolve a COBOL value to Python — variable name or Decimal literal.

    If use_value=True, numeric (non-string) variables get .value appended
    for use in expressions with CobolDecimal.
    """
    text = text.strip()
    upper = text.upper()

    if not text:
        return "None"

    # Subscript access: VARNAME(INDEX)
    if '(' in text:
        py_sub, base_var = _resolve_subscripted_name(text, known_variables, string_vars)
        if py_sub:
            if use_value and not _is_string_operand(base_var, string_vars):
                return f"{py_sub}.value"
            return py_sub

    # Numeric literal
    if re.match(r'^-?[\d.]+$', text):
        return f"Decimal('{text}')"

    # Figurative constants — never append .value (these are plain Python str/Decimal)
    if upper in ("HIGH-VALUE", "HIGH-VALUES"):
        return "high_values"
    if upper in ("LOW-VALUE", "LOW-VALUES"):
        return "low_values"
    if upper in ("QUOTE", "QUOTES"):
        return "quotes"
    if upper in ("SPACES", "SPACE"):
        return "spaces"
    if upper in ("ZEROS", "ZEROES"):
        return "zeros"
    # ALL 'X' — repeat literal (simplified: just the literal value)
    all_match = re.match(r"^ALL\s*['\"](.)['\"]$", text, re.IGNORECASE)
    if all_match:
        return f"'{all_match.group(1)}'"

    # Known variable (case-insensitive match)
    for var in known_variables:
        if upper == var.upper():
            py = to_python_name(var)
            if use_value and not _is_string_operand(var, string_vars):
                return f"{py}.value"
            return py

    # Check for OF qualifier: "FIELD-NAMEOFGROUP-NAME" → qualified lookup
    of_idx = upper.find("OF")
    if of_idx > 0:
        field_part = upper[:of_idx]
        group_part = upper[of_idx + 2:]
        qkey = f"{group_part}__{field_part}"
        for var in known_variables:
            if qkey == var.upper():
                py = to_python_name(var)
                if use_value and not _is_string_operand(var, string_vars):
                    return f"{py}.value"
                return py

    # Unknown but looks like a COBOL name
    if re.match(r'^[A-Z][A-Z0-9\-]*$', upper):
        py = to_python_name(text)
        if use_value:
            return f"{py}.value"
        return py

    return text


def _is_string_operand(text, string_vars):
    """Check if a COBOL operand refers to a PIC X/A variable."""
    if not string_vars:
        return False
    upper = text.strip().upper()
    # Strip subscript: VAR(IDX) → VAR
    paren_idx = upper.find('(')
    if paren_idx > 0:
        upper = upper[:paren_idx].strip()
    return upper in {v.upper() for v in string_vars}


def _resolve_subscripted_name(text, known_variables, string_vars=None):
    """If text is VARNAME(SUBSCRIPT), return (py_indexed_expr, base_var_name).

    Returns (None, None) if text is not a subscript reference.
    COBOL is 1-indexed, Python is 0-indexed — adjusts automatically.
    """
    paren_idx = text.find('(')
    if paren_idx < 1:
        return None, None
    var_part = text[:paren_idx].strip()
    rest = text[paren_idx + 1:]
    close_paren = rest.rfind(')')
    if close_paren < 0:
        return None, None
    subscript = rest[:close_paren].strip()

    # Match base variable
    var_upper = var_part.upper()
    matched = next((v for v in known_variables if v.upper() == var_upper), None)
    if not matched:
        # Variable not in known_variables — still handle reference modification
        # (covers cases where analyzer truncates group-level field names)
        if ':' in subscript:
            py_base = to_python_name(var_part)
            parts = subscript.split(':', 1)
            start_expr, length_expr = _resolve_refmod_expr(
                parts[0].strip(), parts[1].strip(), known_variables, string_vars
            )
            if re.match(r'^\d+$', start_expr) and re.match(r'^\d+$', length_expr):
                s = int(start_expr)
                return f"{py_base}[{s}:{s + int(length_expr)}]", var_part
            return f"{py_base}[{start_expr}:{start_expr} + {length_expr}]", var_part
        return None, None

    py_base = to_python_name(matched)

    # Reference modification: VAR(start:length) — has a colon
    if ':' in subscript:
        parts = subscript.split(':', 1)
        start_expr, length_expr = _resolve_refmod_expr(
            parts[0].strip(), parts[1].strip(), known_variables, string_vars
        )
        if re.match(r'^\d+$', start_expr) and re.match(r'^\d+$', length_expr):
            s = int(start_expr)
            return f"{py_base}[{s}:{s + int(length_expr)}]", matched
        return f"{py_base}[{start_expr}:{start_expr} + {length_expr}]", matched

    idx_expr = _subscript_index(subscript, known_variables, string_vars)
    return f"{py_base}[{idx_expr}]", matched


def _subscript_index(subscript_text, known_variables, string_vars=None):
    """Convert COBOL 1-based subscript to Python 0-based index expression.

    Handles multi-dimensional subscripts (comma-separated) with paren-depth
    awareness to avoid splitting inside nested function calls.
    """
    sub = subscript_text.strip()

    # Multi-dimensional: split on commas at depth 0 (not inside parentheses)
    if ',' in sub:
        parts = []
        depth = 0
        current = []
        for ch in sub:
            if ch == '(':
                depth += 1
            elif ch == ')':
                depth -= 1
            elif ch == ',' and depth == 0:
                parts.append(''.join(current).strip())
                current = []
                continue
            current.append(ch)
        parts.append(''.join(current).strip())
        if len(parts) > 1:
            indices = [_subscript_index(p, known_variables, string_vars) for p in parts]
            return ']['.join(indices)

    # Literal number
    if re.match(r'^\d+$', sub):
        return str(int(sub) - 1)
    # Known variable
    for var in known_variables:
        if sub.upper() == var.upper():
            py = to_python_name(var)
            if not _is_string_operand(var, string_vars):
                return f"int({py}.value) - 1"
            return f"int({py}) - 1"
    # Unknown — assume numeric CobolDecimal
    py = to_python_name(sub)
    return f"int({py}.value) - 1"


def _resolve_refmod_expr(start_text, length_text, known_variables, string_vars=None):
    """Resolve COBOL reference modification start/length to Python expressions.

    Returns (start_expr, length_expr) where start is already 0-indexed.
    """
    # Start position (1-indexed → 0-indexed)
    if re.match(r'^\d+$', start_text):
        start_expr = str(int(start_text) - 1)
    else:
        matched = next((v for v in known_variables if start_text.upper() == v.upper()), None)
        if matched:
            py = to_python_name(matched)
            start_expr = f"int({py}.value) - 1" if not _is_string_operand(matched, string_vars) else f"int({py}) - 1"
        else:
            start_expr = f"int({to_python_name(start_text)}.value) - 1"

    # Length
    if re.match(r'^\d+$', length_text):
        length_expr = length_text
    else:
        matched = next((v for v in known_variables if length_text.upper() == v.upper()), None)
        if matched:
            py = to_python_name(matched)
            length_expr = f"int({py}.value)" if not _is_string_operand(matched, string_vars) else f"int({py})"
        else:
            length_expr = f"int({to_python_name(length_text)}.value)"

    return start_expr, length_expr


def _emit_88_condition(info, string_vars, negated=False, subscript=None):
    """Emit Python expression for an 88-level condition (single, multi-value, or THRU)."""
    issues = []
    parent = info["parent"]
    py_name = to_python_name(parent)
    # Apply subscript if present: WS-TAXABLE(WS-IDX) → ws_taxable[int(ws_idx.value) - 1]
    if subscript:
        from generate_full_python import to_python_name as _tpn
        idx_py = to_python_name(subscript)
        py_name = f"{py_name}[int({idx_py}.value) - 1]"
    is_string = _is_string_operand(parent, string_vars)
    values = info.get("values") or [info["value"]]
    thru = info.get("thru")

    if thru:
        # VALUE x THRU y → low <= field <= high (range check)
        low, high = thru["low"], thru["high"]
        if is_string and string_vars:
            expr = (f"ebcdic_compare({repr(low)}, {py_name}, _CODEPAGE) <= 0 and "
                    f"ebcdic_compare({py_name}, {repr(high)}, _CODEPAGE) <= 0")
        else:
            expr = f"Decimal({repr(low)}) <= {py_name}.value <= Decimal({repr(high)})"
        if negated:
            expr = f"not ({expr})"
        return expr, issues

    if len(values) > 1:
        # Multiple values → field in ('A', 'B', 'C')
        if is_string:
            vals_repr = ", ".join(repr(v) for v in values)
            expr = f'{py_name} in ({vals_repr})'
        else:
            vals_repr = ", ".join(f"Decimal({repr(v)})" for v in values)
            expr = f'{py_name}.value in ({vals_repr})'
        if negated:
            expr = f'{py_name} not in ({vals_repr})' if is_string else f'{py_name}.value not in ({vals_repr})'
        return expr, issues

    # Single value — original behaviour
    value = values[0]
    if not is_string:
        op = "!=" if negated else "=="
        return f"{py_name}.value {op} Decimal({repr(value)})", issues
    op = "!=" if negated else "=="
    return f"{py_name} {op} {repr(value)}", issues


def _split_compound_condition(condition_text, known_variables, level_88_map, string_vars=None):
    """Split compound AND/OR conditions and convert each segment.

    Returns (python_expr, issues) or None if no AND/OR found.
    COBOL precedence: AND binds tighter than OR.
    """
    upper = condition_text.upper().strip()

    # Step 0: Mask string literals to avoid splitting 'ANDERSON', 'ORLANDO', etc.
    placeholders = {}
    masked = condition_text
    placeholder_idx = 0
    for m in re.finditer(r"'[^']*'", condition_text):
        ph = f"\x00PH{placeholder_idx}\x00"
        placeholders[ph] = m.group(0)
        masked = masked[:m.start()] + ph + masked[m.end():]
        placeholder_idx += 1
    # Adjust: rebuild masked from scratch to handle overlapping offsets
    if placeholders:
        masked = condition_text
        offset = 0
        sorted_matches = sorted(re.finditer(r"'[^']*'", condition_text), key=lambda m: m.start())
        placeholders = {}
        masked_parts = []
        last_end = 0
        for i, m in enumerate(sorted_matches):
            ph = f"\x00PH{i}\x00"
            placeholders[ph] = m.group(0)
            masked_parts.append(condition_text[last_end:m.start()])
            masked_parts.append(ph)
            last_end = m.end()
        masked_parts.append(condition_text[last_end:])
        masked = "".join(masked_parts)

    masked_upper = masked.upper()

    # Step 1: Find AND/OR at token boundaries in the masked text.
    # Token boundary: preceded by digit, quote, ), or placeholder-end;
    # followed by letter, (, or placeholder-start.
    # Also handle NOT prefix after AND/OR.
    and_or_pattern = re.compile(
        r'(?<=[0-9\'"\)\x00])(AND|OR)(?=[A-Z(\x000-9])',
        re.IGNORECASE
    )

    matches = list(and_or_pattern.finditer(masked_upper))
    if not matches:
        return None

    # Step 2: Split into segments at AND/OR boundaries
    segments = []
    connectors = []
    last_end = 0
    for m in matches:
        seg = masked[last_end:m.start()]
        if seg.strip():
            segments.append(seg)
            connectors.append(m.group(1).upper())
        last_end = m.end()
    tail = masked[last_end:]
    if tail.strip():
        segments.append(tail)

    if len(segments) < 2:
        return None

    # Step 3: Restore placeholders in each segment
    def restore(text):
        for ph, original in placeholders.items():
            text = text.replace(ph, original)
        return text

    segments = [restore(s) for s in segments]

    # Step 4: Handle abbreviated combined relations.
    # If a segment has no comparison operator, carry forward the last subject+operator.
    # e.g., IF A = 1 OR 2 → segments = ["A=1", "2"], carry "A" and "=" to "2"
    last_subject = None
    last_op = None
    expanded_segments = []
    for seg in segments:
        seg_upper = seg.upper().strip()
        has_op = any(op in seg_upper for op in [">=", "<=", ">", "<", "="])
        has_88 = seg_upper in level_88_map or (
            seg_upper.startswith("NOT") and seg_upper[3:] in level_88_map)
        has_class = bool(re.search(r'IS(NUMERIC|ALPHABETIC)', seg_upper))

        if has_op:
            # Extract subject and operator for potential carry-forward
            for op in [">=", "<=", ">", "<", "="]:
                idx = seg_upper.find(op)
                if idx > 0:
                    last_subject = seg[:idx]
                    last_op = op
                    break
            expanded_segments.append(seg)
        elif has_88 or has_class:
            expanded_segments.append(seg)
        elif last_subject is not None and last_op is not None:
            # Bare value — expand with carried subject+operator
            expanded_segments.append(f"{last_subject}{last_op}{seg}")
        else:
            # Can't expand — keep as-is, will hit MANUAL REVIEW in recursion
            expanded_segments.append(seg)

    # Step 5: Convert each segment recursively
    all_issues = []
    converted = []
    for seg in expanded_segments:
        py_expr, seg_issues = _convert_condition(seg, known_variables, level_88_map, string_vars)
        all_issues.extend(seg_issues)
        converted.append(py_expr)

    # Step 6: Apply COBOL precedence — AND binds tighter than OR.
    # Group consecutive AND-connected expressions, then join OR groups.
    # connectors has len(segments)-1 entries
    if "OR" not in connectors:
        # All AND — simple join
        result = " and ".join(converted)
    elif "AND" not in connectors:
        # All OR — simple join
        result = " or ".join(converted)
    else:
        # Mixed: group AND clusters, then join with OR
        or_groups = []
        current_group = [converted[0]]
        for i, conn in enumerate(connectors):
            if conn == "AND":
                current_group.append(converted[i + 1])
            else:  # OR
                or_groups.append(current_group)
                current_group = [converted[i + 1]]
        or_groups.append(current_group)

        or_parts = []
        for group in or_groups:
            if len(group) == 1:
                or_parts.append(group[0])
            else:
                or_parts.append("(" + " and ".join(group) + ")")
        result = " or ".join(or_parts)

    return result, all_issues


def _convert_condition(condition_text, known_variables, level_88_map, string_vars=None):
    """Convert a COBOL condition to a Python expression."""
    issues = []
    upper = condition_text.upper().strip()

    # ── Compound AND/OR pre-split ────────────────────────────────
    compound = _split_compound_condition(condition_text, known_variables, level_88_map, string_vars)
    if compound is not None:
        return compound

    # 88-level condition lookup (strip subscript for matching — handles nested parens)
    _88_bare = _strip_subscript(upper)
    _88_subscript = _extract_subscript(upper)
    if _88_bare in level_88_map:
        info = level_88_map[_88_bare]
        return _emit_88_condition(info, string_vars, negated=False, subscript=_88_subscript)

    # NOT + 88-level (strip subscript)
    _88_not_text = upper[3:].strip() if upper.startswith("NOT") else ""
    _88_not_bare = _strip_subscript(_88_not_text) if _88_not_text else ""
    _88_not_sub = _extract_subscript(_88_not_text) if _88_not_text else None
    if upper.startswith("NOT") and _88_not_bare in level_88_map:
        info = level_88_map[_88_not_bare]
        return _emit_88_condition(info, string_vars, negated=True, subscript=_88_not_sub)

    # NOT prefix for other conditions
    negated = False
    if upper.startswith("NOT"):
        negated = True
        condition_text = condition_text[3:]
        upper = upper[3:]

    # Fallback: OR-separated 88-level names (WS-BLOCKORWS-REVIEW → WS-BLOCK OR WS-REVIEW)
    # getText() concatenates without spaces, so the regex AND/OR splitter misses these.
    # Use known 88-level names from level_88_map to find split points.
    if 'OR' in upper:
        _88_parts = []
        _remaining = upper
        while _remaining:
            found = False
            for name in sorted(level_88_map.keys(), key=len, reverse=True):
                if _remaining.startswith(name):
                    _88_parts.append(name)
                    _remaining = _remaining[len(name):]
                    if _remaining.startswith('OR'):
                        _remaining = _remaining[2:]
                    found = True
                    break
            if not found:
                break
        if len(_88_parts) >= 2 and not _remaining:
            exprs = []
            for p in _88_parts:
                expr, sub_issues = _emit_88_condition(level_88_map[p], string_vars)
                issues.extend(sub_issues)
                exprs.append(expr)
            result = " or ".join(exprs)
            if negated:
                result = f"not ({result})"
            return result, issues

    # IS NUMERIC / IS ALPHABETIC class conditions (ANTLR getText() strips spaces)
    # Expanded regex: handles subscripts and reference modification: WS-FIELD(1:1)ISNUMERIC
    class_match = re.match(
        r'^([A-Z][A-Z0-9\-]*(?:\([^)]+\))?)IS(NUMERIC|ALPHABETIC|ALPHABETIC-LOWER|ALPHABETIC-UPPER)$',
        upper
    )
    if class_match:
        var_part = class_match.group(1)
        class_type = class_match.group(2)
        # Resolve variable — may include subscript or reference modification
        if '(' in var_part and ':' in var_part:
            # Reference modification: WS-FIELD(1:1)
            base = var_part[:var_part.index('(')]
            refmod = var_part[var_part.index('(') + 1:var_part.rindex(')')]
            parts = refmod.split(':')
            py_base = to_python_name(base)
            start_expr = _resolve_value(parts[0].strip(), known_variables, string_vars=string_vars, use_value=True) if parts[0].strip() else "0"
            length_expr = _resolve_value(parts[1].strip(), known_variables, string_vars=string_vars, use_value=True) if len(parts) > 1 and parts[1].strip() else "1"
            accessor = f"str({py_base})[int({start_expr})-1:int({start_expr})-1+int({length_expr})]"
        else:
            # Plain variable (possibly subscripted or unknown)
            base_name = re.sub(r'\([^)]*\)', '', var_part).strip()
            matched = next((v for v in known_variables if v.upper() == base_name.upper()), None)
            py_name = to_python_name(matched or base_name)
            is_str = _is_string_operand(base_name, string_vars) if matched else False
            accessor = py_name if is_str else f"str({py_name}.value)"
        if class_type == "NUMERIC":
            result = f"{accessor}.replace('.','').replace('-','').isdigit()"
        elif class_type == "ALPHABETIC":
            result = f"{accessor}.replace(' ','').isalpha()"
        elif class_type == "ALPHABETIC-LOWER":
            result = f"{accessor}.replace(' ','').isalpha() and {accessor}.replace(' ','').islower()"
        else:  # ALPHABETIC-UPPER
            result = f"{accessor}.replace(' ','').isalpha() and {accessor}.replace(' ','').isupper()"
        if negated:
            result = f"not ({result})"
        return result, issues

    # Comparison operators (check multi-char first)
    for op_cobol, op_python in [(">=", " >= "), ("<=", " <= "), (">", " > "), ("<", " < "), ("=", " == ")]:
        idx = upper.find(op_cobol)
        if idx > 0:
            left = condition_text[:idx]
            right = condition_text[idx + len(op_cobol):]
            right_upper = right.upper()

            # Check if right operand contains OR/AND + 88-level (compound condition)
            # e.g., "WS-SDN-COUNTORWS-IS-MATCH" → split into comparison + 88-level
            _compound_right = None
            for _conn in ("OR", "AND"):
                for _88name in level_88_map:
                    suffix = _conn + _88name
                    if right_upper.endswith(suffix):
                        actual_right = right[:len(right) - len(suffix)]
                        # EBCDIC-aware ordering for string operands
                        if string_vars and op_cobol != "=" and _is_string_operand(left, string_vars):
                            py_left_c = _resolve_value(left, known_variables)
                            py_right_c = _resolve_value(actual_right, known_variables)
                            ebcdic_op = {">": " > 0", "<": " < 0", ">=": " >= 0", "<=": " <= 0"}[op_cobol]
                            cmp_expr = f"ebcdic_compare({py_left_c}, {py_right_c}, _CODEPAGE){ebcdic_op}"
                        else:
                            py_left_c = _resolve_value(left, known_variables, string_vars=string_vars, use_value=True)
                            py_right_c = _resolve_value(actual_right, known_variables, string_vars=string_vars, use_value=True)
                            cmp_expr = f"{py_left_c}{op_python}{py_right_c}"
                        _88_expr, _88_issues = _emit_88_condition(level_88_map[_88name], string_vars)
                        issues.extend(_88_issues)
                        py_conn = " or " if _conn == "OR" else " and "
                        _compound_right = f"({cmp_expr}{py_conn}{_88_expr})"
                        if negated:
                            _compound_right = f"not {_compound_right}"
                        break
                if _compound_right:
                    break
            if _compound_right:
                return _compound_right, issues

            # Use .value for numeric CobolDecimal variables
            py_left = _resolve_value(left, known_variables, string_vars=string_vars, use_value=True)
            py_right = _resolve_value(right, known_variables, string_vars=string_vars, use_value=True)

            # EBCDIC-aware ordering for PIC X/A fields
            if string_vars and op_cobol != "=" and _is_string_operand(left, string_vars):
                # String vars don't use .value — strip it if added
                py_left_str = _resolve_value(left, known_variables)
                py_right_str = _resolve_value(right, known_variables)
                ebcdic_op = {">": " > 0", "<": " < 0", ">=": " >= 0", "<=": " <= 0"}[op_cobol]
                result = f"ebcdic_compare({py_left_str}, {py_right_str}, _CODEPAGE){ebcdic_op}"
            else:
                result = f"{py_left}{op_python}{py_right}"

            if negated:
                result = f"not ({result})"
            return result, issues

    # Can't parse — be honest
    issues.append({
        "cobol": condition_text,
        "python": f"# MANUAL REVIEW: {condition_text[:60]}",
        "status": "fail",
        "reason": "Unparseable condition",
    })
    return f"True  # MANUAL REVIEW: {condition_text[:60]}", issues


def _tokenize_expression(expr_text, known_variables, string_vars=None):
    """Tokenize a COBOL expression into Python with Decimal wrapping.

    Numeric variables get .value appended for CobolDecimal compatibility.
    """
    if string_vars is None:
        string_vars = set()
    tokens = []
    i = 0
    text = expr_text

    while i < len(text):
        if text[i].isspace():
            i += 1
            continue

        # Exponentiation **
        if text[i] == '*' and i + 1 < len(text) and text[i + 1] == '*':
            tokens.append(" ** ")
            i += 2
            continue

        # Operators, parens, and commas
        if text[i] in "*/+(),":
            tokens.append(f" {text[i]} " if text[i] in "*/+" else (", " if text[i] == "," else text[i]))
            i += 1
            continue

        # Numeric literal
        if text[i].isdigit():
            j = i
            while j < len(text) and (text[j].isdigit() or text[j] == '.'):
                j += 1
            tokens.append(f"Decimal('{text[i:j]}')")
            i = j
            continue

        # FUNCTION keyword — dispatch to intrinsic function
        if text[i:i + 8].upper() == "FUNCTION":
            i += 8
            while i < len(text) and text[i].isspace():
                i += 1
            j = i
            while j < len(text) and (text[j].isalnum() or text[j] == '-'):
                j += 1
            func_name = text[i:j].upper()
            i = j
            if func_name == "INTEGER":
                tokens.append("int")
            elif func_name == "LENGTH":
                tokens.append("_cobol_length")
            elif func_name == "MAX":
                tokens.append("_cobol_max")
            elif func_name == "MIN":
                tokens.append("_cobol_min")
            elif func_name == "ABS":
                tokens.append("_cobol_abs")
            elif func_name == "MOD":
                tokens.append("_cobol_mod")
            elif func_name in ("UPPER-CASE", "UPPER"):
                tokens.append("_cobol_upper")
            elif func_name in ("LOWER-CASE", "LOWER"):
                tokens.append("_cobol_lower")
            elif func_name == "TRIM":
                tokens.append("_cobol_trim")
            elif func_name == "REVERSE":
                tokens.append("_cobol_reverse")
            elif func_name == "ORD":
                tokens.append("_cobol_ord")
            elif func_name in ("CURRENT-DATE", "CURRENT"):
                tokens.append("_cobol_current_date()")
            else:
                tokens.append(f"_cobol_unknown_func('{func_name}')")
            continue

        # Variable name: match longest known variable first
        if text[i].isalpha():
            best_match = None
            for var in known_variables:
                end = i + len(var)
                if end <= len(text) and text[i:end].upper() == var.upper():
                    if best_match is None or len(var) > len(best_match):
                        best_match = var

            if best_match:
                py_name = to_python_name(best_match)
                i += len(best_match)
                # Check for OF qualifier: VAR OF GROUP → qualified name
                if i + 2 < len(text) and text[i:i+2].upper() == "OF":
                    of_pos = i + 2
                    group_match = None
                    for var in known_variables:
                        vlen = len(var)
                        if of_pos + vlen <= len(text) and text[of_pos:of_pos+vlen].upper() == var.upper():
                            if group_match is None or vlen > len(group_match):
                                group_match = var
                    if group_match:
                        qkey = f"{group_match}__{best_match}"
                        if qkey.upper() in {k.upper() for k in known_variables}:
                            py_name = to_python_name(qkey)
                            i = of_pos + len(group_match)
                # Check for subscript: VAR(INDEX)
                if i < len(text) and text[i] == '(':
                    close = text.find(')', i)
                    if close > i:
                        subscript = text[i + 1:close]
                        idx_expr = _subscript_index(subscript, known_variables, string_vars)
                        py_name = f"{py_name}[{idx_expr}]"
                        i = close + 1
                if not _is_string_operand(best_match, string_vars):
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

        # Minus sign — if we reach here, it's subtraction (variable names
        # already consumed their hyphens via longest-match above)
        if text[i] == '-':
            tokens.append(" - ")
            i += 1
            continue

        i += 1

    result = "".join(tokens)
    return re.sub(r'\s+', ' ', result).strip()


def _convert_move(stmt_text, known_variables, string_vars=None):
    """Convert MOVE value TO target. Uses .store() for numeric CobolDecimal targets."""
    issues = []
    upper = stmt_text.upper()

    if not upper.startswith("MOVE"):
        return None, [{"cobol": stmt_text[:60], "python": "", "status": "fail", "reason": "Not a MOVE"}]

    remainder = stmt_text[4:]
    target, source = _find_variable_at_end(remainder, known_variables, "TO")

    if target is None:
        # Fallback regex: also match subscripted targets like VAR(IDX)
        match = re.match(r'(.+?)TO([A-Z][A-Z0-9\-]+(?:\([A-Z0-9\-]+\))?)$', remainder, re.IGNORECASE)
        if match:
            source = match.group(1)
            target = match.group(2)
        else:
            issues.append({"cobol": stmt_text[:60], "python": "# MANUAL REVIEW", "status": "fail", "reason": "Cannot parse MOVE target"})
            return f"# MANUAL REVIEW: {stmt_text[:60]}", issues

    from verb_handlers import emit_move_single

    is_string_target = _is_string_operand(target, string_vars)
    py_value = _resolve_value(source, known_variables, string_vars=string_vars, use_value=not is_string_target)

    # Handle subscripted target: VAR(IDX) → var[idx]
    sub_target, base_var = _resolve_subscripted_name(target, known_variables, string_vars)
    py_target = sub_target if sub_target else to_python_name(target)

    code, move_issues = emit_move_single(py_value, py_target, is_string_target, indent="")
    issues.extend(move_issues)
    return code, issues



# _convert_compute and _convert_add deleted — now delegated to
# parse_compute() and parse_arithmetic('ADD') from generate_full_python.py
# (same pattern as SUBTRACT/MULTIPLY/DIVIDE delegation)


# ── Inline PERFORM VARYING body splitter ──────────────────────────
# COBOL verb keywords that can start a body statement inside an
# inline PERFORM VARYING.  Ordered longest-first so short verbs
# (IF, GO, ADD, SET) don't shadow longer matches.
_PERFORM_BODY_VERBS = [
    'INITIALIZE', 'UNSTRING', 'SUBTRACT', 'MULTIPLY', 'EVALUATE',
    'INSPECT', 'COMPUTE', 'DISPLAY', 'PERFORM', 'DIVIDE', 'STRING',
    'SEARCH', 'WRITE', 'CLOSE', 'MOVE', 'CALL', 'READ', 'OPEN',
    'SORT', 'STOP', 'EXIT', 'ADD', 'SET', 'GOTO', 'IF',
]


def _split_inline_perform_body(text):
    """Split PERFORM VARYING UNTIL text into (condition, body_text).

    When PERFORM VARYING appears inside IF/EVALUATE branches, ANTLR getText()
    concatenates the UNTIL condition with the loop body and END-PERFORM.
    Example: "WS-IDX>8ADDWS-XTOWS-YEND-PERFORM" -> ("WS-IDX>8", "ADDWS-XTOWS-Y")

    Returns (condition_text, body_text) where body_text is "" if no inline body.
    """
    upper = text.upper().strip()
    original = text.strip()

    # No END-PERFORM at end -> no inline body
    if not upper.endswith('END-PERFORM'):
        return original, ""

    # Strip END-PERFORM, also handle nested END-IF/END-EVALUATE before it
    trimmed = original[:-len('END-PERFORM')]
    upper_trimmed = upper[:-len('END-PERFORM')]

    if not trimmed:
        return "", ""

    # Find where UNTIL condition ends and body statements begin.
    # In getText() blobs variable names preserve hyphens (WS-FOO-BAR)
    # but tokens are concatenated without spaces.
    # Rule: a body verb is NOT preceded by '-' and NOT followed by '-'.
    best_pos = len(upper_trimmed)

    for verb in _PERFORM_BODY_VERBS:
        pos = 2  # Need at least some condition text
        while pos < best_pos:
            idx = upper_trimmed.find(verb, pos)
            if idx < 0 or idx >= best_pos:
                break
            # Not preceded by hyphen (would be part of variable name)
            if idx > 0 and upper_trimmed[idx - 1] == '-':
                pos = idx + len(verb)
                continue
            # Not followed by hyphen (would be variable name component)
            end = idx + len(verb)
            if end < len(upper_trimmed) and upper_trimmed[end] == '-':
                pos = idx + len(verb)
                continue
            best_pos = idx
            break

    if best_pos < len(upper_trimmed):
        return trimmed[:best_pos], trimmed[best_pos:]
    else:
        return trimmed, ""


def _split_body_at_verbs(text):
    """Split concatenated getText() body into individual COBOL statements.

    When a getText() blob contains multiple statements (e.g. two MOVEs
    concatenated without spaces), this splits them at verb boundaries.
    Uses the same hyphen-boundary check as _split_inline_perform_body
    to avoid splitting variable names like WS-MOVE-FLAG.
    """
    upper = text.upper()
    if len(upper) < 4:
        return [text]
    positions = [0]
    for verb in _PERFORM_BODY_VERBS:
        pos = 1  # skip first char to keep leading verb
        while pos < len(upper):
            idx = upper.find(verb, pos)
            if idx < 0:
                break
            # Not preceded by hyphen (would be part of variable name)
            if idx > 0 and upper[idx - 1] == '-':
                pos = idx + len(verb)
                continue
            # Not followed by hyphen
            end = idx + len(verb)
            if end < len(upper) and upper[end] == '-':
                pos = idx + len(verb)
                continue
            positions.append(idx)
            pos = idx + len(verb)
    positions = sorted(set(positions))
    if len(positions) <= 1:
        return [text]
    stmts = []
    for i in range(len(positions)):
        start = positions[i]
        end = positions[i + 1] if i + 1 < len(positions) else len(text)
        chunk = text[start:end].strip()
        if chunk:
            stmts.append(chunk)
    return stmts


def _convert_single_statement(stmt_text, known_variables, level_88_map, all_conditions_by_text, indent_level, string_vars=None, all_evaluates_by_text=None, all_strings_by_text=None, thru_paras=None):
    """Convert a single COBOL statement to Python. Dispatches by type."""
    issues = []
    upper = stmt_text.upper()
    indent = "    " * indent_level
    if all_evaluates_by_text is None:
        all_evaluates_by_text = {}
    if all_strings_by_text is None:
        all_strings_by_text = {}

    # Nested EVALUATE — look up structured data
    if upper.startswith("EVALUATE"):
        structured = all_evaluates_by_text.get(stmt_text)
        if structured:
            code, sub_issues = parse_evaluate_statement(
                structured, known_variables, level_88_map,
                string_vars=string_vars,
                all_evaluates_by_text=all_evaluates_by_text,
                all_strings_by_text=all_strings_by_text,
            )
            issues.extend(sub_issues)
            # Re-indent: parse_evaluate_statement emits at indent 0
            indented = "\n".join(
                f"{indent}{line}" if line.strip() else line
                for line in code.split("\n")
            )
            return indented, issues
        else:
            issues.append({
                "cobol": stmt_text[:60],
                "python": "# MANUAL REVIEW: Nested EVALUATE",
                "status": "fail",
                "reason": "Nested EVALUATE without structured data",
            })
            return f"{indent}# MANUAL REVIEW: Nested EVALUATE\n{indent}# {stmt_text[:60]}\n{indent}pass", issues

    # Nested IF — look up structured data (exact match first, then prefix match)
    if upper.startswith("IF"):
        structured = all_conditions_by_text.get(stmt_text)
        if not structured:
            # Prefix match: when verb splitting truncates IF...END-IF blocks,
            # the fragment starts with the IF condition but lacks the full body.
            # Find the structured condition whose getText() starts with this fragment.
            for _ck, _cv in all_conditions_by_text.items():
                if _ck.startswith(stmt_text) and len(_ck) > len(stmt_text):
                    structured = _cv
                    break
        if structured:
            if indent_level > 50:
                return f"{'    ' * indent_level}# MANUAL REVIEW: IF nesting exceeds 50 levels\n{'    ' * indent_level}pass", issues
            code, sub_issues = _convert_if_block(
                structured, known_variables, level_88_map,
                all_conditions_by_text, indent_level, string_vars=string_vars,
                all_evaluates_by_text=all_evaluates_by_text,
                all_strings_by_text=all_strings_by_text,
            )
            issues.extend(sub_issues)
            return code, issues
        else:
            # Fallback: attempt text-based parsing from getText() blob
            # Pattern: IF<condition><body>END-IF or IF<condition><body>ELSE<body>END-IF
            if_text_match = re.match(r'IF(.+?)(?:ELSE(.+?))?END-IF$', stmt_text, re.IGNORECASE)
            if if_text_match:
                cond_and_then = if_text_match.group(1)
                else_body = if_text_match.group(2)
                # Split condition from then-body: find first verb boundary
                _VERBS = ("MOVE", "COMPUTE", "ADD", "SUBTRACT", "MULTIPLY", "DIVIDE",
                          "PERFORM", "DISPLAY", "SET", "INITIALIZE", "GO", "STOP",
                          "STRING", "UNSTRING", "INSPECT", "IF", "EVALUATE",
                          "OPEN", "READ", "WRITE", "CLOSE", "ACCEPT", "CONTINUE")
                cond_text = cond_and_then
                then_body = None
                for verb in _VERBS:
                    idx = cond_and_then.upper().find(verb)
                    if idx > 0:
                        # Check it's a verb boundary (not part of a variable name)
                        pre = cond_and_then[idx - 1] if idx > 0 else ' '
                        if pre.isalpha() or pre == '-':
                            continue
                        cond_text = cond_and_then[:idx]
                        then_body = cond_and_then[idx:]
                        break
                py_cond, cond_issues = _convert_condition(cond_text, known_variables, level_88_map, string_vars=string_vars)
                issues.extend(cond_issues)
                if '#' in py_cond:
                    clean_cond = py_cond[:py_cond.index('#')].strip()
                    mr_comment = py_cond[py_cond.index('#'):]
                    lines = [f"{indent}{mr_comment}"]
                    py_cond = clean_cond
                else:
                    lines = []
                lines.append(f"{indent}if {py_cond}:")
                if then_body:
                    for sub_stmt in _split_body_at_verbs(then_body):
                        then_code, then_issues = _convert_single_statement(
                            sub_stmt, known_variables, level_88_map,
                            all_conditions_by_text, indent_level + 1, string_vars=string_vars,
                            all_evaluates_by_text=all_evaluates_by_text,
                            all_strings_by_text=all_strings_by_text,
                        )
                        issues.extend(then_issues)
                        lines.append(then_code)
                else:
                    lines.append(f"{indent}    pass")
                if else_body:
                    lines.append(f"{indent}else:")
                    for sub_stmt in _split_body_at_verbs(else_body):
                        else_code, else_issues = _convert_single_statement(
                            sub_stmt, known_variables, level_88_map,
                            all_conditions_by_text, indent_level + 1, string_vars=string_vars,
                            all_evaluates_by_text=all_evaluates_by_text,
                            all_strings_by_text=all_strings_by_text,
                        )
                        issues.extend(else_issues)
                        lines.append(else_code)
                return "\n".join(lines), issues

            # Truly unparseable nested IF
            issues.append({
                "cobol": stmt_text[:60],
                "python": "# MANUAL REVIEW: Nested IF",
                "status": "fail",
                "reason": "Nested IF without structured data",
            })
            return f"{indent}# MANUAL REVIEW: Nested IF\n{indent}# {stmt_text[:60]}\n{indent}pass", issues

    # MOVE
    if upper.startswith("MOVE"):
        code, move_issues = _convert_move(stmt_text, known_variables, string_vars=string_vars)
        issues.extend(move_issues)
        if code:
            return f"{indent}{code}", issues

    # COMPUTE — delegate to parse_compute in generate_full_python
    if upper.startswith("COMPUTE"):
        from generate_full_python import parse_compute
        result = parse_compute(stmt_text, known_variables, string_vars=string_vars)
        if result:
            lines = result.split("\n")
            code = "\n".join(f"{indent}{line}" for line in lines)
            return code, issues
        else:
            issues.append({
                "cobol": stmt_text[:60],
                "python": "# MANUAL REVIEW",
                "status": "fail",
                "reason": "Cannot parse COMPUTE",
            })
            return f"{indent}# MANUAL REVIEW: {stmt_text[:60]}\n{indent}pass", issues

    # ADD / SUBTRACT / MULTIPLY / DIVIDE — delegate to parse_arithmetic in generate_full_python
    for arith_verb in ("ADD", "SUBTRACT", "MULTIPLY", "DIVIDE"):
        if upper.startswith(arith_verb):
            from generate_full_python import parse_arithmetic
            result = parse_arithmetic(arith_verb, stmt_text, known_variables, string_vars=string_vars)
            if result:
                lines = result.split("\n")
                code = "\n".join(f"{indent}{line}" for line in lines)
                return code, issues
            else:
                issues.append({
                    "cobol": stmt_text[:60],
                    "python": "# MANUAL REVIEW",
                    "status": "fail",
                    "reason": f"Cannot parse {arith_verb}",
                })
                return f"{indent}# MANUAL REVIEW: {stmt_text[:60]}\n{indent}pass", issues

    # PERFORM VARYING — must come before simple PERFORM
    if "VARYING" in upper and upper.startswith("PERFORM"):
        vary_match = re.match(
            r'PERFORM(.*?)VARYING(.+?)FROM(.+?)BY(.+?)UNTIL(.+)',
            stmt_text, re.IGNORECASE
        )
        if vary_match:
            target_para = vary_match.group(1).strip()
            varying_var = vary_match.group(2).strip()
            from_val_text = vary_match.group(3).strip()
            by_val_text = vary_match.group(4).strip()
            until_raw = vary_match.group(5).strip()

            # Split inline body from UNTIL condition (handles END-PERFORM)
            until_cond_text, body_text = _split_inline_perform_body(until_raw)

            py_var = to_python_name(varying_var)
            py_from = _resolve_value(from_val_text, known_variables, string_vars=string_vars, use_value=False)
            py_by = _resolve_value(by_val_text, known_variables, string_vars=string_vars, use_value=True)
            py_until = _convert_condition(until_cond_text, known_variables, level_88_map, string_vars=string_vars)[0]

            result_lines = []
            result_lines.append(f"{indent}{py_var}.store({py_from})")
            result_lines.append(f"{indent}while not ({py_until}):")

            if body_text:
                # Inline PERFORM VARYING with body — emit via recursive dispatch
                body_code, body_issues = _convert_single_statement(
                    body_text, known_variables, level_88_map,
                    all_conditions_by_text, indent_level + 1,
                    string_vars=string_vars,
                    all_evaluates_by_text=all_evaluates_by_text,
                    all_strings_by_text=all_strings_by_text,
                    thru_paras=thru_paras,
                )
                # Validate: compile-check the body (preserve relative indentation)
                try:
                    _blines = [l for l in body_code.split("\n") if l.strip()]
                    _min_indent = min((len(l) - len(l.lstrip()) for l in _blines), default=0)
                    _test = "\n".join("    " + l[_min_indent:] for l in _blines)
                    compile(f"def _t():\n{_test}\n", "<inline-pv>", "exec")
                    issues.extend(body_issues)
                    for line in body_code.split("\n"):
                        result_lines.append(line)
                except SyntaxError:
                    # Body produced invalid Python — try splitting on verb boundaries
                    _SPLIT_VERBS = ("MOVE", "COMPUTE", "ADD", "SUBTRACT", "MULTIPLY", "DIVIDE",
                                    "PERFORM", "DISPLAY", "SET", "INITIALIZE", "GO", "STOP",
                                    "STRING", "UNSTRING", "INSPECT", "IF", "EVALUATE",
                                    "OPEN", "READ", "WRITE", "CLOSE", "ACCEPT", "CONTINUE")
                    body_upper = body_text.upper()
                    split_points = [0]
                    for verb in _SPLIT_VERBS:
                        pos = 0
                        while True:
                            idx = body_upper.find(verb, pos)
                            if idx < 0:
                                break
                            if idx > 0 and (body_upper[idx - 1].isalpha() or body_upper[idx - 1] == '-'):
                                pos = idx + 1
                                continue
                            if idx not in split_points:
                                split_points.append(idx)
                            pos = idx + 1
                    split_points.sort()
                    stmts = []
                    for si in range(len(split_points)):
                        start = split_points[si]
                        end = split_points[si + 1] if si + 1 < len(split_points) else len(body_text)
                        chunk = body_text[start:end].strip()
                        if chunk:
                            stmts.append(chunk)

                    if len(stmts) > 1:
                        any_ok = False
                        for st in stmts:
                            sc, si = _convert_single_statement(
                                st, known_variables, level_88_map,
                                all_conditions_by_text, indent_level + 1,
                                string_vars=string_vars,
                                all_evaluates_by_text=all_evaluates_by_text,
                                all_strings_by_text=all_strings_by_text,
                                thru_paras=thru_paras,
                            )
                            issues.extend(si)
                            for line in sc.split("\n"):
                                result_lines.append(line)
                            any_ok = True
                        if not any_ok:
                            result_lines.append(f"{indent}    pass  # MANUAL REVIEW: inline PERFORM VARYING body")
                    else:
                        issues.append({
                            "cobol": body_text[:60],
                            "python": "# MANUAL REVIEW",
                            "status": "fail",
                            "reason": "Inline PERFORM VARYING body (multi-statement)",
                        })
                        result_lines.append(f"{indent}    pass  # MANUAL REVIEW: inline PERFORM VARYING body")
            elif target_para:
                py_target = "para_" + to_python_name(target_para)
                result_lines.append(f"{indent}    {py_target}()")
            else:
                result_lines.append(f"{indent}    pass")
            result_lines.append(f"{indent}    {py_var}.store({py_var}.value + {py_by})")
            return "\n".join(result_lines), issues
        # If regex fails, fall through to simple PERFORM

    # PERFORM (getText blob: "PERFORM1000-INIT-CALCULATION")
    if upper.startswith("PERFORM"):
        from verb_handlers import emit_simple_perform
        target_name = stmt_text[7:]
        code, _ = emit_simple_perform(target_name, indent)
        return code, issues

    # GO TO (getText blob: "GOTOCALC-SIMPLE")
    if upper.startswith("GOTO"):
        target_name = stmt_text[4:]
        if thru_paras:
            # GO TO inside THRU range — set flag instead of calling target
            target_in_range = target_name.upper() in {p.upper() for p in thru_paras}
            code_lines = [f"{indent}_thru_goto = '{target_name}'"]
            if not target_in_range:
                tf = "para_" + to_python_name(target_name)
                code_lines.append(f"{indent}{tf}()  # GO TO {target_name} (outside THRU range)")
            code_lines.append(f"{indent}return")
            return "\n".join(code_lines), issues
        from verb_handlers import emit_goto
        code, _ = emit_goto(target_name, indent)
        return code, issues

    # INITIALIZE — set field(s) to default values
    if upper.startswith("INITIALIZE"):
        from verb_handlers import emit_initialize_single
        var_name = stmt_text[10:]
        is_str = bool(string_vars and var_name.upper() in {v.upper() for v in string_vars})
        code, _ = emit_initialize_single(var_name, is_str, indent)
        return code, issues

    # DISPLAY — console output, no data flow impact
    if upper.startswith("DISPLAY"):
        from verb_handlers import emit_display
        rest = stmt_text[7:].strip() if len(stmt_text) > 7 else ""
        # Tokenize getText() blob into operand list for shared handler
        operands = []
        remaining = rest
        while remaining:
            if remaining.startswith("'") or remaining.startswith('"'):
                quote = remaining[0]
                end = remaining.find(quote, 1)
                if end > 0:
                    operands.append(remaining[:end+1])
                    remaining = remaining[end+1:]
                    continue
            m = re.match(r'([A-Z][A-Z0-9\-]*)', remaining, re.IGNORECASE)
            if m:
                operands.append(m.group(1))
                remaining = remaining[m.end():]
                continue
            remaining = remaining[1:]
        code, _ = emit_display(operands, known_variables, string_vars, indent)
        return code, issues

    # ACCEPT FROM DATE/TIME/DAY — deterministic placeholder
    if upper.startswith("ACCEPT"):
        from verb_handlers import emit_accept
        rest = upper[6:]  # strip ACCEPT
        accept_type = None
        if "FROM" in rest:
            from_part = rest[rest.index("FROM") + 4:]
            if "YYYYMMDD" in from_part:
                accept_type = "DATE_YYYYMMDD"
            elif "YYYYDDD" in from_part:
                accept_type = "DAY_YYYYDDD"
            elif "DAYOFWEEK" in from_part or "DAY-OF-WEEK" in from_part:
                accept_type = "DAY_OF_WEEK"
            elif "DAY" in from_part:
                accept_type = "DAY"
            elif "TIME" in from_part:
                accept_type = "TIME"
            elif "DATE" in from_part:
                accept_type = "DATE"
        if accept_type:
            orig_target = stmt_text[6:stmt_text.upper().index("FROM")].strip()
            py_target = to_python_name(orig_target)
            is_string = bool(string_vars and orig_target.upper() in {v.upper() for v in string_vars})
            code, _ = emit_accept(py_target, accept_type, is_string, indent)
            return code, issues

    # SET condition-name TO TRUE
    if upper.startswith("SET") and "TRUE" in upper:
        from verb_handlers import emit_set_true
        # Parse: SET<cond-name>TOTRUE
        inner = upper[3:]  # strip SET
        if inner.endswith("TOTRUE"):
            cond_name = inner[:-6]  # strip TOTRUE
        elif inner.endswith("TO TRUE"):
            cond_name = inner[:-7]
        else:
            cond_name = inner
        cond_name = cond_name.strip()
        code, _ = emit_set_true(cond_name, level_88_map, string_vars, indent)
        if code:
            return code, issues

    # CALL — subprogram invocation (not analyzed → MANUAL REVIEW)
    if upper.startswith("CALL"):
        rest = stmt_text[4:].strip().strip("'\"")
        return f"{indent}# MANUAL REVIEW: CALL {rest} — subprogram not analyzed\n{indent}pass", issues

    # CANCEL — release subprogram (not tracked → MANUAL REVIEW)
    if upper.startswith("CANCEL"):
        rest = stmt_text[6:].strip().strip("'\"")
        return f"{indent}# MANUAL REVIEW: CANCEL {rest} — subprogram state not tracked\n{indent}pass", issues

    # STOP RUN
    if "STOPRUN" in upper.replace(" ", ""):
        from verb_handlers import emit_stop_run
        code, _ = emit_stop_run(indent)
        return code, issues

    # EXIT PROGRAM
    if "EXITPROGRAM" in upper.replace(" ", ""):
        from verb_handlers import emit_exit_program
        code, _ = emit_exit_program(indent)
        return code, issues

    # GOBACK
    if upper.startswith("GOBACK"):
        from verb_handlers import emit_goback
        code, _ = emit_goback(indent)
        return code, issues

    # STRING — lookup structured data
    if upper.startswith("STRING"):
        structured = all_strings_by_text.get(stmt_text)
        if structured:
            has_pointer = structured.get("has_pointer", False)
            has_overflow = structured.get("has_overflow", False)
            sources = structured.get("sources", [])
            target = structured.get("target")

            py_target = to_python_name(target)
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
                ptr_var = structured.get("pointer_var")
                py_ptr = to_python_name(ptr_var)
                lines = []
                lines.append(f"{indent}_concat = {concat_expr}")
                lines.append(f"{indent}_pos = int({py_ptr}.value) - 1")
                lines.append(f"{indent}{py_target} = str({py_target})[:_pos] + _concat + str({py_target})[_pos + len(_concat):]")
                lines.append(f"{indent}{py_ptr}.store(Decimal(str(_pos + 1 + len(_concat))))")
                if has_overflow:
                    lines.append(f"{indent}# WARNING: STRING ON OVERFLOW/NOT ON OVERFLOW body statements are skipped.")
                    lines.append(f"{indent}# If overflow branches modify data fields, results may differ.")
                return "\n".join(lines), issues
            else:
                code = f"{indent}{py_target} = {concat_expr}"
                if has_overflow:
                    code += f"\n{indent}# WARNING: STRING ON OVERFLOW/NOT ON OVERFLOW body statements are skipped."
                    code += f"\n{indent}# If overflow branches modify data fields, results may differ."
                return code, issues
        # No structured data — fall through to unknown

    # ── FILE I/O verbs in branches ─────────────────────────────
    # OPEN I-O / INPUT / OUTPUT
    if upper.startswith("OPEN"):
        from verb_handlers import emit_file_open
        rest = upper[4:]
        if rest.startswith("I-O"):
            fm = re.match(r'([A-Z][A-Z0-9-]*)', rest[3:])
            if fm:
                code, _ = emit_file_open(fm.group(1), 'rw', indent)
                return code, issues
        elif rest.startswith("INPUT"):
            fm = re.match(r'([A-Z][A-Z0-9-]*)', rest[5:])
            if fm:
                code, _ = emit_file_open(fm.group(1), 'r', indent)
                return code, issues
        elif rest.startswith("OUTPUT"):
            fm = re.match(r'([A-Z][A-Z0-9-]*)', rest[6:])
            if fm:
                code, _ = emit_file_open(fm.group(1), 'w', indent)
                return code, issues

    # READ [KEY IS] — keep KEY IS inline (not in verb_handlers, unique to parse_conditions)
    if upper.startswith("READ"):
        from verb_handlers import emit_file_read
        rest = upper[4:]
        # getText() strips spaces, so "READ IDX-FILE KEY IS IDX-KEY" becomes
        # "READIDX-FILEKEYISIDX-KEY".  Split on embedded KEYIS if present.
        key_pos = rest.find("KEYIS")
        if key_pos > 0:
            file_name = rest[:key_pos]
            key_rest = rest[key_pos + 5:]
            km = re.match(r'([A-Z][A-Z0-9-]*)', key_rest)
            if km:
                key_name = km.group(1)
                py_key = to_python_name(key_name)
                key_expr = f"{py_key}.value" if key_name in {v.upper() for v in known_variables} else f"'{key_name}'"
                return f"{indent}_record = _io_read_by_key('{file_name}', '{key_name}', str({key_expr}))", issues
        fm = re.match(r'([A-Z][A-Z0-9-]*)', rest)
        if fm:
            file_name = fm.group(1)
            code, _ = emit_file_read(file_name, indent)
            return code, issues

    # REWRITE
    if upper.startswith("REWRITE"):
        from verb_handlers import emit_file_rewrite
        rest = upper[7:]
        fm = re.match(r'([A-Z][A-Z0-9-]*)', rest)
        if fm:
            code, _ = emit_file_rewrite(fm.group(1), indent)
            return code, issues

    # CLOSE
    if upper.startswith("CLOSE"):
        from verb_handlers import emit_file_close
        rest = upper[5:]
        fm = re.match(r'([A-Z][A-Z0-9-]*)', rest)
        if fm:
            code, _ = emit_file_close(fm.group(1), indent)
            return code, issues

    # WRITE
    if upper.startswith("WRITE"):
        from verb_handlers import emit_file_write
        rest = upper[5:]
        fm = re.match(r'([A-Z][A-Z0-9-]*)', rest)
        if fm:
            code, _ = emit_file_write(fm.group(1), indent)
            return code, issues

    # CONTINUE — COBOL no-op
    if upper == "CONTINUE":
        return f"{indent}pass  # CONTINUE", issues

    # UNSTRING — simple single-delimiter split in branch
    if upper.startswith("UNSTRING"):
        # Pattern: UNSTRING<src>DELIMITEDBY<delim>INTO<tgt1><tgt2>...
        # getText() strips spaces: UNSTRINGWS-NAMEDELIMITEDBY' 'INTOWS-FIRSTWS-LAST
        unstr_match = re.match(
            r"UNSTRING([A-Z][A-Z0-9\-]+)DELIMITEDBY['\"](.+?)['\"]INTO(.+)",
            upper
        )
        if unstr_match:
            src_name = unstr_match.group(1)
            delimiter = unstr_match.group(2)
            targets_text = unstr_match.group(3)
            # Match target variables from known_variables (longest first)
            targets = []
            remaining = targets_text
            while remaining:
                best = None
                for v in known_variables:
                    if remaining.upper().startswith(v.upper()):
                        if best is None or len(v) > len(best):
                            best = v
                if best:
                    targets.append(best)
                    remaining = remaining[len(best):]
                else:
                    break
            if targets:
                py_src = to_python_name(src_name)
                is_src_str = _is_string_operand(src_name, string_vars)
                src_accessor = py_src if is_src_str else f"str({py_src}.value)"
                lines = [f"{indent}_parts = {src_accessor}.split('{delimiter}')"]
                for i, tgt in enumerate(targets):
                    py_tgt = to_python_name(tgt)
                    is_str = _is_string_operand(tgt, string_vars)
                    if is_str:
                        lines.append(f"{indent}{py_tgt} = _parts[{i}].strip() if len(_parts) > {i} else ''")
                    else:
                        lines.append(f"{indent}{py_tgt}.store(Decimal(_parts[{i}].strip()) if len(_parts) > {i} else Decimal('0'))")
                return "\n".join(lines), issues

    # INSPECT TALLYING FOR ALL — count occurrences in branch
    if upper.startswith("INSPECT"):
        # Pattern 1: quoted literal — INSPECT<src>TALLYING<ctr>FORALL'X'
        tally_match = re.match(
            r"INSPECT([A-Z][A-Z0-9\-]+(?:\([^)]+\))?)TALLYING([A-Z][A-Z0-9\-]+)FORALL['\"](.+?)['\"]",
            upper
        )
        # Pattern 2: variable pattern — INSPECT<src>TALLYING<ctr>FORALL<var>
        if not tally_match:
            tally_match = re.match(
                r"INSPECT([A-Z][A-Z0-9\-]+(?:\([^)]+\))?)TALLYING([A-Z][A-Z0-9\-]+)FORALL([A-Z][A-Z0-9\-]+)$",
                upper
            )
        if tally_match:
            src = tally_match.group(1)
            counter = tally_match.group(2)
            pattern_text = tally_match.group(3)
            # Resolve source (may include subscript)
            if '(' in src:
                base = src[:src.index('(')]
                sub = src[src.index('(') + 1:src.rindex(')')]
                py_sub_idx = to_python_name(sub)
                py_src = f"{to_python_name(base)}[int({py_sub_idx}.value) - 1]"
                is_src_str = _is_string_operand(base, string_vars)
            else:
                py_src = to_python_name(src)
                is_src_str = _is_string_operand(src, string_vars)
            py_counter = to_python_name(counter)
            accessor = f"str({py_src})" if is_src_str else f"str({py_src}.value)" if '.' not in py_src else f"str({py_src})"
            # Resolve pattern: quoted literal or variable reference
            if pattern_text.startswith("'") or pattern_text.startswith('"'):
                pattern_expr = f"'{pattern_text.strip(chr(39)).strip(chr(34))}'"
            else:
                # Variable pattern
                matched_pat = next((v for v in known_variables if v.upper() == pattern_text.upper()), None)
                if matched_pat:
                    py_pat = to_python_name(matched_pat)
                    is_pat_str = _is_string_operand(matched_pat, string_vars)
                    pattern_expr = f"str({py_pat})" if is_pat_str else f"str({py_pat}.value)"
                else:
                    pattern_expr = f"'{pattern_text}'"
            return f"{indent}{py_counter}.store(Decimal(str({accessor}.count({pattern_expr}))))", issues
        # Other INSPECT variants — fall through to unknown

    # Unknown statement — honest output
    issues.append({
        "cobol": stmt_text[:60],
        "python": "# MANUAL REVIEW",
        "status": "warn",
        "reason": "Unhandled statement type",
    })
    return f"{indent}# MANUAL REVIEW: {stmt_text[:60]}\n{indent}pass", issues


def _convert_if_block(condition_data, known_variables, level_88_map, all_conditions_by_text, indent_level=0, string_vars=None, all_evaluates_by_text=None, all_strings_by_text=None, thru_paras=None, _depth=0):
    """Convert a structured IF block to Python if/else."""
    issues = []
    indent = "    " * indent_level
    if _depth > 50:
        return f"{indent}# MANUAL REVIEW: IF nesting exceeds 50 levels\n{indent}pass", issues
    lines = []

    # Condition
    py_cond, cond_issues = _convert_condition(
        condition_data["condition"], known_variables, level_88_map, string_vars=string_vars
    )
    issues.extend(cond_issues)
    # Strip inline comments from condition to avoid broken syntax: if True # ...:
    if '#' in py_cond:
        clean_cond = py_cond[:py_cond.index('#')].strip()
        mr_comment = py_cond[py_cond.index('#'):]
        lines.append(f"{indent}{mr_comment}")
        py_cond = clean_cond
    lines.append(f"{indent}if {py_cond}:")

    # Then branch
    then_stmts = condition_data.get("then_statements", [])
    if then_stmts:
        for stmt in then_stmts:
            code, stmt_issues = _convert_single_statement(
                stmt, known_variables, level_88_map,
                all_conditions_by_text, indent_level + 1, string_vars=string_vars,
                all_evaluates_by_text=all_evaluates_by_text,
                all_strings_by_text=all_strings_by_text,
                thru_paras=thru_paras,
            )
            issues.extend(stmt_issues)
            lines.append(code)
    else:
        lines.append(f"{indent}    pass")

    # Else branch
    else_stmts = condition_data.get("else_statements", [])
    if else_stmts:
        lines.append(f"{indent}else:")
        for stmt in else_stmts:
            code, stmt_issues = _convert_single_statement(
                stmt, known_variables, level_88_map,
                all_conditions_by_text, indent_level + 1, string_vars=string_vars,
                all_evaluates_by_text=all_evaluates_by_text,
                all_strings_by_text=all_strings_by_text,
                thru_paras=thru_paras,
            )
            issues.extend(stmt_issues)
            lines.append(code)

    return "\n".join(lines), issues


def parse_evaluate_statement(eval_data, known_variables, level_88_map, all_conditions=None, string_vars=None, all_evaluates_by_text=None, all_strings_by_text=None):
    """
    Convert EVALUATE/WHEN to Python if/elif/else.

    Returns:
        (python_code: str, issues: list[dict])
    """
    issues = []

    # Build lookups for nested statement resolution (needed by both ALSO and single-subject paths)
    all_conditions_by_text = {}
    if all_conditions:
        for cond in all_conditions:
            all_conditions_by_text[cond["statement"]] = cond
    if all_evaluates_by_text is None:
        all_evaluates_by_text = {}
    if all_strings_by_text is None:
        all_strings_by_text = {}

    # EVALUATE ALSO — multi-subject matching
    if eval_data.get("has_also"):
        subjects = [eval_data.get("subject", "")]
        subjects.extend(eval_data.get("also_subjects", []))

        # Resolve each subject to Python
        py_subjects = []
        subject_is_strings = []
        for subj in subjects:
            is_str = _is_string_operand(subj, string_vars)
            subject_is_strings.append(is_str)
            if is_str:
                py_subjects.append(to_python_name(subj))
            else:
                py_subjects.append(_resolve_value(subj, known_variables, string_vars=string_vars, use_value=True))

        lines = []
        first = True

        for clause in eval_data.get("when_clauses", []):
            conditions = clause.get("conditions", [])
            also_conditions = clause.get("also_conditions", [])
            body_stmts = clause.get("body_statements", [])

            # Build compound condition for this WHEN
            all_parts = []
            for cond_idx, cond_text in enumerate(conditions):
                subject_parts = []

                # First subject's value
                if cond_text.upper() != "ANY":
                    # Check for THRU/THROUGH range (numeric) on first subject
                    _thru0 = re.match(r"^(-?[\d.]+)(?:THRU|THROUGH)(-?[\d.]+)$", cond_text, re.IGNORECASE)
                    if _thru0:
                        low_v = f"Decimal('{_thru0.group(1)}')"
                        high_v = f"Decimal('{_thru0.group(2)}')"
                        subject_parts.append(f"{low_v} <= {py_subjects[0]} <= {high_v}")
                    else:
                        # Check for THRU/THROUGH range (string) on first subject
                        _thru0_s = re.match(r"^'([^']*)'(?:THRU|THROUGH)'([^']*)'$", cond_text, re.IGNORECASE)
                        if _thru0_s:
                            low_v = f'"{_thru0_s.group(1)}"'
                            high_v = f'"{_thru0_s.group(2)}"'
                            if subject_is_strings[0]:
                                subject_parts.append(
                                    f"ebcdic_compare({low_v}, {py_subjects[0]}, _CODEPAGE) <= 0 and "
                                    f"ebcdic_compare({py_subjects[0]}, {high_v}, _CODEPAGE) <= 0"
                                )
                            else:
                                subject_parts.append(f"{low_v} <= {py_subjects[0]} <= {high_v}")
                        else:
                            # Check for THRU/THROUGH range (variable) on first subject
                            _thru0_v = re.match(r"^([A-Z][A-Z0-9\-]*)(?:THRU|THROUGH)([A-Z][A-Z0-9\-]*)$", cond_text, re.IGNORECASE)
                            if _thru0_v:
                                py_low = _resolve_value(_thru0_v.group(1), known_variables, string_vars=string_vars, use_value=True)
                                py_high = _resolve_value(_thru0_v.group(2), known_variables, string_vars=string_vars, use_value=True)
                                if subject_is_strings[0]:
                                    subject_parts.append(
                                        f"ebcdic_compare(str({py_low}), str({py_subjects[0]}), _CODEPAGE) <= 0 and "
                                        f"ebcdic_compare(str({py_subjects[0]}), str({py_high}), _CODEPAGE) <= 0"
                                    )
                                else:
                                    subject_parts.append(f"{py_low} <= {py_subjects[0]} <= {py_high}")
                            else:
                                py_val = _resolve_value(cond_text, known_variables, string_vars=string_vars,
                                                       use_value=not subject_is_strings[0])
                                subject_parts.append(f"{py_subjects[0]} == {py_val}")

                # ALSO subjects' values
                also_vals = also_conditions[cond_idx] if cond_idx < len(also_conditions) else []
                for subj_idx, also_val in enumerate(also_vals):
                    s_idx = subj_idx + 1
                    if s_idx < len(py_subjects) and also_val.upper() != "ANY":
                        # Check for THRU/THROUGH range (numeric)
                        _thru = re.match(r"^(-?[\d.]+)(?:THRU|THROUGH)(-?[\d.]+)$", also_val, re.IGNORECASE)
                        if _thru:
                            low_v = f"Decimal('{_thru.group(1)}')"
                            high_v = f"Decimal('{_thru.group(2)}')"
                            subject_parts.append(f"{low_v} <= {py_subjects[s_idx]} <= {high_v}")
                            continue
                        # Check for THRU/THROUGH range (string)
                        _thru_s = re.match(r"^'([^']+)'(?:THRU|THROUGH)'([^']+)'$", also_val, re.IGNORECASE)
                        if _thru_s:
                            low_v = f'"{_thru_s.group(1)}"'
                            high_v = f'"{_thru_s.group(2)}"'
                            if subject_is_strings[s_idx]:
                                subject_parts.append(
                                    f"ebcdic_compare({low_v}, {py_subjects[s_idx]}, _CODEPAGE) <= 0 and "
                                    f"ebcdic_compare({py_subjects[s_idx]}, {high_v}, _CODEPAGE) <= 0"
                                )
                            else:
                                subject_parts.append(f"{low_v} <= {py_subjects[s_idx]} <= {high_v}")
                            continue
                        # Check for THRU/THROUGH range (variable)
                        _thru_v = re.match(r"^([A-Z][A-Z0-9\-]*)(?:THRU|THROUGH)([A-Z][A-Z0-9\-]*)$", also_val, re.IGNORECASE)
                        if _thru_v:
                            py_low = _resolve_value(_thru_v.group(1), known_variables, string_vars=string_vars, use_value=True)
                            py_high = _resolve_value(_thru_v.group(2), known_variables, string_vars=string_vars, use_value=True)
                            if subject_is_strings[s_idx]:
                                subject_parts.append(
                                    f"ebcdic_compare(str({py_low}), str({py_subjects[s_idx]}), _CODEPAGE) <= 0 and "
                                    f"ebcdic_compare(str({py_subjects[s_idx]}), str({py_high}), _CODEPAGE) <= 0"
                                )
                            else:
                                subject_parts.append(f"{py_low} <= {py_subjects[s_idx]} <= {py_high}")
                            continue
                        py_val = _resolve_value(also_val, known_variables, string_vars=string_vars,
                                               use_value=not subject_is_strings[s_idx])
                        subject_parts.append(f"{py_subjects[s_idx]} == {py_val}")

                if subject_parts:
                    combined = " and ".join(subject_parts)
                    all_parts.append(f"({combined})" if len(subject_parts) > 1 else combined)
                else:
                    all_parts.append("True")  # ALL subjects are ANY

            # Multiple conditions in one WHEN → OR
            combined_cond = " or ".join(all_parts) if len(all_parts) > 1 else all_parts[0]

            keyword = "if" if first else "elif"
            lines.append(f"{keyword} {combined_cond}:")
            first = False

            # Body statements
            if body_stmts:
                for stmt_text in body_stmts:
                    code, stmt_issues = _convert_single_statement(
                        stmt_text, known_variables, level_88_map,
                        all_conditions_by_text, indent_level=1, string_vars=string_vars,
                        all_evaluates_by_text=all_evaluates_by_text,
                        all_strings_by_text=all_strings_by_text,
                    )
                    issues.extend(stmt_issues)
                    lines.append(code)
            else:
                lines.append("    pass")

        # WHEN OTHER → else
        when_other = eval_data.get("when_other_statements", [])
        if when_other:
            lines.append("else:")
            for stmt_text in when_other:
                code, stmt_issues = _convert_single_statement(
                    stmt_text, known_variables, level_88_map,
                    all_conditions_by_text, indent_level=1, string_vars=string_vars,
                    all_evaluates_by_text=all_evaluates_by_text,
                    all_strings_by_text=all_strings_by_text,
                )
                issues.extend(stmt_issues)
                lines.append(code)

        return "\n".join(lines), issues

    subject = eval_data.get("subject", "")
    is_true_mode = subject.upper() == "TRUE"

    # Resolve subject for value-based mode
    if not is_true_mode:
        subject_is_string = _is_string_operand(subject, string_vars)
        if subject_is_string:
            py_subject = to_python_name(subject)
        else:
            py_subject = _resolve_value(subject, known_variables, string_vars=string_vars, use_value=True)

    lines = []
    first = True

    for clause in eval_data.get("when_clauses", []):
        conditions = clause.get("conditions", [])
        body_stmts = clause.get("body_statements", [])

        # Build the condition expression
        if is_true_mode:
            # Each condition is a boolean expression
            parts = []
            for cond_text in conditions:
                py_cond, cond_issues = _convert_condition(
                    cond_text, known_variables, level_88_map, string_vars=string_vars
                )
                issues.extend(cond_issues)
                parts.append(py_cond)
            combined = " or ".join(parts) if len(parts) > 1 else parts[0]
        else:
            # Each condition is a value to compare against subject
            parts = []
            for cond_text in conditions:
                # Check for THRU/THROUGH range: value THRU value
                thru_match = re.match(
                    r"^(-?[\d.]+)(?:THRU|THROUGH)(-?[\d.]+)$", cond_text, re.IGNORECASE
                )
                if not thru_match:
                    thru_match = re.match(
                        r"^'([^']+)'(?:THRU|THROUGH)'([^']+)'$", cond_text, re.IGNORECASE
                    )
                    if thru_match:
                        # String range — EBCDIC collation
                        low_val = f'"{thru_match.group(1)}"'
                        high_val = f'"{thru_match.group(2)}"'
                        if subject_is_string:
                            parts.append(
                                f"ebcdic_compare({low_val}, {py_subject}, _CODEPAGE) <= 0 and "
                                f"ebcdic_compare({py_subject}, {high_val}, _CODEPAGE) <= 0"
                            )
                        else:
                            parts.append(f"{low_val} <= {py_subject} <= {high_val}")
                        continue
                if not thru_match:
                    thru_match = re.match(
                        r"^([A-Z][A-Z0-9\-]*)(?:THRU|THROUGH)([A-Z][A-Z0-9\-]*)$",
                        cond_text, re.IGNORECASE,
                    )
                    if thru_match:
                        # Variable range
                        py_low = _resolve_value(thru_match.group(1), known_variables, string_vars=string_vars, use_value=True)
                        py_high = _resolve_value(thru_match.group(2), known_variables, string_vars=string_vars, use_value=True)
                        if subject_is_string:
                            parts.append(
                                f"ebcdic_compare(str({py_low}), str({py_subject}), _CODEPAGE) <= 0 and "
                                f"ebcdic_compare(str({py_subject}), str({py_high}), _CODEPAGE) <= 0"
                            )
                        else:
                            parts.append(f"{py_low} <= {py_subject} <= {py_high}")
                        continue
                if thru_match:
                    # Numeric range
                    low_val = f"Decimal('{thru_match.group(1)}')"
                    high_val = f"Decimal('{thru_match.group(2)}')"
                    parts.append(f"{low_val} <= {py_subject} <= {high_val}")
                    continue

                # Check for comparison operator prefix: > >= < <=
                op_match = re.match(r'^(>=|<=|>|<)\s*(.+)$', cond_text)
                if op_match:
                    op_sym, operand = op_match.group(1), op_match.group(2).strip()
                    if operand.startswith("'") and operand.endswith("'"):
                        py_val = f'"{operand[1:-1]}"'
                    elif re.match(r'^-?[\d.]+$', operand):
                        py_val = f"Decimal('{operand}')"
                    else:
                        py_val = _resolve_value(operand, known_variables, string_vars=string_vars, use_value=True)
                    # EBCDIC-aware ordering for PIC X subjects
                    if subject_is_string:
                        py_subj_raw = to_python_name(subject)
                        py_val_raw = py_val
                        ebcdic_op = {">": " > 0", "<": " < 0", ">=": " >= 0", "<=": " <= 0"}[op_sym]
                        parts.append(f"ebcdic_compare({py_subj_raw}, {py_val_raw}, _CODEPAGE){ebcdic_op}")
                    else:
                        op_python = {">": " > ", "<": " < ", ">=": " >= ", "<=": " <= "}[op_sym]
                        parts.append(f"{py_subject}{op_python}{py_val}")
                # Strip surrounding quotes for string literals
                elif cond_text.startswith("'") and cond_text.endswith("'"):
                    literal = cond_text[1:-1]
                    parts.append(f'{py_subject} == "{literal}"')
                elif re.match(r'^-?[\d.]+$', cond_text):
                    parts.append(f"{py_subject} == Decimal('{cond_text}')")
                else:
                    # Variable or complex expression
                    py_val = _resolve_value(cond_text, known_variables, string_vars=string_vars, use_value=True)
                    parts.append(f"{py_subject} == {py_val}")
            combined = " or ".join(parts) if len(parts) > 1 else parts[0]

        keyword = "if" if first else "elif"
        # Strip inline comments from condition to avoid broken syntax
        if '#' in combined:
            clean_cond = combined[:combined.index('#')].strip()
            mr_comment = combined[combined.index('#'):]
            lines.append(f"{mr_comment}")
            combined = clean_cond
        lines.append(f"{keyword} {combined}:")
        first = False

        # Body statements
        if body_stmts:
            for stmt_text in body_stmts:
                code, stmt_issues = _convert_single_statement(
                    stmt_text, known_variables, level_88_map,
                    all_conditions_by_text, indent_level=1, string_vars=string_vars,
                    all_evaluates_by_text=all_evaluates_by_text,
                    all_strings_by_text=all_strings_by_text,
                )
                issues.extend(stmt_issues)
                lines.append(code)
        else:
            lines.append("    pass")

    # WHEN OTHER → else
    when_other = eval_data.get("when_other_statements", [])
    if when_other:
        lines.append("else:")
        for stmt_text in when_other:
            code, stmt_issues = _convert_single_statement(
                stmt_text, known_variables, level_88_map,
                all_conditions_by_text, indent_level=1, string_vars=string_vars,
                all_evaluates_by_text=all_evaluates_by_text,
                all_strings_by_text=all_strings_by_text,
            )
            issues.extend(stmt_issues)
            lines.append(code)

    return "\n".join(lines), issues


def parse_if_statement(condition_data, known_variables, level_88_map, all_conditions=None, string_vars=None, all_evaluates=None, all_strings=None, thru_paras=None):
    """
    Main entry point: convert a structured IF condition to Python.

    Args:
        condition_data: dict with keys: condition, then_statements,
                        else_statements, statement, has_nested_if
        known_variables: set of COBOL variable names (uppercase)
        level_88_map: dict mapping 88-level name (uppercase) →
                      {"parent": str, "value": str}
        all_conditions: list of all condition dicts from the analyzer
                        (used for nested IF lookup by statement text)
        string_vars: set of COBOL variable names that are PIC X/A
                     (used for EBCDIC-aware ordering comparisons)
        all_evaluates: list of all evaluate dicts from the analyzer
                       (used for nested EVALUATE lookup by statement text)
        all_strings: list of all string dicts from the analyzer
                     (used for nested STRING lookup by statement text)

    Returns:
        (python_code: str, issues: list[dict])
        Each issue: {"cobol": str, "python": str, "status": "ok"|"warn"|"fail",
                     "reason": str}
    """
    # Build lookup table: statement getText() → structured data
    all_conditions_by_text = {}
    if all_conditions:
        for cond in all_conditions:
            all_conditions_by_text[cond["statement"]] = cond

    all_evaluates_by_text = {}
    if all_evaluates:
        for ev in all_evaluates:
            all_evaluates_by_text[ev["statement"]] = ev

    all_strings_by_text = {}
    if all_strings:
        for s in all_strings:
            all_strings_by_text[s["statement"]] = s

    return _convert_if_block(
        condition_data, known_variables, level_88_map,
        all_conditions_by_text, indent_level=0, string_vars=string_vars,
        all_evaluates_by_text=all_evaluates_by_text,
        all_strings_by_text=all_strings_by_text,
        thru_paras=thru_paras,
    )


# ── Self-test ──────────────────────────────────────────────────

if __name__ == "__main__":
    KNOWN_VARS = {
        "WS-VIP-FLAG", "WS-RATE-DISCOUNT", "WS-DAILY-RATE",
        "WS-DAYS-OVERDUE", "WS-GRACE-PERIOD", "WS-PENALTY-AMOUNT",
        "WS-TEMP-AMOUNT", "WS-PRINCIPAL-BAL", "WS-PENALTY-RATE",
        "WS-MAX-PENALTY-PCT", "WS-ACCRUED-INT",
    }

    L88_MAP = {
        "IS-VIP-ACCOUNT": {"parent": "WS-VIP-FLAG", "value": "Y"},
        "IS-STANDARD": {"parent": "WS-VIP-FLAG", "value": "N"},
    }

    # Test 1: Simple IF with 88-level + MOVE + ELSE
    cond1 = {
        "paragraph": "1000-INIT-CALCULATION",
        "statement": "IFIS-VIP-ACCOUNTMOVE0.0015TOWS-RATE-DISCOUNTELSEMOVE0TOWS-RATE-DISCOUNTEND-IF",
        "condition": "IS-VIP-ACCOUNT",
        "then_statements": ["MOVE0.0015TOWS-RATE-DISCOUNT"],
        "else_statements": ["MOVE0TOWS-RATE-DISCOUNT"],
        "has_nested_if": False,
    }

    # Test 2: Nested IF (88-level + COMPUTE + inner IF)
    inner_if = {
        "paragraph": "3000-APPLY-VIP-DISCOUNT",
        "statement": "IFWS-DAILY-RATE<0MOVE0TOWS-DAILY-RATEEND-IF",
        "condition": "WS-DAILY-RATE<0",
        "then_statements": ["MOVE0TOWS-DAILY-RATE"],
        "else_statements": [],
        "has_nested_if": False,
    }

    cond2 = {
        "paragraph": "3000-APPLY-VIP-DISCOUNT",
        "statement": "IFIS-VIP-ACCOUNTCOMPUTEWS-DAILY-RATE=WS-DAILY-RATE-WS-RATE-DISCOUNTIFWS-DAILY-RATE<0MOVE0TOWS-DAILY-RATEEND-IFEND-IF",
        "condition": "IS-VIP-ACCOUNT",
        "then_statements": [
            "COMPUTEWS-DAILY-RATE=WS-DAILY-RATE-WS-RATE-DISCOUNT",
            "IFWS-DAILY-RATE<0MOVE0TOWS-DAILY-RATEEND-IF",
        ],
        "else_statements": [],
        "has_nested_if": True,
    }

    # Test 3: Complex nested IF/ELSE
    inner_if_penalty = {
        "paragraph": "5000-CHECK-LATE-PENALTY",
        "statement": "IFWS-PENALTY-AMOUNT>WS-TEMP-AMOUNTMOVEWS-TEMP-AMOUNTTOWS-PENALTY-AMOUNTEND-IF",
        "condition": "WS-PENALTY-AMOUNT>WS-TEMP-AMOUNT",
        "then_statements": ["MOVEWS-TEMP-AMOUNTTOWS-PENALTY-AMOUNT"],
        "else_statements": [],
        "has_nested_if": False,
    }
    inner_if_vip = {
        "paragraph": "5000-CHECK-LATE-PENALTY",
        "statement": "IFIS-VIP-ACCOUNTCOMPUTEWS-PENALTY-AMOUNT=WS-PENALTY-AMOUNT*0.5END-IF",
        "condition": "IS-VIP-ACCOUNT",
        "then_statements": ["COMPUTEWS-PENALTY-AMOUNT=WS-PENALTY-AMOUNT*0.5"],
        "else_statements": [],
        "has_nested_if": False,
    }
    cond3 = {
        "paragraph": "5000-CHECK-LATE-PENALTY",
        "statement": "IFWS-DAYS-OVERDUE>WS-GRACE-PERIODCOMPUTE...END-IF",
        "condition": "WS-DAYS-OVERDUE>WS-GRACE-PERIOD",
        "then_statements": [
            "COMPUTEWS-PENALTY-AMOUNT=WS-PRINCIPAL-BAL*WS-PENALTY-RATE*(WS-DAYS-OVERDUE-WS-GRACE-PERIOD)",
            "COMPUTEWS-TEMP-AMOUNT=WS-PRINCIPAL-BAL*WS-MAX-PENALTY-PCT",
            "IFWS-PENALTY-AMOUNT>WS-TEMP-AMOUNTMOVEWS-TEMP-AMOUNTTOWS-PENALTY-AMOUNTEND-IF",
            "IFIS-VIP-ACCOUNTCOMPUTEWS-PENALTY-AMOUNT=WS-PENALTY-AMOUNT*0.5END-IF",
        ],
        "else_statements": ["MOVE0TOWS-PENALTY-AMOUNT"],
        "has_nested_if": True,
    }

    all_conds = [cond1, cond2, inner_if, cond3, inner_if_penalty, inner_if_vip]

    print("=" * 60)
    print("PARSE CONDITIONS — STRUCTURED CONVERSION TEST")
    print("=" * 60)

    for i, cond in enumerate([cond1, cond2, cond3], 1):
        print(f"\n--- Test {i}: {cond['paragraph']} ---")
        code, issues = parse_if_statement(cond, KNOWN_VARS, L88_MAP, all_conds)
        print(code)
        if issues:
            print(f"\n  Issues ({len(issues)}):")
            for iss in issues:
                print(f"    [{iss['status']}] {iss['reason']}: {iss['cobol'][:40]}")
        print()
