       IDENTIFICATION DIVISION.
       PROGRAM-ID. OSE-NO-OVERFLOW.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-A           PIC 9(3) VALUE 500.
       01  WS-B           PIC 9(3) VALUE 200.
       01  WS-RESULT      PIC 9(3).
       01  WS-OK-FLAG     PIC X(1) VALUE 'N'.
       PROCEDURE DIVISION.
       0000-MAIN.
           COMPUTE WS-RESULT = WS-A + WS-B
               ON SIZE ERROR
                   MOVE 'E' TO WS-OK-FLAG
               NOT ON SIZE ERROR
                   MOVE 'Y' TO WS-OK-FLAG
           END-COMPUTE.
           STOP RUN.
