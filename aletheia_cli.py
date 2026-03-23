"""
aletheia_cli.py — Headless Execution Mode for Aletheia Beyond

Command-line interface for high-volume COBOL verification without a browser.
Wraps existing engine functions for scripting, automation, and batch processing.

Usage:
    python aletheia_cli.py analyze <file.cbl> [--compiler-trunc STD|BIN|OPT] [--output json|text] [--save-vault]
    python aletheia_cli.py analyze-batch <directory> [--recursive] [--output-dir ./results]
    python aletheia_cli.py shadow-diff --layout <layout.json> --input <input.dat> --expected <output.dat> --python <generated.py>
    python aletheia_cli.py dependency <directory> [--analyze]
    python aletheia_cli.py verify --source <file.cbl> --input <input.dat> --output <output.dat> [--layout <layout.json>]
    python aletheia_cli.py verify-signature <report.json>
    python aletheia_cli.py export-vault [--format json] [--output <file>]
    python aletheia_cli.py version
    python aletheia_cli.py health
"""

import argparse
import hashlib
import json
import os
import sys
import time


VERSION = "3.2.0"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))


# ══════════════════════════════════════════════════════════════════════
# Component 2: Single File Analysis
# ══════════════════════════════════════════════════════════════════════


def _run_analysis(cobol_code: str, filename: str, compiler_trunc: str = None) -> dict:
    """
    Run the full deterministic analysis pipeline on COBOL source.

    Returns the same result structure as /engine/analyze.
    """
    timing = {}

    # Stage 1: ANTLR4 Parse
    t0 = time.perf_counter()
    try:
        from cobol_analyzer_api import analyze_cobol
        parser_output = analyze_cobol(cobol_code)
        parser_output["filename"] = filename
        parser_output["parser"] = "ANTLR4"
        parser_output["engine"] = "deterministic"
    except Exception as e:
        parser_output = {
            "success": False,
            "message": f"Parse failed: {e}",
            "summary": {},
            "paragraphs": [],
            "variables": [],
            "control_flow": [],
            "computes": [],
            "conditions": [],
            "filename": filename,
            "parser": "none",
            "engine": "offline",
        }
    timing["parse_ms"] = round((time.perf_counter() - t0) * 1000, 1)

    # Stage 2: Apply compiler config
    active_compiler_config = None
    if compiler_trunc:
        try:
            from compiler_config import set_config, get_config
            set_config(trunc_mode=compiler_trunc)
            active_compiler_config = get_config()
        except (ValueError, TypeError, ImportError):
            pass

    # Stage 2: Python Generation
    t0 = time.perf_counter()
    generated_python = None
    try:
        from generate_full_python import generate_python_module
        if parser_output.get("success"):
            gen_result = generate_python_module(parser_output, compiler_config=active_compiler_config)
            code = gen_result["code"]
            if not code.startswith("# PARSE ERROR"):
                generated_python = code
    except Exception:
        pass
    timing["generate_ms"] = round((time.perf_counter() - t0) * 1000, 1)

    # Stage 2.5: Arithmetic Risk Analysis
    t0 = time.perf_counter()
    arithmetic_risks = []
    arithmetic_summary = {"total": 0, "safe": 0, "warn": 0, "critical": 0}
    try:
        from generate_full_python import compute_arithmetic_risks
        if parser_output.get("success"):
            arith_data = compute_arithmetic_risks(parser_output)
            arithmetic_risks = arith_data.get("risks", [])
            arithmetic_summary = arith_data.get("summary", arithmetic_summary)
    except Exception:
        pass
    timing["risk_ms"] = round((time.perf_counter() - t0) * 1000, 1)

    # Deterministic verification status
    parse_errors = parser_output.get("parse_errors", 0)
    generator_recovered = (
        parse_errors > 0
        and generated_python is not None
        and "MANUAL REVIEW" not in generated_python
    )
    if generator_recovered:
        try:
            compile(generated_python, "<verify>", "exec")
        except SyntaxError:
            generator_recovered = False
    all_stages_passed = (
        parser_output.get("success")
        and generated_python is not None
        and (parse_errors == 0 or generator_recovered)
    )
    verification_status = "VERIFIED" if all_stages_passed else "REQUIRES_MANUAL_REVIEW"

    # ALTER statement = hard stop — runtime mutation makes static verification impossible
    alter_deps = [d for d in parser_output.get("exec_dependencies", []) if d.get("type") == "ALTER"]
    if alter_deps:
        verification_status = "REQUIRES_MANUAL_REVIEW"

    # Offline verification stub
    summary = parser_output.get("summary", {})
    checklist = []
    if parser_output.get("success"):
        checklist.append({"item": "ANTLR4 parse", "status": "PASS", "note": "Zero parse errors"})
    else:
        checklist.append({"item": "ANTLR4 parse", "status": "FAIL", "note": "Parse errors detected"})
    if generated_python:
        checklist.append({"item": "Python generation", "status": "PASS", "note": f"{len(generated_python)} chars"})
    else:
        checklist.append({"item": "Python generation", "status": "FAIL", "note": "Generation failed"})
    checklist.append({
        "item": "Arithmetic risk",
        "status": "PASS" if arithmetic_summary.get("critical", 0) == 0 else "WARN",
        "note": f"{arithmetic_summary.get('safe', 0)}S/{arithmetic_summary.get('warn', 0)}W/{arithmetic_summary.get('critical', 0)}C",
    })

    human_review_items = []
    exec_deps = parser_output.get("exec_dependencies", [])
    if exec_deps:
        human_review_items.append({
            "item": f"{len(exec_deps)} EXEC SQL/CICS blocks detected",
            "severity": "MEDIUM",
            "reason": "External dependencies require manual verification",
        })

    verification = {
        "verification_status": verification_status,
        "executive_summary": f"{'Deterministic verification complete' if all_stages_passed else 'Manual review required'}. "
                             f"{summary.get('paragraphs', 0)} paragraphs, {summary.get('variables', 0)} variables analyzed.",
        "checklist": checklist,
        "human_review_items": human_review_items,
        "business_logic": [],
    }

    result = {
        "success": True,
        "verification_status": verification_status,
        "parser_output": parser_output,
        "generated_python": generated_python,
        "verification": verification,
        "arithmetic_risks": arithmetic_risks,
        "arithmetic_summary": arithmetic_summary,
        "timing": timing,
    }

    return result


