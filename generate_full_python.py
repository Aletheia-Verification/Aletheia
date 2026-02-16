import re
from cobol_analyzer_api import analyze_cobol

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
    """Extract PIC clause info for Decimal precision."""
    raw_upper = raw.upper()
    
    v_match = re.search(r'V9\((\d+)\)', raw_upper)
    if v_match:
        return int(v_match.group(1))
    
    v_match = re.search(r'V(9+)', raw_upper)
    if v_match:
        return len(v_match.group(1))
    
    return 0

def parse_compute(statement, known_variables):
    """Turn COBOL COMPUTE into Python assignment."""
    stmt = statement.replace("COMPUTE", "").strip()
    
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
            
            if text[i:i+8].upper() == "FUNCTION":
                i += 8
                continue
            
            if text[i:i+7].upper() == "INTEGER":
                tokens.append("int")
                i += 7
                continue
            
            if text[i].isalpha():
                best_match = None
                for var in known_vars:
                    if text[i:i+len(var)].upper() == var.upper():
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
    """Generate complete Python module from COBOL source."""
    analysis = analyze_cobol(cobol_source)
    
    if not analysis["success"]:
        return f"# PARSE ERROR: {analysis['message']}"
    
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
                "python_name": to_python_name(name)
            }
    
    lines = []
    
    lines.append('"""')
    lines.append(f"Auto-generated Python from COBOL")
    lines.append(f"Paragraphs: {len(analysis['paragraphs'])}")
    lines.append(f"Variables: {len(analysis['variables'])}")
    lines.append(f"COMP-3 fields: {analysis['summary']['comp3_variables']}")
    lines.append('"""')
    lines.append("")
    lines.append("from decimal import Decimal, ROUND_DOWN, ROUND_HALF_UP, getcontext")
    lines.append("")
    lines.append("# Set precision to match IBM COBOL ARITH(EXTEND)")
    lines.append("getcontext().prec = 31")
    lines.append("")
    lines.append("# " + "=" * 60)
    lines.append("# WORKING-STORAGE VARIABLES")
    lines.append("# " + "=" * 60)
    lines.append("")
    
    for name, info in var_info.items():
        py_name = info["python_name"]
        decimals = info["decimals"]
        comp3 = info["comp3"]
        
        if decimals > 0:
            default = f"Decimal('0.{'0' * decimals}')"
        else:
            default = "Decimal('0')"
        
        comment = "  # COMP-3 packed decimal" if comp3 else ""
        lines.append(f"{py_name} = {default}{comment}")
    
    lines.append("")
    lines.append("# " + "=" * 60)
    lines.append("# PROCEDURE DIVISION")
    lines.append("# " + "=" * 60)
    lines.append("")
    
    computes_by_para = {}
    for c in analysis["computes"]:
        para = c["paragraph"]
        if para not in computes_by_para:
            computes_by_para[para] = []
        computes_by_para[para].append(c["statement"])
    
    global_vars = ", ".join(sorted([v["python_name"] for v in var_info.values()]))
    
    for para in analysis["paragraphs"]:
        func_name = "para_" + to_python_name(para)
        lines.append(f"def {func_name}():")
        lines.append(f'    """COBOL Paragraph: {para}"""')
        lines.append(f"    global {global_vars}")
        lines.append("")
        
        if para in computes_by_para:
            for stmt in computes_by_para[para]:
                py_stmt = parse_compute(stmt, known_vars)
                if py_stmt:
                    lines.append(f"    {py_stmt}")
        else:
            lines.append("    pass  # No COMPUTE statements")
        
        lines.append("")
    
    lines.append("# " + "=" * 60)
    lines.append("# MAIN EXECUTION")
    lines.append("# " + "=" * 60)
    lines.append("")
    lines.append("def main():")
    
    for flow in analysis["control_flow"]:
        target = "para_" + to_python_name(flow["to"])
        lines.append(f"    {target}()")
    
    lines.append("")
    lines.append("")
    lines.append('if __name__ == "__main__":')
    lines.append("    main()")
    
    return "\n".join(lines)


if __name__ == "__main__":
    with open("DEMO_LOAN_INTEREST.cbl", "r") as f:
        cobol_source = f.read()
    
    python_code = generate_python_module(cobol_source)
    
    with open("converted_loan_interest.py", "w") as f:
        f.write(python_code)
    
    print("Generated: converted_loan_interest.py")
    print()
    print(python_code)