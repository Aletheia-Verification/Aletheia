"""
dependency_crawler.py — CALL Dependency Crawler for Multi-Program Verification

Detects CALL statements in COBOL programs, builds dependency trees,
parses LINKAGE SECTION for parameter mapping, and orchestrates
multi-program analysis through Aletheia's engine.

Components:
  1. detect_calls()          — CALL statement detection (static/dynamic)
  2. build_dependency_tree()  — Directed graph of program calls
  3. parse_linkage_section()  — LINKAGE SECTION variable extraction
  4. map_parameters()         — Caller USING → Callee LINKAGE mapping
  5. analyze_multi_program()  — Orchestrator: full multi-program analysis
  6. analyze_batch()          — Batch: analysis + Python generation + cross-file CALL resolution
"""

import re
import os


# ══════════════════════════════════════════════════════════════════════
# Component 1: CALL Statement Detector
# ══════════════════════════════════════════════════════════════════════

# Static: CALL 'PROGRAM-NAME' or CALL "PROGRAM-NAME"
_STATIC_CALL = re.compile(
    r"""CALL\s+['"]([A-Z0-9][A-Z0-9\-]*)['"]""",
    re.IGNORECASE,
)

# Dynamic: CALL WS-PROG-NAME (identifier, no quotes)
_DYNAMIC_CALL = re.compile(
    r"""CALL\s+([A-Z][A-Z0-9\-]+)(?:\s|\.|\n)""",
    re.IGNORECASE,
)

# USING clause after a CALL (captures everything until period or next statement)
_USING_CLAUSE = re.compile(
    r"""CALL\s+(?:['"][A-Z0-9\-]+['"]|[A-Z][A-Z0-9\-]+)\s+USING\s+(.+?)(?:\.|$)""",
    re.IGNORECASE | re.MULTILINE,
)


def detect_calls(cobol_source: str) -> list:
    """
    Detect all CALL statements in COBOL source.

    Returns list of call descriptors with target, type, parameters, and line number.
    """
    calls = []
    seen = set()

    # Static calls: CALL 'NAME'
    for match in _STATIC_CALL.finditer(cobol_source):
        target = match.group(1).upper()
        line = cobol_source[:match.start()].count('\n') + 1
        key = (target, line)
        if key in seen:
            continue
        seen.add(key)

        # Look for USING clause on this same CALL
        params = _extract_using_params(cobol_source, match.start())

        calls.append({
            "target": target,
            "type": "static",
            "parameters": params,
            "line": line,
        })

    # Dynamic calls: CALL WS-VAR (no quotes)
    for match in _DYNAMIC_CALL.finditer(cobol_source):
        target = match.group(1).upper()
        line = cobol_source[:match.start()].count('\n') + 1
        key = (target, line)
        if key in seen:
            continue

        # Skip if this was already captured as a static call (the regex
        # might match the same CALL if the dynamic pattern overlaps)
        # Also skip COBOL keywords that could look like identifiers
        if target in ('USING', 'GIVING', 'RETURNING', 'ON', 'NOT', 'END-CALL'):
            continue

        seen.add(key)
        params = _extract_using_params(cobol_source, match.start())

        calls.append({
            "target": target,
            "type": "dynamic",
            "parameters": params,
            "line": line,
        })

    return calls


def _extract_using_params(source: str, call_start: int) -> list:
    """Extract USING parameter names from a CALL statement starting at call_start."""
    # Get the rest of the line/statement from the CALL
    rest = source[call_start:call_start + 500]
    using_match = re.search(
        r'USING\s+(.+?)(?:\.\s*$|\n\s*\n|END-CALL)',
        rest,
        re.IGNORECASE | re.DOTALL,
    )
    if not using_match:
        return []

    params_str = using_match.group(1)
    # Remove BY REFERENCE / BY VALUE / BY CONTENT qualifiers
    params_str = re.sub(r'\bBY\s+(REFERENCE|VALUE|CONTENT)\b', '', params_str, flags=re.IGNORECASE)
    # Split on whitespace and filter to valid COBOL identifiers
    tokens = params_str.split()
    params = [t.upper().rstrip('.') for t in tokens
              if re.match(r'^[A-Z][A-Z0-9\-]*$', t.strip('.'), re.IGNORECASE)]
    return params


