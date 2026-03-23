       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOAN-RISK-GRADING.
      *================================================================*
      * LOAN RISK GRADING ENGINE                                       *
      * Assigns risk grade (1-10) based on financial ratios,           *
      * payment history, collateral, and industry sector.              *
      * Computes expected loss and provision requirement.              *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-BORROWER.
           05 WS-BORR-ID            PIC X(10).
           05 WS-BORR-NAME          PIC X(30).
           05 WS-BORR-TYPE          PIC X(1).
               88 WS-COMMERCIAL     VALUE 'C'.
               88 WS-CONSUMER       VALUE 'R'.
               88 WS-SMALL-BIZ      VALUE 'S'.
       01 WS-LOAN-DATA.
           05 WS-LOAN-ID            PIC X(12).
           05 WS-LOAN-BALANCE       PIC S9(11)V99 COMP-3.
           05 WS-ORIG-AMOUNT        PIC S9(11)V99 COMP-3.
           05 WS-INTEREST-RATE      PIC S9(2)V9(4) COMP-3.
           05 WS-DAYS-PAST-DUE      PIC S9(5) COMP-3.
           05 WS-PMTS-MADE          PIC S9(3) COMP-3.
           05 WS-PMTS-LATE-30       PIC S9(3) COMP-3.
           05 WS-PMTS-LATE-60       PIC S9(3) COMP-3.
           05 WS-PMTS-LATE-90       PIC S9(3) COMP-3.
       01 WS-COLLATERAL.
           05 WS-COLL-VALUE         PIC S9(11)V99 COMP-3.
           05 WS-COLL-TYPE          PIC X(2).
               88 WS-REAL-ESTATE    VALUE 'RE'.
               88 WS-EQUIPMENT      VALUE 'EQ'.
               88 WS-INVENTORY      VALUE 'IN'.
               88 WS-UNSECURED      VALUE 'UN'.
           05 WS-LTV-RATIO          PIC S9(3)V99 COMP-3.
       01 WS-FINANCIALS.
           05 WS-DEBT-TO-INCOME     PIC S9(3)V99 COMP-3.
           05 WS-CURRENT-RATIO      PIC S9(3)V99 COMP-3.
           05 WS-DSCR               PIC S9(3)V99 COMP-3.
       01 WS-INDUSTRY-CODE          PIC X(4).
       01 WS-SCORING.
           05 WS-DPD-SCORE          PIC S9(3) COMP-3.
           05 WS-HISTORY-SCORE      PIC S9(3) COMP-3.
           05 WS-LTV-SCORE          PIC S9(3) COMP-3.
           05 WS-FINANCIAL-SCORE    PIC S9(3) COMP-3.
           05 WS-INDUSTRY-SCORE     PIC S9(3) COMP-3.
           05 WS-COMPOSITE          PIC S9(5) COMP-3.
       01 WS-RISK-GRADE             PIC S9(2) COMP-3.
       01 WS-RISK-LABEL             PIC X(15).
       01 WS-PD-RATE                PIC S9(1)V9(6) COMP-3.
       01 WS-LGD-RATE               PIC S9(1)V9(4) COMP-3.
       01 WS-EXPECTED-LOSS          PIC S9(9)V99 COMP-3.
       01 WS-PROVISION-AMT          PIC S9(9)V99 COMP-3.
       01 WS-PROVISION-PCT          PIC S9(3)V99 COMP-3.
       01 WS-LATE-RATIO             PIC S9(1)V9(4) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-SCORE-DELINQUENCY
           PERFORM 3000-SCORE-HISTORY
           PERFORM 4000-SCORE-COLLATERAL
           PERFORM 5000-SCORE-FINANCIALS
           PERFORM 6000-SCORE-INDUSTRY
           PERFORM 7000-CALC-COMPOSITE
               THRU 7500-ASSIGN-GRADE
           PERFORM 8000-CALC-EXPECTED-LOSS
           PERFORM 9000-DISPLAY-RESULT
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'BRW0001234' TO WS-BORR-ID
           MOVE 'MIDWEST MANUFACTURING INC' TO WS-BORR-NAME
           MOVE 'C' TO WS-BORR-TYPE
           MOVE 'LN0000045678' TO WS-LOAN-ID
           MOVE 2500000.00 TO WS-LOAN-BALANCE
           MOVE 3000000.00 TO WS-ORIG-AMOUNT
           MOVE 5.75 TO WS-INTEREST-RATE
           MOVE 35 TO WS-DAYS-PAST-DUE
           MOVE 48 TO WS-PMTS-MADE
           MOVE 3 TO WS-PMTS-LATE-30
           MOVE 1 TO WS-PMTS-LATE-60
           MOVE 0 TO WS-PMTS-LATE-90
           MOVE 3500000.00 TO WS-COLL-VALUE
           MOVE 'RE' TO WS-COLL-TYPE
           MOVE 42.50 TO WS-DEBT-TO-INCOME
           MOVE 1.35 TO WS-CURRENT-RATIO
           MOVE 1.20 TO WS-DSCR
           MOVE '3312' TO WS-INDUSTRY-CODE
           MOVE 0 TO WS-COMPOSITE.
       2000-SCORE-DELINQUENCY.
           EVALUATE TRUE
               WHEN WS-DAYS-PAST-DUE = 0
                   MOVE 10 TO WS-DPD-SCORE
               WHEN WS-DAYS-PAST-DUE <= 30
                   MOVE 30 TO WS-DPD-SCORE
               WHEN WS-DAYS-PAST-DUE <= 60
                   MOVE 55 TO WS-DPD-SCORE
               WHEN WS-DAYS-PAST-DUE <= 90
                   MOVE 75 TO WS-DPD-SCORE
               WHEN WS-DAYS-PAST-DUE <= 180
                   MOVE 90 TO WS-DPD-SCORE
               WHEN OTHER
                   MOVE 100 TO WS-DPD-SCORE
           END-EVALUATE.
       3000-SCORE-HISTORY.
           IF WS-PMTS-MADE > 0
               COMPUTE WS-LATE-RATIO =
                   (WS-PMTS-LATE-30 + WS-PMTS-LATE-60 +
                    WS-PMTS-LATE-90) / WS-PMTS-MADE
           ELSE
               MOVE 0.50 TO WS-LATE-RATIO
           END-IF
           EVALUATE TRUE
               WHEN WS-LATE-RATIO > 0.20
                   MOVE 80 TO WS-HISTORY-SCORE
               WHEN WS-LATE-RATIO > 0.10
                   MOVE 50 TO WS-HISTORY-SCORE
               WHEN WS-LATE-RATIO > 0.05
                   MOVE 30 TO WS-HISTORY-SCORE
               WHEN OTHER
                   MOVE 10 TO WS-HISTORY-SCORE
           END-EVALUATE
           IF WS-PMTS-LATE-90 > 0
               ADD 20 TO WS-HISTORY-SCORE
               IF WS-HISTORY-SCORE > 100
                   MOVE 100 TO WS-HISTORY-SCORE
               END-IF
           END-IF.
       4000-SCORE-COLLATERAL.
           IF WS-COLL-VALUE > 0
               COMPUTE WS-LTV-RATIO ROUNDED =
                   (WS-LOAN-BALANCE / WS-COLL-VALUE) * 100
           ELSE
               MOVE 100 TO WS-LTV-RATIO
           END-IF
           EVALUATE TRUE
               WHEN WS-LTV-RATIO > 100
                   MOVE 90 TO WS-LTV-SCORE
               WHEN WS-LTV-RATIO > 80
                   MOVE 60 TO WS-LTV-SCORE
               WHEN WS-LTV-RATIO > 60
                   MOVE 35 TO WS-LTV-SCORE
               WHEN OTHER
                   MOVE 15 TO WS-LTV-SCORE
           END-EVALUATE
           IF WS-UNSECURED
               MOVE 80 TO WS-LTV-SCORE
           END-IF.
       5000-SCORE-FINANCIALS.
           IF WS-COMMERCIAL
               IF WS-DSCR < 1.00
                   MOVE 80 TO WS-FINANCIAL-SCORE
               ELSE
                   IF WS-DSCR < 1.20
                       MOVE 50 TO WS-FINANCIAL-SCORE
                   ELSE
                       IF WS-DSCR < 1.50
                           MOVE 25 TO WS-FINANCIAL-SCORE
                       ELSE
                           MOVE 10 TO WS-FINANCIAL-SCORE
                       END-IF
                   END-IF
               END-IF
           ELSE
               IF WS-DEBT-TO-INCOME > 50
                   MOVE 75 TO WS-FINANCIAL-SCORE
               ELSE
                   IF WS-DEBT-TO-INCOME > 40
                       MOVE 45 TO WS-FINANCIAL-SCORE
                   ELSE
                       IF WS-DEBT-TO-INCOME > 30
                           MOVE 25 TO WS-FINANCIAL-SCORE
                       ELSE
                           MOVE 10 TO WS-FINANCIAL-SCORE
                       END-IF
                   END-IF
               END-IF
           END-IF.
       6000-SCORE-INDUSTRY.
           EVALUATE WS-INDUSTRY-CODE
               WHEN '3312'
                   MOVE 40 TO WS-INDUSTRY-SCORE
               WHEN '5411'
                   MOVE 15 TO WS-INDUSTRY-SCORE
               WHEN '7211'
                   MOVE 60 TO WS-INDUSTRY-SCORE
               WHEN '2111'
                   MOVE 70 TO WS-INDUSTRY-SCORE
               WHEN OTHER
                   MOVE 30 TO WS-INDUSTRY-SCORE
           END-EVALUATE.
       7000-CALC-COMPOSITE.
           COMPUTE WS-COMPOSITE ROUNDED =
               (WS-DPD-SCORE * 30 +
                WS-HISTORY-SCORE * 25 +
                WS-LTV-SCORE * 20 +
                WS-FINANCIAL-SCORE * 15 +
                WS-INDUSTRY-SCORE * 10) / 100.
       7500-ASSIGN-GRADE.
           EVALUATE TRUE
               WHEN WS-COMPOSITE <= 15
                   MOVE 1 TO WS-RISK-GRADE
                   MOVE 'MINIMAL RISK' TO WS-RISK-LABEL
               WHEN WS-COMPOSITE <= 25
                   MOVE 2 TO WS-RISK-GRADE
                   MOVE 'LOW RISK' TO WS-RISK-LABEL
               WHEN WS-COMPOSITE <= 35
                   MOVE 3 TO WS-RISK-GRADE
                   MOVE 'MODERATE LOW' TO WS-RISK-LABEL
               WHEN WS-COMPOSITE <= 45
                   MOVE 4 TO WS-RISK-GRADE
                   MOVE 'MODERATE' TO WS-RISK-LABEL
               WHEN WS-COMPOSITE <= 55
                   MOVE 5 TO WS-RISK-GRADE
                   MOVE 'MODERATE HIGH' TO WS-RISK-LABEL
               WHEN WS-COMPOSITE <= 65
                   MOVE 6 TO WS-RISK-GRADE
                   MOVE 'ELEVATED' TO WS-RISK-LABEL
               WHEN WS-COMPOSITE <= 75
                   MOVE 7 TO WS-RISK-GRADE
                   MOVE 'HIGH' TO WS-RISK-LABEL
               WHEN WS-COMPOSITE <= 85
                   MOVE 8 TO WS-RISK-GRADE
                   MOVE 'VERY HIGH' TO WS-RISK-LABEL
               WHEN WS-COMPOSITE <= 95
                   MOVE 9 TO WS-RISK-GRADE
                   MOVE 'IMPAIRED' TO WS-RISK-LABEL
               WHEN OTHER
                   MOVE 10 TO WS-RISK-GRADE
                   MOVE 'LOSS' TO WS-RISK-LABEL
           END-EVALUATE.
       8000-CALC-EXPECTED-LOSS.
           EVALUATE WS-RISK-GRADE
               WHEN 1
                   MOVE 0.001 TO WS-PD-RATE
               WHEN 2
                   MOVE 0.005 TO WS-PD-RATE
               WHEN 3
                   MOVE 0.015 TO WS-PD-RATE
               WHEN 4
                   MOVE 0.030 TO WS-PD-RATE
               WHEN 5
                   MOVE 0.060 TO WS-PD-RATE
               WHEN 6
                   MOVE 0.100 TO WS-PD-RATE
               WHEN 7
                   MOVE 0.200 TO WS-PD-RATE
               WHEN 8
                   MOVE 0.350 TO WS-PD-RATE
               WHEN 9
                   MOVE 0.500 TO WS-PD-RATE
               WHEN OTHER
                   MOVE 1.000 TO WS-PD-RATE
           END-EVALUATE
           EVALUATE TRUE
               WHEN WS-REAL-ESTATE
                   MOVE 0.35 TO WS-LGD-RATE
               WHEN WS-EQUIPMENT
                   MOVE 0.50 TO WS-LGD-RATE
               WHEN WS-INVENTORY
                   MOVE 0.70 TO WS-LGD-RATE
               WHEN WS-UNSECURED
                   MOVE 0.90 TO WS-LGD-RATE
               WHEN OTHER
                   MOVE 0.60 TO WS-LGD-RATE
           END-EVALUATE
           COMPUTE WS-EXPECTED-LOSS ROUNDED =
               WS-LOAN-BALANCE * WS-PD-RATE * WS-LGD-RATE
           COMPUTE WS-PROVISION-PCT ROUNDED =
               WS-PD-RATE * WS-LGD-RATE * 100
           COMPUTE WS-PROVISION-AMT ROUNDED =
               WS-EXPECTED-LOSS * 1.20.
       9000-DISPLAY-RESULT.
           DISPLAY '========================================='
           DISPLAY 'LOAN RISK GRADING REPORT'
           DISPLAY '========================================='
           DISPLAY 'BORROWER:        ' WS-BORR-NAME
           DISPLAY 'LOAN ID:         ' WS-LOAN-ID
           DISPLAY 'BALANCE:         ' WS-LOAN-BALANCE
           DISPLAY 'DAYS PAST DUE:   ' WS-DAYS-PAST-DUE
           DISPLAY 'LTV RATIO:       ' WS-LTV-RATIO
           DISPLAY 'DSCR:            ' WS-DSCR
           DISPLAY 'DPD SCORE:       ' WS-DPD-SCORE
           DISPLAY 'HISTORY SCORE:   ' WS-HISTORY-SCORE
           DISPLAY 'LTV SCORE:       ' WS-LTV-SCORE
           DISPLAY 'FINANCIAL SCORE: ' WS-FINANCIAL-SCORE
           DISPLAY 'INDUSTRY SCORE:  ' WS-INDUSTRY-SCORE
           DISPLAY 'COMPOSITE:       ' WS-COMPOSITE
           DISPLAY 'RISK GRADE:      ' WS-RISK-GRADE
           DISPLAY 'RISK LABEL:      ' WS-RISK-LABEL
           DISPLAY 'PD RATE:         ' WS-PD-RATE
           DISPLAY 'LGD RATE:        ' WS-LGD-RATE
           DISPLAY 'EXPECTED LOSS:   ' WS-EXPECTED-LOSS
           DISPLAY 'PROVISION:       ' WS-PROVISION-AMT
           DISPLAY '========================================='.
