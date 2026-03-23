       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-CICS-ACCT-INQ.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-COMM-AREA.
           05 WS-ACCT-KEY          PIC X(12).
           05 WS-ACCT-NAME         PIC X(30).
           05 WS-ACCT-BALANCE      PIC S9(9)V99 COMP-3.
           05 WS-ACCT-STATUS       PIC X(2).
           05 WS-LAST-TXN-DATE     PIC X(10).
           05 WS-BRANCH-CODE       PIC X(4).
       01 WS-RESPONSE-CODE         PIC S9(8) COMP.
       01 WS-ERROR-MSG             PIC X(40).
       01 WS-FOUND-FLAG            PIC X VALUE 'N'.
           88 RECORD-FOUND          VALUE 'Y'.
       01 WS-MAP-FIELDS.
           05 WS-MAP-ACCT          PIC X(12).
           05 WS-MAP-NAME          PIC X(30).
           05 WS-MAP-BAL           PIC Z(7)9.99-.
           05 WS-MAP-STATUS        PIC X(8).
           05 WS-MAP-DATE          PIC X(10).
           05 WS-MAP-MSG           PIC X(40).
       PROCEDURE DIVISION.
       0000-MAIN-LOGIC.
           PERFORM 1000-RECEIVE-MAP
           IF WS-ACCT-KEY NOT = SPACES
               PERFORM 2000-READ-ACCOUNT
               IF RECORD-FOUND
                   PERFORM 3000-FORMAT-DISPLAY
               END-IF
               PERFORM 4000-SEND-MAP
           END-IF
           EXEC CICS
               RETURN TRANSID('AINQ')
               COMMAREA(WS-COMM-AREA)
           END-EXEC.
       1000-RECEIVE-MAP.
           EXEC CICS
               RECEIVE MAP('AINQMAP')
               MAPSET('AINQSET')
               INTO(WS-MAP-FIELDS)
               RESP(WS-RESPONSE-CODE)
           END-EXEC
           IF WS-RESPONSE-CODE NOT = 0
               MOVE 'MAP RECEIVE ERROR' TO WS-ERROR-MSG
           ELSE
               MOVE WS-MAP-ACCT TO WS-ACCT-KEY
           END-IF.
       2000-READ-ACCOUNT.
           EXEC CICS
               READ DATASET('ACCTFILE')
               INTO(WS-COMM-AREA)
               RIDFLD(WS-ACCT-KEY)
               RESP(WS-RESPONSE-CODE)
           END-EXEC
           IF WS-RESPONSE-CODE = 0
               MOVE 'Y' TO WS-FOUND-FLAG
           ELSE
               MOVE 'N' TO WS-FOUND-FLAG
               MOVE 'ACCOUNT NOT FOUND' TO WS-ERROR-MSG
           END-IF.
       3000-FORMAT-DISPLAY.
           MOVE WS-ACCT-KEY TO WS-MAP-ACCT
           MOVE WS-ACCT-NAME TO WS-MAP-NAME
           MOVE WS-ACCT-BALANCE TO WS-MAP-BAL
           MOVE WS-LAST-TXN-DATE TO WS-MAP-DATE
           EVALUATE WS-ACCT-STATUS
               WHEN 'AC'
                   MOVE 'ACTIVE  ' TO WS-MAP-STATUS
               WHEN 'CL'
                   MOVE 'CLOSED  ' TO WS-MAP-STATUS
               WHEN 'FR'
                   MOVE 'FROZEN  ' TO WS-MAP-STATUS
               WHEN OTHER
                   MOVE 'UNKNOWN ' TO WS-MAP-STATUS
           END-EVALUATE
           MOVE SPACES TO WS-MAP-MSG.
       4000-SEND-MAP.
           IF RECORD-FOUND
               MOVE 'ACCOUNT DISPLAYED' TO WS-MAP-MSG
           ELSE
               MOVE WS-ERROR-MSG TO WS-MAP-MSG
           END-IF
           EXEC CICS
               SEND MAP('AINQMAP')
               MAPSET('AINQSET')
               FROM(WS-MAP-FIELDS)
               ERASE
           END-EXEC.
