       IDENTIFICATION DIVISION.
       PROGRAM-ID. LEGACY-ALTER-DISPATCH.
      *================================================================*
      * LEGACY TRANSACTION DISPATCH USING ALTER                        *
      * Runtime paragraph routing via ALTER statement for transaction   *
      * processing: DEPOSIT, WITHDRAWAL, TRANSFER, INQUIRY.            *
      * ALTER forces REQUIRES_MANUAL_REVIEW.                           *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- Transaction Fields ---
       01  WS-TXN-TYPE-CODE           PIC 9(1).
           88  TXN-DEPOSIT             VALUE 1.
           88  TXN-WITHDRAWAL          VALUE 2.
           88  TXN-TRANSFER            VALUE 3.
           88  TXN-INQUIRY             VALUE 4.
       01  WS-TXN-AMOUNT              PIC S9(9)V99 COMP-3.
       01  WS-ACCOUNT-BALANCE         PIC S9(9)V99 COMP-3.
       01  WS-FEE-AMOUNT              PIC S9(7)V99 COMP-3.
       01  WS-NET-AMOUNT              PIC S9(9)V99 COMP-3.
      *--- Fee Schedule ---
       01  WS-DEPOSIT-FEE             PIC S9(5)V99 COMP-3.
       01  WS-WITHDRAWAL-FEE          PIC S9(5)V99 COMP-3.
       01  WS-TRANSFER-FEE            PIC S9(5)V99 COMP-3.
       01  WS-INQUIRY-FEE             PIC S9(5)V99 COMP-3.
      *--- Processing Flags ---
       01  WS-PROCESS-STATUS          PIC X(10).
       01  WS-ERROR-FLAG              PIC X(1).
       01  WS-TXN-COUNT               PIC 9(5).
       01  WS-FEE-TOTAL               PIC S9(9)V99 COMP-3.
      *--- Audit ---
       01  WS-AUDIT-ACCT              PIC X(10).
       01  WS-AUDIT-ACTION            PIC X(15).
       01  WS-PRIOR-BALANCE           PIC S9(9)V99 COMP-3.

       PROCEDURE DIVISION.
       MAIN-PROGRAM.
           PERFORM INITIALIZE-SYSTEM
           PERFORM LOAD-TRANSACTION
           PERFORM SETUP-DISPATCHER
           PERFORM DISPATCH-TRANSACTION
           PERFORM DISPLAY-RESULTS
           STOP RUN.

       INITIALIZE-SYSTEM.
           MOVE 0 TO WS-TXN-AMOUNT
           MOVE 25000.00 TO WS-ACCOUNT-BALANCE
           MOVE 0 TO WS-FEE-AMOUNT
           MOVE 0 TO WS-NET-AMOUNT
           MOVE 0 TO WS-FEE-TOTAL
           MOVE 0 TO WS-TXN-COUNT
           MOVE 'N' TO WS-ERROR-FLAG
           MOVE 'PENDING' TO WS-PROCESS-STATUS
           MOVE 0.50 TO WS-DEPOSIT-FEE
           MOVE 2.50 TO WS-WITHDRAWAL-FEE
           MOVE 5.00 TO WS-TRANSFER-FEE
           MOVE 0.00 TO WS-INQUIRY-FEE
           MOVE 'ACCT001234' TO WS-AUDIT-ACCT.

       LOAD-TRANSACTION.
           MOVE 1 TO WS-TXN-TYPE-CODE
           MOVE 1500.00 TO WS-TXN-AMOUNT
           MOVE WS-ACCOUNT-BALANCE TO WS-PRIOR-BALANCE.

       SETUP-DISPATCHER.
           EVALUATE TRUE
               WHEN TXN-DEPOSIT
                   ALTER DISPATCH-GOTO TO PROCEED TO
                       PROCESS-DEPOSIT
               WHEN TXN-WITHDRAWAL
                   ALTER DISPATCH-GOTO TO PROCEED TO
                       PROCESS-WITHDRAWAL
               WHEN TXN-TRANSFER
                   ALTER DISPATCH-GOTO TO PROCEED TO
                       PROCESS-TRANSFER
               WHEN TXN-INQUIRY
                   ALTER DISPATCH-GOTO TO PROCEED TO
                       PROCESS-INQUIRY
           END-EVALUATE.

       DISPATCH-TRANSACTION.
           ADD 1 TO WS-TXN-COUNT
           PERFORM DISPATCH-GOTO THRU
                   DISPATCH-GOTO-EXIT
           PERFORM APPLY-FEE
           PERFORM FINALIZE-TRANSACTION.

       DISPATCH-GOTO.
           GO TO PROCESS-DEPOSIT.

       DISPATCH-GOTO-EXIT.
           EXIT.

       PROCESS-DEPOSIT.
           MOVE 'DEPOSIT' TO WS-AUDIT-ACTION
           ADD WS-TXN-AMOUNT TO WS-ACCOUNT-BALANCE
           MOVE WS-DEPOSIT-FEE TO WS-FEE-AMOUNT
           MOVE 'COMPLETED' TO WS-PROCESS-STATUS
           GO TO DISPATCH-GOTO-EXIT.

       PROCESS-WITHDRAWAL.
           MOVE 'WITHDRAWAL' TO WS-AUDIT-ACTION
           IF WS-TXN-AMOUNT > WS-ACCOUNT-BALANCE
               MOVE 'DECLINED' TO WS-PROCESS-STATUS
               MOVE 'Y' TO WS-ERROR-FLAG
           ELSE
               SUBTRACT WS-TXN-AMOUNT FROM WS-ACCOUNT-BALANCE
               MOVE WS-WITHDRAWAL-FEE TO WS-FEE-AMOUNT
               MOVE 'COMPLETED' TO WS-PROCESS-STATUS
           END-IF
           GO TO DISPATCH-GOTO-EXIT.

       PROCESS-TRANSFER.
           MOVE 'TRANSFER' TO WS-AUDIT-ACTION
           IF WS-TXN-AMOUNT > WS-ACCOUNT-BALANCE
               MOVE 'DECLINED' TO WS-PROCESS-STATUS
               MOVE 'Y' TO WS-ERROR-FLAG
           ELSE
               SUBTRACT WS-TXN-AMOUNT FROM WS-ACCOUNT-BALANCE
               MOVE WS-TRANSFER-FEE TO WS-FEE-AMOUNT
               MOVE 'COMPLETED' TO WS-PROCESS-STATUS
           END-IF
           GO TO DISPATCH-GOTO-EXIT.

       PROCESS-INQUIRY.
           MOVE 'INQUIRY' TO WS-AUDIT-ACTION
           MOVE WS-INQUIRY-FEE TO WS-FEE-AMOUNT
           MOVE 'COMPLETED' TO WS-PROCESS-STATUS
           GO TO DISPATCH-GOTO-EXIT.

       APPLY-FEE.
           SUBTRACT WS-FEE-AMOUNT FROM WS-ACCOUNT-BALANCE
           ADD WS-FEE-AMOUNT TO WS-FEE-TOTAL
           COMPUTE WS-NET-AMOUNT =
               WS-ACCOUNT-BALANCE - WS-PRIOR-BALANCE.

       FINALIZE-TRANSACTION.
           IF WS-ERROR-FLAG = 'Y'
               DISPLAY 'TXN DECLINED - INSUFFICIENT FUNDS'
           END-IF.

       DISPLAY-RESULTS.
           DISPLAY 'LEGACY ALTER DISPATCH REPORT'
           DISPLAY '============================'
           DISPLAY 'ACCOUNT:        ' WS-AUDIT-ACCT
           DISPLAY 'ACTION:         ' WS-AUDIT-ACTION
           DISPLAY 'TXN AMOUNT:     ' WS-TXN-AMOUNT
           DISPLAY 'FEE:            ' WS-FEE-AMOUNT
           DISPLAY 'PRIOR BALANCE:  ' WS-PRIOR-BALANCE
           DISPLAY 'NEW BALANCE:    ' WS-ACCOUNT-BALANCE
           DISPLAY 'NET CHANGE:     ' WS-NET-AMOUNT
           DISPLAY 'STATUS:         ' WS-PROCESS-STATUS
           DISPLAY 'FEE TOTAL:      ' WS-FEE-TOTAL
           DISPLAY 'TXN COUNT:      ' WS-TXN-COUNT.
