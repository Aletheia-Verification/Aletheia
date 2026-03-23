       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-ODO-INVOICE-BATCH.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-VENDOR-ID            PIC X(10).
       01 WS-INVOICE-DATE         PIC 9(8).
       01 WS-LINE-COUNT           PIC 9(3).
       01 WS-LINE-ITEMS.
           05 WS-LINE OCCURS 1 TO 100 TIMES
               DEPENDING ON WS-LINE-COUNT.
               10 WS-LN-ITEM-CODE PIC X(8).
               10 WS-LN-DESC      PIC X(20).
               10 WS-LN-QTY       PIC 9(5).
               10 WS-LN-UNIT-PRICE PIC S9(5)V99 COMP-3.
               10 WS-LN-EXTENDED  PIC S9(7)V99 COMP-3.
               10 WS-LN-TAX-FLAG  PIC X.
                   88 IS-TAXABLE  VALUE 'Y'.
       01 WS-IDX                  PIC 9(3).
       01 WS-SUBTOTAL             PIC S9(9)V99 COMP-3.
       01 WS-TAX-TOTAL            PIC S9(7)V99 COMP-3.
       01 WS-GRAND-TOTAL          PIC S9(9)V99 COMP-3.
       01 WS-TAX-RATE             PIC S9(1)V9(4) COMP-3
           VALUE 0.0825.
       01 WS-LINE-TAX             PIC S9(5)V99 COMP-3.
       01 WS-DISCOUNT-PCT         PIC S9(1)V99 COMP-3.
       01 WS-DISCOUNT-AMT         PIC S9(7)V99 COMP-3.
       01 WS-INVOICE-NUM          PIC X(12).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-CALC-LINE-ITEMS
           PERFORM 3000-APPLY-DISCOUNT
           PERFORM 4000-CALC-TAX
           PERFORM 5000-OUTPUT
           STOP RUN.
       1000-INIT.
           MOVE 0 TO WS-SUBTOTAL
           MOVE 0 TO WS-TAX-TOTAL
           MOVE 0 TO WS-DISCOUNT-AMT
           ACCEPT WS-INVOICE-DATE FROM DATE YYYYMMDD.
       2000-CALC-LINE-ITEMS.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-LINE-COUNT
               COMPUTE WS-LN-EXTENDED(WS-IDX) =
                   WS-LN-QTY(WS-IDX) *
                   WS-LN-UNIT-PRICE(WS-IDX)
               ADD WS-LN-EXTENDED(WS-IDX) TO WS-SUBTOTAL
           END-PERFORM.
       3000-APPLY-DISCOUNT.
           IF WS-SUBTOTAL > 10000.00
               MOVE 0.05 TO WS-DISCOUNT-PCT
           ELSE
               IF WS-SUBTOTAL > 5000.00
                   MOVE 0.03 TO WS-DISCOUNT-PCT
               ELSE
                   MOVE 0 TO WS-DISCOUNT-PCT
               END-IF
           END-IF
           COMPUTE WS-DISCOUNT-AMT =
               WS-SUBTOTAL * WS-DISCOUNT-PCT
           SUBTRACT WS-DISCOUNT-AMT FROM WS-SUBTOTAL.
       4000-CALC-TAX.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-LINE-COUNT
               IF IS-TAXABLE(WS-IDX)
                   COMPUTE WS-LINE-TAX =
                       WS-LN-EXTENDED(WS-IDX) * WS-TAX-RATE
                   ADD WS-LINE-TAX TO WS-TAX-TOTAL
               END-IF
           END-PERFORM
           COMPUTE WS-GRAND-TOTAL =
               WS-SUBTOTAL + WS-TAX-TOTAL.
       5000-OUTPUT.
           DISPLAY 'INVOICE SUMMARY'
           DISPLAY '==============='
           DISPLAY 'INVOICE: ' WS-INVOICE-NUM
           DISPLAY 'VENDOR:  ' WS-VENDOR-ID
           DISPLAY 'DATE:    ' WS-INVOICE-DATE
           DISPLAY 'LINES:   ' WS-LINE-COUNT
           DISPLAY 'SUBTOTAL: $' WS-SUBTOTAL
           IF WS-DISCOUNT-AMT > 0
               DISPLAY 'DISCOUNT: $' WS-DISCOUNT-AMT
           END-IF
           DISPLAY 'TAX:      $' WS-TAX-TOTAL
           DISPLAY 'TOTAL:    $' WS-GRAND-TOTAL.
