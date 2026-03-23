       IDENTIFICATION DIVISION.
       PROGRAM-ID. EVAL-ALSO.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-A          PIC 9(3).
       01  WS-B          PIC 9(3).
       01  WS-RESULT     PIC X(10).
       PROCEDURE DIVISION.
       0000-MAIN.
           EVALUATE WS-A ALSO WS-B
               WHEN 1 ALSO 2
                   MOVE 'MATCH' TO WS-RESULT
               WHEN OTHER
                   MOVE 'NO' TO WS-RESULT
           END-EVALUATE.
           STOP RUN.
