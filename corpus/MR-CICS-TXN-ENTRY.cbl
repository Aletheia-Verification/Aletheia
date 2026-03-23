       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-CICS-TXN-ENTRY.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-TXN-INPUT.
           05 WS-TI-ACCT-NUM      PIC X(12).
           05 WS-TI-TXN-TYPE      PIC X(2).
               88 TI-DEPOSIT      VALUE 'DP'.
               88 TI-WITHDRAW     VALUE 'WD'.
               88 TI-TRANSFER     VALUE 'TR'.
           05 WS-TI-AMOUNT        PIC S9(9)V99 COMP-3.
           05 WS-TI-DEST-ACCT     PIC X(12).
       01 WS-ACCT-RECORD.
           05 WS-AR-ACCT-NUM      PIC X(12).
           05 WS-AR-NAME          PIC X(30).
           05 WS-AR-BALANCE       PIC S9(11)V99 COMP-3.
           05 WS-AR-STATUS        PIC X(2).
       01 WS-RESPONSE             PIC S9(8) COMP.
       01 WS-RESULT-MSG           PIC X(40).
       01 WS-TXN-SEQ              PIC 9(8).
       01 WS-MAP-DATA.
           05 WS-MD-ACCT          PIC X(12).
           05 WS-MD-TYPE          PIC X(2).
           05 WS-MD-AMT           PIC Z(7)9.99-.
           05 WS-MD-DEST          PIC X(12).
           05 WS-MD-BAL           PIC Z(9)9.99-.
           05 WS-MD-MSG           PIC X(40).
       01 WS-VALID-TXN            PIC X VALUE 'N'.
           88 TXN-VALID           VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-RECEIVE-INPUT
           PERFORM 2000-VALIDATE
           IF TXN-VALID
               PERFORM 3000-PROCESS-TXN
               PERFORM 4000-UPDATE-RECORD
           END-IF
           PERFORM 5000-SEND-RESPONSE
           EXEC CICS
               RETURN TRANSID('TXEN')
               COMMAREA(WS-TXN-INPUT)
           END-EXEC.
       1000-RECEIVE-INPUT.
           EXEC CICS
               RECEIVE MAP('TXNMAP')
               MAPSET('TXNSET')
               INTO(WS-MAP-DATA)
               RESP(WS-RESPONSE)
           END-EXEC
           IF WS-RESPONSE NOT = 0
               MOVE 'RECEIVE ERROR' TO WS-RESULT-MSG
           ELSE
               MOVE WS-MD-ACCT TO WS-TI-ACCT-NUM
               MOVE WS-MD-TYPE TO WS-TI-TXN-TYPE
               MOVE WS-MD-DEST TO WS-TI-DEST-ACCT
           END-IF.
       2000-VALIDATE.
           MOVE 'N' TO WS-VALID-TXN
           IF WS-TI-ACCT-NUM = SPACES
               MOVE 'ACCOUNT NUMBER REQUIRED'
                   TO WS-RESULT-MSG
           ELSE
               IF WS-TI-AMOUNT <= 0
                   MOVE 'AMOUNT MUST BE POSITIVE'
                       TO WS-RESULT-MSG
               ELSE
                   EXEC CICS
                       READ DATASET('ACCTMAST')
                       INTO(WS-ACCT-RECORD)
                       RIDFLD(WS-TI-ACCT-NUM)
                       RESP(WS-RESPONSE)
                   END-EXEC
                   IF WS-RESPONSE = 0
                       IF WS-AR-STATUS = 'AC'
                           MOVE 'Y' TO WS-VALID-TXN
                       ELSE
                           MOVE 'ACCOUNT NOT ACTIVE'
                               TO WS-RESULT-MSG
                       END-IF
                   ELSE
                       MOVE 'ACCOUNT NOT FOUND'
                           TO WS-RESULT-MSG
                   END-IF
               END-IF
           END-IF.
       3000-PROCESS-TXN.
           EVALUATE TRUE
               WHEN TI-DEPOSIT
                   ADD WS-TI-AMOUNT TO WS-AR-BALANCE
                   MOVE 'DEPOSIT PROCESSED' TO WS-RESULT-MSG
               WHEN TI-WITHDRAW
                   IF WS-TI-AMOUNT > WS-AR-BALANCE
                       MOVE 'INSUFFICIENT FUNDS'
                           TO WS-RESULT-MSG
                       MOVE 'N' TO WS-VALID-TXN
                   ELSE
                       SUBTRACT WS-TI-AMOUNT FROM
                           WS-AR-BALANCE
                       MOVE 'WITHDRAWAL PROCESSED'
                           TO WS-RESULT-MSG
                   END-IF
               WHEN TI-TRANSFER
                   IF WS-TI-AMOUNT > WS-AR-BALANCE
                       MOVE 'INSUFFICIENT FOR TRANSFER'
                           TO WS-RESULT-MSG
                       MOVE 'N' TO WS-VALID-TXN
                   ELSE
                       SUBTRACT WS-TI-AMOUNT FROM
                           WS-AR-BALANCE
                       MOVE 'TRANSFER PROCESSED'
                           TO WS-RESULT-MSG
                   END-IF
               WHEN OTHER
                   MOVE 'INVALID TRANSACTION TYPE'
                       TO WS-RESULT-MSG
                   MOVE 'N' TO WS-VALID-TXN
           END-EVALUATE.
       4000-UPDATE-RECORD.
           IF TXN-VALID
               EXEC CICS
                   REWRITE DATASET('ACCTMAST')
                   FROM(WS-ACCT-RECORD)
                   RESP(WS-RESPONSE)
               END-EXEC
               IF WS-RESPONSE NOT = 0
                   MOVE 'UPDATE FAILED' TO WS-RESULT-MSG
               END-IF
           END-IF.
       5000-SEND-RESPONSE.
           MOVE WS-AR-BALANCE TO WS-MD-BAL
           MOVE WS-RESULT-MSG TO WS-MD-MSG
           EXEC CICS
               SEND MAP('TXNMAP')
               MAPSET('TXNSET')
               FROM(WS-MAP-DATA)
               ERASE
           END-EXEC.
