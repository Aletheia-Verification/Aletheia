       IDENTIFICATION DIVISION.
       PROGRAM-ID. PV-AFTER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-I          PIC 9(3).
       01  WS-J          PIC 9(3).
       01  WS-COUNT      PIC 9(5).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 0 TO WS-COUNT.
           PERFORM 1000-BODY
               VARYING WS-I FROM 1 BY 1
               UNTIL WS-I > 3
               AFTER WS-J FROM 1 BY 1
               UNTIL WS-J > 2.
           STOP RUN.
       1000-BODY.
           ADD 1 TO WS-COUNT.
