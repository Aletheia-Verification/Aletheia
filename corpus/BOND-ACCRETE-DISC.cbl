       IDENTIFICATION DIVISION.
       PROGRAM-ID. BOND-ACCRETE-DISC.
      *================================================================
      * BOND DISCOUNT ACCRETION ENGINE
      * Computes constant yield method accretion for bonds purchased
      * at a discount, generating periodic income adjustments.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-BOND.
           05 WS-CUSIP                PIC X(9).
           05 WS-FACE-VALUE           PIC S9(9)V99 COMP-3.
           05 WS-PURCHASE-PRICE       PIC S9(9)V99 COMP-3.
           05 WS-COUPON-RATE          PIC S9(1)V9(6) COMP-3.
           05 WS-YTM                  PIC S9(1)V9(6) COMP-3.
           05 WS-PURCHASE-DATE        PIC 9(8).
           05 WS-MATURITY-DATE        PIC 9(8).
           05 WS-SEMI-PERIODS         PIC 9(3).
       01 WS-ACCRETION-TABLE.
           05 WS-ACC-ENTRY OCCURS 20 TIMES.
               10 WS-AE-PERIOD        PIC 9(3).
               10 WS-AE-BEG-BASIS     PIC S9(9)V99 COMP-3.
               10 WS-AE-COUPON-INC    PIC S9(7)V99 COMP-3.
               10 WS-AE-YTM-INCOME    PIC S9(7)V99 COMP-3.
               10 WS-AE-ACCRETION     PIC S9(7)V99 COMP-3.
               10 WS-AE-END-BASIS     PIC S9(9)V99 COMP-3.
       01 WS-IDX                      PIC 9(3).
       01 WS-CALC.
           05 WS-DISCOUNT-AMT         PIC S9(9)V99 COMP-3.
           05 WS-IS-DISCOUNT          PIC X VALUE 'N'.
               88 BOND-IS-DISCOUNT    VALUE 'Y'.
           05 WS-SEMI-COUPON          PIC S9(7)V99 COMP-3.
           05 WS-SEMI-YTM             PIC S9(1)V9(6) COMP-3.
           05 WS-CURRENT-BASIS        PIC S9(9)V99 COMP-3.
           05 WS-YTM-INCOME           PIC S9(7)V99 COMP-3.
           05 WS-PERIOD-ACCRETION     PIC S9(7)V99 COMP-3.
       01 WS-TOTALS.
           05 WS-TOT-COUPON-INC       PIC S9(9)V99 COMP-3
               VALUE 0.
           05 WS-TOT-YTM-INC          PIC S9(9)V99 COMP-3
               VALUE 0.
           05 WS-TOT-ACCRETION        PIC S9(9)V99 COMP-3
               VALUE 0.
       01 WS-PERIODS-TO-GEN           PIC 9(3).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-VALIDATE-DISCOUNT
           IF BOND-IS-DISCOUNT
               PERFORM 3000-CALC-SEMI-RATES
               PERFORM 4000-GENERATE-SCHEDULE
               PERFORM 5000-TALLY-TOTALS
           END-IF
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE '912828ZT9' TO WS-CUSIP
           MOVE 100000.00 TO WS-FACE-VALUE
           MOVE 95000.00 TO WS-PURCHASE-PRICE
           MOVE 0.040000 TO WS-COUPON-RATE
           MOVE 0.050000 TO WS-YTM
           MOVE 20240601 TO WS-PURCHASE-DATE
           MOVE 20340601 TO WS-MATURITY-DATE
           MOVE 20 TO WS-SEMI-PERIODS.
       2000-VALIDATE-DISCOUNT.
           COMPUTE WS-DISCOUNT-AMT =
               WS-FACE-VALUE - WS-PURCHASE-PRICE
           IF WS-DISCOUNT-AMT > 0
               MOVE 'Y' TO WS-IS-DISCOUNT
           ELSE
               MOVE 'N' TO WS-IS-DISCOUNT
           END-IF.
       3000-CALC-SEMI-RATES.
           COMPUTE WS-SEMI-COUPON =
               (WS-FACE-VALUE * WS-COUPON-RATE) / 2
           COMPUTE WS-SEMI-YTM =
               WS-YTM / 2
           MOVE WS-PURCHASE-PRICE TO WS-CURRENT-BASIS.
       4000-GENERATE-SCHEDULE.
           IF WS-SEMI-PERIODS > 20
               MOVE 20 TO WS-PERIODS-TO-GEN
           ELSE
               MOVE WS-SEMI-PERIODS TO WS-PERIODS-TO-GEN
           END-IF
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-PERIODS-TO-GEN
               MOVE WS-IDX TO WS-AE-PERIOD(WS-IDX)
               MOVE WS-CURRENT-BASIS
                   TO WS-AE-BEG-BASIS(WS-IDX)
               MOVE WS-SEMI-COUPON
                   TO WS-AE-COUPON-INC(WS-IDX)
               COMPUTE WS-YTM-INCOME =
                   WS-CURRENT-BASIS * WS-SEMI-YTM
               MOVE WS-YTM-INCOME
                   TO WS-AE-YTM-INCOME(WS-IDX)
               COMPUTE WS-PERIOD-ACCRETION =
                   WS-YTM-INCOME - WS-SEMI-COUPON
               IF WS-PERIOD-ACCRETION < 0
                   MOVE 0 TO WS-PERIOD-ACCRETION
               END-IF
               MOVE WS-PERIOD-ACCRETION
                   TO WS-AE-ACCRETION(WS-IDX)
               COMPUTE WS-CURRENT-BASIS =
                   WS-CURRENT-BASIS + WS-PERIOD-ACCRETION
               IF WS-CURRENT-BASIS > WS-FACE-VALUE
                   MOVE WS-FACE-VALUE TO WS-CURRENT-BASIS
               END-IF
               MOVE WS-CURRENT-BASIS
                   TO WS-AE-END-BASIS(WS-IDX)
           END-PERFORM.
       5000-TALLY-TOTALS.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-PERIODS-TO-GEN
               ADD WS-AE-COUPON-INC(WS-IDX)
                   TO WS-TOT-COUPON-INC
               ADD WS-AE-YTM-INCOME(WS-IDX)
                   TO WS-TOT-YTM-INC
               ADD WS-AE-ACCRETION(WS-IDX)
                   TO WS-TOT-ACCRETION
           END-PERFORM.
       6000-DISPLAY-RESULTS.
           DISPLAY 'BOND DISCOUNT ACCRETION REPORT'
           DISPLAY '=============================='
           DISPLAY 'CUSIP:           ' WS-CUSIP
           DISPLAY 'FACE VALUE:      ' WS-FACE-VALUE
           DISPLAY 'PURCHASE PRICE:  ' WS-PURCHASE-PRICE
           IF BOND-IS-DISCOUNT
               DISPLAY 'DISCOUNT:        ' WS-DISCOUNT-AMT
               DISPLAY 'COUPON RATE:     ' WS-COUPON-RATE
               DISPLAY 'YTM:             ' WS-YTM
               DISPLAY 'PERIODS:         ' WS-SEMI-PERIODS
               DISPLAY '------------------------------'
               PERFORM VARYING WS-IDX FROM 1 BY 1
                   UNTIL WS-IDX > WS-PERIODS-TO-GEN
                   DISPLAY 'PD ' WS-AE-PERIOD(WS-IDX)
                       ' BEG: ' WS-AE-BEG-BASIS(WS-IDX)
                       ' ACC: ' WS-AE-ACCRETION(WS-IDX)
                       ' END: ' WS-AE-END-BASIS(WS-IDX)
               END-PERFORM
               DISPLAY '------------------------------'
               DISPLAY 'TOTAL COUPON:    '
                   WS-TOT-COUPON-INC
               DISPLAY 'TOTAL YTM INC:   ' WS-TOT-YTM-INC
               DISPLAY 'TOTAL ACCRETION: '
                   WS-TOT-ACCRETION
           ELSE
               DISPLAY 'NOT A DISCOUNT BOND'
           END-IF.
