"""
test_sort.py — Tests for COBOL SORT statement support.

Tests SORT ... USING ... GIVING ... with ascending, descending,
multi-key, numeric vs alpha, empty file, and count verification.
"""

import os
import unittest
from decimal import Decimal

os.environ.setdefault("USE_IN_MEMORY_DB", "1")

from cobol_analyzer_api import analyze_cobol
from generate_full_python import generate_python_module
from cobol_file_io import CobolFileManager, StreamBackend, ReverseKey


SORT_COBOL = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SORT-TEST.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT INPUT-FILE ASSIGN TO 'INPUT.DAT'.
           SELECT OUTPUT-FILE ASSIGN TO 'OUTPUT.DAT'.
           SELECT SORT-WORK ASSIGN TO 'SORT.TMP'.
       DATA DIVISION.
       FILE SECTION.
       FD INPUT-FILE.
       01 INPUT-RECORD.
           05 IN-KEY           PIC 9(5).
           05 IN-NAME          PIC X(10).
       FD OUTPUT-FILE.
       01 OUTPUT-RECORD.
           05 OUT-KEY          PIC 9(5).
           05 OUT-NAME         PIC X(10).
       SD SORT-WORK.
       01 SORT-RECORD.
           05 SORT-KEY         PIC 9(5).
           05 SORT-NAME        PIC X(10).
       WORKING-STORAGE SECTION.
       01 WS-EOF              PIC 9 VALUE 0.
       PROCEDURE DIVISION.
       MAIN-PARA.
           {sort_statement}
           STOP RUN.
"""


def _run_sort(cobol_source, input_records):
    """Parse COBOL, generate Python, execute SORT, return output records."""
    analysis = analyze_cobol(cobol_source)
    gen = generate_python_module(analysis)
    code = gen["code"]

    output_collector = []
    backend = StreamBackend(
        input_streams={"INPUT-FILE": iter(input_records)},
        output_collectors={"OUTPUT-FILE": output_collector},
    )

    ns = {}
    exec(code, ns)

    file_meta = ns.get("_FILE_META", {})
    mgr = CobolFileManager(file_meta, ns, backend)

    ns["_io_open"] = mgr.open
    ns["_io_read"] = mgr.read
    ns["_io_write"] = mgr.write
    ns["_io_write_record"] = mgr.write_record
    ns["_io_close"] = mgr.close
    ns["_io_populate"] = mgr.populate
    ns["_io_rewrite"] = mgr.rewrite
    ns["_io_read_by_key"] = mgr.read_by_key
    ns["ReverseKey"] = ReverseKey

    ns["main"]()
    return output_collector


class TestSingleKeyAscending(unittest.TestCase):
    """Records sorted by one numeric key, ascending order."""

    def test_ascending_sort(self):
        cobol = SORT_COBOL.format(
            sort_statement="""\
SORT SORT-WORK
               ON ASCENDING KEY SORT-KEY
               USING INPUT-FILE
               GIVING OUTPUT-FILE"""
        )

        input_records = [
            {"SORT-KEY": Decimal("30"), "SORT-NAME": "CHARLIE"},
            {"SORT-KEY": Decimal("10"), "SORT-NAME": "ALICE"},
            {"SORT-KEY": Decimal("20"), "SORT-NAME": "BOB"},
        ]

        output = _run_sort(cobol, input_records)
        keys = [r["SORT-KEY"] for r in output]
        self.assertEqual(keys, [Decimal("10"), Decimal("20"), Decimal("30")])


class TestSingleKeyDescending(unittest.TestCase):
    """Records sorted by one numeric key, descending order."""

    def test_descending_sort(self):
        cobol = SORT_COBOL.format(
            sort_statement="""\
SORT SORT-WORK
               ON DESCENDING KEY SORT-KEY
               USING INPUT-FILE
               GIVING OUTPUT-FILE"""
        )

        input_records = [
            {"SORT-KEY": Decimal("10"), "SORT-NAME": "ALICE"},
            {"SORT-KEY": Decimal("30"), "SORT-NAME": "CHARLIE"},
            {"SORT-KEY": Decimal("20"), "SORT-NAME": "BOB"},
        ]

        output = _run_sort(cobol, input_records)
        keys = [r["SORT-KEY"] for r in output]
        self.assertEqual(keys, [Decimal("30"), Decimal("20"), Decimal("10")])


class TestMultiKeySort(unittest.TestCase):
    """Two keys: primary ascending, secondary descending."""

    def test_multi_key(self):
        cobol = SORT_COBOL.format(
            sort_statement="""\
