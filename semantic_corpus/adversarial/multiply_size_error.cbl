       IDENTIFICATION DIVISION.
       PROGRAM-ID. MULT-SIZE-ERROR.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-A             PIC 9(3) VALUE 999.
       01  WS-B             PIC 9(3) VALUE 999.
       01  WS-RESULT        PIC 9(6) VALUE 0.
       01  WS-FLAG          PIC X(1) VALUE ' '.
       PROCEDURE DIVISION.
       0000-MAIN.
           MULTIPLY WS-A BY WS-B
               GIVING WS-RESULT
               ON SIZE ERROR
                   MOVE 'Y' TO WS-FLAG
               NOT ON SIZE ERROR
                   MOVE 'N' TO WS-FLAG
           END-MULTIPLY.
           DISPLAY WS-RESULT.
           DISPLAY WS-FLAG.
           STOP RUN.
