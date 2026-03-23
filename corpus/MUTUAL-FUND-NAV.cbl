       IDENTIFICATION DIVISION.
       PROGRAM-ID. MUTUAL-FUND-NAV.
      *================================================================
      * MUTUAL FUND NAV COMPUTATION
      * Calculates Net Asset Value per share from total assets,
      * liabilities, expenses, and outstanding shares.
      *================================================================
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT HOLDING-FILE ASSIGN TO 'FUNDHOLD'
               FILE STATUS IS WS-HLD-FS.
           SELECT NAV-REPORT ASSIGN TO 'NAVRPT'
               FILE STATUS IS WS-RPT-FS.
       DATA DIVISION.
       FILE SECTION.
       FD HOLDING-FILE.
       01 HLD-RECORD.
           05 HLD-FUND-ID             PIC X(8).
           05 HLD-SECURITY-ID         PIC X(12).
           05 HLD-SHARES              PIC S9(11)V9(4) COMP-3.
           05 HLD-PRICE               PIC S9(7)V9(4) COMP-3.
           05 HLD-SECTOR              PIC X(3).
               88 SEC-EQUITY          VALUE 'EQT'.
               88 SEC-BOND            VALUE 'BND'.
               88 SEC-CASH            VALUE 'CSH'.
               88 SEC-OTHER           VALUE 'OTH'.
       FD NAV-REPORT.
       01 RPT-RECORD                  PIC X(120).
       WORKING-STORAGE SECTION.
       01 WS-FILE-STATUS.
           05 WS-HLD-FS              PIC X(2).
           05 WS-RPT-FS              PIC X(2).
       01 WS-EOF-FLAG                 PIC X VALUE 'N'.
           88 WS-EOF                  VALUE 'Y'.
       01 WS-FUND-TOTALS.
           05 WS-TOTAL-ASSETS         PIC S9(13)V99 COMP-3
               VALUE 0.
           05 WS-EQUITY-VALUE         PIC S9(13)V99 COMP-3
               VALUE 0.
           05 WS-BOND-VALUE           PIC S9(13)V99 COMP-3
               VALUE 0.
           05 WS-CASH-VALUE           PIC S9(13)V99 COMP-3
               VALUE 0.
           05 WS-OTHER-VALUE          PIC S9(13)V99 COMP-3
               VALUE 0.
       01 WS-LIABILITIES.
           05 WS-ACCRUED-FEES         PIC S9(9)V99 COMP-3
               VALUE 0.
           05 WS-PENDING-REDEEM       PIC S9(11)V99 COMP-3
               VALUE 0.
           05 WS-OTHER-LIAB           PIC S9(9)V99 COMP-3
               VALUE 0.
           05 WS-TOTAL-LIAB           PIC S9(11)V99 COMP-3.
       01 WS-EXPENSES.
           05 WS-MGMT-FEE-RATE        PIC S9(1)V9(4) COMP-3
               VALUE 0.0075.
           05 WS-ADMIN-FEE-RATE       PIC S9(1)V9(4) COMP-3
               VALUE 0.0015.
           05 WS-12B1-FEE-RATE        PIC S9(1)V9(4) COMP-3
               VALUE 0.0025.
           05 WS-TOTAL-EXP-RATE       PIC S9(1)V9(4) COMP-3.
           05 WS-DAILY-EXP-RATE       PIC S9(1)V9(8) COMP-3.
           05 WS-DAILY-EXPENSE        PIC S9(9)V99 COMP-3.
       01 WS-NAV-CALC.
           05 WS-NET-ASSETS           PIC S9(13)V99 COMP-3.
           05 WS-SHARES-OUTSTANDING   PIC S9(11)V9(4) COMP-3.
           05 WS-NAV-PER-SHARE        PIC S9(5)V9(4) COMP-3.
           05 WS-PRIOR-NAV            PIC S9(5)V9(4) COMP-3.
           05 WS-NAV-CHANGE           PIC S9(5)V9(4) COMP-3.
           05 WS-NAV-CHANGE-PCT       PIC S9(3)V9(4) COMP-3.
       01 WS-HOLDING-VALUE            PIC S9(13)V99 COMP-3.
       01 WS-HOLDING-COUNT            PIC 9(5) VALUE 0.
       01 WS-SECTOR-PCTS.
           05 WS-EQT-PCT              PIC S9(3)V99 COMP-3.
           05 WS-BND-PCT              PIC S9(3)V99 COMP-3.
           05 WS-CSH-PCT              PIC S9(3)V99 COMP-3.
           05 WS-OTH-PCT              PIC S9(3)V99 COMP-3.
       01 WS-RPT-LINE                 PIC X(120).
       01 WS-CALC-DATE                PIC 9(8).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-OPEN-FILES
           PERFORM 1500-READ-HOLDING
           PERFORM 2000-ACCUMULATE-HOLDINGS
               UNTIL WS-EOF
           PERFORM 3000-CALC-EXPENSES
           PERFORM 4000-CALC-NAV
           PERFORM 5000-CALC-SECTOR-PCTS
           PERFORM 6000-WRITE-REPORT
           PERFORM 9000-CLOSE-FILES
           STOP RUN.
       1000-OPEN-FILES.
           OPEN INPUT HOLDING-FILE
           OPEN OUTPUT NAV-REPORT
           ACCEPT WS-CALC-DATE FROM DATE YYYYMMDD
           MOVE 1000000.0000 TO WS-SHARES-OUTSTANDING
           MOVE 25.3400 TO WS-PRIOR-NAV.
       1500-READ-HOLDING.
           READ HOLDING-FILE
               AT END
                   MOVE 'Y' TO WS-EOF-FLAG
           END-READ.
       2000-ACCUMULATE-HOLDINGS.
           ADD 1 TO WS-HOLDING-COUNT
           COMPUTE WS-HOLDING-VALUE =
               HLD-SHARES * HLD-PRICE
           ADD WS-HOLDING-VALUE TO WS-TOTAL-ASSETS
           EVALUATE TRUE
               WHEN SEC-EQUITY
                   ADD WS-HOLDING-VALUE TO WS-EQUITY-VALUE
               WHEN SEC-BOND
                   ADD WS-HOLDING-VALUE TO WS-BOND-VALUE
               WHEN SEC-CASH
                   ADD WS-HOLDING-VALUE TO WS-CASH-VALUE
               WHEN OTHER
                   ADD WS-HOLDING-VALUE TO WS-OTHER-VALUE
           END-EVALUATE
           PERFORM 1500-READ-HOLDING.
       3000-CALC-EXPENSES.
           COMPUTE WS-TOTAL-EXP-RATE =
               WS-MGMT-FEE-RATE
               + WS-ADMIN-FEE-RATE
               + WS-12B1-FEE-RATE
           COMPUTE WS-DAILY-EXP-RATE =
               WS-TOTAL-EXP-RATE / 365
           COMPUTE WS-DAILY-EXPENSE =
               WS-TOTAL-ASSETS * WS-DAILY-EXP-RATE
           COMPUTE WS-ACCRUED-FEES =
               WS-DAILY-EXPENSE.
       4000-CALC-NAV.
           COMPUTE WS-TOTAL-LIAB =
               WS-ACCRUED-FEES
               + WS-PENDING-REDEEM
               + WS-OTHER-LIAB
           COMPUTE WS-NET-ASSETS =
               WS-TOTAL-ASSETS - WS-TOTAL-LIAB
           IF WS-SHARES-OUTSTANDING > 0
               COMPUTE WS-NAV-PER-SHARE =
                   WS-NET-ASSETS / WS-SHARES-OUTSTANDING
           ELSE
               MOVE 0 TO WS-NAV-PER-SHARE
           END-IF
           COMPUTE WS-NAV-CHANGE =
               WS-NAV-PER-SHARE - WS-PRIOR-NAV
           IF WS-PRIOR-NAV > 0
               COMPUTE WS-NAV-CHANGE-PCT =
                   (WS-NAV-CHANGE / WS-PRIOR-NAV) * 100
           ELSE
               MOVE 0 TO WS-NAV-CHANGE-PCT
           END-IF.
       5000-CALC-SECTOR-PCTS.
           IF WS-TOTAL-ASSETS > 0
               COMPUTE WS-EQT-PCT =
                   (WS-EQUITY-VALUE / WS-TOTAL-ASSETS) * 100
               COMPUTE WS-BND-PCT =
                   (WS-BOND-VALUE / WS-TOTAL-ASSETS) * 100
               COMPUTE WS-CSH-PCT =
                   (WS-CASH-VALUE / WS-TOTAL-ASSETS) * 100
               COMPUTE WS-OTH-PCT =
                   (WS-OTHER-VALUE / WS-TOTAL-ASSETS) * 100
           ELSE
               MOVE 0 TO WS-EQT-PCT
               MOVE 0 TO WS-BND-PCT
               MOVE 0 TO WS-CSH-PCT
               MOVE 0 TO WS-OTH-PCT
           END-IF.
       6000-WRITE-REPORT.
           DISPLAY 'MUTUAL FUND NAV REPORT'
           DISPLAY '======================'
           DISPLAY 'DATE:           ' WS-CALC-DATE
           DISPLAY 'HOLDINGS:       ' WS-HOLDING-COUNT
           DISPLAY 'TOTAL ASSETS:   ' WS-TOTAL-ASSETS
           DISPLAY 'TOTAL LIAB:     ' WS-TOTAL-LIAB
           DISPLAY 'NET ASSETS:     ' WS-NET-ASSETS
           DISPLAY 'SHARES OUT:     ' WS-SHARES-OUTSTANDING
           DISPLAY 'NAV/SHARE:      ' WS-NAV-PER-SHARE
           DISPLAY 'PRIOR NAV:      ' WS-PRIOR-NAV
           DISPLAY 'CHANGE:         ' WS-NAV-CHANGE
           DISPLAY 'CHANGE PCT:     ' WS-NAV-CHANGE-PCT
           DISPLAY 'EQUITY %:       ' WS-EQT-PCT
           DISPLAY 'BOND %:         ' WS-BND-PCT
           DISPLAY 'CASH %:         ' WS-CSH-PCT.
       9000-CLOSE-FILES.
           CLOSE HOLDING-FILE
           CLOSE NAV-REPORT.
