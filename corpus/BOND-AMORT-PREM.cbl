       IDENTIFICATION DIVISION.
       PROGRAM-ID. BOND-AMORT-PREM.
      *================================================================
      * BOND PREMIUM AMORTIZATION ENGINE
      * Computes constant yield method amortization for bonds
      * purchased at a premium above par value.
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
           05 WS-TOTAL-PERIODS        PIC 9(3).
       01 WS-AMORT-SCHEDULE.
           05 WS-AM-ENTRY OCCURS 16 TIMES.
               10 WS-AM-PERIOD        PIC 9(3).
               10 WS-AM-BEG-BASIS     PIC S9(9)V99 COMP-3.
               10 WS-AM-COUPON-REC    PIC S9(7)V99 COMP-3.
               10 WS-AM-YTM-INCOME    PIC S9(7)V99 COMP-3.
               10 WS-AM-AMORT-AMT     PIC S9(7)V99 COMP-3.
               10 WS-AM-END-BASIS     PIC S9(9)V99 COMP-3.
       01 WS-IDX                      PIC 9(3).
       01 WS-CALC.
           05 WS-PREMIUM-AMT          PIC S9(9)V99 COMP-3.
           05 WS-IS-PREMIUM           PIC X VALUE 'N'.
               88 BOND-IS-PREMIUM     VALUE 'Y'.
           05 WS-SEMI-COUPON          PIC S9(7)V99 COMP-3.
           05 WS-SEMI-YTM             PIC S9(1)V9(6) COMP-3.
           05 WS-CURRENT-BASIS        PIC S9(9)V99 COMP-3.
           05 WS-PERIOD-YTM-INC       PIC S9(7)V99 COMP-3.
           05 WS-PERIOD-AMORT         PIC S9(7)V99 COMP-3.
       01 WS-TOTALS.
           05 WS-TOT-COUPON           PIC S9(9)V99 COMP-3
               VALUE 0.
           05 WS-TOT-YTM-INC          PIC S9(9)V99 COMP-3
               VALUE 0.
           05 WS-TOT-AMORT            PIC S9(9)V99 COMP-3
               VALUE 0.
       01 WS-GEN-PERIODS              PIC 9(3).
       01 WS-TAX-IMPACT.
           05 WS-ANNUAL-AMORT         PIC S9(7)V99 COMP-3.
           05 WS-TAX-RATE             PIC S9(1)V99 COMP-3
               VALUE 0.37.
           05 WS-TAX-SAVINGS          PIC S9(7)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-VALIDATE-PREMIUM
           IF BOND-IS-PREMIUM
               PERFORM 3000-CALC-SEMI-RATES
               PERFORM 4000-BUILD-SCHEDULE
               PERFORM 5000-CALC-TOTALS
               PERFORM 6000-CALC-TAX-IMPACT
           END-IF
           PERFORM 7000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE '459200HG7' TO WS-CUSIP
           MOVE 100000.00 TO WS-FACE-VALUE
           MOVE 108500.00 TO WS-PURCHASE-PRICE
           MOVE 0.060000 TO WS-COUPON-RATE
           MOVE 0.045000 TO WS-YTM
           MOVE 20240301 TO WS-PURCHASE-DATE
           MOVE 20320301 TO WS-MATURITY-DATE
           MOVE 16 TO WS-TOTAL-PERIODS.
       2000-VALIDATE-PREMIUM.
           COMPUTE WS-PREMIUM-AMT =
               WS-PURCHASE-PRICE - WS-FACE-VALUE
           IF WS-PREMIUM-AMT > 0
               MOVE 'Y' TO WS-IS-PREMIUM
           ELSE
               MOVE 'N' TO WS-IS-PREMIUM
           END-IF.
       3000-CALC-SEMI-RATES.
           COMPUTE WS-SEMI-COUPON =
               (WS-FACE-VALUE * WS-COUPON-RATE) / 2
           COMPUTE WS-SEMI-YTM =
               WS-YTM / 2
           MOVE WS-PURCHASE-PRICE TO WS-CURRENT-BASIS.
       4000-BUILD-SCHEDULE.
           IF WS-TOTAL-PERIODS > 16
               MOVE 16 TO WS-GEN-PERIODS
           ELSE
               MOVE WS-TOTAL-PERIODS TO WS-GEN-PERIODS
           END-IF
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-GEN-PERIODS
               MOVE WS-IDX TO WS-AM-PERIOD(WS-IDX)
               MOVE WS-CURRENT-BASIS
                   TO WS-AM-BEG-BASIS(WS-IDX)
               MOVE WS-SEMI-COUPON
                   TO WS-AM-COUPON-REC(WS-IDX)
               COMPUTE WS-PERIOD-YTM-INC =
                   WS-CURRENT-BASIS * WS-SEMI-YTM
               MOVE WS-PERIOD-YTM-INC
                   TO WS-AM-YTM-INCOME(WS-IDX)
               COMPUTE WS-PERIOD-AMORT =
                   WS-SEMI-COUPON - WS-PERIOD-YTM-INC
               IF WS-PERIOD-AMORT < 0
                   MOVE 0 TO WS-PERIOD-AMORT
               END-IF
               MOVE WS-PERIOD-AMORT
                   TO WS-AM-AMORT-AMT(WS-IDX)
               COMPUTE WS-CURRENT-BASIS =
                   WS-CURRENT-BASIS - WS-PERIOD-AMORT
               IF WS-CURRENT-BASIS < WS-FACE-VALUE
                   MOVE WS-FACE-VALUE TO WS-CURRENT-BASIS
               END-IF
               MOVE WS-CURRENT-BASIS
                   TO WS-AM-END-BASIS(WS-IDX)
           END-PERFORM.
       5000-CALC-TOTALS.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-GEN-PERIODS
               ADD WS-AM-COUPON-REC(WS-IDX)
                   TO WS-TOT-COUPON
               ADD WS-AM-YTM-INCOME(WS-IDX)
                   TO WS-TOT-YTM-INC
               ADD WS-AM-AMORT-AMT(WS-IDX)
                   TO WS-TOT-AMORT
           END-PERFORM.
       6000-CALC-TAX-IMPACT.
           IF WS-GEN-PERIODS > 0
               COMPUTE WS-ANNUAL-AMORT =
                   WS-TOT-AMORT /
                   (WS-GEN-PERIODS / 2)
           ELSE
               MOVE 0 TO WS-ANNUAL-AMORT
           END-IF
           COMPUTE WS-TAX-SAVINGS =
               WS-ANNUAL-AMORT * WS-TAX-RATE.
       7000-DISPLAY-RESULTS.
           DISPLAY 'BOND PREMIUM AMORTIZATION REPORT'
           DISPLAY '================================='
           DISPLAY 'CUSIP:           ' WS-CUSIP
           DISPLAY 'FACE VALUE:      ' WS-FACE-VALUE
           DISPLAY 'PURCHASE PRICE:  ' WS-PURCHASE-PRICE
           IF BOND-IS-PREMIUM
               DISPLAY 'PREMIUM:         ' WS-PREMIUM-AMT
               DISPLAY 'COUPON RATE:     ' WS-COUPON-RATE
               DISPLAY 'YTM:             ' WS-YTM
               DISPLAY 'PERIODS:         '
                   WS-TOTAL-PERIODS
               DISPLAY '---------------------------------'
               PERFORM VARYING WS-IDX FROM 1 BY 1
                   UNTIL WS-IDX > WS-GEN-PERIODS
                   DISPLAY 'PD ' WS-AM-PERIOD(WS-IDX)
                       ' BEG: ' WS-AM-BEG-BASIS(WS-IDX)
                       ' AMT: ' WS-AM-AMORT-AMT(WS-IDX)
                       ' END: ' WS-AM-END-BASIS(WS-IDX)
               END-PERFORM
               DISPLAY '---------------------------------'
               DISPLAY 'TOTAL COUPON:    ' WS-TOT-COUPON
               DISPLAY 'TOTAL YTM INC:   ' WS-TOT-YTM-INC
               DISPLAY 'TOTAL AMORT:     ' WS-TOT-AMORT
               DISPLAY 'ANNUAL AMORT:    ' WS-ANNUAL-AMORT
               DISPLAY 'TAX SAVINGS:     ' WS-TAX-SAVINGS
           ELSE
               DISPLAY 'NOT A PREMIUM BOND'
           END-IF.
