       IDENTIFICATION DIVISION.
       PROGRAM-ID. ODO-ACCESS.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-COUNT            PIC 9(2).
       01  WS-TABLE.
           05  WS-ITEMS OCCURS 1 TO 10 TIMES
               DEPENDING ON WS-COUNT PIC X(5).
       01  WS-OUT              PIC X(5).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 3 TO WS-COUNT.
           MOVE 'HELLO' TO WS-ITEMS(2).
           MOVE WS-ITEMS(2) TO WS-OUT.
           STOP RUN.
