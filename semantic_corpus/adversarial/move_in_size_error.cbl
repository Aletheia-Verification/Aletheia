       IDENTIFICATION DIVISION.
       PROGRAM-ID. MOVE-SIZE-ERR.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-R            PIC 9(4) VALUE 0.
       01  WS-FLAG          PIC X(1) VALUE 'N'.
       PROCEDURE DIVISION.
       0000-MAIN.
           COMPUTE WS-R = 999 * 999
               ON SIZE ERROR
                   MOVE 'Y' TO WS-FLAG
           END-COMPUTE.
           STOP RUN.
