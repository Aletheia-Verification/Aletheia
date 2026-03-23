       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOAN-PAYOFF-QUOTE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-LOAN-DATA.
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-CURRENT-BAL         PIC S9(9)V99 COMP-3.
           05 WS-ANNUAL-RATE         PIC S9(3)V9(6) COMP-3.
           05 WS-DAILY-RATE          PIC S9(1)V9(10) COMP-3.
           05 WS-MONTHLY-PMT         PIC S9(7)V99 COMP-3.
           05 WS-ESCROW-BAL          PIC S9(7)V99 COMP-3.
           05 WS-SUSPENSE-BAL        PIC S9(7)V99 COMP-3.
       01 WS-PAYOFF-DATE             PIC 9(8).
       01 WS-LAST-PMT-DATE           PIC 9(8).
       01 WS-DAYS-TO-PAYOFF          PIC 9(3).
       01 WS-PAYOFF-FIELDS.
           05 WS-PER-DIEM            PIC S9(5)V99 COMP-3.
           05 WS-ACCRUED-INT         PIC S9(7)V99 COMP-3.
           05 WS-PREPAY-FEE          PIC S9(7)V99 COMP-3.
           05 WS-RECORDING-FEE       PIC S9(5)V99 COMP-3
               VALUE 75.00.
           05 WS-WIRE-FEE            PIC S9(5)V99 COMP-3
               VALUE 25.00.
           05 WS-LATE-CHARGES        PIC S9(5)V99 COMP-3.
           05 WS-OTHER-FEES          PIC S9(5)V99 COMP-3.
           05 WS-ESCROW-REFUND       PIC S9(7)V99 COMP-3.
           05 WS-TOTAL-PAYOFF        PIC S9(9)V99 COMP-3.
           05 WS-NET-PAYOFF          PIC S9(9)V99 COMP-3.
       01 WS-GOOD-THRU-DATE          PIC 9(8).
       01 WS-GOOD-THRU-DAYS          PIC 9(2) VALUE 10.
       01 WS-PAYOFF-TYPE             PIC X(1).
           88 WS-REGULAR-PAYOFF      VALUE 'R'.
           88 WS-REFI-PAYOFF         VALUE 'F'.
           88 WS-SHORT-SALE          VALUE 'S'.
       01 WS-QUOTE-MSG               PIC X(100).
       01 WS-PROCESS-FLAG            PIC X VALUE 'Y'.
           88 WS-CONTINUE             VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-PER-DIEM
           PERFORM 3000-CALC-ACCRUED-INT
           PERFORM 4000-CALC-FEES
           PERFORM 5000-CALC-TOTAL-PAYOFF
           PERFORM 6000-BUILD-QUOTE-MSG
           PERFORM 7000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           COMPUTE WS-DAILY-RATE =
               WS-ANNUAL-RATE / 360
           MOVE 0 TO WS-PREPAY-FEE
           MOVE 0 TO WS-LATE-CHARGES
           MOVE 0 TO WS-OTHER-FEES.
       2000-CALC-PER-DIEM.
           COMPUTE WS-PER-DIEM =
               WS-CURRENT-BAL * WS-DAILY-RATE.
       3000-CALC-ACCRUED-INT.
           COMPUTE WS-ACCRUED-INT =
               WS-PER-DIEM * WS-DAYS-TO-PAYOFF
           IF WS-ACCRUED-INT < 0
               MOVE 0 TO WS-ACCRUED-INT
           END-IF.
       4000-CALC-FEES.
           EVALUATE TRUE
               WHEN WS-REGULAR-PAYOFF
                   MOVE 0 TO WS-PREPAY-FEE
               WHEN WS-REFI-PAYOFF
                   COMPUTE WS-PREPAY-FEE =
                       WS-CURRENT-BAL * 0.01
                   IF WS-PREPAY-FEE > 5000
                       MOVE 5000.00 TO WS-PREPAY-FEE
                   END-IF
               WHEN WS-SHORT-SALE
                   MOVE 0 TO WS-PREPAY-FEE
                   MOVE 0 TO WS-RECORDING-FEE
           END-EVALUATE
           IF WS-SUSPENSE-BAL > 0
               SUBTRACT WS-SUSPENSE-BAL FROM
                   WS-OTHER-FEES
           END-IF.
       5000-CALC-TOTAL-PAYOFF.
           COMPUTE WS-TOTAL-PAYOFF =
               WS-CURRENT-BAL +
               WS-ACCRUED-INT +
               WS-PREPAY-FEE +
               WS-RECORDING-FEE +
               WS-WIRE-FEE +
               WS-LATE-CHARGES +
               WS-OTHER-FEES
           IF WS-ESCROW-BAL > 0
               MOVE WS-ESCROW-BAL TO WS-ESCROW-REFUND
           ELSE
               MOVE 0 TO WS-ESCROW-REFUND
           END-IF
           COMPUTE WS-NET-PAYOFF =
               WS-TOTAL-PAYOFF - WS-ESCROW-REFUND.
       6000-BUILD-QUOTE-MSG.
           STRING 'PAYOFF QUOTE ACCT '
                       DELIMITED BY SIZE
                  WS-ACCT-NUM DELIMITED BY SIZE
                  ' AMT: ' DELIMITED BY SIZE
                  WS-TOTAL-PAYOFF DELIMITED BY SIZE
                  ' PER-DIEM: ' DELIMITED BY SIZE
                  WS-PER-DIEM DELIMITED BY SIZE
                  INTO WS-QUOTE-MSG
           END-STRING.
       7000-DISPLAY-RESULTS.
           DISPLAY 'PAYOFF QUOTE'
           DISPLAY '============'
           DISPLAY 'ACCOUNT:        ' WS-ACCT-NUM
           DISPLAY 'CURRENT BAL:    ' WS-CURRENT-BAL
           DISPLAY 'ANNUAL RATE:    ' WS-ANNUAL-RATE
           DISPLAY 'PER DIEM:       ' WS-PER-DIEM
           DISPLAY 'DAYS TO PAYOFF: ' WS-DAYS-TO-PAYOFF
           DISPLAY 'ACCRUED INT:    ' WS-ACCRUED-INT
           DISPLAY 'PREPAY FEE:     ' WS-PREPAY-FEE
           DISPLAY 'RECORDING FEE:  ' WS-RECORDING-FEE
           DISPLAY 'WIRE FEE:       ' WS-WIRE-FEE
           DISPLAY 'LATE CHARGES:   ' WS-LATE-CHARGES
           DISPLAY 'TOTAL PAYOFF:   ' WS-TOTAL-PAYOFF
           DISPLAY 'ESCROW REFUND:  ' WS-ESCROW-REFUND
           DISPLAY 'NET PAYOFF:     ' WS-NET-PAYOFF
           DISPLAY 'QUOTE MSG:      ' WS-QUOTE-MSG.
