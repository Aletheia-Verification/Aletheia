       IDENTIFICATION DIVISION.
       PROGRAM-ID. TRADE-BOND-YIELD.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-BOND-DATA.
           05 WS-FACE-VALUE          PIC S9(9)V99 COMP-3.
           05 WS-COUPON-RATE         PIC S9(3)V9(6) COMP-3.
           05 WS-MARKET-PRICE        PIC S9(9)V99 COMP-3.
           05 WS-YEARS-TO-MAT        PIC 9(3).
       01 WS-YIELD-FIELDS.
           05 WS-CURRENT-YIELD       PIC S9(3)V9(6) COMP-3.
           05 WS-YTM-ESTIMATE        PIC S9(3)V9(6) COMP-3.
           05 WS-ANNUAL-COUPON       PIC S9(7)V99 COMP-3.
           05 WS-SEMI-COUPON         PIC S9(7)V99 COMP-3.
       01 WS-ITERATION.
           05 WS-LOW-YIELD           PIC S9(1)V9(8) COMP-3.
           05 WS-HIGH-YIELD          PIC S9(1)V9(8) COMP-3.
           05 WS-MID-YIELD           PIC S9(1)V9(8) COMP-3.
           05 WS-PV-CALC             PIC S9(11)V99 COMP-3.
           05 WS-PV-COUPON           PIC S9(9)V99 COMP-3.
           05 WS-PV-FACE             PIC S9(9)V99 COMP-3.
           05 WS-DIFF                PIC S9(9)V99 COMP-3.
           05 WS-TOLERANCE           PIC S9(1)V99 COMP-3
               VALUE 0.01.
           05 WS-CONVERGED-FLAG      PIC X VALUE 'N'.
               88 WS-CONVERGED       VALUE 'Y'.
           05 WS-ITER-COUNT          PIC 9(3).
           05 WS-MAX-ITER            PIC 9(3) VALUE 100.
       01 WS-PERIOD-IDX              PIC 9(3).
       01 WS-PERIODS                 PIC 9(3).
       01 WS-PV-FACTOR               PIC S9(3)V9(10) COMP-3.
       01 WS-YIELD-STATUS            PIC X(1).
           88 WS-PREMIUM             VALUE 'P'.
           88 WS-PAR                 VALUE 'A'.
           88 WS-DISCOUNT            VALUE 'D'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-CURRENT-YIELD
           PERFORM 3000-ESTIMATE-YTM
           PERFORM 4000-CLASSIFY
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           COMPUTE WS-ANNUAL-COUPON =
               WS-FACE-VALUE * WS-COUPON-RATE
           COMPUTE WS-SEMI-COUPON =
               WS-ANNUAL-COUPON / 2
           COMPUTE WS-PERIODS =
               WS-YEARS-TO-MAT * 2
           MOVE 0 TO WS-ITER-COUNT
           MOVE 'N' TO WS-CONVERGED-FLAG.
       2000-CALC-CURRENT-YIELD.
           IF WS-MARKET-PRICE > 0
               COMPUTE WS-CURRENT-YIELD =
                   WS-ANNUAL-COUPON / WS-MARKET-PRICE
           END-IF.
       3000-ESTIMATE-YTM.
           MOVE 0.0001 TO WS-LOW-YIELD
           MOVE 0.2000 TO WS-HIGH-YIELD
           PERFORM 3100-BISECT
               UNTIL WS-CONVERGED
               OR WS-ITER-COUNT >= WS-MAX-ITER
           IF WS-CONVERGED
               COMPUTE WS-YTM-ESTIMATE =
                   WS-MID-YIELD * 2
           ELSE
               MOVE WS-CURRENT-YIELD TO WS-YTM-ESTIMATE
           END-IF.
       3100-BISECT.
           ADD 1 TO WS-ITER-COUNT
           COMPUTE WS-MID-YIELD =
               (WS-LOW-YIELD + WS-HIGH-YIELD) / 2
           MOVE 0 TO WS-PV-CALC
           PERFORM VARYING WS-PERIOD-IDX FROM 1 BY 1
               UNTIL WS-PERIOD-IDX > WS-PERIODS
               COMPUTE WS-PV-FACTOR =
                   1 / ((1 + WS-MID-YIELD) **
                   WS-PERIOD-IDX)
               COMPUTE WS-PV-COUPON =
                   WS-SEMI-COUPON * WS-PV-FACTOR
               ADD WS-PV-COUPON TO WS-PV-CALC
           END-PERFORM
           COMPUTE WS-PV-FACE =
               WS-FACE-VALUE / ((1 + WS-MID-YIELD) **
               WS-PERIODS)
           ADD WS-PV-FACE TO WS-PV-CALC
           COMPUTE WS-DIFF =
               WS-PV-CALC - WS-MARKET-PRICE
           IF WS-DIFF < 0
               MULTIPLY -1 BY WS-DIFF
           END-IF
           IF WS-DIFF < WS-TOLERANCE
               MOVE 'Y' TO WS-CONVERGED-FLAG
           ELSE
               IF WS-PV-CALC > WS-MARKET-PRICE
                   MOVE WS-MID-YIELD TO WS-LOW-YIELD
               ELSE
                   MOVE WS-MID-YIELD TO WS-HIGH-YIELD
               END-IF
           END-IF.
       4000-CLASSIFY.
           IF WS-MARKET-PRICE > WS-FACE-VALUE
               SET WS-PREMIUM TO TRUE
           ELSE
               IF WS-MARKET-PRICE < WS-FACE-VALUE
                   SET WS-DISCOUNT TO TRUE
               ELSE
                   SET WS-PAR TO TRUE
               END-IF
           END-IF.
       5000-DISPLAY-RESULTS.
           DISPLAY 'BOND YIELD CALCULATION'
           DISPLAY '======================'
           DISPLAY 'FACE VALUE:     ' WS-FACE-VALUE
           DISPLAY 'COUPON RATE:    ' WS-COUPON-RATE
           DISPLAY 'MARKET PRICE:   ' WS-MARKET-PRICE
           DISPLAY 'YEARS TO MAT:   ' WS-YEARS-TO-MAT
           DISPLAY 'CURRENT YIELD:  ' WS-CURRENT-YIELD
           DISPLAY 'YTM ESTIMATE:   ' WS-YTM-ESTIMATE
           DISPLAY 'ITERATIONS:     ' WS-ITER-COUNT
           IF WS-PREMIUM
               DISPLAY 'TRADING: AT PREMIUM'
           END-IF
           IF WS-DISCOUNT
               DISPLAY 'TRADING: AT DISCOUNT'
           END-IF
           IF WS-PAR
               DISPLAY 'TRADING: AT PAR'
           END-IF.
