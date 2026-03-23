       IDENTIFICATION DIVISION.
       PROGRAM-ID. PAY-OFFSET-APPLY.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-LOAN-DATA.
           05 WS-LOAN-ACCT           PIC X(12).
           05 WS-LOAN-BALANCE        PIC S9(9)V99 COMP-3.
           05 WS-PAST-DUE-AMT        PIC S9(7)V99 COMP-3.
           05 WS-DAYS-PAST-DUE       PIC S9(3) COMP-3.
       01 WS-DEPOSIT-DATA.
           05 WS-DEP-ACCT            PIC X(12).
           05 WS-DEP-BALANCE         PIC S9(9)V99 COMP-3.
           05 WS-DEP-AVAILABLE       PIC S9(9)V99 COMP-3.
       01 WS-OFFSET-FIELDS.
           05 WS-OFFSET-AMOUNT       PIC S9(7)V99 COMP-3.
           05 WS-OFFSET-FEE          PIC S9(5)V99 COMP-3.
           05 WS-NET-OFFSET          PIC S9(7)V99 COMP-3.
           05 WS-NEW-DEP-BAL         PIC S9(9)V99 COMP-3.
           05 WS-NEW-PAST-DUE        PIC S9(7)V99 COMP-3.
       01 WS-OFFSET-STATUS           PIC X(1).
           88 WS-OFFSET-APPLIED      VALUE 'A'.
           88 WS-OFFSET-PARTIAL      VALUE 'P'.
           88 WS-OFFSET-DENIED       VALUE 'D'.
       01 WS-ELIGIBLE-FLAG           PIC X VALUE 'N'.
           88 WS-CAN-OFFSET          VALUE 'Y'.
       01 WS-DENIAL-REASON           PIC X(30).
       01 WS-MIN-BALANCE             PIC S9(7)V99 COMP-3
           VALUE 100.00.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CHECK-ELIGIBILITY
           IF WS-CAN-OFFSET
               PERFORM 3000-CALC-OFFSET
               PERFORM 4000-APPLY-OFFSET
           END-IF
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-OFFSET-AMOUNT
           MOVE 0 TO WS-OFFSET-FEE
           SET WS-OFFSET-DENIED TO TRUE
           MOVE 'N' TO WS-ELIGIBLE-FLAG.
       2000-CHECK-ELIGIBILITY.
           IF WS-DAYS-PAST-DUE < 60
               MOVE 'NOT YET 60 DPD' TO WS-DENIAL-REASON
           ELSE
               IF WS-DEP-AVAILABLE <= WS-MIN-BALANCE
                   MOVE 'INSUFFICIENT DEPOSIT BAL'
                       TO WS-DENIAL-REASON
               ELSE
                   EVALUATE TRUE
                       WHEN WS-PAST-DUE-AMT <= 0
                           MOVE 'NO PAST DUE AMOUNT'
                               TO WS-DENIAL-REASON
                       WHEN OTHER
                           MOVE 'Y' TO WS-ELIGIBLE-FLAG
                   END-EVALUATE
               END-IF
           END-IF.
       3000-CALC-OFFSET.
           COMPUTE WS-OFFSET-AMOUNT =
               WS-DEP-AVAILABLE - WS-MIN-BALANCE
           IF WS-OFFSET-AMOUNT > WS-PAST-DUE-AMT
               MOVE WS-PAST-DUE-AMT TO WS-OFFSET-AMOUNT
           END-IF
           COMPUTE WS-OFFSET-FEE =
               WS-OFFSET-AMOUNT * 0.01
           IF WS-OFFSET-FEE < 10
               MOVE 10.00 TO WS-OFFSET-FEE
           END-IF
           COMPUTE WS-NET-OFFSET =
               WS-OFFSET-AMOUNT + WS-OFFSET-FEE.
       4000-APPLY-OFFSET.
           IF WS-NET-OFFSET <= WS-DEP-AVAILABLE
               SUBTRACT WS-NET-OFFSET FROM WS-DEP-BALANCE
                   GIVING WS-NEW-DEP-BAL
               SUBTRACT WS-OFFSET-AMOUNT FROM
                   WS-PAST-DUE-AMT GIVING WS-NEW-PAST-DUE
               IF WS-NEW-PAST-DUE <= 0
                   SET WS-OFFSET-APPLIED TO TRUE
               ELSE
                   SET WS-OFFSET-PARTIAL TO TRUE
               END-IF
           ELSE
               SET WS-OFFSET-DENIED TO TRUE
               MOVE 'NET EXCEEDS AVAILABLE'
                   TO WS-DENIAL-REASON
           END-IF.
       5000-DISPLAY-RESULTS.
           DISPLAY 'PAYMENT OFFSET APPLICATION'
           DISPLAY '=========================='
           DISPLAY 'LOAN ACCT:      ' WS-LOAN-ACCT
           DISPLAY 'LOAN BALANCE:   ' WS-LOAN-BALANCE
           DISPLAY 'PAST DUE:       ' WS-PAST-DUE-AMT
           DISPLAY 'DEPOSIT ACCT:   ' WS-DEP-ACCT
           DISPLAY 'DEPOSIT BAL:    ' WS-DEP-BALANCE
           IF WS-OFFSET-APPLIED
               DISPLAY 'STATUS: FULL OFFSET APPLIED'
               DISPLAY 'OFFSET AMT:     ' WS-OFFSET-AMOUNT
               DISPLAY 'OFFSET FEE:     ' WS-OFFSET-FEE
               DISPLAY 'NEW DEP BAL:    ' WS-NEW-DEP-BAL
           END-IF
           IF WS-OFFSET-PARTIAL
               DISPLAY 'STATUS: PARTIAL OFFSET'
               DISPLAY 'OFFSET AMT:     ' WS-OFFSET-AMOUNT
               DISPLAY 'REMAINING DUE:  ' WS-NEW-PAST-DUE
           END-IF
           IF WS-OFFSET-DENIED
               DISPLAY 'STATUS: DENIED'
               DISPLAY 'REASON: ' WS-DENIAL-REASON
           END-IF.
