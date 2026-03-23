       IDENTIFICATION DIVISION.
       PROGRAM-ID. PERIOD-SCOPE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-A             PIC 9(1) VALUE 5.
       01  WS-B             PIC 9(1) VALUE 3.
       01  WS-RESULT        PIC X(10) VALUE SPACES.
       PROCEDURE DIVISION.
       0000-MAIN.
           IF WS-A > WS-B
               IF WS-A > 4
                   MOVE 'INNER-YES' TO WS-RESULT
               ELSE
                   MOVE 'INNER-NO ' TO WS-RESULT.
           DISPLAY WS-RESULT.
           STOP RUN.
