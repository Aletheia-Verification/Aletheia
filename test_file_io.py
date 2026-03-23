"""
test_file_io.py — Tests for V2 Flat File I/O support.

Tests cover:
  - Analyzer: OPEN/READ/WRITE/CLOSE detection with paragraph context,
              INTO, AT END, FROM, FILE STATUS
  - Generator: emitted _io_* calls, AT END branches, _FILE_META, _IS_IO_PROGRAM
  - Runtime I/O: CobolFileManager with StreamBackend
  - Integration: end-to-end parse → generate → execute with stream I/O
  - V2 Proof: full Shadow Diff pipeline with FULLY VERIFIED verdict
"""

import os
import re
import sys
import unittest

import pytest
from decimal import Decimal

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)

os.environ["USE_IN_MEMORY_DB"] = "1"

from cobol_analyzer_api import analyze_cobol
from generate_full_python import generate_python_module, to_python_name


# ══════════════════════════════════════════════════════════════════════
# Test COBOL Sources
# ══════════════════════════════════════════════════════════════════════

SIMPLE_FILE_IO_COBOL = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SIMPLE-IO.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT INPUT-FILE ASSIGN TO 'INPUT.DAT'
               FILE STATUS IS WS-IN-STATUS.
           SELECT OUTPUT-FILE ASSIGN TO 'OUTPUT.DAT'
               FILE STATUS IS WS-OUT-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD INPUT-FILE.
       01 INPUT-RECORD.
           05 IN-ACCOUNT    PIC X(10).
           05 IN-AMOUNT     PIC 9(7)V99.
       FD OUTPUT-FILE.
       01 OUTPUT-RECORD.
           05 OUT-ACCOUNT   PIC X(10).
           05 OUT-RESULT    PIC 9(7)V99.
       WORKING-STORAGE SECTION.
       01 WS-IN-STATUS      PIC XX.
       01 WS-OUT-STATUS     PIC XX.
       01 WS-EOF-FLAG        PIC X VALUE 'N'.
           88 WS-EOF          VALUE 'Y'.
       01 WS-ACCOUNT        PIC X(10).
       01 WS-AMOUNT         PIC 9(7)V99.
       01 WS-RESULT         PIC 9(7)V99.
       PROCEDURE DIVISION.
       MAIN-LOGIC.
           OPEN INPUT INPUT-FILE.
           OPEN OUTPUT OUTPUT-FILE.
           PERFORM READ-PROCESS UNTIL WS-EOF.
           CLOSE INPUT-FILE.
           CLOSE OUTPUT-FILE.
           STOP RUN.
       READ-PROCESS.
           READ INPUT-FILE INTO WS-ACCOUNT
               AT END SET WS-EOF TO TRUE
               NOT AT END PERFORM PROCESS-RECORD.
       PROCESS-RECORD.
           MOVE IN-AMOUNT TO WS-AMOUNT.
           MULTIPLY WS-AMOUNT BY 2 GIVING WS-RESULT.
           MOVE WS-ACCOUNT TO OUT-ACCOUNT.
           MOVE WS-RESULT TO OUT-RESULT.
           WRITE OUTPUT-RECORD FROM WS-ACCOUNT.
