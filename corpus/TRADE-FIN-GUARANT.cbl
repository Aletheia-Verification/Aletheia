       IDENTIFICATION DIVISION.
       PROGRAM-ID. TRADE-FIN-GUARANT.
      *================================================================*
      * Trade Finance Bank Guarantee Manager                            *
      * Manages standby and performance guarantees, tracks utilization, *
      * calculates commitment fees, and monitors expiry/claim status.   *
      *================================================================*
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT GUARANT-FILE ASSIGN TO 'GUARANT.DAT'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-GRT-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD  GUARANT-FILE.
       01  GUARANT-RECORD.
           05  GR-REF-NUM           PIC X(12).
           05  GR-TYPE              PIC X(02).
           05  GR-AMOUNT            PIC 9(11)V99.
           05  GR-UTILIZED          PIC 9(11)V99.
           05  GR-CURRENCY          PIC X(03).
           05  GR-ISSUE-DATE        PIC 9(08).
           05  GR-EXPIRY-DATE       PIC 9(08).
           05  GR-APPLICANT         PIC X(25).
           05  GR-BENEFICIARY       PIC X(25).
           05  GR-CLAIM-STATUS      PIC X(01).
           05  GR-COLLATERAL-PCT    PIC 9(03).
       WORKING-STORAGE SECTION.
       01  WS-GRT-STATUS          PIC XX VALUE SPACES.
       01  WS-EOF                 PIC X VALUE 'N'.
           88  END-OF-FILE        VALUE 'Y'.
       01  WS-GUARANT-CNT        PIC 9(06) VALUE 0.
       01  WS-ACTIVE-CNT         PIC 9(06) VALUE 0.
       01  WS-EXPIRED-CNT        PIC 9(06) VALUE 0.
       01  WS-CLAIMED-CNT        PIC 9(06) VALUE 0.
       01  WS-TOTAL-EXPOSURE     PIC S9(15)V99 VALUE 0.
       01  WS-TOTAL-UTILIZED     PIC S9(15)V99 VALUE 0.
       01  WS-COLLAT-COVERAGE    PIC S9(13)V99 VALUE 0.
       01  WS-FEE-INCOME         PIC S9(11)V99 VALUE 0.
       01  WS-COMMIT-FEE-RATE    PIC 9V9(04) VALUE 0.0150.
       01  WS-STANDBY-FEE-RATE   PIC 9V9(04) VALUE 0.0200.
       01  WS-UTIL-PCT           PIC 9(03)V99.
       01  WS-FEE-AMT            PIC S9(09)V99.
       01  WS-COLLAT-AMT         PIC S9(11)V99.
       01  WS-UNCOVERED          PIC S9(11)V99.
       01  WS-DAYS-TO-EXPIRY     PIC S9(05).
       01  WS-EXPIRING-30        PIC 9(06) VALUE 0.
       01  WS-MSG-BUF            PIC X(100) VALUE SPACES.
       01  WS-CURRENT-DATE.
           05  WS-CUR-YEAR       PIC 9(04).
           05  WS-CUR-MONTH      PIC 9(02).
           05  WS-CUR-DAY        PIC 9(02).
       01  WS-TODAY-NUM          PIC 9(08).
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PROCESS-GUARANTEES
               UNTIL END-OF-FILE
           PERFORM 9000-FINALIZE
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           COMPUTE WS-TODAY-NUM =
               WS-CUR-YEAR * 10000 +
               WS-CUR-MONTH * 100 + WS-CUR-DAY
           OPEN INPUT GUARANT-FILE
           IF WS-GRT-STATUS NOT = '00'
               DISPLAY 'GUARANTEE FILE ERROR: ' WS-GRT-STATUS
               STOP RUN
           END-IF
           PERFORM 1100-READ-GUARANT.
       1100-READ-GUARANT.
           READ GUARANT-FILE
               AT END SET END-OF-FILE TO TRUE
           END-READ.
       2000-PROCESS-GUARANTEES.
           ADD 1 TO WS-GUARANT-CNT
           PERFORM 3000-CHECK-STATUS
           PERFORM 4000-CALC-FEES
           PERFORM 5000-CALC-COLLATERAL
           PERFORM 6000-CHECK-EXPIRY
           PERFORM 1100-READ-GUARANT.
       3000-CHECK-STATUS.
           EVALUATE GR-CLAIM-STATUS
               WHEN 'A'
                   ADD 1 TO WS-ACTIVE-CNT
                   ADD GR-AMOUNT TO WS-TOTAL-EXPOSURE
                   ADD GR-UTILIZED TO WS-TOTAL-UTILIZED
               WHEN 'C'
                   ADD 1 TO WS-CLAIMED-CNT
                   ADD GR-UTILIZED TO WS-TOTAL-UTILIZED
               WHEN 'E'
                   ADD 1 TO WS-EXPIRED-CNT
               WHEN OTHER
                   ADD 1 TO WS-ACTIVE-CNT
                   ADD GR-AMOUNT TO WS-TOTAL-EXPOSURE
           END-EVALUATE.
       4000-CALC-FEES.
           IF GR-CLAIM-STATUS = 'A'
               IF GR-AMOUNT > ZERO
                   COMPUTE WS-UTIL-PCT ROUNDED =
                       (GR-UTILIZED / GR-AMOUNT) * 100
               ELSE
                   MOVE ZERO TO WS-UTIL-PCT
               END-IF
               EVALUATE GR-TYPE
                   WHEN 'SB'
                       COMPUTE WS-FEE-AMT ROUNDED =
                           GR-AMOUNT *
                           WS-STANDBY-FEE-RATE / 12
                   WHEN 'PF'
                       COMPUTE WS-FEE-AMT ROUNDED =
                           GR-AMOUNT *
                           WS-COMMIT-FEE-RATE / 12
                   WHEN 'FN'
                       COMPUTE WS-FEE-AMT ROUNDED =
                           GR-AMOUNT *
                           WS-COMMIT-FEE-RATE / 12
                   WHEN OTHER
                       COMPUTE WS-FEE-AMT ROUNDED =
                           GR-AMOUNT *
                           WS-COMMIT-FEE-RATE / 12
               END-EVALUATE
               ADD WS-FEE-AMT TO WS-FEE-INCOME
           END-IF.
       5000-CALC-COLLATERAL.
           COMPUTE WS-COLLAT-AMT ROUNDED =
               GR-AMOUNT * GR-COLLATERAL-PCT / 100
           ADD WS-COLLAT-AMT TO WS-COLLAT-COVERAGE
           COMPUTE WS-UNCOVERED =
               GR-AMOUNT - WS-COLLAT-AMT
           IF WS-UNCOVERED > 1000000
               MOVE SPACES TO WS-MSG-BUF
               STRING 'HIGH UNCOVERED: '
                   DELIMITED BY SIZE
                   GR-REF-NUM
                   DELIMITED BY SIZE
                   ' AMT='
                   DELIMITED BY SIZE
                   INTO WS-MSG-BUF
               DISPLAY WS-MSG-BUF WS-UNCOVERED
           END-IF.
       6000-CHECK-EXPIRY.
           IF GR-CLAIM-STATUS = 'A'
               IF GR-EXPIRY-DATE > WS-TODAY-NUM
                   COMPUTE WS-DAYS-TO-EXPIRY =
                       GR-EXPIRY-DATE - WS-TODAY-NUM
                   IF WS-DAYS-TO-EXPIRY > 0 AND
                      WS-DAYS-TO-EXPIRY <= 30
                       ADD 1 TO WS-EXPIRING-30
                       DISPLAY 'EXPIRING SOON: '
                           GR-REF-NUM ' DAYS='
                           WS-DAYS-TO-EXPIRY
                   END-IF
               ELSE
                   ADD 1 TO WS-EXPIRED-CNT
               END-IF
           END-IF.
       9000-FINALIZE.
           CLOSE GUARANT-FILE
           DISPLAY 'GUARANTEE PROCESSING COMPLETE'
           DISPLAY 'TOTAL:       ' WS-GUARANT-CNT
           DISPLAY 'ACTIVE:      ' WS-ACTIVE-CNT
           DISPLAY 'CLAIMED:     ' WS-CLAIMED-CNT
           DISPLAY 'EXPIRED:     ' WS-EXPIRED-CNT
           DISPLAY 'EXPOSURE:    ' WS-TOTAL-EXPOSURE
           DISPLAY 'UTILIZED:    ' WS-TOTAL-UTILIZED
           DISPLAY 'COLLATERAL:  ' WS-COLLAT-COVERAGE
           DISPLAY 'FEE INCOME:  ' WS-FEE-INCOME
           DISPLAY 'EXPIRING 30D:' WS-EXPIRING-30.
