       IDENTIFICATION DIVISION.
       PROGRAM-ID. ALTER-SQL-HYBRID.
      *================================================================*
      * HYBRID LEGACY PROGRAM - ALTER + EMBEDDED SQL                   *
      * Account maintenance with ALTER-based dispatch and EXEC SQL     *
      * for data retrieval and update. Tests both MR triggers.         *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- SQL Communication ---
       01  WS-SQLCODE                  PIC S9(9) COMP-3.
      *--- Request Fields ---
       01  WS-REQUEST-TYPE             PIC 9(1).
           88  REQ-ADDR-CHANGE         VALUE 1.
           88  REQ-NAME-CHANGE         VALUE 2.
           88  REQ-CLOSE-ACCT          VALUE 3.
           88  REQ-REOPEN-ACCT         VALUE 4.
       01  WS-ACCT-ID                  PIC X(10).
       01  WS-ACCT-NAME               PIC X(30).
       01  WS-ACCT-ADDRESS            PIC X(50).
       01  WS-ACCT-STATUS             PIC X(2).
       01  WS-ACCT-BALANCE            PIC S9(9)V99 COMP-3.
      *--- Fee Fields ---
       01  WS-MAINT-FEE               PIC S9(5)V99 COMP-3.
       01  WS-CLOSE-FEE               PIC S9(5)V99 COMP-3.
       01  WS-REOPEN-FEE              PIC S9(5)V99 COMP-3.
       01  WS-APPLIED-FEE             PIC S9(5)V99 COMP-3.
       01  WS-FEE-TOTAL               PIC S9(9)V99 COMP-3.
      *--- Processing ---
       01  WS-PROCESS-STATUS           PIC X(12).
       01  WS-ERROR-FLAG               PIC X(1).
       01  WS-RECORDS-PROCESSED        PIC 9(5).
       01  WS-ERRORS                   PIC 9(5).
      *--- Audit Fields ---
       01  WS-AUDIT-ACTION             PIC X(15).
       01  WS-AUDIT-BEFORE             PIC X(50).
       01  WS-AUDIT-AFTER              PIC X(50).
       01  WS-PRIOR-BALANCE            PIC S9(9)V99 COMP-3.

       PROCEDURE DIVISION.
       MAIN-PROGRAM.
           PERFORM INITIALIZE-SYSTEM
           PERFORM LOAD-REQUEST
           PERFORM RETRIEVE-ACCOUNT THRU
                   RETRIEVE-ACCOUNT-EXIT
           IF WS-ERROR-FLAG = 'N'
               PERFORM SETUP-HANDLER
               PERFORM EXECUTE-HANDLER THRU
                       EXECUTE-HANDLER-EXIT
               PERFORM APPLY-FEE
               PERFORM UPDATE-ACCOUNT THRU
                       UPDATE-ACCOUNT-EXIT
               PERFORM LOG-AUDIT
           END-IF
           PERFORM DISPLAY-RESULTS
           STOP RUN.

       INITIALIZE-SYSTEM.
           MOVE 0 TO WS-APPLIED-FEE
           MOVE 0 TO WS-FEE-TOTAL
           MOVE 0 TO WS-RECORDS-PROCESSED
           MOVE 0 TO WS-ERRORS
           MOVE 'N' TO WS-ERROR-FLAG
           MOVE 'PENDING' TO WS-PROCESS-STATUS
           MOVE 10.00 TO WS-MAINT-FEE
           MOVE 25.00 TO WS-CLOSE-FEE
           MOVE 15.00 TO WS-REOPEN-FEE
           MOVE SPACES TO WS-AUDIT-BEFORE
           MOVE SPACES TO WS-AUDIT-AFTER.

       LOAD-REQUEST.
           MOVE 1 TO WS-REQUEST-TYPE
           MOVE 'ACCT005678' TO WS-ACCT-ID
           MOVE '123 NEW STREET, ANYTOWN' TO WS-ACCT-ADDRESS.

       RETRIEVE-ACCOUNT.
           EXEC SQL
               SELECT ACCT_NAME, ACCT_BALANCE, ACCT_STATUS
               INTO :WS-ACCT-NAME,
                    :WS-ACCT-BALANCE,
                    :WS-ACCT-STATUS
               FROM ACCOUNT_MASTER
               WHERE ACCT_ID = :WS-ACCT-ID
           END-EXEC
           IF WS-SQLCODE = 0
               MOVE WS-ACCT-BALANCE TO WS-PRIOR-BALANCE
               ADD 1 TO WS-RECORDS-PROCESSED
           ELSE
               MOVE 'Y' TO WS-ERROR-FLAG
               ADD 1 TO WS-ERRORS
               DISPLAY 'RETRIEVE ERROR: ' WS-SQLCODE
           END-IF.

       RETRIEVE-ACCOUNT-EXIT.
           EXIT.

       SETUP-HANDLER.
           EVALUATE TRUE
               WHEN REQ-ADDR-CHANGE
                   ALTER HANDLER-GOTO TO PROCEED TO
                       HANDLE-ADDRESS
               WHEN REQ-NAME-CHANGE
                   ALTER HANDLER-GOTO TO PROCEED TO
                       HANDLE-NAME
               WHEN REQ-CLOSE-ACCT
                   ALTER HANDLER-GOTO TO PROCEED TO
                       HANDLE-CLOSE
               WHEN REQ-REOPEN-ACCT
                   ALTER HANDLER-GOTO TO PROCEED TO
                       HANDLE-REOPEN
           END-EVALUATE.

       EXECUTE-HANDLER.
           PERFORM HANDLER-GOTO THRU
                   HANDLER-GOTO-EXIT.

       EXECUTE-HANDLER-EXIT.
           EXIT.

       HANDLER-GOTO.
           GO TO HANDLE-ADDRESS.

       HANDLER-GOTO-EXIT.
           EXIT.

       HANDLE-ADDRESS.
           MOVE 'ADDR-CHANGE' TO WS-AUDIT-ACTION
           MOVE WS-ACCT-ADDRESS TO WS-AUDIT-BEFORE
           MOVE '123 NEW STREET, ANYTOWN' TO WS-ACCT-ADDRESS
           MOVE WS-ACCT-ADDRESS TO WS-AUDIT-AFTER
           MOVE WS-MAINT-FEE TO WS-APPLIED-FEE
           MOVE 'COMPLETED' TO WS-PROCESS-STATUS
           GO TO HANDLER-GOTO-EXIT.

       HANDLE-NAME.
           MOVE 'NAME-CHANGE' TO WS-AUDIT-ACTION
           MOVE WS-ACCT-NAME TO WS-AUDIT-BEFORE
           MOVE 'NEW NAME HERE' TO WS-ACCT-NAME
           MOVE WS-ACCT-NAME TO WS-AUDIT-AFTER
           MOVE WS-MAINT-FEE TO WS-APPLIED-FEE
           MOVE 'COMPLETED' TO WS-PROCESS-STATUS
           GO TO HANDLER-GOTO-EXIT.

       HANDLE-CLOSE.
           MOVE 'CLOSE-ACCT' TO WS-AUDIT-ACTION
           IF WS-ACCT-BALANCE > 0
               DISPLAY 'BALANCE DISBURSE: ' WS-ACCT-BALANCE
           END-IF
           MOVE 'CL' TO WS-ACCT-STATUS
           MOVE WS-CLOSE-FEE TO WS-APPLIED-FEE
           MOVE 'COMPLETED' TO WS-PROCESS-STATUS
           GO TO HANDLER-GOTO-EXIT.

       HANDLE-REOPEN.
           MOVE 'REOPEN-ACCT' TO WS-AUDIT-ACTION
           IF WS-ACCT-STATUS = 'CL'
               MOVE 'AC' TO WS-ACCT-STATUS
               MOVE WS-REOPEN-FEE TO WS-APPLIED-FEE
               MOVE 'COMPLETED' TO WS-PROCESS-STATUS
           ELSE
               MOVE 'NOT-CLOSED' TO WS-PROCESS-STATUS
               MOVE 0 TO WS-APPLIED-FEE
           END-IF
           GO TO HANDLER-GOTO-EXIT.

       APPLY-FEE.
           SUBTRACT WS-APPLIED-FEE FROM WS-ACCT-BALANCE
           ADD WS-APPLIED-FEE TO WS-FEE-TOTAL.

       UPDATE-ACCOUNT.
           EXEC SQL
               UPDATE ACCOUNT_MASTER
               SET ACCT_NAME = :WS-ACCT-NAME,
                   ACCT_BALANCE = :WS-ACCT-BALANCE,
                   ACCT_STATUS = :WS-ACCT-STATUS,
                   LAST_MAINT_DATE = CURRENT DATE
               WHERE ACCT_ID = :WS-ACCT-ID
           END-EXEC
           IF WS-SQLCODE NOT = 0
               MOVE 'Y' TO WS-ERROR-FLAG
               ADD 1 TO WS-ERRORS
               DISPLAY 'UPDATE ERROR: ' WS-SQLCODE
           END-IF.

       UPDATE-ACCOUNT-EXIT.
           EXIT.

       LOG-AUDIT.
           EXEC SQL
               INSERT INTO AUDIT_LOG
               (ACCT_ID, ACTION, BEFORE_VAL, AFTER_VAL,
                FEE_AMOUNT, LOG_DATE)
               VALUES
               (:WS-ACCT-ID, :WS-AUDIT-ACTION,
                :WS-AUDIT-BEFORE, :WS-AUDIT-AFTER,
                :WS-APPLIED-FEE, CURRENT TIMESTAMP)
           END-EXEC
           IF WS-SQLCODE NOT = 0
               DISPLAY 'AUDIT LOG ERROR: ' WS-SQLCODE
           END-IF.

       DISPLAY-RESULTS.
           DISPLAY 'ALTER-SQL HYBRID REPORT'
           DISPLAY '======================='
           DISPLAY 'ACCOUNT:    ' WS-ACCT-ID
           DISPLAY 'ACTION:     ' WS-AUDIT-ACTION
           DISPLAY 'STATUS:     ' WS-PROCESS-STATUS
           DISPLAY 'PRIOR BAL:  ' WS-PRIOR-BALANCE
           DISPLAY 'NEW BAL:    ' WS-ACCT-BALANCE
           DISPLAY 'FEE:        ' WS-APPLIED-FEE
           DISPLAY 'PROCESSED:  ' WS-RECORDS-PROCESSED
           DISPLAY 'ERRORS:     ' WS-ERRORS.
