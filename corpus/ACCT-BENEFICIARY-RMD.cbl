       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCT-BENEFICIARY-RMD.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-IRA-ACCOUNT.
           05 WS-IRA-NUM         PIC X(12).
           05 WS-IRA-BALANCE     PIC S9(11)V99 COMP-3.
           05 WS-OWNER-AGE       PIC 9(3).
           05 WS-OWNER-DOB       PIC 9(8).
           05 WS-IRA-TYPE        PIC X(1).
               88 IT-TRADITIONAL VALUE 'T'.
               88 IT-ROTH        VALUE 'R'.
               88 IT-SEP         VALUE 'S'.
       01 WS-LIFE-EXPECTANCY     PIC S9(2)V9 COMP-3.
       01 WS-RMD-AMOUNT          PIC S9(9)V99 COMP-3.
       01 WS-PRIOR-YEAR-BAL      PIC S9(11)V99 COMP-3.
       01 WS-RMD-REQUIRED        PIC X VALUE 'N'.
           88 MUST-TAKE-RMD     VALUE 'Y'.
       01 WS-RMD-AGE-THRESHOLD   PIC 9(3) VALUE 73.
       01 WS-PENALTY-AMT         PIC S9(7)V99 COMP-3.
       01 WS-PENALTY-RATE        PIC S9(1)V99 COMP-3
           VALUE 0.25.
       01 WS-YTD-DISTRIBUTED     PIC S9(9)V99 COMP-3.
       01 WS-REMAINING-RMD       PIC S9(9)V99 COMP-3.
       01 WS-RMD-STATUS          PIC X(12).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-CHECK-RMD-REQ
           IF MUST-TAKE-RMD
               PERFORM 2000-CALC-RMD
               PERFORM 3000-CHECK-COMPLIANCE
           END-IF
           PERFORM 4000-OUTPUT
           STOP RUN.
       1000-CHECK-RMD-REQ.
           IF IT-ROTH
               MOVE 'N' TO WS-RMD-REQUIRED
               MOVE 'EXEMPT-ROTH ' TO WS-RMD-STATUS
           ELSE
               IF WS-OWNER-AGE >= WS-RMD-AGE-THRESHOLD
                   MOVE 'Y' TO WS-RMD-REQUIRED
               ELSE
                   MOVE 'NOT-YET     ' TO WS-RMD-STATUS
               END-IF
           END-IF.
       2000-CALC-RMD.
           IF WS-OWNER-AGE <= 75
               MOVE 24.6 TO WS-LIFE-EXPECTANCY
           ELSE
               IF WS-OWNER-AGE <= 80
                   MOVE 20.2 TO WS-LIFE-EXPECTANCY
               ELSE
                   IF WS-OWNER-AGE <= 85
                       MOVE 16.0 TO WS-LIFE-EXPECTANCY
                   ELSE
                       IF WS-OWNER-AGE <= 90
                           MOVE 12.2 TO WS-LIFE-EXPECTANCY
                       ELSE
                           MOVE 8.6 TO WS-LIFE-EXPECTANCY
                       END-IF
                   END-IF
               END-IF
           END-IF
           IF WS-LIFE-EXPECTANCY > 0
               COMPUTE WS-RMD-AMOUNT =
                   WS-PRIOR-YEAR-BAL / WS-LIFE-EXPECTANCY
           ELSE
               MOVE WS-PRIOR-YEAR-BAL TO WS-RMD-AMOUNT
           END-IF.
       3000-CHECK-COMPLIANCE.
           COMPUTE WS-REMAINING-RMD =
               WS-RMD-AMOUNT - WS-YTD-DISTRIBUTED
           IF WS-REMAINING-RMD <= 0
               MOVE 'SATISFIED   ' TO WS-RMD-STATUS
               MOVE 0 TO WS-PENALTY-AMT
           ELSE
               MOVE 'PENDING     ' TO WS-RMD-STATUS
               COMPUTE WS-PENALTY-AMT =
                   WS-REMAINING-RMD * WS-PENALTY-RATE
           END-IF.
       4000-OUTPUT.
           DISPLAY 'REQUIRED MINIMUM DISTRIBUTION'
           DISPLAY '============================='
           DISPLAY 'IRA:        ' WS-IRA-NUM
           DISPLAY 'TYPE:       ' WS-IRA-TYPE
           DISPLAY 'AGE:        ' WS-OWNER-AGE
           DISPLAY 'BALANCE:    $' WS-IRA-BALANCE
           DISPLAY 'PRIOR YR:   $' WS-PRIOR-YEAR-BAL
           IF MUST-TAKE-RMD
               DISPLAY 'LIFE EXPECT:' WS-LIFE-EXPECTANCY
               DISPLAY 'RMD AMOUNT: $' WS-RMD-AMOUNT
               DISPLAY 'YTD DIST:   $' WS-YTD-DISTRIBUTED
               DISPLAY 'REMAINING:  $' WS-REMAINING-RMD
               DISPLAY 'STATUS:     ' WS-RMD-STATUS
               IF WS-PENALTY-AMT > 0
                   DISPLAY 'PENALTY:    $' WS-PENALTY-AMT
               END-IF
           ELSE
               DISPLAY 'STATUS: ' WS-RMD-STATUS
           END-IF.
