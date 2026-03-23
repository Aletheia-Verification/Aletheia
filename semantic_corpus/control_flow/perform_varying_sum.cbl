       IDENTIFICATION DIVISION.
       PROGRAM-ID. PERFORM-VARYING-SUM.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-IDX        PIC 9(3).
       01  WS-SUM        PIC 9(5).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 0 TO WS-SUM.
           PERFORM 1000-ADD-STEP
               VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > 5.
           STOP RUN.
       1000-ADD-STEP.
           ADD WS-IDX TO WS-SUM.
