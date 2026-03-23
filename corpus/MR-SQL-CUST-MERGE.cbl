       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-SQL-CUST-MERGE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-SQLCODE               PIC S9(9) COMP-3.
       01 WS-SOURCE-CUST.
           05 WS-SRC-ID           PIC X(12).
           05 WS-SRC-NAME         PIC X(40).
           05 WS-SRC-SSN          PIC X(9).
           05 WS-SRC-ACCT-COUNT   PIC 9(3).
       01 WS-TARGET-CUST.
           05 WS-TGT-ID           PIC X(12).
           05 WS-TGT-NAME         PIC X(40).
           05 WS-TGT-SSN          PIC X(9).
           05 WS-TGT-ACCT-COUNT   PIC 9(3).
       01 WS-MERGE-STATUS         PIC X(12).
       01 WS-ACCTS-MOVED          PIC 9(3).
       01 WS-ERRORS               PIC 9(3).
       01 WS-MERGE-DATE           PIC 9(8).
       01 WS-VALID-MERGE          PIC X VALUE 'N'.
           88 MERGE-OK            VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-VALIDATE-MERGE
           IF MERGE-OK
               PERFORM 3000-MOVE-ACCOUNTS
               PERFORM 4000-DEACTIVATE-SOURCE
           END-IF
           PERFORM 5000-REPORT
           STOP RUN.
       1000-INIT.
           MOVE 0 TO WS-ACCTS-MOVED
           MOVE 0 TO WS-ERRORS
           ACCEPT WS-MERGE-DATE FROM DATE YYYYMMDD.
       2000-VALIDATE-MERGE.
           EXEC SQL
               SELECT CUST_ID, CUST_NAME, SSN
               INTO :WS-SRC-ID, :WS-SRC-NAME, :WS-SRC-SSN
               FROM CUSTOMER_MASTER
               WHERE CUST_ID = :WS-SRC-ID
           END-EXEC
           IF WS-SQLCODE NOT = 0
               MOVE 'SRC-NOT-FOUND' TO WS-MERGE-STATUS
           ELSE
               EXEC SQL
                   SELECT CUST_ID, CUST_NAME, SSN
                   INTO :WS-TGT-ID, :WS-TGT-NAME,
                        :WS-TGT-SSN
                   FROM CUSTOMER_MASTER
                   WHERE CUST_ID = :WS-TGT-ID
               END-EXEC
               IF WS-SQLCODE NOT = 0
                   MOVE 'TGT-NOT-FOUND' TO WS-MERGE-STATUS
               ELSE
                   IF WS-SRC-SSN = WS-TGT-SSN
                       MOVE 'Y' TO WS-VALID-MERGE
                   ELSE
                       MOVE 'SSN-MISMATCH' TO WS-MERGE-STATUS
                   END-IF
               END-IF
           END-IF.
       3000-MOVE-ACCOUNTS.
           EXEC SQL
               UPDATE ACCOUNT_MASTER
               SET CUST_ID = :WS-TGT-ID
               WHERE CUST_ID = :WS-SRC-ID
           END-EXEC
           IF WS-SQLCODE = 0
               MOVE WS-SRC-ACCT-COUNT TO WS-ACCTS-MOVED
               MOVE 'MERGED      ' TO WS-MERGE-STATUS
           ELSE
               ADD 1 TO WS-ERRORS
               MOVE 'MOVE-FAILED ' TO WS-MERGE-STATUS
           END-IF.
       4000-DEACTIVATE-SOURCE.
           EXEC SQL
               UPDATE CUSTOMER_MASTER
               SET STATUS = 'MERGED'
               WHERE CUST_ID = :WS-SRC-ID
           END-EXEC
           EXEC SQL
               COMMIT
           END-EXEC.
       5000-REPORT.
           DISPLAY 'CUSTOMER MERGE REPORT'
           DISPLAY '====================='
           DISPLAY 'DATE:     ' WS-MERGE-DATE
           DISPLAY 'SOURCE:   ' WS-SRC-ID ' ' WS-SRC-NAME
           DISPLAY 'TARGET:   ' WS-TGT-ID ' ' WS-TGT-NAME
           DISPLAY 'STATUS:   ' WS-MERGE-STATUS
           DISPLAY 'ACCOUNTS: ' WS-ACCTS-MOVED
           DISPLAY 'ERRORS:   ' WS-ERRORS.
