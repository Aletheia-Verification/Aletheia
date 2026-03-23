       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-CICS-WIRE-AUTH.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-WIRE-REQUEST.
           05 WS-WR-ACCT         PIC X(12).
           05 WS-WR-AMOUNT       PIC S9(11)V99 COMP-3.
           05 WS-WR-BENE-NAME    PIC X(30).
           05 WS-WR-BENE-BANK    PIC X(9).
           05 WS-WR-CCY          PIC X(3).
       01 WS-ACCT-REC.
           05 WS-AR-ACCT         PIC X(12).
           05 WS-AR-BALANCE      PIC S9(11)V99 COMP-3.
           05 WS-AR-WIRE-LIMIT   PIC S9(11)V99 COMP-3.
           05 WS-AR-STATUS       PIC X(2).
       01 WS-MAP-IO.
           05 WS-MI-ACCT         PIC X(12).
           05 WS-MI-AMT          PIC Z(9)9.99-.
           05 WS-MI-BENE         PIC X(30).
           05 WS-MI-MSG          PIC X(40).
       01 WS-RESP                PIC S9(8) COMP.
       01 WS-AUTH-RESULT         PIC X(12).
       PROCEDURE DIVISION.
       0000-MAIN.
           EXEC CICS
               RECEIVE MAP('WIREMAP')
               MAPSET('WIRESET')
               INTO(WS-MAP-IO)
               RESP(WS-RESP)
           END-EXEC
           MOVE WS-MI-ACCT TO WS-WR-ACCT
           PERFORM 1000-READ-ACCT
           IF WS-AUTH-RESULT = 'FOUND       '
               PERFORM 2000-VALIDATE
               IF WS-AUTH-RESULT = 'APPROVED    '
                   PERFORM 3000-PROCESS-WIRE
               END-IF
           END-IF
           PERFORM 4000-SEND
           EXEC CICS
               RETURN TRANSID('WIRE')
               COMMAREA(WS-WIRE-REQUEST)
           END-EXEC.
       1000-READ-ACCT.
           EXEC CICS
               READ DATASET('ACCTMAST')
               INTO(WS-ACCT-REC)
               RIDFLD(WS-WR-ACCT)
               UPDATE
               RESP(WS-RESP)
           END-EXEC
           IF WS-RESP = 0
               MOVE 'FOUND       ' TO WS-AUTH-RESULT
           ELSE
               MOVE 'NOT-FOUND   ' TO WS-AUTH-RESULT
               MOVE 'ACCOUNT NOT FOUND' TO WS-MI-MSG
           END-IF.
       2000-VALIDATE.
           IF WS-AR-STATUS NOT = 'AC'
               MOVE 'ACCT-BLOCKED' TO WS-AUTH-RESULT
               MOVE 'ACCOUNT NOT ACTIVE' TO WS-MI-MSG
           ELSE
               IF WS-WR-AMOUNT > WS-AR-BALANCE
                   MOVE 'NSF         ' TO WS-AUTH-RESULT
                   MOVE 'INSUFFICIENT FUNDS' TO WS-MI-MSG
               ELSE
                   IF WS-WR-AMOUNT > WS-AR-WIRE-LIMIT
                       MOVE 'OVER-LIMIT  ' TO WS-AUTH-RESULT
                       MOVE 'EXCEEDS WIRE LIMIT'
                           TO WS-MI-MSG
                   ELSE
                       MOVE 'APPROVED    ' TO WS-AUTH-RESULT
                       MOVE 'WIRE AUTHORIZED' TO WS-MI-MSG
                   END-IF
               END-IF
           END-IF.
       3000-PROCESS-WIRE.
           SUBTRACT WS-WR-AMOUNT FROM WS-AR-BALANCE
           EXEC CICS
               REWRITE DATASET('ACCTMAST')
               FROM(WS-ACCT-REC)
               RESP(WS-RESP)
           END-EXEC.
       4000-SEND.
           EXEC CICS
               SEND MAP('WIREMAP')
               MAPSET('WIRESET')
               FROM(WS-MAP-IO)
               ERASE
           END-EXEC.
