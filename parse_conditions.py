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


def _resolve_value(text, known_variables):
    """Resolve a COBOL value to Python — variable name or Decimal literal."""
    text = text.strip()
    upper = text.upper()

    if not text:
        return "None"

    # Numeric literal
    if re.match(r'^-?[\d.]+$', text):
        return f"Decimal('{text}')"

    # Known variable (case-insensitive match)
    for var in known_variables:
        if upper == var.upper():
            return to_python_name(var)

    # Unknown but looks like a COBOL name
    if re.match(r'^[A-Z][A-Z0-9\-]*$', upper):
        return to_python_name(text)

    return text


def _convert_condition(condition_text, known_variables, level_88_map):
    """Convert a COBOL condition to a Python expression."""
    issues = []
    upper = condition_text.upper().strip()

    # 88-level condition lookup
    if upper in level_88_map:
        info = level_88_map[upper]
        py_name = to_python_name(info["parent"])
        value = info["value"]
        return f'{py_name} == "{value}"', issues

    # NOT + 88-level
    if upper.startswith("NOT") and upper[3:] in level_88_map:
        info = level_88_map[upper[3:]]
        py_name = to_python_name(info["parent"])
        value = info["value"]
        return f'{py_name} != "{value}"', issues

    # NOT prefix for other conditions
    negated = False
    if upper.startswith("NOT"):
        negated = True
        condition_text = condition_text[3:]
        upper = upper[3:]

    # Comparison operators (check multi-char first)
    for op_cobol, op_python in [(">=", " >= "), ("<=", " <= "), (">", " > "), ("<", " < "), ("=", " == ")]:
        idx = upper.find(op_cobol)
        if idx > 0:
            left = condition_text[:idx]
            right = condition_text[idx + len(op_cobol):]

            py_left = _resolve_value(left, known_variables)
            py_right = _resolve_value(right, known_variables)

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


def _tokenize_expression(expr_text, known_variables):
    """Tokenize a COBOL expression into Python with Decimal wrapping."""
    tokens = []
    i = 0
    text = expr_text

    while i < len(text):
        if text[i].isspace():
            i += 1
            continue

        # Operators and parens
        if text[i] in "*/+()":
            tokens.append(f" {text[i]} " if text[i] in "*/+" else text[i])
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

        # FUNCTION keyword (skip)
        if text[i:i + 8].upper() == "FUNCTION":
            i += 8
            continue

        # INTEGER function
        if text[i:i + 7].upper() == "INTEGER":
            tokens.append("int")
            i += 7
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
                tokens.append(to_python_name(best_match))
                i += len(best_match)
            else:
                j = i
                while j < len(text) and (text[j].isalnum() or text[j] == '-'):
                    j += 1
                tokens.append(to_python_name(text[i:j]))
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


def _convert_move(stmt_text, known_variables):
    """Convert MOVE value TO target."""
    issues = []
    upper = stmt_text.upper()

    if not upper.startswith("MOVE"):
        return None, [{"cobol": stmt_text[:60], "python": "", "status": "fail", "reason": "Not a MOVE"}]

    remainder = stmt_text[4:]
    target, source = _find_variable_at_end(remainder, known_variables, "TO")

    if target is None:
        # Fallback regex for cases where target isn't in known_variables
        match = re.match(r'(.+?)TO([A-Z][A-Z0-9\-]+)$', remainder, re.IGNORECASE)
        if match:
            source = match.group(1)
            target = match.group(2)
        else:
            issues.append({"cobol": stmt_text[:60], "python": "# MANUAL REVIEW", "status": "fail", "reason": "Cannot parse MOVE target"})
            return f"# MANUAL REVIEW: {stmt_text[:60]}", issues

    py_target = to_python_name(target)
    py_value = _resolve_value(source, known_variables)

    return f"{py_target} = {py_value}", issues


def _convert_compute(stmt_text, known_variables):
    """Convert COMPUTE target = expression."""
    issues = []
    upper = stmt_text.upper()

    if not upper.startswith("COMPUTE"):
        return None, [{"cobol": stmt_text[:60], "python": "", "status": "fail", "reason": "Not a COMPUTE"}]

    remainder = stmt_text[7:]

    if "=" not in remainder:
        issues.append({"cobol": stmt_text[:60], "python": "# MANUAL REVIEW", "status": "fail", "reason": "COMPUTE without ="})
        return f"# MANUAL REVIEW: {stmt_text[:60]}", issues

    eq_idx = remainder.index("=")
    target_str = remainder[:eq_idx]
    expr_str = remainder[eq_idx + 1:]

    py_target = to_python_name(target_str)
    py_expr = _tokenize_expression(expr_str, known_variables)

    return f"{py_target} = {py_expr}", issues


