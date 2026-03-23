       IDENTIFICATION DIVISION.
       PROGRAM-ID. THRU-RANGE-88.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-SCORE        PIC 9(3).
           88 IN-RANGE      VALUE 10 THRU 50.
       01  WS-RESULT        PIC 9(3).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 25 TO WS-SCORE.
           MOVE 0 TO WS-RESULT.
           IF IN-RANGE
               MOVE 1 TO WS-RESULT
           END-IF.
           STOP RUN.
