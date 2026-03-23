       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-EXEC-CICS-WIRE.
      *================================================================*
      * MANUAL REVIEW: CICS Wire Transfer Initiation                    *
      * Uses EXEC CICS for online wire transfer processing with        *
      * BMS maps, temporary storage queues, and transient data —       *
      * triggers MANUAL REVIEW detection.                               *
      *================================================================*
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-WIRE-DATA.
           05  WD-ORIG-ACCT        PIC X(12).
           05  WD-ORIG-NAME        PIC X(30).
           05  WD-BENE-NAME        PIC X(30).
           05  WD-BENE-ACCT        PIC X(20).
           05  WD-BENE-BANK        PIC X(11).
           05  WD-BENE-BANK-NAME   PIC X(30).
           05  WD-AMOUNT            PIC S9(11)V99 COMP-3.
           05  WD-CURRENCY          PIC X(03).
           05  WD-PURPOSE           PIC X(40).
           05  WD-WIRE-TYPE         PIC X(01).
           05  WD-PRIORITY          PIC X(01).
       01  WS-ACCT-BAL             PIC S9(11)V99 COMP-3.
       01  WS-AVAIL-BAL            PIC S9(11)V99 COMP-3.
       01  WS-FEE-AMT              PIC S9(05)V99 COMP-3.
       01  WS-TOTAL-DEBIT          PIC S9(11)V99 COMP-3.
       01  WS-WIRE-REF             PIC X(16).
       01  WS-RESP-CODE            PIC S9(08) COMP.
       01  WS-QUEUE-NAME           PIC X(08).
       01  WS-QUEUE-LEN            PIC S9(04) COMP.
       01  WS-OFAC-RESULT          PIC X(01).
       01  WS-APPROVAL-STATUS      PIC X(02).
       01  WS-MAP-OUTPUT.
           05  MO-WIRE-REF         PIC X(16).
           05  MO-STATUS-MSG       PIC X(60).
           05  MO-AMOUNT-DISP      PIC $$$$,$$$,$$9.99.
           05  MO-FEE-DISP         PIC $$$,$$9.99.
           05  MO-TOTAL-DISP       PIC $$$$,$$$,$$9.99.
       01  WS-TIMESTAMP            PIC X(26).
       01  WS-WIRE-LOG-REC.
           05  WL-WIRE-REF         PIC X(16).
           05  WL-TIMESTAMP        PIC X(26).
           05  WL-AMOUNT            PIC S9(11)V99 COMP-3.
           05  WL-STATUS            PIC X(02).
           05  WL-OPERATOR          PIC X(08).
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           EXEC CICS HANDLE CONDITION
               ERROR(8000-ERROR-HANDLER)
           END-EXEC
           PERFORM 1000-RECEIVE-INPUT
           PERFORM 2000-VALIDATE-WIRE
           PERFORM 3000-OFAC-CHECK
           IF WS-OFAC-RESULT = 'C'
               PERFORM 4000-CALC-FEES
               PERFORM 5000-CHECK-BALANCE
               IF WS-APPROVAL-STATUS = 'OK'
                   PERFORM 6000-PROCESS-WIRE
                   PERFORM 7000-LOG-WIRE
               END-IF
           ELSE
               MOVE 'OFAC HOLD - REVIEW REQUIRED'
                   TO MO-STATUS-MSG
               MOVE 'HD' TO WS-APPROVAL-STATUS
           END-IF
           PERFORM 7500-SEND-RESPONSE
           EXEC CICS RETURN END-EXEC
           STOP RUN.
       1000-RECEIVE-INPUT.
           EXEC CICS RECEIVE MAP('WIREMAP')
               MAPSET('WIRESET')
               INTO(WS-WIRE-DATA)
           END-EXEC
           EXEC CICS ASKTIME
               ABSTIME(WS-TIMESTAMP)
           END-EXEC.
       2000-VALIDATE-WIRE.
           MOVE 'OK' TO WS-APPROVAL-STATUS
           IF WD-AMOUNT <= 0
               MOVE 'INVALID AMOUNT' TO MO-STATUS-MSG
               MOVE 'ER' TO WS-APPROVAL-STATUS
           END-IF
           IF WD-BENE-BANK = SPACES
               MOVE 'MISSING BENE BANK' TO MO-STATUS-MSG
               MOVE 'ER' TO WS-APPROVAL-STATUS
           END-IF
           IF WD-BENE-ACCT = SPACES
               MOVE 'MISSING BENE ACCT' TO MO-STATUS-MSG
               MOVE 'ER' TO WS-APPROVAL-STATUS
           END-IF.
       3000-OFAC-CHECK.
           MOVE 'WOFAC   ' TO WS-QUEUE-NAME
           EXEC CICS WRITEQ TS
               QUEUE(WS-QUEUE-NAME)
               FROM(WD-BENE-NAME)
               LENGTH(30)
           END-EXEC
           MOVE 'C' TO WS-OFAC-RESULT.
       4000-CALC-FEES.
           EVALUATE WD-WIRE-TYPE
               WHEN 'D'
                   MOVE 25.00 TO WS-FEE-AMT
               WHEN 'I'
                   MOVE 45.00 TO WS-FEE-AMT
                   IF WD-PRIORITY = 'U'
                       ADD 20.00 TO WS-FEE-AMT
                   END-IF
               WHEN OTHER
                   MOVE 30.00 TO WS-FEE-AMT
           END-EVALUATE
           IF WD-AMOUNT > 100000
               ADD 10.00 TO WS-FEE-AMT
           END-IF
           COMPUTE WS-TOTAL-DEBIT =
               WD-AMOUNT + WS-FEE-AMT
           MOVE WD-AMOUNT TO MO-AMOUNT-DISP
           MOVE WS-FEE-AMT TO MO-FEE-DISP
           MOVE WS-TOTAL-DEBIT TO MO-TOTAL-DISP.
       5000-CHECK-BALANCE.
           EXEC CICS READ
               DATASET('ACCTBAL')
               INTO(WS-ACCT-BAL)
               RIDFLD(WD-ORIG-ACCT)
               RESP(WS-RESP-CODE)
           END-EXEC
           IF WS-RESP-CODE = 0
               IF WS-ACCT-BAL >= WS-TOTAL-DEBIT
                   MOVE 'OK' TO WS-APPROVAL-STATUS
               ELSE
                   MOVE 'INSUFFICIENT FUNDS' TO
                       MO-STATUS-MSG
                   MOVE 'NF' TO WS-APPROVAL-STATUS
               END-IF
           ELSE
               MOVE 'ACCOUNT NOT FOUND' TO MO-STATUS-MSG
               MOVE 'ER' TO WS-APPROVAL-STATUS
           END-IF.
       6000-PROCESS-WIRE.
           EXEC CICS LINK
               PROGRAM('WIREXMIT')
               COMMAREA(WS-WIRE-DATA)
               LENGTH(200)
               RESP(WS-RESP-CODE)
           END-EXEC
           IF WS-RESP-CODE = 0
               MOVE 'WIRE TRANSMITTED' TO MO-STATUS-MSG
               MOVE 'WIRE-REF-001   ' TO WS-WIRE-REF
               MOVE WS-WIRE-REF TO MO-WIRE-REF
               MOVE 'OK' TO WS-APPROVAL-STATUS
           ELSE
               MOVE 'TRANSMISSION ERROR' TO MO-STATUS-MSG
               MOVE 'ER' TO WS-APPROVAL-STATUS
           END-IF.
       7000-LOG-WIRE.
           MOVE WS-WIRE-REF TO WL-WIRE-REF
           MOVE WS-TIMESTAMP TO WL-TIMESTAMP
           MOVE WD-AMOUNT TO WL-AMOUNT
           MOVE WS-APPROVAL-STATUS TO WL-STATUS
           MOVE 'TELLER01' TO WL-OPERATOR
           EXEC CICS WRITEQ TD
               QUEUE('WLOG')
               FROM(WS-WIRE-LOG-REC)
               LENGTH(60)
           END-EXEC.
       7500-SEND-RESPONSE.
           EXEC CICS SEND MAP('WIREMAP')
               MAPSET('WIRESET')
               FROM(WS-MAP-OUTPUT)
               ERASE
           END-EXEC.
       8000-ERROR-HANDLER.
           MOVE 'SYSTEM ERROR' TO MO-STATUS-MSG
           PERFORM 7500-SEND-RESPONSE.
