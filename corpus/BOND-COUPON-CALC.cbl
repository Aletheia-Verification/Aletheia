       IDENTIFICATION DIVISION.
       PROGRAM-ID. BOND-COUPON-CALC.
      *================================================================
      * BOND COUPON PROCESSING
      * Calculates semi-annual coupon payments, accrued interest,
      * and withholding tax for a portfolio of fixed-income bonds.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-BOND-PORTFOLIO.
           05 WS-BOND-ENTRY OCCURS 20 TIMES.
               10 WS-BP-CUSIP          PIC X(9).
               10 WS-BP-FACE           PIC S9(11)V99 COMP-3.
               10 WS-BP-COUPON-RATE    PIC S9(1)V9(6) COMP-3.
               10 WS-BP-MATURITY-DATE  PIC 9(8).
               10 WS-BP-LAST-COUPON    PIC 9(8).
               10 WS-BP-NEXT-COUPON    PIC 9(8).
               10 WS-BP-TAX-EXEMPT     PIC X(1).
                   88 BP-EXEMPT         VALUE 'Y'.
                   88 BP-TAXABLE        VALUE 'N'.
               10 WS-BP-BOND-TYPE      PIC X(1).
                   88 BT-TREASURY      VALUE 'T'.
                   88 BT-CORPORATE     VALUE 'C'.
                   88 BT-MUNICIPAL     VALUE 'M'.
                   88 BT-AGENCY        VALUE 'A'.
       01 WS-BOND-COUNT                PIC 9(2) VALUE 0.
       01 WS-IDX                       PIC 9(2).
       01 WS-CALC-FIELDS.
           05 WS-ANNUAL-COUPON         PIC S9(9)V99 COMP-3.
           05 WS-SEMI-COUPON           PIC S9(9)V99 COMP-3.
           05 WS-DAYS-ACCRUED          PIC S9(3) COMP-3.
           05 WS-DAYS-IN-PERIOD        PIC S9(3) COMP-3
               VALUE 182.
           05 WS-ACCRUED-INT           PIC S9(9)V99 COMP-3.
           05 WS-WITHHOLD-RATE         PIC S9(1)V99 COMP-3.
           05 WS-WITHHOLD-AMT          PIC S9(7)V99 COMP-3.
           05 WS-NET-COUPON            PIC S9(9)V99 COMP-3.
       01 WS-PORTFOLIO-TOTALS.
           05 WS-TOT-FACE              PIC S9(13)V99 COMP-3
               VALUE 0.
           05 WS-TOT-ANNUAL-INC        PIC S9(11)V99 COMP-3
               VALUE 0.
           05 WS-TOT-ACCRUED           PIC S9(11)V99 COMP-3
               VALUE 0.
           05 WS-TOT-WITHHOLD          PIC S9(9)V99 COMP-3
               VALUE 0.
           05 WS-TOT-NET-INC           PIC S9(11)V99 COMP-3
               VALUE 0.
           05 WS-WEIGHTED-YIELD        PIC S9(1)V9(6) COMP-3
               VALUE 0.
       01 WS-CURRENT-DATE             PIC 9(8).
       01 WS-FED-WITHHOLD-RATE        PIC S9(1)V99 COMP-3
           VALUE 0.24.
       01 WS-WEIGHT-FACTOR            PIC S9(3)V9(6) COMP-3.
       01 WS-BOND-WEIGHT              PIC S9(1)V9(6) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-SAMPLE-DATA
           PERFORM 3000-PROCESS-PORTFOLIO
           PERFORM 4000-CALC-WEIGHTED-YIELD
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           INITIALIZE WS-PORTFOLIO-TOTALS.
       2000-LOAD-SAMPLE-DATA.
           MOVE 'US912828' TO WS-BP-CUSIP(1)
           MOVE 100000.00 TO WS-BP-FACE(1)
           MOVE 0.045000 TO WS-BP-COUPON-RATE(1)
           MOVE 20280601 TO WS-BP-MATURITY-DATE(1)
           MOVE 20260101 TO WS-BP-LAST-COUPON(1)
           MOVE 20260701 TO WS-BP-NEXT-COUPON(1)
           MOVE 'N' TO WS-BP-TAX-EXEMPT(1)
           MOVE 'T' TO WS-BP-BOND-TYPE(1)
           MOVE 'AAPL01234' TO WS-BP-CUSIP(2)
           MOVE 50000.00 TO WS-BP-FACE(2)
           MOVE 0.055000 TO WS-BP-COUPON-RATE(2)
           MOVE 20300315 TO WS-BP-MATURITY-DATE(2)
           MOVE 20260115 TO WS-BP-LAST-COUPON(2)
           MOVE 20260715 TO WS-BP-NEXT-COUPON(2)
           MOVE 'N' TO WS-BP-TAX-EXEMPT(2)
           MOVE 'C' TO WS-BP-BOND-TYPE(2)
           MOVE 'NYCGO5678' TO WS-BP-CUSIP(3)
           MOVE 75000.00 TO WS-BP-FACE(3)
           MOVE 0.035000 TO WS-BP-COUPON-RATE(3)
           MOVE 20320901 TO WS-BP-MATURITY-DATE(3)
           MOVE 20260301 TO WS-BP-LAST-COUPON(3)
           MOVE 20260901 TO WS-BP-NEXT-COUPON(3)
           MOVE 'Y' TO WS-BP-TAX-EXEMPT(3)
           MOVE 'M' TO WS-BP-BOND-TYPE(3)
           MOVE 3 TO WS-BOND-COUNT.
       3000-PROCESS-PORTFOLIO.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-BOND-COUNT
               PERFORM 3100-CALC-COUPON
               PERFORM 3200-CALC-ACCRUED
               PERFORM 3300-CALC-WITHHOLDING
               PERFORM 3400-ACCUMULATE-TOTALS
           END-PERFORM.
       3100-CALC-COUPON.
           COMPUTE WS-ANNUAL-COUPON =
               WS-BP-FACE(WS-IDX) *
               WS-BP-COUPON-RATE(WS-IDX)
           COMPUTE WS-SEMI-COUPON =
               WS-ANNUAL-COUPON / 2.
       3200-CALC-ACCRUED.
           COMPUTE WS-DAYS-ACCRUED =
               WS-CURRENT-DATE - WS-BP-LAST-COUPON(WS-IDX)
           IF WS-DAYS-ACCRUED < 0
               MOVE 0 TO WS-DAYS-ACCRUED
           END-IF
           IF WS-DAYS-ACCRUED > WS-DAYS-IN-PERIOD
               MOVE WS-DAYS-IN-PERIOD TO WS-DAYS-ACCRUED
           END-IF
           COMPUTE WS-ACCRUED-INT =
               WS-SEMI-COUPON *
               (WS-DAYS-ACCRUED / WS-DAYS-IN-PERIOD).
       3300-CALC-WITHHOLDING.
           IF BP-EXEMPT(WS-IDX)
               MOVE 0 TO WS-WITHHOLD-AMT
               MOVE 0 TO WS-WITHHOLD-RATE
           ELSE
               MOVE WS-FED-WITHHOLD-RATE
                   TO WS-WITHHOLD-RATE
               COMPUTE WS-WITHHOLD-AMT =
                   WS-SEMI-COUPON * WS-WITHHOLD-RATE
           END-IF
           COMPUTE WS-NET-COUPON =
               WS-SEMI-COUPON - WS-WITHHOLD-AMT.
       3400-ACCUMULATE-TOTALS.
           ADD WS-BP-FACE(WS-IDX) TO WS-TOT-FACE
           ADD WS-ANNUAL-COUPON TO WS-TOT-ANNUAL-INC
           ADD WS-ACCRUED-INT TO WS-TOT-ACCRUED
           ADD WS-WITHHOLD-AMT TO WS-TOT-WITHHOLD
           ADD WS-NET-COUPON TO WS-TOT-NET-INC.
       4000-CALC-WEIGHTED-YIELD.
           IF WS-TOT-FACE > 0
               MOVE 0 TO WS-WEIGHTED-YIELD
               PERFORM VARYING WS-IDX FROM 1 BY 1
                   UNTIL WS-IDX > WS-BOND-COUNT
                   COMPUTE WS-BOND-WEIGHT =
                       WS-BP-FACE(WS-IDX) / WS-TOT-FACE
                   COMPUTE WS-WEIGHT-FACTOR =
                       WS-BP-COUPON-RATE(WS-IDX)
                       * WS-BOND-WEIGHT
                   ADD WS-WEIGHT-FACTOR
                       TO WS-WEIGHTED-YIELD
               END-PERFORM
           END-IF.
       5000-DISPLAY-RESULTS.
           DISPLAY 'BOND COUPON PROCESSING REPORT'
           DISPLAY '============================='
           DISPLAY 'DATE:            ' WS-CURRENT-DATE
           DISPLAY 'BONDS IN PORT:   ' WS-BOND-COUNT
           DISPLAY 'TOTAL FACE:      ' WS-TOT-FACE
           DISPLAY 'ANNUAL INCOME:   ' WS-TOT-ANNUAL-INC
           DISPLAY 'ACCRUED INT:     ' WS-TOT-ACCRUED
           DISPLAY 'WITHHOLDING:     ' WS-TOT-WITHHOLD
           DISPLAY 'NET INCOME:      ' WS-TOT-NET-INC
           DISPLAY 'WEIGHTED YIELD:  ' WS-WEIGHTED-YIELD
           DISPLAY '-----------------------------'
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-BOND-COUNT
               DISPLAY 'CUSIP: ' WS-BP-CUSIP(WS-IDX)
                   ' FACE: ' WS-BP-FACE(WS-IDX)
                   ' RATE: ' WS-BP-COUPON-RATE(WS-IDX)
           END-PERFORM.
