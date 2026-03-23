       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOAN-DTI-CALC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-BORROWER.
           05 WS-BOR-NAME         PIC X(30).
           05 WS-BOR-SSN          PIC X(9).
       01 WS-INCOME-SOURCES.
           05 WS-INC OCCURS 5 TIMES.
               10 WS-INC-TYPE     PIC X(2).
                   88 INC-SALARY  VALUE 'SA'.
                   88 INC-BONUS   VALUE 'BO'.
                   88 INC-RENTAL  VALUE 'RE'.
                   88 INC-INVEST  VALUE 'IN'.
                   88 INC-OTHER   VALUE 'OT'.
               10 WS-INC-MONTHLY  PIC S9(7)V99 COMP-3.
               10 WS-INC-ANNUAL   PIC S9(9)V99 COMP-3.
               10 WS-INC-VERIFIED PIC X.
                   88 IS-VERIFIED VALUE 'Y'.
       01 WS-DEBT-OBLIGATIONS.
           05 WS-DEBT OCCURS 8 TIMES.
               10 WS-DBT-TYPE     PIC X(2).
               10 WS-DBT-MONTHLY  PIC S9(7)V99 COMP-3.
               10 WS-DBT-BALANCE  PIC S9(9)V99 COMP-3.
               10 WS-DBT-MONTHS-LEFT PIC 9(3).
       01 WS-INC-COUNT            PIC 9 VALUE 5.
       01 WS-DBT-COUNT            PIC 9 VALUE 8.
       01 WS-IDX                  PIC 9.
       01 WS-TOTAL-INCOME         PIC S9(9)V99 COMP-3.
       01 WS-VERIFIED-INCOME      PIC S9(9)V99 COMP-3.
       01 WS-TOTAL-DEBT           PIC S9(9)V99 COMP-3.
       01 WS-PROPOSED-PMT         PIC S9(7)V99 COMP-3.
       01 WS-FRONT-DTI            PIC S9(3)V99 COMP-3.
       01 WS-BACK-DTI             PIC S9(3)V99 COMP-3.
       01 WS-FRONT-MAX            PIC S9(3)V99 COMP-3
           VALUE 28.00.
       01 WS-BACK-MAX             PIC S9(3)V99 COMP-3
           VALUE 43.00.
       01 WS-DTI-STATUS           PIC X(15).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-CALC-INCOME
           PERFORM 2000-CALC-DEBT
           PERFORM 3000-CALC-DTI
           PERFORM 4000-EVALUATE-DTI
           PERFORM 5000-OUTPUT
           STOP RUN.
       1000-CALC-INCOME.
           MOVE 0 TO WS-TOTAL-INCOME
           MOVE 0 TO WS-VERIFIED-INCOME
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-INC-COUNT
               IF WS-INC-ANNUAL(WS-IDX) > 0
                   COMPUTE WS-INC-MONTHLY(WS-IDX) =
                       WS-INC-ANNUAL(WS-IDX) / 12
               END-IF
               ADD WS-INC-MONTHLY(WS-IDX) TO
                   WS-TOTAL-INCOME
               IF IS-VERIFIED(WS-IDX)
                   ADD WS-INC-MONTHLY(WS-IDX) TO
                       WS-VERIFIED-INCOME
               END-IF
           END-PERFORM.
       2000-CALC-DEBT.
           MOVE 0 TO WS-TOTAL-DEBT
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-DBT-COUNT
               IF WS-DBT-MONTHS-LEFT(WS-IDX) > 10
                   ADD WS-DBT-MONTHLY(WS-IDX)
                       TO WS-TOTAL-DEBT
               END-IF
           END-PERFORM.
       3000-CALC-DTI.
           IF WS-VERIFIED-INCOME > 0
               COMPUTE WS-FRONT-DTI =
                   (WS-PROPOSED-PMT /
                    WS-VERIFIED-INCOME) * 100
               COMPUTE WS-BACK-DTI =
                   ((WS-TOTAL-DEBT + WS-PROPOSED-PMT) /
                    WS-VERIFIED-INCOME) * 100
           ELSE
               MOVE 999.99 TO WS-FRONT-DTI
               MOVE 999.99 TO WS-BACK-DTI
           END-IF.
       4000-EVALUATE-DTI.
           IF WS-FRONT-DTI > WS-FRONT-MAX
               MOVE 'FRONT DTI HIGH ' TO WS-DTI-STATUS
           ELSE
               IF WS-BACK-DTI > WS-BACK-MAX
                   MOVE 'BACK DTI HIGH  ' TO WS-DTI-STATUS
               ELSE
                   IF WS-BACK-DTI <= 36.00
                       MOVE 'EXCELLENT      ' TO
                           WS-DTI-STATUS
                   ELSE
                       MOVE 'ACCEPTABLE     ' TO
                           WS-DTI-STATUS
                   END-IF
               END-IF
           END-IF.
       5000-OUTPUT.
           DISPLAY 'DTI CALCULATION REPORT'
           DISPLAY '======================'
           DISPLAY 'BORROWER:       ' WS-BOR-NAME
           DISPLAY 'TOTAL INCOME:   $' WS-TOTAL-INCOME
           DISPLAY 'VERIFIED INC:   $' WS-VERIFIED-INCOME
           DISPLAY 'TOTAL DEBT:     $' WS-TOTAL-DEBT
           DISPLAY 'PROPOSED PMT:   $' WS-PROPOSED-PMT
           DISPLAY 'FRONT DTI:      ' WS-FRONT-DTI '%'
           DISPLAY 'BACK DTI:       ' WS-BACK-DTI '%'
           DISPLAY 'STATUS:         ' WS-DTI-STATUS.
