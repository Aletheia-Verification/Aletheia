       IDENTIFICATION DIVISION.
       PROGRAM-ID. COMPUTE-CHAIN-OVERFLOW.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-A             PIC 9(3) VALUE 500.
       01  WS-B             PIC 9(3) VALUE 400.
       01  WS-C             PIC 9(3) VALUE 100.
       01  WS-D             PIC 9(3) VALUE 200.
       01  WS-E             PIC 9(3) VALUE 50.
       01  WS-AMT           PIC 9(5) VALUE 0.
       01  WS-FLAG          PIC X(1) VALUE ' '.
       PROCEDURE DIVISION.
       0000-MAIN.
           COMPUTE WS-AMT = WS-A * WS-B + WS-C / WS-D - WS-E
               ON SIZE ERROR
                   MOVE 'Y' TO WS-FLAG
               NOT ON SIZE ERROR
                   MOVE 'N' TO WS-FLAG
           END-COMPUTE.
           DISPLAY WS-AMT.
           DISPLAY WS-FLAG.
           STOP RUN.
