       IDENTIFICATION DIVISION.
       PROGRAM-ID. INS-DEDUCTIBLE-CALC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CLAIM-DATA.
           05 WS-CLAIM-ID         PIC X(12).
           05 WS-POLICY-NUM       PIC X(12).
           05 WS-CLAIM-DATE       PIC 9(8).
           05 WS-CLAIM-AMT        PIC S9(9)V99 COMP-3.
           05 WS-CLAIM-TYPE       PIC X(2).
               88 CLM-MEDICAL     VALUE 'MD'.
               88 CLM-DENTAL      VALUE 'DN'.
               88 CLM-VISION      VALUE 'VS'.
               88 CLM-PHARMACY    VALUE 'RX'.
       01 WS-POLICY-TERMS.
           05 WS-ANNUAL-DEDUCT    PIC S9(7)V99 COMP-3.
           05 WS-YTD-DEDUCT-MET   PIC S9(7)V99 COMP-3.
           05 WS-COPAY-PCT        PIC S9(1)V99 COMP-3.
           05 WS-MAX-OOP          PIC S9(7)V99 COMP-3.
           05 WS-YTD-OOP          PIC S9(7)V99 COMP-3.
           05 WS-IN-NETWORK       PIC X VALUE 'Y'.
               88 IS-IN-NETWORK   VALUE 'Y'.
       01 WS-CALC-RESULTS.
           05 WS-DEDUCT-APPLIED   PIC S9(7)V99 COMP-3.
           05 WS-COPAY-AMOUNT     PIC S9(7)V99 COMP-3.
           05 WS-PLAN-PAYS        PIC S9(7)V99 COMP-3.
           05 WS-PATIENT-PAYS     PIC S9(7)V99 COMP-3.
           05 WS-REMAINING-BAL    PIC S9(7)V99 COMP-3.
       01 WS-DEDUCT-REMAINING     PIC S9(7)V99 COMP-3.
       01 WS-OOP-REMAINING        PIC S9(7)V99 COMP-3.
       01 WS-ELIGIBLE-AMT         PIC S9(9)V99 COMP-3.
       01 WS-NETWORK-FACTOR       PIC S9(1)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-CALC-ELIGIBLE
           PERFORM 3000-APPLY-DEDUCTIBLE
           PERFORM 4000-APPLY-COPAY
           PERFORM 5000-CHECK-OOP-MAX
           PERFORM 6000-OUTPUT
           STOP RUN.
       1000-INIT.
           MOVE 0 TO WS-DEDUCT-APPLIED
           MOVE 0 TO WS-COPAY-AMOUNT
           MOVE 0 TO WS-PLAN-PAYS
           MOVE 0 TO WS-PATIENT-PAYS
           COMPUTE WS-DEDUCT-REMAINING =
               WS-ANNUAL-DEDUCT - WS-YTD-DEDUCT-MET
           COMPUTE WS-OOP-REMAINING =
               WS-MAX-OOP - WS-YTD-OOP.
       2000-CALC-ELIGIBLE.
           IF IS-IN-NETWORK
               MOVE 1.00 TO WS-NETWORK-FACTOR
           ELSE
               MOVE 0.70 TO WS-NETWORK-FACTOR
           END-IF
           EVALUATE TRUE
               WHEN CLM-MEDICAL
                   COMPUTE WS-ELIGIBLE-AMT =
                       WS-CLAIM-AMT * WS-NETWORK-FACTOR
               WHEN CLM-DENTAL
                   COMPUTE WS-ELIGIBLE-AMT =
                       WS-CLAIM-AMT * WS-NETWORK-FACTOR
                   IF WS-ELIGIBLE-AMT > 2000.00
                       MOVE 2000.00 TO WS-ELIGIBLE-AMT
                   END-IF
               WHEN CLM-VISION
                   COMPUTE WS-ELIGIBLE-AMT =
                       WS-CLAIM-AMT * WS-NETWORK-FACTOR
                   IF WS-ELIGIBLE-AMT > 500.00
                       MOVE 500.00 TO WS-ELIGIBLE-AMT
                   END-IF
               WHEN CLM-PHARMACY
                   MOVE WS-CLAIM-AMT TO WS-ELIGIBLE-AMT
               WHEN OTHER
                   MOVE 0 TO WS-ELIGIBLE-AMT
           END-EVALUATE.
       3000-APPLY-DEDUCTIBLE.
           IF WS-DEDUCT-REMAINING > 0
               IF WS-ELIGIBLE-AMT <= WS-DEDUCT-REMAINING
                   MOVE WS-ELIGIBLE-AMT TO WS-DEDUCT-APPLIED
                   MOVE 0 TO WS-REMAINING-BAL
               ELSE
                   MOVE WS-DEDUCT-REMAINING
                       TO WS-DEDUCT-APPLIED
                   COMPUTE WS-REMAINING-BAL =
                       WS-ELIGIBLE-AMT - WS-DEDUCT-REMAINING
               END-IF
           ELSE
               MOVE 0 TO WS-DEDUCT-APPLIED
               MOVE WS-ELIGIBLE-AMT TO WS-REMAINING-BAL
           END-IF.
       4000-APPLY-COPAY.
           IF WS-REMAINING-BAL > 0
               COMPUTE WS-COPAY-AMOUNT =
                   WS-REMAINING-BAL * WS-COPAY-PCT
               COMPUTE WS-PLAN-PAYS =
                   WS-REMAINING-BAL - WS-COPAY-AMOUNT
           ELSE
               MOVE 0 TO WS-COPAY-AMOUNT
               MOVE 0 TO WS-PLAN-PAYS
           END-IF
           COMPUTE WS-PATIENT-PAYS =
               WS-DEDUCT-APPLIED + WS-COPAY-AMOUNT.
       5000-CHECK-OOP-MAX.
           IF WS-PATIENT-PAYS > WS-OOP-REMAINING
               COMPUTE WS-PLAN-PAYS =
                   WS-PLAN-PAYS +
                   (WS-PATIENT-PAYS - WS-OOP-REMAINING)
               MOVE WS-OOP-REMAINING TO WS-PATIENT-PAYS
           END-IF.
       6000-OUTPUT.
           DISPLAY 'INSURANCE CLAIM CALCULATION'
           DISPLAY '==========================='
           DISPLAY 'CLAIM:      ' WS-CLAIM-ID
           DISPLAY 'POLICY:     ' WS-POLICY-NUM
           DISPLAY 'TYPE:       ' WS-CLAIM-TYPE
           DISPLAY 'CLAIMED:    $' WS-CLAIM-AMT
           DISPLAY 'ELIGIBLE:   $' WS-ELIGIBLE-AMT
           DISPLAY 'DEDUCTIBLE: $' WS-DEDUCT-APPLIED
           DISPLAY 'COPAY:      $' WS-COPAY-AMOUNT
           DISPLAY 'PLAN PAYS:  $' WS-PLAN-PAYS
           DISPLAY 'YOU PAY:    $' WS-PATIENT-PAYS.
