       IDENTIFICATION DIVISION.
       PROGRAM-ID. TRADE-TAX-LOT-CALC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-SELL-DATA.
           05 WS-SELL-QTY            PIC S9(7) COMP-3.
           05 WS-SELL-PRICE          PIC S9(7)V99 COMP-3.
           05 WS-SELL-PROCEEDS       PIC S9(11)V99 COMP-3.
       01 WS-LOT-TABLE.
           05 WS-LOT OCCURS 20.
               10 WS-LT-DATE         PIC 9(8).
               10 WS-LT-QTY          PIC S9(7) COMP-3.
               10 WS-LT-COST         PIC S9(7)V99 COMP-3.
               10 WS-LT-SOLD         PIC S9(7) COMP-3.
               10 WS-LT-GAIN         PIC S9(9)V99 COMP-3.
               10 WS-LT-TERM         PIC X(1).
                   88 WS-LT-SHORT    VALUE 'S'.
                   88 WS-LT-LONG     VALUE 'L'.
       01 WS-LT-IDX                  PIC 9(2).
       01 WS-LOT-COUNT               PIC 9(2).
       01 WS-REMAINING-QTY           PIC S9(7) COMP-3.
       01 WS-ALLOC-QTY               PIC S9(7) COMP-3.
       01 WS-COST-BASIS              PIC S9(11)V99 COMP-3.
       01 WS-TOTAL-GAIN              PIC S9(11)V99 COMP-3.
       01 WS-SHORT-GAIN              PIC S9(11)V99 COMP-3.
       01 WS-LONG-GAIN               PIC S9(11)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-PROCEEDS
           PERFORM 3000-ALLOCATE-FIFO
           PERFORM 4000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-COST-BASIS
           MOVE 0 TO WS-TOTAL-GAIN
           MOVE 0 TO WS-SHORT-GAIN
           MOVE 0 TO WS-LONG-GAIN.
       2000-CALC-PROCEEDS.
           COMPUTE WS-SELL-PROCEEDS =
               WS-SELL-QTY * WS-SELL-PRICE.
       3000-ALLOCATE-FIFO.
           MOVE WS-SELL-QTY TO WS-REMAINING-QTY
           PERFORM VARYING WS-LT-IDX FROM 1 BY 1
               UNTIL WS-LT-IDX > WS-LOT-COUNT
               OR WS-REMAINING-QTY <= 0
               COMPUTE WS-ALLOC-QTY =
                   WS-LT-QTY(WS-LT-IDX) -
                   WS-LT-SOLD(WS-LT-IDX)
               IF WS-ALLOC-QTY > WS-REMAINING-QTY
                   MOVE WS-REMAINING-QTY TO WS-ALLOC-QTY
               END-IF
               IF WS-ALLOC-QTY > 0
                   ADD WS-ALLOC-QTY TO
                       WS-LT-SOLD(WS-LT-IDX)
                   COMPUTE WS-LT-GAIN(WS-LT-IDX) =
                       WS-ALLOC-QTY *
                       (WS-SELL-PRICE -
                       WS-LT-COST(WS-LT-IDX))
                   ADD WS-LT-GAIN(WS-LT-IDX) TO
                       WS-TOTAL-GAIN
                   COMPUTE WS-COST-BASIS =
                       WS-COST-BASIS +
                       (WS-ALLOC-QTY *
                       WS-LT-COST(WS-LT-IDX))
                   IF WS-LT-LONG(WS-LT-IDX)
                       ADD WS-LT-GAIN(WS-LT-IDX) TO
                           WS-LONG-GAIN
                   ELSE
                       ADD WS-LT-GAIN(WS-LT-IDX) TO
                           WS-SHORT-GAIN
                   END-IF
                   SUBTRACT WS-ALLOC-QTY FROM
                       WS-REMAINING-QTY
               END-IF
           END-PERFORM.
       4000-DISPLAY-RESULTS.
           DISPLAY 'TAX LOT CALCULATION (FIFO)'
           DISPLAY '=========================='
           DISPLAY 'SELL QTY:      ' WS-SELL-QTY
           DISPLAY 'SELL PRICE:    ' WS-SELL-PRICE
           DISPLAY 'PROCEEDS:      ' WS-SELL-PROCEEDS
           DISPLAY 'COST BASIS:    ' WS-COST-BASIS
           DISPLAY 'TOTAL GAIN:    ' WS-TOTAL-GAIN
           DISPLAY 'SHORT-TERM:    ' WS-SHORT-GAIN
           DISPLAY 'LONG-TERM:     ' WS-LONG-GAIN
           PERFORM VARYING WS-LT-IDX FROM 1 BY 1
               UNTIL WS-LT-IDX > WS-LOT-COUNT
               IF WS-LT-SOLD(WS-LT-IDX) > 0
                   DISPLAY '  LOT ' WS-LT-IDX
                       ' SOLD=' WS-LT-SOLD(WS-LT-IDX)
                       ' GAIN=' WS-LT-GAIN(WS-LT-IDX)
                       ' TERM=' WS-LT-TERM(WS-LT-IDX)
               END-IF
           END-PERFORM.
