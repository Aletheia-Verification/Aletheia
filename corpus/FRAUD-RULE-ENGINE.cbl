       IDENTIFICATION DIVISION.
       PROGRAM-ID. FRAUD-RULE-ENGINE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-TXN-DATA.
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-TXN-AMOUNT          PIC S9(9)V99 COMP-3.
           05 WS-TXN-COUNTRY         PIC X(3).
           05 WS-TXN-MCC             PIC X(4).
           05 WS-TXN-CHANNEL         PIC X(1).
       01 WS-RULE-TABLE.
           05 WS-RULE OCCURS 10.
               10 WS-RL-ID           PIC 9(3).
               10 WS-RL-NAME         PIC X(15).
               10 WS-RL-POINTS       PIC S9(3) COMP-3.
               10 WS-RL-TRIGGERED    PIC X VALUE 'N'.
                   88 WS-RL-FIRED    VALUE 'Y'.
       01 WS-RL-IDX                  PIC 9(2).
       01 WS-TOTAL-POINTS            PIC S9(3) COMP-3.
       01 WS-RULES-FIRED             PIC 9(2).
       01 WS-DECISION                PIC X(1).
           88 WS-APPROVE             VALUE 'A'.
           88 WS-REVIEW              VALUE 'R'.
           88 WS-DECLINE             VALUE 'D'.
       01 WS-APPROVE-THRESH          PIC S9(3) COMP-3
           VALUE 30.
       01 WS-DECLINE-THRESH          PIC S9(3) COMP-3
           VALUE 70.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-EVALUATE-RULES
           PERFORM 3000-CALC-TOTAL
           PERFORM 4000-MAKE-DECISION
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-POINTS
           MOVE 0 TO WS-RULES-FIRED
           SET WS-APPROVE TO TRUE
           MOVE 1 TO WS-RL-ID(1)
           MOVE 'HIGH AMOUNT' TO WS-RL-NAME(1)
           MOVE 25 TO WS-RL-POINTS(1)
           MOVE 2 TO WS-RL-ID(2)
           MOVE 'INTL TXN' TO WS-RL-NAME(2)
           MOVE 20 TO WS-RL-POINTS(2)
           MOVE 3 TO WS-RL-ID(3)
           MOVE 'RISKY MCC' TO WS-RL-NAME(3)
           MOVE 30 TO WS-RL-POINTS(3)
           MOVE 4 TO WS-RL-ID(4)
           MOVE 'ODD CHANNEL' TO WS-RL-NAME(4)
           MOVE 15 TO WS-RL-POINTS(4).
       2000-EVALUATE-RULES.
           IF WS-TXN-AMOUNT > 5000
               MOVE 'Y' TO WS-RL-TRIGGERED(1)
           END-IF
           IF WS-TXN-COUNTRY NOT = 'USA'
               MOVE 'Y' TO WS-RL-TRIGGERED(2)
           END-IF
           EVALUATE WS-TXN-MCC
               WHEN '7995'
                   MOVE 'Y' TO WS-RL-TRIGGERED(3)
               WHEN '5967'
                   MOVE 'Y' TO WS-RL-TRIGGERED(3)
               WHEN '5966'
                   MOVE 'Y' TO WS-RL-TRIGGERED(3)
               WHEN OTHER
                   CONTINUE
           END-EVALUATE
           IF WS-TXN-CHANNEL = 'X'
               MOVE 'Y' TO WS-RL-TRIGGERED(4)
           END-IF.
       3000-CALC-TOTAL.
           PERFORM VARYING WS-RL-IDX FROM 1 BY 1
               UNTIL WS-RL-IDX > 4
               IF WS-RL-TRIGGERED(WS-RL-IDX) = 'Y'
                   ADD WS-RL-POINTS(WS-RL-IDX) TO
                       WS-TOTAL-POINTS
                   ADD 1 TO WS-RULES-FIRED
               END-IF
           END-PERFORM.
       4000-MAKE-DECISION.
           EVALUATE TRUE
               WHEN WS-TOTAL-POINTS >= WS-DECLINE-THRESH
                   SET WS-DECLINE TO TRUE
               WHEN WS-TOTAL-POINTS >= WS-APPROVE-THRESH
                   SET WS-REVIEW TO TRUE
               WHEN OTHER
                   SET WS-APPROVE TO TRUE
           END-EVALUATE.
       5000-DISPLAY-RESULTS.
           DISPLAY 'FRAUD RULE ENGINE'
           DISPLAY '================='
           DISPLAY 'ACCOUNT:     ' WS-ACCT-NUM
           DISPLAY 'AMOUNT:      ' WS-TXN-AMOUNT
           DISPLAY 'RULES FIRED: ' WS-RULES-FIRED
           DISPLAY 'TOTAL POINTS:' WS-TOTAL-POINTS
           PERFORM VARYING WS-RL-IDX FROM 1 BY 1
               UNTIL WS-RL-IDX > 4
               IF WS-RL-TRIGGERED(WS-RL-IDX) = 'Y'
                   DISPLAY '  RULE: '
                       WS-RL-NAME(WS-RL-IDX)
                       ' PTS=' WS-RL-POINTS(WS-RL-IDX)
               END-IF
           END-PERFORM
           IF WS-APPROVE
               DISPLAY 'DECISION: APPROVE'
           END-IF
           IF WS-REVIEW
               DISPLAY 'DECISION: REVIEW'
           END-IF
           IF WS-DECLINE
               DISPLAY 'DECISION: DECLINE'
           END-IF.
