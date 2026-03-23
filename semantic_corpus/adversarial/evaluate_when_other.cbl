       IDENTIFICATION DIVISION.
       PROGRAM-ID. EVAL-OTHER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-X          PIC 9(3).
       01  WS-RESULT     PIC X(10).
       PROCEDURE DIVISION.
       0000-MAIN.
           EVALUATE TRUE
               WHEN WS-X = 1
                   MOVE 'ONE' TO WS-RESULT
               WHEN WS-X = 2
                   MOVE 'TWO' TO WS-RESULT
               WHEN OTHER
                   MOVE 'OTHER' TO WS-RESULT
           END-EVALUATE.
           STOP RUN.
