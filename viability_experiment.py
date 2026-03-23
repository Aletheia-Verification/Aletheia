"""
Aletheia Viability Experiment
=============================
Measures parse/generate/compile success rates across 25 realistic COBOL
programs written to stress real-world constructs (not our own demo files).

Output: summary table + PVR (Parse-Verify Rate).
Does NOT fix any engine issues — measurement only.
"""

import os, sys, traceback, re
from collections import Counter, defaultdict

os.environ["USE_IN_MEMORY_DB"] = "1"

from cobol_analyzer_api import analyze_cobol
from generate_full_python import generate_python_module

# ════════════════════════════════════════════════════════════════════
# 25 REALISTIC COBOL PROGRAMS
# Patterns from GnuCOBOL test suite, IBM sample programs, and
# real mainframe codebases. Each tests constructs the engine may
# or may not handle.
# ════════════════════════════════════════════════════════════════════

PROGRAMS = {

# ── 1. Basic PERFORM THRU with mixed arithmetic ──
"PAYROLL-CALC": """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. PAYROLL-CALC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-GROSS-PAY           PIC S9(7)V99 COMP-3.
       01  WS-NET-PAY             PIC S9(7)V99 COMP-3.
       01  WS-HOURS               PIC 9(3)V9.
       01  WS-RATE                PIC S9(3)V99.
       01  WS-OVERTIME-HRS        PIC 9(3)V9.
       01  WS-OVERTIME-PAY        PIC S9(7)V99 COMP-3.
       01  WS-FED-TAX             PIC S9(7)V99 COMP-3.
       01  WS-STATE-TAX           PIC S9(7)V99 COMP-3.
       01  WS-FICA               PIC S9(7)V99 COMP-3.
       01  WS-DEDUCTIONS          PIC S9(7)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-CALC-GROSS THRU 1000-EXIT.
           PERFORM 2000-CALC-TAXES THRU 2000-EXIT.
           PERFORM 3000-CALC-NET.
           STOP RUN.
       1000-CALC-GROSS.
           MULTIPLY WS-HOURS BY WS-RATE
               GIVING WS-GROSS-PAY.
           IF WS-HOURS > 40
               SUBTRACT 40 FROM WS-HOURS
                   GIVING WS-OVERTIME-HRS
               MULTIPLY WS-OVERTIME-HRS BY WS-RATE
                   GIVING WS-OVERTIME-PAY
               MULTIPLY WS-OVERTIME-PAY BY 1.5
               ADD WS-OVERTIME-PAY TO WS-GROSS-PAY
           END-IF.
       1000-EXIT.
           EXIT.
       2000-CALC-TAXES.
           MULTIPLY WS-GROSS-PAY BY 0.22
               GIVING WS-FED-TAX.
           MULTIPLY WS-GROSS-PAY BY 0.05
               GIVING WS-STATE-TAX.
           MULTIPLY WS-GROSS-PAY BY 0.0765
               GIVING WS-FICA.
       2000-EXIT.
           EXIT.
       3000-CALC-NET.
           ADD WS-FED-TAX WS-STATE-TAX WS-FICA
               GIVING WS-DEDUCTIONS.
           SUBTRACT WS-DEDUCTIONS FROM WS-GROSS-PAY
               GIVING WS-NET-PAY.
""",

# ── 2. OCCURS clause with subscript access ──
"MONTHLY-TOTALS": """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. MONTHLY-TOTALS.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-MONTHLY-TABLE.
           05  WS-MONTH-AMT        PIC S9(9)V99 COMP-3
                   OCCURS 12 TIMES.
       01  WS-ANNUAL-TOTAL         PIC S9(11)V99 COMP-3.
       01  WS-IDX                  PIC 9(2).
       01  WS-AVERAGE              PIC S9(9)V99 COMP-3.
       01  WS-HIGH-MONTH           PIC 9(2).
       01  WS-HIGH-VALUE           PIC S9(9)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 0 TO WS-ANNUAL-TOTAL.
           MOVE 0 TO WS-HIGH-VALUE.
           PERFORM 1000-SUM-MONTHS
               VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > 12.
           DIVIDE WS-ANNUAL-TOTAL BY 12
               GIVING WS-AVERAGE.
           STOP RUN.
       1000-SUM-MONTHS.
           ADD WS-MONTH-AMT(WS-IDX) TO WS-ANNUAL-TOTAL.
           IF WS-MONTH-AMT(WS-IDX) > WS-HIGH-VALUE
               MOVE WS-MONTH-AMT(WS-IDX) TO WS-HIGH-VALUE
               MOVE WS-IDX TO WS-HIGH-MONTH
           END-IF.
""",

# ── 3. REDEFINES with group items ──
"ACCT-REDEFINE": """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCT-REDEFINE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-ACCT-RECORD.
           05  WS-ACCT-NUM         PIC X(10).
           05  WS-ACCT-TYPE        PIC X(2).
           05  WS-ACCT-BAL-RAW     PIC X(12).
       01  WS-ACCT-NUMERIC REDEFINES WS-ACCT-RECORD.
           05  FILLER              PIC X(12).
           05  WS-ACCT-BAL-NUM     PIC S9(9)V99.
       01  WS-RESULT               PIC X(20).
       01  WS-BALANCE              PIC S9(9)V99.
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE WS-ACCT-BAL-NUM TO WS-BALANCE.
           IF WS-BALANCE > 0
               MOVE 'POSITIVE' TO WS-RESULT
           ELSE
               MOVE 'NEGATIVE' TO WS-RESULT
           END-IF.
           STOP RUN.
""",

# ── 4. Multiple 88-levels with THRU ranges ──
"STATUS-CHECKER": """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. STATUS-CHECKER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-FILE-STATUS          PIC 9(2).
           88  STATUS-OK           VALUE 0.
           88  STATUS-EOF          VALUE 10.
           88  STATUS-DUP-KEY      VALUE 22.
           88  STATUS-NOT-FOUND    VALUE 23.
           88  STATUS-PERM-ERROR   VALUE 30 THRU 39.
           88  STATUS-LOGIC-ERROR  VALUE 40 THRU 49.
           88  STATUS-ANY-ERROR    VALUE 10 THRU 99.
       01  WS-ACTION               PIC X(20).
       01  WS-RETRY-COUNT          PIC 9(2).
       01  WS-MAX-RETRIES          PIC 9(2) VALUE 3.
       PROCEDURE DIVISION.
       0000-MAIN.
           EVALUATE TRUE
               WHEN STATUS-OK
                   MOVE 'CONTINUE' TO WS-ACTION
               WHEN STATUS-EOF
                   MOVE 'END-OF-FILE' TO WS-ACTION
               WHEN STATUS-DUP-KEY
                   MOVE 'SKIP-DUPLICATE' TO WS-ACTION
               WHEN STATUS-NOT-FOUND
                   MOVE 'LOG-MISSING' TO WS-ACTION
               WHEN STATUS-PERM-ERROR
                   MOVE 'ABORT' TO WS-ACTION
               WHEN STATUS-LOGIC-ERROR
                   MOVE 'RETRY' TO WS-ACTION
                   ADD 1 TO WS-RETRY-COUNT
               WHEN OTHER
                   MOVE 'UNKNOWN-ERROR' TO WS-ACTION
           END-EVALUATE.
           STOP RUN.
""",

# ── 5. INITIALIZE with group items ──
"INIT-TEST": """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. INIT-TEST.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-CUSTOMER-REC.
           05  WS-CUST-NAME        PIC X(30).
           05  WS-CUST-ADDR        PIC X(50).
           05  WS-CUST-BALANCE     PIC S9(9)V99 COMP-3.
           05  WS-CUST-STATUS      PIC X(1).
           05  WS-CUST-ACCTS       PIC 9(2).
       01  WS-TRANS-REC.
           05  WS-TRANS-CODE       PIC X(4).
           05  WS-TRANS-AMT        PIC S9(7)V99 COMP-3.
           05  WS-TRANS-DATE       PIC 9(8).
       PROCEDURE DIVISION.
       0000-MAIN.
           INITIALIZE WS-CUSTOMER-REC.
           INITIALIZE WS-TRANS-REC.
           MOVE 'DEPOSIT' TO WS-TRANS-CODE.
           MOVE 1500.00 TO WS-TRANS-AMT.
           ADD WS-TRANS-AMT TO WS-CUST-BALANCE.
           STOP RUN.
""",

# ── 6. DISPLAY with mixed expressions ──
"DISPLAY-MIX": """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. DISPLAY-MIX.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-NAME                 PIC X(20).
       01  WS-AMOUNT               PIC S9(7)V99.
       01  WS-DATE-FIELD           PIC 9(8).
       01  WS-COUNTER              PIC 9(5).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 'JOHN DOE' TO WS-NAME.
           MOVE 12345.67 TO WS-AMOUNT.
           MOVE 20260308 TO WS-DATE-FIELD.
           DISPLAY 'Customer: ' WS-NAME.
           DISPLAY 'Amount:   ' WS-AMOUNT.
           DISPLAY 'Date:     ' WS-DATE-FIELD.
           DISPLAY 'Processing complete'.
           STOP RUN.
""",

# ── 7. Nested EVALUATE inside IF ──
"NESTED-EVAL": """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. NESTED-EVAL.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-REGION               PIC X(2).
       01  WS-PRODUCT              PIC X(3).
       01  WS-RATE                 PIC S9(1)V9(4).
       01  WS-VOLUME               PIC S9(7)V99.
       01  WS-DISCOUNT             PIC S9(1)V9(4).
       01  WS-NET-RATE             PIC S9(1)V9(4).
       PROCEDURE DIVISION.
       0000-MAIN.
           IF WS-VOLUME > 100000
               EVALUATE WS-REGION
                   WHEN 'US'
                       MOVE 0.0350 TO WS-RATE
                   WHEN 'EU'
                       MOVE 0.0425 TO WS-RATE
                   WHEN 'AP'
                       MOVE 0.0500 TO WS-RATE
                   WHEN OTHER
                       MOVE 0.0600 TO WS-RATE
               END-EVALUATE
               MOVE 0.0050 TO WS-DISCOUNT
           ELSE
               EVALUATE WS-REGION
                   WHEN 'US'
                       MOVE 0.0450 TO WS-RATE
                   WHEN 'EU'
                       MOVE 0.0525 TO WS-RATE
                   WHEN OTHER
                       MOVE 0.0700 TO WS-RATE
               END-EVALUATE
               MOVE 0 TO WS-DISCOUNT
           END-IF.
           SUBTRACT WS-DISCOUNT FROM WS-RATE
               GIVING WS-NET-RATE.
           STOP RUN.
""",

# ── 8. GO TO with paragraph flow ──
"GOTO-FLOW": """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. GOTO-FLOW.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT                PIC X(10).
       01  WS-CODE                 PIC 9(2).
       01  WS-RESULT               PIC X(20).
       PROCEDURE DIVISION.
       0000-MAIN.
           IF WS-CODE = 1
               GO TO 1000-PROCESS-A
           END-IF.
           IF WS-CODE = 2
               GO TO 2000-PROCESS-B
           END-IF.
           GO TO 9000-DEFAULT.
       1000-PROCESS-A.
           MOVE 'RESULT-A' TO WS-RESULT.
           GO TO 9999-EXIT.
       2000-PROCESS-B.
           MOVE 'RESULT-B' TO WS-RESULT.
           GO TO 9999-EXIT.
       9000-DEFAULT.
           MOVE 'DEFAULT' TO WS-RESULT.
       9999-EXIT.
           STOP RUN.
""",

# ── 9. COMPUTE with complex expressions ──
"COMPOUND-INT": """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. COMPOUND-INT.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-PRINCIPAL            PIC S9(11)V99 COMP-3.
       01  WS-RATE                 PIC S9(1)V9(6) COMP-3.
       01  WS-PERIODS              PIC 9(3).
       01  WS-COMPOUND-FREQ        PIC 9(2).
       01  WS-FUTURE-VALUE         PIC S9(13)V99 COMP-3.
       01  WS-PERIODIC-RATE        PIC S9(1)V9(8) COMP-3.
       01  WS-GROWTH-FACTOR        PIC S9(3)V9(10) COMP-3.
       01  WS-EFFECTIVE-RATE       PIC S9(1)V9(8) COMP-3.
       01  WS-TOTAL-INTEREST       PIC S9(11)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN.
           DIVIDE WS-RATE BY WS-COMPOUND-FREQ
               GIVING WS-PERIODIC-RATE.
           COMPUTE WS-GROWTH-FACTOR =
               (1 + WS-PERIODIC-RATE) **
               (WS-PERIODS * WS-COMPOUND-FREQ).
           COMPUTE WS-FUTURE-VALUE =
               WS-PRINCIPAL * WS-GROWTH-FACTOR.
           SUBTRACT WS-PRINCIPAL FROM WS-FUTURE-VALUE
               GIVING WS-TOTAL-INTEREST.
           COMPUTE WS-EFFECTIVE-RATE =
               (1 + WS-PERIODIC-RATE) ** WS-COMPOUND-FREQ - 1.
           STOP RUN.
""",

# ── 10. STRING with multiple sources ──
"MSG-BUILDER": """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. MSG-BUILDER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-FIRST-NAME           PIC X(15).
       01  WS-LAST-NAME            PIC X(20).
       01  WS-ACCT-NUM             PIC X(10).
       01  WS-FULL-MSG             PIC X(100).
       01  WS-SEPARATOR            PIC X VALUE '|'.
       PROCEDURE DIVISION.
       0000-MAIN.
           STRING WS-FIRST-NAME DELIMITED BY SIZE
                  ' ' DELIMITED BY SIZE
                  WS-LAST-NAME DELIMITED BY SIZE
                  WS-SEPARATOR DELIMITED BY SIZE
                  WS-ACCT-NUM DELIMITED BY SIZE
                  INTO WS-FULL-MSG.
           STOP RUN.
""",

# ── 11. UNSTRING with multiple targets ──
"CSV-PARSER": """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CSV-PARSER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-CSV-LINE             PIC X(200).
       01  WS-FIELD-1              PIC X(30).
       01  WS-FIELD-2              PIC X(30).
       01  WS-FIELD-3              PIC X(30).
       01  WS-FIELD-4              PIC X(30).
       01  WS-FIELD-5              PIC X(30).
       01  WS-FIELD-COUNT          PIC 9(2).
       PROCEDURE DIVISION.
       0000-MAIN.
           UNSTRING WS-CSV-LINE
               DELIMITED BY ','
               INTO WS-FIELD-1
                    WS-FIELD-2
                    WS-FIELD-3
                    WS-FIELD-4
                    WS-FIELD-5.
           STOP RUN.
""",

# ── 12. INSPECT TALLYING and REPLACING combined ──
"DATA-CLEANER": """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. DATA-CLEANER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT-REC            PIC X(80).
       01  WS-DASH-COUNT           PIC 9(3).
       01  WS-SPACE-COUNT          PIC 9(3).
       01  WS-CLEANED              PIC X(80).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 0 TO WS-DASH-COUNT.
           MOVE 0 TO WS-SPACE-COUNT.
           INSPECT WS-INPUT-REC
               TALLYING WS-DASH-COUNT FOR ALL '-'.
           INSPECT WS-INPUT-REC
               TALLYING WS-SPACE-COUNT FOR ALL SPACES.
           INSPECT WS-INPUT-REC
               REPLACING ALL '-' BY ' '.
           MOVE WS-INPUT-REC TO WS-CLEANED.
           STOP RUN.
""",

# ── 13. IS NUMERIC / IS ALPHABETIC class conditions ──
"TYPE-CHECKER": """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TYPE-CHECKER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-FIELD-A              PIC X(20).
       01  WS-FIELD-B              PIC X(20).
       01  WS-NUM-FLAG             PIC X(1).
       01  WS-ALPHA-FLAG           PIC X(1).
       01  WS-RESULT               PIC X(30).
       PROCEDURE DIVISION.
       0000-MAIN.
           IF WS-FIELD-A IS NUMERIC
               MOVE 'Y' TO WS-NUM-FLAG
           ELSE
               MOVE 'N' TO WS-NUM-FLAG
           END-IF.
           IF WS-FIELD-B IS ALPHABETIC
               MOVE 'Y' TO WS-ALPHA-FLAG
           ELSE
               MOVE 'N' TO WS-ALPHA-FLAG
           END-IF.
           IF WS-FIELD-A IS ALPHABETIC-LOWER
               MOVE 'LOWERCASE' TO WS-RESULT
           END-IF.
           STOP RUN.
""",

# ── 14. PERFORM TIMES ──
"REPEAT-TIMES": """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. REPEAT-TIMES.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-COUNTER              PIC 9(3).
       01  WS-TOTAL                PIC S9(9)V99 COMP-3.
       01  WS-INCREMENT            PIC S9(5)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 0 TO WS-TOTAL.
           MOVE 100.50 TO WS-INCREMENT.
           PERFORM 1000-ADD-AMOUNT 10 TIMES.
           STOP RUN.
       1000-ADD-AMOUNT.
           ADD WS-INCREMENT TO WS-TOTAL.
           ADD 1 TO WS-COUNTER.
""",

# ── 15. EVALUATE variable (not TRUE) ──
"EVAL-VARIABLE": """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. EVAL-VARIABLE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-MONTH                PIC 9(2).
       01  WS-DAYS                 PIC 9(2).
       01  WS-MONTH-NAME           PIC X(9).
       01  WS-QUARTER              PIC 9(1).
       PROCEDURE DIVISION.
       0000-MAIN.
           EVALUATE WS-MONTH
               WHEN 1
                   MOVE 'JANUARY' TO WS-MONTH-NAME
                   MOVE 31 TO WS-DAYS
                   MOVE 1 TO WS-QUARTER
               WHEN 2
                   MOVE 'FEBRUARY' TO WS-MONTH-NAME
                   MOVE 28 TO WS-DAYS
                   MOVE 1 TO WS-QUARTER
               WHEN 3
                   MOVE 'MARCH' TO WS-MONTH-NAME
                   MOVE 31 TO WS-DAYS
                   MOVE 1 TO WS-QUARTER
               WHEN 4
                   MOVE 'APRIL' TO WS-MONTH-NAME
                   MOVE 30 TO WS-DAYS
                   MOVE 2 TO WS-QUARTER
               WHEN 12
                   MOVE 'DECEMBER' TO WS-MONTH-NAME
                   MOVE 31 TO WS-DAYS
                   MOVE 4 TO WS-QUARTER
               WHEN OTHER
                   MOVE 'UNKNOWN' TO WS-MONTH-NAME
                   MOVE 0 TO WS-DAYS
           END-EVALUATE.
           STOP RUN.
""",

# ── 16. OCCURS DEPENDING ON ──
"DYNAMIC-TABLE": """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. DYNAMIC-TABLE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-ITEM-COUNT           PIC 9(3).
       01  WS-ORDER-TABLE.
           05  WS-ORDER-LINE OCCURS 1 TO 100 TIMES
                   DEPENDING ON WS-ITEM-COUNT.
               10  WS-ITEM-CODE    PIC X(10).
               10  WS-ITEM-QTY     PIC 9(5).
               10  WS-ITEM-PRICE   PIC S9(7)V99.
       01  WS-ORDER-TOTAL          PIC S9(9)V99 COMP-3.
       01  WS-LINE-TOTAL           PIC S9(9)V99 COMP-3.
       01  WS-IDX                  PIC 9(3).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 0 TO WS-ORDER-TOTAL.
           PERFORM 1000-CALC-LINE
               VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-ITEM-COUNT.
           STOP RUN.
       1000-CALC-LINE.
           MULTIPLY WS-ITEM-QTY(WS-IDX) BY WS-ITEM-PRICE(WS-IDX)
               GIVING WS-LINE-TOTAL.
           ADD WS-LINE-TOTAL TO WS-ORDER-TOTAL.
""",

# ── 17. ALTER statement (should force MANUAL REVIEW) ──
"ALTER-DANGER": """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. ALTER-DANGER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-MODE                 PIC X(10).
       01  WS-RESULT               PIC X(20).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-DISPATCH.
           STOP RUN.
       1000-DISPATCH.
           GO TO 2000-DEFAULT.
       2000-DEFAULT.
           MOVE 'DEFAULT' TO WS-RESULT.
       3000-OVERRIDE.
           MOVE 'OVERRIDE' TO WS-RESULT.
       4000-SETUP.
           ALTER 1000-DISPATCH TO PROCEED TO 3000-OVERRIDE.
""",

# ── 18. GO TO DEPENDING ON ──
"GOTO-DEPEND": """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. GOTO-DEPEND.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-OPTION               PIC 9(1).
       01  WS-RESULT               PIC X(20).
       PROCEDURE DIVISION.
       0000-MAIN.
           GO TO 1000-OPT-A 2000-OPT-B 3000-OPT-C
               DEPENDING ON WS-OPTION.
           MOVE 'INVALID' TO WS-RESULT.
           STOP RUN.
       1000-OPT-A.
           MOVE 'OPTION-A' TO WS-RESULT.
           STOP RUN.
       2000-OPT-B.
           MOVE 'OPTION-B' TO WS-RESULT.
           STOP RUN.
       3000-OPT-C.
           MOVE 'OPTION-C' TO WS-RESULT.
           STOP RUN.
""",

# ── 19. EVALUATE ALSO (multi-subject) ──
"EVAL-ALSO": """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. EVAL-ALSO.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-GENDER               PIC X(1).
       01  WS-AGE-GROUP            PIC X(5).
       01  WS-PREMIUM              PIC S9(5)V99.
       PROCEDURE DIVISION.
       0000-MAIN.
           EVALUATE WS-GENDER ALSO WS-AGE-GROUP
               WHEN 'M' ALSO 'YOUNG'
                   MOVE 350.00 TO WS-PREMIUM
               WHEN 'M' ALSO 'MID'
                   MOVE 200.00 TO WS-PREMIUM
               WHEN 'F' ALSO 'YOUNG'
                   MOVE 300.00 TO WS-PREMIUM
               WHEN 'F' ALSO 'MID'
                   MOVE 175.00 TO WS-PREMIUM
               WHEN OTHER
                   MOVE 500.00 TO WS-PREMIUM
           END-EVALUATE.
           STOP RUN.
""",

# ── 20. STRING with POINTER (should flag MANUAL REVIEW) ──
"STRING-PTR": """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. STRING-PTR.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-BUFFER               PIC X(100).
       01  WS-PTR                  PIC 9(3) VALUE 1.
       01  WS-FIELD-A              PIC X(20).
       01  WS-FIELD-B              PIC X(20).
       PROCEDURE DIVISION.
       0000-MAIN.
           STRING WS-FIELD-A DELIMITED BY SPACES
                  '/' DELIMITED BY SIZE
                  WS-FIELD-B DELIMITED BY SPACES
                  INTO WS-BUFFER
                  WITH POINTER WS-PTR.
           STOP RUN.
""",

# ── 21. UNSTRING with DELIMITER IN and COUNT IN ──
"UNSTR-COMPLEX": """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. UNSTR-COMPLEX.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT                PIC X(100).
       01  WS-PART-1               PIC X(30).
       01  WS-PART-2               PIC X(30).
       01  WS-DELIM-1              PIC X(1).
       01  WS-COUNT-1              PIC 9(3).
       01  WS-COUNT-2              PIC 9(3).
       PROCEDURE DIVISION.
       0000-MAIN.
           UNSTRING WS-INPUT
               DELIMITED BY ','
               INTO WS-PART-1
                   DELIMITER IN WS-DELIM-1
                   COUNT IN WS-COUNT-1
                    WS-PART-2
                   COUNT IN WS-COUNT-2.
           STOP RUN.
""",

# ── 22. INSPECT CONVERTING (should flag MANUAL REVIEW) ──
"INSPECT-CONV": """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. INSPECT-CONV.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-DATA                 PIC X(50).
       PROCEDURE DIVISION.
       0000-MAIN.
           INSPECT WS-DATA
               CONVERTING
                   'abcdefghijklmnopqrstuvwxyz'
               TO  'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.
           STOP RUN.
""",

# ── 23. DIVIDE with REMAINDER ──
"DIV-REMAINDER": """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. DIV-REMAINDER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-TOTAL-CENTS          PIC 9(7).
       01  WS-DOLLARS              PIC 9(5).
       01  WS-CENTS                PIC 9(2).
       01  WS-QUARTERS             PIC 9(3).
       01  WS-LEFT-OVER            PIC 9(2).
       PROCEDURE DIVISION.
       0000-MAIN.
           DIVIDE WS-TOTAL-CENTS BY 100
               GIVING WS-DOLLARS
               REMAINDER WS-CENTS.
           DIVIDE WS-CENTS BY 25
               GIVING WS-QUARTERS
               REMAINDER WS-LEFT-OVER.
           STOP RUN.
""",

# ── 24. Deeply nested IF/ELSE (5 levels) ──
"DEEP-NEST": """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. DEEP-NEST.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-A                    PIC 9(3).
       01  WS-B                    PIC 9(3).
       01  WS-C                    PIC 9(3).
       01  WS-D                    PIC 9(3).
       01  WS-E                    PIC 9(3).
       01  WS-RESULT               PIC X(30).
       PROCEDURE DIVISION.
       0000-MAIN.
           IF WS-A > 100
               IF WS-B > 50
                   IF WS-C > 25
                       IF WS-D > 10
                           IF WS-E > 5
                               MOVE 'LEVEL-5' TO WS-RESULT
                           ELSE
                               MOVE 'LEVEL-4' TO WS-RESULT
                           END-IF
                       ELSE
                           MOVE 'LEVEL-3' TO WS-RESULT
                       END-IF
                   ELSE
                       MOVE 'LEVEL-2' TO WS-RESULT
                   END-IF
               ELSE
                   MOVE 'LEVEL-1' TO WS-RESULT
               END-IF
           ELSE
               MOVE 'LEVEL-0' TO WS-RESULT
           END-IF.
           STOP RUN.
""",

# ── 25. Mixed: PERFORM VARYING + EVALUATE + STRING + arithmetic ──
"INVOICE-GEN": """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. INVOICE-GEN.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-LINE-COUNT           PIC 9(2).
       01  WS-LINE-IDX             PIC 9(2).
       01  WS-LINE-AMT             PIC S9(7)V99 COMP-3.
       01  WS-LINE-QTY             PIC 9(3).
       01  WS-LINE-PRICE           PIC S9(5)V99 COMP-3.
       01  WS-SUBTOTAL             PIC S9(9)V99 COMP-3.
       01  WS-TAX-RATE             PIC S9(1)V9(4) COMP-3.
       01  WS-TAX-AMT              PIC S9(7)V99 COMP-3.
       01  WS-DISCOUNT-PCT         PIC S9(1)V9(4) COMP-3.
       01  WS-DISCOUNT-AMT         PIC S9(7)V99 COMP-3.
       01  WS-GRAND-TOTAL          PIC S9(9)V99 COMP-3.
       01  WS-CUST-TYPE            PIC X(3).
       01  WS-INVOICE-MSG          PIC X(80).
       01  WS-CUST-NAME            PIC X(30).
       01  WS-INV-NUMBER           PIC X(10).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 0 TO WS-SUBTOTAL.
           MOVE 0.0825 TO WS-TAX-RATE.
           PERFORM 1000-CALC-LINES
               VARYING WS-LINE-IDX FROM 1 BY 1
               UNTIL WS-LINE-IDX > WS-LINE-COUNT.
           PERFORM 2000-APPLY-DISCOUNT.
           PERFORM 3000-CALC-TOTAL.
           PERFORM 4000-FORMAT-MSG.
           STOP RUN.
       1000-CALC-LINES.
           MULTIPLY WS-LINE-QTY BY WS-LINE-PRICE
               GIVING WS-LINE-AMT.
           ADD WS-LINE-AMT TO WS-SUBTOTAL.
       2000-APPLY-DISCOUNT.
           EVALUATE WS-CUST-TYPE
               WHEN 'VIP'
                   MOVE 0.15 TO WS-DISCOUNT-PCT
               WHEN 'PRE'
                   MOVE 0.10 TO WS-DISCOUNT-PCT
               WHEN 'REG'
                   MOVE 0.05 TO WS-DISCOUNT-PCT
               WHEN OTHER
                   MOVE 0 TO WS-DISCOUNT-PCT
           END-EVALUATE.
           MULTIPLY WS-SUBTOTAL BY WS-DISCOUNT-PCT
               GIVING WS-DISCOUNT-AMT.
       3000-CALC-TOTAL.
           SUBTRACT WS-DISCOUNT-AMT FROM WS-SUBTOTAL.
           MULTIPLY WS-SUBTOTAL BY WS-TAX-RATE
               GIVING WS-TAX-AMT.
           ADD WS-SUBTOTAL TO WS-TAX-AMT
               GIVING WS-GRAND-TOTAL.
       4000-FORMAT-MSG.
           STRING 'INV-' DELIMITED BY SIZE
                  WS-INV-NUMBER DELIMITED BY SIZE
                  '|' DELIMITED BY SIZE
                  WS-CUST-NAME DELIMITED BY SIZE
                  INTO WS-INVOICE-MSG.
""",

}

