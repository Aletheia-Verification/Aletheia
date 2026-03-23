       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-SQL-PORTFOLIO.
      *================================================================*
      * MANUAL REVIEW: EMBEDDED SQL PORTFOLIO QUERY                    *
      * Uses EXEC SQL for portfolio valuation queries against DB2.     *
      * Fetches positions, prices, and computes portfolio metrics.     *
      * EXEC SQL triggers REQUIRES_MANUAL_REVIEW.                     *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-PORTFOLIO-ID           PIC X(10).
       01 WS-ACCT-NAME              PIC X(30).
       01 WS-SQLCODE                PIC S9(9) COMP.
           EXEC SQL INCLUDE SQLCA END-EXEC.
       01 WS-POSITION.
           05 WS-SYMBOL             PIC X(6).
           05 WS-SHARES             PIC S9(9) COMP-3.
           05 WS-COST-BASIS         PIC S9(11)V99 COMP-3.
           05 WS-CURRENT-PRICE      PIC S9(7)V99 COMP-3.
           05 WS-MARKET-VALUE       PIC S9(13)V99 COMP-3.
           05 WS-GAIN-LOSS          PIC S9(13)V99 COMP-3.
       01 WS-TOTALS.
           05 WS-TOTAL-COST         PIC S9(15)V99 COMP-3.
           05 WS-TOTAL-MKT-VAL      PIC S9(15)V99 COMP-3.
           05 WS-TOTAL-GAIN         PIC S9(15)V99 COMP-3.
           05 WS-POS-COUNT          PIC S9(5) COMP-3.
           05 WS-GAIN-PCT           PIC S9(5)V99 COMP-3.
       01 WS-NAV                    PIC S9(13)V99 COMP-3.
       01 WS-BENCH-RETURN           PIC S9(5)V99 COMP-3.
       01 WS-ALPHA                  PIC S9(5)V99 COMP-3.
       01 WS-EOF-FLAG               PIC X VALUE 'N'.
           88 WS-END-OF-DATA        VALUE 'Y'.
       01 WS-STATUS                 PIC X(15).
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-OPEN-CURSOR
           PERFORM 3000-FETCH-POSITIONS
           PERFORM 4000-CLOSE-CURSOR
           PERFORM 5000-CALC-PORTFOLIO-METRICS
           PERFORM 6000-FETCH-BENCHMARK
           PERFORM 7000-DISPLAY-REPORT
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'PF00001234' TO WS-PORTFOLIO-ID
           MOVE 0 TO WS-TOTAL-COST
           MOVE 0 TO WS-TOTAL-MKT-VAL
           MOVE 0 TO WS-TOTAL-GAIN
           MOVE 0 TO WS-POS-COUNT
           MOVE 'N' TO WS-EOF-FLAG
           MOVE SPACES TO WS-STATUS.
       2000-OPEN-CURSOR.
           EXEC SQL
               DECLARE POS_CURSOR CURSOR FOR
               SELECT SYMBOL, SHARES, COST_BASIS,
                      CURRENT_PRICE
               FROM PORTFOLIO_POSITIONS
               WHERE PORTFOLIO_ID = :WS-PORTFOLIO-ID
               ORDER BY MARKET_VALUE DESC
           END-EXEC
           EXEC SQL
               OPEN POS_CURSOR
           END-EXEC
           IF WS-SQLCODE NOT = 0
               MOVE 'CURSOR ERROR' TO WS-STATUS
               DISPLAY 'SQL ERROR ON OPEN: ' WS-SQLCODE
           END-IF.
       3000-FETCH-POSITIONS.
           PERFORM UNTIL WS-END-OF-DATA
               EXEC SQL
                   FETCH POS_CURSOR
                   INTO :WS-SYMBOL, :WS-SHARES,
                        :WS-COST-BASIS, :WS-CURRENT-PRICE
               END-EXEC
               EVALUATE WS-SQLCODE
                   WHEN 0
                       PERFORM 3100-PROCESS-POSITION
                   WHEN 100
                       MOVE 'Y' TO WS-EOF-FLAG
                   WHEN OTHER
                       MOVE 'Y' TO WS-EOF-FLAG
                       MOVE 'FETCH ERROR' TO WS-STATUS
               END-EVALUATE
           END-PERFORM.
       3100-PROCESS-POSITION.
           COMPUTE WS-MARKET-VALUE =
               WS-SHARES * WS-CURRENT-PRICE
           COMPUTE WS-GAIN-LOSS =
               WS-MARKET-VALUE - WS-COST-BASIS
           ADD WS-COST-BASIS TO WS-TOTAL-COST
           ADD WS-MARKET-VALUE TO WS-TOTAL-MKT-VAL
           ADD WS-GAIN-LOSS TO WS-TOTAL-GAIN
           ADD 1 TO WS-POS-COUNT
           DISPLAY WS-SYMBOL ' '
               WS-SHARES ' SHARES MKT: '
               WS-MARKET-VALUE ' G/L: '
               WS-GAIN-LOSS.
       4000-CLOSE-CURSOR.
           EXEC SQL
               CLOSE POS_CURSOR
           END-EXEC.
       5000-CALC-PORTFOLIO-METRICS.
           MOVE WS-TOTAL-MKT-VAL TO WS-NAV
           IF WS-TOTAL-COST > 0
               COMPUTE WS-GAIN-PCT ROUNDED =
                   (WS-TOTAL-GAIN / WS-TOTAL-COST) * 100
           ELSE
               MOVE 0 TO WS-GAIN-PCT
           END-IF
           MOVE 'CALCULATED' TO WS-STATUS.
       6000-FETCH-BENCHMARK.
           EXEC SQL
               SELECT RETURN_PCT
               INTO :WS-BENCH-RETURN
               FROM BENCHMARKS
               WHERE BENCH_ID = 'SPX'
               AND PERIOD = 'QTD'
           END-EXEC
           IF WS-SQLCODE = 0
               COMPUTE WS-ALPHA ROUNDED =
                   WS-GAIN-PCT - WS-BENCH-RETURN
           ELSE
               MOVE 0 TO WS-BENCH-RETURN
               MOVE 0 TO WS-ALPHA
           END-IF.
       7000-DISPLAY-REPORT.
           DISPLAY '========================================='
           DISPLAY 'PORTFOLIO VALUATION REPORT'
           DISPLAY '========================================='
           DISPLAY 'PORTFOLIO:       ' WS-PORTFOLIO-ID
           DISPLAY 'POSITIONS:       ' WS-POS-COUNT
           DISPLAY 'TOTAL COST:      ' WS-TOTAL-COST
           DISPLAY 'MARKET VALUE:    ' WS-TOTAL-MKT-VAL
           DISPLAY 'TOTAL GAIN:      ' WS-TOTAL-GAIN
           DISPLAY 'GAIN PCT:        ' WS-GAIN-PCT
           DISPLAY 'NAV:             ' WS-NAV
           DISPLAY 'BENCHMARK:       ' WS-BENCH-RETURN
           DISPLAY 'ALPHA:           ' WS-ALPHA
           DISPLAY 'STATUS:          ' WS-STATUS
           DISPLAY '========================================='.