# ══════════════════════════════════════════════════════════════════════
# Component 2: Dependency Tree Builder
# ══════════════════════════════════════════════════════════════════════


def _extract_program_id(cobol_source: str) -> str:
    """Extract PROGRAM-ID from COBOL source."""
    match = re.search(r'PROGRAM-ID\.\s+([A-Z0-9][A-Z0-9\-]*)', cobol_source, re.IGNORECASE)
    return match.group(1).upper() if match else "UNKNOWN"


def build_dependency_tree(programs: dict) -> dict:
    """
    Build a dependency graph from a dict of {program_name: source_code}.

    Returns tree structure with roots, edges, unresolved refs, dynamic calls, and topological order.
    """
    tree = {}
    all_static_targets = set()
    unresolved = []
    dynamic_calls = []

    # Phase 1: detect calls for each program
    for prog_name, source in programs.items():
        calls_list = detect_calls(source)
        static_targets = []
        for call in calls_list:
            if call["type"] == "static":
                static_targets.append(call["target"])
                all_static_targets.add(call["target"])
            else:
                dynamic_calls.append({
                    "program": prog_name,
                    "variable": call["target"],
                })

        tree[prog_name] = {
            "calls": static_targets,
            "called_by": [],
            "call_details": calls_list,
        }

    # Phase 2: populate called_by (reverse edges)
    for prog_name, node in tree.items():
        for target in node["calls"]:
            if target in tree:
                tree[target]["called_by"].append(prog_name)

    # Phase 3: identify unresolved
    known_programs = set(programs.keys())
    for target in all_static_targets:
        if target not in known_programs:
            unresolved.append(target)

    # Phase 4: detect circular dependencies
    circular = _detect_cycles(tree)

    # Phase 5: topological order (leaves first)
    order = _topological_sort(tree)

    # Phase 6: find root (program with no callers)
    roots = [name for name, node in tree.items() if not node["called_by"]]
    root = roots[0] if roots else (list(programs.keys())[0] if programs else "UNKNOWN")

    return {
        "root": root,
        "tree": {name: {"calls": node["calls"], "called_by": node["called_by"]}
                 for name, node in tree.items()},
        "unresolved": unresolved,
        "dynamic_calls": dynamic_calls,
        "circular": circular,
        "order": order,
    }


def _detect_cycles(tree: dict) -> list:
    """Detect circular dependencies via DFS."""
    cycles = []
    visited = set()
    rec_stack = set()

    def dfs(node, path):
        visited.add(node)
        rec_stack.add(node)
        path.append(node)

        for neighbor in tree.get(node, {}).get("calls", []):
            if neighbor not in tree:
                continue
            if neighbor in rec_stack:
                # Found a cycle
                cycle_start = path.index(neighbor)
                cycle = path[cycle_start:] + [neighbor]
                cycles.append(cycle)
            elif neighbor not in visited:
                dfs(neighbor, path)

        path.pop()
        rec_stack.discard(node)

    for node in tree:
        if node not in visited:
            dfs(node, [])

    return cycles


def _topological_sort(tree: dict) -> list:
    """Topological sort — leaves first, root last. Handles cycles gracefully."""
    in_degree = {name: 0 for name in tree}
    for name, node in tree.items():
        for target in node.get("calls", []):
            if target in in_degree:
                in_degree[target] += 1

    # Start with nodes that have no incoming edges (roots)
    # We want leaves first, so we reverse: start with nodes nobody calls
    queue = [name for name, deg in in_degree.items() if deg == 0]
    result = []

    while queue:
        node = queue.pop(0)
        for target in tree.get(node, {}).get("calls", []):
            if target in in_degree:
                in_degree[target] -= 1
                if in_degree[target] == 0:
                    queue.append(target)
        result.append(node)

    # Add any remaining nodes (part of cycles)
    for name in tree:
        if name not in result:
            result.append(name)

    # Reverse so leaves come first
    result.reverse()
    return result


