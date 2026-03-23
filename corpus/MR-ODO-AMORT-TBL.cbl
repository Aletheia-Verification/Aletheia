       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-ODO-AMORT-TBL.
      *================================================================*
      * MANUAL REVIEW: Amortization Table with OCCURS DEPENDING ON     *
      * Uses ODO for variable-length amortization schedule storage —   *
      * triggers MANUAL REVIEW detection.                               *
      *================================================================*
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-LOAN-PARAMS.
           05  LP-PRINCIPAL         PIC 9(09)V99
                                    VALUE 250000.00.
           05  LP-ANNUAL-RATE       PIC 9V9(06)
                                    VALUE 0.058500.
           05  LP-TERM-MONTHS       PIC 9(03) VALUE 360.
           05  LP-EXTRA-PMT         PIC 9(05)V99 VALUE 0.
       01  WS-ACTUAL-PERIODS       PIC 9(03).
       01  WS-AMORT-TABLE.
           05  WS-AMORT-ENTRY     OCCURS 1 TO 360 TIMES
                                  DEPENDING ON WS-ACTUAL-PERIODS.
               10  AE-PERIOD-NUM  PIC 9(03).
               10  AE-PAYMENT     PIC S9(07)V99.
               10  AE-INTEREST    PIC S9(07)V99.
               10  AE-PRINCIPAL   PIC S9(07)V99.
               10  AE-BALANCE     PIC S9(09)V99.
               10  AE-CUM-INT     PIC S9(09)V99.
       01  WS-MONTHLY-RATE        PIC 9V9(10).
       01  WS-PAYMENT             PIC S9(07)V99.
       01  WS-BALANCE             PIC S9(09)V99.
       01  WS-INT-PORTION         PIC S9(07)V99.
       01  WS-PRIN-PORTION        PIC S9(07)V99.
       01  WS-CUM-INTEREST        PIC S9(09)V99 VALUE 0.
       01  WS-IDX                 PIC 9(03).
       01  WS-RATE-FACTOR         PIC 9(05)V9(10).
       01  WS-DENOM               PIC 9(05)V9(10).
       01  WS-YEAR-TOTAL-INT      PIC S9(09)V99 VALUE 0.
       01  WS-YEAR-TOTAL-PRIN     PIC S9(09)V99 VALUE 0.
       01  WS-MOD-RESULT          PIC 9(02).
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-PAYMENT
           PERFORM 3000-BUILD-SCHEDULE
           PERFORM 4000-DISPLAY-SUMMARY
           STOP RUN.
       1000-INITIALIZE.
           COMPUTE WS-MONTHLY-RATE =
               LP-ANNUAL-RATE / 12
           MOVE LP-PRINCIPAL TO WS-BALANCE
           MOVE LP-TERM-MONTHS TO WS-ACTUAL-PERIODS.
       2000-CALC-PAYMENT.
           COMPUTE WS-RATE-FACTOR =
               1 + WS-MONTHLY-RATE
           MOVE 1 TO WS-DENOM
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > LP-TERM-MONTHS
               COMPUTE WS-DENOM ROUNDED =
                   WS-DENOM * WS-RATE-FACTOR
           END-PERFORM
           COMPUTE WS-PAYMENT ROUNDED =
               LP-PRINCIPAL * WS-MONTHLY-RATE *
               WS-DENOM / (WS-DENOM - 1).
       3000-BUILD-SCHEDULE.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-ACTUAL-PERIODS
               OR WS-BALANCE <= 0
               COMPUTE WS-INT-PORTION ROUNDED =
                   WS-BALANCE * WS-MONTHLY-RATE
               COMPUTE WS-PRIN-PORTION =
                   WS-PAYMENT - WS-INT-PORTION
               IF WS-PRIN-PORTION > WS-BALANCE
                   MOVE WS-BALANCE TO WS-PRIN-PORTION
               END-IF
               SUBTRACT WS-PRIN-PORTION FROM WS-BALANCE
               ADD WS-INT-PORTION TO WS-CUM-INTEREST
               MOVE WS-IDX TO AE-PERIOD-NUM(WS-IDX)
               MOVE WS-PAYMENT TO AE-PAYMENT(WS-IDX)
               MOVE WS-INT-PORTION TO AE-INTEREST(WS-IDX)
               MOVE WS-PRIN-PORTION TO
                   AE-PRINCIPAL(WS-IDX)
               MOVE WS-BALANCE TO AE-BALANCE(WS-IDX)
               MOVE WS-CUM-INTEREST TO
                   AE-CUM-INT(WS-IDX)
               ADD WS-INT-PORTION TO WS-YEAR-TOTAL-INT
               ADD WS-PRIN-PORTION TO WS-YEAR-TOTAL-PRIN
               COMPUTE WS-MOD-RESULT =
                   FUNCTION MOD(WS-IDX, 12)
               IF WS-MOD-RESULT = 0
                   DISPLAY 'YEAR '
                       ' INT=' WS-YEAR-TOTAL-INT
                       ' PRIN=' WS-YEAR-TOTAL-PRIN
                   MOVE ZERO TO WS-YEAR-TOTAL-INT
                   MOVE ZERO TO WS-YEAR-TOTAL-PRIN
               END-IF
           END-PERFORM
           IF WS-BALANCE <= 0
               COMPUTE WS-ACTUAL-PERIODS = WS-IDX - 1
           END-IF.
       4000-DISPLAY-SUMMARY.
           DISPLAY 'AMORTIZATION SCHEDULE COMPLETE'
           DISPLAY 'PRINCIPAL:     ' LP-PRINCIPAL
           DISPLAY 'RATE:          ' LP-ANNUAL-RATE
           DISPLAY 'PAYMENT:       ' WS-PAYMENT
           DISPLAY 'PERIODS:       ' WS-ACTUAL-PERIODS
           DISPLAY 'TOTAL INTEREST:' WS-CUM-INTEREST
           IF WS-ACTUAL-PERIODS > 0
               DISPLAY 'FIRST PERIOD INT: '
                   AE-INTEREST(1)
               DISPLAY 'LAST PERIOD BAL:  '
                   AE-BALANCE(WS-ACTUAL-PERIODS)
           END-IF.
