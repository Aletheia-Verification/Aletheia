       IDENTIFICATION DIVISION.
       PROGRAM-ID. MMKT-TIER-ACCRUE.
      *================================================================*
      * Money Market Tiered Interest Accrual                            *
      * Applies blended tiered rates across balance bands,              *
      * calculates daily accrual using actual/365 day count,            *
      * and generates month-end interest posting records.               *
      *================================================================*
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT MMKT-FILE ASSIGN TO 'MMKTACCT.DAT'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-MMK-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD  MMKT-FILE.
       01  MMKT-RECORD.
           05  MR-ACCT-NUM         PIC X(12).
           05  MR-BALANCE          PIC S9(11)V99.
           05  MR-PRIOR-ACCRUED    PIC S9(09)V99.
           05  MR-ACCT-OPEN-DATE   PIC 9(08).
           05  MR-PROMO-RATE-FLAG  PIC X(01).
           05  MR-PROMO-EXPIRE     PIC 9(08).
       WORKING-STORAGE SECTION.
       01  WS-MMK-STATUS          PIC XX VALUE SPACES.
       01  WS-EOF                 PIC X VALUE 'N'.
           88  END-OF-FILE        VALUE 'Y'.
       01  WS-TIER-TABLE.
           05  WS-TIER-ENTRY      OCCURS 6 TIMES.
               10  TT-LOWER       PIC 9(11)V99.
               10  TT-UPPER       PIC 9(11)V99.
               10  TT-RATE        PIC 9V9(06).
       01  WS-NUM-TIERS           PIC 9(02) VALUE 5.
       01  WS-TIER-IDX            PIC 9(02).
       01  WS-REMAINING-BAL       PIC S9(11)V99.
       01  WS-TIER-AMT            PIC S9(11)V99.
       01  WS-TIER-INT            PIC S9(09)V99.
       01  WS-DAILY-INT           PIC S9(09)V9(06).
       01  WS-TOTAL-DAILY-INT     PIC S9(09)V9(06).
       01  WS-MTD-INTEREST        PIC S9(09)V99.
       01  WS-BLENDED-RATE        PIC 9V9(08).
       01  WS-PROMO-RATE          PIC 9V9(06) VALUE 0.055000.
       01  WS-PROMO-BONUS         PIC S9(09)V99.
       01  WS-ACCT-CNT            PIC 9(08) VALUE 0.
       01  WS-PROMO-CNT           PIC 9(08) VALUE 0.
       01  WS-TOTAL-INTEREST      PIC S9(13)V99 VALUE 0.
       01  WS-TOTAL-BAL           PIC S9(15)V99 VALUE 0.
       01  WS-AVG-RATE            PIC 9V9(06).
       01  WS-DAYS-IN-MONTH       PIC 9(02) VALUE 30.
       01  WS-CURRENT-DATE.
           05  WS-CUR-YEAR        PIC 9(04).
           05  WS-CUR-MONTH       PIC 9(02).
           05  WS-CUR-DAY         PIC 9(02).
       01  WS-TODAY-NUM           PIC 9(08).
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PROCESS-ACCOUNTS
               UNTIL END-OF-FILE
           PERFORM 9000-FINALIZE
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           COMPUTE WS-TODAY-NUM =
               WS-CUR-YEAR * 10000 +
               WS-CUR-MONTH * 100 + WS-CUR-DAY
           PERFORM 1200-LOAD-TIERS
           OPEN INPUT MMKT-FILE
           IF WS-MMK-STATUS NOT = '00'
               DISPLAY 'MMKT FILE ERROR: ' WS-MMK-STATUS
               STOP RUN
           END-IF
           PERFORM 1100-READ-MMKT.
       1100-READ-MMKT.
           READ MMKT-FILE
               AT END SET END-OF-FILE TO TRUE
           END-READ.
       1200-LOAD-TIERS.
           MOVE 0.00 TO TT-LOWER(1)
           MOVE 2499.99 TO TT-UPPER(1)
           MOVE 0.010000 TO TT-RATE(1)
           MOVE 2500.00 TO TT-LOWER(2)
           MOVE 9999.99 TO TT-UPPER(2)
           MOVE 0.020000 TO TT-RATE(2)
           MOVE 10000.00 TO TT-LOWER(3)
           MOVE 49999.99 TO TT-UPPER(3)
           MOVE 0.035000 TO TT-RATE(3)
           MOVE 50000.00 TO TT-LOWER(4)
           MOVE 99999.99 TO TT-UPPER(4)
           MOVE 0.042000 TO TT-RATE(4)
           MOVE 100000.00 TO TT-LOWER(5)
           MOVE 99999999.99 TO TT-UPPER(5)
           MOVE 0.048000 TO TT-RATE(5).
       2000-PROCESS-ACCOUNTS.
           ADD 1 TO WS-ACCT-CNT
           ADD MR-BALANCE TO WS-TOTAL-BAL
           IF MR-BALANCE > ZERO
               PERFORM 3000-CALC-TIERED-INT
               PERFORM 4000-CHECK-PROMO
               PERFORM 5000-CALC-MTD
           ELSE
               MOVE ZERO TO WS-TOTAL-DAILY-INT
           END-IF
           PERFORM 1100-READ-MMKT.
       3000-CALC-TIERED-INT.
           MOVE ZERO TO WS-TOTAL-DAILY-INT
           MOVE MR-BALANCE TO WS-REMAINING-BAL
           PERFORM VARYING WS-TIER-IDX FROM 1 BY 1
               UNTIL WS-TIER-IDX > WS-NUM-TIERS
               OR WS-REMAINING-BAL <= ZERO
               COMPUTE WS-TIER-AMT =
                   TT-UPPER(WS-TIER-IDX) -
                   TT-LOWER(WS-TIER-IDX) + 0.01
               IF WS-REMAINING-BAL < WS-TIER-AMT
                   MOVE WS-REMAINING-BAL TO WS-TIER-AMT
               END-IF
               COMPUTE WS-DAILY-INT ROUNDED =
                   WS-TIER-AMT *
                   TT-RATE(WS-TIER-IDX) / 365
               ADD WS-DAILY-INT TO WS-TOTAL-DAILY-INT
               SUBTRACT WS-TIER-AMT FROM
                   WS-REMAINING-BAL
           END-PERFORM
           IF MR-BALANCE > ZERO
               COMPUTE WS-BLENDED-RATE ROUNDED =
                   (WS-TOTAL-DAILY-INT * 365) /
                   MR-BALANCE
           END-IF.
       4000-CHECK-PROMO.
           IF MR-PROMO-RATE-FLAG = 'Y'
               IF MR-PROMO-EXPIRE >= WS-TODAY-NUM
                   COMPUTE WS-PROMO-BONUS ROUNDED =
                       MR-BALANCE * WS-PROMO-RATE / 365
                   SUBTRACT WS-TOTAL-DAILY-INT FROM
                       WS-PROMO-BONUS
                   IF WS-PROMO-BONUS > ZERO
                       ADD WS-PROMO-BONUS TO
                           WS-TOTAL-DAILY-INT
                   END-IF
                   ADD 1 TO WS-PROMO-CNT
               END-IF
           END-IF.
       5000-CALC-MTD.
           COMPUTE WS-MTD-INTEREST ROUNDED =
               WS-TOTAL-DAILY-INT * WS-DAYS-IN-MONTH
           ADD WS-MTD-INTEREST TO WS-TOTAL-INTEREST
           DISPLAY MR-ACCT-NUM ' BAL='
               MR-BALANCE ' INT='
               WS-MTD-INTEREST ' RATE='
               WS-BLENDED-RATE.
       9000-FINALIZE.
           CLOSE MMKT-FILE
           IF WS-TOTAL-BAL > ZERO
               COMPUTE WS-AVG-RATE ROUNDED =
                   (WS-TOTAL-INTEREST * 12) /
                   WS-TOTAL-BAL
           END-IF
           DISPLAY 'MONEY MARKET ACCRUAL COMPLETE'
           DISPLAY 'ACCOUNTS:   ' WS-ACCT-CNT
           DISPLAY 'PROMO ACCTS:' WS-PROMO-CNT
           DISPLAY 'TOTAL BAL:  ' WS-TOTAL-BAL
           DISPLAY 'TOTAL INT:  ' WS-TOTAL-INTEREST
           DISPLAY 'AVG RATE:   ' WS-AVG-RATE.
