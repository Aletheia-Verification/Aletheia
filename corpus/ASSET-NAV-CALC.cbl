       IDENTIFICATION DIVISION.
       PROGRAM-ID. ASSET-NAV-CALC.
      *================================================================*
      * Asset Management NAV Calculator                                 *
      * Computes Net Asset Value for fund portfolios, applies           *
      * management/performance fees, and generates pricing records.     *
      *================================================================*
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT HOLDING-FILE ASSIGN TO 'HOLDINGS.DAT'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-HLD-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD  HOLDING-FILE.
       01  HOLDING-RECORD.
           05  HR-FUND-ID           PIC X(08).
           05  HR-SECURITY-ID       PIC X(12).
           05  HR-SEC-TYPE          PIC X(02).
           05  HR-QUANTITY           PIC S9(11)V9(04).
           05  HR-COST-BASIS         PIC S9(11)V99.
           05  HR-MARKET-PRICE       PIC S9(07)V9(06).
           05  HR-ACCRUED-INC        PIC S9(09)V99.
           05  HR-UNREALIZED-GL      PIC S9(11)V99.
       WORKING-STORAGE SECTION.
       01  WS-HLD-STATUS           PIC XX VALUE SPACES.
       01  WS-EOF                  PIC X VALUE 'N'.
           88  END-OF-FILE         VALUE 'Y'.
       01  WS-MARKET-VALUE         PIC S9(15)V99.
       01  WS-TOTAL-MV             PIC S9(15)V99 VALUE 0.
       01  WS-TOTAL-COST           PIC S9(15)V99 VALUE 0.
       01  WS-TOTAL-ACCRUED        PIC S9(13)V99 VALUE 0.
       01  WS-TOTAL-UGL            PIC S9(15)V99 VALUE 0.
       01  WS-GROSS-ASSETS         PIC S9(15)V99.
       01  WS-LIABILITIES          PIC S9(13)V99 VALUE 50000.00.
       01  WS-NET-ASSETS           PIC S9(15)V99.
       01  WS-SHARES-OUTSTAND      PIC S9(11)V9(04)
                                   VALUE 1000000.0000.
       01  WS-NAV-PER-SHARE        PIC S9(07)V9(06).
       01  WS-PRIOR-NAV            PIC S9(07)V9(06)
                                   VALUE 25.340000.
       01  WS-DAY-RETURN           PIC S9(03)V9(06).
       01  WS-MGMT-FEE-RATE        PIC 9V9(06) VALUE 0.007500.
       01  WS-PERF-FEE-RATE        PIC 9V9(04) VALUE 0.2000.
       01  WS-DAILY-MGMT-FEE       PIC S9(09)V99.
       01  WS-PERF-FEE             PIC S9(11)V99.
       01  WS-HWM                  PIC S9(07)V9(06)
                                   VALUE 26.000000.
       01  WS-EXCESS-RETURN        PIC S9(07)V9(06).
       01  WS-HOLDING-CNT          PIC 9(06) VALUE 0.
       01  WS-EQUITY-CNT           PIC 9(06) VALUE 0.
       01  WS-BOND-CNT             PIC 9(06) VALUE 0.
       01  WS-OTHER-CNT            PIC 9(06) VALUE 0.
       01  WS-EQUITY-MV            PIC S9(15)V99 VALUE 0.
       01  WS-BOND-MV              PIC S9(15)V99 VALUE 0.
       01  WS-EQUITY-PCT           PIC 9(03)V99.
       01  WS-BOND-PCT             PIC 9(03)V99.
       01  WS-CURRENT-DATE.
           05  WS-CUR-YEAR         PIC 9(04).
           05  WS-CUR-MONTH        PIC 9(02).
           05  WS-CUR-DAY          PIC 9(02).
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PROCESS-HOLDINGS UNTIL END-OF-FILE
           PERFORM 5000-CALC-NAV
           PERFORM 6000-CALC-FEES
           PERFORM 7000-CALC-ALLOCATION
           PERFORM 9000-REPORT
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           OPEN INPUT HOLDING-FILE
           IF WS-HLD-STATUS NOT = '00'
               DISPLAY 'HOLDING FILE ERROR: ' WS-HLD-STATUS
               STOP RUN
           END-IF
           PERFORM 1100-READ-HOLDING.
       1100-READ-HOLDING.
           READ HOLDING-FILE
               AT END SET END-OF-FILE TO TRUE
           END-READ.
       2000-PROCESS-HOLDINGS.
           ADD 1 TO WS-HOLDING-CNT
           COMPUTE WS-MARKET-VALUE ROUNDED =
               HR-QUANTITY * HR-MARKET-PRICE
           ADD WS-MARKET-VALUE TO WS-TOTAL-MV
           ADD HR-COST-BASIS TO WS-TOTAL-COST
           ADD HR-ACCRUED-INC TO WS-TOTAL-ACCRUED
           COMPUTE HR-UNREALIZED-GL =
               WS-MARKET-VALUE - HR-COST-BASIS
           ADD HR-UNREALIZED-GL TO WS-TOTAL-UGL
           EVALUATE HR-SEC-TYPE
               WHEN 'EQ'
                   ADD 1 TO WS-EQUITY-CNT
                   ADD WS-MARKET-VALUE TO WS-EQUITY-MV
               WHEN 'BD'
                   ADD 1 TO WS-BOND-CNT
                   ADD WS-MARKET-VALUE TO WS-BOND-MV
               WHEN 'MF'
                   ADD 1 TO WS-EQUITY-CNT
                   ADD WS-MARKET-VALUE TO WS-EQUITY-MV
               WHEN OTHER
                   ADD 1 TO WS-OTHER-CNT
           END-EVALUATE
           PERFORM 1100-READ-HOLDING.
       5000-CALC-NAV.
           COMPUTE WS-GROSS-ASSETS =
               WS-TOTAL-MV + WS-TOTAL-ACCRUED
           COMPUTE WS-NET-ASSETS =
               WS-GROSS-ASSETS - WS-LIABILITIES
           IF WS-SHARES-OUTSTAND > ZERO
               COMPUTE WS-NAV-PER-SHARE ROUNDED =
                   WS-NET-ASSETS / WS-SHARES-OUTSTAND
           ELSE
               MOVE ZERO TO WS-NAV-PER-SHARE
           END-IF
           IF WS-PRIOR-NAV > ZERO
               COMPUTE WS-DAY-RETURN ROUNDED =
                   ((WS-NAV-PER-SHARE - WS-PRIOR-NAV)
                   / WS-PRIOR-NAV) * 100
           END-IF.
       6000-CALC-FEES.
           COMPUTE WS-DAILY-MGMT-FEE ROUNDED =
               WS-NET-ASSETS * WS-MGMT-FEE-RATE / 365
           IF WS-NAV-PER-SHARE > WS-HWM
               COMPUTE WS-EXCESS-RETURN =
                   WS-NAV-PER-SHARE - WS-HWM
               COMPUTE WS-PERF-FEE ROUNDED =
                   WS-EXCESS-RETURN * WS-SHARES-OUTSTAND
                   * WS-PERF-FEE-RATE
           ELSE
               MOVE ZERO TO WS-PERF-FEE
           END-IF.
       7000-CALC-ALLOCATION.
           IF WS-TOTAL-MV > ZERO
               COMPUTE WS-EQUITY-PCT ROUNDED =
                   (WS-EQUITY-MV / WS-TOTAL-MV) * 100
               COMPUTE WS-BOND-PCT ROUNDED =
                   (WS-BOND-MV / WS-TOTAL-MV) * 100
           END-IF.
       9000-REPORT.
           CLOSE HOLDING-FILE
           DISPLAY 'NAV CALCULATION COMPLETE'
           DISPLAY 'HOLDINGS:   ' WS-HOLDING-CNT
           DISPLAY 'TOTAL MV:   ' WS-TOTAL-MV
           DISPLAY 'NET ASSETS:  ' WS-NET-ASSETS
           DISPLAY 'NAV/SHARE:   ' WS-NAV-PER-SHARE
           DISPLAY 'DAY RETURN:  ' WS-DAY-RETURN '%'
           DISPLAY 'MGMT FEE:    ' WS-DAILY-MGMT-FEE
           DISPLAY 'PERF FEE:    ' WS-PERF-FEE
           DISPLAY 'EQUITY %:    ' WS-EQUITY-PCT
           DISPLAY 'BOND %:      ' WS-BOND-PCT.
