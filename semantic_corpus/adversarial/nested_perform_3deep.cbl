       IDENTIFICATION DIVISION.
       PROGRAM-ID. NESTED-3DEEP.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-COUNT      PIC 9(3).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 0 TO WS-COUNT.
           PERFORM PARA-A.
           STOP RUN.
       PARA-A.
           ADD 1 TO WS-COUNT.
           PERFORM PARA-B.
       PARA-B.
           ADD 1 TO WS-COUNT.
           PERFORM PARA-C.
       PARA-C.
           ADD 1 TO WS-COUNT.
