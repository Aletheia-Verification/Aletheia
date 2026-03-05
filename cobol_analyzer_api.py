import re
from decimal import Decimal
import networkx as nx
from antlr4 import CommonTokenStream, InputStream
from Cobol85Lexer import Cobol85Lexer
from Cobol85Parser import Cobol85Parser
from antlr4 import ParseTreeWalker
from Cobol85Listener import Cobol85Listener


def parse_pic_clause(pic_raw):
    """
    Parse a PIC clause string (from getText(), no spaces) into structured metadata.

    Examples:
        "S9(5)V99"   -> {signed:True,  integers:5,  decimals:2}
        "9(3)"       -> {signed:False, integers:3,  decimals:0}
        "S9(1)V9(8)" -> {signed:True,  integers:1,  decimals:8}
        "X(10)"      -> None  (string type)

    Returns dict or None (for string/unknown types).
    """
    upper = pic_raw.upper().strip()
    if not upper or 'X' in upper or 'Z' in upper:
        return None  # String or edited type — skip arithmetic analysis

    signed = upper.startswith('S')
    if signed:
        upper = upper[1:]

    int_part, dec_part = (upper.split('V', 1) if 'V' in upper else (upper, ''))

    def count_nines(part):
        return sum(
            int(m.group(1)) if m.group(1) else 1
            for m in re.finditer(r'9(?:\((\d+)\))?', part)
        )

    integers = count_nines(int_part)
    decimals = count_nines(dec_part) if dec_part else 0

    if integers == 0:
        return None  # No integer digits — not a standard numeric

    max_str = '9' * integers + ('.' + '9' * decimals if decimals else '')
    max_val = Decimal(max_str)
    return {
        "signed": signed,
        "integers": integers,
        "decimals": decimals,
        "max_value": str(max_val),
        "min_value": str(-max_val if signed else Decimal('0')),
    }


