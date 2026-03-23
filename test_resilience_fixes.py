"""
test_resilience_fixes.py — Phase 4 resilience regression tests.
Verifies parse warning accumulation and success flag accuracy.
"""

import unittest


class TestParseWarnings(unittest.TestCase):

    def test_clean_parse_no_warnings(self):
        """Well-formed COBOL should produce zero parse warnings."""
        from cobol_analyzer_api import analyze_cobol
        clean_cobol = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TESTPROG.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-A  PIC 9(5).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 10 TO WS-A.
           STOP RUN.
"""
        result = analyze_cobol(clean_cobol)
        self.assertTrue(result["success"])
        warnings = result.get("parse_warnings", [])
        self.assertEqual(len(warnings), 0, f"Unexpected warnings: {warnings}")

    def test_parse_warnings_field_exists(self):
        """Analysis result must always include parse_warnings key."""
        from cobol_analyzer_api import analyze_cobol
        cobol = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TESTPROG.
       PROCEDURE DIVISION.
       0000-MAIN.
           STOP RUN.
"""
        result = analyze_cobol(cobol)
        self.assertIn("parse_warnings", result)
        self.assertIsInstance(result["parse_warnings"], list)


if __name__ == "__main__":
    unittest.main()
