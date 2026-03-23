       IDENTIFICATION DIVISION.
       PROGRAM-ID. CORR-SWIFT-ROUTER.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01 WS-MESSAGE-DATA.
           05 WS-MSG-REF              PIC X(16).
           05 WS-MSG-TYPE             PIC X(3).
               88 WS-MT103            VALUE '103'.
               88 WS-MT202            VALUE '202'.
               88 WS-MT199            VALUE '199'.
               88 WS-MT299            VALUE '299'.
           05 WS-ORIG-BIC             PIC X(11).
           05 WS-DEST-BIC             PIC X(11).
           05 WS-AMOUNT               PIC S9(13)V99 COMP-3.
           05 WS-CURRENCY             PIC X(3).
           05 WS-VALUE-DATE           PIC 9(8).
           05 WS-PRIORITY             PIC X(1).
               88 WS-PRIORITY-URGENT  VALUE 'U'.
               88 WS-PRIORITY-NORMAL  VALUE 'N'.
               88 WS-PRIORITY-SYSTEM  VALUE 'S'.

       01 WS-ROUTING-TABLE.
           05 WS-ROUTE OCCURS 10.
               10 WS-RT-BIC-PREFIX    PIC X(4).
               10 WS-RT-CHANNEL       PIC X(2).
                   88 WS-CH-SWIFT     VALUE 'SW'.
                   88 WS-CH-FEDWIRE   VALUE 'FW'.
                   88 WS-CH-CHIPS     VALUE 'CH'.
                   88 WS-CH-TARGET2   VALUE 'T2'.
               10 WS-RT-MAX-AMT       PIC S9(13)V99 COMP-3.
               10 WS-RT-CUTOFF-TIME   PIC 9(4).
       01 WS-ROUTE-COUNT              PIC 9(2) VALUE 0.
       01 WS-ROUTE-IDX                PIC 9(2).

       01 WS-ROUTING-RESULT.
           05 WS-SELECTED-CHANNEL     PIC X(2).
           05 WS-ROUTE-FOUND          PIC X VALUE 'N'.
               88 WS-HAS-ROUTE        VALUE 'Y'.
           05 WS-OVERRIDE-REASON      PIC X(40).
           05 WS-COMPLIANCE-HOLD      PIC X VALUE 'N'.
               88 WS-ON-HOLD          VALUE 'Y'.

       01 WS-BIC-PREFIX               PIC X(4).
       01 WS-CURRENT-TIME             PIC 9(4).

       01 WS-AMT-THRESHOLD            PIC S9(13)V99 COMP-3
           VALUE 1000000.00.
       01 WS-COMPLIANCE-THRESHOLD     PIC S9(13)V99 COMP-3
           VALUE 250000.00.

       01 WS-COUNTERS.
           05 WS-MESSAGES-ROUTED      PIC S9(7) COMP-3 VALUE 0.
           05 WS-SWIFT-COUNT          PIC S9(7) COMP-3 VALUE 0.
           05 WS-FEDWIRE-COUNT        PIC S9(7) COMP-3 VALUE 0.
           05 WS-HOLD-COUNT           PIC S9(7) COMP-3 VALUE 0.
           05 WS-FALLBACK-COUNT       PIC S9(7) COMP-3 VALUE 0.

       01 WS-RESULT-BUF               PIC X(60).
       01 WS-RESULT-PTR               PIC 9(3).
       01 WS-BIC-ALPHA-TALLY          PIC 9(3).

       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INIT-ROUTES
           PERFORM 2000-ROUTE-MESSAGE
           PERFORM 3000-COMPLIANCE-CHECK
           PERFORM 4000-DISPLAY-RESULTS
           STOP RUN.

       1000-INIT-ROUTES.
           MOVE 4 TO WS-ROUTE-COUNT
           MOVE 'CHAS' TO WS-RT-BIC-PREFIX(1)
           MOVE 'FW' TO WS-RT-CHANNEL(1)
           MOVE 999999999.99 TO WS-RT-MAX-AMT(1)
           MOVE 1700 TO WS-RT-CUTOFF-TIME(1)
           MOVE 'DEUT' TO WS-RT-BIC-PREFIX(2)
           MOVE 'T2' TO WS-RT-CHANNEL(2)
           MOVE 999999999.99 TO WS-RT-MAX-AMT(2)
           MOVE 1500 TO WS-RT-CUTOFF-TIME(2)
           MOVE 'HSBC' TO WS-RT-BIC-PREFIX(3)
           MOVE 'CH' TO WS-RT-CHANNEL(3)
           MOVE 500000000.00 TO WS-RT-MAX-AMT(3)
           MOVE 1600 TO WS-RT-CUTOFF-TIME(3)
           MOVE 'BNPA' TO WS-RT-BIC-PREFIX(4)
           MOVE 'T2' TO WS-RT-CHANNEL(4)
           MOVE 999999999.99 TO WS-RT-MAX-AMT(4)
           MOVE 1500 TO WS-RT-CUTOFF-TIME(4)
           MOVE 'N' TO WS-ROUTE-FOUND
           MOVE 'N' TO WS-COMPLIANCE-HOLD
           ACCEPT WS-CURRENT-TIME FROM TIME.

       2000-ROUTE-MESSAGE.
           ADD 1 TO WS-MESSAGES-ROUTED
           MOVE WS-DEST-BIC(1:4) TO WS-BIC-PREFIX
           MOVE 'N' TO WS-ROUTE-FOUND
           PERFORM VARYING WS-ROUTE-IDX FROM 1 BY 1
               UNTIL WS-ROUTE-IDX > WS-ROUTE-COUNT
               OR WS-HAS-ROUTE
               IF WS-RT-BIC-PREFIX(WS-ROUTE-IDX) =
                   WS-BIC-PREFIX
                   IF WS-AMOUNT <=
                       WS-RT-MAX-AMT(WS-ROUTE-IDX)
                       MOVE WS-RT-CHANNEL(WS-ROUTE-IDX)
                           TO WS-SELECTED-CHANNEL
                       MOVE 'Y' TO WS-ROUTE-FOUND
                   END-IF
               END-IF
           END-PERFORM
           IF NOT WS-HAS-ROUTE
               MOVE 'SW' TO WS-SELECTED-CHANNEL
               MOVE 'Y' TO WS-ROUTE-FOUND
               ADD 1 TO WS-FALLBACK-COUNT
               MOVE SPACES TO WS-OVERRIDE-REASON
               STRING 'FALLBACK TO SWIFT FOR BIC '
                   WS-BIC-PREFIX
                   DELIMITED BY SIZE
                   INTO WS-OVERRIDE-REASON
               END-STRING
           END-IF
           EVALUATE WS-SELECTED-CHANNEL
               WHEN 'SW'
                   ADD 1 TO WS-SWIFT-COUNT
               WHEN 'FW'
                   ADD 1 TO WS-FEDWIRE-COUNT
               WHEN OTHER
                   CONTINUE
           END-EVALUATE
           IF WS-PRIORITY-URGENT
               AND WS-SELECTED-CHANNEL NOT = 'FW'
               IF WS-CURRENCY = 'USD'
                   MOVE 'FW' TO WS-SELECTED-CHANNEL
                   ADD 1 TO WS-FEDWIRE-COUNT
                   MOVE 'URGENT USD OVERRIDE TO FEDWIRE'
                       TO WS-OVERRIDE-REASON
               END-IF
           END-IF.

       3000-COMPLIANCE-CHECK.
           IF WS-AMOUNT > WS-COMPLIANCE-THRESHOLD
               MOVE 0 TO WS-BIC-ALPHA-TALLY
               INSPECT WS-DEST-BIC
                   TALLYING WS-BIC-ALPHA-TALLY
                   FOR ALL 'X' ALL 'Z'
               IF WS-BIC-ALPHA-TALLY > 3
                   MOVE 'Y' TO WS-COMPLIANCE-HOLD
                   ADD 1 TO WS-HOLD-COUNT
               END-IF
           END-IF
           IF WS-AMOUNT > WS-AMT-THRESHOLD
               EVALUATE TRUE
                   WHEN WS-MT103
                       IF WS-PRIORITY-URGENT
                           DISPLAY 'HIGH VALUE URGENT MT103'
                       END-IF
                   WHEN WS-MT202
                       DISPLAY 'COVER PAYMENT OVER THRESHOLD'
                   WHEN OTHER
                       CONTINUE
               END-EVALUATE
           END-IF.

       4000-DISPLAY-RESULTS.
           MOVE SPACES TO WS-RESULT-BUF
           MOVE 1 TO WS-RESULT-PTR
           STRING 'ROUTED VIA ' WS-SELECTED-CHANNEL
               ' REF=' WS-MSG-REF
               DELIMITED BY SIZE
               INTO WS-RESULT-BUF
               WITH POINTER WS-RESULT-PTR
           END-STRING
           DISPLAY 'SWIFT MESSAGE ROUTING RESULT'
           DISPLAY WS-RESULT-BUF
           DISPLAY 'MSG TYPE:       ' WS-MSG-TYPE
           DISPLAY 'AMOUNT:         ' WS-AMOUNT
           DISPLAY 'CHANNEL:        ' WS-SELECTED-CHANNEL
           DISPLAY 'COMPLIANCE HOLD:' WS-COMPLIANCE-HOLD
           IF WS-OVERRIDE-REASON NOT = SPACES
               DISPLAY 'OVERRIDE:       ' WS-OVERRIDE-REASON
           END-IF
           DISPLAY 'MSGS ROUTED:    ' WS-MESSAGES-ROUTED
           DISPLAY 'SWIFT:          ' WS-SWIFT-COUNT
           DISPLAY 'FEDWIRE:        ' WS-FEDWIRE-COUNT
           DISPLAY 'HOLDS:          ' WS-HOLD-COUNT
           DISPLAY 'FALLBACKS:      ' WS-FALLBACK-COUNT.
