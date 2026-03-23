       IDENTIFICATION DIVISION.
       PROGRAM-ID. MTG-SERVICING-FEE.
      *================================================================*
      * Mortgage Servicing Fee Calculator                               *
      * Calculates servicing fees, sub-servicing splits, excess         *
      * servicing income, and ancillary fee revenue by loan pool.       *
      *================================================================*
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT POOL-FILE ASSIGN TO 'MSRPOOL.DAT'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-POOL-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD  POOL-FILE.
       01  POOL-RECORD.
           05  PR-POOL-ID           PIC X(08).
           05  PR-LOAN-COUNT        PIC 9(06).
           05  PR-UPB               PIC 9(13)V99.
           05  PR-WAC               PIC 9V9(06).
           05  PR-NET-RATE          PIC 9V9(06).
           05  PR-SERVICING-RATE    PIC 9V9(06).
           05  PR-GUARANT-FEE       PIC 9V9(06).
           05  PR-DELINQ-PCT        PIC 9(03)V99.
           05  PR-INVESTOR-TYPE     PIC X(02).
           05  PR-ANCILLARY-REV     PIC 9(09)V99.
       WORKING-STORAGE SECTION.
       01  WS-POOL-STATUS         PIC XX VALUE SPACES.
       01  WS-EOF                 PIC X VALUE 'N'.
           88  END-OF-FILE        VALUE 'Y'.
       01  WS-GROSS-SVC-FEE      PIC S9(11)V99.
       01  WS-GUARANT-FEE-AMT    PIC S9(11)V99.
       01  WS-NET-SVC-FEE        PIC S9(11)V99.
       01  WS-EXCESS-SPREAD      PIC S9(11)V99.
       01  WS-EXCESS-RATE        PIC 9V9(06).
       01  WS-SUB-SVC-RATE       PIC 9V9(06) VALUE 0.000600.
       01  WS-SUB-SVC-FEE        PIC S9(09)V99.
       01  WS-TOTAL-GROSS        PIC S9(13)V99 VALUE 0.
       01  WS-TOTAL-NET          PIC S9(13)V99 VALUE 0.
       01  WS-TOTAL-EXCESS       PIC S9(13)V99 VALUE 0.
       01  WS-TOTAL-ANCILLARY    PIC S9(13)V99 VALUE 0.
       01  WS-TOTAL-UPB          PIC S9(15)V99 VALUE 0.
       01  WS-POOL-CNT           PIC 9(06) VALUE 0.
       01  WS-DELINQ-COST        PIC S9(11)V99.
       01  WS-DELINQ-COST-RATE   PIC 9V9(06) VALUE 0.001200.
       01  WS-NET-INCOME         PIC S9(11)V99.
       01  WS-TOTAL-NET-INCOME   PIC S9(13)V99 VALUE 0.
       01  WS-MARGIN-PCT         PIC S9(03)V99.
       01  WS-IDX                PIC 9(02).
       01  WS-POOL-TIER          PIC X(10).
       01  WS-MSG                PIC X(80) VALUE SPACES.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PROCESS-POOLS UNTIL END-OF-FILE
           PERFORM 9000-FINALIZE
           STOP RUN.
       1000-INITIALIZE.
           OPEN INPUT POOL-FILE
           IF WS-POOL-STATUS NOT = '00'
               DISPLAY 'POOL FILE ERROR: ' WS-POOL-STATUS
               STOP RUN
           END-IF
           PERFORM 1100-READ-POOL.
       1100-READ-POOL.
           READ POOL-FILE
               AT END SET END-OF-FILE TO TRUE
           END-READ.
       2000-PROCESS-POOLS.
           ADD 1 TO WS-POOL-CNT
           ADD PR-UPB TO WS-TOTAL-UPB
           PERFORM 3000-CALC-SVC-FEES
           PERFORM 3500-CALC-EXCESS
           PERFORM 4000-CALC-DELINQ-COST
           PERFORM 5000-CALC-NET-INCOME
           PERFORM 6000-CLASSIFY-POOL
           PERFORM 1100-READ-POOL.
       3000-CALC-SVC-FEES.
           COMPUTE WS-GROSS-SVC-FEE ROUNDED =
               PR-UPB * PR-SERVICING-RATE / 12
           COMPUTE WS-GUARANT-FEE-AMT ROUNDED =
               PR-UPB * PR-GUARANT-FEE / 12
           COMPUTE WS-SUB-SVC-FEE ROUNDED =
               PR-UPB * WS-SUB-SVC-RATE / 12
           COMPUTE WS-NET-SVC-FEE =
               WS-GROSS-SVC-FEE - WS-SUB-SVC-FEE
           ADD WS-GROSS-SVC-FEE TO WS-TOTAL-GROSS
           ADD WS-NET-SVC-FEE TO WS-TOTAL-NET.
       3500-CALC-EXCESS.
           COMPUTE WS-EXCESS-RATE =
               PR-WAC - PR-NET-RATE -
               PR-SERVICING-RATE - PR-GUARANT-FEE
           IF WS-EXCESS-RATE > ZERO
               COMPUTE WS-EXCESS-SPREAD ROUNDED =
                   PR-UPB * WS-EXCESS-RATE / 12
           ELSE
               MOVE ZERO TO WS-EXCESS-SPREAD
           END-IF
           ADD WS-EXCESS-SPREAD TO WS-TOTAL-EXCESS.
       4000-CALC-DELINQ-COST.
           COMPUTE WS-DELINQ-COST ROUNDED =
               PR-UPB * WS-DELINQ-COST-RATE *
               PR-DELINQ-PCT / 100 / 12.
       5000-CALC-NET-INCOME.
           COMPUTE WS-NET-INCOME =
               WS-NET-SVC-FEE + WS-EXCESS-SPREAD +
               PR-ANCILLARY-REV - WS-DELINQ-COST
           ADD PR-ANCILLARY-REV TO WS-TOTAL-ANCILLARY
           ADD WS-NET-INCOME TO WS-TOTAL-NET-INCOME
           IF WS-GROSS-SVC-FEE > ZERO
               COMPUTE WS-MARGIN-PCT ROUNDED =
                   (WS-NET-INCOME / WS-GROSS-SVC-FEE)
                   * 100
           ELSE
               MOVE ZERO TO WS-MARGIN-PCT
           END-IF.
       6000-CLASSIFY-POOL.
           EVALUATE TRUE
               WHEN PR-DELINQ-PCT < 3.00
                   MOVE 'PERFORMING' TO WS-POOL-TIER
               WHEN PR-DELINQ-PCT < 8.00
                   MOVE 'WATCH' TO WS-POOL-TIER
               WHEN PR-DELINQ-PCT < 15.00
                   MOVE 'STRESSED' TO WS-POOL-TIER
               WHEN OTHER
                   MOVE 'DISTRESSED' TO WS-POOL-TIER
           END-EVALUATE
           IF WS-POOL-TIER = 'DISTRESSED'
               MOVE SPACES TO WS-MSG
               STRING 'ALERT: POOL '
                   DELIMITED BY SIZE
                   PR-POOL-ID
                   DELIMITED BY SIZE
                   ' DISTRESSED DQ='
                   DELIMITED BY SIZE
                   INTO WS-MSG
               DISPLAY WS-MSG PR-DELINQ-PCT '%'
           END-IF.
       9000-FINALIZE.
           CLOSE POOL-FILE
           DISPLAY 'SERVICING FEE ANALYSIS COMPLETE'
           DISPLAY 'POOLS:       ' WS-POOL-CNT
           DISPLAY 'TOTAL UPB:   ' WS-TOTAL-UPB
           DISPLAY 'GROSS SVC:   ' WS-TOTAL-GROSS
           DISPLAY 'NET SVC:     ' WS-TOTAL-NET
           DISPLAY 'EXCESS:      ' WS-TOTAL-EXCESS
           DISPLAY 'ANCILLARY:   ' WS-TOTAL-ANCILLARY
           DISPLAY 'NET INCOME:  ' WS-TOTAL-NET-INCOME.
