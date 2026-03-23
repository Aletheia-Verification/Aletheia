       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOAN-AMORT-CALC.
      *================================================================*
      * LOAN AMORTIZATION CALCULATOR                                   *
      * Computes monthly payment schedule for fixed-rate mortgages     *
      * with optional extra principal payments and PMI removal logic.  *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-LOAN-PARAMS.
           05 WS-PRINCIPAL          PIC S9(9)V99 COMP-3.
           05 WS-ANNUAL-RATE        PIC S9(2)V9(6) COMP-3.
           05 WS-TERM-MONTHS        PIC S9(3) COMP-3.
           05 WS-EXTRA-PAYMENT      PIC S9(7)V99 COMP-3.
           05 WS-ORIG-APPRAISED     PIC S9(9)V99 COMP-3.
       01 WS-CALC-FIELDS.
           05 WS-MONTHLY-RATE       PIC S9(1)V9(8) COMP-3.
           05 WS-MONTHLY-PMT        PIC S9(7)V99 COMP-3.
           05 WS-INTEREST-PORTION   PIC S9(7)V99 COMP-3.
           05 WS-PRINCIPAL-PORTION  PIC S9(7)V99 COMP-3.
           05 WS-REMAINING-BAL      PIC S9(9)V99 COMP-3.
           05 WS-CUM-INTEREST       PIC S9(11)V99 COMP-3.
           05 WS-CUM-PRINCIPAL      PIC S9(11)V99 COMP-3.
           05 WS-RATE-FACTOR        PIC S9(3)V9(8) COMP-3.
       01 WS-PMI-FIELDS.
           05 WS-LTV-RATIO          PIC S9(3)V99 COMP-3.
           05 WS-PMI-MONTHLY        PIC S9(5)V99 COMP-3.
           05 WS-PMI-TOTAL          PIC S9(7)V99 COMP-3.
           05 WS-PMI-ACTIVE         PIC X VALUE 'Y'.
               88 WS-PMI-ON         VALUE 'Y'.
               88 WS-PMI-OFF        VALUE 'N'.
       01 WS-SCHEDULE-TOTALS.
           05 WS-TOTAL-PAID         PIC S9(11)V99 COMP-3.
           05 WS-TOTAL-INTEREST     PIC S9(11)V99 COMP-3.
           05 WS-TOTAL-PMI-PAID     PIC S9(7)V99 COMP-3.
           05 WS-EFFECTIVE-RATE     PIC S9(2)V9(4) COMP-3.
           05 WS-MONTHS-SAVED       PIC S9(3) COMP-3.
       01 WS-COUNTERS.
           05 WS-MONTH-IDX          PIC S9(3) COMP-3.
           05 WS-YEAR-NUM           PIC S9(2) COMP-3.
           05 WS-MONTH-IN-YEAR      PIC S9(2) COMP-3.
           05 WS-ANNUAL-INT         PIC S9(9)V99 COMP-3.
       01 WS-STATUS-FLAG            PIC X VALUE 'Y'.
           88 WS-VALID              VALUE 'Y'.
           88 WS-INVALID            VALUE 'N'.
       01 WS-RESULT-MSG             PIC X(60).
       01 WS-TIER-DESC              PIC X(20).
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           IF WS-VALID
               PERFORM 2000-VALIDATE-INPUTS
           END-IF
           IF WS-VALID
               PERFORM 3000-CALC-MONTHLY-PMT
               PERFORM 4000-RUN-SCHEDULE
               PERFORM 5000-CALC-SUMMARY
           END-IF
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 350000.00 TO WS-PRINCIPAL
           MOVE 6.750000 TO WS-ANNUAL-RATE
           MOVE 360 TO WS-TERM-MONTHS
           MOVE 200.00 TO WS-EXTRA-PAYMENT
           MOVE 400000.00 TO WS-ORIG-APPRAISED
           MOVE 0 TO WS-CUM-INTEREST
           MOVE 0 TO WS-CUM-PRINCIPAL
           MOVE 0 TO WS-PMI-TOTAL
           MOVE 0 TO WS-TOTAL-PMI-PAID
           MOVE 0 TO WS-MONTHS-SAVED
           MOVE 0 TO WS-ANNUAL-INT
           MOVE SPACES TO WS-RESULT-MSG
           COMPUTE WS-LTV-RATIO =
               (WS-PRINCIPAL / WS-ORIG-APPRAISED) * 100.
       2000-VALIDATE-INPUTS.
           IF WS-PRINCIPAL < 1000
               MOVE 'N' TO WS-STATUS-FLAG
               MOVE 'PRINCIPAL BELOW MINIMUM' TO WS-RESULT-MSG
           END-IF
           IF WS-ANNUAL-RATE < 0.01
               MOVE 'N' TO WS-STATUS-FLAG
               MOVE 'RATE MUST BE POSITIVE' TO WS-RESULT-MSG
           END-IF
           IF WS-TERM-MONTHS < 12
               MOVE 'N' TO WS-STATUS-FLAG
               MOVE 'TERM MUST BE AT LEAST 12 MONTHS'
                   TO WS-RESULT-MSG
           END-IF
           IF WS-TERM-MONTHS > 480
               MOVE 'N' TO WS-STATUS-FLAG
               MOVE 'TERM EXCEEDS MAXIMUM 40 YEARS'
                   TO WS-RESULT-MSG
           END-IF.
       3000-CALC-MONTHLY-PMT.
           COMPUTE WS-MONTHLY-RATE =
               WS-ANNUAL-RATE / 1200
           COMPUTE WS-RATE-FACTOR =
               (1 + WS-MONTHLY-RATE) ** WS-TERM-MONTHS
           COMPUTE WS-MONTHLY-PMT ROUNDED =
               WS-PRINCIPAL *
               (WS-MONTHLY-RATE * WS-RATE-FACTOR) /
               (WS-RATE-FACTOR - 1)
           MOVE WS-PRINCIPAL TO WS-REMAINING-BAL
           IF WS-LTV-RATIO > 80
               COMPUTE WS-PMI-MONTHLY ROUNDED =
                   WS-PRINCIPAL * 0.005 / 12
           ELSE
               MOVE 0 TO WS-PMI-MONTHLY
               MOVE 'N' TO WS-PMI-ACTIVE
           END-IF.
       4000-RUN-SCHEDULE.
           PERFORM VARYING WS-MONTH-IDX FROM 1 BY 1
               UNTIL WS-MONTH-IDX > WS-TERM-MONTHS
               OR WS-REMAINING-BAL <= 0
               PERFORM 4100-CALC-MONTH
               PERFORM 4200-CHECK-PMI
               PERFORM 4300-ANNUAL-SUMMARY
           END-PERFORM
           COMPUTE WS-MONTHS-SAVED =
               WS-TERM-MONTHS - WS-MONTH-IDX + 1.
       4100-CALC-MONTH.
           COMPUTE WS-INTEREST-PORTION ROUNDED =
               WS-REMAINING-BAL * WS-MONTHLY-RATE
           COMPUTE WS-PRINCIPAL-PORTION =
               WS-MONTHLY-PMT - WS-INTEREST-PORTION
           ADD WS-EXTRA-PAYMENT TO WS-PRINCIPAL-PORTION
           IF WS-PRINCIPAL-PORTION > WS-REMAINING-BAL
               MOVE WS-REMAINING-BAL TO WS-PRINCIPAL-PORTION
           END-IF
           SUBTRACT WS-PRINCIPAL-PORTION FROM WS-REMAINING-BAL
           ADD WS-INTEREST-PORTION TO WS-CUM-INTEREST
           ADD WS-PRINCIPAL-PORTION TO WS-CUM-PRINCIPAL
           ADD WS-INTEREST-PORTION TO WS-ANNUAL-INT
           IF WS-PMI-ON
               ADD WS-PMI-MONTHLY TO WS-PMI-TOTAL
           END-IF.
       4200-CHECK-PMI.
           IF WS-PMI-ON
               COMPUTE WS-LTV-RATIO =
                   (WS-REMAINING-BAL / WS-ORIG-APPRAISED)
                   * 100
               IF WS-LTV-RATIO <= 78
                   MOVE 'N' TO WS-PMI-ACTIVE
                   MOVE WS-PMI-TOTAL TO WS-TOTAL-PMI-PAID
               END-IF
           END-IF.
       4300-ANNUAL-SUMMARY.
           COMPUTE WS-MONTH-IN-YEAR =
               FUNCTION MOD(WS-MONTH-IDX, 12)
           IF WS-MONTH-IN-YEAR = 0
               COMPUTE WS-YEAR-NUM =
                   WS-MONTH-IDX / 12
               DISPLAY 'YEAR ' WS-YEAR-NUM
                   ' INTEREST: ' WS-ANNUAL-INT
                   ' BALANCE: ' WS-REMAINING-BAL
               MOVE 0 TO WS-ANNUAL-INT
           END-IF.
       5000-CALC-SUMMARY.
           COMPUTE WS-TOTAL-PAID =
               WS-CUM-INTEREST + WS-CUM-PRINCIPAL +
               WS-PMI-TOTAL
           MOVE WS-CUM-INTEREST TO WS-TOTAL-INTEREST
           EVALUATE TRUE
               WHEN WS-ANNUAL-RATE < 4
                   MOVE 'LOW-RATE TIER' TO WS-TIER-DESC
               WHEN WS-ANNUAL-RATE < 6
                   MOVE 'MID-RATE TIER' TO WS-TIER-DESC
               WHEN WS-ANNUAL-RATE < 8
                   MOVE 'HIGH-RATE TIER' TO WS-TIER-DESC
               WHEN OTHER
                   MOVE 'PREMIUM-RATE TIER' TO WS-TIER-DESC
           END-EVALUATE
           IF WS-MONTHS-SAVED > 0
               COMPUTE WS-EFFECTIVE-RATE ROUNDED =
                   (WS-TOTAL-INTEREST / WS-PRINCIPAL) *
                   (12 / WS-MONTH-IDX) * 100
           END-IF.
       6000-DISPLAY-RESULTS.
           DISPLAY '========================================='
           DISPLAY 'LOAN AMORTIZATION SUMMARY'
           DISPLAY '========================================='
           IF WS-VALID
               DISPLAY 'ORIGINAL PRINCIPAL: ' WS-PRINCIPAL
               DISPLAY 'ANNUAL RATE:        ' WS-ANNUAL-RATE
               DISPLAY 'RATE TIER:          ' WS-TIER-DESC
               DISPLAY 'TERM MONTHS:        ' WS-TERM-MONTHS
               DISPLAY 'MONTHLY PAYMENT:    ' WS-MONTHLY-PMT
               DISPLAY 'EXTRA PAYMENT:      ' WS-EXTRA-PAYMENT
               DISPLAY 'TOTAL INTEREST:     ' WS-TOTAL-INTEREST
               DISPLAY 'TOTAL PMI PAID:     ' WS-TOTAL-PMI-PAID
               DISPLAY 'TOTAL COST:         ' WS-TOTAL-PAID
               DISPLAY 'MONTHS SAVED:       ' WS-MONTHS-SAVED
               DISPLAY 'REMAINING BALANCE:  ' WS-REMAINING-BAL
           ELSE
               DISPLAY 'ERROR: ' WS-RESULT-MSG
           END-IF
           DISPLAY '========================================='.