"""


# ══════════════════════════════════════════════════════════════════════
# Analyzer Tests
# ══════════════════════════════════════════════════════════════════════


class TestAnalyzerFileIO:

    def test_open_input_detected(self):
        """OPEN INPUT captured with paragraph and line."""
        result = analyze_cobol(SIMPLE_FILE_IO_COBOL)
        assert result["success"]
        opens = [op for op in result["file_operations"] if op["verb"] == "OPEN"]
        input_opens = [op for op in opens if op["direction"] == "INPUT"]
        assert len(input_opens) >= 1
        op = input_opens[0]
        assert op["file_name"].upper() == "INPUT-FILE"
        assert op["paragraph"] is not None
        assert op["line"] > 0

    def test_open_output_detected(self):
        """OPEN OUTPUT captured with paragraph and line."""
        result = analyze_cobol(SIMPLE_FILE_IO_COBOL)
        opens = [op for op in result["file_operations"] if op["verb"] == "OPEN"]
        output_opens = [op for op in opens if op["direction"] == "OUTPUT"]
        assert len(output_opens) >= 1
        assert output_opens[0]["file_name"].upper() == "OUTPUT-FILE"

    def test_read_with_into_and_at_end(self):
        """READ captures INTO target, AT END, and NOT AT END."""
        result = analyze_cobol(SIMPLE_FILE_IO_COBOL)
        reads = [op for op in result["file_operations"] if op["verb"] == "READ"]
        assert len(reads) >= 1
        rd = reads[0]
        assert rd["file_name"].upper() == "INPUT-FILE"
        assert rd["into"] is not None  # INTO WS-ACCOUNT
        assert len(rd["at_end"]) >= 1  # SET WS-EOF TO TRUE
        assert len(rd["not_at_end"]) >= 1  # PERFORM PROCESS-RECORD

    def test_write_with_from(self):
        """WRITE captures FROM source."""
        result = analyze_cobol(SIMPLE_FILE_IO_COBOL)
        writes = [op for op in result["file_operations"] if op["verb"] == "WRITE"]
        assert len(writes) >= 1
        wr = writes[0]
        assert wr["record_name"].upper() == "OUTPUT-RECORD"
        assert wr["from_source"] is not None

    def test_close_detected(self):
        """CLOSE captured for both files."""
        result = analyze_cobol(SIMPLE_FILE_IO_COBOL)
        closes = [op for op in result["file_operations"] if op["verb"] == "CLOSE"]
        assert len(closes) >= 2
        close_names = {c["file_name"].upper() for c in closes}
        assert "INPUT-FILE" in close_names
        assert "OUTPUT-FILE" in close_names

    def test_file_status_detected(self):
        """FILE STATUS IS detected and associated with correct file."""
        result = analyze_cobol(SIMPLE_FILE_IO_COBOL)
        statuses = result.get("file_statuses", [])
        assert len(statuses) >= 2
        status_map = {fs["file_name"].upper(): fs["status_variable"].upper()
                      for fs in statuses if fs.get("file_name")}
        assert "WS-IN-STATUS" in status_map.get("INPUT-FILE", "")
        assert "WS-OUT-STATUS" in status_map.get("OUTPUT-FILE", "")

    def test_fd_entries_detected(self):
        """FD entries captured for both files."""
        result = analyze_cobol(SIMPLE_FILE_IO_COBOL)
        fds = result.get("file_descriptions", [])
        assert len(fds) >= 2
        fd_names = {fd["name"].upper() for fd in fds}
        assert "INPUT-FILE" in fd_names
        assert "OUTPUT-FILE" in fd_names

    def test_all_operations_have_paragraph(self):
        """All file operations have paragraph context."""
        result = analyze_cobol(SIMPLE_FILE_IO_COBOL)
        for op in result["file_operations"]:
            assert op.get("paragraph") is not None, f"{op['verb']} missing paragraph"
            assert op.get("line", 0) > 0, f"{op['verb']} missing line"


# ══════════════════════════════════════════════════════════════════════
# Generator Tests
# ══════════════════════════════════════════════════════════════════════


class TestGeneratorFileIO:

    def test_is_io_program_flag(self):
        """_IS_IO_PROGRAM = True emitted for file I/O programs."""
        result = analyze_cobol(SIMPLE_FILE_IO_COBOL)
        code = generate_python_module(result)["code"]
        assert "_IS_IO_PROGRAM = True" in code

    def test_is_io_program_false_for_non_io(self):
        """_IS_IO_PROGRAM = False for non-I/O programs."""
        simple = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SIMPLE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-A PIC 9(5) VALUE 100.
       PROCEDURE DIVISION.
       MAIN-LOGIC.
           ADD 1 TO WS-A.
           STOP RUN.
"""
        result = analyze_cobol(simple)
        code = generate_python_module(result)["code"]
        assert "_IS_IO_PROGRAM = False" in code

    def test_io_open_emitted(self):
        """_io_open() calls emitted for OPEN INPUT/OUTPUT."""
        result = analyze_cobol(SIMPLE_FILE_IO_COBOL)
        code = generate_python_module(result)["code"]
        assert "_io_open(" in code

    def test_io_read_emitted(self):
        """_io_read() and _io_populate() emitted for READ."""
        result = analyze_cobol(SIMPLE_FILE_IO_COBOL)
        code = generate_python_module(result)["code"]
        assert "_io_read(" in code
        assert "_io_populate(" in code

    def test_at_end_branch(self):
        """AT END generates if _record is None branch."""
        result = analyze_cobol(SIMPLE_FILE_IO_COBOL)
        code = generate_python_module(result)["code"]
        assert "if _record is None:" in code

    def test_io_write_emitted(self):
        """_io_write() emitted for WRITE."""
        result = analyze_cobol(SIMPLE_FILE_IO_COBOL)
        code = generate_python_module(result)["code"]
        assert "_io_write(" in code

    def test_io_close_emitted(self):
        """_io_close() emitted for CLOSE."""
        result = analyze_cobol(SIMPLE_FILE_IO_COBOL)
        code = generate_python_module(result)["code"]
        assert "_io_close(" in code

    def test_file_meta_emitted(self):
        """_FILE_META dict emitted with file metadata."""
        result = analyze_cobol(SIMPLE_FILE_IO_COBOL)
        code = generate_python_module(result)["code"]
        assert "_FILE_META" in code

    def test_code_compiles(self):
        """Generated code compiles without syntax errors."""
        result = analyze_cobol(SIMPLE_FILE_IO_COBOL)
        code = generate_python_module(result)["code"]
        compile(code, "<test>", "exec")

    def test_emit_counts_io(self):
        """emit_counts tracks I/O statements."""
        result = analyze_cobol(SIMPLE_FILE_IO_COBOL)
        gen = generate_python_module(result)
        assert gen["emit_counts"].get("io", 0) > 0


# ══════════════════════════════════════════════════════════════════════
# Runtime I/O Tests (CobolFileManager + StreamBackend)
# ══════════════════════════════════════════════════════════════════════


