       IDENTIFICATION DIVISION.
       PROGRAM-ID. CORR-BANK-SETTLE.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT PAYMENT-FILE ASSIGN TO 'PAYIN'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-PAY-STATUS.
           SELECT SETTLE-FILE ASSIGN TO 'SETTLEOUT'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-SET-STATUS.

       DATA DIVISION.
       FILE SECTION.

       FD PAYMENT-FILE.
       01 PAY-RECORD.
           05 PAY-MSG-REF             PIC X(16).
           05 PAY-SENDER-BIC          PIC X(11).
           05 PAY-RECEIVER-BIC        PIC X(11).
           05 PAY-AMOUNT              PIC S9(13)V99 COMP-3.
           05 PAY-CURRENCY            PIC X(3).
           05 PAY-VALUE-DATE          PIC 9(8).
           05 PAY-CHARGE-CODE         PIC X(3).
               88 PAY-OUR             VALUE 'OUR'.
               88 PAY-BEN             VALUE 'BEN'.
               88 PAY-SHA             VALUE 'SHA'.
           05 PAY-PRIORITY            PIC X(1).
               88 PAY-URGENT          VALUE 'U'.
               88 PAY-NORMAL          VALUE 'N'.

       FD SETTLE-FILE.
       01 SETTLE-RECORD.
           05 SET-CORR-BIC            PIC X(11).
           05 SET-NET-AMOUNT          PIC S9(15)V99 COMP-3.
           05 SET-CURRENCY            PIC X(3).
           05 SET-TXN-COUNT           PIC 9(5).
           05 SET-CHARGE-TOTAL        PIC S9(9)V99 COMP-3.
           05 SET-STATUS              PIC X(10).

       WORKING-STORAGE SECTION.

       01 WS-PAY-STATUS               PIC X(2).
       01 WS-SET-STATUS               PIC X(2).
       01 WS-EOF-FLAG                 PIC X VALUE 'N'.
           88 WS-EOF                   VALUE 'Y'.

       01 WS-CORR-TABLE.
           05 WS-CORR OCCURS 20.
               10 WS-CR-BIC           PIC X(11).
               10 WS-CR-NET           PIC S9(15)V99 COMP-3.
               10 WS-CR-CCY           PIC X(3).
               10 WS-CR-COUNT         PIC 9(5).
               10 WS-CR-CHARGES       PIC S9(9)V99 COMP-3.

       01 WS-CORR-USED                PIC 9(2) VALUE 0.
       01 WS-CORR-IDX                 PIC 9(2).
       01 WS-FOUND-IDX                PIC 9(2).
       01 WS-FOUND-FLAG               PIC X VALUE 'N'.
           88 WS-CORR-FOUND           VALUE 'Y'.

       01 WS-CHARGE-AMT               PIC S9(9)V99 COMP-3.
       01 WS-CHARGE-RATE-OUR          PIC S9(3)V99 COMP-3
           VALUE 25.00.
       01 WS-CHARGE-RATE-SHA          PIC S9(3)V99 COMP-3
           VALUE 12.50.

       01 WS-COUNTERS.
           05 WS-TOTAL-PAYMENTS       PIC S9(7) COMP-3 VALUE 0.
           05 WS-URGENT-COUNT         PIC S9(7) COMP-3 VALUE 0.
           05 WS-TOTAL-VALUE          PIC S9(15)V99 COMP-3
               VALUE 0.

       01 WS-LOOP-IDX                 PIC 9(2).

       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 1100-OPEN-FILES
           PERFORM 1200-READ-FIRST
           PERFORM 2000-PROCESS-PAYMENT
               UNTIL WS-EOF
           PERFORM 3000-WRITE-SETTLEMENTS
           PERFORM 4000-CLOSE-FILES
           PERFORM 5000-DISPLAY-SUMMARY
           STOP RUN.

       1000-INITIALIZE.
           MOVE 'N' TO WS-EOF-FLAG
           MOVE 0 TO WS-CORR-USED
           PERFORM VARYING WS-LOOP-IDX FROM 1 BY 1
               UNTIL WS-LOOP-IDX > 20
               MOVE SPACES TO WS-CR-BIC(WS-LOOP-IDX)
               MOVE 0 TO WS-CR-NET(WS-LOOP-IDX)
               MOVE SPACES TO WS-CR-CCY(WS-LOOP-IDX)
               MOVE 0 TO WS-CR-COUNT(WS-LOOP-IDX)
               MOVE 0 TO WS-CR-CHARGES(WS-LOOP-IDX)
           END-PERFORM.

       1100-OPEN-FILES.
           OPEN INPUT PAYMENT-FILE
           OPEN OUTPUT SETTLE-FILE.

       1200-READ-FIRST.
           READ PAYMENT-FILE
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ.

       2000-PROCESS-PAYMENT.
           ADD 1 TO WS-TOTAL-PAYMENTS
           ADD PAY-AMOUNT TO WS-TOTAL-VALUE
           IF PAY-URGENT
               ADD 1 TO WS-URGENT-COUNT
           END-IF
           PERFORM 2100-CALC-CHARGES
           PERFORM 2200-FIND-CORR-ENTRY
           IF WS-CORR-FOUND
               ADD PAY-AMOUNT TO
                   WS-CR-NET(WS-FOUND-IDX)
               ADD 1 TO WS-CR-COUNT(WS-FOUND-IDX)
               ADD WS-CHARGE-AMT TO
                   WS-CR-CHARGES(WS-FOUND-IDX)
           ELSE
               IF WS-CORR-USED < 20
                   ADD 1 TO WS-CORR-USED
                   MOVE PAY-RECEIVER-BIC TO
                       WS-CR-BIC(WS-CORR-USED)
                   MOVE PAY-AMOUNT TO
                       WS-CR-NET(WS-CORR-USED)
                   MOVE PAY-CURRENCY TO
                       WS-CR-CCY(WS-CORR-USED)
                   MOVE 1 TO WS-CR-COUNT(WS-CORR-USED)
                   MOVE WS-CHARGE-AMT TO
                       WS-CR-CHARGES(WS-CORR-USED)
               ELSE
                   DISPLAY 'CORR TABLE FULL, SKIPPING '
                       PAY-RECEIVER-BIC
               END-IF
           END-IF
           READ PAYMENT-FILE
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ.

       2100-CALC-CHARGES.
           MOVE 0 TO WS-CHARGE-AMT
           EVALUATE TRUE
               WHEN PAY-OUR
                   MOVE WS-CHARGE-RATE-OUR TO WS-CHARGE-AMT
                   IF PAY-URGENT
                       COMPUTE WS-CHARGE-AMT =
                           WS-CHARGE-AMT * 2
                   END-IF
               WHEN PAY-SHA
                   MOVE WS-CHARGE-RATE-SHA TO WS-CHARGE-AMT
               WHEN PAY-BEN
                   MOVE 0 TO WS-CHARGE-AMT
               WHEN OTHER
                   MOVE WS-CHARGE-RATE-SHA TO WS-CHARGE-AMT
           END-EVALUATE.

       2200-FIND-CORR-ENTRY.
           MOVE 'N' TO WS-FOUND-FLAG
           PERFORM VARYING WS-CORR-IDX FROM 1 BY 1
               UNTIL WS-CORR-IDX > WS-CORR-USED
               OR WS-CORR-FOUND
               IF WS-CR-BIC(WS-CORR-IDX) =
                   PAY-RECEIVER-BIC
                   MOVE 'Y' TO WS-FOUND-FLAG
                   MOVE WS-CORR-IDX TO WS-FOUND-IDX
               END-IF
           END-PERFORM.

       3000-WRITE-SETTLEMENTS.
           PERFORM VARYING WS-LOOP-IDX FROM 1 BY 1
               UNTIL WS-LOOP-IDX > WS-CORR-USED
               MOVE WS-CR-BIC(WS-LOOP-IDX) TO SET-CORR-BIC
               MOVE WS-CR-NET(WS-LOOP-IDX) TO SET-NET-AMOUNT
               MOVE WS-CR-CCY(WS-LOOP-IDX) TO SET-CURRENCY
               MOVE WS-CR-COUNT(WS-LOOP-IDX) TO
                   SET-TXN-COUNT
               MOVE WS-CR-CHARGES(WS-LOOP-IDX) TO
                   SET-CHARGE-TOTAL
               IF WS-CR-NET(WS-LOOP-IDX) > 0
                   MOVE 'DEBIT     ' TO SET-STATUS
               ELSE
                   MOVE 'CREDIT    ' TO SET-STATUS
               END-IF
               WRITE SETTLE-RECORD
           END-PERFORM.

       4000-CLOSE-FILES.
           CLOSE PAYMENT-FILE
           CLOSE SETTLE-FILE.

       5000-DISPLAY-SUMMARY.
           DISPLAY 'CORRESPONDENT BANK SETTLEMENT COMPLETE'
           DISPLAY 'TOTAL PAYMENTS: ' WS-TOTAL-PAYMENTS
           DISPLAY 'URGENT PAYMENTS:' WS-URGENT-COUNT
           DISPLAY 'TOTAL VALUE:    ' WS-TOTAL-VALUE
           DISPLAY 'CORR BANKS:     ' WS-CORR-USED.
