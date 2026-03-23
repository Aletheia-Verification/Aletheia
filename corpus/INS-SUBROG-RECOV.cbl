       IDENTIFICATION DIVISION.
       PROGRAM-ID. INS-SUBROG-RECOV.
      *================================================================
      * SUBROGATION RECOVERY TRACKER
      * Manages third-party recovery efforts on paid claims,
      * tracks recovery rates, and allocates recovered amounts.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CLAIM.
           05 WS-CLM-NUM              PIC X(15).
           05 WS-CLM-DATE             PIC 9(8).
           05 WS-CLM-PAID-AMT         PIC S9(9)V99 COMP-3.
           05 WS-CLM-LINE-BUS         PIC X(3).
               88 LB-AUTO             VALUE 'AUT'.
               88 LB-PROPERTY         VALUE 'PRP'.
               88 LB-LIABILITY        VALUE 'LIA'.
               88 LB-WORKERS          VALUE 'WRK'.
           05 WS-CLM-FAULT-PCT        PIC S9(3)V99 COMP-3.
       01 WS-RECOVERY.
           05 WS-REC-ATTEMPTS OCCURS 5 TIMES.
               10 WS-RA-DATE          PIC 9(8).
               10 WS-RA-AMT-DEMANDED  PIC S9(9)V99 COMP-3.
               10 WS-RA-AMT-RECEIVED  PIC S9(9)V99 COMP-3.
               10 WS-RA-STATUS        PIC X(1).
                   88 RA-OPEN         VALUE 'O'.
                   88 RA-PARTIAL      VALUE 'P'.
                   88 RA-CLOSED       VALUE 'C'.
                   88 RA-DENIED       VALUE 'D'.
       01 WS-ATTEMPT-COUNT            PIC 9(1) VALUE 0.
       01 WS-IDX                      PIC 9(1).
       01 WS-CALC.
           05 WS-MAX-RECOVERABLE      PIC S9(9)V99 COMP-3.
           05 WS-TOTAL-DEMANDED       PIC S9(9)V99 COMP-3
               VALUE 0.
           05 WS-TOTAL-RECEIVED       PIC S9(9)V99 COMP-3
               VALUE 0.
           05 WS-RECOVERY-RATE        PIC S9(3)V99 COMP-3.
           05 WS-NET-LOSS             PIC S9(9)V99 COMP-3.
           05 WS-DEDUCTIBLE-REFUND    PIC S9(7)V99 COMP-3.
           05 WS-INSURER-PORTION      PIC S9(9)V99 COMP-3.
           05 WS-DEDUCTIBLE-AMT       PIC S9(7)V99 COMP-3
               VALUE 1000.00.
           05 WS-DEDUCT-RATIO         PIC S9(1)V9(4) COMP-3.
       01 WS-AGING.
           05 WS-DAYS-SINCE-CLAIM     PIC S9(5) COMP-3.
           05 WS-AGING-CATEGORY       PIC X(10).
           05 WS-WRITE-OFF-FLAG       PIC X VALUE 'N'.
               88 SHOULD-WRITE-OFF    VALUE 'Y'.
       01 WS-CURRENT-DATE             PIC 9(8).
       01 WS-WRITE-OFF-DAYS           PIC 9(4) VALUE 730.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-MAX-RECOVERABLE
           PERFORM 3000-LOAD-RECOVERY-DATA
           PERFORM 4000-TALLY-RECOVERIES
           PERFORM 5000-ALLOCATE-RECOVERY
           PERFORM 6000-AGING-ANALYSIS
           PERFORM 7000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           MOVE 'CLM-2025-00847' TO WS-CLM-NUM
           MOVE 20250215 TO WS-CLM-DATE
           MOVE 45000.00 TO WS-CLM-PAID-AMT
           MOVE 'AUT' TO WS-CLM-LINE-BUS
           MOVE 80.00 TO WS-CLM-FAULT-PCT.
       2000-CALC-MAX-RECOVERABLE.
           COMPUTE WS-MAX-RECOVERABLE =
               WS-CLM-PAID-AMT *
               (WS-CLM-FAULT-PCT / 100).
       3000-LOAD-RECOVERY-DATA.
           MOVE 20250315 TO WS-RA-DATE(1)
           MOVE 36000.00 TO WS-RA-AMT-DEMANDED(1)
           MOVE 0 TO WS-RA-AMT-RECEIVED(1)
           MOVE 'O' TO WS-RA-STATUS(1)
           MOVE 20250501 TO WS-RA-DATE(2)
           MOVE 36000.00 TO WS-RA-AMT-DEMANDED(2)
           MOVE 15000.00 TO WS-RA-AMT-RECEIVED(2)
           MOVE 'P' TO WS-RA-STATUS(2)
           MOVE 20250815 TO WS-RA-DATE(3)
           MOVE 21000.00 TO WS-RA-AMT-DEMANDED(3)
           MOVE 18000.00 TO WS-RA-AMT-RECEIVED(3)
           MOVE 'C' TO WS-RA-STATUS(3)
           MOVE 3 TO WS-ATTEMPT-COUNT.
       4000-TALLY-RECOVERIES.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-ATTEMPT-COUNT
               ADD WS-RA-AMT-DEMANDED(WS-IDX)
                   TO WS-TOTAL-DEMANDED
               ADD WS-RA-AMT-RECEIVED(WS-IDX)
                   TO WS-TOTAL-RECEIVED
           END-PERFORM
           IF WS-MAX-RECOVERABLE > 0
               COMPUTE WS-RECOVERY-RATE =
                   (WS-TOTAL-RECEIVED /
                   WS-MAX-RECOVERABLE) * 100
           ELSE
               MOVE 0 TO WS-RECOVERY-RATE
           END-IF
           COMPUTE WS-NET-LOSS =
               WS-CLM-PAID-AMT - WS-TOTAL-RECEIVED.
       5000-ALLOCATE-RECOVERY.
           IF WS-CLM-PAID-AMT > 0
               COMPUTE WS-DEDUCT-RATIO =
                   WS-DEDUCTIBLE-AMT / WS-CLM-PAID-AMT
           ELSE
               MOVE 0 TO WS-DEDUCT-RATIO
           END-IF
           COMPUTE WS-DEDUCTIBLE-REFUND =
               WS-TOTAL-RECEIVED * WS-DEDUCT-RATIO
           COMPUTE WS-INSURER-PORTION =
               WS-TOTAL-RECEIVED - WS-DEDUCTIBLE-REFUND.
       6000-AGING-ANALYSIS.
           COMPUTE WS-DAYS-SINCE-CLAIM =
               WS-CURRENT-DATE - WS-CLM-DATE
           EVALUATE TRUE
               WHEN WS-DAYS-SINCE-CLAIM < 90
                   MOVE 'CURRENT   ' TO WS-AGING-CATEGORY
               WHEN WS-DAYS-SINCE-CLAIM < 180
                   MOVE '90-180    ' TO WS-AGING-CATEGORY
               WHEN WS-DAYS-SINCE-CLAIM < 365
                   MOVE '180-365   ' TO WS-AGING-CATEGORY
               WHEN WS-DAYS-SINCE-CLAIM < WS-WRITE-OFF-DAYS
                   MOVE '365+      ' TO WS-AGING-CATEGORY
               WHEN OTHER
                   MOVE 'WRITE-OFF ' TO WS-AGING-CATEGORY
                   MOVE 'Y' TO WS-WRITE-OFF-FLAG
           END-EVALUATE.
       7000-DISPLAY-RESULTS.
           DISPLAY 'SUBROGATION RECOVERY REPORT'
           DISPLAY '==========================='
           DISPLAY 'CLAIM:           ' WS-CLM-NUM
           DISPLAY 'PAID AMOUNT:     ' WS-CLM-PAID-AMT
           DISPLAY 'FAULT %:         ' WS-CLM-FAULT-PCT
           DISPLAY 'MAX RECOVERABLE: ' WS-MAX-RECOVERABLE
           DISPLAY 'TOTAL DEMANDED:  ' WS-TOTAL-DEMANDED
           DISPLAY 'TOTAL RECEIVED:  ' WS-TOTAL-RECEIVED
           DISPLAY 'RECOVERY RATE:   ' WS-RECOVERY-RATE
           DISPLAY 'NET LOSS:        ' WS-NET-LOSS
           DISPLAY 'DEDUCT REFUND:   ' WS-DEDUCTIBLE-REFUND
           DISPLAY 'INSURER SHARE:   ' WS-INSURER-PORTION
           DISPLAY 'AGING:           ' WS-AGING-CATEGORY
           IF SHOULD-WRITE-OFF
               DISPLAY 'RECOMMEND: WRITE OFF BALANCE'
           END-IF.
