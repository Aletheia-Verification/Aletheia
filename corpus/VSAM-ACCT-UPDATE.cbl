       IDENTIFICATION DIVISION.
       PROGRAM-ID. VSAM-ACCT-UPDATE.
      *================================================================*
      * VSAM-STYLE INDEXED FILE ACCOUNT UPDATE                         *
      * Opens account file, reads records, updates balances based on   *
      * transaction type, handles account status flags via 88-levels,  *
      * computes interest adjustments. Uses REDEFINES for record       *
      * variant overlay. Simulates VSAM patterns in working storage.   *
      *================================================================*
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ACCOUNT-FILE ASSIGN TO 'ACCTFILE'
               FILE STATUS IS WS-FILE-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  ACCOUNT-FILE.
       01  ACCOUNT-RECORD.
           05  ACCT-KEY                PIC X(10).
           05  ACCT-NAME               PIC X(30).
           05  ACCT-BALANCE            PIC S9(9)V99.
           05  ACCT-STATUS-CODE        PIC 9(1).
           05  ACCT-TYPE               PIC X(2).
           05  ACCT-INTEREST-RATE      PIC 9(1)V9(4).
           05  ACCT-LAST-TXN-DATE      PIC X(10).
           05  ACCT-FILLER             PIC X(16).

       01  ACCOUNT-RECORD-ALT REDEFINES ACCOUNT-RECORD.
           05  ACCT-ALT-KEY            PIC X(10).
           05  ACCT-ALT-DATA           PIC X(70).

       WORKING-STORAGE SECTION.
      *--- File Status ---
       01  WS-FILE-STATUS              PIC X(2).
       01  WS-EOF-FLAG                 PIC X(1).
           88  WS-EOF                  VALUE 'Y'.
           88  WS-NOT-EOF              VALUE 'N'.
      *--- Account Status Flags ---
       01  WS-ACCT-STATUS              PIC 9(1).
           88  ACCT-ACTIVE             VALUE 1.
           88  ACCT-CLOSED             VALUE 2.
           88  ACCT-FROZEN             VALUE 3.
           88  ACCT-DORMANT            VALUE 4.
      *--- Transaction Fields ---
       01  WS-TXN-TYPE                 PIC X(10).
       01  WS-TXN-AMOUNT              PIC S9(9)V99 COMP-3.
       01  WS-INTEREST-ADJ            PIC S9(9)V99 COMP-3.
       01  WS-DAILY-RATE              PIC S9(3)V9(6) COMP-3.
       01  WS-DAYS-ACCRUED            PIC 9(3).
      *--- Counters ---
       01  WS-RECORDS-READ            PIC 9(5).
       01  WS-RECORDS-UPDATED         PIC 9(5).
       01  WS-RECORDS-SKIPPED         PIC 9(5).
       01  WS-ERRORS                  PIC 9(5).
      *--- Work Fields ---
       01  WS-NEW-BALANCE             PIC S9(9)V99 COMP-3.
       01  WS-MIN-BALANCE             PIC S9(9)V99 COMP-3.
       01  WS-OVERDRAFT-FLAG          PIC X(1).
       01  WS-AUDIT-TIMESTAMP         PIC X(20).
       01  WS-PROCESS-FLAG            PIC X(1).
       01  WS-REWRITE-NEEDED          PIC X(1).
      *--- Balance Summary ---
       01  WS-TOTAL-DEPOSITS          PIC S9(11)V99 COMP-3.
       01  WS-TOTAL-INTEREST          PIC S9(11)V99 COMP-3.
       01  WS-AVG-BALANCE             PIC S9(9)V99 COMP-3.
       01  WS-HIGHEST-BALANCE         PIC S9(9)V99 COMP-3.
       01  WS-LOWEST-BALANCE          PIC S9(9)V99 COMP-3.
       01  WS-ACTIVE-COUNT            PIC 9(5).
       01  WS-DORMANT-COUNT           PIC 9(5).
       01  WS-FROZEN-COUNT            PIC 9(5).
       01  WS-CLOSED-COUNT            PIC 9(5).

       PROCEDURE DIVISION.
       MAIN-PROGRAM.
           PERFORM INITIALIZE-COUNTERS
           PERFORM OPEN-ACCOUNT-FILE THRU
                   OPEN-ACCOUNT-FILE-EXIT
           PERFORM PROCESS-ACCOUNTS THRU
                   PROCESS-ACCOUNTS-EXIT
           PERFORM CLOSE-ACCOUNT-FILE
           PERFORM DISPLAY-SUMMARY
           STOP RUN.

       INITIALIZE-COUNTERS.
           MOVE 0 TO WS-RECORDS-READ
           MOVE 0 TO WS-RECORDS-UPDATED
           MOVE 0 TO WS-RECORDS-SKIPPED
           MOVE 0 TO WS-ERRORS
           MOVE 'N' TO WS-EOF-FLAG
           MOVE 'DEPOSIT' TO WS-TXN-TYPE
           MOVE 500.00 TO WS-TXN-AMOUNT
           MOVE 30 TO WS-DAYS-ACCRUED
           MOVE 100.00 TO WS-MIN-BALANCE
           MOVE '2026-03-17T14:30:00' TO WS-AUDIT-TIMESTAMP
           MOVE 0 TO WS-TOTAL-DEPOSITS
           MOVE 0 TO WS-TOTAL-INTEREST
           MOVE 0 TO WS-HIGHEST-BALANCE
           MOVE 999999999.99 TO WS-LOWEST-BALANCE
           MOVE 0 TO WS-ACTIVE-COUNT
           MOVE 0 TO WS-DORMANT-COUNT
           MOVE 0 TO WS-FROZEN-COUNT
           MOVE 0 TO WS-CLOSED-COUNT.

       OPEN-ACCOUNT-FILE.
           OPEN INPUT ACCOUNT-FILE
           IF WS-FILE-STATUS NOT = '00'
               DISPLAY 'FILE OPEN ERROR: ' WS-FILE-STATUS
               ADD 1 TO WS-ERRORS
           END-IF.

       OPEN-ACCOUNT-FILE-EXIT.
           EXIT.

       PROCESS-ACCOUNTS.
           PERFORM UNTIL WS-EOF
               READ ACCOUNT-FILE
                   AT END
                       SET WS-EOF TO TRUE
                   NOT AT END
                       PERFORM HANDLE-RECORD
               END-READ
           END-PERFORM.

       PROCESS-ACCOUNTS-EXIT.
           EXIT.

       HANDLE-RECORD.
           ADD 1 TO WS-RECORDS-READ
           PERFORM EVALUATE-ACCOUNT
           IF WS-PROCESS-FLAG = 'Y'
               PERFORM APPLY-TRANSACTION
               PERFORM COMPUTE-INTEREST
               PERFORM UPDATE-AUDIT-FIELDS
               ADD 1 TO WS-RECORDS-UPDATED
           ELSE
               ADD 1 TO WS-RECORDS-SKIPPED
           END-IF.

       EVALUATE-ACCOUNT.
           MOVE ACCT-STATUS-CODE TO WS-ACCT-STATUS
           MOVE 'N' TO WS-PROCESS-FLAG
           EVALUATE TRUE
               WHEN ACCT-ACTIVE
                   MOVE 'Y' TO WS-PROCESS-FLAG
                   ADD 1 TO WS-ACTIVE-COUNT
               WHEN ACCT-CLOSED
                   MOVE 'N' TO WS-PROCESS-FLAG
                   ADD 1 TO WS-CLOSED-COUNT
                   DISPLAY 'SKIP CLOSED: ' ACCT-KEY
               WHEN ACCT-FROZEN
                   MOVE 'N' TO WS-PROCESS-FLAG
                   ADD 1 TO WS-FROZEN-COUNT
                   DISPLAY 'SKIP FROZEN: ' ACCT-KEY
               WHEN ACCT-DORMANT
                   ADD 1 TO WS-DORMANT-COUNT
                   IF WS-TXN-TYPE = 'DEPOSIT'
                       MOVE 'Y' TO WS-PROCESS-FLAG
                       DISPLAY 'REACTIVATE: ' ACCT-KEY
                   ELSE
                       MOVE 'N' TO WS-PROCESS-FLAG
                       DISPLAY 'SKIP DORMANT: ' ACCT-KEY
                   END-IF
           END-EVALUATE.

       APPLY-TRANSACTION.
           MOVE 'N' TO WS-OVERDRAFT-FLAG
           EVALUATE TRUE
               WHEN WS-TXN-TYPE = 'DEPOSIT'
                   ADD WS-TXN-AMOUNT TO ACCT-BALANCE
               WHEN WS-TXN-TYPE = 'WITHDRAWAL'
                   COMPUTE WS-NEW-BALANCE =
                       ACCT-BALANCE - WS-TXN-AMOUNT
                   IF WS-NEW-BALANCE < WS-MIN-BALANCE
                       MOVE 'Y' TO WS-OVERDRAFT-FLAG
                       DISPLAY 'OVERDRAFT RISK: ' ACCT-KEY
                   END-IF
                   SUBTRACT WS-TXN-AMOUNT FROM ACCT-BALANCE
               WHEN WS-TXN-TYPE = 'TRANSFER'
                   SUBTRACT WS-TXN-AMOUNT FROM ACCT-BALANCE
               WHEN OTHER
                   ADD 1 TO WS-ERRORS
                   DISPLAY 'UNKNOWN TXN: ' WS-TXN-TYPE
           END-EVALUATE.

       COMPUTE-INTEREST.
           IF ACCT-INTEREST-RATE > 0
               COMPUTE WS-DAILY-RATE =
                   ACCT-INTEREST-RATE / 365
               COMPUTE WS-INTEREST-ADJ =
                   ACCT-BALANCE * WS-DAILY-RATE *
                   WS-DAYS-ACCRUED
               ADD WS-INTEREST-ADJ TO ACCT-BALANCE
           END-IF.

       UPDATE-AUDIT-FIELDS.
           MOVE WS-AUDIT-TIMESTAMP TO ACCT-LAST-TXN-DATE
           IF ACCT-DORMANT
               MOVE 1 TO ACCT-STATUS-CODE
           END-IF
           PERFORM TRACK-BALANCE-STATS.

       TRACK-BALANCE-STATS.
           IF WS-TXN-TYPE = 'DEPOSIT'
               ADD WS-TXN-AMOUNT TO WS-TOTAL-DEPOSITS
           END-IF
           ADD WS-INTEREST-ADJ TO WS-TOTAL-INTEREST
           IF ACCT-BALANCE > WS-HIGHEST-BALANCE
               MOVE ACCT-BALANCE TO WS-HIGHEST-BALANCE
           END-IF
           IF ACCT-BALANCE < WS-LOWEST-BALANCE
               MOVE ACCT-BALANCE TO WS-LOWEST-BALANCE
           END-IF.

       CLOSE-ACCOUNT-FILE.
           CLOSE ACCOUNT-FILE
           IF WS-FILE-STATUS NOT = '00'
               DISPLAY 'FILE CLOSE ERROR: ' WS-FILE-STATUS
               ADD 1 TO WS-ERRORS
           END-IF.

       DISPLAY-SUMMARY.
           IF WS-RECORDS-UPDATED > 0
               COMPUTE WS-AVG-BALANCE =
                   WS-TOTAL-DEPOSITS / WS-RECORDS-UPDATED
           ELSE
               MOVE 0 TO WS-AVG-BALANCE
           END-IF
           DISPLAY 'VSAM ACCOUNT UPDATE SUMMARY'
           DISPLAY '==========================='
           DISPLAY 'RECORDS READ:    ' WS-RECORDS-READ
           DISPLAY 'RECORDS UPDATED: ' WS-RECORDS-UPDATED
           DISPLAY 'RECORDS SKIPPED: ' WS-RECORDS-SKIPPED
           DISPLAY 'ERRORS:          ' WS-ERRORS
           DISPLAY ' '
           DISPLAY 'STATUS BREAKDOWN:'
           DISPLAY 'ACTIVE:          ' WS-ACTIVE-COUNT
           DISPLAY 'CLOSED:          ' WS-CLOSED-COUNT
           DISPLAY 'FROZEN:          ' WS-FROZEN-COUNT
           DISPLAY 'DORMANT:         ' WS-DORMANT-COUNT
           DISPLAY ' '
           DISPLAY 'BALANCE STATS:'
           DISPLAY 'TOTAL DEPOSITS:  ' WS-TOTAL-DEPOSITS
           DISPLAY 'TOTAL INTEREST:  ' WS-TOTAL-INTEREST
           DISPLAY 'HIGHEST BAL:     ' WS-HIGHEST-BALANCE
           DISPLAY 'LOWEST BAL:      ' WS-LOWEST-BALANCE
           DISPLAY 'AVG DEPOSIT:     ' WS-AVG-BALANCE.
