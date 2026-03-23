"""
exec_sql_parser.py — EXEC SQL/CICS Logic-Only Parser with Variable Taint Tracking

Parses EXEC SQL and EXEC CICS blocks (already stripped by strip_exec_blocks())
to extract host variable references and classify them as:

  TAINTED — populated by external source (SELECT INTO, FETCH INTO, CICS READ)
  USED    — sent to external source (WHERE, SET, VALUES, CICS SEND FROM)
  CONTROL — drives program flow (SQLCODE, SQLSTATE, EIBRESP)

Also maps SQLCODE/SQLSTATE branch patterns to meaningful labels.
"""

import re


# ══════════════════════════════════════════════════════════════════════
# Component 1: EXEC SQL Parser
# ══════════════════════════════════════════════════════════════════════

_HOST_VAR = re.compile(r':([A-Z][A-Z0-9\-]*)', re.IGNORECASE)


def parse_exec_sql(body: str) -> dict:
    """
    Parse a single EXEC SQL body string and extract host variable references.

    Host variables are prefixed with ':' in embedded SQL (e.g. :WS-BALANCE).
    """
    body = ' '.join(body.split())  # normalise whitespace
    upper = body.upper()

    # Extract verb
    verb_match = re.match(r'(\w+)', body.strip())
    verb = verb_match.group(1).upper() if verb_match else "UNKNOWN"

    into_vars = []
    where_vars = []
    set_vars = []

    # INTO clause (SELECT ... INTO :A, :B FROM ... or FETCH ... INTO :A, :B)
    into_match = re.search(r'\bINTO\s+(.+?)(?:\bFROM\b|$)', upper)
    if into_match:
        into_vars = [m.group(1).upper() for m in _HOST_VAR.finditer(into_match.group(1))]

    # WHERE clause
    where_match = re.search(r'\bWHERE\s+(.+)$', upper)
    if where_match:
        where_vars = [m.group(1).upper() for m in _HOST_VAR.finditer(where_match.group(1))]

    # SET clause (UPDATE ... SET COL = :VAR ...)
    if verb == "UPDATE":
        set_match = re.search(r'\bSET\s+(.+?)(?:\bWHERE\b|$)', upper)
        if set_match:
            set_vars = [m.group(1).upper() for m in _HOST_VAR.finditer(set_match.group(1))]

    # VALUES clause (INSERT INTO ... VALUES(:A, :B))
    values_vars = []
    if verb == "INSERT":
        values_match = re.search(r'\bVALUES\s*\((.+?)\)', upper)
        if values_match:
            values_vars = [m.group(1).upper() for m in _HOST_VAR.finditer(values_match.group(1))]

    all_host_vars = list(dict.fromkeys(into_vars + where_vars + set_vars + values_vars))

    return {
        "verb": verb,
        "into_vars": into_vars,
        "where_vars": where_vars,
        "set_vars": set_vars,
        "all_host_vars": all_host_vars,
    }


# ══════════════════════════════════════════════════════════════════════
# Component 2: EXEC CICS Parser
# ══════════════════════════════════════════════════════════════════════


def parse_exec_cics(body: str) -> dict:
    """
    Parse a single EXEC CICS body string and extract variable references.

    CICS uses parenthesised arguments: INTO(WS-DATA), FROM(WS-DATA), SET(WS-PTR).
    """
    body = ' '.join(body.split())
    upper = body.upper()

    verb_match = re.match(r'(\w+)', body.strip())
    verb = verb_match.group(1).upper() if verb_match else "UNKNOWN"

    into_vars = []
    from_vars = []

    # INTO(var)
    for m in re.finditer(r'\bINTO\(([^)]+)\)', upper):
        into_vars.append(m.group(1).strip())

    # SET(var) — pointer-based read, functionally same as INTO
    for m in re.finditer(r'\bSET\(([^)]+)\)', upper):
        into_vars.append(m.group(1).strip())

    # FROM(var)
    for m in re.finditer(r'\bFROM\(([^)]+)\)', upper):
        from_vars.append(m.group(1).strip())

    all_vars = list(dict.fromkeys(into_vars + from_vars))

    return {
        "verb": verb,
        "into_vars": into_vars,
        "from_vars": from_vars,
        "all_vars": all_vars,
    }


# ══════════════════════════════════════════════════════════════════════
# Component 3: Variable Taint Tracker
# ══════════════════════════════════════════════════════════════════════

_CONTROL_PATTERNS = re.compile(
    r'^(SQLCODE|SQLSTATE|SQLCA|EIBR\w*|DFHRESP\w*|WS-SQLCODE|WS-SQLSTATE)$',
    re.IGNORECASE,
)


