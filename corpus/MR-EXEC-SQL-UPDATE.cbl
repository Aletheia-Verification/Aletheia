       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-EXEC-SQL-UPDATE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-SQLCODE                  PIC S9(9) COMP-3.
       01 WS-ACCT-ID                 PIC X(12).
       01 WS-ACCT-BAL                PIC S9(9)V99 COMP-3.
       01 WS-INT-RATE                PIC S9(3)V9(6) COMP-3.
       01 WS-INT-AMOUNT              PIC S9(7)V99 COMP-3.
       01 WS-NEW-BAL                 PIC S9(9)V99 COMP-3.
       01 WS-POST-DATE               PIC X(10).
       01 WS-ACCT-STATUS             PIC X(2).
       01 WS-ACCT-TYPE               PIC X(1).
           88 WS-CHECKING            VALUE 'C'.
           88 WS-SAVINGS             VALUE 'S'.
           88 WS-MONEY-MKT           VALUE 'M'.
       01 WS-COUNTERS.
           05 WS-PROCESSED           PIC S9(5) COMP-3.
           05 WS-UPDATED             PIC S9(5) COMP-3.
           05 WS-SKIPPED             PIC S9(5) COMP-3.
           05 WS-ERRORS              PIC S9(5) COMP-3.
       01 WS-TOTAL-INTEREST          PIC S9(11)V99 COMP-3.
       01 WS-DAILY-RATE              PIC S9(1)V9(10) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-FETCH-ACCOUNT
           IF WS-SQLCODE = 0
               PERFORM 3000-CALC-INTEREST
               PERFORM 4000-POST-INTEREST
               PERFORM 5000-COMMIT-BATCH
           END-IF
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-PROCESSED
           MOVE 0 TO WS-UPDATED
           MOVE 0 TO WS-SKIPPED
           MOVE 0 TO WS-ERRORS
           MOVE 0 TO WS-TOTAL-INTEREST.
       2000-FETCH-ACCOUNT.
           EXEC SQL
               SELECT ACCT_BAL, INT_RATE, ACCT_STATUS,
                      ACCT_TYPE
               INTO :WS-ACCT-BAL,
                    :WS-INT-RATE,
                    :WS-ACCT-STATUS,
                    :WS-ACCT-TYPE
               FROM ACCOUNT_MASTER
               WHERE ACCT_ID = :WS-ACCT-ID
           END-EXEC
           IF WS-SQLCODE NOT = 0
               DISPLAY 'FETCH ERROR: ' WS-SQLCODE
               ADD 1 TO WS-ERRORS
           ELSE
               ADD 1 TO WS-PROCESSED
           END-IF.
       3000-CALC-INTEREST.
           IF WS-ACCT-STATUS NOT = 'AC'
               ADD 1 TO WS-SKIPPED
           ELSE
               COMPUTE WS-DAILY-RATE =
                   WS-INT-RATE / 360
               COMPUTE WS-INT-AMOUNT =
                   WS-ACCT-BAL * WS-DAILY-RATE
               EVALUATE TRUE
                   WHEN WS-SAVINGS
                       IF WS-INT-AMOUNT < 0.01
                           MOVE 0 TO WS-INT-AMOUNT
                       END-IF
                   WHEN WS-MONEY-MKT
                       COMPUTE WS-INT-AMOUNT =
                           WS-INT-AMOUNT * 1.10
                   WHEN OTHER
                       MOVE 0 TO WS-INT-AMOUNT
               END-EVALUATE
               COMPUTE WS-NEW-BAL =
                   WS-ACCT-BAL + WS-INT-AMOUNT
               ADD WS-INT-AMOUNT TO WS-TOTAL-INTEREST
           END-IF.
       4000-POST-INTEREST.
           IF WS-INT-AMOUNT > 0
               EXEC SQL
                   UPDATE ACCOUNT_MASTER
                   SET ACCT_BAL = :WS-NEW-BAL,
                       LAST_INT_DATE = :WS-POST-DATE
                   WHERE ACCT_ID = :WS-ACCT-ID
               END-EXEC
               IF WS-SQLCODE = 0
                   ADD 1 TO WS-UPDATED
               ELSE
                   ADD 1 TO WS-ERRORS
                   DISPLAY 'UPDATE ERROR: ' WS-SQLCODE
               END-IF
           END-IF.
       5000-COMMIT-BATCH.
           EXEC SQL
               COMMIT
           END-EXEC.
       6000-DISPLAY-RESULTS.
           DISPLAY 'INTEREST POSTING REPORT'
           DISPLAY '======================='
           DISPLAY 'ACCOUNT:        ' WS-ACCT-ID
           DISPLAY 'OLD BALANCE:    ' WS-ACCT-BAL
           DISPLAY 'INTEREST:       ' WS-INT-AMOUNT
           DISPLAY 'NEW BALANCE:    ' WS-NEW-BAL
           DISPLAY 'PROCESSED:      ' WS-PROCESSED
           DISPLAY 'UPDATED:        ' WS-UPDATED
           DISPLAY 'SKIPPED:        ' WS-SKIPPED
           DISPLAY 'ERRORS:         ' WS-ERRORS
           DISPLAY 'TOTAL INTEREST: ' WS-TOTAL-INTEREST.
