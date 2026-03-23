       IDENTIFICATION DIVISION.
       PROGRAM-ID. FRAUD-LINK-ANALYZE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-SUBJECT-ACCT            PIC X(12).
       01 WS-LINK-TABLE.
           05 WS-LINK OCCURS 15.
               10 WS-LK-ACCT         PIC X(12).
               10 WS-LK-TYPE         PIC X(3).
               10 WS-LK-AMOUNT       PIC S9(9)V99 COMP-3.
               10 WS-LK-COUNT        PIC 9(3).
       01 WS-LK-IDX                  PIC 9(2).
       01 WS-LINK-COUNT              PIC 9(2).
       01 WS-TOTAL-LINKED-AMT        PIC S9(11)V99 COMP-3.
       01 WS-UNIQUE-LINKS            PIC 9(2).
       01 WS-SUSPICIOUS-LINKS        PIC 9(2).
       01 WS-RISK-SCORE              PIC S9(3) COMP-3.
       01 WS-LINK-STATUS             PIC X(1).
           88 WS-CLEAN               VALUE 'C'.
           88 WS-REVIEW              VALUE 'R'.
           88 WS-BLOCK               VALUE 'B'.
       01 WS-ALERT-MSG               PIC X(60).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-ANALYZE-LINKS
           PERFORM 3000-ASSESS-RISK
           PERFORM 4000-BUILD-ALERT
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-LINKED-AMT
           MOVE 0 TO WS-UNIQUE-LINKS
           MOVE 0 TO WS-SUSPICIOUS-LINKS
           MOVE 0 TO WS-RISK-SCORE
           SET WS-CLEAN TO TRUE.
       2000-ANALYZE-LINKS.
           PERFORM VARYING WS-LK-IDX FROM 1 BY 1
               UNTIL WS-LK-IDX > WS-LINK-COUNT
               ADD 1 TO WS-UNIQUE-LINKS
               ADD WS-LK-AMOUNT(WS-LK-IDX) TO
                   WS-TOTAL-LINKED-AMT
               IF WS-LK-COUNT(WS-LK-IDX) > 5
                   ADD 1 TO WS-SUSPICIOUS-LINKS
                   ADD 15 TO WS-RISK-SCORE
               END-IF
               IF WS-LK-AMOUNT(WS-LK-IDX) > 10000
                   ADD 10 TO WS-RISK-SCORE
               END-IF
           END-PERFORM.
       3000-ASSESS-RISK.
           IF WS-UNIQUE-LINKS > 10
               ADD 20 TO WS-RISK-SCORE
           END-IF
           IF WS-TOTAL-LINKED-AMT > 100000
               ADD 25 TO WS-RISK-SCORE
           END-IF
           EVALUATE TRUE
               WHEN WS-RISK-SCORE >= 60
                   SET WS-BLOCK TO TRUE
               WHEN WS-RISK-SCORE >= 30
                   SET WS-REVIEW TO TRUE
               WHEN OTHER
                   SET WS-CLEAN TO TRUE
           END-EVALUATE.
       4000-BUILD-ALERT.
           IF WS-BLOCK OR WS-REVIEW
               STRING 'LINK ALERT ' DELIMITED BY SIZE
                      WS-SUBJECT-ACCT DELIMITED BY SIZE
                      ' LINKS=' DELIMITED BY SIZE
                      WS-UNIQUE-LINKS DELIMITED BY SIZE
                      ' AMT=' DELIMITED BY SIZE
                      WS-TOTAL-LINKED-AMT DELIMITED BY SIZE
                      INTO WS-ALERT-MSG
               END-STRING
           END-IF.
       5000-DISPLAY-RESULTS.
           DISPLAY 'LINK ANALYSIS REPORT'
           DISPLAY '===================='
           DISPLAY 'SUBJECT ACCT:  ' WS-SUBJECT-ACCT
           DISPLAY 'LINKS:         ' WS-UNIQUE-LINKS
           DISPLAY 'SUSPICIOUS:    ' WS-SUSPICIOUS-LINKS
           DISPLAY 'LINKED AMOUNT: ' WS-TOTAL-LINKED-AMT
           DISPLAY 'RISK SCORE:    ' WS-RISK-SCORE
           IF WS-BLOCK
               DISPLAY 'STATUS: BLOCKED'
           END-IF
           IF WS-REVIEW
               DISPLAY 'STATUS: REVIEW'
           END-IF
           IF WS-CLEAN
               DISPLAY 'STATUS: CLEAN'
           END-IF.
