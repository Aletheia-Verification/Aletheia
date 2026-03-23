       IDENTIFICATION DIVISION.
       PROGRAM-ID. SWIFT-MT940-RECON.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01 WS-STATEMENT-HEADER.
           05 WS-ACCT-ID              PIC X(34).
           05 WS-STATEMENT-NUM        PIC 9(5).
           05 WS-SEQUENCE-NUM         PIC 9(5).

       01 WS-OPENING-BAL.
           05 WS-OPEN-DC              PIC X(1).
               88 WS-OPEN-CREDIT      VALUE 'C'.
               88 WS-OPEN-DEBIT       VALUE 'D'.
           05 WS-OPEN-DATE            PIC 9(6).
           05 WS-OPEN-CCY             PIC X(3).
           05 WS-OPEN-AMOUNT          PIC S9(13)V99 COMP-3.

       01 WS-CLOSING-BAL.
           05 WS-CLOSE-DC             PIC X(1).
               88 WS-CLOSE-CREDIT     VALUE 'C'.
               88 WS-CLOSE-DEBIT      VALUE 'D'.
           05 WS-CLOSE-DATE           PIC 9(6).
           05 WS-CLOSE-CCY            PIC X(3).
           05 WS-CLOSE-AMOUNT         PIC S9(13)V99 COMP-3.

       01 WS-TXN-ENTRIES.
           05 WS-TXN OCCURS 30.
               10 WS-TX-DATE          PIC 9(6).
               10 WS-TX-DC            PIC X(1).
                   88 WS-TX-CREDIT    VALUE 'C'.
                   88 WS-TX-DEBIT     VALUE 'D'.
               10 WS-TX-AMOUNT        PIC S9(13)V99 COMP-3.
               10 WS-TX-REF           PIC X(16).
               10 WS-TX-DESC          PIC X(35).
       01 WS-TXN-COUNT                PIC 9(2) VALUE 0.
       01 WS-TXN-IDX                  PIC 9(2).

       01 WS-CALC-FIELDS.
           05 WS-SUM-CREDITS          PIC S9(15)V99 COMP-3
               VALUE 0.
           05 WS-SUM-DEBITS           PIC S9(15)V99 COMP-3
               VALUE 0.
           05 WS-EXPECTED-CLOSE       PIC S9(15)V99 COMP-3.
           05 WS-RECON-DIFF           PIC S9(15)V99 COMP-3.
           05 WS-ABS-DIFF             PIC S9(15)V99 COMP-3.

       01 WS-RECON-STATUS             PIC X(1).
           88 WS-BALANCED             VALUE 'B'.
           88 WS-UNBALANCED           VALUE 'U'.

       01 WS-TOLERANCE                PIC S9(5)V99 COMP-3
           VALUE 0.01.

       01 WS-COUNTERS.
           05 WS-CREDIT-COUNT         PIC 9(5) VALUE 0.
           05 WS-DEBIT-COUNT          PIC 9(5) VALUE 0.
           05 WS-RECON-COUNT          PIC S9(5) COMP-3 VALUE 0.
           05 WS-FAIL-COUNT           PIC S9(5) COMP-3 VALUE 0.

       01 WS-DETAIL-BUF               PIC X(60).
       01 WS-DETAIL-PTR               PIC 9(3).
       01 WS-ZERO-TALLY               PIC 9(3).

       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PROCESS-TRANSACTIONS
           PERFORM 3000-RECONCILE
           PERFORM 4000-DISPLAY-RESULTS
           STOP RUN.

       1000-INITIALIZE.
           MOVE 0 TO WS-SUM-CREDITS
           MOVE 0 TO WS-SUM-DEBITS
           MOVE 0 TO WS-CREDIT-COUNT
           MOVE 0 TO WS-DEBIT-COUNT
           MOVE 'U' TO WS-RECON-STATUS.

       2000-PROCESS-TRANSACTIONS.
           PERFORM VARYING WS-TXN-IDX FROM 1 BY 1
               UNTIL WS-TXN-IDX > WS-TXN-COUNT
               EVALUATE TRUE
                   WHEN WS-TX-CREDIT(WS-TXN-IDX)
                       ADD WS-TX-AMOUNT(WS-TXN-IDX) TO
                           WS-SUM-CREDITS
                       ADD 1 TO WS-CREDIT-COUNT
                   WHEN WS-TX-DEBIT(WS-TXN-IDX)
                       ADD WS-TX-AMOUNT(WS-TXN-IDX) TO
                           WS-SUM-DEBITS
                       ADD 1 TO WS-DEBIT-COUNT
                   WHEN OTHER
                       DISPLAY 'UNKNOWN DC INDICATOR: '
                           WS-TX-DC(WS-TXN-IDX)
                           ' REF: ' WS-TX-REF(WS-TXN-IDX)
               END-EVALUATE
           END-PERFORM.

       3000-RECONCILE.
           ADD 1 TO WS-RECON-COUNT
           IF WS-OPEN-CREDIT
               COMPUTE WS-EXPECTED-CLOSE =
                   WS-OPEN-AMOUNT + WS-SUM-CREDITS
                   - WS-SUM-DEBITS
           ELSE
               COMPUTE WS-EXPECTED-CLOSE =
                   (0 - WS-OPEN-AMOUNT) + WS-SUM-CREDITS
                   - WS-SUM-DEBITS
           END-IF
           IF WS-CLOSE-CREDIT
               COMPUTE WS-RECON-DIFF =
                   WS-EXPECTED-CLOSE - WS-CLOSE-AMOUNT
           ELSE
               COMPUTE WS-RECON-DIFF =
                   WS-EXPECTED-CLOSE +
                   WS-CLOSE-AMOUNT
           END-IF
           IF WS-RECON-DIFF < 0
               COMPUTE WS-ABS-DIFF = 0 - WS-RECON-DIFF
           ELSE
               MOVE WS-RECON-DIFF TO WS-ABS-DIFF
           END-IF
           IF WS-ABS-DIFF <= WS-TOLERANCE
               MOVE 'B' TO WS-RECON-STATUS
           ELSE
               MOVE 'U' TO WS-RECON-STATUS
               ADD 1 TO WS-FAIL-COUNT
           END-IF.

       4000-DISPLAY-RESULTS.
           MOVE SPACES TO WS-DETAIL-BUF
           MOVE 1 TO WS-DETAIL-PTR
           IF WS-BALANCED
               STRING 'STATEMENT BALANCED OK'
                   DELIMITED BY SIZE
                   INTO WS-DETAIL-BUF
                   WITH POINTER WS-DETAIL-PTR
               END-STRING
           ELSE
               STRING 'STATEMENT UNBALANCED DIFF='
                   DELIMITED BY SIZE
                   INTO WS-DETAIL-BUF
                   WITH POINTER WS-DETAIL-PTR
               END-STRING
           END-IF
           MOVE 0 TO WS-ZERO-TALLY
           INSPECT WS-ACCT-ID
               TALLYING WS-ZERO-TALLY FOR ALL '0'
           DISPLAY 'MT940 RECONCILIATION RESULTS'
           DISPLAY 'ACCOUNT:         ' WS-ACCT-ID
           DISPLAY 'STATEMENT #:     ' WS-STATEMENT-NUM
           DISPLAY 'OPENING BAL:     ' WS-OPEN-AMOUNT
           DISPLAY 'TOTAL CREDITS:   ' WS-SUM-CREDITS
           DISPLAY 'TOTAL DEBITS:    ' WS-SUM-DEBITS
           DISPLAY 'EXPECTED CLOSE:  ' WS-EXPECTED-CLOSE
           DISPLAY 'ACTUAL CLOSE:    ' WS-CLOSE-AMOUNT
           DISPLAY 'DIFFERENCE:      ' WS-RECON-DIFF
           DISPLAY 'STATUS:          ' WS-DETAIL-BUF
           DISPLAY 'CREDIT TXN CNT:  ' WS-CREDIT-COUNT
           DISPLAY 'DEBIT TXN CNT:   ' WS-DEBIT-COUNT.
