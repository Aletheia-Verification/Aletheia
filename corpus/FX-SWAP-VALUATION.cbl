       IDENTIFICATION DIVISION.
       PROGRAM-ID. FX-SWAP-VALUATION.
      *================================================================*
      * FX SWAP VALUATION ENGINE                                       *
      * Values foreign exchange swap contracts using spot/forward      *
      * rates, calculates mark-to-market P&L, and applies netting.    *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-SWAP-TABLE.
           05 WS-SWAP-ENTRY OCCURS 6.
               10 WS-SWP-ID         PIC X(10).
               10 WS-SWP-CCY-PAIR   PIC X(7).
               10 WS-SWP-NOTIONAL   PIC S9(11)V99 COMP-3.
               10 WS-SWP-SPOT       PIC S9(3)V9(6) COMP-3.
               10 WS-SWP-FWD-RATE   PIC S9(3)V9(6) COMP-3.
               10 WS-SWP-MKT-FWD    PIC S9(3)V9(6) COMP-3.
               10 WS-SWP-DAYS-LEFT  PIC S9(3) COMP-3.
               10 WS-SWP-DIRECTION  PIC X(1).
                   88 WS-SWP-BUY    VALUE 'B'.
                   88 WS-SWP-SELL   VALUE 'S'.
               10 WS-SWP-MTM        PIC S9(11)V99 COMP-3.
               10 WS-SWP-DISC-RATE  PIC S9(1)V9(6) COMP-3.
       01 WS-SWAP-COUNT             PIC S9(2) COMP-3.
       01 WS-PORTFOLIO.
           05 WS-TOTAL-MTM          PIC S9(13)V99 COMP-3.
           05 WS-POSITIVE-MTM       PIC S9(13)V99 COMP-3.
           05 WS-NEGATIVE-MTM       PIC S9(13)V99 COMP-3.
           05 WS-NET-EXPOSURE       PIC S9(13)V99 COMP-3.
           05 WS-GROSS-NOTIONAL     PIC S9(13)V99 COMP-3.
           05 WS-WEIGHTED-DAYS      PIC S9(7)V99 COMP-3.
       01 WS-IDX                    PIC S9(2) COMP-3.
       01 WS-FWD-DIFF               PIC S9(3)V9(6) COMP-3.
       01 WS-RAW-MTM                PIC S9(11)V99 COMP-3.
       01 WS-DISC-FACTOR            PIC S9(1)V9(8) COMP-3.
       01 WS-NETTING-BENEFIT        PIC S9(13)V99 COMP-3.
       01 WS-RISK-WEIGHTED          PIC S9(13)V99 COMP-3.
       01 WS-RWA-FACTOR             PIC S9(1)V9(4) COMP-3
           VALUE 0.20.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-SWAPS
           PERFORM 3000-VALUE-SWAPS
           PERFORM 4000-AGGREGATE-MTM
           PERFORM 5000-CALC-NETTING
           PERFORM 6000-CALC-RWA
           PERFORM 7000-DISPLAY-REPORT
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-MTM
           MOVE 0 TO WS-POSITIVE-MTM
           MOVE 0 TO WS-NEGATIVE-MTM
           MOVE 0 TO WS-NET-EXPOSURE
           MOVE 0 TO WS-GROSS-NOTIONAL
           MOVE 0 TO WS-WEIGHTED-DAYS.
       2000-LOAD-SWAPS.
           MOVE 6 TO WS-SWAP-COUNT
           MOVE 'FXS0000001' TO WS-SWP-ID(1)
           MOVE 'EUR/USD' TO WS-SWP-CCY-PAIR(1)
           MOVE 10000000.00 TO WS-SWP-NOTIONAL(1)
           MOVE 1.085000 TO WS-SWP-SPOT(1)
           MOVE 1.088500 TO WS-SWP-FWD-RATE(1)
           MOVE 1.092000 TO WS-SWP-MKT-FWD(1)
           MOVE 90 TO WS-SWP-DAYS-LEFT(1)
           MOVE 'B' TO WS-SWP-DIRECTION(1)
           MOVE 0.045000 TO WS-SWP-DISC-RATE(1)
           MOVE 'FXS0000002' TO WS-SWP-ID(2)
           MOVE 'GBP/USD' TO WS-SWP-CCY-PAIR(2)
           MOVE 5000000.00 TO WS-SWP-NOTIONAL(2)
           MOVE 1.265000 TO WS-SWP-SPOT(2)
           MOVE 1.268000 TO WS-SWP-FWD-RATE(2)
           MOVE 1.260000 TO WS-SWP-MKT-FWD(2)
           MOVE 60 TO WS-SWP-DAYS-LEFT(2)
           MOVE 'B' TO WS-SWP-DIRECTION(2)
           MOVE 0.050000 TO WS-SWP-DISC-RATE(2)
           MOVE 'FXS0000003' TO WS-SWP-ID(3)
           MOVE 'USD/JPY' TO WS-SWP-CCY-PAIR(3)
           MOVE 20000000.00 TO WS-SWP-NOTIONAL(3)
           MOVE 149.500 TO WS-SWP-SPOT(3)
           MOVE 148.800 TO WS-SWP-FWD-RATE(3)
           MOVE 150.200 TO WS-SWP-MKT-FWD(3)
           MOVE 120 TO WS-SWP-DAYS-LEFT(3)
           MOVE 'S' TO WS-SWP-DIRECTION(3)
           MOVE 0.002000 TO WS-SWP-DISC-RATE(3)
           MOVE 'FXS0000004' TO WS-SWP-ID(4)
           MOVE 'EUR/USD' TO WS-SWP-CCY-PAIR(4)
           MOVE 8000000.00 TO WS-SWP-NOTIONAL(4)
           MOVE 1.090000 TO WS-SWP-SPOT(4)
           MOVE 1.095000 TO WS-SWP-FWD-RATE(4)
           MOVE 1.092000 TO WS-SWP-MKT-FWD(4)
           MOVE 180 TO WS-SWP-DAYS-LEFT(4)
           MOVE 'S' TO WS-SWP-DIRECTION(4)
           MOVE 0.045000 TO WS-SWP-DISC-RATE(4)
           MOVE 'FXS0000005' TO WS-SWP-ID(5)
           MOVE 'USD/CHF' TO WS-SWP-CCY-PAIR(5)
           MOVE 15000000.00 TO WS-SWP-NOTIONAL(5)
           MOVE 0.880000 TO WS-SWP-SPOT(5)
           MOVE 0.876000 TO WS-SWP-FWD-RATE(5)
           MOVE 0.878000 TO WS-SWP-MKT-FWD(5)
           MOVE 45 TO WS-SWP-DAYS-LEFT(5)
           MOVE 'B' TO WS-SWP-DIRECTION(5)
           MOVE 0.015000 TO WS-SWP-DISC-RATE(5)
           MOVE 'FXS0000006' TO WS-SWP-ID(6)
           MOVE 'GBP/USD' TO WS-SWP-CCY-PAIR(6)
           MOVE 12000000.00 TO WS-SWP-NOTIONAL(6)
           MOVE 1.270000 TO WS-SWP-SPOT(6)
           MOVE 1.275000 TO WS-SWP-FWD-RATE(6)
           MOVE 1.280000 TO WS-SWP-MKT-FWD(6)
           MOVE 30 TO WS-SWP-DAYS-LEFT(6)
           MOVE 'B' TO WS-SWP-DIRECTION(6)
           MOVE 0.050000 TO WS-SWP-DISC-RATE(6).
       3000-VALUE-SWAPS.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-SWAP-COUNT
               PERFORM 3100-CALC-SINGLE-MTM
           END-PERFORM.
       3100-CALC-SINGLE-MTM.
           COMPUTE WS-FWD-DIFF =
               WS-SWP-MKT-FWD(WS-IDX) -
               WS-SWP-FWD-RATE(WS-IDX)
           IF WS-SWP-BUY(WS-IDX)
               COMPUTE WS-RAW-MTM =
                   WS-SWP-NOTIONAL(WS-IDX) * WS-FWD-DIFF
           ELSE
               COMPUTE WS-RAW-MTM =
                   WS-SWP-NOTIONAL(WS-IDX) * WS-FWD-DIFF
                   * -1
           END-IF
           COMPUTE WS-DISC-FACTOR ROUNDED =
               1 / (1 + WS-SWP-DISC-RATE(WS-IDX) *
               WS-SWP-DAYS-LEFT(WS-IDX) / 360)
           COMPUTE WS-SWP-MTM(WS-IDX) ROUNDED =
               WS-RAW-MTM * WS-DISC-FACTOR.
       4000-AGGREGATE-MTM.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-SWAP-COUNT
               ADD WS-SWP-MTM(WS-IDX) TO WS-TOTAL-MTM
               ADD WS-SWP-NOTIONAL(WS-IDX) TO
                   WS-GROSS-NOTIONAL
               COMPUTE WS-WEIGHTED-DAYS =
                   WS-WEIGHTED-DAYS +
                   (WS-SWP-NOTIONAL(WS-IDX) *
                    WS-SWP-DAYS-LEFT(WS-IDX))
               IF WS-SWP-MTM(WS-IDX) > 0
                   ADD WS-SWP-MTM(WS-IDX) TO
                       WS-POSITIVE-MTM
               ELSE
                   ADD WS-SWP-MTM(WS-IDX) TO
                       WS-NEGATIVE-MTM
               END-IF
           END-PERFORM.
       5000-CALC-NETTING.
           COMPUTE WS-NET-EXPOSURE =
               WS-POSITIVE-MTM + WS-NEGATIVE-MTM
           COMPUTE WS-NETTING-BENEFIT =
               WS-POSITIVE-MTM -
               FUNCTION ABS(WS-NEGATIVE-MTM) -
               WS-NET-EXPOSURE.
       6000-CALC-RWA.
           IF WS-NET-EXPOSURE > 0
               COMPUTE WS-RISK-WEIGHTED ROUNDED =
                   WS-NET-EXPOSURE * WS-RWA-FACTOR
           ELSE
               MOVE 0 TO WS-RISK-WEIGHTED
           END-IF.
       7000-DISPLAY-REPORT.
           DISPLAY '========================================='
           DISPLAY 'FX SWAP PORTFOLIO VALUATION'
           DISPLAY '========================================='
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-SWAP-COUNT
               DISPLAY WS-SWP-ID(WS-IDX) ' '
                   WS-SWP-CCY-PAIR(WS-IDX) ' '
                   WS-SWP-DIRECTION(WS-IDX) ' MTM: '
                   WS-SWP-MTM(WS-IDX)
           END-PERFORM
           DISPLAY '-----------------------------------------'
           DISPLAY 'GROSS NOTIONAL:  ' WS-GROSS-NOTIONAL
           DISPLAY 'TOTAL MTM:       ' WS-TOTAL-MTM
           DISPLAY 'POSITIVE MTM:    ' WS-POSITIVE-MTM
           DISPLAY 'NEGATIVE MTM:    ' WS-NEGATIVE-MTM
           DISPLAY 'NET EXPOSURE:    ' WS-NET-EXPOSURE
           DISPLAY 'NETTING BENEFIT: ' WS-NETTING-BENEFIT
           DISPLAY 'RISK WEIGHTED:   ' WS-RISK-WEIGHTED
           DISPLAY '========================================='.
