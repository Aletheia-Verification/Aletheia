       IDENTIFICATION DIVISION.
       PROGRAM-ID. SIZE-ERR-INTER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-A          PIC 9(5).
       01  WS-B          PIC 9(5).
       01  WS-RESULT     PIC 9(5) VALUE 0.
       01  WS-FLAG       PIC X VALUE 'N'.
       PROCEDURE DIVISION.
       0000-MAIN.
           COMPUTE WS-RESULT = WS-A * WS-B
               ON SIZE ERROR
                   MOVE 'Y' TO WS-FLAG.
           STOP RUN.
