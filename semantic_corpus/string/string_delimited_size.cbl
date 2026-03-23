       IDENTIFICATION DIVISION.
       PROGRAM-ID. STRING-DELIMITED-SIZE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-FIRST      PIC X(5).
       01  WS-SEP        PIC X(1).
       01  WS-LAST       PIC X(5).
       01  WS-FULL       PIC X(20).
       PROCEDURE DIVISION.
       0000-MAIN.
           STRING WS-FIRST DELIMITED BY SIZE
                  WS-SEP DELIMITED BY SIZE
                  WS-LAST DELIMITED BY SIZE
                  INTO WS-FULL.
           STOP RUN.
