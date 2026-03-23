"""
Generate demo I/O data for ACCT-INTEREST.cbl.
Produces acct_interest_input.dat (100 records) and acct_interest_output.dat
by running the actual generated Python against each input record.
"""
import sys
import os
import random
from decimal import Decimal, getcontext, ROUND_DOWN

# Ensure project root is on path
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)
os.environ["USE_IN_MEMORY_DB"] = "1"

from cobol_analyzer_api import analyze_cobol
from generate_full_python import generate_python_module

# ── Step 1: Generate Python from COBOL ──
with open(os.path.join(ROOT, "demo_data", "ACCT-INTEREST.cbl"), "r") as f:
    source = f.read()

analysis = analyze_cobol(source)
result = generate_python_module(analysis)
generated_code = result["code"]

# ── Step 2: Generate 100 input records ──
random.seed(42)  # reproducible

INPUT_FIELDS = [
    # (name, width, gen_func)
]

records = []
for i in range(100):
    # Account type: S=40%, C=25%, P=20%, B=10%, X=5%
    r = random.random()
    if r < 0.40:
        acct_type = "S"
    elif r < 0.65:
        acct_type = "C"
    elif r < 0.85:
        acct_type = "P"
    elif r < 0.95:
        acct_type = "B"
    else:
        acct_type = "X"  # unknown type — tests error path

    # Balance: realistic banking distribution
    bal_tier = random.random()
    if bal_tier < 0.15:
        balance = Decimal(str(random.randint(50000, 99999))) / Decimal("100")  # 500-999.99
    elif bal_tier < 0.40:
        balance = Decimal(str(random.randint(100000, 2500000))) / Decimal("100")  # 1000-25000
    elif bal_tier < 0.70:
        balance = Decimal(str(random.randint(2500001, 10000000))) / Decimal("100")  # 25000-100000
    elif bal_tier < 0.90:
        balance = Decimal(str(random.randint(10000001, 50000000))) / Decimal("100")  # 100000-500000
    else:
        balance = Decimal(str(random.randint(50000001, 75000000))) / Decimal("100")  # 500000-750000

    # Months: 1-12
    months = random.randint(1, 12)

    # Days inactive: mostly 0, some > 180
    if random.random() < 0.15:
        days_inactive = random.randint(181, 365)
    elif random.random() < 0.10:
        days_inactive = random.randint(30, 180)
    else:
        days_inactive = 0

    records.append({
        "acct_type": acct_type,
        "balance": balance,
        "months": months,
        "days_inactive": days_inactive,
    })

# Format input records as fixed-width
# ACCT-TYPE: 1 char | BALANCE: 12 chars (right-justified, 2 decimals) | MONTHS: 2 chars | DAYS-INACTIVE: 3 chars
input_lines = []
for rec in records:
    acct = rec["acct_type"]
    bal_str = f"{rec['balance']:12.2f}"  # right-justified in 12 chars
    months_str = f"{rec['months']:2d}"
    days_str = f"{rec['days_inactive']:3d}"
    line = f"{acct}{bal_str}{months_str}{days_str}"
    input_lines.append(line)

# Write input file
input_path = os.path.join(ROOT, "demo_data", "acct_interest_input.dat")
with open(input_path, "w", newline="\n") as f:
    for line in input_lines:
        f.write(line + "\n")
print(f"Wrote {len(input_lines)} input records to {input_path}")

# ── Step 3: Execute generated Python against each input record ──
# We compile the generated code and run it per-record

# Inject COBOL built-in 'spaces' before exec
patched_code = 'spaces = " " * 256\n' + generated_code

output_lines = []
for i, rec in enumerate(records):
    # Fresh namespace per record (mirrors shadow_diff._execute_one_record)
    exec_globals = {}
    exec(patched_code, exec_globals)

    # Set input variables
    exec_globals["ws_account_type"] = rec["acct_type"]
    exec_globals["ws_balance"].store(rec["balance"])
    exec_globals["ws_months"].store(Decimal(str(rec["months"])))
    exec_globals["ws_days_inactive"].store(Decimal(str(rec["days_inactive"])))

    # Run main
    exec_globals["para_0000_main_process"]()

    # Extract output values
    new_bal = exec_globals["ws_new_balance"].value
    total_int = exec_globals["ws_total_interest"].value
    net_int = exec_globals["ws_net_interest"].value
    fee = exec_globals["ws_fee"].value
    penalty = exec_globals["ws_penalty"].value
    result_code = exec_globals["ws_result_code"].value
    tier = exec_globals["ws_tier"].value

    # Format output: 7 fields x 40 chars each, right-justified
    def fmt_dec(val, decimals=2):
        """Format decimal value right-justified in 40 chars."""
        s = f"{val:.{decimals}f}"
        return s.rjust(40)

    def fmt_int(val):
        """Format integer value right-justified in 40 chars."""
        s = str(int(val))
        return s.rjust(40)

    out_line = (
        fmt_dec(new_bal) +
        fmt_dec(total_int) +
        fmt_dec(net_int) +
        fmt_dec(fee) +
        fmt_dec(penalty) +
        fmt_int(result_code) +
        fmt_int(tier)
    )
    output_lines.append(out_line)

# Write output file
output_path = os.path.join(ROOT, "demo_data", "acct_interest_output.dat")
with open(output_path, "w", newline="\n") as f:
    for line in output_lines:
        f.write(line + "\n")
print(f"Wrote {len(output_lines)} output records to {output_path}")

# ── Sanity check: print first 3 records ──
print("\n--- Sample records ---")
for i in range(3):
    print(f"Input:  {input_lines[i]}")
    print(f"Output: {output_lines[i][:120]}...")
    print()