def _convert_add(stmt_text, known_variables):
    """Convert ADD value TO target."""
    issues = []
    upper = stmt_text.upper()

    if not upper.startswith("ADD"):
        return None, [{"cobol": stmt_text[:60], "python": "", "status": "fail", "reason": "Not an ADD"}]

    remainder = stmt_text[3:]
    target, source = _find_variable_at_end(remainder, known_variables, "TO")

    if target is None:
        match = re.match(r'(.+?)TO([A-Z][A-Z0-9\-]+)$', remainder, re.IGNORECASE)
        if match:
            source = match.group(1)
            target = match.group(2)
        else:
            issues.append({"cobol": stmt_text[:60], "python": "# MANUAL REVIEW", "status": "fail", "reason": "Cannot parse ADD"})
            return f"# MANUAL REVIEW: {stmt_text[:60]}", issues

    py_target = to_python_name(target)
    py_value = _resolve_value(source, known_variables)

    return f"{py_target} = {py_target} + {py_value}", issues


def _convert_single_statement(stmt_text, known_variables, level_88_map, all_conditions_by_text, indent_level):
    """Convert a single COBOL statement to Python. Dispatches by type."""
    issues = []
    upper = stmt_text.upper()
    indent = "    " * indent_level

    # Nested IF — look up structured data
    if upper.startswith("IF"):
        structured = all_conditions_by_text.get(stmt_text)
        if structured:
            code, sub_issues = _convert_if_block(
                structured, known_variables, level_88_map,
                all_conditions_by_text, indent_level
            )
            issues.extend(sub_issues)
            return code, issues
        else:
            issues.append({
                "cobol": stmt_text[:60],
                "python": "# MANUAL REVIEW: Nested IF",
                "status": "fail",
                "reason": "Nested IF without structured data",
            })
            return f"{indent}# MANUAL REVIEW: Nested IF\n{indent}# {stmt_text[:60]}", issues

    # MOVE
    if upper.startswith("MOVE"):
        code, move_issues = _convert_move(stmt_text, known_variables)
        issues.extend(move_issues)
        if code:
            return f"{indent}{code}", issues

    # COMPUTE
    if upper.startswith("COMPUTE"):
        code, comp_issues = _convert_compute(stmt_text, known_variables)
        issues.extend(comp_issues)
        if code:
            return f"{indent}{code}", issues

    # ADD
    if upper.startswith("ADD"):
        code, add_issues = _convert_add(stmt_text, known_variables)
        issues.extend(add_issues)
        if code:
            return f"{indent}{code}", issues

    # INITIALIZE
    if upper.startswith("INITIALIZE"):
        var_name = stmt_text[10:]
        return f"{indent}# INITIALIZE {to_python_name(var_name)}", issues

    # STOP RUN
    if "STOPRUN" in upper.replace(" ", ""):
        return f"{indent}return", issues

    # Unknown statement — honest output
    issues.append({
        "cobol": stmt_text[:60],
        "python": "# MANUAL REVIEW",
        "status": "warn",
        "reason": "Unhandled statement type",
    })
    return f"{indent}# MANUAL REVIEW: {stmt_text[:60]}", issues


def _convert_if_block(condition_data, known_variables, level_88_map, all_conditions_by_text, indent_level=0):
    """Convert a structured IF block to Python if/else."""
    issues = []
    indent = "    " * indent_level
    lines = []

    # Condition
    py_cond, cond_issues = _convert_condition(
        condition_data["condition"], known_variables, level_88_map
    )
    issues.extend(cond_issues)
    lines.append(f"{indent}if {py_cond}:")

    # Then branch
    then_stmts = condition_data.get("then_statements", [])
    if then_stmts:
        for stmt in then_stmts:
            code, stmt_issues = _convert_single_statement(
                stmt, known_variables, level_88_map,
                all_conditions_by_text, indent_level + 1
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
                all_conditions_by_text, indent_level + 1
            )
            issues.extend(stmt_issues)
            lines.append(code)

    return "\n".join(lines), issues


def parse_if_statement(condition_data, known_variables, level_88_map, all_conditions=None):
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

    return _convert_if_block(
        condition_data, known_variables, level_88_map,
        all_conditions_by_text, indent_level=0
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
