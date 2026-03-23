       IDENTIFICATION DIVISION.
       PROGRAM-ID. CARD-CLI-ENGINE.
      *================================================================*
      * CREDIT LINE INCREASE ENGINE                                    *
      * Evaluates utilization, income, payment behavior, and bureau    *
      * data to recommend limit increases, decreases, or maintenance.  *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CARDHOLDER.
           05 WS-CH-ID              PIC X(10).
           05 WS-CH-NAME            PIC X(30).
           05 WS-CH-ANNUAL-INCOME   PIC S9(9)V99 COMP-3.
           05 WS-CH-MONTHS-ON-BOOK  PIC S9(3) COMP-3.
           05 WS-CH-PRODUCT         PIC X(2).
               88 WS-PLATINUM       VALUE 'PL'.
               88 WS-GOLD           VALUE 'GD'.
               88 WS-CLASSIC        VALUE 'CL'.
               88 WS-SECURED        VALUE 'SC'.
       01 WS-ACCOUNT.
           05 WS-CURRENT-LIMIT      PIC S9(7)V99 COMP-3.
           05 WS-CURRENT-BALANCE    PIC S9(7)V99 COMP-3.
           05 WS-UTILIZATION-PCT    PIC S9(3)V99 COMP-3.
           05 WS-AVG-MONTHLY-SPEND  PIC S9(7)V99 COMP-3.
           05 WS-HIGHEST-BALANCE    PIC S9(7)V99 COMP-3.
           05 WS-AVAILABLE-CREDIT   PIC S9(7)V99 COMP-3.
       01 WS-PAYMENT-HISTORY.
           05 WS-PH-ENTRY OCCURS 12.
               10 WS-PH-MIN-DUE     PIC S9(5)V99 COMP-3.
               10 WS-PH-AMT-PAID    PIC S9(5)V99 COMP-3.
               10 WS-PH-DAYS-LATE   PIC S9(3) COMP-3.
       01 WS-BUREAU-DATA.
           05 WS-FICO-SCORE         PIC S9(3) COMP-3.
           05 WS-TOTAL-REVOLVING    PIC S9(9)V99 COMP-3.
           05 WS-TOTAL-LIMITS       PIC S9(9)V99 COMP-3.
           05 WS-DEROGS             PIC S9(2) COMP-3.
           05 WS-INQUIRIES-6MO      PIC S9(2) COMP-3.
       01 WS-SCORING.
           05 WS-UTIL-SCORE         PIC S9(3) COMP-3.
           05 WS-PAY-SCORE          PIC S9(3) COMP-3.
           05 WS-FICO-POINT-SCORE   PIC S9(3) COMP-3.
           05 WS-INCOME-SCORE       PIC S9(3) COMP-3.
           05 WS-TENURE-SCORE       PIC S9(3) COMP-3.
           05 WS-COMPOSITE-SCORE    PIC S9(5) COMP-3.
       01 WS-IDX                    PIC S9(2) COMP-3.
       01 WS-LATE-COUNT             PIC S9(3) COMP-3.
       01 WS-FULL-PAY-COUNT         PIC S9(3) COMP-3.
       01 WS-INCOME-RATIO           PIC S9(3)V99 COMP-3.
       01 WS-RECOMMENDATION         PIC X(15).
       01 WS-NEW-LIMIT              PIC S9(7)V99 COMP-3.
       01 WS-LIMIT-CHANGE           PIC S9(7)V99 COMP-3.
       01 WS-MAX-PRODUCT-LIMIT      PIC S9(7)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-UTILIZATION
           PERFORM 3000-SCORE-PAYMENTS
           PERFORM 4000-SCORE-BUREAU
           PERFORM 5000-SCORE-INCOME
           PERFORM 6000-SCORE-TENURE
           PERFORM 7000-CALC-COMPOSITE
           PERFORM 8000-DETERMINE-RECOMMENDATION
               THRU 8500-CALC-NEW-LIMIT
           PERFORM 9000-DISPLAY-RESULT
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'CH00001234' TO WS-CH-ID
           MOVE 'WILLIAMS, SARAH J' TO WS-CH-NAME
           MOVE 95000.00 TO WS-CH-ANNUAL-INCOME
           MOVE 36 TO WS-CH-MONTHS-ON-BOOK
           MOVE 'GD' TO WS-CH-PRODUCT
           MOVE 12000.00 TO WS-CURRENT-LIMIT
           MOVE 4200.00 TO WS-CURRENT-BALANCE
           MOVE 5800.00 TO WS-AVG-MONTHLY-SPEND
           MOVE 9500.00 TO WS-HIGHEST-BALANCE
           MOVE 740 TO WS-FICO-SCORE
           MOVE 18000.00 TO WS-TOTAL-REVOLVING
           MOVE 45000.00 TO WS-TOTAL-LIMITS
           MOVE 0 TO WS-DEROGS
           MOVE 1 TO WS-INQUIRIES-6MO
           MOVE 0 TO WS-LATE-COUNT
           MOVE 0 TO WS-FULL-PAY-COUNT
           MOVE 0 TO WS-COMPOSITE-SCORE
           PERFORM 1100-LOAD-PAYMENT-HISTORY.
       1100-LOAD-PAYMENT-HISTORY.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > 12
               MOVE 250.00 TO WS-PH-MIN-DUE(WS-IDX)
               MOVE 0 TO WS-PH-DAYS-LATE(WS-IDX)
           END-PERFORM
           MOVE 1500.00 TO WS-PH-AMT-PAID(1)
           MOVE 4200.00 TO WS-PH-AMT-PAID(2)
           MOVE 800.00 TO WS-PH-AMT-PAID(3)
           MOVE 5000.00 TO WS-PH-AMT-PAID(4)
           MOVE 250.00 TO WS-PH-AMT-PAID(5)
           MOVE 3200.00 TO WS-PH-AMT-PAID(6)
           MOVE 6000.00 TO WS-PH-AMT-PAID(7)
           MOVE 1000.00 TO WS-PH-AMT-PAID(8)
           MOVE 500.00 TO WS-PH-AMT-PAID(9)
           MOVE 4500.00 TO WS-PH-AMT-PAID(10)
           MOVE 2000.00 TO WS-PH-AMT-PAID(11)
           MOVE 3000.00 TO WS-PH-AMT-PAID(12).
       2000-CALC-UTILIZATION.
           IF WS-CURRENT-LIMIT > 0
               COMPUTE WS-UTILIZATION-PCT ROUNDED =
                   (WS-CURRENT-BALANCE / WS-CURRENT-LIMIT)
                   * 100
           ELSE
               MOVE 100 TO WS-UTILIZATION-PCT
           END-IF
           COMPUTE WS-AVAILABLE-CREDIT =
               WS-CURRENT-LIMIT - WS-CURRENT-BALANCE
           EVALUATE TRUE
               WHEN WS-UTILIZATION-PCT < 10
                   MOVE 100 TO WS-UTIL-SCORE
               WHEN WS-UTILIZATION-PCT < 30
                   MOVE 80 TO WS-UTIL-SCORE
               WHEN WS-UTILIZATION-PCT < 50
                   MOVE 60 TO WS-UTIL-SCORE
               WHEN WS-UTILIZATION-PCT < 75
                   MOVE 40 TO WS-UTIL-SCORE
               WHEN OTHER
                   MOVE 20 TO WS-UTIL-SCORE
           END-EVALUATE.
       3000-SCORE-PAYMENTS.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > 12
               IF WS-PH-DAYS-LATE(WS-IDX) > 0
                   ADD 1 TO WS-LATE-COUNT
               END-IF
               IF WS-PH-AMT-PAID(WS-IDX) >=
                   WS-PH-MIN-DUE(WS-IDX) * 3
                   ADD 1 TO WS-FULL-PAY-COUNT
               END-IF
           END-PERFORM
           IF WS-LATE-COUNT = 0
               IF WS-FULL-PAY-COUNT >= 6
                   MOVE 100 TO WS-PAY-SCORE
               ELSE
                   MOVE 80 TO WS-PAY-SCORE
               END-IF
           ELSE
               IF WS-LATE-COUNT <= 2
                   MOVE 50 TO WS-PAY-SCORE
               ELSE
                   MOVE 20 TO WS-PAY-SCORE
               END-IF
           END-IF.
       4000-SCORE-BUREAU.
           EVALUATE TRUE
               WHEN WS-FICO-SCORE >= 760
                   MOVE 100 TO WS-FICO-POINT-SCORE
               WHEN WS-FICO-SCORE >= 720
                   MOVE 85 TO WS-FICO-POINT-SCORE
               WHEN WS-FICO-SCORE >= 680
                   MOVE 65 TO WS-FICO-POINT-SCORE
               WHEN WS-FICO-SCORE >= 640
                   MOVE 45 TO WS-FICO-POINT-SCORE
               WHEN OTHER
                   MOVE 20 TO WS-FICO-POINT-SCORE
           END-EVALUATE
           IF WS-DEROGS > 0
               SUBTRACT 15 FROM WS-FICO-POINT-SCORE
               IF WS-FICO-POINT-SCORE < 0
                   MOVE 0 TO WS-FICO-POINT-SCORE
               END-IF
           END-IF.
       5000-SCORE-INCOME.
           IF WS-CH-ANNUAL-INCOME > 0
               COMPUTE WS-INCOME-RATIO ROUNDED =
                   (WS-CURRENT-LIMIT /
                    WS-CH-ANNUAL-INCOME) * 100
           ELSE
               MOVE 100 TO WS-INCOME-RATIO
           END-IF
           EVALUATE TRUE
               WHEN WS-INCOME-RATIO < 10
                   MOVE 100 TO WS-INCOME-SCORE
               WHEN WS-INCOME-RATIO < 20
                   MOVE 75 TO WS-INCOME-SCORE
               WHEN WS-INCOME-RATIO < 30
                   MOVE 50 TO WS-INCOME-SCORE
               WHEN OTHER
                   MOVE 25 TO WS-INCOME-SCORE
           END-EVALUATE.
       6000-SCORE-TENURE.
           EVALUATE TRUE
               WHEN WS-CH-MONTHS-ON-BOOK >= 60
                   MOVE 100 TO WS-TENURE-SCORE
               WHEN WS-CH-MONTHS-ON-BOOK >= 36
                   MOVE 75 TO WS-TENURE-SCORE
               WHEN WS-CH-MONTHS-ON-BOOK >= 12
                   MOVE 50 TO WS-TENURE-SCORE
               WHEN OTHER
                   MOVE 20 TO WS-TENURE-SCORE
           END-EVALUATE.
       7000-CALC-COMPOSITE.
           COMPUTE WS-COMPOSITE-SCORE ROUNDED =
               (WS-UTIL-SCORE * 20 +
                WS-PAY-SCORE * 30 +
                WS-FICO-POINT-SCORE * 25 +
                WS-INCOME-SCORE * 15 +
                WS-TENURE-SCORE * 10) / 100.
       8000-DETERMINE-RECOMMENDATION.
           IF WS-COMPOSITE-SCORE >= 80
               MOVE 'INCREASE' TO WS-RECOMMENDATION
           ELSE
               IF WS-COMPOSITE-SCORE >= 50
                   MOVE 'MAINTAIN' TO WS-RECOMMENDATION
               ELSE
                   MOVE 'DECREASE' TO WS-RECOMMENDATION
               END-IF
           END-IF.
       8500-CALC-NEW-LIMIT.
           EVALUATE TRUE
               WHEN WS-PLATINUM
                   MOVE 50000.00 TO WS-MAX-PRODUCT-LIMIT
               WHEN WS-GOLD
                   MOVE 25000.00 TO WS-MAX-PRODUCT-LIMIT
               WHEN WS-CLASSIC
                   MOVE 10000.00 TO WS-MAX-PRODUCT-LIMIT
               WHEN WS-SECURED
                   MOVE 5000.00 TO WS-MAX-PRODUCT-LIMIT
           END-EVALUATE
           IF WS-RECOMMENDATION = 'INCREASE'
               COMPUTE WS-LIMIT-CHANGE ROUNDED =
                   WS-CURRENT-LIMIT * 0.25
               COMPUTE WS-NEW-LIMIT =
                   WS-CURRENT-LIMIT + WS-LIMIT-CHANGE
               IF WS-NEW-LIMIT > WS-MAX-PRODUCT-LIMIT
                   MOVE WS-MAX-PRODUCT-LIMIT TO WS-NEW-LIMIT
                   COMPUTE WS-LIMIT-CHANGE =
                       WS-NEW-LIMIT - WS-CURRENT-LIMIT
               END-IF
           ELSE
               IF WS-RECOMMENDATION = 'DECREASE'
                   COMPUTE WS-LIMIT-CHANGE ROUNDED =
                       WS-CURRENT-LIMIT * 0.15 * -1
                   COMPUTE WS-NEW-LIMIT =
                       WS-CURRENT-LIMIT + WS-LIMIT-CHANGE
                   IF WS-NEW-LIMIT < WS-CURRENT-BALANCE
                       MOVE WS-CURRENT-BALANCE TO
                           WS-NEW-LIMIT
                       COMPUTE WS-LIMIT-CHANGE =
                           WS-NEW-LIMIT - WS-CURRENT-LIMIT
                   END-IF
               ELSE
                   MOVE WS-CURRENT-LIMIT TO WS-NEW-LIMIT
                   MOVE 0 TO WS-LIMIT-CHANGE
               END-IF
           END-IF.
       9000-DISPLAY-RESULT.
           DISPLAY '========================================='
           DISPLAY 'CREDIT LINE REVIEW'
           DISPLAY '========================================='
           DISPLAY 'CARDHOLDER:      ' WS-CH-NAME
           DISPLAY 'PRODUCT:         ' WS-CH-PRODUCT
           DISPLAY 'FICO:            ' WS-FICO-SCORE
           DISPLAY 'INCOME:          ' WS-CH-ANNUAL-INCOME
           DISPLAY 'CURRENT LIMIT:   ' WS-CURRENT-LIMIT
           DISPLAY 'UTILIZATION:     ' WS-UTILIZATION-PCT
           DISPLAY 'UTIL SCORE:      ' WS-UTIL-SCORE
           DISPLAY 'PAY SCORE:       ' WS-PAY-SCORE
           DISPLAY 'FICO SCORE:      ' WS-FICO-POINT-SCORE
           DISPLAY 'INCOME SCORE:    ' WS-INCOME-SCORE
           DISPLAY 'TENURE SCORE:    ' WS-TENURE-SCORE
           DISPLAY 'COMPOSITE:       ' WS-COMPOSITE-SCORE
           DISPLAY 'RECOMMENDATION:  ' WS-RECOMMENDATION
           DISPLAY 'LIMIT CHANGE:    ' WS-LIMIT-CHANGE
           DISPLAY 'NEW LIMIT:       ' WS-NEW-LIMIT
           DISPLAY '========================================='.