class FullAnalyzer(Cobol85Listener):
    def __init__(self):
        self.paragraphs = []
        self.variables = []
        self.performs = []
        self.computes = []
        self.conditions = []
        self.level_88s = []
        self.perform_varyings = []
        self.moves = []
        self.gotos = []
        self.stops = []
        self.evaluates = []
        self.arithmetics = []   # ADD, SUBTRACT, MULTIPLY, DIVIDE statements
        self.current_paragraph = None
        self.last_variable_name = None
        self.paragraph_lines = {}
        self.graph = nx.DiGraph()

    # ── Paragraphs ───────────────────────────────────────────────

    def enterParagraph(self, ctx):
        name = ctx.paragraphName().getText()
        self.current_paragraph = name
        self.paragraphs.append(name)
        self.paragraph_lines[name] = ctx.start.line
        self.graph.add_node(name)

    # ── PERFORM ──────────────────────────────────────────────────

    def enterPerformStatement(self, ctx):
        if ctx.performProcedureStatement():
            proc = ctx.performProcedureStatement()
            if proc.procedureName():
                for pn in proc.procedureName():
                    target = pn.getText()
                    self.performs.append({"from": self.current_paragraph, "to": target, "line": ctx.start.line, "statement": ctx.getText()})
                    self.graph.add_edge(self.current_paragraph, target)

    # ── PERFORM VARYING ──────────────────────────────────────────

    def enterPerformVaryingPhrase(self, ctx):
        try:
            varying_var = ctx.identifier().getText() if ctx.identifier() else None
            from_val = ctx.performFrom().getText() if ctx.performFrom() else None
            by_val = ctx.performBy().getText() if ctx.performBy() else None
            until_cond = ctx.performUntil().getText() if ctx.performUntil() else None

            self.perform_varyings.append({
                "paragraph": self.current_paragraph,
                "variable": varying_var,
                "from": from_val,
                "by": by_val,
                "until": until_cond,
            })
        except Exception:
            pass

    # ── COMPUTE ──────────────────────────────────────────────────

    def enterComputeStatement(self, ctx):
        self.computes.append({
            "paragraph": self.current_paragraph,
            "statement": ctx.getText(),
            "line": ctx.start.line,
        })

    # ── Standalone Arithmetic (ADD, SUBTRACT, MULTIPLY, DIVIDE) ──

    def enterAddStatement(self, ctx):
        self.arithmetics.append({
            "paragraph": self.current_paragraph,
            "verb": "ADD",
            "statement": ctx.getText(),
            "line": ctx.start.line,
        })

    def enterSubtractStatement(self, ctx):
        self.arithmetics.append({
            "paragraph": self.current_paragraph,
            "verb": "SUBTRACT",
            "statement": ctx.getText(),
            "line": ctx.start.line,
        })

    def enterMultiplyStatement(self, ctx):
        self.arithmetics.append({
            "paragraph": self.current_paragraph,
            "verb": "MULTIPLY",
            "statement": ctx.getText(),
            "line": ctx.start.line,
        })

    def enterDivideStatement(self, ctx):
        self.arithmetics.append({
            "paragraph": self.current_paragraph,
            "verb": "DIVIDE",
            "statement": ctx.getText(),
            "line": ctx.start.line,
        })

    # ── MOVE ──────────────────────────────────────────────────────

    def enterMoveStatement(self, ctx):
        move_to = ctx.moveToStatement()
        move_corr = ctx.moveCorrespondingToStatement()

        if move_to:
            sending_area = move_to.moveToSendingArea()
            from_val = sending_area.getText() if sending_area else ""
            to_fields = [ident.getText() for ident in (move_to.identifier() or [])]
            self.moves.append({
                "paragraph": self.current_paragraph,
                "from": from_val,
                "to": to_fields,
                "corresponding": False,
                "statement": ctx.getText(),
                "line": ctx.start.line,
            })
        elif move_corr:
            sending_area = move_corr.moveCorrespondingToSendingArea()
            from_val = sending_area.getText() if sending_area else ""
            to_fields = [ident.getText() for ident in (move_corr.identifier() or [])]
            self.moves.append({
                "paragraph": self.current_paragraph,
                "from": from_val,
                "to": to_fields,
                "corresponding": True,
                "statement": ctx.getText(),
                "line": ctx.start.line,
            })

    # ── GO TO ────────────────────────────────────────────────────

    def enterGoToStatement(self, ctx):
        simple = ctx.goToStatementSimple()
        depending = ctx.goToDependingOnStatement()

        if simple:
            target = simple.procedureName().getText() if simple.procedureName() else ""
            self.gotos.append({
                "paragraph": self.current_paragraph,
                "targets": [target],
                "depending_on": None,
                "statement": ctx.getText(),
                "line": ctx.start.line,
            })
        elif depending:
            targets = [pn.getText() for pn in (depending.procedureName() or [])]
            dep_var = depending.identifier().getText() if depending.identifier() else None
            self.gotos.append({
                "paragraph": self.current_paragraph,
                "targets": targets,
                "depending_on": dep_var,
                "statement": ctx.getText(),
                "line": ctx.start.line,
            })

    # ── STOP ─────────────────────────────────────────────────────

    def enterStopStatement(self, ctx):
        self.stops.append({
            "paragraph": self.current_paragraph,
            "statement": ctx.getText(),
            "line": ctx.start.line,
        })

    # ── IF — structured AST walk ─────────────────────────────────

    def enterIfStatement(self, ctx):
        condition_text = ctx.condition().getText() if ctx.condition() else ""

        then_stmts = []
        if ctx.ifThen():
            for stmt in ctx.ifThen().statement():
                then_stmts.append(stmt.getText())

        else_stmts = []
        if ctx.ifElse():
            for stmt in ctx.ifElse().statement():
                else_stmts.append(stmt.getText())

        self.conditions.append({
            "paragraph": self.current_paragraph,
            "statement": ctx.getText(),
            "condition": condition_text,
            "then_statements": then_stmts,
            "else_statements": else_stmts,
            "has_nested_if": any("IF" in s.upper() for s in then_stmts + else_stmts),
            "line": ctx.start.line,
        })

    # ── EVALUATE ────────────────────────────────────────────────

    def enterEvaluateStatement(self, ctx):
        select_ctx = ctx.evaluateSelect()
        subject_text = select_ctx.getText() if select_ctx else ""

        has_also = len(ctx.evaluateAlsoSelect()) > 0

        when_clauses = []
        for phrase_ctx in ctx.evaluateWhenPhrase():
            conditions = []
            for when_ctx in phrase_ctx.evaluateWhen():
                cond_ctx = when_ctx.evaluateCondition()
                cond_text = cond_ctx.getText() if cond_ctx else ""
                has_also = has_also or len(when_ctx.evaluateAlsoCondition()) > 0
                conditions.append(cond_text)

            body_stmts = [s.getText() for s in phrase_ctx.statement()]
            when_clauses.append({
                "conditions": conditions,
                "body_statements": body_stmts,
            })

        when_other_stmts = []
        other_ctx = ctx.evaluateWhenOther()
        if other_ctx:
            when_other_stmts = [s.getText() for s in other_ctx.statement()]

        self.evaluates.append({
            "paragraph": self.current_paragraph,
            "subject": subject_text,
            "has_also": has_also,
            "when_clauses": when_clauses,
            "when_other_statements": when_other_stmts,
            "statement": ctx.getText(),
            "line": ctx.start.line,
        })

    # ── Variables (05-level) ─────────────────────────────────────

    def enterDataDescriptionEntryFormat1(self, ctx):
        text = ctx.getText()
        upper = text.upper()
        is_comp3 = "COMP-3" in upper

        # Extract variable name (lazy match stops before PIC/VALUE/.)
        name_match = re.match(r'^\d{2}([A-Z][A-Z0-9\-]+?)(?:PIC|VALUE|\.)', upper)
        name = name_match.group(1) if name_match else None
        if name:
            self.last_variable_name = name

        # Extract PIC clause (everything between PIC and the next keyword or .)
        pic_match = re.search(r'PIC([SX9ZV()\d]+?)(?=COMP|VALUE|OCCURS|\.)', upper)
        pic_raw = pic_match.group(1) if pic_match else ""
        pic_info = parse_pic_clause(pic_raw) if pic_raw else None

        self.variables.append({
            "raw": text[:60],
            "name": name,
            "pic_raw": pic_raw,
            "pic_info": pic_info,
            "comp3": is_comp3,
        })

    # ── 88-level conditions ──────────────────────────────────────

    def enterDataDescriptionEntryFormat3(self, ctx):
        try:
            cond_name = ctx.conditionName().getText() if ctx.conditionName() else None
            value_clause = ctx.dataValueClause().getText() if ctx.dataValueClause() else ""

            # Extract the actual value from VALUE 'X' or VALUE X
            value = ""
            val_match = re.search(r"VALUE[S]?\s*'([^']*)'", value_clause, re.IGNORECASE)
            if val_match:
                value = val_match.group(1)
            else:
                val_match = re.search(r"VALUE[S]?\s*(\S+)", value_clause, re.IGNORECASE)
                if val_match:
                    value = val_match.group(1).strip(".")

            if cond_name:
                self.level_88s.append({
                    "name": cond_name,
                    "parent": self.last_variable_name or "UNKNOWN",
                    "value": value,
                })
        except Exception:
            pass


