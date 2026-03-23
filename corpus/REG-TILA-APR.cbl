       IDENTIFICATION DIVISION.
       PROGRAM-ID. REG-TILA-APR.
      *================================================================
      * Truth-in-Lending Act APR Disclosure Calculator
      * Computes APR for consumer loans using iterative
      * approximation, validates Regulation Z tolerances.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-LOAN-DATA.
           05 WS-LOAN-AMOUNT          PIC S9(9)V99 COMP-3.
           05 WS-NOTE-RATE            PIC S9(2)V9(4) COMP-3.
           05 WS-TERM-MONTHS          PIC 9(3).
           05 WS-PAYMENT-AMT          PIC S9(7)V99 COMP-3.
           05 WS-LOAN-TYPE            PIC X(2).
               88 WS-FIXED            VALUE 'FX'.
               88 WS-VARIABLE         VALUE 'VR'.
               88 WS-BALLOON          VALUE 'BL'.
       01 WS-FINANCE-CHARGES.
           05 WS-ORIGINATION-FEE      PIC S9(7)V99 COMP-3.
           05 WS-DISCOUNT-POINTS      PIC S9(7)V99 COMP-3.
           05 WS-BROKER-FEE           PIC S9(7)V99 COMP-3.
           05 WS-PMI-UPFRONT          PIC S9(7)V99 COMP-3.
           05 WS-PREPAID-INT          PIC S9(5)V99 COMP-3.
           05 WS-TOTAL-FIN-CHARGES    PIC S9(9)V99 COMP-3.
       01 WS-APR-CALC.
           05 WS-AMOUNT-FINANCED      PIC S9(9)V99 COMP-3.
           05 WS-APR-ESTIMATE         PIC S9(2)V9(6) COMP-3.
           05 WS-APR-LOW              PIC S9(2)V9(6) COMP-3.
           05 WS-APR-HIGH             PIC S9(2)V9(6) COMP-3.
           05 WS-PV-PAYMENTS          PIC S9(11)V99 COMP-3.
           05 WS-ITERATION-CT         PIC 9(3).
           05 WS-MAX-ITERATIONS       PIC 9(3) VALUE 50.
           05 WS-CONVERGENCE          PIC S9(1)V9(8) COMP-3
               VALUE 0.00000100.
       01 WS-DISCLOSURE-FIELDS.
           05 WS-DISCLOSED-APR        PIC S9(2)V9(3) COMP-3.
           05 WS-TOTAL-OF-PAYMENTS    PIC S9(11)V99 COMP-3.
           05 WS-TOTAL-INT-COST       PIC S9(9)V99 COMP-3.
       01 WS-REG-Z-TOLERANCES.
           05 WS-REGULAR-TOL          PIC S9(1)V9(3) COMP-3
               VALUE 0.125.
           05 WS-IRREGULAR-TOL        PIC S9(1)V9(3) COMP-3
               VALUE 0.250.
           05 WS-ACTUAL-TOLERANCE     PIC S9(1)V9(3) COMP-3.
           05 WS-WITHIN-TOLERANCE     PIC X(1).
               88 WS-APR-OK           VALUE 'Y'.
               88 WS-APR-FAIL         VALUE 'N'.
       01 WS-ITER-FIELDS.
           05 WS-MONTHLY-RATE         PIC S9(1)V9(8) COMP-3.
           05 WS-DISCOUNT-FACTOR      PIC S9(3)V9(8) COMP-3.
           05 WS-POWER-FACTOR         PIC S9(3)V9(8) COMP-3.
           05 WS-PMT-IDX              PIC 9(3).
       01 WS-WORK-FIELDS.
           05 WS-TEMP-PV              PIC S9(11)V99 COMP-3.
           05 WS-DIFF                 PIC S9(9)V99 COMP-3.
           05 WS-MID-RATE             PIC S9(2)V9(6) COMP-3.
       01 WS-PROCESS-DATE             PIC 9(8).
       66 WS-PROC-YYYYMM
           RENAMES WS-PROCESS-DATE.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-FINANCE-CHARGES
           PERFORM 3000-CALC-AMOUNT-FINANCED
           PERFORM 4000-ITERATE-APR
           PERFORM 5000-CALC-DISCLOSURE
           PERFORM 6000-CHECK-TOLERANCE
           PERFORM 7000-DISPLAY-DISCLOSURE
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-PROCESS-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-TOTAL-FIN-CHARGES
           MOVE 0 TO WS-ITERATION-CT
           SET WS-APR-OK TO TRUE
           IF WS-FIXED
               MOVE WS-REGULAR-TOL TO WS-ACTUAL-TOLERANCE
           ELSE
               MOVE WS-IRREGULAR-TOL
                   TO WS-ACTUAL-TOLERANCE
           END-IF.
       2000-CALC-FINANCE-CHARGES.
           COMPUTE WS-TOTAL-FIN-CHARGES =
               WS-ORIGINATION-FEE +
               WS-DISCOUNT-POINTS +
               WS-BROKER-FEE +
               WS-PMI-UPFRONT +
               WS-PREPAID-INT.
       3000-CALC-AMOUNT-FINANCED.
           COMPUTE WS-AMOUNT-FINANCED =
               WS-LOAN-AMOUNT - WS-TOTAL-FIN-CHARGES
           IF WS-AMOUNT-FINANCED < 0
               MOVE 0 TO WS-AMOUNT-FINANCED
           END-IF.
       4000-ITERATE-APR.
           MOVE 0.0001 TO WS-APR-LOW
           MOVE 0.50 TO WS-APR-HIGH
           MOVE WS-NOTE-RATE TO WS-APR-ESTIMATE
           PERFORM UNTIL WS-ITERATION-CT >=
               WS-MAX-ITERATIONS
               ADD 1 TO WS-ITERATION-CT
               COMPUTE WS-MID-RATE =
                   (WS-APR-LOW + WS-APR-HIGH) / 2
               COMPUTE WS-MONTHLY-RATE =
                   WS-MID-RATE / 12
               MOVE 0 TO WS-PV-PAYMENTS
               PERFORM VARYING WS-PMT-IDX FROM 1 BY 1
                   UNTIL WS-PMT-IDX > WS-TERM-MONTHS
                   COMPUTE WS-DISCOUNT-FACTOR =
                       1 / (1 + WS-MONTHLY-RATE)
                   COMPUTE WS-POWER-FACTOR =
                       WS-DISCOUNT-FACTOR
                   ADD WS-PAYMENT-AMT TO WS-PV-PAYMENTS
               END-PERFORM
               COMPUTE WS-DIFF =
                   WS-PV-PAYMENTS - WS-AMOUNT-FINANCED
               IF WS-DIFF > 0
                   MOVE WS-MID-RATE TO WS-APR-LOW
               ELSE
                   MOVE WS-MID-RATE TO WS-APR-HIGH
               END-IF
               COMPUTE WS-TEMP-PV =
                   WS-APR-HIGH - WS-APR-LOW
               IF WS-TEMP-PV < WS-CONVERGENCE
                   MOVE WS-MAX-ITERATIONS
                       TO WS-ITERATION-CT
               END-IF
           END-PERFORM
           COMPUTE WS-APR-ESTIMATE =
               (WS-APR-LOW + WS-APR-HIGH) / 2.
       5000-CALC-DISCLOSURE.
           COMPUTE WS-DISCLOSED-APR =
               WS-APR-ESTIMATE * 100
           COMPUTE WS-TOTAL-OF-PAYMENTS =
               WS-PAYMENT-AMT * WS-TERM-MONTHS
           COMPUTE WS-TOTAL-INT-COST =
               WS-TOTAL-OF-PAYMENTS - WS-LOAN-AMOUNT.
       6000-CHECK-TOLERANCE.
           COMPUTE WS-DIFF =
               WS-DISCLOSED-APR - (WS-NOTE-RATE * 100)
           IF WS-DIFF < 0
               MULTIPLY WS-DIFF BY -1
                   GIVING WS-DIFF
           END-IF
           IF WS-DIFF <= WS-ACTUAL-TOLERANCE
               SET WS-APR-OK TO TRUE
           ELSE
               SET WS-APR-FAIL TO TRUE
           END-IF.
       7000-DISPLAY-DISCLOSURE.
           DISPLAY "TILA APR DISCLOSURE"
           DISPLAY "DATE: " WS-PROCESS-DATE
           DISPLAY "LOAN AMOUNT: " WS-LOAN-AMOUNT
           DISPLAY "NOTE RATE: " WS-NOTE-RATE
           DISPLAY "TERM: " WS-TERM-MONTHS " MONTHS"
           DISPLAY "FINANCE CHARGES: "
               WS-TOTAL-FIN-CHARGES
           DISPLAY "AMOUNT FINANCED: "
               WS-AMOUNT-FINANCED
           DISPLAY "APR: " WS-DISCLOSED-APR "%"
           DISPLAY "TOTAL OF PAYMENTS: "
               WS-TOTAL-OF-PAYMENTS
           DISPLAY "TOTAL INTEREST: " WS-TOTAL-INT-COST
           IF WS-APR-OK
               DISPLAY "REG Z: WITHIN TOLERANCE"
           ELSE
               DISPLAY "REG Z: EXCEEDS TOLERANCE"
           END-IF
           DISPLAY "ITERATIONS: " WS-ITERATION-CT.
