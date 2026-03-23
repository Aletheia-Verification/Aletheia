       IDENTIFICATION DIVISION.
       PROGRAM-ID. UNSTR-IN-PERF.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-I            PIC 9(1).
       01  WS-CSV           PIC X(10).
       01  WS-P1            PIC X(5).
       01  WS-P2            PIC X(5).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM VARYING WS-I FROM 1 BY 1
               UNTIL WS-I > 1
               UNSTRING WS-CSV DELIMITED BY ','
                   INTO WS-P1 WS-P2
               END-UNSTRING
           END-PERFORM.
           STOP RUN.