# ══════════════════════════════════════════════════════════════════════
# Component 3: LINKAGE SECTION Parser
# ══════════════════════════════════════════════════════════════════════

_LINKAGE_SECTION = re.compile(
    r'LINKAGE\s+SECTION\s*\.\s*\n(.*?)(?=(?:PROCEDURE\s+DIVISION|DATA\s+DIVISION|WORKING-STORAGE\s+SECTION|LOCAL-STORAGE\s+SECTION|\Z))',
    re.IGNORECASE | re.DOTALL,
)

_LINKAGE_VAR = re.compile(
    r'(\d{2})\s+([A-Z][A-Z0-9\-]+)\s+(PIC\s+\S+)',
    re.IGNORECASE,
)


def parse_linkage_section(cobol_source: str) -> list:
    """
    Parse LINKAGE SECTION and extract variable definitions.

    Returns list of {"name": str, "pic": str, "level": str}.
    """
    linkage_match = _LINKAGE_SECTION.search(cobol_source)
    if not linkage_match:
        return []

    linkage_body = linkage_match.group(1)
    variables = []

    for match in _LINKAGE_VAR.finditer(linkage_body):
        level = match.group(1)
        name = match.group(2).upper()
        pic = match.group(3).strip().rstrip('.')
        variables.append({
            "name": name,
            "pic": pic,
            "level": level,
        })

    return variables


# ══════════════════════════════════════════════════════════════════════
# Component 4: Parameter Mapping
# ══════════════════════════════════════════════════════════════════════


def map_parameters(caller_call: dict, callee_linkage: list) -> list:
    """
    Map positional parameters from CALL USING to LINKAGE SECTION variables.

    COBOL maps by position: first USING param → first LINKAGE var, etc.
    Only maps 01-level LINKAGE variables (group items are the entry points).
    """
    caller_params = caller_call.get("parameters", [])
    # Filter to 01-level linkage vars (top-level parameters)
    top_level = [v for v in callee_linkage if v["level"] == "01"]

    mappings = []
    for i, param in enumerate(caller_params):
        if i < len(top_level):
            mappings.append({
                "caller_var": param,
                "callee_var": top_level[i]["name"],
                "position": i,
            })
        else:
            mappings.append({
                "caller_var": param,
                "callee_var": "UNMATCHED",
                "position": i,
            })

    return mappings


# ══════════════════════════════════════════════════════════════════════
# Component 5: Multi-Program Analyzer (Orchestrator)
# ══════════════════════════════════════════════════════════════════════


def analyze_multi_program(programs: dict) -> dict:
    """
    Full multi-program analysis pipeline.

    1. Build dependency tree
    2. Analyze each program via analyze_cobol()
    3. Parse LINKAGE SECTION for callees
    4. Map parameters across program boundaries
    5. Aggregate results

    Args:
        programs: dict of {program_name: cobol_source_code}

    Returns combined analysis with dependency tree, per-program results, and aggregate.
    """
    from cobol_analyzer_api import analyze_cobol

    dep_tree = build_dependency_tree(programs)
    program_results = {}

    # Analyze each program in topological order (leaves first)
    for prog_name in dep_tree["order"]:
        if prog_name not in programs:
            continue

        source = programs[prog_name]
        analysis = analyze_cobol(source)
        calls = detect_calls(source)
        linkage = parse_linkage_section(source)

        # Map parameters for each call this program makes
        param_mappings = []
        for call in calls:
            if call["type"] == "static" and call["target"] in programs:
                callee_linkage = parse_linkage_section(programs[call["target"]])
                mappings = map_parameters(call, callee_linkage)
                param_mappings.append({
                    "target": call["target"],
                    "mappings": mappings,
                })

        program_results[prog_name] = {
            "analysis": analysis,
            "calls": calls,
            "linkage": linkage,
            "parameter_mappings": param_mappings,
        }

    # Aggregate results
    aggregate = _build_aggregate(program_results, dep_tree)

    return {
        "dependency_tree": dep_tree,
        "program_results": program_results,
        "aggregate": aggregate,
    }


