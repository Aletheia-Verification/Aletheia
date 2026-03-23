       IDENTIFICATION DIVISION.
       PROGRAM-ID. INS-SURR-VALUE.
      *================================================================
      * INSURANCE SURRENDER VALUE CALCULATOR
      * Computes cash surrender value for whole life and universal
      * life policies including MVA and surrender charges.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-POLICY.
           05 WS-POL-NUM              PIC X(12).
           05 WS-POL-TYPE             PIC X(1).
               88 PT-WHOLE-LIFE       VALUE 'W'.
               88 PT-UNIVERSAL        VALUE 'U'.
               88 PT-VARIABLE         VALUE 'V'.
           05 WS-POL-ISSUE-DATE       PIC 9(8).
           05 WS-POL-FACE-AMT         PIC S9(9)V99 COMP-3.
           05 WS-POL-CASH-VALUE       PIC S9(9)V99 COMP-3.
           05 WS-POL-PREMIUMS-PAID    PIC S9(9)V99 COMP-3.
           05 WS-POL-LOAN-BAL         PIC S9(9)V99 COMP-3.
           05 WS-POL-LOAN-INT-RATE    PIC S9(1)V9(4) COMP-3
               VALUE 0.0500.
           05 WS-POL-DIVID-ACCUM      PIC S9(7)V99 COMP-3.
       01 WS-SURR-CHARGE-TABLE.
           05 WS-SC-RATE OCCURS 10 TIMES
                                       PIC S9(1)V99 COMP-3.
       01 WS-CALC.
           05 WS-YEARS-IN-FORCE       PIC 9(3).
           05 WS-SURR-CHARGE-RATE     PIC S9(1)V99 COMP-3.
           05 WS-SURR-CHARGE-AMT      PIC S9(7)V99 COMP-3.
           05 WS-MVA-RATE             PIC S9(3)V9(4) COMP-3.
           05 WS-MVA-FACTOR           PIC S9(1)V9(6) COMP-3.
           05 WS-MVA-ADJUSTMENT       PIC S9(7)V99 COMP-3.
           05 WS-GROSS-CSV            PIC S9(9)V99 COMP-3.
           05 WS-NET-CSV              PIC S9(9)V99 COMP-3.
           05 WS-LOAN-OFFSET          PIC S9(9)V99 COMP-3.
           05 WS-ACCRUED-LOAN-INT     PIC S9(7)V99 COMP-3.
           05 WS-GAIN-ON-SURRENDER    PIC S9(9)V99 COMP-3.
           05 WS-TAX-BASIS            PIC S9(9)V99 COMP-3.
       01 WS-CURRENT-INT-RATE         PIC S9(1)V9(4) COMP-3
           VALUE 0.0450.
       01 WS-ISSUE-INT-RATE           PIC S9(1)V9(4) COMP-3
           VALUE 0.0350.
       01 WS-CURRENT-DATE             PIC 9(8).
       01 WS-IDX                      PIC 9(2).
       01 WS-SC-YEAR                  PIC 9(2).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-YEARS
           PERFORM 3000-CALC-SURR-CHARGE
           PERFORM 4000-CALC-MVA
           PERFORM 5000-CALC-GROSS-CSV
           PERFORM 6000-APPLY-LOAN-OFFSET
           PERFORM 7000-CALC-TAX-IMPACT
           PERFORM 8000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           MOVE 'POL-WL-99001' TO WS-POL-NUM
           MOVE 'W' TO WS-POL-TYPE
           MOVE 20150601 TO WS-POL-ISSUE-DATE
           MOVE 500000.00 TO WS-POL-FACE-AMT
           MOVE 125000.00 TO WS-POL-CASH-VALUE
           MOVE 95000.00 TO WS-POL-PREMIUMS-PAID
           MOVE 30000.00 TO WS-POL-LOAN-BAL
           MOVE 8500.00 TO WS-POL-DIVID-ACCUM
           MOVE 0.10 TO WS-SC-RATE(1)
           MOVE 0.09 TO WS-SC-RATE(2)
           MOVE 0.08 TO WS-SC-RATE(3)
           MOVE 0.07 TO WS-SC-RATE(4)
           MOVE 0.06 TO WS-SC-RATE(5)
           MOVE 0.05 TO WS-SC-RATE(6)
           MOVE 0.04 TO WS-SC-RATE(7)
           MOVE 0.03 TO WS-SC-RATE(8)
           MOVE 0.02 TO WS-SC-RATE(9)
           MOVE 0.01 TO WS-SC-RATE(10).
       2000-CALC-YEARS.
           COMPUTE WS-YEARS-IN-FORCE =
               (WS-CURRENT-DATE - WS-POL-ISSUE-DATE)
               / 10000.
       3000-CALC-SURR-CHARGE.
           IF WS-YEARS-IN-FORCE > 10
               MOVE 0 TO WS-SURR-CHARGE-RATE
           ELSE
               IF WS-YEARS-IN-FORCE < 1
                   MOVE WS-SC-RATE(1) TO WS-SURR-CHARGE-RATE
               ELSE
                   MOVE WS-YEARS-IN-FORCE TO WS-SC-YEAR
                   IF WS-SC-YEAR < 1
                       MOVE 1 TO WS-SC-YEAR
                   END-IF
                   MOVE WS-SC-RATE(WS-SC-YEAR)
                       TO WS-SURR-CHARGE-RATE
               END-IF
           END-IF
           COMPUTE WS-SURR-CHARGE-AMT =
               WS-POL-CASH-VALUE * WS-SURR-CHARGE-RATE.
       4000-CALC-MVA.
           IF PT-UNIVERSAL OR PT-VARIABLE
               COMPUTE WS-MVA-RATE =
                   WS-CURRENT-INT-RATE - WS-ISSUE-INT-RATE
               COMPUTE WS-MVA-FACTOR =
                   1.0000 - (WS-MVA-RATE * 0.5000)
               COMPUTE WS-MVA-ADJUSTMENT =
                   WS-POL-CASH-VALUE *
                   (WS-MVA-FACTOR - 1.0000)
           ELSE
               MOVE 0 TO WS-MVA-ADJUSTMENT
               MOVE 1.0000 TO WS-MVA-FACTOR
           END-IF.
       5000-CALC-GROSS-CSV.
           COMPUTE WS-GROSS-CSV =
               WS-POL-CASH-VALUE
               + WS-POL-DIVID-ACCUM
               + WS-MVA-ADJUSTMENT
               - WS-SURR-CHARGE-AMT
           IF WS-GROSS-CSV < 0
               MOVE 0 TO WS-GROSS-CSV
           END-IF.
       6000-APPLY-LOAN-OFFSET.
           COMPUTE WS-ACCRUED-LOAN-INT =
               WS-POL-LOAN-BAL * WS-POL-LOAN-INT-RATE
           COMPUTE WS-LOAN-OFFSET =
               WS-POL-LOAN-BAL + WS-ACCRUED-LOAN-INT
           COMPUTE WS-NET-CSV =
               WS-GROSS-CSV - WS-LOAN-OFFSET
           IF WS-NET-CSV < 0
               MOVE 0 TO WS-NET-CSV
           END-IF.
       7000-CALC-TAX-IMPACT.
           MOVE WS-POL-PREMIUMS-PAID TO WS-TAX-BASIS
           COMPUTE WS-GAIN-ON-SURRENDER =
               WS-GROSS-CSV - WS-TAX-BASIS
           IF WS-GAIN-ON-SURRENDER < 0
               MOVE 0 TO WS-GAIN-ON-SURRENDER
           END-IF.
       8000-DISPLAY-RESULTS.
           DISPLAY 'SURRENDER VALUE CALCULATION'
           DISPLAY '==========================='
           DISPLAY 'POLICY:          ' WS-POL-NUM
           DISPLAY 'TYPE:            ' WS-POL-TYPE
           DISPLAY 'YEARS IN FORCE:  ' WS-YEARS-IN-FORCE
           DISPLAY 'CASH VALUE:      ' WS-POL-CASH-VALUE
           DISPLAY 'DIVIDENDS:       ' WS-POL-DIVID-ACCUM
           DISPLAY 'SURR CHARGE:     ' WS-SURR-CHARGE-AMT
           DISPLAY 'MVA ADJUST:      ' WS-MVA-ADJUSTMENT
           DISPLAY 'GROSS CSV:       ' WS-GROSS-CSV
           DISPLAY 'LOAN BALANCE:    ' WS-POL-LOAN-BAL
           DISPLAY 'ACCRUED INT:     ' WS-ACCRUED-LOAN-INT
           DISPLAY 'NET CSV:         ' WS-NET-CSV
           DISPLAY 'TAX BASIS:       ' WS-TAX-BASIS
           DISPLAY 'TAXABLE GAIN:    ' WS-GAIN-ON-SURRENDER.
