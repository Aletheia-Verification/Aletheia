       IDENTIFICATION DIVISION.
       PROGRAM-ID. EVAL-RANGE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-X           PIC 9(3).
       01  WS-RESULT      PIC X(10).
       PROCEDURE DIVISION.
       0000-MAIN.
           EVALUATE WS-X
               WHEN 1 THRU 5
                   MOVE 'RANGE' TO WS-RESULT
               WHEN OTHER
                   MOVE 'MISS' TO WS-RESULT
           END-EVALUATE.
           STOP RUN.
