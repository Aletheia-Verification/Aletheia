       IDENTIFICATION DIVISION.
       PROGRAM-ID. TAX-WITHOLD-CALC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-INCOME-DATA.
           05 WS-GROSS-INCOME        PIC S9(9)V99 COMP-3.
           05 WS-FILING-STATUS       PIC X(1).
               88 WS-SINGLE          VALUE 'S'.
               88 WS-MARRIED         VALUE 'M'.
               88 WS-HEAD-HOUSE      VALUE 'H'.
       01 WS-FED-TAX-FIELDS.
           05 WS-FED-TAXABLE         PIC S9(9)V99 COMP-3.
           05 WS-FED-TAX             PIC S9(7)V99 COMP-3.
           05 WS-STD-DEDUCTION       PIC S9(7)V99 COMP-3.
       01 WS-STATE-TAX-FIELDS.
           05 WS-STATE-CODE          PIC X(2).
           05 WS-STATE-RATE          PIC S9(1)V9(4) COMP-3.
           05 WS-STATE-TAX           PIC S9(7)V99 COMP-3.
       01 WS-TOTAL-WITHHELD          PIC S9(7)V99 COMP-3.
       01 WS-MONTHLY-WITHHOLD        PIC S9(5)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-SET-DEDUCTION
           PERFORM 3000-CALC-FED-TAX
           PERFORM 4000-CALC-STATE-TAX
           PERFORM 5000-CALC-MONTHLY
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-FED-TAX
           MOVE 0 TO WS-STATE-TAX
           MOVE 0 TO WS-TOTAL-WITHHELD.
       2000-SET-DEDUCTION.
           EVALUATE TRUE
               WHEN WS-SINGLE
                   MOVE 14600.00 TO WS-STD-DEDUCTION
               WHEN WS-MARRIED
                   MOVE 29200.00 TO WS-STD-DEDUCTION
               WHEN WS-HEAD-HOUSE
                   MOVE 21900.00 TO WS-STD-DEDUCTION
               WHEN OTHER
                   MOVE 14600.00 TO WS-STD-DEDUCTION
           END-EVALUATE
           COMPUTE WS-FED-TAXABLE =
               WS-GROSS-INCOME - WS-STD-DEDUCTION
           IF WS-FED-TAXABLE < 0
               MOVE 0 TO WS-FED-TAXABLE
           END-IF.
       3000-CALC-FED-TAX.
           EVALUATE TRUE
               WHEN WS-FED-TAXABLE <= 11600
                   COMPUTE WS-FED-TAX =
                       WS-FED-TAXABLE * 0.10
               WHEN WS-FED-TAXABLE <= 47150
                   COMPUTE WS-FED-TAX =
                       1160 + (WS-FED-TAXABLE - 11600)
                       * 0.12
               WHEN WS-FED-TAXABLE <= 100525
                   COMPUTE WS-FED-TAX =
                       5426 + (WS-FED-TAXABLE - 47150)
                       * 0.22
               WHEN WS-FED-TAXABLE <= 191950
                   COMPUTE WS-FED-TAX =
                       17168 + (WS-FED-TAXABLE - 100525)
                       * 0.24
               WHEN OTHER
                   COMPUTE WS-FED-TAX =
                       39110 + (WS-FED-TAXABLE - 191950)
                       * 0.32
           END-EVALUATE.
       4000-CALC-STATE-TAX.
           EVALUATE WS-STATE-CODE
               WHEN 'CA'
                   MOVE 0.0930 TO WS-STATE-RATE
               WHEN 'NY'
                   MOVE 0.0685 TO WS-STATE-RATE
               WHEN 'TX'
                   MOVE 0 TO WS-STATE-RATE
               WHEN 'FL'
                   MOVE 0 TO WS-STATE-RATE
               WHEN 'IL'
                   MOVE 0.0495 TO WS-STATE-RATE
               WHEN OTHER
                   MOVE 0.0500 TO WS-STATE-RATE
           END-EVALUATE
           COMPUTE WS-STATE-TAX =
               WS-FED-TAXABLE * WS-STATE-RATE.
       5000-CALC-MONTHLY.
           COMPUTE WS-TOTAL-WITHHELD =
               WS-FED-TAX + WS-STATE-TAX
           COMPUTE WS-MONTHLY-WITHHOLD =
               WS-TOTAL-WITHHELD / 12.
       6000-DISPLAY-RESULTS.
           DISPLAY 'TAX WITHHOLDING CALCULATION'
           DISPLAY '==========================='
           DISPLAY 'GROSS INCOME:   ' WS-GROSS-INCOME
           DISPLAY 'STD DEDUCTION:  ' WS-STD-DEDUCTION
           DISPLAY 'FED TAXABLE:    ' WS-FED-TAXABLE
           DISPLAY 'FED TAX:        ' WS-FED-TAX
           DISPLAY 'STATE TAX:      ' WS-STATE-TAX
           DISPLAY 'TOTAL ANNUAL:   ' WS-TOTAL-WITHHELD
           DISPLAY 'MONTHLY:        ' WS-MONTHLY-WITHHOLD.
