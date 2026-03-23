       IDENTIFICATION DIVISION.
       PROGRAM-ID. COMP-IN-PERF.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-I            PIC 9(3).
       01  WS-SUM          PIC 9(5) VALUE 0.
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 0 TO WS-SUM.
           PERFORM 1000-ADD-STEP
               VARYING WS-I FROM 1 BY 1
               UNTIL WS-I > 5.
           STOP RUN.
       1000-ADD-STEP.
           ADD WS-I TO WS-SUM.
