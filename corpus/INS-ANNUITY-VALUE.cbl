       IDENTIFICATION DIVISION.
       PROGRAM-ID. INS-ANNUITY-VALUE.
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ANNUITY-DATA.
           05 WS-POLICY-NUM          PIC X(12).
           05 WS-MONTHLY-PMT         PIC S9(7)V99 COMP-3.
           05 WS-ANNUAL-RATE         PIC S9(3)V9(6) COMP-3.
           05 WS-YEARS                PIC 9(2).
       01 WS-CALC-FIELDS.
           05 WS-MONTHLY-RATE        PIC S9(1)V9(8) COMP-3.
           05 WS-PERIODS             PIC 9(3).
           05 WS-PV-FACTOR           PIC S9(3)V9(10) COMP-3.
           05 WS-PRESENT-VALUE       PIC S9(11)V99 COMP-3.
           05 WS-FUTURE-VALUE        PIC S9(11)V99 COMP-3.
           05 WS-TOTAL-PMTS          PIC S9(11)V99 COMP-3.
       01 WS-ANNUITY-TYPE            PIC X(1).
           88 WS-ORDINARY            VALUE 'O'.
           88 WS-DUE                 VALUE 'D'.
       01 WS-PERIOD-IDX              PIC 9(3).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-PV
           PERFORM 3000-CALC-FV
           PERFORM 4000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 5,25 TO WS-ANNUAL-RATE
           COMPUTE WS-MONTHLY-RATE =
               WS-ANNUAL-RATE / 12
           COMPUTE WS-PERIODS = WS-YEARS * 12
           MOVE 0 TO WS-PRESENT-VALUE
           MOVE 0 TO WS-FUTURE-VALUE.
       2000-CALC-PV.
           MOVE 0 TO WS-PRESENT-VALUE
           PERFORM VARYING WS-PERIOD-IDX FROM 1 BY 1
               UNTIL WS-PERIOD-IDX > WS-PERIODS
               COMPUTE WS-PV-FACTOR =
                   1 / ((1 + WS-MONTHLY-RATE) **
                   WS-PERIOD-IDX)
               COMPUTE WS-PRESENT-VALUE =
                   WS-PRESENT-VALUE +
                   (WS-MONTHLY-PMT * WS-PV-FACTOR)
           END-PERFORM
           IF WS-DUE
               COMPUTE WS-PRESENT-VALUE =
                   WS-PRESENT-VALUE * (1 + WS-MONTHLY-RATE)
           END-IF.
       3000-CALC-FV.
           COMPUTE WS-TOTAL-PMTS =
               WS-MONTHLY-PMT * WS-PERIODS
           COMPUTE WS-FUTURE-VALUE =
               WS-TOTAL-PMTS +
               (WS-PRESENT-VALUE *
               ((1 + WS-MONTHLY-RATE) ** WS-PERIODS - 1)).
       4000-DISPLAY-RESULTS.
           DISPLAY 'ANNUITY VALUE CALCULATION'
           DISPLAY '========================='
           DISPLAY 'POLICY:       ' WS-POLICY-NUM
           DISPLAY 'MONTHLY PMT:  ' WS-MONTHLY-PMT
           DISPLAY 'ANNUAL RATE:  ' WS-ANNUAL-RATE
           DISPLAY 'YEARS:        ' WS-YEARS
           DISPLAY 'PRESENT VALUE:' WS-PRESENT-VALUE
           DISPLAY 'FUTURE VALUE: ' WS-FUTURE-VALUE
           DISPLAY 'TOTAL PMTS:   ' WS-TOTAL-PMTS
           IF WS-ORDINARY
               DISPLAY 'TYPE: ORDINARY ANNUITY'
           ELSE
               DISPLAY 'TYPE: ANNUITY DUE'
           END-IF.
