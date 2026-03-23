       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCT-HOLD-RELEASE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ACCT-DATA.
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-TOTAL-BAL           PIC S9(9)V99 COMP-3.
           05 WS-AVAIL-BAL           PIC S9(9)V99 COMP-3.
           05 WS-HELD-BAL            PIC S9(9)V99 COMP-3.
       01 WS-HOLD-DATA.
           05 WS-HOLD-AMOUNT         PIC S9(9)V99 COMP-3.
           05 WS-HOLD-DATE           PIC 9(8).
           05 WS-RELEASE-DATE        PIC 9(8).
           05 WS-CURRENT-DATE        PIC 9(8).
           05 WS-HOLD-DAYS           PIC 9(3).
           05 WS-DAYS-HELD           PIC 9(3).
       01 WS-HOLD-TYPE               PIC X(1).
           88 WS-CHECK-HOLD          VALUE 'C'.
           88 WS-LEGAL-HOLD          VALUE 'L'.
           88 WS-ADMIN-HOLD          VALUE 'A'.
           88 WS-DISPUTE-HOLD        VALUE 'D'.
       01 WS-HOLD-STATUS             PIC X(1).
           88 WS-ACTIVE-HOLD         VALUE 'A'.
           88 WS-RELEASED            VALUE 'R'.
           88 WS-EXPIRED             VALUE 'E'.
       01 WS-AUTO-RELEASE            PIC X VALUE 'N'.
           88 WS-CAN-AUTO-RELEASE    VALUE 'Y'.
       01 WS-RELEASE-AMOUNT          PIC S9(9)V99 COMP-3.
       01 WS-PARTIAL-RELEASE         PIC S9(9)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-SET-HOLD-DAYS
           PERFORM 3000-CHECK-EXPIRY
           PERFORM 4000-PROCESS-RELEASE
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           SET WS-ACTIVE-HOLD TO TRUE
           MOVE 'N' TO WS-AUTO-RELEASE
           MOVE 0 TO WS-RELEASE-AMOUNT
           MOVE 0 TO WS-PARTIAL-RELEASE.
       2000-SET-HOLD-DAYS.
           EVALUATE TRUE
               WHEN WS-CHECK-HOLD
                   IF WS-HOLD-AMOUNT > 5525
                       MOVE 7 TO WS-HOLD-DAYS
                   ELSE
                       MOVE 2 TO WS-HOLD-DAYS
                   END-IF
                   MOVE 'Y' TO WS-AUTO-RELEASE
               WHEN WS-LEGAL-HOLD
                   MOVE 999 TO WS-HOLD-DAYS
                   MOVE 'N' TO WS-AUTO-RELEASE
               WHEN WS-ADMIN-HOLD
                   MOVE 30 TO WS-HOLD-DAYS
                   MOVE 'Y' TO WS-AUTO-RELEASE
               WHEN WS-DISPUTE-HOLD
                   MOVE 45 TO WS-HOLD-DAYS
                   MOVE 'N' TO WS-AUTO-RELEASE
               WHEN OTHER
                   MOVE 5 TO WS-HOLD-DAYS
                   MOVE 'Y' TO WS-AUTO-RELEASE
           END-EVALUATE.
       3000-CHECK-EXPIRY.
           IF WS-CURRENT-DATE > WS-HOLD-DATE
               COMPUTE WS-DAYS-HELD =
                   WS-CURRENT-DATE - WS-HOLD-DATE
           ELSE
               MOVE 0 TO WS-DAYS-HELD
           END-IF
           IF WS-DAYS-HELD >= WS-HOLD-DAYS
               IF WS-CAN-AUTO-RELEASE
                   SET WS-EXPIRED TO TRUE
               END-IF
           END-IF.
       4000-PROCESS-RELEASE.
           IF WS-EXPIRED
               MOVE WS-HOLD-AMOUNT TO WS-RELEASE-AMOUNT
               ADD WS-RELEASE-AMOUNT TO WS-AVAIL-BAL
               SUBTRACT WS-RELEASE-AMOUNT FROM WS-HELD-BAL
               SET WS-RELEASED TO TRUE
               DISPLAY 'AUTO-RELEASE: ' WS-RELEASE-AMOUNT
           ELSE
               IF WS-CHECK-HOLD
                   IF WS-DAYS-HELD >= 1
                       IF WS-HOLD-AMOUNT > 5525
                           MOVE 5525.00 TO
                               WS-PARTIAL-RELEASE
                           ADD WS-PARTIAL-RELEASE TO
                               WS-AVAIL-BAL
                       END-IF
                   END-IF
               END-IF
           END-IF.
       5000-DISPLAY-RESULTS.
           DISPLAY 'HOLD/RELEASE PROCESSING'
           DISPLAY '======================='
           DISPLAY 'ACCOUNT:      ' WS-ACCT-NUM
           DISPLAY 'TOTAL BAL:    ' WS-TOTAL-BAL
           DISPLAY 'AVAIL BAL:    ' WS-AVAIL-BAL
           DISPLAY 'HELD BAL:     ' WS-HELD-BAL
           DISPLAY 'HOLD AMOUNT:  ' WS-HOLD-AMOUNT
           DISPLAY 'HOLD DAYS:    ' WS-HOLD-DAYS
           DISPLAY 'DAYS HELD:    ' WS-DAYS-HELD
           IF WS-RELEASED
               DISPLAY 'STATUS: RELEASED'
               DISPLAY 'RELEASED AMT: ' WS-RELEASE-AMOUNT
           ELSE
               IF WS-ACTIVE-HOLD
                   DISPLAY 'STATUS: ACTIVE HOLD'
               END-IF
           END-IF
           IF WS-PARTIAL-RELEASE > 0
               DISPLAY 'PARTIAL REL:  ' WS-PARTIAL-RELEASE
           END-IF.
