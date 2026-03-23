       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOAN-PMI-REMOVAL.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-LOAN-DATA.
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-ORIG-APPRAISED      PIC S9(9)V99 COMP-3.
           05 WS-ORIG-PRINCIPAL      PIC S9(9)V99 COMP-3.
           05 WS-CURRENT-BAL         PIC S9(9)V99 COMP-3.
           05 WS-CURRENT-VALUE       PIC S9(9)V99 COMP-3.
           05 WS-ANNUAL-RATE         PIC S9(3)V9(6) COMP-3.
           05 WS-MONTHLY-PMT         PIC S9(7)V99 COMP-3.
           05 WS-PMI-MONTHLY         PIC S9(5)V99 COMP-3.
           05 WS-ORIG-TERM           PIC 9(3).
           05 WS-MONTHS-ELAPSED      PIC 9(3).
       01 WS-LTV-FIELDS.
           05 WS-ORIG-LTV            PIC S9(3)V99 COMP-3.
           05 WS-CURRENT-LTV         PIC S9(3)V99 COMP-3.
           05 WS-TARGET-LTV          PIC S9(3)V99 COMP-3
               VALUE 80.00.
           05 WS-AUTO-REMOVE-LTV     PIC S9(3)V99 COMP-3
               VALUE 78.00.
       01 WS-PMI-STATUS              PIC X(1).
           88 WS-PMI-ACTIVE          VALUE 'A'.
           88 WS-PMI-ELIGIBLE        VALUE 'E'.
           88 WS-PMI-AUTO-REMOVE     VALUE 'R'.
           88 WS-PMI-NOT-REQUIRED    VALUE 'N'.
       01 WS-REQUEST-TYPE            PIC X(1).
           88 WS-BORROWER-REQUEST    VALUE 'B'.
           88 WS-AUTO-TERMINATE      VALUE 'T'.
           88 WS-NO-REQUEST          VALUE 'N'.
       01 WS-HISTORY-TABLE.
           05 WS-PMT-HISTORY OCCURS 24.
               10 WS-PMT-DATE        PIC 9(8).
               10 WS-PMT-AMOUNT      PIC S9(7)V99 COMP-3.
               10 WS-PMT-ONTIME      PIC X(1).
       01 WS-PMT-IDX                 PIC 9(2).
       01 WS-LATE-COUNT              PIC 9(2).
       01 WS-MONTHS-TO-80            PIC 9(3).
       01 WS-EXTRA-PRINCIPAL         PIC S9(9)V99 COMP-3.
       01 WS-PMI-SAVINGS             PIC S9(7)V99 COMP-3.
       01 WS-GOOD-STANDING           PIC X VALUE 'N'.
           88 WS-IS-GOOD-STANDING    VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-LTV
           PERFORM 3000-CHECK-AUTO-REMOVE
           PERFORM 4000-CHECK-PMT-HISTORY
           PERFORM 5000-EVALUATE-ELIGIBILITY
           PERFORM 6000-CALC-SAVINGS
           PERFORM 7000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-LATE-COUNT
           MOVE 0 TO WS-MONTHS-TO-80
           MOVE 0 TO WS-PMI-SAVINGS
           SET WS-PMI-ACTIVE TO TRUE
           SET WS-NO-REQUEST TO TRUE
           MOVE 'N' TO WS-GOOD-STANDING.
       2000-CALC-LTV.
           IF WS-ORIG-APPRAISED > 0
               COMPUTE WS-ORIG-LTV =
                   (WS-ORIG-PRINCIPAL / WS-ORIG-APPRAISED)
                   * 100
           END-IF
           IF WS-CURRENT-VALUE > 0
               COMPUTE WS-CURRENT-LTV =
                   (WS-CURRENT-BAL / WS-CURRENT-VALUE)
                   * 100
           END-IF.
       3000-CHECK-AUTO-REMOVE.
           IF WS-CURRENT-LTV <= WS-AUTO-REMOVE-LTV
               SET WS-PMI-AUTO-REMOVE TO TRUE
               SET WS-AUTO-TERMINATE TO TRUE
           ELSE
               IF WS-CURRENT-LTV <= WS-TARGET-LTV
                   SET WS-PMI-ELIGIBLE TO TRUE
                   SET WS-BORROWER-REQUEST TO TRUE
               END-IF
           END-IF.
       4000-CHECK-PMT-HISTORY.
           MOVE 0 TO WS-LATE-COUNT
           PERFORM VARYING WS-PMT-IDX FROM 1 BY 1
               UNTIL WS-PMT-IDX > 24
               IF WS-PMT-ONTIME(WS-PMT-IDX) = 'N'
                   ADD 1 TO WS-LATE-COUNT
               END-IF
           END-PERFORM
           IF WS-LATE-COUNT = 0
               MOVE 'Y' TO WS-GOOD-STANDING
           ELSE
               IF WS-LATE-COUNT <= 1
                   IF WS-MONTHS-ELAPSED > 24
                       MOVE 'Y' TO WS-GOOD-STANDING
                   END-IF
               END-IF
           END-IF.
       5000-EVALUATE-ELIGIBILITY.
           EVALUATE TRUE
               WHEN WS-PMI-AUTO-REMOVE
                   DISPLAY 'AUTO-TERMINATION: LTV <= 78%'
               WHEN WS-PMI-ELIGIBLE
                   IF WS-IS-GOOD-STANDING
                       DISPLAY 'ELIGIBLE: GOOD STANDING'
                   ELSE
                       SET WS-PMI-ACTIVE TO TRUE
                       DISPLAY 'DENIED: PAYMENT HISTORY'
                   END-IF
               WHEN WS-CURRENT-LTV > WS-TARGET-LTV
                   IF WS-CURRENT-VALUE >
                       WS-ORIG-APPRAISED
                       COMPUTE WS-EXTRA-PRINCIPAL =
                           WS-CURRENT-BAL -
                           (WS-CURRENT-VALUE *
                           WS-TARGET-LTV / 100)
                       DISPLAY 'EXTRA NEEDED: '
                           WS-EXTRA-PRINCIPAL
                   END-IF
               WHEN OTHER
                   SET WS-PMI-NOT-REQUIRED TO TRUE
           END-EVALUATE.
       6000-CALC-SAVINGS.
           IF WS-PMI-AUTO-REMOVE OR WS-PMI-ELIGIBLE
               COMPUTE WS-MONTHS-TO-80 =
                   WS-ORIG-TERM - WS-MONTHS-ELAPSED
               IF WS-MONTHS-TO-80 > 0
                   COMPUTE WS-PMI-SAVINGS =
                       WS-PMI-MONTHLY * WS-MONTHS-TO-80
               END-IF
           END-IF.
       7000-DISPLAY-RESULTS.
           DISPLAY 'PMI REMOVAL ANALYSIS'
           DISPLAY '===================='
           DISPLAY 'ACCOUNT:         ' WS-ACCT-NUM
           DISPLAY 'ORIGINAL LTV:    ' WS-ORIG-LTV
           DISPLAY 'CURRENT LTV:     ' WS-CURRENT-LTV
           DISPLAY 'CURRENT BALANCE: ' WS-CURRENT-BAL
           DISPLAY 'PROPERTY VALUE:  ' WS-CURRENT-VALUE
           DISPLAY 'PMI MONTHLY:     ' WS-PMI-MONTHLY
           DISPLAY 'LATE PAYMENTS:   ' WS-LATE-COUNT
           IF WS-PMI-AUTO-REMOVE
               DISPLAY 'STATUS: AUTO-REMOVED'
           END-IF
           IF WS-PMI-ELIGIBLE
               IF WS-IS-GOOD-STANDING
                   DISPLAY 'STATUS: REMOVAL APPROVED'
               ELSE
                   DISPLAY 'STATUS: INELIGIBLE'
               END-IF
           END-IF
           IF WS-PMI-ACTIVE
               DISPLAY 'STATUS: PMI REMAINS ACTIVE'
           END-IF
           DISPLAY 'PROJECTED SAVINGS: ' WS-PMI-SAVINGS.
