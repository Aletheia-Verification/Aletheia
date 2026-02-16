import re

def parse_if_statement(statement, known_variables):
    """
    Convert COBOL IF to Python if.
    """
    
    def to_python_name(name):
        return name.lower().replace("-", "_")
    
    # Check for truly complex statements (nested IF or standalone ELSE)
    upper = statement.upper()
    if_count = upper.count("IF") - 1
    has_else = bool(re.search(r'(?<![A-Z])ELSE(?![A-Z])', upper))
    
    if if_count > 1 or has_else:
        return f"# TODO: Complex IF - needs manual review\n# {statement[:60]}..."
    
    # Remove IF and END-IF
    stmt = statement.strip()
    if stmt.upper().startswith("IF"):
        stmt = stmt[2:]
    stmt = re.sub(r'END-IF$', '', stmt, flags=re.IGNORECASE)
    
    # Find the condition (before MOVE or COMPUTE)
    condition_end = len(stmt)
    for keyword in ["MOVE", "COMPUTE"]:
        idx = stmt.upper().find(keyword)
        if idx > 0 and idx < condition_end:
            condition_end = idx
    
    condition = stmt[:condition_end].strip()
    action = stmt[condition_end:].strip()
    
    # Convert condition
    py_condition = condition
    
    # Handle comparisons with < and >
    less_match = re.search(r'([A-Z][A-Z0-9\-]*)<(\d+|[A-Z][A-Z0-9\-]*)', condition, re.IGNORECASE)
    greater_match = re.search(r'([A-Z][A-Z0-9\-]*)>([A-Z][A-Z0-9\-]*)', condition, re.IGNORECASE)
    
    if less_match:
        left = to_python_name(less_match.group(1))
        right = less_match.group(2)
        if right.isdigit():
            py_condition = f"{left} < {right}"
        else:
            py_condition = f"{left} < {to_python_name(right)}"
    elif greater_match:
        left = to_python_name(greater_match.group(1))
        right = to_python_name(greater_match.group(2))
        py_condition = f"{left} > {right}"
    else:
        # Handle 88-level conditions (IS-VIP-ACCOUNT)
        if condition.upper().startswith("IS-"):
            py_condition = f'{to_python_name(condition.replace("IS-", "WS-").replace("-ACCOUNT", "-FLAG"))} == "Y"'
        else:
            py_condition = to_python_name(condition)
    
    # Parse action
    py_action = "pass  # TODO"
    
    if action.upper().startswith("COMPUTE"):
        match = re.match(r'COMPUTE\s*([A-Z][A-Z0-9\-]+)\s*=\s*(.+)', action, re.IGNORECASE)
        if match:
            target = match.group(1)
            expr = match.group(2).strip()
            py_target = to_python_name(target)
            
            # Convert expression
            py_expr = expr
            for var in known_variables:
                pattern = re.compile(re.escape(var), re.IGNORECASE)
                py_expr = pattern.sub(to_python_name(var), py_expr)
            
            # Wrap numbers in Decimal
            py_expr = re.sub(r'(?<![a-z_])(\d+\.?\d*)(?![a-z_\d])', r"Decimal('\1')", py_expr)
            
            py_action = f"{py_target} = {py_expr}"
    
    elif action.upper().startswith("MOVE"):
        match = re.match(r'MOVE\s*([0-9.]+|[A-Z][A-Z0-9\-]*)\s*TO\s*([A-Z][A-Z0-9\-]+)', action, re.IGNORECASE)
        if match:
            value = match.group(1)
            target = match.group(2)
            py_target = to_python_name(target)
            
            if re.match(r'^[\d.]+$', value):
                py_value = f"Decimal('{value}')"
            else:
                py_value = to_python_name(value)
            
            py_action = f"{py_target} = {py_value}"
    
    return f"if {py_condition}:\n    {py_action}"


# Test
if __name__ == "__main__":
    KNOWN_VARS = {"WS-VIP-FLAG", "WS-RATE-DISCOUNT", "WS-DAILY-RATE", "WS-DAYS-OVERDUE", "WS-GRACE-PERIOD", "WS-PENALTY-AMOUNT", "WS-TEMP-AMOUNT"}

    test_cases = [
        "IFWS-DAILY-RATE<0MOVE0TOWS-DAILY-RATEEND-IF",
        "IFWS-PENALTY-AMOUNT>WS-TEMP-AMOUNTMOVEWS-TEMP-AMOUNTTOWS-PENALTY-AMOUNTEND-IF",
        "IFIS-VIP-ACCOUNTCOMPUTEWS-PENALTY-AMOUNT=WS-PENALTY-AMOUNT*0.5END-IF",
    ]

    print("=== IF STATEMENT CONVERSION ===\n")
    for stmt in test_cases:
        py = parse_if_statement(stmt, KNOWN_VARS)
        print(f"COBOL: {stmt[:50]}...")
        print(f"PYTHON:\n{py}")
        print()