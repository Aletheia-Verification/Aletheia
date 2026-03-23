       IDENTIFICATION DIVISION.
       PROGRAM-ID. NESTED-PV.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-I           PIC 9(3).
       01  WS-J           PIC 9(3).
       01  WS-COUNT       PIC 9(5) VALUE 0.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM VARYING WS-I FROM 1 BY 1
               UNTIL WS-I > 3
               PERFORM VARYING WS-J FROM 1 BY 1
                   UNTIL WS-J > 2
                   ADD 1 TO WS-COUNT
               END-PERFORM
           END-PERFORM.
           STOP RUN.
