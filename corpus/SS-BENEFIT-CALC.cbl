       IDENTIFICATION DIVISION.
       PROGRAM-ID. SS-BENEFIT-CALC.
      *================================================================
      * Social Security Benefit Calculation
      * Computes PIA (Primary Insurance Amount) from AIME using
      * bend-point formula with COLA adjustments.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-WORKER-DATA.
           05 WS-WORKER-SSN            PIC X(9).
           05 WS-BIRTH-YEAR            PIC 9(4).
           05 WS-RETIRE-YEAR           PIC 9(4).
           05 WS-YEARS-WORKED          PIC 9(2).
       01 WS-EARNINGS-TABLE.
           05 WS-EARN-ENTRY OCCURS 35
              ASCENDING KEY IS WS-EARN-YEAR
              INDEXED BY WS-EARN-IDX.
               10 WS-EARN-YEAR         PIC 9(4).
               10 WS-EARN-AMOUNT       PIC S9(7)V99 COMP-3.
               10 WS-EARN-INDEXED      PIC S9(7)V99 COMP-3.
       01 WS-EARN-COUNT                PIC 9(2) VALUE 35.
       01 WS-AIME-FIELDS.
           05 WS-TOTAL-INDEXED         PIC S9(9)V99 COMP-3.
           05 WS-TOP35-TOTAL           PIC S9(9)V99 COMP-3.
           05 WS-AIME                  PIC S9(5)V99 COMP-3.
           05 WS-MONTHLY-DIVISOR       PIC 9(3) VALUE 420.
       01 WS-BEND-POINTS.
           05 WS-BEND-1               PIC S9(5)V99 COMP-3
               VALUE 1174.00.
           05 WS-BEND-2               PIC S9(5)V99 COMP-3
               VALUE 7078.00.
       01 WS-PIA-FIELDS.
           05 WS-PIA-TIER-1           PIC S9(5)V99 COMP-3.
           05 WS-PIA-TIER-2           PIC S9(5)V99 COMP-3.
           05 WS-PIA-TIER-3           PIC S9(5)V99 COMP-3.
           05 WS-PIA-RAW              PIC S9(5)V99 COMP-3.
           05 WS-PIA-FINAL            PIC S9(5)V99 COMP-3.
       01 WS-COLA-FIELDS.
           05 WS-COLA-RATE            PIC S9(1)V9(4) COMP-3.
           05 WS-COLA-YEARS           PIC 9(2).
           05 WS-COLA-IDX             PIC 9(2).
           05 WS-COLA-FACTOR          PIC S9(3)V9(6) COMP-3.
       01 WS-REDUCTION-FIELDS.
           05 WS-FRA-AGE              PIC 9(2) VALUE 67.
           05 WS-ACTUAL-AGE           PIC 9(2).
           05 WS-MONTHS-EARLY         PIC 9(3).
           05 WS-REDUCTION-PCT        PIC S9(1)V9(6) COMP-3.
           05 WS-MONTHLY-BENEFIT      PIC S9(5)V99 COMP-3.
       01 WS-WORK-FIELDS.
           05 WS-TEMP-AMT             PIC S9(9)V99 COMP-3.
           05 WS-TEMP-QUOTIENT        PIC S9(9)V99 COMP-3.
           05 WS-TEMP-REMAINDER       PIC S9(7)V99 COMP-3.
           05 WS-SEARCH-YEAR          PIC 9(4).
       01 WS-REPORT-LINE              PIC X(80).
       01 WS-PROCESS-DATE             PIC 9(8).
       66 WS-PROCESS-YYYY
           RENAMES WS-PROCESS-DATE.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-INDEX-EARNINGS
           PERFORM 3000-CALC-AIME
           PERFORM 4000-CALC-PIA
           PERFORM 5000-APPLY-COLA
           PERFORM 6000-EARLY-REDUCTION
           PERFORM 7000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-PROCESS-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-TOTAL-INDEXED
           MOVE 0 TO WS-TOP35-TOTAL
           MOVE 0 TO WS-PIA-RAW
           MOVE 1.0 TO WS-COLA-FACTOR
           COMPUTE WS-ACTUAL-AGE =
               WS-RETIRE-YEAR - WS-BIRTH-YEAR.
       2000-INDEX-EARNINGS.
           PERFORM VARYING WS-EARN-IDX FROM 1 BY 1
               UNTIL WS-EARN-IDX > WS-EARN-COUNT
               IF WS-EARN-AMOUNT(WS-EARN-IDX) > 0
                   COMPUTE WS-EARN-INDEXED(WS-EARN-IDX) =
                       WS-EARN-AMOUNT(WS-EARN-IDX) * 1.02
               ELSE
                   MOVE 0 TO WS-EARN-INDEXED(WS-EARN-IDX)
               END-IF
           END-PERFORM.
       3000-CALC-AIME.
           SORT WS-EARN-ENTRY
               ON DESCENDING KEY WS-EARN-INDEXED
           PERFORM VARYING WS-EARN-IDX FROM 1 BY 1
               UNTIL WS-EARN-IDX > WS-EARN-COUNT
               ADD WS-EARN-INDEXED(WS-EARN-IDX)
                   TO WS-TOP35-TOTAL
           END-PERFORM
           DIVIDE WS-TOP35-TOTAL BY WS-MONTHLY-DIVISOR
               GIVING WS-AIME
               REMAINDER WS-TEMP-REMAINDER.
       4000-CALC-PIA.
           IF WS-AIME <= WS-BEND-1
               COMPUTE WS-PIA-TIER-1 =
                   WS-AIME * 0.90
               MOVE 0 TO WS-PIA-TIER-2
               MOVE 0 TO WS-PIA-TIER-3
           ELSE IF WS-AIME <= WS-BEND-2
               COMPUTE WS-PIA-TIER-1 =
                   WS-BEND-1 * 0.90
               COMPUTE WS-PIA-TIER-2 =
                   (WS-AIME - WS-BEND-1) * 0.32
               MOVE 0 TO WS-PIA-TIER-3
           ELSE
               COMPUTE WS-PIA-TIER-1 =
                   WS-BEND-1 * 0.90
               COMPUTE WS-PIA-TIER-2 =
                   (WS-BEND-2 - WS-BEND-1) * 0.32
               COMPUTE WS-PIA-TIER-3 =
                   (WS-AIME - WS-BEND-2) * 0.15
           END-IF
           COMPUTE WS-PIA-RAW =
               WS-PIA-TIER-1 + WS-PIA-TIER-2 +
               WS-PIA-TIER-3.
       5000-APPLY-COLA.
           COMPUTE WS-COLA-YEARS =
               WS-RETIRE-YEAR - 2024
           IF WS-COLA-YEARS > 0
               MOVE 0.032 TO WS-COLA-RATE
               PERFORM VARYING WS-COLA-IDX FROM 1 BY 1
                   UNTIL WS-COLA-IDX > WS-COLA-YEARS
                   COMPUTE WS-COLA-FACTOR =
                       WS-COLA-FACTOR * (1 + WS-COLA-RATE)
               END-PERFORM
           END-IF
           COMPUTE WS-PIA-FINAL =
               WS-PIA-RAW * WS-COLA-FACTOR.
       6000-EARLY-REDUCTION.
           IF WS-ACTUAL-AGE < WS-FRA-AGE
               COMPUTE WS-MONTHS-EARLY =
                   (WS-FRA-AGE - WS-ACTUAL-AGE) * 12
               IF WS-MONTHS-EARLY <= 36
                   COMPUTE WS-REDUCTION-PCT =
                       WS-MONTHS-EARLY * 0.005556
               ELSE
                   COMPUTE WS-REDUCTION-PCT =
                       36 * 0.005556 +
                       (WS-MONTHS-EARLY - 36) * 0.004167
               END-IF
               COMPUTE WS-MONTHLY-BENEFIT =
                   WS-PIA-FINAL * (1 - WS-REDUCTION-PCT)
           ELSE
               MOVE WS-PIA-FINAL TO WS-MONTHLY-BENEFIT
           END-IF.
       7000-DISPLAY-RESULTS.
           DISPLAY "SS BENEFIT CALCULATION REPORT"
           DISPLAY "SSN: " WS-WORKER-SSN
           DISPLAY "AIME: " WS-AIME
           DISPLAY "PIA (RAW): " WS-PIA-RAW
           DISPLAY "PIA (COLA-ADJUSTED): " WS-PIA-FINAL
           DISPLAY "MONTHLY BENEFIT: " WS-MONTHLY-BENEFIT
           DISPLAY "RETIRE AGE: " WS-ACTUAL-AGE
           IF WS-ACTUAL-AGE < WS-FRA-AGE
               DISPLAY "EARLY REDUCTION APPLIED"
               DISPLAY "MONTHS EARLY: " WS-MONTHS-EARLY
           ELSE
               DISPLAY "FULL RETIREMENT BENEFIT"
           END-IF
           DISPLAY "PROCESSED: " WS-PROCESS-DATE.
