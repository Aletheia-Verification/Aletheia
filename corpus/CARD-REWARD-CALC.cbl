       IDENTIFICATION DIVISION.
       PROGRAM-ID. CARD-REWARD-CALC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CARD-RECORD.
           05 WS-CARD-NUM         PIC X(16).
           05 WS-CARD-TYPE        PIC X(2).
               88 CT-BASIC        VALUE 'BA'.
               88 CT-GOLD         VALUE 'GL'.
               88 CT-PLATINUM     VALUE 'PL'.
               88 CT-BLACK        VALUE 'BK'.
           05 WS-ANNUAL-SPEND     PIC S9(9)V99 COMP-3.
           05 WS-CURRENT-POINTS   PIC S9(9) COMP-3.
       01 WS-MONTHLY-TXN.
           05 WS-MTX OCCURS 15 TIMES.
               10 WS-MTX-AMT      PIC S9(7)V99 COMP-3.
               10 WS-MTX-MCC      PIC X(4).
               10 WS-MTX-FOREIGN  PIC X.
                   88 IS-FOREIGN   VALUE 'Y'.
       01 WS-MTX-COUNT            PIC 99 VALUE 15.
       01 WS-MTX-IDX              PIC 99.
       01 WS-MULTIPLIER           PIC S9(1)V99 COMP-3.
       01 WS-BASE-RATE            PIC S9(1)V99 COMP-3.
       01 WS-BONUS-RATE           PIC S9(1)V99 COMP-3.
       01 WS-TXN-POINTS           PIC S9(7) COMP-3.
       01 WS-MONTH-POINTS         PIC S9(9) COMP-3.
       01 WS-BONUS-POINTS         PIC S9(7) COMP-3.
       01 WS-POINT-VALUE          PIC S9(1)V9(4) COMP-3
           VALUE 0.0100.
       01 WS-CASH-VALUE           PIC S9(7)V99 COMP-3.
       01 WS-MCC-CATEGORY         PIC X(12).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-SET-BASE-RATE
           PERFORM 2000-CALC-MONTHLY-POINTS
           PERFORM 3000-APPLY-TIER-BONUS
           PERFORM 4000-SUMMARY
           STOP RUN.
       1000-SET-BASE-RATE.
           EVALUATE TRUE
               WHEN CT-BASIC
                   MOVE 1.00 TO WS-BASE-RATE
                   MOVE 0.00 TO WS-BONUS-RATE
               WHEN CT-GOLD
                   MOVE 1.50 TO WS-BASE-RATE
                   MOVE 0.25 TO WS-BONUS-RATE
               WHEN CT-PLATINUM
                   MOVE 2.00 TO WS-BASE-RATE
                   MOVE 0.50 TO WS-BONUS-RATE
               WHEN CT-BLACK
                   MOVE 3.00 TO WS-BASE-RATE
                   MOVE 1.00 TO WS-BONUS-RATE
               WHEN OTHER
                   MOVE 1.00 TO WS-BASE-RATE
                   MOVE 0.00 TO WS-BONUS-RATE
           END-EVALUATE.
       2000-CALC-MONTHLY-POINTS.
           MOVE 0 TO WS-MONTH-POINTS
           PERFORM VARYING WS-MTX-IDX FROM 1 BY 1
               UNTIL WS-MTX-IDX > WS-MTX-COUNT
               PERFORM 2100-CATEGORIZE-MCC
               COMPUTE WS-TXN-POINTS =
                   WS-MTX-AMT(WS-MTX-IDX) * WS-MULTIPLIER
               IF IS-FOREIGN(WS-MTX-IDX)
                   COMPUTE WS-TXN-POINTS =
                       WS-TXN-POINTS * 1.50
               END-IF
               ADD WS-TXN-POINTS TO WS-MONTH-POINTS
           END-PERFORM.
       2100-CATEGORIZE-MCC.
           MOVE WS-BASE-RATE TO WS-MULTIPLIER
           EVALUATE WS-MTX-MCC(WS-MTX-IDX)
               WHEN '5411'
                   ADD WS-BONUS-RATE TO WS-MULTIPLIER
                   MOVE 'GROCERY     ' TO WS-MCC-CATEGORY
               WHEN '5541'
                   ADD WS-BONUS-RATE TO WS-MULTIPLIER
                   MOVE 'GAS STATION ' TO WS-MCC-CATEGORY
               WHEN '5812'
                   ADD WS-BONUS-RATE TO WS-MULTIPLIER
                   MOVE 'DINING      ' TO WS-MCC-CATEGORY
               WHEN '3000'
                   COMPUTE WS-MULTIPLIER =
                       WS-MULTIPLIER + WS-BONUS-RATE + 0.50
                   MOVE 'AIRLINE     ' TO WS-MCC-CATEGORY
               WHEN '7011'
                   COMPUTE WS-MULTIPLIER =
                       WS-MULTIPLIER + WS-BONUS-RATE + 0.50
                   MOVE 'HOTEL       ' TO WS-MCC-CATEGORY
               WHEN OTHER
                   MOVE 'OTHER       ' TO WS-MCC-CATEGORY
           END-EVALUATE.
       3000-APPLY-TIER-BONUS.
           MOVE 0 TO WS-BONUS-POINTS
           IF WS-ANNUAL-SPEND > 50000.00
               COMPUTE WS-BONUS-POINTS =
                   WS-MONTH-POINTS * 0.25
               ADD WS-BONUS-POINTS TO WS-MONTH-POINTS
           ELSE
               IF WS-ANNUAL-SPEND > 25000.00
                   COMPUTE WS-BONUS-POINTS =
                       WS-MONTH-POINTS * 0.10
                   ADD WS-BONUS-POINTS TO WS-MONTH-POINTS
               END-IF
           END-IF
           ADD WS-MONTH-POINTS TO WS-CURRENT-POINTS
           COMPUTE WS-CASH-VALUE =
               WS-CURRENT-POINTS * WS-POINT-VALUE.
       4000-SUMMARY.
           DISPLAY 'REWARDS CALCULATION REPORT'
           DISPLAY '========================='
           DISPLAY 'CARD: ' WS-CARD-NUM
           DISPLAY 'TYPE: ' WS-CARD-TYPE
           DISPLAY 'MONTH POINTS: ' WS-MONTH-POINTS
           DISPLAY 'TOTAL POINTS: ' WS-CURRENT-POINTS
           DISPLAY 'CASH VALUE:   $' WS-CASH-VALUE
           IF WS-BONUS-POINTS > 0
               DISPLAY 'TIER BONUS:   ' WS-BONUS-POINTS
           END-IF.
