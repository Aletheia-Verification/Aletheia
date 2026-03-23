       IDENTIFICATION DIVISION.
       PROGRAM-ID. EBCDIC-LOWER-VS-UPPER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-A          PIC X(1).
       01  WS-B          PIC X(1).
       01  WS-RESULT     PIC X(10).
       PROCEDURE DIVISION.
       0000-MAIN.
           IF WS-A < WS-B
               MOVE 'LESS' TO WS-RESULT
           ELSE
               MOVE 'NOT-LESS' TO WS-RESULT
           END-IF.
           STOP RUN.
