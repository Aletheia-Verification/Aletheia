       IDENTIFICATION DIVISION.
       PROGRAM-ID. COMP-COMPLEX.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-BASE       PIC 9(5)V99.
       01  WS-RATE       PIC 9V9(4).
       01  WS-DAYS       PIC 9(3).
       01  WS-RESULT     PIC 9(5)V99.
       PROCEDURE DIVISION.
       0000-MAIN.
           COMPUTE WS-RESULT =
               (WS-BASE * WS-RATE) / 365 * WS-DAYS.
           STOP RUN.
