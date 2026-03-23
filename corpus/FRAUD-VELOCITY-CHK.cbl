       IDENTIFICATION DIVISION.
       PROGRAM-ID. FRAUD-VELOCITY-CHK.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ACCT-NUM                PIC X(12).
       01 WS-CURRENT-TXN-AMT        PIC S9(9)V99 COMP-3.
       01 WS-TXN-HISTORY.
           05 WS-TXN-ENTRY OCCURS 20.
               10 WS-TH-AMOUNT       PIC S9(9)V99 COMP-3.
               10 WS-TH-TIME         PIC 9(6).
               10 WS-TH-TYPE         PIC X(2).
       01 WS-TH-IDX                  PIC 9(2).
       01 WS-TH-COUNT                PIC 9(2).
       01 WS-VELOCITY-FIELDS.
           05 WS-1HR-COUNT           PIC 9(2).
           05 WS-1HR-TOTAL           PIC S9(9)V99 COMP-3.
           05 WS-24HR-COUNT          PIC 9(3).
           05 WS-24HR-TOTAL          PIC S9(11)V99 COMP-3.
       01 WS-LIMITS.
           05 WS-1HR-COUNT-LIM       PIC 9(2) VALUE 5.
           05 WS-1HR-TOTAL-LIM       PIC S9(7)V99 COMP-3
               VALUE 5000.00.
           05 WS-24HR-COUNT-LIM      PIC 9(3) VALUE 20.
           05 WS-24HR-TOTAL-LIM      PIC S9(9)V99 COMP-3
               VALUE 25000.00.
       01 WS-ALERT-LEVEL             PIC X(1).
           88 WS-NO-ALERT            VALUE 'N'.
           88 WS-WARNING             VALUE 'W'.
           88 WS-BLOCK               VALUE 'B'.
       01 WS-RISK-SCORE              PIC S9(3) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-VELOCITY
           PERFORM 3000-ASSESS-RISK
           PERFORM 4000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-1HR-COUNT
           MOVE 0 TO WS-1HR-TOTAL
           MOVE 0 TO WS-24HR-COUNT
           MOVE 0 TO WS-24HR-TOTAL
           MOVE 0 TO WS-RISK-SCORE
           SET WS-NO-ALERT TO TRUE.
       2000-CALC-VELOCITY.
           PERFORM VARYING WS-TH-IDX FROM 1 BY 1
               UNTIL WS-TH-IDX > WS-TH-COUNT
               ADD 1 TO WS-24HR-COUNT
               ADD WS-TH-AMOUNT(WS-TH-IDX) TO
                   WS-24HR-TOTAL
               IF WS-TH-TIME(WS-TH-IDX) > 0
                   ADD 1 TO WS-1HR-COUNT
                   ADD WS-TH-AMOUNT(WS-TH-IDX) TO
                       WS-1HR-TOTAL
               END-IF
           END-PERFORM
           ADD 1 TO WS-24HR-COUNT
           ADD WS-CURRENT-TXN-AMT TO WS-24HR-TOTAL
           ADD 1 TO WS-1HR-COUNT
           ADD WS-CURRENT-TXN-AMT TO WS-1HR-TOTAL.
       3000-ASSESS-RISK.
           IF WS-1HR-COUNT > WS-1HR-COUNT-LIM
               ADD 30 TO WS-RISK-SCORE
           END-IF
           IF WS-1HR-TOTAL > WS-1HR-TOTAL-LIM
               ADD 25 TO WS-RISK-SCORE
           END-IF
           IF WS-24HR-COUNT > WS-24HR-COUNT-LIM
               ADD 20 TO WS-RISK-SCORE
           END-IF
           IF WS-24HR-TOTAL > WS-24HR-TOTAL-LIM
               ADD 25 TO WS-RISK-SCORE
           END-IF
           EVALUATE TRUE
               WHEN WS-RISK-SCORE >= 50
                   SET WS-BLOCK TO TRUE
               WHEN WS-RISK-SCORE >= 25
                   SET WS-WARNING TO TRUE
               WHEN OTHER
                   SET WS-NO-ALERT TO TRUE
           END-EVALUATE.
       4000-DISPLAY-RESULTS.
           DISPLAY 'VELOCITY CHECK REPORT'
           DISPLAY '====================='
           DISPLAY 'ACCOUNT:     ' WS-ACCT-NUM
           DISPLAY 'TXN AMOUNT:  ' WS-CURRENT-TXN-AMT
           DISPLAY '1HR COUNT:   ' WS-1HR-COUNT
           DISPLAY '1HR TOTAL:   ' WS-1HR-TOTAL
           DISPLAY '24HR COUNT:  ' WS-24HR-COUNT
           DISPLAY '24HR TOTAL:  ' WS-24HR-TOTAL
           DISPLAY 'RISK SCORE:  ' WS-RISK-SCORE
           IF WS-BLOCK
               DISPLAY 'ALERT: BLOCK TRANSACTION'
           END-IF
           IF WS-WARNING
               DISPLAY 'ALERT: WARNING'
           END-IF
           IF WS-NO-ALERT
               DISPLAY 'ALERT: NONE'
           END-IF.