def cmd_analyze(args):
    """Analyze a single COBOL file."""
    t_total = time.perf_counter()

    filepath = args.file
    if not os.path.isfile(filepath):
        print(json.dumps({"error": f"File not found: {filepath}"}), file=sys.stderr)
        return 2

    filename = os.path.basename(filepath)
    with open(filepath, "r", encoding="utf-8") as f:
        cobol_code = f.read()

    result = _run_analysis(cobol_code, filename, args.compiler_trunc)

    if not result.get("success"):
        print(f"ERROR: Analysis failed: {result.get('error', 'unknown')}", file=sys.stderr)
        return 2

    result["timing"]["total_ms"] = round((time.perf_counter() - t_total) * 1000, 1)

    # Save to vault if requested
    if args.save_vault:
        try:
            from vault import save_to_vault
            vault_id = save_to_vault(result, cobol_code)
            result["vault_id"] = vault_id
        except Exception as e:
            result["vault_error"] = str(e)

    # Output
    if args.output == "text":
        status = result["verification_status"]
        summary = result.get("parser_output", {}).get("summary", {})
        arith = result.get("arithmetic_summary", {})
        timing = result.get("timing", {})
        print(f"{'='*60}")
        print(f"ALETHEIA BEYOND — {filename}")
        print(f"{'='*60}")
        print(f"Status:      {status}")
        print(f"Paragraphs:  {summary.get('paragraphs', 0)}")
        print(f"Variables:   {summary.get('variables', 0)}")
        print(f"COMP-3:      {summary.get('comp3_variables', 0)}")
        print(f"Risks:       {arith.get('safe', 0)}S / {arith.get('warn', 0)}W / {arith.get('critical', 0)}C")
        print(f"Parse:       {timing.get('parse_ms', 0)}ms")
        print(f"Generate:    {timing.get('generate_ms', 0)}ms")
        print(f"Total:       {timing.get('total_ms', 0)}ms")
        if result.get("vault_id"):
            print(f"Vault ID:    {result['vault_id']}")
        print(f"{'='*60}")
    else:
        print(json.dumps(result, indent=2, default=str))

    return 0 if result["verification_status"] == "VERIFIED" else 1


