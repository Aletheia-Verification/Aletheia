       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-GOV-CICS-TAX.
      *================================================================
      * Government Tax Account Inquiry via CICS
      * Online transaction processing for IRS tax account
      * status inquiries using CICS maps. (MANUAL REVIEW - CICS)
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-COMMAREA.
           05 WS-FUNCTION-CODE        PIC X(2).
               88 WS-INQUIRY          VALUE 'IQ'.
               88 WS-UPDATE           VALUE 'UP'.
               88 WS-PAYMENT          VALUE 'PY'.
           05 WS-TIN                  PIC X(9).
           05 WS-TAX-YEAR             PIC 9(4).
           05 WS-RETURN-CODE          PIC X(2).
       01 WS-TAXPAYER-DATA.
           05 WS-TP-NAME              PIC X(30).
           05 WS-TP-ADDRESS           PIC X(40).
           05 WS-TP-FILING-STATUS     PIC X(1).
               88 WS-SINGLE           VALUE 'S'.
               88 WS-MARRIED          VALUE 'M'.
               88 WS-HEAD-HOUSE       VALUE 'H'.
       01 WS-TAX-ACCOUNT.
           05 WS-TAX-ASSESSED         PIC S9(9)V99 COMP-3.
           05 WS-PAYMENTS-MADE        PIC S9(9)V99 COMP-3.
           05 WS-CREDITS-APPLIED      PIC S9(7)V99 COMP-3.
           05 WS-PENALTIES            PIC S9(7)V99 COMP-3.
           05 WS-INTEREST-DUE         PIC S9(7)V99 COMP-3.
           05 WS-BALANCE-DUE          PIC S9(9)V99 COMP-3.
       01 WS-ACCOUNT-STATUS           PIC X(2).
           88 WS-CURRENT              VALUE 'CU'.
           88 WS-DELINQUENT           VALUE 'DQ'.
           88 WS-IN-COLLECTIONS       VALUE 'CL'.
           88 WS-INSTALLMENT          VALUE 'IN'.
       01 WS-MAP-FIELDS.
           05 WS-SCREEN-MSG           PIC X(60).
           05 WS-ERROR-MSG            PIC X(60).
           05 WS-MSG-SEVERITY         PIC X(1).
               88 WS-INFO             VALUE 'I'.
               88 WS-WARNING          VALUE 'W'.
               88 WS-ERROR            VALUE 'E'.
       01 WS-RESPONSE-CODE            PIC S9(8) COMP.
       01 WS-PROCESS-DATE             PIC 9(8).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           EVALUATE TRUE
               WHEN WS-INQUIRY
                   PERFORM 2000-ACCOUNT-INQUIRY
               WHEN WS-UPDATE
                   PERFORM 3000-ACCOUNT-UPDATE
               WHEN WS-PAYMENT
                   PERFORM 4000-PROCESS-PAYMENT
               WHEN OTHER
                   PERFORM 5000-INVALID-FUNCTION
           END-EVALUATE
           PERFORM 6000-SEND-RESPONSE
           EXEC CICS RETURN
               TRANSID('TAXQ')
               COMMAREA(WS-COMMAREA)
           END-EXEC.
       1000-INITIALIZE.
           ACCEPT WS-PROCESS-DATE FROM DATE YYYYMMDD
           MOVE SPACES TO WS-SCREEN-MSG
           MOVE SPACES TO WS-ERROR-MSG
           SET WS-INFO TO TRUE
           MOVE '00' TO WS-RETURN-CODE.
       2000-ACCOUNT-INQUIRY.
           EXEC CICS READ
               DATASET('TAXACCT')
               INTO(WS-TAX-ACCOUNT)
               RIDFLD(WS-TIN)
               RESP(WS-RESPONSE-CODE)
           END-EXEC
           IF WS-RESPONSE-CODE = 0
               COMPUTE WS-BALANCE-DUE =
                   WS-TAX-ASSESSED -
                   WS-PAYMENTS-MADE -
                   WS-CREDITS-APPLIED +
                   WS-PENALTIES +
                   WS-INTEREST-DUE
               IF WS-BALANCE-DUE > 0
                   SET WS-DELINQUENT TO TRUE
               ELSE
                   SET WS-CURRENT TO TRUE
               END-IF
               MOVE "ACCOUNT FOUND" TO WS-SCREEN-MSG
           ELSE
               MOVE "ACCOUNT NOT FOUND" TO WS-ERROR-MSG
               SET WS-ERROR TO TRUE
               MOVE 'NF' TO WS-RETURN-CODE
           END-IF.
       3000-ACCOUNT-UPDATE.
           EXEC CICS READ
               DATASET('TAXACCT')
               INTO(WS-TAX-ACCOUNT)
               RIDFLD(WS-TIN)
               UPDATE
               RESP(WS-RESPONSE-CODE)
           END-EXEC
           IF WS-RESPONSE-CODE = 0
               COMPUTE WS-BALANCE-DUE =
                   WS-TAX-ASSESSED -
                   WS-PAYMENTS-MADE -
                   WS-CREDITS-APPLIED +
                   WS-PENALTIES +
                   WS-INTEREST-DUE
               EXEC CICS REWRITE
                   DATASET('TAXACCT')
                   FROM(WS-TAX-ACCOUNT)
                   RESP(WS-RESPONSE-CODE)
               END-EXEC
               MOVE "ACCOUNT UPDATED" TO WS-SCREEN-MSG
           ELSE
               MOVE "UPDATE FAILED" TO WS-ERROR-MSG
               MOVE 'UF' TO WS-RETURN-CODE
           END-IF.
       4000-PROCESS-PAYMENT.
           EXEC CICS READ
               DATASET('TAXACCT')
               INTO(WS-TAX-ACCOUNT)
               RIDFLD(WS-TIN)
               UPDATE
               RESP(WS-RESPONSE-CODE)
           END-EXEC
           IF WS-RESPONSE-CODE = 0
               ADD WS-BALANCE-DUE
                   TO WS-PAYMENTS-MADE
               COMPUTE WS-BALANCE-DUE =
                   WS-TAX-ASSESSED -
                   WS-PAYMENTS-MADE -
                   WS-CREDITS-APPLIED +
                   WS-PENALTIES +
                   WS-INTEREST-DUE
               IF WS-BALANCE-DUE <= 0
                   SET WS-CURRENT TO TRUE
                   MOVE 0 TO WS-BALANCE-DUE
               END-IF
               EXEC CICS REWRITE
                   DATASET('TAXACCT')
                   FROM(WS-TAX-ACCOUNT)
                   RESP(WS-RESPONSE-CODE)
               END-EXEC
               MOVE "PAYMENT APPLIED" TO WS-SCREEN-MSG
           ELSE
               MOVE "PAYMENT FAILED" TO WS-ERROR-MSG
               MOVE 'PF' TO WS-RETURN-CODE
           END-IF.
       5000-INVALID-FUNCTION.
           MOVE "INVALID FUNCTION CODE" TO WS-ERROR-MSG
           SET WS-ERROR TO TRUE
           MOVE 'IF' TO WS-RETURN-CODE.
       6000-SEND-RESPONSE.
           EXEC CICS SEND
               MAP('TAXMAP')
               MAPSET('TAXSET')
               FROM(WS-MAP-FIELDS)
               RESP(WS-RESPONSE-CODE)
           END-EXEC
           IF WS-RESPONSE-CODE NOT = 0
               DISPLAY "SEND ERROR: " WS-RESPONSE-CODE
           END-IF.
