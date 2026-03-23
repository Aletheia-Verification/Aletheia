"""
risk_heatmap.py — Portfolio Risk Heatmap Generator

Takes a list of COBOL program analysis dicts and produces a per-program
color-coded risk report for first-meeting customer deliverables.

Color logic:
  GREEN:  All constructs fully supported. Predicted VERIFIED.
  YELLOW: Has constructs that need attention (ODO, large OCCURS,
          unresolved copybooks, heavy GO TO, large programs).
  RED:    Has constructs that WILL trigger MANUAL REVIEW
          (ALTER, EXEC SQL/CICS).
"""

from core_logic import generate_compiler_matrix

# ── Construct name mapping (summary key → display name) ──────────────

CONSTRUCT_MAP = {
    "perform_calls": "PERFORM",
    "compute_statements": "COMPUTE",
    "business_rules": "IF",
    "evaluate_statements": "EVALUATE",
    "arithmetic_statements": "ADD/SUBTRACT/MULTIPLY/DIVIDE",
    "move_statements": "MOVE",
    "goto_statements": "GO TO",
    "string_statements": "STRING",
    "unstring_statements": "UNSTRING",
    "inspect_statements": "INSPECT",
    "display_statements": "DISPLAY",
    "set_statements": "SET",
    "initialize_statements": "INITIALIZE",
}

# Keys used for distinct-category count in complexity score
CATEGORY_KEYS = [
    "compute_statements", "evaluate_statements", "arithmetic_statements",
    "string_statements", "unstring_statements", "inspect_statements",
    "goto_statements", "perform_calls", "display_statements",
    "set_statements", "initialize_statements",
]


# ── Internal helpers ─────────────────────────────────────────────────

def _determine_color(analysis, lines):
    """Classify a program as green/yellow/red based on analysis dict."""
    exec_deps = analysis.get("exec_dependencies", [])
    summary = analysis.get("summary", {})
    variables = analysis.get("variables", [])
    copybook_issues = analysis.get("copybook_issues", [])

    # RED: ALTER or EXEC SQL/CICS
    has_alter = any(d.get("type") == "ALTER" for d in exec_deps)
    has_exec = any(d.get("type", "").startswith("EXEC") for d in exec_deps)
    if has_alter or has_exec:
        return "red", "MANUAL_REVIEW"

    # YELLOW triggers
    has_odo = any(d.get("type") == "ODO" for d in exec_deps)
    has_large_occurs = any(v.get("occurs", 0) > 50 for v in variables)
    has_unresolved_copy = len(copybook_issues) > 0
    has_heavy_goto = summary.get("goto_statements", 0) > 10
    is_large = lines > 500

    if has_odo or has_large_occurs or has_unresolved_copy or has_heavy_goto or is_large:
        return "yellow", "VERIFIED"

    return "green", "VERIFIED"


def _build_risk_factors(analysis, lines):
    """Build human-readable risk factor strings."""
    exec_deps = analysis.get("exec_dependencies", [])
    summary = analysis.get("summary", {})
    variables = analysis.get("variables", [])
    copybook_issues = analysis.get("copybook_issues", [])
    factors = []

    # RED factors
    alter_count = sum(1 for d in exec_deps if d.get("type") == "ALTER")
    if alter_count:
        factors.append(f"ALTER ({alter_count})")

    exec_sql_count = sum(1 for d in exec_deps if d.get("type") == "EXEC SQL")
    if exec_sql_count:
        factors.append(f"EXEC SQL ({exec_sql_count} blocks)")

    exec_cics_count = sum(1 for d in exec_deps if d.get("type") == "EXEC CICS")
    if exec_cics_count:
        factors.append(f"EXEC CICS ({exec_cics_count} blocks)")

    # YELLOW factors
    odo_count = sum(1 for d in exec_deps if d.get("type") == "ODO")
    if odo_count:
        factors.append(f"OCCURS DEPENDING ON ({odo_count})")

    large_occurs = sum(1 for v in variables if v.get("occurs", 0) > 50)
    if large_occurs:
        factors.append(f"Large OCCURS tables ({large_occurs} fields)")

    if copybook_issues:
        factors.append(f"Unresolved copybooks ({len(copybook_issues)})")

    goto_count = summary.get("goto_statements", 0)
    if goto_count > 10:
        factors.append(f"GO TO count ({goto_count})")

    if lines > 500:
        factors.append(f"Large program ({lines} lines)")

    return factors


