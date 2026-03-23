       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-CICS-FX-DEAL-ENTRY.
      *---------------------------------------------------------------
      * MANUAL REVIEW: Contains EXEC CICS commands for FX deal
      * entry screens used by treasury front-office traders.
      *---------------------------------------------------------------

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01 WS-DEAL-DATA.
           05 WS-DEAL-ID              PIC X(16).
           05 WS-TRADER-ID            PIC X(8).
           05 WS-DEAL-TYPE            PIC X(2).
               88 WS-SPOT             VALUE 'SP'.
               88 WS-FORWARD          VALUE 'FW'.
               88 WS-SWAP             VALUE 'SW'.
               88 WS-NDF              VALUE 'ND'.
           05 WS-BUY-CCY              PIC X(3).
           05 WS-BUY-AMT              PIC S9(13)V99 COMP-3.
           05 WS-SELL-CCY             PIC X(3).
           05 WS-SELL-AMT             PIC S9(13)V99 COMP-3.
           05 WS-DEAL-RATE            PIC S9(5)V9(6) COMP-3.
           05 WS-VALUE-DATE           PIC 9(8).
           05 WS-CPTY-BIC             PIC X(11).
           05 WS-STATUS               PIC X(2).
               88 WS-PENDING          VALUE 'PD'.
               88 WS-CONFIRMED        VALUE 'CF'.
               88 WS-REJECTED         VALUE 'RJ'.

       01 WS-SCREEN-INPUT.
           05 WS-SCR-ACTION           PIC X(2).
               88 WS-SCR-NEW          VALUE 'NW'.
               88 WS-SCR-AMEND        VALUE 'AM'.
               88 WS-SCR-CANCEL       VALUE 'CX'.
               88 WS-SCR-INQUIRE      VALUE 'IQ'.
           05 WS-SCR-DEAL-ID          PIC X(16).

       01 WS-RESP-CODE                PIC S9(8) COMP.
       01 WS-ERROR-FLAG               PIC X VALUE 'N'.
           88 WS-HAS-ERROR            VALUE 'Y'.
       01 WS-MESSAGE                  PIC X(60).
       01 WS-MSG-PTR                  PIC 9(3).

       01 WS-LIMIT-DATA.
           05 WS-TRADER-LIMIT         PIC S9(13)V99 COMP-3
               VALUE 50000000.00.
           05 WS-CPTY-LIMIT           PIC S9(13)V99 COMP-3
               VALUE 100000000.00.
           05 WS-DAILY-VOLUME         PIC S9(15)V99 COMP-3
               VALUE 0.

       01 WS-TALLY-WORK               PIC 9(3).

       01 WS-COUNTERS.
           05 WS-DEALS-ENTERED        PIC S9(7) COMP-3 VALUE 0.
           05 WS-DEALS-REJECTED       PIC S9(7) COMP-3 VALUE 0.
           05 WS-DEALS-AMENDED        PIC S9(7) COMP-3 VALUE 0.

       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-RECEIVE-INPUT
           IF NOT WS-HAS-ERROR
               PERFORM 2000-PROCESS-ACTION
           END-IF
           PERFORM 3000-SEND-RESPONSE
           STOP RUN.

       1000-RECEIVE-INPUT.
           MOVE 'N' TO WS-ERROR-FLAG
           MOVE SPACES TO WS-MESSAGE
           EXEC CICS RECEIVE
               MAP('FXDLMAP')
               MAPSET('FXDLSET')
               INTO(WS-SCREEN-INPUT)
               RESP(WS-RESP-CODE)
           END-EXEC
           IF WS-RESP-CODE NOT = 0
               MOVE 'Y' TO WS-ERROR-FLAG
               MOVE 'MAP RECEIVE FAILED' TO WS-MESSAGE
           END-IF.

       2000-PROCESS-ACTION.
           EVALUATE TRUE
               WHEN WS-SCR-NEW
                   PERFORM 2100-NEW-DEAL
               WHEN WS-SCR-AMEND
                   PERFORM 2200-AMEND-DEAL
               WHEN WS-SCR-CANCEL
                   PERFORM 2300-CANCEL-DEAL
               WHEN WS-SCR-INQUIRE
                   PERFORM 2400-INQUIRE-DEAL
               WHEN OTHER
                   MOVE 'Y' TO WS-ERROR-FLAG
                   MOVE SPACES TO WS-MESSAGE
                   MOVE 1 TO WS-MSG-PTR
                   STRING 'INVALID ACTION: '
                       WS-SCR-ACTION
                       DELIMITED BY SIZE
                       INTO WS-MESSAGE
                       WITH POINTER WS-MSG-PTR
                   END-STRING
           END-EVALUATE.

       2100-NEW-DEAL.
           PERFORM 2110-VALIDATE-LIMITS
           IF NOT WS-HAS-ERROR
               MOVE 'PD' TO WS-STATUS
               EXEC CICS WRITE
                   FILE('FXDEALS')
                   FROM(WS-DEAL-DATA)
                   RIDFLD(WS-DEAL-ID)
                   RESP(WS-RESP-CODE)
               END-EXEC
               IF WS-RESP-CODE = 0
                   ADD 1 TO WS-DEALS-ENTERED
                   ADD WS-BUY-AMT TO WS-DAILY-VOLUME
                   MOVE SPACES TO WS-MESSAGE
                   MOVE 1 TO WS-MSG-PTR
                   STRING 'DEAL ' WS-DEAL-ID
                       ' ENTERED PENDING CONFIRM'
                       DELIMITED BY SIZE
                       INTO WS-MESSAGE
                       WITH POINTER WS-MSG-PTR
                   END-STRING
               ELSE
                   MOVE 'Y' TO WS-ERROR-FLAG
                   MOVE 'DEAL WRITE FAILED' TO WS-MESSAGE
               END-IF
           END-IF.

       2110-VALIDATE-LIMITS.
           IF WS-BUY-AMT > WS-TRADER-LIMIT
               MOVE 'Y' TO WS-ERROR-FLAG
               ADD 1 TO WS-DEALS-REJECTED
               MOVE 'EXCEEDS TRADER LIMIT' TO WS-MESSAGE
           END-IF
           IF NOT WS-HAS-ERROR
               COMPUTE WS-DAILY-VOLUME =
                   WS-DAILY-VOLUME + WS-BUY-AMT
               IF WS-DAILY-VOLUME > WS-CPTY-LIMIT
                   MOVE 'Y' TO WS-ERROR-FLAG
                   ADD 1 TO WS-DEALS-REJECTED
                   MOVE 'EXCEEDS CPTY LIMIT' TO WS-MESSAGE
                   SUBTRACT WS-BUY-AMT FROM
                       WS-DAILY-VOLUME
               END-IF
           END-IF
           EVALUATE TRUE
               WHEN WS-SPOT
                   CONTINUE
               WHEN WS-FORWARD
                   IF WS-VALUE-DATE < 20260321
                       MOVE 'Y' TO WS-ERROR-FLAG
                       MOVE 'PAST VALUE DATE' TO WS-MESSAGE
                   END-IF
               WHEN WS-SWAP
                   DISPLAY 'SWAP DEAL REQUIRES DUAL LEGS'
               WHEN WS-NDF
                   DISPLAY 'NDF SETTLEMENT IN BUY CCY'
               WHEN OTHER
                   MOVE 'Y' TO WS-ERROR-FLAG
                   MOVE 'UNKNOWN DEAL TYPE' TO WS-MESSAGE
           END-EVALUATE.

       2200-AMEND-DEAL.
           EXEC CICS READ
               FILE('FXDEALS')
               INTO(WS-DEAL-DATA)
               RIDFLD(WS-SCR-DEAL-ID)
               UPDATE
               RESP(WS-RESP-CODE)
           END-EXEC
           IF WS-RESP-CODE = 0
               EXEC CICS REWRITE
                   FILE('FXDEALS')
                   FROM(WS-DEAL-DATA)
                   RESP(WS-RESP-CODE)
               END-EXEC
               ADD 1 TO WS-DEALS-AMENDED
               MOVE 'DEAL AMENDED' TO WS-MESSAGE
           ELSE
               MOVE 'Y' TO WS-ERROR-FLAG
               MOVE 'DEAL NOT FOUND FOR AMEND'
                   TO WS-MESSAGE
           END-IF.

       2300-CANCEL-DEAL.
           EXEC CICS READ
               FILE('FXDEALS')
               INTO(WS-DEAL-DATA)
               RIDFLD(WS-SCR-DEAL-ID)
               UPDATE
               RESP(WS-RESP-CODE)
           END-EXEC
           IF WS-RESP-CODE = 0
               MOVE 'RJ' TO WS-STATUS
               EXEC CICS REWRITE
                   FILE('FXDEALS')
                   FROM(WS-DEAL-DATA)
                   RESP(WS-RESP-CODE)
               END-EXEC
               MOVE 'DEAL CANCELLED' TO WS-MESSAGE
           ELSE
               MOVE 'Y' TO WS-ERROR-FLAG
               MOVE 'DEAL NOT FOUND FOR CANCEL'
                   TO WS-MESSAGE
           END-IF.

       2400-INQUIRE-DEAL.
           EXEC CICS READ
               FILE('FXDEALS')
               INTO(WS-DEAL-DATA)
               RIDFLD(WS-SCR-DEAL-ID)
               RESP(WS-RESP-CODE)
           END-EXEC
           IF WS-RESP-CODE = 0
               MOVE 0 TO WS-TALLY-WORK
               INSPECT WS-CPTY-BIC
                   TALLYING WS-TALLY-WORK FOR ALL ' '
               MOVE SPACES TO WS-MESSAGE
               MOVE 1 TO WS-MSG-PTR
               STRING 'DEAL ' WS-DEAL-ID ' STATUS='
                   WS-STATUS ' RATE=' WS-DEAL-RATE
                   DELIMITED BY SIZE
                   INTO WS-MESSAGE
                   WITH POINTER WS-MSG-PTR
               END-STRING
           ELSE
               MOVE 'Y' TO WS-ERROR-FLAG
               MOVE 'DEAL NOT FOUND' TO WS-MESSAGE
           END-IF.

       3000-SEND-RESPONSE.
           EXEC CICS SEND
               MAP('FXDLMAP')
               MAPSET('FXDLSET')
               FROM(WS-SCREEN-INPUT)
               ERASE
               RESP(WS-RESP-CODE)
           END-EXEC
           DISPLAY 'FX DEAL ENTRY: ' WS-MESSAGE
           DISPLAY 'DEALS ENTERED:  ' WS-DEALS-ENTERED
           DISPLAY 'DEALS REJECTED: ' WS-DEALS-REJECTED
           DISPLAY 'DEALS AMENDED:  ' WS-DEALS-AMENDED
           DISPLAY 'DAILY VOLUME:   ' WS-DAILY-VOLUME.
