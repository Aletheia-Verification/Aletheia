import re
from parse_conditions import parse_if_statement, parse_evaluate_statement, _resolve_value, _is_string_operand


def to_python_name(name):
    """WS-DAILY-RATE -> ws_daily_rate"""
    return name.lower().replace("-", "_")


def extract_var_name(raw):
    """Extract clean variable name from raw parser output."""
    match = re.match(r'^\d{2}([A-Z][A-Z0-9\-]+?)(?:PIC|VALUE|\.)', raw.upper())
    if match:
        return match.group(1)
    return None


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


def parse_compute(statement, known_variables, string_vars=None):
    """Turn COBOL COMPUTE getText() blob into Python assignment.

    Uses CobolDecimal .store() for target and .value for variable refs.
    """
    if string_vars is None:
        string_vars = set()

    stmt = statement[7:].strip()  # strip 'COMPUTE'

    if "=" not in stmt:
        return None

    parts = stmt.split("=", 1)
    target = parts[0].strip()
    # Strip ROUNDED keyword from target — ANTLR getText() strips whitespace,
    # so "WS-RESULT ROUNDED" arrives as "WS-RESULTROUNDED"
    target = re.sub(r'ROUNDED$', '', target, flags=re.IGNORECASE).strip()
    expr = parts[1].strip()

    # Strip ON SIZE ERROR clause from expression — getText() delivers
    # "ONSIZEERROR..." with optional "NOTONSIZEERROR..." after it
    on_size_error = None
    ose_match = re.search(r'ONSIZEERROR(.*)$', expr, flags=re.IGNORECASE)
    if ose_match:
        on_size_error = ose_match.group(1).strip()
        expr = expr[:ose_match.start()].strip()
        # Clean up the handler text for the comment (remove END-COMPUTE etc.)
        on_size_error = re.sub(r'END[_-]?COMPUTE$', '', on_size_error, flags=re.IGNORECASE).strip()

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
            if text[i] in "*/+()":
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
                continue
            if text[i:i + 7].upper() == "INTEGER":
                tokens.append("int")
                i += 7
                continue
            if text[i].isalpha():
                best_match = None
                for var in known_vars:
                    if text[i:i + len(var)].upper() == var.upper():
                        if best_match is None or len(var) > len(best_match):
                            best_match = var
                if best_match:
                    py_name = to_python_name(best_match)
                    # Numeric CobolDecimal vars need .value in expressions
                    if best_match.upper() not in {s.upper() for s in string_vars}:
                        tokens.append(f"{py_name}.value")
                    else:
                        tokens.append(py_name)
                    i += len(best_match)
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
        else:
            py_expr += tok

    py_expr = " ".join(py_expr.split())
    result = f"{py_target}.store({py_expr})"
    if on_size_error:
        result += f"\n# ON SIZE ERROR: {on_size_error} (not emulated)"
    return result