# ══════════════════════════════════════════════════════════════════════
# Component 3: Batch Analysis
# ══════════════════════════════════════════════════════════════════════


def cmd_analyze_batch(args):
    """Analyze all COBOL files in a directory."""
    t_total = time.perf_counter()

    directory = args.directory
    if not os.path.isdir(directory):
        print(json.dumps({"error": f"Directory not found: {directory}"}), file=sys.stderr)
        return 2

    output_dir = args.output_dir or os.path.join(os.getcwd(), "results")
    os.makedirs(output_dir, exist_ok=True)

    # Collect COBOL files
    extensions = (".cbl", ".cob", ".cobol")
    files = []
    if args.recursive:
        for root, _, fnames in os.walk(directory):
            for fn in fnames:
                if fn.lower().endswith(extensions):
                    files.append(os.path.join(root, fn))
    else:
        for fn in os.listdir(directory):
            if fn.lower().endswith(extensions):
                files.append(os.path.join(directory, fn))

    if not files:
        print(json.dumps({"error": "No COBOL files found"}), file=sys.stderr)
        return 2

    files.sort()
    total = len(files)
    verified = 0
    manual_review = 0
    errors = 0
    total_variables = 0
    total_paragraphs = 0
    critical_risks = 0

    for i, filepath in enumerate(files, 1):
        filename = os.path.basename(filepath)
        t_file = time.perf_counter()

        try:
            with open(filepath, "r", encoding="utf-8") as f:
                cobol_code = f.read()

            result = _run_analysis(cobol_code, filename, args.compiler_trunc)

            if not result.get("success"):
                print(f"  ERROR: {filename}: {result.get('error', 'unknown')}", file=sys.stderr)
                errors += 1
                continue

            result["timing"]["total_ms"] = round((time.perf_counter() - t_file) * 1000, 1)
            elapsed = result["timing"]["total_ms"] / 1000

            status = result["verification_status"]
            if status == "VERIFIED":
                verified += 1
            else:
                manual_review += 1

            summary = result.get("parser_output", {}).get("summary", {})
            total_variables += summary.get("variables", 0)
            total_paragraphs += summary.get("paragraphs", 0)
            critical_risks += result.get("arithmetic_summary", {}).get("critical", 0)

            # Write per-file result
            out_name = os.path.splitext(filename)[0] + ".json"
            with open(os.path.join(output_dir, out_name), "w", encoding="utf-8") as f:
                json.dump(result, f, indent=2, default=str)

            print(f"[{i}/{total}] {filename} ... {status} ({elapsed:.1f}s)", file=sys.stderr)

        except Exception as e:
            errors += 1
            from abend_handler import S0C7DataException
            if isinstance(e, S0C7DataException):
                print(f"[{i}/{total}] {filename} ... S0C7 ABEND: {e}", file=sys.stderr)
            else:
                print(f"[{i}/{total}] {filename} ... ERROR: {e}", file=sys.stderr)

    duration = round(time.perf_counter() - t_total, 1)

    summary_data = {
        "total_programs": total,
        "verified": verified,
        "manual_review": manual_review,
        "errors": errors,
        "total_variables": total_variables,
        "total_paragraphs": total_paragraphs,
        "critical_risks": critical_risks,
        "duration_seconds": duration,
    }

    summary_path = os.path.join(output_dir, "summary.json")
    with open(summary_path, "w", encoding="utf-8") as f:
        json.dump(summary_data, f, indent=2)

    print(json.dumps(summary_data, indent=2))

    if errors > 0:
        return 2
    elif manual_review > 0:
        return 1
    return 0


# ══════════════════════════════════════════════════════════════════════
# Component 4: Shadow Diff CLI
# ══════════════════════════════════════════════════════════════════════


