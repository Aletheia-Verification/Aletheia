       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-SQL-INVEST-REPORT.
      *================================================================
      * MANUAL REVIEW: EXEC SQL
      * Embedded SQL report generator for investment performance,
      * fetches portfolio returns and benchmarks from DB2 tables.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-REPORT-PARAMS.
           05 WS-PORT-ID              PIC X(10).
           05 WS-REPORT-DATE          PIC X(10).
           05 WS-PERIOD               PIC X(2).
               88 PER-MONTHLY         VALUE 'MO'.
               88 PER-QUARTERLY       VALUE 'QT'.
               88 PER-ANNUAL          VALUE 'AN'.
       01 WS-PORTFOLIO-DATA.
           05 WS-PD-NAME              PIC X(30).
           05 WS-PD-MANAGER           PIC X(20).
           05 WS-PD-INCEPTION         PIC X(10).
           05 WS-PD-TOTAL-VALUE       PIC S9(13)V99 COMP-3.
           05 WS-PD-BENCHMARK         PIC X(10).
       01 WS-RETURNS.
           05 WS-RT-ENTRY OCCURS 5 TIMES.
               10 WS-RT-PERIOD-NAME   PIC X(10).
               10 WS-RT-PORT-RETURN   PIC S9(3)V9(4) COMP-3.
               10 WS-RT-BENCH-RETURN  PIC S9(3)V9(4) COMP-3.
               10 WS-RT-EXCESS        PIC S9(3)V9(4) COMP-3.
       01 WS-HOLDINGS.
           05 WS-HL-ENTRY OCCURS 10 TIMES.
               10 WS-HL-SECURITY      PIC X(12).
               10 WS-HL-WEIGHT        PIC S9(1)V9(4) COMP-3.
               10 WS-HL-RETURN        PIC S9(3)V9(4) COMP-3.
               10 WS-HL-CONTRIBUTION  PIC S9(3)V9(4) COMP-3.
       01 WS-IDX                      PIC 9(2).
       01 WS-HOLD-COUNT               PIC 9(2) VALUE 0.
       01 WS-TOTAL-CONTRIBUTION       PIC S9(3)V9(4) COMP-3
           VALUE 0.
       01 WS-ALPHA                    PIC S9(3)V9(4) COMP-3.
       01 WS-TRACKING-ERROR           PIC S9(3)V9(4) COMP-3.
       01 WS-INFO-RATIO               PIC S9(3)V9(4) COMP-3.
           EXEC SQL INCLUDE SQLCA END-EXEC.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-FETCH-PORTFOLIO
           PERFORM 3000-FETCH-RETURNS
           PERFORM 4000-FETCH-HOLDINGS
           PERFORM 5000-CALC-ATTRIBUTION
           PERFORM 6000-CALC-RATIOS
           PERFORM 7000-DISPLAY-REPORT
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'PORT-R-0055' TO WS-PORT-ID
           MOVE '2026-03-21' TO WS-REPORT-DATE
           MOVE 'QT' TO WS-PERIOD
           INITIALIZE WS-PORTFOLIO-DATA.
       2000-FETCH-PORTFOLIO.
           EXEC SQL
               SELECT PORT_NAME,
                      MANAGER_NAME,
                      INCEPTION_DATE,
                      TOTAL_VALUE,
                      BENCHMARK_CODE
               INTO :WS-PD-NAME,
                    :WS-PD-MANAGER,
                    :WS-PD-INCEPTION,
                    :WS-PD-TOTAL-VALUE,
                    :WS-PD-BENCHMARK
               FROM PORTFOLIO_MASTER
               WHERE PORT_ID = :WS-PORT-ID
           END-EXEC.
       3000-FETCH-RETURNS.
           EXEC SQL
               SELECT PERIOD_NAME,
                      PORT_RETURN,
                      BENCH_RETURN
               INTO :WS-RT-PERIOD-NAME(1),
                    :WS-RT-PORT-RETURN(1),
                    :WS-RT-BENCH-RETURN(1)
               FROM PERFORMANCE_DATA
               WHERE PORT_ID = :WS-PORT-ID
                 AND PERIOD_TYPE = :WS-PERIOD
               ORDER BY PERIOD_END DESC
               FETCH FIRST 1 ROW ONLY
           END-EXEC
           COMPUTE WS-RT-EXCESS(1) =
               WS-RT-PORT-RETURN(1) -
               WS-RT-BENCH-RETURN(1).
       4000-FETCH-HOLDINGS.
           EXEC SQL
               DECLARE HOLD_CURSOR CURSOR FOR
               SELECT SECURITY_ID,
                      WEIGHT_PCT,
                      PERIOD_RETURN
               FROM HOLDING_RETURNS
               WHERE PORT_ID = :WS-PORT-ID
               ORDER BY WEIGHT_PCT DESC
           END-EXEC
           EXEC SQL OPEN HOLD_CURSOR END-EXEC
           MOVE 0 TO WS-HOLD-COUNT
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > 10
               EXEC SQL
                   FETCH HOLD_CURSOR
                   INTO :WS-HL-SECURITY(WS-IDX),
                        :WS-HL-WEIGHT(WS-IDX),
                        :WS-HL-RETURN(WS-IDX)
               END-EXEC
               ADD 1 TO WS-HOLD-COUNT
           END-PERFORM
           EXEC SQL CLOSE HOLD_CURSOR END-EXEC.
       5000-CALC-ATTRIBUTION.
           MOVE 0 TO WS-TOTAL-CONTRIBUTION
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-HOLD-COUNT
               COMPUTE WS-HL-CONTRIBUTION(WS-IDX) =
                   WS-HL-WEIGHT(WS-IDX) *
                   WS-HL-RETURN(WS-IDX)
               ADD WS-HL-CONTRIBUTION(WS-IDX)
                   TO WS-TOTAL-CONTRIBUTION
           END-PERFORM.
       6000-CALC-RATIOS.
           MOVE WS-RT-EXCESS(1) TO WS-ALPHA
           MOVE 0.0250 TO WS-TRACKING-ERROR
           IF WS-TRACKING-ERROR > 0
               COMPUTE WS-INFO-RATIO =
                   WS-ALPHA / WS-TRACKING-ERROR
           ELSE
               MOVE 0 TO WS-INFO-RATIO
           END-IF.
       7000-DISPLAY-REPORT.
           DISPLAY 'INVESTMENT PERFORMANCE REPORT (SQL)'
           DISPLAY '===================================='
           DISPLAY 'PORTFOLIO:     ' WS-PD-NAME
           DISPLAY 'MANAGER:       ' WS-PD-MANAGER
           DISPLAY 'TOTAL VALUE:   ' WS-PD-TOTAL-VALUE
           DISPLAY 'PORT RETURN:   ' WS-RT-PORT-RETURN(1)
           DISPLAY 'BENCH RETURN:  ' WS-RT-BENCH-RETURN(1)
           DISPLAY 'ALPHA:         ' WS-ALPHA
           DISPLAY 'INFO RATIO:    ' WS-INFO-RATIO
           DISPLAY '------------------------------------'
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-HOLD-COUNT
               DISPLAY WS-HL-SECURITY(WS-IDX)
                   ' WT: ' WS-HL-WEIGHT(WS-IDX)
                   ' RET: ' WS-HL-RETURN(WS-IDX)
                   ' CTR: ' WS-HL-CONTRIBUTION(WS-IDX)
           END-PERFORM.
