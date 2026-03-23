       IDENTIFICATION DIVISION.
       PROGRAM-ID. PAY-RECUR-SCHED.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-SCHEDULE-DATA.
           05 WS-SCHED-ID            PIC X(10).
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-PAY-AMOUNT          PIC S9(7)V99 COMP-3.
           05 WS-START-DATE          PIC 9(8).
           05 WS-END-DATE            PIC 9(8).
           05 WS-CURRENT-DATE        PIC 9(8).
       01 WS-FREQUENCY               PIC X(1).
           88 WS-WEEKLY              VALUE 'W'.
           88 WS-BIWEEKLY            VALUE 'B'.
           88 WS-MONTHLY             VALUE 'M'.
           88 WS-QUARTERLY           VALUE 'Q'.
       01 WS-SCHED-STATUS            PIC X(1).
           88 WS-ACTIVE              VALUE 'A'.
           88 WS-SUSPENDED           VALUE 'S'.
           88 WS-EXPIRED             VALUE 'E'.
           88 WS-CANCELLED           VALUE 'C'.
       01 WS-PAYMENT-TABLE.
           05 WS-UPCOMING OCCURS 12.
               10 WS-UP-DATE         PIC 9(8).
               10 WS-UP-AMOUNT       PIC S9(7)V99 COMP-3.
               10 WS-UP-STATUS       PIC X(1).
       01 WS-UP-IDX                  PIC 9(2).
       01 WS-GENERATED-COUNT         PIC 9(2).
       01 WS-TOTAL-SCHEDULED         PIC S9(9)V99 COMP-3.
       01 WS-NEXT-DATE               PIC 9(8).
       01 WS-DAY-INCREMENT           PIC 9(3).
       01 WS-BALANCE-CHECK           PIC S9(9)V99 COMP-3.
       01 WS-AVAIL-BALANCE           PIC S9(9)V99 COMP-3.
       01 WS-FUNDS-OK                PIC X VALUE 'Y'.
           88 WS-HAS-FUNDS           VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-VALIDATE-SCHEDULE
           IF WS-ACTIVE
               PERFORM 3000-CALC-INCREMENT
               PERFORM 4000-GENERATE-DATES
               PERFORM 5000-CHECK-FUNDS
           END-IF
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-GENERATED-COUNT
           MOVE 0 TO WS-TOTAL-SCHEDULED
           SET WS-ACTIVE TO TRUE.
       2000-VALIDATE-SCHEDULE.
           IF WS-CURRENT-DATE > WS-END-DATE
               SET WS-EXPIRED TO TRUE
           END-IF
           IF WS-PAY-AMOUNT <= 0
               SET WS-SUSPENDED TO TRUE
           END-IF.
       3000-CALC-INCREMENT.
           EVALUATE TRUE
               WHEN WS-WEEKLY
                   MOVE 7 TO WS-DAY-INCREMENT
               WHEN WS-BIWEEKLY
                   MOVE 14 TO WS-DAY-INCREMENT
               WHEN WS-MONTHLY
                   MOVE 30 TO WS-DAY-INCREMENT
               WHEN WS-QUARTERLY
                   MOVE 90 TO WS-DAY-INCREMENT
               WHEN OTHER
                   MOVE 30 TO WS-DAY-INCREMENT
           END-EVALUATE.
       4000-GENERATE-DATES.
           MOVE WS-CURRENT-DATE TO WS-NEXT-DATE
           PERFORM VARYING WS-UP-IDX FROM 1 BY 1
               UNTIL WS-UP-IDX > 12
               OR WS-NEXT-DATE > WS-END-DATE
               MOVE WS-NEXT-DATE TO WS-UP-DATE(WS-UP-IDX)
               MOVE WS-PAY-AMOUNT TO
                   WS-UP-AMOUNT(WS-UP-IDX)
               MOVE 'P' TO WS-UP-STATUS(WS-UP-IDX)
               ADD WS-PAY-AMOUNT TO WS-TOTAL-SCHEDULED
               ADD 1 TO WS-GENERATED-COUNT
               ADD WS-DAY-INCREMENT TO WS-NEXT-DATE
           END-PERFORM.
       5000-CHECK-FUNDS.
           COMPUTE WS-BALANCE-CHECK =
               WS-AVAIL-BALANCE - WS-PAY-AMOUNT
           IF WS-BALANCE-CHECK < 0
               MOVE 'N' TO WS-FUNDS-OK
               IF WS-GENERATED-COUNT > 0
                   MOVE 'H' TO WS-UP-STATUS(1)
               END-IF
           END-IF.
       6000-DISPLAY-RESULTS.
           DISPLAY 'RECURRING PAYMENT SCHEDULE'
           DISPLAY '=========================='
           DISPLAY 'SCHEDULE ID:     ' WS-SCHED-ID
           DISPLAY 'ACCOUNT:         ' WS-ACCT-NUM
           DISPLAY 'AMOUNT:          ' WS-PAY-AMOUNT
           IF WS-ACTIVE
               DISPLAY 'STATUS: ACTIVE'
               DISPLAY 'PAYMENTS GEN:    ' WS-GENERATED-COUNT
               DISPLAY 'TOTAL SCHEDULED: ' WS-TOTAL-SCHEDULED
               IF WS-HAS-FUNDS
                   DISPLAY 'FUNDS: AVAILABLE'
               ELSE
                   DISPLAY 'FUNDS: INSUFFICIENT'
               END-IF
               PERFORM VARYING WS-UP-IDX FROM 1 BY 1
                   UNTIL WS-UP-IDX > WS-GENERATED-COUNT
                   DISPLAY '  DATE=' WS-UP-DATE(WS-UP-IDX)
                       ' AMT=' WS-UP-AMOUNT(WS-UP-IDX)
                       ' ST=' WS-UP-STATUS(WS-UP-IDX)
               END-PERFORM
           END-IF
           IF WS-EXPIRED
               DISPLAY 'STATUS: EXPIRED'
           END-IF
           IF WS-SUSPENDED
               DISPLAY 'STATUS: SUSPENDED'
           END-IF.
