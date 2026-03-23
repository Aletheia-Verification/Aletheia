       IDENTIFICATION DIVISION.
       PROGRAM-ID. COMPUTE-PREC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-A          PIC 9(3).
       01  WS-B          PIC 9(3).
       01  WS-C          PIC 9(3).
       01  WS-RESULT     PIC 9(5).
       PROCEDURE DIVISION.
       0000-MAIN.
           COMPUTE WS-RESULT = WS-A + WS-B * WS-C.
           STOP RUN.
