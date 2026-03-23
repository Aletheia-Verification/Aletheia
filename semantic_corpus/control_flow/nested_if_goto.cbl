       IDENTIFICATION DIVISION.
       PROGRAM-ID. NESTED-IF-GOTO.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-X          PIC S9(3).
       01  WS-Y          PIC S9(3).
       01  WS-RESULT     PIC X(10).
       PROCEDURE DIVISION.
       0000-MAIN.
           IF WS-X > 0
               IF WS-Y > 0
                   GO TO 1000-BOTH-POS
               END-IF
               GO TO 2000-X-ONLY
           END-IF.
           MOVE 'NEITHER' TO WS-RESULT.
           GO TO 9999-EXIT.
       1000-BOTH-POS.
           MOVE 'BOTH' TO WS-RESULT.
           GO TO 9999-EXIT.
       2000-X-ONLY.
           MOVE 'X-ONLY' TO WS-RESULT.
       9999-EXIT.
           STOP RUN.
