       IDENTIFICATION DIVISION.
       PROGRAM-ID. TAX-LOT-ACCT.
      *================================================================
      * TAX LOT ACCOUNTING MODULE
      * Maintains tax lot inventory with cost basis adjustments for
      * corporate actions, return of capital, and amortization.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ACCOUNT.
           05 WS-ACCT-NUM             PIC X(10).
           05 WS-TAX-YEAR             PIC 9(4).
           05 WS-ACCT-TYPE            PIC X(1).
               88 ACCT-TAXABLE        VALUE 'T'.
               88 ACCT-IRA            VALUE 'I'.
               88 ACCT-ROTH           VALUE 'R'.
       01 WS-LOT-TABLE.
           05 WS-LOT OCCURS 15 TIMES.
               10 WS-LT-SECURITY      PIC X(8).
               10 WS-LT-DATE          PIC 9(8).
               10 WS-LT-SHARES        PIC S9(9)V9(4) COMP-3.
               10 WS-LT-ORIG-COST     PIC S9(9)V99 COMP-3.
               10 WS-LT-ADJ-COST      PIC S9(9)V99 COMP-3.
               10 WS-LT-AMORT-AMT     PIC S9(7)V99 COMP-3.
               10 WS-LT-ROC-ADJ       PIC S9(7)V99 COMP-3.
               10 WS-LT-CORP-ACT-ADJ  PIC S9(7)V99 COMP-3.
               10 WS-LT-STATUS        PIC X(1).
                   88 LT-OPEN         VALUE 'O'.
                   88 LT-CLOSED       VALUE 'C'.
       01 WS-LOT-COUNT                PIC 9(2) VALUE 0.
       01 WS-IDX                      PIC 9(2).
       01 WS-JDEX                     PIC 9(2).
       01 WS-CORP-ACTION.
           05 WS-CA-TYPE              PIC X(2).
               88 CA-SPLIT            VALUE 'SP'.
               88 CA-MERGER           VALUE 'MG'.
               88 CA-SPINOFF          VALUE 'SO'.
           05 WS-CA-RATIO-NUM         PIC S9(3)V99 COMP-3.
           05 WS-CA-RATIO-DEN         PIC S9(3)V99 COMP-3.
           05 WS-CA-SECURITY          PIC X(8).
       01 WS-ROC-EVENT.
           05 WS-ROC-SECURITY         PIC X(8).
           05 WS-ROC-PER-SHARE        PIC S9(3)V9(4) COMP-3.
       01 WS-AMORT-EVENT.
           05 WS-AM-SECURITY          PIC X(8).
           05 WS-AM-ANNUAL-AMT        PIC S9(5)V99 COMP-3.
           05 WS-AM-PERIODS           PIC 9(2).
           05 WS-AM-PER-PERIOD        PIC S9(5)V99 COMP-3.
       01 WS-TOTALS.
           05 WS-TOT-OPEN-LOTS        PIC 9(3) VALUE 0.
           05 WS-TOT-ORIG-COST        PIC S9(13)V99 COMP-3
               VALUE 0.
           05 WS-TOT-ADJ-COST         PIC S9(13)V99 COMP-3
               VALUE 0.
           05 WS-TOT-SHARES           PIC S9(11)V9(4) COMP-3
               VALUE 0.
           05 WS-TOTAL-ADJUSTMENTS     PIC S9(11)V99 COMP-3
               VALUE 0.
       01 WS-TEMP-SHARES              PIC S9(9)V9(4) COMP-3.
       01 WS-TEMP-COST                PIC S9(9)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-LOAD-LOTS
           PERFORM 2000-APPLY-CORP-ACTION
           PERFORM 3000-APPLY-ROC
           PERFORM 4000-APPLY-AMORTIZATION
           PERFORM 5000-RECALC-ADJ-COST
           PERFORM 6000-SUMMARIZE
           PERFORM 7000-DISPLAY-REPORT
           STOP RUN.
       1000-LOAD-LOTS.
           MOVE 'ACC-001234' TO WS-ACCT-NUM
           MOVE 2026 TO WS-TAX-YEAR
           MOVE 'T' TO WS-ACCT-TYPE
           MOVE 'AAPL    ' TO WS-LT-SECURITY(1)
           MOVE 20230615 TO WS-LT-DATE(1)
           MOVE 200.0000 TO WS-LT-SHARES(1)
           MOVE 34000.00 TO WS-LT-ORIG-COST(1)
           MOVE 34000.00 TO WS-LT-ADJ-COST(1)
           MOVE 0 TO WS-LT-AMORT-AMT(1)
           MOVE 0 TO WS-LT-ROC-ADJ(1)
           MOVE 0 TO WS-LT-CORP-ACT-ADJ(1)
           MOVE 'O' TO WS-LT-STATUS(1)
           MOVE 'BND-FUND' TO WS-LT-SECURITY(2)
           MOVE 20240101 TO WS-LT-DATE(2)
           MOVE 500.0000 TO WS-LT-SHARES(2)
           MOVE 50000.00 TO WS-LT-ORIG-COST(2)
           MOVE 50000.00 TO WS-LT-ADJ-COST(2)
           MOVE 0 TO WS-LT-AMORT-AMT(2)
           MOVE 0 TO WS-LT-ROC-ADJ(2)
           MOVE 0 TO WS-LT-CORP-ACT-ADJ(2)
           MOVE 'O' TO WS-LT-STATUS(2)
           MOVE 'REIT-DIV' TO WS-LT-SECURITY(3)
           MOVE 20240601 TO WS-LT-DATE(3)
           MOVE 300.0000 TO WS-LT-SHARES(3)
           MOVE 15000.00 TO WS-LT-ORIG-COST(3)
           MOVE 15000.00 TO WS-LT-ADJ-COST(3)
           MOVE 0 TO WS-LT-AMORT-AMT(3)
           MOVE 0 TO WS-LT-ROC-ADJ(3)
           MOVE 0 TO WS-LT-CORP-ACT-ADJ(3)
           MOVE 'O' TO WS-LT-STATUS(3)
           MOVE 3 TO WS-LOT-COUNT.
       2000-APPLY-CORP-ACTION.
           MOVE 'SP' TO WS-CA-TYPE
           MOVE 4.00 TO WS-CA-RATIO-NUM
           MOVE 1.00 TO WS-CA-RATIO-DEN
           MOVE 'AAPL    ' TO WS-CA-SECURITY
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-LOT-COUNT
               IF WS-LT-SECURITY(WS-IDX) = WS-CA-SECURITY
                   AND LT-OPEN(WS-IDX)
                   IF CA-SPLIT
                       COMPUTE WS-TEMP-SHARES =
                           WS-LT-SHARES(WS-IDX) *
                           (WS-CA-RATIO-NUM /
                            WS-CA-RATIO-DEN)
                       COMPUTE WS-LT-CORP-ACT-ADJ(WS-IDX) =
                           WS-TEMP-SHARES -
                           WS-LT-SHARES(WS-IDX)
                       MOVE WS-TEMP-SHARES
                           TO WS-LT-SHARES(WS-IDX)
                   END-IF
               END-IF
           END-PERFORM.
       3000-APPLY-ROC.
           MOVE 'REIT-DIV' TO WS-ROC-SECURITY
           MOVE 2.5000 TO WS-ROC-PER-SHARE
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-LOT-COUNT
               IF WS-LT-SECURITY(WS-IDX) = WS-ROC-SECURITY
                   AND LT-OPEN(WS-IDX)
                   COMPUTE WS-LT-ROC-ADJ(WS-IDX) =
                       WS-LT-SHARES(WS-IDX) *
                       WS-ROC-PER-SHARE
               END-IF
           END-PERFORM.
       4000-APPLY-AMORTIZATION.
           MOVE 'BND-FUND' TO WS-AM-SECURITY
           MOVE 1200.00 TO WS-AM-ANNUAL-AMT
           MOVE 12 TO WS-AM-PERIODS
           COMPUTE WS-AM-PER-PERIOD =
               WS-AM-ANNUAL-AMT / WS-AM-PERIODS
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-LOT-COUNT
               IF WS-LT-SECURITY(WS-IDX) = WS-AM-SECURITY
                   AND LT-OPEN(WS-IDX)
                   MOVE WS-AM-ANNUAL-AMT
                       TO WS-LT-AMORT-AMT(WS-IDX)
               END-IF
           END-PERFORM.
       5000-RECALC-ADJ-COST.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-LOT-COUNT
               IF LT-OPEN(WS-IDX)
                   COMPUTE WS-LT-ADJ-COST(WS-IDX) =
                       WS-LT-ORIG-COST(WS-IDX)
                       - WS-LT-ROC-ADJ(WS-IDX)
                       - WS-LT-AMORT-AMT(WS-IDX)
                   IF WS-LT-ADJ-COST(WS-IDX) < 0
                       MOVE 0 TO WS-LT-ADJ-COST(WS-IDX)
                   END-IF
               END-IF
           END-PERFORM.
       6000-SUMMARIZE.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-LOT-COUNT
               IF LT-OPEN(WS-IDX)
                   ADD 1 TO WS-TOT-OPEN-LOTS
                   ADD WS-LT-ORIG-COST(WS-IDX)
                       TO WS-TOT-ORIG-COST
                   ADD WS-LT-ADJ-COST(WS-IDX)
                       TO WS-TOT-ADJ-COST
                   ADD WS-LT-SHARES(WS-IDX)
                       TO WS-TOT-SHARES
               END-IF
           END-PERFORM
           COMPUTE WS-TOTAL-ADJUSTMENTS =
               WS-TOT-ORIG-COST - WS-TOT-ADJ-COST.
       7000-DISPLAY-REPORT.
           DISPLAY 'TAX LOT ACCOUNTING REPORT'
           DISPLAY '========================='
           DISPLAY 'ACCOUNT:     ' WS-ACCT-NUM
           DISPLAY 'TAX YEAR:    ' WS-TAX-YEAR
           DISPLAY 'OPEN LOTS:   ' WS-TOT-OPEN-LOTS
           DISPLAY 'ORIG COST:   ' WS-TOT-ORIG-COST
           DISPLAY 'ADJ COST:    ' WS-TOT-ADJ-COST
           DISPLAY 'ADJUSTMENTS: ' WS-TOTAL-ADJUSTMENTS
           DISPLAY 'TOT SHARES:  ' WS-TOT-SHARES
           DISPLAY '-------------------------'
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-LOT-COUNT
               IF LT-OPEN(WS-IDX)
                   DISPLAY WS-LT-SECURITY(WS-IDX)
                       ' SHR: ' WS-LT-SHARES(WS-IDX)
                       ' ADJ: ' WS-LT-ADJ-COST(WS-IDX)
               END-IF
           END-PERFORM.
