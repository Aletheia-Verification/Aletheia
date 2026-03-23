       IDENTIFICATION DIVISION.
       PROGRAM-ID. BATCH-SETTLE-PROC.
      *================================================================*
      * BATCH SETTLEMENT PROCESSOR                                     *
      * Processes end-of-day card settlement batches. Groups by        *
      * merchant, nets debits/credits, applies interchange fees,       *
      * and generates funding instructions.                            *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-BATCH-HEADER.
           05 WS-BATCH-ID           PIC X(12).
           05 WS-BATCH-DATE         PIC 9(8).
           05 WS-NETWORK-ID         PIC X(4).
               88 WS-VISA           VALUE 'VISA'.
               88 WS-MAST           VALUE 'MAST'.
               88 WS-AMEX           VALUE 'AMEX'.
       01 WS-TXN-TABLE.
           05 WS-TXN-ENTRY OCCURS 15.
               10 WS-TXN-SEQ        PIC S9(5) COMP-3.
               10 WS-TXN-MERCH-ID   PIC X(10).
               10 WS-TXN-AMOUNT     PIC S9(9)V99 COMP-3.
               10 WS-TXN-TYPE       PIC X(2).
                   88 WS-SALE        VALUE 'SA'.
                   88 WS-RETURN      VALUE 'RE'.
                   88 WS-REVERSAL    VALUE 'RV'.
               10 WS-TXN-CARD-TYPE  PIC X(2).
                   88 WS-DEBIT-CARD  VALUE 'DB'.
                   88 WS-CREDIT-CARD VALUE 'CR'.
               10 WS-TXN-STATUS     PIC X(1).
                   88 WS-SETTLED     VALUE 'S'.
                   88 WS-PENDING     VALUE 'P'.
                   88 WS-REJECTED    VALUE 'R'.
       01 WS-TXN-COUNT              PIC S9(3) COMP-3.
       01 WS-INTERCHANGE.
           05 WS-IC-DEBIT-RATE      PIC S9(1)V9(4) COMP-3
               VALUE 0.0150.
           05 WS-IC-CREDIT-RATE     PIC S9(1)V9(4) COMP-3
               VALUE 0.0250.
           05 WS-IC-AMEX-RATE       PIC S9(1)V9(4) COMP-3
               VALUE 0.0350.
           05 WS-IC-AMOUNT          PIC S9(7)V99 COMP-3.
           05 WS-IC-TOTAL           PIC S9(9)V99 COMP-3.
       01 WS-SETTLEMENT-TOTALS.
           05 WS-GROSS-SALES        PIC S9(11)V99 COMP-3.
           05 WS-GROSS-RETURNS      PIC S9(11)V99 COMP-3.
           05 WS-GROSS-REVERSALS    PIC S9(11)V99 COMP-3.
           05 WS-NET-AMOUNT         PIC S9(11)V99 COMP-3.
           05 WS-FUNDING-AMT        PIC S9(11)V99 COMP-3.
           05 WS-TOTAL-IC-FEES      PIC S9(9)V99 COMP-3.
       01 WS-STATS.
           05 WS-SALE-COUNT         PIC S9(5) COMP-3.
           05 WS-RETURN-COUNT       PIC S9(5) COMP-3.
           05 WS-REVERSAL-COUNT     PIC S9(5) COMP-3.
           05 WS-REJECT-COUNT       PIC S9(5) COMP-3.
       01 WS-IDX                    PIC S9(3) COMP-3.
       01 WS-BATCH-STATUS           PIC X(10).
       01 WS-VALIDATE-FLAG          PIC X VALUE 'Y'.
           88 WS-BATCH-VALID        VALUE 'Y'.
           88 WS-BATCH-INVALID      VALUE 'N'.
       01 WS-HASH-TOTAL             PIC S9(13)V99 COMP-3.
       01 WS-RATE-USED              PIC S9(1)V9(4) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-BATCH
           PERFORM 3000-VALIDATE-BATCH
           IF WS-BATCH-VALID
               PERFORM 4000-PROCESS-ENTRIES
               PERFORM 5000-CALC-INTERCHANGE
               PERFORM 6000-NET-SETTLEMENT
               PERFORM 7000-SET-STATUS
           END-IF
           PERFORM 8000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'BTH202603150' TO WS-BATCH-ID
           MOVE 20260315 TO WS-BATCH-DATE
           MOVE 'VISA' TO WS-NETWORK-ID
           MOVE 0 TO WS-GROSS-SALES
           MOVE 0 TO WS-GROSS-RETURNS
           MOVE 0 TO WS-GROSS-REVERSALS
           MOVE 0 TO WS-NET-AMOUNT
           MOVE 0 TO WS-FUNDING-AMT
           MOVE 0 TO WS-TOTAL-IC-FEES
           MOVE 0 TO WS-IC-TOTAL
           MOVE 0 TO WS-SALE-COUNT
           MOVE 0 TO WS-RETURN-COUNT
           MOVE 0 TO WS-REVERSAL-COUNT
           MOVE 0 TO WS-REJECT-COUNT
           MOVE 0 TO WS-HASH-TOTAL.
       2000-LOAD-BATCH.
           MOVE 8 TO WS-TXN-COUNT
           MOVE 1 TO WS-TXN-SEQ(1)
           MOVE 'MERCH00001' TO WS-TXN-MERCH-ID(1)
           MOVE 1250.50 TO WS-TXN-AMOUNT(1)
           MOVE 'SA' TO WS-TXN-TYPE(1)
           MOVE 'CR' TO WS-TXN-CARD-TYPE(1)
           MOVE 'P' TO WS-TXN-STATUS(1)
           MOVE 2 TO WS-TXN-SEQ(2)
           MOVE 'MERCH00001' TO WS-TXN-MERCH-ID(2)
           MOVE 325.00 TO WS-TXN-AMOUNT(2)
           MOVE 'SA' TO WS-TXN-TYPE(2)
           MOVE 'DB' TO WS-TXN-CARD-TYPE(2)
           MOVE 'P' TO WS-TXN-STATUS(2)
           MOVE 3 TO WS-TXN-SEQ(3)
           MOVE 'MERCH00002' TO WS-TXN-MERCH-ID(3)
           MOVE 89.99 TO WS-TXN-AMOUNT(3)
           MOVE 'RE' TO WS-TXN-TYPE(3)
           MOVE 'CR' TO WS-TXN-CARD-TYPE(3)
           MOVE 'P' TO WS-TXN-STATUS(3)
           MOVE 4 TO WS-TXN-SEQ(4)
           MOVE 'MERCH00002' TO WS-TXN-MERCH-ID(4)
           MOVE 4500.00 TO WS-TXN-AMOUNT(4)
           MOVE 'SA' TO WS-TXN-TYPE(4)
           MOVE 'CR' TO WS-TXN-CARD-TYPE(4)
           MOVE 'P' TO WS-TXN-STATUS(4)
           MOVE 5 TO WS-TXN-SEQ(5)
           MOVE 'MERCH00003' TO WS-TXN-MERCH-ID(5)
           MOVE 175.25 TO WS-TXN-AMOUNT(5)
           MOVE 'SA' TO WS-TXN-TYPE(5)
           MOVE 'DB' TO WS-TXN-CARD-TYPE(5)
           MOVE 'P' TO WS-TXN-STATUS(5)
           MOVE 6 TO WS-TXN-SEQ(6)
           MOVE 'MERCH00001' TO WS-TXN-MERCH-ID(6)
           MOVE 50.00 TO WS-TXN-AMOUNT(6)
           MOVE 'RV' TO WS-TXN-TYPE(6)
           MOVE 'CR' TO WS-TXN-CARD-TYPE(6)
           MOVE 'P' TO WS-TXN-STATUS(6)
           MOVE 7 TO WS-TXN-SEQ(7)
           MOVE 'MERCH00003' TO WS-TXN-MERCH-ID(7)
           MOVE 2100.00 TO WS-TXN-AMOUNT(7)
           MOVE 'SA' TO WS-TXN-TYPE(7)
           MOVE 'CR' TO WS-TXN-CARD-TYPE(7)
           MOVE 'R' TO WS-TXN-STATUS(7)
           MOVE 8 TO WS-TXN-SEQ(8)
           MOVE 'MERCH00002' TO WS-TXN-MERCH-ID(8)
           MOVE 780.00 TO WS-TXN-AMOUNT(8)
           MOVE 'SA' TO WS-TXN-TYPE(8)
           MOVE 'DB' TO WS-TXN-CARD-TYPE(8)
           MOVE 'P' TO WS-TXN-STATUS(8).
       3000-VALIDATE-BATCH.
           IF WS-TXN-COUNT < 1
               MOVE 'N' TO WS-VALIDATE-FLAG
           END-IF
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-TXN-COUNT
               IF WS-TXN-AMOUNT(WS-IDX) < 0
                   MOVE 'N' TO WS-VALIDATE-FLAG
               END-IF
               ADD WS-TXN-AMOUNT(WS-IDX) TO WS-HASH-TOTAL
           END-PERFORM.
       4000-PROCESS-ENTRIES.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-TXN-COUNT
               IF WS-REJECTED(WS-IDX)
                   ADD 1 TO WS-REJECT-COUNT
               ELSE
                   EVALUATE TRUE
                       WHEN WS-SALE(WS-IDX)
                           ADD WS-TXN-AMOUNT(WS-IDX) TO
                               WS-GROSS-SALES
                           ADD 1 TO WS-SALE-COUNT
                       WHEN WS-RETURN(WS-IDX)
                           ADD WS-TXN-AMOUNT(WS-IDX) TO
                               WS-GROSS-RETURNS
                           ADD 1 TO WS-RETURN-COUNT
                       WHEN WS-REVERSAL(WS-IDX)
                           ADD WS-TXN-AMOUNT(WS-IDX) TO
                               WS-GROSS-REVERSALS
                           ADD 1 TO WS-REVERSAL-COUNT
                   END-EVALUATE
                   MOVE 'S' TO WS-TXN-STATUS(WS-IDX)
               END-IF
           END-PERFORM.
       5000-CALC-INTERCHANGE.
           MOVE 0 TO WS-IC-TOTAL
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-TXN-COUNT
               IF WS-SETTLED(WS-IDX) AND WS-SALE(WS-IDX)
                   IF WS-AMEX
                       MOVE WS-IC-AMEX-RATE TO WS-RATE-USED
                   ELSE
                       IF WS-DEBIT-CARD(WS-IDX)
                           MOVE WS-IC-DEBIT-RATE TO
                               WS-RATE-USED
                       ELSE
                           MOVE WS-IC-CREDIT-RATE TO
                               WS-RATE-USED
                       END-IF
                   END-IF
                   COMPUTE WS-IC-AMOUNT ROUNDED =
                       WS-TXN-AMOUNT(WS-IDX) * WS-RATE-USED
                   ADD WS-IC-AMOUNT TO WS-IC-TOTAL
               END-IF
           END-PERFORM
           MOVE WS-IC-TOTAL TO WS-TOTAL-IC-FEES.
       6000-NET-SETTLEMENT.
           COMPUTE WS-NET-AMOUNT =
               WS-GROSS-SALES - WS-GROSS-RETURNS -
               WS-GROSS-REVERSALS
           COMPUTE WS-FUNDING-AMT =
               WS-NET-AMOUNT - WS-TOTAL-IC-FEES.
       7000-SET-STATUS.
           IF WS-FUNDING-AMT >= 0
               MOVE 'APPROVED' TO WS-BATCH-STATUS
           ELSE
               MOVE 'DEBIT DUE' TO WS-BATCH-STATUS
           END-IF.
       8000-DISPLAY-RESULTS.
           DISPLAY '========================================='
           DISPLAY 'BATCH SETTLEMENT REPORT'
           DISPLAY '========================================='
           DISPLAY 'BATCH ID:        ' WS-BATCH-ID
           DISPLAY 'DATE:            ' WS-BATCH-DATE
           DISPLAY 'NETWORK:         ' WS-NETWORK-ID
           IF WS-BATCH-VALID
               DISPLAY 'TOTAL TXNS:      ' WS-TXN-COUNT
               DISPLAY 'SALES:           ' WS-SALE-COUNT
                   ' / ' WS-GROSS-SALES
               DISPLAY 'RETURNS:         ' WS-RETURN-COUNT
                   ' / ' WS-GROSS-RETURNS
               DISPLAY 'REVERSALS:       ' WS-REVERSAL-COUNT
                   ' / ' WS-GROSS-REVERSALS
               DISPLAY 'REJECTED:        ' WS-REJECT-COUNT
               DISPLAY 'NET AMOUNT:      ' WS-NET-AMOUNT
               DISPLAY 'IC FEES:         ' WS-TOTAL-IC-FEES
               DISPLAY 'FUNDING AMOUNT:  ' WS-FUNDING-AMT
               DISPLAY 'STATUS:          ' WS-BATCH-STATUS
               DISPLAY 'HASH TOTAL:      ' WS-HASH-TOTAL
           ELSE
               DISPLAY 'BATCH VALIDATION FAILED'
           END-IF
           DISPLAY '========================================='.
