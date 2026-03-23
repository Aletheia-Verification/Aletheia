       IDENTIFICATION DIVISION.
       PROGRAM-ID. TREAS-CD-LADDER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CD-PORTFOLIO.
           05 WS-CD OCCURS 12 TIMES.
               10 WS-CD-ID        PIC X(10).
               10 WS-CD-PRINCIPAL PIC S9(9)V99 COMP-3.
               10 WS-CD-RATE      PIC S9(2)V9(4) COMP-3.
               10 WS-CD-TERM-MO   PIC 9(3).
               10 WS-CD-MATURE-DT PIC 9(8).
               10 WS-CD-INTEREST  PIC S9(7)V99 COMP-3.
               10 WS-CD-STATUS    PIC X(1).
                   88 CD-ACTIVE   VALUE 'A'.
                   88 CD-MATURING VALUE 'M'.
                   88 CD-MATURED  VALUE 'X'.
       01 WS-CD-COUNT             PIC 99 VALUE 12.
       01 WS-IDX                  PIC 99.
       01 WS-CURRENT-DATE         PIC 9(8).
       01 WS-DAYS-TO-MATURITY     PIC S9(5) COMP-3.
       01 WS-TOTAL-PRINCIPAL      PIC S9(11)V99 COMP-3.
       01 WS-TOTAL-INTEREST       PIC S9(9)V99 COMP-3.
       01 WS-AVG-RATE             PIC S9(2)V9(4) COMP-3.
       01 WS-RATE-SUM             PIC S9(5)V9(4) COMP-3.
       01 WS-ACTIVE-COUNT         PIC 99.
       01 WS-MATURING-30          PIC 99.
       01 WS-MATURING-60          PIC 99.
       01 WS-MATURING-90          PIC 99.
       01 WS-REINVEST-AMT         PIC S9(11)V99 COMP-3.
       01 WS-WEIGHTED-RATE        PIC S9(5)V9(4) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-ANALYZE-PORTFOLIO
           PERFORM 3000-CALC-SUMMARY
           PERFORM 4000-REPORT
           STOP RUN.
       1000-INIT.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-TOTAL-PRINCIPAL
           MOVE 0 TO WS-TOTAL-INTEREST
           MOVE 0 TO WS-RATE-SUM
           MOVE 0 TO WS-ACTIVE-COUNT
           MOVE 0 TO WS-MATURING-30
           MOVE 0 TO WS-MATURING-60
           MOVE 0 TO WS-MATURING-90
           MOVE 0 TO WS-REINVEST-AMT
           MOVE 0 TO WS-WEIGHTED-RATE.
       2000-ANALYZE-PORTFOLIO.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-CD-COUNT
               PERFORM 2100-EVALUATE-CD
           END-PERFORM.
       2100-EVALUATE-CD.
           COMPUTE WS-DAYS-TO-MATURITY =
               WS-CD-MATURE-DT(WS-IDX) - WS-CURRENT-DATE
           IF WS-DAYS-TO-MATURITY <= 0
               MOVE 'X' TO WS-CD-STATUS(WS-IDX)
               ADD WS-CD-PRINCIPAL(WS-IDX)
                   TO WS-REINVEST-AMT
           ELSE
               IF WS-DAYS-TO-MATURITY <= 30
                   MOVE 'M' TO WS-CD-STATUS(WS-IDX)
                   ADD 1 TO WS-MATURING-30
               ELSE
                   IF WS-DAYS-TO-MATURITY <= 60
                       ADD 1 TO WS-MATURING-60
                   ELSE
                       IF WS-DAYS-TO-MATURITY <= 90
                           ADD 1 TO WS-MATURING-90
                       END-IF
                   END-IF
                   MOVE 'A' TO WS-CD-STATUS(WS-IDX)
               END-IF
               ADD 1 TO WS-ACTIVE-COUNT
           END-IF
           COMPUTE WS-CD-INTEREST(WS-IDX) =
               WS-CD-PRINCIPAL(WS-IDX) *
               WS-CD-RATE(WS-IDX) / 12 *
               WS-CD-TERM-MO(WS-IDX)
           ADD WS-CD-PRINCIPAL(WS-IDX) TO
               WS-TOTAL-PRINCIPAL
           ADD WS-CD-INTEREST(WS-IDX) TO
               WS-TOTAL-INTEREST
           ADD WS-CD-RATE(WS-IDX) TO WS-RATE-SUM
           COMPUTE WS-WEIGHTED-RATE =
               WS-WEIGHTED-RATE +
               (WS-CD-RATE(WS-IDX) *
                WS-CD-PRINCIPAL(WS-IDX)).
       3000-CALC-SUMMARY.
           IF WS-CD-COUNT > 0
               COMPUTE WS-AVG-RATE =
                   WS-RATE-SUM / WS-CD-COUNT
           ELSE
               MOVE 0 TO WS-AVG-RATE
           END-IF
           IF WS-TOTAL-PRINCIPAL > 0
               COMPUTE WS-WEIGHTED-RATE =
                   WS-WEIGHTED-RATE / WS-TOTAL-PRINCIPAL
           END-IF.
       4000-REPORT.
           DISPLAY 'CD LADDER ANALYSIS REPORT'
           DISPLAY '========================='
           DISPLAY 'DATE:         ' WS-CURRENT-DATE
           DISPLAY 'TOTAL CDS:    ' WS-CD-COUNT
           DISPLAY 'ACTIVE:       ' WS-ACTIVE-COUNT
           DISPLAY 'PRINCIPAL:    $' WS-TOTAL-PRINCIPAL
           DISPLAY 'INTEREST:     $' WS-TOTAL-INTEREST
           DISPLAY 'AVG RATE:     ' WS-AVG-RATE
           DISPLAY 'WGTD RATE:    ' WS-WEIGHTED-RATE
           DISPLAY 'MATURING 30D: ' WS-MATURING-30
           DISPLAY 'MATURING 60D: ' WS-MATURING-60
           DISPLAY 'MATURING 90D: ' WS-MATURING-90
           DISPLAY 'REINVEST AMT: $' WS-REINVEST-AMT
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-CD-COUNT
               DISPLAY '  ' WS-CD-ID(WS-IDX)
                   ' $' WS-CD-PRINCIPAL(WS-IDX)
                   ' ' WS-CD-RATE(WS-IDX) '%'
                   ' [' WS-CD-STATUS(WS-IDX) ']'
           END-PERFORM.
