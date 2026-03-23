       IDENTIFICATION DIVISION.
       PROGRAM-ID. INS-PREM-TIERED.
      *================================================================*
      * INSURANCE PREMIUM CALCULATOR - TIERED RATING                   *
      * Multi-factor premium with age bands, coverage tiers, rider     *
      * add-ons, loyalty discounts, and claims surcharges.             *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-POLICY-DATA.
           05 WS-POLICY-NUM         PIC X(10).
           05 WS-INSURED-AGE        PIC S9(3) COMP-3.
           05 WS-GENDER             PIC X.
               88 WS-MALE           VALUE 'M'.
               88 WS-FEMALE         VALUE 'F'.
           05 WS-SMOKER-FLAG        PIC X.
               88 WS-SMOKER         VALUE 'Y'.
               88 WS-NON-SMOKER     VALUE 'N'.
           05 WS-COVERAGE-AMT       PIC S9(9)V99 COMP-3.
           05 WS-POLICY-TERM        PIC S9(2) COMP-3.
           05 WS-POLICY-TYPE        PIC X(2).
               88 WS-TERM-LIFE      VALUE 'TL'.
               88 WS-WHOLE-LIFE     VALUE 'WL'.
               88 WS-UNIVERSAL      VALUE 'UL'.
           05 WS-YEARS-INSURED      PIC S9(2) COMP-3.
           05 WS-CLAIMS-3YR         PIC S9(2) COMP-3.
       01 WS-RIDERS.
           05 WS-RIDER-AD-D         PIC X VALUE 'N'.
               88 WS-HAS-ADD        VALUE 'Y'.
           05 WS-RIDER-WAIVER       PIC X VALUE 'N'.
               88 WS-HAS-WAIVER     VALUE 'Y'.
           05 WS-RIDER-CHILD        PIC X VALUE 'N'.
               88 WS-HAS-CHILD      VALUE 'Y'.
           05 WS-RIDER-ACCEL        PIC X VALUE 'N'.
               88 WS-HAS-ACCEL      VALUE 'Y'.
       01 WS-RATE-FACTORS.
           05 WS-BASE-RATE          PIC S9(3)V9(4) COMP-3.
           05 WS-AGE-FACTOR         PIC S9(1)V9(4) COMP-3.
           05 WS-SMOKER-FACTOR      PIC S9(1)V9(4) COMP-3.
           05 WS-GENDER-FACTOR      PIC S9(1)V9(4) COMP-3.
           05 WS-TYPE-FACTOR        PIC S9(1)V9(4) COMP-3.
           05 WS-LOYALTY-DISC       PIC S9(1)V9(4) COMP-3.
           05 WS-CLAIMS-SURCHG      PIC S9(1)V9(4) COMP-3.
       01 WS-PREMIUM-CALC.
           05 WS-BASE-PREMIUM       PIC S9(7)V99 COMP-3.
           05 WS-RIDER-PREMIUM      PIC S9(5)V99 COMP-3.
           05 WS-SUBTOTAL           PIC S9(7)V99 COMP-3.
           05 WS-DISC-AMOUNT        PIC S9(5)V99 COMP-3.
           05 WS-SURCHG-AMOUNT      PIC S9(5)V99 COMP-3.
           05 WS-ANNUAL-PREMIUM     PIC S9(7)V99 COMP-3.
           05 WS-MONTHLY-PREMIUM    PIC S9(5)V99 COMP-3.
           05 WS-QUARTERLY-PREM     PIC S9(7)V99 COMP-3.
       01 WS-COVERAGE-UNITS         PIC S9(5) COMP-3.
       01 WS-IDX                    PIC S9(2) COMP-3.
       01 WS-RATE-CLASS             PIC X(15).
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-DETERMINE-BASE-RATE
               THRU 2900-APPLY-TYPE-FACTOR
           PERFORM 3000-CALC-BASE-PREMIUM
           PERFORM 4000-CALC-RIDERS
           PERFORM 5000-APPLY-DISCOUNTS
               THRU 5500-APPLY-SURCHARGES
           PERFORM 6000-CALC-FINAL-PREMIUM
           PERFORM 7000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'POL0045821' TO WS-POLICY-NUM
           MOVE 45 TO WS-INSURED-AGE
           MOVE 'M' TO WS-GENDER
           MOVE 'N' TO WS-SMOKER-FLAG
           MOVE 500000.00 TO WS-COVERAGE-AMT
           MOVE 20 TO WS-POLICY-TERM
           MOVE 'TL' TO WS-POLICY-TYPE
           MOVE 8 TO WS-YEARS-INSURED
           MOVE 1 TO WS-CLAIMS-3YR
           MOVE 'Y' TO WS-RIDER-AD-D
           MOVE 'Y' TO WS-RIDER-WAIVER
           MOVE 'N' TO WS-RIDER-CHILD
           MOVE 'N' TO WS-RIDER-ACCEL
           MOVE 0 TO WS-BASE-PREMIUM
           MOVE 0 TO WS-RIDER-PREMIUM
           MOVE 0 TO WS-DISC-AMOUNT
           MOVE 0 TO WS-SURCHG-AMOUNT.
       2000-DETERMINE-BASE-RATE.
           EVALUATE TRUE
               WHEN WS-INSURED-AGE < 25
                   MOVE 0.85 TO WS-BASE-RATE
                   MOVE 'PREFERRED YOUTH' TO WS-RATE-CLASS
               WHEN WS-INSURED-AGE < 35
                   MOVE 1.20 TO WS-BASE-RATE
                   MOVE 'STANDARD YOUNG' TO WS-RATE-CLASS
               WHEN WS-INSURED-AGE < 45
                   MOVE 2.50 TO WS-BASE-RATE
                   MOVE 'STANDARD MID' TO WS-RATE-CLASS
               WHEN WS-INSURED-AGE < 55
                   MOVE 4.80 TO WS-BASE-RATE
                   MOVE 'STANDARD MATURE' TO WS-RATE-CLASS
               WHEN WS-INSURED-AGE < 65
                   MOVE 8.50 TO WS-BASE-RATE
                   MOVE 'SENIOR' TO WS-RATE-CLASS
               WHEN OTHER
                   MOVE 15.00 TO WS-BASE-RATE
                   MOVE 'ELDERLY' TO WS-RATE-CLASS
           END-EVALUATE.
       2500-APPLY-SMOKER-GENDER.
           IF WS-SMOKER
               MOVE 1.75 TO WS-SMOKER-FACTOR
           ELSE
               MOVE 1.00 TO WS-SMOKER-FACTOR
           END-IF
           IF WS-MALE
               MOVE 1.08 TO WS-GENDER-FACTOR
           ELSE
               MOVE 1.00 TO WS-GENDER-FACTOR
           END-IF.
       2900-APPLY-TYPE-FACTOR.
           EVALUATE TRUE
               WHEN WS-TERM-LIFE
                   MOVE 1.00 TO WS-TYPE-FACTOR
               WHEN WS-WHOLE-LIFE
                   MOVE 3.50 TO WS-TYPE-FACTOR
               WHEN WS-UNIVERSAL
                   MOVE 2.80 TO WS-TYPE-FACTOR
               WHEN OTHER
                   MOVE 1.00 TO WS-TYPE-FACTOR
           END-EVALUATE.
       3000-CALC-BASE-PREMIUM.
           COMPUTE WS-COVERAGE-UNITS =
               WS-COVERAGE-AMT / 1000
           COMPUTE WS-BASE-PREMIUM ROUNDED =
               WS-COVERAGE-UNITS * WS-BASE-RATE *
               WS-SMOKER-FACTOR * WS-GENDER-FACTOR *
               WS-TYPE-FACTOR.
       4000-CALC-RIDERS.
           MOVE 0 TO WS-RIDER-PREMIUM
           IF WS-HAS-ADD
               COMPUTE WS-RIDER-PREMIUM =
                   WS-RIDER-PREMIUM +
                   (WS-COVERAGE-UNITS * 0.15)
           END-IF
           IF WS-HAS-WAIVER
               COMPUTE WS-RIDER-PREMIUM =
                   WS-RIDER-PREMIUM +
                   (WS-BASE-PREMIUM * 0.05)
           END-IF
           IF WS-HAS-CHILD
               ADD 120.00 TO WS-RIDER-PREMIUM
           END-IF
           IF WS-HAS-ACCEL
               COMPUTE WS-RIDER-PREMIUM =
                   WS-RIDER-PREMIUM +
                   (WS-BASE-PREMIUM * 0.02)
           END-IF.
       5000-APPLY-DISCOUNTS.
           MOVE 0 TO WS-LOYALTY-DISC
           EVALUATE TRUE
               WHEN WS-YEARS-INSURED >= 10
                   MOVE 0.10 TO WS-LOYALTY-DISC
               WHEN WS-YEARS-INSURED >= 5
                   MOVE 0.05 TO WS-LOYALTY-DISC
               WHEN WS-YEARS-INSURED >= 3
                   MOVE 0.02 TO WS-LOYALTY-DISC
               WHEN OTHER
                   MOVE 0 TO WS-LOYALTY-DISC
           END-EVALUATE
           COMPUTE WS-SUBTOTAL =
               WS-BASE-PREMIUM + WS-RIDER-PREMIUM
           COMPUTE WS-DISC-AMOUNT ROUNDED =
               WS-SUBTOTAL * WS-LOYALTY-DISC.
       5500-APPLY-SURCHARGES.
           MOVE 0 TO WS-CLAIMS-SURCHG
           IF WS-CLAIMS-3YR > 2
               MOVE 0.25 TO WS-CLAIMS-SURCHG
           ELSE
               IF WS-CLAIMS-3YR > 0
                   MOVE 0.10 TO WS-CLAIMS-SURCHG
               END-IF
           END-IF
           COMPUTE WS-SURCHG-AMOUNT ROUNDED =
               WS-SUBTOTAL * WS-CLAIMS-SURCHG.
       6000-CALC-FINAL-PREMIUM.
           COMPUTE WS-ANNUAL-PREMIUM ROUNDED =
               WS-SUBTOTAL - WS-DISC-AMOUNT +
               WS-SURCHG-AMOUNT
           COMPUTE WS-MONTHLY-PREMIUM ROUNDED =
               WS-ANNUAL-PREMIUM / 12
           COMPUTE WS-QUARTERLY-PREM ROUNDED =
               WS-ANNUAL-PREMIUM / 4
           IF WS-ANNUAL-PREMIUM < 0
               MOVE 0 TO WS-ANNUAL-PREMIUM
               MOVE 0 TO WS-MONTHLY-PREMIUM
               MOVE 0 TO WS-QUARTERLY-PREM
           END-IF.
       7000-DISPLAY-RESULTS.
           DISPLAY '======================================='
           DISPLAY 'INSURANCE PREMIUM CALCULATION'
           DISPLAY '======================================='
           DISPLAY 'POLICY:          ' WS-POLICY-NUM
           DISPLAY 'AGE:             ' WS-INSURED-AGE
           DISPLAY 'RATE CLASS:      ' WS-RATE-CLASS
           DISPLAY 'COVERAGE:        ' WS-COVERAGE-AMT
           DISPLAY 'BASE RATE:       ' WS-BASE-RATE
           DISPLAY 'BASE PREMIUM:    ' WS-BASE-PREMIUM
           DISPLAY 'RIDER PREMIUM:   ' WS-RIDER-PREMIUM
           DISPLAY 'DISCOUNT:        ' WS-DISC-AMOUNT
           DISPLAY 'SURCHARGE:       ' WS-SURCHG-AMOUNT
           DISPLAY 'ANNUAL PREMIUM:  ' WS-ANNUAL-PREMIUM
           DISPLAY 'MONTHLY PREMIUM: ' WS-MONTHLY-PREMIUM
           DISPLAY 'QUARTERLY:       ' WS-QUARTERLY-PREM
           DISPLAY '======================================='.