def cmd_shadow_diff(args):
    """Run Shadow Diff verification against mainframe output."""
    t_total = time.perf_counter()

    for path, name in [(args.layout, "layout"), (args.input, "input"),
                        (args.expected, "expected"), (args.python, "python")]:
        if not os.path.isfile(path):
            print(json.dumps({"error": f"{name} file not found: {path}"}), file=sys.stderr)
            return 2

    from shadow_diff import parse_fixed_width_stream, run_streaming_pipeline, generate_report

    # Read files
    with open(args.layout, "r", encoding="utf-8") as f:
        layout = json.load(f)

    with open(args.input, "r", encoding="utf-8") as f:
        input_data = f.read()

    with open(args.expected, "r", encoding="utf-8") as f:
        expected_data = f.read()

    with open(args.python, "r", encoding="utf-8") as f:
        python_source = f.read()

    # Build streaming input parser (filter to input fields only)
    input_mapping = layout.get("input_mapping", {})
    input_layout = {
        "fields": [f for f in layout["fields"] if f["name"] in input_mapping],
        "record_length": layout.get("record_length"),
    }

    # Build streaming mainframe output parser
    output_layout = layout.get("output_layout", {})
    field_mapping = output_layout.get("field_mapping", {})

    def _mainframe_stream():
        for rec in parse_fixed_width_stream(output_layout, expected_data):
            mapped = {}
            for cobol_name, python_name in field_mapping.items():
                if cobol_name in rec:
                    mapped[python_name] = str(rec[cobol_name])
            yield mapped

    output_fields = layout.get("output_fields", [])
    constants = layout.get("constants", None)

    # Parse constants — convert string values to Decimal where possible
    if constants:
        from decimal import Decimal
        parsed_constants = {}
        for k, v in constants.items():
            try:
                parsed_constants[k] = Decimal(str(v))
            except Exception:
                parsed_constants[k] = v
        constants = parsed_constants

    # Streaming pipeline: parse one, execute one, compare one
    comparison = run_streaming_pipeline(
        source=python_source,
        input_stream=parse_fixed_width_stream(input_layout, input_data),
        mainframe_stream=_mainframe_stream(),
        input_mapping=input_mapping,
        output_fields=output_fields,
        constants=constants,
    )

    # Report
    input_hash = hashlib.sha256(input_data.encode("utf-8")).hexdigest()
    output_hash = hashlib.sha256(expected_data.encode("utf-8")).hexdigest()
    report = generate_report(comparison, input_hash, output_hash, layout.get("name", ""))

    report["timing"] = {
        "total_ms": round((time.perf_counter() - t_total) * 1000, 1),
    }

    s0c7_count = report.get("s0c7_abends", 0)
    if s0c7_count > 0:
        print(f"WARNING: {s0c7_count} S0C7 DATA EXCEPTION(s) detected", file=sys.stderr)

    print(json.dumps(report, indent=2, default=str))

    return 0 if comparison["mismatches"] == 0 else 1


# ══════════════════════════════════════════════════════════════════════
# Component 5: Dependency Analysis CLI
# ══════════════════════════════════════════════════════════════════════


def cmd_dependency(args):
    """Analyze COBOL program dependencies."""
    directory = args.directory
    if not os.path.isdir(directory):
        print(json.dumps({"error": f"Directory not found: {directory}"}), file=sys.stderr)
        return 2

    from dependency_crawler import load_programs_from_directory, build_dependency_tree, analyze_multi_program

    programs = load_programs_from_directory(directory)
    if not programs:
        print(json.dumps({"error": "No COBOL programs found"}), file=sys.stderr)
        return 2

    t0 = time.perf_counter()
    if args.analyze:
        result = analyze_multi_program(programs)
    else:
        result = build_dependency_tree(programs)

    result["timing"] = {
        "total_ms": round((time.perf_counter() - t0) * 1000, 1),
    }

    print(json.dumps(result, indent=2, default=str))
    return 0


# ══════════════════════════════════════════════════════════════════════
# Component 6: Full Verify (Engine + Shadow Diff) CLI
# ══════════════════════════════════════════════════════════════════════


