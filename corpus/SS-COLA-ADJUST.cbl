       IDENTIFICATION DIVISION.
       PROGRAM-ID. SS-COLA-ADJUST.
      *================================================================
      * Social Security COLA Adjustment Batch
      * Applies annual Cost-of-Living Adjustment to beneficiary
      * records using CPI-W third-quarter comparison.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-COLA-PARAMS.
           05 WS-CURRENT-YEAR          PIC 9(4).
           05 WS-CPI-W-CURRENT         PIC S9(5)V9(4) COMP-3.
           05 WS-CPI-W-PRIOR           PIC S9(5)V9(4) COMP-3.
           05 WS-COLA-PCT              PIC S9(3)V9(4) COMP-3.
           05 WS-COLA-EFFECTIVE        PIC 9(8).
       01 WS-BENEFICIARY-TABLE.
           05 WS-BENE OCCURS 25
              ASCENDING KEY IS WS-BENE-SSN
              INDEXED BY WS-BENE-IDX.
               10 WS-BENE-SSN          PIC X(9).
               10 WS-BENE-NAME         PIC X(25).
               10 WS-BENE-TYPE         PIC X(1).
                   88 WS-RETIRED       VALUE 'R'.
                   88 WS-DISABLED      VALUE 'D'.
                   88 WS-SURVIVOR      VALUE 'S'.
                   88 WS-DEPENDENT     VALUE 'P'.
               10 WS-BENE-CURRENT-AMT  PIC S9(5)V99 COMP-3.
               10 WS-BENE-NEW-AMT      PIC S9(5)V99 COMP-3.
               10 WS-BENE-INCREASE     PIC S9(5)V99 COMP-3.
               10 WS-BENE-PART-B       PIC S9(5)V99 COMP-3.
               10 WS-BENE-NET-CHG      PIC S9(5)V99 COMP-3.
       01 WS-BENE-COUNT                PIC 9(3) VALUE 25.
       01 WS-SUMMARY.
           05 WS-TOTAL-PROCESSED       PIC 9(5).
           05 WS-TOTAL-INCREASED       PIC 9(5).
           05 WS-TOTAL-HELD-HARMLESS   PIC 9(5).
           05 WS-TOTAL-OLD-COST        PIC S9(11)V99 COMP-3.
           05 WS-TOTAL-NEW-COST        PIC S9(11)V99 COMP-3.
           05 WS-TOTAL-INCREASE-AMT    PIC S9(11)V99 COMP-3.
       01 WS-PART-B-FIELDS.
           05 WS-PART-B-OLD            PIC S9(5)V99 COMP-3
               VALUE 174.70.
           05 WS-PART-B-NEW            PIC S9(5)V99 COMP-3
               VALUE 185.00.
           05 WS-PART-B-INCREASE       PIC S9(5)V99 COMP-3.
       01 WS-HOLD-HARMLESS-FLAG        PIC X(1).
           88 WS-APPLY-HOLD-HARMLESS   VALUE 'Y'.
       01 WS-WORK-FIELDS.
           05 WS-TEMP-AMT              PIC S9(7)V99 COMP-3.
           05 WS-TEMP-INCREASE         PIC S9(5)V99 COMP-3.
           05 WS-COLA-DOLLAR           PIC S9(5)V99 COMP-3.
       01 WS-SEARCH-SSN                PIC X(9).
       01 WS-PROCESS-DATE              PIC 9(8).
       01 WS-DIVIDE-FIELDS.
           05 WS-AVG-INCREASE          PIC S9(5)V99 COMP-3.
           05 WS-AVG-REMAINDER         PIC S9(3)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-COMPUTE-COLA-PCT
           PERFORM 3000-APPLY-COLA
           PERFORM 4000-APPLY-HOLD-HARMLESS
           PERFORM 5000-COMPUTE-SUMMARY
           PERFORM 6000-DISPLAY-REPORT
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-PROCESS-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-TOTAL-PROCESSED
           MOVE 0 TO WS-TOTAL-INCREASED
           MOVE 0 TO WS-TOTAL-HELD-HARMLESS
           MOVE 0 TO WS-TOTAL-OLD-COST
           MOVE 0 TO WS-TOTAL-NEW-COST
           MOVE 0 TO WS-TOTAL-INCREASE-AMT
           COMPUTE WS-PART-B-INCREASE =
               WS-PART-B-NEW - WS-PART-B-OLD.
       2000-COMPUTE-COLA-PCT.
           IF WS-CPI-W-PRIOR > 0
               COMPUTE WS-COLA-PCT =
                   ((WS-CPI-W-CURRENT - WS-CPI-W-PRIOR)
                    / WS-CPI-W-PRIOR) * 100
           ELSE
               MOVE 0 TO WS-COLA-PCT
           END-IF
           IF WS-COLA-PCT < 0
               MOVE 0 TO WS-COLA-PCT
           END-IF.
       3000-APPLY-COLA.
           PERFORM VARYING WS-BENE-IDX FROM 1 BY 1
               UNTIL WS-BENE-IDX > WS-BENE-COUNT
               ADD 1 TO WS-TOTAL-PROCESSED
               COMPUTE WS-COLA-DOLLAR =
                   WS-BENE-CURRENT-AMT(WS-BENE-IDX) *
                   (WS-COLA-PCT / 100)
               COMPUTE WS-BENE-NEW-AMT(WS-BENE-IDX) =
                   WS-BENE-CURRENT-AMT(WS-BENE-IDX) +
                   WS-COLA-DOLLAR
               MOVE WS-COLA-DOLLAR
                   TO WS-BENE-INCREASE(WS-BENE-IDX)
               ADD WS-BENE-CURRENT-AMT(WS-BENE-IDX)
                   TO WS-TOTAL-OLD-COST
           END-PERFORM.
       4000-APPLY-HOLD-HARMLESS.
           PERFORM VARYING WS-BENE-IDX FROM 1 BY 1
               UNTIL WS-BENE-IDX > WS-BENE-COUNT
               COMPUTE WS-BENE-NET-CHG(WS-BENE-IDX) =
                   WS-BENE-INCREASE(WS-BENE-IDX) -
                   WS-PART-B-INCREASE
               IF WS-BENE-NET-CHG(WS-BENE-IDX) < 0
                   MOVE 0 TO WS-BENE-INCREASE(WS-BENE-IDX)
                   MOVE WS-BENE-CURRENT-AMT(WS-BENE-IDX)
                       TO WS-BENE-NEW-AMT(WS-BENE-IDX)
                   ADD 1 TO WS-TOTAL-HELD-HARMLESS
               ELSE
                   ADD 1 TO WS-TOTAL-INCREASED
               END-IF
               ADD WS-BENE-NEW-AMT(WS-BENE-IDX)
                   TO WS-TOTAL-NEW-COST
           END-PERFORM.
       5000-COMPUTE-SUMMARY.
           COMPUTE WS-TOTAL-INCREASE-AMT =
               WS-TOTAL-NEW-COST - WS-TOTAL-OLD-COST
           IF WS-TOTAL-INCREASED > 0
               DIVIDE WS-TOTAL-INCREASE-AMT
                   BY WS-TOTAL-INCREASED
                   GIVING WS-AVG-INCREASE
                   REMAINDER WS-AVG-REMAINDER
           END-IF.
       6000-DISPLAY-REPORT.
           DISPLAY "SS COLA ADJUSTMENT REPORT"
           DISPLAY "YEAR: " WS-CURRENT-YEAR
           DISPLAY "DATE: " WS-PROCESS-DATE
           DISPLAY "CPI-W CURRENT: " WS-CPI-W-CURRENT
           DISPLAY "CPI-W PRIOR: " WS-CPI-W-PRIOR
           DISPLAY "COLA PERCENTAGE: " WS-COLA-PCT "%"
           DISPLAY "TOTAL PROCESSED: " WS-TOTAL-PROCESSED
           DISPLAY "INCREASED: " WS-TOTAL-INCREASED
           DISPLAY "HELD HARMLESS: "
               WS-TOTAL-HELD-HARMLESS
           DISPLAY "OLD MONTHLY COST: " WS-TOTAL-OLD-COST
           DISPLAY "NEW MONTHLY COST: " WS-TOTAL-NEW-COST
           DISPLAY "TOTAL INCREASE: "
               WS-TOTAL-INCREASE-AMT
           DISPLAY "AVG INCREASE: " WS-AVG-INCREASE.
