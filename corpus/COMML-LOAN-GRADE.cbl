       IDENTIFICATION DIVISION.
       PROGRAM-ID. COMML-LOAN-GRADE.
      *================================================================*
      * Commercial Loan Risk Grading Engine                             *
      * Scores commercial loans using financial ratios, collateral      *
      * coverage, industry risk, and payment history to assign          *
      * regulatory risk grades (1=Pass through 5=Loss).                 *
      *================================================================*
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT LOAN-FILE ASSIGN TO 'COMMLOAN.DAT'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-LOAN-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD  LOAN-FILE.
       01  LOAN-RECORD.
           05  LR-LOAN-NUM          PIC X(12).
           05  LR-BORROWER          PIC X(30).
           05  LR-OUTSTANDING       PIC 9(11)V99.
           05  LR-COLLATERAL-VAL    PIC 9(11)V99.
           05  LR-NET-INCOME        PIC S9(11)V99.
           05  LR-TOTAL-DEBT        PIC 9(11)V99.
           05  LR-TOTAL-ASSETS      PIC 9(11)V99.
           05  LR-ANNUAL-REVENUE    PIC 9(11)V99.
           05  LR-INDUSTRY-CODE     PIC X(04).
           05  LR-DAYS-DELINQ       PIC 9(03).
           05  LR-PRIOR-GRADE       PIC 9(01).
       WORKING-STORAGE SECTION.
       01  WS-LOAN-STATUS          PIC XX VALUE SPACES.
       01  WS-EOF                  PIC X VALUE 'N'.
           88  END-OF-FILE         VALUE 'Y'.
       01  WS-LTV-RATIO            PIC 9(03)V99.
       01  WS-DSCR                 PIC 9(03)V99.
       01  WS-DEBT-RATIO           PIC 9(03)V99.
       01  WS-SCORE                PIC 9(03) VALUE 0.
       01  WS-GRADE                PIC 9(01).
       01  WS-GRADE-DESC           PIC X(20).
       01  WS-DOWNGRADE-FLAG       PIC X VALUE 'N'.
           88  IS-DOWNGRADE        VALUE 'Y'.
       01  WS-LOAN-CNT             PIC 9(06) VALUE 0.
       01  WS-GRADE-DIST.
           05  WS-GRADE-CT         PIC 9(06) OCCURS 5 TIMES.
       01  WS-GRADE-IDX            PIC 9(02).
       01  WS-TOTAL-OUTSTANDING    PIC S9(15)V99 VALUE 0.
       01  WS-WATCH-TOTAL          PIC S9(15)V99 VALUE 0.
       01  WS-CLASSIFIED-TOTAL     PIC S9(15)V99 VALUE 0.
       01  WS-INDUSTRY-RISK        PIC 9(02).
       01  WS-DOWNGRADE-CNT        PIC 9(06) VALUE 0.
       01  WS-MSG                  PIC X(80) VALUE SPACES.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PROCESS-LOANS UNTIL END-OF-FILE
           PERFORM 8000-PRINT-SUMMARY
           PERFORM 9000-FINALIZE
           STOP RUN.
       1000-INITIALIZE.
           INITIALIZE WS-GRADE-DIST
           OPEN INPUT LOAN-FILE
           IF WS-LOAN-STATUS NOT = '00'
               DISPLAY 'LOAN FILE ERROR: ' WS-LOAN-STATUS
               STOP RUN
           END-IF
           PERFORM 1100-READ-LOAN.
       1100-READ-LOAN.
           READ LOAN-FILE
               AT END SET END-OF-FILE TO TRUE
           END-READ.
       2000-PROCESS-LOANS.
           ADD 1 TO WS-LOAN-CNT
           ADD LR-OUTSTANDING TO WS-TOTAL-OUTSTANDING
           MOVE ZERO TO WS-SCORE
           PERFORM 3000-CALC-LTV
           PERFORM 3100-CALC-DSCR
           PERFORM 3200-CALC-DEBT-RATIO
           PERFORM 3300-INDUSTRY-RISK
           PERFORM 3400-DELINQUENCY-SCORE
           PERFORM 4000-ASSIGN-GRADE
           PERFORM 5000-CHECK-DOWNGRADE
           ADD 1 TO WS-GRADE-CT(WS-GRADE)
           PERFORM 1100-READ-LOAN.
       3000-CALC-LTV.
           IF LR-COLLATERAL-VAL > ZERO
               COMPUTE WS-LTV-RATIO ROUNDED =
                   (LR-OUTSTANDING / LR-COLLATERAL-VAL)
                   * 100
           ELSE
               MOVE 999.99 TO WS-LTV-RATIO
           END-IF
           EVALUATE TRUE
               WHEN WS-LTV-RATIO < 60
                   ADD 0 TO WS-SCORE
               WHEN WS-LTV-RATIO < 75
                   ADD 10 TO WS-SCORE
               WHEN WS-LTV-RATIO < 85
                   ADD 20 TO WS-SCORE
               WHEN WS-LTV-RATIO < 100
                   ADD 35 TO WS-SCORE
               WHEN OTHER
                   ADD 50 TO WS-SCORE
           END-EVALUATE.
       3100-CALC-DSCR.
           IF LR-TOTAL-DEBT > ZERO AND
              LR-ANNUAL-REVENUE > ZERO
               COMPUTE WS-DSCR ROUNDED =
                   LR-NET-INCOME / (LR-TOTAL-DEBT / 12)
           ELSE
               MOVE 0 TO WS-DSCR
           END-IF
           EVALUATE TRUE
               WHEN WS-DSCR > 2.00
                   ADD 0 TO WS-SCORE
               WHEN WS-DSCR > 1.50
                   ADD 5 TO WS-SCORE
               WHEN WS-DSCR > 1.25
                   ADD 15 TO WS-SCORE
               WHEN WS-DSCR > 1.00
                   ADD 25 TO WS-SCORE
               WHEN OTHER
                   ADD 40 TO WS-SCORE
           END-EVALUATE.
       3200-CALC-DEBT-RATIO.
           IF LR-TOTAL-ASSETS > ZERO
               COMPUTE WS-DEBT-RATIO ROUNDED =
                   (LR-TOTAL-DEBT / LR-TOTAL-ASSETS) * 100
           ELSE
               MOVE 100 TO WS-DEBT-RATIO
           END-IF
           IF WS-DEBT-RATIO > 80
               ADD 15 TO WS-SCORE
           ELSE
               IF WS-DEBT-RATIO > 60
                   ADD 8 TO WS-SCORE
               END-IF
           END-IF.
       3300-INDUSTRY-RISK.
           MOVE 5 TO WS-INDUSTRY-RISK
           IF LR-INDUSTRY-CODE = '5812' OR
              LR-INDUSTRY-CODE = '5813'
               MOVE 15 TO WS-INDUSTRY-RISK
           END-IF
           IF LR-INDUSTRY-CODE = '1521' OR
              LR-INDUSTRY-CODE = '1522'
               MOVE 12 TO WS-INDUSTRY-RISK
           END-IF
           ADD WS-INDUSTRY-RISK TO WS-SCORE.
       3400-DELINQUENCY-SCORE.
           EVALUATE TRUE
               WHEN LR-DAYS-DELINQ = 0
                   ADD 0 TO WS-SCORE
               WHEN LR-DAYS-DELINQ < 30
                   ADD 10 TO WS-SCORE
               WHEN LR-DAYS-DELINQ < 60
                   ADD 25 TO WS-SCORE
               WHEN LR-DAYS-DELINQ < 90
                   ADD 40 TO WS-SCORE
               WHEN OTHER
                   ADD 60 TO WS-SCORE
           END-EVALUATE.
       4000-ASSIGN-GRADE.
           EVALUATE TRUE
               WHEN WS-SCORE < 25
                   MOVE 1 TO WS-GRADE
                   MOVE 'PASS' TO WS-GRADE-DESC
               WHEN WS-SCORE < 50
                   MOVE 2 TO WS-GRADE
                   MOVE 'WATCH' TO WS-GRADE-DESC
                   ADD LR-OUTSTANDING TO WS-WATCH-TOTAL
               WHEN WS-SCORE < 75
                   MOVE 3 TO WS-GRADE
                   MOVE 'SUBSTANDARD' TO WS-GRADE-DESC
                   ADD LR-OUTSTANDING TO WS-CLASSIFIED-TOTAL
               WHEN WS-SCORE < 100
                   MOVE 4 TO WS-GRADE
                   MOVE 'DOUBTFUL' TO WS-GRADE-DESC
                   ADD LR-OUTSTANDING TO WS-CLASSIFIED-TOTAL
               WHEN OTHER
                   MOVE 5 TO WS-GRADE
                   MOVE 'LOSS' TO WS-GRADE-DESC
                   ADD LR-OUTSTANDING TO WS-CLASSIFIED-TOTAL
           END-EVALUATE.
       5000-CHECK-DOWNGRADE.
           MOVE 'N' TO WS-DOWNGRADE-FLAG
           IF LR-PRIOR-GRADE > 0 AND
              WS-GRADE > LR-PRIOR-GRADE
               MOVE 'Y' TO WS-DOWNGRADE-FLAG
               ADD 1 TO WS-DOWNGRADE-CNT
               MOVE SPACES TO WS-MSG
               STRING 'DOWNGRADE: '
                   DELIMITED BY SIZE
                   LR-LOAN-NUM
                   DELIMITED BY SIZE
                   ' FROM '
                   DELIMITED BY SIZE
                   INTO WS-MSG
               DISPLAY WS-MSG
           END-IF.
       8000-PRINT-SUMMARY.
           DISPLAY 'COMMERCIAL LOAN GRADING SUMMARY'
           DISPLAY 'TOTAL LOANS:    ' WS-LOAN-CNT
           DISPLAY 'OUTSTANDING:    ' WS-TOTAL-OUTSTANDING
           DISPLAY 'WATCH LIST:     ' WS-WATCH-TOTAL
           DISPLAY 'CLASSIFIED:     ' WS-CLASSIFIED-TOTAL
           DISPLAY 'DOWNGRADES:     ' WS-DOWNGRADE-CNT
           PERFORM VARYING WS-GRADE-IDX FROM 1 BY 1
               UNTIL WS-GRADE-IDX > 5
               DISPLAY 'GRADE ' WS-GRADE-IDX ': '
                   WS-GRADE-CT(WS-GRADE-IDX)
           END-PERFORM.
       9000-FINALIZE.
           CLOSE LOAN-FILE.
