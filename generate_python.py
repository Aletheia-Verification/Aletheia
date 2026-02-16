import re

def parse_compute(statement, known_variables=None):
    """
    Turn COBOL COMPUTE into Python assignment.
    Uses known_variables to correctly identify subtraction vs variable names.
    """
    if known_variables is None:
        known_variables = set()
    
    # Remove COMPUTE keyword
    stmt = statement.replace("COMPUTE", "").strip()
    
    if "=" not in stmt:
        return None
    
    parts = stmt.split("=", 1)
    target = parts[0].strip()
    expr = parts[1].strip()
    
    def to_python_name(name):
        return name.lower().replace("-", "_")
    
    def tokenize_expr(text, known_vars):
        """
        Break expression into tokens, using known variables to disambiguate.
        """
        tokens = []
        i = 0
        
        while i < len(text):
            # Skip whitespace
            if text[i].isspace():
                i += 1
                continue
            
            # Operators and parens
            if text[i] in "*/+()":
                tokens.append(text[i])
                i += 1
                continue
            
            # Numbers (including decimals)
            if text[i].isdigit():
                j = i
                while j < len(text) and (text[j].isdigit() or text[j] == '.'):
                    j += 1
                tokens.append(text[i:j])
                i = j
                continue
            
            # FUNCTION keyword
            if text[i:i+8].upper() == "FUNCTION":
                i += 8
                continue
            
            # INTEGER function
            if text[i:i+7].upper() == "INTEGER":
                tokens.append("int")
                i += 7
                continue
            
            # Variable name - find longest match from known variables
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
                    # Unknown variable - grab until non-alnum/hyphen
                    j = i
                    while j < len(text) and (text[j].isalnum() or text[j] == '-'):
                        j += 1
                    tokens.append(to_python_name(text[i:j]))
                    i = j
                continue
            
            # Minus sign (if we get here, it's subtraction)
            if text[i] == '-':
                tokens.append('-')
                i += 1
                continue
            
            # Unknown character - skip
            i += 1
        
        return tokens
    
    # Convert target
    py_target = to_python_name(target)
    
    # Tokenize expression
    tokens = tokenize_expr(expr, known_variables)
    
    # Build Python expression with proper spacing
    py_expr = ""
    for i, tok in enumerate(tokens):
        if tok in "*/+-":
            py_expr += f" {tok} "
        elif tok == "(":
            py_expr += "("
        elif tok == ")":
            py_expr += ")"
        else:
            py_expr += tok
    
    # Clean up
    py_expr = " ".join(py_expr.split())
    
    return f"{py_target} = {py_expr}"


# Known variables from our COBOL parser
KNOWN_VARIABLES = {
    "WS-ACCOUNT-DATA",
    "WS-ACCOUNT-NUM",
    "WS-PRINCIPAL-BAL",
    "WS-ANNUAL-RATE",
    "WS-DAYS-IN-YEAR",
    "WS-ACCRUED-INT",
    "WS-PENALTY-RATE",
    "WS-CALC-FIELDS",
    "WS-DAILY-RATE",
    "WS-DAILY-INTEREST",
    "WS-COMPOUND-FACTOR",
    "WS-TEMP-AMOUNT",
    "WS-PENALTY-DATA",
    "WS-DAYS-OVERDUE",
    "WS-PENALTY-AMOUNT",
    "WS-GRACE-PERIOD",
    "WS-MAX-PENALTY-PCT",
    "WS-ACCOUNT-FLAGS",
    "WS-VIP-FLAG",
    "WS-RATE-DISCOUNT",
}

# Test statements
test_statements = [
    "COMPUTEWS-DAILY-RATE=WS-ANNUAL-RATE/WS-DAYS-IN-YEAR",
    "COMPUTEWS-DAILY-RATE=WS-DAILY-RATE-WS-RATE-DISCOUNT",
    "COMPUTEWS-TEMP-AMOUNT=WS-PRINCIPAL-BAL*WS-DAILY-RATE",
    "COMPUTEWS-DAILY-INTEREST=FUNCTIONINTEGER(WS-TEMP-AMOUNT*100)/100",
    "COMPUTEWS-PENALTY-AMOUNT=WS-PRINCIPAL-BAL*WS-PENALTY-RATE*(WS-DAYS-OVERDUE-WS-GRACE-PERIOD)",
    "COMPUTEWS-TEMP-AMOUNT=WS-PRINCIPAL-BAL*WS-MAX-PENALTY-PCT",
    "COMPUTEWS-PENALTY-AMOUNT=WS-PENALTY-AMOUNT*0.5",
]

print("=== COBOL TO PYTHON ===\n")
for stmt in test_statements:
    py = parse_compute(stmt, KNOWN_VARIABLES)
    print(f"COBOL:  {stmt}")
    print(f"PYTHON: {py}")
    print()