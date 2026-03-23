       IDENTIFICATION DIVISION.
       PROGRAM-ID. FUND-REDEMPTION-PROC.
      *================================================================
      * MUTUAL FUND REDEMPTION PROCESSOR
      * Processes shareholder redemption requests with CDSC charges,
      * short-term trading fees, and early redemption penalties.
      *================================================================
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT REDEEM-FILE ASSIGN TO 'REDEEMRQ'
               FILE STATUS IS WS-RED-FS.
           SELECT SETTLE-FILE ASSIGN TO 'SETLOUT'
               FILE STATUS IS WS-STL-FS.
       DATA DIVISION.
       FILE SECTION.
       FD REDEEM-FILE.
       01 RED-RECORD.
           05 RED-ACCT-NUM             PIC X(10).
           05 RED-FUND-CODE            PIC X(6).
           05 RED-SHARES-REQ           PIC S9(9)V9(4) COMP-3.
           05 RED-REQUEST-DATE         PIC 9(8).
           05 RED-SHARE-CLASS          PIC X(1).
               88 RED-CLASS-A          VALUE 'A'.
               88 RED-CLASS-B          VALUE 'B'.
               88 RED-CLASS-C          VALUE 'C'.
           05 RED-PURCHASE-DATE        PIC 9(8).
           05 RED-COST-BASIS           PIC S9(9)V99 COMP-3.
       FD SETTLE-FILE.
       01 STL-RECORD.
           05 STL-ACCT-NUM             PIC X(10).
           05 STL-FUND-CODE            PIC X(6).
           05 STL-SHARES-REDEEMED      PIC S9(9)V9(4) COMP-3.
           05 STL-GROSS-PROCEEDS       PIC S9(9)V99 COMP-3.
           05 STL-CDSC-AMT             PIC S9(7)V99 COMP-3.
           05 STL-SHORT-TERM-FEE       PIC S9(5)V99 COMP-3.
           05 STL-NET-PROCEEDS         PIC S9(9)V99 COMP-3.
           05 STL-SETTLE-DATE          PIC 9(8).
       WORKING-STORAGE SECTION.
       01 WS-FILE-STATUS.
           05 WS-RED-FS               PIC X(2).
           05 WS-STL-FS               PIC X(2).
       01 WS-EOF-FLAG                 PIC X VALUE 'N'.
           88 WS-EOF                  VALUE 'Y'.
       01 WS-NAV-PER-SHARE            PIC S9(5)V9(4) COMP-3
           VALUE 47.8500.
       01 WS-CDSC-TABLE.
           05 WS-CDSC-RATE OCCURS 7 TIMES
                                       PIC S9(1)V99 COMP-3.
       01 WS-CALC.
           05 WS-GROSS-PROCEEDS       PIC S9(9)V99 COMP-3.
           05 WS-HOLD-DAYS            PIC S9(5) COMP-3.
           05 WS-HOLD-YEARS           PIC 9(2).
           05 WS-CDSC-RATE            PIC S9(1)V99 COMP-3.
           05 WS-CDSC-AMT             PIC S9(7)V99 COMP-3.
           05 WS-SHORT-TERM-DAYS      PIC 9(2) VALUE 30.
           05 WS-SHORT-FEE-RATE       PIC S9(1)V99 COMP-3
               VALUE 0.02.
           05 WS-SHORT-FEE            PIC S9(5)V99 COMP-3.
           05 WS-NET-PROCEEDS         PIC S9(9)V99 COMP-3.
           05 WS-SETTLE-DAYS          PIC 9(1) VALUE 2.
       01 WS-COUNTERS.
           05 WS-READ-COUNT           PIC 9(5) VALUE 0.
           05 WS-SETTLED-COUNT        PIC 9(5) VALUE 0.
           05 WS-CDSC-COUNT           PIC 9(5) VALUE 0.
           05 WS-SHORT-FEE-COUNT      PIC 9(5) VALUE 0.
       01 WS-TOTALS.
           05 WS-TOT-SHARES-RED       PIC S9(11)V9(4) COMP-3
               VALUE 0.
           05 WS-TOT-GROSS            PIC S9(13)V99 COMP-3
               VALUE 0.
           05 WS-TOT-CDSC             PIC S9(9)V99 COMP-3
               VALUE 0.
           05 WS-TOT-SHORT-FEES       PIC S9(7)V99 COMP-3
               VALUE 0.
           05 WS-TOT-NET              PIC S9(13)V99 COMP-3
               VALUE 0.
       01 WS-IDX                      PIC 9(1).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-OPEN-FILES
           PERFORM 1100-INIT-CDSC-TABLE
           PERFORM 1500-READ-REDEEM
           PERFORM 2000-PROCESS-REDEMPTIONS
               UNTIL WS-EOF
           PERFORM 8000-DISPLAY-TOTALS
           PERFORM 9000-CLOSE-FILES
           STOP RUN.
       1000-OPEN-FILES.
           OPEN INPUT REDEEM-FILE
           OPEN OUTPUT SETTLE-FILE.
       1100-INIT-CDSC-TABLE.
           MOVE 0.05 TO WS-CDSC-RATE(1)
           MOVE 0.04 TO WS-CDSC-RATE(2)
           MOVE 0.03 TO WS-CDSC-RATE(3)
           MOVE 0.02 TO WS-CDSC-RATE(4)
           MOVE 0.01 TO WS-CDSC-RATE(5)
           MOVE 0.01 TO WS-CDSC-RATE(6)
           MOVE 0.00 TO WS-CDSC-RATE(7).
       1500-READ-REDEEM.
           READ REDEEM-FILE
               AT END
                   MOVE 'Y' TO WS-EOF-FLAG
           END-READ
           IF NOT WS-EOF
               ADD 1 TO WS-READ-COUNT
           END-IF.
       2000-PROCESS-REDEMPTIONS.
           INITIALIZE STL-RECORD
           PERFORM 2100-CALC-GROSS
           PERFORM 2200-CALC-CDSC
           PERFORM 2300-CALC-SHORT-TERM-FEE
           PERFORM 2400-CALC-NET
           PERFORM 3000-WRITE-SETTLEMENT
           PERFORM 1500-READ-REDEEM.
       2100-CALC-GROSS.
           COMPUTE WS-GROSS-PROCEEDS =
               RED-SHARES-REQ * WS-NAV-PER-SHARE.
       2200-CALC-CDSC.
           MOVE 0 TO WS-CDSC-AMT
           IF RED-CLASS-B
               COMPUTE WS-HOLD-DAYS =
                   RED-REQUEST-DATE - RED-PURCHASE-DATE
               COMPUTE WS-HOLD-YEARS =
                   WS-HOLD-DAYS / 365
               IF WS-HOLD-YEARS < 1
                   MOVE 1 TO WS-HOLD-YEARS
               END-IF
               IF WS-HOLD-YEARS <= 7
                   MOVE WS-CDSC-RATE(WS-HOLD-YEARS)
                       TO WS-CDSC-RATE
               ELSE
                   MOVE 0 TO WS-CDSC-RATE
               END-IF
               COMPUTE WS-CDSC-AMT =
                   WS-GROSS-PROCEEDS * WS-CDSC-RATE
               IF WS-CDSC-AMT > 0
                   ADD 1 TO WS-CDSC-COUNT
               END-IF
           END-IF.
       2300-CALC-SHORT-TERM-FEE.
           MOVE 0 TO WS-SHORT-FEE
           COMPUTE WS-HOLD-DAYS =
               RED-REQUEST-DATE - RED-PURCHASE-DATE
           IF WS-HOLD-DAYS <= WS-SHORT-TERM-DAYS
               COMPUTE WS-SHORT-FEE =
                   WS-GROSS-PROCEEDS * WS-SHORT-FEE-RATE
               ADD 1 TO WS-SHORT-FEE-COUNT
           END-IF.
       2400-CALC-NET.
           COMPUTE WS-NET-PROCEEDS =
               WS-GROSS-PROCEEDS
               - WS-CDSC-AMT
               - WS-SHORT-FEE.
       3000-WRITE-SETTLEMENT.
           MOVE RED-ACCT-NUM TO STL-ACCT-NUM
           MOVE RED-FUND-CODE TO STL-FUND-CODE
           MOVE RED-SHARES-REQ TO STL-SHARES-REDEEMED
           MOVE WS-GROSS-PROCEEDS TO STL-GROSS-PROCEEDS
           MOVE WS-CDSC-AMT TO STL-CDSC-AMT
           MOVE WS-SHORT-FEE TO STL-SHORT-TERM-FEE
           MOVE WS-NET-PROCEEDS TO STL-NET-PROCEEDS
           COMPUTE STL-SETTLE-DATE =
               RED-REQUEST-DATE + WS-SETTLE-DAYS
           WRITE STL-RECORD
           ADD 1 TO WS-SETTLED-COUNT
           ADD RED-SHARES-REQ TO WS-TOT-SHARES-RED
           ADD WS-GROSS-PROCEEDS TO WS-TOT-GROSS
           ADD WS-CDSC-AMT TO WS-TOT-CDSC
           ADD WS-SHORT-FEE TO WS-TOT-SHORT-FEES
           ADD WS-NET-PROCEEDS TO WS-TOT-NET.
       8000-DISPLAY-TOTALS.
           DISPLAY 'FUND REDEMPTION PROCESSING REPORT'
           DISPLAY '=================================='
           DISPLAY 'REQUESTS READ:   ' WS-READ-COUNT
           DISPLAY 'SETTLED:         ' WS-SETTLED-COUNT
           DISPLAY 'CDSC CHARGED:    ' WS-CDSC-COUNT
           DISPLAY 'SHORT-TERM FEE:  ' WS-SHORT-FEE-COUNT
           DISPLAY 'TOTAL SHARES:    ' WS-TOT-SHARES-RED
           DISPLAY 'TOTAL GROSS:     ' WS-TOT-GROSS
           DISPLAY 'TOTAL CDSC:      ' WS-TOT-CDSC
           DISPLAY 'TOTAL SHORT FEE: ' WS-TOT-SHORT-FEES
           DISPLAY 'TOTAL NET:       ' WS-TOT-NET.
       9000-CLOSE-FILES.
           CLOSE REDEEM-FILE
           CLOSE SETTLE-FILE.
