       IDENTIFICATION DIVISION.
       PROGRAM-ID. COMPUTE-FUNCTION-MIN.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-A             PIC 9(4) VALUE 5.
       01  WS-B             PIC 9(4) VALUE 15.
       01  WS-C             PIC 9(4) VALUE 10.
       01  WS-RESULT        PIC 9(4) VALUE 0.
       PROCEDURE DIVISION.
       0000-MAIN.
           COMPUTE WS-RESULT = FUNCTION MIN(WS-A WS-B WS-C).
           DISPLAY WS-RESULT.
           STOP RUN.
