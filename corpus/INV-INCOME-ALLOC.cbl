       IDENTIFICATION DIVISION.
       PROGRAM-ID. INV-INCOME-ALLOC.
      *================================================================
      * INVESTMENT INCOME ALLOCATOR
      * Allocates fund income (interest, dividends, capital gains)
      * across investor accounts based on daily average share balance.
      *================================================================
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT INVESTOR-FILE ASSIGN TO 'INVFILE'
               FILE STATUS IS WS-INV-FS.
           SELECT ALLOC-FILE ASSIGN TO 'ALLOCOUT'
               FILE STATUS IS WS-ALC-FS.
       DATA DIVISION.
       FILE SECTION.
       FD INVESTOR-FILE.
       01 INV-RECORD.
           05 INV-ACCT-NUM            PIC X(10).
           05 INV-FUND-CODE           PIC X(6).
           05 INV-AVG-SHARES          PIC S9(11)V9(4) COMP-3.
           05 INV-TAX-STATUS          PIC X(1).
               88 TS-TAXABLE          VALUE 'T'.
               88 TS-TAX-EXEMPT       VALUE 'E'.
               88 TS-RETIREMENT       VALUE 'R'.
       FD ALLOC-FILE.
       01 ALC-RECORD.
           05 ALC-ACCT-NUM            PIC X(10).
           05 ALC-FUND-CODE           PIC X(6).
           05 ALC-INT-INCOME          PIC S9(9)V99 COMP-3.
           05 ALC-DIV-INCOME          PIC S9(9)V99 COMP-3.
           05 ALC-ST-GAIN             PIC S9(9)V99 COMP-3.
           05 ALC-LT-GAIN             PIC S9(9)V99 COMP-3.
           05 ALC-TOTAL               PIC S9(9)V99 COMP-3.
       WORKING-STORAGE SECTION.
       01 WS-FILE-STATUS.
           05 WS-INV-FS              PIC X(2).
           05 WS-ALC-FS              PIC X(2).
       01 WS-EOF-FLAG                PIC X VALUE 'N'.
           88 WS-EOF                 VALUE 'Y'.
       01 WS-FUND-INCOME.
           05 WS-FUND-TOTAL-SHARES   PIC S9(13)V9(4) COMP-3
               VALUE 0.
           05 WS-FUND-INT-POOL       PIC S9(11)V99 COMP-3.
           05 WS-FUND-DIV-POOL       PIC S9(11)V99 COMP-3.
           05 WS-FUND-ST-POOL        PIC S9(11)V99 COMP-3.
           05 WS-FUND-LT-POOL        PIC S9(11)V99 COMP-3.
       01 WS-PER-SHARE-RATES.
           05 WS-INT-PER-SHARE       PIC S9(3)V9(8) COMP-3.
           05 WS-DIV-PER-SHARE       PIC S9(3)V9(8) COMP-3.
           05 WS-ST-PER-SHARE        PIC S9(3)V9(8) COMP-3.
           05 WS-LT-PER-SHARE        PIC S9(3)V9(8) COMP-3.
       01 WS-INVESTOR-ALLOC.
           05 WS-IA-INT               PIC S9(9)V99 COMP-3.
           05 WS-IA-DIV               PIC S9(9)V99 COMP-3.
           05 WS-IA-ST                PIC S9(9)V99 COMP-3.
           05 WS-IA-LT                PIC S9(9)V99 COMP-3.
           05 WS-IA-TOTAL             PIC S9(9)V99 COMP-3.
       01 WS-COUNTERS.
           05 WS-READ-COUNT          PIC 9(5) VALUE 0.
           05 WS-ALLOC-COUNT         PIC 9(5) VALUE 0.
       01 WS-TOTALS.
           05 WS-TOT-ALLOCATED       PIC S9(13)V99 COMP-3
               VALUE 0.
           05 WS-TOT-POOL            PIC S9(13)V99 COMP-3.
           05 WS-ROUNDING-ADJ        PIC S9(7)V99 COMP-3.
       01 WS-ALLOC-DATE              PIC 9(8).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-OPEN-FILES
           PERFORM 1100-SETUP-FUND-INCOME
           PERFORM 1200-FIRST-PASS-TOTAL-SHARES
           PERFORM 1300-CALC-PER-SHARE-RATES
           PERFORM 1500-READ-INVESTOR
           PERFORM 2000-ALLOCATE-INCOME
               UNTIL WS-EOF
           PERFORM 3000-CALC-ROUNDING
           PERFORM 8000-DISPLAY-SUMMARY
           PERFORM 9000-CLOSE-FILES
           STOP RUN.
       1000-OPEN-FILES.
           OPEN INPUT INVESTOR-FILE
           OPEN OUTPUT ALLOC-FILE
           ACCEPT WS-ALLOC-DATE FROM DATE YYYYMMDD.
       1100-SETUP-FUND-INCOME.
           MOVE 1250000.00 TO WS-FUND-INT-POOL
           MOVE 850000.00 TO WS-FUND-DIV-POOL
           MOVE 320000.00 TO WS-FUND-ST-POOL
           MOVE 575000.00 TO WS-FUND-LT-POOL.
       1200-FIRST-PASS-TOTAL-SHARES.
           MOVE 5000000.0000 TO WS-FUND-TOTAL-SHARES.
       1300-CALC-PER-SHARE-RATES.
           IF WS-FUND-TOTAL-SHARES > 0
               COMPUTE WS-INT-PER-SHARE =
                   WS-FUND-INT-POOL /
                   WS-FUND-TOTAL-SHARES
               COMPUTE WS-DIV-PER-SHARE =
                   WS-FUND-DIV-POOL /
                   WS-FUND-TOTAL-SHARES
               COMPUTE WS-ST-PER-SHARE =
                   WS-FUND-ST-POOL /
                   WS-FUND-TOTAL-SHARES
               COMPUTE WS-LT-PER-SHARE =
                   WS-FUND-LT-POOL /
                   WS-FUND-TOTAL-SHARES
           ELSE
               MOVE 0 TO WS-INT-PER-SHARE
               MOVE 0 TO WS-DIV-PER-SHARE
               MOVE 0 TO WS-ST-PER-SHARE
               MOVE 0 TO WS-LT-PER-SHARE
           END-IF.
       1500-READ-INVESTOR.
           READ INVESTOR-FILE
               AT END
                   MOVE 'Y' TO WS-EOF-FLAG
           END-READ
           IF NOT WS-EOF
               ADD 1 TO WS-READ-COUNT
           END-IF.
       2000-ALLOCATE-INCOME.
           COMPUTE WS-IA-INT =
               INV-AVG-SHARES * WS-INT-PER-SHARE
           COMPUTE WS-IA-DIV =
               INV-AVG-SHARES * WS-DIV-PER-SHARE
           COMPUTE WS-IA-ST =
               INV-AVG-SHARES * WS-ST-PER-SHARE
           COMPUTE WS-IA-LT =
               INV-AVG-SHARES * WS-LT-PER-SHARE
           COMPUTE WS-IA-TOTAL =
               WS-IA-INT + WS-IA-DIV
               + WS-IA-ST + WS-IA-LT
           PERFORM 2500-WRITE-ALLOC
           PERFORM 1500-READ-INVESTOR.
       2500-WRITE-ALLOC.
           MOVE INV-ACCT-NUM TO ALC-ACCT-NUM
           MOVE INV-FUND-CODE TO ALC-FUND-CODE
           MOVE WS-IA-INT TO ALC-INT-INCOME
           MOVE WS-IA-DIV TO ALC-DIV-INCOME
           MOVE WS-IA-ST TO ALC-ST-GAIN
           MOVE WS-IA-LT TO ALC-LT-GAIN
           MOVE WS-IA-TOTAL TO ALC-TOTAL
           WRITE ALC-RECORD
           ADD 1 TO WS-ALLOC-COUNT
           ADD WS-IA-TOTAL TO WS-TOT-ALLOCATED.
       3000-CALC-ROUNDING.
           COMPUTE WS-TOT-POOL =
               WS-FUND-INT-POOL + WS-FUND-DIV-POOL
               + WS-FUND-ST-POOL + WS-FUND-LT-POOL
           COMPUTE WS-ROUNDING-ADJ =
               WS-TOT-POOL - WS-TOT-ALLOCATED.
       8000-DISPLAY-SUMMARY.
           DISPLAY 'INCOME ALLOCATION SUMMARY'
           DISPLAY '========================='
           DISPLAY 'ALLOC DATE:      ' WS-ALLOC-DATE
           DISPLAY 'INVESTORS READ:  ' WS-READ-COUNT
           DISPLAY 'ALLOCATIONS:     ' WS-ALLOC-COUNT
           DISPLAY 'INT POOL:        ' WS-FUND-INT-POOL
           DISPLAY 'DIV POOL:        ' WS-FUND-DIV-POOL
           DISPLAY 'ST GAIN POOL:    ' WS-FUND-ST-POOL
           DISPLAY 'LT GAIN POOL:    ' WS-FUND-LT-POOL
           DISPLAY 'TOTAL POOL:      ' WS-TOT-POOL
           DISPLAY 'TOTAL ALLOCATED: ' WS-TOT-ALLOCATED
           DISPLAY 'ROUNDING ADJ:    ' WS-ROUNDING-ADJ.
       9000-CLOSE-FILES.
           CLOSE INVESTOR-FILE
           CLOSE ALLOC-FILE.
