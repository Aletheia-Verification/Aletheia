       IDENTIFICATION DIVISION.
       PROGRAM-ID. REG-AML-CASE-SCORE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CASE.
           05 WS-CASE-ID          PIC X(10).
           05 WS-ALERT-TYPE       PIC X(2).
               88 AT-CTR          VALUE 'CT'.
               88 AT-SAR          VALUE 'SA'.
               88 AT-VELOCITY     VALUE 'VE'.
               88 AT-STRUCTURING  VALUE 'ST'.
               88 AT-GEOGRAPHIC   VALUE 'GE'.
           05 WS-ALERT-DATE       PIC 9(8).
           05 WS-CUST-ID          PIC X(12).
           05 WS-TXN-AMOUNT       PIC S9(11)V99 COMP-3.
       01 WS-CUST-PROFILE.
           05 WS-CUST-RISK        PIC 9.
               88 CR-LOW          VALUE 1.
               88 CR-MEDIUM       VALUE 2.
               88 CR-HIGH         VALUE 3.
           05 WS-CUST-TENURE-MO   PIC 9(4).
           05 WS-PRIOR-ALERTS     PIC 9(3).
           05 WS-PRIOR-SARS       PIC 9(2).
           05 WS-PEP-FLAG         PIC X.
               88 IS-PEP          VALUE 'Y'.
       01 WS-SCORE-COMPONENTS.
           05 WS-TYPE-SCORE       PIC S9(3) COMP-3.
           05 WS-RISK-SCORE       PIC S9(3) COMP-3.
           05 WS-HISTORY-SCORE    PIC S9(3) COMP-3.
           05 WS-AMOUNT-SCORE     PIC S9(3) COMP-3.
           05 WS-PEP-SCORE        PIC S9(3) COMP-3.
           05 WS-TOTAL-SCORE      PIC S9(3) COMP-3.
       01 WS-DISPOSITION          PIC X(15).
       01 WS-ESCALATE-FLAG        PIC X VALUE 'N'.
           88 NEEDS-ESCALATION    VALUE 'Y'.
       01 WS-SLA-DAYS             PIC 9(2).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-SCORE-ALERT-TYPE
           PERFORM 2000-SCORE-RISK
           PERFORM 3000-SCORE-HISTORY
           PERFORM 4000-SCORE-AMOUNT
           PERFORM 5000-CALC-TOTAL
           PERFORM 6000-DETERMINE-DISPOSITION
           PERFORM 7000-OUTPUT
           STOP RUN.
       1000-SCORE-ALERT-TYPE.
           EVALUATE TRUE
               WHEN AT-CTR
                   MOVE 10 TO WS-TYPE-SCORE
               WHEN AT-SAR
                   MOVE 30 TO WS-TYPE-SCORE
               WHEN AT-VELOCITY
                   MOVE 25 TO WS-TYPE-SCORE
               WHEN AT-STRUCTURING
                   MOVE 35 TO WS-TYPE-SCORE
               WHEN AT-GEOGRAPHIC
                   MOVE 20 TO WS-TYPE-SCORE
               WHEN OTHER
                   MOVE 5 TO WS-TYPE-SCORE
           END-EVALUATE.
       2000-SCORE-RISK.
           EVALUATE TRUE
               WHEN CR-LOW
                   MOVE 5 TO WS-RISK-SCORE
               WHEN CR-MEDIUM
                   MOVE 15 TO WS-RISK-SCORE
               WHEN CR-HIGH
                   MOVE 30 TO WS-RISK-SCORE
               WHEN OTHER
                   MOVE 10 TO WS-RISK-SCORE
           END-EVALUATE
           IF IS-PEP
               MOVE 20 TO WS-PEP-SCORE
           ELSE
               MOVE 0 TO WS-PEP-SCORE
           END-IF.
       3000-SCORE-HISTORY.
           IF WS-PRIOR-SARS > 0
               COMPUTE WS-HISTORY-SCORE =
                   WS-PRIOR-SARS * 15
               IF WS-HISTORY-SCORE > 30
                   MOVE 30 TO WS-HISTORY-SCORE
               END-IF
           ELSE
               IF WS-PRIOR-ALERTS > 5
                   MOVE 15 TO WS-HISTORY-SCORE
               ELSE
                   IF WS-PRIOR-ALERTS > 0
                       MOVE 5 TO WS-HISTORY-SCORE
                   ELSE
                       MOVE 0 TO WS-HISTORY-SCORE
                   END-IF
               END-IF
           END-IF.
       4000-SCORE-AMOUNT.
           IF WS-TXN-AMOUNT > 100000.00
               MOVE 20 TO WS-AMOUNT-SCORE
           ELSE
               IF WS-TXN-AMOUNT > 10000.00
                   MOVE 10 TO WS-AMOUNT-SCORE
               ELSE
                   MOVE 5 TO WS-AMOUNT-SCORE
               END-IF
           END-IF.
       5000-CALC-TOTAL.
           COMPUTE WS-TOTAL-SCORE =
               WS-TYPE-SCORE + WS-RISK-SCORE +
               WS-HISTORY-SCORE + WS-AMOUNT-SCORE +
               WS-PEP-SCORE.
       6000-DETERMINE-DISPOSITION.
           IF WS-TOTAL-SCORE >= 80
               MOVE 'FILE SAR       ' TO WS-DISPOSITION
               MOVE 'Y' TO WS-ESCALATE-FLAG
               MOVE 5 TO WS-SLA-DAYS
           ELSE
               IF WS-TOTAL-SCORE >= 60
                   MOVE 'INVEST-PRIORITY' TO WS-DISPOSITION
                   MOVE 'Y' TO WS-ESCALATE-FLAG
                   MOVE 10 TO WS-SLA-DAYS
               ELSE
                   IF WS-TOTAL-SCORE >= 40
                       MOVE 'INVESTIGATE    ' TO
                           WS-DISPOSITION
                       MOVE 30 TO WS-SLA-DAYS
                   ELSE
                       MOVE 'CLOSE-NO-ACTION' TO
                           WS-DISPOSITION
                       MOVE 5 TO WS-SLA-DAYS
                   END-IF
               END-IF
           END-IF.
       7000-OUTPUT.
           DISPLAY 'AML CASE SCORING REPORT'
           DISPLAY '======================='
           DISPLAY 'CASE:       ' WS-CASE-ID
           DISPLAY 'ALERT TYPE: ' WS-ALERT-TYPE
           DISPLAY 'CUSTOMER:   ' WS-CUST-ID
           DISPLAY 'AMOUNT:     $' WS-TXN-AMOUNT
           DISPLAY 'TYPE SCORE: ' WS-TYPE-SCORE
           DISPLAY 'RISK SCORE: ' WS-RISK-SCORE
           DISPLAY 'HIST SCORE: ' WS-HISTORY-SCORE
           DISPLAY 'AMT SCORE:  ' WS-AMOUNT-SCORE
           DISPLAY 'PEP SCORE:  ' WS-PEP-SCORE
           DISPLAY 'TOTAL:      ' WS-TOTAL-SCORE
           DISPLAY 'DISPOSITION:' WS-DISPOSITION
           DISPLAY 'SLA DAYS:   ' WS-SLA-DAYS
           IF NEEDS-ESCALATION
               DISPLAY 'ESCALATION REQUIRED'
           END-IF.
