"""
GnuCOBOL Differential Testing — Standalone Script

Compiles and runs semantic corpus COBOL programs with GnuCOBOL (cobc),
then runs the same programs through Aletheia's Python engine, and compares
outputs field-by-field.  Any divergence = potential engine bug.

Usage:
    python gnucobol_diff_test.py

Requires: GnuCOBOL (cobc) on PATH.  If not found, exits gracefully.
Output:   gnucobol_diff_report.md
"""

import json
import os
import platform
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from datetime import datetime
from decimal import Decimal
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(PROJECT_ROOT))
os.environ["USE_IN_MEMORY_DB"] = "1"

from generate_full_python import to_python_name  # noqa: E402

# Import corpus runner for Aletheia-side execution
sys.path.insert(0, str(PROJECT_ROOT / "semantic_corpus"))
from run_corpus import _collect_entries, execute_entry  # noqa: E402

IS_WINDOWS = platform.system() == "Windows"
AREA_B = "           "  # 11 spaces — standard COBOL Area B indent


# ── Data ────────────────────────────────────────────────────────────


@dataclass
class EntryResult:
    name: str
    status: str  # MATCH | DIVERGENCE | SKIP | ERROR
    details: str = ""
    mismatches: list = field(default_factory=list)
    skip_reason: str = ""
    cbl_path: str = ""


# ── 1. cobc availability ───────────────────────────────────────────


def check_cobc_available():
    """Return (available, version_string)."""
    try:
        r = subprocess.run(
            ["cobc", "--version"],
            capture_output=True, text=True, timeout=10,
        )
        version = r.stdout.splitlines()[0] if r.stdout else "unknown"
        return True, version
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False, ""


# ── 2. Skip detection ──────────────────────────────────────────────


_SKIP_PATTERNS = [
    (r"\bEXEC\s+SQL\b", "EXEC SQL"),
    (r"\bEXEC\s+CICS\b", "EXEC CICS"),
    (r"\bCOPY\s+\w", "COPY statement"),
    (r"\bALTER\s+\w", "ALTER statement"),
    (r"\bOPEN\s+(INPUT|OUTPUT|I-O|EXTEND)\b", "File I/O"),
    (r"\bREAD\s+\w", "File I/O (READ)"),
    (r"\bWRITE\s+\w", "File I/O (WRITE)"),
    (r"\bCLOSE\s+\w", "File I/O (CLOSE)"),
    (r"\bSORT\s+\w", "SORT statement"),
    (r"\bMERGE\s+\w", "MERGE statement"),
]


def should_skip(cbl_source, entry_name):
    """Return reason string if program should be skipped, else None."""
    # EBCDIC tests — GnuCOBOL uses ASCII ordering
    if entry_name.startswith("string/ebcdic"):
        return "EBCDIC ordering (GnuCOBOL uses ASCII)"

    # DECIMAL-POINT IS COMMA — output normalization too fragile in v1
    if re.search(r"DECIMAL-POINT\s+IS\s+COMMA", cbl_source, re.IGNORECASE):
        return "DECIMAL-POINT IS COMMA (v1 limitation)"

    for pattern, reason in _SKIP_PATTERNS:
        if re.search(pattern, cbl_source, re.IGNORECASE):
            return reason

    return None


# ── 3. PIC metadata extraction ─────────────────────────────────────


def extract_pic_metadata(cbl_source, var_names):
    """Extract PIC clause info for each variable.

    Returns {VAR-NAME: {"type": "numeric"|"alpha", "decimals": int, "signed": bool}}
    """
    meta = {}
    for var in var_names:
        # Match:  05  WS-VAR  PIC S9(5)V99  [COMP-3].
        pat = re.compile(
            rf"\b{re.escape(var)}\s+PIC\s+([^\.\s]+)",
            re.IGNORECASE,
        )
        m = pat.search(cbl_source)
        if not m:
            meta[var] = {"type": "alpha", "decimals": 0, "signed": False}
            continue

        pic = m.group(1).upper()
        is_alpha = "X" in pic or "A" in pic
        is_signed = pic.startswith("S") or pic.startswith("-")

        # Count decimal places after V
        decimals = 0
        v_pos = pic.find("V")
        if v_pos >= 0:
            after_v = pic[v_pos + 1:]
            # Count 9s: either 9(n) or raw 9s
            for dm in re.finditer(r"9\((\d+)\)", after_v):
                decimals += int(dm.group(1))
            decimals += after_v.count("9") - len(re.findall(r"9\(\d+\)", after_v)) * 1
            # Fix: count raw 9s that are NOT inside 9(n)
            raw_9s = len(re.sub(r"9\(\d+\)", "", after_v).replace("9", ""))
            decimals = 0
            for dm in re.finditer(r"9\((\d+)\)", after_v):
                decimals += int(dm.group(1))
            stripped = re.sub(r"9\(\d+\)", "", after_v)
            decimals += stripped.count("9")

        meta[var] = {
            "type": "alpha" if is_alpha else "numeric",
            "decimals": decimals,
            "signed": is_signed,
        }
    return meta


