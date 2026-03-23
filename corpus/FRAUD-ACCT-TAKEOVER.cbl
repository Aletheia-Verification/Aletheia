       IDENTIFICATION DIVISION.
       PROGRAM-ID. FRAUD-ACCT-TAKEOVER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ACCT-NUM                PIC X(12).
       01 WS-ACTIVITY-TABLE.
           05 WS-ACTIVITY OCCURS 10.
               10 WS-ACT-TYPE        PIC X(3).
               10 WS-ACT-TIME        PIC 9(6).
               10 WS-ACT-RESULT      PIC X(1).
       01 WS-ACT-IDX                 PIC 9(2).
       01 WS-ACT-COUNT               PIC 9(2).
       01 WS-ATO-INDICATORS.
           05 WS-PWD-CHANGES         PIC 9(2).
           05 WS-ADDR-CHANGES        PIC 9(2).
           05 WS-PHONE-CHANGES       PIC 9(2).
           05 WS-EMAIL-CHANGES       PIC 9(2).
           05 WS-FAILED-LOGINS       PIC 9(2).
       01 WS-ATO-SCORE               PIC S9(3) COMP-3.
       01 WS-ATO-STATUS              PIC X(1).
           88 WS-NORMAL              VALUE 'N'.
           88 WS-SUSPICIOUS          VALUE 'S'.
           88 WS-COMPROMISED         VALUE 'C'.
       01 WS-NARRATIVE               PIC X(40).
       01 WS-CASH-COUNT              PIC 9(3).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-ANALYZE-ACTIVITY
           PERFORM 3000-SCORE-ATO
           PERFORM 4000-DETERMINE-STATUS
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-ATO-SCORE
           MOVE 0 TO WS-PWD-CHANGES
           MOVE 0 TO WS-ADDR-CHANGES
           MOVE 0 TO WS-PHONE-CHANGES
           MOVE 0 TO WS-EMAIL-CHANGES
           MOVE 0 TO WS-FAILED-LOGINS
           MOVE 0 TO WS-CASH-COUNT
           SET WS-NORMAL TO TRUE.
       2000-ANALYZE-ACTIVITY.
           PERFORM VARYING WS-ACT-IDX FROM 1 BY 1
               UNTIL WS-ACT-IDX > WS-ACT-COUNT
               EVALUATE WS-ACT-TYPE(WS-ACT-IDX)
                   WHEN 'PWD'
                       ADD 1 TO WS-PWD-CHANGES
                   WHEN 'ADR'
                       ADD 1 TO WS-ADDR-CHANGES
                   WHEN 'PHN'
                       ADD 1 TO WS-PHONE-CHANGES
                   WHEN 'EML'
                       ADD 1 TO WS-EMAIL-CHANGES
                   WHEN 'LGN'
                       IF WS-ACT-RESULT(WS-ACT-IDX) = 'F'
                           ADD 1 TO WS-FAILED-LOGINS
                       END-IF
               END-EVALUATE
           END-PERFORM
           MOVE 'ACCOUNT ACTIVITY REVIEW' TO WS-NARRATIVE
           INSPECT WS-NARRATIVE
               TALLYING WS-CASH-COUNT FOR ALL 'A'.
       3000-SCORE-ATO.
           IF WS-PWD-CHANGES > 1
               ADD 25 TO WS-ATO-SCORE
           END-IF
           IF WS-ADDR-CHANGES > 0
               ADD 30 TO WS-ATO-SCORE
           END-IF
           IF WS-PHONE-CHANGES > 0
               ADD 20 TO WS-ATO-SCORE
           END-IF
           IF WS-EMAIL-CHANGES > 0
               ADD 25 TO WS-ATO-SCORE
           END-IF
           IF WS-FAILED-LOGINS > 3
               COMPUTE WS-ATO-SCORE =
                   WS-ATO-SCORE + WS-FAILED-LOGINS * 5
           END-IF.
       4000-DETERMINE-STATUS.
           EVALUATE TRUE
               WHEN WS-ATO-SCORE >= 60
                   SET WS-COMPROMISED TO TRUE
               WHEN WS-ATO-SCORE >= 30
                   SET WS-SUSPICIOUS TO TRUE
               WHEN OTHER
                   SET WS-NORMAL TO TRUE
           END-EVALUATE.
       5000-DISPLAY-RESULTS.
           DISPLAY 'ACCOUNT TAKEOVER ANALYSIS'
           DISPLAY '========================='
           DISPLAY 'ACCOUNT:       ' WS-ACCT-NUM
           DISPLAY 'PWD CHANGES:   ' WS-PWD-CHANGES
           DISPLAY 'ADDR CHANGES:  ' WS-ADDR-CHANGES
           DISPLAY 'PHONE CHANGES: ' WS-PHONE-CHANGES
           DISPLAY 'EMAIL CHANGES: ' WS-EMAIL-CHANGES
           DISPLAY 'FAILED LOGINS: ' WS-FAILED-LOGINS
           DISPLAY 'ATO SCORE:     ' WS-ATO-SCORE
           IF WS-COMPROMISED
               DISPLAY 'STATUS: COMPROMISED'
           END-IF
           IF WS-SUSPICIOUS
               DISPLAY 'STATUS: SUSPICIOUS'
           END-IF
           IF WS-NORMAL
               DISPLAY 'STATUS: NORMAL'
           END-IF.
