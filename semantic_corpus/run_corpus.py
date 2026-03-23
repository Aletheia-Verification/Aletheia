"""
Semantic Regression Corpus — Test Runner

Parses each .cbl → generates Python → executes → compares outputs to expected values.
Exact Decimal match required. Integrates with pytest.

Run all:   pytest semantic_corpus/run_corpus.py -v
Run one:   pytest semantic_corpus/run_corpus.py -v -k "comp3_boundary"
Standalone: python semantic_corpus/run_corpus.py
"""

import os
import sys
import json
import contextvars
import threading
from decimal import Decimal
from pathlib import Path

# Ensure project root is importable
PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

os.environ["USE_IN_MEMORY_DB"] = "1"

import pytest
from cobol_analyzer_api import analyze_cobol
from generate_full_python import generate_python_module, to_python_name
from compiler_config import set_config, reset_config

CORPUS_DIR = Path(__file__).resolve().parent


def _collect_entries():
    """Discover all .cbl + .json pairs under corpus subdirectories."""
    entries = []
    for subdir in sorted(CORPUS_DIR.iterdir()):
        if subdir.is_dir() and subdir.name not in ("__pycache__",):
            for cbl in sorted(subdir.glob("*.cbl")):
                json_file = cbl.with_suffix(".json")
                if json_file.exists():
                    entries.append((cbl, json_file))
    return entries


def execute_entry(cbl_source, entry):
    """Execute a single corpus entry. Returns (passed, actual, errors)."""
    errors = []
    actual = {}
    trunc_mode = entry.get("trunc_mode", "STD")
    arith_mode = entry.get("arith_mode", "EXTEND")

    try:
        set_config(trunc_mode=trunc_mode, arith_mode=arith_mode)

        # Parse
        analysis = analyze_cobol(cbl_source)
        if not analysis.get("success"):
            errors.append(f"Parse failed: {analysis.get('message', 'unknown')}")
            return False, actual, errors

        # Auto-apply CBL/PROCESS options detected in source when JSON
        # doesn't explicitly override them (mirrors core_logic.py behavior)
        detected = analysis.get("compiler_options_detected", {})
        if detected:
            cfg_kwargs = {}
            # Only apply detected option if JSON didn't set an explicit value
            if "trunc_mode" in detected and "trunc_mode" not in entry:
                cfg_kwargs["trunc_mode"] = detected["trunc_mode"]
            if "arith_mode" in detected and "arith_mode" not in entry:
                cfg_kwargs["arith_mode"] = detected["arith_mode"]
            if "decimal_point" in detected and "decimal_point" not in entry:
                cfg_kwargs["decimal_point"] = detected["decimal_point"]
            if cfg_kwargs:
                # Merge with current config
                current = {"trunc_mode": trunc_mode, "arith_mode": arith_mode}
                current.update(cfg_kwargs)
                set_config(**current)

        # Generate
        result = generate_python_module(analysis)
        if isinstance(result, str):
            errors.append(f"Generate returned string: {result[:100]}")
            return False, actual, errors
        code = result["code"]

        # Compile
        try:
            compile(code, "<corpus>", "exec")
        except SyntaxError as e:
            errors.append(f"Compile error: {e}")
            return False, actual, errors

        # Execute in fresh namespace
        namespace = {}
        exec(code, namespace)

        # Set inputs
        inputs = entry.get("inputs", {})
        for cobol_name, value in inputs.items():
            py_name = to_python_name(cobol_name)
            existing = namespace.get(py_name)
            if existing is not None and hasattr(existing, "store"):
                existing.store(Decimal(str(value)))
            elif existing is not None:
                namespace[py_name] = value
            else:
                errors.append(f"Input variable not found: {cobol_name} -> {py_name}")

        # Run main() with timeout — copy context so ContextVar (TRUNC mode) propagates
        exec_error = [None]
        ctx = contextvars.copy_context()

        def _run():
            try:
                ctx.run(namespace["main"])
            except Exception as e:
                exec_error[0] = e

        thread = threading.Thread(target=_run, daemon=True)
        thread.start()
        thread.join(timeout=5)

        if thread.is_alive():
            errors.append("Timeout after 5s")
            return False, actual, errors

        if exec_error[0]:
            errors.append(f"Execution error: {exec_error[0]}")
            return False, actual, errors

        # Read outputs and compare
        expected = entry.get("expected_outputs", {})
        passed = True
        for cobol_name, expected_val in expected.items():
            py_name = to_python_name(cobol_name)
            val = namespace.get(py_name)
            if val is None:
                errors.append(f"Output variable not found: {cobol_name} -> {py_name}")
                passed = False
                continue

            if hasattr(val, "value"):
                raw = val.value
                # Quantize to PIC scale for consistent string representation
                if hasattr(val, "pic_decimals") and val.pic_decimals > 0:
                    scale = Decimal(10) ** -val.pic_decimals
                    raw = raw.quantize(scale)
                elif isinstance(raw, Decimal) and raw == 0:
                    raw = Decimal("0")
                actual_val = str(raw)
            else:
                actual_val = str(val)

            actual[cobol_name] = actual_val

            if actual_val != expected_val:
                errors.append(
                    f"{cobol_name}: expected {expected_val!r}, got {actual_val!r}"
                )
                passed = False

        return passed, actual, errors

    finally:
        reset_config()


# ── Pytest integration ────────────────────────────────────────────

_ENTRIES = _collect_entries()


@pytest.mark.parametrize(
    "cbl_path,json_path",
    _ENTRIES,
    ids=[f"{p[0].parent.name}/{p[0].stem}" for p in _ENTRIES],
)
def test_corpus_entry(cbl_path, json_path):
    cbl_source = cbl_path.read_text(encoding="utf-8")
    entry = json.loads(json_path.read_text(encoding="utf-8"))

    passed, actual, errors = execute_entry(cbl_source, entry)

    if not passed:
        detail = "\n".join(errors)
        pytest.fail(f"{entry.get('description', cbl_path.stem)}\n{detail}")


# ── Standalone runner ─────────────────────────────────────────────

if __name__ == "__main__":
    entries = _collect_entries()
    if not entries:
        print("No corpus entries found.")
        sys.exit(1)

    total = len(entries)
    passed_count = 0
    failed = []

    print(f"\n{'=' * 70}")
    print(f"  SEMANTIC REGRESSION CORPUS — {total} entries")
    print(f"{'=' * 70}\n")

    for cbl_path, json_path in entries:
        cbl_source = cbl_path.read_text(encoding="utf-8")
        entry = json.loads(json_path.read_text(encoding="utf-8"))
        label = f"{cbl_path.parent.name}/{cbl_path.stem}"

        passed, actual, errors = execute_entry(cbl_source, entry)

        if passed:
            print(f"  PASS  {label}")
            passed_count += 1
        else:
            print(f"  FAIL  {label}")
            for err in errors:
                print(f"        {err}")
            failed.append(label)

    print(f"\n{'=' * 70}")
    print(f"  {passed_count}/{total} passed")
    if failed:
        print(f"  FAILED: {', '.join(failed)}")
    print(f"{'=' * 70}\n")

    sys.exit(0 if passed_count == total else 1)
