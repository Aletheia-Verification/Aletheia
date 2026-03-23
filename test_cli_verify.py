"""Tests for aletheia_cli.py verify command — full Engine + Shadow Diff pipeline."""

import json
import os
import subprocess
import sys
import tempfile

import pytest

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PYTHON = os.path.join(SCRIPT_DIR, "venv", "Scripts", "python.exe")
CLI = os.path.join(SCRIPT_DIR, "aletheia_cli.py")

DEMO_DATA = os.path.join(SCRIPT_DIR, "demo_data")
DEMO_CBL = os.path.join(SCRIPT_DIR, "DEMO_LOAN_INTEREST.cbl")
LOAN_INPUT = os.path.join(DEMO_DATA, "loan_input.dat")
LOAN_OUTPUT = os.path.join(DEMO_DATA, "loan_mainframe_output.dat")
LOAN_OUTPUT_DRIFT = os.path.join(DEMO_DATA, "loan_mainframe_output_WITH_DRIFT.dat")
LOAN_LAYOUT = os.path.join(DEMO_DATA, "loan_layout.json")


def _run_verify(*extra_args, timeout=120):
    """Helper: run aletheia verify with given extra args."""
    cmd = [PYTHON, CLI, "verify", *extra_args]
    return subprocess.run(
        cmd, capture_output=True, text=True, timeout=timeout, cwd=SCRIPT_DIR,
    )


class TestVerifyCommand:

    def test_verify_with_layout_exit_0(self):
        """Full pipeline with manual layout → FULLY VERIFIED, exit 0."""
        result = _run_verify(
            "--source", DEMO_CBL,
            "--input", LOAN_INPUT,
            "--output", LOAN_OUTPUT,
            "--layout", LOAN_LAYOUT,
        )
        assert result.returncode == 0, f"stderr: {result.stderr}\nstdout: {result.stdout}"
        assert "FULLY VERIFIED" in result.stdout
        assert "100/100" in result.stdout

    def test_verify_auto_layout_exit_0(self):
        """Full pipeline with auto-generated layout → FULLY VERIFIED, exit 0."""
        result = _run_verify(
            "--source", DEMO_CBL,
            "--input", LOAN_INPUT,
            "--output", LOAN_OUTPUT,
            # No --layout: auto-generate from DATA DIVISION
        )
        assert result.returncode == 0, f"stderr: {result.stderr}\nstdout: {result.stdout}"
        assert "FULLY VERIFIED" in result.stdout

    def test_verify_drift_exit_1(self):
        """Drift data → DRIFT DETECTED, exit 1."""
        result = _run_verify(
            "--source", DEMO_CBL,
            "--input", LOAN_INPUT,
            "--output", LOAN_OUTPUT_DRIFT,
            "--layout", LOAN_LAYOUT,
        )
        assert result.returncode == 1, f"stderr: {result.stderr}\nstdout: {result.stdout}"
        assert "DRIFT DETECTED" in result.stdout

    def test_verify_bad_cobol_exit_2(self):
        """Invalid COBOL source → exit 2."""
        with tempfile.NamedTemporaryFile(mode="w", suffix=".cbl", delete=False) as f:
            f.write("THIS IS NOT VALID COBOL AT ALL GARBAGE INPUT 12345")
            bad_path = f.name

        try:
            result = _run_verify(
                "--source", bad_path,
                "--input", LOAN_INPUT,
                "--output", LOAN_OUTPUT,
                "--layout", LOAN_LAYOUT,
            )
            assert result.returncode == 2, f"stderr: {result.stderr}\nstdout: {result.stdout}"
            assert "ERROR" in result.stderr
        finally:
            os.unlink(bad_path)
