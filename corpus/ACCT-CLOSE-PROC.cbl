       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCT-CLOSE-PROC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ACCT-DATA.
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-ACCT-BALANCE        PIC S9(9)V99 COMP-3.
           05 WS-PENDING-TXN         PIC S9(7)V99 COMP-3.
           05 WS-ACCRUED-INT         PIC S9(5)V99 COMP-3.
           05 WS-EARLY-CLOSE-FEE     PIC S9(5)V99 COMP-3.
           05 WS-MONTHS-OPEN         PIC 9(3).
       01 WS-ACCT-TYPE               PIC X(1).
           88 WS-CHECKING            VALUE 'C'.
           88 WS-SAVINGS             VALUE 'S'.
           88 WS-CD                  VALUE 'D'.
           88 WS-MONEY-MARKET        VALUE 'M'.
       01 WS-CLOSE-REASON            PIC X(1).
           88 WS-CUSTOMER-REQ        VALUE 'R'.
           88 WS-DORMANT             VALUE 'D'.
           88 WS-FRAUD               VALUE 'F'.
           88 WS-DECEASED            VALUE 'X'.
       01 WS-DISBURSE-METHOD         PIC X(1).
           88 WS-CHECK-MAIL          VALUE 'C'.
           88 WS-TRANSFER            VALUE 'T'.
           88 WS-WIRE                VALUE 'W'.
       01 WS-CLOSE-FIELDS.
           05 WS-FINAL-BALANCE       PIC S9(9)V99 COMP-3.
           05 WS-TOTAL-DEDUCTIONS    PIC S9(7)V99 COMP-3.
           05 WS-DISBURSE-AMOUNT     PIC S9(9)V99 COMP-3.
           05 WS-WIRE-FEE            PIC S9(5)V99 COMP-3
               VALUE 25.00.
       01 WS-CAN-CLOSE               PIC X VALUE 'N'.
           88 WS-CLOSEABLE           VALUE 'Y'.
       01 WS-BLOCK-REASON            PIC X(30).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CHECK-ELIGIBLE
           IF WS-CLOSEABLE
               PERFORM 3000-CALC-FINAL-BAL
               PERFORM 4000-CALC-FEES
               PERFORM 5000-CALC-DISBURSE
           END-IF
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-DEDUCTIONS
           MOVE 0 TO WS-EARLY-CLOSE-FEE
           MOVE 'N' TO WS-CAN-CLOSE
           MOVE SPACES TO WS-BLOCK-REASON.
       2000-CHECK-ELIGIBLE.
           IF WS-PENDING-TXN > 0
               MOVE 'PENDING TRANSACTIONS' TO
                   WS-BLOCK-REASON
           ELSE
               IF WS-ACCT-BALANCE < 0
                   EVALUATE TRUE
                       WHEN WS-FRAUD
                           MOVE 'Y' TO WS-CAN-CLOSE
                       WHEN WS-DECEASED
                           MOVE 'Y' TO WS-CAN-CLOSE
                       WHEN OTHER
                           MOVE 'NEGATIVE BALANCE'
                               TO WS-BLOCK-REASON
                   END-EVALUATE
               ELSE
                   MOVE 'Y' TO WS-CAN-CLOSE
               END-IF
           END-IF.
       3000-CALC-FINAL-BAL.
           COMPUTE WS-FINAL-BALANCE =
               WS-ACCT-BALANCE + WS-ACCRUED-INT.
       4000-CALC-FEES.
           IF WS-CD
               IF WS-MONTHS-OPEN < 12
                   COMPUTE WS-EARLY-CLOSE-FEE =
                       WS-ACCT-BALANCE * 0.01
                   IF WS-EARLY-CLOSE-FEE < 25
                       MOVE 25.00 TO WS-EARLY-CLOSE-FEE
                   END-IF
               END-IF
           END-IF
           IF WS-CHECKING
               IF WS-MONTHS-OPEN < 6
                   MOVE 25.00 TO WS-EARLY-CLOSE-FEE
               END-IF
           END-IF
           COMPUTE WS-TOTAL-DEDUCTIONS =
               WS-EARLY-CLOSE-FEE.
       5000-CALC-DISBURSE.
           COMPUTE WS-DISBURSE-AMOUNT =
               WS-FINAL-BALANCE - WS-TOTAL-DEDUCTIONS
           IF WS-WIRE
               SUBTRACT WS-WIRE-FEE FROM
                   WS-DISBURSE-AMOUNT
           END-IF
           IF WS-DISBURSE-AMOUNT < 0
               MOVE 0 TO WS-DISBURSE-AMOUNT
           END-IF.
       6000-DISPLAY-RESULTS.
           DISPLAY 'ACCOUNT CLOSING PROCESS'
           DISPLAY '======================='
           DISPLAY 'ACCOUNT:       ' WS-ACCT-NUM
           DISPLAY 'BALANCE:       ' WS-ACCT-BALANCE
           DISPLAY 'ACCRUED INT:   ' WS-ACCRUED-INT
           IF WS-CLOSEABLE
               DISPLAY 'STATUS: CLOSING'
               DISPLAY 'FINAL BAL:     ' WS-FINAL-BALANCE
               DISPLAY 'EARLY FEE:     ' WS-EARLY-CLOSE-FEE
               DISPLAY 'DISBURSE AMT:  ' WS-DISBURSE-AMOUNT
               IF WS-CHECK-MAIL
                   DISPLAY 'METHOD: CHECK MAILED'
               END-IF
               IF WS-TRANSFER
                   DISPLAY 'METHOD: TRANSFER'
               END-IF
               IF WS-WIRE
                   DISPLAY 'METHOD: WIRE (FEE $25)'
               END-IF
           ELSE
               DISPLAY 'STATUS: BLOCKED'
               DISPLAY 'REASON: ' WS-BLOCK-REASON
           END-IF.