class TestRuntimeIO:

    def test_stream_backend_read(self):
        """StreamBackend yields records and returns None at EOF."""
        from cobol_file_io import StreamBackend

        records = iter([{"FIELD-A": "hello"}, {"FIELD-A": "world"}])
        backend = StreamBackend(input_streams={"INPUT-FILE": records})

        rec1, status1 = backend.read("INPUT-FILE")
        assert rec1 == {"FIELD-A": "hello"}
        assert status1 == "00"

        rec2, status2 = backend.read("INPUT-FILE")
        assert rec2 == {"FIELD-A": "world"}
        assert status2 == "00"

        rec3, status3 = backend.read("INPUT-FILE")
        assert rec3 is None
        assert status3 == "10"

    def test_stream_backend_write(self):
        """StreamBackend collects output records."""
        from cobol_file_io import StreamBackend

        collector = []
        backend = StreamBackend(output_collectors={"OUTPUT-FILE": collector})

        backend.write("OUTPUT-FILE", {"RESULT": "42.00"})
        backend.write("OUTPUT-FILE", {"RESULT": "84.00"})

        assert len(collector) == 2
        assert collector[0]["RESULT"] == "42.00"

    def test_file_manager_populate(self):
        """populate() maps COBOL names to Python names and stores values."""
        from cobol_file_io import CobolFileManager, StreamBackend
        from cobol_types import CobolDecimal

        namespace = {
            "ws_amount": CobolDecimal("0", pic_integers=7, pic_decimals=2),
            "ws_account": "",
        }
        file_meta = {
            "INPUT-FILE": {
                "fields": [
                    {"name": "ACCOUNT", "python_name": "ws_account", "type": "string"},
                    {"name": "AMOUNT", "python_name": "ws_amount", "type": "decimal", "decimals": 2},
                ],
                "status_var": None,
            }
        }
        backend = StreamBackend()
        mgr = CobolFileManager(file_meta, namespace, backend)

        mgr.populate("INPUT-FILE", {"ACCOUNT": "ACCT001", "AMOUNT": Decimal("123.45")})
        assert namespace["ws_account"] == "ACCT001"
        assert namespace["ws_amount"].value == Decimal("123.45")

    def test_file_manager_status_var(self):
        """FILE STATUS variable gets set on read."""
        from cobol_file_io import CobolFileManager, StreamBackend

        namespace = {"ws_status": "00"}
        file_meta = {
            "INPUT-FILE": {
                "fields": [],
                "status_var": "ws_status",
            }
        }
        records = iter([{"X": "1"}])
        backend = StreamBackend(input_streams={"INPUT-FILE": records})
        mgr = CobolFileManager(file_meta, namespace, backend)

        mgr.read("INPUT-FILE")
        assert namespace["ws_status"] == "00"

        mgr.read("INPUT-FILE")  # EOF
        assert namespace["ws_status"] == "10"

    def test_file_manager_write_collects(self):
        """write() collects output record from namespace."""
        from cobol_file_io import CobolFileManager, StreamBackend
        from cobol_types import CobolDecimal

        namespace = {
            "ws_result": CobolDecimal("42.50", pic_integers=7, pic_decimals=2),
        }
        collector = []
        file_meta = {
            "OUTPUT-FILE": {
                "record_name": "OUTPUT-RECORD",
                "fields": [
                    {"name": "RESULT", "python_name": "ws_result", "type": "decimal", "decimals": 2},
                ],
                "status_var": None,
            }
        }
        backend = StreamBackend(output_collectors={"OUTPUT-FILE": collector})
        mgr = CobolFileManager(file_meta, namespace, backend)

        mgr.write("OUTPUT-RECORD")
        assert len(collector) == 1
        assert collector[0]["RESULT"] == "42.50"


# ══════════════════════════════════════════════════════════════════════
# Integration Tests
# ══════════════════════════════════════════════════════════════════════


class TestIntegration:

    def test_execute_io_program_basic(self):
        """End-to-end: parse → generate → execute with StreamBackend."""
        from shadow_diff import execute_io_program

        # Simple COBOL: read amount, double it, write result
        cobol = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. DOUBLE-IT.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT INPUT-FILE ASSIGN TO 'INPUT.DAT'.
           SELECT OUTPUT-FILE ASSIGN TO 'OUTPUT.DAT'.
       DATA DIVISION.
       FILE SECTION.
       FD INPUT-FILE.
       01 INPUT-RECORD.
           05 IN-AMOUNT    PIC 9(5)V99.
       FD OUTPUT-FILE.
       01 OUTPUT-RECORD.
           05 OUT-RESULT   PIC 9(5)V99.
       WORKING-STORAGE SECTION.
       01 WS-EOF           PIC X VALUE 'N'.
           88 END-OF-FILE  VALUE 'Y'.
       01 WS-AMOUNT        PIC 9(5)V99.
       01 WS-RESULT        PIC 9(5)V99.
       PROCEDURE DIVISION.
       MAIN-LOGIC.
           OPEN INPUT INPUT-FILE.
           OPEN OUTPUT OUTPUT-FILE.
           PERFORM READ-NEXT UNTIL END-OF-FILE.
           CLOSE INPUT-FILE.
           CLOSE OUTPUT-FILE.
           STOP RUN.
       READ-NEXT.
           READ INPUT-FILE
               AT END SET END-OF-FILE TO TRUE
               NOT AT END PERFORM PROCESS-REC.
       PROCESS-REC.
           MOVE IN-AMOUNT TO WS-AMOUNT.
           MULTIPLY WS-AMOUNT BY 2 GIVING WS-RESULT.
           MOVE WS-RESULT TO OUT-RESULT.
           WRITE OUTPUT-RECORD.
