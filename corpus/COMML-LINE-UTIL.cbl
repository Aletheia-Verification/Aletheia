       IDENTIFICATION DIVISION.
       PROGRAM-ID. COMML-LINE-UTIL.
      *================================================================*
      * Commercial Line of Credit Utilization Monitor                    *
      * Tracks revolving line usage, calculates commitment/usage fees,  *
      * monitors borrowing base compliance, and flags over-advances.    *
      *================================================================*
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT LINE-FILE ASSIGN TO 'LOCUTIL.DAT'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-LIN-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD  LINE-FILE.
       01  LINE-RECORD.
           05  LN-LOAN-NUM         PIC X(12).
           05  LN-BORROWER         PIC X(25).
           05  LN-COMMITMENT       PIC 9(11)V99.
           05  LN-OUTSTANDING      PIC 9(11)V99.
           05  LN-AVAIL-BAL        PIC S9(11)V99.
           05  LN-INT-RATE         PIC 9V9(06).
           05  LN-COMMIT-FEE-RT    PIC 9V9(04).
           05  LN-AR-ELIGIBLE      PIC 9(11)V99.
           05  LN-INV-ELIGIBLE     PIC 9(11)V99.
           05  LN-AR-ADV-RATE      PIC 9(03).
           05  LN-INV-ADV-RATE     PIC 9(03).
           05  LN-MATURITY-DATE    PIC 9(08).
       WORKING-STORAGE SECTION.
       01  WS-LIN-STATUS          PIC XX VALUE SPACES.
       01  WS-EOF                 PIC X VALUE 'N'.
           88  END-OF-FILE        VALUE 'Y'.
       01  WS-BB-AR-AMT           PIC S9(11)V99.
       01  WS-BB-INV-AMT          PIC S9(11)V99.
       01  WS-BORROWING-BASE      PIC S9(11)V99.
       01  WS-EFFECTIVE-AVAIL     PIC S9(11)V99.
       01  WS-OVER-ADVANCE        PIC S9(11)V99.
       01  WS-UTIL-PCT            PIC 9(03)V99.
       01  WS-UNUSED-AMT          PIC S9(11)V99.
       01  WS-INT-CHARGE          PIC S9(09)V99.
       01  WS-COMMIT-FEE          PIC S9(09)V99.
       01  WS-LINE-CNT            PIC 9(06) VALUE 0.
       01  WS-OVER-ADV-CNT        PIC 9(06) VALUE 0.
       01  WS-HIGH-UTIL-CNT       PIC 9(06) VALUE 0.
       01  WS-MATURING-CNT        PIC 9(06) VALUE 0.
       01  WS-TOTAL-COMMIT        PIC S9(15)V99 VALUE 0.
       01  WS-TOTAL-OUTSTAND      PIC S9(15)V99 VALUE 0.
       01  WS-TOTAL-INT           PIC S9(13)V99 VALUE 0.
       01  WS-TOTAL-FEES          PIC S9(11)V99 VALUE 0.
       01  WS-PORTFOLIO-UTIL      PIC 9(03)V99.
       01  WS-DAYS-TO-MATURITY    PIC S9(05).
       01  WS-MSG                 PIC X(100) VALUE SPACES.
       01  WS-CURRENT-DATE.
           05  WS-CUR-YEAR        PIC 9(04).
           05  WS-CUR-MONTH       PIC 9(02).
           05  WS-CUR-DAY         PIC 9(02).
       01  WS-TODAY-NUM           PIC 9(08).
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PROCESS-LINES UNTIL END-OF-FILE
           PERFORM 8000-PORTFOLIO-SUMMARY
           PERFORM 9000-FINALIZE
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           COMPUTE WS-TODAY-NUM =
               WS-CUR-YEAR * 10000 +
               WS-CUR-MONTH * 100 + WS-CUR-DAY
           OPEN INPUT LINE-FILE
           IF WS-LIN-STATUS NOT = '00'
               DISPLAY 'LINE FILE ERROR: ' WS-LIN-STATUS
               STOP RUN
           END-IF
           PERFORM 1100-READ-LINE.
       1100-READ-LINE.
           READ LINE-FILE
               AT END SET END-OF-FILE TO TRUE
           END-READ.
       2000-PROCESS-LINES.
           ADD 1 TO WS-LINE-CNT
           ADD LN-COMMITMENT TO WS-TOTAL-COMMIT
           ADD LN-OUTSTANDING TO WS-TOTAL-OUTSTAND
           PERFORM 3000-CALC-BORROWING-BASE
           PERFORM 4000-CHECK-OVER-ADVANCE
           PERFORM 5000-CALC-UTILIZATION
           PERFORM 6000-CALC-CHARGES
           PERFORM 7000-CHECK-MATURITY
           PERFORM 1100-READ-LINE.
       3000-CALC-BORROWING-BASE.
           COMPUTE WS-BB-AR-AMT ROUNDED =
               LN-AR-ELIGIBLE * LN-AR-ADV-RATE / 100
           COMPUTE WS-BB-INV-AMT ROUNDED =
               LN-INV-ELIGIBLE * LN-INV-ADV-RATE / 100
           COMPUTE WS-BORROWING-BASE =
               WS-BB-AR-AMT + WS-BB-INV-AMT
           IF WS-BORROWING-BASE < LN-COMMITMENT
               MOVE WS-BORROWING-BASE TO
                   WS-EFFECTIVE-AVAIL
           ELSE
               MOVE LN-COMMITMENT TO WS-EFFECTIVE-AVAIL
           END-IF.
       4000-CHECK-OVER-ADVANCE.
           IF LN-OUTSTANDING > WS-EFFECTIVE-AVAIL
               COMPUTE WS-OVER-ADVANCE =
                   LN-OUTSTANDING - WS-EFFECTIVE-AVAIL
               ADD 1 TO WS-OVER-ADV-CNT
               MOVE SPACES TO WS-MSG
               STRING 'OVER-ADVANCE: '
                   DELIMITED BY SIZE
                   LN-LOAN-NUM
                   DELIMITED BY SIZE
                   ' '
                   DELIMITED BY SIZE
                   LN-BORROWER
                   DELIMITED BY SIZE
                   ' AMT='
                   DELIMITED BY SIZE
                   INTO WS-MSG
               DISPLAY WS-MSG WS-OVER-ADVANCE
           ELSE
               MOVE ZERO TO WS-OVER-ADVANCE
           END-IF.
       5000-CALC-UTILIZATION.
           IF LN-COMMITMENT > ZERO
               COMPUTE WS-UTIL-PCT ROUNDED =
                   (LN-OUTSTANDING / LN-COMMITMENT) * 100
           ELSE
               MOVE ZERO TO WS-UTIL-PCT
           END-IF
           IF WS-UTIL-PCT > 90.00
               ADD 1 TO WS-HIGH-UTIL-CNT
           END-IF.
       6000-CALC-CHARGES.
           COMPUTE WS-INT-CHARGE ROUNDED =
               LN-OUTSTANDING * LN-INT-RATE / 12
           ADD WS-INT-CHARGE TO WS-TOTAL-INT
           COMPUTE WS-UNUSED-AMT =
               LN-COMMITMENT - LN-OUTSTANDING
           IF WS-UNUSED-AMT > ZERO
               COMPUTE WS-COMMIT-FEE ROUNDED =
                   WS-UNUSED-AMT * LN-COMMIT-FEE-RT / 12
           ELSE
               MOVE ZERO TO WS-COMMIT-FEE
           END-IF
           ADD WS-COMMIT-FEE TO WS-TOTAL-FEES.
       7000-CHECK-MATURITY.
           IF LN-MATURITY-DATE > WS-TODAY-NUM
               COMPUTE WS-DAYS-TO-MATURITY =
                   LN-MATURITY-DATE - WS-TODAY-NUM
               IF WS-DAYS-TO-MATURITY <= 90
                   ADD 1 TO WS-MATURING-CNT
                   DISPLAY 'MATURING: ' LN-LOAN-NUM
                       ' DAYS=' WS-DAYS-TO-MATURITY
               END-IF
           ELSE
               ADD 1 TO WS-MATURING-CNT
               DISPLAY 'PAST MATURITY: ' LN-LOAN-NUM
           END-IF.
       8000-PORTFOLIO-SUMMARY.
           IF WS-TOTAL-COMMIT > ZERO
               COMPUTE WS-PORTFOLIO-UTIL ROUNDED =
                   (WS-TOTAL-OUTSTAND / WS-TOTAL-COMMIT)
                   * 100
           END-IF.
       9000-FINALIZE.
           CLOSE LINE-FILE
           DISPLAY 'LINE UTILIZATION MONITOR COMPLETE'
           DISPLAY 'TOTAL LINES:   ' WS-LINE-CNT
           DISPLAY 'COMMITMENT:    ' WS-TOTAL-COMMIT
           DISPLAY 'OUTSTANDING:   ' WS-TOTAL-OUTSTAND
           DISPLAY 'PORTFOLIO UTIL:' WS-PORTFOLIO-UTIL '%'
           DISPLAY 'OVER-ADVANCES: ' WS-OVER-ADV-CNT
           DISPLAY 'HIGH UTIL:     ' WS-HIGH-UTIL-CNT
           DISPLAY 'MATURING:      ' WS-MATURING-CNT
           DISPLAY 'INTEREST:      ' WS-TOTAL-INT
           DISPLAY 'COMMIT FEES:   ' WS-TOTAL-FEES.
