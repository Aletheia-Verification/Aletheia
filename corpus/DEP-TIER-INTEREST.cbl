       IDENTIFICATION DIVISION.
       PROGRAM-ID. DEP-TIER-INTEREST.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ACCT-NUM                PIC X(12).
       01 WS-BALANCE                 PIC S9(9)V99 COMP-3.
       01 WS-TIER-TABLE.
           05 WS-TIER OCCURS 4.
               10 WS-TI-FLOOR        PIC S9(9)V99 COMP-3.
               10 WS-TI-CEILING      PIC S9(9)V99 COMP-3.
               10 WS-TI-RATE         PIC S9(1)V9(6) COMP-3.
               10 WS-TI-INTEREST     PIC S9(7)V99 COMP-3.
       01 WS-TI-IDX                  PIC 9(1).
       01 WS-TOTAL-INTEREST          PIC S9(7)V99 COMP-3.
       01 WS-TIER-BAL                PIC S9(9)V99 COMP-3.
       01 WS-REMAINING               PIC S9(9)V99 COMP-3.
       01 WS-BLENDED-RATE            PIC S9(1)V9(6) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-TIERS
           PERFORM 3000-CALC-TIERED-INT
           PERFORM 4000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-INTEREST.
       2000-LOAD-TIERS.
           MOVE 0 TO WS-TI-FLOOR(1)
           MOVE 10000.00 TO WS-TI-CEILING(1)
           MOVE 0.0100 TO WS-TI-RATE(1)
           MOVE 10000.01 TO WS-TI-FLOOR(2)
           MOVE 50000.00 TO WS-TI-CEILING(2)
           MOVE 0.0200 TO WS-TI-RATE(2)
           MOVE 50000.01 TO WS-TI-FLOOR(3)
           MOVE 100000.00 TO WS-TI-CEILING(3)
           MOVE 0.0350 TO WS-TI-RATE(3)
           MOVE 100000.01 TO WS-TI-FLOOR(4)
           MOVE 999999999.99 TO WS-TI-CEILING(4)
           MOVE 0.0450 TO WS-TI-RATE(4).
       3000-CALC-TIERED-INT.
           MOVE WS-BALANCE TO WS-REMAINING
           PERFORM VARYING WS-TI-IDX FROM 1 BY 1
               UNTIL WS-TI-IDX > 4
               OR WS-REMAINING <= 0
               COMPUTE WS-TIER-BAL =
                   WS-TI-CEILING(WS-TI-IDX) -
                   WS-TI-FLOOR(WS-TI-IDX)
               IF WS-REMAINING < WS-TIER-BAL
                   MOVE WS-REMAINING TO WS-TIER-BAL
               END-IF
               COMPUTE WS-TI-INTEREST(WS-TI-IDX) =
                   WS-TIER-BAL * WS-TI-RATE(WS-TI-IDX) / 12
               ADD WS-TI-INTEREST(WS-TI-IDX) TO
                   WS-TOTAL-INTEREST
               SUBTRACT WS-TIER-BAL FROM WS-REMAINING
           END-PERFORM
           IF WS-BALANCE > 0
               COMPUTE WS-BLENDED-RATE =
                   (WS-TOTAL-INTEREST * 12) / WS-BALANCE
           END-IF.
       4000-DISPLAY-RESULTS.
           DISPLAY 'TIERED INTEREST REPORT'
           DISPLAY '======================'
           DISPLAY 'ACCOUNT:      ' WS-ACCT-NUM
           DISPLAY 'BALANCE:      ' WS-BALANCE
           DISPLAY 'MONTHLY INT:  ' WS-TOTAL-INTEREST
           DISPLAY 'BLENDED RATE: ' WS-BLENDED-RATE
           PERFORM VARYING WS-TI-IDX FROM 1 BY 1
               UNTIL WS-TI-IDX > 4
               IF WS-TI-INTEREST(WS-TI-IDX) > 0
                   DISPLAY '  TIER ' WS-TI-IDX
                       ' RATE=' WS-TI-RATE(WS-TI-IDX)
                       ' INT=' WS-TI-INTEREST(WS-TI-IDX)
               END-IF
           END-PERFORM.
