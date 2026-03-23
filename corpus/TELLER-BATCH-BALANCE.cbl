       IDENTIFICATION DIVISION.
       PROGRAM-ID. TELLER-BATCH-BALANCE.
      *================================================================*
      * TELLER DRAWER BALANCING - END OF SHIFT                         *
      * Counts denominations, sums cash, compares against expected     *
      * total from transaction log, flags over/short variances, and    *
      * requires supervisor approval above threshold.                   *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- Denomination Table (8 denominations) ---
       01  WS-DENOM-TABLE.
           05  WS-DENOM-ENTRY OCCURS 8 TIMES.
               10  WS-DENOM-VALUE      PIC S9(5)V99 COMP-3.
               10  WS-DENOM-COUNT      PIC S9(5) COMP-3.
               10  WS-DENOM-SUBTOTAL   PIC S9(9)V99 COMP-3.
      *--- Totals ---
       01  WS-CASH-TOTAL              PIC S9(9)V99 COMP-3.
       01  WS-EXPECTED-TOTAL          PIC S9(9)V99 COMP-3.
       01  WS-OPENING-BALANCE         PIC S9(9)V99 COMP-3.
       01  WS-DEPOSITS-TOTAL          PIC S9(9)V99 COMP-3.
       01  WS-WITHDRAWALS-TOTAL       PIC S9(9)V99 COMP-3.
       01  WS-VARIANCE                PIC S9(9)V99 COMP-3.
       01  WS-ABS-VARIANCE            PIC S9(9)V99 COMP-3.
      *--- Threshold and Flags ---
       01  WS-OVER-SHORT-THRESHOLD    PIC S9(7)V99 COMP-3.
       01  WS-SUPERVISOR-REQUIRED     PIC X(1).
       01  WS-BALANCE-STATUS          PIC X(10).
       01  WS-TELLER-ID              PIC X(8).
       01  WS-SHIFT-DATE             PIC X(10).
      *--- Transaction Log Description ---
       01  WS-TXN-DESCRIPTION         PIC X(80).
       01  WS-DEPOSIT-COUNT           PIC 9(5).
       01  WS-WITHDRAWAL-COUNT        PIC 9(5).
       01  WS-CHECK-COUNT             PIC 9(5).
       01  WS-TOTAL-TXN-COUNT         PIC 9(5).
      *--- Loop Control ---
       01  WS-IDX                     PIC 9(3).
       01  WS-DENOM-IDX              PIC 9(3).
      *--- Coin totals ---
       01  WS-COIN-TOTAL              PIC S9(9)V99 COMP-3.
       01  WS-BILL-TOTAL              PIC S9(9)V99 COMP-3.
      *--- Work Fields ---
       01  WS-WORK-AMT                PIC S9(9)V99 COMP-3.
       01  WS-NET-TRANSACTIONS        PIC S9(9)V99 COMP-3.
      *--- Check Processing ---
       01  WS-CHECK-AMOUNT-TOTAL      PIC S9(9)V99 COMP-3.
       01  WS-CHECK-HOLD-TOTAL        PIC S9(9)V99 COMP-3.
       01  WS-CHECK-HOLD-PCT          PIC S9(3)V9(4) COMP-3.
       01  WS-AVAILABLE-CASH          PIC S9(9)V99 COMP-3.
      *--- Variance Categories ---
       01  WS-VARIANCE-CATEGORY       PIC X(12).
       01  WS-CRITICAL-THRESHOLD      PIC S9(7)V99 COMP-3.
       01  WS-WARNING-THRESHOLD       PIC S9(7)V99 COMP-3.
       01  WS-TELLER-RATING           PIC X(10).
      *--- Shift Summary ---
       01  WS-SHIFT-HOURS             PIC 9(2).
       01  WS-TXNS-PER-HOUR           PIC S9(5)V99 COMP-3.
       01  WS-AVG-DEPOSIT             PIC S9(9)V99 COMP-3.
       01  WS-AVG-WITHDRAWAL          PIC S9(9)V99 COMP-3.

       PROCEDURE DIVISION.
       MAIN-PROGRAM.
           PERFORM INITIALIZE-DRAWER
           PERFORM LOAD-DENOMINATIONS THRU
                   LOAD-DENOMINATIONS-EXIT
           PERFORM SUM-DENOMINATIONS
           PERFORM LOAD-TRANSACTION-LOG THRU
                   LOAD-TRANSACTION-LOG-EXIT
           PERFORM COUNT-TRANSACTIONS
           PERFORM COMPUTE-EXPECTED-TOTAL
           PERFORM COMPUTE-VARIANCE
           PERFORM CATEGORIZE-VARIANCE THRU
                   CATEGORIZE-VARIANCE-EXIT
           PERFORM COMPUTE-CHECK-HOLDS
           PERFORM COMPUTE-SHIFT-STATS
           PERFORM CHECK-APPROVAL-REQUIRED
           PERFORM DISPLAY-BALANCE-REPORT
           STOP RUN.

       INITIALIZE-DRAWER.
           MOVE 0 TO WS-CASH-TOTAL
           MOVE 0 TO WS-EXPECTED-TOTAL
           MOVE 0 TO WS-VARIANCE
           MOVE 0 TO WS-ABS-VARIANCE
           MOVE 0 TO WS-COIN-TOTAL
           MOVE 0 TO WS-BILL-TOTAL
           MOVE 0 TO WS-DEPOSIT-COUNT
           MOVE 0 TO WS-WITHDRAWAL-COUNT
           MOVE 0 TO WS-CHECK-COUNT
           MOVE 0 TO WS-TOTAL-TXN-COUNT
           MOVE 'N' TO WS-SUPERVISOR-REQUIRED
           MOVE 'BALANCED' TO WS-BALANCE-STATUS
           MOVE 'TLR00142' TO WS-TELLER-ID
           MOVE '2026-03-17' TO WS-SHIFT-DATE
           MOVE 25.00 TO WS-OVER-SHORT-THRESHOLD
           MOVE 100.00 TO WS-CRITICAL-THRESHOLD
           MOVE 50.00 TO WS-WARNING-THRESHOLD
           MOVE 5000.00 TO WS-OPENING-BALANCE
           MOVE 0 TO WS-CHECK-AMOUNT-TOTAL
           MOVE 0 TO WS-CHECK-HOLD-TOTAL
           MOVE 0.10 TO WS-CHECK-HOLD-PCT
           MOVE 8 TO WS-SHIFT-HOURS
           MOVE 'EXCELLENT' TO WS-TELLER-RATING.

       LOAD-DENOMINATIONS.
      *--- Bills ---
           MOVE 100.00 TO WS-DENOM-VALUE(1)
           MOVE 42 TO WS-DENOM-COUNT(1)
           MOVE 50.00 TO WS-DENOM-VALUE(2)
           MOVE 18 TO WS-DENOM-COUNT(2)
           MOVE 20.00 TO WS-DENOM-VALUE(3)
           MOVE 95 TO WS-DENOM-COUNT(3)
           MOVE 10.00 TO WS-DENOM-VALUE(4)
           MOVE 60 TO WS-DENOM-COUNT(4)
      *--- Coins ---
           MOVE 5.00 TO WS-DENOM-VALUE(5)
           MOVE 30 TO WS-DENOM-COUNT(5)
           MOVE 1.00 TO WS-DENOM-VALUE(6)
           MOVE 85 TO WS-DENOM-COUNT(6)
           MOVE 0.25 TO WS-DENOM-VALUE(7)
           MOVE 120 TO WS-DENOM-COUNT(7)
           MOVE 0.10 TO WS-DENOM-VALUE(8)
           MOVE 200 TO WS-DENOM-COUNT(8).

       LOAD-DENOMINATIONS-EXIT.
           EXIT.

       SUM-DENOMINATIONS.
           MOVE 0 TO WS-CASH-TOTAL
           MOVE 0 TO WS-COIN-TOTAL
           MOVE 0 TO WS-BILL-TOTAL
           PERFORM VARYING WS-DENOM-IDX FROM 1 BY 1
               UNTIL WS-DENOM-IDX > 8
               COMPUTE WS-DENOM-SUBTOTAL(WS-DENOM-IDX) =
                   WS-DENOM-VALUE(WS-DENOM-IDX) *
                   WS-DENOM-COUNT(WS-DENOM-IDX)
               ADD WS-DENOM-SUBTOTAL(WS-DENOM-IDX)
                   TO WS-CASH-TOTAL
               IF WS-DENOM-VALUE(WS-DENOM-IDX) >= 5.00
                   ADD WS-DENOM-SUBTOTAL(WS-DENOM-IDX)
                       TO WS-BILL-TOTAL
               ELSE
                   ADD WS-DENOM-SUBTOTAL(WS-DENOM-IDX)
                       TO WS-COIN-TOTAL
               END-IF
           END-PERFORM.

       LOAD-TRANSACTION-LOG.
           MOVE 15200.00 TO WS-DEPOSITS-TOTAL
           MOVE 12850.00 TO WS-WITHDRAWALS-TOTAL
           MOVE 'DEP DEP WDR DEP CHK WDR DEP CHK CHK DEP'
               TO WS-TXN-DESCRIPTION.

       LOAD-TRANSACTION-LOG-EXIT.
           EXIT.

       COUNT-TRANSACTIONS.
           MOVE 0 TO WS-DEPOSIT-COUNT
           MOVE 0 TO WS-WITHDRAWAL-COUNT
           MOVE 0 TO WS-CHECK-COUNT
           INSPECT WS-TXN-DESCRIPTION
               TALLYING WS-DEPOSIT-COUNT
               FOR ALL 'DEP'
           INSPECT WS-TXN-DESCRIPTION
               TALLYING WS-WITHDRAWAL-COUNT
               FOR ALL 'WDR'
           INSPECT WS-TXN-DESCRIPTION
               TALLYING WS-CHECK-COUNT
               FOR ALL 'CHK'
           COMPUTE WS-TOTAL-TXN-COUNT =
               WS-DEPOSIT-COUNT + WS-WITHDRAWAL-COUNT +
               WS-CHECK-COUNT.

       COMPUTE-EXPECTED-TOTAL.
           COMPUTE WS-NET-TRANSACTIONS =
               WS-DEPOSITS-TOTAL - WS-WITHDRAWALS-TOTAL
           COMPUTE WS-EXPECTED-TOTAL =
               WS-OPENING-BALANCE + WS-NET-TRANSACTIONS.

       COMPUTE-VARIANCE.
           COMPUTE WS-VARIANCE =
               WS-CASH-TOTAL - WS-EXPECTED-TOTAL
           IF WS-VARIANCE < 0
               COMPUTE WS-ABS-VARIANCE =
                   WS-VARIANCE * -1
           ELSE
               MOVE WS-VARIANCE TO WS-ABS-VARIANCE
           END-IF
           IF WS-VARIANCE > 0
               MOVE 'OVER' TO WS-BALANCE-STATUS
           ELSE
               IF WS-VARIANCE < 0
                   MOVE 'SHORT' TO WS-BALANCE-STATUS
               ELSE
                   MOVE 'BALANCED' TO WS-BALANCE-STATUS
               END-IF
           END-IF.

       CATEGORIZE-VARIANCE.
           IF WS-ABS-VARIANCE > WS-CRITICAL-THRESHOLD
               MOVE 'CRITICAL' TO WS-VARIANCE-CATEGORY
               MOVE 'POOR' TO WS-TELLER-RATING
           ELSE
               IF WS-ABS-VARIANCE > WS-WARNING-THRESHOLD
                   MOVE 'WARNING' TO WS-VARIANCE-CATEGORY
                   MOVE 'FAIR' TO WS-TELLER-RATING
               ELSE
                   IF WS-ABS-VARIANCE > WS-OVER-SHORT-THRESHOLD
                       MOVE 'MINOR' TO WS-VARIANCE-CATEGORY
                       MOVE 'GOOD' TO WS-TELLER-RATING
                   ELSE
                       MOVE 'ACCEPTABLE' TO WS-VARIANCE-CATEGORY
                       MOVE 'EXCELLENT' TO WS-TELLER-RATING
                   END-IF
               END-IF
           END-IF.

       CATEGORIZE-VARIANCE-EXIT.
           EXIT.

       COMPUTE-CHECK-HOLDS.
           MOVE 3500.00 TO WS-CHECK-AMOUNT-TOTAL
           COMPUTE WS-CHECK-HOLD-TOTAL =
               WS-CHECK-AMOUNT-TOTAL * WS-CHECK-HOLD-PCT
           COMPUTE WS-AVAILABLE-CASH =
               WS-CASH-TOTAL - WS-CHECK-HOLD-TOTAL
           IF WS-AVAILABLE-CASH < 0
               MOVE 0 TO WS-AVAILABLE-CASH
           END-IF.

       COMPUTE-SHIFT-STATS.
           IF WS-SHIFT-HOURS > 0
               COMPUTE WS-TXNS-PER-HOUR =
                   WS-TOTAL-TXN-COUNT / WS-SHIFT-HOURS
           ELSE
               MOVE 0 TO WS-TXNS-PER-HOUR
           END-IF
           IF WS-DEPOSIT-COUNT > 0
               COMPUTE WS-AVG-DEPOSIT =
                   WS-DEPOSITS-TOTAL / WS-DEPOSIT-COUNT
           ELSE
               MOVE 0 TO WS-AVG-DEPOSIT
           END-IF
           IF WS-WITHDRAWAL-COUNT > 0
               COMPUTE WS-AVG-WITHDRAWAL =
                   WS-WITHDRAWALS-TOTAL / WS-WITHDRAWAL-COUNT
           ELSE
               MOVE 0 TO WS-AVG-WITHDRAWAL
           END-IF.

       CHECK-APPROVAL-REQUIRED.
           IF WS-ABS-VARIANCE > WS-OVER-SHORT-THRESHOLD
               MOVE 'Y' TO WS-SUPERVISOR-REQUIRED
           ELSE
               MOVE 'N' TO WS-SUPERVISOR-REQUIRED
           END-IF.

       DISPLAY-BALANCE-REPORT.
           DISPLAY 'TELLER BATCH BALANCE REPORT'
           DISPLAY '==========================='
           DISPLAY 'TELLER: ' WS-TELLER-ID
           DISPLAY 'DATE:   ' WS-SHIFT-DATE
           DISPLAY ' '
           DISPLAY 'DENOMINATION COUNTS:'
           PERFORM VARYING WS-DENOM-IDX FROM 1 BY 1
               UNTIL WS-DENOM-IDX > 8
               DISPLAY '  VALUE: ' WS-DENOM-VALUE(WS-DENOM-IDX)
                   ' COUNT: ' WS-DENOM-COUNT(WS-DENOM-IDX)
                   ' TOTAL: ' WS-DENOM-SUBTOTAL(WS-DENOM-IDX)
           END-PERFORM
           DISPLAY ' '
           DISPLAY 'BILL TOTAL:    ' WS-BILL-TOTAL
           DISPLAY 'COIN TOTAL:    ' WS-COIN-TOTAL
           DISPLAY 'CASH TOTAL:    ' WS-CASH-TOTAL
           DISPLAY 'EXPECTED:      ' WS-EXPECTED-TOTAL
           DISPLAY 'VARIANCE:      ' WS-VARIANCE
           DISPLAY 'STATUS:        ' WS-BALANCE-STATUS
           DISPLAY 'TXN DEPOSITS:  ' WS-DEPOSIT-COUNT
           DISPLAY 'TXN WITHDRAWS: ' WS-WITHDRAWAL-COUNT
           DISPLAY 'TXN CHECKS:    ' WS-CHECK-COUNT
           DISPLAY 'TOTAL TXNS:    ' WS-TOTAL-TXN-COUNT
           DISPLAY 'SUPERVISOR:    ' WS-SUPERVISOR-REQUIRED
           DISPLAY ' '
           DISPLAY 'VARIANCE CATEGORY: ' WS-VARIANCE-CATEGORY
           DISPLAY 'TELLER RATING:     ' WS-TELLER-RATING
           DISPLAY 'CHECK HOLD TOTAL:  ' WS-CHECK-HOLD-TOTAL
           DISPLAY 'AVAILABLE CASH:    ' WS-AVAILABLE-CASH
           DISPLAY 'TXNS PER HOUR:     ' WS-TXNS-PER-HOUR
           DISPLAY 'AVG DEPOSIT:       ' WS-AVG-DEPOSIT
           DISPLAY 'AVG WITHDRAWAL:    ' WS-AVG-WITHDRAWAL.
