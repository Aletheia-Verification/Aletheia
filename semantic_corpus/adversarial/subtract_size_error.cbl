       IDENTIFICATION DIVISION.
       PROGRAM-ID. SUB-SIZE-ERR.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-A          PIC 9(4).
       01  WS-B          PIC 9(3) VALUE 500.
       01  WS-FLAG       PIC X VALUE 'N'.
       PROCEDURE DIVISION.
       0000-MAIN.
           SUBTRACT WS-A FROM WS-B
               ON SIZE ERROR
                   MOVE 'Y' TO WS-FLAG.
           STOP RUN.
