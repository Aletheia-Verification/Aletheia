import re
import networkx as nx
from antlr4 import CommonTokenStream, InputStream
from Cobol85Lexer import Cobol85Lexer
from Cobol85Parser import Cobol85Parser
from antlr4 import ParseTreeWalker
from Cobol85Listener import Cobol85Listener


class FullAnalyzer(Cobol85Listener):
    def __init__(self):
        self.paragraphs = []
        self.variables = []
        self.performs = []
        self.computes = []
        self.conditions = []
        self.level_88s = []
        self.perform_varyings = []
        self.current_paragraph = None
        self.last_variable_name = None
        self.graph = nx.DiGraph()

    # ── Paragraphs ───────────────────────────────────────────────

    def enterParagraph(self, ctx):
        name = ctx.paragraphName().getText()
        self.current_paragraph = name
        self.paragraphs.append(name)
        self.graph.add_node(name)

    # ── PERFORM ──────────────────────────────────────────────────

    def enterPerformStatement(self, ctx):
        if ctx.performProcedureStatement():
            proc = ctx.performProcedureStatement()
            if proc.procedureName():
                for pn in proc.procedureName():
                    target = pn.getText()
                    self.performs.append({"from": self.current_paragraph, "to": target})
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
            "statement": ctx.getText()
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
        })

    # ── Variables (05-level) ─────────────────────────────────────

    def enterDataDescriptionEntryFormat1(self, ctx):
        text = ctx.getText()
        is_comp3 = "COMP-3" in text.upper()

        # Extract variable name for 88-level parent tracking
        # Use lazy match + look-ahead to stop before PIC/VALUE/. (getText() strips spaces)
        name_match = re.match(r'^\d{2}([A-Z][A-Z0-9\-]+?)(?:PIC|VALUE|\.)', text.upper())
        if name_match:
            self.last_variable_name = name_match.group(1)

        self.variables.append({
            "raw": text[:60],
            "comp3": is_comp3
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


def analyze_cobol(cobol_source: str) -> dict:
    """
    Analyze COBOL source code and return structured JSON.
    """
    input_stream = InputStream(cobol_source)
    lexer = Cobol85Lexer(input_stream)
    token_stream = CommonTokenStream(lexer)
    parser = Cobol85Parser(token_stream)
    tree = parser.startRule()

    errors = parser.getNumberOfSyntaxErrors()
    if errors > 0:
        return {
            "success": False,
            "errors": errors,
            "message": f"Parse failed with {errors} syntax errors"
        }

    analyzer = FullAnalyzer()
    walker = ParseTreeWalker()
    walker.walk(analyzer, tree)

    # Detect cycles
    cycles = list(nx.simple_cycles(analyzer.graph))

    # Detect unreachable code
    unreachable = []
    if analyzer.paragraphs:
        entry = analyzer.paragraphs[0]
        reachable = set(nx.descendants(analyzer.graph, entry)) | {entry}
        unreachable = list(set(analyzer.paragraphs) - reachable)

    return {
        "success": True,
        "summary": {
            "paragraphs": len(analyzer.paragraphs),
            "variables": len(analyzer.variables),
            "comp3_variables": sum(1 for v in analyzer.variables if v["comp3"]),
            "perform_calls": len(analyzer.performs),
            "compute_statements": len(analyzer.computes),
            "business_rules": len(analyzer.conditions),
            "cycles": len(cycles),
            "unreachable": len(unreachable)
        },
        "paragraphs": analyzer.paragraphs,
        "variables": analyzer.variables,
        "control_flow": analyzer.performs,
        "computes": analyzer.computes,
        "conditions": analyzer.conditions,
        "level_88": analyzer.level_88s,
        "perform_varyings": analyzer.perform_varyings,
        "cycles": cycles,
        "unreachable": unreachable
    }

# Test it
if __name__ == "__main__":
    with open("DEMO_LOAN_INTEREST.cbl", "r") as f:
        test_cobol = f.read()
    result = analyze_cobol(test_cobol)
    import json
    print(json.dumps(result, indent=2))
