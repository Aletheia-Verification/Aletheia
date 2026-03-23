       IDENTIFICATION DIVISION.
       PROGRAM-ID. ODO-MAX-BOUNDARY.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-N           PIC 9       VALUE 5.
       01  WS-TABLE.
           05  WS-ITEM    PIC 9(3)  OCCURS 1 TO 5
                           DEPENDING ON WS-N.
       01  WS-RESULT      PIC 9(3).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 100 TO WS-ITEM(1).
           MOVE 200 TO WS-ITEM(2).
           MOVE 300 TO WS-ITEM(3).
           MOVE 400 TO WS-ITEM(4).
           MOVE 500 TO WS-ITEM(5).
           MOVE WS-ITEM(5) TO WS-RESULT.
           STOP RUN.
