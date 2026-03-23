       IDENTIFICATION DIVISION.
       PROGRAM-ID. PAY-DIRECT-DEPOSIT.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-EMPLOYEE-TABLE.
           05 WS-EMPLOYEE OCCURS 40 TIMES.
               10 WS-EMP-ID       PIC X(8).
               10 WS-EMP-NAME     PIC X(25).
               10 WS-GROSS-PAY    PIC S9(7)V99 COMP-3.
               10 WS-FED-TAX      PIC S9(5)V99 COMP-3.
               10 WS-STATE-TAX    PIC S9(5)V99 COMP-3.
               10 WS-FICA         PIC S9(5)V99 COMP-3.
               10 WS-NET-PAY      PIC S9(7)V99 COMP-3.
               10 WS-ACCT-NUM     PIC X(12).
               10 WS-ROUTING-NUM  PIC X(9).
               10 WS-DD-STATUS    PIC X(1).
                   88 DD-ACTIVE   VALUE 'A'.
                   88 DD-HOLD     VALUE 'H'.
       01 WS-EMP-COUNT            PIC 99 VALUE 40.
       01 WS-IDX                  PIC 99.
       01 WS-TOTAL-GROSS          PIC S9(9)V99 COMP-3.
       01 WS-TOTAL-FED            PIC S9(9)V99 COMP-3.
       01 WS-TOTAL-STATE          PIC S9(9)V99 COMP-3.
       01 WS-TOTAL-FICA           PIC S9(9)V99 COMP-3.
       01 WS-TOTAL-NET            PIC S9(9)V99 COMP-3.
       01 WS-PROCESSED            PIC 99.
       01 WS-HELD                 PIC 99.
       01 WS-FED-RATE             PIC S9(1)V99 COMP-3.
       01 WS-STATE-RATE           PIC S9(1)V99 COMP-3
           VALUE 0.05.
       01 WS-FICA-RATE            PIC S9(1)V9(4) COMP-3
           VALUE 0.0765.
       01 WS-PAY-DATE             PIC 9(8).
       01 WS-BATCH-LINE           PIC X(80).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-CALC-PAYROLL
           PERFORM 3000-PROCESS-DEPOSITS
           PERFORM 4000-REPORT
           STOP RUN.
       1000-INIT.
           MOVE 0 TO WS-TOTAL-GROSS
           MOVE 0 TO WS-TOTAL-FED
           MOVE 0 TO WS-TOTAL-STATE
           MOVE 0 TO WS-TOTAL-FICA
           MOVE 0 TO WS-TOTAL-NET
           MOVE 0 TO WS-PROCESSED
           MOVE 0 TO WS-HELD
           ACCEPT WS-PAY-DATE FROM DATE YYYYMMDD.
       2000-CALC-PAYROLL.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-EMP-COUNT
               PERFORM 2100-CALC-EMPLOYEE
           END-PERFORM.
       2100-CALC-EMPLOYEE.
           IF WS-GROSS-PAY(WS-IDX) > 5000.00
               MOVE 0.22 TO WS-FED-RATE
           ELSE
               IF WS-GROSS-PAY(WS-IDX) > 3000.00
                   MOVE 0.15 TO WS-FED-RATE
               ELSE
                   MOVE 0.10 TO WS-FED-RATE
               END-IF
           END-IF
           COMPUTE WS-FED-TAX(WS-IDX) =
               WS-GROSS-PAY(WS-IDX) * WS-FED-RATE
           COMPUTE WS-STATE-TAX(WS-IDX) =
               WS-GROSS-PAY(WS-IDX) * WS-STATE-RATE
           COMPUTE WS-FICA(WS-IDX) =
               WS-GROSS-PAY(WS-IDX) * WS-FICA-RATE
           COMPUTE WS-NET-PAY(WS-IDX) =
               WS-GROSS-PAY(WS-IDX) -
               WS-FED-TAX(WS-IDX) -
               WS-STATE-TAX(WS-IDX) -
               WS-FICA(WS-IDX)
           ADD WS-GROSS-PAY(WS-IDX) TO WS-TOTAL-GROSS
           ADD WS-FED-TAX(WS-IDX) TO WS-TOTAL-FED
           ADD WS-STATE-TAX(WS-IDX) TO WS-TOTAL-STATE
           ADD WS-FICA(WS-IDX) TO WS-TOTAL-FICA.
       3000-PROCESS-DEPOSITS.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-EMP-COUNT
               IF DD-ACTIVE(WS-IDX)
                   ADD WS-NET-PAY(WS-IDX) TO WS-TOTAL-NET
                   ADD 1 TO WS-PROCESSED
               ELSE
                   ADD 1 TO WS-HELD
               END-IF
           END-PERFORM.
       4000-REPORT.
           DISPLAY 'DIRECT DEPOSIT BATCH REPORT'
           DISPLAY '==========================='
           DISPLAY 'PAY DATE:    ' WS-PAY-DATE
           DISPLAY 'EMPLOYEES:   ' WS-EMP-COUNT
           DISPLAY 'PROCESSED:   ' WS-PROCESSED
           DISPLAY 'HELD:        ' WS-HELD
           DISPLAY 'TOTAL GROSS: $' WS-TOTAL-GROSS
           DISPLAY 'FEDERAL TAX: $' WS-TOTAL-FED
           DISPLAY 'STATE TAX:   $' WS-TOTAL-STATE
           DISPLAY 'FICA:        $' WS-TOTAL-FICA
           DISPLAY 'TOTAL NET:   $' WS-TOTAL-NET.
