       IDENTIFICATION DIVISION.
       PROGRAM-ID. REG-STRESS-CALC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-PORTFOLIO.
           05 WS-SEGMENT OCCURS 5.
               10 WS-SG-NAME         PIC X(15).
               10 WS-SG-BALANCE      PIC S9(11)V99 COMP-3.
               10 WS-SG-LOSS-RATE    PIC S9(1)V9(4) COMP-3.
               10 WS-SG-STRESS-LOSS  PIC S9(9)V99 COMP-3.
       01 WS-SG-IDX                  PIC 9(1).
       01 WS-SCENARIO                PIC X(1).
           88 WS-BASELINE            VALUE 'B'.
           88 WS-ADVERSE             VALUE 'A'.
           88 WS-SEVERE              VALUE 'S'.
       01 WS-MULTIPLIER              PIC S9(1)V9(4) COMP-3.
       01 WS-TOTALS.
           05 WS-TOTAL-BAL           PIC S9(13)V99 COMP-3.
           05 WS-TOTAL-LOSS          PIC S9(11)V99 COMP-3.
           05 WS-LOSS-RATIO          PIC S9(1)V9(6) COMP-3.
       01 WS-CAPITAL-FIELDS.
           05 WS-CURRENT-CAPITAL     PIC S9(11)V99 COMP-3.
           05 WS-POST-STRESS-CAP     PIC S9(11)V99 COMP-3.
           05 WS-CAP-RATIO           PIC S9(1)V9(4) COMP-3.
           05 WS-MIN-CAP-RATIO       PIC S9(1)V9(4) COMP-3
               VALUE 0.0450.
       01 WS-PASS-FAIL               PIC X(1).
           88 WS-PASSES              VALUE 'P'.
           88 WS-FAILS               VALUE 'F'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-SET-MULTIPLIER
           PERFORM 3000-CALC-STRESS-LOSSES
           PERFORM 4000-CALC-CAPITAL-IMPACT
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-BAL
           MOVE 0 TO WS-TOTAL-LOSS
           SET WS-PASSES TO TRUE.
       2000-SET-MULTIPLIER.
           EVALUATE TRUE
               WHEN WS-BASELINE
                   MOVE 1.00 TO WS-MULTIPLIER
               WHEN WS-ADVERSE
                   MOVE 2.50 TO WS-MULTIPLIER
               WHEN WS-SEVERE
                   MOVE 4.00 TO WS-MULTIPLIER
               WHEN OTHER
                   MOVE 1.00 TO WS-MULTIPLIER
           END-EVALUATE.
       3000-CALC-STRESS-LOSSES.
           PERFORM VARYING WS-SG-IDX FROM 1 BY 1
               UNTIL WS-SG-IDX > 5
               COMPUTE WS-SG-STRESS-LOSS(WS-SG-IDX) =
                   WS-SG-BALANCE(WS-SG-IDX) *
                   WS-SG-LOSS-RATE(WS-SG-IDX) *
                   WS-MULTIPLIER
               ADD WS-SG-BALANCE(WS-SG-IDX) TO
                   WS-TOTAL-BAL
               ADD WS-SG-STRESS-LOSS(WS-SG-IDX) TO
                   WS-TOTAL-LOSS
           END-PERFORM
           IF WS-TOTAL-BAL > 0
               COMPUTE WS-LOSS-RATIO =
                   WS-TOTAL-LOSS / WS-TOTAL-BAL
           END-IF.
       4000-CALC-CAPITAL-IMPACT.
           COMPUTE WS-POST-STRESS-CAP =
               WS-CURRENT-CAPITAL - WS-TOTAL-LOSS
           IF WS-TOTAL-BAL > 0
               COMPUTE WS-CAP-RATIO =
                   WS-POST-STRESS-CAP / WS-TOTAL-BAL
           END-IF
           IF WS-CAP-RATIO < WS-MIN-CAP-RATIO
               SET WS-FAILS TO TRUE
           END-IF.
       5000-DISPLAY-RESULTS.
           DISPLAY 'STRESS TEST RESULTS'
           DISPLAY '==================='
           DISPLAY 'TOTAL PORTFOLIO: ' WS-TOTAL-BAL
           DISPLAY 'STRESS LOSSES:   ' WS-TOTAL-LOSS
           DISPLAY 'LOSS RATIO:      ' WS-LOSS-RATIO
           DISPLAY 'CURRENT CAPITAL: ' WS-CURRENT-CAPITAL
           DISPLAY 'POST-STRESS CAP: ' WS-POST-STRESS-CAP
           DISPLAY 'CAPITAL RATIO:   ' WS-CAP-RATIO
           IF WS-PASSES
               DISPLAY 'RESULT: PASS'
           ELSE
               DISPLAY 'RESULT: FAIL'
           END-IF
           PERFORM VARYING WS-SG-IDX FROM 1 BY 1
               UNTIL WS-SG-IDX > 5
               DISPLAY '  ' WS-SG-NAME(WS-SG-IDX)
                   ' BAL=' WS-SG-BALANCE(WS-SG-IDX)
                   ' LOSS=' WS-SG-STRESS-LOSS(WS-SG-IDX)
           END-PERFORM.