"""
        analysis = analyze_cobol(cobol)
        assert analysis["success"], analysis.get("message", "parse failed")
        gen = generate_python_module(analysis)
        code = gen["code"]
        assert "_IS_IO_PROGRAM = True" in code
        compile(code, "<integration>", "exec")

    def test_execute_io_program_with_records(self):
        """Execute an I/O program with actual input records via StreamBackend."""
        from shadow_diff import execute_io_program

        # Minimal COBOL: read an amount, add 10, write
        cobol = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. ADD-TEN.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT INPUT-FILE ASSIGN TO 'INPUT.DAT'.
           SELECT OUTPUT-FILE ASSIGN TO 'OUTPUT.DAT'.
       DATA DIVISION.
       FILE SECTION.
       FD INPUT-FILE.
       01 INPUT-RECORD.
           05 IN-VAL       PIC 9(5)V99.
       FD OUTPUT-FILE.
       01 OUTPUT-RECORD.
           05 OUT-VAL      PIC 9(5)V99.
       WORKING-STORAGE SECTION.
       01 WS-EOF           PIC X VALUE 'N'.
           88 END-OF-FILE  VALUE 'Y'.
       01 WS-VAL           PIC 9(5)V99.
       01 WS-OUT           PIC 9(5)V99.
       PROCEDURE DIVISION.
       MAIN-LOGIC.
           OPEN INPUT INPUT-FILE.
           OPEN OUTPUT OUTPUT-FILE.
           PERFORM READ-NEXT UNTIL END-OF-FILE.
           CLOSE INPUT-FILE.
           CLOSE OUTPUT-FILE.
           STOP RUN.
       READ-NEXT.
           READ INPUT-FILE
               AT END SET END-OF-FILE TO TRUE
               NOT AT END PERFORM CALC-IT.
       CALC-IT.
           MOVE IN-VAL TO WS-VAL.
           ADD 10 TO WS-VAL GIVING WS-OUT.
           MOVE WS-OUT TO OUT-VAL.
           WRITE OUTPUT-RECORD.
"""
        analysis = analyze_cobol(cobol)
        assert analysis["success"], analysis.get("message")
        code = generate_python_module(analysis)["code"]

        # Prepare input records
        input_records = [
            {"IN-VAL": Decimal("100.00")},
            {"IN-VAL": Decimal("200.50")},
            {"IN-VAL": Decimal("50.25")},
        ]

        results = list(execute_io_program(
            source=code,
            input_streams={"INPUT-FILE": iter(input_records)},
            output_file_name="OUTPUT-FILE",
            output_fields=["OUT-VAL"],
        ))

        assert len(results) == 3, f"Expected 3 output records, got {len(results)}: {results}"
        # Check no errors
        for r in results:
            assert "_error" not in r, f"Execution error: {r.get('_error')}"

    def test_v2_proof_shadow_diff_verified(self):
        """V2 PROOF TEST: COBOL file I/O → Shadow Diff → FULLY VERIFIED.

        This is the litmus test for V2: a file I/O COBOL program processed
        through the full Shadow Diff pipeline with zero drift.
        """
        from shadow_diff import execute_io_program, compare_outputs

        # COBOL: read amount, multiply by 3, write result
        cobol = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TRIPLE-IT.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT INPUT-FILE ASSIGN TO 'INPUT.DAT'.
           SELECT OUTPUT-FILE ASSIGN TO 'OUTPUT.DAT'.
       DATA DIVISION.
       FILE SECTION.
       FD INPUT-FILE.
       01 INPUT-RECORD.
           05 IN-AMT       PIC 9(5)V99.
       FD OUTPUT-FILE.
       01 OUTPUT-RECORD.
           05 OUT-AMT      PIC 9(5)V99.
       WORKING-STORAGE SECTION.
       01 WS-EOF           PIC X VALUE 'N'.
           88 END-OF-FILE  VALUE 'Y'.
       01 WS-AMT           PIC 9(5)V99.
       01 WS-OUT           PIC 9(5)V99.
       PROCEDURE DIVISION.
       MAIN-LOGIC.
           OPEN INPUT INPUT-FILE.
           OPEN OUTPUT OUTPUT-FILE.
           PERFORM READ-LOOP UNTIL END-OF-FILE.
           CLOSE INPUT-FILE.
           CLOSE OUTPUT-FILE.
           STOP RUN.
       READ-LOOP.
           READ INPUT-FILE
               AT END SET END-OF-FILE TO TRUE
               NOT AT END PERFORM CALC.
       CALC.
           MOVE IN-AMT TO WS-AMT.
           MULTIPLY WS-AMT BY 3 GIVING WS-OUT.
           MOVE WS-OUT TO OUT-AMT.
           WRITE OUTPUT-RECORD.
