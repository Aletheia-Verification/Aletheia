       IDENTIFICATION DIVISION.
       PROGRAM-ID. TRUST-FEE-CALC.
      *================================================================*
      * TRUST ACCOUNT FEE CALCULATION                                  *
      * Computes tiered advisory fees, custody charges, transaction    *
      * fees, and performance-based incentives for trust accounts.     *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-TRUST.
           05 WS-TRUST-ID           PIC X(10).
           05 WS-TRUST-TYPE         PIC X(2).
               88 WS-REVOCABLE      VALUE 'RV'.
               88 WS-IRREVOCABLE    VALUE 'IR'.
               88 WS-TESTAMENTARY   VALUE 'TM'.
               88 WS-CHARITABLE     VALUE 'CH'.
           05 WS-AUM                PIC S9(13)V99 COMP-3.
           05 WS-TXN-COUNT-QTR      PIC S9(5) COMP-3.
           05 WS-LAST-QTR-RETURN    PIC S9(3)V99 COMP-3.
           05 WS-BENCHMARK-RETURN   PIC S9(3)V99 COMP-3.
       01 WS-ASSET-CLASSES.
           05 WS-AC-ENTRY OCCURS 5.
               10 WS-AC-TYPE        PIC X(10).
               10 WS-AC-VALUE       PIC S9(13)V99 COMP-3.
               10 WS-AC-PCT         PIC S9(3)V99 COMP-3.
               10 WS-AC-CUST-RATE   PIC S9(1)V9(4) COMP-3.
               10 WS-AC-CUST-FEE    PIC S9(9)V99 COMP-3.
       01 WS-ADVISORY-FEES.
           05 WS-TIER1-FEE          PIC S9(9)V99 COMP-3.
           05 WS-TIER2-FEE          PIC S9(9)V99 COMP-3.
           05 WS-TIER3-FEE          PIC S9(9)V99 COMP-3.
           05 WS-TOTAL-ADVISORY     PIC S9(9)V99 COMP-3.
       01 WS-OTHER-FEES.
           05 WS-CUSTODY-FEE        PIC S9(9)V99 COMP-3.
           05 WS-TXN-FEES           PIC S9(7)V99 COMP-3.
           05 WS-ADMIN-FEE          PIC S9(7)V99 COMP-3.
           05 WS-PERF-INCENTIVE     PIC S9(9)V99 COMP-3.
           05 WS-CHARITABLE-DISC    PIC S9(7)V99 COMP-3.
       01 WS-GRAND-TOTAL            PIC S9(11)V99 COMP-3.
       01 WS-EFFECTIVE-BPS          PIC S9(5)V99 COMP-3.
       01 WS-IDX                    PIC S9(2) COMP-3.
       01 WS-EXCESS-RETURN          PIC S9(3)V99 COMP-3.
       01 WS-TIER1-AMT              PIC S9(13)V99 COMP-3.
       01 WS-TIER2-AMT              PIC S9(13)V99 COMP-3.
       01 WS-TIER3-AMT              PIC S9(13)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-ASSETS
           PERFORM 3000-CALC-ADVISORY-FEE
           PERFORM 4000-CALC-CUSTODY-FEE
           PERFORM 5000-CALC-TXN-FEES
           PERFORM 6000-CALC-PERFORMANCE
               THRU 6500-APPLY-DISCOUNTS
           PERFORM 7000-CALC-TOTAL
           PERFORM 8000-DISPLAY-REPORT
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'TRS0001234' TO WS-TRUST-ID
           MOVE 'IR' TO WS-TRUST-TYPE
           MOVE 5200000.00 TO WS-AUM
           MOVE 145 TO WS-TXN-COUNT-QTR
           MOVE 8.25 TO WS-LAST-QTR-RETURN
           MOVE 6.50 TO WS-BENCHMARK-RETURN
           MOVE 0 TO WS-TOTAL-ADVISORY
           MOVE 0 TO WS-CUSTODY-FEE
           MOVE 0 TO WS-TXN-FEES
           MOVE 0 TO WS-PERF-INCENTIVE
           MOVE 0 TO WS-CHARITABLE-DISC.
       2000-LOAD-ASSETS.
           MOVE 'EQUITIES' TO WS-AC-TYPE(1)
           MOVE 2600000.00 TO WS-AC-VALUE(1)
           MOVE 0.0008 TO WS-AC-CUST-RATE(1)
           MOVE 'FIXED INC' TO WS-AC-TYPE(2)
           MOVE 1560000.00 TO WS-AC-VALUE(2)
           MOVE 0.0004 TO WS-AC-CUST-RATE(2)
           MOVE 'ALTERNATIV' TO WS-AC-TYPE(3)
           MOVE 520000.00 TO WS-AC-VALUE(3)
           MOVE 0.0015 TO WS-AC-CUST-RATE(3)
           MOVE 'CASH' TO WS-AC-TYPE(4)
           MOVE 260000.00 TO WS-AC-VALUE(4)
           MOVE 0.0002 TO WS-AC-CUST-RATE(4)
           MOVE 'REAL EST' TO WS-AC-TYPE(5)
           MOVE 260000.00 TO WS-AC-VALUE(5)
           MOVE 0.0012 TO WS-AC-CUST-RATE(5)
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > 5
               IF WS-AUM > 0
                   COMPUTE WS-AC-PCT(WS-IDX) ROUNDED =
                       (WS-AC-VALUE(WS-IDX) / WS-AUM)
                       * 100
               END-IF
           END-PERFORM.
       3000-CALC-ADVISORY-FEE.
           IF WS-AUM <= 1000000
               COMPUTE WS-TIER1-FEE ROUNDED =
                   WS-AUM * 0.0100
               MOVE 0 TO WS-TIER2-FEE
               MOVE 0 TO WS-TIER3-FEE
           ELSE
               IF WS-AUM <= 5000000
                   COMPUTE WS-TIER1-FEE ROUNDED =
                       1000000 * 0.0100
                   COMPUTE WS-TIER2-AMT =
                       WS-AUM - 1000000
                   COMPUTE WS-TIER2-FEE ROUNDED =
                       WS-TIER2-AMT * 0.0075
                   MOVE 0 TO WS-TIER3-FEE
               ELSE
                   COMPUTE WS-TIER1-FEE ROUNDED =
                       1000000 * 0.0100
                   COMPUTE WS-TIER2-FEE ROUNDED =
                       4000000 * 0.0075
                   COMPUTE WS-TIER3-AMT =
                       WS-AUM - 5000000
                   COMPUTE WS-TIER3-FEE ROUNDED =
                       WS-TIER3-AMT * 0.0050
               END-IF
           END-IF
           COMPUTE WS-TOTAL-ADVISORY =
               WS-TIER1-FEE + WS-TIER2-FEE + WS-TIER3-FEE.
       4000-CALC-CUSTODY-FEE.
           MOVE 0 TO WS-CUSTODY-FEE
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > 5
               COMPUTE WS-AC-CUST-FEE(WS-IDX) ROUNDED =
                   WS-AC-VALUE(WS-IDX) *
                   WS-AC-CUST-RATE(WS-IDX)
               ADD WS-AC-CUST-FEE(WS-IDX) TO
                   WS-CUSTODY-FEE
           END-PERFORM.
       5000-CALC-TXN-FEES.
           EVALUATE TRUE
               WHEN WS-TXN-COUNT-QTR > 200
                   COMPUTE WS-TXN-FEES =
                       200 * 15.00 +
                       (WS-TXN-COUNT-QTR - 200) * 10.00
               WHEN WS-TXN-COUNT-QTR > 50
                   COMPUTE WS-TXN-FEES =
                       WS-TXN-COUNT-QTR * 15.00
               WHEN OTHER
                   COMPUTE WS-TXN-FEES =
                       WS-TXN-COUNT-QTR * 20.00
           END-EVALUATE
           EVALUATE TRUE
               WHEN WS-REVOCABLE
                   COMPUTE WS-ADMIN-FEE = 500.00
               WHEN WS-IRREVOCABLE
                   COMPUTE WS-ADMIN-FEE = 750.00
               WHEN WS-TESTAMENTARY
                   COMPUTE WS-ADMIN-FEE = 1000.00
               WHEN WS-CHARITABLE
                   COMPUTE WS-ADMIN-FEE = 600.00
           END-EVALUATE.
       6000-CALC-PERFORMANCE.
           COMPUTE WS-EXCESS-RETURN =
               WS-LAST-QTR-RETURN - WS-BENCHMARK-RETURN
           IF WS-EXCESS-RETURN > 0
               COMPUTE WS-PERF-INCENTIVE ROUNDED =
                   WS-AUM * (WS-EXCESS-RETURN / 100)
                   * 0.20
           ELSE
               MOVE 0 TO WS-PERF-INCENTIVE
           END-IF.
       6500-APPLY-DISCOUNTS.
           IF WS-CHARITABLE
               COMPUTE WS-CHARITABLE-DISC ROUNDED =
                   (WS-TOTAL-ADVISORY + WS-CUSTODY-FEE)
                   * 0.15
           ELSE
               MOVE 0 TO WS-CHARITABLE-DISC
           END-IF.
       7000-CALC-TOTAL.
           COMPUTE WS-GRAND-TOTAL =
               WS-TOTAL-ADVISORY + WS-CUSTODY-FEE +
               WS-TXN-FEES + WS-ADMIN-FEE +
               WS-PERF-INCENTIVE - WS-CHARITABLE-DISC
           IF WS-AUM > 0
               COMPUTE WS-EFFECTIVE-BPS ROUNDED =
                   (WS-GRAND-TOTAL / WS-AUM) * 10000
           ELSE
               MOVE 0 TO WS-EFFECTIVE-BPS
           END-IF.
       8000-DISPLAY-REPORT.
           DISPLAY '========================================='
           DISPLAY 'TRUST FEE CALCULATION'
           DISPLAY '========================================='
           DISPLAY 'TRUST ID:        ' WS-TRUST-ID
           DISPLAY 'TYPE:            ' WS-TRUST-TYPE
           DISPLAY 'AUM:             ' WS-AUM
           DISPLAY '----- ASSETS -----'
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > 5
               DISPLAY WS-AC-TYPE(WS-IDX) ' '
                   WS-AC-VALUE(WS-IDX) ' ('
                   WS-AC-PCT(WS-IDX) '%) CUST: '
                   WS-AC-CUST-FEE(WS-IDX)
           END-PERFORM
           DISPLAY '----- FEES -----'
           DISPLAY 'ADVISORY:        ' WS-TOTAL-ADVISORY
           DISPLAY 'CUSTODY:         ' WS-CUSTODY-FEE
           DISPLAY 'TRANSACTIONS:    ' WS-TXN-FEES
           DISPLAY 'ADMIN:           ' WS-ADMIN-FEE
           DISPLAY 'PERFORMANCE:     ' WS-PERF-INCENTIVE
           DISPLAY 'DISCOUNT:        ' WS-CHARITABLE-DISC
           DISPLAY 'GRAND TOTAL:     ' WS-GRAND-TOTAL
           DISPLAY 'EFFECTIVE BPS:   ' WS-EFFECTIVE-BPS
           DISPLAY '========================================='.
