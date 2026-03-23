       IDENTIFICATION DIVISION.
       PROGRAM-ID. EBCDIC-SPECIAL-SORT.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-A          PIC X.
       01  WS-B          PIC X.
       01  WS-RESULT     PIC X.
       PROCEDURE DIVISION.
       0000-MAIN.
           IF WS-A < WS-B
               MOVE 'Y' TO WS-RESULT
           ELSE
               MOVE 'N' TO WS-RESULT
           END-IF.
           STOP RUN.
