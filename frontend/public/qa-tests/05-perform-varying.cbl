       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOOP-TEST.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-I      PIC 9(3).
       01 WS-SUM    PIC 9(5) VALUE 0.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM VARYING WS-I FROM 1 BY 1
               UNTIL WS-I > 10
               ADD WS-I TO WS-SUM
           END-PERFORM.
           DISPLAY WS-SUM.
           STOP RUN.
