       IDENTIFICATION DIVISION.
       PROGRAM-ID. DEP-RATE-BOARD.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-PRODUCT-TABLE.
           05 WS-PRODUCT OCCURS 5.
               10 WS-PR-NAME         PIC X(15).
               10 WS-PR-RATE         PIC S9(1)V9(6) COMP-3.
               10 WS-PR-MIN-BAL      PIC S9(9)V99 COMP-3.
               10 WS-PR-APY          PIC S9(1)V9(6) COMP-3.
       01 WS-PR-IDX                  PIC 9(1).
       01 WS-DEPOSIT-AMT             PIC S9(9)V99 COMP-3.
       01 WS-BEST-IDX                PIC 9(1).
       01 WS-BEST-APY                PIC S9(1)V9(6) COMP-3.
       01 WS-COMPOUND-FREQ           PIC 9(3) VALUE 365.
       01 WS-TIER-TYPE               PIC X(1).
           88 WS-STANDARD            VALUE 'S'.
           88 WS-PREMIUM             VALUE 'P'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-APY
           PERFORM 3000-FIND-BEST
           PERFORM 4000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-BEST-APY
           MOVE 0 TO WS-BEST-IDX.
       2000-CALC-APY.
           PERFORM VARYING WS-PR-IDX FROM 1 BY 1
               UNTIL WS-PR-IDX > 5
               COMPUTE WS-PR-APY(WS-PR-IDX) =
                   (1 + WS-PR-RATE(WS-PR-IDX) /
                   WS-COMPOUND-FREQ) ** WS-COMPOUND-FREQ - 1
           END-PERFORM.
       3000-FIND-BEST.
           PERFORM VARYING WS-PR-IDX FROM 1 BY 1
               UNTIL WS-PR-IDX > 5
               IF WS-DEPOSIT-AMT >= WS-PR-MIN-BAL(WS-PR-IDX)
                   IF WS-PR-APY(WS-PR-IDX) > WS-BEST-APY
                       MOVE WS-PR-APY(WS-PR-IDX) TO
                           WS-BEST-APY
                       MOVE WS-PR-IDX TO WS-BEST-IDX
                   END-IF
               END-IF
           END-PERFORM.
       4000-DISPLAY-RESULTS.
           DISPLAY 'DEPOSIT RATE BOARD'
           DISPLAY '=================='
           PERFORM VARYING WS-PR-IDX FROM 1 BY 1
               UNTIL WS-PR-IDX > 5
               DISPLAY '  ' WS-PR-NAME(WS-PR-IDX)
                   ' RATE=' WS-PR-RATE(WS-PR-IDX)
                   ' APY=' WS-PR-APY(WS-PR-IDX)
           END-PERFORM
           IF WS-BEST-IDX > 0
               DISPLAY 'BEST: '
                   WS-PR-NAME(WS-BEST-IDX)
           END-IF.
