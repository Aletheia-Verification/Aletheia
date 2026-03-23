       IDENTIFICATION DIVISION.
       PROGRAM-ID. OCC-EXAM-EXTRACT.
      *================================================================
      * OCC Examination Data Extraction
      * Extracts and formats key safety/soundness metrics for
      * OCC exam preparation including CAMELS component data.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-BANK-INFO.
           05 WS-CHARTER-NUM           PIC 9(6).
           05 WS-BANK-NAME             PIC X(30).
           05 WS-EXAM-CYCLE            PIC X(2).
               88 WS-ANNUAL            VALUE '12'.
               88 WS-18-MONTH          VALUE '18'.
       01 WS-CAMELS-DATA.
           05 WS-CAPITAL-SCORE         PIC 9(1).
           05 WS-ASSET-QUALITY         PIC 9(1).
           05 WS-MANAGEMENT            PIC 9(1).
           05 WS-EARNINGS              PIC 9(1).
           05 WS-LIQUIDITY             PIC 9(1).
           05 WS-SENSITIVITY           PIC 9(1).
           05 WS-COMPOSITE             PIC 9(1).
       01 WS-CAPITAL-METRICS.
           05 WS-TIER1-LEV-RATIO       PIC S9(3)V9(4) COMP-3.
           05 WS-CET1-RATIO            PIC S9(3)V9(4) COMP-3.
           05 WS-TOTAL-CAP-RATIO       PIC S9(3)V9(4) COMP-3.
           05 WS-TCE-RATIO             PIC S9(3)V9(4) COMP-3.
       01 WS-ASSET-METRICS.
           05 WS-CLASSIFIED-ASSETS     PIC S9(11)V99 COMP-3.
           05 WS-TOTAL-CAPITAL         PIC S9(11)V99 COMP-3.
           05 WS-CLASS-TO-CAP          PIC S9(3)V9(4) COMP-3.
           05 WS-NPA-RATIO             PIC S9(3)V9(4) COMP-3.
           05 WS-NET-CHARGEOFF-RT      PIC S9(3)V9(4) COMP-3.
       01 WS-EARNINGS-METRICS.
           05 WS-ROA                   PIC S9(1)V9(4) COMP-3.
           05 WS-ROE                   PIC S9(3)V9(4) COMP-3.
           05 WS-NIM                   PIC S9(1)V9(4) COMP-3.
           05 WS-EFFICIENCY-RATIO      PIC S9(3)V9(2) COMP-3.
       01 WS-LIQUIDITY-METRICS.
           05 WS-LOAN-TO-DEPOSIT       PIC S9(3)V9(4) COMP-3.
           05 WS-CASH-TO-ASSETS        PIC S9(3)V9(4) COMP-3.
           05 WS-BORROWING-RATIO       PIC S9(3)V9(4) COMP-3.
       01 WS-FINDINGS-TABLE.
           05 WS-FINDING OCCURS 15
              ASCENDING KEY IS WS-FIND-SEVERITY
              INDEXED BY WS-FIND-IDX.
               10 WS-FIND-SEVERITY     PIC 9(1).
               10 WS-FIND-CATEGORY     PIC X(1).
               10 WS-FIND-DESC         PIC X(40).
               10 WS-FIND-STATUS       PIC X(1).
                   88 WS-FIND-OPEN     VALUE 'O'.
                   88 WS-FIND-CLOSED   VALUE 'C'.
       01 WS-FIND-COUNT                PIC 9(2).
       01 WS-THRESHOLDS.
           05 WS-CLASS-THRESH          PIC S9(3)V9(4) COMP-3
               VALUE 40.0000.
           05 WS-NPA-THRESH            PIC S9(3)V9(4) COMP-3
               VALUE 5.0000.
       01 WS-COUNTERS.
           05 WS-OPEN-FINDINGS         PIC 9(2).
           05 WS-CRITICAL-FINDINGS     PIC 9(2).
           05 WS-MRA-COUNT             PIC 9(2).
           05 WS-MRIA-COUNT            PIC 9(2).
       01 WS-COMPOSITE-CALC.
           05 WS-SCORE-SUM             PIC 9(3).
           05 WS-SCORE-AVG             PIC S9(1)V9(2) COMP-3.
           05 WS-SCORE-REMAINDER       PIC S9(1)V99 COMP-3.
       01 WS-PROCESS-DATE              PIC 9(8).
       01 WS-EXAM-DATE                 PIC 9(8).
       01 WS-SEARCH-SEV                PIC 9(1).
       01 WS-REPORT-LINE               PIC X(80).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-RATIOS
           PERFORM 3000-SCORE-CAMELS
           PERFORM 4000-TALLY-FINDINGS
           PERFORM 5000-ASSESS-RISK
           PERFORM 6000-DISPLAY-EXTRACT
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-PROCESS-DATE FROM DATE YYYYMMDD
           MOVE WS-PROCESS-DATE TO WS-EXAM-DATE
           MOVE 0 TO WS-OPEN-FINDINGS
           MOVE 0 TO WS-CRITICAL-FINDINGS
           MOVE 0 TO WS-MRA-COUNT
           MOVE 0 TO WS-MRIA-COUNT.
       2000-CALC-RATIOS.
           IF WS-TOTAL-CAPITAL > 0
               COMPUTE WS-CLASS-TO-CAP =
                   (WS-CLASSIFIED-ASSETS /
                    WS-TOTAL-CAPITAL) * 100
           END-IF.
       3000-SCORE-CAMELS.
           COMPUTE WS-SCORE-SUM =
               WS-CAPITAL-SCORE + WS-ASSET-QUALITY +
               WS-MANAGEMENT + WS-EARNINGS +
               WS-LIQUIDITY + WS-SENSITIVITY
           DIVIDE WS-SCORE-SUM BY 6
               GIVING WS-SCORE-AVG
               REMAINDER WS-SCORE-REMAINDER
           IF WS-SCORE-AVG < 1.5
               MOVE 1 TO WS-COMPOSITE
           ELSE IF WS-SCORE-AVG < 2.5
               MOVE 2 TO WS-COMPOSITE
           ELSE IF WS-SCORE-AVG < 3.5
               MOVE 3 TO WS-COMPOSITE
           ELSE IF WS-SCORE-AVG < 4.5
               MOVE 4 TO WS-COMPOSITE
           ELSE
               MOVE 5 TO WS-COMPOSITE
           END-IF.
       4000-TALLY-FINDINGS.
           PERFORM VARYING WS-FIND-IDX FROM 1 BY 1
               UNTIL WS-FIND-IDX > WS-FIND-COUNT
               IF WS-FIND-OPEN(WS-FIND-IDX)
                   ADD 1 TO WS-OPEN-FINDINGS
                   IF WS-FIND-SEVERITY(WS-FIND-IDX) >= 4
                       ADD 1 TO WS-CRITICAL-FINDINGS
                       ADD 1 TO WS-MRIA-COUNT
                   ELSE IF WS-FIND-SEVERITY(WS-FIND-IDX)
                       >= 3
                       ADD 1 TO WS-MRA-COUNT
                   END-IF
               END-IF
           END-PERFORM.
       5000-ASSESS-RISK.
           IF WS-CLASS-TO-CAP > WS-CLASS-THRESH
               DISPLAY "WARNING: CLASSIFIED/CAPITAL HIGH"
           END-IF
           IF WS-NPA-RATIO > WS-NPA-THRESH
               DISPLAY "WARNING: NPA RATIO ELEVATED"
           END-IF
           IF WS-COMPOSITE >= 4
               DISPLAY "ALERT: PROBLEM INSTITUTION"
           END-IF.
       6000-DISPLAY-EXTRACT.
           DISPLAY "OCC EXAMINATION DATA EXTRACT"
           DISPLAY "CHARTER: " WS-CHARTER-NUM
           DISPLAY "BANK: " WS-BANK-NAME
           DISPLAY "DATE: " WS-PROCESS-DATE
           DISPLAY "--- CAMELS ---"
           DISPLAY "CAPITAL: " WS-CAPITAL-SCORE
           DISPLAY "ASSET QUALITY: " WS-ASSET-QUALITY
           DISPLAY "MANAGEMENT: " WS-MANAGEMENT
           DISPLAY "EARNINGS: " WS-EARNINGS
           DISPLAY "LIQUIDITY: " WS-LIQUIDITY
           DISPLAY "SENSITIVITY: " WS-SENSITIVITY
           DISPLAY "COMPOSITE: " WS-COMPOSITE
           DISPLAY "--- KEY RATIOS ---"
           DISPLAY "CET1: " WS-CET1-RATIO "%"
           DISPLAY "CLASSIFIED/CAPITAL: "
               WS-CLASS-TO-CAP "%"
           DISPLAY "ROA: " WS-ROA
           DISPLAY "NIM: " WS-NIM
           DISPLAY "--- FINDINGS ---"
           DISPLAY "OPEN: " WS-OPEN-FINDINGS
           DISPLAY "MRA: " WS-MRA-COUNT
           DISPLAY "MRIA: " WS-MRIA-COUNT.
