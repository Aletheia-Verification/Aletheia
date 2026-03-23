       IDENTIFICATION DIVISION.
       PROGRAM-ID. TREAS-GAP-ANALYSIS.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-TIME-BUCKETS.
           05 WS-BUCKET OCCURS 7 TIMES.
               10 WS-BK-LABEL    PIC X(10).
               10 WS-BK-ASSETS   PIC S9(13)V99 COMP-3.
               10 WS-BK-LIAB     PIC S9(13)V99 COMP-3.
               10 WS-BK-GAP      PIC S9(13)V99 COMP-3.
               10 WS-BK-CUM-GAP  PIC S9(13)V99 COMP-3.
               10 WS-BK-GAP-RATIO PIC S9(3)V99 COMP-3.
       01 WS-BK-COUNT            PIC 9 VALUE 7.
       01 WS-IDX                 PIC 9.
       01 WS-TOTAL-ASSETS        PIC S9(15)V99 COMP-3.
       01 WS-TOTAL-LIAB          PIC S9(15)V99 COMP-3.
       01 WS-TOTAL-GAP           PIC S9(15)V99 COMP-3.
       01 WS-CUM-GAP             PIC S9(15)V99 COMP-3.
       01 WS-NII-IMPACT          PIC S9(11)V99 COMP-3.
       01 WS-RATE-SHIFT          PIC S9(2)V9(4) COMP-3
           VALUE 0.0100.
       01 WS-REPORT-DATE         PIC 9(8).
       01 WS-RISK-LEVEL          PIC X(8).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-CALC-GAPS
           PERFORM 3000-CALC-NII-IMPACT
           PERFORM 4000-ASSESS-RISK
           PERFORM 5000-REPORT
           STOP RUN.
       1000-INIT.
           ACCEPT WS-REPORT-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-TOTAL-ASSETS
           MOVE 0 TO WS-TOTAL-LIAB
           MOVE 0 TO WS-CUM-GAP.
       2000-CALC-GAPS.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-BK-COUNT
               COMPUTE WS-BK-GAP(WS-IDX) =
                   WS-BK-ASSETS(WS-IDX) -
                   WS-BK-LIAB(WS-IDX)
               ADD WS-BK-GAP(WS-IDX) TO WS-CUM-GAP
               MOVE WS-CUM-GAP TO WS-BK-CUM-GAP(WS-IDX)
               ADD WS-BK-ASSETS(WS-IDX) TO WS-TOTAL-ASSETS
               ADD WS-BK-LIAB(WS-IDX) TO WS-TOTAL-LIAB
               IF WS-TOTAL-ASSETS > 0
                   COMPUTE WS-BK-GAP-RATIO(WS-IDX) =
                       (WS-BK-CUM-GAP(WS-IDX) /
                        WS-TOTAL-ASSETS) * 100
               END-IF
           END-PERFORM
           COMPUTE WS-TOTAL-GAP =
               WS-TOTAL-ASSETS - WS-TOTAL-LIAB.
       3000-CALC-NII-IMPACT.
           COMPUTE WS-NII-IMPACT =
               WS-CUM-GAP * WS-RATE-SHIFT.
       4000-ASSESS-RISK.
           IF WS-BK-GAP-RATIO(1) > 10
               OR WS-BK-GAP-RATIO(1) < -10
               MOVE 'HIGH    ' TO WS-RISK-LEVEL
           ELSE
               IF WS-BK-GAP-RATIO(1) > 5
                   OR WS-BK-GAP-RATIO(1) < -5
                   MOVE 'MEDIUM  ' TO WS-RISK-LEVEL
               ELSE
                   MOVE 'LOW     ' TO WS-RISK-LEVEL
               END-IF
           END-IF.
       5000-REPORT.
           DISPLAY 'INTEREST RATE GAP ANALYSIS'
           DISPLAY '=========================='
           DISPLAY 'DATE: ' WS-REPORT-DATE
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-BK-COUNT
               DISPLAY '  ' WS-BK-LABEL(WS-IDX)
                   ' A=$' WS-BK-ASSETS(WS-IDX)
                   ' L=$' WS-BK-LIAB(WS-IDX)
                   ' GAP=$' WS-BK-GAP(WS-IDX)
           END-PERFORM
           DISPLAY 'TOTAL ASSETS:  $' WS-TOTAL-ASSETS
           DISPLAY 'TOTAL LIAB:    $' WS-TOTAL-LIAB
           DISPLAY 'CUM GAP:       $' WS-CUM-GAP
           DISPLAY 'NII IMPACT:    $' WS-NII-IMPACT
           DISPLAY 'RISK:          ' WS-RISK-LEVEL.
