       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-ODO-INVOICE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-INVOICE-HEADER.
           05 WS-INV-NUM             PIC X(10).
           05 WS-CUST-NAME           PIC X(30).
           05 WS-INV-DATE            PIC 9(8).
           05 WS-LINE-COUNT          PIC 9(2).
       01 WS-LINE-TABLE.
           05 WS-INV-LINE OCCURS 1 TO 50 TIMES
               DEPENDING ON WS-LINE-COUNT.
               10 WS-IL-ITEM         PIC X(20).
               10 WS-IL-QTY          PIC 9(5).
               10 WS-IL-PRICE        PIC S9(7)V99 COMP-3.
               10 WS-IL-AMOUNT       PIC S9(9)V99 COMP-3.
               10 WS-IL-TAX-FLAG     PIC X(1).
                   88 WS-IL-TAXABLE  VALUE 'Y'.
                   88 WS-IL-EXEMPT   VALUE 'N'.
       01 WS-IDX                     PIC 9(2).
       01 WS-CALC-FIELDS.
           05 WS-SUBTOTAL            PIC S9(11)V99 COMP-3.
           05 WS-TAX-TOTAL           PIC S9(7)V99 COMP-3.
           05 WS-TAX-RATE            PIC S9(1)V9(4) COMP-3
               VALUE 0.0825.
           05 WS-DISCOUNT-PCT        PIC S9(1)V9(4) COMP-3.
           05 WS-DISCOUNT-AMT        PIC S9(7)V99 COMP-3.
           05 WS-GRAND-TOTAL         PIC S9(11)V99 COMP-3.
           05 WS-TAXABLE-AMT         PIC S9(11)V99 COMP-3.
       01 WS-CUST-TIER               PIC X(1).
           88 WS-TIER-A              VALUE 'A'.
           88 WS-TIER-B              VALUE 'B'.
           88 WS-TIER-C              VALUE 'C'.
       01 WS-SUMMARY-LINE            PIC X(80).
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           IF WS-LINE-COUNT > 0
               PERFORM 2000-CALC-LINE-AMOUNTS
               PERFORM 3000-APPLY-DISCOUNT
               PERFORM 4000-CALC-TAX
               PERFORM 5000-CALC-GRAND-TOTAL
               PERFORM 6000-BUILD-SUMMARY
           END-IF
           PERFORM 7000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-SUBTOTAL
           MOVE 0 TO WS-TAX-TOTAL
           MOVE 0 TO WS-DISCOUNT-AMT
           MOVE 0 TO WS-TAXABLE-AMT.
       2000-CALC-LINE-AMOUNTS.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-LINE-COUNT
               COMPUTE WS-IL-AMOUNT(WS-IDX) =
                   WS-IL-QTY(WS-IDX) *
                   WS-IL-PRICE(WS-IDX)
               ADD WS-IL-AMOUNT(WS-IDX) TO WS-SUBTOTAL
               IF WS-IL-TAXABLE(WS-IDX)
                   ADD WS-IL-AMOUNT(WS-IDX) TO
                       WS-TAXABLE-AMT
               END-IF
           END-PERFORM.
       3000-APPLY-DISCOUNT.
           EVALUATE TRUE
               WHEN WS-TIER-A
                   MOVE 0.1500 TO WS-DISCOUNT-PCT
               WHEN WS-TIER-B
                   MOVE 0.1000 TO WS-DISCOUNT-PCT
               WHEN WS-TIER-C
                   MOVE 0.0500 TO WS-DISCOUNT-PCT
               WHEN OTHER
                   MOVE 0 TO WS-DISCOUNT-PCT
           END-EVALUATE
           COMPUTE WS-DISCOUNT-AMT =
               WS-SUBTOTAL * WS-DISCOUNT-PCT
           SUBTRACT WS-DISCOUNT-AMT FROM WS-SUBTOTAL.
       4000-CALC-TAX.
           IF WS-TAXABLE-AMT > 0
               COMPUTE WS-TAX-TOTAL =
                   WS-TAXABLE-AMT * WS-TAX-RATE
           END-IF.
       5000-CALC-GRAND-TOTAL.
           COMPUTE WS-GRAND-TOTAL =
               WS-SUBTOTAL + WS-TAX-TOTAL.
       6000-BUILD-SUMMARY.
           STRING 'INV ' DELIMITED BY SIZE
                  WS-INV-NUM DELIMITED BY SIZE
                  ' LINES=' DELIMITED BY SIZE
                  WS-LINE-COUNT DELIMITED BY SIZE
                  ' TOTAL=' DELIMITED BY SIZE
                  WS-GRAND-TOTAL DELIMITED BY SIZE
                  INTO WS-SUMMARY-LINE
           END-STRING.
       7000-DISPLAY-RESULTS.
           DISPLAY 'ODO INVOICE REPORT'
           DISPLAY '=================='
           DISPLAY 'INVOICE:     ' WS-INV-NUM
           DISPLAY 'CUSTOMER:    ' WS-CUST-NAME
           DISPLAY 'LINES:       ' WS-LINE-COUNT
           DISPLAY 'SUBTOTAL:    ' WS-SUBTOTAL
           DISPLAY 'DISCOUNT:    ' WS-DISCOUNT-AMT
           DISPLAY 'TAX:         ' WS-TAX-TOTAL
           DISPLAY 'GRAND TOTAL: ' WS-GRAND-TOTAL
           DISPLAY 'SUMMARY: ' WS-SUMMARY-LINE
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-LINE-COUNT
               DISPLAY '  LINE ' WS-IDX
                   ' ITEM=' WS-IL-ITEM(WS-IDX)
                   ' QTY=' WS-IL-QTY(WS-IDX)
                   ' AMT=' WS-IL-AMOUNT(WS-IDX)
           END-PERFORM.
