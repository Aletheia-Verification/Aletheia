       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-SQL-DAILY-BAL.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-SQLCODE              PIC S9(9) COMP-3.
       01 WS-ACCT-REC.
           05 WS-ACCT-NUM        PIC X(12).
           05 WS-ACCT-NAME       PIC X(30).
           05 WS-ACCT-TYPE       PIC X(2).
           05 WS-LEDGER-BAL      PIC S9(11)V99 COMP-3.
           05 WS-AVAIL-BAL       PIC S9(11)V99 COMP-3.
           05 WS-HOLD-AMT        PIC S9(7)V99 COMP-3.
       01 WS-DAILY-REC.
           05 WS-DR-ACCT         PIC X(12).
           05 WS-DR-DATE         PIC X(10).
           05 WS-DR-LEDGER       PIC S9(11)V99 COMP-3.
           05 WS-DR-AVAIL        PIC S9(11)V99 COMP-3.
       01 WS-EOF-FLAG            PIC X VALUE 'N'.
           88 WS-EOF             VALUE 'Y'.
       01 WS-PROCESS-DATE        PIC 9(8).
       01 WS-PROCESS-DATE-X      PIC X(10).
       01 WS-ACCTS-PROCESSED     PIC 9(5).
       01 WS-INSERT-ERRORS       PIC 9(3).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-OPEN-CURSOR
           PERFORM 3000-PROCESS UNTIL WS-EOF
           PERFORM 4000-CLOSE
           PERFORM 5000-REPORT
           STOP RUN.
       1000-INIT.
           MOVE 0 TO WS-ACCTS-PROCESSED
           MOVE 0 TO WS-INSERT-ERRORS
           ACCEPT WS-PROCESS-DATE FROM DATE YYYYMMDD.
       2000-OPEN-CURSOR.
           EXEC SQL
               DECLARE ACCT_BAL_CUR CURSOR FOR
               SELECT ACCT_NUM, ACCT_NAME, ACCT_TYPE,
                      LEDGER_BAL, AVAIL_BAL, HOLD_AMT
               FROM ACCOUNT_MASTER
               WHERE ACCT_STATUS = 'AC'
               ORDER BY ACCT_NUM
           END-EXEC
           EXEC SQL OPEN ACCT_BAL_CUR END-EXEC.
       3000-PROCESS.
           EXEC SQL
               FETCH ACCT_BAL_CUR
               INTO :WS-ACCT-NUM, :WS-ACCT-NAME,
                    :WS-ACCT-TYPE, :WS-LEDGER-BAL,
                    :WS-AVAIL-BAL, :WS-HOLD-AMT
           END-EXEC
           IF WS-SQLCODE = 100
               SET WS-EOF TO TRUE
           ELSE
               IF WS-SQLCODE = 0
                   PERFORM 3100-INSERT-DAILY
               END-IF
           END-IF.
       3100-INSERT-DAILY.
           ADD 1 TO WS-ACCTS-PROCESSED
           MOVE WS-ACCT-NUM TO WS-DR-ACCT
           MOVE WS-LEDGER-BAL TO WS-DR-LEDGER
           COMPUTE WS-DR-AVAIL =
               WS-AVAIL-BAL - WS-HOLD-AMT
           EXEC SQL
               INSERT INTO DAILY_BALANCES
               (ACCT_NUM, BAL_DATE, LEDGER_BAL, AVAIL_BAL)
               VALUES
               (:WS-DR-ACCT, CURRENT DATE,
                :WS-DR-LEDGER, :WS-DR-AVAIL)
           END-EXEC
           IF WS-SQLCODE NOT = 0
               ADD 1 TO WS-INSERT-ERRORS
           END-IF.
       4000-CLOSE.
           EXEC SQL CLOSE ACCT_BAL_CUR END-EXEC
           EXEC SQL COMMIT END-EXEC.
       5000-REPORT.
           DISPLAY 'DAILY BALANCE SNAPSHOT'
           DISPLAY '======================'
           DISPLAY 'DATE:      ' WS-PROCESS-DATE
           DISPLAY 'PROCESSED: ' WS-ACCTS-PROCESSED
           DISPLAY 'ERRORS:    ' WS-INSERT-ERRORS.
