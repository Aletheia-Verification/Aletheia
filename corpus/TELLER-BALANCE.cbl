       IDENTIFICATION DIVISION.
       PROGRAM-ID. TELLER-BALANCE.
      *================================================================*
      * Teller End-of-Day Balancing                                    *
      * Computes net cash position from all transaction types,         *
      * applies adjustments, flags variances for supervisor review.    *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- Teller Identity ---
       01  WS-TELLER-ID              PIC X(8).
       01  WS-BRANCH-CODE            PIC X(6).
       01  WS-BALANCE-DATE           PIC 9(8).
      *--- Cash Drawer Starting Position ---
       01  WS-OPENING-CASH           PIC S9(9)V99 COMP-3.
       01  WS-CLOSING-CASH           PIC S9(9)V99 COMP-3.
       01  WS-EXPECTED-CASH          PIC S9(9)V99 COMP-3.
      *--- Transaction Totals ---
       01  WS-TXN-TOTALS.
           05  WS-CASH-IN-TOTAL      PIC S9(9)V99 COMP-3.
           05  WS-CASH-OUT-TOTAL     PIC S9(9)V99 COMP-3.
           05  WS-CHECK-CASHED       PIC S9(9)V99 COMP-3.
           05  WS-CHECK-DEPOSITED    PIC S9(9)V99 COMP-3.
           05  WS-LOAN-PAYMENTS      PIC S9(9)V99 COMP-3.
           05  WS-MONEY-ORDERS       PIC S9(9)V99 COMP-3.
           05  WS-OFFICIAL-CHECKS    PIC S9(9)V99 COMP-3.
      *--- Transaction Counts ---
       01  WS-TXN-COUNTS.
           05  WS-DEPOSIT-CT         PIC S9(5) COMP-3.
           05  WS-WITHDRAWAL-CT      PIC S9(5) COMP-3.
           05  WS-CHECK-CT           PIC S9(5) COMP-3.
           05  WS-MO-CT              PIC S9(5) COMP-3.
           05  WS-OC-CT              PIC S9(5) COMP-3.
           05  WS-TOTAL-CT           PIC S9(5) COMP-3.
      *--- Variance Analysis ---
       01  WS-VARIANCE               PIC S9(9)V99 COMP-3.
       01  WS-ABS-VARIANCE           PIC S9(9)V99 COMP-3.
       01  WS-VARIANCE-THRESHOLD     PIC S9(5)V99 COMP-3.
       01  WS-VARIANCE-STATUS        PIC 9.
           88  WS-BALANCED            VALUE 1.
           88  WS-SHORT              VALUE 2.
           88  WS-OVER               VALUE 3.
           88  WS-CRITICAL           VALUE 4.
      *--- Supervisor Approval ---
       01  WS-SUPERVISOR-NEEDED      PIC 9.
       01  WS-APPROVAL-LEVEL         PIC 9.
           88  WS-TELLER-APPROVE     VALUE 1.
           88  WS-SUPV-APPROVE       VALUE 2.
           88  WS-MGR-APPROVE        VALUE 3.
      *--- Adjustment Table ---
       01  WS-ADJUST-TABLE.
           05  WS-ADJUST-ENTRY OCCURS 5 TIMES.
               10  WS-ADJUST-CODE    PIC X(4).
               10  WS-ADJUST-AMT     PIC S9(7)V99 COMP-3.
               10  WS-ADJUST-REASON  PIC X(30).
       01  WS-ADJUST-IDX             PIC 9(3).
       01  WS-ADJUST-TOTAL           PIC S9(9)V99 COMP-3.
       01  WS-ADJUST-COUNT           PIC 9(3).
      *--- Display Fields ---
       01  WS-DISP-AMT               PIC -$$$,$$$,$$9.99.
       01  WS-DISP-CT                PIC Z,ZZ9.
       01  WS-DISP-VAR               PIC -$$$,$$9.99.
      *--- Intermediate Calculations ---
       01  WS-NET-CASH-FLOW          PIC S9(11)V99 COMP-3.
       01  WS-WORK-AMOUNT            PIC S9(9)V99 COMP-3.
       01  WS-PERCENT-OFF            PIC S9(3)V9(4) COMP-3.
      *--- String Work Area ---
       01  WS-STATUS-MSG             PIC X(50).
       01  WS-REPORT-LINE            PIC X(80).

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-TXN-TOTALS
           PERFORM 3000-COMPUTE-EXPECTED
           PERFORM 4000-APPLY-ADJUSTMENTS
           PERFORM 5000-ANALYZE-VARIANCE
           PERFORM 6000-DETERMINE-APPROVAL
           PERFORM 7000-DISPLAY-REPORT
           STOP RUN.

       1000-INITIALIZE.
           MOVE "TLR00105" TO WS-TELLER-ID
           MOVE "BR0042" TO WS-BRANCH-CODE
           ACCEPT WS-BALANCE-DATE FROM DATE YYYYMMDD
           MOVE 10000.00 TO WS-OPENING-CASH
           MOVE 9753.47 TO WS-CLOSING-CASH
           MOVE 25.00 TO WS-VARIANCE-THRESHOLD
           MOVE 0 TO WS-ADJUST-TOTAL
           MOVE 0 TO WS-SUPERVISOR-NEEDED
           INITIALIZE WS-TXN-COUNTS
           MOVE 2 TO WS-ADJUST-COUNT
           MOVE "RNDG" TO WS-ADJUST-CODE(1)
           MOVE 0.03 TO WS-ADJUST-AMT(1)
           MOVE "PENNY ROUNDING"
               TO WS-ADJUST-REASON(1)
           MOVE "VOID" TO WS-ADJUST-CODE(2)
           MOVE -15.00 TO WS-ADJUST-AMT(2)
           MOVE "VOIDED MONEY ORDER"
               TO WS-ADJUST-REASON(2).

       2000-LOAD-TXN-TOTALS.
           MOVE 25340.00 TO WS-CASH-IN-TOTAL
           MOVE 18750.00 TO WS-CASH-OUT-TOTAL
           MOVE 4200.00 TO WS-CHECK-CASHED
           MOVE 12500.00 TO WS-CHECK-DEPOSITED
           MOVE 3100.00 TO WS-LOAN-PAYMENTS
           MOVE 750.00 TO WS-MONEY-ORDERS
           MOVE 1200.00 TO WS-OFFICIAL-CHECKS
           MOVE 47 TO WS-DEPOSIT-CT
           MOVE 32 TO WS-WITHDRAWAL-CT
           MOVE 15 TO WS-CHECK-CT
           MOVE 3 TO WS-MO-CT
           MOVE 2 TO WS-OC-CT
           COMPUTE WS-TOTAL-CT =
               WS-DEPOSIT-CT + WS-WITHDRAWAL-CT
               + WS-CHECK-CT + WS-MO-CT + WS-OC-CT.

       3000-COMPUTE-EXPECTED.
           COMPUTE WS-NET-CASH-FLOW =
               WS-CASH-IN-TOTAL - WS-CASH-OUT-TOTAL
               - WS-CHECK-CASHED
               - WS-MONEY-ORDERS - WS-OFFICIAL-CHECKS
               + WS-LOAN-PAYMENTS
           COMPUTE WS-EXPECTED-CASH =
               WS-OPENING-CASH + WS-NET-CASH-FLOW.

       4000-APPLY-ADJUSTMENTS.
           PERFORM VARYING WS-ADJUST-IDX FROM 1 BY 1
               UNTIL WS-ADJUST-IDX > WS-ADJUST-COUNT
               ADD WS-ADJUST-AMT(WS-ADJUST-IDX)
                   TO WS-ADJUST-TOTAL
           END-PERFORM
           ADD WS-ADJUST-TOTAL TO WS-EXPECTED-CASH.

       5000-ANALYZE-VARIANCE.
           COMPUTE WS-VARIANCE =
               WS-CLOSING-CASH - WS-EXPECTED-CASH
           IF WS-VARIANCE < 0
               COMPUTE WS-ABS-VARIANCE =
                   WS-VARIANCE * -1
           ELSE
               MOVE WS-VARIANCE TO WS-ABS-VARIANCE
           END-IF
           EVALUATE TRUE
               WHEN WS-ABS-VARIANCE = 0
                   MOVE 1 TO WS-VARIANCE-STATUS
               WHEN WS-VARIANCE < 0
                   MOVE 2 TO WS-VARIANCE-STATUS
               WHEN WS-VARIANCE > 0
                   MOVE 3 TO WS-VARIANCE-STATUS
           END-EVALUATE
           IF WS-ABS-VARIANCE > WS-VARIANCE-THRESHOLD
               MOVE 4 TO WS-VARIANCE-STATUS
           END-IF
           IF WS-EXPECTED-CASH NOT = 0
               COMPUTE WS-PERCENT-OFF ROUNDED =
                   (WS-ABS-VARIANCE / WS-EXPECTED-CASH)
                   * 100
           END-IF.

       6000-DETERMINE-APPROVAL.
           EVALUATE TRUE
               WHEN WS-BALANCED
                   MOVE 1 TO WS-APPROVAL-LEVEL
               WHEN WS-ABS-VARIANCE <= 10.00
                   MOVE 1 TO WS-APPROVAL-LEVEL
               WHEN WS-ABS-VARIANCE <= WS-VARIANCE-THRESHOLD
                   MOVE 2 TO WS-APPROVAL-LEVEL
                   MOVE 1 TO WS-SUPERVISOR-NEEDED
               WHEN OTHER
                   MOVE 3 TO WS-APPROVAL-LEVEL
                   MOVE 1 TO WS-SUPERVISOR-NEEDED
           END-EVALUATE.

       7000-DISPLAY-REPORT.
           DISPLAY "========================================"
           DISPLAY "   TELLER BALANCING REPORT"
           DISPLAY "========================================"
           DISPLAY "TELLER: " WS-TELLER-ID
               " BRANCH: " WS-BRANCH-CODE
           DISPLAY "--- TRANSACTION SUMMARY ---"
           MOVE WS-TOTAL-CT TO WS-DISP-CT
           DISPLAY "TOTAL TRANSACTIONS: " WS-DISP-CT
           MOVE WS-CASH-IN-TOTAL TO WS-DISP-AMT
           DISPLAY "CASH IN:    " WS-DISP-AMT
           MOVE WS-CASH-OUT-TOTAL TO WS-DISP-AMT
           DISPLAY "CASH OUT:   " WS-DISP-AMT
           DISPLAY "--- BALANCE ---"
           MOVE WS-OPENING-CASH TO WS-DISP-AMT
           DISPLAY "OPENING:    " WS-DISP-AMT
           MOVE WS-EXPECTED-CASH TO WS-DISP-AMT
           DISPLAY "EXPECTED:   " WS-DISP-AMT
           MOVE WS-CLOSING-CASH TO WS-DISP-AMT
           DISPLAY "ACTUAL:     " WS-DISP-AMT
           MOVE WS-VARIANCE TO WS-DISP-VAR
           DISPLAY "VARIANCE:   " WS-DISP-VAR
           EVALUATE TRUE
               WHEN WS-BALANCED
                   MOVE "BALANCED" TO WS-STATUS-MSG
               WHEN WS-SHORT
                   MOVE "SHORT" TO WS-STATUS-MSG
               WHEN WS-OVER
                   MOVE "OVER" TO WS-STATUS-MSG
               WHEN WS-CRITICAL
                   MOVE "CRITICAL VARIANCE"
                       TO WS-STATUS-MSG
           END-EVALUATE
           DISPLAY "STATUS:     " WS-STATUS-MSG
           IF WS-SUPERVISOR-NEEDED = 1
               DISPLAY "*** SUPERVISOR APPROVAL REQUIRED ***"
           END-IF
           DISPLAY "========================================".
