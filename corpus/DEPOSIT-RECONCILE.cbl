       IDENTIFICATION DIVISION.
       PROGRAM-ID. DEPOSIT-RECONCILE.
      *================================================================*
      * End-of-Day Deposit Reconciliation                              *
      * Reads teller transaction records, maintains per-teller totals, *
      * detects over/short variances, generates discrepancy report.    *
      *================================================================*

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT TELLER-FILE ASSIGN TO "TELLER.DAT"
               FILE STATUS IS WS-FILE-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  TELLER-FILE.
       01  TELLER-RECORD.
           05  TR-TELLER-ID          PIC 9(4).
           05  TR-TRAN-TYPE          PIC X(2).
           05  TR-TRAN-AMOUNT        PIC 9(9)V99.
           05  TR-TRAN-DESC          PIC X(30).
           05  TR-CHECK-FLAG         PIC X(1).
           05  TR-SEQUENCE-NUM       PIC 9(6).
           05  TR-FILLER             PIC X(26).

       WORKING-STORAGE SECTION.

      *--- File Control ---*
       01  WS-FILE-STATUS            PIC XX.
       01  WS-EOF-FLAG               PIC 9 VALUE 0.

      *--- Teller Totals Array ---*
       01  WS-TELLER-TABLE.
           05  WS-TELLER-ENTRY OCCURS 20.
               10  WT-TELLER-ID      PIC 9(4).
               10  WT-EXPECTED-BAL    PIC S9(11)V99 COMP-3.
               10  WT-ACTUAL-BAL      PIC S9(11)V99 COMP-3.
               10  WT-DEPOSIT-COUNT   PIC S9(5) COMP-3.
               10  WT-CHECK-COUNT     PIC S9(5) COMP-3.
               10  WT-CASH-COUNT      PIC S9(5) COMP-3.
               10  WT-TRAN-TOTAL      PIC S9(11)V99 COMP-3.
               10  WT-ACTIVE-FLAG     PIC 9.

      *--- Processing Accumulators ---*
       01  WS-GRAND-DEPOSITS         PIC S9(13)V99 COMP-3.
       01  WS-GRAND-WITHDRAWALS      PIC S9(13)V99 COMP-3.
       01  WS-GRAND-CHECKS           PIC S9(7) COMP-3.
       01  WS-TOTAL-RECORDS          PIC S9(7) COMP-3.
       01  WS-ERROR-RECORDS          PIC S9(7) COMP-3.
       01  WS-VARIANCE-COUNT         PIC S9(5) COMP-3.

      *--- Work Fields ---*
       01  WS-TELLER-INDEX           PIC S9(3) COMP-3.
       01  WS-FOUND-INDEX            PIC S9(3) COMP-3.
       01  WS-SEARCH-INDEX           PIC S9(3) COMP-3.
       01  WS-VARIANCE-AMT           PIC S9(11)V99 COMP-3.
       01  WS-ABS-VARIANCE           PIC S9(11)V99 COMP-3.
       01  WS-TOLERANCE              PIC S9(5)V99 COMP-3.
       01  WS-CLEAN-DESC             PIC X(30).
       01  WS-CHAR-COUNT             PIC S9(5) COMP-3.
       01  WS-LOOP-IDX               PIC S9(3) COMP-3.

      *--- Display Fields ---*
       01  WS-DISP-AMOUNT            PIC $$$,$$$,$$9.99.
       01  WS-DISP-VARIANCE          PIC -$$$,$$9.99.
       01  WS-DISP-COUNT             PIC Z,ZZ9.
       01  WS-DISP-TELLER            PIC 9(4).

      *--- Report Counters ---*
       01  WS-OVER-COUNT             PIC S9(5) COMP-3.
       01  WS-SHORT-COUNT            PIC S9(5) COMP-3.
       01  WS-BALANCED-COUNT         PIC S9(5) COMP-3.
       01  WS-REPORT-INDEX           PIC S9(3) COMP-3.
       01  WS-ACTIVE-TELLERS         PIC S9(3) COMP-3.

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PROCESS-TRANSACTIONS
           PERFORM 3000-COMPUTE-VARIANCES
           PERFORM 4000-GENERATE-REPORT
           STOP RUN.

       1000-INITIALIZE.
           INITIALIZE WS-TELLER-TABLE
           MOVE 0 TO WS-GRAND-DEPOSITS
           MOVE 0 TO WS-GRAND-WITHDRAWALS
           MOVE 0 TO WS-GRAND-CHECKS
           MOVE 0 TO WS-TOTAL-RECORDS
           MOVE 0 TO WS-ERROR-RECORDS
           MOVE 0 TO WS-VARIANCE-COUNT
           MOVE 0 TO WS-OVER-COUNT
           MOVE 0 TO WS-SHORT-COUNT
           MOVE 0 TO WS-BALANCED-COUNT
           MOVE 0 TO WS-ACTIVE-TELLERS
           MOVE 0.50 TO WS-TOLERANCE
           PERFORM VARYING WS-LOOP-IDX FROM 1 BY 1
               UNTIL WS-LOOP-IDX > 20
               MOVE 0 TO WT-ACTIVE-FLAG(WS-LOOP-IDX)
               MOVE 0 TO WT-TELLER-ID(WS-LOOP-IDX)
               MOVE 0 TO WT-EXPECTED-BAL(WS-LOOP-IDX)
               MOVE 0 TO WT-ACTUAL-BAL(WS-LOOP-IDX)
               MOVE 0 TO WT-DEPOSIT-COUNT(WS-LOOP-IDX)
               MOVE 0 TO WT-CHECK-COUNT(WS-LOOP-IDX)
               MOVE 0 TO WT-CASH-COUNT(WS-LOOP-IDX)
               MOVE 0 TO WT-TRAN-TOTAL(WS-LOOP-IDX)
           END-PERFORM
           OPEN INPUT TELLER-FILE
           MOVE 0 TO WS-EOF-FLAG.

       2000-PROCESS-TRANSACTIONS.
           PERFORM 2100-READ-TELLER-RECORD
           PERFORM UNTIL WS-EOF-FLAG = 1
               PERFORM 2200-VALIDATE-RECORD
               PERFORM 2100-READ-TELLER-RECORD
           END-PERFORM
           CLOSE TELLER-FILE.

       2100-READ-TELLER-RECORD.
           READ TELLER-FILE
               AT END
                   MOVE 1 TO WS-EOF-FLAG
           END-READ
           IF WS-EOF-FLAG = 0
               ADD 1 TO WS-TOTAL-RECORDS
           END-IF.

       2200-VALIDATE-RECORD.
           PERFORM 2300-FIND-TELLER
           IF WS-FOUND-INDEX > 0
               PERFORM 2400-CLEAN-DESCRIPTION
               PERFORM 2500-COUNT-CHECK-ITEMS
               PERFORM 2600-APPLY-TRANSACTION
           ELSE
               ADD 1 TO WS-ERROR-RECORDS
           END-IF.

       2300-FIND-TELLER.
           MOVE 0 TO WS-FOUND-INDEX
           PERFORM VARYING WS-SEARCH-INDEX FROM 1 BY 1
               UNTIL WS-SEARCH-INDEX > 20
               IF WT-TELLER-ID(WS-SEARCH-INDEX) =
                   TR-TELLER-ID
                   MOVE WS-SEARCH-INDEX TO WS-FOUND-INDEX
               END-IF
               IF WT-ACTIVE-FLAG(WS-SEARCH-INDEX) = 0
                   IF WS-FOUND-INDEX = 0
                       MOVE WS-SEARCH-INDEX TO WS-FOUND-INDEX
                       MOVE TR-TELLER-ID TO
                           WT-TELLER-ID(WS-FOUND-INDEX)
                       MOVE 1 TO
                           WT-ACTIVE-FLAG(WS-FOUND-INDEX)
                       ADD 1 TO WS-ACTIVE-TELLERS
                   END-IF
               END-IF
           END-PERFORM.

       2400-CLEAN-DESCRIPTION.
           MOVE TR-TRAN-DESC TO WS-CLEAN-DESC.

       2500-COUNT-CHECK-ITEMS.
           IF TR-CHECK-FLAG = "Y"
               ADD 1 TO WT-CHECK-COUNT(WS-FOUND-INDEX)
               ADD 1 TO WS-GRAND-CHECKS
           ELSE
               ADD 1 TO WT-CASH-COUNT(WS-FOUND-INDEX)
           END-IF.

       2600-APPLY-TRANSACTION.
           EVALUATE TRUE
               WHEN TR-TRAN-TYPE = "DP"
                   ADD TR-TRAN-AMOUNT TO
                       WT-TRAN-TOTAL(WS-FOUND-INDEX)
                   ADD TR-TRAN-AMOUNT TO WS-GRAND-DEPOSITS
                   ADD 1 TO WT-DEPOSIT-COUNT(WS-FOUND-INDEX)
               WHEN TR-TRAN-TYPE = "WD"
                   SUBTRACT TR-TRAN-AMOUNT FROM
                       WT-TRAN-TOTAL(WS-FOUND-INDEX)
                   ADD TR-TRAN-AMOUNT TO WS-GRAND-WITHDRAWALS
               WHEN TR-TRAN-TYPE = "CK"
                   ADD TR-TRAN-AMOUNT TO
                       WT-TRAN-TOTAL(WS-FOUND-INDEX)
                   ADD TR-TRAN-AMOUNT TO WS-GRAND-DEPOSITS
                   ADD 1 TO WT-DEPOSIT-COUNT(WS-FOUND-INDEX)
               WHEN OTHER
                   ADD 1 TO WS-ERROR-RECORDS
           END-EVALUATE.

       3000-COMPUTE-VARIANCES.
           PERFORM VARYING WS-TELLER-INDEX FROM 1 BY 1
               UNTIL WS-TELLER-INDEX > 20
               IF WT-ACTIVE-FLAG(WS-TELLER-INDEX) = 1
                   COMPUTE WS-VARIANCE-AMT =
                       WT-TRAN-TOTAL(WS-TELLER-INDEX)
                       - WT-EXPECTED-BAL(WS-TELLER-INDEX)
                   MOVE WS-VARIANCE-AMT TO WS-ABS-VARIANCE
                   IF WS-ABS-VARIANCE < 0
                       MULTIPLY -1 BY WS-ABS-VARIANCE
                   END-IF
                   IF WS-ABS-VARIANCE > WS-TOLERANCE
                       ADD 1 TO WS-VARIANCE-COUNT
                       IF WS-VARIANCE-AMT > 0
                           ADD 1 TO WS-OVER-COUNT
                       ELSE
                           ADD 1 TO WS-SHORT-COUNT
                       END-IF
                   ELSE
                       ADD 1 TO WS-BALANCED-COUNT
                   END-IF
               END-IF
           END-PERFORM.

       4000-GENERATE-REPORT.
           DISPLAY "========================================"
           DISPLAY "  END-OF-DAY DEPOSIT RECONCILIATION"
           DISPLAY "========================================"
           MOVE WS-TOTAL-RECORDS TO WS-DISP-COUNT
           DISPLAY "TOTAL RECORDS:     " WS-DISP-COUNT
           MOVE WS-GRAND-DEPOSITS TO WS-DISP-AMOUNT
           DISPLAY "TOTAL DEPOSITS:    " WS-DISP-AMOUNT
           MOVE WS-GRAND-WITHDRAWALS TO WS-DISP-AMOUNT
           DISPLAY "TOTAL WITHDRAWALS: " WS-DISP-AMOUNT
           MOVE WS-GRAND-CHECKS TO WS-DISP-COUNT
           DISPLAY "CHECK ITEMS:       " WS-DISP-COUNT
           DISPLAY "----------------------------------------"
           DISPLAY "ACTIVE TELLERS:    " WS-ACTIVE-TELLERS
           DISPLAY "OVER:              " WS-OVER-COUNT
           DISPLAY "SHORT:             " WS-SHORT-COUNT
           DISPLAY "BALANCED:          " WS-BALANCED-COUNT
           DISPLAY "----------------------------------------"
           PERFORM 4100-DETAIL-REPORT
           DISPLAY "========================================"
           DISPLAY "  END OF RECONCILIATION REPORT".

       4100-DETAIL-REPORT.
           PERFORM VARYING WS-REPORT-INDEX FROM 1 BY 1
               UNTIL WS-REPORT-INDEX > 20
               IF WT-ACTIVE-FLAG(WS-REPORT-INDEX) = 1
                   MOVE WT-TELLER-ID(WS-REPORT-INDEX)
                       TO WS-DISP-TELLER
                   DISPLAY "TELLER: " WS-DISP-TELLER
                   MOVE WT-TRAN-TOTAL(WS-REPORT-INDEX)
                       TO WS-DISP-AMOUNT
                   DISPLAY "  TOTAL:     " WS-DISP-AMOUNT
                   MOVE WT-DEPOSIT-COUNT(WS-REPORT-INDEX)
                       TO WS-DISP-COUNT
                   DISPLAY "  DEPOSITS:  " WS-DISP-COUNT
                   MOVE WT-CHECK-COUNT(WS-REPORT-INDEX)
                       TO WS-DISP-COUNT
                   DISPLAY "  CHECKS:    " WS-DISP-COUNT
               END-IF
           END-PERFORM.
