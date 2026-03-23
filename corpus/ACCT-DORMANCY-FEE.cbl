       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCT-DORMANCY-FEE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ACCT-TABLE.
           05 WS-ACCT-ENTRY OCCURS 50 TIMES.
               10 WS-ACCT-ID          PIC X(10).
               10 WS-LAST-ACTIVITY    PIC 9(8).
               10 WS-ACCT-BALANCE     PIC S9(9)V99 COMP-3.
               10 WS-ACCT-TYPE        PIC X(2).
               10 WS-FEE-EXEMPT       PIC X VALUE 'N'.
                   88 IS-EXEMPT        VALUE 'Y'.
               10 WS-FEE-APPLIED      PIC S9(5)V99 COMP-3.
       01 WS-CURRENT-DATE            PIC 9(8).
       01 WS-DAYS-INACTIVE           PIC 9(5).
       01 WS-DORMANCY-THRESHOLD      PIC 9(5) VALUE 365.
       01 WS-FEE-SCHEDULE.
           05 WS-TIER1-FEE           PIC S9(3)V99 COMP-3
               VALUE 5.00.
           05 WS-TIER2-FEE           PIC S9(3)V99 COMP-3
               VALUE 10.00.
           05 WS-TIER3-FEE           PIC S9(3)V99 COMP-3
               VALUE 25.00.
       01 WS-IDX                     PIC 99.
       01 WS-ACCT-COUNT              PIC 99 VALUE 50.
       01 WS-TOTAL-FEES              PIC S9(7)V99 COMP-3.
       01 WS-DORMANT-COUNT           PIC 9(3).
       01 WS-EXEMPT-COUNT            PIC 9(3).
       01 WS-FEE-AMOUNT              PIC S9(5)V99 COMP-3.
       01 WS-REPORT-LINE             PIC X(80).
       01 WS-YEAR-DIFF               PIC 9(3).
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-SCAN-ACCOUNTS
           PERFORM 3000-PRODUCE-REPORT
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-FEES
           MOVE 0 TO WS-DORMANT-COUNT
           MOVE 0 TO WS-EXEMPT-COUNT
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD.
       2000-SCAN-ACCOUNTS.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-ACCT-COUNT
               PERFORM 2100-EVALUATE-ACCOUNT
           END-PERFORM.
       2100-EVALUATE-ACCOUNT.
           IF IS-EXEMPT(WS-IDX)
               ADD 1 TO WS-EXEMPT-COUNT
           ELSE
               COMPUTE WS-DAYS-INACTIVE =
                   WS-CURRENT-DATE -
                   WS-LAST-ACTIVITY(WS-IDX)
               IF WS-DAYS-INACTIVE > WS-DORMANCY-THRESHOLD
                   PERFORM 2200-DETERMINE-FEE
                   ADD 1 TO WS-DORMANT-COUNT
               END-IF
           END-IF.
       2200-DETERMINE-FEE.
           COMPUTE WS-YEAR-DIFF =
               WS-DAYS-INACTIVE / 365
           EVALUATE TRUE
               WHEN WS-YEAR-DIFF < 2
                   MOVE WS-TIER1-FEE TO WS-FEE-AMOUNT
               WHEN WS-YEAR-DIFF < 4
                   MOVE WS-TIER2-FEE TO WS-FEE-AMOUNT
               WHEN OTHER
                   MOVE WS-TIER3-FEE TO WS-FEE-AMOUNT
           END-EVALUATE
           IF WS-ACCT-TYPE(WS-IDX) = 'SV'
               COMPUTE WS-FEE-AMOUNT =
                   WS-FEE-AMOUNT * 0.50
           END-IF
           IF WS-FEE-AMOUNT > WS-ACCT-BALANCE(WS-IDX)
               MOVE WS-ACCT-BALANCE(WS-IDX)
                   TO WS-FEE-AMOUNT
           END-IF
           SUBTRACT WS-FEE-AMOUNT FROM
               WS-ACCT-BALANCE(WS-IDX)
           MOVE WS-FEE-AMOUNT TO
               WS-FEE-APPLIED(WS-IDX)
           ADD WS-FEE-AMOUNT TO WS-TOTAL-FEES.
       3000-PRODUCE-REPORT.
           DISPLAY 'DORMANCY FEE ASSESSMENT REPORT'
           DISPLAY '=============================='
           DISPLAY 'DATE: ' WS-CURRENT-DATE
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-ACCT-COUNT
               IF WS-FEE-APPLIED(WS-IDX) > 0
                   STRING WS-ACCT-ID(WS-IDX)
                       DELIMITED BY '  '
                       ' FEE=$' DELIMITED BY SIZE
                       WS-FEE-APPLIED(WS-IDX)
                       DELIMITED BY SIZE
                       INTO WS-REPORT-LINE
                   END-STRING
                   DISPLAY WS-REPORT-LINE
               END-IF
           END-PERFORM
           DISPLAY 'DORMANT ACCOUNTS: ' WS-DORMANT-COUNT
           DISPLAY 'EXEMPT ACCOUNTS:  ' WS-EXEMPT-COUNT
           DISPLAY 'TOTAL FEES:       ' WS-TOTAL-FEES.
