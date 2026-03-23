       IDENTIFICATION DIVISION.
       PROGRAM-ID. CCAR-STRESS-TEST.
      *================================================================
      * CCAR Stress Test - Comprehensive Capital Analysis
      * Applies macroeconomic scenarios to loan portfolio segments
      * with probability-weighted loss estimation.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-MACRO-SCENARIO.
           05 WS-SCENARIO-ID           PIC X(3).
               88 WS-BASE              VALUE 'BAS'.
               88 WS-ADVERSE           VALUE 'ADV'.
               88 WS-SEVERELY-ADV      VALUE 'SEV'.
           05 WS-UNEMPLOYMENT-RT       PIC S9(2)V9(2) COMP-3.
           05 WS-GDP-CHANGE            PIC S9(2)V9(2) COMP-3.
           05 WS-HPI-CHANGE            PIC S9(2)V9(2) COMP-3.
           05 WS-CRE-CHANGE            PIC S9(2)V9(2) COMP-3.
           05 WS-TREASURY-10Y          PIC S9(2)V9(4) COMP-3.
       01 WS-PORTFOLIO-SEGMENTS.
           05 WS-SEGMENT OCCURS 8
              ASCENDING KEY IS WS-SEG-CODE
              INDEXED BY WS-SEG-IDX.
               10 WS-SEG-CODE          PIC X(4).
               10 WS-SEG-NAME          PIC X(20).
               10 WS-SEG-BALANCE       PIC S9(13)V99 COMP-3.
               10 WS-SEG-PD            PIC S9(1)V9(6) COMP-3.
               10 WS-SEG-LGD           PIC S9(1)V9(4) COMP-3.
               10 WS-SEG-EAD           PIC S9(13)V99 COMP-3.
               10 WS-SEG-EL            PIC S9(11)V99 COMP-3.
               10 WS-SEG-STRESSED-EL   PIC S9(11)V99 COMP-3.
       01 WS-SEG-COUNT                 PIC 9(1) VALUE 8.
       01 WS-CAPITAL-DATA.
           05 WS-CET1-CAPITAL          PIC S9(13)V99 COMP-3.
           05 WS-TIER1-CAPITAL         PIC S9(13)V99 COMP-3.
           05 WS-TOTAL-CAPITAL         PIC S9(13)V99 COMP-3.
           05 WS-RWA                   PIC S9(13)V99 COMP-3.
       01 WS-STRESS-RESULTS.
           05 WS-TOTAL-EL              PIC S9(13)V99 COMP-3.
           05 WS-TOTAL-STRESSED-EL     PIC S9(13)V99 COMP-3.
           05 WS-PRE-STRESS-CET1       PIC S9(3)V9(4) COMP-3.
           05 WS-POST-STRESS-CET1      PIC S9(3)V9(4) COMP-3.
           05 WS-MIN-CET1              PIC S9(3)V9(4) COMP-3
               VALUE 4.5000.
           05 WS-BUFFER                PIC S9(3)V9(4) COMP-3
               VALUE 2.5000.
       01 WS-PASS-FAIL                 PIC X(4).
           88 WS-PASSES                VALUE 'PASS'.
           88 WS-FAILS                 VALUE 'FAIL'.
       01 WS-STRESS-MULTIPLIER         PIC S9(2)V9(4) COMP-3.
       01 WS-WORK-FIELDS.
           05 WS-TEMP-LOSS             PIC S9(13)V99 COMP-3.
           05 WS-TEMP-RATIO            PIC S9(3)V9(6) COMP-3.
           05 WS-CAPITAL-SHORTFALL     PIC S9(13)V99 COMP-3.
           05 WS-PCT-CHANGE            PIC S9(3)V9(4) COMP-3.
       01 WS-SEARCH-CODE               PIC X(4).
       01 WS-PROCESS-DATE              PIC 9(8).
       01 WS-QUARTER                   PIC 9(1).
       01 WS-REPORT-LINE               PIC X(80).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-SET-SCENARIO
           PERFORM 3000-CALC-BASELINE-EL
           PERFORM 4000-APPLY-STRESS
           PERFORM 5000-CALC-CAPITAL-RATIOS
           PERFORM 6000-DETERMINE-RESULT
           PERFORM 7000-GENERATE-REPORT
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-PROCESS-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-TOTAL-EL
           MOVE 0 TO WS-TOTAL-STRESSED-EL
           SET WS-PASSES TO TRUE.
       2000-SET-SCENARIO.
           EVALUATE TRUE
               WHEN WS-BASE
                   MOVE 1.0000 TO WS-STRESS-MULTIPLIER
               WHEN WS-ADVERSE
                   MOVE 2.5000 TO WS-STRESS-MULTIPLIER
               WHEN WS-SEVERELY-ADV
                   MOVE 4.5000 TO WS-STRESS-MULTIPLIER
               WHEN OTHER
                   MOVE 1.0000 TO WS-STRESS-MULTIPLIER
           END-EVALUATE.
       3000-CALC-BASELINE-EL.
           PERFORM VARYING WS-SEG-IDX FROM 1 BY 1
               UNTIL WS-SEG-IDX > WS-SEG-COUNT
               COMPUTE WS-SEG-EAD(WS-SEG-IDX) =
                   WS-SEG-BALANCE(WS-SEG-IDX)
               COMPUTE WS-SEG-EL(WS-SEG-IDX) =
                   WS-SEG-PD(WS-SEG-IDX) *
                   WS-SEG-LGD(WS-SEG-IDX) *
                   WS-SEG-EAD(WS-SEG-IDX)
               ADD WS-SEG-EL(WS-SEG-IDX)
                   TO WS-TOTAL-EL
           END-PERFORM.
       4000-APPLY-STRESS.
           PERFORM VARYING WS-SEG-IDX FROM 1 BY 1
               UNTIL WS-SEG-IDX > WS-SEG-COUNT
               COMPUTE WS-SEG-STRESSED-EL(WS-SEG-IDX) =
                   WS-SEG-EL(WS-SEG-IDX) *
                   WS-STRESS-MULTIPLIER
               IF WS-SEG-STRESSED-EL(WS-SEG-IDX) >
                   WS-SEG-EAD(WS-SEG-IDX)
                   MOVE WS-SEG-EAD(WS-SEG-IDX)
                       TO WS-SEG-STRESSED-EL(WS-SEG-IDX)
               END-IF
               ADD WS-SEG-STRESSED-EL(WS-SEG-IDX)
                   TO WS-TOTAL-STRESSED-EL
           END-PERFORM.
       5000-CALC-CAPITAL-RATIOS.
           IF WS-RWA > 0
               COMPUTE WS-PRE-STRESS-CET1 =
                   (WS-CET1-CAPITAL / WS-RWA) * 100
               COMPUTE WS-POST-STRESS-CET1 =
                   ((WS-CET1-CAPITAL -
                     WS-TOTAL-STRESSED-EL) /
                    WS-RWA) * 100
           ELSE
               MOVE 0 TO WS-PRE-STRESS-CET1
               MOVE 0 TO WS-POST-STRESS-CET1
           END-IF
           COMPUTE WS-PCT-CHANGE =
               WS-PRE-STRESS-CET1 - WS-POST-STRESS-CET1.
       6000-DETERMINE-RESULT.
           COMPUTE WS-TEMP-RATIO =
               WS-MIN-CET1 + WS-BUFFER
           IF WS-POST-STRESS-CET1 < WS-TEMP-RATIO
               SET WS-FAILS TO TRUE
               COMPUTE WS-CAPITAL-SHORTFALL =
                   (WS-TEMP-RATIO - WS-POST-STRESS-CET1)
                   * WS-RWA / 100
           ELSE
               SET WS-PASSES TO TRUE
               MOVE 0 TO WS-CAPITAL-SHORTFALL
           END-IF.
       7000-GENERATE-REPORT.
           DISPLAY "CCAR STRESS TEST RESULTS"
           DISPLAY "DATE: " WS-PROCESS-DATE
           DISPLAY "SCENARIO: " WS-SCENARIO-ID
           DISPLAY "TOTAL EL (BASELINE): " WS-TOTAL-EL
           DISPLAY "TOTAL EL (STRESSED): "
               WS-TOTAL-STRESSED-EL
           DISPLAY "PRE-STRESS CET1: "
               WS-PRE-STRESS-CET1 "%"
           DISPLAY "POST-STRESS CET1: "
               WS-POST-STRESS-CET1 "%"
           DISPLAY "RESULT: " WS-PASS-FAIL
           IF WS-FAILS
               DISPLAY "CAPITAL SHORTFALL: "
                   WS-CAPITAL-SHORTFALL
           END-IF
           PERFORM VARYING WS-SEG-IDX FROM 1 BY 1
               UNTIL WS-SEG-IDX > WS-SEG-COUNT
               DISPLAY "  SEG " WS-SEG-CODE(WS-SEG-IDX)
                   " EL=" WS-SEG-STRESSED-EL(WS-SEG-IDX)
           END-PERFORM.