# ── 4. Source transformation ────────────────────────────────────────


def inject_test_harness(cbl_source, inputs, expected_outputs, pic_meta):
    """Modify COBOL source: inject MOVEs for inputs, DISPLAYs for outputs.

    Returns the modified source string.
    """
    lines = cbl_source.splitlines(keepends=True)
    result_lines = []

    # Strip CBL/PROCESS directive on line 1
    first_content = lines[0].strip().upper() if lines else ""
    start_idx = 0
    if first_content.startswith("CBL ") or first_content.startswith("PROCESS "):
        start_idx = 1

    # Build MOVE block
    move_block = []
    for var_name, value in inputs.items():
        m = pic_meta.get(var_name, {})
        if m.get("type") == "alpha":
            move_block.append(f'{AREA_B}MOVE "{value}" TO {var_name}.\n')
        else:
            move_block.append(f"{AREA_B}MOVE {value} TO {var_name}.\n")

    # Build DISPLAY block
    display_block = []
    for var_name in expected_outputs:
        display_block.append(
            f'{AREA_B}DISPLAY "@@{var_name}=" {var_name}.\n'
        )

    # Find insertion points
    proc_div_found = False
    first_para_injected = False

    for i, line in enumerate(lines):
        if i < start_idx:
            continue  # skip CBL/PROCESS line

        upper = line.upper().strip()

        # Inject MOVEs after first paragraph header following PROCEDURE DIVISION
        if not proc_div_found and "PROCEDURE DIVISION" in upper:
            proc_div_found = True
            result_lines.append(line)
            continue

        if proc_div_found and not first_para_injected and re.match(
            r"\s+[\w-]+\.\s*$", line
        ):
            # This is a paragraph header line
            result_lines.append(line)
            result_lines.extend(move_block)
            first_para_injected = True
            continue

        # Inject DISPLAYs before every STOP RUN
        if re.search(r"\bSTOP\s+RUN\b", upper):
            result_lines.extend(display_block)
            result_lines.append(line)
            continue

        result_lines.append(line)

    return "".join(result_lines)


# ── 5. Compile and run ──────────────────────────────────────────────


def compile_and_run(modified_cbl, entry_name):
    """Compile with cobc, run, return (returncode, stdout, stderr)."""
    with tempfile.TemporaryDirectory(prefix="aletheia_gnucobol_") as tmp:
        src_path = Path(tmp) / "program.cbl"
        exe_name = "prog.exe" if IS_WINDOWS else "prog"
        exe_path = Path(tmp) / exe_name

        src_path.write_text(modified_cbl, encoding="utf-8")

        # Compile
        comp = subprocess.run(
            ["cobc", "-x", "-o", str(exe_path), str(src_path)],
            capture_output=True, text=True, timeout=30,
        )
        if comp.returncode != 0:
            return comp.returncode, "", comp.stderr

        # Run
        try:
            run = subprocess.run(
                [str(exe_path)],
                capture_output=True, text=True, timeout=10,
                cwd=tmp,
            )
            return run.returncode, run.stdout, run.stderr
        except subprocess.TimeoutExpired:
            return -1, "", "Execution timed out (10s)"


# ── 6. Parse GnuCOBOL output ───────────────────────────────────────


def parse_gnucobol_output(stdout):
    """Extract @@VARNAME=value lines from stdout."""
    results = {}
    for line in stdout.splitlines():
        line = line.strip()
        if line.startswith("@@"):
            key, _, value = line[2:].partition("=")
            results[key] = value
    return results


# ── 7. Normalize GnuCOBOL values ───────────────────────────────────