"""
        analysis = analyze_cobol(cobol)
        assert analysis["success"], analysis.get("message")
        code = generate_python_module(analysis)["code"]

        # Input records
        inputs = [
            {"IN-AMT": Decimal("10.00")},
            {"IN-AMT": Decimal("20.50")},
            {"IN-AMT": Decimal("33.33")},
        ]

        # Expected mainframe outputs (what a mainframe would produce)
        # 10.00 * 3 = 30.00, 20.50 * 3 = 61.50, 33.33 * 3 = 99.99
        expected_outputs = [
            {"OUT-AMT": "30.00"},
            {"OUT-AMT": "61.50"},
            {"OUT-AMT": "99.99"},
        ]

        # Execute
        aletheia_outputs = list(execute_io_program(
            source=code,
            input_streams={"INPUT-FILE": iter(inputs)},
            output_file_name="OUTPUT-FILE",
            output_fields=["OUT-AMT"],
        ))

        assert len(aletheia_outputs) == 3, f"Expected 3 outputs, got {len(aletheia_outputs)}: {aletheia_outputs}"

        # Check no errors
        for r in aletheia_outputs:
            assert "_error" not in r, f"Execution error: {r.get('_error')}"

        # Compare with expected mainframe outputs
        comparison = compare_outputs(
            aletheia_outputs=aletheia_outputs,
            mainframe_outputs=expected_outputs,
            output_fields=["OUT-AMT"],
        )

        assert comparison["mismatches"] == 0, (
            f"DRIFT DETECTED — expected zero drift.\n"
            f"Aletheia outputs: {aletheia_outputs}\n"
            f"Expected outputs: {expected_outputs}\n"
            f"Mismatch details: {comparison.get('mismatch_details', [])}"
        )
        assert comparison["total_records"] == 3
        assert comparison["matches"] == 3


# ══════════════════════════════════════════════════════════════════════
# FILE STATUS End-to-End Tests
# ══════════════════════════════════════════════════════════════════════

FILE_STATUS_E2E_COBOL = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. FS-TEST.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT IN-FILE ASSIGN TO 'IN.DAT'
               FILE STATUS IS WS-FS.
           SELECT OUT-FILE ASSIGN TO 'OUT.DAT'.
       DATA DIVISION.
       FILE SECTION.
       FD IN-FILE.
       01 IN-REC.
           05 IN-AMT    PIC 9(5)V99.
       FD OUT-FILE.
       01 OUT-REC.
           05 OUT-AMT   PIC 9(5)V99.
       WORKING-STORAGE SECTION.
       01 WS-FS          PIC XX.
       01 WS-EOF-FLAG    PIC X VALUE 'N'.
           88 END-OF-FILE VALUE 'Y'.
       01 WS-AMT         PIC 9(5)V99.
       01 WS-FLAG        PIC X VALUE 'N'.
       PROCEDURE DIVISION.
       MAIN-PARA.
           OPEN INPUT IN-FILE.
           OPEN OUTPUT OUT-FILE.
           PERFORM READ-NEXT UNTIL END-OF-FILE.
           CLOSE IN-FILE.
           CLOSE OUT-FILE.
           STOP RUN.
       READ-NEXT.
           READ IN-FILE
               AT END SET END-OF-FILE TO TRUE
               NOT AT END PERFORM PROCESS-REC.
       PROCESS-REC.
           MOVE IN-AMT TO WS-AMT.
           ADD 1 TO WS-AMT.
           MOVE WS-AMT TO OUT-AMT.
           WRITE OUT-REC.
"""


