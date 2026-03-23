       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOAN-FORBEARANCE-CALC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-LOAN-DATA.
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-PRINCIPAL            PIC S9(9)V99 COMP-3.
           05 WS-ANNUAL-RATE          PIC S9(3)V9(6) COMP-3.
           05 WS-MONTHLY-RATE         PIC S9(1)V9(8) COMP-3.
           05 WS-MONTHLY-PMT          PIC S9(7)V99 COMP-3.
           05 WS-REMAINING-TERM       PIC 9(3).
           05 WS-CURRENT-BAL          PIC S9(9)V99 COMP-3.
       01 WS-FORBEAR-TYPE            PIC X(1).
           88 WS-FULL-FORBEAR         VALUE 'F'.
           88 WS-REDUCED-PMT          VALUE 'R'.
           88 WS-INT-ONLY             VALUE 'I'.
       01 WS-FORBEAR-MONTHS          PIC 9(2).
       01 WS-REPAY-PLAN              PIC X(1).
           88 WS-LUMP-SUM             VALUE 'L'.
           88 WS-SPREAD-OVER          VALUE 'S'.
           88 WS-TERM-EXTEND          VALUE 'T'.
           88 WS-MODIFICATION         VALUE 'M'.
       01 WS-HARDSHIP-TYPE           PIC X(1).
           88 WS-JOB-LOSS             VALUE 'J'.
           88 WS-MEDICAL              VALUE 'M'.
           88 WS-DISASTER             VALUE 'D'.
           88 WS-OTHER-HARDSHIP       VALUE 'O'.
       01 WS-CALC-FIELDS.
           05 WS-DEFERRED-INT        PIC S9(7)V99 COMP-3.
           05 WS-DEFERRED-PRIN       PIC S9(7)V99 COMP-3.
           05 WS-TOTAL-DEFERRED      PIC S9(9)V99 COMP-3.
           05 WS-REDUCED-AMOUNT      PIC S9(7)V99 COMP-3.
           05 WS-INT-ONLY-AMT        PIC S9(7)V99 COMP-3.
           05 WS-POST-BAL            PIC S9(9)V99 COMP-3.
           05 WS-POST-PMT            PIC S9(7)V99 COMP-3.
           05 WS-SPREAD-MONTHS       PIC 9(3).
           05 WS-EXTRA-PER-MONTH     PIC S9(7)V99 COMP-3.
           05 WS-NEW-TERM            PIC 9(3).
           05 WS-MOD-RATE            PIC S9(3)V9(6) COMP-3.
       01 WS-MAX-FORBEAR             PIC 9(2) VALUE 12.
       01 WS-MONTH-IDX               PIC 9(2).
       01 WS-MONTH-INT               PIC S9(7)V99 COMP-3.
       01 WS-APPROVED-FLAG           PIC X VALUE 'N'.
           88 WS-IS-APPROVED          VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-VALIDATE-REQUEST
           IF WS-IS-APPROVED
               PERFORM 3000-CALC-DEFERRAL
               PERFORM 4000-CALC-REPAYMENT
               PERFORM 5000-CALC-POST-FORBEAR
           END-IF
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           COMPUTE WS-MONTHLY-RATE =
               WS-ANNUAL-RATE / 12
           MOVE 0 TO WS-DEFERRED-INT
           MOVE 0 TO WS-DEFERRED-PRIN
           MOVE 0 TO WS-TOTAL-DEFERRED
           MOVE 'N' TO WS-APPROVED-FLAG.
       2000-VALIDATE-REQUEST.
           IF WS-FORBEAR-MONTHS > WS-MAX-FORBEAR
               MOVE WS-MAX-FORBEAR TO WS-FORBEAR-MONTHS
           END-IF
           EVALUATE TRUE
               WHEN WS-JOB-LOSS
                   MOVE 'Y' TO WS-APPROVED-FLAG
               WHEN WS-MEDICAL
                   MOVE 'Y' TO WS-APPROVED-FLAG
               WHEN WS-DISASTER
                   MOVE 'Y' TO WS-APPROVED-FLAG
                   IF WS-FORBEAR-MONTHS < 6
                       MOVE 6 TO WS-FORBEAR-MONTHS
                   END-IF
               WHEN WS-OTHER-HARDSHIP
                   IF WS-FORBEAR-MONTHS <= 3
                       MOVE 'Y' TO WS-APPROVED-FLAG
                   END-IF
               WHEN OTHER
                   DISPLAY 'INVALID HARDSHIP TYPE'
           END-EVALUATE.
       3000-CALC-DEFERRAL.
           MOVE WS-CURRENT-BAL TO WS-POST-BAL
           PERFORM VARYING WS-MONTH-IDX FROM 1 BY 1
               UNTIL WS-MONTH-IDX > WS-FORBEAR-MONTHS
               COMPUTE WS-MONTH-INT =
                   WS-POST-BAL * WS-MONTHLY-RATE
               IF WS-FULL-FORBEAR
                   ADD WS-MONTH-INT TO WS-DEFERRED-INT
                   ADD WS-MONTHLY-PMT TO WS-DEFERRED-PRIN
                   ADD WS-MONTH-INT TO WS-POST-BAL
               ELSE
                   IF WS-INT-ONLY
                       MOVE WS-MONTH-INT TO WS-INT-ONLY-AMT
                   ELSE
                       COMPUTE WS-REDUCED-AMOUNT =
                           WS-MONTHLY-PMT * 0.50
                       ADD WS-MONTH-INT TO WS-DEFERRED-INT
                       SUBTRACT WS-REDUCED-AMOUNT FROM
                           WS-MONTH-INT
                       IF WS-MONTH-INT > 0
                           ADD WS-MONTH-INT TO WS-POST-BAL
                       END-IF
                   END-IF
               END-IF
           END-PERFORM
           COMPUTE WS-TOTAL-DEFERRED =
               WS-DEFERRED-INT + WS-DEFERRED-PRIN.
       4000-CALC-REPAYMENT.
           EVALUATE TRUE
               WHEN WS-LUMP-SUM
                   MOVE WS-TOTAL-DEFERRED TO
                       WS-EXTRA-PER-MONTH
                   MOVE 1 TO WS-SPREAD-MONTHS
               WHEN WS-SPREAD-OVER
                   COMPUTE WS-SPREAD-MONTHS =
                       WS-FORBEAR-MONTHS * 2
                   COMPUTE WS-EXTRA-PER-MONTH =
                       WS-TOTAL-DEFERRED /
                       WS-SPREAD-MONTHS
               WHEN WS-TERM-EXTEND
                   COMPUTE WS-NEW-TERM =
                       WS-REMAINING-TERM +
                       WS-FORBEAR-MONTHS
                   MOVE 0 TO WS-EXTRA-PER-MONTH
               WHEN WS-MODIFICATION
                   COMPUTE WS-MOD-RATE =
                       WS-ANNUAL-RATE - 0.0100
                   IF WS-MOD-RATE < 0.0200
                       MOVE 0.0200 TO WS-MOD-RATE
                   END-IF
                   COMPUTE WS-NEW-TERM =
                       WS-REMAINING-TERM + 60
                   MOVE 0 TO WS-EXTRA-PER-MONTH
           END-EVALUATE.
       5000-CALC-POST-FORBEAR.
           IF WS-MODIFICATION
               COMPUTE WS-POST-PMT =
                   WS-POST-BAL *
                   (WS-MOD-RATE / 12) /
                   (1 - (1 + WS-MOD-RATE / 12)
                   ** (0 - WS-NEW-TERM))
           ELSE
               IF WS-TERM-EXTEND
                   COMPUTE WS-POST-PMT =
                       WS-POST-BAL *
                       WS-MONTHLY-RATE /
                       (1 - (1 + WS-MONTHLY-RATE)
                       ** (0 - WS-NEW-TERM))
               ELSE
                   COMPUTE WS-POST-PMT =
                       WS-MONTHLY-PMT + WS-EXTRA-PER-MONTH
               END-IF
           END-IF.
       6000-DISPLAY-RESULTS.
           DISPLAY 'FORBEARANCE PLAN ANALYSIS'
           DISPLAY '========================='
           DISPLAY 'ACCOUNT:         ' WS-ACCT-NUM
           DISPLAY 'CURRENT BALANCE: ' WS-CURRENT-BAL
           DISPLAY 'MONTHLY PAYMENT: ' WS-MONTHLY-PMT
           IF WS-IS-APPROVED
               DISPLAY 'STATUS: APPROVED'
               DISPLAY 'MONTHS:          ' WS-FORBEAR-MONTHS
               IF WS-FULL-FORBEAR
                   DISPLAY 'TYPE: FULL FORBEARANCE'
               END-IF
               IF WS-REDUCED-PMT
                   DISPLAY 'TYPE: REDUCED PAYMENT'
                   DISPLAY 'REDUCED TO:      ' WS-REDUCED-AMOUNT
               END-IF
               IF WS-INT-ONLY
                   DISPLAY 'TYPE: INTEREST ONLY'
                   DISPLAY 'INT PAYMENT:     ' WS-INT-ONLY-AMT
               END-IF
               DISPLAY 'DEFERRED INT:    ' WS-DEFERRED-INT
               DISPLAY 'TOTAL DEFERRED:  ' WS-TOTAL-DEFERRED
               DISPLAY 'POST-FORB BAL:   ' WS-POST-BAL
               DISPLAY 'POST-FORB PMT:   ' WS-POST-PMT
           ELSE
               DISPLAY 'STATUS: DENIED'
           END-IF.
