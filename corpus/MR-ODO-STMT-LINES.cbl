       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-ODO-STMT-LINES.
      *================================================================*
      * Customer Statement with Variable-Length Lines (ODO)            *
      * Uses OCCURS DEPENDING ON for dynamic transaction line          *
      * count in statement generation.                                 *
      * INTENTIONAL: Uses OCCURS DEPENDING ON for MANUAL REVIEW.       *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- Customer Info ---
       01  WS-CUST-NAME              PIC X(35).
       01  WS-ACCT-NUM               PIC 9(10).
       01  WS-STMT-DATE              PIC 9(8).
      *--- Variable-Length Transaction Detail ---
       01  WS-ACTUAL-LINE-CT         PIC S9(3) COMP-3.
       01  WS-STMT-BLOCK.
           05  WS-STMT-LINE
               OCCURS 1 TO 50 TIMES
               DEPENDING ON WS-ACTUAL-LINE-CT.
               10  WS-SL-DATE        PIC 9(8).
               10  WS-SL-DESC        PIC X(25).
               10  WS-SL-AMOUNT      PIC S9(9)V99 COMP-3.
               10  WS-SL-BALANCE     PIC S9(11)V99 COMP-3.
      *--- Running Totals ---
       01  WS-OPENING-BAL            PIC S9(11)V99 COMP-3.
       01  WS-RUNNING-BAL            PIC S9(11)V99 COMP-3.
       01  WS-TOTAL-DEBITS           PIC S9(11)V99 COMP-3.
       01  WS-TOTAL-CREDITS          PIC S9(11)V99 COMP-3.
       01  WS-CLOSING-BAL            PIC S9(11)V99 COMP-3.
       01  WS-DEBIT-CT               PIC S9(5) COMP-3.
       01  WS-CREDIT-CT              PIC S9(5) COMP-3.
      *--- Loop Control ---
       01  WS-LINE-IDX               PIC 9(3).
      *--- Interest ---
       01  WS-INT-RATE               PIC S9(3)V9(6) COMP-3.
       01  WS-INT-EARNED             PIC S9(7)V99 COMP-3.
       01  WS-DAYS-IN-PERIOD         PIC S9(3) COMP-3.
      *--- Display ---
       01  WS-DISP-AMT               PIC -$$$,$$$,$$9.99.
       01  WS-DISP-BAL               PIC -$$$,$$$,$$$,$$9.99.
       01  WS-DISP-CT                PIC ZZ9.
      *--- Tally ---
       01  WS-DESC-TALLY             PIC S9(3) COMP-3.

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-LINES
           PERFORM 3000-COMPUTE-BALANCES
           PERFORM 4000-CALCULATE-INTEREST
           PERFORM 5000-PRINT-STATEMENT
           STOP RUN.

       1000-INITIALIZE.
           MOVE "WILLIAMS, JAMES R"
               TO WS-CUST-NAME
           MOVE 9988776655 TO WS-ACCT-NUM
           ACCEPT WS-STMT-DATE FROM DATE YYYYMMDD
           MOVE 8 TO WS-ACTUAL-LINE-CT
           MOVE 15234.50 TO WS-OPENING-BAL
           MOVE WS-OPENING-BAL TO WS-RUNNING-BAL
           MOVE 0 TO WS-TOTAL-DEBITS
           MOVE 0 TO WS-TOTAL-CREDITS
           MOVE 0 TO WS-DEBIT-CT
           MOVE 0 TO WS-CREDIT-CT
           MOVE 0.0325 TO WS-INT-RATE
           MOVE 30 TO WS-DAYS-IN-PERIOD.

       2000-LOAD-LINES.
           MOVE 20260301 TO WS-SL-DATE(1)
           MOVE "PAYROLL DEPOSIT"
               TO WS-SL-DESC(1)
           MOVE 3250.00 TO WS-SL-AMOUNT(1)
           MOVE 20260303 TO WS-SL-DATE(2)
           MOVE "ATM WITHDRAWAL"
               TO WS-SL-DESC(2)
           MOVE -200.00 TO WS-SL-AMOUNT(2)
           MOVE 20260305 TO WS-SL-DATE(3)
           MOVE "ELECTRIC CO PMT"
               TO WS-SL-DESC(3)
           MOVE -145.67 TO WS-SL-AMOUNT(3)
           MOVE 20260308 TO WS-SL-DATE(4)
           MOVE "ONLINE TRANSFER IN"
               TO WS-SL-DESC(4)
           MOVE 500.00 TO WS-SL-AMOUNT(4)
           MOVE 20260310 TO WS-SL-DATE(5)
           MOVE "CHECK 2045"
               TO WS-SL-DESC(5)
           MOVE -1875.00 TO WS-SL-AMOUNT(5)
           MOVE 20260315 TO WS-SL-DATE(6)
           MOVE "PAYROLL DEPOSIT"
               TO WS-SL-DESC(6)
           MOVE 3250.00 TO WS-SL-AMOUNT(6)
           MOVE 20260318 TO WS-SL-DATE(7)
           MOVE "INSURANCE PREMIUM"
               TO WS-SL-DESC(7)
           MOVE -425.00 TO WS-SL-AMOUNT(7)
           MOVE 20260320 TO WS-SL-DATE(8)
           MOVE "POS PURCHASE"
               TO WS-SL-DESC(8)
           MOVE -89.99 TO WS-SL-AMOUNT(8).

       3000-COMPUTE-BALANCES.
           PERFORM VARYING WS-LINE-IDX FROM 1 BY 1
               UNTIL WS-LINE-IDX > WS-ACTUAL-LINE-CT
               ADD WS-SL-AMOUNT(WS-LINE-IDX)
                   TO WS-RUNNING-BAL
               MOVE WS-RUNNING-BAL
                   TO WS-SL-BALANCE(WS-LINE-IDX)
               IF WS-SL-AMOUNT(WS-LINE-IDX) > 0
                   ADD WS-SL-AMOUNT(WS-LINE-IDX)
                       TO WS-TOTAL-CREDITS
                   ADD 1 TO WS-CREDIT-CT
               ELSE
                   SUBTRACT WS-SL-AMOUNT(WS-LINE-IDX)
                       FROM WS-TOTAL-DEBITS
                   ADD 1 TO WS-DEBIT-CT
               END-IF
           END-PERFORM.

       4000-CALCULATE-INTEREST.
           COMPUTE WS-INT-EARNED ROUNDED =
               WS-RUNNING-BAL * WS-INT-RATE
               / 365 * WS-DAYS-IN-PERIOD
           ADD WS-INT-EARNED TO WS-RUNNING-BAL
           MOVE WS-RUNNING-BAL TO WS-CLOSING-BAL.

       5000-PRINT-STATEMENT.
           DISPLAY "========================================"
           DISPLAY "   CUSTOMER STATEMENT"
           DISPLAY "========================================"
           DISPLAY "NAME:    " WS-CUST-NAME
           DISPLAY "ACCOUNT: " WS-ACCT-NUM
           MOVE WS-OPENING-BAL TO WS-DISP-BAL
           DISPLAY "OPENING: " WS-DISP-BAL
           DISPLAY "--- TRANSACTIONS ---"
           PERFORM VARYING WS-LINE-IDX FROM 1 BY 1
               UNTIL WS-LINE-IDX > WS-ACTUAL-LINE-CT
               MOVE 0 TO WS-DESC-TALLY
               INSPECT WS-SL-DESC(WS-LINE-IDX)
                   TALLYING WS-DESC-TALLY FOR ALL SPACES
               MOVE WS-SL-AMOUNT(WS-LINE-IDX)
                   TO WS-DISP-AMT
               MOVE WS-SL-BALANCE(WS-LINE-IDX)
                   TO WS-DISP-BAL
               DISPLAY WS-SL-DATE(WS-LINE-IDX) " "
                   WS-SL-DESC(WS-LINE-IDX) " "
                   WS-DISP-AMT
           END-PERFORM
           DISPLAY "--- SUMMARY ---"
           MOVE WS-TOTAL-CREDITS TO WS-DISP-AMT
           DISPLAY "CREDITS:  " WS-DISP-AMT
           MOVE WS-TOTAL-DEBITS TO WS-DISP-AMT
           DISPLAY "DEBITS:   " WS-DISP-AMT
           MOVE WS-INT-EARNED TO WS-DISP-AMT
           DISPLAY "INTEREST: " WS-DISP-AMT
           MOVE WS-CLOSING-BAL TO WS-DISP-BAL
           DISPLAY "CLOSING:  " WS-DISP-BAL
           MOVE WS-ACTUAL-LINE-CT TO WS-DISP-CT
           DISPLAY "LINES:    " WS-DISP-CT
           DISPLAY "========================================".
