       IDENTIFICATION DIVISION.
       PROGRAM-ID. ARITH-COMPAT-18.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-A          PIC 9(5).
       01  WS-B          PIC 9(5).
       01  WS-C          PIC 9(5).
       01  WS-RESULT     PIC 9(5).
       PROCEDURE DIVISION.
       0000-MAIN.
           COMPUTE WS-RESULT = (WS-A + WS-B) * WS-C.
           STOP RUN.
