       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCT-MIN-BAL-CHECK.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ACCT-DATA.
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-CURRENT-BAL         PIC S9(9)V99 COMP-3.
           05 WS-AVG-BAL-MTD         PIC S9(9)V99 COMP-3.
           05 WS-LOW-BAL-MTD         PIC S9(9)V99 COMP-3.
       01 WS-ACCT-PRODUCT            PIC X(2).
           88 WS-BASIC-CHK           VALUE 'BC'.
           88 WS-INTEREST-CHK        VALUE 'IC'.
           88 WS-PREMIUM-CHK         VALUE 'PC'.
           88 WS-BUS-CHK             VALUE 'BZ'.
       01 WS-MIN-BAL-FIELDS.
           05 WS-REQUIRED-MIN        PIC S9(7)V99 COMP-3.
           05 WS-FEE-AMOUNT          PIC S9(5)V99 COMP-3.
           05 WS-WAIVER-BAL          PIC S9(9)V99 COMP-3.
           05 WS-SHORTFALL           PIC S9(9)V99 COMP-3.
       01 WS-FEE-STATUS              PIC X(1).
           88 WS-FEE-ASSESSED        VALUE 'A'.
           88 WS-FEE-WAIVED          VALUE 'W'.
           88 WS-NO-FEE              VALUE 'N'.
       01 WS-COMBINED-BAL            PIC S9(11)V99 COMP-3.
       01 WS-HAS-LINKED             PIC X VALUE 'N'.
           88 WS-LINKED-ACCTS       VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-SET-MINIMUMS
           PERFORM 3000-CHECK-BALANCE
           PERFORM 4000-CHECK-WAIVER
           PERFORM 5000-ASSESS-FEE
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-SHORTFALL
           SET WS-NO-FEE TO TRUE.
       2000-SET-MINIMUMS.
           EVALUATE TRUE
               WHEN WS-BASIC-CHK
                   MOVE 100.00 TO WS-REQUIRED-MIN
                   MOVE 12.00 TO WS-FEE-AMOUNT
                   MOVE 500.00 TO WS-WAIVER-BAL
               WHEN WS-INTEREST-CHK
                   MOVE 1000.00 TO WS-REQUIRED-MIN
                   MOVE 15.00 TO WS-FEE-AMOUNT
                   MOVE 2500.00 TO WS-WAIVER-BAL
               WHEN WS-PREMIUM-CHK
                   MOVE 5000.00 TO WS-REQUIRED-MIN
                   MOVE 25.00 TO WS-FEE-AMOUNT
                   MOVE 15000.00 TO WS-WAIVER-BAL
               WHEN WS-BUS-CHK
                   MOVE 2500.00 TO WS-REQUIRED-MIN
                   MOVE 20.00 TO WS-FEE-AMOUNT
                   MOVE 10000.00 TO WS-WAIVER-BAL
               WHEN OTHER
                   MOVE 0 TO WS-REQUIRED-MIN
                   MOVE 0 TO WS-FEE-AMOUNT
           END-EVALUATE.
       3000-CHECK-BALANCE.
           IF WS-AVG-BAL-MTD < WS-REQUIRED-MIN
               COMPUTE WS-SHORTFALL =
                   WS-REQUIRED-MIN - WS-AVG-BAL-MTD
               SET WS-FEE-ASSESSED TO TRUE
           END-IF.
       4000-CHECK-WAIVER.
           IF WS-FEE-ASSESSED
               IF WS-LINKED-ACCTS
                   IF WS-COMBINED-BAL >= WS-WAIVER-BAL
                       SET WS-FEE-WAIVED TO TRUE
                   END-IF
               ELSE
                   IF WS-CURRENT-BAL >= WS-WAIVER-BAL
                       SET WS-FEE-WAIVED TO TRUE
                   END-IF
               END-IF
           END-IF.
       5000-ASSESS-FEE.
           IF WS-FEE-ASSESSED
               SUBTRACT WS-FEE-AMOUNT FROM WS-CURRENT-BAL
               DISPLAY 'FEE ASSESSED: ' WS-FEE-AMOUNT
           END-IF
           IF WS-FEE-WAIVED
               DISPLAY 'FEE WAIVED - BALANCE THRESHOLD MET'
           END-IF.
       6000-DISPLAY-RESULTS.
           DISPLAY 'MINIMUM BALANCE CHECK'
           DISPLAY '====================='
           DISPLAY 'ACCOUNT:      ' WS-ACCT-NUM
           DISPLAY 'PRODUCT:      ' WS-ACCT-PRODUCT
           DISPLAY 'CURRENT BAL:  ' WS-CURRENT-BAL
           DISPLAY 'AVG BAL MTD:  ' WS-AVG-BAL-MTD
           DISPLAY 'REQUIRED MIN: ' WS-REQUIRED-MIN
           IF WS-FEE-ASSESSED
               DISPLAY 'STATUS: FEE ASSESSED'
               DISPLAY 'FEE:          ' WS-FEE-AMOUNT
               DISPLAY 'SHORTFALL:    ' WS-SHORTFALL
           END-IF
           IF WS-FEE-WAIVED
               DISPLAY 'STATUS: FEE WAIVED'
           END-IF
           IF WS-NO-FEE
               DISPLAY 'STATUS: NO FEE'
           END-IF.