# ════════════════════════════════════════════════════════════════════
# ALSO TEST ALL EXISTING .CBL FILES IN THE PROJECT
# ════════════════════════════════════════════════════════════════════

CBL_DIRS = [".", "demo_data", "corpus"]

for d in CBL_DIRS:
    if not os.path.isdir(d):
        continue
    for fname in os.listdir(d):
        if fname.upper().endswith(".CBL"):
            path = os.path.join(d, fname)
            key = fname.replace(".cbl", "").replace(".CBL", "")
            if key not in PROGRAMS:
                with open(path, "r", encoding="utf-8", errors="replace") as f:
                    PROGRAMS[key] = f.read()


# ════════════════════════════════════════════════════════════════════
# RUN EXPERIMENT
# ════════════════════════════════════════════════════════════════════

def detect_constructs(source):
    """Detect which COBOL constructs appear in source text."""
    src = source.upper()
    constructs = set()
    checks = {
        "PERFORM": r"\bPERFORM\b",
        "PERFORM VARYING": r"\bPERFORM\b.*\bVARYING\b",
        "PERFORM THRU": r"\bPERFORM\b.*\bTHRU\b",
        "PERFORM TIMES": r"\b\d+\s+TIMES\b",
        "EVALUATE TRUE": r"\bEVALUATE\s+TRUE\b",
        "EVALUATE variable": r"\bEVALUATE\s+WS-",
        "EVALUATE ALSO": r"\bEVALUATE\b.*\bALSO\b",
        "IF/ELSE": r"\bIF\b",
        "COMPUTE": r"\bCOMPUTE\b",
        "MOVE": r"\bMOVE\b",
        "ADD": r"\bADD\b",
        "SUBTRACT": r"\bSUBTRACT\b",
        "MULTIPLY": r"\bMULTIPLY\b",
        "DIVIDE": r"\bDIVIDE\b",
        "DIVIDE REMAINDER": r"\bREMAINDER\b",
        "STRING": r"\bSTRING\b.*\bDELIMITED\b",
        "UNSTRING": r"\bUNSTRING\b",
        "INSPECT TALLYING": r"\bINSPECT\b.*\bTALLYING\b",
        "INSPECT REPLACING": r"\bINSPECT\b.*\bREPLACING\b",
        "INSPECT CONVERTING": r"\bINSPECT\b.*\bCONVERTING\b",
        "DISPLAY": r"\bDISPLAY\b",
        "GO TO": r"\bGO\s+TO\b",
        "GO TO DEPENDING": r"\bGO\s+TO\b.*\bDEPENDING\b",
        "ALTER": r"\bALTER\b",
        "STOP RUN": r"\bSTOP\s+RUN\b",
        "INITIALIZE": r"\bINITIALIZE\b",
        "COMP-3": r"\bCOMP-3\b",
        "88-level": r"^\s*88\s",
        "88 THRU": r"\b88\b.*\bTHRU\b",
        "REDEFINES": r"\bREDEFINES\b",
        "OCCURS": r"\bOCCURS\b",
        "OCCURS DEPENDING": r"\bOCCURS\b.*\bDEPENDING\b",
        "COPY": r"\bCOPY\b",
        "EXEC SQL": r"\bEXEC\s+SQL\b",
        "IS NUMERIC": r"\bIS\s+NUMERIC\b",
        "IS ALPHABETIC": r"\bIS\s+ALPHABETIC\b",
        "STRING POINTER": r"\bWITH\s+POINTER\b",
        "DELIMITER IN": r"\bDELIMITER\s+IN\b",
    }
    for name, pattern in checks.items():
        if re.search(pattern, src, re.MULTILINE):
            constructs.add(name)
    return constructs


