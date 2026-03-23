       IDENTIFICATION DIVISION.
       PROGRAM-ID. TREAS-LIQUIDITY-RPT.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-BALANCE-SHEET.
           05 WS-CASH-EQUIV          PIC S9(13)V99 COMP-3.
           05 WS-SHORT-TERM-INV      PIC S9(13)V99 COMP-3.
           05 WS-TOTAL-ASSETS        PIC S9(13)V99 COMP-3.
           05 WS-CURRENT-LIAB        PIC S9(13)V99 COMP-3.
           05 WS-NET-STABLE-FUND     PIC S9(13)V99 COMP-3.
       01 WS-RATIOS.
           05 WS-LCR                 PIC S9(3)V99 COMP-3.
           05 WS-NSFR                PIC S9(3)V99 COMP-3.
           05 WS-QUICK-RATIO         PIC S9(3)V99 COMP-3.
       01 WS-LCR-STATUS              PIC X(1).
           88 WS-LCR-PASS            VALUE 'P'.
           88 WS-LCR-WARN            VALUE 'W'.
           88 WS-LCR-FAIL            VALUE 'F'.
       01 WS-LCR-MIN                 PIC S9(3)V99 COMP-3
           VALUE 100.00.
       01 WS-NSFR-MIN                PIC S9(3)V99 COMP-3
           VALUE 100.00.
       01 WS-HQLA                    PIC S9(13)V99 COMP-3.
       01 WS-NET-OUTFLOW             PIC S9(13)V99 COMP-3.
       01 WS-REPORT-LINE             PIC X(80).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-HQLA
           PERFORM 3000-CALC-RATIOS
           PERFORM 4000-ASSESS-STATUS
           PERFORM 5000-BUILD-REPORT
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-HQLA
           MOVE 0 TO WS-LCR
           MOVE 0 TO WS-NSFR.
       2000-CALC-HQLA.
           COMPUTE WS-HQLA =
               WS-CASH-EQUIV + WS-SHORT-TERM-INV.
       3000-CALC-RATIOS.
           IF WS-NET-OUTFLOW > 0
               COMPUTE WS-LCR =
                   (WS-HQLA / WS-NET-OUTFLOW) * 100
           END-IF
           IF WS-CURRENT-LIAB > 0
               COMPUTE WS-NSFR =
                   (WS-NET-STABLE-FUND / WS-CURRENT-LIAB)
                   * 100
           END-IF
           IF WS-CURRENT-LIAB > 0
               COMPUTE WS-QUICK-RATIO =
                   WS-HQLA / WS-CURRENT-LIAB
           END-IF.
       4000-ASSESS-STATUS.
           EVALUATE TRUE
               WHEN WS-LCR >= 120
                   SET WS-LCR-PASS TO TRUE
               WHEN WS-LCR >= WS-LCR-MIN
                   SET WS-LCR-WARN TO TRUE
               WHEN OTHER
                   SET WS-LCR-FAIL TO TRUE
           END-EVALUATE.
       5000-BUILD-REPORT.
           STRING 'LCR=' DELIMITED BY SIZE
                  WS-LCR DELIMITED BY SIZE
                  ' NSFR=' DELIMITED BY SIZE
                  WS-NSFR DELIMITED BY SIZE
                  ' HQLA=' DELIMITED BY SIZE
                  WS-HQLA DELIMITED BY SIZE
                  INTO WS-REPORT-LINE
           END-STRING.
       6000-DISPLAY-RESULTS.
           DISPLAY 'LIQUIDITY REPORT'
           DISPLAY '================'
           DISPLAY 'CASH EQUIV:      ' WS-CASH-EQUIV
           DISPLAY 'SHORT TERM INV:  ' WS-SHORT-TERM-INV
           DISPLAY 'HQLA:            ' WS-HQLA
           DISPLAY 'NET OUTFLOW:     ' WS-NET-OUTFLOW
           DISPLAY 'LCR:             ' WS-LCR
           DISPLAY 'NSFR:            ' WS-NSFR
           DISPLAY 'QUICK RATIO:     ' WS-QUICK-RATIO
           IF WS-LCR-PASS
               DISPLAY 'LCR STATUS: PASS'
           END-IF
           IF WS-LCR-WARN
               DISPLAY 'LCR STATUS: WARNING'
           END-IF
           IF WS-LCR-FAIL
               DISPLAY 'LCR STATUS: FAIL'
           END-IF
           DISPLAY WS-REPORT-LINE.
