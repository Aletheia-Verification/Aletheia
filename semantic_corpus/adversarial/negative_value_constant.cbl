       IDENTIFICATION DIVISION.
       PROGRAM-ID. NEG-VALUE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-X          PIC S9(3) VALUE -100.
       01  WS-Y          PIC S9(3).
       PROCEDURE DIVISION.
       0000-MAIN.
           COMPUTE WS-Y = WS-X + 50.
           STOP RUN.
