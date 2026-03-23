       IDENTIFICATION DIVISION.
       PROGRAM-ID. REG-SAR-SCREEN.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-TXN-DATA.
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-TXN-AMOUNT          PIC S9(9)V99 COMP-3.
           05 WS-DAILY-TOTAL         PIC S9(9)V99 COMP-3.
           05 WS-TXN-COUNT           PIC 9(3).
           05 WS-TXN-NARRATIVE       PIC X(50).
       01 WS-RISK-SCORE              PIC S9(3) COMP-3.
       01 WS-RISK-LEVEL              PIC X(1).
           88 WS-LOW-RISK            VALUE 'L'.
           88 WS-MED-RISK            VALUE 'M'.
           88 WS-HIGH-RISK           VALUE 'H'.
       01 WS-PATTERN-FLAGS.
           05 WS-STRUCTURING         PIC X VALUE 'N'.
               88 WS-IS-STRUCTURING  VALUE 'Y'.
           05 WS-ROUND-TRIP          PIC X VALUE 'N'.
               88 WS-IS-ROUND-TRIP   VALUE 'Y'.
           05 WS-RAPID-MOVE          PIC X VALUE 'N'.
               88 WS-IS-RAPID        VALUE 'Y'.
       01 WS-SAR-REQUIRED            PIC X VALUE 'N'.
           88 WS-NEEDS-SAR           VALUE 'Y'.
       01 WS-SUSPICIOUS-COUNT        PIC 9(3).
       01 WS-IDX                     PIC 9(3).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CHECK-PATTERNS
           PERFORM 3000-SCORE-RISK
           PERFORM 4000-DETERMINE-SAR
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-RISK-SCORE
           MOVE 0 TO WS-SUSPICIOUS-COUNT
           SET WS-LOW-RISK TO TRUE.
       2000-CHECK-PATTERNS.
           IF WS-DAILY-TOTAL > 8000
               IF WS-DAILY-TOTAL < 10000
                   MOVE 'Y' TO WS-STRUCTURING
                   ADD 40 TO WS-RISK-SCORE
               END-IF
           END-IF
           IF WS-TXN-COUNT > 10
               ADD 20 TO WS-RISK-SCORE
               MOVE 'Y' TO WS-RAPID-MOVE
           END-IF
           MOVE 0 TO WS-SUSPICIOUS-COUNT
           INSPECT WS-TXN-NARRATIVE
               TALLYING WS-SUSPICIOUS-COUNT
               FOR ALL 'CASH'
           IF WS-SUSPICIOUS-COUNT > 0
               ADD 15 TO WS-RISK-SCORE
           END-IF
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-TXN-COUNT
               IF WS-TXN-AMOUNT > 5000
                   ADD 5 TO WS-RISK-SCORE
               END-IF
           END-PERFORM.
       3000-SCORE-RISK.
           EVALUATE TRUE
               WHEN WS-RISK-SCORE >= 60
                   SET WS-HIGH-RISK TO TRUE
               WHEN WS-RISK-SCORE >= 30
                   SET WS-MED-RISK TO TRUE
               WHEN OTHER
                   SET WS-LOW-RISK TO TRUE
           END-EVALUATE.
       4000-DETERMINE-SAR.
           IF WS-HIGH-RISK
               MOVE 'Y' TO WS-SAR-REQUIRED
           ELSE
               IF WS-MED-RISK
                   IF WS-IS-STRUCTURING
                       MOVE 'Y' TO WS-SAR-REQUIRED
                   END-IF
               END-IF
           END-IF.
       5000-DISPLAY-RESULTS.
           DISPLAY 'SAR SCREENING REPORT'
           DISPLAY '===================='
           DISPLAY 'ACCOUNT:       ' WS-ACCT-NUM
           DISPLAY 'TXN AMOUNT:    ' WS-TXN-AMOUNT
           DISPLAY 'DAILY TOTAL:   ' WS-DAILY-TOTAL
           DISPLAY 'TXN COUNT:     ' WS-TXN-COUNT
           DISPLAY 'RISK SCORE:    ' WS-RISK-SCORE
           IF WS-IS-STRUCTURING
               DISPLAY 'PATTERN: STRUCTURING'
           END-IF
           IF WS-IS-RAPID
               DISPLAY 'PATTERN: RAPID MOVEMENT'
           END-IF
           IF WS-NEEDS-SAR
               DISPLAY 'SAR: REQUIRED'
           ELSE
               DISPLAY 'SAR: NOT REQUIRED'
           END-IF.
