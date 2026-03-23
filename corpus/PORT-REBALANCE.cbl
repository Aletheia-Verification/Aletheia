       IDENTIFICATION DIVISION.
       PROGRAM-ID. PORT-REBALANCE.
      *================================================================
      * PORTFOLIO REBALANCING ENGINE
      * Compares current allocation to target, generates buy/sell
      * orders to bring portfolio within tolerance bands.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-PORTFOLIO.
           05 WS-PORT-ID              PIC X(10).
           05 WS-PORT-TOTAL-VALUE     PIC S9(13)V99 COMP-3.
           05 WS-PORT-CASH-BAL        PIC S9(11)V99 COMP-3.
       01 WS-ASSET-CLASS-TABLE.
           05 WS-ASSET-ENTRY OCCURS 6 TIMES.
               10 WS-AC-NAME          PIC X(15).
               10 WS-AC-CURRENT-VAL   PIC S9(11)V99 COMP-3.
               10 WS-AC-TARGET-PCT    PIC S9(3)V99 COMP-3.
               10 WS-AC-CURRENT-PCT   PIC S9(3)V99 COMP-3.
               10 WS-AC-DRIFT         PIC S9(3)V99 COMP-3.
               10 WS-AC-TARGET-VAL    PIC S9(11)V99 COMP-3.
               10 WS-AC-TRADE-AMT     PIC S9(11)V99 COMP-3.
               10 WS-AC-ACTION        PIC X(4).
       01 WS-CLASS-COUNT              PIC 9(1) VALUE 6.
       01 WS-TOLERANCE                PIC S9(3)V99 COMP-3
           VALUE 3.00.
       01 WS-IDX                      PIC 9(1).
       01 WS-NEEDS-REBALANCE          PIC X VALUE 'N'.
           88 WS-REBAL-YES            VALUE 'Y'.
           88 WS-REBAL-NO             VALUE 'N'.
       01 WS-TOTAL-BUY                PIC S9(11)V99 COMP-3
           VALUE 0.
       01 WS-TOTAL-SELL               PIC S9(11)V99 COMP-3
           VALUE 0.
       01 WS-NET-TRADES               PIC S9(11)V99 COMP-3.
       01 WS-ABS-DRIFT                PIC S9(3)V99 COMP-3.
       01 WS-MAX-DRIFT                PIC S9(3)V99 COMP-3
           VALUE 0.
       01 WS-TRADE-COUNT              PIC 9(3) VALUE 0.
       01 WS-MIN-TRADE-AMT            PIC S9(7)V99 COMP-3
           VALUE 500.00.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-CURRENT-ALLOC
           PERFORM 3000-CALC-DRIFT
           PERFORM 4000-GENERATE-TRADES
           PERFORM 5000-SUMMARIZE
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'PORT-A0001' TO WS-PORT-ID
           MOVE 1000000.00 TO WS-PORT-TOTAL-VALUE
           MOVE 25000.00 TO WS-PORT-CASH-BAL
           MOVE 'US LARGE CAP   ' TO WS-AC-NAME(1)
           MOVE 350000.00 TO WS-AC-CURRENT-VAL(1)
           MOVE 30.00 TO WS-AC-TARGET-PCT(1)
           MOVE 'US SMALL CAP   ' TO WS-AC-NAME(2)
           MOVE 120000.00 TO WS-AC-CURRENT-VAL(2)
           MOVE 15.00 TO WS-AC-TARGET-PCT(2)
           MOVE 'INTL DEVELOPED ' TO WS-AC-NAME(3)
           MOVE 180000.00 TO WS-AC-CURRENT-VAL(3)
           MOVE 20.00 TO WS-AC-TARGET-PCT(3)
           MOVE 'EMERG MARKETS  ' TO WS-AC-NAME(4)
           MOVE 80000.00 TO WS-AC-CURRENT-VAL(4)
           MOVE 10.00 TO WS-AC-TARGET-PCT(4)
           MOVE 'FIXED INCOME   ' TO WS-AC-NAME(5)
           MOVE 220000.00 TO WS-AC-CURRENT-VAL(5)
           MOVE 20.00 TO WS-AC-TARGET-PCT(5)
           MOVE 'CASH/EQUIV     ' TO WS-AC-NAME(6)
           MOVE 50000.00 TO WS-AC-CURRENT-VAL(6)
           MOVE 5.00 TO WS-AC-TARGET-PCT(6).
       2000-CALC-CURRENT-ALLOC.
           IF WS-PORT-TOTAL-VALUE > 0
               PERFORM VARYING WS-IDX FROM 1 BY 1
                   UNTIL WS-IDX > WS-CLASS-COUNT
                   COMPUTE WS-AC-CURRENT-PCT(WS-IDX) =
                       (WS-AC-CURRENT-VAL(WS-IDX) /
                       WS-PORT-TOTAL-VALUE) * 100
               END-PERFORM
           END-IF.
       3000-CALC-DRIFT.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-CLASS-COUNT
               COMPUTE WS-AC-DRIFT(WS-IDX) =
                   WS-AC-CURRENT-PCT(WS-IDX) -
                   WS-AC-TARGET-PCT(WS-IDX)
               MOVE WS-AC-DRIFT(WS-IDX) TO WS-ABS-DRIFT
               IF WS-ABS-DRIFT < 0
                   MULTIPLY -1 BY WS-ABS-DRIFT
               END-IF
               IF WS-ABS-DRIFT > WS-TOLERANCE
                   MOVE 'Y' TO WS-NEEDS-REBALANCE
               END-IF
               IF WS-ABS-DRIFT > WS-MAX-DRIFT
                   MOVE WS-ABS-DRIFT TO WS-MAX-DRIFT
               END-IF
           END-PERFORM.
       4000-GENERATE-TRADES.
           IF WS-REBAL-YES
               PERFORM VARYING WS-IDX FROM 1 BY 1
                   UNTIL WS-IDX > WS-CLASS-COUNT
                   COMPUTE WS-AC-TARGET-VAL(WS-IDX) =
                       WS-PORT-TOTAL-VALUE *
                       (WS-AC-TARGET-PCT(WS-IDX) / 100)
                   COMPUTE WS-AC-TRADE-AMT(WS-IDX) =
                       WS-AC-TARGET-VAL(WS-IDX) -
                       WS-AC-CURRENT-VAL(WS-IDX)
                   IF WS-AC-TRADE-AMT(WS-IDX) > 0
                       IF WS-AC-TRADE-AMT(WS-IDX) >=
                           WS-MIN-TRADE-AMT
                           MOVE 'BUY ' TO
                               WS-AC-ACTION(WS-IDX)
                           ADD WS-AC-TRADE-AMT(WS-IDX)
                               TO WS-TOTAL-BUY
                           ADD 1 TO WS-TRADE-COUNT
                       ELSE
                           MOVE 'HOLD' TO
                               WS-AC-ACTION(WS-IDX)
                           MOVE 0 TO
                               WS-AC-TRADE-AMT(WS-IDX)
                       END-IF
                   ELSE
                       IF WS-AC-TRADE-AMT(WS-IDX) < 0
                           MULTIPLY -1 BY
                               WS-AC-TRADE-AMT(WS-IDX)
                           IF WS-AC-TRADE-AMT(WS-IDX) >=
                               WS-MIN-TRADE-AMT
                               MOVE 'SELL' TO
                                   WS-AC-ACTION(WS-IDX)
                               ADD WS-AC-TRADE-AMT(WS-IDX)
                                   TO WS-TOTAL-SELL
                               ADD 1 TO WS-TRADE-COUNT
                           ELSE
                               MOVE 'HOLD' TO
                                   WS-AC-ACTION(WS-IDX)
                               MOVE 0 TO
                                   WS-AC-TRADE-AMT(WS-IDX)
                           END-IF
                       ELSE
                           MOVE 'HOLD' TO
                               WS-AC-ACTION(WS-IDX)
                       END-IF
                   END-IF
               END-PERFORM
           END-IF.
       5000-SUMMARIZE.
           COMPUTE WS-NET-TRADES =
               WS-TOTAL-BUY - WS-TOTAL-SELL.
       6000-DISPLAY-RESULTS.
           DISPLAY 'PORTFOLIO REBALANCING REPORT'
           DISPLAY '============================'
           DISPLAY 'PORTFOLIO:     ' WS-PORT-ID
           DISPLAY 'TOTAL VALUE:   ' WS-PORT-TOTAL-VALUE
           DISPLAY 'TOLERANCE:     ' WS-TOLERANCE
           DISPLAY 'MAX DRIFT:     ' WS-MAX-DRIFT
           IF WS-REBAL-YES
               DISPLAY 'STATUS: REBALANCING REQUIRED'
           ELSE
               DISPLAY 'STATUS: WITHIN TOLERANCE'
           END-IF
           DISPLAY '----------------------------'
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-CLASS-COUNT
               DISPLAY WS-AC-NAME(WS-IDX)
                   ' CUR: ' WS-AC-CURRENT-PCT(WS-IDX)
                   ' TGT: ' WS-AC-TARGET-PCT(WS-IDX)
                   ' ' WS-AC-ACTION(WS-IDX)
                   ' ' WS-AC-TRADE-AMT(WS-IDX)
           END-PERFORM
           DISPLAY '----------------------------'
           DISPLAY 'TOTAL BUYS:    ' WS-TOTAL-BUY
           DISPLAY 'TOTAL SELLS:   ' WS-TOTAL-SELL
           DISPLAY 'TRADE COUNT:   ' WS-TRADE-COUNT.