def parse_arithmetic(verb, statement, known_variables, string_vars=None):
    """Turn standalone COBOL arithmetic (ADD/SUBTRACT/MULTIPLY/DIVIDE) into Python.

    Parses the getText() blob from ANTLR4 and emits CobolDecimal .store()/.value code.
    Returns a Python statement string, or None if unparseable.
    """
    if string_vars is None:
        string_vars = set()

    raw = statement[len(verb):]

    # Strip ON SIZE ERROR / NOT ON SIZE ERROR / END-verb clauses
    for suffix in [
        f"END-{verb}", f"END{verb}",
        "NOTONSIZEERROR", "ONSIZEERROR",
    ]:
        idx = raw.upper().find(suffix)
        if idx != -1:
            raw = raw[:idx]

    def _match_var(text, pos):
        best = None
        for var in known_variables:
            vup = var.upper()
            if text[pos:pos + len(vup)].upper() == vup:
                if best is None or len(vup) > len(best[0]):
                    best = (var, vup)
        return best

    def _resolve_operand(name):
        py = to_python_name(name)
        return f"{py}.value"

    def _store(target, expr):
        py = to_python_name(target)
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
            tokens.append(("VAR", best_var[0]))
            i += len(best_var[1])
            continue

        if matched_kw:
            tokens.append(("KW", matched_kw))
            i += len(matched_kw)
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
        return _resolve_operand(operand[1])

    def _store_target(operand, expr):
        if operand[0] == "VAR":
            return _store(operand[1], expr)
        return None

    has_giving = "GIVING" in kws
    has_remainder = "REMAINDER" in kws

    groups = {}
    current_group = "BEFORE"
    groups[current_group] = []
    for t in tokens:
        if t[0] == "KW" and t[1] in ("TO", "FROM", "BY", "INTO", "GIVING", "REMAINDER"):
            current_group = t[1]
            groups.setdefault(current_group, [])
        elif t[0] in ("VAR", "NUM"):
            groups.setdefault(current_group, []).append(t)

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
                return _store_target(giving_ops[0], expr)
            else:
                before = groups.get("BEFORE", [])
                to_ops = groups.get("TO", [])
                if not to_ops:
                    return None
                target = to_ops[-1] if len(to_ops) == 1 else to_ops[0]
                if len(to_ops) > 1:
                    target = to_ops[0]
                addend_expr = " + ".join(_val(op) for op in before)
                return _store_target(target, f"{_val(target)} + {addend_expr}")

        elif verb == "SUBTRACT":
            if has_giving:
                before = groups.get("BEFORE", [])
                from_ops = groups.get("FROM", [])
                giving_ops = groups.get("GIVING", [])
                if not from_ops or not giving_ops:
                    return None
                sub_expr = " - ".join(_val(op) for op in before)
                return _store_target(giving_ops[0], f"{_val(from_ops[0])} - {sub_expr}")
            else:
                before = groups.get("BEFORE", [])
                from_ops = groups.get("FROM", [])
                if not from_ops:
                    return None
                target = from_ops[0]
                sub_expr = " - ".join(_val(op) for op in before)
                return _store_target(target, f"{_val(target)} - {sub_expr}")

        elif verb == "MULTIPLY":
            if has_giving:
                before = groups.get("BEFORE", [])
                by_ops = groups.get("BY", [])
                giving_ops = groups.get("GIVING", [])
                if not by_ops or not giving_ops:
                    return None
                operand_a = before[0] if before else by_ops[0]
                operand_b = by_ops[0] if before else (by_ops[1] if len(by_ops) > 1 else before[0])
                return _store_target(giving_ops[0], f"{_val(operand_a)} * {_val(operand_b)}")
            else:
                before = groups.get("BEFORE", [])
                by_ops = groups.get("BY", [])
                if not by_ops:
                    return None
                operand_a = before[0] if before else None
                target = by_ops[0]
                if operand_a:
                    return _store_target(target, f"{_val(target)} * {_val(operand_a)}")
                return None

        elif verb == "DIVIDE":
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
                    result = _store_target(giving_ops[0], f"{_val(dividend)} / {_val(divisor)}")
                    if has_remainder and remainder_ops:
                        result += f"\n{_store_target(remainder_ops[0], f'{_val(dividend)} % {_val(divisor)}')}"
                    return result
                else:
                    before = groups.get("BEFORE", [])
                    into_ops = groups.get("INTO", [])
                    if not into_ops or not before:
                        return None
                    divisor = before[0]
                    target = into_ops[0]
                    return _store_target(target, f"{_val(target)} / {_val(divisor)}")
            elif "BY" in kws:
                before = groups.get("BEFORE", [])
                by_ops = groups.get("BY", [])
                giving_ops = groups.get("GIVING", [])
                remainder_ops = groups.get("REMAINDER", [])
                if not by_ops or not giving_ops or not before:
                    return None
                dividend = before[0]
                divisor = by_ops[0]
                result = _store_target(giving_ops[0], f"{_val(dividend)} / {_val(divisor)}")
                if has_remainder and remainder_ops:
                    result += f"\n{_store_target(remainder_ops[0], f'{_val(dividend)} % {_val(divisor)}')}"
                return result

    except (IndexError, KeyError):
        return None

    return None


