       IDENTIFICATION DIVISION.
       PROGRAM-ID. TRADE-BOND-SETTLE.
      *================================================================*
      * BOND TRADE SETTLEMENT ENGINE                                   *
      * Calculates accrued interest, settlement amount, and applies    *
      * T+1/T+2 conventions. Handles both clean and dirty pricing.     *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-TRADE.
           05 WS-TRADE-ID           PIC X(12).
           05 WS-CUSIP              PIC X(9).
           05 WS-FACE-VALUE         PIC S9(11)V99 COMP-3.
           05 WS-CLEAN-PRICE        PIC S9(3)V9(6) COMP-3.
           05 WS-COUPON-RATE        PIC S9(2)V9(6) COMP-3.
           05 WS-COUPON-FREQ        PIC S9(1) COMP-3.
           05 WS-TRADE-DATE         PIC 9(8).
           05 WS-SETTLE-DATE        PIC 9(8).
           05 WS-MATURITY-DATE      PIC 9(8).
           05 WS-LAST-COUPON-DT     PIC 9(8).
           05 WS-NEXT-COUPON-DT     PIC 9(8).
           05 WS-SIDE               PIC X(1).
               88 WS-BUY            VALUE 'B'.
               88 WS-SELL           VALUE 'S'.
           05 WS-DAY-COUNT          PIC X(3).
               88 WS-ACTUAL-360     VALUE '360'.
               88 WS-ACTUAL-365     VALUE '365'.
               88 WS-30-360         VALUE '300'.
       01 WS-CALCS.
           05 WS-DAYS-ACCRUED       PIC S9(5) COMP-3.
           05 WS-COUPON-PERIOD      PIC S9(5) COMP-3.
           05 WS-ACCRUED-INT        PIC S9(9)V99 COMP-3.
           05 WS-MARKET-VALUE       PIC S9(13)V99 COMP-3.
           05 WS-DIRTY-PRICE        PIC S9(3)V9(6) COMP-3.
           05 WS-SETTLE-AMT         PIC S9(13)V99 COMP-3.
           05 WS-PER-PERIOD-COUPON  PIC S9(9)V99 COMP-3.
       01 WS-FEES.
           05 WS-COMMISSION         PIC S9(7)V99 COMP-3.
           05 WS-SEC-FEE            PIC S9(5)V99 COMP-3.
           05 WS-CLEARING-FEE       PIC S9(5)V99 COMP-3.
           05 WS-TOTAL-FEES         PIC S9(7)V99 COMP-3.
       01 WS-COMM-RATE              PIC S9(1)V9(4) COMP-3
           VALUE 0.0010.
       01 WS-SEC-FEE-RATE           PIC S9(1)V9(6) COMP-3
           VALUE 0.000008.
       01 WS-CLEAR-PER-BOND         PIC S9(1)V99 COMP-3
           VALUE 0.05.
       01 WS-NET-AMOUNT             PIC S9(13)V99 COMP-3.
       01 WS-BOND-QTY               PIC S9(7) COMP-3.
       01 WS-DAY-BASIS              PIC S9(3) COMP-3.
       01 WS-SETTLE-STATUS          PIC X(10).
       01 WS-ACCRUAL-FRAC           PIC S9(1)V9(8) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-ACCRUED-INT
           PERFORM 3000-CALC-MARKET-VALUE
           PERFORM 4000-CALC-SETTLEMENT-AMT
           PERFORM 5000-CALC-FEES
               THRU 5500-NET-CALCULATION
           PERFORM 6000-DETERMINE-STATUS
           PERFORM 7000-DISPLAY-REPORT
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'TRD202603001' TO WS-TRADE-ID
           MOVE '912828ZT2' TO WS-CUSIP
           MOVE 1000000.00 TO WS-FACE-VALUE
           MOVE 99.875000 TO WS-CLEAN-PRICE
           MOVE 4.250000 TO WS-COUPON-RATE
           MOVE 2 TO WS-COUPON-FREQ
           MOVE 20260320 TO WS-TRADE-DATE
           MOVE 20260321 TO WS-SETTLE-DATE
           MOVE 20310315 TO WS-MATURITY-DATE
           MOVE 20260315 TO WS-LAST-COUPON-DT
           MOVE 20260915 TO WS-NEXT-COUPON-DT
           MOVE 'B' TO WS-SIDE
           MOVE '365' TO WS-DAY-COUNT
           MOVE 0 TO WS-ACCRUED-INT
           MOVE 0 TO WS-MARKET-VALUE
           MOVE 0 TO WS-SETTLE-AMT
           MOVE 0 TO WS-COMMISSION
           MOVE 0 TO WS-SEC-FEE
           MOVE 0 TO WS-CLEARING-FEE.
       2000-CALC-ACCRUED-INT.
           COMPUTE WS-DAYS-ACCRUED =
               WS-SETTLE-DATE - WS-LAST-COUPON-DT
           COMPUTE WS-COUPON-PERIOD =
               WS-NEXT-COUPON-DT - WS-LAST-COUPON-DT
           EVALUATE TRUE
               WHEN WS-ACTUAL-365
                   MOVE 365 TO WS-DAY-BASIS
               WHEN WS-ACTUAL-360
                   MOVE 360 TO WS-DAY-BASIS
               WHEN WS-30-360
                   MOVE 360 TO WS-DAY-BASIS
               WHEN OTHER
                   MOVE 365 TO WS-DAY-BASIS
           END-EVALUATE
           COMPUTE WS-PER-PERIOD-COUPON ROUNDED =
               WS-FACE-VALUE * WS-COUPON-RATE / 100
               / WS-COUPON-FREQ
           IF WS-COUPON-PERIOD > 0
               COMPUTE WS-ACCRUAL-FRAC ROUNDED =
                   WS-DAYS-ACCRUED / WS-COUPON-PERIOD
           ELSE
               MOVE 0 TO WS-ACCRUAL-FRAC
           END-IF
           COMPUTE WS-ACCRUED-INT ROUNDED =
               WS-PER-PERIOD-COUPON * WS-ACCRUAL-FRAC.
       3000-CALC-MARKET-VALUE.
           COMPUTE WS-MARKET-VALUE ROUNDED =
               WS-FACE-VALUE * WS-CLEAN-PRICE / 100
           COMPUTE WS-DIRTY-PRICE ROUNDED =
               WS-CLEAN-PRICE +
               (WS-ACCRUED-INT / WS-FACE-VALUE * 100).
       4000-CALC-SETTLEMENT-AMT.
           COMPUTE WS-SETTLE-AMT =
               WS-MARKET-VALUE + WS-ACCRUED-INT.
       5000-CALC-FEES.
           COMPUTE WS-COMMISSION ROUNDED =
               WS-SETTLE-AMT * WS-COMM-RATE
           IF WS-SELL
               COMPUTE WS-SEC-FEE ROUNDED =
                   WS-SETTLE-AMT * WS-SEC-FEE-RATE
           ELSE
               MOVE 0 TO WS-SEC-FEE
           END-IF
           COMPUTE WS-BOND-QTY =
               WS-FACE-VALUE / 1000
           COMPUTE WS-CLEARING-FEE ROUNDED =
               WS-BOND-QTY * WS-CLEAR-PER-BOND.
       5500-NET-CALCULATION.
           COMPUTE WS-TOTAL-FEES =
               WS-COMMISSION + WS-SEC-FEE + WS-CLEARING-FEE
           IF WS-BUY
               COMPUTE WS-NET-AMOUNT =
                   WS-SETTLE-AMT + WS-TOTAL-FEES
           ELSE
               COMPUTE WS-NET-AMOUNT =
                   WS-SETTLE-AMT - WS-TOTAL-FEES
           END-IF.
       6000-DETERMINE-STATUS.
           IF WS-SETTLE-DATE >= WS-TRADE-DATE
               IF WS-SETTLE-DATE <= WS-MATURITY-DATE
                   MOVE 'CONFIRMED' TO WS-SETTLE-STATUS
               ELSE
                   MOVE 'PAST MAT' TO WS-SETTLE-STATUS
               END-IF
           ELSE
               MOVE 'INVALID' TO WS-SETTLE-STATUS
           END-IF.
       7000-DISPLAY-REPORT.
           DISPLAY '========================================='
           DISPLAY 'BOND SETTLEMENT REPORT'
           DISPLAY '========================================='
           DISPLAY 'TRADE ID:        ' WS-TRADE-ID
           DISPLAY 'CUSIP:           ' WS-CUSIP
           DISPLAY 'FACE VALUE:      ' WS-FACE-VALUE
           DISPLAY 'CLEAN PRICE:     ' WS-CLEAN-PRICE
           DISPLAY 'DIRTY PRICE:     ' WS-DIRTY-PRICE
           DISPLAY 'COUPON RATE:     ' WS-COUPON-RATE
           DISPLAY 'DAYS ACCRUED:    ' WS-DAYS-ACCRUED
           DISPLAY 'ACCRUED INT:     ' WS-ACCRUED-INT
           DISPLAY 'MARKET VALUE:    ' WS-MARKET-VALUE
           DISPLAY 'SETTLE AMOUNT:   ' WS-SETTLE-AMT
           DISPLAY 'COMMISSION:      ' WS-COMMISSION
           DISPLAY 'SEC FEE:         ' WS-SEC-FEE
           DISPLAY 'CLEARING FEE:    ' WS-CLEARING-FEE
           DISPLAY 'TOTAL FEES:      ' WS-TOTAL-FEES
           DISPLAY 'NET AMOUNT:      ' WS-NET-AMOUNT
           DISPLAY 'STATUS:          ' WS-SETTLE-STATUS
           DISPLAY '========================================='.