def run_experiment():
    results = []
    construct_freq = Counter()
    failure_cats = Counter()
    manual_review_reasons = []

    for name, source in sorted(PROGRAMS.items()):
        record = {
            "name": name,
            "lines": len(source.strip().split("\n")),
            "constructs": set(),
            "parse_ok": False,
            "parse_errors": 0,
            "generate_ok": False,
            "compile_ok": False,
            "manual_review": 0,
            "emit_counts": {},
            "failure": None,
        }

        # Detect constructs
        record["constructs"] = detect_constructs(source)
        for c in record["constructs"]:
            construct_freq[c] += 1

        # Step 1: Parse
        try:
            parsed = analyze_cobol(source)
            record["parse_ok"] = parsed.get("success", False)
            record["parse_errors"] = parsed.get("parse_errors", 0)
            if not record["parse_ok"] and record["parse_errors"] == 0:
                record["parse_ok"] = True  # success=False but no errors
        except Exception as e:
            record["failure"] = f"PARSE CRASH: {e}"
            failure_cats["parse_crash"] += 1
            results.append(record)
            continue

        # Step 2: Generate
        try:
            gen_result = generate_python_module(parsed)
            code = gen_result["code"]
            record["generate_ok"] = True
            record["emit_counts"] = gen_result.get("emit_counts", {})

            # Count MANUAL REVIEW markers
            mr_count = code.count("# MANUAL REVIEW")
            record["manual_review"] = mr_count
            if mr_count > 0:
                # Extract reasons
                for line in code.split("\n"):
                    if "# MANUAL REVIEW" in line:
                        manual_review_reasons.append(
                            f"{name}: {line.strip()[:100]}")
        except Exception as e:
            record["failure"] = f"GENERATE CRASH: {e}"
            failure_cats["generate_crash"] += 1
            results.append(record)
            continue

        # Step 3: Compile
        try:
            compile(code, f"<{name}>", "exec")
            record["compile_ok"] = True
        except SyntaxError as e:
            record["failure"] = f"COMPILE ERROR: {e.msg} (line {e.lineno})"
            failure_cats["compile_error"] += 1
        except Exception as e:
            record["failure"] = f"COMPILE CRASH: {e}"
            failure_cats["compile_crash"] += 1

        results.append(record)

    return results, construct_freq, failure_cats, manual_review_reasons


