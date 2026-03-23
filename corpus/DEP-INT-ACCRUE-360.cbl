       IDENTIFICATION DIVISION.
       PROGRAM-ID. DEP-INT-ACCRUE-360.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ACCT-NUM                PIC X(12).
       01 WS-BALANCE                 PIC S9(9)V99 COMP-3.
       01 WS-ANNUAL-RATE             PIC S9(1)V9(6) COMP-3.
       01 WS-DAILY-RATE              PIC S9(1)V9(10) COMP-3.
       01 WS-ACCRUAL-DAYS            PIC 9(3).
       01 WS-DAILY-INT               PIC S9(5)V99 COMP-3.
       01 WS-TOTAL-ACCRUED           PIC S9(7)V99 COMP-3.
       01 WS-DAY-IDX                 PIC 9(3).
       01 WS-RUNNING-BAL             PIC S9(9)V99 COMP-3.
       01 WS-ACCRUAL-METHOD          PIC X(1).
           88 WS-SIMPLE              VALUE 'S'.
           88 WS-COMPOUND            VALUE 'C'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-ACCRUE-INTEREST
           PERFORM 3000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-ACCRUED
           MOVE WS-BALANCE TO WS-RUNNING-BAL
           COMPUTE WS-DAILY-RATE = WS-ANNUAL-RATE / 360
           COMPUTE WS-DAILY-INT =
               WS-BALANCE * WS-DAILY-RATE.
       2000-ACCRUE-INTEREST.
           PERFORM VARYING WS-DAY-IDX FROM 1 BY 1
               UNTIL WS-DAY-IDX > WS-ACCRUAL-DAYS
               IF WS-COMPOUND
                   COMPUTE WS-DAILY-INT =
                       WS-RUNNING-BAL * WS-DAILY-RATE
                   ADD WS-DAILY-INT TO WS-RUNNING-BAL
               END-IF
               ADD WS-DAILY-INT TO WS-TOTAL-ACCRUED
           END-PERFORM.
       3000-DISPLAY-RESULTS.
           DISPLAY 'INTEREST ACCRUAL 30/360'
           DISPLAY '======================='
           DISPLAY 'ACCOUNT:      ' WS-ACCT-NUM
           DISPLAY 'BALANCE:      ' WS-BALANCE
           DISPLAY 'RATE:         ' WS-ANNUAL-RATE
           DISPLAY 'DAYS:         ' WS-ACCRUAL-DAYS
           DISPLAY 'TOTAL ACCRUED:' WS-TOTAL-ACCRUED.
