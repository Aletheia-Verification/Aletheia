       IDENTIFICATION DIVISION.
       PROGRAM-ID. REG-DODD-FRANK-RPT.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-BANK-METRICS.
           05 WS-TOTAL-ASSETS     PIC S9(15)V99 COMP-3.
           05 WS-TIER1-CAPITAL    PIC S9(13)V99 COMP-3.
           05 WS-TIER2-CAPITAL    PIC S9(13)V99 COMP-3.
           05 WS-RWA              PIC S9(15)V99 COMP-3.
           05 WS-LEVERAGE-ASSETS  PIC S9(15)V99 COMP-3.
           05 WS-LIQUID-ASSETS    PIC S9(13)V99 COMP-3.
           05 WS-NET-CASH-OUTFLOW PIC S9(13)V99 COMP-3.
       01 WS-RATIOS.
           05 WS-CET1-RATIO       PIC S9(2)V9(4) COMP-3.
           05 WS-TIER1-RATIO      PIC S9(2)V9(4) COMP-3.
           05 WS-TOTAL-CAP-RATIO  PIC S9(2)V9(4) COMP-3.
           05 WS-LEVERAGE-RATIO   PIC S9(2)V9(4) COMP-3.
           05 WS-LCR              PIC S9(3)V99 COMP-3.
       01 WS-MINIMUMS.
           05 WS-MIN-CET1         PIC S9(2)V9(4) COMP-3
               VALUE 0.0450.
           05 WS-MIN-TIER1        PIC S9(2)V9(4) COMP-3
               VALUE 0.0600.
           05 WS-MIN-TOTAL-CAP    PIC S9(2)V9(4) COMP-3
               VALUE 0.0800.
           05 WS-MIN-LEVERAGE     PIC S9(2)V9(4) COMP-3
               VALUE 0.0400.
           05 WS-MIN-LCR          PIC S9(3)V99 COMP-3
               VALUE 100.00.
       01 WS-BREACH-COUNT         PIC 9.
       01 WS-BREACHES.
           05 WS-BREACH OCCURS 5 TIMES PIC X(25).
       01 WS-BR-IDX               PIC 9.
       01 WS-WELL-CAPITALIZED     PIC X VALUE 'Y'.
           88 IS-WELL-CAP         VALUE 'Y'.
       01 WS-REPORT-DATE          PIC 9(8).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-CALC-RATIOS
           PERFORM 2000-CHECK-COMPLIANCE
           PERFORM 3000-REPORT
           STOP RUN.
       1000-CALC-RATIOS.
           ACCEPT WS-REPORT-DATE FROM DATE YYYYMMDD
           IF WS-RWA > 0
               COMPUTE WS-CET1-RATIO =
                   WS-TIER1-CAPITAL / WS-RWA
               COMPUTE WS-TIER1-RATIO =
                   WS-TIER1-CAPITAL / WS-RWA
               COMPUTE WS-TOTAL-CAP-RATIO =
                   (WS-TIER1-CAPITAL + WS-TIER2-CAPITAL) /
                   WS-RWA
           END-IF
           IF WS-LEVERAGE-ASSETS > 0
               COMPUTE WS-LEVERAGE-RATIO =
                   WS-TIER1-CAPITAL / WS-LEVERAGE-ASSETS
           END-IF
           IF WS-NET-CASH-OUTFLOW > 0
               COMPUTE WS-LCR =
                   (WS-LIQUID-ASSETS / WS-NET-CASH-OUTFLOW)
                   * 100
           ELSE
               MOVE 999.99 TO WS-LCR
           END-IF.
       2000-CHECK-COMPLIANCE.
           MOVE 0 TO WS-BREACH-COUNT
           MOVE 1 TO WS-BR-IDX
           IF WS-CET1-RATIO < WS-MIN-CET1
               MOVE 'CET1 RATIO BELOW MIN '
                   TO WS-BREACH(WS-BR-IDX)
               ADD 1 TO WS-BREACH-COUNT
               ADD 1 TO WS-BR-IDX
               MOVE 'N' TO WS-WELL-CAPITALIZED
           END-IF
           IF WS-TIER1-RATIO < WS-MIN-TIER1
               MOVE 'TIER1 RATIO BELOW MIN'
                   TO WS-BREACH(WS-BR-IDX)
               ADD 1 TO WS-BREACH-COUNT
               ADD 1 TO WS-BR-IDX
               MOVE 'N' TO WS-WELL-CAPITALIZED
           END-IF
           IF WS-TOTAL-CAP-RATIO < WS-MIN-TOTAL-CAP
               MOVE 'TOTAL CAP BELOW MIN  '
                   TO WS-BREACH(WS-BR-IDX)
               ADD 1 TO WS-BREACH-COUNT
               ADD 1 TO WS-BR-IDX
               MOVE 'N' TO WS-WELL-CAPITALIZED
           END-IF
           IF WS-LEVERAGE-RATIO < WS-MIN-LEVERAGE
               MOVE 'LEVERAGE BELOW MIN   '
                   TO WS-BREACH(WS-BR-IDX)
               ADD 1 TO WS-BREACH-COUNT
               ADD 1 TO WS-BR-IDX
               MOVE 'N' TO WS-WELL-CAPITALIZED
           END-IF
           IF WS-LCR < WS-MIN-LCR
               IF WS-BR-IDX <= 5
                   MOVE 'LCR BELOW MIN        '
                       TO WS-BREACH(WS-BR-IDX)
                   ADD 1 TO WS-BREACH-COUNT
               END-IF
           END-IF.
       3000-REPORT.
           DISPLAY 'DODD-FRANK CAPITAL REPORT'
           DISPLAY '========================='
           DISPLAY 'DATE:       ' WS-REPORT-DATE
           DISPLAY 'CET1 RATIO: ' WS-CET1-RATIO
           DISPLAY 'TIER1 RATIO:' WS-TIER1-RATIO
           DISPLAY 'TOTAL CAP:  ' WS-TOTAL-CAP-RATIO
           DISPLAY 'LEVERAGE:   ' WS-LEVERAGE-RATIO
           DISPLAY 'LCR:        ' WS-LCR
           IF IS-WELL-CAP
               DISPLAY 'STATUS: WELL CAPITALIZED'
           ELSE
               DISPLAY 'STATUS: NOT WELL CAPITALIZED'
               DISPLAY 'BREACHES: ' WS-BREACH-COUNT
               PERFORM VARYING WS-BR-IDX FROM 1 BY 1
                   UNTIL WS-BR-IDX > WS-BREACH-COUNT
                   DISPLAY '  ' WS-BREACH(WS-BR-IDX)
               END-PERFORM
           END-IF.