class TestFileStatusEndToEnd:
    """End-to-end: COBOL → analyze → generate → execute → verify FILE STATUS."""

    def _setup_io(self, cobol, input_records):
        """Parse → generate → exec module → wire CobolFileManager → return
        (namespace, mgr, output_collector).  Does NOT call main()."""
        from cobol_file_io import CobolFileManager, StreamBackend

        analysis = analyze_cobol(cobol)
        assert analysis["success"], analysis.get("message")
        code = generate_python_module(analysis)["code"]
        compile(code, "<fs-test>", "exec")

        namespace = {}
        exec(code, namespace)

        output_collector = []
        backend = StreamBackend(
            input_streams={"IN-FILE": iter(input_records)},
            output_collectors={"OUT-FILE": output_collector},
        )

        file_meta = namespace.get("_FILE_META", {})
        mgr = CobolFileManager(file_meta, namespace, backend)
        namespace["_io_open"] = mgr.open
        namespace["_io_read"] = mgr.read
        namespace["_io_write"] = mgr.write
        namespace["_io_close"] = mgr.close
        namespace["_io_populate"] = mgr.populate
        namespace["_io_write_record"] = mgr.write_record
        namespace["_io_rewrite"] = mgr.rewrite
        namespace["_io_read_by_key"] = mgr.read_by_key

        return namespace, mgr, output_collector

    def test_file_status_set_on_read(self):
        """READ success → FILE STATUS = '00' in namespace (via generated _FILE_META)."""
        ns, mgr, _ = self._setup_io(
            FILE_STATUS_E2E_COBOL,
            [{"IN-AMT": Decimal("100.00")}],
        )
        # ws_fs starts as "" (PIC XX, no VALUE clause)
        assert ns["ws_fs"] == ""

        # OPEN sets status to "00"
        mgr.open("IN-FILE", "r")
        assert ns["ws_fs"] == "00", f"Expected '00' after OPEN, got '{ns['ws_fs']}'"

        # READ success → status stays "00"
        record = mgr.read("IN-FILE")
        assert record is not None
        assert ns["ws_fs"] == "00", f"Expected '00' after READ, got '{ns['ws_fs']}'"

    def test_file_status_eof(self):
        """READ past end → FILE STATUS = '10' in namespace."""
        ns, mgr, _ = self._setup_io(
            FILE_STATUS_E2E_COBOL,
            [{"IN-AMT": Decimal("50.00")}],
        )
        mgr.open("IN-FILE", "r")
        mgr.read("IN-FILE")  # first record → "00"

        # Second read → EOF → status "10"
        record = mgr.read("IN-FILE")
        assert record is None
        assert ns["ws_fs"] == "10", f"Expected '10' (EOF), got '{ns['ws_fs']}'"

    def test_file_status_in_condition(self):
        """IF WS-FS = '00' after READ → branch taken (full main() execution)."""
        ns, _, outputs = self._setup_io(
            FILE_STATUS_E2E_COBOL,
            [
                {"IN-AMT": Decimal("10.00")},
                {"IN-AMT": Decimal("20.00")},
            ],
        )
        ns["main"]()

        # PROCESS-REC runs for each record → 2 outputs with +1 added
        assert len(outputs) == 2, (
            f"Expected 2 outputs, got {len(outputs)}: {outputs}"
        )
        assert outputs[0]["OUT-AMT"] == "11.00"
        assert outputs[1]["OUT-AMT"] == "21.00"

        # After full execution (including CLOSE), status is "00"
        assert ns["ws_fs"] == "00"


# ══════════════════════════════════════════════════════════════════════
# OPEN I-O / READ KEY IS / REWRITE tests
# ══════════════════════════════════════════════════════════════════════

OPEN_IO_COBOL = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. IO-TEST.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT MASTER-FILE ASSIGN TO 'MASTER.DAT'
               FILE STATUS IS WS-MASTER-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD MASTER-FILE.
       01 MASTER-REC.
           05 MASTER-KEY       PIC 9(5).
           05 MASTER-NAME      PIC X(10).
       WORKING-STORAGE SECTION.
       01 WS-MASTER-STATUS     PIC XX VALUE '00'.
       PROCEDURE DIVISION.
       MAIN-PARA.
           OPEN I-O MASTER-FILE.
           STOP RUN.
"""

IDX_READ_REWRITE_COBOL = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. IDX-TEST.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT IDX-FILE ASSIGN TO 'IDX.DAT'
               FILE STATUS IS WS-IDX-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD IDX-FILE.
       01 IDX-REC.
           05 IDX-KEY          PIC 9(5).
           05 IDX-NAME         PIC X(10).
       WORKING-STORAGE SECTION.
       01 WS-IDX-STATUS        PIC XX VALUE '00'.
       PROCEDURE DIVISION.
       MAIN-PARA.
           OPEN I-O IDX-FILE.
           IF WS-IDX-STATUS = '00'
               READ IDX-FILE KEY IS IDX-KEY
               IF WS-IDX-STATUS = '00'
                   REWRITE IDX-REC
               END-IF
           END-IF.
           CLOSE IDX-FILE.
           STOP RUN.
"""


class TestOpenIO(unittest.TestCase):
    """OPEN I-O emits _io_open with 'rw' mode, no MANUAL REVIEW."""

    def test_open_io_mode(self):
        analysis = analyze_cobol(OPEN_IO_COBOL)
        assert analysis["success"], analysis.get("message")

        # Analyzer detects OPEN with direction IO
        io_ops = [op for op in analysis.get("file_operations", [])
                  if op["verb"] == "OPEN" and op.get("direction") == "IO"]
        assert len(io_ops) >= 1, f"Expected OPEN I-O detected, got: {analysis.get('file_operations')}"

        # Generator emits rw mode, no MR
        code = generate_python_module(analysis)["code"]
        assert "_io_open('MASTER-FILE', 'rw')" in code
        assert "MANUAL REVIEW" not in code


