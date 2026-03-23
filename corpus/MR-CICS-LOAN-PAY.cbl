       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-CICS-LOAN-PAY.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-LOAN-REC.
           05 WS-LN-ACCT          PIC X(12).
           05 WS-LN-BALANCE       PIC S9(9)V99 COMP-3.
           05 WS-LN-RATE          PIC S9(2)V9(4) COMP-3.
           05 WS-LN-MIN-PMT       PIC S9(7)V99 COMP-3.
           05 WS-LN-STATUS        PIC X(2).
       01 WS-PMT-INPUT.
           05 WS-PI-ACCT          PIC X(12).
           05 WS-PI-AMOUNT        PIC S9(7)V99 COMP-3.
           05 WS-PI-SOURCE        PIC X(2).
       01 WS-MAP-DATA.
           05 WS-MD-ACCT          PIC X(12).
           05 WS-MD-PMT           PIC Z(5)9.99-.
           05 WS-MD-BAL           PIC Z(7)9.99-.
           05 WS-MD-MSG           PIC X(40).
       01 WS-RESP                 PIC S9(8) COMP.
       01 WS-RESULT               PIC X(12).
       01 WS-INTEREST-DUE         PIC S9(7)V99 COMP-3.
       01 WS-PRINCIPAL-APPLIED    PIC S9(7)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-RECEIVE
           PERFORM 2000-READ-LOAN
           IF WS-RESULT = 'FOUND       '
               PERFORM 3000-APPLY-PAYMENT
               PERFORM 4000-UPDATE-LOAN
           END-IF
           PERFORM 5000-SEND
           EXEC CICS
               RETURN TRANSID('LPAY')
               COMMAREA(WS-PMT-INPUT)
           END-EXEC.
       1000-RECEIVE.
           EXEC CICS
               RECEIVE MAP('LPAYMAP')
               MAPSET('LPAYSET')
               INTO(WS-MAP-DATA)
               RESP(WS-RESP)
           END-EXEC
           MOVE WS-MD-ACCT TO WS-PI-ACCT.
       2000-READ-LOAN.
           EXEC CICS
               READ DATASET('LOANFILE')
               INTO(WS-LOAN-REC)
               RIDFLD(WS-PI-ACCT)
               UPDATE
               RESP(WS-RESP)
           END-EXEC
           IF WS-RESP = 0
               MOVE 'FOUND       ' TO WS-RESULT
           ELSE
               MOVE 'NOT FOUND   ' TO WS-RESULT
               MOVE 'LOAN NOT FOUND' TO WS-MD-MSG
           END-IF.
       3000-APPLY-PAYMENT.
           IF WS-PI-AMOUNT < WS-LN-MIN-PMT
               MOVE 'BELOW MINIMUM PMT' TO WS-MD-MSG
               MOVE 'PMT TOO LOW ' TO WS-RESULT
           ELSE
               COMPUTE WS-INTEREST-DUE =
                   WS-LN-BALANCE * WS-LN-RATE / 12
               COMPUTE WS-PRINCIPAL-APPLIED =
                   WS-PI-AMOUNT - WS-INTEREST-DUE
               IF WS-PRINCIPAL-APPLIED > WS-LN-BALANCE
                   MOVE WS-LN-BALANCE TO WS-PRINCIPAL-APPLIED
               END-IF
               SUBTRACT WS-PRINCIPAL-APPLIED FROM
                   WS-LN-BALANCE
               MOVE 'PMT APPLIED ' TO WS-RESULT
               MOVE 'PAYMENT PROCESSED' TO WS-MD-MSG
           END-IF.
       4000-UPDATE-LOAN.
           IF WS-RESULT = 'PMT APPLIED '
               EXEC CICS
                   REWRITE DATASET('LOANFILE')
                   FROM(WS-LOAN-REC)
                   RESP(WS-RESP)
               END-EXEC
               IF WS-RESP NOT = 0
                   MOVE 'UPDATE FAILED' TO WS-MD-MSG
               END-IF
           END-IF.
       5000-SEND.
           MOVE WS-LN-BALANCE TO WS-MD-BAL
           EXEC CICS
               SEND MAP('LPAYMAP')
               MAPSET('LPAYSET')
               FROM(WS-MAP-DATA)
               ERASE
           END-EXEC.
