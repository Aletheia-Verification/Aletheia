       IDENTIFICATION DIVISION.
       PROGRAM-ID. TRADE-ACCRUED-INT.
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-BOND-DATA.
           05 WS-CUSIP               PIC X(9).
           05 WS-FACE-VALUE          PIC S9(9)V99 COMP-3.
           05 WS-COUPON-RATE         PIC S9(3)V9(6) COMP-3.
           05 WS-LAST-COUPON-DATE    PIC 9(8).
           05 WS-SETTLE-DATE         PIC 9(8).
           05 WS-NEXT-COUPON-DATE    PIC 9(8).
       01 WS-DAY-COUNT               PIC X(1).
           88 WS-30-360              VALUE '3'.
           88 WS-ACT-360             VALUE 'A'.
           88 WS-ACT-ACT             VALUE 'C'.
       01 WS-CALC-FIELDS.
           05 WS-DAYS-ACCRUED        PIC S9(3) COMP-3.
           05 WS-DAYS-IN-PERIOD      PIC S9(3) COMP-3.
           05 WS-ACCRUED-INT         PIC S9(9)V99 COMP-3.
           05 WS-SEMI-COUPON         PIC S9(7)V99 COMP-3.
           05 WS-CLEAN-PRICE         PIC S9(7)V99 COMP-3.
           05 WS-DIRTY-PRICE         PIC S9(7)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-DAYS
           PERFORM 3000-CALC-ACCRUED
           PERFORM 4000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-ACCRUED-INT
           COMPUTE WS-SEMI-COUPON =
               WS-FACE-VALUE * WS-COUPON-RATE / 2.
       2000-CALC-DAYS.
           EVALUATE TRUE
               WHEN WS-30-360
                   MOVE 180 TO WS-DAYS-IN-PERIOD
                   COMPUTE WS-DAYS-ACCRUED =
                       WS-SETTLE-DATE - WS-LAST-COUPON-DATE
                   IF WS-DAYS-ACCRUED > 180
                       MOVE 180 TO WS-DAYS-ACCRUED
                   END-IF
               WHEN WS-ACT-360
                   MOVE 180 TO WS-DAYS-IN-PERIOD
                   COMPUTE WS-DAYS-ACCRUED =
                       WS-SETTLE-DATE - WS-LAST-COUPON-DATE
               WHEN WS-ACT-ACT
                   COMPUTE WS-DAYS-IN-PERIOD =
                       WS-NEXT-COUPON-DATE -
                       WS-LAST-COUPON-DATE
                   COMPUTE WS-DAYS-ACCRUED =
                       WS-SETTLE-DATE - WS-LAST-COUPON-DATE
               WHEN OTHER
                   MOVE 180 TO WS-DAYS-IN-PERIOD
                   COMPUTE WS-DAYS-ACCRUED =
                       WS-SETTLE-DATE - WS-LAST-COUPON-DATE
           END-EVALUATE
           IF WS-DAYS-ACCRUED < 0
               MOVE 0 TO WS-DAYS-ACCRUED
           END-IF.
       3000-CALC-ACCRUED.
           IF WS-DAYS-IN-PERIOD > 0
               COMPUTE WS-ACCRUED-INT =
                   WS-SEMI-COUPON * WS-DAYS-ACCRUED /
                   WS-DAYS-IN-PERIOD
           END-IF
           COMPUTE WS-DIRTY-PRICE =
               WS-CLEAN-PRICE + WS-ACCRUED-INT.
       4000-DISPLAY-RESULTS.
           DISPLAY 'ACCRUED INTEREST CALCULATION'
           DISPLAY '============================'
           DISPLAY 'CUSIP:         ' WS-CUSIP
           DISPLAY 'FACE VALUE:    ' WS-FACE-VALUE
           DISPLAY 'COUPON RATE:   ' WS-COUPON-RATE
           DISPLAY 'SEMI COUPON:   ' WS-SEMI-COUPON
           DISPLAY 'DAYS ACCRUED:  ' WS-DAYS-ACCRUED
           DISPLAY 'DAYS IN PER:   ' WS-DAYS-IN-PERIOD
           DISPLAY 'ACCRUED INT:   ' WS-ACCRUED-INT
           DISPLAY 'CLEAN PRICE:   ' WS-CLEAN-PRICE
           DISPLAY 'DIRTY PRICE:   ' WS-DIRTY-PRICE.
