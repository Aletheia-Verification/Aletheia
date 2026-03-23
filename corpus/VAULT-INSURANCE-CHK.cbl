       IDENTIFICATION DIVISION.
       PROGRAM-ID. VAULT-INSURANCE-CHK.
      *================================================================*
      * Vault Insurance Coverage Verification                          *
      * Computes insured vs excess cash, splits by location,           *
      * generates coverage gap report for risk management.             *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- Location Table ---
       01  WS-LOC-TABLE.
           05  WS-LOC-ENTRY OCCURS 5 TIMES.
               10  WS-LOC-ID          PIC X(8).
               10  WS-LOC-TYPE        PIC 9.
               10  WS-LOC-CASH-BAL    PIC S9(11)V99 COMP-3.
               10  WS-LOC-INS-LIMIT   PIC S9(11)V99 COMP-3.
               10  WS-LOC-INSURED     PIC S9(11)V99 COMP-3.
               10  WS-LOC-EXCESS      PIC S9(11)V99 COMP-3.
               10  WS-LOC-PREMIUM     PIC S9(7)V99 COMP-3.
       01  WS-LOC-IDX                PIC 9(3).
       01  WS-LOC-COUNT              PIC 9(3).
      *--- Location Types ---
       01  WS-LOC-TYPE-VAL           PIC 9.
           88  WS-LOC-MAIN-VAULT     VALUE 1.
           88  WS-LOC-ATM            VALUE 2.
           88  WS-LOC-NIGHT-DROP     VALUE 3.
           88  WS-LOC-SAFE-DEP       VALUE 4.
      *--- Insurance Parameters ---
       01  WS-BASE-RATE              PIC S9(3)V9(6) COMP-3.
       01  WS-ATM-RATE-MULT         PIC S9(3)V99 COMP-3.
       01  WS-NIGHT-RATE-MULT       PIC S9(3)V99 COMP-3.
       01  WS-DEDUCTIBLE            PIC S9(9)V99 COMP-3.
       01  WS-MAX-COVERAGE          PIC S9(13)V99 COMP-3.
      *--- Totals ---
       01  WS-TOTAL-CASH            PIC S9(13)V99 COMP-3.
       01  WS-TOTAL-INSURED         PIC S9(13)V99 COMP-3.
       01  WS-TOTAL-EXCESS          PIC S9(11)V99 COMP-3.
       01  WS-TOTAL-PREMIUM         PIC S9(9)V99 COMP-3.
       01  WS-COVERAGE-PCT          PIC S9(3)V99 COMP-3.
       01  WS-GAP-EXISTS            PIC 9.
           88  WS-NO-GAP            VALUE 0.
           88  WS-HAS-GAP           VALUE 1.
      *--- Display ---
       01  WS-DISP-AMT              PIC -$$$,$$$,$$$,$$9.99.
       01  WS-DISP-PCT              PIC ZZ9.99.
       01  WS-DISP-PREM             PIC -$$$,$$9.99.
      *--- Work ---
       01  WS-WORK-RATE             PIC S9(3)V9(6) COMP-3.
       01  WS-LOC-NAME              PIC X(15).
       01  WS-TALLY-WORK            PIC S9(3) COMP-3.

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-COMPUTE-COVERAGE
           PERFORM 3000-CALCULATE-PREMIUMS
           PERFORM 4000-ASSESS-GAPS
           PERFORM 5000-DISPLAY-REPORT
           STOP RUN.

       1000-INITIALIZE.
           MOVE 0.000150 TO WS-BASE-RATE
           MOVE 1.50 TO WS-ATM-RATE-MULT
           MOVE 2.00 TO WS-NIGHT-RATE-MULT
           MOVE 5000.00 TO WS-DEDUCTIBLE
           MOVE 5000000.00 TO WS-MAX-COVERAGE
           MOVE 0 TO WS-TOTAL-CASH
           MOVE 0 TO WS-TOTAL-INSURED
           MOVE 0 TO WS-TOTAL-EXCESS
           MOVE 0 TO WS-TOTAL-PREMIUM
           MOVE 0 TO WS-GAP-EXISTS
           MOVE 4 TO WS-LOC-COUNT
           MOVE "VAULT-01" TO WS-LOC-ID(1)
           MOVE 1 TO WS-LOC-TYPE(1)
           MOVE 2500000.00 TO WS-LOC-CASH-BAL(1)
           MOVE 3000000.00 TO WS-LOC-INS-LIMIT(1)
           MOVE "ATM-FL01" TO WS-LOC-ID(2)
           MOVE 2 TO WS-LOC-TYPE(2)
           MOVE 320000.00 TO WS-LOC-CASH-BAL(2)
           MOVE 250000.00 TO WS-LOC-INS-LIMIT(2)
           MOVE "NDROP-01" TO WS-LOC-ID(3)
           MOVE 3 TO WS-LOC-TYPE(3)
           MOVE 75000.00 TO WS-LOC-CASH-BAL(3)
           MOVE 100000.00 TO WS-LOC-INS-LIMIT(3)
           MOVE "ATM-FL02" TO WS-LOC-ID(4)
           MOVE 2 TO WS-LOC-TYPE(4)
           MOVE 180000.00 TO WS-LOC-CASH-BAL(4)
           MOVE 250000.00 TO WS-LOC-INS-LIMIT(4).

       2000-COMPUTE-COVERAGE.
           PERFORM VARYING WS-LOC-IDX FROM 1 BY 1
               UNTIL WS-LOC-IDX > WS-LOC-COUNT
               IF WS-LOC-CASH-BAL(WS-LOC-IDX) <=
                   WS-LOC-INS-LIMIT(WS-LOC-IDX)
                   MOVE WS-LOC-CASH-BAL(WS-LOC-IDX)
                       TO WS-LOC-INSURED(WS-LOC-IDX)
                   MOVE 0 TO WS-LOC-EXCESS(WS-LOC-IDX)
               ELSE
                   MOVE WS-LOC-INS-LIMIT(WS-LOC-IDX)
                       TO WS-LOC-INSURED(WS-LOC-IDX)
                   COMPUTE WS-LOC-EXCESS(WS-LOC-IDX) =
                       WS-LOC-CASH-BAL(WS-LOC-IDX)
                       - WS-LOC-INS-LIMIT(WS-LOC-IDX)
               END-IF
               ADD WS-LOC-CASH-BAL(WS-LOC-IDX)
                   TO WS-TOTAL-CASH
               ADD WS-LOC-INSURED(WS-LOC-IDX)
                   TO WS-TOTAL-INSURED
               ADD WS-LOC-EXCESS(WS-LOC-IDX)
                   TO WS-TOTAL-EXCESS
           END-PERFORM.

       3000-CALCULATE-PREMIUMS.
           PERFORM VARYING WS-LOC-IDX FROM 1 BY 1
               UNTIL WS-LOC-IDX > WS-LOC-COUNT
               EVALUATE WS-LOC-TYPE(WS-LOC-IDX)
                   WHEN 1
                       MOVE WS-BASE-RATE TO WS-WORK-RATE
                   WHEN 2
                       COMPUTE WS-WORK-RATE =
                           WS-BASE-RATE * WS-ATM-RATE-MULT
                   WHEN 3
                       COMPUTE WS-WORK-RATE =
                           WS-BASE-RATE * WS-NIGHT-RATE-MULT
                   WHEN OTHER
                       MOVE WS-BASE-RATE TO WS-WORK-RATE
               END-EVALUATE
               COMPUTE WS-LOC-PREMIUM(WS-LOC-IDX) ROUNDED =
                   WS-LOC-INSURED(WS-LOC-IDX)
                   * WS-WORK-RATE
               ADD WS-LOC-PREMIUM(WS-LOC-IDX)
                   TO WS-TOTAL-PREMIUM
           END-PERFORM.

       4000-ASSESS-GAPS.
           IF WS-TOTAL-CASH > 0
               COMPUTE WS-COVERAGE-PCT ROUNDED =
                   WS-TOTAL-INSURED / WS-TOTAL-CASH * 100
           ELSE
               MOVE 100.00 TO WS-COVERAGE-PCT
           END-IF
           IF WS-TOTAL-EXCESS > 0
               MOVE 1 TO WS-GAP-EXISTS
           END-IF.

       5000-DISPLAY-REPORT.
           DISPLAY "========================================"
           DISPLAY "   INSURANCE COVERAGE REPORT"
           DISPLAY "========================================"
           PERFORM VARYING WS-LOC-IDX FROM 1 BY 1
               UNTIL WS-LOC-IDX > WS-LOC-COUNT
               EVALUATE WS-LOC-TYPE(WS-LOC-IDX)
                   WHEN 1
                       MOVE "MAIN VAULT" TO WS-LOC-NAME
                   WHEN 2
                       MOVE "ATM" TO WS-LOC-NAME
                   WHEN 3
                       MOVE "NIGHT DROP" TO WS-LOC-NAME
                   WHEN OTHER
                       MOVE "OTHER" TO WS-LOC-NAME
               END-EVALUATE
               MOVE 0 TO WS-TALLY-WORK
               INSPECT WS-LOC-ID(WS-LOC-IDX)
                   TALLYING WS-TALLY-WORK
                   FOR ALL "0"
               DISPLAY WS-LOC-ID(WS-LOC-IDX) " "
                   WS-LOC-NAME
               MOVE WS-LOC-CASH-BAL(WS-LOC-IDX)
                   TO WS-DISP-AMT
               DISPLAY "  CASH:    " WS-DISP-AMT
               IF WS-LOC-EXCESS(WS-LOC-IDX) > 0
                   MOVE WS-LOC-EXCESS(WS-LOC-IDX)
                       TO WS-DISP-AMT
                   DISPLAY "  EXCESS:  " WS-DISP-AMT
               END-IF
               MOVE WS-LOC-PREMIUM(WS-LOC-IDX)
                   TO WS-DISP-PREM
               DISPLAY "  PREMIUM: " WS-DISP-PREM
           END-PERFORM
           DISPLAY "--- COVERAGE SUMMARY ---"
           MOVE WS-COVERAGE-PCT TO WS-DISP-PCT
           DISPLAY "COVERAGE:    " WS-DISP-PCT "%"
           MOVE WS-TOTAL-PREMIUM TO WS-DISP-PREM
           DISPLAY "TOTAL PREM:  " WS-DISP-PREM
           IF WS-HAS-GAP
               MOVE WS-TOTAL-EXCESS TO WS-DISP-AMT
               DISPLAY "*** GAP: " WS-DISP-AMT
                   " UNINSURED ***"
           END-IF
           DISPLAY "========================================".
