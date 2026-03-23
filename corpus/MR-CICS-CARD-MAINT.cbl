       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-CICS-CARD-MAINT.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CARD-REC.
           05 WS-CR-PAN          PIC X(16).
           05 WS-CR-STATUS       PIC X(1).
           05 WS-CR-LIMIT        PIC S9(7)V99 COMP-3.
           05 WS-CR-BALANCE      PIC S9(7)V99 COMP-3.
           05 WS-CR-EXPIRY       PIC X(4).
           05 WS-CR-CUST-ID      PIC X(10).
       01 WS-MAINT-ACTION        PIC X(2).
           88 MA-ACTIVATE        VALUE 'AC'.
           88 MA-BLOCK           VALUE 'BL'.
           88 MA-CHG-LIMIT       VALUE 'CL'.
           88 MA-CLOSE           VALUE 'CS'.
       01 WS-NEW-LIMIT           PIC S9(7)V99 COMP-3.
       01 WS-MAP-IO.
           05 WS-MI-PAN          PIC X(16).
           05 WS-MI-ACTION       PIC X(2).
           05 WS-MI-LIMIT        PIC Z(5)9.99.
           05 WS-MI-STATUS       PIC X(10).
           05 WS-MI-MSG          PIC X(40).
       01 WS-RESP                PIC S9(8) COMP.
       01 WS-RESULT              PIC X(12).
       PROCEDURE DIVISION.
       0000-MAIN.
           EXEC CICS
               RECEIVE MAP('CMNTMAP')
               MAPSET('CMNTSET')
               INTO(WS-MAP-IO)
               RESP(WS-RESP)
           END-EXEC
           MOVE WS-MI-PAN TO WS-CR-PAN
           MOVE WS-MI-ACTION TO WS-MAINT-ACTION
           PERFORM 1000-READ-CARD
           IF WS-RESULT = 'FOUND       '
               PERFORM 2000-APPLY-MAINT
               PERFORM 3000-UPDATE-CARD
           END-IF
           PERFORM 4000-SEND-RESPONSE
           EXEC CICS
               RETURN TRANSID('CMNT')
               COMMAREA(WS-CR-PAN)
           END-EXEC.
       1000-READ-CARD.
           EXEC CICS
               READ DATASET('CARDFILE')
               INTO(WS-CARD-REC)
               RIDFLD(WS-CR-PAN)
               UPDATE
               RESP(WS-RESP)
           END-EXEC
           IF WS-RESP = 0
               MOVE 'FOUND       ' TO WS-RESULT
           ELSE
               MOVE 'NOT FOUND   ' TO WS-RESULT
               MOVE 'CARD NOT FOUND' TO WS-MI-MSG
           END-IF.
       2000-APPLY-MAINT.
           EVALUATE TRUE
               WHEN MA-ACTIVATE
                   MOVE 'A' TO WS-CR-STATUS
                   MOVE 'ACTIVATED' TO WS-MI-MSG
               WHEN MA-BLOCK
                   MOVE 'B' TO WS-CR-STATUS
                   MOVE 'BLOCKED' TO WS-MI-MSG
               WHEN MA-CHG-LIMIT
                   MOVE WS-NEW-LIMIT TO WS-CR-LIMIT
                   MOVE 'LIMIT CHANGED' TO WS-MI-MSG
               WHEN MA-CLOSE
                   IF WS-CR-BALANCE > 0
                       MOVE 'BALANCE OUTSTANDING'
                           TO WS-MI-MSG
                       MOVE 'BAL-OWED    ' TO WS-RESULT
                   ELSE
                       MOVE 'C' TO WS-CR-STATUS
                       MOVE 'CARD CLOSED' TO WS-MI-MSG
                   END-IF
               WHEN OTHER
                   MOVE 'INVALID ACTION' TO WS-MI-MSG
                   MOVE 'ERROR       ' TO WS-RESULT
           END-EVALUATE.
       3000-UPDATE-CARD.
           IF WS-RESULT = 'FOUND       '
               EXEC CICS
                   REWRITE DATASET('CARDFILE')
                   FROM(WS-CARD-REC)
                   RESP(WS-RESP)
               END-EXEC
               IF WS-RESP NOT = 0
                   MOVE 'UPDATE FAILED' TO WS-MI-MSG
               END-IF
           END-IF.
       4000-SEND-RESPONSE.
           EXEC CICS
               SEND MAP('CMNTMAP')
               MAPSET('CMNTSET')
               FROM(WS-MAP-IO)
               ERASE
           END-EXEC.