SORT SORT-WORK
               ON ASCENDING KEY SORT-KEY
               ON DESCENDING KEY SORT-NAME
               USING INPUT-FILE
               GIVING OUTPUT-FILE"""
        )

        input_records = [
            {"SORT-KEY": Decimal("20"), "SORT-NAME": "BETA"},
            {"SORT-KEY": Decimal("10"), "SORT-NAME": "ALPHA"},
            {"SORT-KEY": Decimal("20"), "SORT-NAME": "DELTA"},
            {"SORT-KEY": Decimal("10"), "SORT-NAME": "GAMMA"},
            {"SORT-KEY": Decimal("20"), "SORT-NAME": "ALPHA"},
        ]

        output = _run_sort(cobol, input_records)
        result = [(r["SORT-KEY"], r["SORT-NAME"]) for r in output]
        expected = [
            (Decimal("10"), "GAMMA"),   # key=10, name desc: GAMMA > ALPHA
            (Decimal("10"), "ALPHA"),
            (Decimal("20"), "DELTA"),   # key=20, name desc: DELTA > BETA > ALPHA
            (Decimal("20"), "BETA"),
            (Decimal("20"), "ALPHA"),
        ]
        self.assertEqual(result, expected)


class TestNumericVsAlphaKey(unittest.TestCase):
    """Numeric key sorts by value, alpha key sorts lexicographically."""

    def test_numeric_sorts_by_value(self):
        """Decimal(2) < Decimal(10) — not string '10' < '2'."""
        cobol = SORT_COBOL.format(
            sort_statement="""\
SORT SORT-WORK
               ON ASCENDING KEY SORT-KEY
               USING INPUT-FILE
               GIVING OUTPUT-FILE"""
        )

        input_records = [
            {"SORT-KEY": Decimal("2"), "SORT-NAME": "TWO"},
            {"SORT-KEY": Decimal("10"), "SORT-NAME": "TEN"},
            {"SORT-KEY": Decimal("1"), "SORT-NAME": "ONE"},
        ]

        output = _run_sort(cobol, input_records)
        keys = [r["SORT-KEY"] for r in output]
        # Numeric order: 1, 2, 10 (not lexicographic "1", "10", "2")
        self.assertEqual(keys, [Decimal("1"), Decimal("2"), Decimal("10")])

    def test_alpha_sorts_lexicographically(self):
        """String keys sort by character order."""
        cobol = SORT_COBOL.format(
            sort_statement="""\
SORT SORT-WORK
               ON ASCENDING KEY SORT-NAME
               USING INPUT-FILE
               GIVING OUTPUT-FILE"""
        )

        input_records = [
            {"SORT-KEY": Decimal("1"), "SORT-NAME": "CHERRY"},
            {"SORT-KEY": Decimal("2"), "SORT-NAME": "APPLE"},
            {"SORT-KEY": Decimal("3"), "SORT-NAME": "BANANA"},
        ]

        output = _run_sort(cobol, input_records)
        names = [r["SORT-NAME"] for r in output]
        self.assertEqual(names, ["APPLE", "BANANA", "CHERRY"])


class TestEmptyFile(unittest.TestCase):
    """Zero input records — zero output records, no crash."""

    def test_empty_input(self):
        cobol = SORT_COBOL.format(
            sort_statement="""\
SORT SORT-WORK
               ON ASCENDING KEY SORT-KEY
               USING INPUT-FILE
               GIVING OUTPUT-FILE"""
        )

        output = _run_sort(cobol, [])
        self.assertEqual(output, [])


class TestOutputCountMatchesInput(unittest.TestCase):
    """N input records produce exactly N output records."""

    def test_count_preserved(self):
        cobol = SORT_COBOL.format(
            sort_statement="""\
