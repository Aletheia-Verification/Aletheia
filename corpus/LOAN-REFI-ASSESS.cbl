       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOAN-REFI-ASSESS.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-EXISTING-LOAN.
           05 WS-EX-ACCT          PIC X(12).
           05 WS-EX-BALANCE       PIC S9(9)V99 COMP-3.
           05 WS-EX-RATE          PIC S9(2)V9(4) COMP-3.
           05 WS-EX-TERM-LEFT     PIC 9(3).
           05 WS-EX-MONTHLY-PMT   PIC S9(7)V99 COMP-3.
           05 WS-EX-PREPAY-PEN    PIC X VALUE 'N'.
               88 HAS-PREPAY      VALUE 'Y'.
       01 WS-NEW-TERMS.
           05 WS-NEW-RATE         PIC S9(2)V9(4) COMP-3.
           05 WS-NEW-TERM         PIC 9(3).
           05 WS-CLOSING-COSTS    PIC S9(7)V99 COMP-3.
           05 WS-POINTS           PIC S9(1)V99 COMP-3.
           05 WS-POINT-COST       PIC S9(7)V99 COMP-3.
       01 WS-ANALYSIS.
           05 WS-NEW-MONTHLY-PMT  PIC S9(7)V99 COMP-3.
           05 WS-MONTHLY-SAVINGS  PIC S9(7)V99 COMP-3.
           05 WS-TOTAL-NEW-COST   PIC S9(9)V99 COMP-3.
           05 WS-TOTAL-OLD-COST   PIC S9(9)V99 COMP-3.
           05 WS-BREAKEVEN-MO     PIC 9(3).
           05 WS-NET-SAVINGS      PIC S9(9)V99 COMP-3.
           05 WS-PREPAY-AMOUNT    PIC S9(7)V99 COMP-3.
       01 WS-RECOMMENDATION       PIC X(20).
       01 WS-RATE-DIFF            PIC S9(2)V9(4) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-CALC-NEW-PAYMENT
           PERFORM 2000-CALC-COSTS
           PERFORM 3000-CALC-BREAKEVEN
           PERFORM 4000-RECOMMEND
           PERFORM 5000-OUTPUT
           STOP RUN.
       1000-CALC-NEW-PAYMENT.
           COMPUTE WS-RATE-DIFF =
               WS-EX-RATE - WS-NEW-RATE
           COMPUTE WS-NEW-MONTHLY-PMT =
               WS-EX-BALANCE / WS-NEW-TERM
           COMPUTE WS-MONTHLY-SAVINGS =
               WS-EX-MONTHLY-PMT - WS-NEW-MONTHLY-PMT.
       2000-CALC-COSTS.
           COMPUTE WS-POINT-COST =
               WS-EX-BALANCE * WS-POINTS / 100
           COMPUTE WS-TOTAL-OLD-COST =
               WS-EX-MONTHLY-PMT * WS-EX-TERM-LEFT
           COMPUTE WS-TOTAL-NEW-COST =
               (WS-NEW-MONTHLY-PMT * WS-NEW-TERM) +
               WS-CLOSING-COSTS + WS-POINT-COST
           IF HAS-PREPAY
               COMPUTE WS-PREPAY-AMOUNT =
                   WS-EX-BALANCE * 0.02
               ADD WS-PREPAY-AMOUNT TO WS-TOTAL-NEW-COST
           ELSE
               MOVE 0 TO WS-PREPAY-AMOUNT
           END-IF
           COMPUTE WS-NET-SAVINGS =
               WS-TOTAL-OLD-COST - WS-TOTAL-NEW-COST.
       3000-CALC-BREAKEVEN.
           IF WS-MONTHLY-SAVINGS > 0
               COMPUTE WS-BREAKEVEN-MO =
                   (WS-CLOSING-COSTS + WS-POINT-COST +
                    WS-PREPAY-AMOUNT) /
                   WS-MONTHLY-SAVINGS
           ELSE
               MOVE 999 TO WS-BREAKEVEN-MO
           END-IF.
       4000-RECOMMEND.
           IF WS-RATE-DIFF < 0.5000
               MOVE 'NOT RECOMMENDED     ' TO
                   WS-RECOMMENDATION
           ELSE
               IF WS-NET-SAVINGS <= 0
                   MOVE 'NOT BENEFICIAL      ' TO
                       WS-RECOMMENDATION
               ELSE
                   IF WS-BREAKEVEN-MO <= 24
                       MOVE 'STRONGLY RECOMMENDED'
                           TO WS-RECOMMENDATION
                   ELSE
                       IF WS-BREAKEVEN-MO <= 48
                           MOVE 'RECOMMENDED         '
                               TO WS-RECOMMENDATION
                       ELSE
                           MOVE 'MARGINAL BENEFIT    '
                               TO WS-RECOMMENDATION
                       END-IF
                   END-IF
               END-IF
           END-IF.
       5000-OUTPUT.
           DISPLAY 'REFINANCE ASSESSMENT'
           DISPLAY '===================='
           DISPLAY 'CURRENT RATE:   ' WS-EX-RATE
           DISPLAY 'NEW RATE:       ' WS-NEW-RATE
           DISPLAY 'RATE DIFF:      ' WS-RATE-DIFF
           DISPLAY 'CURRENT PMT:    $' WS-EX-MONTHLY-PMT
           DISPLAY 'NEW PMT:        $' WS-NEW-MONTHLY-PMT
           DISPLAY 'MONTHLY SAVE:   $' WS-MONTHLY-SAVINGS
           DISPLAY 'CLOSING COSTS:  $' WS-CLOSING-COSTS
           DISPLAY 'POINT COST:     $' WS-POINT-COST
           IF HAS-PREPAY
               DISPLAY 'PREPAY PENALTY: $' WS-PREPAY-AMOUNT
           END-IF
           DISPLAY 'BREAKEVEN MOS:  ' WS-BREAKEVEN-MO
           DISPLAY 'NET SAVINGS:    $' WS-NET-SAVINGS
           DISPLAY 'RECOMMENDATION: ' WS-RECOMMENDATION.
