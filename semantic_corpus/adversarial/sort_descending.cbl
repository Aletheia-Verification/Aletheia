       IDENTIFICATION DIVISION.
       PROGRAM-ID. SORT-DESCENDING.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-TABLE.
           05  WS-ENTRY OCCURS 5 TIMES.
               10  WS-AMT   PIC 9(5).
               10  WS-NAME  PIC X(5).
       01  WS-SORT-TABLE.
           05  WS-SORT-ENTRY OCCURS 5 TIMES.
               10  WS-SORT-AMT  PIC 9(5).
               10  WS-SORT-NAME PIC X(5).
       01  WS-I             PIC 9(1).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 00300 TO WS-AMT(1).
           MOVE 'CHARLIE' TO WS-NAME(1).
           MOVE 00100 TO WS-AMT(2).
           MOVE 'ALICE' TO WS-NAME(2).
           MOVE 00500 TO WS-AMT(3).
           MOVE 'EVE' TO WS-NAME(3).
           MOVE 00200 TO WS-AMT(4).
           MOVE 'BOB' TO WS-NAME(4).
           MOVE 00400 TO WS-AMT(5).
           MOVE 'DAVE' TO WS-NAME(5).
           SORT WS-ENTRY ON DESCENDING KEY WS-AMT.
           DISPLAY WS-AMT(1).
           DISPLAY WS-AMT(2).
           DISPLAY WS-AMT(3).
           STOP RUN.
