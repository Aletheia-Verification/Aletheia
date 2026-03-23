       IDENTIFICATION DIVISION.
       PROGRAM-ID. EVAL-WHEN-NOT.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-X           PIC 9(3).
       01  WS-RESULT      PIC X(10).
       PROCEDURE DIVISION.
       0000-MAIN.
           EVALUATE TRUE
               WHEN NOT WS-X = 1
                   MOVE 'NOT1' TO WS-RESULT
               WHEN OTHER
                   MOVE 'IS1' TO WS-RESULT
           END-EVALUATE.
           STOP RUN.
