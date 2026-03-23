       IDENTIFICATION DIVISION.
       PROGRAM-ID. FDIC-ASSESS-TIER.
      *================================================================
      * FDIC Assessment Tiering Engine
      * Assigns deposit insurance assessment rates based on
      * institution size, CAMELS composite, and financial ratios.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-INSTITUTION.
           05 WS-CERT-NUM             PIC 9(6).
           05 WS-INST-NAME            PIC X(30).
           05 WS-CAMELS-COMPOSITE     PIC 9(1).
               88 WS-CAMELS-1         VALUE 1.
               88 WS-CAMELS-2         VALUE 2.
               88 WS-CAMELS-345       VALUES 3 THRU 5.
       01 WS-SIZE-DATA.
           05 WS-TOTAL-ASSETS         PIC S9(15)V99 COMP-3.
           05 WS-SIZE-TIER            PIC X(1).
               88 WS-SMALL            VALUE 'S'.
               88 WS-LARGE            VALUE 'L'.
               88 WS-HIGHLY-COMPLEX   VALUE 'H'.
           05 WS-SMALL-THRESH         PIC S9(15)V99 COMP-3
               VALUE 10000000000.00.
           05 WS-COMPLEX-THRESH       PIC S9(15)V99 COMP-3
               VALUE 50000000000.00.
       01 WS-FINANCIAL-RATIOS.
           05 WS-TIER1-LEV            PIC S9(3)V9(4) COMP-3.
           05 WS-NONCURR-RATIO        PIC S9(3)V9(4) COMP-3.
           05 WS-OREO-RATIO           PIC S9(3)V9(4) COMP-3.
           05 WS-NET-INC-PRETAX       PIC S9(3)V9(4) COMP-3.
           05 WS-ADJ-BROK-RATIO       PIC S9(3)V9(4) COMP-3.
           05 WS-1YR-GROWTH           PIC S9(3)V9(4) COMP-3.
           05 WS-WEIGHTED-AVG-SCORE   PIC S9(5)V99 COMP-3.
       01 WS-RATE-SCHEDULE.
           05 WS-RATE-ENTRY OCCURS 12.
               10 WS-RS-CAMELS        PIC 9(1).
               10 WS-RS-SIZE          PIC X(1).
               10 WS-RS-MIN-RATE      PIC S9(1)V9(4) COMP-3.
               10 WS-RS-MAX-RATE      PIC S9(1)V9(4) COMP-3.
       01 WS-RS-IDX                   PIC 9(2).
       01 WS-SCORING-TABLE.
           05 WS-SCORE-ENTRY OCCURS 6
              ASCENDING KEY IS WS-SC-METRIC
              INDEXED BY WS-SC-IDX.
               10 WS-SC-METRIC        PIC X(4).
               10 WS-SC-VALUE         PIC S9(5)V99 COMP-3.
               10 WS-SC-WEIGHT        PIC S9(1)V9(4) COMP-3.
               10 WS-SC-WEIGHTED      PIC S9(5)V99 COMP-3.
       01 WS-SC-COUNT                 PIC 9(1) VALUE 6.
       01 WS-ASSESS-RESULT.
           05 WS-ASSIGNED-RATE        PIC S9(1)V9(4) COMP-3.
           05 WS-ASSESS-BASE          PIC S9(13)V99 COMP-3.
           05 WS-QUARTERLY-PREMIUM    PIC S9(11)V99 COMP-3.
       01 WS-SURCHARGE-FIELDS.
           05 WS-GSIB-SURCHARGE       PIC S9(1)V9(4) COMP-3.
           05 WS-UNSECURED-ADJ        PIC S9(1)V9(4) COMP-3.
           05 WS-TOTAL-RATE           PIC S9(1)V9(4) COMP-3.
       01 WS-SIGN-PREMIUM
           PIC S9(9)V99 SIGN IS LEADING SEPARATE.
       01 WS-PROCESS-DATE             PIC 9(8).
       01 WS-SEARCH-METRIC            PIC X(4).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-DETERMINE-SIZE-TIER
           PERFORM 3000-CALCULATE-SCORES
           PERFORM 4000-ASSIGN-RATE
           PERFORM 5000-APPLY-SURCHARGES
           PERFORM 6000-COMPUTE-PREMIUM
           PERFORM 7000-DISPLAY-RESULT
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-PROCESS-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-WEIGHTED-AVG-SCORE
           MOVE 0 TO WS-GSIB-SURCHARGE
           MOVE 0 TO WS-UNSECURED-ADJ.
       2000-DETERMINE-SIZE-TIER.
           IF WS-TOTAL-ASSETS >= WS-COMPLEX-THRESH
               SET WS-HIGHLY-COMPLEX TO TRUE
           ELSE IF WS-TOTAL-ASSETS >= WS-SMALL-THRESH
               SET WS-LARGE TO TRUE
           ELSE
               SET WS-SMALL TO TRUE
           END-IF.
       3000-CALCULATE-SCORES.
           PERFORM VARYING WS-SC-IDX FROM 1 BY 1
               UNTIL WS-SC-IDX > WS-SC-COUNT
               COMPUTE WS-SC-WEIGHTED(WS-SC-IDX) =
                   WS-SC-VALUE(WS-SC-IDX) *
                   WS-SC-WEIGHT(WS-SC-IDX)
               ADD WS-SC-WEIGHTED(WS-SC-IDX)
                   TO WS-WEIGHTED-AVG-SCORE
           END-PERFORM.
       4000-ASSIGN-RATE.
           EVALUATE TRUE
               WHEN WS-CAMELS-1
                   IF WS-SMALL
                       MOVE 0.0150 TO WS-ASSIGNED-RATE
                   ELSE
                       MOVE 0.0200 TO WS-ASSIGNED-RATE
                   END-IF
               WHEN WS-CAMELS-2
                   IF WS-SMALL
                       MOVE 0.0300 TO WS-ASSIGNED-RATE
                   ELSE
                       MOVE 0.0400 TO WS-ASSIGNED-RATE
                   END-IF
               WHEN WS-CAMELS-345
                   IF WS-SMALL
                       MOVE 0.0700 TO WS-ASSIGNED-RATE
                   ELSE
                       MOVE 0.1200 TO WS-ASSIGNED-RATE
                   END-IF
               WHEN OTHER
                   MOVE 0.1200 TO WS-ASSIGNED-RATE
           END-EVALUATE.
       5000-APPLY-SURCHARGES.
           IF WS-HIGHLY-COMPLEX
               MOVE 0.0050 TO WS-GSIB-SURCHARGE
           END-IF
           IF WS-ADJ-BROK-RATIO > 10.0
               MOVE 0.0025 TO WS-UNSECURED-ADJ
           END-IF
           COMPUTE WS-TOTAL-RATE =
               WS-ASSIGNED-RATE + WS-GSIB-SURCHARGE +
               WS-UNSECURED-ADJ.
       6000-COMPUTE-PREMIUM.
           COMPUTE WS-QUARTERLY-PREMIUM =
               WS-ASSESS-BASE * WS-TOTAL-RATE / 100
           COMPUTE WS-SIGN-PREMIUM =
               WS-QUARTERLY-PREMIUM.
       7000-DISPLAY-RESULT.
           DISPLAY "FDIC ASSESSMENT TIERING"
           DISPLAY "CERT: " WS-CERT-NUM
           DISPLAY "NAME: " WS-INST-NAME
           DISPLAY "DATE: " WS-PROCESS-DATE
           DISPLAY "SIZE TIER: " WS-SIZE-TIER
           DISPLAY "CAMELS: " WS-CAMELS-COMPOSITE
           DISPLAY "WEIGHTED SCORE: "
               WS-WEIGHTED-AVG-SCORE
           DISPLAY "BASE RATE: " WS-ASSIGNED-RATE
           DISPLAY "TOTAL RATE: " WS-TOTAL-RATE
           DISPLAY "PREMIUM: " WS-SIGN-PREMIUM.
