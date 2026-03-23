       IDENTIFICATION DIVISION.
       PROGRAM-ID. EVAL-ALSO-RATE-MATRIX.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01 WS-PRODUCT-INFO.
          05 WS-PRODUCT-CODE          PIC X(1).
             88 PROD-MORTGAGE         VALUE 'M'.
             88 PROD-AUTO             VALUE 'A'.
             88 PROD-PERSONAL         VALUE 'P'.
             88 PROD-HELOC            VALUE 'H'.
          05 WS-PRODUCT-NAME          PIC X(10).
          05 WS-LOAN-AMOUNT           PIC S9(9)V99 COMP-3.
          05 WS-LOAN-TERM-MONTHS      PIC 9(3).

       01 WS-CREDIT-INFO.
          05 WS-CREDIT-SCORE          PIC 9(3).
          05 WS-CREDIT-TIER           PIC X(1).
             88 TIER-PRIME            VALUE 'P'.
             88 TIER-GOOD             VALUE 'G'.
             88 TIER-FAIR             VALUE 'F'.
             88 TIER-POOR             VALUE 'R'.
          05 WS-TIER-NAME             PIC X(8).

       01 WS-RATE-FIELDS.
          05 WS-BASE-RATE             PIC S9(3)V9(6) COMP-3.
          05 WS-SPREAD-ADJ            PIC S9(1)V9(6) COMP-3.
          05 WS-FLOOR-RATE            PIC S9(3)V9(6) COMP-3.
          05 WS-CEILING-RATE          PIC S9(3)V9(6) COMP-3.
          05 WS-EFFECTIVE-RATE        PIC S9(3)V9(6) COMP-3.
          05 WS-MARGIN                PIC S9(1)V9(6) COMP-3.

       01 WS-CALC-FIELDS.
          05 WS-MONTHLY-RATE          PIC S9(1)V9(8) COMP-3.
          05 WS-MONTHLY-PAYMENT       PIC S9(7)V99 COMP-3.
          05 WS-TOTAL-INTEREST        PIC S9(11)V99 COMP-3.
          05 WS-TOTAL-COST            PIC S9(11)V99 COMP-3.
          05 WS-TEMP-RATE             PIC S9(3)V9(6) COMP-3.

       01 WS-ADJUSTMENT-FIELDS.
          05 WS-LTV-RATIO             PIC S9(1)V9(4) COMP-3.
          05 WS-LTV-SURCHARGE         PIC S9(1)V9(4) COMP-3.
          05 WS-TERM-ADJ              PIC S9(1)V9(4) COMP-3.
          05 WS-AMOUNT-ADJ            PIC S9(1)V9(4) COMP-3.

       01 WS-OUTPUT-SUMMARY.
          05 WS-RATE-APPROVED         PIC X(1).
             88 RATE-APPROVED         VALUE 'Y'.
             88 RATE-DECLINED         VALUE 'N'.
          05 WS-DECLINE-REASON        PIC X(30).

       PROCEDURE DIVISION.

       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-DETERMINE-CREDIT-TIER
           PERFORM 3000-LOOKUP-BASE-RATE
           PERFORM 4000-APPLY-ADJUSTMENTS
           PERFORM 5000-ENFORCE-RATE-BOUNDS
           PERFORM 6000-COMPUTE-PAYMENT
           PERFORM 7000-DISPLAY-RESULTS
           STOP RUN.

       1000-INITIALIZE.
           INITIALIZE WS-RATE-FIELDS
           INITIALIZE WS-CALC-FIELDS
           INITIALIZE WS-ADJUSTMENT-FIELDS
           SET RATE-APPROVED TO TRUE
           MOVE 2.50 TO WS-FLOOR-RATE
           MOVE 18.00 TO WS-CEILING-RATE
           MOVE 1.50 TO WS-MARGIN.

       2000-DETERMINE-CREDIT-TIER.
           EVALUATE TRUE
              WHEN WS-CREDIT-SCORE > 749
                 SET TIER-PRIME TO TRUE
                 MOVE "PRIME" TO WS-TIER-NAME
              WHEN WS-CREDIT-SCORE > 669
                 SET TIER-GOOD TO TRUE
                 MOVE "GOOD" TO WS-TIER-NAME
              WHEN WS-CREDIT-SCORE > 579
                 SET TIER-FAIR TO TRUE
                 MOVE "FAIR" TO WS-TIER-NAME
              WHEN OTHER
                 SET TIER-POOR TO TRUE
                 MOVE "POOR" TO WS-TIER-NAME
           END-EVALUATE.

       3000-LOOKUP-BASE-RATE.
           EVALUATE WS-PRODUCT-CODE ALSO WS-CREDIT-TIER
              WHEN 'M' ALSO 'P'
                 MOVE 3.25 TO WS-BASE-RATE
              WHEN 'M' ALSO 'G'
                 MOVE 3.75 TO WS-BASE-RATE
              WHEN 'M' ALSO 'F'
                 MOVE 4.50 TO WS-BASE-RATE
              WHEN 'M' ALSO 'R'
                 MOVE 5.75 TO WS-BASE-RATE
              WHEN 'A' ALSO 'P'
                 MOVE 4.50 TO WS-BASE-RATE
              WHEN 'A' ALSO 'G'
                 MOVE 5.25 TO WS-BASE-RATE
              WHEN 'A' ALSO 'F'
                 MOVE 6.50 TO WS-BASE-RATE
              WHEN 'A' ALSO 'R'
                 MOVE 8.25 TO WS-BASE-RATE
              WHEN 'P' ALSO 'P'
                 MOVE 6.75 TO WS-BASE-RATE
              WHEN 'P' ALSO 'G'
                 MOVE 8.25 TO WS-BASE-RATE
              WHEN 'P' ALSO 'F'
                 MOVE 10.50 TO WS-BASE-RATE
              WHEN 'P' ALSO 'R'
                 MOVE 14.25 TO WS-BASE-RATE
              WHEN 'H' ALSO 'P'
                 MOVE 4.00 TO WS-BASE-RATE
              WHEN 'H' ALSO 'G'
                 MOVE 4.75 TO WS-BASE-RATE
              WHEN 'H' ALSO 'F'
                 MOVE 5.75 TO WS-BASE-RATE
              WHEN 'H' ALSO 'R'
                 MOVE 7.25 TO WS-BASE-RATE
              WHEN OTHER
                 MOVE 10.00 TO WS-BASE-RATE
           END-EVALUATE.

       4000-APPLY-ADJUSTMENTS.
           IF WS-LOAN-TERM-MONTHS > 360
              MOVE 0.25 TO WS-TERM-ADJ
           ELSE
              IF WS-LOAN-TERM-MONTHS > 180
                 MOVE 0.125 TO WS-TERM-ADJ
              ELSE
                 MOVE 0 TO WS-TERM-ADJ
              END-IF
           END-IF
           IF WS-LOAN-AMOUNT > 500000
              MOVE 0.125 TO WS-AMOUNT-ADJ
           ELSE
              IF WS-LOAN-AMOUNT > 250000
                 MOVE 0.0625 TO WS-AMOUNT-ADJ
              ELSE
                 MOVE 0 TO WS-AMOUNT-ADJ
              END-IF
           END-IF
           IF WS-LTV-RATIO > 0.80
              COMPUTE WS-LTV-SURCHARGE =
                 (WS-LTV-RATIO - 0.80) * 2.0
           ELSE
              MOVE 0 TO WS-LTV-SURCHARGE
           END-IF
           COMPUTE WS-SPREAD-ADJ =
              WS-TERM-ADJ + WS-AMOUNT-ADJ +
              WS-LTV-SURCHARGE
           COMPUTE WS-EFFECTIVE-RATE =
              WS-BASE-RATE + WS-SPREAD-ADJ +
              WS-MARGIN.

       5000-ENFORCE-RATE-BOUNDS.
           IF WS-EFFECTIVE-RATE < WS-FLOOR-RATE
              MOVE WS-FLOOR-RATE TO WS-EFFECTIVE-RATE
           END-IF
           IF WS-EFFECTIVE-RATE > WS-CEILING-RATE
              MOVE WS-CEILING-RATE TO WS-EFFECTIVE-RATE
           END-IF
           IF TIER-POOR
              IF PROD-MORTGAGE
                 IF WS-LOAN-AMOUNT > 400000
                    SET RATE-DECLINED TO TRUE
                    MOVE "POOR CREDIT HIGH MORTGAGE"
                       TO WS-DECLINE-REASON
                 END-IF
              END-IF
           END-IF.

       6000-COMPUTE-PAYMENT.
           IF RATE-APPROVED
              COMPUTE WS-MONTHLY-RATE =
                 WS-EFFECTIVE-RATE / 100 / 12
              COMPUTE WS-MONTHLY-PAYMENT =
                 WS-LOAN-AMOUNT * WS-MONTHLY-RATE
              COMPUTE WS-TOTAL-COST =
                 WS-MONTHLY-PAYMENT * WS-LOAN-TERM-MONTHS
              COMPUTE WS-TOTAL-INTEREST =
                 WS-TOTAL-COST - WS-LOAN-AMOUNT
           ELSE
              MOVE 0 TO WS-MONTHLY-PAYMENT
              MOVE 0 TO WS-TOTAL-INTEREST
              MOVE 0 TO WS-TOTAL-COST
           END-IF.

       7000-DISPLAY-RESULTS.
           DISPLAY "PRODUCT: " WS-PRODUCT-CODE
           DISPLAY "CREDIT TIER: " WS-TIER-NAME
           DISPLAY "BASE RATE: " WS-BASE-RATE
           DISPLAY "SPREAD ADJ: " WS-SPREAD-ADJ
           DISPLAY "EFFECTIVE RATE: " WS-EFFECTIVE-RATE
           DISPLAY "MONTHLY PAYMENT: " WS-MONTHLY-PAYMENT
           IF RATE-DECLINED
              DISPLAY "STATUS: DECLINED"
              DISPLAY "REASON: " WS-DECLINE-REASON
           ELSE
              DISPLAY "STATUS: APPROVED"
           END-IF.
