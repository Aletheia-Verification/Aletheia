       IDENTIFICATION DIVISION.
       PROGRAM-ID. PAY-BATCH-SETTLE.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT PAY-FILE ASSIGN TO 'PAYMENTS.DAT'
               FILE STATUS IS WS-PAY-STATUS.
           SELECT SETTLE-FILE ASSIGN TO 'SETTLE.DAT'
               FILE STATUS IS WS-SETTLE-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD PAY-FILE.
       01 PAY-RECORD.
           05 PR-BATCH-ID            PIC X(10).
           05 PR-TXN-TYPE            PIC X(2).
           05 PR-AMOUNT              PIC 9(9)V99.
           05 PR-ACCT-FROM           PIC X(12).
           05 PR-ACCT-TO             PIC X(12).
           05 PR-STATUS              PIC X(1).
       FD SETTLE-FILE.
       01 SETTLE-RECORD.
           05 ST-BATCH-ID            PIC X(10).
           05 ST-TOTAL-DEBITS        PIC 9(11)V99.
           05 ST-TOTAL-CREDITS       PIC 9(11)V99.
           05 ST-NET-AMOUNT          PIC S9(11)V99.
           05 ST-TXN-COUNT           PIC 9(5).
           05 ST-STATUS              PIC X(8).
       WORKING-STORAGE SECTION.
       01 WS-PAY-STATUS              PIC XX.
       01 WS-SETTLE-STATUS           PIC XX.
       01 WS-EOF-FLAG                PIC X VALUE 'N'.
           88 WS-EOF                  VALUE 'Y'.
       01 WS-BATCH-TOTALS.
           05 WS-BATCH-DEBITS        PIC S9(11)V99 COMP-3.
           05 WS-BATCH-CREDITS       PIC S9(11)V99 COMP-3.
           05 WS-BATCH-NET           PIC S9(11)V99 COMP-3.
           05 WS-BATCH-COUNT         PIC S9(5) COMP-3.
           05 WS-BATCH-ERRORS        PIC S9(5) COMP-3.
       01 WS-SETTLE-TABLE.
           05 WS-SETTLE-ENTRY OCCURS 20.
               10 WS-SE-BANK-ID      PIC X(8).
               10 WS-SE-DEBIT-TOT    PIC S9(11)V99 COMP-3.
               10 WS-SE-CREDIT-TOT   PIC S9(11)V99 COMP-3.
               10 WS-SE-NET          PIC S9(11)V99 COMP-3.
       01 WS-SE-IDX                  PIC 9(2).
       01 WS-SE-COUNT                PIC 9(2).
       01 WS-CURRENT-BATCH           PIC X(10).
       01 WS-TXN-VALID               PIC X VALUE 'Y'.
           88 WS-IS-VALID             VALUE 'Y'.
           88 WS-IS-INVALID           VALUE 'N'.
       01 WS-GRAND-DEBITS            PIC S9(13)V99 COMP-3.
       01 WS-GRAND-CREDITS           PIC S9(13)V99 COMP-3.
       01 WS-GRAND-COUNT             PIC S9(7) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 1100-OPEN-FILES
           PERFORM 2000-PROCESS-PAYMENTS UNTIL WS-EOF
           PERFORM 3000-WRITE-FINAL-SETTLE
           PERFORM 4000-CLOSE-FILES
           PERFORM 5000-DISPLAY-SUMMARY
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-BATCH-DEBITS
           MOVE 0 TO WS-BATCH-CREDITS
           MOVE 0 TO WS-BATCH-COUNT
           MOVE 0 TO WS-BATCH-ERRORS
           MOVE 0 TO WS-GRAND-DEBITS
           MOVE 0 TO WS-GRAND-CREDITS
           MOVE 0 TO WS-GRAND-COUNT
           MOVE 0 TO WS-SE-COUNT
           MOVE SPACES TO WS-CURRENT-BATCH.
       1100-OPEN-FILES.
           OPEN INPUT PAY-FILE
           OPEN OUTPUT SETTLE-FILE.
       2000-PROCESS-PAYMENTS.
           READ PAY-FILE
               AT END SET WS-EOF TO TRUE
               NOT AT END PERFORM 2100-VALIDATE-TXN
                          PERFORM 2200-ACCUMULATE
           END-READ.
       2100-VALIDATE-TXN.
           MOVE 'Y' TO WS-TXN-VALID
           IF PR-AMOUNT <= 0
               MOVE 'N' TO WS-TXN-VALID
               ADD 1 TO WS-BATCH-ERRORS
           END-IF
           IF PR-ACCT-FROM = SPACES
               MOVE 'N' TO WS-TXN-VALID
               ADD 1 TO WS-BATCH-ERRORS
           END-IF.
       2200-ACCUMULATE.
           IF WS-IS-VALID
               ADD 1 TO WS-BATCH-COUNT
               ADD 1 TO WS-GRAND-COUNT
               EVALUATE PR-TXN-TYPE
                   WHEN 'DB'
                       ADD PR-AMOUNT TO WS-BATCH-DEBITS
                       ADD PR-AMOUNT TO WS-GRAND-DEBITS
                   WHEN 'CR'
                       ADD PR-AMOUNT TO WS-BATCH-CREDITS
                       ADD PR-AMOUNT TO WS-GRAND-CREDITS
                   WHEN OTHER
                       ADD 1 TO WS-BATCH-ERRORS
               END-EVALUATE
           END-IF.
       3000-WRITE-FINAL-SETTLE.
           COMPUTE WS-BATCH-NET =
               WS-BATCH-DEBITS - WS-BATCH-CREDITS
           MOVE WS-CURRENT-BATCH TO ST-BATCH-ID
           MOVE WS-BATCH-DEBITS TO ST-TOTAL-DEBITS
           MOVE WS-BATCH-CREDITS TO ST-TOTAL-CREDITS
           MOVE WS-BATCH-NET TO ST-NET-AMOUNT
           MOVE WS-BATCH-COUNT TO ST-TXN-COUNT
           IF WS-BATCH-ERRORS > 0
               MOVE 'ERRORS  ' TO ST-STATUS
           ELSE
               MOVE 'SETTLED ' TO ST-STATUS
           END-IF
           WRITE SETTLE-RECORD.
       4000-CLOSE-FILES.
           CLOSE PAY-FILE
           CLOSE SETTLE-FILE.
       5000-DISPLAY-SUMMARY.
           DISPLAY 'BATCH SETTLEMENT SUMMARY'
           DISPLAY '========================'
           DISPLAY 'TOTAL DEBITS:  ' WS-GRAND-DEBITS
           DISPLAY 'TOTAL CREDITS: ' WS-GRAND-CREDITS
           DISPLAY 'TRANSACTIONS:  ' WS-GRAND-COUNT
           DISPLAY 'ERRORS:        ' WS-BATCH-ERRORS.
