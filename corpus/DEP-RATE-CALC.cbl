       IDENTIFICATION DIVISION.
       PROGRAM-ID. DEP-RATE-CALC.
      *================================================================*
      * DEPOSIT RATE CALCULATION ENGINE                                *
      * Determines interest rate for deposit accounts based on         *
      * product tier, balance band, relationship, and promo codes.     *
      * Computes daily accrual using 365/360 day count conventions.    *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ACCOUNT.
           05 WS-ACCT-NUM           PIC X(12).
           05 WS-ACCT-TYPE          PIC X(2).
               88 WS-SAVINGS        VALUE 'SA'.
               88 WS-CHECKING       VALUE 'CK'.
               88 WS-MONEY-MKT      VALUE 'MM'.
               88 WS-CD-ACCT        VALUE 'CD'.
           05 WS-BALANCE            PIC S9(11)V99 COMP-3.
           05 WS-ACCT-OPEN-DATE     PIC 9(8).
           05 WS-PROMO-CODE         PIC X(6).
               88 WS-NO-PROMO       VALUE SPACES.
               88 WS-PROMO-NEW      VALUE 'NEWCST'.
               88 WS-PROMO-LOYAL    VALUE 'LOYAL5'.
       01 WS-RELATIONSHIP.
           05 WS-TOTAL-DEPOSITS     PIC S9(13)V99 COMP-3.
           05 WS-HAS-LOAN           PIC X VALUE 'N'.
               88 WS-LOAN-HOLDER    VALUE 'Y'.
           05 WS-HAS-MORTGAGE       PIC X VALUE 'N'.
               88 WS-MORTGAGE-HOLDER VALUE 'Y'.
           05 WS-YEARS-CUSTOMER     PIC S9(2) COMP-3.
       01 WS-RATE-COMPONENTS.
           05 WS-BASE-RATE          PIC S9(2)V9(4) COMP-3.
           05 WS-BALANCE-BUMP       PIC S9(1)V9(4) COMP-3.
           05 WS-RELATION-BUMP      PIC S9(1)V9(4) COMP-3.
           05 WS-PROMO-BUMP         PIC S9(1)V9(4) COMP-3.
           05 WS-LOYALTY-BUMP       PIC S9(1)V9(4) COMP-3.
           05 WS-EFFECTIVE-RATE     PIC S9(2)V9(4) COMP-3.
       01 WS-ACCRUAL.
           05 WS-DAY-COUNT-BASIS    PIC S9(3) COMP-3.
           05 WS-DAILY-ACCRUAL      PIC S9(5)V9(6) COMP-3.
           05 WS-MONTHLY-INTEREST   PIC S9(7)V99 COMP-3.
           05 WS-ANNUAL-INTEREST    PIC S9(9)V99 COMP-3.
           05 WS-APY                PIC S9(2)V9(4) COMP-3.
       01 WS-RATE-TIER-DESC         PIC X(20).
       01 WS-COMPOUND-FACTOR        PIC S9(3)V9(8) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-DETERMINE-BASE-RATE
           PERFORM 3000-CALC-BALANCE-BUMP
           PERFORM 4000-CALC-RELATIONSHIP-BUMP
           PERFORM 5000-APPLY-PROMOS
               THRU 5500-APPLY-LOYALTY
           PERFORM 6000-CALC-EFFECTIVE-RATE
           PERFORM 7000-CALC-ACCRUAL
           PERFORM 8000-DISPLAY-RESULT
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'ACCT00012345' TO WS-ACCT-NUM
           MOVE 'MM' TO WS-ACCT-TYPE
           MOVE 175000.00 TO WS-BALANCE
           MOVE 20210615 TO WS-ACCT-OPEN-DATE
           MOVE 'LOYAL5' TO WS-PROMO-CODE
           MOVE 350000.00 TO WS-TOTAL-DEPOSITS
           MOVE 'Y' TO WS-HAS-LOAN
           MOVE 'Y' TO WS-HAS-MORTGAGE
           MOVE 5 TO WS-YEARS-CUSTOMER
           MOVE 0 TO WS-BASE-RATE
           MOVE 0 TO WS-BALANCE-BUMP
           MOVE 0 TO WS-RELATION-BUMP
           MOVE 0 TO WS-PROMO-BUMP
           MOVE 0 TO WS-LOYALTY-BUMP.
       2000-DETERMINE-BASE-RATE.
           EVALUATE TRUE
               WHEN WS-CD-ACCT
                   MOVE 4.25 TO WS-BASE-RATE
                   MOVE 360 TO WS-DAY-COUNT-BASIS
                   MOVE 'CD BASE' TO WS-RATE-TIER-DESC
               WHEN WS-MONEY-MKT
                   MOVE 3.50 TO WS-BASE-RATE
                   MOVE 365 TO WS-DAY-COUNT-BASIS
                   MOVE 'MONEY MARKET BASE' TO
                       WS-RATE-TIER-DESC
               WHEN WS-SAVINGS
                   MOVE 2.00 TO WS-BASE-RATE
                   MOVE 365 TO WS-DAY-COUNT-BASIS
                   MOVE 'SAVINGS BASE' TO WS-RATE-TIER-DESC
               WHEN WS-CHECKING
                   MOVE 0.50 TO WS-BASE-RATE
                   MOVE 365 TO WS-DAY-COUNT-BASIS
                   MOVE 'CHECKING BASE' TO WS-RATE-TIER-DESC
               WHEN OTHER
                   MOVE 0.25 TO WS-BASE-RATE
                   MOVE 365 TO WS-DAY-COUNT-BASIS
                   MOVE 'DEFAULT BASE' TO WS-RATE-TIER-DESC
           END-EVALUATE.
       3000-CALC-BALANCE-BUMP.
           EVALUATE TRUE
               WHEN WS-BALANCE >= 500000
                   MOVE 0.50 TO WS-BALANCE-BUMP
               WHEN WS-BALANCE >= 250000
                   MOVE 0.35 TO WS-BALANCE-BUMP
               WHEN WS-BALANCE >= 100000
                   MOVE 0.25 TO WS-BALANCE-BUMP
               WHEN WS-BALANCE >= 50000
                   MOVE 0.15 TO WS-BALANCE-BUMP
               WHEN WS-BALANCE >= 10000
                   MOVE 0.05 TO WS-BALANCE-BUMP
               WHEN OTHER
                   MOVE 0 TO WS-BALANCE-BUMP
           END-EVALUATE.
       4000-CALC-RELATIONSHIP-BUMP.
           MOVE 0 TO WS-RELATION-BUMP
           IF WS-TOTAL-DEPOSITS > 500000
               ADD 0.15 TO WS-RELATION-BUMP
           END-IF
           IF WS-MORTGAGE-HOLDER
               ADD 0.10 TO WS-RELATION-BUMP
           END-IF
           IF WS-LOAN-HOLDER
               ADD 0.05 TO WS-RELATION-BUMP
           END-IF.
       5000-APPLY-PROMOS.
           EVALUATE TRUE
               WHEN WS-PROMO-NEW
                   MOVE 0.50 TO WS-PROMO-BUMP
               WHEN WS-PROMO-LOYAL
                   MOVE 0.25 TO WS-PROMO-BUMP
               WHEN WS-NO-PROMO
                   MOVE 0 TO WS-PROMO-BUMP
               WHEN OTHER
                   MOVE 0 TO WS-PROMO-BUMP
           END-EVALUATE.
       5500-APPLY-LOYALTY.
           EVALUATE TRUE
               WHEN WS-YEARS-CUSTOMER >= 10
                   MOVE 0.20 TO WS-LOYALTY-BUMP
               WHEN WS-YEARS-CUSTOMER >= 5
                   MOVE 0.10 TO WS-LOYALTY-BUMP
               WHEN WS-YEARS-CUSTOMER >= 3
                   MOVE 0.05 TO WS-LOYALTY-BUMP
               WHEN OTHER
                   MOVE 0 TO WS-LOYALTY-BUMP
           END-EVALUATE.
       6000-CALC-EFFECTIVE-RATE.
           COMPUTE WS-EFFECTIVE-RATE =
               WS-BASE-RATE + WS-BALANCE-BUMP +
               WS-RELATION-BUMP + WS-PROMO-BUMP +
               WS-LOYALTY-BUMP
           IF WS-EFFECTIVE-RATE > 6.00
               MOVE 6.00 TO WS-EFFECTIVE-RATE
           END-IF
           IF WS-EFFECTIVE-RATE < 0
               MOVE 0 TO WS-EFFECTIVE-RATE
           END-IF.
       7000-CALC-ACCRUAL.
           COMPUTE WS-DAILY-ACCRUAL ROUNDED =
               WS-BALANCE * (WS-EFFECTIVE-RATE / 100) /
               WS-DAY-COUNT-BASIS
           COMPUTE WS-MONTHLY-INTEREST ROUNDED =
               WS-DAILY-ACCRUAL * 30
           COMPUTE WS-ANNUAL-INTEREST ROUNDED =
               WS-BALANCE * WS-EFFECTIVE-RATE / 100
           COMPUTE WS-COMPOUND-FACTOR ROUNDED =
               (1 + (WS-EFFECTIVE-RATE / 100 / 12))
               ** 12
           COMPUTE WS-APY ROUNDED =
               (WS-COMPOUND-FACTOR - 1) * 100.
       8000-DISPLAY-RESULT.
           DISPLAY '========================================='
           DISPLAY 'DEPOSIT RATE CALCULATION'
           DISPLAY '========================================='
           DISPLAY 'ACCOUNT:         ' WS-ACCT-NUM
           DISPLAY 'TYPE:            ' WS-ACCT-TYPE
           DISPLAY 'BALANCE:         ' WS-BALANCE
           DISPLAY 'TIER:            ' WS-RATE-TIER-DESC
           DISPLAY '----- RATE COMPONENTS -----'
           DISPLAY 'BASE RATE:       ' WS-BASE-RATE
           DISPLAY 'BALANCE BUMP:    ' WS-BALANCE-BUMP
           DISPLAY 'RELATION BUMP:   ' WS-RELATION-BUMP
           DISPLAY 'PROMO BUMP:      ' WS-PROMO-BUMP
           DISPLAY 'LOYALTY BUMP:    ' WS-LOYALTY-BUMP
           DISPLAY 'EFFECTIVE RATE:  ' WS-EFFECTIVE-RATE
           DISPLAY 'APY:             ' WS-APY
           DISPLAY '----- ACCRUAL -----'
           DISPLAY 'DAILY ACCRUAL:   ' WS-DAILY-ACCRUAL
           DISPLAY 'MONTHLY INT:     ' WS-MONTHLY-INTEREST
           DISPLAY 'ANNUAL INT:      ' WS-ANNUAL-INTEREST
           DISPLAY '========================================='.
