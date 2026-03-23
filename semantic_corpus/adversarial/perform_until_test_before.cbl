       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEST-BEFORE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-X           PIC 9(3) VALUE 1.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-BODY
               WITH TEST BEFORE
               UNTIL WS-X > 3.
           STOP RUN.
       1000-BODY.
           ADD 1 TO WS-X.
