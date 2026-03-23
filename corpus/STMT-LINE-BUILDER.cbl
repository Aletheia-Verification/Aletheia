       IDENTIFICATION DIVISION.
       PROGRAM-ID. STMT-LINE-BUILDER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ACCOUNT-INFO.
           05 WS-ACCT-NUM         PIC X(12).
           05 WS-ACCT-NAME        PIC X(30).
           05 WS-OPENING-BAL      PIC S9(9)V99 COMP-3.
           05 WS-CLOSING-BAL      PIC S9(9)V99 COMP-3.
           05 WS-RUNNING-BAL      PIC S9(9)V99 COMP-3.
       01 WS-TRANSACTION-TABLE.
           05 WS-TRAN-COUNT       PIC S9(3) COMP-3.
           05 WS-TRAN-ENTRY OCCURS 20.
               10 WS-TRAN-DATE    PIC X(10).
               10 WS-TRAN-TYPE    PIC X(1).
               10 WS-TRAN-AMOUNT  PIC S9(7)V99 COMP-3.
               10 WS-TRAN-DESC    PIC X(30).
               10 WS-TRAN-REF     PIC X(12).
               10 WS-TRAN-MEMO    PIC X(40).
       01 WS-TYPE-FLAG            PIC X.
           88 WS-IS-DEPOSIT       VALUE 'D'.
           88 WS-IS-WITHDRAWAL    VALUE 'W'.
           88 WS-IS-FEE           VALUE 'F'.
           88 WS-IS-INTEREST      VALUE 'I'.
           88 WS-IS-TRANSFER      VALUE 'T'.
       01 WS-SUBTOTALS.
           05 WS-DEP-TOTAL        PIC S9(9)V99 COMP-3.
           05 WS-WDR-TOTAL        PIC S9(9)V99 COMP-3.
           05 WS-FEE-TOTAL        PIC S9(9)V99 COMP-3.
           05 WS-INT-TOTAL        PIC S9(9)V99 COMP-3.
           05 WS-XFR-TOTAL        PIC S9(9)V99 COMP-3.
           05 WS-DEP-COUNT        PIC S9(3) COMP-3.
           05 WS-WDR-COUNT        PIC S9(3) COMP-3.
           05 WS-FEE-COUNT        PIC S9(3) COMP-3.
           05 WS-INT-COUNT        PIC S9(3) COMP-3.
           05 WS-XFR-COUNT        PIC S9(3) COMP-3.
       01 WS-STMT-LINE            PIC X(80).
       01 WS-FORMATTED-AMT        PIC X(15).
       01 WS-FORMATTED-BAL        PIC X(15).
       01 WS-TYPE-LABEL           PIC X(12).
       01 WS-IDX                  PIC 9(3).
       01 WS-MEMO-FIELDS.
           05 WS-MEMO-PART-1      PIC X(20).
           05 WS-MEMO-PART-2      PIC X(20).
       01 WS-STMT-HEADER          PIC X(80).
       01 WS-STMT-FOOTER          PIC X(80).
       01 WS-NET-ACTIVITY         PIC S9(9)V99 COMP-3.
       01 WS-AVG-DEPOSIT          PIC S9(7)V99 COMP-3.
       01 WS-AVG-WITHDRAWAL       PIC S9(7)V99 COMP-3.
       01 WS-LARGEST-TRAN         PIC S9(7)V99 COMP-3.
       01 WS-LARGEST-IDX          PIC 9(3).
       01 WS-DAILY-LIMIT          PIC S9(9)V99 VALUE 10000.00.
       01 WS-OVER-LIMIT-FLAG      PIC X VALUE 'N'.
           88 WS-OVER-LIMIT       VALUE 'Y'.
       01 WS-PAGE-LINES           PIC 9(3).
       01 WS-MAX-LINES            PIC 9(3) VALUE 50.
       01 WS-PAGE-NUM             PIC 9(3).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 0100-INITIALIZE
           PERFORM 0200-BUILD-HEADER
           PERFORM 0300-PROCESS-TRANSACTIONS
           PERFORM 0400-CALC-SUBTOTALS
           PERFORM 0500-FIND-LARGEST
           PERFORM 0600-BUILD-FOOTER
           PERFORM 0700-DISPLAY-SUMMARY
           STOP RUN.
       0100-INITIALIZE.
           INITIALIZE WS-SUBTOTALS
           MOVE 0 TO WS-DEP-TOTAL
           MOVE 0 TO WS-WDR-TOTAL
           MOVE 0 TO WS-FEE-TOTAL
           MOVE 0 TO WS-INT-TOTAL
           MOVE 0 TO WS-XFR-TOTAL
           MOVE 0 TO WS-DEP-COUNT
           MOVE 0 TO WS-WDR-COUNT
           MOVE 0 TO WS-FEE-COUNT
           MOVE 0 TO WS-INT-COUNT
           MOVE 0 TO WS-XFR-COUNT
           MOVE WS-OPENING-BAL TO WS-RUNNING-BAL
           MOVE 0 TO WS-LARGEST-TRAN
           MOVE 0 TO WS-PAGE-LINES
           MOVE 1 TO WS-PAGE-NUM
           MOVE 'N' TO WS-OVER-LIMIT-FLAG.
       0200-BUILD-HEADER.
           STRING 'STATEMENT FOR ' DELIMITED BY SIZE
                  WS-ACCT-NUM DELIMITED BY SIZE
                  ' - ' DELIMITED BY SIZE
                  WS-ACCT-NAME DELIMITED BY SIZE
                  INTO WS-STMT-HEADER
           END-STRING
           DISPLAY WS-STMT-HEADER
           DISPLAY '----------------------------------------'
                   '----------------------------------------'.
       0300-PROCESS-TRANSACTIONS.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-TRAN-COUNT
               OR WS-IDX > 20
               MOVE WS-TRAN-TYPE(WS-IDX) TO WS-TYPE-FLAG
               PERFORM 1000-CATEGORIZE-TRAN
               PERFORM 1100-UPDATE-BALANCE
               PERFORM 1200-PARSE-MEMO
               PERFORM 1300-FORMAT-LINE
               PERFORM 1400-CHECK-PAGE-BREAK
               DISPLAY WS-STMT-LINE
               ADD 1 TO WS-PAGE-LINES
           END-PERFORM.
       1000-CATEGORIZE-TRAN.
           EVALUATE TRUE
               WHEN WS-IS-DEPOSIT
                   MOVE 'DEPOSIT     ' TO WS-TYPE-LABEL
                   ADD WS-TRAN-AMOUNT(WS-IDX) TO
                       WS-DEP-TOTAL
                   ADD 1 TO WS-DEP-COUNT
               WHEN WS-IS-WITHDRAWAL
                   MOVE 'WITHDRAWAL  ' TO WS-TYPE-LABEL
                   ADD WS-TRAN-AMOUNT(WS-IDX) TO
                       WS-WDR-TOTAL
                   ADD 1 TO WS-WDR-COUNT
               WHEN WS-IS-FEE
                   MOVE 'FEE         ' TO WS-TYPE-LABEL
                   ADD WS-TRAN-AMOUNT(WS-IDX) TO
                       WS-FEE-TOTAL
                   ADD 1 TO WS-FEE-COUNT
               WHEN WS-IS-INTEREST
                   MOVE 'INTEREST    ' TO WS-TYPE-LABEL
                   ADD WS-TRAN-AMOUNT(WS-IDX) TO
                       WS-INT-TOTAL
                   ADD 1 TO WS-INT-COUNT
               WHEN WS-IS-TRANSFER
                   MOVE 'TRANSFER    ' TO WS-TYPE-LABEL
                   ADD WS-TRAN-AMOUNT(WS-IDX) TO
                       WS-XFR-TOTAL
                   ADD 1 TO WS-XFR-COUNT
               WHEN OTHER
                   MOVE 'UNKNOWN     ' TO WS-TYPE-LABEL
           END-EVALUATE.
       1100-UPDATE-BALANCE.
           IF WS-IS-DEPOSIT
               ADD WS-TRAN-AMOUNT(WS-IDX) TO
                   WS-RUNNING-BAL
           ELSE
               IF WS-IS-INTEREST
                   ADD WS-TRAN-AMOUNT(WS-IDX) TO
                       WS-RUNNING-BAL
               ELSE
                   SUBTRACT WS-TRAN-AMOUNT(WS-IDX) FROM
                       WS-RUNNING-BAL
               END-IF
           END-IF
           IF WS-TRAN-AMOUNT(WS-IDX) > WS-DAILY-LIMIT
               MOVE 'Y' TO WS-OVER-LIMIT-FLAG
           END-IF.
       1200-PARSE-MEMO.
           UNSTRING WS-TRAN-MEMO(WS-IDX)
               DELIMITED BY '|'
               INTO WS-MEMO-PART-1 WS-MEMO-PART-2
           END-UNSTRING.
       1300-FORMAT-LINE.
           MOVE SPACES TO WS-STMT-LINE
           STRING WS-TRAN-DATE(WS-IDX) DELIMITED BY SIZE
                  ' ' DELIMITED BY SIZE
                  WS-TYPE-LABEL DELIMITED BY SIZE
                  ' ' DELIMITED BY SIZE
                  WS-TRAN-DESC(WS-IDX) DELIMITED BY SIZE
                  INTO WS-STMT-LINE
           END-STRING.
       1400-CHECK-PAGE-BREAK.
           IF WS-PAGE-LINES > WS-MAX-LINES
               ADD 1 TO WS-PAGE-NUM
               MOVE 0 TO WS-PAGE-LINES
               DISPLAY '--- PAGE ' WS-PAGE-NUM ' ---'
           END-IF.
       0400-CALC-SUBTOTALS.
           COMPUTE WS-NET-ACTIVITY =
               WS-DEP-TOTAL + WS-INT-TOTAL
               - WS-WDR-TOTAL - WS-FEE-TOTAL
               - WS-XFR-TOTAL
           COMPUTE WS-CLOSING-BAL =
               WS-OPENING-BAL + WS-NET-ACTIVITY
           IF WS-DEP-COUNT > 0
               DIVIDE WS-DEP-TOTAL BY WS-DEP-COUNT
                   GIVING WS-AVG-DEPOSIT
           ELSE
               MOVE 0 TO WS-AVG-DEPOSIT
           END-IF
           IF WS-WDR-COUNT > 0
               DIVIDE WS-WDR-TOTAL BY WS-WDR-COUNT
                   GIVING WS-AVG-WITHDRAWAL
           ELSE
               MOVE 0 TO WS-AVG-WITHDRAWAL
           END-IF.
       0500-FIND-LARGEST.
           MOVE 0 TO WS-LARGEST-TRAN
           MOVE 0 TO WS-LARGEST-IDX
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-TRAN-COUNT
               OR WS-IDX > 20
               IF WS-TRAN-AMOUNT(WS-IDX) >
                   WS-LARGEST-TRAN
                   MOVE WS-TRAN-AMOUNT(WS-IDX) TO
                       WS-LARGEST-TRAN
                   MOVE WS-IDX TO WS-LARGEST-IDX
               END-IF
           END-PERFORM.
       0600-BUILD-FOOTER.
           DISPLAY '----------------------------------------'
                   '----------------------------------------'
           STRING 'CLOSING BALANCE: ' DELIMITED BY SIZE
                  WS-ACCT-NUM DELIMITED BY SIZE
                  INTO WS-STMT-FOOTER
           END-STRING
           DISPLAY WS-STMT-FOOTER.
       0700-DISPLAY-SUMMARY.
           DISPLAY 'STATEMENT SUMMARY'
           DISPLAY 'OPENING BALANCE:   ' WS-OPENING-BAL
           DISPLAY 'DEPOSITS:          ' WS-DEP-TOTAL
               ' (' WS-DEP-COUNT ' TRANSACTIONS)'
           DISPLAY 'WITHDRAWALS:       ' WS-WDR-TOTAL
               ' (' WS-WDR-COUNT ' TRANSACTIONS)'
           DISPLAY 'FEES:              ' WS-FEE-TOTAL
               ' (' WS-FEE-COUNT ' TRANSACTIONS)'
           DISPLAY 'INTEREST:          ' WS-INT-TOTAL
               ' (' WS-INT-COUNT ' TRANSACTIONS)'
           DISPLAY 'TRANSFERS:         ' WS-XFR-TOTAL
               ' (' WS-XFR-COUNT ' TRANSACTIONS)'
           DISPLAY 'NET ACTIVITY:      ' WS-NET-ACTIVITY
           DISPLAY 'CLOSING BALANCE:   ' WS-CLOSING-BAL
           DISPLAY 'AVG DEPOSIT:       ' WS-AVG-DEPOSIT
           DISPLAY 'AVG WITHDRAWAL:    ' WS-AVG-WITHDRAWAL
           DISPLAY 'LARGEST TRAN:      ' WS-LARGEST-TRAN
           IF WS-OVER-LIMIT
               DISPLAY 'WARNING: OVER-LIMIT TRANSACTIONS'
           END-IF
           DISPLAY 'PAGES:             ' WS-PAGE-NUM
           IF WS-CLOSING-BAL < 0
               DISPLAY 'ALERT: NEGATIVE CLOSING BALANCE'
               DISPLAY 'OVERDRAFT AMOUNT:  ' WS-CLOSING-BAL
           END-IF
           IF WS-FEE-TOTAL > WS-INT-TOTAL
               DISPLAY 'NOTE: FEES EXCEED INTEREST EARNED'
               COMPUTE WS-NET-ACTIVITY =
                   WS-FEE-TOTAL - WS-INT-TOTAL
               DISPLAY 'FEE EXCESS:        '
                   WS-NET-ACTIVITY
           END-IF.
