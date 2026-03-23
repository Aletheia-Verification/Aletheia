       IDENTIFICATION DIVISION.
       PROGRAM-ID. MTG-AMORT-SCHED.
      *================================================================*
      * Mortgage Amortization Schedule Generator                        *
      * Builds full P&I schedule for fixed-rate mortgages with          *
      * extra payment handling, early payoff detection, and             *
      * interest/principal split reporting.                             *
      *================================================================*
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-LOAN-PARAMS.
           05  LP-ORIGINAL-BAL      PIC 9(09)V99
                                    VALUE 350000.00.
           05  LP-ANNUAL-RATE       PIC 9V9(06) VALUE 0.065000.
           05  LP-TERM-MONTHS       PIC 9(03) VALUE 360.
           05  LP-EXTRA-PMT         PIC 9(07)V99 VALUE 200.00.
           05  LP-START-DATE        PIC 9(08) VALUE 20250101.
       01  WS-MONTHLY-RATE         PIC 9V9(10).
       01  WS-PAYMENT              PIC S9(07)V99.
       01  WS-BALANCE              PIC S9(09)V99.
       01  WS-INT-PORTION          PIC S9(07)V99.
       01  WS-PRIN-PORTION         PIC S9(07)V99.
       01  WS-MONTH-IDX            PIC 9(03).
       01  WS-TOTAL-INTEREST       PIC S9(11)V99 VALUE 0.
       01  WS-TOTAL-PRINCIPAL      PIC S9(11)V99 VALUE 0.
       01  WS-TOTAL-EXTRA          PIC S9(09)V99 VALUE 0.
       01  WS-ACTUAL-TERM          PIC 9(03) VALUE 0.
       01  WS-YEAR-INT             PIC S9(09)V99 VALUE 0.
       01  WS-YEAR-PRIN            PIC S9(09)V99 VALUE 0.
       01  WS-CURRENT-YEAR         PIC 9(04).
       01  WS-PMT-YEAR             PIC 9(04).
       01  WS-PMT-MONTH            PIC 9(02).
       01  WS-RATE-FACTOR          PIC 9V9(10).
       01  WS-DENOM                PIC 9(05)V9(10).
       01  WS-EARLY-PAYOFF         PIC X VALUE 'N'.
           88  PAID-OFF             VALUE 'Y'.
       01  WS-FINAL-PMT            PIC S9(07)V99.
       01  WS-SAVINGS              PIC S9(11)V99.
       01  WS-ORIG-TOTAL-INT       PIC S9(11)V99.
       01  WS-DISPLAY-LINE         PIC X(80) VALUE SPACES.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-PAYMENT
           PERFORM 3000-GENERATE-SCHEDULE
           PERFORM 8000-CALC-SAVINGS
           PERFORM 9000-REPORT
           STOP RUN.
       1000-INITIALIZE.
           COMPUTE WS-MONTHLY-RATE =
               LP-ANNUAL-RATE / 12
           MOVE LP-ORIGINAL-BAL TO WS-BALANCE
           COMPUTE WS-PMT-YEAR =
               LP-START-DATE / 10000
           MOVE WS-PMT-YEAR TO WS-CURRENT-YEAR.
       2000-CALC-PAYMENT.
           COMPUTE WS-RATE-FACTOR ROUNDED =
               1 + WS-MONTHLY-RATE
           MOVE 1 TO WS-DENOM
           PERFORM VARYING WS-MONTH-IDX FROM 1 BY 1
               UNTIL WS-MONTH-IDX > LP-TERM-MONTHS
               COMPUTE WS-DENOM ROUNDED =
                   WS-DENOM * WS-RATE-FACTOR
           END-PERFORM
           COMPUTE WS-PAYMENT ROUNDED =
               LP-ORIGINAL-BAL * WS-MONTHLY-RATE *
               WS-DENOM /
               (WS-DENOM - 1).
       3000-GENERATE-SCHEDULE.
           PERFORM VARYING WS-MONTH-IDX FROM 1 BY 1
               UNTIL WS-MONTH-IDX > LP-TERM-MONTHS
               OR PAID-OFF
               PERFORM 3100-CALC-MONTH
               PERFORM 3200-APPLY-EXTRA
               PERFORM 3300-CHECK-PAYOFF
               PERFORM 3400-YEAR-BOUNDARY
               ADD 1 TO WS-ACTUAL-TERM
           END-PERFORM.
       3100-CALC-MONTH.
           COMPUTE WS-INT-PORTION ROUNDED =
               WS-BALANCE * WS-MONTHLY-RATE
           COMPUTE WS-PRIN-PORTION =
               WS-PAYMENT - WS-INT-PORTION
           IF WS-PRIN-PORTION > WS-BALANCE
               MOVE WS-BALANCE TO WS-PRIN-PORTION
               COMPUTE WS-FINAL-PMT =
                   WS-BALANCE + WS-INT-PORTION
           END-IF
           SUBTRACT WS-PRIN-PORTION FROM WS-BALANCE
           ADD WS-INT-PORTION TO WS-TOTAL-INTEREST
           ADD WS-INT-PORTION TO WS-YEAR-INT
           ADD WS-PRIN-PORTION TO WS-TOTAL-PRINCIPAL
           ADD WS-PRIN-PORTION TO WS-YEAR-PRIN.
       3200-APPLY-EXTRA.
           IF LP-EXTRA-PMT > ZERO AND WS-BALANCE > ZERO
               IF LP-EXTRA-PMT >= WS-BALANCE
                   ADD WS-BALANCE TO WS-TOTAL-EXTRA
                   ADD WS-BALANCE TO WS-TOTAL-PRINCIPAL
                   MOVE ZERO TO WS-BALANCE
               ELSE
                   SUBTRACT LP-EXTRA-PMT FROM WS-BALANCE
                   ADD LP-EXTRA-PMT TO WS-TOTAL-EXTRA
                   ADD LP-EXTRA-PMT TO WS-TOTAL-PRINCIPAL
               END-IF
           END-IF.
       3300-CHECK-PAYOFF.
           IF WS-BALANCE <= ZERO
               MOVE 'Y' TO WS-EARLY-PAYOFF
               DISPLAY 'EARLY PAYOFF AT MONTH '
                   WS-MONTH-IDX
           END-IF.
       3400-YEAR-BOUNDARY.
           COMPUTE WS-PMT-MONTH =
               FUNCTION MOD(WS-MONTH-IDX, 12)
           IF WS-PMT-MONTH = 0
               DISPLAY 'YEAR ' WS-CURRENT-YEAR
                   ' INT=' WS-YEAR-INT
                   ' PRIN=' WS-YEAR-PRIN
               MOVE ZERO TO WS-YEAR-INT
               MOVE ZERO TO WS-YEAR-PRIN
               ADD 1 TO WS-CURRENT-YEAR
           END-IF.
       8000-CALC-SAVINGS.
           COMPUTE WS-ORIG-TOTAL-INT =
               (WS-PAYMENT * LP-TERM-MONTHS) -
               LP-ORIGINAL-BAL
           COMPUTE WS-SAVINGS =
               WS-ORIG-TOTAL-INT - WS-TOTAL-INTEREST.
       9000-REPORT.
           DISPLAY 'AMORTIZATION SCHEDULE COMPLETE'
           DISPLAY 'ORIGINAL BAL:  ' LP-ORIGINAL-BAL
           DISPLAY 'MONTHLY PMT:   ' WS-PAYMENT
           DISPLAY 'ACTUAL TERM:   ' WS-ACTUAL-TERM
               ' MONTHS'
           DISPLAY 'TOTAL INTEREST:' WS-TOTAL-INTEREST
           DISPLAY 'TOTAL PRINCIP: ' WS-TOTAL-PRINCIPAL
           DISPLAY 'TOTAL EXTRA:   ' WS-TOTAL-EXTRA
           IF PAID-OFF
               DISPLAY 'INTEREST SAVED:' WS-SAVINGS
               DISPLAY 'MONTHS SAVED:  '
               COMPUTE WS-MONTH-IDX =
                   LP-TERM-MONTHS - WS-ACTUAL-TERM
               DISPLAY WS-MONTH-IDX
           END-IF.
