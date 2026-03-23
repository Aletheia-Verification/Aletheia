       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-ALTER-DISPATCH-V2.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-TXN-TYPE                PIC 9(1).
           88 TXN-DEPOSIT            VALUE 1.
           88 TXN-WITHDRAWAL         VALUE 2.
           88 TXN-TRANSFER           VALUE 3.
           88 TXN-INQUIRY            VALUE 4.
       01 WS-ACCT-NUM                PIC X(12).
       01 WS-AMOUNT                  PIC S9(9)V99 COMP-3.
       01 WS-BALANCE                 PIC S9(9)V99 COMP-3.
       01 WS-FEE                     PIC S9(5)V99 COMP-3.
       01 WS-RESULT-CODE             PIC X(2).
           88 WS-SUCCESS             VALUE 'OK'.
           88 WS-FAILED              VALUE 'FL'.
       01 WS-PROCESS-COUNT           PIC S9(5) COMP-3.
       01 WS-ERROR-COUNT             PIC S9(5) COMP-3.
       01 WS-AUDIT-FLAG              PIC X VALUE 'N'.
           88 WS-NEEDS-AUDIT         VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM INITIALIZE-SYSTEM
           PERFORM SETUP-DISPATCHER
           PERFORM DISPATCH-TXN THRU DISPATCH-TXN-EXIT
           PERFORM APPLY-FEE
           PERFORM DISPLAY-RESULT
           STOP RUN.
       INITIALIZE-SYSTEM.
           MOVE 0 TO WS-FEE
           MOVE 0 TO WS-PROCESS-COUNT
           MOVE 0 TO WS-ERROR-COUNT
           SET WS-FAILED TO TRUE.
       SETUP-DISPATCHER.
           EVALUATE TRUE
               WHEN TXN-DEPOSIT
                   ALTER HANDLER-GOTO TO PROCEED TO
                       HANDLE-DEPOSIT
               WHEN TXN-WITHDRAWAL
                   ALTER HANDLER-GOTO TO PROCEED TO
                       HANDLE-WITHDRAWAL
               WHEN TXN-TRANSFER
                   ALTER HANDLER-GOTO TO PROCEED TO
                       HANDLE-TRANSFER
               WHEN TXN-INQUIRY
                   ALTER HANDLER-GOTO TO PROCEED TO
                       HANDLE-INQUIRY
           END-EVALUATE.
       DISPATCH-TXN.
           PERFORM HANDLER-GOTO THRU HANDLER-GOTO-EXIT.
       DISPATCH-TXN-EXIT.
           EXIT.
       HANDLER-GOTO.
           GO TO HANDLE-DEPOSIT.
       HANDLER-GOTO-EXIT.
           EXIT.
       HANDLE-DEPOSIT.
           ADD WS-AMOUNT TO WS-BALANCE
           ADD 1 TO WS-PROCESS-COUNT
           SET WS-SUCCESS TO TRUE
           DISPLAY 'DEPOSIT PROCESSED: ' WS-AMOUNT
           GO TO HANDLER-GOTO-EXIT.
       HANDLE-WITHDRAWAL.
           IF WS-AMOUNT > WS-BALANCE
               SET WS-FAILED TO TRUE
               ADD 1 TO WS-ERROR-COUNT
               DISPLAY 'INSUFFICIENT FUNDS'
           ELSE
               SUBTRACT WS-AMOUNT FROM WS-BALANCE
               ADD 1 TO WS-PROCESS-COUNT
               SET WS-SUCCESS TO TRUE
               IF WS-AMOUNT > 10000
                   MOVE 'Y' TO WS-AUDIT-FLAG
               END-IF
           END-IF
           GO TO HANDLER-GOTO-EXIT.
       HANDLE-TRANSFER.
           IF WS-AMOUNT > WS-BALANCE
               SET WS-FAILED TO TRUE
               DISPLAY 'TRANSFER DECLINED'
           ELSE
               SUBTRACT WS-AMOUNT FROM WS-BALANCE
               COMPUTE WS-FEE = WS-AMOUNT * 0.0025
               IF WS-FEE < 5.00
                   MOVE 5.00 TO WS-FEE
               END-IF
               SET WS-SUCCESS TO TRUE
               MOVE 'Y' TO WS-AUDIT-FLAG
           END-IF
           GO TO HANDLER-GOTO-EXIT.
       HANDLE-INQUIRY.
           SET WS-SUCCESS TO TRUE
           DISPLAY 'BALANCE: ' WS-BALANCE
           GO TO HANDLER-GOTO-EXIT.
       APPLY-FEE.
           IF WS-FEE > 0
               SUBTRACT WS-FEE FROM WS-BALANCE
           END-IF.
       DISPLAY-RESULT.
           DISPLAY 'ALTER DISPATCH V2 RESULT'
           DISPLAY '========================'
           DISPLAY 'ACCOUNT:   ' WS-ACCT-NUM
           DISPLAY 'TXN TYPE:  ' WS-TXN-TYPE
           DISPLAY 'AMOUNT:    ' WS-AMOUNT
           DISPLAY 'BALANCE:   ' WS-BALANCE
           DISPLAY 'FEE:       ' WS-FEE
           DISPLAY 'RESULT:    ' WS-RESULT-CODE
           DISPLAY 'PROCESSED: ' WS-PROCESS-COUNT
           DISPLAY 'ERRORS:    ' WS-ERROR-COUNT
           IF WS-NEEDS-AUDIT
               DISPLAY 'AUDIT FLAG: YES'
           END-IF.
