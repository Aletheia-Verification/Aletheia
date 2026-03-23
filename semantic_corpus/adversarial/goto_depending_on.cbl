       IDENTIFICATION DIVISION.
       PROGRAM-ID. GOTO-DEPEND.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-IDX        PIC 9(3).
       01  WS-RESULT     PIC X.
       PROCEDURE DIVISION.
       0000-MAIN.
           GO TO PARA-A PARA-B PARA-C
               DEPENDING ON WS-IDX.
           MOVE 'X' TO WS-RESULT.
           STOP RUN.
       PARA-A.
           MOVE 'A' TO WS-RESULT.
           STOP RUN.
       PARA-B.
           MOVE 'B' TO WS-RESULT.
           STOP RUN.
       PARA-C.
           MOVE 'C' TO WS-RESULT.
           STOP RUN.
