"""
test_call_cancel.py — CALL / CANCEL subprogram invocation tests.

4 tests:
  - CALL 'PROG' literal detected in analysis
  - CALL WS-NAME dynamic detected
  - CALL with USING parameters captured
  - CANCEL detected, generated code compiles
"""

import os
os.environ["USE_IN_MEMORY_DB"] = "1"

import pytest
from cobol_analyzer_api import analyze_cobol
from generate_full_python import generate_python_module


class TestCallCancel:

    def test_call_literal_detected(self):
        """CALL 'CALCINT' detected in analysis with correct target."""
        src = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEST-CALL.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-AMT PIC 9(5)V99.
       PROCEDURE DIVISION.
       0000-MAIN.
           CALL 'CALCINT'.
           STOP RUN.
"""
        analysis = analyze_cobol(src)
        calls = analysis.get("call_statements", [])
        assert len(calls) >= 1
        assert calls[0]["target"] == "CALCINT"
        assert calls[0]["is_dynamic"] is False

        # Generated code should compile and have CALL comment
        result = generate_python_module(analysis)
        code = result["code"]
        compile(code, "<test-call>", "exec")
        assert "CALL" in code
        assert "CALCINT" in code

    def test_call_variable_dynamic(self):
        """CALL WS-PROG-NAME detected as dynamic."""
        src = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEST-DYN.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-PROG-NAME PIC X(8).
       PROCEDURE DIVISION.
       0000-MAIN.
           CALL WS-PROG-NAME.
           STOP RUN.
"""
        analysis = analyze_cobol(src)
        calls = analysis.get("call_statements", [])
        assert len(calls) >= 1
        assert calls[0]["is_dynamic"] is True

        result = generate_python_module(analysis)
        code = result["code"]
        compile(code, "<test-dyn>", "exec")
        assert "dynamic" in code.lower() or "CALL" in code

    def test_call_using_parameters(self):
        """CALL with USING captures parameter names."""
        src = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEST-USING.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-AMT   PIC 9(5)V99.
       01 WS-RATE  PIC 9(3)V99.
       01 WS-RESULT PIC 9(7)V99.
       PROCEDURE DIVISION.
       0000-MAIN.
           CALL 'CALCINT' USING WS-AMT WS-RATE WS-RESULT.
           STOP RUN.
"""
        analysis = analyze_cobol(src)
        calls = analysis.get("call_statements", [])
        assert len(calls) >= 1
        params = calls[0].get("using_params", [])
        assert len(params) >= 1
        param_names = [p["name"] for p in params]
        assert any("AMT" in n.upper() for n in param_names)

    def test_cancel_detected_compiles(self):
        """CANCEL 'CALCINT' detected and generated code compiles."""
        src = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEST-CANCEL.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-X PIC 9(1).
       PROCEDURE DIVISION.
       0000-MAIN.
           CALL 'CALCINT'.
           CANCEL 'CALCINT'.
           STOP RUN.
"""
        analysis = analyze_cobol(src)
        cancels = analysis.get("cancel_statements", [])
        assert len(cancels) >= 1

        result = generate_python_module(analysis)
        code = result["code"]
        compile(code, "<test-cancel>", "exec")
        assert "CANCEL" in code
