       IDENTIFICATION DIVISION.
       PROGRAM-ID. EVAL-WHEN-EBCDIC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-CODE        PIC X(1).
       01  WS-RESULT      PIC X(10).
       PROCEDURE DIVISION.
       0000-MAIN.
           EVALUATE WS-CODE
               WHEN 'A'
                   MOVE 'ALPHA' TO WS-RESULT
               WHEN '1'
                   MOVE 'DIGIT' TO WS-RESULT
               WHEN OTHER
                   MOVE 'OTHER' TO WS-RESULT
           END-EVALUATE.
           STOP RUN.
