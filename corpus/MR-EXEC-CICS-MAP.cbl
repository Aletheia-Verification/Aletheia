       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-EXEC-CICS-MAP.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-TXN-DATA.
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-TXN-TYPE            PIC X(2).
           05 WS-TXN-AMOUNT          PIC S9(9)V99 COMP-3.
           05 WS-TELLER-ID           PIC X(8).
       01 WS-SCREEN-FIELDS.
           05 WS-SCR-ACCT            PIC X(12).
           05 WS-SCR-AMOUNT          PIC X(12).
           05 WS-SCR-TYPE            PIC X(2).
           05 WS-SCR-MSG             PIC X(40).
           05 WS-SCR-STATUS          PIC X(10).
       01 WS-TXN-CODE                PIC X(2).
           88 WS-DEPOSIT             VALUE 'DP'.
           88 WS-WITHDRAW            VALUE 'WD'.
           88 WS-BALANCE-INQ         VALUE 'BI'.
       01 WS-BALANCE                 PIC S9(9)V99 COMP-3.
       01 WS-NEW-BALANCE             PIC S9(9)V99 COMP-3.
       01 WS-FEE                     PIC S9(5)V99 COMP-3.
       01 WS-RESULT                  PIC X(1).
           88 WS-SUCCESS             VALUE 'S'.
           88 WS-FAILURE             VALUE 'F'.
       01 WS-RESP-CODE               PIC S9(8) COMP.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-RECEIVE-SCREEN
           PERFORM 3000-VALIDATE-INPUT
           IF WS-SUCCESS
               PERFORM 4000-PROCESS-TXN
           END-IF
           PERFORM 5000-SEND-RESPONSE
           EXEC CICS RETURN
           END-EXEC.
       1000-INITIALIZE.
           MOVE 0 TO WS-FEE
           MOVE 0 TO WS-NEW-BALANCE
           SET WS-FAILURE TO TRUE
           MOVE SPACES TO WS-SCR-MSG.
       2000-RECEIVE-SCREEN.
           EXEC CICS RECEIVE MAP('TLRMAP')
               MAPSET('TLRSET')
               INTO(WS-SCREEN-FIELDS)
               RESP(WS-RESP-CODE)
           END-EXEC
           IF WS-RESP-CODE NOT = 0
               MOVE 'RECEIVE ERROR' TO WS-SCR-MSG
           ELSE
               MOVE WS-SCR-ACCT TO WS-ACCT-NUM
               MOVE WS-SCR-TYPE TO WS-TXN-CODE
           END-IF.
       3000-VALIDATE-INPUT.
           IF WS-ACCT-NUM = SPACES
               MOVE 'ACCOUNT REQUIRED' TO WS-SCR-MSG
           ELSE
               EVALUATE TRUE
                   WHEN WS-DEPOSIT
                       SET WS-SUCCESS TO TRUE
                   WHEN WS-WITHDRAW
                       SET WS-SUCCESS TO TRUE
                   WHEN WS-BALANCE-INQ
                       SET WS-SUCCESS TO TRUE
                   WHEN OTHER
                       MOVE 'INVALID TXN TYPE' TO
                           WS-SCR-MSG
               END-EVALUATE
           END-IF.
       4000-PROCESS-TXN.
           EVALUATE TRUE
               WHEN WS-DEPOSIT
                   ADD WS-TXN-AMOUNT TO WS-BALANCE
                       GIVING WS-NEW-BALANCE
                   IF WS-TXN-AMOUNT > 10000
                       MOVE 'CTR REQUIRED' TO WS-SCR-MSG
                   ELSE
                       MOVE 'DEPOSIT POSTED' TO WS-SCR-MSG
                   END-IF
               WHEN WS-WITHDRAW
                   IF WS-TXN-AMOUNT > WS-BALANCE
                       SET WS-FAILURE TO TRUE
                       MOVE 'INSUFFICIENT FUNDS' TO
                           WS-SCR-MSG
                   ELSE
                       SUBTRACT WS-TXN-AMOUNT FROM
                           WS-BALANCE GIVING WS-NEW-BALANCE
                       COMPUTE WS-FEE =
                           WS-TXN-AMOUNT * 0.001
                       MOVE 'WITHDRAWAL POSTED' TO
                           WS-SCR-MSG
                   END-IF
               WHEN WS-BALANCE-INQ
                   MOVE WS-BALANCE TO WS-NEW-BALANCE
                   MOVE 'BALANCE DISPLAYED' TO WS-SCR-MSG
           END-EVALUATE.
       5000-SEND-RESPONSE.
           IF WS-SUCCESS
               MOVE 'COMPLETE' TO WS-SCR-STATUS
           ELSE
               MOVE 'ERROR' TO WS-SCR-STATUS
           END-IF
           EXEC CICS SEND MAP('TLRMAP')
               MAPSET('TLRSET')
               FROM(WS-SCREEN-FIELDS)
               ERASE
               RESP(WS-RESP-CODE)
           END-EXEC
           DISPLAY 'TELLER TXN: ' WS-TXN-CODE
               ' ACCT=' WS-ACCT-NUM
               ' AMT=' WS-TXN-AMOUNT.
