       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOAN-COLLATERAL-VAL.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-COLLATERAL.
           05 WS-COLL-ID          PIC X(12).
           05 WS-COLL-TYPE        PIC X(2).
               88 COLL-REAL-ESTATE VALUE 'RE'.
               88 COLL-VEHICLE    VALUE 'VH'.
               88 COLL-SECURITIES VALUE 'SC'.
               88 COLL-EQUIPMENT  VALUE 'EQ'.
               88 COLL-DEPOSIT    VALUE 'DP'.
           05 WS-ORIG-VALUE       PIC S9(11)V99 COMP-3.
           05 WS-APPRAISAL-DATE   PIC 9(8).
           05 WS-DEPREC-RATE      PIC S9(1)V9(4) COMP-3.
           05 WS-MARKET-FACTOR    PIC S9(1)V9(4) COMP-3.
       01 WS-LOAN-DATA.
           05 WS-LOAN-NUM         PIC X(12).
           05 WS-LOAN-BALANCE     PIC S9(11)V99 COMP-3.
           05 WS-LOAN-LIMIT       PIC S9(11)V99 COMP-3.
       01 WS-VALUATION.
           05 WS-CURRENT-VALUE    PIC S9(11)V99 COMP-3.
           05 WS-HAIRCUT-PCT      PIC S9(1)V99 COMP-3.
           05 WS-LENDING-VALUE    PIC S9(11)V99 COMP-3.
           05 WS-LTV-RATIO        PIC S9(3)V99 COMP-3.
           05 WS-COVERAGE-RATIO   PIC S9(3)V99 COMP-3.
       01 WS-CURRENT-DATE         PIC 9(8).
       01 WS-MONTHS-ELAPSED       PIC 9(3).
       01 WS-DEPREC-AMOUNT        PIC S9(11)V99 COMP-3.
       01 WS-STATUS               PIC X(15).
       01 WS-ACTION                PIC X(30).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-CALC-CURRENT-VALUE
           PERFORM 3000-APPLY-HAIRCUT
           PERFORM 4000-CALC-RATIOS
           PERFORM 5000-DETERMINE-STATUS
           PERFORM 6000-OUTPUT
           STOP RUN.
       1000-INIT.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           COMPUTE WS-MONTHS-ELAPSED =
               (WS-CURRENT-DATE - WS-APPRAISAL-DATE) / 100.
       2000-CALC-CURRENT-VALUE.
           EVALUATE TRUE
               WHEN COLL-REAL-ESTATE
                   COMPUTE WS-CURRENT-VALUE =
                       WS-ORIG-VALUE * WS-MARKET-FACTOR
               WHEN COLL-VEHICLE
                   COMPUTE WS-DEPREC-AMOUNT =
                       WS-ORIG-VALUE * WS-DEPREC-RATE *
                       WS-MONTHS-ELAPSED
                   COMPUTE WS-CURRENT-VALUE =
                       WS-ORIG-VALUE - WS-DEPREC-AMOUNT
                   IF WS-CURRENT-VALUE < 0
                       MOVE 0 TO WS-CURRENT-VALUE
                   END-IF
               WHEN COLL-SECURITIES
                   COMPUTE WS-CURRENT-VALUE =
                       WS-ORIG-VALUE * WS-MARKET-FACTOR
               WHEN COLL-EQUIPMENT
                   COMPUTE WS-DEPREC-AMOUNT =
                       WS-ORIG-VALUE * WS-DEPREC-RATE *
                       WS-MONTHS-ELAPSED
                   COMPUTE WS-CURRENT-VALUE =
                       WS-ORIG-VALUE - WS-DEPREC-AMOUNT
                   IF WS-CURRENT-VALUE <
                       WS-ORIG-VALUE * 0.10
                       COMPUTE WS-CURRENT-VALUE =
                           WS-ORIG-VALUE * 0.10
                   END-IF
               WHEN COLL-DEPOSIT
                   MOVE WS-ORIG-VALUE TO WS-CURRENT-VALUE
               WHEN OTHER
                   MOVE 0 TO WS-CURRENT-VALUE
           END-EVALUATE.
       3000-APPLY-HAIRCUT.
           EVALUATE TRUE
               WHEN COLL-REAL-ESTATE
                   MOVE 0.80 TO WS-HAIRCUT-PCT
               WHEN COLL-VEHICLE
                   MOVE 0.70 TO WS-HAIRCUT-PCT
               WHEN COLL-SECURITIES
                   MOVE 0.75 TO WS-HAIRCUT-PCT
               WHEN COLL-EQUIPMENT
                   MOVE 0.60 TO WS-HAIRCUT-PCT
               WHEN COLL-DEPOSIT
                   MOVE 0.95 TO WS-HAIRCUT-PCT
               WHEN OTHER
                   MOVE 0.50 TO WS-HAIRCUT-PCT
           END-EVALUATE
           COMPUTE WS-LENDING-VALUE =
               WS-CURRENT-VALUE * WS-HAIRCUT-PCT.
       4000-CALC-RATIOS.
           IF WS-LENDING-VALUE > 0
               COMPUTE WS-LTV-RATIO =
                   (WS-LOAN-BALANCE / WS-LENDING-VALUE) * 100
           ELSE
               MOVE 999.99 TO WS-LTV-RATIO
           END-IF
           IF WS-LOAN-BALANCE > 0
               COMPUTE WS-COVERAGE-RATIO =
                   WS-LENDING-VALUE / WS-LOAN-BALANCE
           ELSE
               MOVE 0 TO WS-COVERAGE-RATIO
           END-IF.
       5000-DETERMINE-STATUS.
           IF WS-LTV-RATIO <= 80
               MOVE 'ADEQUATE       ' TO WS-STATUS
               MOVE SPACES TO WS-ACTION
           ELSE
               IF WS-LTV-RATIO <= 100
                   MOVE 'MARGINAL       ' TO WS-STATUS
                   MOVE 'MONITOR QUARTERLY'
                       TO WS-ACTION
               ELSE
                   IF WS-LTV-RATIO <= 120
                       MOVE 'DEFICIENT      ' TO WS-STATUS
                       MOVE 'REQUEST ADDITIONAL COLL'
                           TO WS-ACTION
                   ELSE
                       MOVE 'CRITICAL       ' TO WS-STATUS
                       MOVE 'IMMEDIATE COLL CALL'
                           TO WS-ACTION
                   END-IF
               END-IF
           END-IF.
       6000-OUTPUT.
           DISPLAY 'COLLATERAL VALUATION REPORT'
           DISPLAY '==========================='
           DISPLAY 'COLLATERAL: ' WS-COLL-ID
           DISPLAY 'TYPE:       ' WS-COLL-TYPE
           DISPLAY 'ORIG VALUE: $' WS-ORIG-VALUE
           DISPLAY 'CURR VALUE: $' WS-CURRENT-VALUE
           DISPLAY 'LEND VALUE: $' WS-LENDING-VALUE
           DISPLAY 'HAIRCUT:    ' WS-HAIRCUT-PCT
           DISPLAY 'LOAN BAL:   $' WS-LOAN-BALANCE
           DISPLAY 'LTV RATIO:  ' WS-LTV-RATIO
           DISPLAY 'COVERAGE:   ' WS-COVERAGE-RATIO
           DISPLAY 'STATUS:     ' WS-STATUS
           IF WS-ACTION NOT = SPACES
               DISPLAY 'ACTION:     ' WS-ACTION
           END-IF.
