       IDENTIFICATION DIVISION.
       PROGRAM-ID. OCCURS-NESTED-3DEEP.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-TABLE.
           05  WS-LEVEL1 OCCURS 5 TIMES.
               10  WS-LEVEL2 OCCURS 3 TIMES.
                   15  WS-LEVEL3 OCCURS 2 TIMES.
                       20  WS-CELL  PIC 9(3) VALUE 0.
       01  WS-I             PIC 9(1).
       01  WS-J             PIC 9(1).
       01  WS-K             PIC 9(1).
       01  WS-OUT           PIC 9(3).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 1 TO WS-I.
           MOVE 2 TO WS-J.
           MOVE 1 TO WS-K.
           MOVE 999 TO WS-CELL(WS-I, WS-J, WS-K).
           MOVE WS-CELL(1, 2, 1) TO WS-OUT.
           DISPLAY WS-OUT.
           STOP RUN.
