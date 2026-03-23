       IDENTIFICATION DIVISION.
       PROGRAM-ID. DIVIDEND-DIST-PROC.
      *================================================================
      * DIVIDEND DISTRIBUTION PROCESSOR
      * Reads shareholder positions, applies dividend rate by share
      * class, calculates withholding, and writes distribution file.
      *================================================================
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT POSITION-FILE ASSIGN TO 'SHRHLDPOS'
               FILE STATUS IS WS-POS-FS.
           SELECT DISTRIB-FILE ASSIGN TO 'DIVDIST'
               FILE STATUS IS WS-DST-FS.
       DATA DIVISION.
       FILE SECTION.
       FD POSITION-FILE.
       01 POS-RECORD.
           05 POS-ACCT-NUM             PIC X(10).
           05 POS-FUND-CODE            PIC X(6).
           05 POS-SHARE-CLASS          PIC X(1).
               88 CLASS-A              VALUE 'A'.
               88 CLASS-B              VALUE 'B'.
               88 CLASS-C              VALUE 'C'.
               88 CLASS-I              VALUE 'I'.
           05 POS-SHARES-HELD          PIC S9(11)V9(4) COMP-3.
           05 POS-TAX-STATUS           PIC X(1).
               88 TAX-REGULAR          VALUE 'R'.
               88 TAX-EXEMPT           VALUE 'E'.
               88 TAX-DEFERRED         VALUE 'D'.
           05 POS-COUNTRY-CODE         PIC X(2).
           05 POS-REINVEST-FLAG        PIC X(1).
               88 POS-REINVEST         VALUE 'Y'.
               88 POS-CASH-OUT         VALUE 'N'.
       FD DISTRIB-FILE.
       01 DST-RECORD.
           05 DST-ACCT-NUM             PIC X(10).
           05 DST-FUND-CODE            PIC X(6).
           05 DST-GROSS-AMT            PIC S9(9)V99 COMP-3.
           05 DST-WITHHOLD-AMT         PIC S9(7)V99 COMP-3.
           05 DST-NET-AMT              PIC S9(9)V99 COMP-3.
           05 DST-REINVEST-SHARES      PIC S9(9)V9(4) COMP-3.
           05 DST-DISP-CODE            PIC X(1).
       WORKING-STORAGE SECTION.
       01 WS-FILE-STATUS.
           05 WS-POS-FS               PIC X(2).
           05 WS-DST-FS               PIC X(2).
       01 WS-EOF-FLAG                 PIC X VALUE 'N'.
           88 WS-EOF                  VALUE 'Y'.
       01 WS-DIVIDEND-RATES.
           05 WS-DIV-PER-SHARE        PIC S9(3)V9(6) COMP-3.
           05 WS-INCOME-DIV           PIC S9(3)V9(6) COMP-3
               VALUE 0.125000.
           05 WS-CAP-GAIN-DIV         PIC S9(3)V9(6) COMP-3
               VALUE 0.035000.
       01 WS-CLASS-EXPENSE.
           05 WS-EXP-RATE-A           PIC S9(1)V9(4) COMP-3
               VALUE 0.0050.
           05 WS-EXP-RATE-B           PIC S9(1)V9(4) COMP-3
               VALUE 0.0100.
           05 WS-EXP-RATE-C           PIC S9(1)V9(4) COMP-3
               VALUE 0.0100.
           05 WS-EXP-RATE-I           PIC S9(1)V9(4) COMP-3
               VALUE 0.0025.
       01 WS-CALC.
           05 WS-EXPENSE-DEDUCT       PIC S9(1)V9(6) COMP-3.
           05 WS-NET-DIV-RATE         PIC S9(3)V9(6) COMP-3.
           05 WS-GROSS-DIVIDEND       PIC S9(9)V99 COMP-3.
           05 WS-WITHHOLD-RATE        PIC S9(1)V99 COMP-3.
           05 WS-WITHHOLD-AMT         PIC S9(7)V99 COMP-3.
           05 WS-NET-DIVIDEND         PIC S9(9)V99 COMP-3.
           05 WS-REINVEST-PRICE       PIC S9(5)V9(4) COMP-3
               VALUE 45.2500.
           05 WS-NEW-SHARES           PIC S9(9)V9(4) COMP-3.
       01 WS-COUNTERS.
           05 WS-READ-COUNT           PIC 9(7) VALUE 0.
           05 WS-DIST-COUNT           PIC 9(7) VALUE 0.
           05 WS-REINVEST-COUNT       PIC 9(7) VALUE 0.
           05 WS-CASHOUT-COUNT        PIC 9(7) VALUE 0.
       01 WS-TOTALS.
           05 WS-TOT-GROSS            PIC S9(13)V99 COMP-3
               VALUE 0.
           05 WS-TOT-WITHHOLD         PIC S9(11)V99 COMP-3
               VALUE 0.
           05 WS-TOT-NET              PIC S9(13)V99 COMP-3
               VALUE 0.
           05 WS-TOT-REINV-SHARES     PIC S9(13)V9(4) COMP-3
               VALUE 0.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-OPEN-FILES
           PERFORM 1500-READ-POSITION
           PERFORM 2000-PROCESS-POSITIONS
               UNTIL WS-EOF
           PERFORM 8000-DISPLAY-TOTALS
           PERFORM 9000-CLOSE-FILES
           STOP RUN.
       1000-OPEN-FILES.
           OPEN INPUT POSITION-FILE
           OPEN OUTPUT DISTRIB-FILE
           COMPUTE WS-DIV-PER-SHARE =
               WS-INCOME-DIV + WS-CAP-GAIN-DIV.
       1500-READ-POSITION.
           READ POSITION-FILE
               AT END
                   MOVE 'Y' TO WS-EOF-FLAG
           END-READ
           IF NOT WS-EOF
               ADD 1 TO WS-READ-COUNT
           END-IF.
       2000-PROCESS-POSITIONS.
           INITIALIZE DST-RECORD
           PERFORM 2100-CALC-EXPENSE-DEDUCT
           PERFORM 2200-CALC-GROSS-DIVIDEND
           PERFORM 2300-CALC-WITHHOLDING
           PERFORM 2400-CALC-NET
           PERFORM 2500-HANDLE-REINVEST
           PERFORM 3000-WRITE-DISTRIBUTION
           PERFORM 1500-READ-POSITION.
       2100-CALC-EXPENSE-DEDUCT.
           EVALUATE TRUE
               WHEN CLASS-A
                   MOVE WS-EXP-RATE-A TO WS-EXPENSE-DEDUCT
               WHEN CLASS-B
                   MOVE WS-EXP-RATE-B TO WS-EXPENSE-DEDUCT
               WHEN CLASS-C
                   MOVE WS-EXP-RATE-C TO WS-EXPENSE-DEDUCT
               WHEN CLASS-I
                   MOVE WS-EXP-RATE-I TO WS-EXPENSE-DEDUCT
               WHEN OTHER
                   MOVE WS-EXP-RATE-A TO WS-EXPENSE-DEDUCT
           END-EVALUATE
           COMPUTE WS-NET-DIV-RATE =
               WS-DIV-PER-SHARE - WS-EXPENSE-DEDUCT.
       2200-CALC-GROSS-DIVIDEND.
           COMPUTE WS-GROSS-DIVIDEND =
               POS-SHARES-HELD * WS-NET-DIV-RATE.
       2300-CALC-WITHHOLDING.
           IF TAX-EXEMPT OR TAX-DEFERRED
               MOVE 0 TO WS-WITHHOLD-AMT
               MOVE 0 TO WS-WITHHOLD-RATE
           ELSE
               IF POS-COUNTRY-CODE = 'US'
                   MOVE 0 TO WS-WITHHOLD-RATE
                   MOVE 0 TO WS-WITHHOLD-AMT
               ELSE
                   MOVE 0.30 TO WS-WITHHOLD-RATE
                   COMPUTE WS-WITHHOLD-AMT =
                       WS-GROSS-DIVIDEND * WS-WITHHOLD-RATE
               END-IF
           END-IF.
       2400-CALC-NET.
           COMPUTE WS-NET-DIVIDEND =
               WS-GROSS-DIVIDEND - WS-WITHHOLD-AMT.
       2500-HANDLE-REINVEST.
           IF POS-REINVEST
               IF WS-REINVEST-PRICE > 0
                   COMPUTE WS-NEW-SHARES =
                       WS-NET-DIVIDEND / WS-REINVEST-PRICE
               ELSE
                   MOVE 0 TO WS-NEW-SHARES
               END-IF
               ADD WS-NEW-SHARES TO WS-TOT-REINV-SHARES
               ADD 1 TO WS-REINVEST-COUNT
               MOVE 'R' TO DST-DISP-CODE
           ELSE
               MOVE 0 TO WS-NEW-SHARES
               ADD 1 TO WS-CASHOUT-COUNT
               MOVE 'C' TO DST-DISP-CODE
           END-IF.
       3000-WRITE-DISTRIBUTION.
           MOVE POS-ACCT-NUM TO DST-ACCT-NUM
           MOVE POS-FUND-CODE TO DST-FUND-CODE
           MOVE WS-GROSS-DIVIDEND TO DST-GROSS-AMT
           MOVE WS-WITHHOLD-AMT TO DST-WITHHOLD-AMT
           MOVE WS-NET-DIVIDEND TO DST-NET-AMT
           MOVE WS-NEW-SHARES TO DST-REINVEST-SHARES
           WRITE DST-RECORD
           ADD 1 TO WS-DIST-COUNT
           ADD WS-GROSS-DIVIDEND TO WS-TOT-GROSS
           ADD WS-WITHHOLD-AMT TO WS-TOT-WITHHOLD
           ADD WS-NET-DIVIDEND TO WS-TOT-NET.
       8000-DISPLAY-TOTALS.
           DISPLAY 'DIVIDEND DISTRIBUTION SUMMARY'
           DISPLAY '============================='
           DISPLAY 'POSITIONS READ:  ' WS-READ-COUNT
           DISPLAY 'DISTRIBUTIONS:   ' WS-DIST-COUNT
           DISPLAY 'REINVESTED:      ' WS-REINVEST-COUNT
           DISPLAY 'CASH PAYOUTS:    ' WS-CASHOUT-COUNT
           DISPLAY 'TOTAL GROSS:     ' WS-TOT-GROSS
           DISPLAY 'TOTAL WITHHOLD:  ' WS-TOT-WITHHOLD
           DISPLAY 'TOTAL NET:       ' WS-TOT-NET
           DISPLAY 'REINVEST SHARES: ' WS-TOT-REINV-SHARES.
       9000-CLOSE-FILES.
           CLOSE POSITION-FILE
           CLOSE DISTRIB-FILE.
