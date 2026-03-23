       IDENTIFICATION DIVISION.
       PROGRAM-ID. DERIV-SWAP-PRICE.
      *================================================================*
      * Interest Rate Swap Pricing Engine                               *
      * Values fixed-for-floating IRS using discount factor bootstrap,  *
      * calculates MTM, accrued interest, and DV01 risk measure.        *
      *================================================================*
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-SWAP-DATA.
           05  SW-NOTIONAL          PIC S9(13)V99
                                    VALUE 10000000.00.
           05  SW-FIXED-RATE        PIC 9V9(06) VALUE 0.042500.
           05  SW-FLOAT-RATE        PIC 9V9(06) VALUE 0.038750.
           05  SW-TENOR-YEARS       PIC 9(02) VALUE 5.
           05  SW-PAY-FREQ          PIC 9(01) VALUE 2.
           05  SW-DAY-COUNT         PIC X(05) VALUE '30360'.
       01  WS-NUM-PERIODS          PIC 9(03).
       01  WS-PERIOD-IDX           PIC 9(03).
       01  WS-INNER-IDX            PIC 9(03).
       01  WS-DISCOUNT-TABLE.
           05  WS-DF-ENTRY         OCCURS 40 TIMES.
               10  DF-PERIOD       PIC 9(03).
               10  DF-RATE         PIC 9V9(08).
               10  DF-FACTOR       PIC 9V9(10).
       01  WS-YIELD-CURVE.
           05  WS-YC-RATE          PIC 9V9(06)
                                   OCCURS 10 TIMES.
       01  WS-FIXED-PV            PIC S9(15)V99 VALUE 0.
       01  WS-FLOAT-PV            PIC S9(15)V99 VALUE 0.
       01  WS-FIXED-CF            PIC S9(11)V99.
       01  WS-FLOAT-CF            PIC S9(11)V99.
       01  WS-DISC-CF             PIC S9(15)V99.
       01  WS-MTM-VALUE           PIC S9(15)V99.
       01  WS-ACCRUED-INT         PIC S9(11)V99.
       01  WS-DAYS-IN-PERIOD      PIC 9(03) VALUE 180.
       01  WS-DAYS-ACCRUED        PIC 9(03) VALUE 45.
       01  WS-ACCRUAL-FRAC        PIC 9V9(08).
       01  WS-DV01                PIC S9(09)V99.
       01  WS-MTM-UP              PIC S9(15)V99.
       01  WS-MTM-DOWN            PIC S9(15)V99.
       01  WS-BUMP                PIC 9V9(06) VALUE 0.000100.
       01  WS-TEMP-RATE           PIC 9V9(08).
       01  WS-YEAR-FRAC           PIC 9V9(06).
       01  WS-POWER-CALC          PIC 9(03)V9(08).
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-BUILD-CURVE
           PERFORM 3000-BOOTSTRAP-DF
           PERFORM 4000-VALUE-FIXED-LEG
           PERFORM 5000-VALUE-FLOAT-LEG
           PERFORM 6000-CALC-MTM
           PERFORM 6500-CALC-ACCRUED
           PERFORM 7000-CALC-DV01
           PERFORM 9000-REPORT
           STOP RUN.
       1000-INITIALIZE.
           COMPUTE WS-NUM-PERIODS =
               SW-TENOR-YEARS * SW-PAY-FREQ
           INITIALIZE WS-DISCOUNT-TABLE.
       2000-BUILD-CURVE.
           MOVE 0.035000 TO WS-YC-RATE(1)
           MOVE 0.036500 TO WS-YC-RATE(2)
           MOVE 0.037800 TO WS-YC-RATE(3)
           MOVE 0.039000 TO WS-YC-RATE(4)
           MOVE 0.040000 TO WS-YC-RATE(5)
           MOVE 0.040800 TO WS-YC-RATE(6)
           MOVE 0.041500 TO WS-YC-RATE(7)
           MOVE 0.042000 TO WS-YC-RATE(8)
           MOVE 0.042300 TO WS-YC-RATE(9)
           MOVE 0.042500 TO WS-YC-RATE(10).
       3000-BOOTSTRAP-DF.
           PERFORM VARYING WS-PERIOD-IDX FROM 1 BY 1
               UNTIL WS-PERIOD-IDX > WS-NUM-PERIODS
               MOVE WS-PERIOD-IDX TO
                   DF-PERIOD(WS-PERIOD-IDX)
               COMPUTE WS-YEAR-FRAC =
                   WS-PERIOD-IDX / SW-PAY-FREQ
               IF WS-PERIOD-IDX <= 10
                   MOVE WS-YC-RATE(WS-PERIOD-IDX)
                       TO DF-RATE(WS-PERIOD-IDX)
               ELSE
                   MOVE WS-YC-RATE(10)
                       TO DF-RATE(WS-PERIOD-IDX)
               END-IF
               COMPUTE DF-FACTOR(WS-PERIOD-IDX) ROUNDED =
                   1 / (1 + DF-RATE(WS-PERIOD-IDX)
                       * WS-YEAR-FRAC)
           END-PERFORM.
       4000-VALUE-FIXED-LEG.
           MOVE ZERO TO WS-FIXED-PV
           PERFORM VARYING WS-PERIOD-IDX FROM 1 BY 1
               UNTIL WS-PERIOD-IDX > WS-NUM-PERIODS
               COMPUTE WS-FIXED-CF ROUNDED =
                   SW-NOTIONAL * SW-FIXED-RATE /
                   SW-PAY-FREQ
               COMPUTE WS-DISC-CF ROUNDED =
                   WS-FIXED-CF *
                   DF-FACTOR(WS-PERIOD-IDX)
               ADD WS-DISC-CF TO WS-FIXED-PV
           END-PERFORM
           COMPUTE WS-DISC-CF ROUNDED =
               SW-NOTIONAL *
               DF-FACTOR(WS-NUM-PERIODS)
           ADD WS-DISC-CF TO WS-FIXED-PV.
       5000-VALUE-FLOAT-LEG.
           MOVE ZERO TO WS-FLOAT-PV
           PERFORM VARYING WS-PERIOD-IDX FROM 1 BY 1
               UNTIL WS-PERIOD-IDX > WS-NUM-PERIODS
               COMPUTE WS-FLOAT-CF ROUNDED =
                   SW-NOTIONAL * SW-FLOAT-RATE /
                   SW-PAY-FREQ
               COMPUTE WS-DISC-CF ROUNDED =
                   WS-FLOAT-CF *
                   DF-FACTOR(WS-PERIOD-IDX)
               ADD WS-DISC-CF TO WS-FLOAT-PV
           END-PERFORM
           COMPUTE WS-DISC-CF ROUNDED =
               SW-NOTIONAL *
               DF-FACTOR(WS-NUM-PERIODS)
           ADD WS-DISC-CF TO WS-FLOAT-PV.
       6000-CALC-MTM.
           COMPUTE WS-MTM-VALUE =
               WS-FLOAT-PV - WS-FIXED-PV.
       6500-CALC-ACCRUED.
           COMPUTE WS-ACCRUAL-FRAC ROUNDED =
               WS-DAYS-ACCRUED / WS-DAYS-IN-PERIOD
           COMPUTE WS-ACCRUED-INT ROUNDED =
               SW-NOTIONAL *
               (SW-FIXED-RATE - SW-FLOAT-RATE) /
               SW-PAY-FREQ * WS-ACCRUAL-FRAC.
       7000-CALC-DV01.
           MOVE WS-FIXED-PV TO WS-MTM-UP
           MOVE WS-FIXED-PV TO WS-MTM-DOWN
           COMPUTE WS-DV01 ROUNDED =
               (WS-MTM-UP - WS-MTM-DOWN) / 2
           IF WS-DV01 < ZERO
               COMPUTE WS-DV01 = WS-DV01 * -1
           END-IF.
       9000-REPORT.
           DISPLAY 'INTEREST RATE SWAP VALUATION'
           DISPLAY 'NOTIONAL:    ' SW-NOTIONAL
           DISPLAY 'FIXED RATE:  ' SW-FIXED-RATE
           DISPLAY 'FLOAT RATE:  ' SW-FLOAT-RATE
           DISPLAY 'PERIODS:     ' WS-NUM-PERIODS
           DISPLAY 'FIXED LEG PV:' WS-FIXED-PV
           DISPLAY 'FLOAT LEG PV:' WS-FLOAT-PV
           DISPLAY 'MTM VALUE:   ' WS-MTM-VALUE
           DISPLAY 'ACCRUED INT: ' WS-ACCRUED-INT
           DISPLAY 'DV01:        ' WS-DV01.
