       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-EXEC-SQL-CURSOR.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-SQLCODE                  PIC S9(9) COMP-3.
       01 WS-ACCT-DATA.
           05 WS-ACCT-ID             PIC X(12).
           05 WS-ACCT-NAME           PIC X(30).
           05 WS-ACCT-BAL            PIC S9(9)V99 COMP-3.
           05 WS-ACCT-STATUS         PIC X(2).
           05 WS-LAST-TXN-DATE       PIC X(10).
       01 WS-RECON-FIELDS.
           05 WS-EXPECTED-BAL        PIC S9(9)V99 COMP-3.
           05 WS-VARIANCE            PIC S9(9)V99 COMP-3.
           05 WS-ABS-VARIANCE        PIC S9(9)V99 COMP-3.
           05 WS-TOLERANCE           PIC S9(5)V99 COMP-3
               VALUE 0.01.
       01 WS-COUNTERS.
           05 WS-TOTAL-READ          PIC S9(5) COMP-3.
           05 WS-MATCHED             PIC S9(5) COMP-3.
           05 WS-MISMATCHED          PIC S9(5) COMP-3.
           05 WS-ERRORS              PIC S9(5) COMP-3.
       01 WS-EOF-FLAG                PIC X VALUE 'N'.
           88 WS-EOF                  VALUE 'Y'.
       01 WS-PROCESS-FLAG            PIC X VALUE 'Y'.
           88 WS-CONTINUE             VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-OPEN-CURSOR
           IF WS-CONTINUE
               PERFORM 3000-FETCH-LOOP UNTIL WS-EOF
               PERFORM 4000-CLOSE-CURSOR
           END-IF
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-READ
           MOVE 0 TO WS-MATCHED
           MOVE 0 TO WS-MISMATCHED
           MOVE 0 TO WS-ERRORS
           MOVE 'N' TO WS-EOF-FLAG.
       2000-OPEN-CURSOR.
           EXEC SQL
               DECLARE ACCT_CURSOR CURSOR FOR
               SELECT ACCT_ID, ACCT_NAME, BALANCE,
                      STATUS, LAST_TXN_DATE
               FROM ACCOUNT_MASTER
               WHERE STATUS = 'AC'
               ORDER BY ACCT_ID
           END-EXEC
           EXEC SQL
               OPEN ACCT_CURSOR
           END-EXEC
           IF WS-SQLCODE NOT = 0
               DISPLAY 'CURSOR OPEN ERROR: ' WS-SQLCODE
               MOVE 'N' TO WS-PROCESS-FLAG
           END-IF.
       3000-FETCH-LOOP.
           EXEC SQL
               FETCH ACCT_CURSOR
               INTO :WS-ACCT-ID,
                    :WS-ACCT-NAME,
                    :WS-ACCT-BAL,
                    :WS-ACCT-STATUS,
                    :WS-LAST-TXN-DATE
           END-EXEC
           IF WS-SQLCODE = 100
               SET WS-EOF TO TRUE
           ELSE
               IF WS-SQLCODE = 0
                   PERFORM 3100-RECONCILE-RECORD
               ELSE
                   ADD 1 TO WS-ERRORS
               END-IF
           END-IF.
       3100-RECONCILE-RECORD.
           ADD 1 TO WS-TOTAL-READ
           COMPUTE WS-VARIANCE =
               WS-ACCT-BAL - WS-EXPECTED-BAL
           MOVE WS-VARIANCE TO WS-ABS-VARIANCE
           IF WS-ABS-VARIANCE < 0
               MULTIPLY -1 BY WS-ABS-VARIANCE
           END-IF
           IF WS-ABS-VARIANCE <= WS-TOLERANCE
               ADD 1 TO WS-MATCHED
           ELSE
               ADD 1 TO WS-MISMATCHED
               DISPLAY 'MISMATCH: ' WS-ACCT-ID
                   ' VAR=' WS-VARIANCE
           END-IF.
       4000-CLOSE-CURSOR.
           EXEC SQL
               CLOSE ACCT_CURSOR
           END-EXEC
           EXEC SQL
               COMMIT
           END-EXEC.
       5000-DISPLAY-RESULTS.
           DISPLAY 'DB2 CURSOR RECON REPORT'
           DISPLAY '======================='
           DISPLAY 'RECORDS READ:    ' WS-TOTAL-READ
           DISPLAY 'MATCHED:         ' WS-MATCHED
           DISPLAY 'MISMATCHED:      ' WS-MISMATCHED
           DISPLAY 'ERRORS:          ' WS-ERRORS.
