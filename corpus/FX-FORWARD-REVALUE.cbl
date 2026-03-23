       IDENTIFICATION DIVISION.
       PROGRAM-ID. FX-FORWARD-REVALUE.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01 WS-CONTRACT-DATA.
           05 WS-CONTRACT-ID          PIC X(16).
           05 WS-BUY-CCY              PIC X(3).
           05 WS-SELL-CCY             PIC X(3).
           05 WS-NOTIONAL             PIC S9(13)V99 COMP-3.
           05 WS-CONTRACT-RATE        PIC S9(5)V9(6) COMP-3.
           05 WS-MATURITY-DATE        PIC 9(8).
           05 WS-TRADE-DATE           PIC 9(8).

       01 WS-MARKET-DATA.
           05 WS-SPOT-RATE            PIC S9(5)V9(6) COMP-3.
           05 WS-FWD-POINTS           PIC S9(5)V9(6) COMP-3.
           05 WS-MARKET-FWD-RATE      PIC S9(5)V9(6) COMP-3.
           05 WS-DISC-FACTOR          PIC S9(1)V9(8) COMP-3.

       01 WS-REVALUE-RESULTS.
           05 WS-ORIGINAL-VALUE       PIC S9(13)V99 COMP-3.
           05 WS-CURRENT-VALUE        PIC S9(13)V99 COMP-3.
           05 WS-MTM-PNL              PIC S9(13)V99 COMP-3.
           05 WS-PNL-STATUS           PIC X(1).
               88 WS-PNL-GAIN         VALUE 'G'.
               88 WS-PNL-LOSS         VALUE 'L'.
               88 WS-PNL-FLAT         VALUE 'F'.

       01 WS-DAYS-TO-MATURITY         PIC S9(5) COMP-3.
       01 WS-INTEREST-RATE            PIC S9(3)V9(6) COMP-3
           VALUE 0.050000.
       01 WS-RATE-DIFF                PIC S9(5)V9(6) COMP-3.

       01 WS-PORTFOLIO-TABLE.
           05 WS-PORT OCCURS 10.
               10 WS-PT-CCY-PAIR      PIC X(7).
               10 WS-PT-MTM           PIC S9(13)V99 COMP-3.
               10 WS-PT-COUNT         PIC S9(5) COMP-3.
       01 WS-PORT-USED                PIC 9(2) VALUE 0.
       01 WS-PORT-IDX                 PIC 9(2).
       01 WS-PORT-FOUND               PIC X VALUE 'N'.
           88 WS-FOUND-PORT           VALUE 'Y'.
       01 WS-CCY-PAIR                 PIC X(7).

       01 WS-COUNTERS.
           05 WS-CONTRACTS-PROC       PIC S9(5) COMP-3 VALUE 0.
           05 WS-TOTAL-GAINS          PIC S9(15)V99 COMP-3
               VALUE 0.
           05 WS-TOTAL-LOSSES         PIC S9(15)V99 COMP-3
               VALUE 0.

       01 WS-DISPLAY-BUF              PIC X(60).
       01 WS-DISPLAY-PTR              PIC 9(3).

       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-FORWARD-RATE
           PERFORM 3000-REVALUE-CONTRACT
           PERFORM 4000-UPDATE-PORTFOLIO
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.

       1000-INITIALIZE.
           MOVE 0 TO WS-PORT-USED
           MOVE 0 TO WS-CONTRACTS-PROC
           MOVE 0 TO WS-TOTAL-GAINS
           MOVE 0 TO WS-TOTAL-LOSSES
           INITIALIZE WS-REVALUE-RESULTS.

       2000-CALC-FORWARD-RATE.
           COMPUTE WS-MARKET-FWD-RATE =
               WS-SPOT-RATE + WS-FWD-POINTS
           COMPUTE WS-DISC-FACTOR =
               1 / (1 + (WS-INTEREST-RATE *
               (WS-DAYS-TO-MATURITY / 360)))
           IF WS-DISC-FACTOR <= 0
               MOVE 1 TO WS-DISC-FACTOR
           END-IF.

       3000-REVALUE-CONTRACT.
           ADD 1 TO WS-CONTRACTS-PROC
           COMPUTE WS-ORIGINAL-VALUE =
               WS-NOTIONAL * WS-CONTRACT-RATE
           COMPUTE WS-CURRENT-VALUE =
               WS-NOTIONAL * WS-MARKET-FWD-RATE
           COMPUTE WS-RATE-DIFF =
               WS-MARKET-FWD-RATE - WS-CONTRACT-RATE
           COMPUTE WS-MTM-PNL =
               (WS-CURRENT-VALUE - WS-ORIGINAL-VALUE)
               * WS-DISC-FACTOR
           EVALUATE TRUE
               WHEN WS-MTM-PNL > 0
                   MOVE 'G' TO WS-PNL-STATUS
                   ADD WS-MTM-PNL TO WS-TOTAL-GAINS
               WHEN WS-MTM-PNL < 0
                   MOVE 'L' TO WS-PNL-STATUS
                   ADD WS-MTM-PNL TO WS-TOTAL-LOSSES
               WHEN OTHER
                   MOVE 'F' TO WS-PNL-STATUS
           END-EVALUATE.

       4000-UPDATE-PORTFOLIO.
           STRING WS-BUY-CCY '/' WS-SELL-CCY
               DELIMITED BY SIZE
               INTO WS-CCY-PAIR
           END-STRING
           MOVE 'N' TO WS-PORT-FOUND
           PERFORM VARYING WS-PORT-IDX FROM 1 BY 1
               UNTIL WS-PORT-IDX > WS-PORT-USED
               OR WS-FOUND-PORT
               IF WS-PT-CCY-PAIR(WS-PORT-IDX) =
                   WS-CCY-PAIR
                   MOVE 'Y' TO WS-PORT-FOUND
                   ADD WS-MTM-PNL TO
                       WS-PT-MTM(WS-PORT-IDX)
                   ADD 1 TO WS-PT-COUNT(WS-PORT-IDX)
               END-IF
           END-PERFORM
           IF NOT WS-FOUND-PORT
               IF WS-PORT-USED < 10
                   ADD 1 TO WS-PORT-USED
                   MOVE WS-CCY-PAIR TO
                       WS-PT-CCY-PAIR(WS-PORT-USED)
                   MOVE WS-MTM-PNL TO
                       WS-PT-MTM(WS-PORT-USED)
                   MOVE 1 TO WS-PT-COUNT(WS-PORT-USED)
               END-IF
           END-IF.

       5000-DISPLAY-RESULTS.
           MOVE SPACES TO WS-DISPLAY-BUF
           MOVE 1 TO WS-DISPLAY-PTR
           STRING 'CONTRACT ' WS-CONTRACT-ID ' MTM: '
               DELIMITED BY SIZE
               INTO WS-DISPLAY-BUF
               WITH POINTER WS-DISPLAY-PTR
           END-STRING
           DISPLAY WS-DISPLAY-BUF
           DISPLAY 'CONTRACT RATE:    ' WS-CONTRACT-RATE
           DISPLAY 'MARKET FWD RATE:  ' WS-MARKET-FWD-RATE
           DISPLAY 'ORIGINAL VALUE:   ' WS-ORIGINAL-VALUE
           DISPLAY 'CURRENT VALUE:    ' WS-CURRENT-VALUE
           DISPLAY 'MTM P&L:          ' WS-MTM-PNL
           DISPLAY 'STATUS:           ' WS-PNL-STATUS
           DISPLAY 'TOTAL GAINS:      ' WS-TOTAL-GAINS
           DISPLAY 'TOTAL LOSSES:     ' WS-TOTAL-LOSSES
           DISPLAY 'CONTRACTS VALUED: ' WS-CONTRACTS-PROC.