def normalize_gnucobol_value(raw, meta):
    """Normalize GnuCOBOL DISPLAY output to match expected format.

    GnuCOBOL DISPLAY of PIC 9(5)V99 with value 123.45 outputs '0012345'
    (no decimal point). We insert the decimal point using PIC metadata.
    """
    if meta.get("type") == "alpha":
        return raw.rstrip()

    decimals = meta.get("decimals", 0)
    signed = meta.get("signed", False)

    # Strip spaces
    s = raw.strip()
    if not s:
        return "0"

    # Handle sign character (GnuCOBOL may prepend or append sign)
    negative = False
    if s.startswith("-"):
        negative = True
        s = s[1:]
    elif s.startswith("+"):
        s = s[1:]
    if s.endswith("-"):
        negative = True
        s = s[:-1]
    elif s.endswith("+"):
        s = s[:-1]

    # Remove any spaces within the number
    s = s.replace(" ", "")

    # If GnuCOBOL already output a decimal point, parse directly
    if "." in s:
        try:
            d = Decimal(s)
            if negative:
                d = -d
            # Quantize to PIC scale
            if decimals > 0:
                scale = Decimal(10) ** -decimals
                d = d.quantize(scale)
            result = str(d)
            # Strip leading zeros but keep "0" before decimal
            if "." in result:
                int_part, dec_part = result.split(".")
                int_part = int_part.lstrip("0") or "0"
                # Handle negative zero
                if int_part == "-":
                    int_part = "-0"
                elif int_part == "-0" and all(c == "0" for c in dec_part):
                    int_part = "0"  # normalize -0.00 to 0.00
                return f"{int_part}.{dec_part}"
            else:
                return result.lstrip("0") or "0"
        except Exception:
            pass

    # No decimal point — insert based on PIC
    if decimals > 0 and len(s) > decimals:
        int_part = s[:-decimals]
        dec_part = s[-decimals:]
        int_part = int_part.lstrip("0") or "0"
        val = f"{int_part}.{dec_part}"
    elif decimals > 0:
        # Value is shorter than decimal places
        s = s.zfill(decimals)
        val = f"0.{s}"
    else:
        val = s.lstrip("0") or "0"

    if negative and val != "0" and not val.startswith("-"):
        val = f"-{val}"

    return val


# ── 8. Aletheia engine execution ────────────────────────────────────


def run_aletheia_engine(cbl_source, entry):
    """Run program through Aletheia engine. Returns (outputs_dict, errors)."""
    passed, actual, errors = execute_entry(cbl_source, entry)
    return actual, errors


# ── 9. Compare outputs ──────────────────────────────────────────────


def compare_outputs(gnucobol, aletheia, expected):
    """Compare GnuCOBOL vs Aletheia outputs. Returns list of mismatches."""
    mismatches = []
    for var_name in expected:
        gval = gnucobol.get(var_name, "<missing>")
        aval = aletheia.get(var_name, "<missing>")
        if gval != aval:
            mismatches.append(
                f"{var_name}: GnuCOBOL={gval!r}, Aletheia={aval!r}, "
                f"Expected={expected[var_name]!r}"
            )
    return mismatches


# ── 10. Report generation ──────────────────────────────────────────


def generate_report(results, cobc_version, report_path):
    """Write markdown report."""
    tested = sum(1 for r in results if r.status in ("MATCH", "DIVERGENCE"))
    skipped = sum(1 for r in results if r.status == "SKIP")
    matched = sum(1 for r in results if r.status == "MATCH")
    diverged = sum(1 for r in results if r.status == "DIVERGENCE")
    errored = sum(1 for r in results if r.status == "ERROR")

    lines = [
        "# GnuCOBOL Differential Test Report\n",
        f"\nGenerated: {datetime.now().strftime('%Y-%m-%d %H:%M')} | "
        f"GnuCOBOL: {cobc_version}\n",
        f"\nTested: {tested}/{len(results)} | Skipped: {skipped} | "
        f"Match: {matched} | Divergence: {diverged}"
        + (f" | Error: {errored}" if errored else "") + "\n",
        "\n## Results\n",
        "\n| Program | Status | Details |",
        "\n|---------|--------|---------|",
    ]

    for r in results:
        detail = r.skip_reason or r.details or ""
        lines.append(f"\n| {r.name} | {r.status} | {detail} |")

    # Divergence details
    divergences = [r for r in results if r.status == "DIVERGENCE"]
    if divergences:
        lines.append("\n\n## Divergences\n")
        for r in divergences:
            lines.append(f"\n### {r.name}\n")
            for m in r.mismatches:
                lines.append(f"\n- {m}")
            lines.append(f"\n- Source: {r.cbl_path}")

    lines.append("\n")
    report_path.write_text("".join(lines), encoding="utf-8")


# ── 11. Main ────────────────────────────────────────────────────────


