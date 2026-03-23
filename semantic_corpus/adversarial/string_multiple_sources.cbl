       IDENTIFICATION DIVISION.
       PROGRAM-ID. STR-MULTI-SRC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-A            PIC X(5).
       01  WS-B            PIC X(1).
       01  WS-C            PIC X(5).
       01  WS-TARGET       PIC X(20).
       PROCEDURE DIVISION.
       0000-MAIN.
           STRING WS-A DELIMITED BY SIZE
                  WS-B DELIMITED BY SIZE
                  WS-C DELIMITED BY SIZE
                  INTO WS-TARGET.
           STOP RUN.