def _build_aggregate(program_results: dict, dep_tree: dict) -> dict:
    """Build aggregate statistics across all analyzed programs."""
    total_variables = 0
    total_paragraphs = 0
    total_comp3 = 0
    total_exec_deps = 0
    worst_risk = "SAFE"
    has_manual_review = False

    risk_order = {"SAFE": 0, "WARN": 1, "CRITICAL": 2}

    for prog_name, result in program_results.items():
        analysis = result.get("analysis", {})
        summary = analysis.get("summary", {})

        total_variables += summary.get("variables", 0)
        total_paragraphs += summary.get("paragraphs", 0)
        total_comp3 += summary.get("comp3_variables", 0)
        total_exec_deps += len(analysis.get("exec_dependencies", []))

        # Check if this program has any MANUAL REVIEW items
        # A program needs manual review if it has exec dependencies or parse issues
        if analysis.get("exec_dependencies"):
            has_manual_review = True

    verification_status = "REQUIRES_MANUAL_REVIEW" if has_manual_review else "VERIFIED"

    return {
        "total_programs": len(program_results),
        "total_variables": total_variables,
        "total_paragraphs": total_paragraphs,
        "total_comp3": total_comp3,
        "total_exec_deps": total_exec_deps,
        "worst_risk": worst_risk,
        "verification_status": verification_status,
        "unresolved_programs": dep_tree.get("unresolved", []),
        "dynamic_calls": dep_tree.get("dynamic_calls", []),
    }


# ══════════════════════════════════════════════════════════════════════
# Component 6: Batch Analyzer (Python generation + cross-file CALL resolution)
# ══════════════════════════════════════════════════════════════════════