def cmd_verify(args):
    """Run full Engine + Shadow Diff pipeline from source COBOL."""
    t_total = time.perf_counter()

    # Validate files exist
    source_path = args.source
    input_path = getattr(args, "input")
    output_path = args.output
    layout_path = args.layout

    for path, name in [(source_path, "source"), (input_path, "input"), (output_path, "output")]:
        if not os.path.isfile(path):
            print(f"ERROR: {name} file not found: {path}", file=sys.stderr)
            return 2

    if layout_path and not os.path.isfile(layout_path):
        print(f"ERROR: layout file not found: {layout_path}", file=sys.stderr)
        return 2

    # ── Stage A: Engine Analysis ────────────────────────────────────
    with open(source_path, "r", encoding="utf-8") as f:
        cobol_code = f.read()

    filename = os.path.basename(source_path)
    compiler_trunc = getattr(args, "compiler_trunc", None)

    try:
        engine_result = _run_analysis(cobol_code, filename, compiler_trunc)
    except Exception as e:
        print(f"ERROR: Engine analysis failed: {e}", file=sys.stderr)
        return 2

    if not engine_result.get("success"):
        print(f"ERROR: Engine analysis failed: {engine_result.get('error', 'unknown')}", file=sys.stderr)
        return 2

    generated_python = engine_result.get("generated_python")
    if not generated_python:
        print("ERROR: Python generation failed — cannot run Shadow Diff", file=sys.stderr)
        return 2

    engine_verdict = engine_result.get("verification_status", "REQUIRES_MANUAL_REVIEW")

    # ── Stage B: Shadow Diff ────────────────────────────────────────
    from shadow_diff import parse_fixed_width_stream, run_streaming_pipeline, generate_report as sd_generate_report
    from decimal import Decimal

    with open(input_path, "rb") as f:
        input_bytes = f.read()
    with open(output_path, "rb") as f:
        output_bytes = f.read()

    input_hash = hashlib.sha256(input_bytes).hexdigest()
    output_hash = hashlib.sha256(output_bytes).hexdigest()

    # Layout: load from file or auto-generate
    if layout_path:
        with open(layout_path, "r", encoding="utf-8") as f:
            layout = json.load(f)
    else:
        try:
            from layout_generator import generate_layout
            parser_output = engine_result.get("parser_output", {})
            layout = generate_layout(parser_output, generated_python, filename)
        except Exception as e:
            print(f"ERROR: Layout auto-generation failed: {e}", file=sys.stderr)
            return 2

    input_mapping = layout.get("input_mapping")
    output_fields = layout.get("output_fields")
    if not input_mapping or not output_fields:
        print("ERROR: Layout must include 'input_mapping' and 'output_fields'.", file=sys.stderr)
        return 2

    output_layout_def = layout.get("output_layout")
    if not output_layout_def:
        print("ERROR: Layout must include 'output_layout'.", file=sys.stderr)
        return 2

    # Parse constants to Decimal
    raw_constants = layout.get("constants") or {}
    parsed_constants = {}
    for k, v in raw_constants.items():
        try:
            parsed_constants[k] = Decimal(str(v))
        except Exception:
            parsed_constants[k] = v

    # Build input layout (only fields referenced by input_mapping)
    input_layout = {
        "fields": [f for f in layout["fields"] if f["name"] in input_mapping],
        "record_length": layout.get("record_length"),
    }

    # Build mainframe output stream with field mapping
    output_field_mapping = output_layout_def.get("field_mapping", {})

    def _mainframe_stream():
        for rec in parse_fixed_width_stream(output_layout_def, output_bytes):
            mapped = {}
            for cobol_name, python_name in output_field_mapping.items():
                if cobol_name in rec:
                    mapped[python_name] = str(rec[cobol_name])
            yield mapped

    # Run streaming pipeline
    comparison = run_streaming_pipeline(
        source=generated_python,
        input_stream=parse_fixed_width_stream(input_layout, input_bytes),
        mainframe_stream=_mainframe_stream(),
        input_mapping=input_mapping,
        output_fields=output_fields,
        constants=parsed_constants,
    )

    report = sd_generate_report(
        comparison,
        input_file_hash=input_hash,
        output_file_hash=output_hash,
        layout_name=layout.get("name", ""),
        layout=layout,
    )

    total_records = report["total_records"]
    mismatches = report["mismatches"]
    matches = total_records - mismatches
    elapsed = round((time.perf_counter() - t_total) * 1000, 1)

    # ── Unified Verdict ─────────────────────────────────────────────
    sd_clean = mismatches == 0
    if engine_verdict == "VERIFIED" and sd_clean:
        print(f"FULLY VERIFIED \u2014 {matches}/{total_records} records match ({elapsed}ms)")
        return 0
    elif not sd_clean:
        # Collect drifted field names
        mismatch_log = report.get("mismatch_log", [])
        drifted_fields = sorted(set(m.get("field", "") for m in mismatch_log if m.get("field")))
        fields_str = ", ".join(drifted_fields) if drifted_fields else "unknown"
        print(f"DRIFT DETECTED \u2014 {mismatches}/{total_records} records, fields: {fields_str}")
        return 1
    else:
        # Engine didn't verify but shadow diff was clean
        print(f"REQUIRES MANUAL REVIEW \u2014 {matches}/{total_records} records match, engine: {engine_verdict}")
        return 1


