       IDENTIFICATION DIVISION.
       PROGRAM-ID. THRU-GOTO.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-COUNT      PIC 9(5).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 0 TO WS-COUNT.
           PERFORM PARA-A THRU PARA-C.
           STOP RUN.
       PARA-A.
           ADD 1 TO WS-COUNT.
       PARA-B.
           ADD 10 TO WS-COUNT.
           GO TO PARA-C.
           ADD 100 TO WS-COUNT.
       PARA-C.
           ADD 1000 TO WS-COUNT.
