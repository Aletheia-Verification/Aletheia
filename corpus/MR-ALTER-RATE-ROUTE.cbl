       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-ALTER-RATE-ROUTE.
      *================================================================*
      * MANUAL REVIEW: ALTER-BASED RATE ROUTING ENGINE                 *
      * Uses ALTER to dynamically route rate calculation logic         *
      * based on product type: CD, SAVINGS, CHECKING, MONEY MARKET.   *
      * ALTER triggers REQUIRES_MANUAL_REVIEW.                         *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-PRODUCT-CODE           PIC 9(1).
           88 WS-PRODUCT-CD         VALUE 1.
           88 WS-PRODUCT-SAV        VALUE 2.
           88 WS-PRODUCT-CHK        VALUE 3.
           88 WS-PRODUCT-MM         VALUE 4.
       01 WS-BALANCE                PIC S9(11)V99 COMP-3.
       01 WS-TERM-MONTHS            PIC S9(3) COMP-3.
       01 WS-BASE-RATE              PIC S9(2)V9(4) COMP-3.
       01 WS-BONUS-RATE             PIC S9(1)V9(4) COMP-3.
       01 WS-EFFECTIVE-RATE         PIC S9(2)V9(4) COMP-3.
       01 WS-DAILY-ACCRUAL          PIC S9(5)V9(6) COMP-3.
       01 WS-MONTHLY-INTEREST       PIC S9(7)V99 COMP-3.
       01 WS-PRODUCT-DESC           PIC X(20).
       01 WS-PENALTY-RATE           PIC S9(1)V9(4) COMP-3.
       01 WS-EARLY-PENALTY          PIC S9(7)V99 COMP-3.
       01 WS-TIER-LABEL             PIC X(15).
       01 WS-MIN-BAL                PIC S9(7)V99 COMP-3.
       PROCEDURE DIVISION.
       MAIN-PROGRAM.
           PERFORM INIT-DATA
           PERFORM SETUP-ROUTER
           PERFORM ROUTE-CALC
           PERFORM CALC-ACCRUAL
           PERFORM DISPLAY-RESULT
           STOP RUN.
       INIT-DATA.
           MOVE 4 TO WS-PRODUCT-CODE
           MOVE 250000.00 TO WS-BALANCE
           MOVE 0 TO WS-TERM-MONTHS
           MOVE 0 TO WS-BASE-RATE
           MOVE 0 TO WS-BONUS-RATE
           MOVE 0 TO WS-EFFECTIVE-RATE
           MOVE 0 TO WS-DAILY-ACCRUAL
           MOVE 0 TO WS-MONTHLY-INTEREST
           MOVE 0 TO WS-PENALTY-RATE
           MOVE 0 TO WS-EARLY-PENALTY
           MOVE 0 TO WS-MIN-BAL
           MOVE SPACES TO WS-PRODUCT-DESC
           MOVE SPACES TO WS-TIER-LABEL.
       SETUP-ROUTER.
           EVALUATE TRUE
               WHEN WS-PRODUCT-CD
                   ALTER ROUTE-CALC TO PROCEED TO
                       CALC-CD-RATE
               WHEN WS-PRODUCT-SAV
                   ALTER ROUTE-CALC TO PROCEED TO
                       CALC-SAVINGS-RATE
               WHEN WS-PRODUCT-CHK
                   ALTER ROUTE-CALC TO PROCEED TO
                       CALC-CHECKING-RATE
               WHEN WS-PRODUCT-MM
                   ALTER ROUTE-CALC TO PROCEED TO
                       CALC-MM-RATE
           END-EVALUATE.
       ROUTE-CALC.
           GO TO CALC-CD-RATE.
       CALC-CD-RATE.
           MOVE 'CERTIFICATE DEP' TO WS-PRODUCT-DESC
           MOVE 12 TO WS-TERM-MONTHS
           EVALUATE TRUE
               WHEN WS-BALANCE >= 100000
                   MOVE 4.75 TO WS-BASE-RATE
                   MOVE 'JUMBO' TO WS-TIER-LABEL
               WHEN WS-BALANCE >= 25000
                   MOVE 4.25 TO WS-BASE-RATE
                   MOVE 'PREMIUM' TO WS-TIER-LABEL
               WHEN OTHER
                   MOVE 3.75 TO WS-BASE-RATE
                   MOVE 'STANDARD' TO WS-TIER-LABEL
           END-EVALUATE
           COMPUTE WS-PENALTY-RATE = 0.50
           COMPUTE WS-EARLY-PENALTY ROUNDED =
               WS-BALANCE * WS-PENALTY-RATE / 100 *
               (WS-TERM-MONTHS / 12)
           GO TO APPLY-BONUS.
       CALC-SAVINGS-RATE.
           MOVE 'SAVINGS ACCOUNT' TO WS-PRODUCT-DESC
           MOVE 100.00 TO WS-MIN-BAL
           IF WS-BALANCE >= 50000
               MOVE 2.50 TO WS-BASE-RATE
               MOVE 'HIGH BALANCE' TO WS-TIER-LABEL
           ELSE
               IF WS-BALANCE >= 10000
                   MOVE 2.00 TO WS-BASE-RATE
                   MOVE 'STANDARD' TO WS-TIER-LABEL
               ELSE
                   MOVE 1.50 TO WS-BASE-RATE
                   MOVE 'BASIC' TO WS-TIER-LABEL
               END-IF
           END-IF
           GO TO APPLY-BONUS.
       CALC-CHECKING-RATE.
           MOVE 'INTEREST CHECKING' TO WS-PRODUCT-DESC
           MOVE 1500.00 TO WS-MIN-BAL
           IF WS-BALANCE >= 25000
               MOVE 0.75 TO WS-BASE-RATE
               MOVE 'PREMIUM' TO WS-TIER-LABEL
           ELSE
               MOVE 0.25 TO WS-BASE-RATE
               MOVE 'BASIC' TO WS-TIER-LABEL
           END-IF
           GO TO APPLY-BONUS.
       CALC-MM-RATE.
           MOVE 'MONEY MARKET' TO WS-PRODUCT-DESC
           MOVE 2500.00 TO WS-MIN-BAL
           EVALUATE TRUE
               WHEN WS-BALANCE >= 250000
                   MOVE 4.00 TO WS-BASE-RATE
                   MOVE 'SUPER PREMIUM' TO WS-TIER-LABEL
               WHEN WS-BALANCE >= 100000
                   MOVE 3.50 TO WS-BASE-RATE
                   MOVE 'PREMIUM' TO WS-TIER-LABEL
               WHEN WS-BALANCE >= 25000
                   MOVE 3.00 TO WS-BASE-RATE
                   MOVE 'STANDARD' TO WS-TIER-LABEL
               WHEN OTHER
                   MOVE 2.25 TO WS-BASE-RATE
                   MOVE 'BASIC' TO WS-TIER-LABEL
           END-EVALUATE
           GO TO APPLY-BONUS.
       APPLY-BONUS.
           IF WS-BALANCE >= 500000
               MOVE 0.25 TO WS-BONUS-RATE
           ELSE
               IF WS-BALANCE >= 100000
                   MOVE 0.10 TO WS-BONUS-RATE
               ELSE
                   MOVE 0 TO WS-BONUS-RATE
               END-IF
           END-IF
           COMPUTE WS-EFFECTIVE-RATE =
               WS-BASE-RATE + WS-BONUS-RATE.
       CALC-ACCRUAL.
           COMPUTE WS-DAILY-ACCRUAL ROUNDED =
               WS-BALANCE * (WS-EFFECTIVE-RATE / 100) / 365
           COMPUTE WS-MONTHLY-INTEREST ROUNDED =
               WS-DAILY-ACCRUAL * 30.
       DISPLAY-RESULT.
           DISPLAY '========================================='
           DISPLAY 'RATE CALCULATION RESULT'
           DISPLAY '========================================='
           DISPLAY 'PRODUCT:         ' WS-PRODUCT-DESC
           DISPLAY 'TIER:            ' WS-TIER-LABEL
           DISPLAY 'BALANCE:         ' WS-BALANCE
           DISPLAY 'BASE RATE:       ' WS-BASE-RATE
           DISPLAY 'BONUS RATE:      ' WS-BONUS-RATE
           DISPLAY 'EFFECTIVE RATE:  ' WS-EFFECTIVE-RATE
           DISPLAY 'DAILY ACCRUAL:   ' WS-DAILY-ACCRUAL
           DISPLAY 'MONTHLY INT:     ' WS-MONTHLY-INTEREST
           IF WS-EARLY-PENALTY > 0
               DISPLAY 'EARLY PENALTY:   ' WS-EARLY-PENALTY
           END-IF
           IF WS-MIN-BAL > 0
               DISPLAY 'MIN BALANCE:     ' WS-MIN-BAL
           END-IF
           DISPLAY '========================================='.
