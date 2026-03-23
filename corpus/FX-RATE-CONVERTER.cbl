       IDENTIFICATION DIVISION.
       PROGRAM-ID. FX-RATE-CONVERTER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-RATE-TABLE.
           05 WS-RATE-ENTRY OCCURS 20.
               10 WS-CURRENCY-CD  PIC X(3).
               10 WS-BUY-RATE     PIC S9(3)V9(6) COMP-3.
               10 WS-SELL-RATE    PIC S9(3)V9(6) COMP-3.
               10 WS-DECIMALS     PIC 9(1).
               10 WS-MIN-AMOUNT   PIC S9(9)V99 COMP-3.
               10 WS-MAX-AMOUNT   PIC S9(11)V99 COMP-3.
       01 WS-RATE-COUNT           PIC 9(2).
       01 WS-IDX                  PIC 9(2).
       01 WS-FOUND-IDX            PIC 9(2).
       01 WS-REQUEST.
           05 WS-SOURCE-CURR      PIC X(3).
           05 WS-TARGET-CURR      PIC X(3).
           05 WS-SOURCE-AMOUNT    PIC S9(11)V99 COMP-3.
           05 WS-TARGET-AMOUNT    PIC S9(11)V99 COMP-3.
       01 WS-CALC-FIELDS.
           05 WS-USD-AMOUNT       PIC S9(11)V9(6) COMP-3.
           05 WS-SRC-BUY-RATE     PIC S9(3)V9(6) COMP-3.
           05 WS-SRC-SELL-RATE    PIC S9(3)V9(6) COMP-3.
           05 WS-TGT-BUY-RATE     PIC S9(3)V9(6) COMP-3.
           05 WS-TGT-SELL-RATE    PIC S9(3)V9(6) COMP-3.
           05 WS-CROSS-RATE       PIC S9(3)V9(6) COMP-3.
           05 WS-SPREAD           PIC S9(1)V9(6) COMP-3.
           05 WS-SPREAD-PCT       PIC S9(1)V9(4) COMP-3.
           05 WS-BID-PRICE        PIC S9(11)V9(6) COMP-3.
           05 WS-ASK-PRICE        PIC S9(11)V9(6) COMP-3.
           05 WS-MID-RATE         PIC S9(3)V9(6) COMP-3.
           05 WS-MARGIN-AMT       PIC S9(9)V99 COMP-3.
           05 WS-MARGIN-PCT       PIC S9(1)V9(4) VALUE 0.0150.
           05 WS-FEE-AMOUNT       PIC S9(7)V99 COMP-3.
           05 WS-MIN-FEE          PIC S9(5)V99 VALUE 25.00.
           05 WS-FEE-RATE         PIC S9(1)V9(4) VALUE 0.0025.
           05 WS-TOTAL-COST       PIC S9(11)V99 COMP-3.
           05 WS-NET-AMOUNT       PIC S9(11)V99 COMP-3.
       01 WS-ROUND-FIELDS.
           05 WS-ROUND-FACTOR     PIC S9(7) COMP-3.
           05 WS-ROUNDED-AMT      PIC S9(11)V99 COMP-3.
           05 WS-ROUND-REMAINDER  PIC S9(5)V99 COMP-3.
       01 WS-SRC-FOUND            PIC X VALUE 'N'.
           88 WS-SRC-OK           VALUE 'Y'.
       01 WS-TGT-FOUND            PIC X VALUE 'N'.
           88 WS-TGT-OK           VALUE 'Y'.
       01 WS-VALID-FLAG           PIC X VALUE 'Y'.
           88 WS-VALID            VALUE 'Y'.
           88 WS-INVALID          VALUE 'N'.
       01 WS-CURRENCY-CODE        PIC X(3).
       01 WS-PRECISION            PIC 9(1).
       01 WS-TIER-MARKUP          PIC S9(1)V9(4) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 0100-INITIALIZE-RATES
           PERFORM 0200-VALIDATE-REQUEST
           IF WS-VALID
               PERFORM 1000-LOOKUP-RATES
               PERFORM 2000-CALC-CROSS-RATE
               PERFORM 3000-CALC-SPREAD
               PERFORM 4000-APPLY-MARGIN
               PERFORM 5000-ROUND-TO-PRECISION
               PERFORM 6000-CALC-FEES
               PERFORM 7000-DISPLAY-QUOTE
           ELSE
               DISPLAY 'INVALID REQUEST'
           END-IF
           STOP RUN.
       0100-INITIALIZE-RATES.
           MOVE 8 TO WS-RATE-COUNT
           MOVE 'EUR' TO WS-CURRENCY-CD(1)
           MOVE 1.085000 TO WS-BUY-RATE(1)
           MOVE 1.095000 TO WS-SELL-RATE(1)
           MOVE 2 TO WS-DECIMALS(1)
           MOVE 100.00 TO WS-MIN-AMOUNT(1)
           MOVE 10000000.00 TO WS-MAX-AMOUNT(1)
           MOVE 'GBP' TO WS-CURRENCY-CD(2)
           MOVE 1.265000 TO WS-BUY-RATE(2)
           MOVE 1.275000 TO WS-SELL-RATE(2)
           MOVE 2 TO WS-DECIMALS(2)
           MOVE 100.00 TO WS-MIN-AMOUNT(2)
           MOVE 10000000.00 TO WS-MAX-AMOUNT(2)
           MOVE 'JPY' TO WS-CURRENCY-CD(3)
           MOVE 0.006700 TO WS-BUY-RATE(3)
           MOVE 0.006750 TO WS-SELL-RATE(3)
           MOVE 0 TO WS-DECIMALS(3)
           MOVE 10000.00 TO WS-MIN-AMOUNT(3)
           MOVE 99999999.00 TO WS-MAX-AMOUNT(3)
           MOVE 'CHF' TO WS-CURRENCY-CD(4)
           MOVE 1.120000 TO WS-BUY-RATE(4)
           MOVE 1.130000 TO WS-SELL-RATE(4)
           MOVE 2 TO WS-DECIMALS(4)
           MOVE 100.00 TO WS-MIN-AMOUNT(4)
           MOVE 10000000.00 TO WS-MAX-AMOUNT(4)
           MOVE 'CAD' TO WS-CURRENCY-CD(5)
           MOVE 0.735000 TO WS-BUY-RATE(5)
           MOVE 0.742000 TO WS-SELL-RATE(5)
           MOVE 2 TO WS-DECIMALS(5)
           MOVE 100.00 TO WS-MIN-AMOUNT(5)
           MOVE 10000000.00 TO WS-MAX-AMOUNT(5)
           MOVE 'AUD' TO WS-CURRENCY-CD(6)
           MOVE 0.655000 TO WS-BUY-RATE(6)
           MOVE 0.662000 TO WS-SELL-RATE(6)
           MOVE 2 TO WS-DECIMALS(6)
           MOVE 100.00 TO WS-MIN-AMOUNT(6)
           MOVE 10000000.00 TO WS-MAX-AMOUNT(6)
           MOVE 'SGD' TO WS-CURRENCY-CD(7)
           MOVE 0.745000 TO WS-BUY-RATE(7)
           MOVE 0.752000 TO WS-SELL-RATE(7)
           MOVE 2 TO WS-DECIMALS(7)
           MOVE 100.00 TO WS-MIN-AMOUNT(7)
           MOVE 10000000.00 TO WS-MAX-AMOUNT(7)
           MOVE 'HKD' TO WS-CURRENCY-CD(8)
           MOVE 0.128000 TO WS-BUY-RATE(8)
           MOVE 0.129000 TO WS-SELL-RATE(8)
           MOVE 2 TO WS-DECIMALS(8)
           MOVE 1000.00 TO WS-MIN-AMOUNT(8)
           MOVE 99999999.00 TO WS-MAX-AMOUNT(8)
           PERFORM VARYING WS-IDX FROM 9 BY 1
               UNTIL WS-IDX > 20
               MOVE SPACES TO WS-CURRENCY-CD(WS-IDX)
               MOVE 0 TO WS-BUY-RATE(WS-IDX)
               MOVE 0 TO WS-SELL-RATE(WS-IDX)
           END-PERFORM.
       0200-VALIDATE-REQUEST.
           MOVE 'Y' TO WS-VALID-FLAG
           IF WS-SOURCE-CURR = SPACES
               MOVE 'N' TO WS-VALID-FLAG
           END-IF
           IF WS-TARGET-CURR = SPACES
               MOVE 'N' TO WS-VALID-FLAG
           END-IF
           IF WS-SOURCE-AMOUNT < 0
               MOVE 'N' TO WS-VALID-FLAG
           END-IF
           IF WS-SOURCE-CURR = WS-TARGET-CURR
               MOVE 'N' TO WS-VALID-FLAG
               DISPLAY 'SAME CURRENCY CONVERSION'
           END-IF.
       1000-LOOKUP-RATES.
           MOVE 'N' TO WS-SRC-FOUND
           MOVE 'N' TO WS-TGT-FOUND
           IF WS-SOURCE-CURR = 'USD'
               MOVE 'Y' TO WS-SRC-FOUND
               MOVE 1.000000 TO WS-SRC-BUY-RATE
               MOVE 1.000000 TO WS-SRC-SELL-RATE
           END-IF
           IF WS-TARGET-CURR = 'USD'
               MOVE 'Y' TO WS-TGT-FOUND
               MOVE 1.000000 TO WS-TGT-BUY-RATE
               MOVE 1.000000 TO WS-TGT-SELL-RATE
           END-IF
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-RATE-COUNT
               IF WS-CURRENCY-CD(WS-IDX) =
                   WS-SOURCE-CURR
                   MOVE WS-BUY-RATE(WS-IDX) TO
                       WS-SRC-BUY-RATE
                   MOVE WS-SELL-RATE(WS-IDX) TO
                       WS-SRC-SELL-RATE
                   MOVE 'Y' TO WS-SRC-FOUND
               END-IF
               IF WS-CURRENCY-CD(WS-IDX) =
                   WS-TARGET-CURR
                   MOVE WS-BUY-RATE(WS-IDX) TO
                       WS-TGT-BUY-RATE
                   MOVE WS-SELL-RATE(WS-IDX) TO
                       WS-TGT-SELL-RATE
                   MOVE WS-DECIMALS(WS-IDX) TO
                       WS-PRECISION
                   MOVE 'Y' TO WS-TGT-FOUND
               END-IF
           END-PERFORM
           IF WS-SRC-FOUND = 'N'
               MOVE 'N' TO WS-VALID-FLAG
               DISPLAY 'SOURCE CURRENCY NOT FOUND'
           END-IF
           IF WS-TGT-FOUND = 'N'
               MOVE 'N' TO WS-VALID-FLAG
               DISPLAY 'TARGET CURRENCY NOT FOUND'
           END-IF.
       2000-CALC-CROSS-RATE.
           COMPUTE WS-USD-AMOUNT =
               WS-SOURCE-AMOUNT * WS-SRC-BUY-RATE
           COMPUTE WS-CROSS-RATE =
               WS-SRC-BUY-RATE / WS-TGT-SELL-RATE
           COMPUTE WS-TARGET-AMOUNT =
               WS-SOURCE-AMOUNT * WS-CROSS-RATE
           MOVE WS-CURRENCY-CODE TO WS-TARGET-CURR
           EVALUATE WS-TARGET-CURR
               WHEN 'JPY'
                   MOVE 0.0050 TO WS-TIER-MARKUP
               WHEN 'EUR'
                   MOVE 0.0020 TO WS-TIER-MARKUP
               WHEN 'GBP'
                   MOVE 0.0025 TO WS-TIER-MARKUP
               WHEN 'CHF'
                   MOVE 0.0030 TO WS-TIER-MARKUP
               WHEN OTHER
                   MOVE 0.0040 TO WS-TIER-MARKUP
           END-EVALUATE
           IF WS-SOURCE-AMOUNT > 100000
               COMPUTE WS-TIER-MARKUP =
                   WS-TIER-MARKUP * 0.50
           ELSE
               IF WS-SOURCE-AMOUNT > 10000
                   COMPUTE WS-TIER-MARKUP =
                       WS-TIER-MARKUP * 0.75
               END-IF
           END-IF.
       3000-CALC-SPREAD.
           COMPUTE WS-SPREAD =
               WS-SRC-SELL-RATE - WS-SRC-BUY-RATE
           COMPUTE WS-MID-RATE =
               (WS-SRC-BUY-RATE + WS-SRC-SELL-RATE) / 2
           IF WS-MID-RATE > 0
               COMPUTE WS-SPREAD-PCT =
                   WS-SPREAD / WS-MID-RATE
           ELSE
               MOVE 0 TO WS-SPREAD-PCT
           END-IF
           COMPUTE WS-BID-PRICE =
               WS-TARGET-AMOUNT - (WS-TARGET-AMOUNT *
               WS-SPREAD-PCT)
           COMPUTE WS-ASK-PRICE =
               WS-TARGET-AMOUNT + (WS-TARGET-AMOUNT *
               WS-SPREAD-PCT).
       4000-APPLY-MARGIN.
           COMPUTE WS-MARGIN-AMT =
               WS-TARGET-AMOUNT * WS-MARGIN-PCT
           ADD WS-TIER-MARKUP TO WS-MARGIN-PCT
           COMPUTE WS-MARGIN-AMT =
               WS-TARGET-AMOUNT * WS-MARGIN-PCT
           SUBTRACT WS-MARGIN-AMT FROM WS-TARGET-AMOUNT.
       5000-ROUND-TO-PRECISION.
           IF WS-PRECISION = 0
               DIVIDE WS-TARGET-AMOUNT BY 1
                   GIVING WS-ROUNDED-AMT
                   REMAINDER WS-ROUND-REMAINDER
               MOVE WS-ROUNDED-AMT TO WS-TARGET-AMOUNT
           ELSE
               COMPUTE WS-ROUND-FACTOR = 10
               MULTIPLY WS-TARGET-AMOUNT BY
                   WS-ROUND-FACTOR
                   GIVING WS-ROUNDED-AMT
               DIVIDE WS-ROUNDED-AMT BY WS-ROUND-FACTOR
                   GIVING WS-TARGET-AMOUNT
                   REMAINDER WS-ROUND-REMAINDER
           END-IF.
       6000-CALC-FEES.
           COMPUTE WS-FEE-AMOUNT =
               WS-SOURCE-AMOUNT * WS-FEE-RATE
           IF WS-FEE-AMOUNT < WS-MIN-FEE
               MOVE WS-MIN-FEE TO WS-FEE-AMOUNT
           END-IF
           COMPUTE WS-TOTAL-COST =
               WS-SOURCE-AMOUNT + WS-FEE-AMOUNT
           COMPUTE WS-NET-AMOUNT =
               WS-TARGET-AMOUNT - WS-FEE-AMOUNT.
       7000-DISPLAY-QUOTE.
           DISPLAY 'FX CONVERSION QUOTE'
           DISPLAY 'SOURCE:      ' WS-SOURCE-CURR
               ' ' WS-SOURCE-AMOUNT
           DISPLAY 'TARGET:      ' WS-TARGET-CURR
               ' ' WS-TARGET-AMOUNT
           DISPLAY 'CROSS RATE:  ' WS-CROSS-RATE
           DISPLAY 'SPREAD:      ' WS-SPREAD-PCT
           DISPLAY 'BID:         ' WS-BID-PRICE
           DISPLAY 'ASK:         ' WS-ASK-PRICE
           DISPLAY 'MARGIN:      ' WS-MARGIN-AMT
           DISPLAY 'FEE:         ' WS-FEE-AMOUNT
           DISPLAY 'TOTAL COST:  ' WS-TOTAL-COST
           DISPLAY 'NET AMOUNT:  ' WS-NET-AMOUNT.
