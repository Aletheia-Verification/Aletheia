       IDENTIFICATION DIVISION.
       PROGRAM-ID. BSA-AGGREGATE-CTR.
      *================================================================
      * BSA Aggregate CTR Monitoring
      * Monitors multiple-day cash activity patterns per customer,
      * flags potential structuring across business days.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-MONITORING-PARAMS.
           05 WS-LOOKBACK-DAYS        PIC 9(2) VALUE 5.
           05 WS-REPORT-DATE          PIC 9(8).
           05 WS-THRESHOLD            PIC S9(11)V99 COMP-3
               VALUE 10000.00.
       01 WS-CUSTOMER.
           05 WS-CUST-ID              PIC X(12).
           05 WS-CUST-NAME            PIC X(30).
           05 WS-CUST-RISK-RATING     PIC X(1).
               88 WS-LOW-RISK         VALUE 'L'.
               88 WS-MEDIUM-RISK      VALUE 'M'.
               88 WS-HIGH-RISK        VALUE 'H'.
       01 WS-DAILY-ACTIVITY.
           05 WS-DAY-ENTRY OCCURS 5
              ASCENDING KEY IS WS-DE-DATE
              INDEXED BY WS-DE-IDX.
               10 WS-DE-DATE          PIC 9(8).
               10 WS-DE-CASH-IN       PIC S9(9)V99 COMP-3.
               10 WS-DE-CASH-OUT      PIC S9(9)V99 COMP-3.
               10 WS-DE-TXN-COUNT     PIC 9(3).
               10 WS-DE-BRANCH-COUNT  PIC 9(2).
               10 WS-DE-DAILY-TOTAL   PIC S9(11)V99 COMP-3.
       01 WS-DAY-COUNT                PIC 9(2).
       01 WS-AGGREGATE-FIELDS.
           05 WS-AGG-CASH-IN          PIC S9(11)V99 COMP-3.
           05 WS-AGG-CASH-OUT         PIC S9(11)V99 COMP-3.
           05 WS-AGG-TOTAL            PIC S9(11)V99 COMP-3.
           05 WS-AGG-TXN-COUNT        PIC 9(5).
           05 WS-AVG-DAILY-AMT        PIC S9(9)V99 COMP-3.
       01 WS-PATTERN-FLAGS.
           05 WS-STRUCTURING-FLAG     PIC X(1).
               88 WS-STRUCT-DETECTED  VALUE 'Y'.
           05 WS-MULTI-BRANCH-FLAG    PIC X(1).
               88 WS-MULTI-BRANCH     VALUE 'Y'.
           05 WS-ESCALATING-FLAG      PIC X(1).
               88 WS-ESCALATING       VALUE 'Y'.
           05 WS-JUST-UNDER-FLAG      PIC X(1).
               88 WS-JUST-UNDER       VALUE 'Y'.
       01 WS-PATTERN-ANALYSIS.
           05 WS-DAYS-OVER-THRESH     PIC 9(2).
           05 WS-DAYS-NEAR-THRESH     PIC 9(2).
           05 WS-NEAR-THRESH-AMT      PIC S9(11)V99 COMP-3
               VALUE 8500.00.
           05 WS-MAX-BRANCH-CT        PIC 9(2).
           05 WS-PREV-DAILY-TOTAL     PIC S9(11)V99 COMP-3.
           05 WS-CONSEC-INCREASE      PIC 9(2).
       01 WS-ALERT-LEVEL              PIC 9(1).
           88 WS-NO-ALERT             VALUE 0.
           88 WS-LOW-ALERT            VALUE 1.
           88 WS-MEDIUM-ALERT         VALUE 2.
           88 WS-HIGH-ALERT           VALUE 3.
       01 WS-WORK-FIELDS.
           05 WS-TEMP-AMT             PIC S9(11)V99 COMP-3.
           05 WS-SEARCH-DATE          PIC 9(8).
       01 WS-DIVIDE-FIELDS.
           05 WS-AVG-QUOTIENT         PIC S9(9)V99 COMP-3.
           05 WS-AVG-REMAINDER        PIC S9(7)V99 COMP-3.
       01 WS-PROCESS-DATE             PIC 9(8).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-AGGREGATE-ACTIVITY
           PERFORM 3000-ANALYZE-PATTERNS
           PERFORM 4000-DETERMINE-ALERT
           PERFORM 5000-DISPLAY-REPORT
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-PROCESS-DATE FROM DATE YYYYMMDD
           MOVE WS-PROCESS-DATE TO WS-REPORT-DATE
           MOVE 0 TO WS-AGG-CASH-IN
           MOVE 0 TO WS-AGG-CASH-OUT
           MOVE 0 TO WS-AGG-TOTAL
           MOVE 0 TO WS-AGG-TXN-COUNT
           MOVE 0 TO WS-DAYS-OVER-THRESH
           MOVE 0 TO WS-DAYS-NEAR-THRESH
           MOVE 0 TO WS-MAX-BRANCH-CT
           MOVE 0 TO WS-CONSEC-INCREASE
           MOVE 'N' TO WS-STRUCTURING-FLAG
           MOVE 'N' TO WS-MULTI-BRANCH-FLAG
           MOVE 'N' TO WS-ESCALATING-FLAG
           MOVE 'N' TO WS-JUST-UNDER-FLAG
           SET WS-NO-ALERT TO TRUE.
       2000-AGGREGATE-ACTIVITY.
           PERFORM VARYING WS-DE-IDX FROM 1 BY 1
               UNTIL WS-DE-IDX > WS-DAY-COUNT
               COMPUTE WS-DE-DAILY-TOTAL(WS-DE-IDX) =
                   WS-DE-CASH-IN(WS-DE-IDX) +
                   WS-DE-CASH-OUT(WS-DE-IDX)
               ADD WS-DE-CASH-IN(WS-DE-IDX)
                   TO WS-AGG-CASH-IN
               ADD WS-DE-CASH-OUT(WS-DE-IDX)
                   TO WS-AGG-CASH-OUT
               ADD WS-DE-TXN-COUNT(WS-DE-IDX)
                   TO WS-AGG-TXN-COUNT
               IF WS-DE-BRANCH-COUNT(WS-DE-IDX) >
                   WS-MAX-BRANCH-CT
                   MOVE WS-DE-BRANCH-COUNT(WS-DE-IDX)
                       TO WS-MAX-BRANCH-CT
               END-IF
           END-PERFORM
           COMPUTE WS-AGG-TOTAL =
               WS-AGG-CASH-IN + WS-AGG-CASH-OUT
           IF WS-DAY-COUNT > 0
               DIVIDE WS-AGG-TOTAL BY WS-DAY-COUNT
                   GIVING WS-AVG-DAILY-AMT
                   REMAINDER WS-AVG-REMAINDER
           END-IF.
       3000-ANALYZE-PATTERNS.
           MOVE 0 TO WS-PREV-DAILY-TOTAL
           PERFORM VARYING WS-DE-IDX FROM 1 BY 1
               UNTIL WS-DE-IDX > WS-DAY-COUNT
               IF WS-DE-DAILY-TOTAL(WS-DE-IDX) >
                   WS-THRESHOLD
                   ADD 1 TO WS-DAYS-OVER-THRESH
               END-IF
               IF WS-DE-DAILY-TOTAL(WS-DE-IDX) >=
                   WS-NEAR-THRESH-AMT
               AND WS-DE-DAILY-TOTAL(WS-DE-IDX) <
                   WS-THRESHOLD
                   ADD 1 TO WS-DAYS-NEAR-THRESH
                   SET WS-JUST-UNDER TO TRUE
               END-IF
               IF WS-DE-DAILY-TOTAL(WS-DE-IDX) >
                   WS-PREV-DAILY-TOTAL
               AND WS-PREV-DAILY-TOTAL > 0
                   ADD 1 TO WS-CONSEC-INCREASE
               ELSE
                   MOVE 0 TO WS-CONSEC-INCREASE
               END-IF
               MOVE WS-DE-DAILY-TOTAL(WS-DE-IDX)
                   TO WS-PREV-DAILY-TOTAL
           END-PERFORM
           IF WS-DAYS-NEAR-THRESH >= 3
               SET WS-STRUCT-DETECTED TO TRUE
           END-IF
           IF WS-MAX-BRANCH-CT > 1
               SET WS-MULTI-BRANCH TO TRUE
           END-IF
           IF WS-CONSEC-INCREASE >= 3
               SET WS-ESCALATING TO TRUE
           END-IF.
       4000-DETERMINE-ALERT.
           MOVE 0 TO WS-ALERT-LEVEL
           IF WS-STRUCT-DETECTED
               ADD 2 TO WS-ALERT-LEVEL
           END-IF
           IF WS-MULTI-BRANCH
               ADD 1 TO WS-ALERT-LEVEL
           END-IF
           IF WS-HIGH-RISK
               ADD 1 TO WS-ALERT-LEVEL
           END-IF
           IF WS-ALERT-LEVEL > 3
               MOVE 3 TO WS-ALERT-LEVEL
           END-IF.
       5000-DISPLAY-REPORT.
           DISPLAY "BSA AGGREGATE MONITORING"
           DISPLAY "DATE: " WS-PROCESS-DATE
           DISPLAY "CUSTOMER: " WS-CUST-NAME
           DISPLAY "RISK RATING: " WS-CUST-RISK-RATING
           DISPLAY "LOOKBACK DAYS: " WS-DAY-COUNT
           DISPLAY "AGG CASH IN: " WS-AGG-CASH-IN
           DISPLAY "AGG CASH OUT: " WS-AGG-CASH-OUT
           DISPLAY "AGG TOTAL: " WS-AGG-TOTAL
           DISPLAY "AVG DAILY: " WS-AVG-DAILY-AMT
           DISPLAY "DAYS OVER THRESH: "
               WS-DAYS-OVER-THRESH
           DISPLAY "DAYS NEAR THRESH: "
               WS-DAYS-NEAR-THRESH
           IF WS-STRUCT-DETECTED
               DISPLAY "ALERT: STRUCTURING PATTERN"
           END-IF
           IF WS-MULTI-BRANCH
               DISPLAY "NOTE: MULTI-BRANCH ACTIVITY"
           END-IF
           DISPLAY "ALERT LEVEL: " WS-ALERT-LEVEL.
