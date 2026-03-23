       IDENTIFICATION DIVISION.
       PROGRAM-ID. EMBEDDED-SQL-BATCH.
      *================================================================*
      * DB2 BATCH ACCOUNT RECONCILIATION                               *
      * Uses EXEC SQL for cursor-based processing, balance adjustments *
      * error handling with SQLCODE checks, batch commit frequency,    *
      * and running totals for reconciliation.                         *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- SQL Communication Area ---
       01  WS-SQLCODE                  PIC S9(9) COMP-3.
      *--- Host Variables ---
       01  WS-HOST-ACCT-ID            PIC X(10).
       01  WS-HOST-ACCT-NAME          PIC X(30).
       01  WS-HOST-DB-BALANCE         PIC S9(9)V99 COMP-3.
       01  WS-HOST-LEDGER-BALANCE     PIC S9(9)V99 COMP-3.
       01  WS-HOST-STATUS             PIC X(2).
       01  WS-HOST-LAST-DATE          PIC X(10).
      *--- Reconciliation Fields ---
       01  WS-VARIANCE                PIC S9(9)V99 COMP-3.
       01  WS-ABS-VARIANCE            PIC S9(9)V99 COMP-3.
       01  WS-ADJUSTMENT              PIC S9(9)V99 COMP-3.
       01  WS-TOLERANCE               PIC S9(5)V99 COMP-3.
       01  WS-NEW-BALANCE             PIC S9(9)V99 COMP-3.
      *--- Batch Control ---
       01  WS-BATCH-SIZE              PIC 9(5).
       01  WS-COMMIT-FREQUENCY        PIC 9(5).
       01  WS-RECORDS-SINCE-COMMIT    PIC 9(5).
       01  WS-TOTAL-COMMITS           PIC 9(5).
      *--- Running Totals ---
       01  WS-TOTAL-DB-BALANCE        PIC S9(11)V99 COMP-3.
       01  WS-TOTAL-LEDGER-BALANCE    PIC S9(11)V99 COMP-3.
       01  WS-TOTAL-ADJUSTMENTS       PIC S9(11)V99 COMP-3.
       01  WS-TOTAL-VARIANCE          PIC S9(11)V99 COMP-3.
      *--- Counters ---
       01  WS-RECORDS-PROCESSED       PIC 9(7).
       01  WS-RECORDS-MATCHED         PIC 9(7).
       01  WS-RECORDS-ADJUSTED        PIC 9(7).
       01  WS-RECORDS-ERRORED         PIC 9(7).
       01  WS-CURSOR-OPEN             PIC X(1).
      *--- Processing Flags ---
       01  WS-EOF-FLAG                PIC X(1).
       01  WS-ERROR-FLAG              PIC X(1).
       01  WS-RECON-STATUS            PIC X(15).

       PROCEDURE DIVISION.
       MAIN-PROGRAM.
           PERFORM INITIALIZE-BATCH
           PERFORM OPEN-CURSOR THRU
                   OPEN-CURSOR-EXIT
           PERFORM PROCESS-RECORDS THRU
                   PROCESS-RECORDS-EXIT
           PERFORM CLOSE-CURSOR THRU
                   CLOSE-CURSOR-EXIT
           PERFORM FINAL-COMMIT
           PERFORM DISPLAY-SUMMARY
           STOP RUN.

       INITIALIZE-BATCH.
           MOVE 0 TO WS-RECORDS-PROCESSED
           MOVE 0 TO WS-RECORDS-MATCHED
           MOVE 0 TO WS-RECORDS-ADJUSTED
           MOVE 0 TO WS-RECORDS-ERRORED
           MOVE 0 TO WS-TOTAL-DB-BALANCE
           MOVE 0 TO WS-TOTAL-LEDGER-BALANCE
           MOVE 0 TO WS-TOTAL-ADJUSTMENTS
           MOVE 0 TO WS-TOTAL-VARIANCE
           MOVE 0 TO WS-RECORDS-SINCE-COMMIT
           MOVE 0 TO WS-TOTAL-COMMITS
           MOVE 500 TO WS-COMMIT-FREQUENCY
           MOVE 0.01 TO WS-TOLERANCE
           MOVE 'N' TO WS-EOF-FLAG
           MOVE 'N' TO WS-ERROR-FLAG
           MOVE 'N' TO WS-CURSOR-OPEN
           MOVE 'PENDING' TO WS-RECON-STATUS.

       OPEN-CURSOR.
           EXEC SQL
               DECLARE ACCT_CURSOR CURSOR FOR
               SELECT ACCT_ID, ACCT_NAME, DB_BALANCE,
                      LEDGER_BALANCE, ACCT_STATUS, LAST_TXN_DATE
               FROM ACCOUNT_MASTER
               WHERE ACCT_STATUS = 'AC'
               ORDER BY ACCT_ID
           END-EXEC
           EXEC SQL
               OPEN ACCT_CURSOR
           END-EXEC
           IF WS-SQLCODE = 0
               MOVE 'Y' TO WS-CURSOR-OPEN
           ELSE
               MOVE 'Y' TO WS-ERROR-FLAG
               DISPLAY 'CURSOR OPEN ERROR: ' WS-SQLCODE
           END-IF.

       OPEN-CURSOR-EXIT.
           EXIT.

       PROCESS-RECORDS.
           PERFORM UNTIL WS-EOF-FLAG = 'Y'
               PERFORM FETCH-NEXT-RECORD
               IF WS-EOF-FLAG = 'N'
                   ADD 1 TO WS-RECORDS-PROCESSED
                   PERFORM RECONCILE-RECORD
                   PERFORM CHECK-COMMIT-NEEDED
               END-IF
           END-PERFORM.

       PROCESS-RECORDS-EXIT.
           EXIT.

       FETCH-NEXT-RECORD.
           EXEC SQL
               FETCH ACCT_CURSOR
               INTO :WS-HOST-ACCT-ID,
                    :WS-HOST-ACCT-NAME,
                    :WS-HOST-DB-BALANCE,
                    :WS-HOST-LEDGER-BALANCE,
                    :WS-HOST-STATUS,
                    :WS-HOST-LAST-DATE
           END-EXEC
           IF WS-SQLCODE = 100
               MOVE 'Y' TO WS-EOF-FLAG
           ELSE
               IF WS-SQLCODE NOT = 0
                   MOVE 'Y' TO WS-ERROR-FLAG
                   MOVE 'Y' TO WS-EOF-FLAG
                   DISPLAY 'FETCH ERROR: ' WS-SQLCODE
               END-IF
           END-IF.

       RECONCILE-RECORD.
           ADD WS-HOST-DB-BALANCE TO WS-TOTAL-DB-BALANCE
           ADD WS-HOST-LEDGER-BALANCE TO WS-TOTAL-LEDGER-BALANCE
           COMPUTE WS-VARIANCE =
               WS-HOST-DB-BALANCE - WS-HOST-LEDGER-BALANCE
           IF WS-VARIANCE < 0
               COMPUTE WS-ABS-VARIANCE = WS-VARIANCE * -1
           ELSE
               MOVE WS-VARIANCE TO WS-ABS-VARIANCE
           END-IF
           ADD WS-VARIANCE TO WS-TOTAL-VARIANCE
           IF WS-ABS-VARIANCE <= WS-TOLERANCE
               ADD 1 TO WS-RECORDS-MATCHED
           ELSE
               PERFORM APPLY-ADJUSTMENT
           END-IF.

       APPLY-ADJUSTMENT.
           COMPUTE WS-ADJUSTMENT = WS-VARIANCE * -1
           COMPUTE WS-NEW-BALANCE =
               WS-HOST-DB-BALANCE + WS-ADJUSTMENT
           EXEC SQL
               UPDATE ACCOUNT_MASTER
               SET DB_BALANCE = :WS-NEW-BALANCE,
                   LAST_TXN_DATE = CURRENT DATE
               WHERE ACCT_ID = :WS-HOST-ACCT-ID
           END-EXEC
           IF WS-SQLCODE = 0
               ADD 1 TO WS-RECORDS-ADJUSTED
               ADD WS-ADJUSTMENT TO WS-TOTAL-ADJUSTMENTS
           ELSE
               ADD 1 TO WS-RECORDS-ERRORED
               DISPLAY 'UPDATE ERROR: ' WS-HOST-ACCT-ID
                       ' SQLCODE: ' WS-SQLCODE
           END-IF.

       CHECK-COMMIT-NEEDED.
           ADD 1 TO WS-RECORDS-SINCE-COMMIT
           IF WS-RECORDS-SINCE-COMMIT >= WS-COMMIT-FREQUENCY
               EXEC SQL
                   COMMIT
               END-EXEC
               ADD 1 TO WS-TOTAL-COMMITS
               MOVE 0 TO WS-RECORDS-SINCE-COMMIT
           END-IF.

       CLOSE-CURSOR.
           IF WS-CURSOR-OPEN = 'Y'
               EXEC SQL
                   CLOSE ACCT_CURSOR
               END-EXEC
               MOVE 'N' TO WS-CURSOR-OPEN
           END-IF.

       CLOSE-CURSOR-EXIT.
           EXIT.

       FINAL-COMMIT.
           IF WS-RECORDS-SINCE-COMMIT > 0
               EXEC SQL
                   COMMIT
               END-EXEC
               ADD 1 TO WS-TOTAL-COMMITS
           END-IF
           IF WS-ERROR-FLAG = 'N'
               MOVE 'RECONCILED' TO WS-RECON-STATUS
           ELSE
               MOVE 'ERRORS FOUND' TO WS-RECON-STATUS
           END-IF.

       DISPLAY-SUMMARY.
           DISPLAY 'DB2 BATCH RECONCILIATION SUMMARY'
           DISPLAY '================================='
           DISPLAY 'RECORDS PROCESSED: ' WS-RECORDS-PROCESSED
           DISPLAY 'RECORDS MATCHED:   ' WS-RECORDS-MATCHED
           DISPLAY 'RECORDS ADJUSTED:  ' WS-RECORDS-ADJUSTED
           DISPLAY 'RECORDS ERRORED:   ' WS-RECORDS-ERRORED
           DISPLAY 'TOTAL DB BAL:      ' WS-TOTAL-DB-BALANCE
           DISPLAY 'TOTAL LEDGER BAL:  ' WS-TOTAL-LEDGER-BALANCE
           DISPLAY 'TOTAL ADJUSTMENTS: ' WS-TOTAL-ADJUSTMENTS
           DISPLAY 'TOTAL VARIANCE:    ' WS-TOTAL-VARIANCE
           DISPLAY 'TOTAL COMMITS:     ' WS-TOTAL-COMMITS
           DISPLAY 'STATUS:            ' WS-RECON-STATUS.
