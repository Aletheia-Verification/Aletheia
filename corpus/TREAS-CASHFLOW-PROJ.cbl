       IDENTIFICATION DIVISION.
       PROGRAM-ID. TREAS-CASHFLOW-PROJ.
      *================================================================*
      * TREASURY CASH FLOW PROJECTION                                  *
      * Projects 12-month cash flows from known receivables/payables,  *
      * applies seasonal adjustments, computes funding gaps.           *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-MONTHLY-DATA.
           05 WS-MONTH-ENTRY OCCURS 12.
               10 WS-MO-RECEIVABLE   PIC S9(11)V99 COMP-3.
               10 WS-MO-PAYABLE      PIC S9(11)V99 COMP-3.
               10 WS-MO-SEASONAL-ADJ PIC S9(1)V9(4) COMP-3.
               10 WS-MO-NET-FLOW     PIC S9(11)V99 COMP-3.
               10 WS-MO-CUM-BALANCE  PIC S9(13)V99 COMP-3.
               10 WS-MO-FUNDING-GAP  PIC S9(11)V99 COMP-3.
               10 WS-MO-GAP-FLAG     PIC X VALUE 'N'.
                   88 WS-HAS-GAP     VALUE 'Y'.
       01 WS-OPENING-BALANCE        PIC S9(13)V99 COMP-3.
       01 WS-MIN-RESERVE            PIC S9(11)V99 COMP-3
           VALUE 500000.00.
       01 WS-TOTAL-RECV             PIC S9(13)V99 COMP-3.
       01 WS-TOTAL-PAY              PIC S9(13)V99 COMP-3.
       01 WS-TOTAL-GAPS             PIC S9(13)V99 COMP-3.
       01 WS-GAP-MONTHS             PIC S9(2) COMP-3.
       01 WS-MAX-GAP                PIC S9(11)V99 COMP-3.
       01 WS-MIN-BALANCE            PIC S9(13)V99 COMP-3.
       01 WS-IDX                    PIC S9(2) COMP-3.
       01 WS-ADJUSTED-RECV          PIC S9(11)V99 COMP-3.
       01 WS-ADJUSTED-PAY           PIC S9(11)V99 COMP-3.
       01 WS-PREV-BALANCE           PIC S9(13)V99 COMP-3.
       01 WS-FUNDING-STRATEGY       PIC X(20).
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-PROJECTIONS
           PERFORM 3000-CALC-CASH-FLOWS
           PERFORM 4000-IDENTIFY-GAPS
           PERFORM 5000-RECOMMEND-STRATEGY
           PERFORM 6000-DISPLAY-REPORT
           STOP RUN.
       1000-INITIALIZE.
           MOVE 2500000.00 TO WS-OPENING-BALANCE
           MOVE 0 TO WS-TOTAL-RECV
           MOVE 0 TO WS-TOTAL-PAY
           MOVE 0 TO WS-TOTAL-GAPS
           MOVE 0 TO WS-GAP-MONTHS
           MOVE 0 TO WS-MAX-GAP
           MOVE 999999999.99 TO WS-MIN-BALANCE.
       2000-LOAD-PROJECTIONS.
           MOVE 1800000.00 TO WS-MO-RECEIVABLE(1)
           MOVE 2200000.00 TO WS-MO-PAYABLE(1)
           MOVE 0.95 TO WS-MO-SEASONAL-ADJ(1)
           MOVE 2100000.00 TO WS-MO-RECEIVABLE(2)
           MOVE 1900000.00 TO WS-MO-PAYABLE(2)
           MOVE 0.97 TO WS-MO-SEASONAL-ADJ(2)
           MOVE 2400000.00 TO WS-MO-RECEIVABLE(3)
           MOVE 2100000.00 TO WS-MO-PAYABLE(3)
           MOVE 1.00 TO WS-MO-SEASONAL-ADJ(3)
           MOVE 2600000.00 TO WS-MO-RECEIVABLE(4)
           MOVE 2500000.00 TO WS-MO-PAYABLE(4)
           MOVE 1.05 TO WS-MO-SEASONAL-ADJ(4)
           MOVE 2200000.00 TO WS-MO-RECEIVABLE(5)
           MOVE 2800000.00 TO WS-MO-PAYABLE(5)
           MOVE 1.02 TO WS-MO-SEASONAL-ADJ(5)
           MOVE 1900000.00 TO WS-MO-RECEIVABLE(6)
           MOVE 3200000.00 TO WS-MO-PAYABLE(6)
           MOVE 0.90 TO WS-MO-SEASONAL-ADJ(6)
           MOVE 2000000.00 TO WS-MO-RECEIVABLE(7)
           MOVE 2100000.00 TO WS-MO-PAYABLE(7)
           MOVE 0.92 TO WS-MO-SEASONAL-ADJ(7)
           MOVE 2300000.00 TO WS-MO-RECEIVABLE(8)
           MOVE 2000000.00 TO WS-MO-PAYABLE(8)
           MOVE 0.98 TO WS-MO-SEASONAL-ADJ(8)
           MOVE 2700000.00 TO WS-MO-RECEIVABLE(9)
           MOVE 2300000.00 TO WS-MO-PAYABLE(9)
           MOVE 1.08 TO WS-MO-SEASONAL-ADJ(9)
           MOVE 3000000.00 TO WS-MO-RECEIVABLE(10)
           MOVE 2600000.00 TO WS-MO-PAYABLE(10)
           MOVE 1.12 TO WS-MO-SEASONAL-ADJ(10)
           MOVE 2800000.00 TO WS-MO-RECEIVABLE(11)
           MOVE 3500000.00 TO WS-MO-PAYABLE(11)
           MOVE 1.10 TO WS-MO-SEASONAL-ADJ(11)
           MOVE 3200000.00 TO WS-MO-RECEIVABLE(12)
           MOVE 3800000.00 TO WS-MO-PAYABLE(12)
           MOVE 1.15 TO WS-MO-SEASONAL-ADJ(12).
       3000-CALC-CASH-FLOWS.
           MOVE WS-OPENING-BALANCE TO WS-PREV-BALANCE
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > 12
               COMPUTE WS-ADJUSTED-RECV ROUNDED =
                   WS-MO-RECEIVABLE(WS-IDX) *
                   WS-MO-SEASONAL-ADJ(WS-IDX)
               COMPUTE WS-ADJUSTED-PAY ROUNDED =
                   WS-MO-PAYABLE(WS-IDX) *
                   WS-MO-SEASONAL-ADJ(WS-IDX)
               COMPUTE WS-MO-NET-FLOW(WS-IDX) =
                   WS-ADJUSTED-RECV - WS-ADJUSTED-PAY
               COMPUTE WS-MO-CUM-BALANCE(WS-IDX) =
                   WS-PREV-BALANCE +
                   WS-MO-NET-FLOW(WS-IDX)
               MOVE WS-MO-CUM-BALANCE(WS-IDX) TO
                   WS-PREV-BALANCE
               ADD WS-ADJUSTED-RECV TO WS-TOTAL-RECV
               ADD WS-ADJUSTED-PAY TO WS-TOTAL-PAY
               IF WS-MO-CUM-BALANCE(WS-IDX) <
                   WS-MIN-BALANCE
                   MOVE WS-MO-CUM-BALANCE(WS-IDX) TO
                       WS-MIN-BALANCE
               END-IF
           END-PERFORM.
       4000-IDENTIFY-GAPS.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > 12
               IF WS-MO-CUM-BALANCE(WS-IDX) <
                   WS-MIN-RESERVE
                   MOVE 'Y' TO WS-MO-GAP-FLAG(WS-IDX)
                   COMPUTE WS-MO-FUNDING-GAP(WS-IDX) =
                       WS-MIN-RESERVE -
                       WS-MO-CUM-BALANCE(WS-IDX)
                   ADD WS-MO-FUNDING-GAP(WS-IDX) TO
                       WS-TOTAL-GAPS
                   ADD 1 TO WS-GAP-MONTHS
                   IF WS-MO-FUNDING-GAP(WS-IDX) >
                       WS-MAX-GAP
                       MOVE WS-MO-FUNDING-GAP(WS-IDX) TO
                           WS-MAX-GAP
                   END-IF
               ELSE
                   MOVE 0 TO WS-MO-FUNDING-GAP(WS-IDX)
               END-IF
           END-PERFORM.
       5000-RECOMMEND-STRATEGY.
           EVALUATE TRUE
               WHEN WS-GAP-MONTHS = 0
                   MOVE 'NO ACTION NEEDED' TO
                       WS-FUNDING-STRATEGY
               WHEN WS-GAP-MONTHS <= 2
                   MOVE 'SHORT-TERM REVOLVER'
                       TO WS-FUNDING-STRATEGY
               WHEN WS-GAP-MONTHS <= 6
                   MOVE 'CREDIT FACILITY' TO
                       WS-FUNDING-STRATEGY
               WHEN OTHER
                   MOVE 'CAPITAL RAISE' TO
                       WS-FUNDING-STRATEGY
           END-EVALUATE.
       6000-DISPLAY-REPORT.
           DISPLAY '========================================='
           DISPLAY 'CASH FLOW PROJECTION REPORT'
           DISPLAY '========================================='
           DISPLAY 'OPENING BALANCE: ' WS-OPENING-BALANCE
           DISPLAY 'MIN RESERVE:     ' WS-MIN-RESERVE
           DISPLAY '-----------------------------------------'
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > 12
               DISPLAY 'MONTH ' WS-IDX
                   ' NET: ' WS-MO-NET-FLOW(WS-IDX)
                   ' BAL: ' WS-MO-CUM-BALANCE(WS-IDX)
               IF WS-HAS-GAP(WS-IDX)
                   DISPLAY '  *** GAP: '
                       WS-MO-FUNDING-GAP(WS-IDX)
               END-IF
           END-PERFORM
           DISPLAY '-----------------------------------------'
           DISPLAY 'TOTAL RECEIVABLE: ' WS-TOTAL-RECV
           DISPLAY 'TOTAL PAYABLE:    ' WS-TOTAL-PAY
           DISPLAY 'MIN BALANCE:      ' WS-MIN-BALANCE
           DISPLAY 'GAP MONTHS:       ' WS-GAP-MONTHS
           DISPLAY 'MAX GAP:          ' WS-MAX-GAP
           DISPLAY 'TOTAL GAPS:       ' WS-TOTAL-GAPS
           DISPLAY 'STRATEGY:         ' WS-FUNDING-STRATEGY
           DISPLAY '========================================='.
