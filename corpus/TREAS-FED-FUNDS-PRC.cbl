       IDENTIFICATION DIVISION.
       PROGRAM-ID. TREAS-FED-FUNDS-PRC.
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-FED-FUNDS-DATA.
           05 WS-EFFECTIVE-RATE      PIC S9(1)V9(6) COMP-3.
           05 WS-BID-RATE            PIC S9(1)V9(6) COMP-3.
           05 WS-OFFER-RATE          PIC S9(1)V9(6) COMP-3.
           05 WS-SPREAD              PIC S9(1)V9(6) COMP-3.
       01 WS-LOAN-AMOUNT             PIC S9(11)V99 COMP-3.
       01 WS-TERM-DAYS               PIC 9(3).
       01 WS-CALC-FIELDS.
           05 WS-INTEREST-AMT        PIC S9(9)V99 COMP-3.
           05 WS-DAILY-RATE          PIC S9(1)V9(10) COMP-3.
           05 WS-TOTAL-COST          PIC S9(9)V99 COMP-3.
           05 WS-ANNUALIZED          PIC S9(1)V9(6) COMP-3.
       01 WS-PARTY-TYPE              PIC X(1).
           88 WS-BORROWER            VALUE 'B'.
           88 WS-LENDER              VALUE 'L'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-SPREAD
           PERFORM 3000-CALC-INTEREST
           PERFORM 4000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0,0525 TO WS-EFFECTIVE-RATE
           MOVE 0 TO WS-INTEREST-AMT
           MOVE 0 TO WS-TOTAL-COST.
       2000-CALC-SPREAD.
           COMPUTE WS-SPREAD =
               WS-OFFER-RATE - WS-BID-RATE
           IF WS-SPREAD < 0,0001
               MOVE 0,0001 TO WS-SPREAD
           END-IF.
       3000-CALC-INTEREST.
           IF WS-BORROWER
               COMPUTE WS-DAILY-RATE =
                   WS-OFFER-RATE / 360
           ELSE
               COMPUTE WS-DAILY-RATE =
                   WS-BID-RATE / 360
           END-IF
           COMPUTE WS-INTEREST-AMT =
               WS-LOAN-AMOUNT * WS-DAILY-RATE *
               WS-TERM-DAYS
           COMPUTE WS-TOTAL-COST = WS-INTEREST-AMT
           IF WS-TERM-DAYS > 0
               COMPUTE WS-ANNUALIZED =
                   (WS-INTEREST-AMT / WS-LOAN-AMOUNT)
                   * (360 / WS-TERM-DAYS)
           END-IF.
       4000-DISPLAY-RESULTS.
           DISPLAY 'FED FUNDS PRICING'
           DISPLAY '================='
           DISPLAY 'EFFECTIVE RATE: ' WS-EFFECTIVE-RATE
           DISPLAY 'BID RATE:       ' WS-BID-RATE
           DISPLAY 'OFFER RATE:     ' WS-OFFER-RATE
           DISPLAY 'SPREAD:         ' WS-SPREAD
           DISPLAY 'LOAN AMOUNT:    ' WS-LOAN-AMOUNT
           DISPLAY 'TERM DAYS:      ' WS-TERM-DAYS
           DISPLAY 'INTEREST:       ' WS-INTEREST-AMT
           DISPLAY 'ANNUALIZED:     ' WS-ANNUALIZED
           IF WS-BORROWER
               DISPLAY 'ROLE: BORROWER'
           ELSE
               DISPLAY 'ROLE: LENDER'
           END-IF.
