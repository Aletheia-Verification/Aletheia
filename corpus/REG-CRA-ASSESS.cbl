       IDENTIFICATION DIVISION.
       PROGRAM-ID. REG-CRA-ASSESS.
      *================================================================
      * Community Reinvestment Act Assessment Engine
      * Evaluates lending, investment, and service tests for
      * CRA compliance rating determination.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-BANK-DATA.
           05 WS-BANK-ID              PIC X(10).
           05 WS-BANK-NAME            PIC X(30).
           05 WS-ASSESSMENT-AREA      PIC X(20).
           05 WS-BANK-SIZE            PIC X(1).
               88 WS-LARGE-BANK       VALUE 'L'.
               88 WS-INTERMEDIATE     VALUE 'I'.
               88 WS-SMALL-BANK       VALUE 'S'.
       01 WS-LENDING-TEST.
           05 WS-HMDA-LOANS           PIC 9(5).
           05 WS-HMDA-LMI             PIC 9(5).
           05 WS-HMDA-LMI-PCT         PIC S9(3)V9(4) COMP-3.
           05 WS-SM-BIZ-LOANS         PIC 9(5).
           05 WS-SM-BIZ-LMI           PIC 9(5).
           05 WS-SM-BIZ-LMI-PCT       PIC S9(3)V9(4) COMP-3.
           05 WS-CD-LOANS-AMT         PIC S9(11)V99 COMP-3.
           05 WS-LENDING-SCORE        PIC 9(2).
       01 WS-INVEST-TEST.
           05 WS-QI-AMOUNT            PIC S9(11)V99 COMP-3.
           05 WS-QI-AS-PCT-ASSETS     PIC S9(3)V9(4) COMP-3.
           05 WS-QI-INNOVATIVE        PIC X(1).
               88 WS-IS-INNOVATIVE    VALUE 'Y'.
           05 WS-INVEST-SCORE         PIC 9(2).
       01 WS-SERVICE-TEST.
           05 WS-BRANCHES-TOTAL       PIC 9(3).
           05 WS-BRANCHES-LMI         PIC 9(3).
           05 WS-BRANCH-LMI-PCT       PIC S9(3)V9(4) COMP-3.
           05 WS-CD-SERVICES-CT       PIC 9(3).
           05 WS-SERVICE-SCORE        PIC 9(2).
       01 WS-PEER-DATA.
           05 WS-PEER OCCURS 5
              ASCENDING KEY IS WS-PR-ID
              INDEXED BY WS-PR-IDX.
               10 WS-PR-ID            PIC X(4).
               10 WS-PR-LEND-PCT      PIC S9(3)V9(4) COMP-3.
               10 WS-PR-INV-PCT       PIC S9(3)V9(4) COMP-3.
       01 WS-PR-COUNT                 PIC 9(1) VALUE 5.
       01 WS-COMPOSITE-FIELDS.
           05 WS-COMPOSITE-SCORE      PIC 9(3).
           05 WS-COMPOSITE-RATING     PIC X(12).
               88 WS-OUTSTANDING      VALUE 'OUTSTANDING'.
               88 WS-SATISFACTORY     VALUE 'SATISFACTORY'.
               88 WS-NEEDS-IMPROVE    VALUE 'NEEDS IMPROV'.
               88 WS-SUBSTANTIAL-NC   VALUE 'SUBST NONCOM'.
       01 WS-WEIGHT-FIELDS.
           05 WS-LENDING-WEIGHT       PIC S9(1)V9(2) COMP-3
               VALUE 0.50.
           05 WS-INVEST-WEIGHT        PIC S9(1)V9(2) COMP-3
               VALUE 0.25.
           05 WS-SERVICE-WEIGHT       PIC S9(1)V9(2) COMP-3
               VALUE 0.25.
           05 WS-WEIGHTED-SCORE       PIC S9(5)V99 COMP-3.
       01 WS-WORK-FIELDS.
           05 WS-TEMP-PCT             PIC S9(3)V9(4) COMP-3.
           05 WS-PEER-AVG             PIC S9(3)V9(4) COMP-3.
           05 WS-PEER-SUM             PIC S9(5)V9(4) COMP-3.
       01 WS-DIVIDE-FIELDS.
           05 WS-AVG-RESULT           PIC S9(3)V9(4) COMP-3.
           05 WS-AVG-REMAIN           PIC S9(1)V9(4) COMP-3.
       01 WS-PROCESS-DATE             PIC 9(8).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-SCORE-LENDING
           PERFORM 3000-SCORE-INVESTMENT
           PERFORM 4000-SCORE-SERVICE
           PERFORM 5000-CALC-PEER-COMPARISON
           PERFORM 6000-DETERMINE-RATING
           PERFORM 7000-DISPLAY-REPORT
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-PROCESS-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-LENDING-SCORE
           MOVE 0 TO WS-INVEST-SCORE
           MOVE 0 TO WS-SERVICE-SCORE
           MOVE 0 TO WS-COMPOSITE-SCORE.
       2000-SCORE-LENDING.
           IF WS-HMDA-LOANS > 0
               COMPUTE WS-HMDA-LMI-PCT =
                   (WS-HMDA-LMI / WS-HMDA-LOANS) * 100
           END-IF
           IF WS-SM-BIZ-LOANS > 0
               COMPUTE WS-SM-BIZ-LMI-PCT =
                   (WS-SM-BIZ-LMI / WS-SM-BIZ-LOANS) * 100
           END-IF
           EVALUATE TRUE
               WHEN WS-HMDA-LMI-PCT >= 60
                   MOVE 90 TO WS-LENDING-SCORE
               WHEN WS-HMDA-LMI-PCT >= 40
                   MOVE 70 TO WS-LENDING-SCORE
               WHEN WS-HMDA-LMI-PCT >= 20
                   MOVE 50 TO WS-LENDING-SCORE
               WHEN OTHER
                   MOVE 30 TO WS-LENDING-SCORE
           END-EVALUATE.
       3000-SCORE-INVESTMENT.
           IF WS-QI-AMOUNT > 0
               IF WS-QI-AS-PCT-ASSETS >= 2.0
                   MOVE 90 TO WS-INVEST-SCORE
               ELSE IF WS-QI-AS-PCT-ASSETS >= 1.0
                   MOVE 70 TO WS-INVEST-SCORE
               ELSE
                   MOVE 50 TO WS-INVEST-SCORE
               END-IF
           ELSE
               MOVE 20 TO WS-INVEST-SCORE
           END-IF
           IF WS-IS-INNOVATIVE
               ADD 10 TO WS-INVEST-SCORE
           END-IF.
       4000-SCORE-SERVICE.
           IF WS-BRANCHES-TOTAL > 0
               COMPUTE WS-BRANCH-LMI-PCT =
                   (WS-BRANCHES-LMI /
                    WS-BRANCHES-TOTAL) * 100
           END-IF
           IF WS-BRANCH-LMI-PCT >= 30
               MOVE 80 TO WS-SERVICE-SCORE
           ELSE IF WS-BRANCH-LMI-PCT >= 15
               MOVE 60 TO WS-SERVICE-SCORE
           ELSE
               MOVE 40 TO WS-SERVICE-SCORE
           END-IF
           IF WS-CD-SERVICES-CT >= 10
               ADD 10 TO WS-SERVICE-SCORE
           END-IF.
       5000-CALC-PEER-COMPARISON.
           MOVE 0 TO WS-PEER-SUM
           PERFORM VARYING WS-PR-IDX FROM 1 BY 1
               UNTIL WS-PR-IDX > WS-PR-COUNT
               ADD WS-PR-LEND-PCT(WS-PR-IDX)
                   TO WS-PEER-SUM
           END-PERFORM
           IF WS-PR-COUNT > 0
               DIVIDE WS-PEER-SUM BY WS-PR-COUNT
                   GIVING WS-PEER-AVG
                   REMAINDER WS-AVG-REMAIN
           END-IF.
       6000-DETERMINE-RATING.
           COMPUTE WS-WEIGHTED-SCORE =
               (WS-LENDING-SCORE * WS-LENDING-WEIGHT) +
               (WS-INVEST-SCORE * WS-INVEST-WEIGHT) +
               (WS-SERVICE-SCORE * WS-SERVICE-WEIGHT)
           COMPUTE WS-COMPOSITE-SCORE = WS-WEIGHTED-SCORE
           EVALUATE TRUE
               WHEN WS-COMPOSITE-SCORE >= 80
                   SET WS-OUTSTANDING TO TRUE
               WHEN WS-COMPOSITE-SCORE >= 60
                   SET WS-SATISFACTORY TO TRUE
               WHEN WS-COMPOSITE-SCORE >= 40
                   SET WS-NEEDS-IMPROVE TO TRUE
               WHEN OTHER
                   SET WS-SUBSTANTIAL-NC TO TRUE
           END-EVALUATE.
       7000-DISPLAY-REPORT.
           DISPLAY "CRA ASSESSMENT REPORT"
           DISPLAY "DATE: " WS-PROCESS-DATE
           DISPLAY "BANK: " WS-BANK-NAME
           DISPLAY "AREA: " WS-ASSESSMENT-AREA
           DISPLAY "LENDING SCORE: " WS-LENDING-SCORE
           DISPLAY "INVESTMENT SCORE: " WS-INVEST-SCORE
           DISPLAY "SERVICE SCORE: " WS-SERVICE-SCORE
           DISPLAY "COMPOSITE: " WS-COMPOSITE-SCORE
           DISPLAY "RATING: " WS-COMPOSITE-RATING
           DISPLAY "PEER AVG LENDING: " WS-PEER-AVG.
