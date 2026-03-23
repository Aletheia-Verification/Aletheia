"""
test_cli.py — Headless CLI Tests

12 tests covering:
  - Single file analysis (4)
  - Batch analysis (2)
  - Shadow Diff (1)
  - Signature verification (2)
  - Dependency analysis (1)
  - Version and health (2)

Run with:
    pytest test_cli.py -v
"""

import json
import os
import subprocess
import sys
import tempfile

import pytest

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CLI = os.path.join(SCRIPT_DIR, "aletheia_cli.py")
PYTHON = sys.executable
DEMO_CBL = os.path.join(SCRIPT_DIR, "DEMO_LOAN_INTEREST.cbl")
DEMO_DIR = os.path.join(SCRIPT_DIR, "demo_data")


def run_cli(*args, timeout=120):
    """Run the CLI and return (returncode, stdout, stderr)."""
    cmd = [PYTHON, CLI] + list(args)
    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        timeout=timeout,
        cwd=SCRIPT_DIR,
    )
    return result.returncode, result.stdout, result.stderr


# ══════════════════════════════════════════════════════════════════════
# TestAnalyze (4 tests)
# ══════════════════════════════════════════════════════════════════════


class TestAnalyze:
    def test_analyze_single_file(self):
        """DEMO_LOAN_INTEREST.cbl returns VERIFIED in output."""
        code, stdout, stderr = run_cli("analyze", DEMO_CBL)
        data = json.loads(stdout)
        assert data["verification_status"] == "VERIFIED"
        assert data["success"] is True

    def test_analyze_output_json(self):
        """JSON output is parseable and has required fields."""
        code, stdout, stderr = run_cli("analyze", DEMO_CBL)
        data = json.loads(stdout)
        assert "verification_status" in data
        assert "parser_output" in data
        assert "generated_python" in data
        assert "arithmetic_summary" in data
        assert "timing" in data
        assert data["timing"]["parse_ms"] > 0
        assert data["timing"]["total_ms"] > 0

    def test_analyze_compiler_flag(self):
        """--compiler-trunc BIN applies correctly."""
        code, stdout, stderr = run_cli("analyze", DEMO_CBL, "--compiler-trunc", "BIN")
        data = json.loads(stdout)
        assert data["verification_status"] == "VERIFIED"
        # The analysis should complete without error
        assert data["success"] is True

    def test_exit_code_verified(self):
        """Exit code 0 for VERIFIED program."""
        code, stdout, stderr = run_cli("analyze", DEMO_CBL)
        assert code == 0


# ══════════════════════════════════════════════════════════════════════
# TestBatch (2 tests)
# ══════════════════════════════════════════════════════════════════════


class TestBatch:
    def test_analyze_batch(self):
        """demo_data/ directory processes multiple COBOL files."""
        with tempfile.TemporaryDirectory() as tmpdir:
            code, stdout, stderr = run_cli(
                "analyze-batch", DEMO_DIR, "--output-dir", tmpdir,
            )
            data = json.loads(stdout)
            assert data["total_programs"] >= 3
            assert data["verified"] + data["manual_review"] + data["errors"] == data["total_programs"]
            # Per-file results written
            json_files = [f for f in os.listdir(tmpdir) if f.endswith(".json") and f != "summary.json"]
            assert len(json_files) >= 3

    def test_batch_summary(self):
        """summary.json has correct total_programs count."""
        with tempfile.TemporaryDirectory() as tmpdir:
            run_cli("analyze-batch", DEMO_DIR, "--output-dir", tmpdir)
            summary_path = os.path.join(tmpdir, "summary.json")
            assert os.path.exists(summary_path)
            with open(summary_path, "r") as f:
                summary = json.load(f)
            assert summary["total_programs"] >= 3
            assert "duration_seconds" in summary
            assert "total_variables" in summary
            assert "total_paragraphs" in summary


# ══════════════════════════════════════════════════════════════════════
# TestShadowDiff (1 test)
# ══════════════════════════════════════════════════════════════════════


