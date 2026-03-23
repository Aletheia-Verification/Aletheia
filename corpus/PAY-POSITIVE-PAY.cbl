       IDENTIFICATION DIVISION.
       PROGRAM-ID. PAY-POSITIVE-PAY.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ISSUED-CHECKS.
           05 WS-ISSUED OCCURS 25 TIMES.
               10 WS-IS-SERIAL   PIC X(10).
               10 WS-IS-AMOUNT   PIC S9(7)V99 COMP-3.
               10 WS-IS-PAYEE    PIC X(25).
               10 WS-IS-DATE     PIC 9(8).
               10 WS-IS-MATCHED  PIC X VALUE 'N'.
                   88 WAS-MATCHED VALUE 'Y'.
       01 WS-PRESENTED-CHECKS.
           05 WS-PRESENT OCCURS 25 TIMES.
               10 WS-PR-SERIAL   PIC X(10).
               10 WS-PR-AMOUNT   PIC S9(7)V99 COMP-3.
               10 WS-PR-PAYEE    PIC X(25).
               10 WS-PR-STATUS   PIC X(8).
       01 WS-ISS-COUNT           PIC 99 VALUE 25.
       01 WS-PRS-COUNT           PIC 99 VALUE 25.
       01 WS-IDX                 PIC 99.
       01 WS-JDX                 PIC 99.
       01 WS-MATCH-COUNT         PIC 99.
       01 WS-EXCEPTION-COUNT     PIC 99.
       01 WS-STALE-COUNT         PIC 99.
       01 WS-MATCHED-AMT         PIC S9(9)V99 COMP-3.
       01 WS-EXCEPTION-AMT       PIC S9(9)V99 COMP-3.
       01 WS-FOUND-FLAG          PIC X.
       01 WS-AMT-TOLERANCE       PIC S9(3)V99 COMP-3
           VALUE 0.00.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-MATCH-CHECKS
           PERFORM 3000-FLAG-EXCEPTIONS
           PERFORM 4000-REPORT
           STOP RUN.
       1000-INIT.
           MOVE 0 TO WS-MATCH-COUNT
           MOVE 0 TO WS-EXCEPTION-COUNT
           MOVE 0 TO WS-STALE-COUNT
           MOVE 0 TO WS-MATCHED-AMT
           MOVE 0 TO WS-EXCEPTION-AMT.
       2000-MATCH-CHECKS.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-PRS-COUNT
               MOVE 'N' TO WS-FOUND-FLAG
               PERFORM VARYING WS-JDX FROM 1 BY 1
                   UNTIL WS-JDX > WS-ISS-COUNT
                   IF WS-PR-SERIAL(WS-IDX) =
                       WS-IS-SERIAL(WS-JDX)
                       AND NOT WAS-MATCHED(WS-JDX)
                       IF WS-PR-AMOUNT(WS-IDX) =
                           WS-IS-AMOUNT(WS-JDX)
                           MOVE 'MATCH   ' TO
                               WS-PR-STATUS(WS-IDX)
                           MOVE 'Y' TO
                               WS-IS-MATCHED(WS-JDX)
                           MOVE 'Y' TO WS-FOUND-FLAG
                           ADD 1 TO WS-MATCH-COUNT
                           ADD WS-PR-AMOUNT(WS-IDX) TO
                               WS-MATCHED-AMT
                       ELSE
                           MOVE 'AMT-DIFF' TO
                               WS-PR-STATUS(WS-IDX)
                           MOVE 'Y' TO WS-FOUND-FLAG
                           ADD 1 TO WS-EXCEPTION-COUNT
                           ADD WS-PR-AMOUNT(WS-IDX) TO
                               WS-EXCEPTION-AMT
                       END-IF
                   END-IF
               END-PERFORM
               IF WS-FOUND-FLAG = 'N'
                   MOVE 'NO-ISSUE' TO WS-PR-STATUS(WS-IDX)
                   ADD 1 TO WS-EXCEPTION-COUNT
                   ADD WS-PR-AMOUNT(WS-IDX) TO
                       WS-EXCEPTION-AMT
               END-IF
           END-PERFORM.
       3000-FLAG-EXCEPTIONS.
           PERFORM VARYING WS-JDX FROM 1 BY 1
               UNTIL WS-JDX > WS-ISS-COUNT
               IF NOT WAS-MATCHED(WS-JDX)
                   ADD 1 TO WS-STALE-COUNT
               END-IF
           END-PERFORM.
       4000-REPORT.
           DISPLAY 'POSITIVE PAY RECONCILIATION'
           DISPLAY '==========================='
           DISPLAY 'ISSUED:     ' WS-ISS-COUNT
           DISPLAY 'PRESENTED:  ' WS-PRS-COUNT
           DISPLAY 'MATCHED:    ' WS-MATCH-COUNT
           DISPLAY 'EXCEPTIONS: ' WS-EXCEPTION-COUNT
           DISPLAY 'STALE/VOID: ' WS-STALE-COUNT
           DISPLAY 'MATCHED$:   $' WS-MATCHED-AMT
           DISPLAY 'EXCEPTION$: $' WS-EXCEPTION-AMT
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-PRS-COUNT
               IF WS-PR-STATUS(WS-IDX) NOT = 'MATCH   '
                   DISPLAY '  EXC: ' WS-PR-SERIAL(WS-IDX)
                       ' $' WS-PR-AMOUNT(WS-IDX)
                       ' ' WS-PR-STATUS(WS-IDX)
               END-IF
           END-PERFORM.
