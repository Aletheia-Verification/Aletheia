       IDENTIFICATION DIVISION.
       PROGRAM-ID. CD-MATURITY-CALC.
      *================================================================*
      * Certificate of Deposit Maturity and Penalty Calculator         *
      * Computes maturity value, APY, and early withdrawal penalties   *
      * for various CD term structures.                                *
      *================================================================*

       DATA DIVISION.
       WORKING-STORAGE SECTION.

      *--- CD Account Parameters ---*
       01  WS-CD-PRINCIPAL           PIC S9(11)V99 COMP-3.
       01  WS-ANNUAL-RATE            PIC S9(3)V9(6) COMP-3.
       01  WS-TERM-MONTHS            PIC S9(3) COMP-3.
       01  WS-COMPOUND-FREQ          PIC S9(3) COMP-3.
       01  WS-DEPOSIT-DATE           PIC 9(8).
       01  WS-MATURITY-DATE          PIC 9(8).
       01  WS-CURRENT-DATE           PIC 9(8).

      *--- Compounding Work Fields ---*
       01  WS-PERIODS-TOTAL          PIC S9(5) COMP-3.
       01  WS-PERIOD-RATE            PIC S9(3)V9(8) COMP-3.
       01  WS-CURRENT-BALANCE        PIC S9(13)V99 COMP-3.
       01  WS-PERIOD-INTEREST        PIC S9(11)V99 COMP-3.
       01  WS-TOTAL-INTEREST         PIC S9(11)V99 COMP-3.
       01  WS-MATURITY-VALUE         PIC S9(13)V99 COMP-3.
       01  WS-PERIOD-INDEX           PIC S9(5) COMP-3.

      *--- APY Calculation Fields ---*
       01  WS-APY-ESTIMATE           PIC S9(3)V9(6) COMP-3.
       01  WS-APY-ITERATION          PIC S9(3) COMP-3.
       01  WS-APY-TEST-VALUE         PIC S9(13)V99 COMP-3.
       01  WS-APY-DIFF               PIC S9(13)V99 COMP-3.
       01  WS-APY-LOW                PIC S9(3)V9(6) COMP-3.
       01  WS-APY-HIGH               PIC S9(3)V9(6) COMP-3.
       01  WS-APY-MID                PIC S9(3)V9(6) COMP-3.
       01  WS-APY-YEARS              PIC S9(3)V9(4) COMP-3.
       01  WS-APY-DISPLAY            PIC Z9.999999.

      *--- Early Withdrawal Fields ---*
       01  WS-DAYS-HELD              PIC S9(5) COMP-3.
       01  WS-PENALTY-TIER           PIC S9(1) COMP-3.
       01  WS-PENALTY-DAYS           PIC S9(5) COMP-3.
       01  WS-DAILY-INTEREST         PIC S9(9)V9(4) COMP-3.
       01  WS-PENALTY-AMOUNT         PIC S9(11)V99 COMP-3.
       01  WS-NET-PROCEEDS           PIC S9(13)V99 COMP-3.
       01  WS-EARLY-FLAG             PIC 9.
       01  WS-ACCRUED-TO-DATE        PIC S9(11)V99 COMP-3.

      *--- Display Formatting ---*
       01  WS-DISP-PRINCIPAL         PIC $$$,$$$,$$9.99.
       01  WS-DISP-MATURITY          PIC $$$,$$$,$$9.99.
       01  WS-DISP-INTEREST          PIC $$$,$$$,$$9.99.
       01  WS-DISP-PENALTY           PIC $$$,$$$,$$9.99.
       01  WS-DISP-NET               PIC $$$,$$$,$$9.99.
       01  WS-DISP-RATE              PIC Z9.999999.
       01  WS-DISP-DAYS              PIC Z,ZZ9.

      *--- Processing Controls ---*
       01  WS-PROCESS-COUNT          PIC S9(5) COMP-3.
       01  WS-ERROR-COUNT            PIC S9(5) COMP-3.
       01  WS-TEMP-CALC              PIC S9(13)V9(4) COMP-3.

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE-FIELDS
           PERFORM 2000-SET-CD-PARAMETERS
           PERFORM 3000-COMPUTE-MATURITY
           PERFORM 4000-CALCULATE-APY
           PERFORM 5000-CHECK-EARLY-WITHDRAWAL
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.

       1000-INITIALIZE-FIELDS.
           MOVE 0 TO WS-TOTAL-INTEREST
           MOVE 0 TO WS-MATURITY-VALUE
           MOVE 0 TO WS-PENALTY-AMOUNT
           MOVE 0 TO WS-PROCESS-COUNT
           MOVE 0 TO WS-ERROR-COUNT
           MOVE 0 TO WS-EARLY-FLAG
           MOVE 0 TO WS-ACCRUED-TO-DATE
           MOVE 0 TO WS-NET-PROCEEDS.

       2000-SET-CD-PARAMETERS.
           MOVE 100000.00 TO WS-CD-PRINCIPAL
           MOVE 4.750000 TO WS-ANNUAL-RATE
           MOVE 24 TO WS-TERM-MONTHS
           MOVE 12 TO WS-COMPOUND-FREQ
           MOVE 20250115 TO WS-DEPOSIT-DATE
           MOVE 20270115 TO WS-MATURITY-DATE
           MOVE 20260315 TO WS-CURRENT-DATE
           MOVE 425 TO WS-DAYS-HELD.

       3000-COMPUTE-MATURITY.
           COMPUTE WS-PERIODS-TOTAL =
               WS-TERM-MONTHS * WS-COMPOUND-FREQ / 12
           IF WS-PERIODS-TOTAL < 1
               MOVE 1 TO WS-PERIODS-TOTAL
           END-IF
           DIVIDE WS-ANNUAL-RATE BY WS-COMPOUND-FREQ
               GIVING WS-PERIOD-RATE
           END-DIVIDE
           DIVIDE WS-PERIOD-RATE BY 100
               GIVING WS-PERIOD-RATE
           END-DIVIDE
           MOVE WS-CD-PRINCIPAL TO WS-CURRENT-BALANCE
           MOVE 0 TO WS-TOTAL-INTEREST
           PERFORM VARYING WS-PERIOD-INDEX
               FROM 1 BY 1
               UNTIL WS-PERIOD-INDEX > WS-PERIODS-TOTAL
               COMPUTE WS-PERIOD-INTEREST =
                   WS-CURRENT-BALANCE * WS-PERIOD-RATE
               ADD WS-PERIOD-INTEREST TO WS-CURRENT-BALANCE
               ADD WS-PERIOD-INTEREST TO WS-TOTAL-INTEREST
               ADD 1 TO WS-PROCESS-COUNT
           END-PERFORM
           MOVE WS-CURRENT-BALANCE TO WS-MATURITY-VALUE.

       4000-CALCULATE-APY.
           COMPUTE WS-APY-YEARS =
               WS-TERM-MONTHS / 12
           MOVE 0.000000 TO WS-APY-LOW
           MOVE 1.000000 TO WS-APY-HIGH
           PERFORM VARYING WS-APY-ITERATION
               FROM 1 BY 1
               UNTIL WS-APY-ITERATION > 50
               COMPUTE WS-APY-MID =
                   (WS-APY-LOW + WS-APY-HIGH) / 2
               COMPUTE WS-APY-TEST-VALUE =
                   WS-CD-PRINCIPAL *
                   (1 + WS-APY-MID) * WS-APY-YEARS
               IF WS-APY-TEST-VALUE < WS-MATURITY-VALUE
                   MOVE WS-APY-MID TO WS-APY-LOW
               ELSE
                   MOVE WS-APY-MID TO WS-APY-HIGH
               END-IF
           END-PERFORM
           MOVE WS-APY-MID TO WS-APY-ESTIMATE.

       5000-CHECK-EARLY-WITHDRAWAL.
           IF WS-CURRENT-DATE < WS-MATURITY-DATE
               MOVE 1 TO WS-EARLY-FLAG
               PERFORM 5100-DETERMINE-PENALTY-TIER
               PERFORM 5200-COMPUTE-PENALTY
               PERFORM 5300-COMPUTE-NET-PROCEEDS
           ELSE
               MOVE 0 TO WS-EARLY-FLAG
               MOVE WS-MATURITY-VALUE TO WS-NET-PROCEEDS
               MOVE 0 TO WS-PENALTY-AMOUNT
           END-IF.

       5100-DETERMINE-PENALTY-TIER.
           EVALUATE TRUE
               WHEN WS-DAYS-HELD < 90
                   MOVE 1 TO WS-PENALTY-TIER
                   MOVE 90 TO WS-PENALTY-DAYS
               WHEN WS-DAYS-HELD < 180
                   MOVE 2 TO WS-PENALTY-TIER
                   MOVE 180 TO WS-PENALTY-DAYS
               WHEN WS-DAYS-HELD < 365
                   MOVE 3 TO WS-PENALTY-TIER
                   MOVE 270 TO WS-PENALTY-DAYS
               WHEN WS-DAYS-HELD < 730
                   MOVE 4 TO WS-PENALTY-TIER
                   MOVE 365 TO WS-PENALTY-DAYS
               WHEN OTHER
                   MOVE 4 TO WS-PENALTY-TIER
                   MOVE 180 TO WS-PENALTY-DAYS
           END-EVALUATE.

       5200-COMPUTE-PENALTY.
           COMPUTE WS-DAILY-INTEREST =
               WS-CD-PRINCIPAL * WS-ANNUAL-RATE / 100 / 365
           COMPUTE WS-PENALTY-AMOUNT =
               WS-DAILY-INTEREST * WS-PENALTY-DAYS
           COMPUTE WS-ACCRUED-TO-DATE =
               WS-DAILY-INTEREST * WS-DAYS-HELD
           IF WS-PENALTY-AMOUNT > WS-ACCRUED-TO-DATE
               MOVE WS-ACCRUED-TO-DATE TO WS-PENALTY-AMOUNT
           END-IF.

       5300-COMPUTE-NET-PROCEEDS.
           COMPUTE WS-NET-PROCEEDS =
               WS-CD-PRINCIPAL + WS-ACCRUED-TO-DATE
               - WS-PENALTY-AMOUNT
           IF WS-NET-PROCEEDS < WS-CD-PRINCIPAL
               MOVE WS-CD-PRINCIPAL TO WS-NET-PROCEEDS
               COMPUTE WS-PENALTY-AMOUNT =
                   WS-ACCRUED-TO-DATE
           END-IF.

       6000-DISPLAY-RESULTS.
           MOVE WS-CD-PRINCIPAL TO WS-DISP-PRINCIPAL
           DISPLAY "=== CD MATURITY REPORT ==="
           DISPLAY "PRINCIPAL:    " WS-DISP-PRINCIPAL
           MOVE WS-ANNUAL-RATE TO WS-DISP-RATE
           DISPLAY "ANNUAL RATE:  " WS-DISP-RATE "%"
           DISPLAY "TERM MONTHS:  " WS-TERM-MONTHS
           MOVE WS-MATURITY-VALUE TO WS-DISP-MATURITY
           DISPLAY "MATURITY VAL: " WS-DISP-MATURITY
           MOVE WS-TOTAL-INTEREST TO WS-DISP-INTEREST
           DISPLAY "TOTAL INT:    " WS-DISP-INTEREST
           MOVE WS-APY-ESTIMATE TO WS-APY-DISPLAY
           DISPLAY "EST APY:      " WS-APY-DISPLAY "%"
           IF WS-EARLY-FLAG = 1
               DISPLAY "*** EARLY WITHDRAWAL ***"
               MOVE WS-DAYS-HELD TO WS-DISP-DAYS
               DISPLAY "DAYS HELD:    " WS-DISP-DAYS
               DISPLAY "PENALTY TIER: " WS-PENALTY-TIER
               MOVE WS-PENALTY-AMOUNT TO WS-DISP-PENALTY
               DISPLAY "PENALTY:      " WS-DISP-PENALTY
               MOVE WS-NET-PROCEEDS TO WS-DISP-NET
               DISPLAY "NET PROCEEDS: " WS-DISP-NET
           ELSE
               DISPLAY "CD HELD TO MATURITY"
           END-IF
           DISPLAY "PERIODS PROCESSED: " WS-PROCESS-COUNT
           DISPLAY "=== END REPORT ===".