def classify_variables(parsed_blocks: list, all_variables: list) -> dict:
    """
    Classify every variable touched by EXEC blocks.

    Returns {"tainted": [...], "used": [...], "control": [...]}.
    """
    tainted = []
    used = []
    control = []

    seen_tainted = set()
    seen_used = set()
    seen_control = set()

    # Check all declared variables for control patterns
    for v in all_variables:
        name = v.get("name", "") if isinstance(v, dict) else str(v)
        if _CONTROL_PATTERNS.match(name) and name not in seen_control:
            seen_control.add(name)
            control.append({
                "var": name,
                "source": "DECLARED",
                "detail": "SQL/CICS return code — drives IF branches",
            })

    for block in parsed_blocks:
        exec_type = block.get("exec_type", "EXEC SQL")
        verb = block.get("verb", "UNKNOWN")
        parsed = block.get("parsed", {})

        source_label = f"{exec_type} {verb}"

        # TAINTED: variables populated by external source
        into_vars = parsed.get("into_vars", [])
        for var in into_vars:
            if var not in seen_tainted:
                seen_tainted.add(var)
                tainted.append({
                    "var": var,
                    "source": source_label,
                    "detail": f"populated via INTO clause",
                })

        # USED: variables sent to external source
        for key in ("where_vars", "set_vars", "from_vars"):
            for var in parsed.get(key, []):
                if var not in seen_used:
                    seen_used.add(var)
                    used.append({
                        "var": var,
                        "source": source_label,
                        "detail": f"referenced in {key.replace('_vars', '').upper()} clause",
                    })

        # Also check all_host_vars for VALUES-only vars
        for var in parsed.get("all_host_vars", parsed.get("all_vars", [])):
            if var not in seen_tainted and var not in seen_used:
                if var not in seen_used:
                    seen_used.add(var)
                    used.append({
                        "var": var,
                        "source": source_label,
                        "detail": "referenced in SQL statement",
                    })

        # Check INTO/FROM vars for control patterns too
        for var in into_vars + parsed.get("from_vars", []):
            if _CONTROL_PATTERNS.match(var) and var not in seen_control:
                seen_control.add(var)
                control.append({
                    "var": var,
                    "source": source_label,
                    "detail": "SQL/CICS return code — drives IF branches",
                })

    return {
        "tainted": tainted,
        "used": used,
        "control": control,
    }


# ══════════════════════════════════════════════════════════════════════
# Component 4: SQLCODE Branch Mapping
# ══════════════════════════════════════════════════════════════════════

_SQLCODE_NAMES = {"SQLCODE", "WS-SQLCODE", "SQLSTATE", "WS-SQLSTATE"}


def map_sqlcode_branches(conditions: list, exec_deps: list) -> list:
    """
    Detect IF statements referencing SQLCODE/SQLSTATE and map to meaning.
    """
    if not exec_deps:
        return []

    branches = []

    for cond in conditions:
        raw = cond.get("raw", "") if isinstance(cond, dict) else str(cond)
        upper = raw.upper()

        # Check if any SQLCODE-like name appears
        has_sqlcode = any(name in upper for name in _SQLCODE_NAMES)
        if not has_sqlcode:
            continue

        # Determine branch meaning
        meaning = "SQLCODE check"
        branch = "unknown"

        if "NOT" in upper and "= 0" in upper:
            meaning = "Error handler — query failed"
            branch = "error"
        elif "= 100" in upper:
            meaning = "Not found — no matching rows"
            branch = "not_found"
        elif "< 0" in upper:
            meaning = "Severe error — database exception"
            branch = "severe"
        elif "= 0" in upper:
            meaning = "Success path — query succeeded"
            branch = "success"
        elif "> 0" in upper:
            meaning = "Warning or not found"
            branch = "warning"

        branches.append({
            "condition": raw.strip(),
            "meaning": meaning,
            "branch": branch,
        })

    return branches


# ══════════════════════════════════════════════════════════════════════
# Orchestrator
# ══════════════════════════════════════════════════════════════════════


def analyze_exec_blocks(exec_dependencies: list, conditions: list,
                        variables: list) -> dict:
    """
    Top-level analysis: parse all EXEC blocks, classify variables, map branches.

    Args:
        exec_dependencies: list from strip_exec_blocks() — each has type, verb, body_preview, flag
        conditions: list from ANTLR4 parser — IF statement conditions
        variables: list from ANTLR4 parser — declared variables

    Returns combined analysis dict.
    """
    parsed_blocks = []

    for dep in exec_dependencies:
        exec_type = dep.get("type", "EXEC SQL")
        body = dep.get("body_preview", "")

        if "CICS" in exec_type.upper():
            parsed = parse_exec_cics(body)
        else:
            parsed = parse_exec_sql(body)

        parsed_blocks.append({
            "exec_type": exec_type,
            "verb": parsed["verb"],
            "body_preview": body,
            "parsed": parsed,
        })

    variable_taint = classify_variables(parsed_blocks, variables)
    sqlcode_branches = map_sqlcode_branches(conditions, exec_dependencies)

    return {
        "parsed_blocks": parsed_blocks,
        "variable_taint": variable_taint,
        "sqlcode_branches": sqlcode_branches,
        "summary": {
            "total_exec_blocks": len(exec_dependencies),
            "tainted_vars": len(variable_taint["tainted"]),
            "used_vars": len(variable_taint["used"]),
            "control_vars": len(variable_taint["control"]),
            "sqlcode_branches": len(sqlcode_branches),
        },
    }
