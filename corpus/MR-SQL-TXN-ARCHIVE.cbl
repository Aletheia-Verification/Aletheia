       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-SQL-TXN-ARCHIVE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-SQLCODE              PIC S9(9) COMP-3.
       01 WS-ARCHIVE-PARAMS.
           05 WS-CUTOFF-DATE      PIC X(10).
           05 WS-BATCH-SIZE       PIC 9(5) VALUE 1000.
       01 WS-TXN-RECORD.
           05 WS-TXN-ID           PIC X(20).
           05 WS-TXN-DATE         PIC X(10).
           05 WS-TXN-ACCT         PIC X(12).
           05 WS-TXN-AMT          PIC S9(9)V99 COMP-3.
           05 WS-TXN-TYPE         PIC X(4).
       01 WS-COUNTERS.
           05 WS-ROWS-READ        PIC 9(7).
           05 WS-ROWS-ARCHIVED    PIC 9(7).
           05 WS-ROWS-DELETED     PIC 9(7).
           05 WS-ERRORS           PIC 9(5).
       01 WS-EOF-FLAG             PIC X VALUE 'N'.
           88 WS-EOF              VALUE 'Y'.
       01 WS-ARCHIVE-STATUS       PIC X(12).
       01 WS-RUN-DATE             PIC 9(8).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-OPEN-CURSOR
           PERFORM 3000-ARCHIVE-LOOP UNTIL WS-EOF
           PERFORM 4000-CLOSE-CURSOR
           PERFORM 5000-DELETE-ARCHIVED
           PERFORM 6000-REPORT
           STOP RUN.
       1000-INIT.
           MOVE 0 TO WS-ROWS-READ
           MOVE 0 TO WS-ROWS-ARCHIVED
           MOVE 0 TO WS-ROWS-DELETED
           MOVE 0 TO WS-ERRORS
           ACCEPT WS-RUN-DATE FROM DATE YYYYMMDD.
       2000-OPEN-CURSOR.
           EXEC SQL
               DECLARE ARCHIVE_CUR CURSOR FOR
               SELECT TXN_ID, TXN_DATE, ACCT_NUM,
                      TXN_AMOUNT, TXN_TYPE
               FROM TRANSACTION_HISTORY
               WHERE TXN_DATE < :WS-CUTOFF-DATE
               ORDER BY TXN_DATE
           END-EXEC
           EXEC SQL
               OPEN ARCHIVE_CUR
           END-EXEC.
       3000-ARCHIVE-LOOP.
           EXEC SQL
               FETCH ARCHIVE_CUR
               INTO :WS-TXN-ID, :WS-TXN-DATE,
                    :WS-TXN-ACCT, :WS-TXN-AMT,
                    :WS-TXN-TYPE
           END-EXEC
           IF WS-SQLCODE = 100
               SET WS-EOF TO TRUE
           ELSE
               IF WS-SQLCODE = 0
                   ADD 1 TO WS-ROWS-READ
                   PERFORM 3100-INSERT-ARCHIVE
               ELSE
                   ADD 1 TO WS-ERRORS
               END-IF
           END-IF.
       3100-INSERT-ARCHIVE.
           EXEC SQL
               INSERT INTO TRANSACTION_ARCHIVE
               (TXN_ID, TXN_DATE, ACCT_NUM,
                TXN_AMOUNT, TXN_TYPE, ARCHIVE_DATE)
               VALUES
               (:WS-TXN-ID, :WS-TXN-DATE,
                :WS-TXN-ACCT, :WS-TXN-AMT,
                :WS-TXN-TYPE, CURRENT DATE)
           END-EXEC
           IF WS-SQLCODE = 0
               ADD 1 TO WS-ROWS-ARCHIVED
           ELSE
               ADD 1 TO WS-ERRORS
           END-IF.
       4000-CLOSE-CURSOR.
           EXEC SQL
               CLOSE ARCHIVE_CUR
           END-EXEC
           EXEC SQL COMMIT END-EXEC.
       5000-DELETE-ARCHIVED.
           EXEC SQL
               DELETE FROM TRANSACTION_HISTORY
               WHERE TXN_DATE < :WS-CUTOFF-DATE
           END-EXEC
           IF WS-SQLCODE >= 0
               MOVE WS-ROWS-ARCHIVED TO WS-ROWS-DELETED
               MOVE 'COMPLETE    ' TO WS-ARCHIVE-STATUS
           ELSE
               MOVE 'DEL-FAILED  ' TO WS-ARCHIVE-STATUS
               ADD 1 TO WS-ERRORS
           END-IF
           EXEC SQL COMMIT END-EXEC.
       6000-REPORT.
           DISPLAY 'TRANSACTION ARCHIVE REPORT'
           DISPLAY '=========================='
           DISPLAY 'RUN DATE:  ' WS-RUN-DATE
           DISPLAY 'CUTOFF:    ' WS-CUTOFF-DATE
           DISPLAY 'READ:      ' WS-ROWS-READ
           DISPLAY 'ARCHIVED:  ' WS-ROWS-ARCHIVED
           DISPLAY 'DELETED:   ' WS-ROWS-DELETED
           DISPLAY 'ERRORS:    ' WS-ERRORS
           DISPLAY 'STATUS:    ' WS-ARCHIVE-STATUS.
