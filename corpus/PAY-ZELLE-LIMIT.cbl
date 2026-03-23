       IDENTIFICATION DIVISION.
       PROGRAM-ID. PAY-ZELLE-LIMIT.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-PAYMENT-REQUEST.
           05 WS-SENDER-ACCT     PIC X(12).
           05 WS-RECIPIENT-ID    PIC X(30).
           05 WS-AMOUNT          PIC S9(7)V99 COMP-3.
           05 WS-MEMO            PIC X(30).
       01 WS-SENDER-PROFILE.
           05 WS-ENROLLED-DATE   PIC 9(8).
           05 WS-DAILY-SENT      PIC S9(7)V99 COMP-3.
           05 WS-WEEKLY-SENT     PIC S9(7)V99 COMP-3.
           05 WS-MONTHLY-SENT    PIC S9(9)V99 COMP-3.
           05 WS-ACCT-BALANCE    PIC S9(9)V99 COMP-3.
           05 WS-CUST-TIER       PIC 9.
               88 TIER-BASIC     VALUE 1.
               88 TIER-STANDARD  VALUE 2.
               88 TIER-PREMIUM   VALUE 3.
       01 WS-LIMITS.
           05 WS-DAILY-LIMIT     PIC S9(7)V99 COMP-3.
           05 WS-WEEKLY-LIMIT    PIC S9(7)V99 COMP-3.
           05 WS-MONTHLY-LIMIT   PIC S9(9)V99 COMP-3.
           05 WS-PER-TXN-LIMIT   PIC S9(7)V99 COMP-3.
       01 WS-RESULT              PIC X(12).
       01 WS-DECLINE-REASON      PIC X(30).
       01 WS-CURRENT-DATE        PIC 9(8).
       01 WS-MONTHS-ENROLLED     PIC 9(3).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-SET-LIMITS
           PERFORM 2000-CHECK-LIMITS
           PERFORM 3000-CHECK-BALANCE
           PERFORM 4000-OUTPUT
           STOP RUN.
       1000-SET-LIMITS.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           COMPUTE WS-MONTHS-ENROLLED =
               (WS-CURRENT-DATE - WS-ENROLLED-DATE) / 100
           EVALUATE TRUE
               WHEN TIER-BASIC
                   MOVE 500.00 TO WS-DAILY-LIMIT
                   MOVE 1000.00 TO WS-WEEKLY-LIMIT
                   MOVE 2500.00 TO WS-MONTHLY-LIMIT
                   MOVE 500.00 TO WS-PER-TXN-LIMIT
               WHEN TIER-STANDARD
                   MOVE 2000.00 TO WS-DAILY-LIMIT
                   MOVE 5000.00 TO WS-WEEKLY-LIMIT
                   MOVE 10000.00 TO WS-MONTHLY-LIMIT
                   MOVE 2000.00 TO WS-PER-TXN-LIMIT
               WHEN TIER-PREMIUM
                   MOVE 5000.00 TO WS-DAILY-LIMIT
                   MOVE 15000.00 TO WS-WEEKLY-LIMIT
                   MOVE 50000.00 TO WS-MONTHLY-LIMIT
                   MOVE 5000.00 TO WS-PER-TXN-LIMIT
               WHEN OTHER
                   MOVE 250.00 TO WS-DAILY-LIMIT
                   MOVE 500.00 TO WS-WEEKLY-LIMIT
                   MOVE 1000.00 TO WS-MONTHLY-LIMIT
                   MOVE 250.00 TO WS-PER-TXN-LIMIT
           END-EVALUATE
           IF WS-MONTHS-ENROLLED < 3
               COMPUTE WS-DAILY-LIMIT =
                   WS-DAILY-LIMIT * 0.50
               COMPUTE WS-PER-TXN-LIMIT =
                   WS-PER-TXN-LIMIT * 0.50
           END-IF.
       2000-CHECK-LIMITS.
           MOVE 'APPROVED    ' TO WS-RESULT
           IF WS-AMOUNT > WS-PER-TXN-LIMIT
               MOVE 'DECLINED    ' TO WS-RESULT
               MOVE 'EXCEEDS PER-TXN LIMIT' TO
                   WS-DECLINE-REASON
           END-IF
           IF WS-RESULT = 'APPROVED    '
               COMPUTE WS-DAILY-SENT =
                   WS-DAILY-SENT + WS-AMOUNT
               IF WS-DAILY-SENT > WS-DAILY-LIMIT
                   MOVE 'DECLINED    ' TO WS-RESULT
                   MOVE 'DAILY LIMIT EXCEEDED' TO
                       WS-DECLINE-REASON
               END-IF
           END-IF
           IF WS-RESULT = 'APPROVED    '
               COMPUTE WS-WEEKLY-SENT =
                   WS-WEEKLY-SENT + WS-AMOUNT
               IF WS-WEEKLY-SENT > WS-WEEKLY-LIMIT
                   MOVE 'DECLINED    ' TO WS-RESULT
                   MOVE 'WEEKLY LIMIT EXCEEDED' TO
                       WS-DECLINE-REASON
               END-IF
           END-IF
           IF WS-RESULT = 'APPROVED    '
               COMPUTE WS-MONTHLY-SENT =
                   WS-MONTHLY-SENT + WS-AMOUNT
               IF WS-MONTHLY-SENT > WS-MONTHLY-LIMIT
                   MOVE 'DECLINED    ' TO WS-RESULT
                   MOVE 'MONTHLY LIMIT EXCEEDED' TO
                       WS-DECLINE-REASON
               END-IF
           END-IF.
       3000-CHECK-BALANCE.
           IF WS-RESULT = 'APPROVED    '
               IF WS-AMOUNT > WS-ACCT-BALANCE
                   MOVE 'DECLINED    ' TO WS-RESULT
                   MOVE 'INSUFFICIENT FUNDS' TO
                       WS-DECLINE-REASON
               ELSE
                   SUBTRACT WS-AMOUNT FROM WS-ACCT-BALANCE
               END-IF
           END-IF.
       4000-OUTPUT.
           DISPLAY 'ZELLE PAYMENT RESULT'
           DISPLAY '===================='
           DISPLAY 'SENDER:   ' WS-SENDER-ACCT
           DISPLAY 'TO:       ' WS-RECIPIENT-ID
           DISPLAY 'AMOUNT:   $' WS-AMOUNT
           DISPLAY 'RESULT:   ' WS-RESULT
           IF WS-RESULT NOT = 'APPROVED    '
               DISPLAY 'REASON:   ' WS-DECLINE-REASON
           ELSE
               DISPLAY 'NEW BAL:  $' WS-ACCT-BALANCE
           END-IF.