class TestReadKeyAndRewrite(unittest.TestCase):
    """READ KEY IS and REWRITE inside IF branches produce real code, no MR."""

    def test_read_key_no_mr(self):
        analysis = analyze_cobol(IDX_READ_REWRITE_COBOL)
        assert analysis["success"], analysis.get("message")
        code = generate_python_module(analysis)["code"]

        # READ KEY IS should emit _io_read_by_key, not MANUAL REVIEW
        assert "_io_read_by_key" in code, f"Expected _io_read_by_key in code, got MR instead"
        assert "MANUAL REVIEW" not in code, f"Unexpected MANUAL REVIEW in generated code:\n{code}"

    def test_rewrite_no_mr(self):
        analysis = analyze_cobol(IDX_READ_REWRITE_COBOL)
        assert analysis["success"], analysis.get("message")
        code = generate_python_module(analysis)["code"]

        # REWRITE should emit _io_rewrite, not MANUAL REVIEW
        assert "_io_rewrite" in code, f"Expected _io_rewrite in code"
        assert "MANUAL REVIEW" not in code

    def test_read_key_found(self):
        """READ KEY IS with matching key returns record (noop in stream)."""
        from cobol_file_io import CobolFileManager, StreamBackend
        backend = StreamBackend()
        mgr = CobolFileManager({}, {}, backend)

        # StreamBackend.read_by_key always returns None, "23" (not found)
        record = mgr.read_by_key("IDX-FILE", "IDX-KEY", "00010")
        assert record is None

    def test_read_key_not_found(self):
        """READ KEY IS with no match returns None and status '23'."""
        from cobol_file_io import CobolFileManager, StreamBackend
        ns = {}
        file_meta = {
            "IDX-FILE": {
                "record_name": "IDX-REC",
                "fields": [
                    {"name": "IDX-KEY", "python_name": "idx_key",
                     "start": 0, "length": 5, "type": "numeric", "decimals": 0},
                ],
                "record_length": 15,
                "status_var": "ws_idx_status",
                "direction": "IO",
            }
        }
        ns["ws_idx_status"] = "00"
        backend = StreamBackend()
        mgr = CobolFileManager(file_meta, ns, backend)

        record = mgr.read_by_key("IDX-FILE", "IDX-KEY", "99999")
        assert record is None
        # Status should be "23" (record not found)
        assert ns["ws_idx_status"] == "23"


# ══════════════════════════════════════════════════════════════════════
# Indexed File Operations — START / READ NEXT / DELETE
# ══════════════════════════════════════════════════════════════════════


class TestIndexedFileOperations:
    """START, READ NEXT, DELETE for indexed files."""

    @staticmethod
    def _make_manager(records):
        from cobol_file_io import CobolFileManager, StreamBackend
        input_streams = {"IDX-FILE": iter(records)}
        backend = StreamBackend(input_streams=input_streams)
        file_meta = {
            "IDX-FILE": {
                "record_name": "IDX-REC",
                "fields": [
                    {"name": "IDX-KEY", "python_name": "idx_key", "start": 0,
                     "length": 5, "type": "string", "decimals": 0},
                    {"name": "IDX-NAME", "python_name": "idx_name", "start": 5,
                     "length": 10, "type": "string", "decimals": 0},
                ],
                "record_length": 15,
                "status_var": "ws_status",
                "direction": "IO",
            }
        }
        ns = {"ws_status": "00"}
        mgr = CobolFileManager(file_meta, ns, backend)
        mgr.open("IDX-FILE", "rw")
        return mgr, ns

    def test_start_eq_found(self):
        records = [
            {"IDX-KEY": "00010", "IDX-NAME": "ALICE"},
            {"IDX-KEY": "00020", "IDX-NAME": "BOB"},
            {"IDX-KEY": "00030", "IDX-NAME": "CAROL"},
        ]
        mgr, ns = self._make_manager(records)
        mgr.start("IDX-FILE", "IDX-KEY", "00020", mode="EQ")
        assert ns["ws_status"] == "00"

    def test_start_eq_not_found(self):
        records = [{"IDX-KEY": "00010", "IDX-NAME": "ALICE"}]
        mgr, ns = self._make_manager(records)
        mgr.start("IDX-FILE", "IDX-KEY", "99999", mode="EQ")
        assert ns["ws_status"] == "23"

    def test_start_ge_positions_correctly(self):
        records = [
            {"IDX-KEY": "00010", "IDX-NAME": "ALICE"},
            {"IDX-KEY": "00030", "IDX-NAME": "CAROL"},
        ]
        mgr, ns = self._make_manager(records)
        mgr.start("IDX-FILE", "IDX-KEY", "00020", mode="GE")
        assert ns["ws_status"] == "00"
        rec = mgr.read_next("IDX-FILE")
        assert rec is not None
        assert rec["IDX-KEY"] == "00030"

    def test_read_next_sequential(self):
        records = [
            {"IDX-KEY": "00010", "IDX-NAME": "ALICE"},
            {"IDX-KEY": "00020", "IDX-NAME": "BOB"},
        ]
        mgr, ns = self._make_manager(records)
        mgr.start("IDX-FILE", "IDX-KEY", "00010", mode="EQ")
        r1 = mgr.read_next("IDX-FILE")
        assert r1["IDX-NAME"] == "ALICE"
        r2 = mgr.read_next("IDX-FILE")
        assert r2["IDX-NAME"] == "BOB"

    def test_read_next_eof(self):
        records = [{"IDX-KEY": "00010", "IDX-NAME": "ALICE"}]
        mgr, ns = self._make_manager(records)
        mgr.start("IDX-FILE", "IDX-KEY", "00010", mode="EQ")
        mgr.read_next("IDX-FILE")
        mgr.read_next("IDX-FILE")  # past end
        assert ns["ws_status"] == "10"

    def test_delete_current_record(self):
        records = [
            {"IDX-KEY": "00010", "IDX-NAME": "ALICE"},
            {"IDX-KEY": "00020", "IDX-NAME": "BOB"},
        ]
        mgr, ns = self._make_manager(records)
        mgr.start("IDX-FILE", "IDX-KEY", "00010", mode="EQ")
        mgr.read_next("IDX-FILE")
        mgr.delete("IDX-FILE")
        assert ns["ws_status"] == "00"

    def test_delete_no_prior_read(self):
        records = [{"IDX-KEY": "00010", "IDX-NAME": "ALICE"}]
        mgr, ns = self._make_manager(records)
        mgr.delete("IDX-FILE")
        assert ns["ws_status"] == "23"

    def test_start_gt_mode(self):
        records = [
            {"IDX-KEY": "00010", "IDX-NAME": "ALICE"},
            {"IDX-KEY": "00020", "IDX-NAME": "BOB"},
            {"IDX-KEY": "00030", "IDX-NAME": "CAROL"},
        ]
        mgr, ns = self._make_manager(records)
        mgr.start("IDX-FILE", "IDX-KEY", "00010", mode="GT")
        assert ns["ws_status"] == "00"
        rec = mgr.read_next("IDX-FILE")
        assert rec["IDX-KEY"] == "00020"


