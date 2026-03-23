       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-EXEC-SQL-DEPOSIT.
      *================================================================*
      * MANUAL REVIEW: Deposit Account SQL Interface                    *
      * Uses embedded EXEC SQL for deposit account queries, updates,   *
      * and interest posting — triggers MANUAL REVIEW detection.       *
      *================================================================*
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-ACCT-NUM            PIC X(12).
       01  WS-ACCT-NAME           PIC X(30).
       01  WS-BALANCE             PIC S9(11)V99.
       01  WS-INT-RATE            PIC 9V9(06).
       01  WS-INT-AMT             PIC S9(09)V99.
       01  WS-NEW-BALANCE         PIC S9(11)V99.
       01  WS-ACCT-TYPE           PIC X(02).
       01  WS-STATUS              PIC X(01).
       01  WS-PROCESS-DATE        PIC X(10).
       01  WS-ROW-COUNT           PIC S9(08) COMP.
       01  WS-TOTAL-POSTED        PIC S9(13)V99 VALUE 0.
       01  WS-ACCT-CNT            PIC 9(06) VALUE 0.
       01  WS-ERROR-CNT           PIC 9(06) VALUE 0.
       01  WS-SQLCODE              PIC S9(09) COMP.
       01  WS-MSG                 PIC X(80) VALUE SPACES.
           EXEC SQL INCLUDE SQLCA END-EXEC.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-OPEN-CURSOR
           PERFORM 3000-PROCESS-ACCOUNTS
           PERFORM 8000-CLOSE-CURSOR
           PERFORM 9000-FINALIZE
           STOP RUN.
       1000-INITIALIZE.
           EXEC SQL
               CONNECT TO DEPOSIT_DB
               USER 'BATCH'
               USING 'BATCH_PWD'
           END-EXEC
           IF SQLCODE NOT = 0
               DISPLAY 'DB CONNECT ERROR: ' SQLCODE
               STOP RUN
           END-IF
           ACCEPT WS-PROCESS-DATE FROM DATE YYYYMMDD.
       2000-OPEN-CURSOR.
           EXEC SQL
               DECLARE ACCT_CURSOR CURSOR FOR
               SELECT ACCT_NUM, ACCT_NAME, BALANCE,
                      INT_RATE, ACCT_TYPE, STATUS
               FROM DEPOSIT_ACCOUNTS
               WHERE STATUS = 'A'
               AND ACCT_TYPE IN ('SA', 'MM', 'CD')
               ORDER BY ACCT_NUM
           END-EXEC
           EXEC SQL
               OPEN ACCT_CURSOR
           END-EXEC
           IF SQLCODE NOT = 0
               DISPLAY 'CURSOR OPEN ERROR: ' SQLCODE
               STOP RUN
           END-IF.
       3000-PROCESS-ACCOUNTS.
           PERFORM 3100-FETCH-NEXT
           PERFORM UNTIL SQLCODE NOT = 0
               ADD 1 TO WS-ACCT-CNT
               PERFORM 4000-CALC-INTEREST
               PERFORM 5000-POST-INTEREST
               PERFORM 3100-FETCH-NEXT
           END-PERFORM.
       3100-FETCH-NEXT.
           EXEC SQL
               FETCH ACCT_CURSOR
               INTO :WS-ACCT-NUM, :WS-ACCT-NAME,
                    :WS-BALANCE, :WS-INT-RATE,
                    :WS-ACCT-TYPE, :WS-STATUS
           END-EXEC.
       4000-CALC-INTEREST.
           EVALUATE WS-ACCT-TYPE
               WHEN 'SA'
                   COMPUTE WS-INT-AMT ROUNDED =
                       WS-BALANCE * WS-INT-RATE / 365
               WHEN 'MM'
                   IF WS-BALANCE >= 10000
                       COMPUTE WS-INT-AMT ROUNDED =
                           WS-BALANCE * WS-INT-RATE / 365
                   ELSE
                       COMPUTE WS-INT-AMT ROUNDED =
                           WS-BALANCE *
                           (WS-INT-RATE * 0.50) / 365
                   END-IF
               WHEN 'CD'
                   COMPUTE WS-INT-AMT ROUNDED =
                       WS-BALANCE * WS-INT-RATE / 360
               WHEN OTHER
                   MOVE ZERO TO WS-INT-AMT
           END-EVALUATE
           COMPUTE WS-NEW-BALANCE =
               WS-BALANCE + WS-INT-AMT.
       5000-POST-INTEREST.
           EXEC SQL
               UPDATE DEPOSIT_ACCOUNTS
               SET BALANCE = :WS-NEW-BALANCE,
                   LAST_INT_DATE = :WS-PROCESS-DATE,
                   LAST_INT_AMT = :WS-INT-AMT
               WHERE ACCT_NUM = :WS-ACCT-NUM
           END-EXEC
           IF SQLCODE = 0
               ADD WS-INT-AMT TO WS-TOTAL-POSTED
               EXEC SQL
                   INSERT INTO INTEREST_HISTORY
                   (ACCT_NUM, POST_DATE, INT_AMT,
                    PRIOR_BAL, NEW_BAL)
                   VALUES (:WS-ACCT-NUM,
                           :WS-PROCESS-DATE,
                           :WS-INT-AMT,
                           :WS-BALANCE,
                           :WS-NEW-BALANCE)
               END-EXEC
           ELSE
               ADD 1 TO WS-ERROR-CNT
               DISPLAY 'POST ERROR: ' WS-ACCT-NUM
                   ' SQLCODE=' SQLCODE
           END-IF.
       8000-CLOSE-CURSOR.
           EXEC SQL
               CLOSE ACCT_CURSOR
           END-EXEC
           EXEC SQL
               COMMIT
           END-EXEC.
       9000-FINALIZE.
           EXEC SQL
               DISCONNECT
           END-EXEC
           DISPLAY 'INTEREST POSTING COMPLETE'
           DISPLAY 'ACCOUNTS:    ' WS-ACCT-CNT
           DISPLAY 'ERRORS:      ' WS-ERROR-CNT
           DISPLAY 'TOTAL POSTED:' WS-TOTAL-POSTED.
