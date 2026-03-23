       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOAN-CONV-ASSESS.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-LOAN-DATA.
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-CURRENT-BAL         PIC S9(9)V99 COMP-3.
           05 WS-CURRENT-RATE        PIC S9(3)V9(6) COMP-3.
           05 WS-APPRAISED-VALUE     PIC S9(9)V99 COMP-3.
           05 WS-MONTHLY-INCOME      PIC S9(7)V99 COMP-3.
           05 WS-MONTHLY-DEBT        PIC S9(7)V99 COMP-3.
           05 WS-CREDIT-SCORE        PIC 9(3).
           05 WS-MONTHS-OWNED        PIC 9(3).
           05 WS-CURRENT-PMT         PIC S9(7)V99 COMP-3.
       01 WS-CURRENT-PROGRAM         PIC X(3).
           88 WS-IS-FHA              VALUE 'FHA'.
           88 WS-IS-VA               VALUE 'VA '.
           88 WS-IS-CONV             VALUE 'CNV'.
           88 WS-IS-USDA             VALUE 'USD'.
       01 WS-TARGET-PROGRAM          PIC X(3).
       01 WS-LTV                     PIC S9(3)V99 COMP-3.
       01 WS-DTI                     PIC S9(1)V9(4) COMP-3.
       01 WS-ELIGIBLE-FLAG           PIC X VALUE 'N'.
           88 WS-IS-ELIGIBLE         VALUE 'Y'.
       01 WS-DENIAL-REASON           PIC X(40).
       01 WS-CONV-RATE               PIC S9(3)V9(6) COMP-3.
       01 WS-CONV-PMT                PIC S9(7)V99 COMP-3.
       01 WS-PMT-SAVINGS             PIC S9(7)V99 COMP-3.
       01 WS-MIP-SAVINGS             PIC S9(5)V99 COMP-3.
       01 WS-MONTHLY-MIP             PIC S9(5)V99 COMP-3.
       01 WS-SCORE-VALID             PIC X VALUE 'N'.
           88 WS-SCORE-OK            VALUE 'Y'.
       01 WS-MIN-SCORE               PIC 9(3).
       01 WS-MIN-MONTHS              PIC 9(3) VALUE 24.
       01 WS-MAX-LTV                 PIC S9(3)V99 COMP-3.
       01 WS-MAX-DTI                 PIC S9(1)V9(4) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-VALIDATE-SCORE
           PERFORM 3000-CALC-RATIOS
           PERFORM 4000-CHECK-ELIGIBILITY
           PERFORM 5000-CALC-SAVINGS
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'N' TO WS-ELIGIBLE-FLAG
           MOVE SPACES TO WS-DENIAL-REASON
           MOVE 0 TO WS-PMT-SAVINGS
           MOVE 0 TO WS-MIP-SAVINGS
           MOVE 'N' TO WS-SCORE-VALID.
       2000-VALIDATE-SCORE.
           IF WS-CREDIT-SCORE IS NUMERIC
               IF WS-CREDIT-SCORE >= 300
                   IF WS-CREDIT-SCORE <= 850
                       MOVE 'Y' TO WS-SCORE-VALID
                   END-IF
               END-IF
           END-IF
           IF WS-SCORE-OK
               DISPLAY 'CREDIT SCORE VALIDATED: '
                   WS-CREDIT-SCORE
           ELSE
               DISPLAY 'INVALID CREDIT SCORE'
           END-IF.
       3000-CALC-RATIOS.
           IF WS-APPRAISED-VALUE > 0
               COMPUTE WS-LTV =
                   (WS-CURRENT-BAL / WS-APPRAISED-VALUE)
                   * 100
           END-IF
           IF WS-MONTHLY-INCOME > 0
               COMPUTE WS-DTI =
                   (WS-MONTHLY-DEBT + WS-CURRENT-PMT) /
                   WS-MONTHLY-INCOME
           END-IF.
       4000-CHECK-ELIGIBILITY.
           EVALUATE TRUE
               WHEN WS-IS-FHA
                   MOVE 'CNV' TO WS-TARGET-PROGRAM
                   MOVE 620 TO WS-MIN-SCORE
                   MOVE 80.00 TO WS-MAX-LTV
                   MOVE 0.4500 TO WS-MAX-DTI
                   COMPUTE WS-MONTHLY-MIP =
                       WS-CURRENT-BAL * 0.0055 / 12
               WHEN WS-IS-VA
                   MOVE 'CNV' TO WS-TARGET-PROGRAM
                   MOVE 640 TO WS-MIN-SCORE
                   MOVE 80.00 TO WS-MAX-LTV
                   MOVE 0.4300 TO WS-MAX-DTI
                   MOVE 0 TO WS-MONTHLY-MIP
               WHEN WS-IS-USDA
                   MOVE 'CNV' TO WS-TARGET-PROGRAM
                   MOVE 640 TO WS-MIN-SCORE
                   MOVE 80.00 TO WS-MAX-LTV
                   MOVE 0.4300 TO WS-MAX-DTI
                   COMPUTE WS-MONTHLY-MIP =
                       WS-CURRENT-BAL * 0.0035 / 12
               WHEN OTHER
                   MOVE 'NO CONVERSION NEEDED'
                       TO WS-DENIAL-REASON
                   GO TO 4000-CHECK-ELIGIBILITY-EXIT
           END-EVALUATE
           IF WS-CREDIT-SCORE < WS-MIN-SCORE
               MOVE 'CREDIT SCORE TOO LOW'
                   TO WS-DENIAL-REASON
           ELSE
               IF WS-LTV > WS-MAX-LTV
                   MOVE 'LTV EXCEEDS MAXIMUM'
                       TO WS-DENIAL-REASON
               ELSE
                   IF WS-DTI > WS-MAX-DTI
                       MOVE 'DTI EXCEEDS MAXIMUM'
                           TO WS-DENIAL-REASON
                   ELSE
                       IF WS-MONTHS-OWNED < WS-MIN-MONTHS
                           MOVE 'INSUFFICIENT SEASONING'
                               TO WS-DENIAL-REASON
                       ELSE
                           MOVE 'Y' TO WS-ELIGIBLE-FLAG
                       END-IF
                   END-IF
               END-IF
           END-IF.
       4000-CHECK-ELIGIBILITY-EXIT.
           EXIT.
       5000-CALC-SAVINGS.
           IF WS-IS-ELIGIBLE
               SUBTRACT 0.0050 FROM WS-CURRENT-RATE
                   GIVING WS-CONV-RATE
               IF WS-CONV-RATE < 0.0300
                   MOVE 0.0300 TO WS-CONV-RATE
               END-IF
               COMPUTE WS-CONV-PMT =
                   WS-CURRENT-BAL *
                   (WS-CONV-RATE / 12) /
                   (1 - (1 + WS-CONV-RATE / 12) **
                   (0 - 360))
               COMPUTE WS-PMT-SAVINGS =
                   WS-CURRENT-PMT - WS-CONV-PMT
               MOVE WS-MONTHLY-MIP TO WS-MIP-SAVINGS
           END-IF.
       6000-DISPLAY-RESULTS.
           DISPLAY 'LOAN CONVERSION ASSESSMENT'
           DISPLAY '=========================='
           DISPLAY 'ACCOUNT:         ' WS-ACCT-NUM
           DISPLAY 'CURRENT PROGRAM: ' WS-CURRENT-PROGRAM
           DISPLAY 'CREDIT SCORE:    ' WS-CREDIT-SCORE
           DISPLAY 'LTV:             ' WS-LTV
           DISPLAY 'DTI:             ' WS-DTI
           IF WS-IS-ELIGIBLE
               DISPLAY 'STATUS: ELIGIBLE'
               DISPLAY 'TARGET PROGRAM:  ' WS-TARGET-PROGRAM
               DISPLAY 'CONV RATE:       ' WS-CONV-RATE
               DISPLAY 'CONV PMT:        ' WS-CONV-PMT
               DISPLAY 'PMT SAVINGS:     ' WS-PMT-SAVINGS
               DISPLAY 'MIP SAVINGS:     ' WS-MIP-SAVINGS
           ELSE
               DISPLAY 'STATUS: INELIGIBLE'
               DISPLAY 'REASON: ' WS-DENIAL-REASON
           END-IF.
