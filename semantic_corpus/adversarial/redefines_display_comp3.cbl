       IDENTIFICATION DIVISION.
       PROGRAM-ID. REDEF-COMP3.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-GROUP.
           05  WS-DISP         PIC X(3).
           05  WS-COMP3 REDEFINES WS-DISP
                               PIC S9(5) COMP-3.
       01  WS-RESULT           PIC X(3).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 'ABC' TO WS-DISP.
           MOVE WS-DISP TO WS-RESULT.
           STOP RUN.
