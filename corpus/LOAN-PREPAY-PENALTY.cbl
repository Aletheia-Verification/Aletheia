       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOAN-PREPAY-PENALTY.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-LOAN-DATA.
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-ORIG-PRINCIPAL      PIC S9(9)V99 COMP-3.
           05 WS-CURRENT-BAL         PIC S9(9)V99 COMP-3.
           05 WS-ANNUAL-RATE         PIC S9(3)V9(6) COMP-3.
           05 WS-MONTHLY-RATE        PIC S9(1)V9(8) COMP-3.
           05 WS-ORIG-TERM           PIC 9(3).
           05 WS-MONTHS-ELAPSED      PIC 9(3).
           05 WS-MONTHS-REMAIN       PIC 9(3).
       01 WS-LOAN-TYPE               PIC X(1).
           88 WS-FIXED-RATE          VALUE 'F'.
           88 WS-VARIABLE-RATE       VALUE 'V'.
           88 WS-JUMBO               VALUE 'J'.
       01 WS-PREPAY-TYPE             PIC X(1).
           88 WS-FULL-PAYOFF         VALUE 'F'.
           88 WS-PARTIAL-PREPAY      VALUE 'P'.
           88 WS-REFI-PREPAY         VALUE 'R'.
       01 WS-PREPAY-AMOUNT           PIC S9(9)V99 COMP-3.
       01 WS-PENALTY-FIELDS.
           05 WS-PENALTY-PCT         PIC S9(1)V9(4) COMP-3.
           05 WS-PENALTY-AMT         PIC S9(7)V99 COMP-3.
           05 WS-MIN-PENALTY         PIC S9(7)V99 COMP-3
               VALUE 250.00.
           05 WS-MAX-PENALTY         PIC S9(7)V99 COMP-3
               VALUE 25000.00.
           05 WS-INT-PENALTY         PIC S9(7)V99 COMP-3.
           05 WS-MONTHS-INT          PIC 9(2).
       01 WS-LOCKOUT-MONTHS          PIC 9(3).
       01 WS-STEPDOWN-FIELDS.
           05 WS-YEAR-1-PCT          PIC S9(1)V9(4) VALUE 0.0500.
           05 WS-YEAR-2-PCT          PIC S9(1)V9(4) VALUE 0.0400.
           05 WS-YEAR-3-PCT          PIC S9(1)V9(4) VALUE 0.0300.
           05 WS-YEAR-4-PCT          PIC S9(1)V9(4) VALUE 0.0200.
           05 WS-YEAR-5-PCT          PIC S9(1)V9(4) VALUE 0.0100.
       01 WS-WAIVER-FLAG             PIC X VALUE 'N'.
           88 WS-WAIVER-ELIGIBLE     VALUE 'Y'.
       01 WS-RESULT-STATUS           PIC X(2).
           88 WS-PENALTY-APPLIES     VALUE 'PA'.
           88 WS-PENALTY-WAIVED      VALUE 'PW'.
           88 WS-NO-PENALTY          VALUE 'NP'.
       01 WS-NET-PROCEEDS            PIC S9(9)V99 COMP-3.
       01 WS-ELAPSED-YEARS           PIC 9(2).
       01 WS-YIELD-MAINT-AMT        PIC S9(7)V99 COMP-3.
       01 WS-TREASURY-RATE           PIC S9(1)V9(6) COMP-3.
       01 WS-RATE-DIFF               PIC S9(1)V9(6) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CHECK-LOCKOUT THRU 2000-EXIT
           PERFORM 3000-CALC-PENALTY THRU 3000-EXIT
           PERFORM 4000-APPLY-LIMITS
           PERFORM 5000-CHECK-WAIVER
           PERFORM 6000-CALC-PROCEEDS
           PERFORM 7000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           COMPUTE WS-MONTHLY-RATE =
               WS-ANNUAL-RATE / 12
           COMPUTE WS-MONTHS-REMAIN =
               WS-ORIG-TERM - WS-MONTHS-ELAPSED
           COMPUTE WS-ELAPSED-YEARS =
               WS-MONTHS-ELAPSED / 12
           MOVE 0 TO WS-PENALTY-AMT
           MOVE 0 TO WS-YIELD-MAINT-AMT
           MOVE 'NP' TO WS-RESULT-STATUS
           MOVE 0.0250 TO WS-TREASURY-RATE.
       2000-CHECK-LOCKOUT.
           EVALUATE TRUE
               WHEN WS-FIXED-RATE
                   MOVE 60 TO WS-LOCKOUT-MONTHS
               WHEN WS-VARIABLE-RATE
                   MOVE 36 TO WS-LOCKOUT-MONTHS
               WHEN WS-JUMBO
                   MOVE 84 TO WS-LOCKOUT-MONTHS
               WHEN OTHER
                   MOVE 0 TO WS-LOCKOUT-MONTHS
           END-EVALUATE
           IF WS-MONTHS-ELAPSED >= WS-LOCKOUT-MONTHS
               SET WS-NO-PENALTY TO TRUE
           END-IF.
       2000-EXIT.
           EXIT.
       3000-CALC-PENALTY.
           IF WS-NO-PENALTY
               GO TO 3000-EXIT
           END-IF
           SET WS-PENALTY-APPLIES TO TRUE
           EVALUATE TRUE
               WHEN WS-ELAPSED-YEARS < 1
                   MOVE WS-YEAR-1-PCT TO WS-PENALTY-PCT
               WHEN WS-ELAPSED-YEARS < 2
                   MOVE WS-YEAR-2-PCT TO WS-PENALTY-PCT
               WHEN WS-ELAPSED-YEARS < 3
                   MOVE WS-YEAR-3-PCT TO WS-PENALTY-PCT
               WHEN WS-ELAPSED-YEARS < 4
                   MOVE WS-YEAR-4-PCT TO WS-PENALTY-PCT
               WHEN OTHER
                   MOVE WS-YEAR-5-PCT TO WS-PENALTY-PCT
           END-EVALUATE
           MULTIPLY WS-PREPAY-AMOUNT BY WS-PENALTY-PCT
               GIVING WS-PENALTY-AMT
           IF WS-JUMBO
               COMPUTE WS-RATE-DIFF =
                   WS-ANNUAL-RATE - WS-TREASURY-RATE
               IF WS-RATE-DIFF > 0
                   COMPUTE WS-YIELD-MAINT-AMT =
                       WS-PREPAY-AMOUNT * WS-RATE-DIFF *
                       WS-MONTHS-REMAIN / 12
                   IF WS-YIELD-MAINT-AMT > WS-PENALTY-AMT
                       MOVE WS-YIELD-MAINT-AMT TO
                           WS-PENALTY-AMT
                   END-IF
               END-IF
           END-IF
           IF WS-REFI-PREPAY
               MOVE 6 TO WS-MONTHS-INT
               COMPUTE WS-INT-PENALTY =
                   WS-CURRENT-BAL * WS-MONTHLY-RATE *
                   WS-MONTHS-INT
               IF WS-INT-PENALTY > WS-PENALTY-AMT
                   MOVE WS-INT-PENALTY TO WS-PENALTY-AMT
               END-IF
           END-IF.
       3000-EXIT.
           EXIT.
       4000-APPLY-LIMITS.
           IF WS-PENALTY-APPLIES
               IF WS-PENALTY-AMT < WS-MIN-PENALTY
                   MOVE WS-MIN-PENALTY TO WS-PENALTY-AMT
               END-IF
               IF WS-PENALTY-AMT > WS-MAX-PENALTY
                   MOVE WS-MAX-PENALTY TO WS-PENALTY-AMT
               END-IF
           END-IF.
       5000-CHECK-WAIVER.
           IF WS-PENALTY-APPLIES
               IF WS-PARTIAL-PREPAY
                   IF WS-PREPAY-AMOUNT <
                       WS-CURRENT-BAL * 0.20
                       SET WS-PENALTY-WAIVED TO TRUE
                       MOVE 0 TO WS-PENALTY-AMT
                   END-IF
               END-IF
           END-IF.
       6000-CALC-PROCEEDS.
           IF WS-FULL-PAYOFF
               COMPUTE WS-NET-PROCEEDS =
                   WS-CURRENT-BAL - WS-PENALTY-AMT
           ELSE
               COMPUTE WS-NET-PROCEEDS =
                   WS-PREPAY-AMOUNT - WS-PENALTY-AMT
           END-IF.
       7000-DISPLAY-RESULTS.
           DISPLAY 'PREPAYMENT PENALTY ANALYSIS'
           DISPLAY '============================'
           DISPLAY 'ACCOUNT:        ' WS-ACCT-NUM
           DISPLAY 'CURRENT BAL:    ' WS-CURRENT-BAL
           DISPLAY 'PREPAY AMOUNT:  ' WS-PREPAY-AMOUNT
           DISPLAY 'MONTHS ELAPSED: ' WS-MONTHS-ELAPSED
           DISPLAY 'ELAPSED YEARS:  ' WS-ELAPSED-YEARS
           IF WS-PENALTY-APPLIES
               DISPLAY 'STATUS: PENALTY APPLIES'
               DISPLAY 'PENALTY RATE:   ' WS-PENALTY-PCT
               DISPLAY 'PENALTY AMOUNT: ' WS-PENALTY-AMT
           END-IF
           IF WS-PENALTY-WAIVED
               DISPLAY 'STATUS: PENALTY WAIVED (< 20%)'
           END-IF
           IF WS-NO-PENALTY
               DISPLAY 'STATUS: NO PENALTY (PAST LOCKOUT)'
           END-IF
           DISPLAY 'NET PROCEEDS:   ' WS-NET-PROCEEDS.