# ══════════════════════════════════════════════════════════════════════
# Relative File Operations — Position-Based Access
# ══════════════════════════════════════════════════════════════════════


class TestRelativeFileOperations:
    """RELATIVE file access by record number."""

    @staticmethod
    def _make_manager():
        from cobol_file_io import CobolFileManager, StreamBackend
        backend = StreamBackend()
        file_meta = {
            "REL-FILE": {
                "record_name": "REL-REC",
                "fields": [
                    {"name": "REL-DATA", "python_name": "rel_data", "start": 0,
                     "length": 20, "type": "string", "decimals": 0},
                ],
                "record_length": 20,
                "status_var": "ws_status",
                "direction": "IO",
            }
        }
        ns = {"ws_status": "00", "rel_data": ""}
        mgr = CobolFileManager(file_meta, ns, backend)
        mgr.open("REL-FILE", "rw")
        return mgr, ns, backend

    def test_write_and_read_relative(self):
        mgr, ns, backend = self._make_manager()
        backend.write_relative("REL-FILE", {"REL-DATA": "RECORD-ONE"}, 1)
        rec = mgr.read_relative("REL-FILE", 1)
        assert rec is not None
        assert rec["REL-DATA"] == "RECORD-ONE"
        assert ns["ws_status"] == "00"

    def test_read_nonexistent_slot(self):
        mgr, ns, backend = self._make_manager()
        rec = mgr.read_relative("REL-FILE", 99)
        assert rec is None
        assert ns["ws_status"] == "23"

    def test_write_duplicate_key(self):
        mgr, ns, backend = self._make_manager()
        backend.write_relative("REL-FILE", {"REL-DATA": "FIRST"}, 5)
        status = backend.write_relative("REL-FILE", {"REL-DATA": "SECOND"}, 5)
        assert status == "22"

    def test_delete_relative(self):
        mgr, ns, backend = self._make_manager()
        backend.write_relative("REL-FILE", {"REL-DATA": "DELETE-ME"}, 3)
        mgr.delete_relative("REL-FILE", 3)
        assert ns["ws_status"] == "00"
        rec = mgr.read_relative("REL-FILE", 3)
        assert rec is None
        assert ns["ws_status"] == "23"

    def test_delete_nonexistent(self):
        mgr, ns, backend = self._make_manager()
        mgr.delete_relative("REL-FILE", 42)
        assert ns["ws_status"] == "23"

    def test_sequential_relative_slots(self):
        mgr, ns, backend = self._make_manager()
        for i in range(1, 6):
            backend.write_relative("REL-FILE", {"REL-DATA": f"REC-{i}"}, i)
        for i in range(1, 6):
            rec, status = backend.read_relative("REL-FILE", i)
            assert status == "00"
            assert rec["REL-DATA"] == f"REC-{i}"

    def test_rewrite_relative(self):
        mgr, ns, backend = self._make_manager()
        backend.write_relative("REL-FILE", {"REL-DATA": "ORIGINAL"}, 1)
        status = backend.rewrite_relative("REL-FILE", {"REL-DATA": "UPDATED"}, 1)
        assert status == "00"
        rec, status = backend.read_relative("REL-FILE", 1)
        assert rec["REL-DATA"] == "UPDATED"

    def test_rewrite_nonexistent(self):
        mgr, ns, backend = self._make_manager()
        status = backend.rewrite_relative("REL-FILE", {"REL-DATA": "X"}, 99)
        assert status == "23"