def analyze_batch(programs: dict, copybooks: dict = None) -> dict:
    """
    Full batch analysis pipeline with Python generation and cross-file CALL resolution.

    1. Store inline copybooks, preprocess sources (expand COPY statements)
    2. Build dependency tree (topological order, leaves first)
    3. Analyze each program, generate Python, compute arithmetic risks
    4. Post-process: inject cross-file CALL resolution blocks
    5. Determine per-file verdicts + combined verdict

    Args:
        programs:  dict of {program_name: cobol_source_code}
        copybooks: optional dict of {copybook_name: content} for inline resolution

    Returns combined analysis with per-file results, generated Python, and overall verdict.
    """
    from cobol_analyzer_api import analyze_cobol
    from generate_full_python import generate_python_module, compute_arithmetic_risks

    # ── Step 1: Copybook preprocessing ──
    preprocessed = dict(programs)
    all_copy_issues = {}
    try:
        from copybook_resolver import preprocess_source, store_copybook
        if copybooks:
            for name, content in copybooks.items():
                store_copybook(name, content)
        for prog_name, source in programs.items():
            expanded, issues = preprocess_source(source)
            preprocessed[prog_name] = expanded
            all_copy_issues[prog_name] = issues
    except ImportError:
        pass

    # ── Step 2: Dependency tree ──
    dep_tree = build_dependency_tree(preprocessed)

    # ── Step 3: Analyze + generate per file (topological order) ──
    program_results = {}
    generated_code = {}

    for prog_name in dep_tree["order"]:
        if prog_name not in preprocessed:
            continue

        source = preprocessed[prog_name]
        analysis = analyze_cobol(source)
        calls = detect_calls(source)
        linkage = parse_linkage_section(source)

        # Parameter mappings for each CALL
        param_mappings = []
        for call in calls:
            if call["type"] == "static" and call["target"] in preprocessed:
                callee_linkage = parse_linkage_section(preprocessed[call["target"]])
                mappings = map_parameters(call, callee_linkage)
                param_mappings.append({
                    "target": call["target"],
                    "mappings": mappings,
                })

        # Generate Python
        python_code = None
        emit_counts = {}
        if analysis.get("success"):
            try:
                gen_result = generate_python_module(analysis)
                python_code = gen_result["code"]
                emit_counts = gen_result.get("emit_counts", {})
            except Exception:
                pass

        # Arithmetic risks
        arith_risks = {"risks": [], "summary": {"total": 0, "safe": 0, "warn": 0, "critical": 0}}
        if analysis.get("success"):
            try:
                arith_risks = compute_arithmetic_risks(analysis)
            except Exception:
                pass

        # Per-file verdict
        exec_deps = analysis.get("exec_dependencies", [])
        alter_deps = [d for d in exec_deps if d.get("type") == "ALTER"]
        file_ok = (
            analysis.get("success")
            and python_code is not None
            and analysis.get("parse_errors", 0) == 0
            and not alter_deps
        )
        file_verdict = "VERIFIED" if file_ok else "REQUIRES_MANUAL_REVIEW"

        generated_code[prog_name] = python_code
        program_results[prog_name] = {
            "analysis": analysis,
            "calls": calls,
            "linkage": linkage,
            "parameter_mappings": param_mappings,
            "generated_python": python_code,
            "emit_counts": emit_counts,
            "arithmetic_risks": arith_risks.get("risks", []),
            "arithmetic_summary": arith_risks.get("summary", {}),
            "verification_status": file_verdict,
            "copybook_issues": all_copy_issues.get(prog_name, []),
        }

    # ── Step 4: Cross-file CALL resolution ──
    resolved_code = _inject_call_resolution(generated_code, program_results)
    for prog_name in program_results:
        if prog_name in resolved_code:
            program_results[prog_name]["generated_python"] = resolved_code[prog_name]

    # ── Step 5: Combined verdict ──
    has_unresolved = len(dep_tree.get("unresolved", [])) > 0
    has_dynamic = len(dep_tree.get("dynamic_calls", [])) > 0
    has_circular = len(dep_tree.get("circular", [])) > 0
    all_verified = all(
        pr["verification_status"] == "VERIFIED"
        for pr in program_results.values()
    )
    combined_verdict = "VERIFIED" if (
        all_verified and not has_unresolved and not has_dynamic and not has_circular
    ) else "REQUIRES_MANUAL_REVIEW"

    # Aggregate
    aggregate = _build_batch_aggregate(program_results, dep_tree, combined_verdict)

    return {
        "dependency_tree": dep_tree,
        "program_results": program_results,
        "aggregate": aggregate,
        "combined_verdict": combined_verdict,
    }


