       IDENTIFICATION DIVISION.
       PROGRAM-ID. BATCH-GL-POSTING.
      *================================================================*
      * General Ledger Batch Posting Engine                            *
      * Reads journal entries, validates debit/credit balancing,       *
      * posts to chart of accounts table, handles suspense.            *
      *================================================================*

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT JOURNAL-FILE ASSIGN TO "JOURNAL.DAT"
               FILE STATUS IS WS-FILE-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  JOURNAL-FILE.
       01  JOURNAL-RECORD.
           05  JR-BATCH-NUM          PIC 9(6).
           05  JR-SEQUENCE           PIC 9(4).
           05  JR-ACCOUNT-NUM        PIC 9(6).
           05  JR-ENTRY-TYPE         PIC X(1).
           05  JR-AMOUNT             PIC 9(11)V99.
           05  JR-DESCRIPTION        PIC X(30).
           05  JR-FILLER             PIC X(20).

       WORKING-STORAGE SECTION.

      *--- File Control ---*
       01  WS-FILE-STATUS            PIC XX.
       01  WS-EOF-FLAG               PIC 9 VALUE 0.

      *--- Chart of Accounts Table ---*
       01  WS-COA-TABLE.
           05  WS-COA-ENTRY OCCURS 50.
               10  WC-ACCOUNT-NUM    PIC 9(6).
               10  WC-ACCOUNT-NAME   PIC X(20).
               10  WC-ACCOUNT-TYPE   PIC X(1).
               10  WC-BALANCE        PIC S9(13)V99 COMP-3.
               10  WC-DEBIT-TOTAL    PIC S9(13)V99 COMP-3.
               10  WC-CREDIT-TOTAL   PIC S9(13)V99 COMP-3.
               10  WC-POST-COUNT     PIC S9(5) COMP-3.
               10  WC-ACTIVE         PIC 9.

      *--- Batch Control ---*
       01  WS-CURRENT-BATCH          PIC 9(6).
       01  WS-EXPECTED-SEQ           PIC 9(4).
       01  WS-BATCH-DEBIT-TOT        PIC S9(13)V99 COMP-3.
       01  WS-BATCH-CREDIT-TOT       PIC S9(13)V99 COMP-3.
       01  WS-BATCH-DIFFERENCE        PIC S9(13)V99 COMP-3.
       01  WS-BATCH-RECORD-CNT       PIC S9(7) COMP-3.

      *--- Suspense Account ---*
       01  WS-SUSPENSE-ACCT          PIC 9(6).
       01  WS-SUSPENSE-BALANCE       PIC S9(13)V99 COMP-3.
       01  WS-SUSPENSE-COUNT         PIC S9(5) COMP-3.

      *--- Grand Totals ---*
       01  WS-GRAND-DEBITS           PIC S9(15)V99 COMP-3.
       01  WS-GRAND-CREDITS          PIC S9(15)V99 COMP-3.
       01  WS-GRAND-RECORDS          PIC S9(7) COMP-3.
       01  WS-BATCHES-PROCESSED      PIC S9(5) COMP-3.
       01  WS-BATCHES-BALANCED       PIC S9(5) COMP-3.
       01  WS-BATCHES-SUSPENDED      PIC S9(5) COMP-3.
       01  WS-SEQ-ERRORS             PIC S9(5) COMP-3.

      *--- Work Fields ---*
       01  WS-ACCT-INDEX             PIC S9(3) COMP-3.
       01  WS-SEARCH-INDEX           PIC S9(3) COMP-3.
       01  WS-FOUND-INDEX            PIC S9(3) COMP-3.
       01  WS-COA-COUNT              PIC S9(3) COMP-3.
       01  WS-LOOP-IDX               PIC S9(3) COMP-3.
       01  WS-REPORT-IDX             PIC S9(3) COMP-3.
       01  WS-POST-AMOUNT            PIC S9(13)V99 COMP-3.
       01  WS-ABS-DIFF               PIC S9(13)V99 COMP-3.
       01  WS-BATCH-COMPLETE         PIC 9.

      *--- Display ---*
       01  WS-DISP-AMOUNT            PIC -$$$,$$$,$$$,$$9.99.
       01  WS-DISP-COUNT             PIC Z,ZZZ,ZZ9.
       01  WS-DISP-ACCT              PIC 9(6).

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-CHART-OF-ACCOUNTS
           PERFORM 3000-PROCESS-JOURNAL
           PERFORM 4000-FINALIZE-BATCH
           PERFORM 5000-GENERATE-REPORT
           STOP RUN.

       1000-INITIALIZE.
           INITIALIZE WS-COA-TABLE
           MOVE 0 TO WS-GRAND-DEBITS
           MOVE 0 TO WS-GRAND-CREDITS
           MOVE 0 TO WS-GRAND-RECORDS
           MOVE 0 TO WS-BATCHES-PROCESSED
           MOVE 0 TO WS-BATCHES-BALANCED
           MOVE 0 TO WS-BATCHES-SUSPENDED
           MOVE 0 TO WS-SEQ-ERRORS
           MOVE 999999 TO WS-SUSPENSE-ACCT
           MOVE 0 TO WS-SUSPENSE-BALANCE
           MOVE 0 TO WS-SUSPENSE-COUNT
           MOVE 0 TO WS-COA-COUNT
           MOVE 0 TO WS-BATCH-DEBIT-TOT
           MOVE 0 TO WS-BATCH-CREDIT-TOT
           MOVE 0 TO WS-BATCH-RECORD-CNT
           MOVE 0 TO WS-EXPECTED-SEQ
           MOVE 0 TO WS-CURRENT-BATCH
           MOVE 0 TO WS-BATCH-COMPLETE
           PERFORM VARYING WS-LOOP-IDX FROM 1 BY 1
               UNTIL WS-LOOP-IDX > 50
               MOVE 0 TO WC-ACTIVE(WS-LOOP-IDX)
           END-PERFORM.

       2000-LOAD-CHART-OF-ACCOUNTS.
           MOVE 1 TO WS-COA-COUNT
           MOVE 100100 TO WC-ACCOUNT-NUM(1)
           MOVE "CASH-OPERATING" TO WC-ACCOUNT-NAME(1)
           MOVE "A" TO WC-ACCOUNT-TYPE(1)
           MOVE 1500000.00 TO WC-BALANCE(1)
           MOVE 0 TO WC-DEBIT-TOTAL(1)
           MOVE 0 TO WC-CREDIT-TOTAL(1)
           MOVE 0 TO WC-POST-COUNT(1)
           MOVE 1 TO WC-ACTIVE(1)

           ADD 1 TO WS-COA-COUNT
           MOVE 200100 TO WC-ACCOUNT-NUM(2)
           MOVE "DEMAND-DEPOSITS" TO WC-ACCOUNT-NAME(2)
           MOVE "L" TO WC-ACCOUNT-TYPE(2)
           MOVE 980000.00 TO WC-BALANCE(2)
           MOVE 0 TO WC-DEBIT-TOTAL(2)
           MOVE 0 TO WC-CREDIT-TOTAL(2)
           MOVE 0 TO WC-POST-COUNT(2)
           MOVE 1 TO WC-ACTIVE(2)

           ADD 1 TO WS-COA-COUNT
           MOVE 300100 TO WC-ACCOUNT-NUM(3)
           MOVE "INTEREST-INCOME" TO WC-ACCOUNT-NAME(3)
           MOVE "R" TO WC-ACCOUNT-TYPE(3)
           MOVE 0 TO WC-BALANCE(3)
           MOVE 0 TO WC-DEBIT-TOTAL(3)
           MOVE 0 TO WC-CREDIT-TOTAL(3)
           MOVE 0 TO WC-POST-COUNT(3)
           MOVE 1 TO WC-ACTIVE(3)

           ADD 1 TO WS-COA-COUNT
           MOVE 400100 TO WC-ACCOUNT-NUM(4)
           MOVE "LOAN-INTEREST-EXP" TO WC-ACCOUNT-NAME(4)
           MOVE "E" TO WC-ACCOUNT-TYPE(4)
           MOVE 0 TO WC-BALANCE(4)
           MOVE 0 TO WC-DEBIT-TOTAL(4)
           MOVE 0 TO WC-CREDIT-TOTAL(4)
           MOVE 0 TO WC-POST-COUNT(4)
           MOVE 1 TO WC-ACTIVE(4)

           ADD 1 TO WS-COA-COUNT
           MOVE 500100 TO WC-ACCOUNT-NUM(5)
           MOVE "LOAN-PORTFOLIO" TO WC-ACCOUNT-NAME(5)
           MOVE "A" TO WC-ACCOUNT-TYPE(5)
           MOVE 2500000.00 TO WC-BALANCE(5)
           MOVE 0 TO WC-DEBIT-TOTAL(5)
           MOVE 0 TO WC-CREDIT-TOTAL(5)
           MOVE 0 TO WC-POST-COUNT(5)
           MOVE 1 TO WC-ACTIVE(5).

       3000-PROCESS-JOURNAL.
           OPEN INPUT JOURNAL-FILE
           MOVE 0 TO WS-EOF-FLAG
           PERFORM 3100-READ-JOURNAL
           PERFORM UNTIL WS-EOF-FLAG = 1
               PERFORM 3200-PROCESS-ENTRY
               PERFORM 3100-READ-JOURNAL
           END-PERFORM
           CLOSE JOURNAL-FILE.

       3100-READ-JOURNAL.
           READ JOURNAL-FILE
               AT END
                   MOVE 1 TO WS-EOF-FLAG
           END-READ
           IF WS-EOF-FLAG = 0
               ADD 1 TO WS-GRAND-RECORDS
           END-IF.

       3200-PROCESS-ENTRY.
           IF WS-CURRENT-BATCH = 0
               MOVE JR-BATCH-NUM TO WS-CURRENT-BATCH
               MOVE 1 TO WS-EXPECTED-SEQ
               MOVE 0 TO WS-BATCH-DEBIT-TOT
               MOVE 0 TO WS-BATCH-CREDIT-TOT
               MOVE 0 TO WS-BATCH-RECORD-CNT
           END-IF
           IF JR-BATCH-NUM NOT = WS-CURRENT-BATCH
               PERFORM 4000-FINALIZE-BATCH
               MOVE JR-BATCH-NUM TO WS-CURRENT-BATCH
               MOVE 1 TO WS-EXPECTED-SEQ
               MOVE 0 TO WS-BATCH-DEBIT-TOT
               MOVE 0 TO WS-BATCH-CREDIT-TOT
               MOVE 0 TO WS-BATCH-RECORD-CNT
           END-IF
           PERFORM 3300-VALIDATE-SEQUENCE
           PERFORM 3400-FIND-ACCOUNT
           IF WS-FOUND-INDEX > 0
               PERFORM 3500-POST-TO-ACCOUNT
           ELSE
               PERFORM 3600-POST-TO-SUSPENSE
           END-IF
           ADD 1 TO WS-BATCH-RECORD-CNT.

       3300-VALIDATE-SEQUENCE.
           IF JR-SEQUENCE NOT = WS-EXPECTED-SEQ
               ADD 1 TO WS-SEQ-ERRORS
           END-IF
           ADD 1 TO WS-EXPECTED-SEQ.

       3400-FIND-ACCOUNT.
           MOVE 0 TO WS-FOUND-INDEX
           PERFORM VARYING WS-SEARCH-INDEX FROM 1 BY 1
               UNTIL WS-SEARCH-INDEX > WS-COA-COUNT
               IF WC-ACCOUNT-NUM(WS-SEARCH-INDEX) =
                   JR-ACCOUNT-NUM
                   IF WC-ACTIVE(WS-SEARCH-INDEX) = 1
                       MOVE WS-SEARCH-INDEX TO WS-FOUND-INDEX
                   END-IF
               END-IF
           END-PERFORM.

       3500-POST-TO-ACCOUNT.
           EVALUATE TRUE
               WHEN JR-ENTRY-TYPE = "D"
                   ADD JR-AMOUNT TO
                       WC-DEBIT-TOTAL(WS-FOUND-INDEX)
                   ADD JR-AMOUNT TO WS-BATCH-DEBIT-TOT
                   ADD JR-AMOUNT TO WS-GRAND-DEBITS
                   IF WC-ACCOUNT-TYPE(WS-FOUND-INDEX) = "A"
                       ADD JR-AMOUNT TO
                           WC-BALANCE(WS-FOUND-INDEX)
                   ELSE
                       SUBTRACT JR-AMOUNT FROM
                           WC-BALANCE(WS-FOUND-INDEX)
                   END-IF
               WHEN JR-ENTRY-TYPE = "C"
                   ADD JR-AMOUNT TO
                       WC-CREDIT-TOTAL(WS-FOUND-INDEX)
                   ADD JR-AMOUNT TO WS-BATCH-CREDIT-TOT
                   ADD JR-AMOUNT TO WS-GRAND-CREDITS
                   IF WC-ACCOUNT-TYPE(WS-FOUND-INDEX) = "L"
                       ADD JR-AMOUNT TO
                           WC-BALANCE(WS-FOUND-INDEX)
                   ELSE
                       IF WC-ACCOUNT-TYPE(WS-FOUND-INDEX) = "R"
                           ADD JR-AMOUNT TO
                               WC-BALANCE(WS-FOUND-INDEX)
                       ELSE
                           SUBTRACT JR-AMOUNT FROM
                               WC-BALANCE(WS-FOUND-INDEX)
                       END-IF
                   END-IF
               WHEN OTHER
                   PERFORM 3600-POST-TO-SUSPENSE
           END-EVALUATE
           ADD 1 TO WC-POST-COUNT(WS-FOUND-INDEX).

       3600-POST-TO-SUSPENSE.
           ADD JR-AMOUNT TO WS-SUSPENSE-BALANCE
           ADD 1 TO WS-SUSPENSE-COUNT
           DISPLAY "SUSPENSE: ACCT=" JR-ACCOUNT-NUM
               " AMT=" JR-AMOUNT.

       4000-FINALIZE-BATCH.
           IF WS-CURRENT-BATCH > 0
               ADD 1 TO WS-BATCHES-PROCESSED
               COMPUTE WS-BATCH-DIFFERENCE =
                   WS-BATCH-DEBIT-TOT - WS-BATCH-CREDIT-TOT
               MOVE WS-BATCH-DIFFERENCE TO WS-ABS-DIFF
               IF WS-ABS-DIFF < 0
                   MULTIPLY -1 BY WS-ABS-DIFF
               END-IF
               IF WS-ABS-DIFF < 0.01
                   ADD 1 TO WS-BATCHES-BALANCED
               ELSE
                   ADD 1 TO WS-BATCHES-SUSPENDED
                   ADD WS-BATCH-DIFFERENCE TO
                       WS-SUSPENSE-BALANCE
                   ADD 1 TO WS-SUSPENSE-COUNT
                   DISPLAY "BATCH " WS-CURRENT-BATCH
                       " OUT OF BALANCE BY "
                       WS-BATCH-DIFFERENCE
               END-IF
           END-IF.

       5000-GENERATE-REPORT.
           DISPLAY "========================================"
           DISPLAY "  GENERAL LEDGER BATCH POSTING REPORT"
           DISPLAY "========================================"
           MOVE WS-GRAND-RECORDS TO WS-DISP-COUNT
           DISPLAY "TOTAL RECORDS:     " WS-DISP-COUNT
           MOVE WS-BATCHES-PROCESSED TO WS-DISP-COUNT
           DISPLAY "BATCHES PROCESSED: " WS-DISP-COUNT
           MOVE WS-BATCHES-BALANCED TO WS-DISP-COUNT
           DISPLAY "BATCHES BALANCED:  " WS-DISP-COUNT
           MOVE WS-BATCHES-SUSPENDED TO WS-DISP-COUNT
           DISPLAY "BATCHES SUSPENDED: " WS-DISP-COUNT
           MOVE WS-SEQ-ERRORS TO WS-DISP-COUNT
           DISPLAY "SEQUENCE ERRORS:   " WS-DISP-COUNT
           DISPLAY "----------------------------------------"
           MOVE WS-GRAND-DEBITS TO WS-DISP-AMOUNT
           DISPLAY "TOTAL DEBITS:      " WS-DISP-AMOUNT
           MOVE WS-GRAND-CREDITS TO WS-DISP-AMOUNT
           DISPLAY "TOTAL CREDITS:     " WS-DISP-AMOUNT
           MOVE WS-SUSPENSE-BALANCE TO WS-DISP-AMOUNT
           DISPLAY "SUSPENSE BALANCE:  " WS-DISP-AMOUNT
           MOVE WS-SUSPENSE-COUNT TO WS-DISP-COUNT
           DISPLAY "SUSPENSE ITEMS:    " WS-DISP-COUNT
           DISPLAY "----------------------------------------"
           PERFORM 5100-ACCOUNT-DETAIL
           DISPLAY "========================================"
           DISPLAY "  END GL POSTING REPORT".

       5100-ACCOUNT-DETAIL.
           PERFORM VARYING WS-REPORT-IDX FROM 1 BY 1
               UNTIL WS-REPORT-IDX > WS-COA-COUNT
               IF WC-ACTIVE(WS-REPORT-IDX) = 1
                   MOVE WC-ACCOUNT-NUM(WS-REPORT-IDX)
                       TO WS-DISP-ACCT
                   DISPLAY "ACCT " WS-DISP-ACCT ": "
                       WC-ACCOUNT-NAME(WS-REPORT-IDX)
                   MOVE WC-BALANCE(WS-REPORT-IDX)
                       TO WS-DISP-AMOUNT
                   DISPLAY "  BALANCE: " WS-DISP-AMOUNT
                   MOVE WC-POST-COUNT(WS-REPORT-IDX)
                       TO WS-DISP-COUNT
                   DISPLAY "  POSTINGS: " WS-DISP-COUNT
               END-IF
           END-PERFORM.