def strip_exec_blocks(cobol_source: str) -> tuple:
    """
    Strip EXEC SQL / EXEC CICS / EXEC SQLIMS blocks before ANTLR4 parsing.

    ANTLR4's COBOL85 grammar tokenizes these as line-level tokens but the
    parser cannot handle the embedded SQL/CICS syntax, producing dozens of
    spurious parse errors.  We replace each block with a CONTINUE statement
    (valid COBOL no-op) and record the external dependency for the report.

    Returns (cleaned_source, list_of_exec_dependency_dicts).
    """
    EXEC_PATTERN = re.compile(
        r'(\s*EXEC\s+(SQL|CICS|SQLIMS)\b)(.*?)(END-EXEC)',
        re.DOTALL | re.IGNORECASE,
    )

    dependencies = []

    def _replace(match):
        exec_type = match.group(2).upper()
        body = match.group(3).strip().replace('\n', ' ')
        # First keyword of the embedded statement (SELECT, INSERT, UPDATE, SEND, etc.)
        verb_match = re.match(r'(\w+)', body)
        verb = verb_match.group(1).upper() if verb_match else "UNKNOWN"

        dependencies.append({
            "type": f"EXEC {exec_type}",
            "verb": verb,
            "body_preview": body[:120],
            "flag": "EXTERNAL DEPENDENCY — REQUIRES MANUAL REVIEW",
        })
        # Replace with a COBOL CONTINUE (no-op) to keep paragraph flow valid
        return "           CONTINUE"

    cleaned = EXEC_PATTERN.sub(_replace, cobol_source)
    return cleaned, dependencies


