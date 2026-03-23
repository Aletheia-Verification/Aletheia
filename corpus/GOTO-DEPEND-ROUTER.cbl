       IDENTIFICATION DIVISION.
       PROGRAM-ID. GOTO-DEPEND-ROUTER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-TXN-TYPE                PIC 9(1).
       01 WS-ACCT-NUM                PIC X(12).
       01 WS-AMOUNT                  PIC S9(9)V99 COMP-3.
       01 WS-BALANCE                 PIC S9(9)V99 COMP-3.
       01 WS-RESULT                  PIC X(20).
       01 WS-FEE                     PIC S9(5)V99 COMP-3.
       01 WS-STATUS                  PIC X(1).
           88 WS-SUCCESS             VALUE 'S'.
           88 WS-FAILURE             VALUE 'F'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           GO TO 2000-DEPOSIT
                  3000-WITHDRAWAL
                  4000-TRANSFER
                  5000-INQUIRY
               DEPENDING ON WS-TXN-TYPE
           MOVE 'INVALID TYPE' TO WS-RESULT
           GO TO 9000-DISPLAY.
       1000-INITIALIZE.
           MOVE 0 TO WS-FEE
           SET WS-FAILURE TO TRUE
           MOVE SPACES TO WS-RESULT.
       2000-DEPOSIT.
           ADD WS-AMOUNT TO WS-BALANCE
           MOVE 'DEPOSIT OK' TO WS-RESULT
           SET WS-SUCCESS TO TRUE
           GO TO 9000-DISPLAY.
       3000-WITHDRAWAL.
           IF WS-AMOUNT > WS-BALANCE
               MOVE 'INSUFFICIENT FUNDS' TO WS-RESULT
           ELSE
               SUBTRACT WS-AMOUNT FROM WS-BALANCE
               MOVE 'WITHDRAWAL OK' TO WS-RESULT
               SET WS-SUCCESS TO TRUE
           END-IF
           GO TO 9000-DISPLAY.
       4000-TRANSFER.
           IF WS-AMOUNT > WS-BALANCE
               MOVE 'TRANSFER DECLINED' TO WS-RESULT
           ELSE
               SUBTRACT WS-AMOUNT FROM WS-BALANCE
               COMPUTE WS-FEE = WS-AMOUNT * 0.001
               SUBTRACT WS-FEE FROM WS-BALANCE
               MOVE 'TRANSFER OK' TO WS-RESULT
               SET WS-SUCCESS TO TRUE
           END-IF
           GO TO 9000-DISPLAY.
       5000-INQUIRY.
           MOVE 'INQUIRY COMPLETE' TO WS-RESULT
           SET WS-SUCCESS TO TRUE
           GO TO 9000-DISPLAY.
       9000-DISPLAY.
           DISPLAY 'GOTO DEPENDING ROUTER'
           DISPLAY '====================='
           DISPLAY 'TXN TYPE: ' WS-TXN-TYPE
           DISPLAY 'ACCOUNT:  ' WS-ACCT-NUM
           DISPLAY 'AMOUNT:   ' WS-AMOUNT
           DISPLAY 'BALANCE:  ' WS-BALANCE
           DISPLAY 'FEE:      ' WS-FEE
           DISPLAY 'RESULT:   ' WS-RESULT
           STOP RUN.
