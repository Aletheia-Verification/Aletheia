       IDENTIFICATION DIVISION.
       PROGRAM-ID. COMP4-VS-COMP.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-A           PIC 9(4) COMP-4 VALUE 1234.
       01  WS-B           PIC 9(5).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE WS-A TO WS-B.
           STOP RUN.
