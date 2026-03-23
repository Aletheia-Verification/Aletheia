       IDENTIFICATION DIVISION.
       PROGRAM-ID. ASSET-REBAL-OPT.
      *================================================================*
      * Asset Management Portfolio Rebalancing Optimizer                 *
      * Calculates drift from target allocation, generates trade        *
      * orders to rebalance, respects minimum trade sizes and           *
      * tax-loss harvesting opportunities.                              *
      *================================================================*
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-PORTFOLIO-VALUE      PIC S9(15)V99
                                   VALUE 5000000.00.
       01  WS-ASSET-TABLE.
           05  WS-ASSET-ENTRY     OCCURS 10 TIMES.
               10  AT-CLASS-NAME  PIC X(15).
               10  AT-CURRENT-MV  PIC S9(13)V99.
               10  AT-TARGET-PCT  PIC 9(03)V99.
               10  AT-CURRENT-PCT PIC 9(03)V99.
               10  AT-DRIFT       PIC S9(03)V99.
               10  AT-TARGET-MV   PIC S9(13)V99.
               10  AT-TRADE-AMT   PIC S9(13)V99.
               10  AT-COST-BASIS  PIC S9(13)V99.
               10  AT-UNREAL-GL   PIC S9(13)V99.
               10  AT-TLH-FLAG    PIC X VALUE 'N'.
       01  WS-NUM-CLASSES         PIC 9(02) VALUE 6.
       01  WS-IDX                 PIC 9(02).
       01  WS-INNER-IDX           PIC 9(02).
       01  WS-DRIFT-THRESHOLD     PIC 9(03)V99 VALUE 2.00.
       01  WS-MIN-TRADE           PIC 9(09)V99 VALUE 5000.00.
       01  WS-TOTAL-BUYS          PIC S9(13)V99 VALUE 0.
       01  WS-TOTAL-SELLS         PIC S9(13)V99 VALUE 0.
       01  WS-TRADE-COUNT         PIC 9(04) VALUE 0.
       01  WS-TLH-SAVINGS         PIC S9(11)V99 VALUE 0.
       01  WS-TAX-RATE            PIC 9V9(04) VALUE 0.2300.
       01  WS-REBAL-NEEDED        PIC X VALUE 'N'.
           88  NEEDS-REBAL         VALUE 'Y'.
       01  WS-MAX-DRIFT           PIC S9(03)V99 VALUE 0.
       01  WS-ABS-DRIFT           PIC 9(03)V99.
       01  WS-ABS-TRADE           PIC 9(13)V99.
       01  WS-MSG                 PIC X(80) VALUE SPACES.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-CURRENT-ALLOC
           PERFORM 3000-CALC-DRIFT
           IF NEEDS-REBAL
               PERFORM 4000-GENERATE-TRADES
               PERFORM 5000-TAX-LOSS-HARVEST
               PERFORM 6000-PRINT-ORDERS
           ELSE
               DISPLAY 'NO REBALANCING NEEDED'
           END-IF
           PERFORM 9000-REPORT
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'US LARGE CAP   ' TO AT-CLASS-NAME(1)
           MOVE 1600000.00 TO AT-CURRENT-MV(1)
           MOVE 30.00 TO AT-TARGET-PCT(1)
           MOVE 1400000.00 TO AT-COST-BASIS(1)
           MOVE 'US SMALL CAP   ' TO AT-CLASS-NAME(2)
           MOVE 600000.00 TO AT-CURRENT-MV(2)
           MOVE 10.00 TO AT-TARGET-PCT(2)
           MOVE 650000.00 TO AT-COST-BASIS(2)
           MOVE 'INTL DEVELOPED ' TO AT-CLASS-NAME(3)
           MOVE 900000.00 TO AT-CURRENT-MV(3)
           MOVE 20.00 TO AT-TARGET-PCT(3)
           MOVE 850000.00 TO AT-COST-BASIS(3)
           MOVE 'EMERGING MKT   ' TO AT-CLASS-NAME(4)
           MOVE 350000.00 TO AT-CURRENT-MV(4)
           MOVE 5.00 TO AT-TARGET-PCT(4)
           MOVE 400000.00 TO AT-COST-BASIS(4)
           MOVE 'FIXED INCOME   ' TO AT-CLASS-NAME(5)
           MOVE 1200000.00 TO AT-CURRENT-MV(5)
           MOVE 30.00 TO AT-TARGET-PCT(5)
           MOVE 1250000.00 TO AT-COST-BASIS(5)
           MOVE 'ALTERNATIVES   ' TO AT-CLASS-NAME(6)
           MOVE 350000.00 TO AT-CURRENT-MV(6)
           MOVE 5.00 TO AT-TARGET-PCT(6)
           MOVE 300000.00 TO AT-COST-BASIS(6).
       2000-CALC-CURRENT-ALLOC.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-NUM-CLASSES
               IF WS-PORTFOLIO-VALUE > ZERO
                   COMPUTE AT-CURRENT-PCT(WS-IDX) ROUNDED =
                       (AT-CURRENT-MV(WS-IDX) /
                       WS-PORTFOLIO-VALUE) * 100
               END-IF
               COMPUTE AT-UNREAL-GL(WS-IDX) =
                   AT-CURRENT-MV(WS-IDX) -
                   AT-COST-BASIS(WS-IDX)
           END-PERFORM.
       3000-CALC-DRIFT.
           MOVE 'N' TO WS-REBAL-NEEDED
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-NUM-CLASSES
               COMPUTE AT-DRIFT(WS-IDX) =
                   AT-CURRENT-PCT(WS-IDX) -
                   AT-TARGET-PCT(WS-IDX)
               MOVE AT-DRIFT(WS-IDX) TO WS-ABS-DRIFT
               IF AT-DRIFT(WS-IDX) < ZERO
                   COMPUTE WS-ABS-DRIFT =
                       AT-DRIFT(WS-IDX) * -1
               END-IF
               IF WS-ABS-DRIFT > WS-DRIFT-THRESHOLD
                   MOVE 'Y' TO WS-REBAL-NEEDED
               END-IF
               IF WS-ABS-DRIFT > WS-MAX-DRIFT
                   MOVE WS-ABS-DRIFT TO WS-MAX-DRIFT
               END-IF
           END-PERFORM.
       4000-GENERATE-TRADES.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-NUM-CLASSES
               COMPUTE AT-TARGET-MV(WS-IDX) ROUNDED =
                   WS-PORTFOLIO-VALUE *
                   AT-TARGET-PCT(WS-IDX) / 100
               COMPUTE AT-TRADE-AMT(WS-IDX) =
                   AT-TARGET-MV(WS-IDX) -
                   AT-CURRENT-MV(WS-IDX)
               MOVE AT-TRADE-AMT(WS-IDX) TO WS-ABS-TRADE
               IF AT-TRADE-AMT(WS-IDX) < ZERO
                   COMPUTE WS-ABS-TRADE =
                       AT-TRADE-AMT(WS-IDX) * -1
               END-IF
               IF WS-ABS-TRADE < WS-MIN-TRADE
                   MOVE ZERO TO AT-TRADE-AMT(WS-IDX)
               ELSE
                   ADD 1 TO WS-TRADE-COUNT
                   IF AT-TRADE-AMT(WS-IDX) > ZERO
                       ADD AT-TRADE-AMT(WS-IDX)
                           TO WS-TOTAL-BUYS
                   ELSE
                       ADD AT-TRADE-AMT(WS-IDX)
                           TO WS-TOTAL-SELLS
                   END-IF
               END-IF
           END-PERFORM.
       5000-TAX-LOSS-HARVEST.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-NUM-CLASSES
               IF AT-TRADE-AMT(WS-IDX) < ZERO AND
                  AT-UNREAL-GL(WS-IDX) < ZERO
                   MOVE 'Y' TO AT-TLH-FLAG(WS-IDX)
                   COMPUTE WS-TLH-SAVINGS ROUNDED =
                       WS-TLH-SAVINGS +
                       (AT-UNREAL-GL(WS-IDX) * WS-TAX-RATE
                       * -1)
               END-IF
           END-PERFORM.
       6000-PRINT-ORDERS.
           DISPLAY 'REBALANCING TRADE ORDERS:'
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-NUM-CLASSES
               IF AT-TRADE-AMT(WS-IDX) NOT = ZERO
                   MOVE SPACES TO WS-MSG
                   STRING AT-CLASS-NAME(WS-IDX)
                       DELIMITED BY SIZE
                       ' AMT='
                       DELIMITED BY SIZE
                       INTO WS-MSG
                   DISPLAY WS-MSG AT-TRADE-AMT(WS-IDX)
                   IF AT-TLH-FLAG(WS-IDX) = 'Y'
                       DISPLAY '  ** TAX-LOSS HARVEST **'
                   END-IF
               END-IF
           END-PERFORM.
       9000-REPORT.
           DISPLAY 'REBALANCING SUMMARY'
           DISPLAY 'PORTFOLIO:  ' WS-PORTFOLIO-VALUE
           DISPLAY 'MAX DRIFT:  ' WS-MAX-DRIFT '%'
           DISPLAY 'TRADES:     ' WS-TRADE-COUNT
           DISPLAY 'TOTAL BUYS: ' WS-TOTAL-BUYS
           DISPLAY 'TOTAL SELLS:' WS-TOTAL-SELLS
           DISPLAY 'TLH SAVINGS:' WS-TLH-SAVINGS.
