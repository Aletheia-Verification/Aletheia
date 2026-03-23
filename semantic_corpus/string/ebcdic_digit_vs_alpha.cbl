       IDENTIFICATION DIVISION.
       PROGRAM-ID. EBCDIC-DIGIT-VS-ALPHA.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-A          PIC X(1).
       01  WS-B          PIC X(1).
       01  WS-RESULT     PIC X(10).
       PROCEDURE DIVISION.
       0000-MAIN.
           IF WS-A > WS-B
               MOVE 'GREATER' TO WS-RESULT
           ELSE
               MOVE 'NOT-GT' TO WS-RESULT
           END-IF.
           STOP RUN.