def _build_constructs(summary, analysis):
    """Build list of distinct construct names present in the program."""
    constructs = [
        name for key, name in CONSTRUCT_MAP.items()
        if summary.get(key, 0) > 0
    ]

    exec_deps = analysis.get("exec_dependencies", [])
    if any(d.get("type", "").startswith("EXEC SQL") for d in exec_deps):
        constructs.append("EXEC SQL")
    if any(d.get("type", "").startswith("EXEC CICS") for d in exec_deps):
        constructs.append("EXEC CICS")

    file_ops = analysis.get("file_operations", [])
    if file_ops:
        constructs.append("FILE I/O")

    sort_stmts = analysis.get("sort_statements", [])
    if sort_stmts:
        constructs.append("SORT")

    return constructs


def _compute_complexity(summary, analysis, lines):
    """Compute complexity score (0-100) from analysis data."""
    exec_deps = analysis.get("exec_dependencies", [])
    score = 0.0

    # Lines of code (0-20 points): 500+ lines = max
    score += min(20, lines / 25)

    # Distinct construct categories (0-15 points)
    categories = sum(1 for k in CATEGORY_KEYS if summary.get(k, 0) > 0)
    score += min(15, categories * 1.5)

    # COPY dependencies (0-10 points)
    copy_count = len(analysis.get("copybook_issues", []))
    score += min(10, copy_count * 2)

    # EXEC SQL blocks (0-20 points, high weight)
    exec_count = sum(1 for d in exec_deps if d.get("type", "").startswith("EXEC"))
    score += min(20, exec_count * 5)

    # GO TO count (0-10 points)
    goto_count = summary.get("goto_statements", 0)
    score += min(10, goto_count * 2)

    # REDEFINES groups (0-10 points)
    redefines_count = len(analysis.get("redefines", {}).get("redefines_groups", []))
    score += min(10, redefines_count * 3)

    # COMP-3 fields (0-10 points)
    comp3_count = summary.get("comp3_variables", 0)
    score += min(10, comp3_count)

    # PERFORM depth proxy (0-5 points)
    perform_count = summary.get("perform_calls", 0)
    score += min(5, perform_count / 4)

    return round(score)


def _classify_program(filename, analysis, lines):
    """Classify a single program and return its heatmap entry."""
    summary = analysis.get("summary", {})
    status, predicted_outcome = _determine_color(analysis, lines)
    constructs = _build_constructs(summary, analysis)
    risk_factors = _build_risk_factors(analysis, lines)
    complexity_score = _compute_complexity(summary, analysis, lines)

    # Compiler matrix warnings count
    matrix = generate_compiler_matrix(analysis)
    compiler_matrix_warnings = len(matrix.get("warnings", []))

    # Strip extension for display name
    name = filename
    for ext in (".cbl", ".cob", ".CBL", ".COB"):
        if name.endswith(ext):
            name = name[:-len(ext)]
            break

    return {
        "name": name,
        "lines": lines,
        "status": status,
        "predicted_outcome": predicted_outcome,
        "complexity_score": complexity_score,
        "construct_count": len(constructs),
        "constructs": constructs,
        "risk_factors": risk_factors,
        "compiler_matrix_warnings": compiler_matrix_warnings,
    }


# ── Public API ───────────────────────────────────────────────────────

def generate_risk_heatmap(programs):
    """Generate a portfolio risk heatmap from a list of analyzed programs.

    Args:
        programs: list of dicts, each with:
            - "filename": str
            - "lines": int
            - "analysis": dict (from analyze_cobol)

    Returns:
        dict with "programs" (list of per-program reports) and "summary".
    """
    results = []
    for prog in programs:
        entry = _classify_program(
            prog["filename"],
            prog["analysis"],
            prog["lines"],
        )
        results.append(entry)

    total = len(results)
    green = sum(1 for r in results if r["status"] == "green")
    yellow = sum(1 for r in results if r["status"] == "yellow")
    red = sum(1 for r in results if r["status"] == "red")

    # Predicted PVR range (conservative)
    if total > 0:
        green_pct = green / total * 100
        if green_pct >= 90:
            predicted_pvr = f"{int(green_pct - 5)}-{int(green_pct)}%"
        elif green_pct >= 70:
            predicted_pvr = f"{int(green_pct - 10)}-{int(green_pct - 5)}%"
        else:
            predicted_pvr = f"{int(green_pct - 15)}-{int(green_pct - 10)}%"
    else:
        predicted_pvr = "N/A"

    return {
        "programs": results,
        "summary": {
            "total": total,
            "green": green,
            "yellow": yellow,
            "red": red,
            "predicted_pvr": predicted_pvr,
        },
    }
