       IDENTIFICATION DIVISION.
       PROGRAM-ID. CHAINED-COMPUTE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-A          PIC S9(3)V99.
       01  WS-B          PIC S9(3)V99.
       01  WS-C          PIC S9(3)V99.
       01  WS-RESULT     PIC S9(3)V99.
       PROCEDURE DIVISION.
       0000-MAIN.
           COMPUTE WS-RESULT = (WS-A / WS-B) * WS-C.
           STOP RUN.