SORT SORT-WORK
               ON ASCENDING KEY SORT-KEY
               USING INPUT-FILE
               GIVING OUTPUT-FILE"""
        )

        input_records = [
            {"SORT-KEY": Decimal(str(i)), "SORT-NAME": f"REC-{i:05d}"}
            for i in range(50, 0, -1)
        ]

        output = _run_sort(cobol, input_records)
        self.assertEqual(len(output), 50)
        # Also verify sorted correctly
        keys = [r["SORT-KEY"] for r in output]
        self.assertEqual(keys, [Decimal(str(i)) for i in range(1, 51)])


class TestUnknownFieldDefaultsToString(unittest.TestCase):
    """SORT key field NOT in sd_field_lookup defaults to string comparison."""

    UNKNOWN_COBOL = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SORT-UNKNOWN.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT INPUT-FILE ASSIGN TO 'INPUT.DAT'.
           SELECT OUTPUT-FILE ASSIGN TO 'OUTPUT.DAT'.
           SELECT SORT-WORK ASSIGN TO 'SORT.TMP'.
       DATA DIVISION.
       FILE SECTION.
       FD INPUT-FILE.
       01 INPUT-RECORD.
           05 IN-DATA          PIC X(10).
       FD OUTPUT-FILE.
       01 OUTPUT-RECORD.
           05 OUT-DATA         PIC X(10).
       SD SORT-WORK.
       01 SORT-RECORD.
           05 SORT-DATA        PIC X(10).
       WORKING-STORAGE SECTION.
       01 WS-EOF              PIC 9 VALUE 0.
       PROCEDURE DIVISION.
       MAIN-PARA.
           SORT SORT-WORK
               ON ASCENDING KEY SORT-DATA
               USING INPUT-FILE
               GIVING OUTPUT-FILE.
           STOP RUN.
"""

    def test_sort_unknown_field_defaults_to_string(self):
        """Values 'BANANA','APPLE','CHERRY' sort lexicographically."""
        input_records = [
            {"SORT-DATA": "BANANA"},
            {"SORT-DATA": "APPLE"},
            {"SORT-DATA": "CHERRY"},
        ]
        output = _run_sort(self.UNKNOWN_COBOL, input_records)
        names = [r["SORT-DATA"] for r in output]
        self.assertEqual(names, ["APPLE", "BANANA", "CHERRY"])

    def test_sort_unknown_field_numeric_strings(self):
        """String values '9','10','2' sort lexicographically, NOT numerically."""
        input_records = [
            {"SORT-DATA": "9"},
            {"SORT-DATA": "10"},
            {"SORT-DATA": "2"},
        ]
        output = _run_sort(self.UNKNOWN_COBOL, input_records)
        values = [r["SORT-DATA"] for r in output]
        # Lexicographic: "10" < "2" < "9"
        self.assertEqual(values, ["10", "2", "9"])


class TestKnownNumericFieldStillWorks(unittest.TestCase):
    """Regression guard: explicitly numeric SD field still sorts by value."""

    def test_sort_known_numeric_field_still_works(self):
        cobol = SORT_COBOL.format(
            sort_statement="""\
SORT SORT-WORK
               ON ASCENDING KEY SORT-KEY
               USING INPUT-FILE
               GIVING OUTPUT-FILE"""
        )

        input_records = [
            {"SORT-KEY": Decimal("9"), "SORT-NAME": "NINE"},
            {"SORT-KEY": Decimal("10"), "SORT-NAME": "TEN"},
            {"SORT-KEY": Decimal("2"), "SORT-NAME": "TWO"},
        ]

        output = _run_sort(cobol, input_records)
        keys = [r["SORT-KEY"] for r in output]
        # Numeric order: 2, 9, 10
        self.assertEqual(keys, [Decimal("2"), Decimal("9"), Decimal("10")])


# ── INPUT/OUTPUT PROCEDURE tests ──────────────────────────

SORT_PROC_COBOL = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SORT-PROC-TEST.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT SORT-WORK ASSIGN TO 'SORTWORK'.
       DATA DIVISION.
       FILE SECTION.
       SD SORT-WORK.
       01 SORT-RECORD.
           05 SORT-KEY         PIC 9(5).
           05 SORT-NAME        PIC X(10).
       WORKING-STORAGE SECTION.
       01 WS-RESULT            PIC X(30).
       PROCEDURE DIVISION.
       MAIN-PARA.
           SORT SORT-WORK
               ON ASCENDING KEY SORT-KEY
               INPUT PROCEDURE IS FEED-SORT
               OUTPUT PROCEDURE IS READ-SORT.
           DISPLAY 'DONE'.
           STOP RUN.
       FEED-SORT.
           MOVE 00030 TO SORT-KEY.
           MOVE 'CHARLIE' TO SORT-NAME.
           RELEASE SORT-RECORD.
           MOVE 00010 TO SORT-KEY.
           MOVE 'ALICE' TO SORT-NAME.
           RELEASE SORT-RECORD.
           MOVE 00020 TO SORT-KEY.
           MOVE 'BOB' TO SORT-NAME.
           RELEASE SORT-RECORD.
       READ-SORT.
           RETURN SORT-WORK INTO WS-RESULT
               AT END CONTINUE
           END-RETURN.
