       IDENTIFICATION DIVISION.
       PROGRAM-ID. EBCDIC-CASE-ORDER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-LOWER       PIC X(1).
       01  WS-UPPER       PIC X(1).
       01  WS-RESULT      PIC X(10).
       PROCEDURE DIVISION.
       0000-MAIN.
           IF WS-LOWER < WS-UPPER
               MOVE 'LOWER-LESS' TO WS-RESULT
           ELSE
               MOVE 'LOWER-GTE' TO WS-RESULT
           END-IF.
           STOP RUN.