def generate_python_module(analysis, compiler_config=None):
    """
    Generate a complete Python module from an analysis dict (from analyze_cobol).

    Returns clean Python code. If conversion confidence < 95%, prepends
    a REQUIRES MANUAL REVIEW header. Always appends a side-by-side
    COBOL ↔ Python validation report as a comment block.

    compiler_config: optional CompilerConfig (from compiler_config module).
                     If None, uses default STD/EXTEND.
    """
    if not analysis.get("success"):
        return f"# PARSE ERROR: {analysis.get('message', 'Parser returned no data')}"

    # Resolve compiler config
    if compiler_config is None:
        from compiler_config import get_config
        compiler_config = get_config()
    trunc_mode = compiler_config.trunc_mode
    arith_mode = compiler_config.arith_mode
    arith_prec = compiler_config.precision

    # ── Variable info ────────────────────────────────────────────
    known_vars = set()
    var_info = {}
    for v in analysis["variables"]:
        raw = v["raw"]
        name = extract_var_name(raw)
        if name:
            known_vars.add(name)
            pic_raw = v.get("pic_raw", "")
            is_string = bool(pic_raw and ("X" in pic_raw.upper() or "A" in pic_raw.upper()))
            pic_info = v.get("pic_info") or {}
            var_info[name] = {
                "comp3": v["comp3"],
                "decimals": get_pic_info(raw),
                "integers": pic_info.get("integers", 0),
                "signed": pic_info.get("signed", False),
                "python_name": to_python_name(name),
                "is_string": is_string,
            }

    # PIC X/A variable names — needed for EBCDIC-aware comparisons
    string_vars = {name for name, info in var_info.items() if info["is_string"]}

    # ── 88-level condition map ───────────────────────────────────
    level_88_map = {}
    for item in analysis.get("level_88", []):
        level_88_map[item["name"].upper()] = {
            "parent": item["parent"],
            "value": item["value"],
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

    nested_condition_texts = {
        c["statement"] for c in analysis["conditions"]
        if c["statement"] in statements_in_branches
    }

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

    # EVALUATEs
    for ev in analysis.get("evaluates", []):
        para = ev["paragraph"]
        stmts_by_para.setdefault(para, []).append((ev.get("line", 0), "evaluate", ev))

    # PERFORMs (not those inside IF branches)
    for p in analysis.get("control_flow", []):
        if p.get("statement", "") in statements_in_branches:
            continue
        para = p["from"]
        if para:
            stmts_by_para.setdefault(para, []).append((p.get("line", 0), "perform", p))

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

    # Sort each paragraph's statements by source line number
    for para in stmts_by_para:
        stmts_by_para[para].sort(key=lambda x: x[0])

    # ── Conversion tracking ──────────────────────────────────────
    all_issues: list[dict] = []
    validation_entries: list[tuple] = []  # (cobol_repr, py_repr, status_char)
    total_stmts = 0
    fail_count = 0
    emit_counts = {"move": 0, "compute": 0, "condition": 0, "perform": 0, "goto": 0, "stop": 0, "evaluate": 0, "arithmetic": 0}

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
    body.append("from decimal import Decimal, ROUND_DOWN, ROUND_HALF_UP, getcontext")
    body.append("from cobol_types import CobolDecimal")
    body.append("from compiler_config import set_config")
    if string_vars:
        body.append("from ebcdic_utils import ebcdic_compare")
    body.append("")
    body.append(f"# Compiler: TRUNC({trunc_mode}), ARITH({arith_mode})")
    body.append(f"set_config(trunc_mode='{trunc_mode}', arith_mode='{arith_mode}')")
    body.append(f"getcontext().prec = {arith_prec}")
    body.append("")
    body.append("# " + "=" * 60)
    body.append("# WORKING-STORAGE VARIABLES")
    body.append("# " + "=" * 60)
    body.append("")

    for name, info in var_info.items():
        py_name = info["python_name"]
        if info["is_string"]:
            body.append(f'{py_name} = ""')
        else:
            integers = info["integers"] or 1
            decimals = info["decimals"]
            signed = info["signed"]
            is_comp = info["comp3"]
            comment = "  # COMP-3 packed decimal" if is_comp else ""
            body.append(
                f"{py_name} = CobolDecimal('0', "
                f"pic_integers={integers}, pic_decimals={decimals}, "
                f"is_signed={signed}, is_comp={is_comp}){comment}"
            )

    if level_88_map:
        body.append("")
        body.append("# 88-level condition map")
        for name, info in level_88_map.items():
            body.append(
                f"# {name} -> {to_python_name(info['parent'])} == \"{info['value']}\""
            )

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
            preview = dep.get('body_preview', dep.get('flag', ''))[:80]
            body.append(f"# {dep['type']} {verb}: {preview}" if verb else f"# {dep['type']}: {preview}")

        # Enhanced taint tracking comments
        if exec_analysis and exec_analysis.get("variable_taint"):
            taint = exec_analysis["variable_taint"]
            if taint.get("tainted"):
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
                "cobol": f"{dep['type']} {dep.get('verb', '')}: {dep.get('body_preview', dep.get('flag', ''))[:50]}",
            })
            total_stmts += 1
            fail_count += 1

    body.append("")
    body.append("# " + "=" * 60)
    body.append("# PROCEDURE DIVISION")
    body.append("# " + "=" * 60)
    body.append("")

    global_vars = ", ".join(sorted(v["python_name"] for v in var_info.values()))

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
                    py_stmt = parse_compute(stmt, known_vars, string_vars=string_vars)
                    if py_stmt:
                        body.append(f"    {py_stmt}")
                        cobol_repr = ("COMPUTE " + stmt[7:])[:45]
                        validation_entries.append((cobol_repr, py_stmt[:45], "[OK]  "))
                        emit_counts["compute"] += 1
                    else:
                        body.append(f"    # MANUAL REVIEW: {stmt[:55]}")
                        validation_entries.append((stmt[:45], "# MANUAL REVIEW", "[FAIL]"))
                        fail_count += 1

                elif stmt_type == "condition":
                    py_code, issues = parse_if_statement(
                        stmt, known_vars, level_88_map, analysis["conditions"],
                        string_vars=string_vars,
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
                        body.append(f"    # MANUAL REVIEW: MOVE CORRESPONDING {stmt['from']}")
                        validation_entries.append(("MOVE CORRESPONDING"[:45], "# MANUAL REVIEW", "[FAIL]"))
                        fail_count += 1
                    else:
                        move_from = stmt["from"]
                        move_to_list = stmt["to"]
                        for target_name in move_to_list:
                            is_string = _is_string_operand(target_name, string_vars)
                            py_value = _resolve_value(
                                move_from, known_vars,
                                string_vars=string_vars,
                                use_value=not is_string,
                            )
                            py_target = to_python_name(target_name)
                            if is_string:
                                body.append(f"    {py_target} = {py_value}")
                            else:
                                body.append(f"    {py_target}.store({py_value})")
                        cobol_repr = f"MOVE {move_from} TO {', '.join(move_to_list)}"[:45]
                        py_repr = f"{to_python_name(move_to_list[0])}.store(...)"[:45]
                        validation_entries.append((cobol_repr, py_repr, "[OK]  "))
                        emit_counts["move"] += 1

                elif stmt_type == "perform":
                    target_func = "para_" + to_python_name(stmt["to"])
                    body.append(f"    {target_func}()")
                    cobol_repr = f"PERFORM {stmt['to']}"[:45]
                    validation_entries.append((cobol_repr, f"{target_func}()"[:45], "[OK]  "))
                    emit_counts["perform"] += 1

                elif stmt_type == "goto":
                    if stmt.get("depending_on"):
                        body.append(f"    # MANUAL REVIEW: GO TO DEPENDING ON {stmt['depending_on']}")
                        validation_entries.append(("GO TO DEPENDING ON"[:45], "# MANUAL REVIEW", "[FAIL]"))
                        fail_count += 1
                    else:
                        target = stmt["targets"][0]
                        target_func = "para_" + to_python_name(target)
                        body.append(f"    {target_func}()  # GO TO {target}")
                        body.append(f"    return")
                        validation_entries.append((f"GO TO {target}"[:45], f"{target_func}(); return"[:45], "[OK]  "))
                        emit_counts["goto"] += 1

                elif stmt_type == "stop":
                    body.append(f"    return  # STOP RUN")
                    validation_entries.append(("STOP RUN", "return", "[OK]  "))
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

                elif stmt_type == "arithmetic":
                    py_stmt = parse_arithmetic(
                        stmt["verb"], stmt["statement"], known_vars, string_vars=string_vars
                    )
                    if py_stmt:
                        for line in py_stmt.split("\n"):
                            body.append(f"    {line}")
                        cobol_repr = f"{stmt['verb']} ..."[:45]
                        validation_entries.append((cobol_repr, py_stmt.split("\n")[0][:45], "[OK]  "))
                        emit_counts["arithmetic"] += 1
                    else:
                        body.append(f"    # MANUAL REVIEW: {stmt['statement'][:55]}")
                        validation_entries.append((stmt['statement'][:45], "# MANUAL REVIEW", "[FAIL]"))
                        fail_count += 1
        else:
            body.append("    pass  # No statements captured")

        body.append("")

    body.append("# " + "=" * 60)
    body.append("# MAIN EXECUTION")
    body.append("# " + "=" * 60)
    body.append("")
    body.append("def main():")

    if analysis["paragraphs"]:
        entry = "para_" + to_python_name(analysis["paragraphs"][0])
        body.append(f"    {entry}()")
    else:
        body.append("    pass")

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

    return {"code": "\n".join(output), "emit_counts": emit_counts}


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
