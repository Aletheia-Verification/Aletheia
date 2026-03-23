       IDENTIFICATION DIVISION.
       PROGRAM-ID. EVAL-SUBJ-VAR.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-X           PIC X(5).
       01  WS-RESULT      PIC X(10).
       PROCEDURE DIVISION.
       0000-MAIN.
           EVALUATE WS-X
               WHEN 'A'
                   MOVE 'FOUND' TO WS-RESULT
               WHEN OTHER
                   MOVE 'NOPE' TO WS-RESULT
           END-EVALUATE.
           STOP RUN.