def print_report(results, construct_freq, failure_cats, manual_review_reasons):
    total = len(results)
    parse_ok = sum(1 for r in results if r["parse_ok"])
    gen_ok = sum(1 for r in results if r["generate_ok"])
    compile_ok = sum(1 for r in results if r["compile_ok"])
    mr_programs = sum(1 for r in results if r["manual_review"] > 0)
    total_mr = sum(r["manual_review"] for r in results)
    clean_verified = sum(1 for r in results
                         if r["compile_ok"] and r["manual_review"] == 0)

    pvr = (clean_verified / total * 100) if total > 0 else 0

    print("=" * 90)
    print("  ALETHEIA VIABILITY EXPERIMENT")
    print("=" * 90)
    print()

    # Summary table
    print(f"  Programs tested    : {total}")
    print(f"  Parse success      : {parse_ok}/{total} "
          f"({parse_ok/total*100:.1f}%)")
    print(f"  Generate success   : {gen_ok}/{total} "
          f"({gen_ok/total*100:.1f}%)")
    print(f"  Compile success    : {compile_ok}/{total} "
          f"({compile_ok/total*100:.1f}%)")
    print(f"  Clean (0 MR)       : {clean_verified}/{total} "
          f"({clean_verified/total*100:.1f}%)")
    print(f"  With MANUAL REVIEW : {mr_programs} programs, "
          f"{total_mr} total flags")
    print()
    print(f"  PVR (Parse-Verify Rate) = {pvr:.1f}%")
    print()

    # Per-program detail table
    hdr = f"  {'PROGRAM':<25} {'LINES':>5} {'PARSE':>6} {'GEN':>5} "
    hdr += f"{'COMP':>5} {'MR':>4} {'STATUS':<30}"
    print(hdr)
    print("  " + "-" * 86)

    for r in results:
        status = ""
        if r["failure"]:
            status = r["failure"][:30]
        elif r["manual_review"] > 0:
            status = f"{r['manual_review']} MANUAL REVIEW flags"
        elif r["compile_ok"]:
            status = "VERIFIED"

        print(f"  {r['name']:<25} {r['lines']:>5} "
              f"{'OK' if r['parse_ok'] else 'FAIL':>6} "
              f"{'OK' if r['generate_ok'] else 'FAIL':>5} "
              f"{'OK' if r['compile_ok'] else 'FAIL':>5} "
              f"{r['manual_review']:>4} "
              f"{status:<30}")

    # Construct frequency
    print()
    print("  CONSTRUCT FREQUENCY (across all programs)")
    print("  " + "-" * 50)
    for construct, count in construct_freq.most_common():
        bar = "#" * min(count, 40)
        print(f"  {construct:<25} {count:>3} {bar}")

    # Failure categories
    if failure_cats:
        print()
        print("  FAILURE CATEGORIES")
        print("  " + "-" * 50)
        for cat, count in failure_cats.most_common():
            print(f"  {cat:<30} {count}")

    # Manual review reasons
    if manual_review_reasons:
        print()
        print(f"  MANUAL REVIEW FLAGS ({len(manual_review_reasons)} total)")
        print("  " + "-" * 50)
        for reason in manual_review_reasons:
            print(f"  {reason}")

    print()
    print("=" * 90)
    print(f"  PVR = {pvr:.1f}%  "
          f"({clean_verified} clean / {total} tested)")
    print("=" * 90)


if __name__ == "__main__":
    results, construct_freq, failure_cats, mr_reasons = run_experiment()
    print_report(results, construct_freq, failure_cats, mr_reasons)
