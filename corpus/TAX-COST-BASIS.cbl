       IDENTIFICATION DIVISION.
       PROGRAM-ID. TAX-COST-BASIS.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-SECURITY-ID             PIC X(10).
       01 WS-LOT-TABLE.
           05 WS-LOT OCCURS 10.
               10 WS-LT-DATE         PIC 9(8).
               10 WS-LT-QTY          PIC S9(7) COMP-3.
               10 WS-LT-PRICE        PIC S9(7)V99 COMP-3.
               10 WS-LT-COST         PIC S9(9)V99 COMP-3.
               10 WS-LT-ADJ-COST     PIC S9(9)V99 COMP-3.
       01 WS-LT-IDX                  PIC 9(2).
       01 WS-LOT-COUNT               PIC 9(2).
       01 WS-TOTAL-QTY               PIC S9(9) COMP-3.
       01 WS-TOTAL-COST              PIC S9(11)V99 COMP-3.
       01 WS-AVG-COST                PIC S9(7)V99 COMP-3.
       01 WS-CURRENT-PRICE           PIC S9(7)V99 COMP-3.
       01 WS-MARKET-VALUE            PIC S9(11)V99 COMP-3.
       01 WS-UNREALIZED-GAIN         PIC S9(11)V99 COMP-3.
       01 WS-WASH-SALE-ADJ           PIC S9(7)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-LOTS
           PERFORM 3000-CALC-AVG-COST
           PERFORM 4000-CALC-UNREALIZED
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-QTY
           MOVE 0 TO WS-TOTAL-COST
           MOVE 0 TO WS-WASH-SALE-ADJ.
       2000-CALC-LOTS.
           PERFORM VARYING WS-LT-IDX FROM 1 BY 1
               UNTIL WS-LT-IDX > WS-LOT-COUNT
               COMPUTE WS-LT-COST(WS-LT-IDX) =
                   WS-LT-QTY(WS-LT-IDX) *
                   WS-LT-PRICE(WS-LT-IDX)
               COMPUTE WS-LT-ADJ-COST(WS-LT-IDX) =
                   WS-LT-COST(WS-LT-IDX) +
                   WS-WASH-SALE-ADJ
               ADD WS-LT-QTY(WS-LT-IDX) TO WS-TOTAL-QTY
               ADD WS-LT-ADJ-COST(WS-LT-IDX) TO
                   WS-TOTAL-COST
           END-PERFORM.
       3000-CALC-AVG-COST.
           IF WS-TOTAL-QTY > 0
               COMPUTE WS-AVG-COST =
                   WS-TOTAL-COST / WS-TOTAL-QTY
           END-IF.
       4000-CALC-UNREALIZED.
           COMPUTE WS-MARKET-VALUE =
               WS-TOTAL-QTY * WS-CURRENT-PRICE
           COMPUTE WS-UNREALIZED-GAIN =
               WS-MARKET-VALUE - WS-TOTAL-COST.
       5000-DISPLAY-RESULTS.
           DISPLAY 'COST BASIS REPORT'
           DISPLAY '================='
           DISPLAY 'SECURITY:        ' WS-SECURITY-ID
           DISPLAY 'TOTAL QTY:       ' WS-TOTAL-QTY
           DISPLAY 'TOTAL COST:      ' WS-TOTAL-COST
           DISPLAY 'AVG COST:        ' WS-AVG-COST
           DISPLAY 'MARKET VALUE:    ' WS-MARKET-VALUE
           DISPLAY 'UNREALIZED GAIN: ' WS-UNREALIZED-GAIN
           PERFORM VARYING WS-LT-IDX FROM 1 BY 1
               UNTIL WS-LT-IDX > WS-LOT-COUNT
               DISPLAY '  LOT ' WS-LT-IDX
                   ' QTY=' WS-LT-QTY(WS-LT-IDX)
                   ' COST=' WS-LT-ADJ-COST(WS-LT-IDX)
           END-PERFORM.
