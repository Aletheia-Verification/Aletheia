       IDENTIFICATION DIVISION.
       PROGRAM-ID. GOTO-PERF.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-COUNTER     PIC 9(3) VALUE 0.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM PARA-A.
           STOP RUN.
       PARA-A.
           ADD 1 TO WS-COUNTER.
           GO TO PARA-EXIT.
           ADD 99 TO WS-COUNTER.
       PARA-EXIT.
           EXIT.
