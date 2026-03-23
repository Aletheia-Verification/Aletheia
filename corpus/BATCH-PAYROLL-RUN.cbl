       IDENTIFICATION DIVISION.
       PROGRAM-ID. BATCH-PAYROLL-RUN.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT EMPLOYEE-FILE ASSIGN TO 'EMPLOYEE.DAT'
               FILE STATUS IS WS-EMP-STATUS.
           SELECT PAYROLL-FILE ASSIGN TO 'PAYROLL.DAT'
               FILE STATUS IS WS-PAY-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD EMPLOYEE-FILE.
       01 EMP-RECORD.
           05 EMP-ID              PIC X(8).
           05 EMP-NAME            PIC X(25).
           05 EMP-DEPT            PIC X(4).
           05 EMP-PAY-TYPE        PIC X(1).
           05 EMP-HOURLY-RATE     PIC 9(3)V99.
           05 EMP-SALARY          PIC 9(7)V99.
           05 EMP-HOURS-REG       PIC 9(3)V99.
           05 EMP-HOURS-OT        PIC 9(3)V99.
           05 EMP-STATE-CODE      PIC X(2).
           05 EMP-EXEMPTIONS      PIC 9(2).
       FD PAYROLL-FILE.
       01 PAY-RECORD.
           05 PAY-EMP-ID          PIC X(8).
           05 PAY-GROSS           PIC 9(7)V99.
           05 PAY-FED-TAX         PIC 9(7)V99.
           05 PAY-STATE-TAX       PIC 9(7)V99.
           05 PAY-FICA            PIC 9(7)V99.
           05 PAY-MEDICARE        PIC 9(5)V99.
           05 PAY-NET             PIC 9(7)V99.
           05 PAY-CHECK-AMT       PIC 9(7)V99.
           05 PAY-REMAINDER       PIC 9(5)V99.
       WORKING-STORAGE SECTION.
       01 WS-EMP-STATUS           PIC XX.
       01 WS-PAY-STATUS           PIC XX.
       01 WS-EOF-FLAG             PIC X VALUE 'N'.
           88 WS-EOF              VALUE 'Y'.
       01 WS-PAY-TYPE-FLAG        PIC X.
           88 WS-HOURLY           VALUE 'H'.
           88 WS-SALARIED         VALUE 'S'.
       01 WS-CALC-FIELDS.
           05 WS-GROSS-PAY        PIC S9(7)V99 COMP-3.
           05 WS-REG-PAY          PIC S9(7)V99 COMP-3.
           05 WS-OT-PAY           PIC S9(7)V99 COMP-3.
           05 WS-OT-RATE          PIC S9(5)V99 COMP-3.
           05 WS-FED-TAX          PIC S9(7)V99 COMP-3.
           05 WS-STATE-TAX        PIC S9(7)V99 COMP-3.
           05 WS-FICA-AMT         PIC S9(7)V99 COMP-3.
           05 WS-MEDICARE-AMT     PIC S9(5)V99 COMP-3.
           05 WS-NET-PAY          PIC S9(7)V99 COMP-3.
           05 WS-TAXABLE-INCOME   PIC S9(7)V99 COMP-3.
           05 WS-EXEMPT-AMT       PIC S9(7)V99 COMP-3.
           05 WS-CHECK-AMT        PIC S9(7)V99 COMP-3.
           05 WS-PAY-REMAINDER    PIC S9(5)V99 COMP-3.
       01 WS-CONSTANTS.
           05 WS-OT-MULTIPLIER    PIC S9(1)V9 VALUE 1.5.
           05 WS-FICA-RATE        PIC S9(1)V9(4) VALUE 0.0620.
           05 WS-MEDICARE-RATE    PIC S9(1)V9(4) VALUE 0.0145.
           05 WS-STATE-RATE       PIC S9(1)V9(4) VALUE 0.0500.
           05 WS-EXEMPT-VALUE     PIC S9(5)V99 VALUE 350.00.
           05 WS-PAY-PERIODS      PIC 9(2) VALUE 26.
           05 WS-BIWEEKLY-DIVS    PIC 9(1) VALUE 2.
       01 WS-TOTALS.
           05 WS-TOTAL-GROSS      PIC S9(9)V99 COMP-3.
           05 WS-TOTAL-NET        PIC S9(9)V99 COMP-3.
           05 WS-TOTAL-TAXES      PIC S9(9)V99 COMP-3.
           05 WS-EMP-COUNT        PIC S9(5) COMP-3.
       01 WS-EMP-TABLE.
           05 WS-DEPT-TOTAL OCCURS 10.
               10 WS-DEPT-CODE    PIC X(4).
               10 WS-DEPT-GROSS   PIC S9(9)V99 COMP-3.
               10 WS-DEPT-COUNT   PIC S9(3) COMP-3.
       01 WS-IDX                  PIC 9(2).
       01 WS-FOUND-FLAG           PIC X VALUE 'N'.
           88 WS-FOUND            VALUE 'Y'.
       01 WS-VALIDATION.
           05 WS-VALID-FLAG       PIC X VALUE 'Y'.
               88 WS-VALID        VALUE 'Y'.
               88 WS-INVALID      VALUE 'N'.
           05 WS-ERROR-COUNT      PIC S9(3) COMP-3.
           05 WS-SKIP-COUNT       PIC S9(5) COMP-3.
       01 WS-BONUS-FIELDS.
           05 WS-BONUS-PCT        PIC S9(1)V9(4) COMP-3.
           05 WS-BONUS-AMT        PIC S9(7)V99 COMP-3.
           05 WS-ANNUAL-GROSS     PIC S9(9)V99 COMP-3.
           05 WS-YTD-GROSS        PIC S9(9)V99 COMP-3.
           05 WS-YTD-FED-TAX     PIC S9(9)V99 COMP-3.
           05 WS-YTD-STATE-TAX   PIC S9(9)V99 COMP-3.
       01 WS-401K-FIELDS.
           05 WS-401K-PCT         PIC S9(1)V9(4) COMP-3.
           05 WS-401K-DEDUCT      PIC S9(7)V99 COMP-3.
           05 WS-401K-LIMIT       PIC S9(7)V99 VALUE 23000.00.
           05 WS-401K-YTD         PIC S9(7)V99 COMP-3.
       01 WS-INSURANCE.
           05 WS-HEALTH-PREM      PIC S9(5)V99 VALUE 245.50.
           05 WS-DENTAL-PREM      PIC S9(5)V99 VALUE 35.75.
           05 WS-VISION-PREM      PIC S9(5)V99 VALUE 12.25.
           05 WS-TOTAL-PREM       PIC S9(5)V99 COMP-3.
       01 WS-GARNISHMENT.
           05 WS-GARN-FLAG        PIC X VALUE 'N'.
               88 WS-HAS-GARN     VALUE 'Y'.
           05 WS-GARN-AMT         PIC S9(7)V99 COMP-3.
           05 WS-GARN-MAX-PCT     PIC S9(1)V99 VALUE 0.25.
           05 WS-GARN-LIMIT       PIC S9(7)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 0100-INITIALIZE
           PERFORM 0200-OPEN-FILES
           PERFORM 0300-READ-EMPLOYEE UNTIL WS-EOF
           PERFORM 0400-PRINT-TOTALS
           PERFORM 0500-CLOSE-FILES
           STOP RUN.
       0100-INITIALIZE.
           INITIALIZE WS-CALC-FIELDS
           INITIALIZE WS-TOTALS
           MOVE 0 TO WS-EMP-COUNT
           MOVE 0 TO WS-TOTAL-GROSS
           MOVE 0 TO WS-TOTAL-NET
           MOVE 0 TO WS-TOTAL-TAXES
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > 10
               MOVE SPACES TO WS-DEPT-CODE(WS-IDX)
               MOVE 0 TO WS-DEPT-GROSS(WS-IDX)
               MOVE 0 TO WS-DEPT-COUNT(WS-IDX)
           END-PERFORM.
       0200-OPEN-FILES.
           OPEN INPUT EMPLOYEE-FILE
           OPEN OUTPUT PAYROLL-FILE.
       0300-READ-EMPLOYEE.
           READ EMPLOYEE-FILE
               AT END SET WS-EOF TO TRUE
               NOT AT END PERFORM 1000-CALC-GROSS
                              THRU 3000-WRITE-OUTPUT.
       1000-CALC-GROSS.
           MOVE EMP-PAY-TYPE TO WS-PAY-TYPE-FLAG
           IF WS-HOURLY
               COMPUTE WS-REG-PAY =
                   EMP-HOURLY-RATE * EMP-HOURS-REG
               COMPUTE WS-OT-RATE =
                   EMP-HOURLY-RATE * WS-OT-MULTIPLIER
               COMPUTE WS-OT-PAY =
                   WS-OT-RATE * EMP-HOURS-OT
               COMPUTE WS-GROSS-PAY =
                   WS-REG-PAY + WS-OT-PAY
           ELSE
               COMPUTE WS-GROSS-PAY =
                   EMP-SALARY / WS-PAY-PERIODS
               MOVE 0 TO WS-OT-PAY
           END-IF.
       2000-CALC-DEDUCTIONS.
           COMPUTE WS-EXEMPT-AMT =
               EMP-EXEMPTIONS * WS-EXEMPT-VALUE
           COMPUTE WS-TAXABLE-INCOME =
               WS-GROSS-PAY - WS-EXEMPT-AMT
           IF WS-TAXABLE-INCOME < 0
               MOVE 0 TO WS-TAXABLE-INCOME
           END-IF
           IF WS-TAXABLE-INCOME > 8000
               COMPUTE WS-FED-TAX =
                   WS-TAXABLE-INCOME * 0.32
           ELSE
               IF WS-TAXABLE-INCOME > 4000
                   COMPUTE WS-FED-TAX =
                       WS-TAXABLE-INCOME * 0.22
               ELSE
                   IF WS-TAXABLE-INCOME > 1500
                       COMPUTE WS-FED-TAX =
                           WS-TAXABLE-INCOME * 0.12
                   ELSE
                       COMPUTE WS-FED-TAX =
                           WS-TAXABLE-INCOME * 0.10
                   END-IF
               END-IF
           END-IF
           COMPUTE WS-STATE-TAX =
               WS-GROSS-PAY * WS-STATE-RATE
           COMPUTE WS-FICA-AMT =
               WS-GROSS-PAY * WS-FICA-RATE
           COMPUTE WS-MEDICARE-AMT =
               WS-GROSS-PAY * WS-MEDICARE-RATE
           COMPUTE WS-NET-PAY =
               WS-GROSS-PAY - WS-FED-TAX
               - WS-STATE-TAX - WS-FICA-AMT
               - WS-MEDICARE-AMT
           IF WS-NET-PAY < 0
               MOVE 0 TO WS-NET-PAY
           END-IF
           PERFORM 2100-CALC-BENEFITS
           PERFORM 2200-CALC-401K
           PERFORM 2300-CALC-GARNISHMENT
           SUBTRACT WS-TOTAL-PREM FROM WS-NET-PAY
           SUBTRACT WS-401K-DEDUCT FROM WS-NET-PAY
           IF WS-HAS-GARN
               SUBTRACT WS-GARN-AMT FROM WS-NET-PAY
           END-IF
           IF WS-NET-PAY < 0
               MOVE 0 TO WS-NET-PAY
           END-IF
           DIVIDE WS-NET-PAY BY WS-BIWEEKLY-DIVS
               GIVING WS-CHECK-AMT
               REMAINDER WS-PAY-REMAINDER.
       2100-CALC-BENEFITS.
           COMPUTE WS-TOTAL-PREM =
               WS-HEALTH-PREM + WS-DENTAL-PREM
               + WS-VISION-PREM
           DIVIDE WS-TOTAL-PREM BY WS-PAY-PERIODS
               GIVING WS-TOTAL-PREM.
       2200-CALC-401K.
           MOVE 0.06 TO WS-401K-PCT
           COMPUTE WS-401K-DEDUCT =
               WS-GROSS-PAY * WS-401K-PCT
           COMPUTE WS-ANNUAL-GROSS =
               WS-GROSS-PAY * WS-PAY-PERIODS
           IF WS-ANNUAL-GROSS > 150000
               MOVE 0.10 TO WS-401K-PCT
               COMPUTE WS-401K-DEDUCT =
                   WS-GROSS-PAY * WS-401K-PCT
           END-IF
           ADD WS-401K-DEDUCT TO WS-401K-YTD
           IF WS-401K-YTD > WS-401K-LIMIT
               COMPUTE WS-401K-DEDUCT =
                   WS-401K-DEDUCT -
                   (WS-401K-YTD - WS-401K-LIMIT)
               IF WS-401K-DEDUCT < 0
                   MOVE 0 TO WS-401K-DEDUCT
               END-IF
           END-IF.
       2300-CALC-GARNISHMENT.
           IF WS-HAS-GARN
               COMPUTE WS-GARN-LIMIT =
                   WS-NET-PAY * WS-GARN-MAX-PCT
               IF WS-GARN-AMT > WS-GARN-LIMIT
                   MOVE WS-GARN-LIMIT TO WS-GARN-AMT
               END-IF
           ELSE
               MOVE 0 TO WS-GARN-AMT
           END-IF.
       2400-VALIDATE-EMPLOYEE.
           MOVE 'Y' TO WS-VALID-FLAG
           IF EMP-ID = SPACES
               MOVE 'N' TO WS-VALID-FLAG
               ADD 1 TO WS-ERROR-COUNT
           END-IF
           IF EMP-HOURLY-RATE = 0 AND EMP-SALARY = 0
               MOVE 'N' TO WS-VALID-FLAG
               ADD 1 TO WS-ERROR-COUNT
           END-IF
           IF WS-INVALID
               ADD 1 TO WS-SKIP-COUNT
               DISPLAY 'SKIPPED INVALID EMP: ' EMP-ID
           END-IF.
       2500-UPDATE-DEPT-TOTALS.
           MOVE 'N' TO WS-FOUND-FLAG
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > 10 OR WS-FOUND
               IF WS-DEPT-CODE(WS-IDX) = EMP-DEPT
                   ADD WS-GROSS-PAY TO
                       WS-DEPT-GROSS(WS-IDX)
                   ADD 1 TO WS-DEPT-COUNT(WS-IDX)
                   MOVE 'Y' TO WS-FOUND-FLAG
               END-IF
               IF WS-DEPT-CODE(WS-IDX) = SPACES
                   MOVE EMP-DEPT TO WS-DEPT-CODE(WS-IDX)
                   MOVE WS-GROSS-PAY TO
                       WS-DEPT-GROSS(WS-IDX)
                   MOVE 1 TO WS-DEPT-COUNT(WS-IDX)
                   MOVE 'Y' TO WS-FOUND-FLAG
               END-IF
           END-PERFORM.
       3000-WRITE-OUTPUT.
           MOVE EMP-ID TO PAY-EMP-ID
           MOVE WS-GROSS-PAY TO PAY-GROSS
           MOVE WS-FED-TAX TO PAY-FED-TAX
           MOVE WS-STATE-TAX TO PAY-STATE-TAX
           MOVE WS-FICA-AMT TO PAY-FICA
           MOVE WS-MEDICARE-AMT TO PAY-MEDICARE
           MOVE WS-NET-PAY TO PAY-NET
           MOVE WS-CHECK-AMT TO PAY-CHECK-AMT
           MOVE WS-PAY-REMAINDER TO PAY-REMAINDER
           WRITE PAY-RECORD
           ADD 1 TO WS-EMP-COUNT
           ADD WS-GROSS-PAY TO WS-TOTAL-GROSS
           ADD WS-NET-PAY TO WS-TOTAL-NET
           ADD WS-FED-TAX WS-STATE-TAX
               WS-FICA-AMT WS-MEDICARE-AMT
               GIVING WS-TOTAL-TAXES.
       0400-PRINT-TOTALS.
           DISPLAY 'PAYROLL BATCH COMPLETE'
           DISPLAY 'EMPLOYEES PROCESSED: ' WS-EMP-COUNT
           DISPLAY 'TOTAL GROSS PAY:     ' WS-TOTAL-GROSS
           DISPLAY 'TOTAL NET PAY:       ' WS-TOTAL-NET
           DISPLAY 'TOTAL TAXES:         ' WS-TOTAL-TAXES
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > 10
               IF WS-DEPT-CODE(WS-IDX) NOT = SPACES
                   DISPLAY 'DEPT ' WS-DEPT-CODE(WS-IDX)
                       ' GROSS: ' WS-DEPT-GROSS(WS-IDX)
                       ' COUNT: ' WS-DEPT-COUNT(WS-IDX)
               END-IF
           END-PERFORM.
       0500-CLOSE-FILES.
           CLOSE EMPLOYEE-FILE
           CLOSE PAYROLL-FILE.
