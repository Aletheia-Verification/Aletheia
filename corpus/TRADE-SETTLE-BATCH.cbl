       IDENTIFICATION DIVISION.
       PROGRAM-ID. TRADE-SETTLE-BATCH.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT TRADE-FILE ASSIGN TO 'TRADES.DAT'
               FILE STATUS IS WS-TRADE-STATUS.
           SELECT SETTLE-FILE ASSIGN TO 'SETTLED.DAT'
               FILE STATUS IS WS-SETTLE-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD TRADE-FILE.
       01 TRADE-RECORD.
           05 TR-TRADE-ID            PIC X(12).
           05 TR-SECURITY            PIC X(10).
           05 TR-SIDE                PIC X(1).
           05 TR-QTY                 PIC 9(7).
           05 TR-PRICE               PIC 9(7)V99.
           05 TR-SETTLE-DATE         PIC 9(8).
       FD SETTLE-FILE.
       01 SETTLE-RECORD.
           05 SR-TRADE-ID            PIC X(12).
           05 SR-NET-AMOUNT          PIC S9(11)V99.
           05 SR-COMMISSION          PIC 9(7)V99.
           05 SR-FEES                PIC 9(5)V99.
           05 SR-STATUS              PIC X(8).
       WORKING-STORAGE SECTION.
       01 WS-TRADE-STATUS            PIC XX.
       01 WS-SETTLE-STATUS           PIC XX.
       01 WS-EOF-FLAG                PIC X VALUE 'N'.
           88 WS-EOF                  VALUE 'Y'.
       01 WS-CALC-FIELDS.
           05 WS-GROSS-AMT           PIC S9(11)V99 COMP-3.
           05 WS-COMMISSION          PIC S9(7)V99 COMP-3.
           05 WS-SEC-FEE             PIC S9(5)V99 COMP-3.
           05 WS-NET-AMT             PIC S9(11)V99 COMP-3.
       01 WS-SIDE-FLAG               PIC X(1).
           88 WS-BUY                  VALUE 'B'.
           88 WS-SELL                 VALUE 'S'.
       01 WS-COMM-TABLE.
           05 WS-COMM-ENTRY OCCURS 4.
               10 WS-CE-MIN-QTY      PIC 9(7).
               10 WS-CE-RATE         PIC S9(1)V9(4) COMP-3.
       01 WS-CE-IDX                  PIC 9(1).
       01 WS-TOTALS.
           05 WS-TOTAL-BUYS          PIC S9(13)V99 COMP-3.
           05 WS-TOTAL-SELLS         PIC S9(13)V99 COMP-3.
           05 WS-TOTAL-COMM          PIC S9(9)V99 COMP-3.
           05 WS-TRADE-COUNT         PIC S9(5) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 1100-OPEN-FILES
           PERFORM 2000-PROCESS-TRADES UNTIL WS-EOF
           PERFORM 3000-CLOSE-FILES
           PERFORM 4000-DISPLAY-SUMMARY
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-BUYS
           MOVE 0 TO WS-TOTAL-SELLS
           MOVE 0 TO WS-TOTAL-COMM
           MOVE 0 TO WS-TRADE-COUNT
           MOVE 100 TO WS-CE-MIN-QTY(1)
           MOVE 0.0100 TO WS-CE-RATE(1)
           MOVE 1000 TO WS-CE-MIN-QTY(2)
           MOVE 0.0075 TO WS-CE-RATE(2)
           MOVE 10000 TO WS-CE-MIN-QTY(3)
           MOVE 0.0050 TO WS-CE-RATE(3)
           MOVE 100000 TO WS-CE-MIN-QTY(4)
           MOVE 0.0025 TO WS-CE-RATE(4).
       1100-OPEN-FILES.
           OPEN INPUT TRADE-FILE
           OPEN OUTPUT SETTLE-FILE.
       2000-PROCESS-TRADES.
           READ TRADE-FILE
               AT END SET WS-EOF TO TRUE
               NOT AT END PERFORM 2100-SETTLE-TRADE
           END-READ.
       2100-SETTLE-TRADE.
           ADD 1 TO WS-TRADE-COUNT
           MOVE TR-SIDE TO WS-SIDE-FLAG
           COMPUTE WS-GROSS-AMT =
               TR-QTY * TR-PRICE
           PERFORM 2200-CALC-COMMISSION
           COMPUTE WS-SEC-FEE =
               WS-GROSS-AMT * 0.0000278
           IF WS-BUY
               COMPUTE WS-NET-AMT =
                   WS-GROSS-AMT + WS-COMMISSION +
                   WS-SEC-FEE
               ADD WS-GROSS-AMT TO WS-TOTAL-BUYS
           ELSE
               COMPUTE WS-NET-AMT =
                   WS-GROSS-AMT - WS-COMMISSION -
                   WS-SEC-FEE
               ADD WS-GROSS-AMT TO WS-TOTAL-SELLS
           END-IF
           ADD WS-COMMISSION TO WS-TOTAL-COMM
           MOVE TR-TRADE-ID TO SR-TRADE-ID
           MOVE WS-NET-AMT TO SR-NET-AMOUNT
           MOVE WS-COMMISSION TO SR-COMMISSION
           MOVE WS-SEC-FEE TO SR-FEES
           MOVE 'SETTLED ' TO SR-STATUS
           WRITE SETTLE-RECORD.
       2200-CALC-COMMISSION.
           MOVE 0.0100 TO WS-COMMISSION
           PERFORM VARYING WS-CE-IDX FROM 4 BY -1
               UNTIL WS-CE-IDX < 1
               IF TR-QTY >= WS-CE-MIN-QTY(WS-CE-IDX)
                   COMPUTE WS-COMMISSION =
                       WS-GROSS-AMT *
                       WS-CE-RATE(WS-CE-IDX)
               END-IF
           END-PERFORM.
       3000-CLOSE-FILES.
           CLOSE TRADE-FILE
           CLOSE SETTLE-FILE.
       4000-DISPLAY-SUMMARY.
           DISPLAY 'TRADE SETTLEMENT SUMMARY'
           DISPLAY '========================'
           DISPLAY 'TRADES:       ' WS-TRADE-COUNT
           DISPLAY 'TOTAL BUYS:   ' WS-TOTAL-BUYS
           DISPLAY 'TOTAL SELLS:  ' WS-TOTAL-SELLS
           DISPLAY 'TOTAL COMM:   ' WS-TOTAL-COMM.