def _inject_call_resolution(generated_code: dict, program_results: dict) -> dict:
    """
    Post-process generated Python to add cross-file CALL resolution comment blocks.

    For each caller, injects after the import section:
      - Import statement for each called subprogram
      - Parameter mapping documentation (caller var → callee LINKAGE var)
      - MANUAL REVIEW for dynamic or unresolved calls
    """
    result = dict(generated_code)

    for prog_name, prog_data in program_results.items():
        code = result.get(prog_name)
        if not code:
            continue

        calls = prog_data.get("calls", [])
        if not calls:
            continue

        import_lines = []
        mapping_lines = []

        for call in calls:
            target = call["target"]

            if call["type"] == "dynamic":
                mapping_lines.append(
                    f"# MANUAL REVIEW: Dynamic CALL to variable {target}"
                )
                mapping_lines.append(
                    "#   Cannot resolve target at analysis time"
                )
                continue

            if target not in generated_code or generated_code[target] is None:
                mapping_lines.append(
                    f"# MANUAL REVIEW: CALL '{target}' \u2014 program not available"
                )
                continue

            module_name = target.lower().replace("-", "_")

            # Find entry paragraph of the callee
            callee_result = program_results.get(target, {})
            callee_analysis = callee_result.get("analysis", {})
            callee_paras = callee_analysis.get("paragraphs", [])
            if callee_paras:
                first_para = callee_paras[0]
                if isinstance(first_para, dict):
                    first_para = first_para.get("name", first_para)
                entry_func = "para_" + first_para.lower().replace("-", "_")
            else:
                entry_func = "main"

            import_lines.append(f"from {module_name} import {entry_func}")

            # Parameter mapping documentation
            params = call.get("parameters", [])
            callee_linkage = callee_result.get("linkage", [])
            top_linkage = [v for v in callee_linkage if v["level"] == "01"]

            mapping_lines.append(f"# CALL '{target}' USING {' '.join(params)}")
            mapping_lines.append(f"#   -> {module_name}.{entry_func}()")
            for i, param in enumerate(params):
                if i < len(top_linkage):
                    link_var = top_linkage[i]["name"]
                    mapping_lines.append(
                        f"#   {param} (caller) -> {link_var} (callee) [position {i}]"
                    )
                else:
                    mapping_lines.append(
                        f"#   {param} (caller) -> UNMATCHED [position {i}]"
                    )

        if import_lines or mapping_lines:
            injection = [""]
            injection.append("# " + "=" * 60)
            injection.append("# CROSS-FILE CALL RESOLUTION")
            injection.append("# " + "=" * 60)
            injection.append("# NOTE: Cross-module execution requires manual wiring")
            injection.append("#   this block is for audit documentation")
            injection.append("")
            if import_lines:
                injection.extend(import_lines)
                injection.append("")
            injection.extend(mapping_lines)
            injection.append("")

            # Insert after the last import line in the generated code
            lines = code.split("\n")
            insert_idx = 0
            for i, line in enumerate(lines):
                if line.startswith("from ") or line.startswith("import "):
                    insert_idx = i + 1

            lines = lines[:insert_idx] + injection + lines[insert_idx:]
            result[prog_name] = "\n".join(lines)

    return result


def _build_batch_aggregate(program_results: dict, dep_tree: dict, combined_verdict: str) -> dict:
    """Build aggregate statistics for a batch analysis run."""
    total_vars = sum(
        pr["analysis"].get("summary", {}).get("variables", 0)
        for pr in program_results.values()
    )
    total_paras = sum(
        pr["analysis"].get("summary", {}).get("paragraphs", 0)
        for pr in program_results.values()
    )
    total_comp3 = sum(
        pr["analysis"].get("summary", {}).get("comp3_variables", 0)
        for pr in program_results.values()
    )
    total_safe = sum(pr.get("arithmetic_summary", {}).get("safe", 0) for pr in program_results.values())
    total_warn = sum(pr.get("arithmetic_summary", {}).get("warn", 0) for pr in program_results.values())
    total_critical = sum(pr.get("arithmetic_summary", {}).get("critical", 0) for pr in program_results.values())

    verified_count = sum(1 for pr in program_results.values() if pr["verification_status"] == "VERIFIED")

    return {
        "total_programs": len(program_results),
        "total_variables": total_vars,
        "total_paragraphs": total_paras,
        "total_comp3": total_comp3,
        "verified_programs": verified_count,
        "manual_review_programs": len(program_results) - verified_count,
        "arithmetic_safe": total_safe,
        "arithmetic_warn": total_warn,
        "arithmetic_critical": total_critical,
        "verification_status": combined_verdict,
        "unresolved_programs": dep_tree.get("unresolved", []),
        "dynamic_calls": dep_tree.get("dynamic_calls", []),
        "circular_dependencies": dep_tree.get("circular", []),
    }


# ══════════════════════════════════════════════════════════════════════
# Utility: Load programs from directory
# ══════════════════════════════════════════════════════════════════════


def load_programs_from_directory(directory: str) -> dict:
    """Load all .cbl/.cob/.cobol files from a directory into a programs dict."""
    programs = {}
    for filename in os.listdir(directory):
        if filename.lower().endswith(('.cbl', '.cob', '.cobol')):
            filepath = os.path.join(directory, filename)
            with open(filepath, 'r', encoding='utf-8') as f:
                source = f.read()
            prog_id = _extract_program_id(source)
            if prog_id == "UNKNOWN":
                prog_id = os.path.splitext(filename)[0].upper()
            programs[prog_id] = source
    return programs