# ══════════════════════════════════════════════════════════════════════
# Component 6b: Signature Verification CLI
# ══════════════════════════════════════════════════════════════════════


def cmd_verify_signature(args):
    """Verify a signed report's cryptographic integrity."""
    filepath = args.report
    if not os.path.isfile(filepath):
        print(json.dumps({"error": f"File not found: {filepath}"}), file=sys.stderr)
        return 2

    from report_signing import verify_report

    with open(filepath, "r", encoding="utf-8") as f:
        report_data = json.load(f)

    # Check if report has embedded signature data
    sig_data = None
    if "signature" in report_data and "verification_chain" in report_data:
        sig_data = report_data
    elif "signature_data" in report_data:
        sig_data = report_data["signature_data"]
    else:
        # Try to reconstruct from separate fields
        if args.signature and os.path.isfile(args.signature):
            with open(args.signature, "r") as f:
                sig_b64 = f.read().strip()
            chain = report_data.get("verification_chain", report_data)
            sig_data = {
                "signature": sig_b64,
                "verification_chain": chain,
            }

    if not sig_data:
        print("TAMPERED")
        print(json.dumps({"valid": False, "details": "No signature data found"}))
        return 1

    kwargs = {}
    if hasattr(args, "keys_dir") and args.keys_dir:
        kwargs["keys_dir"] = args.keys_dir
    result = verify_report(sig_data, **kwargs)

    if result["valid"]:
        print("AUTHENTIC")
    else:
        print("TAMPERED")

    print(json.dumps(result, indent=2))
    return 0 if result["valid"] else 1


# ══════════════════════════════════════════════════════════════════════
# Component 7: Vault Export CLI
# ══════════════════════════════════════════════════════════════════════


def cmd_export_vault(args):
    """Export vault records."""
    from vault import _get_conn, _ALL_COLS

    conn = _get_conn()
    cols = ", ".join(_ALL_COLS)
    rows = conn.execute(f"SELECT {cols} FROM verifications ORDER BY timestamp DESC").fetchall()
    conn.close()

    records = [dict(r) for r in rows]

    if args.format == "pdf":
        print("PDF export requires the browser UI. Use --format json instead.", file=sys.stderr)
        args.format = "json"

    output = json.dumps(records, indent=2, default=str)

    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(output)
        print(f"Exported {len(records)} records to {args.output}", file=sys.stderr)
    else:
        print(output)

    return 0


# ══════════════════════════════════════════════════════════════════════
# Component 8: Version & Health
# ══════════════════════════════════════════════════════════════════════


def cmd_version(args):
    """Print version string."""
    print(f"Aletheia Beyond v{VERSION} — Behavioral Verification Engine")
    return 0


def cmd_health(args):
    """Print system health status."""
    status = {
        "version": VERSION,
        "status": "operational",
    }

    # Check ANTLR4 parser
    try:
        from cobol_analyzer_api import analyze_cobol
        status["antlr4_parser"] = "available"
    except ImportError:
        status["antlr4_parser"] = "unavailable"

    # Check Python generator
    try:
        from generate_full_python import generate_python_module
        status["python_generator"] = "available"
    except ImportError:
        status["python_generator"] = "unavailable"

    # Check vault
    vault_path = os.path.join(SCRIPT_DIR, "vault.db")
    status["vault_db"] = "exists" if os.path.exists(vault_path) else "not found"

    # Check signing keys
    keys_dir = os.path.join(SCRIPT_DIR, "aletheia_keys")
    status["signing_keys"] = "present" if os.path.exists(os.path.join(keys_dir, "public.pem")) else "not generated"

    # Mode
    status["mode"] = os.environ.get("ALETHEIA_MODE", "air-gapped")

    print(json.dumps(status, indent=2))
    return 0


