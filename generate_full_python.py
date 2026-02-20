import re
from cobol_analyzer_api import analyze_cobol
from parse_conditions import parse_if_statement


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


def parse_compute(statement, known_variables):
    """Turn COBOL COMPUTE getText() blob into Python assignment."""
    stmt = statement[7:].strip()  # strip 'COMPUTE'

    if "=" not in stmt:
        return None

    parts = stmt.split("=", 1)
    target = parts[0].strip()
    expr = parts[1].strip()

    def tokenize_expr(text, known_vars):
        tokens = []
        i = 0
        while i < len(text):
            if text[i].isspace():
                i += 1
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
                    tokens.append(to_python_name(best_match))
                    i += len(best_match)
                else:
                    j = i
                    while j < len(text) and (text[j].isalnum() or text[j] == '-'):
                        j += 1
                    tokens.append(to_python_name(text[i:j]))
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
        if tok in "*/+-":
            py_expr += f" {tok} "
        elif tok == "(":
            py_expr += "("
        elif tok == ")":
            py_expr += ")"
        else:
            py_expr += tok

    py_expr = " ".join(py_expr.split())
    return f"{py_target} = {py_expr}"


def generate_python_module(cobol_source):
    """
    Generate a complete Python module from COBOL source.

    Returns clean Python code. If conversion confidence < 95%, prepends
    a REQUIRES MANUAL REVIEW header. Always appends a side-by-side
    COBOL ↔ Python validation report as a comment block.
    """
    analysis = analyze_cobol(cobol_source)

    if not analysis["success"]:
        return f"# PARSE ERROR: {analysis['message']}"

    # ── Variable info ────────────────────────────────────────────
    known_vars = set()
    var_info = {}
    for v in analysis["variables"]:
        raw = v["raw"]
        name = extract_var_name(raw)
        if name:
            known_vars.add(name)
            var_info[name] = {
                "comp3": v["comp3"],
                "decimals": get_pic_info(raw),
                "python_name": to_python_name(name),
            }

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

    nested_condition_texts = {
        c["statement"] for c in analysis["conditions"]
        if c["statement"] in statements_in_branches
    }

    # ── Build ordered statement list per paragraph ───────────────
    stmts_by_para: dict[str, list] = {}

    # Top-level COMPUTEs only (not those inside IF branches)
    for c in analysis["computes"]:
        if c["statement"] in statements_in_branches:
            continue
        para = c["paragraph"]
        stmts_by_para.setdefault(para, []).append(("compute", c["statement"]))

    # Top-level IFs only (nested handled recursively in parse_if_statement)
    for c in analysis["conditions"]:
        if c["statement"] in nested_condition_texts:
            continue
        para = c["paragraph"]
        stmts_by_para.setdefault(para, []).append(("condition", c))

    # ── Conversion tracking ──────────────────────────────────────
    all_issues: list[dict] = []
    validation_entries: list[tuple] = []  # (cobol_repr, py_repr, status_char)
    total_stmts = 0
    fail_count = 0

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
    body.append("")
    body.append("# Set precision to match IBM COBOL ARITH(EXTEND)")
    body.append("getcontext().prec = 31")
    body.append("")
    body.append("# " + "=" * 60)
    body.append("# WORKING-STORAGE VARIABLES")
    body.append("# " + "=" * 60)
    body.append("")

    for name, info in var_info.items():
        py_name = info["python_name"]
        decimals = info["decimals"]
        default = (
            f"Decimal('0.{'0' * decimals}')" if decimals > 0
            else "Decimal('0')"
        )
        comment = "  # COMP-3 packed decimal" if info["comp3"] else ""
        body.append(f"{py_name} = {default}{comment}")

    if level_88_map:
        body.append("")
        body.append("# 88-level condition map")
        for name, info in level_88_map.items():
            body.append(
                f"# {name} -> {to_python_name(info['parent'])} == \"{info['value']}\""
            )

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
            for stmt_type, stmt in stmts_by_para[para]:
                total_stmts += 1

                if stmt_type == "compute":
                    py_stmt = parse_compute(stmt, known_vars)
                    if py_stmt:
                        body.append(f"    {py_stmt}")
                        cobol_repr = ("COMPUTE " + stmt[7:])[:45]
                        validation_entries.append((cobol_repr, py_stmt[:45], "[OK]  "))
                    else:
                        body.append(f"    # MANUAL REVIEW: {stmt[:55]}")
                        validation_entries.append((stmt[:45], "# MANUAL REVIEW", "[FAIL]"))
                        fail_count += 1

                elif stmt_type == "condition":
                    py_code, issues = parse_if_statement(
                        stmt, known_vars, level_88_map, analysis["conditions"]
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

                    for line in py_code.split("\n"):
                        body.append(f"    {line}")
        else:
            body.append("    pass  # No statements captured")

        body.append("")

    body.append("# " + "=" * 60)
    body.append("# MAIN EXECUTION")
    body.append("# " + "=" * 60)
    body.append("")
    body.append("def main():")

    for flow in analysis["control_flow"]:
        target = "para_" + to_python_name(flow["to"])
        body.append(f"    {target}()")

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

    return "\n".join(output)


# ── CLI entry point ──────────────────────────────────────────────

if __name__ == "__main__":
    with open("DEMO_LOAN_INTEREST.cbl", "r") as f:
        cobol_source = f.read()

    python_code = generate_python_module(cobol_source)

    with open("converted_loan_interest.py", "w", encoding="utf-8") as f:
        f.write(python_code)

    print("Generated: converted_loan_interest.py")
    print()
    print(python_code)
