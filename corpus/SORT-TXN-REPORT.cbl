       IDENTIFICATION DIVISION.
       PROGRAM-ID. SORT-TXN-REPORT.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT TXN-INPUT-FILE
              ASSIGN TO 'TXNINPUT'
              ORGANIZATION IS SEQUENTIAL
              FILE STATUS IS WS-INPUT-STATUS.
           SELECT TXN-OUTPUT-FILE
              ASSIGN TO 'TXNOUTPUT'
              ORGANIZATION IS SEQUENTIAL
              FILE STATUS IS WS-OUTPUT-STATUS.
           SELECT SORT-WORK-FILE
              ASSIGN TO 'SORTWORK'.

       DATA DIVISION.
       FILE SECTION.

       FD TXN-INPUT-FILE.
       01 TXN-INPUT-REC.
          05 TI-ACCOUNT-NUM           PIC X(12).
          05 TI-TXN-DATE              PIC 9(8).
          05 TI-TXN-TYPE              PIC X(2).
          05 TI-TXN-AMOUNT            PIC S9(9)V99.
          05 TI-TXN-DESC              PIC X(30).
          05 TI-FILLER                PIC X(17).

       FD TXN-OUTPUT-FILE.
       01 TXN-OUTPUT-REC.
          05 TO-DETAIL-LINE           PIC X(80).

       SD SORT-WORK-FILE.
       01 SORT-WORK-REC.
          05 SW-ACCOUNT-NUM           PIC X(12).
          05 SW-TXN-DATE              PIC 9(8).
          05 SW-TXN-TYPE              PIC X(2).
          05 SW-TXN-AMOUNT            PIC S9(9)V99.
          05 SW-TXN-DESC              PIC X(30).
          05 SW-FILLER                PIC X(17).

       WORKING-STORAGE SECTION.

       01 WS-FILE-STATUS.
          05 WS-INPUT-STATUS          PIC X(2).
          05 WS-OUTPUT-STATUS         PIC X(2).

       01 WS-CONTROL-FLAGS.
          05 WS-EOF-FLAG              PIC X(1).
             88 END-OF-FILE           VALUE 'Y'.
             88 NOT-END-OF-FILE       VALUE 'N'.
          05 WS-RECORD-COUNT          PIC 9(6).

       01 WS-CATEGORY-TOTALS.
          05 WS-DEPOSIT-TOTAL         PIC S9(11)V99 COMP-3.
          05 WS-DEPOSIT-COUNT         PIC 9(6).
          05 WS-WITHDRAW-TOTAL        PIC S9(11)V99 COMP-3.
          05 WS-WITHDRAW-COUNT        PIC 9(6).
          05 WS-TRANSFER-TOTAL        PIC S9(11)V99 COMP-3.
          05 WS-TRANSFER-COUNT        PIC 9(6).
          05 WS-PAYMENT-TOTAL         PIC S9(11)V99 COMP-3.
          05 WS-PAYMENT-COUNT         PIC 9(6).
          05 WS-OTHER-TOTAL           PIC S9(11)V99 COMP-3.
          05 WS-OTHER-COUNT           PIC 9(6).

       01 WS-RUNNING-BAL.
          05 WS-BALANCE               PIC S9(11)V99 COMP-3.
          05 WS-PREV-BALANCE          PIC S9(11)V99 COMP-3.
          05 WS-NET-CHANGE            PIC S9(11)V99 COMP-3.

       01 WS-REPORT-FIELDS.
          05 WS-REPORT-LINE           PIC X(80).
          05 WS-CATEGORY-NAME         PIC X(12).
          05 WS-FORMATTED-AMT         PIC S9(9)V99 COMP-3.
          05 WS-GRAND-TOTAL           PIC S9(11)V99 COMP-3.
          05 WS-TOTAL-RECORDS         PIC 9(6).

       01 WS-WORK-FIELDS.
          05 WS-TEMP-AMT              PIC S9(11)V99 COMP-3.
          05 WS-ABS-AMOUNT            PIC S9(11)V99 COMP-3.

       PROCEDURE DIVISION.

       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           SORT SORT-WORK-FILE
              ON ASCENDING KEY SW-TXN-DATE
              USING TXN-INPUT-FILE
              GIVING TXN-OUTPUT-FILE
           PERFORM 2000-OPEN-FILES
           PERFORM 3000-PROCESS-RECORDS
              THRU 3900-PROCESS-EXIT
           PERFORM 4000-WRITE-SUMMARY THRU 4900-SUMMARY-EXIT
           PERFORM 5000-CLOSE-FILES
           STOP RUN.

       1000-INITIALIZE.
           INITIALIZE WS-CATEGORY-TOTALS
           INITIALIZE WS-RUNNING-BAL
           INITIALIZE WS-REPORT-FIELDS
           MOVE 0 TO WS-RECORD-COUNT
           SET NOT-END-OF-FILE TO TRUE.

       2000-OPEN-FILES.
           OPEN INPUT TXN-INPUT-FILE
           OPEN OUTPUT TXN-OUTPUT-FILE.

       3000-PROCESS-RECORDS.
           READ TXN-INPUT-FILE
              AT END
                 SET END-OF-FILE TO TRUE
              NOT AT END
                 PERFORM 3050-HANDLE-RECORD
           END-READ
           IF NOT-END-OF-FILE
              GO TO 3000-PROCESS-RECORDS
           END-IF.

       3050-HANDLE-RECORD.
           PERFORM 3100-CATEGORIZE-TXN
           PERFORM 3200-UPDATE-BALANCE
           PERFORM 3300-FORMAT-OUTPUT
           ADD 1 TO WS-RECORD-COUNT.

       3900-PROCESS-EXIT.
           DISPLAY "RECORDS PROCESSED: " WS-RECORD-COUNT.

       3100-CATEGORIZE-TXN.
           EVALUATE TRUE
              WHEN TI-TXN-TYPE = 'DP'
                 MOVE "DEPOSIT" TO WS-CATEGORY-NAME
                 ADD TI-TXN-AMOUNT TO WS-DEPOSIT-TOTAL
                 ADD 1 TO WS-DEPOSIT-COUNT
              WHEN TI-TXN-TYPE = 'WD'
                 MOVE "WITHDRAWAL" TO WS-CATEGORY-NAME
                 ADD TI-TXN-AMOUNT TO WS-WITHDRAW-TOTAL
                 ADD 1 TO WS-WITHDRAW-COUNT
              WHEN TI-TXN-TYPE = 'TR'
                 MOVE "TRANSFER" TO WS-CATEGORY-NAME
                 ADD TI-TXN-AMOUNT TO WS-TRANSFER-TOTAL
                 ADD 1 TO WS-TRANSFER-COUNT
              WHEN TI-TXN-TYPE = 'PY'
                 MOVE "PAYMENT" TO WS-CATEGORY-NAME
                 ADD TI-TXN-AMOUNT TO WS-PAYMENT-TOTAL
                 ADD 1 TO WS-PAYMENT-COUNT
              WHEN OTHER
                 MOVE "OTHER" TO WS-CATEGORY-NAME
                 ADD TI-TXN-AMOUNT TO WS-OTHER-TOTAL
                 ADD 1 TO WS-OTHER-COUNT
           END-EVALUATE.

       3200-UPDATE-BALANCE.
           MOVE WS-BALANCE TO WS-PREV-BALANCE
           EVALUATE TRUE
              WHEN TI-TXN-TYPE = 'DP'
                 ADD TI-TXN-AMOUNT TO WS-BALANCE
              WHEN TI-TXN-TYPE = 'WD'
                 SUBTRACT TI-TXN-AMOUNT FROM WS-BALANCE
              WHEN TI-TXN-TYPE = 'TR'
                 SUBTRACT TI-TXN-AMOUNT FROM WS-BALANCE
              WHEN TI-TXN-TYPE = 'PY'
                 SUBTRACT TI-TXN-AMOUNT FROM WS-BALANCE
              WHEN OTHER
                 SUBTRACT TI-TXN-AMOUNT FROM WS-BALANCE
           END-EVALUATE
           COMPUTE WS-NET-CHANGE =
              WS-BALANCE - WS-PREV-BALANCE.

       3300-FORMAT-OUTPUT.
           DISPLAY "TXN: " TI-TXN-DATE " "
              WS-CATEGORY-NAME " "
              TI-TXN-AMOUNT " BAL: " WS-BALANCE.

       4000-WRITE-SUMMARY.
           DISPLAY "===== TRANSACTION SUMMARY ====="
           DISPLAY "DEPOSITS:    " WS-DEPOSIT-TOTAL
              " COUNT: " WS-DEPOSIT-COUNT
           DISPLAY "WITHDRAWALS: " WS-WITHDRAW-TOTAL
              " COUNT: " WS-WITHDRAW-COUNT
           DISPLAY "TRANSFERS:   " WS-TRANSFER-TOTAL
              " COUNT: " WS-TRANSFER-COUNT
           DISPLAY "PAYMENTS:    " WS-PAYMENT-TOTAL
              " COUNT: " WS-PAYMENT-COUNT
           DISPLAY "OTHER:       " WS-OTHER-TOTAL
              " COUNT: " WS-OTHER-COUNT
           COMPUTE WS-GRAND-TOTAL =
              WS-DEPOSIT-TOTAL + WS-WITHDRAW-TOTAL +
              WS-TRANSFER-TOTAL + WS-PAYMENT-TOTAL +
              WS-OTHER-TOTAL
           COMPUTE WS-TOTAL-RECORDS =
              WS-DEPOSIT-COUNT + WS-WITHDRAW-COUNT +
              WS-TRANSFER-COUNT + WS-PAYMENT-COUNT +
              WS-OTHER-COUNT
           DISPLAY "GRAND TOTAL: " WS-GRAND-TOTAL
           DISPLAY "FINAL BALANCE: " WS-BALANCE.

       4900-SUMMARY-EXIT.
           DISPLAY "REPORT COMPLETE".

       5000-CLOSE-FILES.
           CLOSE TXN-INPUT-FILE
           CLOSE TXN-OUTPUT-FILE.
