       IDENTIFICATION DIVISION.
       PROGRAM-ID. OSE-COMP-BIN.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-COMP-VAL    PIC S9(4) COMP VALUE 30000.
       01  WS-RESULT      PIC S9(4) COMP.
       01  WS-ERR-FLAG    PIC X(1) VALUE 'N'.
       PROCEDURE DIVISION.
       0000-MAIN.
           COMPUTE WS-RESULT = WS-COMP-VAL + 3000
               ON SIZE ERROR
                   MOVE 'Y' TO WS-ERR-FLAG
               NOT ON SIZE ERROR
                   MOVE 'N' TO WS-ERR-FLAG
           END-COMPUTE.
           STOP RUN.
