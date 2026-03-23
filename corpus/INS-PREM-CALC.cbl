       IDENTIFICATION DIVISION.
       PROGRAM-ID. INS-PREM-CALC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-POLICY-DATA.
           05 WS-POLICY-NUM          PIC X(12).
           05 WS-INSURED-AGE         PIC 9(3).
           05 WS-COVERAGE-AMT        PIC S9(9)V99 COMP-3.
           05 WS-DEDUCTIBLE          PIC S9(7)V99 COMP-3.
       01 WS-RISK-CLASS              PIC X(1).
           88 WS-PREFERRED           VALUE 'P'.
           88 WS-STANDARD            VALUE 'S'.
           88 WS-SUBSTANDARD         VALUE 'U'.
       01 WS-PRODUCT-TYPE            PIC X(1).
           88 WS-TERM-LIFE           VALUE 'T'.
           88 WS-WHOLE-LIFE          VALUE 'W'.
           88 WS-UNIVERSAL           VALUE 'U'.
       01 WS-PREMIUM-FIELDS.
           05 WS-BASE-RATE           PIC S9(1)V9(6) COMP-3.
           05 WS-AGE-FACTOR          PIC S9(3)V9(4) COMP-3.
           05 WS-RISK-FACTOR         PIC S9(1)V9(4) COMP-3.
           05 WS-DEDUCT-CREDIT       PIC S9(5)V99 COMP-3.
           05 WS-ANNUAL-PREM         PIC S9(7)V99 COMP-3.
           05 WS-MONTHLY-PREM        PIC S9(5)V99 COMP-3.
       01 WS-AGE-IDX                 PIC 9(2).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-SET-BASE-RATE
           PERFORM 3000-CALC-AGE-FACTOR
           PERFORM 4000-CALC-RISK-FACTOR
           PERFORM 5000-CALC-PREMIUM
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-ANNUAL-PREM
           MOVE 0 TO WS-DEDUCT-CREDIT.
       2000-SET-BASE-RATE.
           EVALUATE TRUE
               WHEN WS-TERM-LIFE
                   MOVE 0.0035 TO WS-BASE-RATE
               WHEN WS-WHOLE-LIFE
                   MOVE 0.0120 TO WS-BASE-RATE
               WHEN WS-UNIVERSAL
                   MOVE 0.0080 TO WS-BASE-RATE
               WHEN OTHER
                   MOVE 0.0050 TO WS-BASE-RATE
           END-EVALUATE.
       3000-CALC-AGE-FACTOR.
           MOVE 1.0000 TO WS-AGE-FACTOR
           PERFORM VARYING WS-AGE-IDX FROM 25 BY 5
               UNTIL WS-AGE-IDX > WS-INSURED-AGE
               COMPUTE WS-AGE-FACTOR =
                   WS-AGE-FACTOR * 1.1500
           END-PERFORM
           IF WS-INSURED-AGE > 65
               COMPUTE WS-AGE-FACTOR =
                   WS-AGE-FACTOR * 1.2500
           END-IF.
       4000-CALC-RISK-FACTOR.
           EVALUATE TRUE
               WHEN WS-PREFERRED
                   MOVE 0.8500 TO WS-RISK-FACTOR
               WHEN WS-STANDARD
                   MOVE 1.0000 TO WS-RISK-FACTOR
               WHEN WS-SUBSTANDARD
                   MOVE 1.5000 TO WS-RISK-FACTOR
               WHEN OTHER
                   MOVE 1.2500 TO WS-RISK-FACTOR
           END-EVALUATE.
       5000-CALC-PREMIUM.
           COMPUTE WS-ANNUAL-PREM =
               WS-COVERAGE-AMT * WS-BASE-RATE *
               WS-AGE-FACTOR * WS-RISK-FACTOR
           IF WS-DEDUCTIBLE > 1000
               COMPUTE WS-DEDUCT-CREDIT =
                   WS-ANNUAL-PREM * 0.05
               SUBTRACT WS-DEDUCT-CREDIT FROM
                   WS-ANNUAL-PREM
           END-IF
           COMPUTE WS-MONTHLY-PREM =
               WS-ANNUAL-PREM / 12
           IF WS-MONTHLY-PREM < 25
               MOVE 25.00 TO WS-MONTHLY-PREM
               COMPUTE WS-ANNUAL-PREM =
                   WS-MONTHLY-PREM * 12
           END-IF.
       6000-DISPLAY-RESULTS.
           DISPLAY 'INSURANCE PREMIUM CALCULATION'
           DISPLAY '============================='
           DISPLAY 'POLICY:       ' WS-POLICY-NUM
           DISPLAY 'AGE:          ' WS-INSURED-AGE
           DISPLAY 'COVERAGE:     ' WS-COVERAGE-AMT
           DISPLAY 'BASE RATE:    ' WS-BASE-RATE
           DISPLAY 'AGE FACTOR:   ' WS-AGE-FACTOR
           DISPLAY 'RISK FACTOR:  ' WS-RISK-FACTOR
           DISPLAY 'ANNUAL PREM:  ' WS-ANNUAL-PREM
           DISPLAY 'MONTHLY PREM: ' WS-MONTHLY-PREM.
