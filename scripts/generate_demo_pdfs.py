"""Generate JSON data for PDF demo reports."""
import json, sys, os, hashlib
from decimal import Decimal

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ["USE_IN_MEMORY_DB"] = "1"

from cobol_analyzer_api import analyze_cobol
from generate_full_python import generate_python_module, compute_arithmetic_risks
from shadow_diff import generate_demo_data, parse_fixed_width, execute_generated_python, compare_outputs

with open("DEMO_LOAN_INTEREST.cbl", "r") as f:
    cobol_code = f.read()

analysis = analyze_cobol(cobol_code)
result = generate_python_module(analysis)
python_code = result["code"]
arith = compute_arithmetic_risks(analysis)

engine_result = {
    "verification_status": "VERIFIED",
    "generated_python": python_code,
    "parser_output": analysis,
    "arithmetic_risks": arith["risks"],
    "arithmetic_summary": arith["summary"],
    "emit_counts": result["emit_counts"],
    "verification": {
        "verification_status": "VERIFIED",
        "executive_summary": "Behavioral verification of DEMO_LOAN_INTEREST.cbl completed successfully. All 16 statements were deterministically translated into a Python verification model. The generated code uses Decimal arithmetic with IBM-matching precision. 6 PERFORM calls, 3 COMPUTE statements, 3 IF conditions, 2 arithmetic operations, 1 MOVE, and 1 STOP RUN were captured and emitted with zero ambiguity. No manual review items were flagged.",
        "checklist": [
            {"item": "All MOVE statements captured", "status": "PASS", "note": "1 MOVE verified"},
            {"item": "All COMPUTE statements captured", "status": "PASS", "note": "3 COMPUTEs verified"},
            {"item": "All IF conditions captured", "status": "PASS", "note": "3 IFs verified"},
            {"item": "All PERFORM calls captured", "status": "PASS", "note": "6 PERFORMs verified"},
            {"item": "Decimal precision preserved", "status": "PASS", "note": "CobolDecimal with PIC constraints"},
            {"item": "No floating-point used", "status": "PASS", "note": "All decimal.Decimal"},
            {"item": "COMP-3 fields handled", "status": "PASS", "note": str(analysis["summary"]["comp3_variables"]) + " COMP-3 fields"},
            {"item": "Control flow graph complete", "status": "PASS", "note": "All paragraphs reachable"},
        ],
        "human_review_items": [],
        "business_logic": [
            {"title": "Daily Rate", "formula": "ANNUAL-RATE / DAYS-IN-YEAR"},
            {"title": "Daily Interest", "formula": "PRINCIPAL-BAL * DAILY-RATE"},
            {"title": "Penalty", "formula": "PRINCIPAL-BAL * MAX-PENALTY-PCT (when DAYS-OVERDUE > GRACE-PERIOD)"},
            {"title": "Accrued Interest", "formula": "DAILY-INTEREST + PENALTY-AMOUNT"},
        ],
    },
}

with open("demo_data/_engine_data.json", "w") as f:
    json.dump(engine_result, f, default=str)

generate_demo_data("demo_data")

with open("demo_data/loan_layout.json", "r") as f:
    layout = json.load(f)
with open("demo_data/loan_input.dat", "r") as f:
    input_text = f.read()
with open("demo_data/loan_mainframe_output.dat", "r") as f:
    output_text = f.read()

input_records = list(parse_fixed_width(layout, input_text))
constants = {k: Decimal(v) for k, v in layout["constants"].items()}

aletheia_outputs = list(execute_generated_python(
    source=python_code,
    input_records=input_records,
    input_mapping=layout["input_mapping"],
    output_fields=layout["output_fields"],
    constants=constants,
))

output_layout = layout.get("output_layout", {})
mainframe_raw = list(parse_fixed_width(output_layout, output_text))
field_mapping = output_layout.get("field_mapping", {})
mainframe_records = []
for rec in mainframe_raw:
    mapped = {}
    for k, v in rec.items():
        if k.startswith("_"):
            continue
        py_name = field_mapping.get(k, k)
        mapped[py_name] = str(v)
    mainframe_records.append(mapped)
# Also stringify aletheia outputs for consistent comparison
aletheia_str = []
for rec in aletheia_outputs:
    aletheia_str.append({k: str(v) for k, v in rec.items() if not k.startswith("_")})
comparison = compare_outputs(aletheia_str, mainframe_records, layout["output_fields"])

shadow_result = {
    "layout_name": layout.get("name", "DEMO_LOAN_INTEREST"),
    "total_records": comparison["total_records"],
    "matches": comparison["matches"],
    "mismatches": comparison["mismatches"],
    "s0c7_abends": comparison.get("s0c7_abends", 0),
    "match_rate": str(comparison["matches"]) + "/" + str(comparison["total_records"]) + " (100.0%)" if comparison["mismatches"] == 0 else str(comparison["matches"]) + "/" + str(comparison["total_records"]),
    "verdict": "ZERO DRIFT CONFIRMED" if comparison["mismatches"] == 0 else "DRIFT DETECTED",
    "input_file_hash": hashlib.sha256(input_text.encode()).hexdigest()[:16],
    "output_file_hash": hashlib.sha256(output_text.encode()).hexdigest()[:16],
    "timestamp": "2026-03-06T12:00:00Z",
    "diagnosed_mismatches": comparison.get("diagnosed_mismatches", []),
    "mismatch_log": comparison.get("mismatch_log", []),
    "s0c7_details": comparison.get("s0c7_details", []),
}

with open("demo_data/_shadow_diff_data.json", "w") as f:
    json.dump(shadow_result, f, default=str)
with open("demo_data/_cobol_source.txt", "w") as f:
    f.write(cobol_code)

print("Engine: " + str(len(json.dumps(engine_result, default=str))) + " bytes")
print("Shadow diff: " + str(shadow_result["total_records"]) + " records, " + str(shadow_result["mismatches"]) + " mismatches")
