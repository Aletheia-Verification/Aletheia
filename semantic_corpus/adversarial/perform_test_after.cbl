       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEST-AFTER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-X          PIC 9(3).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 0 TO WS-X.
           PERFORM WITH TEST AFTER
               UNTIL WS-X > 0
               ADD 1 TO WS-X
           END-PERFORM.
           STOP RUN.
