       IDENTIFICATION DIVISION.
       PROGRAM-ID. ANNUITY-PAYOUT-CALC.
      *================================================================
      * ANNUITY PAYOUT CALCULATOR
      * Computes periodic payouts for fixed, variable, and indexed
      * annuities using mortality tables and guaranteed minimums.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CONTRACT.
           05 WS-CONTRACT-ID          PIC X(12).
           05 WS-ANNUITY-TYPE         PIC X(1).
               88 ANN-FIXED           VALUE 'F'.
               88 ANN-VARIABLE        VALUE 'V'.
               88 ANN-INDEXED         VALUE 'I'.
           05 WS-PAYOUT-MODE          PIC X(1).
               88 PAY-MONTHLY         VALUE 'M'.
               88 PAY-QUARTERLY       VALUE 'Q'.
               88 PAY-ANNUAL          VALUE 'A'.
           05 WS-ACCOUNT-VALUE        PIC S9(11)V99 COMP-3.
           05 WS-GUAR-RATE            PIC S9(1)V9(4) COMP-3.
           05 WS-ANNUITANT-AGE        PIC 9(3).
           05 WS-JOINT-AGE            PIC 9(3).
           05 WS-JOINT-FLAG           PIC X(1).
               88 IS-JOINT            VALUE 'Y'.
               88 IS-SINGLE           VALUE 'N'.
       01 WS-MORTALITY-TABLE.
           05 WS-MORT-FACTOR OCCURS 10 TIMES
                                       PIC S9(3)V9(4) COMP-3.
       01 WS-CALC-FIELDS.
           05 WS-LIFE-EXPECT          PIC S9(3)V99 COMP-3.
           05 WS-JOINT-EXPECT         PIC S9(3)V99 COMP-3.
           05 WS-PAYOUT-PERIODS       PIC S9(5) COMP-3.
           05 WS-PERIODS-PER-YEAR     PIC 9(2).
           05 WS-PERIOD-RATE          PIC S9(1)V9(6) COMP-3.
           05 WS-ANNUITY-FACTOR       PIC S9(5)V9(6) COMP-3.
           05 WS-PV-SUM               PIC S9(11)V9(4) COMP-3.
           05 WS-DISCOUNT-FACTOR      PIC S9(3)V9(8) COMP-3.
           05 WS-RAW-PAYOUT           PIC S9(9)V99 COMP-3.
           05 WS-GUAR-MINIMUM         PIC S9(9)V99 COMP-3.
           05 WS-FINAL-PAYOUT         PIC S9(9)V99 COMP-3.
           05 WS-ANNUAL-PAYOUT        PIC S9(9)V99 COMP-3.
       01 WS-ADMIN-FEE-PCT            PIC S9(1)V9(4) COMP-3
           VALUE 0.0025.
       01 WS-ADMIN-FEE-AMT            PIC S9(7)V99 COMP-3.
       01 WS-NET-PAYOUT               PIC S9(9)V99 COMP-3.
       01 WS-IDX                       PIC 9(5).
       01 WS-AGE-BRACKET              PIC 9(2).
       01 WS-MORT-IDX                 PIC 9(2).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-DETERMINE-LIFE-EXPECT
           PERFORM 3000-CALC-PAYOUT-PERIODS
           PERFORM 4000-CALC-ANNUITY-FACTOR
           PERFORM 5000-CALC-RAW-PAYOUT
           PERFORM 6000-APPLY-GUARANTEE
           PERFORM 7000-DEDUCT-FEES
           PERFORM 8000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           INITIALIZE WS-CALC-FIELDS
           MOVE 25.5000 TO WS-MORT-FACTOR(1)
           MOVE 23.2000 TO WS-MORT-FACTOR(2)
           MOVE 20.8000 TO WS-MORT-FACTOR(3)
           MOVE 18.5000 TO WS-MORT-FACTOR(4)
           MOVE 16.2000 TO WS-MORT-FACTOR(5)
           MOVE 13.8000 TO WS-MORT-FACTOR(6)
           MOVE 11.5000 TO WS-MORT-FACTOR(7)
           MOVE 9.2000 TO WS-MORT-FACTOR(8)
           MOVE 7.0000 TO WS-MORT-FACTOR(9)
           MOVE 5.0000 TO WS-MORT-FACTOR(10).
       2000-DETERMINE-LIFE-EXPECT.
           IF WS-ANNUITANT-AGE < 55
               MOVE 1 TO WS-MORT-IDX
           ELSE
               IF WS-ANNUITANT-AGE < 60
                   MOVE 2 TO WS-MORT-IDX
               ELSE
                   IF WS-ANNUITANT-AGE < 65
                       MOVE 3 TO WS-MORT-IDX
                   ELSE
                       IF WS-ANNUITANT-AGE < 70
                           MOVE 4 TO WS-MORT-IDX
                       ELSE
                           IF WS-ANNUITANT-AGE < 75
                               MOVE 5 TO WS-MORT-IDX
                           ELSE
                               IF WS-ANNUITANT-AGE < 80
                                   MOVE 6 TO WS-MORT-IDX
                               ELSE
                                   MOVE 7 TO WS-MORT-IDX
                               END-IF
                           END-IF
                       END-IF
                   END-IF
               END-IF
           END-IF
           MOVE WS-MORT-FACTOR(WS-MORT-IDX)
               TO WS-LIFE-EXPECT
           IF IS-JOINT
               ADD 3.50 TO WS-LIFE-EXPECT
                   GIVING WS-JOINT-EXPECT
               MOVE WS-JOINT-EXPECT TO WS-LIFE-EXPECT
           END-IF.
       3000-CALC-PAYOUT-PERIODS.
           EVALUATE TRUE
               WHEN PAY-MONTHLY
                   MOVE 12 TO WS-PERIODS-PER-YEAR
               WHEN PAY-QUARTERLY
                   MOVE 4 TO WS-PERIODS-PER-YEAR
               WHEN PAY-ANNUAL
                   MOVE 1 TO WS-PERIODS-PER-YEAR
               WHEN OTHER
                   MOVE 12 TO WS-PERIODS-PER-YEAR
           END-EVALUATE
           COMPUTE WS-PAYOUT-PERIODS =
               WS-LIFE-EXPECT * WS-PERIODS-PER-YEAR
           COMPUTE WS-PERIOD-RATE =
               WS-GUAR-RATE / WS-PERIODS-PER-YEAR.
       4000-CALC-ANNUITY-FACTOR.
           MOVE 0 TO WS-PV-SUM
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-PAYOUT-PERIODS
               COMPUTE WS-DISCOUNT-FACTOR =
                   1 / ((1 + WS-PERIOD-RATE) ** WS-IDX)
               ADD WS-DISCOUNT-FACTOR TO WS-PV-SUM
           END-PERFORM
           MOVE WS-PV-SUM TO WS-ANNUITY-FACTOR.
       5000-CALC-RAW-PAYOUT.
           IF WS-ANNUITY-FACTOR > 0
               COMPUTE WS-RAW-PAYOUT =
                   WS-ACCOUNT-VALUE / WS-ANNUITY-FACTOR
           ELSE
               MOVE 0 TO WS-RAW-PAYOUT
           END-IF.
       6000-APPLY-GUARANTEE.
           COMPUTE WS-GUAR-MINIMUM =
               WS-ACCOUNT-VALUE / WS-PAYOUT-PERIODS
           IF WS-RAW-PAYOUT < WS-GUAR-MINIMUM
               MOVE WS-GUAR-MINIMUM TO WS-FINAL-PAYOUT
           ELSE
               MOVE WS-RAW-PAYOUT TO WS-FINAL-PAYOUT
           END-IF.
       7000-DEDUCT-FEES.
           COMPUTE WS-ADMIN-FEE-AMT =
               WS-FINAL-PAYOUT * WS-ADMIN-FEE-PCT
           COMPUTE WS-NET-PAYOUT =
               WS-FINAL-PAYOUT - WS-ADMIN-FEE-AMT
           COMPUTE WS-ANNUAL-PAYOUT =
               WS-NET-PAYOUT * WS-PERIODS-PER-YEAR.
       8000-DISPLAY-RESULTS.
           DISPLAY 'ANNUITY PAYOUT CALCULATION'
           DISPLAY '=========================='
           DISPLAY 'CONTRACT:       ' WS-CONTRACT-ID
           DISPLAY 'TYPE:           ' WS-ANNUITY-TYPE
           DISPLAY 'ACCOUNT VALUE:  ' WS-ACCOUNT-VALUE
           DISPLAY 'LIFE EXPECT:    ' WS-LIFE-EXPECT
           DISPLAY 'TOTAL PERIODS:  ' WS-PAYOUT-PERIODS
           DISPLAY 'ANNUITY FACTOR: ' WS-ANNUITY-FACTOR
           DISPLAY 'RAW PAYOUT:     ' WS-RAW-PAYOUT
           DISPLAY 'GUAR MINIMUM:   ' WS-GUAR-MINIMUM
           DISPLAY 'ADMIN FEE:      ' WS-ADMIN-FEE-AMT
           DISPLAY 'NET PAYOUT:     ' WS-NET-PAYOUT
           DISPLAY 'ANNUAL TOTAL:   ' WS-ANNUAL-PAYOUT
           IF IS-JOINT
               DISPLAY 'JOINT LIFE: YES'
           END-IF.
