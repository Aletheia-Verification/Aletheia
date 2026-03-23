       IDENTIFICATION DIVISION.
       PROGRAM-ID. CUST-STMT-GEN.
      *================================================================*
      * Customer Statement Generation                                  *
      * Builds monthly statements with transaction details, running    *
      * balance, interest earned, fees charged, and summary totals.    *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- Customer/Account ---
       01  WS-CUSTOMER-NAME           PIC X(40).
       01  WS-ACCOUNT-NUM             PIC 9(10).
       01  WS-STMT-PERIOD.
           05  WS-PERIOD-FROM         PIC 9(8).
           05  WS-PERIOD-TO           PIC 9(8).
       01  WS-ACCT-TYPE               PIC 9.
           88  WS-TYPE-CHECKING       VALUE 1.
           88  WS-TYPE-SAVINGS        VALUE 2.
           88  WS-TYPE-MMA            VALUE 3.
      *--- Transaction Detail Table ---
       01  WS-TXN-TABLE.
           05  WS-TXN-ENTRY OCCURS 12 TIMES.
               10  WS-TXN-DATE        PIC 9(8).
               10  WS-TXN-CODE        PIC X(3).
               10  WS-TXN-DESC        PIC X(30).
               10  WS-TXN-AMOUNT      PIC S9(9)V99 COMP-3.
               10  WS-TXN-BALANCE     PIC S9(11)V99 COMP-3.
       01  WS-TXN-IDX                 PIC 9(3).
       01  WS-TXN-COUNT               PIC 9(3).
      *--- Running Totals ---
       01  WS-OPENING-BAL             PIC S9(11)V99 COMP-3.
       01  WS-CLOSING-BAL             PIC S9(11)V99 COMP-3.
       01  WS-RUNNING-BAL             PIC S9(11)V99 COMP-3.
       01  WS-TOTAL-DEPOSITS          PIC S9(11)V99 COMP-3.
       01  WS-TOTAL-WITHDRAWALS       PIC S9(11)V99 COMP-3.
       01  WS-TOTAL-FEES              PIC S9(7)V99 COMP-3.
       01  WS-TOTAL-INTEREST          PIC S9(7)V99 COMP-3.
       01  WS-DEPOSIT-COUNT           PIC S9(5) COMP-3.
       01  WS-WITHDRAWAL-COUNT        PIC S9(5) COMP-3.
      *--- Interest Calculation ---
       01  WS-ANNUAL-RATE             PIC S9(3)V9(6) COMP-3.
       01  WS-DAILY-RATE              PIC S9(3)V9(8) COMP-3.
       01  WS-DAYS-IN-PERIOD          PIC S9(3) COMP-3.
       01  WS-AVG-DAILY-BAL           PIC S9(11)V99 COMP-3.
       01  WS-BAL-SUM                 PIC S9(13)V99 COMP-3.
       01  WS-INTEREST-EARNED         PIC S9(7)V99 COMP-3.
      *--- Fee Assessment ---
       01  WS-MIN-BALANCE             PIC S9(9)V99 COMP-3.
       01  WS-LOWEST-BALANCE          PIC S9(11)V99 COMP-3.
       01  WS-MAINT-FEE               PIC S9(5)V99 COMP-3.
       01  WS-FEE-WAIVED              PIC 9.
      *--- Statement Line ---
       01  WS-STMT-LINE               PIC X(80).
       01  WS-FORMATTED-DATE          PIC X(10).
      *--- Display ---
       01  WS-DISP-AMT                PIC -$$$,$$$,$$9.99.
       01  WS-DISP-BAL                PIC -$$$,$$$,$$$,$$9.99.
       01  WS-DISP-RATE               PIC Z9.999999.
       01  WS-DISP-CT                 PIC ZZ9.
      *--- Tallying ---
       01  WS-FEE-TALLY               PIC S9(5) COMP-3.

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-TRANSACTIONS
           PERFORM 3000-PROCESS-TRANSACTIONS
           PERFORM 4000-CALCULATE-INTEREST
           PERFORM 5000-ASSESS-FEES
           PERFORM 6000-COMPUTE-CLOSING
           PERFORM 7000-PRINT-STATEMENT
           STOP RUN.

       1000-INITIALIZE.
           MOVE "JOHNSON, MARIA T"
               TO WS-CUSTOMER-NAME
           MOVE 4455667788 TO WS-ACCOUNT-NUM
           MOVE 20260201 TO WS-PERIOD-FROM
           MOVE 20260228 TO WS-PERIOD-TO
           MOVE 1 TO WS-ACCT-TYPE
           MOVE 12543.87 TO WS-OPENING-BAL
           MOVE WS-OPENING-BAL TO WS-RUNNING-BAL
           MOVE WS-OPENING-BAL TO WS-LOWEST-BALANCE
           MOVE 0 TO WS-TOTAL-DEPOSITS
           MOVE 0 TO WS-TOTAL-WITHDRAWALS
           MOVE 0 TO WS-TOTAL-FEES
           MOVE 0 TO WS-TOTAL-INTEREST
           MOVE 0 TO WS-DEPOSIT-COUNT
           MOVE 0 TO WS-WITHDRAWAL-COUNT
           MOVE 0 TO WS-BAL-SUM
           MOVE 0.0425 TO WS-ANNUAL-RATE
           COMPUTE WS-DAILY-RATE ROUNDED =
               WS-ANNUAL-RATE / 365
           MOVE 28 TO WS-DAYS-IN-PERIOD
           MOVE 1500.00 TO WS-MIN-BALANCE
           MOVE 12.00 TO WS-MAINT-FEE.

       2000-LOAD-TRANSACTIONS.
           MOVE 8 TO WS-TXN-COUNT
           MOVE 20260203 TO WS-TXN-DATE(1)
           MOVE "DEP" TO WS-TXN-CODE(1)
           MOVE "DIRECT DEPOSIT PAYROLL"
               TO WS-TXN-DESC(1)
           MOVE 3250.00 TO WS-TXN-AMOUNT(1)
           MOVE 20260205 TO WS-TXN-DATE(2)
           MOVE "WTH" TO WS-TXN-CODE(2)
           MOVE "ATM WITHDRAWAL"
               TO WS-TXN-DESC(2)
           MOVE -200.00 TO WS-TXN-AMOUNT(2)
           MOVE 20260208 TO WS-TXN-DATE(3)
           MOVE "CHK" TO WS-TXN-CODE(3)
           MOVE "CHECK 1042"
               TO WS-TXN-DESC(3)
           MOVE -1875.50 TO WS-TXN-AMOUNT(3)
           MOVE 20260210 TO WS-TXN-DATE(4)
           MOVE "ACH" TO WS-TXN-CODE(4)
           MOVE "ELECTRIC COMPANY PMT"
               TO WS-TXN-DESC(4)
           MOVE -145.67 TO WS-TXN-AMOUNT(4)
           MOVE 20260214 TO WS-TXN-DATE(5)
           MOVE "DEP" TO WS-TXN-CODE(5)
           MOVE "MOBILE DEPOSIT"
               TO WS-TXN-DESC(5)
           MOVE 500.00 TO WS-TXN-AMOUNT(5)
           MOVE 20260218 TO WS-TXN-DATE(6)
           MOVE "DEP" TO WS-TXN-CODE(6)
           MOVE "DIRECT DEPOSIT PAYROLL"
               TO WS-TXN-DESC(6)
           MOVE 3250.00 TO WS-TXN-AMOUNT(6)
           MOVE 20260222 TO WS-TXN-DATE(7)
           MOVE "WTH" TO WS-TXN-CODE(7)
           MOVE "POS PURCHASE"
               TO WS-TXN-DESC(7)
           MOVE -89.99 TO WS-TXN-AMOUNT(7)
           MOVE 20260225 TO WS-TXN-DATE(8)
           MOVE "ACH" TO WS-TXN-CODE(8)
           MOVE "INSURANCE PREMIUM"
               TO WS-TXN-DESC(8)
           MOVE -325.00 TO WS-TXN-AMOUNT(8).

       3000-PROCESS-TRANSACTIONS.
           PERFORM VARYING WS-TXN-IDX FROM 1 BY 1
               UNTIL WS-TXN-IDX > WS-TXN-COUNT
               ADD WS-TXN-AMOUNT(WS-TXN-IDX)
                   TO WS-RUNNING-BAL
               MOVE WS-RUNNING-BAL
                   TO WS-TXN-BALANCE(WS-TXN-IDX)
               IF WS-TXN-AMOUNT(WS-TXN-IDX) > 0
                   ADD WS-TXN-AMOUNT(WS-TXN-IDX)
                       TO WS-TOTAL-DEPOSITS
                   ADD 1 TO WS-DEPOSIT-COUNT
               ELSE
                   SUBTRACT WS-TXN-AMOUNT(WS-TXN-IDX)
                       FROM WS-TOTAL-WITHDRAWALS
                   ADD 1 TO WS-WITHDRAWAL-COUNT
               END-IF
               IF WS-RUNNING-BAL < WS-LOWEST-BALANCE
                   MOVE WS-RUNNING-BAL
                       TO WS-LOWEST-BALANCE
               END-IF
               ADD WS-RUNNING-BAL TO WS-BAL-SUM
           END-PERFORM.

       4000-CALCULATE-INTEREST.
           COMPUTE WS-AVG-DAILY-BAL ROUNDED =
               WS-BAL-SUM / WS-TXN-COUNT
           COMPUTE WS-INTEREST-EARNED ROUNDED =
               WS-AVG-DAILY-BAL * WS-DAILY-RATE
               * WS-DAYS-IN-PERIOD
           MOVE WS-INTEREST-EARNED TO WS-TOTAL-INTEREST.

       5000-ASSESS-FEES.
           MOVE 0 TO WS-FEE-WAIVED
           MOVE 0 TO WS-FEE-TALLY
           INSPECT WS-CUSTOMER-NAME
               TALLYING WS-FEE-TALLY FOR ALL ","
           IF WS-LOWEST-BALANCE < WS-MIN-BALANCE
               EVALUATE TRUE
                   WHEN WS-TYPE-CHECKING
                       MOVE 12.00 TO WS-MAINT-FEE
                   WHEN WS-TYPE-SAVINGS
                       MOVE 5.00 TO WS-MAINT-FEE
                   WHEN WS-TYPE-MMA
                       MOVE 15.00 TO WS-MAINT-FEE
               END-EVALUATE
               MOVE WS-MAINT-FEE TO WS-TOTAL-FEES
           ELSE
               MOVE 0 TO WS-TOTAL-FEES
               MOVE 1 TO WS-FEE-WAIVED
           END-IF.

       6000-COMPUTE-CLOSING.
           COMPUTE WS-CLOSING-BAL =
               WS-RUNNING-BAL + WS-TOTAL-INTEREST
               - WS-TOTAL-FEES.

       7000-PRINT-STATEMENT.
           DISPLAY "========================================"
           DISPLAY "   MONTHLY ACCOUNT STATEMENT"
           DISPLAY "========================================"
           DISPLAY "NAME:    " WS-CUSTOMER-NAME
           DISPLAY "ACCOUNT: " WS-ACCOUNT-NUM
           DISPLAY "PERIOD:  " WS-PERIOD-FROM
               " TO " WS-PERIOD-TO
           DISPLAY "--- TRANSACTIONS ---"
           PERFORM VARYING WS-TXN-IDX FROM 1 BY 1
               UNTIL WS-TXN-IDX > WS-TXN-COUNT
               MOVE WS-TXN-AMOUNT(WS-TXN-IDX)
                   TO WS-DISP-AMT
               MOVE WS-TXN-BALANCE(WS-TXN-IDX)
                   TO WS-DISP-BAL
               DISPLAY WS-TXN-DATE(WS-TXN-IDX) " "
                   WS-TXN-CODE(WS-TXN-IDX) " "
                   WS-DISP-AMT " " WS-DISP-BAL
           END-PERFORM
           DISPLAY "--- SUMMARY ---"
           MOVE WS-OPENING-BAL TO WS-DISP-BAL
           DISPLAY "OPENING:   " WS-DISP-BAL
           MOVE WS-TOTAL-DEPOSITS TO WS-DISP-AMT
           DISPLAY "DEPOSITS:  " WS-DISP-AMT
           MOVE WS-TOTAL-WITHDRAWALS TO WS-DISP-AMT
           DISPLAY "WITHDRAWS: " WS-DISP-AMT
           MOVE WS-TOTAL-INTEREST TO WS-DISP-AMT
           DISPLAY "INTEREST:  " WS-DISP-AMT
           MOVE WS-TOTAL-FEES TO WS-DISP-AMT
           DISPLAY "FEES:      " WS-DISP-AMT
           MOVE WS-CLOSING-BAL TO WS-DISP-BAL
           DISPLAY "CLOSING:   " WS-DISP-BAL
           DISPLAY "========================================".
