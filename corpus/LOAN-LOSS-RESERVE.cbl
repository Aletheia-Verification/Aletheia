       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOAN-LOSS-RESERVE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-PORTFOLIO.
           05 WS-SEGMENT OCCURS 6.
               10 WS-SEG-NAME        PIC X(15).
               10 WS-SEG-BALANCE     PIC S9(11)V99 COMP-3.
               10 WS-SEG-COUNT       PIC S9(5) COMP-3.
               10 WS-SEG-PD-RATE     PIC S9(1)V9(6) COMP-3.
               10 WS-SEG-LGD-RATE    PIC S9(1)V9(4) COMP-3.
               10 WS-SEG-ECL         PIC S9(9)V99 COMP-3.
               10 WS-SEG-RESERVE     PIC S9(9)V99 COMP-3.
               10 WS-SEG-RISK        PIC X(1).
                   88 WS-LOW-RISK    VALUE 'L'.
                   88 WS-MED-RISK    VALUE 'M'.
                   88 WS-HIGH-RISK   VALUE 'H'.
       01 WS-SEG-IDX                 PIC 9(1).
       01 WS-TOTAL-BALANCE           PIC S9(13)V99 COMP-3.
       01 WS-TOTAL-RESERVE           PIC S9(11)V99 COMP-3.
       01 WS-TOTAL-ECL               PIC S9(11)V99 COMP-3.
       01 WS-RESERVE-RATIO           PIC S9(1)V9(6) COMP-3.
       01 WS-MACRO-ADJUST.
           05 WS-GDP-FACTOR          PIC S9(1)V9(4) COMP-3.
           05 WS-UNEMP-FACTOR        PIC S9(1)V9(4) COMP-3.
           05 WS-COMBINED-FACTOR     PIC S9(1)V9(4) COMP-3.
       01 WS-ECON-SCENARIO           PIC X(1).
           88 WS-BASE-CASE           VALUE 'B'.
           88 WS-ADVERSE             VALUE 'A'.
           88 WS-SEVERE              VALUE 'S'.
       01 WS-Q-FACTOR                PIC S9(1)V9(4) COMP-3.
       01 WS-PRIOR-RESERVE           PIC S9(11)V99 COMP-3.
       01 WS-PROVISION               PIC S9(9)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-SET-MACRO-FACTORS
           PERFORM 3000-CALC-ECL
           PERFORM 4000-APPLY-Q-FACTORS
           PERFORM 5000-CALC-PROVISION
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-BALANCE
           MOVE 0 TO WS-TOTAL-RESERVE
           MOVE 0 TO WS-TOTAL-ECL.
       2000-SET-MACRO-FACTORS.
           EVALUATE TRUE
               WHEN WS-BASE-CASE
                   MOVE 1.00 TO WS-GDP-FACTOR
                   MOVE 1.00 TO WS-UNEMP-FACTOR
               WHEN WS-ADVERSE
                   MOVE 1.25 TO WS-GDP-FACTOR
                   MOVE 1.50 TO WS-UNEMP-FACTOR
               WHEN WS-SEVERE
                   MOVE 1.75 TO WS-GDP-FACTOR
                   MOVE 2.25 TO WS-UNEMP-FACTOR
               WHEN OTHER
                   MOVE 1.00 TO WS-GDP-FACTOR
                   MOVE 1.00 TO WS-UNEMP-FACTOR
           END-EVALUATE
           COMPUTE WS-COMBINED-FACTOR =
               (WS-GDP-FACTOR + WS-UNEMP-FACTOR) / 2.
       3000-CALC-ECL.
           PERFORM VARYING WS-SEG-IDX FROM 1 BY 1
               UNTIL WS-SEG-IDX > 6
               COMPUTE WS-SEG-ECL(WS-SEG-IDX) =
                   WS-SEG-BALANCE(WS-SEG-IDX) *
                   WS-SEG-PD-RATE(WS-SEG-IDX) *
                   WS-SEG-LGD-RATE(WS-SEG-IDX) *
                   WS-COMBINED-FACTOR
               EVALUATE TRUE
                   WHEN WS-SEG-PD-RATE(WS-SEG-IDX) < 0.02
                       MOVE 'L' TO WS-SEG-RISK(WS-SEG-IDX)
                   WHEN WS-SEG-PD-RATE(WS-SEG-IDX) < 0.05
                       MOVE 'M' TO WS-SEG-RISK(WS-SEG-IDX)
                   WHEN OTHER
                       MOVE 'H' TO WS-SEG-RISK(WS-SEG-IDX)
               END-EVALUATE
               ADD WS-SEG-BALANCE(WS-SEG-IDX) TO
                   WS-TOTAL-BALANCE
               ADD WS-SEG-ECL(WS-SEG-IDX) TO WS-TOTAL-ECL
           END-PERFORM.
       4000-APPLY-Q-FACTORS.
           PERFORM VARYING WS-SEG-IDX FROM 1 BY 1
               UNTIL WS-SEG-IDX > 6
               IF WS-SEG-RISK(WS-SEG-IDX) = 'H'
                   MOVE 0.0150 TO WS-Q-FACTOR
               ELSE
                   IF WS-SEG-RISK(WS-SEG-IDX) = 'M'
                       MOVE 0.0075 TO WS-Q-FACTOR
                   ELSE
                       MOVE 0.0025 TO WS-Q-FACTOR
                   END-IF
               END-IF
               COMPUTE WS-SEG-RESERVE(WS-SEG-IDX) =
                   WS-SEG-ECL(WS-SEG-IDX) +
                   (WS-SEG-BALANCE(WS-SEG-IDX) *
                   WS-Q-FACTOR)
               ADD WS-SEG-RESERVE(WS-SEG-IDX) TO
                   WS-TOTAL-RESERVE
           END-PERFORM
           IF WS-TOTAL-BALANCE > 0
               COMPUTE WS-RESERVE-RATIO =
                   WS-TOTAL-RESERVE / WS-TOTAL-BALANCE
           END-IF.
       5000-CALC-PROVISION.
           COMPUTE WS-PROVISION =
               WS-TOTAL-RESERVE - WS-PRIOR-RESERVE
           IF WS-PROVISION < 0
               MOVE 0 TO WS-PROVISION
           END-IF.
       6000-DISPLAY-RESULTS.
           DISPLAY 'CECL LOSS RESERVE REPORT'
           DISPLAY '========================'
           DISPLAY 'PORTFOLIO BALANCE: ' WS-TOTAL-BALANCE
           DISPLAY 'TOTAL ECL:         ' WS-TOTAL-ECL
           DISPLAY 'TOTAL RESERVE:     ' WS-TOTAL-RESERVE
           DISPLAY 'RESERVE RATIO:     ' WS-RESERVE-RATIO
           DISPLAY 'PRIOR RESERVE:     ' WS-PRIOR-RESERVE
           DISPLAY 'PROVISION NEEDED:  ' WS-PROVISION
           PERFORM VARYING WS-SEG-IDX FROM 1 BY 1
               UNTIL WS-SEG-IDX > 6
               DISPLAY '  SEGMENT: '
                   WS-SEG-NAME(WS-SEG-IDX)
                   ' BAL=' WS-SEG-BALANCE(WS-SEG-IDX)
                   ' ECL=' WS-SEG-ECL(WS-SEG-IDX)
                   ' RES=' WS-SEG-RESERVE(WS-SEG-IDX)
                   ' RISK=' WS-SEG-RISK(WS-SEG-IDX)
           END-PERFORM.
