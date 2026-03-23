       IDENTIFICATION DIVISION.
       PROGRAM-ID. MTG-FORBEAR-EVAL.
      *================================================================*
      * Mortgage Forbearance Evaluation Engine                          *
      * Evaluates borrower eligibility for forbearance, calculates     *
      * deferred payment schedules, and tracks repayment plans.         *
      *================================================================*
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT BORROWER-FILE ASSIGN TO 'BORROWER.DAT'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-BOR-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD  BORROWER-FILE.
       01  BORROWER-RECORD.
           05  BR-LOAN-NUM          PIC X(10).
           05  BR-BORROWER-NAME     PIC X(25).
           05  BR-MONTHLY-PMT       PIC 9(07)V99.
           05  BR-CURRENT-BAL       PIC 9(09)V99.
           05  BR-MONTHLY-INCOME    PIC 9(07)V99.
           05  BR-MONTHLY-EXPENSE   PIC 9(07)V99.
           05  BR-HARDSHIP-CODE     PIC X(02).
           05  BR-MONTHS-DELINQ     PIC 9(02).
           05  BR-PROPERTY-VALUE    PIC 9(09)V99.
           05  BR-PRIOR-FORBEAR     PIC X(01).
           05  BR-LOAN-TYPE         PIC X(02).
       WORKING-STORAGE SECTION.
       01  WS-BOR-STATUS           PIC XX VALUE SPACES.
       01  WS-EOF                  PIC X VALUE 'N'.
           88  END-OF-FILE         VALUE 'Y'.
       01  WS-DTI-RATIO            PIC 9(03)V99.
       01  WS-LTV-RATIO            PIC 9(03)V99.
       01  WS-DISPOSABLE           PIC S9(07)V99.
       01  WS-ELIGIBLE             PIC X VALUE 'N'.
           88  IS-ELIGIBLE          VALUE 'Y'.
       01  WS-PLAN-TYPE            PIC X(10).
       01  WS-FORBEAR-MONTHS       PIC 9(02).
       01  WS-DEFERRED-AMT         PIC S9(09)V99.
       01  WS-REPAY-MONTHLY        PIC S9(07)V99.
       01  WS-REPAY-TERM           PIC 9(02).
       01  WS-TOTAL-REVIEWED       PIC 9(06) VALUE 0.
       01  WS-APPROVED-CNT         PIC 9(06) VALUE 0.
       01  WS-DENIED-CNT           PIC 9(06) VALUE 0.
       01  WS-DEFERRED-TOTAL       PIC S9(13)V99 VALUE 0.
       01  WS-DENIAL-REASON        PIC X(40).
       01  WS-MSG                  PIC X(100) VALUE SPACES.
       01  WS-PMT-IDX             PIC 9(02).
       01  WS-RUNNING-BAL         PIC S9(09)V99.
       01  WS-MONTH-INT           PIC S9(07)V99.
       01  WS-INT-RATE            PIC 9V9(06) VALUE 0.045000.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PROCESS-BORROWERS
               UNTIL END-OF-FILE
           PERFORM 9000-FINALIZE
           STOP RUN.
       1000-INITIALIZE.
           OPEN INPUT BORROWER-FILE
           IF WS-BOR-STATUS NOT = '00'
               DISPLAY 'BORROWER FILE ERROR: ' WS-BOR-STATUS
               STOP RUN
           END-IF
           PERFORM 1100-READ-BORROWER.
       1100-READ-BORROWER.
           READ BORROWER-FILE
               AT END SET END-OF-FILE TO TRUE
           END-READ.
       2000-PROCESS-BORROWERS.
           ADD 1 TO WS-TOTAL-REVIEWED
           MOVE 'N' TO WS-ELIGIBLE
           MOVE SPACES TO WS-DENIAL-REASON
           PERFORM 3000-CALC-RATIOS
           PERFORM 4000-EVAL-ELIGIBILITY
           IF IS-ELIGIBLE
               PERFORM 5000-DETERMINE-PLAN
               PERFORM 6000-CALC-REPAYMENT
               ADD 1 TO WS-APPROVED-CNT
           ELSE
               ADD 1 TO WS-DENIED-CNT
               PERFORM 7000-GENERATE-DENIAL
           END-IF
           PERFORM 1100-READ-BORROWER.
       3000-CALC-RATIOS.
           IF BR-MONTHLY-INCOME > ZERO
               COMPUTE WS-DTI-RATIO ROUNDED =
                   (BR-MONTHLY-PMT + BR-MONTHLY-EXPENSE) /
                   BR-MONTHLY-INCOME * 100
           ELSE
               MOVE 999.99 TO WS-DTI-RATIO
           END-IF
           IF BR-PROPERTY-VALUE > ZERO
               COMPUTE WS-LTV-RATIO ROUNDED =
                   BR-CURRENT-BAL / BR-PROPERTY-VALUE
                   * 100
           ELSE
               MOVE 999.99 TO WS-LTV-RATIO
           END-IF
           COMPUTE WS-DISPOSABLE =
               BR-MONTHLY-INCOME - BR-MONTHLY-EXPENSE -
               BR-MONTHLY-PMT.
       4000-EVAL-ELIGIBILITY.
           EVALUATE TRUE
               WHEN BR-HARDSHIP-CODE = 'NA'
                   MOVE 'NO DOCUMENTED HARDSHIP'
                       TO WS-DENIAL-REASON
               WHEN BR-PRIOR-FORBEAR = 'Y' AND
                    BR-MONTHS-DELINQ > 6
                   MOVE 'PRIOR FORBEAR + DELINQUENT'
                       TO WS-DENIAL-REASON
               WHEN WS-LTV-RATIO > 150
                   MOVE 'LTV EXCEEDS 150 PCT'
                       TO WS-DENIAL-REASON
               WHEN BR-MONTHS-DELINQ > 12
                   MOVE 'DELINQUENCY EXCEEDS 12 MONTHS'
                       TO WS-DENIAL-REASON
               WHEN OTHER
                   MOVE 'Y' TO WS-ELIGIBLE
           END-EVALUATE.
       5000-DETERMINE-PLAN.
           EVALUATE TRUE
               WHEN WS-DTI-RATIO > 60
                   MOVE 'FULL' TO WS-PLAN-TYPE
                   MOVE 6 TO WS-FORBEAR-MONTHS
               WHEN WS-DTI-RATIO > 45
                   MOVE 'PARTIAL' TO WS-PLAN-TYPE
                   MOVE 3 TO WS-FORBEAR-MONTHS
               WHEN WS-DISPOSABLE < 200
                   MOVE 'FULL' TO WS-PLAN-TYPE
                   MOVE 3 TO WS-FORBEAR-MONTHS
               WHEN OTHER
                   MOVE 'REDUCED' TO WS-PLAN-TYPE
                   MOVE 3 TO WS-FORBEAR-MONTHS
           END-EVALUATE
           IF BR-LOAN-TYPE = 'FH'
               IF WS-FORBEAR-MONTHS < 6
                   MOVE 6 TO WS-FORBEAR-MONTHS
               END-IF
           END-IF
           COMPUTE WS-DEFERRED-AMT =
               BR-MONTHLY-PMT * WS-FORBEAR-MONTHS
           ADD WS-DEFERRED-AMT TO WS-DEFERRED-TOTAL.
       6000-CALC-REPAYMENT.
           MOVE 12 TO WS-REPAY-TERM
           COMPUTE WS-REPAY-MONTHLY ROUNDED =
               WS-DEFERRED-AMT / WS-REPAY-TERM
           MOVE WS-DEFERRED-AMT TO WS-RUNNING-BAL
           PERFORM VARYING WS-PMT-IDX FROM 1 BY 1
               UNTIL WS-PMT-IDX > WS-REPAY-TERM
               COMPUTE WS-MONTH-INT ROUNDED =
                   WS-RUNNING-BAL * WS-INT-RATE / 12
               SUBTRACT WS-REPAY-MONTHLY FROM
                   WS-RUNNING-BAL
               IF WS-RUNNING-BAL < ZERO
                   MOVE ZERO TO WS-RUNNING-BAL
               END-IF
           END-PERFORM
           DISPLAY 'APPROVED: ' BR-LOAN-NUM
               ' PLAN=' WS-PLAN-TYPE
               ' MONTHS=' WS-FORBEAR-MONTHS.
       7000-GENERATE-DENIAL.
           MOVE SPACES TO WS-MSG
           STRING 'DENIED: '
               DELIMITED BY SIZE
               BR-LOAN-NUM
               DELIMITED BY SIZE
               ' REASON='
               DELIMITED BY SIZE
               WS-DENIAL-REASON
               DELIMITED BY SIZE
               INTO WS-MSG
           DISPLAY WS-MSG.
       9000-FINALIZE.
           CLOSE BORROWER-FILE
           DISPLAY 'FORBEARANCE EVALUATION COMPLETE'
           DISPLAY 'REVIEWED:  ' WS-TOTAL-REVIEWED
           DISPLAY 'APPROVED:  ' WS-APPROVED-CNT
           DISPLAY 'DENIED:    ' WS-DENIED-CNT
           DISPLAY 'DEFERRED:  ' WS-DEFERRED-TOTAL.
