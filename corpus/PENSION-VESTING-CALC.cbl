       IDENTIFICATION DIVISION.
       PROGRAM-ID. PENSION-VESTING-CALC.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01 WS-EMPLOYEE-DATA.
           05 WS-EMP-ID               PIC X(10).
           05 WS-EMP-NAME             PIC X(30).
           05 WS-HIRE-DATE            PIC 9(8).
           05 WS-TERM-DATE            PIC 9(8).
           05 WS-YEARS-SERVICE        PIC 9(2).
           05 WS-PLAN-TYPE            PIC X(1).
               88 WS-CLIFF-VEST       VALUE 'C'.
               88 WS-GRADED-VEST      VALUE 'G'.
               88 WS-IMMEDIATE-VEST   VALUE 'I'.

       01 WS-VESTING-SCHEDULE.
           05 WS-VEST-TIER OCCURS 7.
               10 WS-VEST-YEAR        PIC 9(2).
               10 WS-VEST-PCT         PIC S9(3)V99 COMP-3.

       01 WS-VEST-IDX                 PIC 9(1).

       01 WS-ACCOUNT-BALANCES.
           05 WS-EMPLOYEE-CONTRIB     PIC S9(11)V99 COMP-3.
           05 WS-EMPLOYER-CONTRIB     PIC S9(11)V99 COMP-3.
           05 WS-INVESTMENT-GAIN      PIC S9(11)V99 COMP-3.
           05 WS-TOTAL-BALANCE        PIC S9(11)V99 COMP-3.

       01 WS-VESTED-AMOUNTS.
           05 WS-VEST-PCT-APPLIED     PIC S9(3)V99 COMP-3.
           05 WS-VESTED-EMPLOYER      PIC S9(11)V99 COMP-3.
           05 WS-VESTED-TOTAL         PIC S9(11)V99 COMP-3.
           05 WS-FORFEITED-AMT        PIC S9(11)V99 COMP-3.

       01 WS-BREAK-YEARS              PIC 9(2) VALUE 0.
       01 WS-ADJUSTED-SERVICE         PIC 9(2).
       01 WS-BREAK-THRESHOLD          PIC 9(2) VALUE 5.

       01 WS-RESULT-MSG               PIC X(60).
       01 WS-RESULT-PTR               PIC 9(3).
       01 WS-SPACE-TALLY              PIC 9(3).
       01 WS-LOOP-IDX                 PIC 9(2).

       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INIT-SCHEDULES
           PERFORM 2000-CALC-SERVICE-YEARS
           PERFORM 3000-DETERMINE-VESTING
           PERFORM 4000-CALC-VESTED-AMOUNTS
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.

       1000-INIT-SCHEDULES.
           MOVE 1 TO WS-VEST-YEAR(1)
           MOVE 0 TO WS-VEST-PCT(1)
           MOVE 2 TO WS-VEST-YEAR(2)
           MOVE 20.00 TO WS-VEST-PCT(2)
           MOVE 3 TO WS-VEST-YEAR(3)
           MOVE 40.00 TO WS-VEST-PCT(3)
           MOVE 4 TO WS-VEST-YEAR(4)
           MOVE 60.00 TO WS-VEST-PCT(4)
           MOVE 5 TO WS-VEST-YEAR(5)
           MOVE 80.00 TO WS-VEST-PCT(5)
           MOVE 6 TO WS-VEST-YEAR(6)
           MOVE 100.00 TO WS-VEST-PCT(6)
           MOVE 7 TO WS-VEST-YEAR(7)
           MOVE 100.00 TO WS-VEST-PCT(7)
           MOVE 0 TO WS-VEST-PCT-APPLIED
           MOVE 0 TO WS-VESTED-EMPLOYER
           MOVE 0 TO WS-VESTED-TOTAL
           MOVE 0 TO WS-FORFEITED-AMT.

       2000-CALC-SERVICE-YEARS.
           IF WS-BREAK-YEARS > WS-BREAK-THRESHOLD
               MOVE 0 TO WS-ADJUSTED-SERVICE
           ELSE
               IF WS-BREAK-YEARS > 0
                   SUBTRACT WS-BREAK-YEARS FROM
                       WS-YEARS-SERVICE
                       GIVING WS-ADJUSTED-SERVICE
                   IF WS-ADJUSTED-SERVICE < 0
                       MOVE 0 TO WS-ADJUSTED-SERVICE
                   END-IF
               ELSE
                   MOVE WS-YEARS-SERVICE TO
                       WS-ADJUSTED-SERVICE
               END-IF
           END-IF.

       3000-DETERMINE-VESTING.
           EVALUATE TRUE
               WHEN WS-IMMEDIATE-VEST
                   MOVE 100.00 TO WS-VEST-PCT-APPLIED
               WHEN WS-CLIFF-VEST
                   IF WS-ADJUSTED-SERVICE >= 3
                       MOVE 100.00 TO WS-VEST-PCT-APPLIED
                   ELSE
                       MOVE 0 TO WS-VEST-PCT-APPLIED
                   END-IF
               WHEN WS-GRADED-VEST
                   PERFORM 3100-GRADED-LOOKUP
               WHEN OTHER
                   MOVE 0 TO WS-VEST-PCT-APPLIED
                   DISPLAY 'UNKNOWN PLAN TYPE: '
                       WS-PLAN-TYPE
           END-EVALUATE.

       3100-GRADED-LOOKUP.
           MOVE 0 TO WS-VEST-PCT-APPLIED
           PERFORM VARYING WS-VEST-IDX FROM 7 BY -1
               UNTIL WS-VEST-IDX < 1
               IF WS-ADJUSTED-SERVICE >=
                   WS-VEST-YEAR(WS-VEST-IDX)
                   IF WS-VEST-PCT(WS-VEST-IDX) >
                       WS-VEST-PCT-APPLIED
                       MOVE WS-VEST-PCT(WS-VEST-IDX)
                           TO WS-VEST-PCT-APPLIED
                   END-IF
               END-IF
           END-PERFORM.

       4000-CALC-VESTED-AMOUNTS.
           COMPUTE WS-TOTAL-BALANCE =
               WS-EMPLOYEE-CONTRIB + WS-EMPLOYER-CONTRIB
               + WS-INVESTMENT-GAIN
           COMPUTE WS-VESTED-EMPLOYER =
               WS-EMPLOYER-CONTRIB *
               (WS-VEST-PCT-APPLIED / 100)
           COMPUTE WS-VESTED-TOTAL =
               WS-EMPLOYEE-CONTRIB +
               WS-VESTED-EMPLOYER +
               WS-INVESTMENT-GAIN
           COMPUTE WS-FORFEITED-AMT =
               WS-EMPLOYER-CONTRIB - WS-VESTED-EMPLOYER
           MOVE 0 TO WS-SPACE-TALLY
           INSPECT WS-EMP-NAME
               TALLYING WS-SPACE-TALLY FOR ALL ' '.

       5000-DISPLAY-RESULTS.
           MOVE SPACES TO WS-RESULT-MSG
           MOVE 1 TO WS-RESULT-PTR
           IF WS-VEST-PCT-APPLIED >= 100.00
               STRING 'FULLY VESTED - '
                   WS-EMP-NAME
                   DELIMITED BY SIZE
                   INTO WS-RESULT-MSG
                   WITH POINTER WS-RESULT-PTR
               END-STRING
           ELSE
               STRING 'PARTIALLY VESTED AT '
                   WS-VEST-PCT-APPLIED '% - '
                   WS-EMP-NAME
                   DELIMITED BY SIZE
                   INTO WS-RESULT-MSG
                   WITH POINTER WS-RESULT-PTR
               END-STRING
           END-IF
           DISPLAY WS-RESULT-MSG
           DISPLAY 'EMPLOYEE ID:      ' WS-EMP-ID
           DISPLAY 'SERVICE YEARS:    ' WS-ADJUSTED-SERVICE
           DISPLAY 'VESTING PCT:      ' WS-VEST-PCT-APPLIED
           DISPLAY 'TOTAL BALANCE:    ' WS-TOTAL-BALANCE
           DISPLAY 'VESTED TOTAL:     ' WS-VESTED-TOTAL
           DISPLAY 'FORFEITED:        ' WS-FORFEITED-AMT.
