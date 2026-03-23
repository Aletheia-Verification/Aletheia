       IDENTIFICATION DIVISION.
       PROGRAM-ID. PAY-LIMIT-ENFORCE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-TXN-DATA.
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-TXN-AMOUNT          PIC S9(9)V99 COMP-3.
           05 WS-TXN-TYPE            PIC X(2).
       01 WS-LIMIT-TIER              PIC X(1).
           88 WS-CONSUMER            VALUE 'C'.
           88 WS-BUSINESS            VALUE 'B'.
           88 WS-CORPORATE           VALUE 'R'.
       01 WS-LIMITS.
           05 WS-PER-TXN-LIMIT       PIC S9(9)V99 COMP-3.
           05 WS-DAILY-LIMIT         PIC S9(11)V99 COMP-3.
           05 WS-MONTHLY-LIMIT       PIC S9(11)V99 COMP-3.
           05 WS-DAILY-USED          PIC S9(11)V99 COMP-3.
           05 WS-MONTHLY-USED        PIC S9(11)V99 COMP-3.
           05 WS-DAILY-REMAIN        PIC S9(11)V99 COMP-3.
           05 WS-MONTHLY-REMAIN      PIC S9(11)V99 COMP-3.
       01 WS-CHECK-RESULT            PIC X(1).
           88 WS-APPROVED            VALUE 'A'.
           88 WS-DENIED              VALUE 'D'.
           88 WS-PENDING-REVIEW      VALUE 'P'.
       01 WS-DENY-REASON             PIC X(30).
       01 WS-OVERRIDE-FLAG           PIC X VALUE 'N'.
           88 WS-HAS-OVERRIDE        VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-SET-LIMITS
           PERFORM 3000-CHECK-PER-TXN
           PERFORM 4000-CHECK-DAILY
           PERFORM 5000-CHECK-MONTHLY
           PERFORM 6000-FINAL-DECISION
           PERFORM 7000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE SPACES TO WS-DENY-REASON
           SET WS-APPROVED TO TRUE.
       2000-SET-LIMITS.
           EVALUATE TRUE
               WHEN WS-CONSUMER
                   MOVE 10000.00 TO WS-PER-TXN-LIMIT
                   MOVE 25000.00 TO WS-DAILY-LIMIT
                   MOVE 100000.00 TO WS-MONTHLY-LIMIT
               WHEN WS-BUSINESS
                   MOVE 100000.00 TO WS-PER-TXN-LIMIT
                   MOVE 500000.00 TO WS-DAILY-LIMIT
                   MOVE 2000000.00 TO WS-MONTHLY-LIMIT
               WHEN WS-CORPORATE
                   MOVE 1000000.00 TO WS-PER-TXN-LIMIT
                   MOVE 5000000.00 TO WS-DAILY-LIMIT
                   MOVE 50000000.00 TO WS-MONTHLY-LIMIT
               WHEN OTHER
                   MOVE 5000.00 TO WS-PER-TXN-LIMIT
                   MOVE 10000.00 TO WS-DAILY-LIMIT
                   MOVE 50000.00 TO WS-MONTHLY-LIMIT
           END-EVALUATE
           COMPUTE WS-DAILY-REMAIN =
               WS-DAILY-LIMIT - WS-DAILY-USED
           COMPUTE WS-MONTHLY-REMAIN =
               WS-MONTHLY-LIMIT - WS-MONTHLY-USED.
       3000-CHECK-PER-TXN.
           IF WS-TXN-AMOUNT > WS-PER-TXN-LIMIT
               IF WS-HAS-OVERRIDE
                   SET WS-PENDING-REVIEW TO TRUE
               ELSE
                   SET WS-DENIED TO TRUE
                   MOVE 'EXCEEDS PER-TXN LIMIT' TO
                       WS-DENY-REASON
               END-IF
           END-IF.
       4000-CHECK-DAILY.
           IF WS-APPROVED OR WS-PENDING-REVIEW
               IF WS-TXN-AMOUNT > WS-DAILY-REMAIN
                   IF WS-PENDING-REVIEW
                       SET WS-DENIED TO TRUE
                       MOVE 'EXCEEDS DAILY LIMIT' TO
                           WS-DENY-REASON
                   ELSE
                       IF WS-HAS-OVERRIDE
                           SET WS-PENDING-REVIEW TO TRUE
                       ELSE
                           SET WS-DENIED TO TRUE
                           MOVE 'EXCEEDS DAILY LIMIT' TO
                               WS-DENY-REASON
                       END-IF
                   END-IF
               END-IF
           END-IF.
       5000-CHECK-MONTHLY.
           IF WS-APPROVED OR WS-PENDING-REVIEW
               IF WS-TXN-AMOUNT > WS-MONTHLY-REMAIN
                   SET WS-DENIED TO TRUE
                   MOVE 'EXCEEDS MONTHLY LIMIT' TO
                       WS-DENY-REASON
               END-IF
           END-IF.
       6000-FINAL-DECISION.
           IF WS-APPROVED
               ADD WS-TXN-AMOUNT TO WS-DAILY-USED
               ADD WS-TXN-AMOUNT TO WS-MONTHLY-USED
               DISPLAY 'TRANSACTION APPROVED'
           END-IF.
       7000-DISPLAY-RESULTS.
           DISPLAY 'PAYMENT LIMIT ENFORCEMENT'
           DISPLAY '========================='
           DISPLAY 'ACCOUNT:        ' WS-ACCT-NUM
           DISPLAY 'TXN AMOUNT:     ' WS-TXN-AMOUNT
           DISPLAY 'PER-TXN LIMIT:  ' WS-PER-TXN-LIMIT
           DISPLAY 'DAILY LIMIT:    ' WS-DAILY-LIMIT
           DISPLAY 'DAILY USED:     ' WS-DAILY-USED
           DISPLAY 'MONTHLY LIMIT:  ' WS-MONTHLY-LIMIT
           DISPLAY 'MONTHLY USED:   ' WS-MONTHLY-USED
           IF WS-APPROVED
               DISPLAY 'RESULT: APPROVED'
           END-IF
           IF WS-DENIED
               DISPLAY 'RESULT: DENIED'
               DISPLAY 'REASON: ' WS-DENY-REASON
           END-IF
           IF WS-PENDING-REVIEW
               DISPLAY 'RESULT: PENDING REVIEW'
           END-IF.
