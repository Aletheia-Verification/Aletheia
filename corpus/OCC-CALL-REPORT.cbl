       IDENTIFICATION DIVISION.
       PROGRAM-ID. OCC-CALL-REPORT.
      *================================================================
      * OCC Call Report Generator (FFIEC 031/041)
      * Aggregates balance sheet and income statement data for
      * quarterly regulatory reporting with validation checks.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-REPORT-HEADER.
           05 WS-RSSD-ID              PIC 9(7).
           05 WS-BANK-NAME            PIC X(30).
           05 WS-REPORT-PERIOD        PIC 9(6).
           05 WS-REPORT-TYPE          PIC X(3).
               88 WS-FFIEC-031        VALUE '031'.
               88 WS-FFIEC-041        VALUE '041'.
       01 WS-BALANCE-SHEET.
           05 WS-BS-ASSETS.
               10 WS-CASH-DUE         PIC S9(13)V99 COMP-3.
               10 WS-SECURITIES       PIC S9(13)V99 COMP-3.
               10 WS-FED-FUNDS-SOLD   PIC S9(13)V99 COMP-3.
               10 WS-LOANS-NET        PIC S9(13)V99 COMP-3.
               10 WS-PREMISES         PIC S9(11)V99 COMP-3.
               10 WS-OTHER-ASSETS     PIC S9(11)V99 COMP-3.
               10 WS-TOTAL-ASSETS     PIC S9(15)V99 COMP-3.
           05 WS-BS-LIABILITIES.
               10 WS-DEPOSITS         PIC S9(13)V99 COMP-3.
               10 WS-FED-FUNDS-PURCH  PIC S9(13)V99 COMP-3.
               10 WS-OTHER-BORROWED   PIC S9(13)V99 COMP-3.
               10 WS-SUB-DEBT         PIC S9(11)V99 COMP-3.
               10 WS-OTHER-LIAB       PIC S9(11)V99 COMP-3.
               10 WS-TOTAL-LIAB       PIC S9(15)V99 COMP-3.
           05 WS-BS-EQUITY.
               10 WS-COMMON-STOCK     PIC S9(11)V99 COMP-3.
               10 WS-SURPLUS          PIC S9(11)V99 COMP-3.
               10 WS-RETAINED-EARN    PIC S9(11)V99 COMP-3.
               10 WS-TOTAL-EQUITY     PIC S9(13)V99 COMP-3.
       01 WS-INCOME-STMT.
           05 WS-INT-INCOME           PIC S9(11)V99 COMP-3.
           05 WS-INT-EXPENSE          PIC S9(11)V99 COMP-3.
           05 WS-NII                  PIC S9(11)V99 COMP-3.
           05 WS-PROVISION            PIC S9(11)V99 COMP-3.
           05 WS-NONINT-INCOME        PIC S9(11)V99 COMP-3.
           05 WS-NONINT-EXPENSE       PIC S9(11)V99 COMP-3.
           05 WS-PRE-TAX-INCOME       PIC S9(11)V99 COMP-3.
           05 WS-TAX-EXPENSE          PIC S9(9)V99 COMP-3.
           05 WS-NET-INCOME           PIC S9(11)V99 COMP-3.
       01 WS-VALIDATION-CHECKS.
           05 WS-CHECK OCCURS 10.
               10 WS-CHK-ID           PIC 9(3).
               10 WS-CHK-DESC         PIC X(30).
               10 WS-CHK-STATUS       PIC X(1).
                   88 WS-CHK-PASS     VALUE 'P'.
                   88 WS-CHK-FAIL     VALUE 'F'.
                   88 WS-CHK-WARN     VALUE 'W'.
               10 WS-CHK-VARIANCE     PIC S9(13)V99 COMP-3.
       01 WS-CHK-IDX                  PIC 9(2).
       01 WS-VALIDATION-RESULTS.
           05 WS-CHECKS-PASSED        PIC 9(2).
           05 WS-CHECKS-FAILED        PIC 9(2).
           05 WS-CHECKS-WARNED        PIC 9(2).
       01 WS-BS-CHECK-AMT             PIC S9(15)V99 COMP-3.
       01 WS-PROCESS-DATE             PIC 9(8).
       01 WS-DIVIDE-FIELDS.
           05 WS-AVG-CHECK-VAR        PIC S9(11)V99 COMP-3.
           05 WS-DIV-REMAIN           PIC S9(9)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-TOTALS
           PERFORM 3000-CALC-INCOME
           PERFORM 4000-RUN-VALIDATIONS
           PERFORM 5000-TALLY-RESULTS
           PERFORM 6000-DISPLAY-REPORT
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-PROCESS-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-CHECKS-PASSED
           MOVE 0 TO WS-CHECKS-FAILED
           MOVE 0 TO WS-CHECKS-WARNED.
       2000-CALC-TOTALS.
           COMPUTE WS-TOTAL-ASSETS =
               WS-CASH-DUE + WS-SECURITIES +
               WS-FED-FUNDS-SOLD + WS-LOANS-NET +
               WS-PREMISES + WS-OTHER-ASSETS
           COMPUTE WS-TOTAL-LIAB =
               WS-DEPOSITS + WS-FED-FUNDS-PURCH +
               WS-OTHER-BORROWED + WS-SUB-DEBT +
               WS-OTHER-LIAB
           COMPUTE WS-TOTAL-EQUITY =
               WS-COMMON-STOCK + WS-SURPLUS +
               WS-RETAINED-EARN.
       3000-CALC-INCOME.
           COMPUTE WS-NII =
               WS-INT-INCOME - WS-INT-EXPENSE
           COMPUTE WS-PRE-TAX-INCOME =
               WS-NII - WS-PROVISION +
               WS-NONINT-INCOME - WS-NONINT-EXPENSE
           COMPUTE WS-NET-INCOME =
               WS-PRE-TAX-INCOME - WS-TAX-EXPENSE.
       4000-RUN-VALIDATIONS.
           MOVE 1 TO WS-CHK-ID(1)
           MOVE "A=L+E BALANCE CHECK" TO WS-CHK-DESC(1)
           COMPUTE WS-BS-CHECK-AMT =
               WS-TOTAL-LIAB + WS-TOTAL-EQUITY
           COMPUTE WS-CHK-VARIANCE(1) =
               WS-TOTAL-ASSETS - WS-BS-CHECK-AMT
           IF WS-CHK-VARIANCE(1) = 0
               SET WS-CHK-PASS(1) TO TRUE
           ELSE
               SET WS-CHK-FAIL(1) TO TRUE
           END-IF
           MOVE 2 TO WS-CHK-ID(2)
           MOVE "NET INCOME CROSS-CHECK"
               TO WS-CHK-DESC(2)
           COMPUTE WS-CHK-VARIANCE(2) =
               WS-PRE-TAX-INCOME - WS-TAX-EXPENSE -
               WS-NET-INCOME
           IF WS-CHK-VARIANCE(2) = 0
               SET WS-CHK-PASS(2) TO TRUE
           ELSE
               SET WS-CHK-FAIL(2) TO TRUE
           END-IF
           MOVE 3 TO WS-CHK-ID(3)
           MOVE "ASSETS POSITIVE" TO WS-CHK-DESC(3)
           MOVE 0 TO WS-CHK-VARIANCE(3)
           IF WS-TOTAL-ASSETS >= 0
               SET WS-CHK-PASS(3) TO TRUE
           ELSE
               SET WS-CHK-FAIL(3) TO TRUE
           END-IF.
       5000-TALLY-RESULTS.
           PERFORM VARYING WS-CHK-IDX FROM 1 BY 1
               UNTIL WS-CHK-IDX > 3
               EVALUATE TRUE
                   WHEN WS-CHK-PASS(WS-CHK-IDX)
                       ADD 1 TO WS-CHECKS-PASSED
                   WHEN WS-CHK-FAIL(WS-CHK-IDX)
                       ADD 1 TO WS-CHECKS-FAILED
                   WHEN WS-CHK-WARN(WS-CHK-IDX)
                       ADD 1 TO WS-CHECKS-WARNED
               END-EVALUATE
           END-PERFORM
           IF WS-CHECKS-FAILED > 0
               DIVIDE WS-CHK-VARIANCE(1) BY
                   WS-CHECKS-FAILED
                   GIVING WS-AVG-CHECK-VAR
                   REMAINDER WS-DIV-REMAIN
           END-IF.
       6000-DISPLAY-REPORT.
           DISPLAY "OCC CALL REPORT"
           DISPLAY "RSSD: " WS-RSSD-ID
           DISPLAY "PERIOD: " WS-REPORT-PERIOD
           DISPLAY "TYPE: " WS-REPORT-TYPE
           DISPLAY "TOTAL ASSETS: " WS-TOTAL-ASSETS
           DISPLAY "TOTAL LIABILITIES: " WS-TOTAL-LIAB
           DISPLAY "TOTAL EQUITY: " WS-TOTAL-EQUITY
           DISPLAY "NET INCOME: " WS-NET-INCOME
           DISPLAY "VALIDATION: PASS=" WS-CHECKS-PASSED
               " FAIL=" WS-CHECKS-FAILED
               " WARN=" WS-CHECKS-WARNED
           IF WS-CHECKS-FAILED > 0
               DISPLAY "REPORT CANNOT BE SUBMITTED"
           ELSE
               DISPLAY "REPORT READY FOR SUBMISSION"
           END-IF.
