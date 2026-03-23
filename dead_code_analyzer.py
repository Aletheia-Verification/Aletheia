"""Dead Code Analyzer — paragraph-level reachability for COBOL programs.

Consumes parser_output from cobol_analyzer_api.analyze_cobol() and builds
an enhanced call graph that includes PERFORM edges, GO TO edges, PERFORM THRU
intermediate paragraphs, and sequential fall-through.  Returns unreachable
paragraphs with line numbers and a dead-code percentage.
"""

from collections import deque


def analyze_dead_code(parser_output: dict) -> dict:
    """Analyze paragraph reachability in a single COBOL program.

    Args:
        parser_output: dict returned by analyze_cobol()

    Returns:
        dict with unreachable_paragraphs, total/reachable counts,
        dead_percentage, and has_alter flag.
    """
    paragraphs = parser_output.get("paragraphs", [])
    paragraph_lines = parser_output.get("paragraph_lines", {})
    control_flow = parser_output.get("control_flow", [])   # PERFORM entries
    gotos = parser_output.get("gotos", [])
    stops = parser_output.get("stops", [])
    exec_deps = parser_output.get("exec_dependencies", [])

    empty = {
        "unreachable_paragraphs": [],
        "total_paragraphs": 0,
        "reachable_paragraphs": 0,
        "dead_percentage": 0.0,
        "has_alter": False,
    }

    if not paragraphs:
        return empty

    all_paras = set(paragraphs)

    # ── Build adjacency list ────────────────────────────────────
    graph: dict[str, set[str]] = {p: set() for p in paragraphs}

    # 1. PERFORM edges
    for cf in control_flow:
        src = cf.get("from")
        tgt = cf.get("to")
        if src and tgt and src in all_paras and tgt in all_paras:
            graph[src].add(tgt)

    # 2. GO TO edges
    for g in gotos:
        src = g.get("paragraph")
        if src and src in all_paras:
            for tgt in g.get("targets", []):
                if tgt in all_paras:
                    graph[src].add(tgt)

    # 3. PERFORM THRU — two control_flow entries with same from + line
    #    represent PERFORM A THRU B; mark all intermediate paragraphs
    thru_pairs: dict[tuple, list[str]] = {}
    for cf in control_flow:
        key = (cf.get("from"), cf.get("line"))
        thru_pairs.setdefault(key, []).append(cf.get("to"))

    for (src, _line), targets in thru_pairs.items():
        if len(targets) >= 2:
            first = targets[0]
            last = targets[-1]
            if first in all_paras and last in all_paras:
                try:
                    i_start = paragraphs.index(first)
                    i_end = paragraphs.index(last)
                except ValueError:
                    continue
                if i_start > i_end:
                    i_start, i_end = i_end, i_start
                # Chain sequential fall-through edges through the range
                for i in range(i_start, i_end):
                    graph.setdefault(paragraphs[i], set()).add(paragraphs[i + 1])

    # 4. Fall-through edges (paragraph[i] → paragraph[i+1])
    #    Skip if paragraph[i] ends with GO TO or STOP RUN
    #    Skip if paragraph[i] is a PERFORM target (returns to caller, not fall-through)
    goto_paras = {g["paragraph"] for g in gotos if g.get("paragraph")}
    stop_paras = {s["paragraph"] for s in stops if s.get("paragraph")}
    terminal_paras = goto_paras | stop_paras

    perform_targets = set()
    for cf in control_flow:
        tgt = cf.get("to")
        if tgt and tgt in all_paras:
            perform_targets.add(tgt)

    for i in range(len(paragraphs) - 1):
        if paragraphs[i] not in terminal_paras and paragraphs[i] not in perform_targets:
            graph[paragraphs[i]].add(paragraphs[i + 1])

    # ── Seed BFS ────────────────────────────────────────────────
    seeds: set[str] = set()

    # First named paragraph is always reachable
    seeds.add(paragraphs[0])

    # Implicit main section: performs/gotos with from=None
    for cf in control_flow:
        if cf.get("from") is None and cf.get("to") in all_paras:
            seeds.add(cf["to"])

    for g in gotos:
        if g.get("paragraph") is None:
            for tgt in g.get("targets", []):
                if tgt in all_paras:
                    seeds.add(tgt)

    # ALTER safety: if any ALTER exists, mark all ALTER target paragraphs
    # as reachable (ALTER makes static analysis incomplete)
    has_alter = False
    for dep in exec_deps:
        if dep.get("type") == "ALTER":
            has_alter = True
            # ALTER changes GO TO targets at runtime — mark the paragraph
            # containing the ALTER and any referenced paragraphs as reachable
            if dep.get("paragraph") and dep["paragraph"] in all_paras:
                seeds.add(dep["paragraph"])
            # Also parse targets from ALTER statement text if available
            for tgt in dep.get("targets", []):
                if tgt in all_paras:
                    seeds.add(tgt)

    # If ALTER present, conservatively mark ALL paragraphs reachable
    if has_alter:
        reachable = all_paras.copy()
    else:
        # ── BFS ─────────────────────────────────────────────────
        reachable: set[str] = set()
        queue = deque(seeds)
        while queue:
            node = queue.popleft()
            if node in reachable:
                continue
            reachable.add(node)
            for neighbor in graph.get(node, set()):
                if neighbor not in reachable:
                    queue.append(neighbor)

    # ── Result ──────────────────────────────────────────────────
    unreachable = sorted(
        [p for p in paragraphs if p not in reachable],
        key=lambda p: paragraph_lines.get(p, 0),
    )

    total = len(paragraphs)
    reachable_count = total - len(unreachable)
    dead_pct = round((len(unreachable) / total) * 100, 1) if total > 0 else 0.0

    return {
        "unreachable_paragraphs": [
            {"name": p, "line": paragraph_lines.get(p, 0)} for p in unreachable
        ],
        "total_paragraphs": total,
        "reachable_paragraphs": reachable_count,
        "dead_percentage": dead_pct,
        "has_alter": has_alter,
    }
