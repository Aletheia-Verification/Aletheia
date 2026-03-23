       IDENTIFICATION DIVISION.
       PROGRAM-ID. MMKT-SWEEP-ENGINE.
      *================================================================*
      * Money Market Sweep Engine                                       *
      * Sweeps excess balances from checking to money market accounts,  *
      * calculates tiered interest, enforces Reg D transaction limits.  *
      *================================================================*
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT SWEEP-FILE ASSIGN TO 'SWEEP.DAT'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-SWP-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD  SWEEP-FILE.
       01  SWEEP-RECORD.
           05  SR-CUST-ID           PIC X(10).
           05  SR-CHK-ACCT          PIC X(12).
           05  SR-MMK-ACCT          PIC X(12).
           05  SR-CHK-BAL           PIC S9(11)V99.
           05  SR-MMK-BAL           PIC S9(11)V99.
           05  SR-TARGET-BAL        PIC 9(11)V99.
           05  SR-SWEEP-DIR         PIC X(01).
           05  SR-MTD-TRANS         PIC 9(03).
       WORKING-STORAGE SECTION.
       01  WS-SWP-STATUS           PIC XX VALUE SPACES.
       01  WS-EOF                  PIC X VALUE 'N'.
           88  END-OF-FILE         VALUE 'Y'.
       01  WS-SWEEP-AMT            PIC S9(11)V99.
       01  WS-INTEREST-AMT         PIC S9(09)V99.
       01  WS-REG-D-LIMIT          PIC 9(03) VALUE 6.
       01  WS-REG-D-REMAINING      PIC 9(03).
       01  WS-DAILY-RATE            PIC 9V9(08).
       01  WS-EXCESS               PIC S9(11)V99.
       01  WS-SHORTFALL            PIC S9(11)V99.
       01  WS-SWEEP-CNT            PIC 9(08) VALUE 0.
       01  WS-SKIP-CNT             PIC 9(08) VALUE 0.
       01  WS-REGD-BLOCK-CNT       PIC 9(08) VALUE 0.
       01  WS-TOTAL-SWEPT          PIC S9(13)V99 VALUE 0.
       01  WS-TOTAL-INTEREST       PIC S9(11)V99 VALUE 0.
       01  WS-TIER-TABLE.
           05  WS-TIER-ENTRY       OCCURS 5 TIMES.
               10  TIER-FLOOR      PIC 9(11)V99.
               10  TIER-RATE       PIC 9V9(06).
       01  WS-TIER-IDX             PIC 9(02).
       01  WS-APPLICABLE-RATE      PIC 9V9(06).
       01  WS-ERR-BUF              PIC X(100) VALUE SPACES.
       01  WS-CURRENT-DATE.
           05  WS-CUR-YEAR         PIC 9(04).
           05  WS-CUR-MONTH        PIC 9(02).
           05  WS-CUR-DAY          PIC 9(02).
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PROCESS-SWEEPS UNTIL END-OF-FILE
           PERFORM 9000-FINALIZE
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           PERFORM 1200-LOAD-TIER-RATES
           OPEN INPUT SWEEP-FILE
           IF WS-SWP-STATUS NOT = '00'
               DISPLAY 'SWEEP FILE ERROR: ' WS-SWP-STATUS
               STOP RUN
           END-IF
           PERFORM 1100-READ-SWEEP.
       1100-READ-SWEEP.
           READ SWEEP-FILE
               AT END SET END-OF-FILE TO TRUE
           END-READ.
       1200-LOAD-TIER-RATES.
           MOVE 0           TO TIER-FLOOR(1)
           MOVE 0.010000    TO TIER-RATE(1)
           MOVE 10000.00    TO TIER-FLOOR(2)
           MOVE 0.020000    TO TIER-RATE(2)
           MOVE 50000.00    TO TIER-FLOOR(3)
           MOVE 0.035000    TO TIER-RATE(3)
           MOVE 100000.00   TO TIER-FLOOR(4)
           MOVE 0.045000    TO TIER-RATE(4)
           MOVE 500000.00   TO TIER-FLOOR(5)
           MOVE 0.050000    TO TIER-RATE(5).
       2000-PROCESS-SWEEPS.
           EVALUATE SR-SWEEP-DIR
               WHEN 'O'
                   PERFORM 3000-SWEEP-OUT
               WHEN 'I'
                   PERFORM 4000-SWEEP-IN
               WHEN 'A'
                   PERFORM 5000-AUTO-SWEEP
               WHEN OTHER
                   ADD 1 TO WS-SKIP-CNT
           END-EVALUATE
           PERFORM 1100-READ-SWEEP.
       3000-SWEEP-OUT.
           IF SR-MTD-TRANS >= WS-REG-D-LIMIT
               ADD 1 TO WS-REGD-BLOCK-CNT
               MOVE SPACES TO WS-ERR-BUF
               STRING 'REG-D BLOCK CUST='
                   DELIMITED BY SIZE
                   SR-CUST-ID
                   DELIMITED BY SIZE
                   ' TRANS='
                   DELIMITED BY SIZE
                   INTO WS-ERR-BUF
               DISPLAY WS-ERR-BUF
           ELSE
               COMPUTE WS-EXCESS =
                   SR-CHK-BAL - SR-TARGET-BAL
               IF WS-EXCESS > 100
                   MOVE WS-EXCESS TO WS-SWEEP-AMT
                   PERFORM 6000-CALC-INTEREST
                   ADD WS-SWEEP-AMT TO WS-TOTAL-SWEPT
                   ADD 1 TO WS-SWEEP-CNT
               END-IF
           END-IF.
       4000-SWEEP-IN.
           IF SR-CHK-BAL < SR-TARGET-BAL
               COMPUTE WS-SHORTFALL =
                   SR-TARGET-BAL - SR-CHK-BAL
               IF WS-SHORTFALL <= SR-MMK-BAL
                   MOVE WS-SHORTFALL TO WS-SWEEP-AMT
               ELSE
                   MOVE SR-MMK-BAL TO WS-SWEEP-AMT
               END-IF
               IF WS-SWEEP-AMT > ZERO
                   SUBTRACT WS-SWEEP-AMT FROM
                       WS-TOTAL-SWEPT
                   ADD 1 TO WS-SWEEP-CNT
               END-IF
           END-IF.
       5000-AUTO-SWEEP.
           IF SR-CHK-BAL > SR-TARGET-BAL
               PERFORM 3000-SWEEP-OUT
           ELSE
               IF SR-CHK-BAL < SR-TARGET-BAL
                   PERFORM 4000-SWEEP-IN
               END-IF
           END-IF.
       6000-CALC-INTEREST.
           MOVE 0.010000 TO WS-APPLICABLE-RATE
           PERFORM VARYING WS-TIER-IDX FROM 5 BY -1
               UNTIL WS-TIER-IDX < 1
               IF SR-MMK-BAL >= TIER-FLOOR(WS-TIER-IDX)
                   MOVE TIER-RATE(WS-TIER-IDX)
                       TO WS-APPLICABLE-RATE
               END-IF
           END-PERFORM
           COMPUTE WS-DAILY-RATE =
               WS-APPLICABLE-RATE / 365
           COMPUTE WS-INTEREST-AMT ROUNDED =
               SR-MMK-BAL * WS-DAILY-RATE
           ADD WS-INTEREST-AMT TO WS-TOTAL-INTEREST.
       9000-FINALIZE.
           CLOSE SWEEP-FILE
           DISPLAY 'MONEY MARKET SWEEP COMPLETE'
           DISPLAY 'SWEEPS:     ' WS-SWEEP-CNT
           DISPLAY 'SKIPPED:    ' WS-SKIP-CNT
           DISPLAY 'REG-D BLOCK:' WS-REGD-BLOCK-CNT
           DISPLAY 'NET SWEPT:  ' WS-TOTAL-SWEPT
           DISPLAY 'INTEREST:   ' WS-TOTAL-INTEREST.
