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
        self.current_paragraph = None
        self.graph = nx.DiGraph()
    
    def enterParagraph(self, ctx):
        name = ctx.paragraphName().getText()
        self.current_paragraph = name
        self.paragraphs.append(name)
        self.graph.add_node(name)
    
    def enterPerformStatement(self, ctx):
        if ctx.performProcedureStatement():
            proc = ctx.performProcedureStatement()
            if proc.procedureName():
                for pn in proc.procedureName():
                    target = pn.getText()
                    self.performs.append({"from": self.current_paragraph, "to": target})
                    self.graph.add_edge(self.current_paragraph, target)
    
    def enterComputeStatement(self, ctx):
        self.computes.append({
            "paragraph": self.current_paragraph,
            "statement": ctx.getText()
        })
    
    def enterIfStatement(self, ctx):
        self.conditions.append({
            "paragraph": self.current_paragraph,
            "statement": ctx.getText()
        })
    
    def enterDataDescriptionEntryFormat1(self, ctx):
        text = ctx.getText()
        is_comp3 = "COMP-3" in text.upper()
        self.variables.append({
            "raw": text[:60],
            "comp3": is_comp3
        })

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