def main():
    available, cobc_version = check_cobc_available()
    if not available:
        print("cobc (GnuCOBOL) not found on PATH. Install GnuCOBOL to run "
              "differential tests.")
        print("  Linux:   apt install gnucobol")
        print("  macOS:   brew install gnucobol")
        print("  Windows: download from https://gnucobol.sourceforge.io/")
        sys.exit(0)

    print(f"GnuCOBOL found: {cobc_version}")

    entries = _collect_entries()
    if not entries:
        print("No semantic corpus entries found.")
        sys.exit(1)

    print(f"Corpus entries: {len(entries)}\n")

    results = []

    for cbl_path, json_path in entries:
        entry_name = f"{cbl_path.parent.name}/{cbl_path.stem}"
        cbl_source = cbl_path.read_text(encoding="utf-8")
        entry = json.loads(json_path.read_text(encoding="utf-8"))

        # Skip check
        reason = should_skip(cbl_source, entry_name)
        if reason:
            print(f"  SKIP  {entry_name}  ({reason})")
            results.append(EntryResult(
                name=entry_name, status="SKIP",
                skip_reason=reason, cbl_path=str(cbl_path),
            ))
            continue

        inputs = entry.get("inputs", {})
        expected = entry.get("expected_outputs", {})
        all_vars = list(set(list(inputs.keys()) + list(expected.keys())))
        pic_meta = extract_pic_metadata(cbl_source, all_vars)

        # Transform source for GnuCOBOL
        modified = inject_test_harness(cbl_source, inputs, expected, pic_meta)

        # Compile and run with GnuCOBOL
        try:
            rc, stdout, stderr = compile_and_run(modified, entry_name)
        except Exception as e:
            print(f"  ERROR {entry_name}  (compile/run: {e})")
            results.append(EntryResult(
                name=entry_name, status="ERROR",
                details=str(e), cbl_path=str(cbl_path),
            ))
            continue

        if rc != 0:
            detail = stderr.strip()[:120] if stderr else "compilation failed"
            print(f"  SKIP  {entry_name}  (cobc: {detail})")
            results.append(EntryResult(
                name=entry_name, status="SKIP",
                skip_reason=f"cobc failed: {detail}",
                cbl_path=str(cbl_path),
            ))
            continue

        # Parse GnuCOBOL output
        raw_outputs = parse_gnucobol_output(stdout)
        gnucobol_outputs = {}
        for var_name, raw_val in raw_outputs.items():
            m = pic_meta.get(var_name, {"type": "alpha", "decimals": 0, "signed": False})
            gnucobol_outputs[var_name] = normalize_gnucobol_value(raw_val, m)

        # Run Aletheia engine
        aletheia_outputs, aletheia_errors = run_aletheia_engine(cbl_source, entry)
        if aletheia_errors and not aletheia_outputs:
            print(f"  ERROR {entry_name}  (Aletheia: {aletheia_errors[0]})")
            results.append(EntryResult(
                name=entry_name, status="ERROR",
                details=f"Aletheia: {'; '.join(aletheia_errors)}",
                cbl_path=str(cbl_path),
            ))
            continue

        # Compare
        mismatches = compare_outputs(gnucobol_outputs, aletheia_outputs, expected)

        if mismatches:
            print(f"  DIVERGE {entry_name}")
            for m in mismatches:
                print(f"          {m}")
            results.append(EntryResult(
                name=entry_name, status="DIVERGENCE",
                details=f"{len(mismatches)} field(s) differ",
                mismatches=mismatches, cbl_path=str(cbl_path),
            ))
        else:
            n = len(expected)
            print(f"  MATCH {entry_name}  ({n} output{'s' if n != 1 else ''} verified)")
            results.append(EntryResult(
                name=entry_name, status="MATCH",
                details=f"{n} output{'s' if n != 1 else ''} verified",
                cbl_path=str(cbl_path),
            ))

    # Report
    report_path = PROJECT_ROOT / "gnucobol_diff_report.md"
    generate_report(results, cobc_version, report_path)

    # Summary
    matched = sum(1 for r in results if r.status == "MATCH")
    diverged = sum(1 for r in results if r.status == "DIVERGENCE")
    skipped = sum(1 for r in results if r.status == "SKIP")
    errored = sum(1 for r in results if r.status == "ERROR")

    print(f"\n{'=' * 60}")
    print(f"  Match: {matched}  Divergence: {diverged}  "
          f"Skip: {skipped}  Error: {errored}")
    print(f"  Report: {report_path}")
    print(f"{'=' * 60}")

    sys.exit(1 if diverged > 0 else 0)


if __name__ == "__main__":
    main()
