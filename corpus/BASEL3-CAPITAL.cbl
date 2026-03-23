       IDENTIFICATION DIVISION.
       PROGRAM-ID. BASEL3-CAPITAL.
      *================================================================
      * Basel III Capital Adequacy Calculation
      * Computes CET1, Tier 1, Total Capital ratios and leverage
      * ratio with countercyclical buffer assessment.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-BANK-ID                   PIC X(10).
       01 WS-CAPITAL-COMPONENTS.
           05 WS-COMMON-EQUITY         PIC S9(13)V99 COMP-3.
           05 WS-RETAINED-EARNINGS     PIC S9(13)V99 COMP-3.
           05 WS-AOCI                  PIC S9(11)V99 COMP-3.
           05 WS-GOODWILL              PIC S9(11)V99 COMP-3.
           05 WS-INTANGIBLES           PIC S9(11)V99 COMP-3.
           05 WS-DTA-DEDUCTION         PIC S9(11)V99 COMP-3.
       01 WS-TIER1-ADDITIONS.
           05 WS-ADDL-TIER1            PIC S9(13)V99 COMP-3.
           05 WS-NONCUM-PREF           PIC S9(11)V99 COMP-3.
       01 WS-TIER2-COMPONENTS.
           05 WS-SUB-DEBT              PIC S9(13)V99 COMP-3.
           05 WS-ALLOWANCE-INCL        PIC S9(11)V99 COMP-3.
           05 WS-ALLOWANCE-LIMIT       PIC S9(11)V99 COMP-3.
       01 WS-RWA-TABLE.
           05 WS-RWA-ENTRY OCCURS 6
              ASCENDING KEY IS WS-RWA-CATEGORY
              INDEXED BY WS-RWA-IDX.
               10 WS-RWA-CATEGORY      PIC X(4).
               10 WS-RWA-EXPOSURE      PIC S9(13)V99 COMP-3.
               10 WS-RWA-WEIGHT        PIC S9(1)V9(4) COMP-3.
               10 WS-RWA-AMOUNT        PIC S9(13)V99 COMP-3.
       01 WS-RWA-COUNT                 PIC 9(1) VALUE 6.
       01 WS-COMPUTED-CAPITALS.
           05 WS-CET1-AMT              PIC S9(13)V99 COMP-3.
           05 WS-TIER1-AMT             PIC S9(13)V99 COMP-3.
           05 WS-TOTAL-CAPITAL-AMT     PIC S9(13)V99 COMP-3.
           05 WS-TOTAL-RWA             PIC S9(13)V99 COMP-3.
           05 WS-TOTAL-EXPOSURE        PIC S9(13)V99 COMP-3.
       01 WS-RATIOS.
           05 WS-CET1-RATIO            PIC S9(3)V9(4) COMP-3.
           05 WS-TIER1-RATIO           PIC S9(3)V9(4) COMP-3.
           05 WS-TOTAL-CAP-RATIO       PIC S9(3)V9(4) COMP-3.
           05 WS-LEVERAGE-RATIO        PIC S9(3)V9(4) COMP-3.
       01 WS-MINIMUMS.
           05 WS-MIN-CET1              PIC S9(3)V9(4) COMP-3
               VALUE 4.5000.
           05 WS-MIN-TIER1             PIC S9(3)V9(4) COMP-3
               VALUE 6.0000.
           05 WS-MIN-TOTAL             PIC S9(3)V9(4) COMP-3
               VALUE 8.0000.
           05 WS-MIN-LEVERAGE          PIC S9(3)V9(4) COMP-3
               VALUE 4.0000.
       01 WS-BUFFERS.
           05 WS-CONSERV-BUFFER        PIC S9(1)V9(4) COMP-3
               VALUE 2.5000.
           05 WS-CCYB                  PIC S9(1)V9(4) COMP-3
               VALUE 0.0000.
           05 WS-GSIB-SURCHARGE        PIC S9(1)V9(4) COMP-3
               VALUE 0.0000.
           05 WS-TOTAL-BUFFER          PIC S9(1)V9(4) COMP-3.
       01 WS-COMPLIANCE-FLAGS.
           05 WS-CET1-OK               PIC X(1).
               88 WS-CET1-PASS         VALUE 'Y'.
           05 WS-TIER1-OK              PIC X(1).
               88 WS-TIER1-PASS        VALUE 'Y'.
           05 WS-TOTAL-OK              PIC X(1).
               88 WS-TOTAL-PASS        VALUE 'Y'.
           05 WS-LEVERAGE-OK           PIC X(1).
               88 WS-LEVERAGE-PASS     VALUE 'Y'.
           05 WS-WELL-CAPITALIZED      PIC X(1).
               88 WS-IS-WELL-CAP       VALUE 'Y'.
       01 WS-PROCESS-DATE              PIC 9(8).
       01 WS-SEARCH-CAT                PIC X(4).
       01 WS-REPORT-LINE               PIC X(80).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-CET1
           PERFORM 3000-CALC-RWA
           PERFORM 4000-CALC-RATIOS
           PERFORM 5000-CHECK-COMPLIANCE
           PERFORM 6000-DISPLAY-REPORT
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-PROCESS-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-TOTAL-RWA
           MOVE 0 TO WS-TOTAL-EXPOSURE
           COMPUTE WS-TOTAL-BUFFER =
               WS-CONSERV-BUFFER + WS-CCYB +
               WS-GSIB-SURCHARGE.
       2000-CALC-CET1.
           COMPUTE WS-CET1-AMT =
               WS-COMMON-EQUITY +
               WS-RETAINED-EARNINGS +
               WS-AOCI -
               WS-GOODWILL -
               WS-INTANGIBLES -
               WS-DTA-DEDUCTION
           COMPUTE WS-TIER1-AMT =
               WS-CET1-AMT + WS-ADDL-TIER1 +
               WS-NONCUM-PREF
           COMPUTE WS-ALLOWANCE-LIMIT =
               WS-TOTAL-RWA * 0.0125
           IF WS-ALLOWANCE-INCL > WS-ALLOWANCE-LIMIT
               MOVE WS-ALLOWANCE-LIMIT
                   TO WS-ALLOWANCE-INCL
           END-IF
           COMPUTE WS-TOTAL-CAPITAL-AMT =
               WS-TIER1-AMT + WS-SUB-DEBT +
               WS-ALLOWANCE-INCL.
       3000-CALC-RWA.
           PERFORM VARYING WS-RWA-IDX FROM 1 BY 1
               UNTIL WS-RWA-IDX > WS-RWA-COUNT
               COMPUTE WS-RWA-AMOUNT(WS-RWA-IDX) =
                   WS-RWA-EXPOSURE(WS-RWA-IDX) *
                   WS-RWA-WEIGHT(WS-RWA-IDX)
               ADD WS-RWA-AMOUNT(WS-RWA-IDX)
                   TO WS-TOTAL-RWA
               ADD WS-RWA-EXPOSURE(WS-RWA-IDX)
                   TO WS-TOTAL-EXPOSURE
           END-PERFORM.
       4000-CALC-RATIOS.
           IF WS-TOTAL-RWA > 0
               COMPUTE WS-CET1-RATIO =
                   (WS-CET1-AMT / WS-TOTAL-RWA) * 100
               COMPUTE WS-TIER1-RATIO =
                   (WS-TIER1-AMT / WS-TOTAL-RWA) * 100
               COMPUTE WS-TOTAL-CAP-RATIO =
                   (WS-TOTAL-CAPITAL-AMT /
                    WS-TOTAL-RWA) * 100
           END-IF
           IF WS-TOTAL-EXPOSURE > 0
               COMPUTE WS-LEVERAGE-RATIO =
                   (WS-TIER1-AMT /
                    WS-TOTAL-EXPOSURE) * 100
           END-IF.
       5000-CHECK-COMPLIANCE.
           IF WS-CET1-RATIO >=
               WS-MIN-CET1 + WS-TOTAL-BUFFER
               SET WS-CET1-PASS TO TRUE
           ELSE
               MOVE 'N' TO WS-CET1-OK
           END-IF
           IF WS-TIER1-RATIO >= WS-MIN-TIER1
               SET WS-TIER1-PASS TO TRUE
           ELSE
               MOVE 'N' TO WS-TIER1-OK
           END-IF
           IF WS-TOTAL-CAP-RATIO >= WS-MIN-TOTAL
               SET WS-TOTAL-PASS TO TRUE
           ELSE
               MOVE 'N' TO WS-TOTAL-OK
           END-IF
           IF WS-LEVERAGE-RATIO >= WS-MIN-LEVERAGE
               SET WS-LEVERAGE-PASS TO TRUE
           ELSE
               MOVE 'N' TO WS-LEVERAGE-OK
           END-IF
           IF WS-CET1-PASS AND WS-TIER1-PASS
           AND WS-TOTAL-PASS AND WS-LEVERAGE-PASS
               SET WS-IS-WELL-CAP TO TRUE
           ELSE
               MOVE 'N' TO WS-WELL-CAPITALIZED
           END-IF.
       6000-DISPLAY-REPORT.
           DISPLAY "BASEL III CAPITAL ADEQUACY"
           DISPLAY "BANK: " WS-BANK-ID
           DISPLAY "DATE: " WS-PROCESS-DATE
           DISPLAY "CET1: " WS-CET1-AMT
           DISPLAY "CET1 RATIO: " WS-CET1-RATIO "%"
           DISPLAY "TIER1 RATIO: " WS-TIER1-RATIO "%"
           DISPLAY "TOTAL CAP RATIO: "
               WS-TOTAL-CAP-RATIO "%"
           DISPLAY "LEVERAGE RATIO: "
               WS-LEVERAGE-RATIO "%"
           IF WS-IS-WELL-CAP
               DISPLAY "STATUS: WELL CAPITALIZED"
           ELSE
               DISPLAY "STATUS: BELOW MINIMUM"
           END-IF.
