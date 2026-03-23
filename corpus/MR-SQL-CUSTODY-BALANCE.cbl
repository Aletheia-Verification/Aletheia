       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-SQL-CUSTODY-BALANCE.
      *---------------------------------------------------------------
      * MANUAL REVIEW: Contains EXEC SQL for custody account
      * balance reconciliation against DB2 positions.
      *---------------------------------------------------------------

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01 WS-SQLCODE                   PIC S9(9) COMP-3.

       01 WS-POSITION-DATA.
           05 WS-ACCT-ID              PIC X(12).
           05 WS-CUSIP                PIC X(9).
           05 WS-POSITION-QTY         PIC S9(11)V99 COMP-3.
           05 WS-SETTLE-QTY           PIC S9(11)V99 COMP-3.
           05 WS-PENDING-QTY          PIC S9(11)V99 COMP-3.
           05 WS-MARKET-PRICE         PIC S9(7)V9(4) COMP-3.
           05 WS-MARKET-VALUE         PIC S9(13)V99 COMP-3.

       01 WS-RECON-DATA.
           05 WS-EXT-QTY              PIC S9(11)V99 COMP-3.
           05 WS-VARIANCE             PIC S9(11)V99 COMP-3.
           05 WS-ABS-VARIANCE         PIC S9(11)V99 COMP-3.
           05 WS-TOLERANCE            PIC S9(5)V99 COMP-3
               VALUE 0.01.

       01 WS-EOF-FLAG                 PIC X VALUE 'N'.
           88 WS-EOF                   VALUE 'Y'.

       01 WS-FILTER-ACCT             PIC X(12) VALUE SPACES.

       01 WS-COUNTERS.
           05 WS-TOTAL-POSITIONS      PIC S9(7) COMP-3 VALUE 0.
           05 WS-MATCHED              PIC S9(7) COMP-3 VALUE 0.
           05 WS-BREAKS               PIC S9(7) COMP-3 VALUE 0.
           05 WS-SQL-ERRORS           PIC S9(7) COMP-3 VALUE 0.

       01 WS-TOTALS.
           05 WS-TOT-POSITION-VAL     PIC S9(15)V99 COMP-3
               VALUE 0.
           05 WS-TOT-VARIANCE-VAL     PIC S9(13)V99 COMP-3
               VALUE 0.

       01 WS-DETAIL-BUF               PIC X(60).
       01 WS-DETAIL-PTR               PIC 9(3).
       01 WS-CUSIP-TALLY              PIC 9(3).

       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-OPEN-CURSOR
           IF WS-SQLCODE = 0
               PERFORM 3000-FETCH-LOOP
                   UNTIL WS-EOF
               PERFORM 4000-CLOSE-CURSOR
           ELSE
               DISPLAY 'CURSOR OPEN FAILED: ' WS-SQLCODE
           END-IF
           PERFORM 5000-GENERATE-SUMMARY
           STOP RUN.

       1000-INITIALIZE.
           MOVE 'N' TO WS-EOF-FLAG
           MOVE 0 TO WS-TOTAL-POSITIONS
           MOVE 0 TO WS-MATCHED
           MOVE 0 TO WS-BREAKS
           MOVE 0 TO WS-SQL-ERRORS.

       2000-OPEN-CURSOR.
           EXEC SQL
               DECLARE POSITION_CURSOR CURSOR FOR
               SELECT ACCOUNT_ID,
                      CUSIP,
                      POSITION_QTY,
                      SETTLED_QTY,
                      PENDING_QTY,
                      MARKET_PRICE
               FROM CUSTODY_POSITIONS
               WHERE ACCOUNT_ID LIKE :WS-FILTER-ACCT
                 AND POSITION_QTY <> 0
               ORDER BY ACCOUNT_ID, CUSIP
           END-EXEC
           EXEC SQL
               OPEN POSITION_CURSOR
           END-EXEC
           MOVE SQLCODE TO WS-SQLCODE.

       3000-FETCH-LOOP.
           EXEC SQL
               FETCH POSITION_CURSOR
               INTO :WS-ACCT-ID,
                    :WS-CUSIP,
                    :WS-POSITION-QTY,
                    :WS-SETTLE-QTY,
                    :WS-PENDING-QTY,
                    :WS-MARKET-PRICE
           END-EXEC
           MOVE SQLCODE TO WS-SQLCODE
           IF WS-SQLCODE = 100
               MOVE 'Y' TO WS-EOF-FLAG
           ELSE
               IF WS-SQLCODE = 0
                   ADD 1 TO WS-TOTAL-POSITIONS
                   PERFORM 3100-RECONCILE-POSITION
               ELSE
                   ADD 1 TO WS-SQL-ERRORS
               END-IF
           END-IF.

       3100-RECONCILE-POSITION.
           COMPUTE WS-MARKET-VALUE =
               WS-POSITION-QTY * WS-MARKET-PRICE
           ADD WS-MARKET-VALUE TO WS-TOT-POSITION-VAL
           COMPUTE WS-EXT-QTY =
               WS-SETTLE-QTY + WS-PENDING-QTY
           COMPUTE WS-VARIANCE =
               WS-POSITION-QTY - WS-EXT-QTY
           IF WS-VARIANCE < 0
               COMPUTE WS-ABS-VARIANCE = 0 - WS-VARIANCE
           ELSE
               MOVE WS-VARIANCE TO WS-ABS-VARIANCE
           END-IF
           IF WS-ABS-VARIANCE <= WS-TOLERANCE
               ADD 1 TO WS-MATCHED
           ELSE
               ADD 1 TO WS-BREAKS
               COMPUTE WS-TOT-VARIANCE-VAL =
                   WS-TOT-VARIANCE-VAL +
                   (WS-VARIANCE * WS-MARKET-PRICE)
               MOVE SPACES TO WS-DETAIL-BUF
               MOVE 1 TO WS-DETAIL-PTR
               STRING 'BREAK: ' WS-ACCT-ID '/'
                   WS-CUSIP
                   DELIMITED BY SIZE
                   INTO WS-DETAIL-BUF
                   WITH POINTER WS-DETAIL-PTR
               END-STRING
               MOVE 0 TO WS-CUSIP-TALLY
               INSPECT WS-CUSIP
                   TALLYING WS-CUSIP-TALLY FOR ALL '0'
               DISPLAY WS-DETAIL-BUF
           END-IF.

       4000-CLOSE-CURSOR.
           EXEC SQL
               CLOSE POSITION_CURSOR
           END-EXEC.

       5000-GENERATE-SUMMARY.
           DISPLAY '=== CUSTODY BALANCE RECON ==='
           DISPLAY 'TOTAL POSITIONS:  ' WS-TOTAL-POSITIONS
           DISPLAY 'MATCHED:          ' WS-MATCHED
           DISPLAY 'BREAKS:           ' WS-BREAKS
           DISPLAY 'SQL ERRORS:       ' WS-SQL-ERRORS
           DISPLAY 'TOTAL POSITION $: '
               WS-TOT-POSITION-VAL
           DISPLAY 'TOTAL VARIANCE $: '
               WS-TOT-VARIANCE-VAL.
