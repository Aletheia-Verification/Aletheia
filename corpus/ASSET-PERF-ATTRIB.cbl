       IDENTIFICATION DIVISION.
       PROGRAM-ID. ASSET-PERF-ATTRIB.
      *================================================================*
      * Asset Management Performance Attribution Engine                  *
      * Decomposes portfolio return into allocation effect,             *
      * selection effect, and interaction effect using Brinson model.   *
      *================================================================*
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-SECTOR-TABLE.
           05  WS-SECTOR-ENTRY    OCCURS 8 TIMES.
               10  SE-NAME        PIC X(15).
               10  SE-PORT-WT     PIC S9(03)V9(06).
               10  SE-BENCH-WT    PIC S9(03)V9(06).
               10  SE-PORT-RET    PIC S9(03)V9(06).
               10  SE-BENCH-RET   PIC S9(03)V9(06).
               10  SE-ALLOC-EFF   PIC S9(03)V9(06).
               10  SE-SELECT-EFF  PIC S9(03)V9(06).
               10  SE-INTER-EFF   PIC S9(03)V9(06).
               10  SE-TOTAL-EFF   PIC S9(03)V9(06).
       01  WS-NUM-SECTORS         PIC 9(02) VALUE 8.
       01  WS-IDX                 PIC 9(02).
       01  WS-PORT-TOTAL-RET      PIC S9(03)V9(06) VALUE 0.
       01  WS-BENCH-TOTAL-RET     PIC S9(03)V9(06) VALUE 0.
       01  WS-TOTAL-ALLOC         PIC S9(03)V9(06) VALUE 0.
       01  WS-TOTAL-SELECT        PIC S9(03)V9(06) VALUE 0.
       01  WS-TOTAL-INTER         PIC S9(03)V9(06) VALUE 0.
       01  WS-ACTIVE-RETURN       PIC S9(03)V9(06).
       01  WS-EXPLAINED-RETURN    PIC S9(03)V9(06).
       01  WS-RESIDUAL            PIC S9(03)V9(06).
       01  WS-WT-DIFF             PIC S9(03)V9(06).
       01  WS-RET-DIFF            PIC S9(03)V9(06).
       01  WS-TRACKING-ERR        PIC S9(03)V9(06).
       01  WS-INFO-RATIO          PIC S9(03)V9(06).
       01  WS-ANNUALIZED-TE       PIC 9V9(06)
                                  VALUE 0.020000.
       01  WS-MSG                 PIC X(80) VALUE SPACES.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-RETURNS
           PERFORM 3000-CALC-ATTRIBUTION
           PERFORM 4000-CALC-RATIOS
           PERFORM 9000-REPORT
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'TECHNOLOGY     ' TO SE-NAME(1)
           MOVE 0.280000 TO SE-PORT-WT(1)
           MOVE 0.250000 TO SE-BENCH-WT(1)
           MOVE 0.085000 TO SE-PORT-RET(1)
           MOVE 0.072000 TO SE-BENCH-RET(1)
           MOVE 'HEALTHCARE     ' TO SE-NAME(2)
           MOVE 0.150000 TO SE-PORT-WT(2)
           MOVE 0.130000 TO SE-BENCH-WT(2)
           MOVE 0.042000 TO SE-PORT-RET(2)
           MOVE 0.038000 TO SE-BENCH-RET(2)
           MOVE 'FINANCIALS     ' TO SE-NAME(3)
           MOVE 0.120000 TO SE-PORT-WT(3)
           MOVE 0.140000 TO SE-BENCH-WT(3)
           MOVE 0.065000 TO SE-PORT-RET(3)
           MOVE 0.058000 TO SE-BENCH-RET(3)
           MOVE 'CONSUMER DISC  ' TO SE-NAME(4)
           MOVE 0.100000 TO SE-PORT-WT(4)
           MOVE 0.110000 TO SE-BENCH-WT(4)
           MOVE -0.012000 TO SE-PORT-RET(4)
           MOVE -0.008000 TO SE-BENCH-RET(4)
           MOVE 'INDUSTRIALS    ' TO SE-NAME(5)
           MOVE 0.100000 TO SE-PORT-WT(5)
           MOVE 0.100000 TO SE-BENCH-WT(5)
           MOVE 0.035000 TO SE-PORT-RET(5)
           MOVE 0.032000 TO SE-BENCH-RET(5)
           MOVE 'ENERGY         ' TO SE-NAME(6)
           MOVE 0.050000 TO SE-PORT-WT(6)
           MOVE 0.080000 TO SE-BENCH-WT(6)
           MOVE 0.095000 TO SE-PORT-RET(6)
           MOVE 0.088000 TO SE-BENCH-RET(6)
           MOVE 'UTILITIES      ' TO SE-NAME(7)
           MOVE 0.080000 TO SE-PORT-WT(7)
           MOVE 0.060000 TO SE-BENCH-WT(7)
           MOVE 0.018000 TO SE-PORT-RET(7)
           MOVE 0.022000 TO SE-BENCH-RET(7)
           MOVE 'MATERIALS      ' TO SE-NAME(8)
           MOVE 0.120000 TO SE-PORT-WT(8)
           MOVE 0.130000 TO SE-BENCH-WT(8)
           MOVE 0.028000 TO SE-PORT-RET(8)
           MOVE 0.025000 TO SE-BENCH-RET(8).
       2000-CALC-RETURNS.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-NUM-SECTORS
               COMPUTE WS-PORT-TOTAL-RET ROUNDED =
                   WS-PORT-TOTAL-RET +
                   (SE-PORT-WT(WS-IDX) *
                   SE-PORT-RET(WS-IDX))
               COMPUTE WS-BENCH-TOTAL-RET ROUNDED =
                   WS-BENCH-TOTAL-RET +
                   (SE-BENCH-WT(WS-IDX) *
                   SE-BENCH-RET(WS-IDX))
           END-PERFORM
           COMPUTE WS-ACTIVE-RETURN =
               WS-PORT-TOTAL-RET - WS-BENCH-TOTAL-RET.
       3000-CALC-ATTRIBUTION.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-NUM-SECTORS
               COMPUTE WS-WT-DIFF =
                   SE-PORT-WT(WS-IDX) -
                   SE-BENCH-WT(WS-IDX)
               COMPUTE WS-RET-DIFF =
                   SE-PORT-RET(WS-IDX) -
                   SE-BENCH-RET(WS-IDX)
               COMPUTE SE-ALLOC-EFF(WS-IDX) ROUNDED =
                   WS-WT-DIFF *
                   (SE-BENCH-RET(WS-IDX) -
                   WS-BENCH-TOTAL-RET)
               COMPUTE SE-SELECT-EFF(WS-IDX) ROUNDED =
                   SE-BENCH-WT(WS-IDX) * WS-RET-DIFF
               COMPUTE SE-INTER-EFF(WS-IDX) ROUNDED =
                   WS-WT-DIFF * WS-RET-DIFF
               COMPUTE SE-TOTAL-EFF(WS-IDX) =
                   SE-ALLOC-EFF(WS-IDX) +
                   SE-SELECT-EFF(WS-IDX) +
                   SE-INTER-EFF(WS-IDX)
               ADD SE-ALLOC-EFF(WS-IDX) TO WS-TOTAL-ALLOC
               ADD SE-SELECT-EFF(WS-IDX) TO
                   WS-TOTAL-SELECT
               ADD SE-INTER-EFF(WS-IDX) TO WS-TOTAL-INTER
           END-PERFORM
           COMPUTE WS-EXPLAINED-RETURN =
               WS-TOTAL-ALLOC + WS-TOTAL-SELECT +
               WS-TOTAL-INTER
           COMPUTE WS-RESIDUAL =
               WS-ACTIVE-RETURN - WS-EXPLAINED-RETURN.
       4000-CALC-RATIOS.
           MOVE WS-ANNUALIZED-TE TO WS-TRACKING-ERR
           IF WS-TRACKING-ERR > ZERO
               COMPUTE WS-INFO-RATIO ROUNDED =
                   WS-ACTIVE-RETURN / WS-TRACKING-ERR
           ELSE
               MOVE ZERO TO WS-INFO-RATIO
           END-IF.
       9000-REPORT.
           DISPLAY 'PERFORMANCE ATTRIBUTION REPORT'
           DISPLAY '================================='
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-NUM-SECTORS
               DISPLAY SE-NAME(WS-IDX)
                   ' ALLOC=' SE-ALLOC-EFF(WS-IDX)
                   ' SEL=' SE-SELECT-EFF(WS-IDX)
                   ' TOT=' SE-TOTAL-EFF(WS-IDX)
           END-PERFORM
           DISPLAY '================================='
           DISPLAY 'PORT RETURN:   ' WS-PORT-TOTAL-RET
           DISPLAY 'BENCH RETURN:  ' WS-BENCH-TOTAL-RET
           DISPLAY 'ACTIVE RETURN: ' WS-ACTIVE-RETURN
           DISPLAY 'ALLOCATION:    ' WS-TOTAL-ALLOC
           DISPLAY 'SELECTION:     ' WS-TOTAL-SELECT
           DISPLAY 'INTERACTION:   ' WS-TOTAL-INTER
           DISPLAY 'RESIDUAL:      ' WS-RESIDUAL
           DISPLAY 'TRACKING ERR:  ' WS-TRACKING-ERR
           DISPLAY 'INFO RATIO:    ' WS-INFO-RATIO.
