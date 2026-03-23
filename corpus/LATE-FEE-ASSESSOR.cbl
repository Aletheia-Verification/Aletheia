       IDENTIFICATION DIVISION.
       PROGRAM-ID. LATE-FEE-ASSESSOR.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01 WS-ACCOUNT-INFO.
          05 WS-ACCOUNT-NUM           PIC X(12).
          05 WS-PRODUCT-TYPE          PIC X(1).
             88 PRODUCT-MORTGAGE      VALUE 'M'.
             88 PRODUCT-AUTO          VALUE 'A'.
             88 PRODUCT-PERSONAL      VALUE 'P'.
             88 PRODUCT-CREDIT-CARD   VALUE 'C'.
          05 WS-OUTSTANDING-BAL       PIC S9(9)V99 COMP-3.
          05 WS-PAYMENT-DUE           PIC S9(7)V99 COMP-3.
          05 WS-PAYMENT-RECEIVED      PIC S9(7)V99 COMP-3.
          05 WS-DAYS-PAST-DUE         PIC 9(4).

       01 WS-WAIVER-FLAGS.
          05 WS-WAIVER-TYPE           PIC X(1).
             88 WAIVER-NONE           VALUE 'N'.
             88 WAIVER-FIRST-TIME     VALUE 'F'.
             88 WAIVER-HARDSHIP       VALUE 'H'.
             88 WAIVER-LOYALTY        VALUE 'L'.
          05 WS-YEARS-AS-CUSTOMER     PIC 9(2).
          05 WS-PREV-LATE-COUNT       PIC 9(2).
          05 WS-HARDSHIP-FLAG         PIC X(1).
             88 HAS-HARDSHIP          VALUE 'Y'.
             88 NO-HARDSHIP           VALUE 'N'.

       01 WS-FEE-CALC.
          05 WS-BASE-FEE-PCT          PIC S9(1)V9(4) COMP-3.
          05 WS-PRODUCT-FACTOR        PIC S9(1)V9(4) COMP-3.
          05 WS-LATE-FEE-AMOUNT       PIC S9(7)V99 COMP-3.
          05 WS-MAX-FEE-CAP           PIC S9(7)V99 COMP-3.
          05 WS-FEE-BEFORE-CAP        PIC S9(7)V99 COMP-3.
          05 WS-WAIVER-DISCOUNT       PIC S9(1)V9(4) COMP-3.
          05 WS-FINAL-FEE             PIC S9(7)V99 COMP-3.

       01 WS-INTEREST-ON-FEES.
          05 WS-UNPAID-FEE-BAL        PIC S9(7)V99 COMP-3.
          05 WS-FEE-INT-RATE          PIC S9(1)V9(6) COMP-3.
          05 WS-FEE-INT-AMOUNT        PIC S9(7)V99 COMP-3.
          05 WS-FEE-INT-DAYS          PIC 9(3).
          05 WS-DAILY-FEE-RATE        PIC S9(1)V9(8) COMP-3.

       01 WS-TOTALS.
          05 WS-TOTAL-ASSESSED        PIC S9(9)V99 COMP-3.
          05 WS-TOTAL-WAIVED          PIC S9(9)V99 COMP-3.
          05 WS-TOTAL-INTEREST        PIC S9(9)V99 COMP-3.
          05 WS-NET-FEE-AMOUNT        PIC S9(9)V99 COMP-3.

       01 WS-WORK-FIELDS.
          05 WS-TEMP-AMT              PIC S9(9)V99 COMP-3.
          05 WS-SHORTFALL             PIC S9(7)V99 COMP-3.
          05 WS-DPD-BUCKET            PIC 9(1).
          05 WS-WAIVER-ELIGIBLE       PIC X(1).
             88 IS-WAIVER-ELIGIBLE    VALUE 'Y'.
             88 NOT-WAIVER-ELIGIBLE   VALUE 'N'.

       PROCEDURE DIVISION.

       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-DETERMINE-DPD-BUCKET
           PERFORM 3000-CALC-BASE-FEE THRU 3900-CALC-EXIT
           PERFORM 4000-CHECK-WAIVER-ELIGIBILITY
           PERFORM 5000-APPLY-WAIVER
           PERFORM 6000-ENFORCE-FEE-CAP
           PERFORM 7000-CALC-FEE-INTEREST
           PERFORM 8000-FINALIZE-TOTALS
           STOP RUN.

       1000-INITIALIZE.
           INITIALIZE WS-FEE-CALC
           INITIALIZE WS-INTEREST-ON-FEES
           INITIALIZE WS-TOTALS
           INITIALIZE WS-WORK-FIELDS
           MOVE 0.18 TO WS-FEE-INT-RATE
           COMPUTE WS-SHORTFALL =
              WS-PAYMENT-DUE - WS-PAYMENT-RECEIVED
           IF WS-SHORTFALL < 0
              MOVE 0 TO WS-SHORTFALL
           END-IF.

       2000-DETERMINE-DPD-BUCKET.
           EVALUATE TRUE
              WHEN WS-DAYS-PAST-DUE < 30
                 MOVE 0 TO WS-DPD-BUCKET
                 MOVE 0 TO WS-BASE-FEE-PCT
              WHEN WS-DAYS-PAST-DUE < 60
                 MOVE 1 TO WS-DPD-BUCKET
                 MOVE 0.02 TO WS-BASE-FEE-PCT
              WHEN WS-DAYS-PAST-DUE < 90
                 MOVE 2 TO WS-DPD-BUCKET
                 MOVE 0.04 TO WS-BASE-FEE-PCT
              WHEN WS-DAYS-PAST-DUE < 120
                 MOVE 3 TO WS-DPD-BUCKET
                 MOVE 0.06 TO WS-BASE-FEE-PCT
              WHEN OTHER
                 MOVE 4 TO WS-DPD-BUCKET
                 MOVE 0.08 TO WS-BASE-FEE-PCT
           END-EVALUATE.

       3000-CALC-BASE-FEE.
           IF WS-DPD-BUCKET = 0
              MOVE 0 TO WS-LATE-FEE-AMOUNT
              MOVE 0 TO WS-PRODUCT-FACTOR
              GO TO 3900-CALC-EXIT
           END-IF
           EVALUATE TRUE
              WHEN PRODUCT-MORTGAGE
                 IF WS-DPD-BUCKET > 2
                    MOVE 1.5 TO WS-PRODUCT-FACTOR
                 ELSE
                    MOVE 1.2 TO WS-PRODUCT-FACTOR
                 END-IF
                 COMPUTE WS-MAX-FEE-CAP =
                    WS-PAYMENT-DUE * 0.10
              WHEN PRODUCT-AUTO
                 IF WS-DPD-BUCKET > 2
                    MOVE 1.3 TO WS-PRODUCT-FACTOR
                 ELSE
                    MOVE 1.0 TO WS-PRODUCT-FACTOR
                 END-IF
                 COMPUTE WS-MAX-FEE-CAP =
                    WS-PAYMENT-DUE * 0.08
              WHEN PRODUCT-PERSONAL
                 IF WS-DPD-BUCKET > 2
                    MOVE 1.8 TO WS-PRODUCT-FACTOR
                 ELSE
                    MOVE 1.4 TO WS-PRODUCT-FACTOR
                 END-IF
                 COMPUTE WS-MAX-FEE-CAP =
                    WS-PAYMENT-DUE * 0.15
              WHEN PRODUCT-CREDIT-CARD
                 IF WS-DPD-BUCKET > 2
                    MOVE 2.0 TO WS-PRODUCT-FACTOR
                 ELSE
                    MOVE 1.6 TO WS-PRODUCT-FACTOR
                 END-IF
                 COMPUTE WS-MAX-FEE-CAP =
                    WS-PAYMENT-DUE * 0.12
              WHEN OTHER
                 MOVE 1.0 TO WS-PRODUCT-FACTOR
                 COMPUTE WS-MAX-FEE-CAP =
                    WS-PAYMENT-DUE * 0.05
           END-EVALUATE
           COMPUTE WS-LATE-FEE-AMOUNT =
              WS-SHORTFALL * WS-BASE-FEE-PCT *
              WS-PRODUCT-FACTOR
           MOVE WS-LATE-FEE-AMOUNT TO WS-FEE-BEFORE-CAP.

       3900-CALC-EXIT.
           DISPLAY "BASE FEE CALCULATED".

       4000-CHECK-WAIVER-ELIGIBILITY.
           SET NOT-WAIVER-ELIGIBLE TO TRUE
           IF WAIVER-FIRST-TIME
              IF WS-PREV-LATE-COUNT = 0
                 SET IS-WAIVER-ELIGIBLE TO TRUE
              END-IF
           END-IF
           IF WAIVER-HARDSHIP
              IF HAS-HARDSHIP
                 SET IS-WAIVER-ELIGIBLE TO TRUE
              END-IF
           END-IF
           IF WAIVER-LOYALTY
              IF WS-YEARS-AS-CUSTOMER > 10
                 SET IS-WAIVER-ELIGIBLE TO TRUE
              END-IF
           END-IF.

       5000-APPLY-WAIVER.
           IF IS-WAIVER-ELIGIBLE
              EVALUATE TRUE
                 WHEN WAIVER-FIRST-TIME
                    MOVE 1.0 TO WS-WAIVER-DISCOUNT
                 WHEN WAIVER-HARDSHIP
                    MOVE 0.75 TO WS-WAIVER-DISCOUNT
                 WHEN WAIVER-LOYALTY
                    MOVE 0.25 TO WS-WAIVER-DISCOUNT
                 WHEN OTHER
                    MOVE 0 TO WS-WAIVER-DISCOUNT
              END-EVALUATE
              IF WAIVER-LOYALTY
                 IF WS-YEARS-AS-CUSTOMER > 20
                    MOVE 0.50 TO WS-WAIVER-DISCOUNT
                 END-IF
              END-IF
              COMPUTE WS-TEMP-AMT =
                 WS-LATE-FEE-AMOUNT * WS-WAIVER-DISCOUNT
              SUBTRACT WS-TEMP-AMT FROM WS-LATE-FEE-AMOUNT
              ADD WS-TEMP-AMT TO WS-TOTAL-WAIVED
           END-IF.

       6000-ENFORCE-FEE-CAP.
           IF WS-LATE-FEE-AMOUNT > WS-MAX-FEE-CAP
              MOVE WS-MAX-FEE-CAP TO WS-LATE-FEE-AMOUNT
           END-IF
           IF WS-LATE-FEE-AMOUNT < 0
              MOVE 0 TO WS-LATE-FEE-AMOUNT
           END-IF
           MOVE WS-LATE-FEE-AMOUNT TO WS-FINAL-FEE.

       7000-CALC-FEE-INTEREST.
           IF WS-UNPAID-FEE-BAL > 0
              COMPUTE WS-DAILY-FEE-RATE =
                 WS-FEE-INT-RATE / 365
              COMPUTE WS-FEE-INT-AMOUNT =
                 WS-UNPAID-FEE-BAL * WS-DAILY-FEE-RATE *
                 WS-FEE-INT-DAYS
              ADD WS-FEE-INT-AMOUNT TO WS-TOTAL-INTEREST
           ELSE
              MOVE 0 TO WS-FEE-INT-AMOUNT
           END-IF.

       8000-FINALIZE-TOTALS.
           ADD WS-FINAL-FEE TO WS-TOTAL-ASSESSED
           COMPUTE WS-NET-FEE-AMOUNT =
              WS-TOTAL-ASSESSED + WS-TOTAL-INTEREST
              - WS-TOTAL-WAIVED
           DISPLAY "ACCOUNT: " WS-ACCOUNT-NUM
           DISPLAY "DPD BUCKET: " WS-DPD-BUCKET
           DISPLAY "BASE FEE: " WS-FEE-BEFORE-CAP
           DISPLAY "FINAL FEE: " WS-FINAL-FEE
           DISPLAY "NET AMOUNT: " WS-NET-FEE-AMOUNT.
