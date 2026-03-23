       IDENTIFICATION DIVISION.
       PROGRAM-ID. PV-DECREMENT.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-I           PIC S9(3).
       01  WS-COUNT       PIC 9(5) VALUE 0.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-BODY
               VARYING WS-I FROM 10 BY -1
               UNTIL WS-I < 1.
           STOP RUN.
       1000-BODY.
           ADD 1 TO WS-COUNT.
