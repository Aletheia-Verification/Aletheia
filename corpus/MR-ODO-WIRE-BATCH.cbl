       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-ODO-WIRE-BATCH.
      *================================================================*
      * MANUAL REVIEW: ODO WIRE BATCH PROCESSOR                       *
      * Uses OCCURS DEPENDING ON for variable-length wire batch.       *
      * Validates each wire, applies fees, totals by priority.         *
      * OCCURS DEPENDING ON triggers REQUIRES_MANUAL_REVIEW.          *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-BATCH-HEADER.
           05 WS-BATCH-ID           PIC X(12).
           05 WS-BATCH-DATE         PIC 9(8).
           05 WS-WIRE-COUNT         PIC 9(3).
       01 WS-WIRE-TABLE.
           05 WS-WIRE-ENTRY OCCURS 1 TO 50 TIMES
               DEPENDING ON WS-WIRE-COUNT.
               10 WS-WR-REF         PIC X(16).
               10 WS-WR-SENDER      PIC X(12).
               10 WS-WR-BENEF       PIC X(34).
               10 WS-WR-AMOUNT      PIC S9(11)V99 COMP-3.
               10 WS-WR-CURRENCY    PIC X(3).
               10 WS-WR-PRIORITY    PIC X(1).
                   88 WS-WR-URGENT  VALUE 'U'.
                   88 WS-WR-NORMAL  VALUE 'N'.
               10 WS-WR-FEE         PIC S9(5)V99 COMP-3.
               10 WS-WR-STATUS      PIC X(2).
                   88 WS-WR-VALID   VALUE 'OK'.
                   88 WS-WR-INVALID VALUE 'ER'.
                   88 WS-WR-HELD    VALUE 'HL'.
       01 WS-IDX                    PIC S9(3) COMP-3.
       01 WS-TOTALS.
           05 WS-TOTAL-AMOUNT       PIC S9(13)V99 COMP-3.
           05 WS-TOTAL-FEES         PIC S9(9)V99 COMP-3.
           05 WS-URGENT-TOTAL       PIC S9(13)V99 COMP-3.
           05 WS-NORMAL-TOTAL       PIC S9(13)V99 COMP-3.
           05 WS-VALID-COUNT        PIC S9(3) COMP-3.
           05 WS-ERROR-COUNT        PIC S9(3) COMP-3.
           05 WS-HELD-COUNT         PIC S9(3) COMP-3.
       01 WS-CTR-THRESHOLD          PIC S9(7)V99 COMP-3
           VALUE 10000.00.
       01 WS-CTR-FLAGGED            PIC S9(3) COMP-3.
       01 WS-BATCH-STATUS           PIC X(10).
       01 WS-DETAIL-LINE            PIC X(80).
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-BATCH
           IF WS-WIRE-COUNT > 0
               PERFORM 3000-PROCESS-WIRES
               PERFORM 4000-CALC-TOTALS
               PERFORM 5000-DETERMINE-STATUS
           END-IF
           PERFORM 6000-DISPLAY-REPORT
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'WBT202603210' TO WS-BATCH-ID
           MOVE 20260321 TO WS-BATCH-DATE
           MOVE 0 TO WS-TOTAL-AMOUNT
           MOVE 0 TO WS-TOTAL-FEES
           MOVE 0 TO WS-URGENT-TOTAL
           MOVE 0 TO WS-NORMAL-TOTAL
           MOVE 0 TO WS-VALID-COUNT
           MOVE 0 TO WS-ERROR-COUNT
           MOVE 0 TO WS-HELD-COUNT
           MOVE 0 TO WS-CTR-FLAGGED.
       2000-LOAD-BATCH.
           MOVE 5 TO WS-WIRE-COUNT
           MOVE 'WR20260321-001' TO WS-WR-REF(1)
           MOVE 'ACCT00001234' TO WS-WR-SENDER(1)
           MOVE 'DE89370400440532013000' TO WS-WR-BENEF(1)
           MOVE 75000.00 TO WS-WR-AMOUNT(1)
           MOVE 'USD' TO WS-WR-CURRENCY(1)
           MOVE 'U' TO WS-WR-PRIORITY(1)
           MOVE 'WR20260321-002' TO WS-WR-REF(2)
           MOVE 'ACCT00005678' TO WS-WR-SENDER(2)
           MOVE 'GB29NWBK60161331926819' TO WS-WR-BENEF(2)
           MOVE 12500.00 TO WS-WR-AMOUNT(2)
           MOVE 'GBP' TO WS-WR-CURRENCY(2)
           MOVE 'N' TO WS-WR-PRIORITY(2)
           MOVE 'WR20260321-003' TO WS-WR-REF(3)
           MOVE 'ACCT00009012' TO WS-WR-SENDER(3)
           MOVE 'CH9300762011623852957' TO WS-WR-BENEF(3)
           MOVE 250000.00 TO WS-WR-AMOUNT(3)
           MOVE 'CHF' TO WS-WR-CURRENCY(3)
           MOVE 'U' TO WS-WR-PRIORITY(3)
           MOVE 'WR20260321-004' TO WS-WR-REF(4)
           MOVE 'ACCT00003456' TO WS-WR-SENDER(4)
           MOVE SPACES TO WS-WR-BENEF(4)
           MOVE 5000.00 TO WS-WR-AMOUNT(4)
           MOVE 'EUR' TO WS-WR-CURRENCY(4)
           MOVE 'N' TO WS-WR-PRIORITY(4)
           MOVE 'WR20260321-005' TO WS-WR-REF(5)
           MOVE 'ACCT00007890' TO WS-WR-SENDER(5)
           MOVE 'FR7630006000011234567890189' TO
               WS-WR-BENEF(5)
           MOVE 8500.00 TO WS-WR-AMOUNT(5)
           MOVE 'EUR' TO WS-WR-CURRENCY(5)
           MOVE 'N' TO WS-WR-PRIORITY(5).
       3000-PROCESS-WIRES.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-WIRE-COUNT
               PERFORM 3100-VALIDATE-WIRE
               IF WS-WR-VALID(WS-IDX)
                   PERFORM 3200-CALC-FEE
                   PERFORM 3300-CHECK-CTR
               END-IF
           END-PERFORM.
       3100-VALIDATE-WIRE.
           IF WS-WR-BENEF(WS-IDX) = SPACES
               MOVE 'ER' TO WS-WR-STATUS(WS-IDX)
           ELSE
               IF WS-WR-AMOUNT(WS-IDX) <= 0
                   MOVE 'ER' TO WS-WR-STATUS(WS-IDX)
               ELSE
                   MOVE 'OK' TO WS-WR-STATUS(WS-IDX)
               END-IF
           END-IF.
       3200-CALC-FEE.
           IF WS-WR-URGENT(WS-IDX)
               EVALUATE TRUE
                   WHEN WS-WR-AMOUNT(WS-IDX) > 100000
                       COMPUTE WS-WR-FEE(WS-IDX) = 55.00
                   WHEN WS-WR-AMOUNT(WS-IDX) > 10000
                       COMPUTE WS-WR-FEE(WS-IDX) = 40.00
                   WHEN OTHER
                       COMPUTE WS-WR-FEE(WS-IDX) = 30.00
               END-EVALUATE
           ELSE
               EVALUATE TRUE
                   WHEN WS-WR-AMOUNT(WS-IDX) > 100000
                       COMPUTE WS-WR-FEE(WS-IDX) = 35.00
                   WHEN WS-WR-AMOUNT(WS-IDX) > 10000
                       COMPUTE WS-WR-FEE(WS-IDX) = 25.00
                   WHEN OTHER
                       COMPUTE WS-WR-FEE(WS-IDX) = 15.00
               END-EVALUATE
           END-IF.
       3300-CHECK-CTR.
           IF WS-WR-AMOUNT(WS-IDX) > WS-CTR-THRESHOLD
               ADD 1 TO WS-CTR-FLAGGED
           END-IF
           IF WS-WR-AMOUNT(WS-IDX) > 200000
               MOVE 'HL' TO WS-WR-STATUS(WS-IDX)
           END-IF.
       4000-CALC-TOTALS.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-WIRE-COUNT
               EVALUATE TRUE
                   WHEN WS-WR-VALID(WS-IDX)
                       ADD 1 TO WS-VALID-COUNT
                       ADD WS-WR-AMOUNT(WS-IDX) TO
                           WS-TOTAL-AMOUNT
                       ADD WS-WR-FEE(WS-IDX) TO
                           WS-TOTAL-FEES
                       IF WS-WR-URGENT(WS-IDX)
                           ADD WS-WR-AMOUNT(WS-IDX) TO
                               WS-URGENT-TOTAL
                       ELSE
                           ADD WS-WR-AMOUNT(WS-IDX) TO
                               WS-NORMAL-TOTAL
                       END-IF
                   WHEN WS-WR-INVALID(WS-IDX)
                       ADD 1 TO WS-ERROR-COUNT
                   WHEN WS-WR-HELD(WS-IDX)
                       ADD 1 TO WS-HELD-COUNT
                       ADD WS-WR-AMOUNT(WS-IDX) TO
                           WS-TOTAL-AMOUNT
                       ADD WS-WR-FEE(WS-IDX) TO
                           WS-TOTAL-FEES
               END-EVALUATE
           END-PERFORM.
       5000-DETERMINE-STATUS.
           IF WS-ERROR-COUNT = 0
               IF WS-HELD-COUNT = 0
                   MOVE 'COMPLETE' TO WS-BATCH-STATUS
               ELSE
                   MOVE 'PARTIAL' TO WS-BATCH-STATUS
               END-IF
           ELSE
               MOVE 'HAS ERRORS' TO WS-BATCH-STATUS
           END-IF.
       6000-DISPLAY-REPORT.
           DISPLAY '========================================='
           DISPLAY 'WIRE BATCH REPORT'
           DISPLAY '========================================='
           DISPLAY 'BATCH ID:        ' WS-BATCH-ID
           DISPLAY 'DATE:            ' WS-BATCH-DATE
           DISPLAY 'WIRE COUNT:      ' WS-WIRE-COUNT
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-WIRE-COUNT
               MOVE SPACES TO WS-DETAIL-LINE
               STRING WS-WR-REF(WS-IDX) DELIMITED BY SIZE
                   ' ' DELIMITED BY SIZE
                   WS-WR-AMOUNT(WS-IDX) DELIMITED BY SIZE
                   ' ' DELIMITED BY SIZE
                   WS-WR-STATUS(WS-IDX) DELIMITED BY SIZE
                   INTO WS-DETAIL-LINE
               DISPLAY WS-DETAIL-LINE
           END-PERFORM
           DISPLAY '-----------------------------------------'
           DISPLAY 'VALID:           ' WS-VALID-COUNT
           DISPLAY 'ERRORS:          ' WS-ERROR-COUNT
           DISPLAY 'HELD:            ' WS-HELD-COUNT
           DISPLAY 'TOTAL AMOUNT:    ' WS-TOTAL-AMOUNT
           DISPLAY 'TOTAL FEES:      ' WS-TOTAL-FEES
           DISPLAY 'URGENT TOTAL:    ' WS-URGENT-TOTAL
           DISPLAY 'NORMAL TOTAL:    ' WS-NORMAL-TOTAL
           DISPLAY 'CTR FLAGGED:     ' WS-CTR-FLAGGED
           DISPLAY 'STATUS:          ' WS-BATCH-STATUS
           DISPLAY '========================================='.
