       IDENTIFICATION DIVISION.
       PROGRAM-ID. ESCROW-ANALYSIS.
      *================================================================*
      * Mortgage Escrow Analysis and Adjustment                        *
      * Projects tax/insurance disbursements, computes monthly escrow  *
      * payment, detects surplus/shortage, generates spread plan.      *
      *================================================================*

       DATA DIVISION.
       WORKING-STORAGE SECTION.

      *--- Loan Parameters ---*
       01  WS-LOAN-NUMBER            PIC 9(10).
       01  WS-LOAN-BALANCE           PIC S9(11)V99 COMP-3.
       01  WS-MONTHLY-PAYMENT        PIC S9(7)V99 COMP-3.
       01  WS-ESCROW-BALANCE         PIC S9(9)V99 COMP-3.

      *--- Tax Fields ---*
       01  WS-ANNUAL-TAX             PIC S9(9)V99 COMP-3.
       01  WS-TAX-INSTALLMENT        PIC S9(7)V99 COMP-3.
       01  WS-TAX-FREQUENCY          PIC S9(1) COMP-3.
       01  WS-MONTHLY-TAX            PIC S9(7)V99 COMP-3.

      *--- Insurance Fields ---*
       01  WS-ANNUAL-INSURANCE       PIC S9(9)V99 COMP-3.
       01  WS-MONTHLY-INSURANCE      PIC S9(7)V99 COMP-3.
       01  WS-INSURANCE-DUE-MONTH    PIC S9(3) COMP-3.

      *--- Monthly Projection Table ---*
       01  WS-MONTH-INDEX            PIC S9(3) COMP-3.
       01  WS-PROJECTED-TABLE.
           05  WS-MONTH-ENTRY OCCURS 12.
               10  WP-MONTH-NUM      PIC S9(3) COMP-3.
               10  WP-ESCROW-IN      PIC S9(7)V99 COMP-3.
               10  WP-TAX-OUT        PIC S9(7)V99 COMP-3.
               10  WP-INS-OUT        PIC S9(7)V99 COMP-3.
               10  WP-NET-FLOW       PIC S9(7)V99 COMP-3.
               10  WP-END-BALANCE    PIC S9(9)V99 COMP-3.

      *--- Escrow Computation ---*
       01  WS-TOTAL-ANNUAL-DISB      PIC S9(9)V99 COMP-3.
       01  WS-REQUIRED-MONTHLY       PIC S9(7)V99 COMP-3.
       01  WS-CURRENT-MONTHLY        PIC S9(7)V99 COMP-3.
       01  WS-MONTHLY-ADJUSTMENT     PIC S9(7)V99 COMP-3.
       01  WS-NEW-MONTHLY-ESCROW     PIC S9(7)V99 COMP-3.

      *--- Surplus / Shortage ---*
       01  WS-PROJECTED-YEAR-END     PIC S9(9)V99 COMP-3.
       01  WS-REQUIRED-YEAR-END      PIC S9(9)V99 COMP-3.
       01  WS-SURPLUS-SHORTAGE       PIC S9(9)V99 COMP-3.
       01  WS-ABS-SURPLUS            PIC S9(9)V99 COMP-3.
       01  WS-ONE-SIXTH-ANNUAL       PIC S9(9)V99 COMP-3.
       01  WS-SURPLUS-FLAG           PIC 9.
       01  WS-SHORTAGE-FLAG          PIC 9.

      *--- Cushion Calculation ---*
       01  WS-CUSHION-LIMIT          PIC S9(9)V99 COMP-3.
       01  WS-CUSHION-MONTHS         PIC S9(1) COMP-3.
       01  WS-LOWEST-PROJECTED       PIC S9(9)V99 COMP-3.

      *--- Spread Plan ---*
       01  WS-SPREAD-MONTHS          PIC S9(3) COMP-3.
       01  WS-MONTHLY-SPREAD         PIC S9(7)V99 COMP-3.
       01  WS-EFFECTIVE-MONTH        PIC S9(3) COMP-3.
       01  WS-SPREAD-INDEX           PIC S9(3) COMP-3.

      *--- Display ---*
       01  WS-DISP-AMOUNT            PIC -$$$,$$$,$$9.99.
       01  WS-DISP-MONTHLY           PIC -$$,$$9.99.
       01  WS-DISP-MONTH             PIC Z9.

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PROJECT-MONTHLY-FLOWS
           PERFORM 3000-COMPUTE-NEW-ESCROW
           PERFORM 4000-DETECT-SURPLUS-SHORTAGE
           PERFORM 5000-GENERATE-SPREAD-PLAN
           PERFORM 6000-DISPLAY-ANALYSIS
           STOP RUN.

       1000-INITIALIZE.
           MOVE 3456789012 TO WS-LOAN-NUMBER
           MOVE 285000.00 TO WS-LOAN-BALANCE
           MOVE 1842.50 TO WS-MONTHLY-PAYMENT
           MOVE 3250.00 TO WS-ESCROW-BALANCE
           MOVE 8400.00 TO WS-ANNUAL-TAX
           MOVE 2 TO WS-TAX-FREQUENCY
           COMPUTE WS-TAX-INSTALLMENT =
               WS-ANNUAL-TAX / WS-TAX-FREQUENCY
           COMPUTE WS-MONTHLY-TAX =
               WS-ANNUAL-TAX / 12
           MOVE 2400.00 TO WS-ANNUAL-INSURANCE
           COMPUTE WS-MONTHLY-INSURANCE =
               WS-ANNUAL-INSURANCE / 12
           MOVE 9 TO WS-INSURANCE-DUE-MONTH
           MOVE 450.00 TO WS-CURRENT-MONTHLY
           MOVE 0 TO WS-SURPLUS-FLAG
           MOVE 0 TO WS-SHORTAGE-FLAG
           MOVE 2 TO WS-CUSHION-MONTHS
           MOVE 12 TO WS-SPREAD-MONTHS
           MOVE 4 TO WS-EFFECTIVE-MONTH
           MOVE 999999.99 TO WS-LOWEST-PROJECTED.

       2000-PROJECT-MONTHLY-FLOWS.
           MOVE WS-ESCROW-BALANCE TO WS-PROJECTED-YEAR-END
           PERFORM VARYING WS-MONTH-INDEX FROM 1 BY 1
               UNTIL WS-MONTH-INDEX > 12
               MOVE WS-MONTH-INDEX TO
                   WP-MONTH-NUM(WS-MONTH-INDEX)
               MOVE WS-CURRENT-MONTHLY TO
                   WP-ESCROW-IN(WS-MONTH-INDEX)
               MOVE 0 TO WP-TAX-OUT(WS-MONTH-INDEX)
               MOVE 0 TO WP-INS-OUT(WS-MONTH-INDEX)
               IF WS-MONTH-INDEX = 6
                   MOVE WS-TAX-INSTALLMENT TO
                       WP-TAX-OUT(WS-MONTH-INDEX)
               END-IF
               IF WS-MONTH-INDEX = 12
                   MOVE WS-TAX-INSTALLMENT TO
                       WP-TAX-OUT(WS-MONTH-INDEX)
               END-IF
               IF WS-MONTH-INDEX = WS-INSURANCE-DUE-MONTH
                   MOVE WS-ANNUAL-INSURANCE TO
                       WP-INS-OUT(WS-MONTH-INDEX)
               END-IF
               COMPUTE WP-NET-FLOW(WS-MONTH-INDEX) =
                   WP-ESCROW-IN(WS-MONTH-INDEX)
                   - WP-TAX-OUT(WS-MONTH-INDEX)
                   - WP-INS-OUT(WS-MONTH-INDEX)
               ADD WP-NET-FLOW(WS-MONTH-INDEX) TO
                   WS-PROJECTED-YEAR-END
               MOVE WS-PROJECTED-YEAR-END TO
                   WP-END-BALANCE(WS-MONTH-INDEX)
               IF WS-PROJECTED-YEAR-END <
                   WS-LOWEST-PROJECTED
                   MOVE WS-PROJECTED-YEAR-END TO
                       WS-LOWEST-PROJECTED
               END-IF
           END-PERFORM.

       3000-COMPUTE-NEW-ESCROW.
           COMPUTE WS-TOTAL-ANNUAL-DISB =
               WS-ANNUAL-TAX + WS-ANNUAL-INSURANCE
           COMPUTE WS-REQUIRED-MONTHLY =
               WS-TOTAL-ANNUAL-DISB / 12
           COMPUTE WS-CUSHION-LIMIT =
               WS-REQUIRED-MONTHLY * WS-CUSHION-MONTHS
           MOVE WS-CUSHION-LIMIT TO WS-REQUIRED-YEAR-END.

       4000-DETECT-SURPLUS-SHORTAGE.
           COMPUTE WS-SURPLUS-SHORTAGE =
               WS-PROJECTED-YEAR-END - WS-REQUIRED-YEAR-END
           MOVE WS-SURPLUS-SHORTAGE TO WS-ABS-SURPLUS
           IF WS-ABS-SURPLUS < 0
               MULTIPLY -1 BY WS-ABS-SURPLUS
           END-IF
           COMPUTE WS-ONE-SIXTH-ANNUAL =
               WS-TOTAL-ANNUAL-DISB / 6
           IF WS-SURPLUS-SHORTAGE > 0
               IF WS-ABS-SURPLUS > WS-ONE-SIXTH-ANNUAL
                   MOVE 1 TO WS-SURPLUS-FLAG
               END-IF
           ELSE
               IF WS-SURPLUS-SHORTAGE < 0
                   MOVE 1 TO WS-SHORTAGE-FLAG
               END-IF
           END-IF.

       5000-GENERATE-SPREAD-PLAN.
           IF WS-SHORTAGE-FLAG = 1
               COMPUTE WS-MONTHLY-SPREAD =
                   WS-ABS-SURPLUS / WS-SPREAD-MONTHS
               COMPUTE WS-NEW-MONTHLY-ESCROW =
                   WS-REQUIRED-MONTHLY + WS-MONTHLY-SPREAD
               COMPUTE WS-MONTHLY-ADJUSTMENT =
                   WS-NEW-MONTHLY-ESCROW - WS-CURRENT-MONTHLY
           ELSE
               IF WS-SURPLUS-FLAG = 1
                   COMPUTE WS-MONTHLY-ADJUSTMENT =
                       WS-SURPLUS-SHORTAGE / WS-SPREAD-MONTHS
                   MULTIPLY -1 BY WS-MONTHLY-ADJUSTMENT
                   COMPUTE WS-NEW-MONTHLY-ESCROW =
                       WS-CURRENT-MONTHLY
                       - WS-MONTHLY-ADJUSTMENT
               ELSE
                   MOVE WS-CURRENT-MONTHLY TO
                       WS-NEW-MONTHLY-ESCROW
                   MOVE 0 TO WS-MONTHLY-ADJUSTMENT
               END-IF
           END-IF.

       6000-DISPLAY-ANALYSIS.
           DISPLAY "=== ESCROW ANALYSIS REPORT ==="
           DISPLAY "LOAN NUMBER: " WS-LOAN-NUMBER
           MOVE WS-LOAN-BALANCE TO WS-DISP-AMOUNT
           DISPLAY "LOAN BALANCE:      " WS-DISP-AMOUNT
           MOVE WS-ESCROW-BALANCE TO WS-DISP-AMOUNT
           DISPLAY "ESCROW BALANCE:    " WS-DISP-AMOUNT
           DISPLAY "--- ANNUAL DISBURSEMENTS ---"
           MOVE WS-ANNUAL-TAX TO WS-DISP-AMOUNT
           DISPLAY "PROPERTY TAX:      " WS-DISP-AMOUNT
           MOVE WS-ANNUAL-INSURANCE TO WS-DISP-AMOUNT
           DISPLAY "INSURANCE:         " WS-DISP-AMOUNT
           MOVE WS-TOTAL-ANNUAL-DISB TO WS-DISP-AMOUNT
           DISPLAY "TOTAL ANNUAL:      " WS-DISP-AMOUNT
           DISPLAY "--- PROJECTION ---"
           MOVE WS-PROJECTED-YEAR-END TO WS-DISP-AMOUNT
           DISPLAY "YEAR-END BALANCE:  " WS-DISP-AMOUNT
           MOVE WS-REQUIRED-YEAR-END TO WS-DISP-AMOUNT
           DISPLAY "REQUIRED CUSHION:  " WS-DISP-AMOUNT
           MOVE WS-SURPLUS-SHORTAGE TO WS-DISP-AMOUNT
           DISPLAY "SURPLUS/SHORTAGE:  " WS-DISP-AMOUNT
           DISPLAY "--- ADJUSTMENT ---"
           MOVE WS-CURRENT-MONTHLY TO WS-DISP-MONTHLY
           DISPLAY "CURRENT ESCROW:    " WS-DISP-MONTHLY
           MOVE WS-NEW-MONTHLY-ESCROW TO WS-DISP-MONTHLY
           DISPLAY "NEW ESCROW:        " WS-DISP-MONTHLY
           MOVE WS-MONTHLY-ADJUSTMENT TO WS-DISP-MONTHLY
           DISPLAY "ADJUSTMENT:        " WS-DISP-MONTHLY
           IF WS-SURPLUS-FLAG = 1
               DISPLAY "STATUS: SURPLUS - REFUND DUE"
           ELSE
               IF WS-SHORTAGE-FLAG = 1
                   DISPLAY "STATUS: SHORTAGE - SPREAD PLAN"
                   DISPLAY "SPREAD OVER MONTHS: "
                       WS-SPREAD-MONTHS
               ELSE
                   DISPLAY "STATUS: WITHIN TOLERANCE"
               END-IF
           END-IF
           DISPLAY "=== END ANALYSIS ===".
