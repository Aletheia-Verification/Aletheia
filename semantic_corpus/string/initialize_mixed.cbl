       IDENTIFICATION DIVISION.
       PROGRAM-ID. INITIALIZE-MIXED.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-GROUP.
           05  WS-NAME       PIC X(10).
           05  WS-AMOUNT     PIC S9(5)V99.
           05  WS-CODE       PIC X(3).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 'JOHN' TO WS-NAME.
           MOVE 500.00 TO WS-AMOUNT.
           MOVE 'ABC' TO WS-CODE.
           INITIALIZE WS-GROUP.
           STOP RUN.
