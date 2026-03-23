       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-ODO-PAYROLL-RUN.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-COMPANY-ID          PIC X(8).
       01 WS-PAY-PERIOD-END      PIC 9(8).
       01 WS-EMP-COUNT           PIC 9(4).
       01 WS-EMPLOYEE-TABLE.
           05 WS-EMP OCCURS 1 TO 500 TIMES
               DEPENDING ON WS-EMP-COUNT.
               10 WS-EMP-ID      PIC X(8).
               10 WS-EMP-NAME    PIC X(25).
               10 WS-EMP-HOURS   PIC 9(3)V9.
               10 WS-EMP-RATE    PIC S9(3)V99 COMP-3.
               10 WS-EMP-OT-HRS  PIC 9(2)V9.
               10 WS-EMP-GROSS   PIC S9(7)V99 COMP-3.
               10 WS-EMP-NET     PIC S9(7)V99 COMP-3.
               10 WS-EMP-TYPE    PIC X(1).
                   88 HOURLY     VALUE 'H'.
                   88 SALARIED   VALUE 'S'.
       01 WS-IDX                 PIC 9(4).
       01 WS-REG-PAY             PIC S9(7)V99 COMP-3.
       01 WS-OT-PAY              PIC S9(7)V99 COMP-3.
       01 WS-OT-RATE             PIC S9(3)V99 COMP-3.
       01 WS-DEDUCTIONS          PIC S9(5)V99 COMP-3.
       01 WS-TOTAL-GROSS         PIC S9(9)V99 COMP-3.
       01 WS-TOTAL-NET           PIC S9(9)V99 COMP-3.
       01 WS-TOTAL-OT            PIC S9(7)V99 COMP-3.
       01 WS-HOURLY-COUNT        PIC 9(4).
       01 WS-SALARY-COUNT        PIC 9(4).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-CALC-PAYROLL
           PERFORM 3000-SUMMARY
           STOP RUN.
       1000-INIT.
           MOVE 0 TO WS-TOTAL-GROSS
           MOVE 0 TO WS-TOTAL-NET
           MOVE 0 TO WS-TOTAL-OT
           MOVE 0 TO WS-HOURLY-COUNT
           MOVE 0 TO WS-SALARY-COUNT
           ACCEPT WS-PAY-PERIOD-END FROM DATE YYYYMMDD.
       2000-CALC-PAYROLL.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-EMP-COUNT
               PERFORM 2100-CALC-EMPLOYEE
           END-PERFORM.
       2100-CALC-EMPLOYEE.
           IF HOURLY(WS-IDX)
               ADD 1 TO WS-HOURLY-COUNT
               COMPUTE WS-REG-PAY =
                   WS-EMP-HOURS(WS-IDX) *
                   WS-EMP-RATE(WS-IDX)
               COMPUTE WS-OT-RATE =
                   WS-EMP-RATE(WS-IDX) * 1.5
               COMPUTE WS-OT-PAY =
                   WS-EMP-OT-HRS(WS-IDX) * WS-OT-RATE
               COMPUTE WS-EMP-GROSS(WS-IDX) =
                   WS-REG-PAY + WS-OT-PAY
               ADD WS-OT-PAY TO WS-TOTAL-OT
           ELSE
               ADD 1 TO WS-SALARY-COUNT
               MOVE WS-EMP-RATE(WS-IDX) TO
                   WS-EMP-GROSS(WS-IDX)
           END-IF
           COMPUTE WS-DEDUCTIONS =
               WS-EMP-GROSS(WS-IDX) * 0.28
           COMPUTE WS-EMP-NET(WS-IDX) =
               WS-EMP-GROSS(WS-IDX) - WS-DEDUCTIONS
           ADD WS-EMP-GROSS(WS-IDX) TO WS-TOTAL-GROSS
           ADD WS-EMP-NET(WS-IDX) TO WS-TOTAL-NET.
       3000-SUMMARY.
           DISPLAY 'PAYROLL RUN SUMMARY'
           DISPLAY '==================='
           DISPLAY 'COMPANY:  ' WS-COMPANY-ID
           DISPLAY 'PAY DATE: ' WS-PAY-PERIOD-END
           DISPLAY 'EMPLOYEES:' WS-EMP-COUNT
           DISPLAY 'HOURLY:   ' WS-HOURLY-COUNT
           DISPLAY 'SALARIED: ' WS-SALARY-COUNT
           DISPLAY 'GROSS:    $' WS-TOTAL-GROSS
           DISPLAY 'NET:      $' WS-TOTAL-NET
           DISPLAY 'OVERTIME: $' WS-TOTAL-OT.
