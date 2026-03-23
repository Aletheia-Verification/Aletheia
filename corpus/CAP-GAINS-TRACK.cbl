       IDENTIFICATION DIVISION.
       PROGRAM-ID. CAP-GAINS-TRACK.
      *================================================================
      * CAPITAL GAINS TRACKING ENGINE
      * Matches sell lots against purchase lots using FIFO, calculates
      * short-term vs long-term gains, and wash sale detection.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-TAX-LOT-TABLE.
           05 WS-LOT-ENTRY OCCURS 30 TIMES.
               10 WS-LOT-ID           PIC 9(5).
               10 WS-LOT-BUY-DATE     PIC 9(8).
               10 WS-LOT-SHARES       PIC S9(9)V9(4) COMP-3.
               10 WS-LOT-COST-BASIS   PIC S9(9)V99 COMP-3.
               10 WS-LOT-PER-SHARE    PIC S9(5)V9(4) COMP-3.
               10 WS-LOT-SOLD         PIC X(1).
                   88 LOT-AVAILABLE    VALUE 'N'.
                   88 LOT-USED         VALUE 'Y'.
       01 WS-LOT-COUNT                PIC 9(2) VALUE 0.
       01 WS-SALE.
           05 WS-SALE-DATE            PIC 9(8).
           05 WS-SALE-SHARES          PIC S9(9)V9(4) COMP-3.
           05 WS-SALE-PRICE           PIC S9(5)V9(4) COMP-3.
           05 WS-SALE-PROCEEDS        PIC S9(11)V99 COMP-3.
       01 WS-MATCH-FIELDS.
           05 WS-REMAINING-SHARES     PIC S9(9)V9(4) COMP-3.
           05 WS-MATCHED-SHARES       PIC S9(9)V9(4) COMP-3.
           05 WS-MATCHED-BASIS        PIC S9(9)V99 COMP-3.
           05 WS-MATCHED-PROCEEDS     PIC S9(9)V99 COMP-3.
           05 WS-GAIN-LOSS            PIC S9(9)V99 COMP-3.
           05 WS-HOLD-DAYS            PIC S9(5) COMP-3.
           05 WS-LONG-TERM-FLAG       PIC X VALUE 'N'.
               88 IS-LONG-TERM        VALUE 'Y'.
               88 IS-SHORT-TERM       VALUE 'N'.
       01 WS-WASH-SALE.
           05 WS-WASH-WINDOW          PIC 9(3) VALUE 30.
           05 WS-WASH-FLAG            PIC X VALUE 'N'.
               88 IS-WASH-SALE        VALUE 'Y'.
           05 WS-WASH-AMOUNT          PIC S9(9)V99 COMP-3
               VALUE 0.
       01 WS-TOTALS.
           05 WS-TOT-ST-GAIN          PIC S9(11)V99 COMP-3
               VALUE 0.
           05 WS-TOT-ST-LOSS          PIC S9(11)V99 COMP-3
               VALUE 0.
           05 WS-TOT-LT-GAIN          PIC S9(11)V99 COMP-3
               VALUE 0.
           05 WS-TOT-LT-LOSS          PIC S9(11)V99 COMP-3
               VALUE 0.
           05 WS-TOT-WASH-ADJ         PIC S9(11)V99 COMP-3
               VALUE 0.
           05 WS-NET-GAIN             PIC S9(11)V99 COMP-3.
       01 WS-IDX                      PIC 9(2).
       01 WS-MATCH-COUNT              PIC 9(3) VALUE 0.
       01 WS-LT-THRESHOLD             PIC 9(3) VALUE 365.
       01 WS-RECENT-BUY-DATE          PIC 9(8) VALUE 0.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-LOAD-LOTS
           PERFORM 2000-SETUP-SALE
           PERFORM 3000-MATCH-FIFO
           PERFORM 4000-CHECK-WASH-SALE
           PERFORM 5000-CALC-NET
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-LOAD-LOTS.
           INITIALIZE WS-TAX-LOT-TABLE
           MOVE 1 TO WS-LOT-ID(1)
           MOVE 20240115 TO WS-LOT-BUY-DATE(1)
           MOVE 100.0000 TO WS-LOT-SHARES(1)
           MOVE 5000.00 TO WS-LOT-COST-BASIS(1)
           MOVE 50.0000 TO WS-LOT-PER-SHARE(1)
           MOVE 'N' TO WS-LOT-SOLD(1)
           MOVE 2 TO WS-LOT-ID(2)
           MOVE 20240615 TO WS-LOT-BUY-DATE(2)
           MOVE 150.0000 TO WS-LOT-SHARES(2)
           MOVE 9000.00 TO WS-LOT-COST-BASIS(2)
           MOVE 60.0000 TO WS-LOT-PER-SHARE(2)
           MOVE 'N' TO WS-LOT-SOLD(2)
           MOVE 3 TO WS-LOT-ID(3)
           MOVE 20250301 TO WS-LOT-BUY-DATE(3)
           MOVE 75.0000 TO WS-LOT-SHARES(3)
           MOVE 5250.00 TO WS-LOT-COST-BASIS(3)
           MOVE 70.0000 TO WS-LOT-PER-SHARE(3)
           MOVE 'N' TO WS-LOT-SOLD(3)
           MOVE 3 TO WS-LOT-COUNT.
       2000-SETUP-SALE.
           MOVE 20260320 TO WS-SALE-DATE
           MOVE 200.0000 TO WS-SALE-SHARES
           MOVE 65.0000 TO WS-SALE-PRICE
           COMPUTE WS-SALE-PROCEEDS =
               WS-SALE-SHARES * WS-SALE-PRICE
           MOVE WS-SALE-SHARES TO WS-REMAINING-SHARES.
       3000-MATCH-FIFO.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-LOT-COUNT
               OR WS-REMAINING-SHARES <= 0
               IF LOT-AVAILABLE(WS-IDX)
                   PERFORM 3100-MATCH-LOT
               END-IF
           END-PERFORM.
       3100-MATCH-LOT.
           IF WS-LOT-SHARES(WS-IDX) <= WS-REMAINING-SHARES
               MOVE WS-LOT-SHARES(WS-IDX)
                   TO WS-MATCHED-SHARES
               MOVE 'Y' TO WS-LOT-SOLD(WS-IDX)
           ELSE
               MOVE WS-REMAINING-SHARES
                   TO WS-MATCHED-SHARES
               SUBTRACT WS-MATCHED-SHARES
                   FROM WS-LOT-SHARES(WS-IDX)
           END-IF
           SUBTRACT WS-MATCHED-SHARES
               FROM WS-REMAINING-SHARES
           COMPUTE WS-MATCHED-BASIS =
               WS-MATCHED-SHARES * WS-LOT-PER-SHARE(WS-IDX)
           COMPUTE WS-MATCHED-PROCEEDS =
               WS-MATCHED-SHARES * WS-SALE-PRICE
           COMPUTE WS-GAIN-LOSS =
               WS-MATCHED-PROCEEDS - WS-MATCHED-BASIS
           COMPUTE WS-HOLD-DAYS =
               WS-SALE-DATE - WS-LOT-BUY-DATE(WS-IDX)
           IF WS-HOLD-DAYS > WS-LT-THRESHOLD
               MOVE 'Y' TO WS-LONG-TERM-FLAG
               IF WS-GAIN-LOSS >= 0
                   ADD WS-GAIN-LOSS TO WS-TOT-LT-GAIN
               ELSE
                   ADD WS-GAIN-LOSS TO WS-TOT-LT-LOSS
               END-IF
           ELSE
               MOVE 'N' TO WS-LONG-TERM-FLAG
               IF WS-GAIN-LOSS >= 0
                   ADD WS-GAIN-LOSS TO WS-TOT-ST-GAIN
               ELSE
                   ADD WS-GAIN-LOSS TO WS-TOT-ST-LOSS
               END-IF
           END-IF
           ADD 1 TO WS-MATCH-COUNT
           DISPLAY 'LOT ' WS-LOT-ID(WS-IDX)
               ' SHARES: ' WS-MATCHED-SHARES
               ' GAIN/LOSS: ' WS-GAIN-LOSS.
       4000-CHECK-WASH-SALE.
           MOVE 'N' TO WS-WASH-FLAG
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-LOT-COUNT
               IF LOT-AVAILABLE(WS-IDX)
                   COMPUTE WS-HOLD-DAYS =
                       WS-LOT-BUY-DATE(WS-IDX)
                       - WS-SALE-DATE
                   IF WS-HOLD-DAYS >= 0
                       AND WS-HOLD-DAYS <= WS-WASH-WINDOW
                       MOVE 'Y' TO WS-WASH-FLAG
                       MOVE WS-LOT-BUY-DATE(WS-IDX)
                           TO WS-RECENT-BUY-DATE
                   END-IF
               END-IF
           END-PERFORM
           IF IS-WASH-SALE
               IF WS-TOT-ST-LOSS < 0
                   MOVE WS-TOT-ST-LOSS TO WS-WASH-AMOUNT
                   MULTIPLY -1 BY WS-WASH-AMOUNT
                   ADD WS-WASH-AMOUNT TO WS-TOT-WASH-ADJ
               END-IF
           END-IF.
       5000-CALC-NET.
           COMPUTE WS-NET-GAIN =
               WS-TOT-ST-GAIN + WS-TOT-ST-LOSS
               + WS-TOT-LT-GAIN + WS-TOT-LT-LOSS
               - WS-TOT-WASH-ADJ.
       6000-DISPLAY-RESULTS.
           DISPLAY 'CAPITAL GAINS TRACKING REPORT'
           DISPLAY '============================='
           DISPLAY 'SALE DATE:       ' WS-SALE-DATE
           DISPLAY 'SHARES SOLD:     ' WS-SALE-SHARES
           DISPLAY 'SALE PRICE:      ' WS-SALE-PRICE
           DISPLAY 'PROCEEDS:        ' WS-SALE-PROCEEDS
           DISPLAY 'LOTS MATCHED:    ' WS-MATCH-COUNT
           DISPLAY 'ST GAINS:        ' WS-TOT-ST-GAIN
           DISPLAY 'ST LOSSES:       ' WS-TOT-ST-LOSS
           DISPLAY 'LT GAINS:        ' WS-TOT-LT-GAIN
           DISPLAY 'LT LOSSES:       ' WS-TOT-LT-LOSS
           IF IS-WASH-SALE
               DISPLAY 'WASH SALE:   YES'
               DISPLAY 'WASH ADJ:    ' WS-TOT-WASH-ADJ
           END-IF
           DISPLAY 'NET GAIN/LOSS:   ' WS-NET-GAIN.
