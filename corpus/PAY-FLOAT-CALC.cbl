       IDENTIFICATION DIVISION.
       PROGRAM-ID. PAY-FLOAT-CALC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CHECK-DATA.
           05 WS-CHECK-NUM           PIC X(10).
           05 WS-CHECK-AMOUNT        PIC S9(9)V99 COMP-3.
           05 WS-DEPOSIT-DATE        PIC 9(8).
           05 WS-CLEAR-DATE          PIC 9(8).
           05 WS-AVAIL-DATE          PIC 9(8).
       01 WS-CHECK-TYPE              PIC X(1).
           88 WS-LOCAL               VALUE 'L'.
           88 WS-NON-LOCAL           VALUE 'N'.
           88 WS-GOVERNMENT          VALUE 'G'.
           88 WS-ON-US               VALUE 'U'.
       01 WS-HOLD-FIELDS.
           05 WS-HOLD-DAYS           PIC 9(2).
           05 WS-NEXT-DAY-AVAIL      PIC S9(9)V99 COMP-3.
           05 WS-REMAINING-HOLD      PIC S9(9)V99 COMP-3.
           05 WS-FLOAT-DAYS          PIC 9(2).
           05 WS-FLOAT-INCOME        PIC S9(7)V99 COMP-3.
       01 WS-FED-FUNDS-RATE          PIC S9(1)V9(6) COMP-3
           VALUE 0.0525.
       01 WS-DAILY-EARN-RATE         PIC S9(1)V9(10) COMP-3.
       01 WS-DAY-IDX                 PIC 9(2).
       01 WS-DAILY-FLOAT             PIC S9(9)V99 COMP-3.
       01 WS-TOTAL-FLOAT-INCOME      PIC S9(7)V99 COMP-3.
       01 WS-NEW-ACCT-FLAG           PIC X VALUE 'N'.
           88 WS-IS-NEW-ACCT         VALUE 'Y'.
       01 WS-LARGE-CHECK-FLAG        PIC X VALUE 'N'.
           88 WS-IS-LARGE            VALUE 'Y'.
       01 WS-FIRST-5K                PIC S9(7)V99 COMP-3
           VALUE 5525.00.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-DETERMINE-HOLD
           PERFORM 3000-CALC-AVAILABILITY
           PERFORM 4000-CALC-FLOAT-INCOME
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           COMPUTE WS-DAILY-EARN-RATE =
               WS-FED-FUNDS-RATE / 360
           MOVE 0 TO WS-FLOAT-INCOME
           MOVE 0 TO WS-TOTAL-FLOAT-INCOME
           IF WS-CHECK-AMOUNT > 5525
               MOVE 'Y' TO WS-LARGE-CHECK-FLAG
           END-IF.
       2000-DETERMINE-HOLD.
           EVALUATE TRUE
               WHEN WS-ON-US
                   MOVE 0 TO WS-HOLD-DAYS
               WHEN WS-GOVERNMENT
                   MOVE 1 TO WS-HOLD-DAYS
               WHEN WS-LOCAL
                   IF WS-IS-NEW-ACCT
                       MOVE 5 TO WS-HOLD-DAYS
                   ELSE
                       MOVE 2 TO WS-HOLD-DAYS
                   END-IF
               WHEN WS-NON-LOCAL
                   IF WS-IS-NEW-ACCT
                       MOVE 9 TO WS-HOLD-DAYS
                   ELSE
                       MOVE 5 TO WS-HOLD-DAYS
                   END-IF
               WHEN OTHER
                   MOVE 7 TO WS-HOLD-DAYS
           END-EVALUATE
           IF WS-IS-LARGE
               IF WS-HOLD-DAYS < 7
                   MOVE 7 TO WS-HOLD-DAYS
               END-IF
           END-IF.
       3000-CALC-AVAILABILITY.
           IF WS-IS-LARGE
               MOVE WS-FIRST-5K TO WS-NEXT-DAY-AVAIL
               COMPUTE WS-REMAINING-HOLD =
                   WS-CHECK-AMOUNT - WS-FIRST-5K
           ELSE
               MOVE WS-CHECK-AMOUNT TO WS-NEXT-DAY-AVAIL
               MOVE 0 TO WS-REMAINING-HOLD
           END-IF
           COMPUTE WS-FLOAT-DAYS = WS-HOLD-DAYS.
       4000-CALC-FLOAT-INCOME.
           MOVE 0 TO WS-TOTAL-FLOAT-INCOME
           PERFORM VARYING WS-DAY-IDX FROM 1 BY 1
               UNTIL WS-DAY-IDX > WS-FLOAT-DAYS
               IF WS-DAY-IDX = 1
                   COMPUTE WS-DAILY-FLOAT =
                       WS-CHECK-AMOUNT - WS-NEXT-DAY-AVAIL
               ELSE
                   MOVE WS-REMAINING-HOLD TO WS-DAILY-FLOAT
               END-IF
               COMPUTE WS-FLOAT-INCOME =
                   WS-DAILY-FLOAT * WS-DAILY-EARN-RATE
               ADD WS-FLOAT-INCOME TO WS-TOTAL-FLOAT-INCOME
           END-PERFORM.
       5000-DISPLAY-RESULTS.
           DISPLAY 'CHECK FLOAT CALCULATION'
           DISPLAY '======================'
           DISPLAY 'CHECK:           ' WS-CHECK-NUM
           DISPLAY 'AMOUNT:          ' WS-CHECK-AMOUNT
           IF WS-LOCAL
               DISPLAY 'TYPE: LOCAL'
           END-IF
           IF WS-NON-LOCAL
               DISPLAY 'TYPE: NON-LOCAL'
           END-IF
           IF WS-GOVERNMENT
               DISPLAY 'TYPE: GOVERNMENT'
           END-IF
           IF WS-ON-US
               DISPLAY 'TYPE: ON-US'
           END-IF
           DISPLAY 'HOLD DAYS:       ' WS-HOLD-DAYS
           DISPLAY 'NEXT-DAY AVAIL:  ' WS-NEXT-DAY-AVAIL
           DISPLAY 'REMAINING HOLD:  ' WS-REMAINING-HOLD
           DISPLAY 'FLOAT INCOME:    ' WS-TOTAL-FLOAT-INCOME.
