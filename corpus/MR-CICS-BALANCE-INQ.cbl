       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-CICS-BALANCE-INQ.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ACCT-KEY            PIC X(12).
       01 WS-MULTI-ACCT.
           05 WS-MA OCCURS 4 TIMES.
               10 WS-MA-NUM      PIC X(12).
               10 WS-MA-TYPE     PIC X(2).
               10 WS-MA-BAL      PIC S9(11)V99 COMP-3.
               10 WS-MA-AVAIL    PIC S9(11)V99 COMP-3.
               10 WS-MA-HOLD     PIC S9(7)V99 COMP-3.
       01 WS-MA-COUNT            PIC 9.
       01 WS-IDX                 PIC 9.
       01 WS-TOTAL-BAL           PIC S9(13)V99 COMP-3.
       01 WS-TOTAL-AVAIL         PIC S9(13)V99 COMP-3.
       01 WS-MAP-SCREEN.
           05 WS-MS-CUST-ID      PIC X(12).
           05 WS-MS-NAME         PIC X(30).
           05 WS-MS-TOTAL        PIC Z(11)9.99-.
           05 WS-MS-MSG          PIC X(40).
       01 WS-RESP                PIC S9(8) COMP.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-RECEIVE
           PERFORM 2000-READ-ACCOUNTS
           PERFORM 3000-CALC-TOTALS
           PERFORM 4000-FORMAT-SCREEN
           PERFORM 5000-SEND
           EXEC CICS
               RETURN TRANSID('BINQ')
               COMMAREA(WS-ACCT-KEY)
           END-EXEC.
       1000-RECEIVE.
           EXEC CICS
               RECEIVE MAP('BINQMAP')
               MAPSET('BINQSET')
               INTO(WS-MAP-SCREEN)
               RESP(WS-RESP)
           END-EXEC
           MOVE WS-MS-CUST-ID TO WS-ACCT-KEY.
       2000-READ-ACCOUNTS.
           MOVE 0 TO WS-MA-COUNT
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > 4
               EXEC CICS
                   READ DATASET('CUSTACCT')
                   INTO(WS-MA(WS-IDX))
                   RIDFLD(WS-ACCT-KEY)
                   RESP(WS-RESP)
               END-EXEC
               IF WS-RESP = 0
                   ADD 1 TO WS-MA-COUNT
                   COMPUTE WS-MA-AVAIL(WS-IDX) =
                       WS-MA-BAL(WS-IDX) -
                       WS-MA-HOLD(WS-IDX)
               END-IF
           END-PERFORM.
       3000-CALC-TOTALS.
           MOVE 0 TO WS-TOTAL-BAL
           MOVE 0 TO WS-TOTAL-AVAIL
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-MA-COUNT
               ADD WS-MA-BAL(WS-IDX) TO WS-TOTAL-BAL
               ADD WS-MA-AVAIL(WS-IDX) TO WS-TOTAL-AVAIL
           END-PERFORM.
       4000-FORMAT-SCREEN.
           MOVE WS-TOTAL-BAL TO WS-MS-TOTAL
           IF WS-MA-COUNT > 0
               MOVE 'BALANCES DISPLAYED' TO WS-MS-MSG
           ELSE
               MOVE 'NO ACCOUNTS FOUND' TO WS-MS-MSG
           END-IF.
       5000-SEND.
           EXEC CICS
               SEND MAP('BINQMAP')
               MAPSET('BINQSET')
               FROM(WS-MAP-SCREEN)
               ERASE
           END-EXEC.
