       IDENTIFICATION DIVISION.
       PROGRAM-ID. DEP-REG-D-MONITOR.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ACCT-NUM                PIC X(12).
       01 WS-MONTH-TXN-COUNT         PIC 9(3).
       01 WS-REG-D-LIMIT             PIC 9(2) VALUE 6.
       01 WS-EXCESS-COUNT             PIC 9(3).
       01 WS-EXCESS-FEE               PIC S9(5)V99 COMP-3
           VALUE 10.00.
       01 WS-TOTAL-FEES               PIC S9(5)V99 COMP-3.
       01 WS-REG-D-STATUS             PIC X(1).
           88 WS-COMPLIANT            VALUE 'C'.
           88 WS-WARNING              VALUE 'W'.
           88 WS-VIOLATION            VALUE 'V'.
       01 WS-CONSECUTIVE-VIOLATIONS   PIC 9(2).
       01 WS-TXN-IDX                  PIC 9(3).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CHECK-COMPLIANCE
           PERFORM 3000-CALC-FEES
           PERFORM 4000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-EXCESS-COUNT
           MOVE 0 TO WS-TOTAL-FEES
           SET WS-COMPLIANT TO TRUE.
       2000-CHECK-COMPLIANCE.
           IF WS-MONTH-TXN-COUNT > WS-REG-D-LIMIT
               COMPUTE WS-EXCESS-COUNT =
                   WS-MONTH-TXN-COUNT - WS-REG-D-LIMIT
               SET WS-VIOLATION TO TRUE
               ADD 1 TO WS-CONSECUTIVE-VIOLATIONS
           ELSE
               IF WS-MONTH-TXN-COUNT > 4
                   SET WS-WARNING TO TRUE
               ELSE
                   SET WS-COMPLIANT TO TRUE
               END-IF
           END-IF.
       3000-CALC-FEES.
           IF WS-VIOLATION
               PERFORM VARYING WS-TXN-IDX FROM 1 BY 1
                   UNTIL WS-TXN-IDX > WS-EXCESS-COUNT
                   ADD WS-EXCESS-FEE TO WS-TOTAL-FEES
               END-PERFORM
           END-IF.
       4000-DISPLAY-RESULTS.
           DISPLAY 'REG D MONITORING'
           DISPLAY '================'
           DISPLAY 'ACCOUNT:   ' WS-ACCT-NUM
           DISPLAY 'TXN COUNT: ' WS-MONTH-TXN-COUNT
           DISPLAY 'EXCESS:    ' WS-EXCESS-COUNT
           DISPLAY 'FEES:      ' WS-TOTAL-FEES
           IF WS-COMPLIANT
               DISPLAY 'STATUS: COMPLIANT'
           END-IF
           IF WS-WARNING
               DISPLAY 'STATUS: WARNING'
           END-IF
           IF WS-VIOLATION
               DISPLAY 'STATUS: VIOLATION'
           END-IF.
