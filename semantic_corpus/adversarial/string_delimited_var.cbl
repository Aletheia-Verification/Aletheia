       IDENTIFICATION DIVISION.
       PROGRAM-ID. STR-DELIM-VAR.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-A            PIC X(11).
       01  WS-DELIM        PIC X(1).
       01  WS-TGT          PIC X(20).
       PROCEDURE DIVISION.
       0000-MAIN.
           STRING WS-A DELIMITED BY WS-DELIM
                  INTO WS-TGT.
           STOP RUN.
