       IDENTIFICATION DIVISION.
       PROGRAM-ID. COMP-ELDER-ABUSE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CUSTOMER.
           05 WS-CUST-ID         PIC X(12).
           05 WS-CUST-AGE        PIC 9(3).
           05 WS-CUST-NAME       PIC X(30).
       01 WS-INDICATORS.
           05 WS-LARGE-WD-FLAG   PIC X VALUE 'N'.
               88 HAS-LARGE-WD  VALUE 'Y'.
           05 WS-NEW-POA-FLAG    PIC X VALUE 'N'.
               88 HAS-NEW-POA   VALUE 'Y'.
           05 WS-ACCT-CHG-FLAG   PIC X VALUE 'N'.
               88 HAS-ACCT-CHG  VALUE 'Y'.
           05 WS-FEAR-OBSERVED   PIC X VALUE 'N'.
               88 SHOWED-FEAR   VALUE 'Y'.
           05 WS-THIRD-PARTY-FL  PIC X VALUE 'N'.
               88 TP-DIRECTED   VALUE 'Y'.
       01 WS-RECENT-ACTIVITY.
           05 WS-WD-30DAY-AMT    PIC S9(9)V99 COMP-3.
           05 WS-WD-AVG-PRIOR    PIC S9(7)V99 COMP-3.
           05 WS-ACCT-CHG-COUNT  PIC 9(2).
       01 WS-RISK-SCORE          PIC 9(3).
       01 WS-ALERT-STATUS        PIC X(15).
       01 WS-ACTION              PIC X(30).
       01 WS-WD-RATIO            PIC S9(3)V99 COMP-3.
       01 WS-SCORE-DATE          PIC 9(8).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-CHECK-AGE
           PERFORM 2000-SCORE-INDICATORS
           PERFORM 3000-CHECK-ACTIVITY
           PERFORM 4000-DETERMINE-ACTION
           PERFORM 5000-OUTPUT
           STOP RUN.
       1000-CHECK-AGE.
           ACCEPT WS-SCORE-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-RISK-SCORE
           IF WS-CUST-AGE >= 65
               ADD 10 TO WS-RISK-SCORE
           END-IF
           IF WS-CUST-AGE >= 80
               ADD 10 TO WS-RISK-SCORE
           END-IF.
       2000-SCORE-INDICATORS.
           IF HAS-LARGE-WD
               ADD 20 TO WS-RISK-SCORE
           END-IF
           IF HAS-NEW-POA
               ADD 15 TO WS-RISK-SCORE
           END-IF
           IF HAS-ACCT-CHG
               ADD 10 TO WS-RISK-SCORE
           END-IF
           IF SHOWED-FEAR
               ADD 25 TO WS-RISK-SCORE
           END-IF
           IF TP-DIRECTED
               ADD 20 TO WS-RISK-SCORE
           END-IF.
       3000-CHECK-ACTIVITY.
           IF WS-WD-AVG-PRIOR > 0
               COMPUTE WS-WD-RATIO =
                   WS-WD-30DAY-AMT / WS-WD-AVG-PRIOR
               IF WS-WD-RATIO > 5
                   ADD 20 TO WS-RISK-SCORE
               ELSE
                   IF WS-WD-RATIO > 3
                       ADD 10 TO WS-RISK-SCORE
                   END-IF
               END-IF
           END-IF
           IF WS-ACCT-CHG-COUNT > 3
               ADD 15 TO WS-RISK-SCORE
           END-IF.
       4000-DETERMINE-ACTION.
           IF WS-RISK-SCORE >= 70
               MOVE 'HIGH RISK      ' TO WS-ALERT-STATUS
               MOVE 'FILE SAR - CONTACT APS'
                   TO WS-ACTION
           ELSE
               IF WS-RISK-SCORE >= 40
                   MOVE 'MEDIUM RISK    ' TO WS-ALERT-STATUS
                   MOVE 'ESCALATE TO BSA OFFICER'
                       TO WS-ACTION
               ELSE
                   IF WS-RISK-SCORE >= 20
                       MOVE 'LOW RISK       ' TO
                           WS-ALERT-STATUS
                       MOVE 'DOCUMENT AND MONITOR'
                           TO WS-ACTION
                   ELSE
                       MOVE 'NO CONCERN     ' TO
                           WS-ALERT-STATUS
                       MOVE SPACES TO WS-ACTION
                   END-IF
               END-IF
           END-IF.
       5000-OUTPUT.
           DISPLAY 'ELDER FINANCIAL ABUSE SCREENING'
           DISPLAY '==============================='
           DISPLAY 'CUSTOMER: ' WS-CUST-ID
           DISPLAY 'NAME:     ' WS-CUST-NAME
           DISPLAY 'AGE:      ' WS-CUST-AGE
           DISPLAY 'RISK:     ' WS-RISK-SCORE
           DISPLAY 'STATUS:   ' WS-ALERT-STATUS
           IF WS-ACTION NOT = SPACES
               DISPLAY 'ACTION:   ' WS-ACTION
           END-IF.
