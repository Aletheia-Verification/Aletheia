       IDENTIFICATION DIVISION.
       PROGRAM-ID. CURRENCY-DENOM-CALC.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01 WS-INPUT-FIELDS.
          05 WS-CASH-AMOUNT           PIC S9(9)V99 COMP-3.
          05 WS-DRAWER-TARGET         PIC S9(7)V99 COMP-3.
          05 WS-TELLER-ID             PIC X(8).

       01 WS-DENOMINATION-TABLE.
          05 WS-DENOM-ENTRY OCCURS 8.
             10 WS-DENOM-VALUE        PIC S9(5)V99 COMP-3.
             10 WS-DENOM-NAME         PIC X(10).
             10 WS-DENOM-COUNT        PIC 9(5).
             10 WS-DENOM-SUBTOTAL     PIC S9(9)V99 COMP-3.

       01 WS-ACTUAL-COUNTS.
          05 WS-ACTUAL-ENTRY OCCURS 8.
             10 WS-ACTUAL-COUNT       PIC 9(5).
             10 WS-ACTUAL-SUBTOTAL    PIC S9(9)V99 COMP-3.

       01 WS-WORK-FIELDS.
          05 WS-REMAINING             PIC S9(9)V99 COMP-3.
          05 WS-TEMP-COUNT            PIC 9(5).
          05 WS-TEMP-AMT              PIC S9(9)V99 COMP-3.
          05 WS-QUOTIENT              PIC 9(5).
          05 WS-REMAINDER-AMT         PIC S9(9)V99 COMP-3.
          05 WS-IDX                   PIC 9(2).

       01 WS-VERIFICATION.
          05 WS-EXPECTED-TOTAL        PIC S9(9)V99 COMP-3.
          05 WS-ACTUAL-TOTAL          PIC S9(9)V99 COMP-3.
          05 WS-VARIANCE              PIC S9(9)V99 COMP-3.
          05 WS-ABS-VARIANCE          PIC S9(9)V99 COMP-3.
          05 WS-VARIANCE-FLAG         PIC X(1).
             88 VARIANCE-ZERO         VALUE '0'.
             88 VARIANCE-MINOR        VALUE 'M'.
             88 VARIANCE-MAJOR        VALUE 'X'.

       01 WS-DRAWER-FIELDS.
          05 WS-MIN-BILLS             PIC 9(3).
          05 WS-DRAWER-TOTAL          PIC S9(9)V99 COMP-3.
          05 WS-DRAWER-IDX            PIC 9(2).
          05 WS-DRAWER-COUNT          PIC 9(5).
          05 WS-DRAWER-SUBTOTAL       PIC S9(9)V99 COMP-3.

       01 WS-SUMMARY.
          05 WS-TOTAL-BILLS           PIC 9(6).
          05 WS-TOTAL-COINS           PIC 9(6).
          05 WS-GRAND-TOTAL           PIC S9(9)V99 COMP-3.
          05 WS-VERIFIED-FLAG         PIC X(1).
             88 IS-VERIFIED           VALUE 'Y'.
             88 NOT-VERIFIED          VALUE 'N'.

       PROCEDURE DIVISION.

       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-SETUP-DENOMINATIONS
           PERFORM 3000-CALC-BREAKDOWN
           PERFORM 4000-CALC-MIN-DRAWER
           PERFORM 5000-VERIFY-COUNTS
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.

       1000-INITIALIZE.
           INITIALIZE WS-DENOMINATION-TABLE
           INITIALIZE WS-ACTUAL-COUNTS
           INITIALIZE WS-VERIFICATION
           INITIALIZE WS-SUMMARY
           SET NOT-VERIFIED TO TRUE.

       2000-SETUP-DENOMINATIONS.
           MOVE 100.00 TO WS-DENOM-VALUE(1)
           MOVE "$100" TO WS-DENOM-NAME(1)
           MOVE 50.00 TO WS-DENOM-VALUE(2)
           MOVE "$50" TO WS-DENOM-NAME(2)
           MOVE 20.00 TO WS-DENOM-VALUE(3)
           MOVE "$20" TO WS-DENOM-NAME(3)
           MOVE 10.00 TO WS-DENOM-VALUE(4)
           MOVE "$10" TO WS-DENOM-NAME(4)
           MOVE 5.00 TO WS-DENOM-VALUE(5)
           MOVE "$5" TO WS-DENOM-NAME(5)
           MOVE 1.00 TO WS-DENOM-VALUE(6)
           MOVE "$1" TO WS-DENOM-NAME(6)
           MOVE 0.25 TO WS-DENOM-VALUE(7)
           MOVE "QUARTER" TO WS-DENOM-NAME(7)
           MOVE 0.01 TO WS-DENOM-VALUE(8)
           MOVE "PENNY" TO WS-DENOM-NAME(8).

       3000-CALC-BREAKDOWN.
           MOVE WS-CASH-AMOUNT TO WS-REMAINING
           PERFORM VARYING WS-IDX FROM 1 BY 1
              UNTIL WS-IDX > 8
              IF WS-REMAINING > 0
                 IF WS-DENOM-VALUE(WS-IDX) > 0
                    DIVIDE WS-REMAINING BY
                       WS-DENOM-VALUE(WS-IDX)
                       GIVING WS-QUOTIENT
                       REMAINDER WS-REMAINDER-AMT
                    MOVE WS-QUOTIENT
                       TO WS-DENOM-COUNT(WS-IDX)
                    COMPUTE WS-DENOM-SUBTOTAL(WS-IDX) =
                       WS-DENOM-COUNT(WS-IDX) *
                       WS-DENOM-VALUE(WS-IDX)
                    MOVE WS-REMAINDER-AMT
                       TO WS-REMAINING
                 END-IF
              ELSE
                 MOVE 0 TO WS-DENOM-COUNT(WS-IDX)
                 MOVE 0 TO WS-DENOM-SUBTOTAL(WS-IDX)
              END-IF
           END-PERFORM
           MOVE 0 TO WS-EXPECTED-TOTAL
           PERFORM VARYING WS-IDX FROM 1 BY 1
              UNTIL WS-IDX > 8
              ADD WS-DENOM-SUBTOTAL(WS-IDX)
                 TO WS-EXPECTED-TOTAL
              IF WS-IDX < 7
                 ADD WS-DENOM-COUNT(WS-IDX)
                    TO WS-TOTAL-BILLS
              ELSE
                 ADD WS-DENOM-COUNT(WS-IDX)
                    TO WS-TOTAL-COINS
              END-IF
           END-PERFORM.

       4000-CALC-MIN-DRAWER.
           MOVE 0 TO WS-DRAWER-TOTAL
           MOVE 20 TO WS-MIN-BILLS
           PERFORM VARYING WS-DRAWER-IDX FROM 1 BY 1
              UNTIL WS-DRAWER-IDX > 6
              COMPUTE WS-DRAWER-COUNT =
                 WS-MIN-BILLS
              COMPUTE WS-DRAWER-SUBTOTAL =
                 WS-DRAWER-COUNT *
                 WS-DENOM-VALUE(WS-DRAWER-IDX)
              ADD WS-DRAWER-SUBTOTAL TO WS-DRAWER-TOTAL
           END-PERFORM
           IF WS-DRAWER-TOTAL < WS-DRAWER-TARGET
              COMPUTE WS-TEMP-AMT =
                 WS-DRAWER-TARGET - WS-DRAWER-TOTAL
              DIVIDE WS-TEMP-AMT BY 20.00
                 GIVING WS-TEMP-COUNT
              ADD WS-TEMP-COUNT TO WS-MIN-BILLS
           END-IF.

       5000-VERIFY-COUNTS.
           MOVE 0 TO WS-ACTUAL-TOTAL
           PERFORM VARYING WS-IDX FROM 1 BY 1
              UNTIL WS-IDX > 8
              COMPUTE WS-ACTUAL-SUBTOTAL(WS-IDX) =
                 WS-ACTUAL-COUNT(WS-IDX) *
                 WS-DENOM-VALUE(WS-IDX)
              ADD WS-ACTUAL-SUBTOTAL(WS-IDX)
                 TO WS-ACTUAL-TOTAL
           END-PERFORM
           COMPUTE WS-VARIANCE =
              WS-ACTUAL-TOTAL - WS-EXPECTED-TOTAL
           IF WS-VARIANCE < 0
              COMPUTE WS-ABS-VARIANCE =
                 0 - WS-VARIANCE
           ELSE
              MOVE WS-VARIANCE TO WS-ABS-VARIANCE
           END-IF
           IF WS-ABS-VARIANCE = 0
              SET VARIANCE-ZERO TO TRUE
              SET IS-VERIFIED TO TRUE
           ELSE
              IF WS-ABS-VARIANCE < 1.00
                 SET VARIANCE-MINOR TO TRUE
                 SET IS-VERIFIED TO TRUE
              ELSE
                 SET VARIANCE-MAJOR TO TRUE
                 SET NOT-VERIFIED TO TRUE
              END-IF
           END-IF.

       6000-DISPLAY-RESULTS.
           DISPLAY "===== DENOMINATION BREAKDOWN ====="
           PERFORM VARYING WS-IDX FROM 1 BY 1
              UNTIL WS-IDX > 8
              DISPLAY WS-DENOM-NAME(WS-IDX) ": "
                 WS-DENOM-COUNT(WS-IDX) " = "
                 WS-DENOM-SUBTOTAL(WS-IDX)
           END-PERFORM
           DISPLAY "TOTAL BILLS: " WS-TOTAL-BILLS
           DISPLAY "TOTAL COINS: " WS-TOTAL-COINS
           DISPLAY "EXPECTED: " WS-EXPECTED-TOTAL
           DISPLAY "ACTUAL: " WS-ACTUAL-TOTAL
           DISPLAY "VARIANCE: " WS-VARIANCE
           IF IS-VERIFIED
              DISPLAY "STATUS: VERIFIED"
           ELSE
              DISPLAY "STATUS: VARIANCE DETECTED"
           END-IF.
