       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOAN-GRACE-PERIOD-CALC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-LOAN-INFO.
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-PRINCIPAL            PIC S9(9)V99 COMP-3.
           05 WS-ANNUAL-RATE          PIC S9(3)V9(6) COMP-3.
           05 WS-MONTHLY-RATE         PIC S9(1)V9(8) COMP-3.
           05 WS-PAYMENT-DUE          PIC S9(7)V99 COMP-3.
           05 WS-BALANCE              PIC S9(9)V99 COMP-3.
           05 WS-DUE-DAY              PIC 9(2).
           05 WS-GRACE-DAYS           PIC 9(2) VALUE 15.
       01 WS-LOAN-STATUS             PIC X(1).
           88 WS-CURRENT              VALUE 'C'.
           88 WS-GRACE                VALUE 'G'.
           88 WS-LATE                 VALUE 'L'.
           88 WS-DEFAULT              VALUE 'D'.
       01 WS-PAYMENT-TYPE            PIC X(1).
           88 WS-FULL-PAY             VALUE 'F'.
           88 WS-PARTIAL-PAY          VALUE 'P'.
           88 WS-NO-PAY               VALUE 'N'.
       01 WS-DATE-FIELDS.
           05 WS-CURRENT-DATE         PIC 9(8).
           05 WS-DUE-DATE             PIC 9(8).
           05 WS-GRACE-END-DATE       PIC 9(8).
           05 WS-DAYS-PAST-DUE        PIC S9(3) COMP-3.
       01 WS-GRACE-CALC.
           05 WS-GRACE-INT-RATE       PIC S9(1)V9(8) COMP-3.
           05 WS-GRACE-INTEREST       PIC S9(7)V99 COMP-3.
           05 WS-DAILY-RATE           PIC S9(1)V9(10) COMP-3.
           05 WS-ACCUM-INTEREST       PIC S9(7)V99 COMP-3.
           05 WS-PENALTY-RATE         PIC S9(1)V9(4) COMP-3
               VALUE 0.0500.
           05 WS-PENALTY-AMOUNT       PIC S9(7)V99 COMP-3.
           05 WS-TOTAL-DUE            PIC S9(9)V99 COMP-3.
       01 WS-LATE-FEE-TIER           PIC X(1).
           88 WS-TIER-1               VALUE '1'.
           88 WS-TIER-2               VALUE '2'.
           88 WS-TIER-3               VALUE '3'.
       01 WS-LATE-FEE                PIC S9(5)V99 COMP-3.
       01 WS-PAYMENT-RECEIVED        PIC S9(7)V99 COMP-3.
       01 WS-SHORTFALL               PIC S9(7)V99 COMP-3.
       01 WS-PROCESS-FLAG            PIC X VALUE 'Y'.
           88 WS-CONTINUE             VALUE 'Y'.
           88 WS-STOP                 VALUE 'N'.
       01 WS-DAY-IDX                 PIC 9(3).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-MONTHLY-RATE
           PERFORM 3000-DETERMINE-STATUS
           IF WS-CONTINUE
               PERFORM 4000-CALC-GRACE-INTEREST
           END-IF
           IF WS-CONTINUE
               PERFORM 5000-ASSESS-LATE-FEE
           END-IF
           IF WS-CONTINUE
               PERFORM 6000-CALC-TOTAL-DUE
           END-IF
           PERFORM 7000-APPLY-PAYMENT THRU 7000-EXIT
           PERFORM 8000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-GRACE-INTEREST
           MOVE 0 TO WS-ACCUM-INTEREST
           MOVE 0 TO WS-PENALTY-AMOUNT
           MOVE 0 TO WS-LATE-FEE
           MOVE 0 TO WS-SHORTFALL
           MOVE 'Y' TO WS-PROCESS-FLAG
           MOVE 'C' TO WS-LOAN-STATUS.
       2000-CALC-MONTHLY-RATE.
           COMPUTE WS-MONTHLY-RATE =
               WS-ANNUAL-RATE / 12
           COMPUTE WS-DAILY-RATE =
               WS-ANNUAL-RATE / 360.
       3000-DETERMINE-STATUS.
           IF WS-DAYS-PAST-DUE = 0
               SET WS-CURRENT TO TRUE
               MOVE 'N' TO WS-PROCESS-FLAG
               DISPLAY 'LOAN CURRENT - NO GRACE CALC'
           ELSE
               IF WS-DAYS-PAST-DUE <= WS-GRACE-DAYS
                   SET WS-GRACE TO TRUE
               ELSE
                   IF WS-DAYS-PAST-DUE <= 90
                       SET WS-LATE TO TRUE
                   ELSE
                       SET WS-DEFAULT TO TRUE
                   END-IF
               END-IF
           END-IF.
       4000-CALC-GRACE-INTEREST.
           MOVE 0 TO WS-ACCUM-INTEREST
           PERFORM VARYING WS-DAY-IDX FROM 1 BY 1
               UNTIL WS-DAY-IDX > WS-DAYS-PAST-DUE
               COMPUTE WS-GRACE-INTEREST =
                   WS-BALANCE * WS-DAILY-RATE
               ADD WS-GRACE-INTEREST TO WS-ACCUM-INTEREST
           END-PERFORM
           IF WS-LATE OR WS-DEFAULT
               COMPUTE WS-PENALTY-AMOUNT =
                   WS-BALANCE * WS-PENALTY-RATE *
                   WS-DAYS-PAST-DUE / 360
           END-IF.
       5000-ASSESS-LATE-FEE.
           IF WS-GRACE
               MOVE 0 TO WS-LATE-FEE
           ELSE
               EVALUATE TRUE
                   WHEN WS-DAYS-PAST-DUE < 30
                       SET WS-TIER-1 TO TRUE
                       COMPUTE WS-LATE-FEE =
                           WS-PAYMENT-DUE * 0.04
                       IF WS-LATE-FEE < 25
                           MOVE 25.00 TO WS-LATE-FEE
                       END-IF
                   WHEN WS-DAYS-PAST-DUE < 60
                       SET WS-TIER-2 TO TRUE
                       COMPUTE WS-LATE-FEE =
                           WS-PAYMENT-DUE * 0.06
                       IF WS-LATE-FEE < 50
                           MOVE 50.00 TO WS-LATE-FEE
                       END-IF
                   WHEN OTHER
                       SET WS-TIER-3 TO TRUE
                       COMPUTE WS-LATE-FEE =
                           WS-PAYMENT-DUE * 0.08
                       IF WS-LATE-FEE < 75
                           MOVE 75.00 TO WS-LATE-FEE
                       END-IF
               END-EVALUATE
           END-IF.
       6000-CALC-TOTAL-DUE.
           COMPUTE WS-TOTAL-DUE =
               WS-PAYMENT-DUE + WS-ACCUM-INTEREST +
               WS-PENALTY-AMOUNT + WS-LATE-FEE.
       7000-APPLY-PAYMENT.
           EVALUATE TRUE
               WHEN WS-PAYMENT-RECEIVED >= WS-TOTAL-DUE
                   SET WS-FULL-PAY TO TRUE
                   SUBTRACT WS-PAYMENT-DUE FROM
                       WS-BALANCE
               WHEN WS-PAYMENT-RECEIVED > 0
                   SET WS-PARTIAL-PAY TO TRUE
                   COMPUTE WS-SHORTFALL =
                       WS-TOTAL-DUE - WS-PAYMENT-RECEIVED
               WHEN OTHER
                   SET WS-NO-PAY TO TRUE
                   MOVE WS-TOTAL-DUE TO WS-SHORTFALL
           END-EVALUATE.
       7000-EXIT.
           EXIT.
       8000-DISPLAY-RESULTS.
           DISPLAY 'GRACE PERIOD CALCULATION'
           DISPLAY '========================='
           DISPLAY 'ACCOUNT:       ' WS-ACCT-NUM
           DISPLAY 'BALANCE:       ' WS-BALANCE
           DISPLAY 'PAYMENT DUE:   ' WS-PAYMENT-DUE
           DISPLAY 'DAYS PAST DUE: ' WS-DAYS-PAST-DUE
           IF WS-CURRENT
               DISPLAY 'STATUS: CURRENT'
           END-IF
           IF WS-GRACE
               DISPLAY 'STATUS: IN GRACE PERIOD'
               DISPLAY 'GRACE INTEREST: ' WS-ACCUM-INTEREST
           END-IF
           IF WS-LATE
               DISPLAY 'STATUS: LATE'
               DISPLAY 'ACCRUED INT:    ' WS-ACCUM-INTEREST
               DISPLAY 'PENALTY:        ' WS-PENALTY-AMOUNT
               DISPLAY 'LATE FEE:       ' WS-LATE-FEE
               DISPLAY 'LATE FEE TIER:  ' WS-LATE-FEE-TIER
           END-IF
           IF WS-DEFAULT
               DISPLAY 'STATUS: DEFAULT'
           END-IF
           DISPLAY 'TOTAL DUE:     ' WS-TOTAL-DUE
           IF WS-FULL-PAY
               DISPLAY 'PAYMENT: FULL - APPLIED'
           END-IF
           IF WS-PARTIAL-PAY
               DISPLAY 'PAYMENT: PARTIAL'
               DISPLAY 'SHORTFALL:     ' WS-SHORTFALL
           END-IF
           IF WS-NO-PAY
               DISPLAY 'PAYMENT: NONE RECEIVED'
           END-IF.
