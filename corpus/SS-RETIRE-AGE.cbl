       IDENTIFICATION DIVISION.
       PROGRAM-ID. SS-RETIRE-AGE.
      *================================================================
      * Social Security Full Retirement Age Calculator
      * Determines FRA based on birth year, calculates early/
      * delayed retirement credits and break-even analysis.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CLAIMANT.
           05 WS-SSN                   PIC X(9).
           05 WS-BIRTH-YEAR            PIC 9(4).
           05 WS-BIRTH-MONTH           PIC 9(2).
           05 WS-CLAIM-AGE-YR          PIC 9(2).
           05 WS-CLAIM-AGE-MO          PIC 9(2).
           05 WS-PIA                   PIC S9(5)V99 COMP-3.
       01 WS-FRA-TABLE.
           05 WS-FRA-ENTRY OCCURS 7
              ASCENDING KEY IS WS-FT-YEAR-FROM
              INDEXED BY WS-FT-IDX.
               10 WS-FT-YEAR-FROM     PIC 9(4).
               10 WS-FT-YEAR-TO       PIC 9(4).
               10 WS-FT-FRA-YEARS     PIC 9(2).
               10 WS-FT-FRA-MONTHS    PIC 9(2).
       01 WS-FRA-RESULT.
           05 WS-FRA-YEARS            PIC 9(2).
           05 WS-FRA-MONTHS           PIC 9(2).
           05 WS-FRA-TOTAL-MO         PIC 9(4).
       01 WS-CLAIM-TOTAL-MO           PIC 9(4).
       01 WS-ADJUSTMENT.
           05 WS-MONTHS-DIFF          PIC S9(4) COMP-3.
           05 WS-IS-EARLY             PIC X(1).
               88 WS-EARLY-CLAIM      VALUE 'Y'.
               88 WS-DELAYED-CLAIM    VALUE 'N'.
           05 WS-REDUCTION-FACTOR     PIC S9(1)V9(6) COMP-3.
           05 WS-CREDIT-FACTOR        PIC S9(1)V9(6) COMP-3.
           05 WS-ADJUSTED-BENEFIT     PIC S9(5)V99 COMP-3.
       01 WS-EARLY-REDUCTION.
           05 WS-FIRST-36-MO          PIC 9(3).
           05 WS-EXTRA-MO             PIC 9(3).
           05 WS-FIRST-36-RATE        PIC S9(1)V9(6) COMP-3
               VALUE 0.005556.
           05 WS-EXTRA-RATE           PIC S9(1)V9(6) COMP-3
               VALUE 0.004167.
       01 WS-DELAYED-CREDIT.
           05 WS-DRC-RATE-YR          PIC S9(1)V9(4) COMP-3
               VALUE 0.0800.
           05 WS-DRC-RATE-MO          PIC S9(1)V9(6) COMP-3.
       01 WS-BREAKEVEN.
           05 WS-EARLY-ANNUAL         PIC S9(7)V99 COMP-3.
           05 WS-FRA-ANNUAL           PIC S9(7)V99 COMP-3.
           05 WS-DIFF-MONTHLY         PIC S9(5)V99 COMP-3.
           05 WS-EARLY-HEAD-START     PIC S9(7)V99 COMP-3.
           05 WS-BREAKEVEN-MONTHS     PIC S9(5) COMP-3.
       01 WS-WORK-FIELDS.
           05 WS-TEMP-FACTOR          PIC S9(3)V9(6) COMP-3.
           05 WS-SEARCH-YEAR          PIC 9(4).
       01 WS-PROCESS-DATE             PIC 9(8).
       66 WS-PROC-YEAR
           RENAMES WS-PROCESS-DATE.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-FRA-TABLE
           PERFORM 3000-LOOKUP-FRA
           PERFORM 4000-CALC-ADJUSTMENT
           PERFORM 5000-CALC-BREAKEVEN
           PERFORM 6000-DISPLAY-RESULT
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-PROCESS-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-REDUCTION-FACTOR
           MOVE 0 TO WS-CREDIT-FACTOR
           COMPUTE WS-DRC-RATE-MO =
               WS-DRC-RATE-YR / 12.
       2000-LOAD-FRA-TABLE.
           MOVE 1937 TO WS-FT-YEAR-FROM(1)
           MOVE 1937 TO WS-FT-YEAR-TO(1)
           MOVE 65 TO WS-FT-FRA-YEARS(1)
           MOVE 0 TO WS-FT-FRA-MONTHS(1)
           MOVE 1938 TO WS-FT-YEAR-FROM(2)
           MOVE 1942 TO WS-FT-YEAR-TO(2)
           MOVE 65 TO WS-FT-FRA-YEARS(2)
           MOVE 2 TO WS-FT-FRA-MONTHS(2)
           MOVE 1943 TO WS-FT-YEAR-FROM(3)
           MOVE 1954 TO WS-FT-YEAR-TO(3)
           MOVE 66 TO WS-FT-FRA-YEARS(3)
           MOVE 0 TO WS-FT-FRA-MONTHS(3)
           MOVE 1955 TO WS-FT-YEAR-FROM(4)
           MOVE 1959 TO WS-FT-YEAR-TO(4)
           MOVE 66 TO WS-FT-FRA-YEARS(4)
           MOVE 2 TO WS-FT-FRA-MONTHS(4)
           MOVE 1960 TO WS-FT-YEAR-FROM(5)
           MOVE 2000 TO WS-FT-YEAR-TO(5)
           MOVE 67 TO WS-FT-FRA-YEARS(5)
           MOVE 0 TO WS-FT-FRA-MONTHS(5)
           MOVE 2001 TO WS-FT-YEAR-FROM(6)
           MOVE 2010 TO WS-FT-YEAR-TO(6)
           MOVE 67 TO WS-FT-FRA-YEARS(6)
           MOVE 0 TO WS-FT-FRA-MONTHS(6)
           MOVE 2011 TO WS-FT-YEAR-FROM(7)
           MOVE 9999 TO WS-FT-YEAR-TO(7)
           MOVE 67 TO WS-FT-FRA-YEARS(7)
           MOVE 0 TO WS-FT-FRA-MONTHS(7).
       3000-LOOKUP-FRA.
           MOVE WS-BIRTH-YEAR TO WS-SEARCH-YEAR
           PERFORM VARYING WS-FT-IDX FROM 1 BY 1
               UNTIL WS-FT-IDX > 7
               IF WS-BIRTH-YEAR >=
                   WS-FT-YEAR-FROM(WS-FT-IDX)
               AND WS-BIRTH-YEAR <=
                   WS-FT-YEAR-TO(WS-FT-IDX)
                   MOVE WS-FT-FRA-YEARS(WS-FT-IDX)
                       TO WS-FRA-YEARS
                   MOVE WS-FT-FRA-MONTHS(WS-FT-IDX)
                       TO WS-FRA-MONTHS
               END-IF
           END-PERFORM
           COMPUTE WS-FRA-TOTAL-MO =
               WS-FRA-YEARS * 12 + WS-FRA-MONTHS
           COMPUTE WS-CLAIM-TOTAL-MO =
               WS-CLAIM-AGE-YR * 12 + WS-CLAIM-AGE-MO.
       4000-CALC-ADJUSTMENT.
           COMPUTE WS-MONTHS-DIFF =
               WS-CLAIM-TOTAL-MO - WS-FRA-TOTAL-MO
           IF WS-MONTHS-DIFF < 0
               SET WS-EARLY-CLAIM TO TRUE
               MULTIPLY WS-MONTHS-DIFF BY -1
                   GIVING WS-MONTHS-DIFF
               IF WS-MONTHS-DIFF <= 36
                   MOVE WS-MONTHS-DIFF TO WS-FIRST-36-MO
                   MOVE 0 TO WS-EXTRA-MO
               ELSE
                   MOVE 36 TO WS-FIRST-36-MO
                   COMPUTE WS-EXTRA-MO =
                       WS-MONTHS-DIFF - 36
               END-IF
               COMPUTE WS-REDUCTION-FACTOR =
                   (WS-FIRST-36-MO * WS-FIRST-36-RATE) +
                   (WS-EXTRA-MO * WS-EXTRA-RATE)
               COMPUTE WS-ADJUSTED-BENEFIT =
                   WS-PIA * (1 - WS-REDUCTION-FACTOR)
           ELSE
               SET WS-DELAYED-CLAIM TO TRUE
               COMPUTE WS-CREDIT-FACTOR =
                   WS-MONTHS-DIFF * WS-DRC-RATE-MO
               COMPUTE WS-ADJUSTED-BENEFIT =
                   WS-PIA * (1 + WS-CREDIT-FACTOR)
           END-IF.
       5000-CALC-BREAKEVEN.
           IF WS-EARLY-CLAIM
               COMPUTE WS-EARLY-ANNUAL =
                   WS-ADJUSTED-BENEFIT * 12
               COMPUTE WS-FRA-ANNUAL = WS-PIA * 12
               COMPUTE WS-DIFF-MONTHLY =
                   WS-PIA - WS-ADJUSTED-BENEFIT
               COMPUTE WS-EARLY-HEAD-START =
                   WS-ADJUSTED-BENEFIT * WS-MONTHS-DIFF
               IF WS-DIFF-MONTHLY > 0
                   DIVIDE WS-EARLY-HEAD-START
                       BY WS-DIFF-MONTHLY
                       GIVING WS-BREAKEVEN-MONTHS
               END-IF
           END-IF.
       6000-DISPLAY-RESULT.
           DISPLAY "SS RETIREMENT AGE ANALYSIS"
           DISPLAY "DATE: " WS-PROCESS-DATE
           DISPLAY "SSN: " WS-SSN
           DISPLAY "BIRTH YEAR: " WS-BIRTH-YEAR
           DISPLAY "FRA: " WS-FRA-YEARS " YEARS "
               WS-FRA-MONTHS " MONTHS"
           DISPLAY "PIA: " WS-PIA
           IF WS-EARLY-CLAIM
               DISPLAY "EARLY CLAIM AT AGE "
                   WS-CLAIM-AGE-YR
               DISPLAY "REDUCTION: "
                   WS-REDUCTION-FACTOR
               DISPLAY "MONTHLY BENEFIT: "
                   WS-ADJUSTED-BENEFIT
               DISPLAY "BREAKEVEN: "
                   WS-BREAKEVEN-MONTHS " MONTHS"
           ELSE
               DISPLAY "DELAYED CLAIM AT AGE "
                   WS-CLAIM-AGE-YR
               DISPLAY "DRC CREDIT: "
                   WS-CREDIT-FACTOR
               DISPLAY "MONTHLY BENEFIT: "
                   WS-ADJUSTED-BENEFIT
           END-IF.
