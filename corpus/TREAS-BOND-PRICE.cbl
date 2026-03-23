       IDENTIFICATION DIVISION.
       PROGRAM-ID. TREAS-BOND-PRICE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-BOND.
           05 WS-BOND-CUSIP       PIC X(9).
           05 WS-FACE-VALUE       PIC S9(11)V99 COMP-3.
           05 WS-COUPON-RATE      PIC S9(2)V9(4) COMP-3.
           05 WS-YIELD            PIC S9(2)V9(4) COMP-3.
           05 WS-PERIODS-LEFT     PIC 9(3).
           05 WS-PAY-FREQUENCY    PIC 9.
               88 PAY-SEMI        VALUE 2.
               88 PAY-QUARTERLY   VALUE 4.
               88 PAY-ANNUAL      VALUE 1.
       01 WS-PRICING.
           05 WS-COUPON-PMT       PIC S9(9)V99 COMP-3.
           05 WS-PERIOD-YIELD     PIC S9(1)V9(8) COMP-3.
           05 WS-PV-COUPONS       PIC S9(11)V99 COMP-3.
           05 WS-PV-FACE          PIC S9(11)V99 COMP-3.
           05 WS-CLEAN-PRICE      PIC S9(11)V99 COMP-3.
           05 WS-ACCRUED-INT      PIC S9(7)V99 COMP-3.
           05 WS-DIRTY-PRICE      PIC S9(11)V99 COMP-3.
       01 WS-PD-IDX               PIC 9(3).
       01 WS-DISCOUNT-FACTOR      PIC S9(1)V9(8) COMP-3.
       01 WS-POWER-FACTOR         PIC S9(1)V9(8) COMP-3.
       01 WS-PV-COUPON-SUM        PIC S9(11)V99 COMP-3.
       01 WS-DURATION             PIC S9(3)V9(4) COMP-3.
       01 WS-WEIGHTED-SUM         PIC S9(13)V99 COMP-3.
       01 WS-PRICE-PCT            PIC S9(3)V9(4) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-CALC-COUPON
           PERFORM 2000-PRICE-BOND
           PERFORM 3000-CALC-DURATION
           PERFORM 4000-OUTPUT
           STOP RUN.
       1000-CALC-COUPON.
           COMPUTE WS-COUPON-PMT =
               WS-FACE-VALUE * WS-COUPON-RATE /
               WS-PAY-FREQUENCY
           COMPUTE WS-PERIOD-YIELD =
               WS-YIELD / WS-PAY-FREQUENCY.
       2000-PRICE-BOND.
           MOVE 0 TO WS-PV-COUPON-SUM
           PERFORM VARYING WS-PD-IDX FROM 1 BY 1
               UNTIL WS-PD-IDX > WS-PERIODS-LEFT
               COMPUTE WS-POWER-FACTOR =
                   1 + WS-PERIOD-YIELD
               COMPUTE WS-DISCOUNT-FACTOR =
                   1 / WS-POWER-FACTOR
               COMPUTE WS-PV-COUPONS =
                   WS-COUPON-PMT * WS-DISCOUNT-FACTOR
               ADD WS-PV-COUPONS TO WS-PV-COUPON-SUM
           END-PERFORM
           COMPUTE WS-POWER-FACTOR = 1 + WS-PERIOD-YIELD
           COMPUTE WS-PV-FACE =
               WS-FACE-VALUE / WS-POWER-FACTOR
           COMPUTE WS-CLEAN-PRICE =
               WS-PV-COUPON-SUM + WS-PV-FACE
           COMPUTE WS-DIRTY-PRICE =
               WS-CLEAN-PRICE + WS-ACCRUED-INT
           IF WS-FACE-VALUE > 0
               COMPUTE WS-PRICE-PCT =
                   (WS-CLEAN-PRICE / WS-FACE-VALUE) * 100
           END-IF.
       3000-CALC-DURATION.
           MOVE 0 TO WS-WEIGHTED-SUM
           PERFORM VARYING WS-PD-IDX FROM 1 BY 1
               UNTIL WS-PD-IDX > WS-PERIODS-LEFT
               COMPUTE WS-POWER-FACTOR =
                   1 + WS-PERIOD-YIELD
               COMPUTE WS-DISCOUNT-FACTOR =
                   1 / WS-POWER-FACTOR
               COMPUTE WS-WEIGHTED-SUM =
                   WS-WEIGHTED-SUM +
                   (WS-PD-IDX * WS-COUPON-PMT *
                    WS-DISCOUNT-FACTOR)
           END-PERFORM
           COMPUTE WS-WEIGHTED-SUM =
               WS-WEIGHTED-SUM +
               (WS-PERIODS-LEFT * WS-PV-FACE)
           IF WS-DIRTY-PRICE > 0
               COMPUTE WS-DURATION =
                   WS-WEIGHTED-SUM / WS-DIRTY-PRICE
           ELSE
               MOVE 0 TO WS-DURATION
           END-IF.
       4000-OUTPUT.
           DISPLAY 'BOND PRICING REPORT'
           DISPLAY '==================='
           DISPLAY 'CUSIP:      ' WS-BOND-CUSIP
           DISPLAY 'FACE:       $' WS-FACE-VALUE
           DISPLAY 'COUPON:     ' WS-COUPON-RATE
           DISPLAY 'YIELD:      ' WS-YIELD
           DISPLAY 'PERIODS:    ' WS-PERIODS-LEFT
           DISPLAY 'COUPON PMT: $' WS-COUPON-PMT
           DISPLAY 'CLEAN PRICE:$' WS-CLEAN-PRICE
           DISPLAY 'ACCRUED INT:$' WS-ACCRUED-INT
           DISPLAY 'DIRTY PRICE:$' WS-DIRTY-PRICE
           DISPLAY 'PRICE PCT:  ' WS-PRICE-PCT
           DISPLAY 'DURATION:   ' WS-DURATION.