class TestShadowDiff:
    def test_shadow_diff_cli(self):
        """Demo data produces ZERO DRIFT."""
        from cobol_analyzer_api import analyze_cobol
        from generate_full_python import generate_python_module

        # Generate Python live from DEMO_LOAN_INTEREST.cbl
        cobol_path = os.path.join(SCRIPT_DIR, "DEMO_LOAN_INTEREST.cbl")
        with open(cobol_path, "r", encoding="utf-8") as f:
            cobol_source = f.read()
        analysis = analyze_cobol(cobol_source)
        python_code = generate_python_module(analysis)["code"]

        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".py", dir=SCRIPT_DIR, delete=False, encoding="utf-8"
        ) as tmp:
            tmp.write(python_code)
            python_path = tmp.name

        try:
            layout_path = os.path.join(DEMO_DIR, "loan_layout.json")
            input_path = os.path.join(DEMO_DIR, "loan_input.dat")
            expected_path = os.path.join(DEMO_DIR, "loan_mainframe_output.dat")

            code, stdout, stderr = run_cli(
                "shadow-diff",
                "--layout", layout_path,
                "--input", input_path,
                "--expected", expected_path,
                "--python", python_path,
            )
            data = json.loads(stdout)
            assert data["verdict"].startswith("SHADOW DIFF: ZERO DRIFT")
            assert code == 0
        finally:
            os.unlink(python_path)


# ══════════════════════════════════════════════════════════════════════
# TestVerify (2 tests)
# ══════════════════════════════════════════════════════════════════════


class TestVerify:
    def test_verify_authentic(self):
        """Signed report verifies as AUTHENTIC."""
        from report_signing import build_verification_chain, sign_report

        # Create a signed report
        analysis = {
            "verification_status": "VERIFIED",
            "generated_python": "result = 42",
            "parser_output": {"summary": {}},
        }
        cobol = "       IDENTIFICATION DIVISION.\n       PROGRAM-ID. TEST.\n"

        with tempfile.TemporaryDirectory() as tmpdir:
            chain = build_verification_chain(analysis, cobol)
            sig = sign_report(chain, keys_dir=tmpdir)

            report_path = os.path.join(tmpdir, "report.json")
            with open(report_path, "w") as f:
                json.dump(sig, f)

            cmd = [PYTHON, CLI, "verify-signature", report_path, "--keys-dir", tmpdir]
            result = subprocess.run(
                cmd, capture_output=True, text=True, timeout=30, cwd=SCRIPT_DIR,
            )
            assert result.returncode == 0
            assert "AUTHENTIC" in result.stdout

    def test_verify_tampered(self):
        """Tampered report detected."""
        from report_signing import build_verification_chain, sign_report

        analysis = {
            "verification_status": "VERIFIED",
            "generated_python": "result = 42",
        }
        cobol = "       IDENTIFICATION DIVISION.\n       PROGRAM-ID. TEST.\n"

        with tempfile.TemporaryDirectory() as tmpdir:
            chain = build_verification_chain(analysis, cobol)
            sig = sign_report(chain, keys_dir=tmpdir)

            # Tamper with chain hash
            sig["verification_chain"]["chain_hash"] = "a" * 64

            report_path = os.path.join(tmpdir, "report.json")
            with open(report_path, "w") as f:
                json.dump(sig, f)

            cmd = [PYTHON, CLI, "verify-signature", report_path, "--keys-dir", tmpdir]
            result = subprocess.run(
                cmd, capture_output=True, text=True, timeout=30, cwd=SCRIPT_DIR,
            )
            assert result.returncode == 1
            assert "TAMPERED" in result.stdout


# ══════════════════════════════════════════════════════════════════════
# TestDependency (1 test)
# ══════════════════════════════════════════════════════════════════════


class TestDependency:
    def test_dependency_tree(self):
        """demo_data/ tree contains MAIN-LOAN calling CALC-INT."""
        code, stdout, stderr = run_cli("dependency", DEMO_DIR)
        data = json.loads(stdout)
        assert "tree" in data
        assert "MAIN-LOAN" in data["tree"]
        assert "CALC-INT" in data["tree"]["MAIN-LOAN"]["calls"]
        assert code == 0


# ══════════════════════════════════════════════════════════════════════
# TestMisc (2 tests)
# ══════════════════════════════════════════════════════════════════════


class TestMisc:
    def test_version(self):
        """Prints version string containing 3.2.0."""
        code, stdout, stderr = run_cli("version")
        assert "3.2.0" in stdout
        assert code == 0

    def test_health(self):
        """Prints system status with parser/generator info."""
        code, stdout, stderr = run_cli("health")
        data = json.loads(stdout)
        assert data["version"] == "3.2.0"
        assert data["antlr4_parser"] == "available"
        assert data["python_generator"] == "available"
        assert code == 0
