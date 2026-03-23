       IDENTIFICATION DIVISION.
       PROGRAM-ID. DODD-FRANK-RPT.
      *================================================================
      * Dodd-Frank Act Section 165 Reporting
      * Computes systemic risk indicators, resolution plan metrics,
      * and Volcker Rule compliance flags.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-INSTITUTION.
           05 WS-INST-ID               PIC X(8).
           05 WS-INST-NAME             PIC X(30).
           05 WS-INST-CATEGORY         PIC X(1).
               88 WS-GSIB              VALUE 'G'.
               88 WS-LARGE-BHC         VALUE 'L'.
               88 WS-REGIONAL          VALUE 'R'.
       01 WS-ASSET-DATA.
           05 WS-TOTAL-ASSETS          PIC S9(15)V99 COMP-3.
           05 WS-RISK-WEIGHTED         PIC S9(15)V99 COMP-3.
           05 WS-OFF-BALANCE           PIC S9(13)V99 COMP-3.
           05 WS-DERIVATIVE-NOTIONAL   PIC S9(15)V99 COMP-3.
       01 WS-TRADING-PORTFOLIO.
           05 WS-PROPRIETARY-POS       PIC S9(13)V99 COMP-3.
           05 WS-MARKET-MAKING         PIC S9(13)V99 COMP-3.
           05 WS-HEDGING-POS           PIC S9(13)V99 COMP-3.
           05 WS-COVERED-FUND-INV      PIC S9(11)V99 COMP-3.
       01 WS-VOLCKER-FIELDS.
           05 WS-PROP-TRADING-FLAG     PIC X(1).
               88 WS-HAS-PROP-TRADING  VALUE 'Y'.
           05 WS-COVERED-FUND-FLAG     PIC X(1).
               88 WS-EXCEEDS-FUND-LIM  VALUE 'Y'.
           05 WS-TIER1-CAPITAL         PIC S9(13)V99 COMP-3.
           05 WS-FUND-LIMIT-PCT        PIC S9(1)V9(4) COMP-3
               VALUE 0.0300.
           05 WS-FUND-LIMIT-AMT        PIC S9(11)V99 COMP-3.
       01 WS-SYSTEMIC-INDICATORS.
           05 WS-INTERCONNECTEDNESS    PIC S9(5)V99 COMP-3.
           05 WS-SUBSTITUTABILITY      PIC S9(5)V99 COMP-3.
           05 WS-COMPLEXITY-SCORE      PIC S9(5)V99 COMP-3.
           05 WS-CROSS-BORDER          PIC S9(5)V99 COMP-3.
           05 WS-SIZE-SCORE            PIC S9(5)V99 COMP-3.
           05 WS-SYSTEMIC-TOTAL        PIC S9(7)V99 COMP-3.
       01 WS-RESOLUTION-PLAN.
           05 WS-CRITICAL-OPS-CT       PIC 9(3).
           05 WS-LEGAL-ENTITIES-CT     PIC 9(3).
           05 WS-MATERIAL-ENTITIES-CT  PIC 9(3).
           05 WS-INTERCONNECT-CT       PIC 9(3).
           05 WS-PLAN-GRADE            PIC X(1).
               88 WS-PLAN-ADEQUATE     VALUE 'A'.
               88 WS-PLAN-DEFICIENT    VALUE 'D'.
               88 WS-PLAN-SHORTCOMING  VALUE 'S'.
       01 WS-SIGN-FIELD
           PIC S9(7)V99 SIGN IS LEADING SEPARATE.
       01 WS-WORK-FIELDS.
           05 WS-TEMP-AMT              PIC S9(15)V99 COMP-3.
           05 WS-TEMP-PCT              PIC S9(3)V9(4) COMP-3.
           05 WS-WEIGHT-SUM            PIC S9(7)V99 COMP-3.
           05 WS-WEIGHT-COUNT          PIC 9(2).
           05 WS-QUOTIENT              PIC S9(7)V99 COMP-3.
           05 WS-DIV-REMAINDER         PIC S9(5)V99 COMP-3.
       01 WS-PROCESS-DATE              PIC 9(8).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-SIZE-SCORE
           PERFORM 3000-CALC-SYSTEMIC-RISK
           PERFORM 4000-CHECK-VOLCKER
           PERFORM 5000-ASSESS-RESOLUTION
           PERFORM 6000-FORMAT-SIGN-FIELD
           PERFORM 7000-DISPLAY-REPORT
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-PROCESS-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-SYSTEMIC-TOTAL
           MOVE 0 TO WS-WEIGHT-SUM
           MOVE 'N' TO WS-PROP-TRADING-FLAG
           MOVE 'N' TO WS-COVERED-FUND-FLAG.
       2000-CALC-SIZE-SCORE.
           IF WS-TOTAL-ASSETS > 0
               COMPUTE WS-TEMP-AMT =
                   WS-TOTAL-ASSETS + WS-OFF-BALANCE +
                   WS-DERIVATIVE-NOTIONAL
               DIVIDE WS-TEMP-AMT BY 1000000000
                   GIVING WS-SIZE-SCORE
                   REMAINDER WS-DIV-REMAINDER
           ELSE
               MOVE 0 TO WS-SIZE-SCORE
           END-IF.
       3000-CALC-SYSTEMIC-RISK.
           COMPUTE WS-SYSTEMIC-TOTAL =
               (WS-SIZE-SCORE * 0.20) +
               (WS-INTERCONNECTEDNESS * 0.20) +
               (WS-SUBSTITUTABILITY * 0.20) +
               (WS-COMPLEXITY-SCORE * 0.20) +
               (WS-CROSS-BORDER * 0.20).
       4000-CHECK-VOLCKER.
           IF WS-PROPRIETARY-POS > 0
               SET WS-HAS-PROP-TRADING TO TRUE
           END-IF
           COMPUTE WS-FUND-LIMIT-AMT =
               WS-TIER1-CAPITAL * WS-FUND-LIMIT-PCT
           IF WS-COVERED-FUND-INV > WS-FUND-LIMIT-AMT
               SET WS-EXCEEDS-FUND-LIM TO TRUE
           END-IF.
       5000-ASSESS-RESOLUTION.
           EVALUATE TRUE
               WHEN WS-GSIB
                   IF WS-MATERIAL-ENTITIES-CT > 100
                       SET WS-PLAN-DEFICIENT TO TRUE
                   ELSE
                       SET WS-PLAN-ADEQUATE TO TRUE
                   END-IF
               WHEN WS-LARGE-BHC
                   IF WS-LEGAL-ENTITIES-CT > 50
                       SET WS-PLAN-SHORTCOMING TO TRUE
                   ELSE
                       SET WS-PLAN-ADEQUATE TO TRUE
                   END-IF
               WHEN OTHER
                   SET WS-PLAN-ADEQUATE TO TRUE
           END-EVALUATE.
       6000-FORMAT-SIGN-FIELD.
           COMPUTE WS-SIGN-FIELD =
               WS-SYSTEMIC-TOTAL * -1.
       7000-DISPLAY-REPORT.
           DISPLAY "DODD-FRANK SECTION 165 REPORT"
           DISPLAY "INSTITUTION: " WS-INST-NAME
           DISPLAY "DATE: " WS-PROCESS-DATE
           DISPLAY "TOTAL ASSETS: " WS-TOTAL-ASSETS
           DISPLAY "SIZE SCORE: " WS-SIZE-SCORE
           DISPLAY "SYSTEMIC RISK: " WS-SYSTEMIC-TOTAL
           IF WS-HAS-PROP-TRADING
               DISPLAY "VOLCKER: PROP TRADING DETECTED"
           END-IF
           IF WS-EXCEEDS-FUND-LIM
               DISPLAY "VOLCKER: FUND LIMIT EXCEEDED"
           END-IF
           DISPLAY "RESOLUTION PLAN: " WS-PLAN-GRADE
           DISPLAY "CRITICAL OPS: " WS-CRITICAL-OPS-CT
           DISPLAY "LEGAL ENTITIES: "
               WS-LEGAL-ENTITIES-CT.