# ══════════════════════════════════════════════════════════════════════
# Main Entry Point
# ══════════════════════════════════════════════════════════════════════


def main():
    parser = argparse.ArgumentParser(
        prog="aletheia",
        description="Aletheia Beyond — Headless Behavioral Verification Engine",
    )
    subparsers = parser.add_subparsers(dest="command", help="Available commands")

    # analyze
    p_analyze = subparsers.add_parser("analyze", help="Analyze a single COBOL file")
    p_analyze.add_argument("file", help="Path to COBOL source file")
    p_analyze.add_argument("--compiler-trunc", choices=["STD", "BIN", "OPT"], default=None,
                           help="TRUNC compiler option")
    p_analyze.add_argument("--output", choices=["json", "text"], default="json",
                           help="Output format (default: json)")
    p_analyze.add_argument("--save-vault", action="store_true",
                           help="Save result to vault.db")

    # analyze-batch
    p_batch = subparsers.add_parser("analyze-batch", help="Batch analyze a directory of COBOL files")
    p_batch.add_argument("directory", help="Directory containing COBOL files")
    p_batch.add_argument("--recursive", action="store_true",
                         help="Scan subdirectories recursively")
    p_batch.add_argument("--compiler-trunc", choices=["STD", "BIN", "OPT"], default=None,
                         help="TRUNC compiler option")
    p_batch.add_argument("--output-dir", default=None,
                         help="Output directory for results (default: ./results)")

    # shadow-diff
    p_shadow = subparsers.add_parser("shadow-diff", help="Run Shadow Diff verification")
    p_shadow.add_argument("--layout", required=True, help="Layout definition JSON")
    p_shadow.add_argument("--input", required=True, help="Input data file")
    p_shadow.add_argument("--expected", required=True, help="Expected mainframe output file")
    p_shadow.add_argument("--python", required=True, help="Generated Python file")

    # dependency
    p_dep = subparsers.add_parser("dependency", help="Analyze COBOL program dependencies")
    p_dep.add_argument("directory", help="Directory containing COBOL programs")
    p_dep.add_argument("--analyze", action="store_true",
                       help="Run full analysis (not just tree)")

    # verify (full Engine + Shadow Diff pipeline)
    p_verify = subparsers.add_parser("verify", help="Full verify: Engine + Shadow Diff from COBOL source")
    p_verify.add_argument("--source", required=True, help="Path to COBOL source file")
    p_verify.add_argument("--input", required=True, help="Mainframe input data file")
    p_verify.add_argument("--output", required=True, help="Mainframe output data file")
    p_verify.add_argument("--layout", default=None, help="Layout JSON (auto-generated if omitted)")
    p_verify.add_argument("--compiler-trunc", choices=["STD", "BIN", "OPT"], default=None,
                           help="TRUNC compiler option")

    # verify-signature
    p_vsig = subparsers.add_parser("verify-signature", help="Verify a signed report")
    p_vsig.add_argument("report", help="Report JSON file")
    p_vsig.add_argument("--signature", default=None, help="Signature file (base64)")
    p_vsig.add_argument("--public-key", default=None, help="Public key PEM file")
    p_vsig.add_argument("--keys-dir", default=None, help="Directory containing keys")

    # export-vault
    p_export = subparsers.add_parser("export-vault", help="Export vault records")
    p_export.add_argument("--format", choices=["json", "pdf"], default="json",
                          help="Export format (default: json)")
    p_export.add_argument("--output", default=None, help="Output file path")

    # version
    subparsers.add_parser("version", help="Print version")

    # health
    subparsers.add_parser("health", help="Print system health status")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(0)

    handlers = {
        "analyze": cmd_analyze,
        "analyze-batch": cmd_analyze_batch,
        "shadow-diff": cmd_shadow_diff,
        "dependency": cmd_dependency,
        "verify": cmd_verify,
        "verify-signature": cmd_verify_signature,
        "export-vault": cmd_export_vault,
        "version": cmd_version,
        "health": cmd_health,
    }

    handler = handlers.get(args.command)
    if handler:
        exit_code = handler(args)
        sys.exit(exit_code or 0)
    else:
        parser.print_help()
        sys.exit(0)


if __name__ == "__main__":
    main()
