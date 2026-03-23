       IDENTIFICATION DIVISION.
       PROGRAM-ID. PAYROLL-TAX-ENGINE.
      *================================================================*
      * PAYROLL TAX CALCULATION ENGINE                                 *
      * Computes federal, state, FICA, Medicare taxes from gross pay.  *
      * Handles YTD limits, pre-tax deductions, and multiple brackets. *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-EMPLOYEE.
           05 WS-EMP-ID             PIC X(10).
           05 WS-EMP-NAME           PIC X(30).
           05 WS-FILING-STATUS      PIC X(1).
               88 WS-SINGLE         VALUE 'S'.
               88 WS-MARRIED        VALUE 'M'.
               88 WS-HEAD-HOUSE     VALUE 'H'.
           05 WS-ALLOWANCES         PIC S9(2) COMP-3.
           05 WS-STATE-CODE         PIC X(2).
           05 WS-PAY-FREQUENCY      PIC X(1).
               88 WS-WEEKLY         VALUE 'W'.
               88 WS-BIWEEKLY       VALUE 'B'.
               88 WS-SEMIMONTHLY    VALUE 'S'.
               88 WS-MONTHLY        VALUE 'M'.
       01 WS-PAY-DATA.
           05 WS-GROSS-PAY          PIC S9(7)V99 COMP-3.
           05 WS-PRE-TAX-401K      PIC S9(7)V99 COMP-3.
           05 WS-PRE-TAX-HSA       PIC S9(5)V99 COMP-3.
           05 WS-PRE-TAX-DENTAL    PIC S9(5)V99 COMP-3.
           05 WS-TAXABLE-GROSS      PIC S9(7)V99 COMP-3.
       01 WS-YTD-DATA.
           05 WS-YTD-GROSS          PIC S9(9)V99 COMP-3.
           05 WS-YTD-FED-TAX        PIC S9(9)V99 COMP-3.
           05 WS-YTD-STATE-TAX      PIC S9(9)V99 COMP-3.
           05 WS-YTD-FICA           PIC S9(9)V99 COMP-3.
           05 WS-YTD-MEDICARE       PIC S9(9)V99 COMP-3.
       01 WS-LIMITS.
           05 WS-FICA-LIMIT         PIC S9(9)V99 COMP-3
               VALUE 168600.00.
           05 WS-MEDICARE-ADDL-LIM  PIC S9(9)V99 COMP-3
               VALUE 200000.00.
           05 WS-401K-ANNUAL-LIM   PIC S9(7)V99 COMP-3
               VALUE 23500.00.
       01 WS-RATES.
           05 WS-FICA-RATE          PIC S9(1)V9(4) COMP-3
               VALUE 0.0620.
           05 WS-MED-RATE           PIC S9(1)V9(4) COMP-3
               VALUE 0.0145.
           05 WS-MED-ADDL-RATE      PIC S9(1)V9(4) COMP-3
               VALUE 0.0090.
       01 WS-CURRENT-TAXES.
           05 WS-FED-TAX            PIC S9(7)V99 COMP-3.
           05 WS-STATE-TAX          PIC S9(7)V99 COMP-3.
           05 WS-FICA-TAX           PIC S9(7)V99 COMP-3.
           05 WS-MED-TAX            PIC S9(7)V99 COMP-3.
           05 WS-TOTAL-TAX          PIC S9(7)V99 COMP-3.
           05 WS-NET-PAY            PIC S9(7)V99 COMP-3.
       01 WS-FED-BRACKET-AMT       PIC S9(7)V99 COMP-3.
       01 WS-ANNUAL-TAXABLE        PIC S9(9)V99 COMP-3.
       01 WS-PERIODS-PER-YEAR      PIC S9(2) COMP-3.
       01 WS-PER-ALLOW-DEDUCT      PIC S9(7)V99 COMP-3.
       01 WS-FICA-REMAINING        PIC S9(9)V99 COMP-3.
       01 WS-FICA-SUBJECT          PIC S9(7)V99 COMP-3.
       01 WS-MED-ADDL-SUBJECT      PIC S9(7)V99 COMP-3.
       01 WS-TOTAL-DEDUCTIONS      PIC S9(7)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-TAXABLE-GROSS
           PERFORM 3000-CALC-FEDERAL-TAX
           PERFORM 4000-CALC-STATE-TAX
           PERFORM 5000-CALC-FICA
           PERFORM 6000-CALC-MEDICARE
           PERFORM 7000-CALC-NET-PAY
           PERFORM 8000-UPDATE-YTD
           PERFORM 9000-DISPLAY-STUB
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'EMP0001234' TO WS-EMP-ID
           MOVE 'ROBERTSON, JAMES A' TO WS-EMP-NAME
           MOVE 'M' TO WS-FILING-STATUS
           MOVE 3 TO WS-ALLOWANCES
           MOVE 'CA' TO WS-STATE-CODE
           MOVE 'B' TO WS-PAY-FREQUENCY
           MOVE 5000.00 TO WS-GROSS-PAY
           MOVE 375.00 TO WS-PRE-TAX-401K
           MOVE 125.00 TO WS-PRE-TAX-HSA
           MOVE 45.00 TO WS-PRE-TAX-DENTAL
           MOVE 115000.00 TO WS-YTD-GROSS
           MOVE 18500.00 TO WS-YTD-FED-TAX
           MOVE 6200.00 TO WS-YTD-STATE-TAX
           MOVE 7130.00 TO WS-YTD-FICA
           MOVE 1667.50 TO WS-YTD-MEDICARE
           MOVE 0 TO WS-FED-TAX
           MOVE 0 TO WS-STATE-TAX
           MOVE 0 TO WS-FICA-TAX
           MOVE 0 TO WS-MED-TAX.
       2000-CALC-TAXABLE-GROSS.
           COMPUTE WS-TOTAL-DEDUCTIONS =
               WS-PRE-TAX-401K + WS-PRE-TAX-HSA +
               WS-PRE-TAX-DENTAL
           COMPUTE WS-TAXABLE-GROSS =
               WS-GROSS-PAY - WS-TOTAL-DEDUCTIONS
           EVALUATE TRUE
               WHEN WS-WEEKLY
                   MOVE 52 TO WS-PERIODS-PER-YEAR
               WHEN WS-BIWEEKLY
                   MOVE 26 TO WS-PERIODS-PER-YEAR
               WHEN WS-SEMIMONTHLY
                   MOVE 24 TO WS-PERIODS-PER-YEAR
               WHEN WS-MONTHLY
                   MOVE 12 TO WS-PERIODS-PER-YEAR
           END-EVALUATE
           COMPUTE WS-PER-ALLOW-DEDUCT ROUNDED =
               4300 / WS-PERIODS-PER-YEAR
           COMPUTE WS-ANNUAL-TAXABLE ROUNDED =
               (WS-TAXABLE-GROSS -
               (WS-ALLOWANCES * WS-PER-ALLOW-DEDUCT)) *
               WS-PERIODS-PER-YEAR.
       3000-CALC-FEDERAL-TAX.
           IF WS-MARRIED
               EVALUATE TRUE
                   WHEN WS-ANNUAL-TAXABLE <= 23200
                       COMPUTE WS-FED-BRACKET-AMT ROUNDED =
                           WS-ANNUAL-TAXABLE * 0.10
                   WHEN WS-ANNUAL-TAXABLE <= 94300
                       COMPUTE WS-FED-BRACKET-AMT ROUNDED =
                           2320.00 + (WS-ANNUAL-TAXABLE
                           - 23200) * 0.12
                   WHEN WS-ANNUAL-TAXABLE <= 201050
                       COMPUTE WS-FED-BRACKET-AMT ROUNDED =
                           10852.00 + (WS-ANNUAL-TAXABLE
                           - 94300) * 0.22
                   WHEN WS-ANNUAL-TAXABLE <= 383900
                       COMPUTE WS-FED-BRACKET-AMT ROUNDED =
                           34337.00 + (WS-ANNUAL-TAXABLE
                           - 201050) * 0.24
                   WHEN OTHER
                       COMPUTE WS-FED-BRACKET-AMT ROUNDED =
                           78221.00 + (WS-ANNUAL-TAXABLE
                           - 383900) * 0.32
               END-EVALUATE
           ELSE
               EVALUATE TRUE
                   WHEN WS-ANNUAL-TAXABLE <= 11600
                       COMPUTE WS-FED-BRACKET-AMT ROUNDED =
                           WS-ANNUAL-TAXABLE * 0.10
                   WHEN WS-ANNUAL-TAXABLE <= 47150
                       COMPUTE WS-FED-BRACKET-AMT ROUNDED =
                           1160.00 + (WS-ANNUAL-TAXABLE
                           - 11600) * 0.12
                   WHEN WS-ANNUAL-TAXABLE <= 100525
                       COMPUTE WS-FED-BRACKET-AMT ROUNDED =
                           5426.00 + (WS-ANNUAL-TAXABLE
                           - 47150) * 0.22
                   WHEN OTHER
                       COMPUTE WS-FED-BRACKET-AMT ROUNDED =
                           17168.50 + (WS-ANNUAL-TAXABLE
                           - 100525) * 0.24
               END-EVALUATE
           END-IF
           COMPUTE WS-FED-TAX ROUNDED =
               WS-FED-BRACKET-AMT / WS-PERIODS-PER-YEAR
           IF WS-FED-TAX < 0
               MOVE 0 TO WS-FED-TAX
           END-IF.
       4000-CALC-STATE-TAX.
           EVALUATE WS-STATE-CODE
               WHEN 'CA'
                   COMPUTE WS-STATE-TAX ROUNDED =
                       WS-TAXABLE-GROSS * 0.0725
               WHEN 'NY'
                   COMPUTE WS-STATE-TAX ROUNDED =
                       WS-TAXABLE-GROSS * 0.0685
               WHEN 'TX'
                   MOVE 0 TO WS-STATE-TAX
               WHEN 'FL'
                   MOVE 0 TO WS-STATE-TAX
               WHEN 'IL'
                   COMPUTE WS-STATE-TAX ROUNDED =
                       WS-TAXABLE-GROSS * 0.0495
               WHEN OTHER
                   COMPUTE WS-STATE-TAX ROUNDED =
                       WS-TAXABLE-GROSS * 0.0500
           END-EVALUATE.
       5000-CALC-FICA.
           COMPUTE WS-FICA-REMAINING =
               WS-FICA-LIMIT - WS-YTD-GROSS
           IF WS-FICA-REMAINING > 0
               IF WS-GROSS-PAY <= WS-FICA-REMAINING
                   MOVE WS-GROSS-PAY TO WS-FICA-SUBJECT
               ELSE
                   MOVE WS-FICA-REMAINING TO
                       WS-FICA-SUBJECT
               END-IF
               COMPUTE WS-FICA-TAX ROUNDED =
                   WS-FICA-SUBJECT * WS-FICA-RATE
           ELSE
               MOVE 0 TO WS-FICA-TAX
           END-IF.
       6000-CALC-MEDICARE.
           COMPUTE WS-MED-TAX ROUNDED =
               WS-GROSS-PAY * WS-MED-RATE
           COMPUTE WS-MED-ADDL-SUBJECT =
               WS-YTD-GROSS + WS-GROSS-PAY -
               WS-MEDICARE-ADDL-LIM
           IF WS-MED-ADDL-SUBJECT > 0
               IF WS-MED-ADDL-SUBJECT > WS-GROSS-PAY
                   ADD WS-GROSS-PAY * WS-MED-ADDL-RATE
                       TO WS-MED-TAX
               ELSE
                   ADD WS-MED-ADDL-SUBJECT *
                       WS-MED-ADDL-RATE TO WS-MED-TAX
               END-IF
           END-IF.
       7000-CALC-NET-PAY.
           COMPUTE WS-TOTAL-TAX =
               WS-FED-TAX + WS-STATE-TAX +
               WS-FICA-TAX + WS-MED-TAX
           COMPUTE WS-NET-PAY =
               WS-GROSS-PAY - WS-TOTAL-DEDUCTIONS -
               WS-TOTAL-TAX.
       8000-UPDATE-YTD.
           ADD WS-GROSS-PAY TO WS-YTD-GROSS
           ADD WS-FED-TAX TO WS-YTD-FED-TAX
           ADD WS-STATE-TAX TO WS-YTD-STATE-TAX
           ADD WS-FICA-TAX TO WS-YTD-FICA
           ADD WS-MED-TAX TO WS-YTD-MEDICARE.
       9000-DISPLAY-STUB.
           DISPLAY '========================================='
           DISPLAY 'PAY STUB'
           DISPLAY '========================================='
           DISPLAY 'EMPLOYEE:        ' WS-EMP-NAME
           DISPLAY 'ID:              ' WS-EMP-ID
           DISPLAY 'FILING:          ' WS-FILING-STATUS
           DISPLAY '----- CURRENT PERIOD -----'
           DISPLAY 'GROSS PAY:       ' WS-GROSS-PAY
           DISPLAY '401K:            ' WS-PRE-TAX-401K
           DISPLAY 'HSA:             ' WS-PRE-TAX-HSA
           DISPLAY 'DENTAL:          ' WS-PRE-TAX-DENTAL
           DISPLAY 'TAXABLE GROSS:   ' WS-TAXABLE-GROSS
           DISPLAY 'FEDERAL TAX:     ' WS-FED-TAX
           DISPLAY 'STATE TAX:       ' WS-STATE-TAX
           DISPLAY 'FICA:            ' WS-FICA-TAX
           DISPLAY 'MEDICARE:        ' WS-MED-TAX
           DISPLAY 'TOTAL TAX:       ' WS-TOTAL-TAX
           DISPLAY 'NET PAY:         ' WS-NET-PAY
           DISPLAY '----- YEAR TO DATE -----'
           DISPLAY 'YTD GROSS:       ' WS-YTD-GROSS
           DISPLAY 'YTD FED TAX:     ' WS-YTD-FED-TAX
           DISPLAY 'YTD STATE TAX:   ' WS-YTD-STATE-TAX
           DISPLAY 'YTD FICA:        ' WS-YTD-FICA
           DISPLAY 'YTD MEDICARE:    ' WS-YTD-MEDICARE
           DISPLAY '========================================='.