"""


class TestSortInputOutputBasic(unittest.TestCase):
    """SORT with INPUT/OUTPUT PROCEDURE generates code, no MR."""

    def test_sort_input_output_no_mr(self):
        analysis = analyze_cobol(SORT_PROC_COBOL)
        gen = generate_python_module(analysis)
        code = gen["code"]
        self.assertNotIn("MANUAL REVIEW", code)
        self.assertIn("_sort_buffer", code)
        self.assertIn("_sort_iter", code)
        # Code compiles
        compile(code, "<sort_proc>", "exec")


class TestSortInputOutputOrder(unittest.TestCase):
    """SORT with INPUT/OUTPUT PROCEDURE sorts records correctly."""

    def test_sort_order_correct(self):
        analysis = analyze_cobol(SORT_PROC_COBOL)
        gen = generate_python_module(analysis)
        code = gen["code"]

        ns = {}
        exec(code, ns)
        ns["ReverseKey"] = ReverseKey
        ns["main"]()

        # After sort + RETURN, SORT-KEY should be 00010 (first sorted record)
        self.assertEqual(ns["sort_key"].value, Decimal("10"))


class TestSortUsingGivingRegression(unittest.TestCase):
    """Existing USING/GIVING path still works after adding INPUT/OUTPUT PROCEDURE."""

    def test_using_giving_still_works(self):
        cobol = SORT_COBOL.format(
            sort_statement="""\
SORT SORT-WORK
               ON ASCENDING KEY SORT-KEY
               USING INPUT-FILE
               GIVING OUTPUT-FILE"""
        )
        input_records = [
            {"SORT-KEY": Decimal("30"), "SORT-NAME": "CHARLIE"},
            {"SORT-KEY": Decimal("10"), "SORT-NAME": "ALICE"},
            {"SORT-KEY": Decimal("20"), "SORT-NAME": "BOB"},
        ]
        output = _run_sort(cobol, input_records)
        keys = [r["SORT-KEY"] for r in output]
        self.assertEqual(keys, [Decimal("10"), Decimal("20"), Decimal("30")])


class TestSortDuplicatesInOrder(unittest.TestCase):
    """Item 20: SORT WITH DUPLICATES IN ORDER detection."""

    def test_sort_without_duplicates_emits_warning(self):
        from cobol_analyzer_api import analyze_cobol
        from generate_full_python import generate_python_module
        cobol = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SORTND.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT SORT-FILE ASSIGN TO 'SORT'.
           SELECT IN-FILE ASSIGN TO 'INPUT'.
           SELECT OUT-FILE ASSIGN TO 'OUTPUT'.
       DATA DIVISION.
       FILE SECTION.
       SD  SORT-FILE.
       01  SORT-REC.
           05  SORT-KEY          PIC 9(5).
       FD  IN-FILE.
       01  IN-REC               PIC X(5).
       FD  OUT-FILE.
       01  OUT-REC              PIC X(5).
       PROCEDURE DIVISION.
       MAIN-PARA.
           SORT SORT-FILE ASCENDING KEY SORT-KEY
               USING IN-FILE GIVING OUT-FILE.
           STOP RUN.
"""
        result = generate_python_module(analyze_cobol(cobol))
        warnings = result.get("compiler_warnings", [])
        assert any("DUPLICATES" in w for w in warnings)

    def test_sort_with_duplicates_no_warning(self):
        from cobol_analyzer_api import analyze_cobol
        from generate_full_python import generate_python_module
        cobol = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SORTWD.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT SORT-FILE ASSIGN TO 'SORT'.
           SELECT IN-FILE ASSIGN TO 'INPUT'.
           SELECT OUT-FILE ASSIGN TO 'OUTPUT'.
       DATA DIVISION.
       FILE SECTION.
       SD  SORT-FILE.
       01  SORT-REC.
           05  SORT-KEY          PIC 9(5).
       FD  IN-FILE.
       01  IN-REC               PIC X(5).
       FD  OUT-FILE.
       01  OUT-REC              PIC X(5).
       PROCEDURE DIVISION.
       MAIN-PARA.
           SORT SORT-FILE ASCENDING KEY SORT-KEY
               WITH DUPLICATES IN ORDER
               USING IN-FILE GIVING OUT-FILE.
           STOP RUN.
"""
        result = generate_python_module(analyze_cobol(cobol))
        warnings = result.get("compiler_warnings", [])
        assert not any("DUPLICATES" in w for w in warnings)
        code = result["code"]
        assert "DUPLICATES" in code or "stable" in code


if __name__ == "__main__":
    unittest.main()
