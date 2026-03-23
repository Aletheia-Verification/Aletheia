       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOAN-CREDIT-SCORE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-APPLICANT.
           05 WS-APP-NAME          PIC X(30).
           05 WS-APP-SSN           PIC X(9).
           05 WS-CREDIT-SCORE      PIC 9(3).
           05 WS-ANNUAL-INCOME     PIC S9(9)V99 COMP-3.
           05 WS-TOTAL-DEBT        PIC S9(9)V99 COMP-3.
           05 WS-EMPLOYMENT-YRS    PIC 9(2).
           05 WS-BANKRUPTCY-FLAG   PIC X.
               88 HAS-BANKRUPTCY   VALUE 'Y'.
           05 WS-FORECLOSURE-FLAG  PIC X.
               88 HAS-FORECLOSURE  VALUE 'Y'.
       01 WS-LOAN-REQUEST.
           05 WS-LOAN-AMOUNT       PIC S9(9)V99 COMP-3.
           05 WS-LOAN-TERM         PIC 9(3).
           05 WS-LOAN-PURPOSE      PIC X(2).
               88 PURPOSE-HOME     VALUE 'HM'.
               88 PURPOSE-AUTO     VALUE 'AU'.
               88 PURPOSE-PERSONAL VALUE 'PL'.
               88 PURPOSE-BUSINESS VALUE 'BL'.
       01 WS-DECISION.
           05 WS-DTI-RATIO         PIC S9(3)V99 COMP-3.
           05 WS-RISK-POINTS       PIC S9(3) COMP-3.
           05 WS-MAX-POINTS        PIC S9(3) COMP-3 VALUE 100.
           05 WS-APPROVAL-STATUS   PIC X(11).
           05 WS-OFFERED-RATE      PIC S9(2)V9(4) COMP-3.
           05 WS-MAX-APPROVED      PIC S9(9)V99 COMP-3.
       01 WS-MONTHLY-INCOME        PIC S9(7)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-CALC-DTI
           PERFORM 2000-SCORE-RISK
           PERFORM 3000-DETERMINE-RATE
           PERFORM 4000-MAKE-DECISION
           PERFORM 5000-OUTPUT-DECISION
           STOP RUN.
       1000-CALC-DTI.
           COMPUTE WS-MONTHLY-INCOME =
               WS-ANNUAL-INCOME / 12
           IF WS-MONTHLY-INCOME > 0
               COMPUTE WS-DTI-RATIO =
                   (WS-TOTAL-DEBT / WS-MONTHLY-INCOME) * 100
           ELSE
               MOVE 999.99 TO WS-DTI-RATIO
           END-IF.
       2000-SCORE-RISK.
           MOVE 0 TO WS-RISK-POINTS
           IF WS-CREDIT-SCORE >= 750
               ADD 40 TO WS-RISK-POINTS
           ELSE
               IF WS-CREDIT-SCORE >= 700
                   ADD 30 TO WS-RISK-POINTS
               ELSE
                   IF WS-CREDIT-SCORE >= 650
                       ADD 20 TO WS-RISK-POINTS
                   ELSE
                       ADD 5 TO WS-RISK-POINTS
                   END-IF
               END-IF
           END-IF
           IF WS-DTI-RATIO < 30
               ADD 25 TO WS-RISK-POINTS
           ELSE
               IF WS-DTI-RATIO < 40
                   ADD 15 TO WS-RISK-POINTS
               ELSE
                   IF WS-DTI-RATIO < 50
                       ADD 5 TO WS-RISK-POINTS
                   END-IF
               END-IF
           END-IF
           IF WS-EMPLOYMENT-YRS >= 5
               ADD 15 TO WS-RISK-POINTS
           ELSE
               IF WS-EMPLOYMENT-YRS >= 2
                   ADD 10 TO WS-RISK-POINTS
               END-IF
           END-IF
           IF HAS-BANKRUPTCY
               SUBTRACT 25 FROM WS-RISK-POINTS
           END-IF
           IF HAS-FORECLOSURE
               SUBTRACT 30 FROM WS-RISK-POINTS
           END-IF
           EVALUATE TRUE
               WHEN PURPOSE-HOME
                   ADD 10 TO WS-RISK-POINTS
               WHEN PURPOSE-AUTO
                   ADD 5 TO WS-RISK-POINTS
               WHEN PURPOSE-PERSONAL
                   ADD 0 TO WS-RISK-POINTS
               WHEN PURPOSE-BUSINESS
                   ADD 3 TO WS-RISK-POINTS
           END-EVALUATE.
       3000-DETERMINE-RATE.
           IF WS-RISK-POINTS >= 70
               MOVE 4.2500 TO WS-OFFERED-RATE
           ELSE
               IF WS-RISK-POINTS >= 50
                   MOVE 5.7500 TO WS-OFFERED-RATE
               ELSE
                   IF WS-RISK-POINTS >= 30
                       MOVE 8.2500 TO WS-OFFERED-RATE
                   ELSE
                       MOVE 12.9900 TO WS-OFFERED-RATE
                   END-IF
               END-IF
           END-IF
           IF PURPOSE-HOME
               SUBTRACT 0.5000 FROM WS-OFFERED-RATE
           END-IF.
       4000-MAKE-DECISION.
           IF WS-RISK-POINTS < 20
               MOVE 'DECLINED   ' TO WS-APPROVAL-STATUS
               MOVE 0 TO WS-MAX-APPROVED
           ELSE
               IF WS-RISK-POINTS < 40
                   MOVE 'CONDITIONAL' TO WS-APPROVAL-STATUS
                   COMPUTE WS-MAX-APPROVED =
                       WS-LOAN-AMOUNT * 0.75
               ELSE
                   MOVE 'APPROVED   ' TO WS-APPROVAL-STATUS
                   MOVE WS-LOAN-AMOUNT TO WS-MAX-APPROVED
               END-IF
           END-IF.
       5000-OUTPUT-DECISION.
           DISPLAY 'CREDIT DECISION REPORT'
           DISPLAY '======================'
           DISPLAY 'APPLICANT: ' WS-APP-NAME
           DISPLAY 'SCORE:     ' WS-CREDIT-SCORE
           DISPLAY 'DTI RATIO: ' WS-DTI-RATIO
           DISPLAY 'RISK PTS:  ' WS-RISK-POINTS
           DISPLAY 'STATUS:    ' WS-APPROVAL-STATUS
           IF WS-MAX-APPROVED > 0
               DISPLAY 'APPROVED:  $' WS-MAX-APPROVED
               DISPLAY 'RATE:      ' WS-OFFERED-RATE
           END-IF.
