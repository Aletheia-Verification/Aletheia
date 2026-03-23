       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-SQL-LOAN-AGING.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-SQLCODE               PIC S9(9) COMP-3.
       01 WS-LOAN-REC.
           05 WS-LOAN-NUM          PIC X(12).
           05 WS-BORROWER          PIC X(30).
           05 WS-OUTSTANDING       PIC S9(11)V99 COMP-3.
           05 WS-DUE-DATE          PIC X(10).
           05 WS-DAYS-PAST-DUE     PIC S9(5) COMP-3.
           05 WS-LOAN-GRADE        PIC X(2).
       01 WS-AGING-BUCKETS.
           05 WS-CURRENT-BAL       PIC S9(13)V99 COMP-3.
           05 WS-BUCKET-30         PIC S9(13)V99 COMP-3.
           05 WS-BUCKET-60         PIC S9(13)V99 COMP-3.
           05 WS-BUCKET-90         PIC S9(13)V99 COMP-3.
           05 WS-BUCKET-120        PIC S9(13)V99 COMP-3.
           05 WS-BUCKET-180        PIC S9(13)V99 COMP-3.
       01 WS-COUNTS.
           05 WS-CNT-CURRENT       PIC 9(5).
           05 WS-CNT-30            PIC 9(5).
           05 WS-CNT-60            PIC 9(5).
           05 WS-CNT-90            PIC 9(5).
           05 WS-CNT-120           PIC 9(5).
           05 WS-CNT-180           PIC 9(5).
       01 WS-TOTAL-PORTFOLIO       PIC S9(13)V99 COMP-3.
       01 WS-DELINQ-RATIO          PIC S9(3)V99 COMP-3.
       01 WS-EOF-FLAG               PIC X VALUE 'N'.
           88 WS-EOF                VALUE 'Y'.
       01 WS-REPORT-DATE            PIC 9(8).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-OPEN-CURSOR
           PERFORM 3000-PROCESS-LOANS UNTIL WS-EOF
           PERFORM 4000-CLOSE-CURSOR
           PERFORM 5000-CALC-RATIOS
           PERFORM 6000-REPORT
           STOP RUN.
       1000-INIT.
           INITIALIZE WS-AGING-BUCKETS
           INITIALIZE WS-COUNTS
           MOVE 0 TO WS-TOTAL-PORTFOLIO
           ACCEPT WS-REPORT-DATE FROM DATE YYYYMMDD.
       2000-OPEN-CURSOR.
           EXEC SQL
               DECLARE LOAN_AGING_CUR CURSOR FOR
               SELECT LOAN_NUM, BORROWER_NAME,
                      OUTSTANDING_BAL, DUE_DATE,
                      DAYS_PAST_DUE, LOAN_GRADE
               FROM LOAN_MASTER
               WHERE OUTSTANDING_BAL > 0
               ORDER BY DAYS_PAST_DUE DESC
           END-EXEC
           EXEC SQL
               OPEN LOAN_AGING_CUR
           END-EXEC.
       3000-PROCESS-LOANS.
           EXEC SQL
               FETCH LOAN_AGING_CUR
               INTO :WS-LOAN-NUM,
                    :WS-BORROWER,
                    :WS-OUTSTANDING,
                    :WS-DUE-DATE,
                    :WS-DAYS-PAST-DUE,
                    :WS-LOAN-GRADE
           END-EXEC
           IF WS-SQLCODE = 100
               SET WS-EOF TO TRUE
           ELSE
               IF WS-SQLCODE = 0
                   PERFORM 3100-BUCKET-LOAN
               END-IF
           END-IF.
       3100-BUCKET-LOAN.
           ADD WS-OUTSTANDING TO WS-TOTAL-PORTFOLIO
           EVALUATE TRUE
               WHEN WS-DAYS-PAST-DUE <= 0
                   ADD WS-OUTSTANDING TO WS-CURRENT-BAL
                   ADD 1 TO WS-CNT-CURRENT
               WHEN WS-DAYS-PAST-DUE <= 30
                   ADD WS-OUTSTANDING TO WS-BUCKET-30
                   ADD 1 TO WS-CNT-30
               WHEN WS-DAYS-PAST-DUE <= 60
                   ADD WS-OUTSTANDING TO WS-BUCKET-60
                   ADD 1 TO WS-CNT-60
               WHEN WS-DAYS-PAST-DUE <= 90
                   ADD WS-OUTSTANDING TO WS-BUCKET-90
                   ADD 1 TO WS-CNT-90
               WHEN WS-DAYS-PAST-DUE <= 120
                   ADD WS-OUTSTANDING TO WS-BUCKET-120
                   ADD 1 TO WS-CNT-120
               WHEN OTHER
                   ADD WS-OUTSTANDING TO WS-BUCKET-180
                   ADD 1 TO WS-CNT-180
           END-EVALUATE.
       4000-CLOSE-CURSOR.
           EXEC SQL
               CLOSE LOAN_AGING_CUR
           END-EXEC.
       5000-CALC-RATIOS.
           IF WS-TOTAL-PORTFOLIO > 0
               COMPUTE WS-DELINQ-RATIO =
                   ((WS-BUCKET-30 + WS-BUCKET-60 +
                     WS-BUCKET-90 + WS-BUCKET-120 +
                     WS-BUCKET-180) /
                    WS-TOTAL-PORTFOLIO) * 100
           ELSE
               MOVE 0 TO WS-DELINQ-RATIO
           END-IF.
       6000-REPORT.
           DISPLAY 'LOAN AGING REPORT'
           DISPLAY '================='
           DISPLAY 'DATE: ' WS-REPORT-DATE
           DISPLAY 'CURRENT:    $' WS-CURRENT-BAL
               ' (' WS-CNT-CURRENT ')'
           DISPLAY '1-30 DPD:   $' WS-BUCKET-30
               ' (' WS-CNT-30 ')'
           DISPLAY '31-60 DPD:  $' WS-BUCKET-60
               ' (' WS-CNT-60 ')'
           DISPLAY '61-90 DPD:  $' WS-BUCKET-90
               ' (' WS-CNT-90 ')'
           DISPLAY '91-120 DPD: $' WS-BUCKET-120
               ' (' WS-CNT-120 ')'
           DISPLAY '120+ DPD:   $' WS-BUCKET-180
               ' (' WS-CNT-180 ')'
           DISPLAY 'PORTFOLIO:  $' WS-TOTAL-PORTFOLIO
           DISPLAY 'DELINQ PCT: ' WS-DELINQ-RATIO.
