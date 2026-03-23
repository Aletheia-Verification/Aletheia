       IDENTIFICATION DIVISION.
       PROGRAM-ID. CREDIT-SCORE.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-BASE-SCORE          PIC 9(3).
       01  WS-ADJUSTED-SCORE      PIC 9(3).
       01  WS-PAYMENT-HISTORY.
           05  WS-ON-TIME-PCT     PIC 9(3)V99.
           05  WS-MISSED-PAYMENTS PIC 9(2).
           05  WS-CONSECUTIVE-ON  PIC 9(2).
       01  WS-DEBT-INFO.
           05  WS-TOTAL-DEBT      PIC S9(9)V99 COMP-3.
           05  WS-TOTAL-CREDIT    PIC S9(9)V99 COMP-3.
           05  WS-UTILIZATION     PIC S9(1)V9(4) COMP-3.
           05  WS-DEBT-INCOME     PIC S9(1)V9(4) COMP-3.
       01  WS-ACCOUNT-AGE         PIC 9(3).
       01  WS-NUM-ACCOUNTS        PIC 9(2).
       01  WS-HARD-INQUIRIES      PIC 9(2).
       01  WS-SCORE-ADJUST        PIC S9(3).
       01  WS-CATEGORY            PIC X(10).
           88  SCORE-EXCELLENT     VALUE 'EXCELLENT'.
           88  SCORE-GOOD          VALUE 'GOOD'.
           88  SCORE-FAIR          VALUE 'FAIR'.
           88  SCORE-POOR          VALUE 'POOR'.
           88  SCORE-VERY-POOR     VALUE 'VERY-POOR'.
       01  WS-RISK-LEVEL          PIC 9(1).
           88  LOW-RISK            VALUE 1.
           88  MEDIUM-RISK         VALUE 2.
           88  HIGH-RISK           VALUE 3.
           88  VERY-HIGH-RISK      VALUE 4.
       01  WS-TEMP-SCORE          PIC S9(4).
       01  WS-WEIGHT              PIC S9(1)V9(4) COMP-3.
       01  WS-FACTOR-CTR          PIC 9(1).
       01  WS-WEIGHTED-SUM        PIC S9(5)V99 COMP-3.
       01  WS-FACTOR-COUNT        PIC 9(1).
       01  WS-MONTHLY-INCOME      PIC S9(7)V99 COMP-3.
       01  WS-RATE-OFFERED        PIC S9(1)V9(4) COMP-3.
       01  WS-MAX-LOAN            PIC S9(9)V99 COMP-3.
       01  WS-INQUIRY-PENALTY     PIC S9(3).

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT.
           PERFORM 2000-PAYMENT-SCORE.
           PERFORM 3000-UTILIZATION-SCORE.
           PERFORM 4000-HISTORY-SCORE.
           PERFORM 5000-INQUIRY-SCORE.
           PERFORM 6000-DETERMINE-CATEGORY.
           PERFORM 7000-CALC-RATE.
           STOP RUN.

       1000-INIT.
           MOVE WS-BASE-SCORE TO WS-ADJUSTED-SCORE.
           MOVE 0 TO WS-SCORE-ADJUST.
           MOVE 0 TO WS-WEIGHTED-SUM.
           MOVE 0 TO WS-INQUIRY-PENALTY.
           MOVE SPACES TO WS-CATEGORY.

       2000-PAYMENT-SCORE.
           EVALUATE TRUE
               WHEN WS-ON-TIME-PCT >= 99
                   ADD 50 TO WS-SCORE-ADJUST
               WHEN WS-ON-TIME-PCT >= 95
                   ADD 30 TO WS-SCORE-ADJUST
               WHEN WS-ON-TIME-PCT >= 90
                   ADD 10 TO WS-SCORE-ADJUST
               WHEN WS-ON-TIME-PCT >= 80
                   SUBTRACT 20 FROM WS-SCORE-ADJUST
               WHEN OTHER
                   SUBTRACT 50 FROM WS-SCORE-ADJUST
           END-EVALUATE.
           IF WS-MISSED-PAYMENTS > 0
               MULTIPLY WS-MISSED-PAYMENTS BY 15
                   GIVING WS-TEMP-SCORE
               SUBTRACT WS-TEMP-SCORE FROM WS-SCORE-ADJUST
           END-IF.
           IF WS-CONSECUTIVE-ON > 12
               ADD 25 TO WS-SCORE-ADJUST
           END-IF.

       3000-UTILIZATION-SCORE.
           IF WS-TOTAL-CREDIT > 0
               DIVIDE WS-TOTAL-DEBT BY WS-TOTAL-CREDIT
                   GIVING WS-UTILIZATION
           ELSE
               MOVE 0 TO WS-UTILIZATION
           END-IF.
           EVALUATE TRUE
               WHEN WS-UTILIZATION < 0.10
                   ADD 40 TO WS-SCORE-ADJUST
               WHEN WS-UTILIZATION < 0.30
                   ADD 20 TO WS-SCORE-ADJUST
               WHEN WS-UTILIZATION < 0.50
                   ADD 0 TO WS-SCORE-ADJUST
               WHEN WS-UTILIZATION < 0.75
                   SUBTRACT 30 FROM WS-SCORE-ADJUST
               WHEN OTHER
                   SUBTRACT 60 FROM WS-SCORE-ADJUST
           END-EVALUATE.

       4000-HISTORY-SCORE.
           IF WS-ACCOUNT-AGE > 120
               ADD 30 TO WS-SCORE-ADJUST
           ELSE
               IF WS-ACCOUNT-AGE > 60
                   ADD 15 TO WS-SCORE-ADJUST
               ELSE
                   IF WS-ACCOUNT-AGE < 12
                       SUBTRACT 10 FROM WS-SCORE-ADJUST
                   END-IF
               END-IF
           END-IF.
           IF WS-NUM-ACCOUNTS > 5
               ADD 10 TO WS-SCORE-ADJUST
           END-IF.

       5000-INQUIRY-SCORE.
           PERFORM 5100-CALC-INQUIRY-PENALTY
               VARYING WS-FACTOR-CTR FROM 1 BY 1
               UNTIL WS-FACTOR-CTR > WS-HARD-INQUIRIES.
           SUBTRACT WS-INQUIRY-PENALTY FROM WS-SCORE-ADJUST.

       5100-CALC-INQUIRY-PENALTY.
           IF WS-FACTOR-CTR <= 2
               ADD 5 TO WS-INQUIRY-PENALTY
           ELSE
               ADD 10 TO WS-INQUIRY-PENALTY
           END-IF.

       6000-DETERMINE-CATEGORY.
           ADD WS-SCORE-ADJUST TO WS-ADJUSTED-SCORE.
           IF WS-ADJUSTED-SCORE > 850
               MOVE 850 TO WS-ADJUSTED-SCORE
           END-IF.
           IF WS-ADJUSTED-SCORE < 300
               MOVE 300 TO WS-ADJUSTED-SCORE
           END-IF.
           EVALUATE TRUE
               WHEN WS-ADJUSTED-SCORE >= 750
                   MOVE 'EXCELLENT' TO WS-CATEGORY
                   MOVE 1 TO WS-RISK-LEVEL
               WHEN WS-ADJUSTED-SCORE >= 700
                   MOVE 'GOOD' TO WS-CATEGORY
                   MOVE 1 TO WS-RISK-LEVEL
               WHEN WS-ADJUSTED-SCORE >= 650
                   MOVE 'FAIR' TO WS-CATEGORY
                   MOVE 2 TO WS-RISK-LEVEL
               WHEN WS-ADJUSTED-SCORE >= 550
                   MOVE 'POOR' TO WS-CATEGORY
                   MOVE 3 TO WS-RISK-LEVEL
               WHEN OTHER
                   MOVE 'VERY-POOR' TO WS-CATEGORY
                   MOVE 4 TO WS-RISK-LEVEL
           END-EVALUATE.

       7000-CALC-RATE.
           EVALUATE TRUE
               WHEN LOW-RISK
                   MOVE 0.0499 TO WS-RATE-OFFERED
               WHEN MEDIUM-RISK
                   MOVE 0.0899 TO WS-RATE-OFFERED
               WHEN HIGH-RISK
                   MOVE 0.1499 TO WS-RATE-OFFERED
               WHEN VERY-HIGH-RISK
                   MOVE 0.2199 TO WS-RATE-OFFERED
           END-EVALUATE.
           IF WS-MONTHLY-INCOME > 0
               COMPUTE WS-DEBT-INCOME =
                   WS-TOTAL-DEBT / (WS-MONTHLY-INCOME * 12)
               IF WS-DEBT-INCOME < 0.43
                   COMPUTE WS-MAX-LOAN =
                       (WS-MONTHLY-INCOME * 0.28) /
                       (WS-RATE-OFFERED / 12)
               ELSE
                   MOVE 0 TO WS-MAX-LOAN
               END-IF
           ELSE
               MOVE 0 TO WS-MAX-LOAN
           END-IF.