def analyze_cobol(cobol_source: str) -> dict:
    """
    Analyze COBOL source code and return structured JSON.
    """
    # Preprocess EXEC SQL/CICS/SQLIMS blocks (must run BEFORE ANTLR4)
    exec_dependencies = []
    cobol_source, exec_dependencies = strip_exec_blocks(cobol_source)

    # Detect ALTER statements — runtime control flow mutation makes static
    # verification impossible.  This is a hard stop.
    ALTER_PATTERN = re.compile(
        r'^\s{6}\s+ALTER\s+(\S+)\s+TO\s+(?:PROCEED\s+TO\s+)?(\S+)',
        re.IGNORECASE | re.MULTILINE,
    )
    for m in ALTER_PATTERN.finditer(cobol_source):
        exec_dependencies.append({
            "type": "ALTER",
            "source_paragraph": m.group(1).strip('.'),
            "target_paragraph": m.group(2).strip('.'),
            "body_preview": m.group(0).strip(),
            "flag": "RUNTIME MUTATION DETECTED — ALTER statement modifies control flow at runtime. Static verification is not possible for this program.",
            "line": cobol_source[:m.start()].count('\n') + 1,
        })

    # Detect OCCURS DEPENDING ON — variable-length records that may break
    # fixed-width parsing assumptions in Shadow Diff.
    ODO_PATTERN = re.compile(
        r'^\s{6}\s+\d{2}\s+(\S+).*?OCCURS\s+\d+\s+TO\s+(\d+)\s+(?:TIMES\s+)?DEPENDING\s+ON\s+(\S+)',
        re.IGNORECASE | re.MULTILINE,
    )
    for m in ODO_PATTERN.finditer(cobol_source):
        exec_dependencies.append({
            "type": "ODO",
            "field_name": m.group(1).strip('.'),
            "max_occurs": int(m.group(2)),
            "depending_on": m.group(3).strip('.'),
            "body_preview": m.group(0).strip(),
            "flag": "VARIABLE-LENGTH RECORDS DETECTED — OCCURS DEPENDING ON requires dynamic record parsing. Fixed-width reader may produce incorrect results for this data structure.",
        })

    # Preprocess COPY statements (lazy — works without copybook_resolver)
    copy_issues = []
    try:
        from copybook_resolver import preprocess_source
        cobol_source, copy_issues = preprocess_source(cobol_source)
    except ImportError:
        pass

    input_stream = InputStream(cobol_source)
    lexer = Cobol85Lexer(input_stream)
    token_stream = CommonTokenStream(lexer)
    parser = Cobol85Parser(token_stream)
    tree = parser.startRule()

    # Count syntax errors but DO NOT bail out — ANTLR4 error recovery means
    # the parse tree is still walkable and useful even with errors/warnings.
    parse_errors = parser.getNumberOfSyntaxErrors()

    analyzer = FullAnalyzer()
    walker = ParseTreeWalker()
    walker.walk(analyzer, tree)

    # Assign ALTER entries to paragraphs using line numbers
    if analyzer.paragraph_lines:
        para_boundaries = sorted(analyzer.paragraph_lines.items(), key=lambda x: x[1])
        for dep in exec_dependencies:
            if dep["type"] == "ALTER" and "line" in dep:
                alter_line = dep["line"]
                for i, (pname, pline) in enumerate(para_boundaries):
                    next_line = para_boundaries[i + 1][1] if i + 1 < len(para_boundaries) else float('inf')
                    if pline <= alter_line < next_line:
                        dep["paragraph"] = pname
                        break

    # Detect cycles
    cycles = list(nx.simple_cycles(analyzer.graph))

    # Detect unreachable code
    unreachable = []
    if analyzer.paragraphs:
        entry = analyzer.paragraphs[0]
        reachable = set(nx.descendants(analyzer.graph, entry)) | {entry}
        unreachable = list(set(analyzer.paragraphs) - reachable)

    # success = True whenever we extracted any meaningful structure.
    # parse_errors > 0 means non-standard syntax was encountered but data
    # may still be complete (e.g. extra tokens at EOF, unrecognised chars).
    got_data = len(analyzer.paragraphs) > 0 or len(analyzer.variables) > 0

    result = {
        "success": got_data,
        "parse_errors": parse_errors,
        "parse_warning": (
            f"{parse_errors} syntax warning(s) — data extracted via error recovery"
            if parse_errors > 0 else None
        ),
        "summary": {
            "paragraphs": len(analyzer.paragraphs),
            "variables": len(analyzer.variables),
            "comp3_variables": sum(1 for v in analyzer.variables if v["comp3"]),
            "perform_calls": len(analyzer.performs),
            "compute_statements": len(analyzer.computes),
            "move_statements": len(analyzer.moves),
            "goto_statements": len(analyzer.gotos),
            "stop_statements": len(analyzer.stops),
            "business_rules": len(analyzer.conditions),
            "evaluate_statements": len(analyzer.evaluates),
            "arithmetic_statements": len(analyzer.arithmetics),
            "cycles": len(cycles),
            "unreachable": len(unreachable)
        },
        "paragraphs": analyzer.paragraphs,
        "variables": analyzer.variables,
        "control_flow": analyzer.performs,
        "computes": analyzer.computes,
        "moves": analyzer.moves,
        "gotos": analyzer.gotos,
        "stops": analyzer.stops,
        "conditions": analyzer.conditions,
        "evaluates": analyzer.evaluates,
        "arithmetics": analyzer.arithmetics,
        "level_88": analyzer.level_88s,
        "perform_varyings": analyzer.perform_varyings,
        "paragraph_lines": analyzer.paragraph_lines,
        "cycles": cycles,
        "unreachable": unreachable,
        "copybook_issues": copy_issues,
        "exec_dependencies": exec_dependencies,
    }

    # EXEC SQL/CICS deep analysis (lazy — works without exec_sql_parser)
    if exec_dependencies:
        try:
            from exec_sql_parser import analyze_exec_blocks
            result["exec_analysis"] = analyze_exec_blocks(
                exec_dependencies, analyzer.conditions, analyzer.variables,
            )
        except ImportError:
            result["exec_analysis"] = None
    else:
        result["exec_analysis"] = None

    # REDEFINES analysis (lazy — works without copybook_resolver)
    try:
        from copybook_resolver import resolve_redefines
        result["redefines"] = resolve_redefines(analyzer.variables)
    except ImportError:
        result["redefines"] = {
            "memory_map": [], "redefines_groups": [],
            "ambiguous_references": [],
        }

    return result

# Test it
if __name__ == "__main__":
    with open("DEMO_LOAN_INTEREST.cbl", "r") as f:
        test_cobol = f.read()
    result = analyze_cobol(test_cobol)
    import json
    print(json.dumps(result, indent=2))
