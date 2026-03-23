       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOAN-DELINQ-TRACKER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-LOAN-INFO.
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-BORROWER-NAME       PIC X(30).
           05 WS-CURRENT-BAL         PIC S9(9)V99 COMP-3.
           05 WS-MONTHLY-PMT         PIC S9(7)V99 COMP-3.
           05 WS-ANNUAL-RATE         PIC S9(3)V9(6) COMP-3.
           05 WS-LAST-PMT-DATE       PIC 9(8).
           05 WS-CURRENT-DATE        PIC 9(8).
       01 WS-DELINQ-STATUS           PIC X(1).
           88 WS-CURRENT              VALUE 'C'.
           88 WS-DELINQ-30            VALUE '1'.
           88 WS-DELINQ-60            VALUE '2'.
           88 WS-DELINQ-90            VALUE '3'.
           88 WS-DELINQ-120           VALUE '4'.
       01 WS-ACTION-CODE             PIC X(1).
           88 WS-NO-ACTION            VALUE 'N'.
           88 WS-SEND-NOTICE          VALUE 'S'.
           88 WS-CALL-BORROWER        VALUE 'C'.
           88 WS-REFER-COLLECTIONS    VALUE 'R'.
           88 WS-FORECLOSURE-REF      VALUE 'F'.
       01 WS-DAYS-PAST-DUE           PIC S9(3) COMP-3.
       01 WS-MISSED-PMTS             PIC 9(2).
       01 WS-TOTAL-ARREARS           PIC S9(9)V99 COMP-3.
       01 WS-LATE-CHARGES            PIC S9(7)V99 COMP-3.
       01 WS-ACCRUED-INT             PIC S9(7)V99 COMP-3.
       01 WS-TOTAL-DUE               PIC S9(9)V99 COMP-3.
       01 WS-NOTICE-MSG              PIC X(80).
       01 WS-PMT-IDX                 PIC 9(2).
       01 WS-LATE-FEE-PCT            PIC S9(1)V9(4) COMP-3.
       01 WS-DAILY-RATE              PIC S9(1)V9(10) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CLASSIFY-DELINQUENCY
           PERFORM 3000-CALC-ARREARS
           PERFORM 4000-DETERMINE-ACTION
           PERFORM 5000-BUILD-NOTICE
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-ARREARS
           MOVE 0 TO WS-LATE-CHARGES
           MOVE 0 TO WS-ACCRUED-INT
           SET WS-CURRENT TO TRUE
           SET WS-NO-ACTION TO TRUE
           COMPUTE WS-DAILY-RATE =
               WS-ANNUAL-RATE / 360.
       2000-CLASSIFY-DELINQUENCY.
           EVALUATE TRUE
               WHEN WS-DAYS-PAST-DUE <= 0
                   SET WS-CURRENT TO TRUE
                   MOVE 0 TO WS-MISSED-PMTS
               WHEN WS-DAYS-PAST-DUE <= 30
                   SET WS-DELINQ-30 TO TRUE
                   MOVE 1 TO WS-MISSED-PMTS
               WHEN WS-DAYS-PAST-DUE <= 60
                   SET WS-DELINQ-60 TO TRUE
                   MOVE 2 TO WS-MISSED-PMTS
               WHEN WS-DAYS-PAST-DUE <= 90
                   SET WS-DELINQ-90 TO TRUE
                   MOVE 3 TO WS-MISSED-PMTS
               WHEN OTHER
                   SET WS-DELINQ-120 TO TRUE
                   COMPUTE WS-MISSED-PMTS =
                       WS-DAYS-PAST-DUE / 30
           END-EVALUATE.
       3000-CALC-ARREARS.
           IF WS-CURRENT
               MOVE 0 TO WS-TOTAL-DUE
           ELSE
               COMPUTE WS-TOTAL-ARREARS =
                   WS-MONTHLY-PMT * WS-MISSED-PMTS
               EVALUATE TRUE
                   WHEN WS-DELINQ-30
                       MOVE 0.0400 TO WS-LATE-FEE-PCT
                   WHEN WS-DELINQ-60
                       MOVE 0.0500 TO WS-LATE-FEE-PCT
                   WHEN WS-DELINQ-90
                       MOVE 0.0600 TO WS-LATE-FEE-PCT
                   WHEN OTHER
                       MOVE 0.0800 TO WS-LATE-FEE-PCT
               END-EVALUATE
               PERFORM VARYING WS-PMT-IDX FROM 1 BY 1
                   UNTIL WS-PMT-IDX > WS-MISSED-PMTS
                   ADD WS-MONTHLY-PMT TO WS-LATE-CHARGES
               END-PERFORM
               MULTIPLY WS-LATE-FEE-PCT BY WS-LATE-CHARGES
               COMPUTE WS-ACCRUED-INT =
                   WS-CURRENT-BAL * WS-DAILY-RATE *
                   WS-DAYS-PAST-DUE
               COMPUTE WS-TOTAL-DUE =
                   WS-TOTAL-ARREARS + WS-LATE-CHARGES +
                   WS-ACCRUED-INT
           END-IF.
       4000-DETERMINE-ACTION.
           EVALUATE TRUE
               WHEN WS-CURRENT
                   SET WS-NO-ACTION TO TRUE
               WHEN WS-DELINQ-30
                   SET WS-SEND-NOTICE TO TRUE
               WHEN WS-DELINQ-60
                   SET WS-CALL-BORROWER TO TRUE
               WHEN WS-DELINQ-90
                   SET WS-REFER-COLLECTIONS TO TRUE
               WHEN WS-DELINQ-120
                   SET WS-FORECLOSURE-REF TO TRUE
           END-EVALUATE.
       5000-BUILD-NOTICE.
           IF WS-CURRENT
               MOVE SPACES TO WS-NOTICE-MSG
           ELSE
               STRING 'ACCT ' DELIMITED BY SIZE
                      WS-ACCT-NUM DELIMITED BY SIZE
                      ' DPD=' DELIMITED BY SIZE
                      WS-DAYS-PAST-DUE DELIMITED BY SIZE
                      ' DUE=' DELIMITED BY SIZE
                      WS-TOTAL-DUE DELIMITED BY SIZE
                      INTO WS-NOTICE-MSG
               END-STRING
           END-IF.
       6000-DISPLAY-RESULTS.
           DISPLAY 'DELINQUENCY TRACKER REPORT'
           DISPLAY '=========================='
           DISPLAY 'ACCOUNT:       ' WS-ACCT-NUM
           DISPLAY 'BORROWER:      ' WS-BORROWER-NAME
           DISPLAY 'BALANCE:       ' WS-CURRENT-BAL
           DISPLAY 'DAYS PAST DUE: ' WS-DAYS-PAST-DUE
           DISPLAY 'MISSED PMTS:   ' WS-MISSED-PMTS
           IF WS-CURRENT
               DISPLAY 'STATUS: CURRENT'
           END-IF
           IF WS-DELINQ-30
               DISPLAY 'STATUS: 30-DAY DELINQUENT'
           END-IF
           IF WS-DELINQ-60
               DISPLAY 'STATUS: 60-DAY DELINQUENT'
           END-IF
           IF WS-DELINQ-90
               DISPLAY 'STATUS: 90-DAY DELINQUENT'
           END-IF
           IF WS-DELINQ-120
               DISPLAY 'STATUS: 120+ DAY DELINQUENT'
           END-IF
           DISPLAY 'ARREARS:       ' WS-TOTAL-ARREARS
           DISPLAY 'LATE CHARGES:  ' WS-LATE-CHARGES
           DISPLAY 'ACCRUED INT:   ' WS-ACCRUED-INT
           DISPLAY 'TOTAL DUE:     ' WS-TOTAL-DUE
           DISPLAY 'ACTION:        ' WS-ACTION-CODE
           DISPLAY 'NOTICE:        ' WS-NOTICE-MSG.
