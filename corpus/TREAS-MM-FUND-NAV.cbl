       IDENTIFICATION DIVISION.
       PROGRAM-ID. TREAS-MM-FUND-NAV.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-FUND-HOLDINGS.
           05 WS-HOLDING OCCURS 15 TIMES.
               10 WS-HD-CUSIP     PIC X(9).
               10 WS-HD-DESC      PIC X(20).
               10 WS-HD-PAR       PIC S9(11)V99 COMP-3.
               10 WS-HD-MKT-VAL   PIC S9(11)V99 COMP-3.
               10 WS-HD-YIELD     PIC S9(2)V9(4) COMP-3.
               10 WS-HD-MATURITY  PIC 9(8).
               10 WS-HD-DAYS-MAT  PIC 9(3).
       01 WS-HD-COUNT             PIC 99 VALUE 15.
       01 WS-IDX                  PIC 99.
       01 WS-TOTAL-PAR            PIC S9(13)V99 COMP-3.
       01 WS-TOTAL-MKT            PIC S9(13)V99 COMP-3.
       01 WS-TOTAL-SHARES         PIC S9(11)V99 COMP-3.
       01 WS-NAV-PER-SHARE        PIC S9(1)V9(4) COMP-3.
       01 WS-WAM                  PIC S9(3)V99 COMP-3.
       01 WS-WEIGHTED-YIELD       PIC S9(5)V9(4) COMP-3.
       01 WS-AVG-YIELD            PIC S9(2)V9(4) COMP-3.
       01 WS-NAV-DEVIATION        PIC S9(1)V9(4) COMP-3.
       01 WS-SHADOW-NAV           PIC S9(1)V9(4) COMP-3.
       01 WS-CURRENT-DATE         PIC 9(8).
       01 WS-FUND-STATUS          PIC X(10).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-CALC-TOTALS
           PERFORM 3000-CALC-NAV
           PERFORM 4000-CALC-WAM
           PERFORM 5000-CHECK-STABILITY
           PERFORM 6000-REPORT
           STOP RUN.
       1000-INIT.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-TOTAL-PAR
           MOVE 0 TO WS-TOTAL-MKT
           MOVE 0 TO WS-WEIGHTED-YIELD.
       2000-CALC-TOTALS.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-HD-COUNT
               ADD WS-HD-PAR(WS-IDX) TO WS-TOTAL-PAR
               ADD WS-HD-MKT-VAL(WS-IDX) TO WS-TOTAL-MKT
               COMPUTE WS-WEIGHTED-YIELD =
                   WS-WEIGHTED-YIELD +
                   (WS-HD-YIELD(WS-IDX) *
                    WS-HD-MKT-VAL(WS-IDX))
               COMPUTE WS-HD-DAYS-MAT(WS-IDX) =
                   WS-HD-MATURITY(WS-IDX) - WS-CURRENT-DATE
           END-PERFORM.
       3000-CALC-NAV.
           IF WS-TOTAL-SHARES > 0
               COMPUTE WS-NAV-PER-SHARE =
                   WS-TOTAL-MKT / WS-TOTAL-SHARES
           ELSE
               MOVE 1.0000 TO WS-NAV-PER-SHARE
           END-IF
           IF WS-TOTAL-PAR > 0
               COMPUTE WS-SHADOW-NAV =
                   WS-TOTAL-MKT / WS-TOTAL-PAR
           ELSE
               MOVE 1.0000 TO WS-SHADOW-NAV
           END-IF
           IF WS-TOTAL-MKT > 0
               COMPUTE WS-AVG-YIELD =
                   WS-WEIGHTED-YIELD / WS-TOTAL-MKT
           END-IF.
       4000-CALC-WAM.
           MOVE 0 TO WS-WAM
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-HD-COUNT
               IF WS-TOTAL-MKT > 0
                   COMPUTE WS-WAM = WS-WAM +
                       (WS-HD-DAYS-MAT(WS-IDX) *
                        WS-HD-MKT-VAL(WS-IDX) /
                        WS-TOTAL-MKT)
               END-IF
           END-PERFORM.
       5000-CHECK-STABILITY.
           COMPUTE WS-NAV-DEVIATION =
               WS-NAV-PER-SHARE - 1.0000
           IF WS-NAV-DEVIATION < 0
               MULTIPLY -1 BY WS-NAV-DEVIATION
           END-IF
           IF WS-NAV-DEVIATION > 0.0050
               MOVE 'ALERT     ' TO WS-FUND-STATUS
           ELSE
               IF WS-NAV-DEVIATION > 0.0025
                   MOVE 'WATCH     ' TO WS-FUND-STATUS
               ELSE
                   MOVE 'STABLE    ' TO WS-FUND-STATUS
               END-IF
           END-IF.
       6000-REPORT.
           DISPLAY 'MONEY MARKET FUND NAV REPORT'
           DISPLAY '============================'
           DISPLAY 'DATE:        ' WS-CURRENT-DATE
           DISPLAY 'TOTAL PAR:   $' WS-TOTAL-PAR
           DISPLAY 'TOTAL MKT:   $' WS-TOTAL-MKT
           DISPLAY 'SHARES:      ' WS-TOTAL-SHARES
           DISPLAY 'NAV/SHARE:   ' WS-NAV-PER-SHARE
           DISPLAY 'SHADOW NAV:  ' WS-SHADOW-NAV
           DISPLAY 'AVG YIELD:   ' WS-AVG-YIELD
           DISPLAY 'WAM (DAYS):  ' WS-WAM
           DISPLAY 'STATUS:      ' WS-FUND-STATUS.
