       IDENTIFICATION DIVISION.
       PROGRAM-ID. OSE-OVERFLOW.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-A           PIC 9(3) VALUE 999.
       01  WS-B           PIC 9(3) VALUE 1.
       01  WS-RESULT      PIC 9(3).
       01  WS-ERR-FLAG    PIC X(1) VALUE 'N'.
       PROCEDURE DIVISION.
       0000-MAIN.
           COMPUTE WS-RESULT = WS-A + WS-B
               ON SIZE ERROR
                   MOVE 'Y' TO WS-ERR-FLAG
           END-COMPUTE.
           STOP RUN.
