       IDENTIFICATION DIVISION.
       PROGRAM-ID. STR-PTR.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-A            PIC X(5).
       01  WS-TGT          PIC X(20).
       01  WS-PTR          PIC 9(3) VALUE 1.
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE SPACES TO WS-TGT.
           STRING WS-A DELIMITED BY SIZE
                  INTO WS-TGT
                  WITH POINTER WS-PTR.
           STOP RUN.
