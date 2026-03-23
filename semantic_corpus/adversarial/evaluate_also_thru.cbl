       IDENTIFICATION DIVISION.
       PROGRAM-ID. EVAL-ALSO-THRU.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-X             PIC 9(2) VALUE 3.
       01  WS-Y             PIC X(1) VALUE 'B'.
       01  WS-RESULT        PIC X(10) VALUE SPACES.
       PROCEDURE DIVISION.
       0000-MAIN.
           EVALUATE WS-X ALSO WS-Y
               WHEN 1 THRU 5 ALSO 'A' THRU 'C'
                   MOVE 'MATCH-1' TO WS-RESULT
               WHEN 6 THRU 10 ALSO 'D' THRU 'F'
                   MOVE 'MATCH-2' TO WS-RESULT
               WHEN OTHER
                   MOVE 'NO-MATCH' TO WS-RESULT
           END-EVALUATE.
           DISPLAY WS-RESULT.
           STOP RUN.
