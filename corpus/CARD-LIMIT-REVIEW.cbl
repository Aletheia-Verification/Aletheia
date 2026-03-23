       IDENTIFICATION DIVISION.
       PROGRAM-ID. CARD-LIMIT-REVIEW.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CARDHOLDER.
           05 WS-CARD-NUM         PIC X(16).
           05 WS-CARD-HOLDER      PIC X(30).
           05 WS-CURRENT-LIMIT    PIC S9(7)V99 COMP-3.
           05 WS-CURRENT-BAL      PIC S9(7)V99 COMP-3.
           05 WS-MONTHS-OPEN      PIC 9(3).
           05 WS-PAYMENT-HISTORY  PIC X(12).
           05 WS-CREDIT-SCORE     PIC 9(3).
           05 WS-INCOME           PIC S9(9)V99 COMP-3.
       01 WS-USAGE-DATA.
           05 WS-AVG-UTILIZATION  PIC S9(3)V99 COMP-3.
           05 WS-PEAK-UTILIZATION PIC S9(3)V99 COMP-3.
           05 WS-LATE-COUNT-12MO  PIC 9(2).
           05 WS-OVERLIMIT-COUNT  PIC 9(2).
       01 WS-REVIEW-RESULT.
           05 WS-NEW-LIMIT        PIC S9(7)V99 COMP-3.
           05 WS-LIMIT-CHANGE     PIC S9(7)V99 COMP-3.
           05 WS-LIMIT-PCT-CHG    PIC S9(3)V99 COMP-3.
           05 WS-DECISION         PIC X(12).
           05 WS-REASON-CODE      PIC X(4).
       01 WS-UTILIZATION-RATIO    PIC S9(3)V99 COMP-3.
       01 WS-ELIGIBLE-INCREASE    PIC S9(7)V99 COMP-3.
       01 WS-MAX-ALLOWED          PIC S9(7)V99 COMP-3.
       01 WS-ON-TIME-COUNT        PIC 9(2).
       01 WS-TALLY-ON-TIME        PIC 9(3).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-CALC-METRICS
           PERFORM 2000-CHECK-ELIGIBILITY
           PERFORM 3000-DETERMINE-ADJUSTMENT
           PERFORM 4000-OUTPUT
           STOP RUN.
       1000-CALC-METRICS.
           IF WS-CURRENT-LIMIT > 0
               COMPUTE WS-UTILIZATION-RATIO =
                   (WS-CURRENT-BAL / WS-CURRENT-LIMIT) * 100
           ELSE
               MOVE 0 TO WS-UTILIZATION-RATIO
           END-IF
           MOVE 0 TO WS-TALLY-ON-TIME
           INSPECT WS-PAYMENT-HISTORY
               TALLYING WS-TALLY-ON-TIME
               FOR ALL 'O'
           MOVE WS-TALLY-ON-TIME TO WS-ON-TIME-COUNT.
       2000-CHECK-ELIGIBILITY.
           MOVE 'N/A         ' TO WS-DECISION
           IF WS-MONTHS-OPEN < 6
               MOVE 'R001' TO WS-REASON-CODE
               MOVE 'TOO NEW     ' TO WS-DECISION
           ELSE
               IF WS-LATE-COUNT-12MO > 2
                   MOVE 'R002' TO WS-REASON-CODE
                   MOVE 'DECREASE    ' TO WS-DECISION
               ELSE
                   IF WS-CREDIT-SCORE < 600
                       MOVE 'R003' TO WS-REASON-CODE
                       MOVE 'DECREASE    ' TO WS-DECISION
                   ELSE
                       MOVE 'ELIGIBLE    ' TO WS-DECISION
                   END-IF
               END-IF
           END-IF.
       3000-DETERMINE-ADJUSTMENT.
           IF WS-DECISION = 'ELIGIBLE    '
               IF WS-CREDIT-SCORE >= 750
                   COMPUTE WS-ELIGIBLE-INCREASE =
                       WS-CURRENT-LIMIT * 0.50
               ELSE
                   IF WS-CREDIT-SCORE >= 700
                       COMPUTE WS-ELIGIBLE-INCREASE =
                           WS-CURRENT-LIMIT * 0.25
                   ELSE
                       COMPUTE WS-ELIGIBLE-INCREASE =
                           WS-CURRENT-LIMIT * 0.10
                   END-IF
               END-IF
               COMPUTE WS-MAX-ALLOWED =
                   WS-INCOME * 0.30
               COMPUTE WS-NEW-LIMIT =
                   WS-CURRENT-LIMIT + WS-ELIGIBLE-INCREASE
               IF WS-NEW-LIMIT > WS-MAX-ALLOWED
                   MOVE WS-MAX-ALLOWED TO WS-NEW-LIMIT
               END-IF
               MOVE 'INCREASE    ' TO WS-DECISION
               MOVE 'A001' TO WS-REASON-CODE
           ELSE
               IF WS-DECISION = 'DECREASE    '
                   COMPUTE WS-NEW-LIMIT =
                       WS-CURRENT-LIMIT * 0.75
                   IF WS-NEW-LIMIT < WS-CURRENT-BAL
                       MOVE WS-CURRENT-BAL TO WS-NEW-LIMIT
                   END-IF
               ELSE
                   MOVE WS-CURRENT-LIMIT TO WS-NEW-LIMIT
               END-IF
           END-IF
           COMPUTE WS-LIMIT-CHANGE =
               WS-NEW-LIMIT - WS-CURRENT-LIMIT
           IF WS-CURRENT-LIMIT > 0
               COMPUTE WS-LIMIT-PCT-CHG =
                   (WS-LIMIT-CHANGE / WS-CURRENT-LIMIT) * 100
           END-IF.
       4000-OUTPUT.
           DISPLAY 'CREDIT LIMIT REVIEW'
           DISPLAY '==================='
           DISPLAY 'CARD:        ' WS-CARD-NUM
           DISPLAY 'HOLDER:      ' WS-CARD-HOLDER
           DISPLAY 'SCORE:       ' WS-CREDIT-SCORE
           DISPLAY 'CURR LIMIT:  $' WS-CURRENT-LIMIT
           DISPLAY 'UTILIZATION: ' WS-UTILIZATION-RATIO '%'
           DISPLAY 'ON-TIME PMT: ' WS-ON-TIME-COUNT '/12'
           DISPLAY 'DECISION:    ' WS-DECISION
           DISPLAY 'REASON:      ' WS-REASON-CODE
           DISPLAY 'NEW LIMIT:   $' WS-NEW-LIMIT
           DISPLAY 'CHANGE:      $' WS-LIMIT-CHANGE
           DISPLAY 'PCT CHANGE:  ' WS-LIMIT-PCT-CHG '%'.
