       IDENTIFICATION DIVISION.
       PROGRAM-ID. BRANCH-FEE-REVENUE.
      *================================================================*
      * Branch Fee Revenue Tracker                                     *
      * Aggregates fee income by category, computes month-over-month   *
      * trends, identifies top revenue generators for incentive calc.  *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- Fee Category Table ---
       01  WS-FEE-CAT-TABLE.
           05  WS-FEE-CAT OCCURS 8 TIMES.
               10  WS-CAT-CODE        PIC X(4).
               10  WS-CAT-NAME        PIC X(25).
               10  WS-CAT-CURRENT     PIC S9(9)V99 COMP-3.
               10  WS-CAT-PRIOR       PIC S9(9)V99 COMP-3.
               10  WS-CAT-CHANGE      PIC S9(9)V99 COMP-3.
               10  WS-CAT-PCT-CHG     PIC S9(5)V99 COMP-3.
               10  WS-CAT-TXN-CT      PIC S9(7) COMP-3.
       01  WS-CAT-IDX                PIC 9(3).
       01  WS-CAT-COUNT              PIC 9(3).
      *--- Totals ---
       01  WS-TOTAL-CURRENT          PIC S9(11)V99 COMP-3.
       01  WS-TOTAL-PRIOR            PIC S9(11)V99 COMP-3.
       01  WS-TOTAL-CHANGE           PIC S9(9)V99 COMP-3.
       01  WS-TOTAL-PCT-CHG          PIC S9(5)V99 COMP-3.
      *--- Top Performer ---
       01  WS-TOP-CAT-IDX            PIC 9(3).
       01  WS-TOP-REVENUE            PIC S9(9)V99 COMP-3.
       01  WS-TOP-NAME               PIC X(25).
      *--- Target/Budget ---
       01  WS-MONTHLY-TARGET         PIC S9(9)V99 COMP-3.
       01  WS-TARGET-PCT             PIC S9(5)V99 COMP-3.
       01  WS-ON-TARGET              PIC 9.
           88  WS-ABOVE-TARGET       VALUE 1.
           88  WS-BELOW-TARGET       VALUE 0.
      *--- Branch Info ---
       01  WS-BRANCH-ID              PIC X(6).
       01  WS-REPORT-MONTH           PIC 9(6).
      *--- Display ---
       01  WS-DISP-AMT               PIC -$$$,$$$,$$9.99.
       01  WS-DISP-PCT               PIC -ZZ9.99.
       01  WS-DISP-CT                PIC ZZZ,ZZ9.
      *--- String/Tally ---
       01  WS-REPORT-LINE            PIC X(72).
       01  WS-NAME-TALLY             PIC S9(3) COMP-3.

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-FEE-DATA
           PERFORM 3000-COMPUTE-CHANGES
           PERFORM 4000-FIND-TOP-PERFORMER
           PERFORM 5000-CHECK-TARGET
           PERFORM 6000-DISPLAY-REPORT
           STOP RUN.

       1000-INITIALIZE.
           MOVE "BR0042" TO WS-BRANCH-ID
           MOVE 202602 TO WS-REPORT-MONTH
           MOVE 0 TO WS-TOTAL-CURRENT
           MOVE 0 TO WS-TOTAL-PRIOR
           MOVE 0 TO WS-TOP-REVENUE
           MOVE 0 TO WS-TOP-CAT-IDX
           MOVE 85000.00 TO WS-MONTHLY-TARGET.

       2000-LOAD-FEE-DATA.
           MOVE 7 TO WS-CAT-COUNT
           MOVE "MNTC" TO WS-CAT-CODE(1)
           MOVE "MAINTENANCE FEES"
               TO WS-CAT-NAME(1)
           MOVE 12500.00 TO WS-CAT-CURRENT(1)
           MOVE 11800.00 TO WS-CAT-PRIOR(1)
           MOVE 1042 TO WS-CAT-TXN-CT(1)
           MOVE "ODFT" TO WS-CAT-CODE(2)
           MOVE "OVERDRAFT FEES"
               TO WS-CAT-NAME(2)
           MOVE 28750.00 TO WS-CAT-CURRENT(2)
           MOVE 31200.00 TO WS-CAT-PRIOR(2)
           MOVE 821 TO WS-CAT-TXN-CT(2)
           MOVE "NSFF" TO WS-CAT-CODE(3)
           MOVE "NSF FEES"
               TO WS-CAT-NAME(3)
           MOVE 18600.00 TO WS-CAT-CURRENT(3)
           MOVE 19100.00 TO WS-CAT-PRIOR(3)
           MOVE 517 TO WS-CAT-TXN-CT(3)
           MOVE "WIRE" TO WS-CAT-CODE(4)
           MOVE "WIRE TRANSFER FEES"
               TO WS-CAT-NAME(4)
           MOVE 8750.00 TO WS-CAT-CURRENT(4)
           MOVE 7500.00 TO WS-CAT-PRIOR(4)
           MOVE 350 TO WS-CAT-TXN-CT(4)
           MOVE "STPF" TO WS-CAT-CODE(5)
           MOVE "STOP PAYMENT FEES"
               TO WS-CAT-NAME(5)
           MOVE 3500.00 TO WS-CAT-CURRENT(5)
           MOVE 3150.00 TO WS-CAT-PRIOR(5)
           MOVE 100 TO WS-CAT-TXN-CT(5)
           MOVE "ATMF" TO WS-CAT-CODE(6)
           MOVE "ATM SURCHARGES"
               TO WS-CAT-NAME(6)
           MOVE 15200.00 TO WS-CAT-CURRENT(6)
           MOVE 14800.00 TO WS-CAT-PRIOR(6)
           MOVE 5067 TO WS-CAT-TXN-CT(6)
           MOVE "MISC" TO WS-CAT-CODE(7)
           MOVE "MISCELLANEOUS FEES"
               TO WS-CAT-NAME(7)
           MOVE 2100.00 TO WS-CAT-CURRENT(7)
           MOVE 1950.00 TO WS-CAT-PRIOR(7)
           MOVE 175 TO WS-CAT-TXN-CT(7).

       3000-COMPUTE-CHANGES.
           PERFORM VARYING WS-CAT-IDX FROM 1 BY 1
               UNTIL WS-CAT-IDX > WS-CAT-COUNT
               COMPUTE WS-CAT-CHANGE(WS-CAT-IDX) =
                   WS-CAT-CURRENT(WS-CAT-IDX)
                   - WS-CAT-PRIOR(WS-CAT-IDX)
               IF WS-CAT-PRIOR(WS-CAT-IDX) > 0
                   COMPUTE WS-CAT-PCT-CHG(WS-CAT-IDX)
                       ROUNDED =
                       WS-CAT-CHANGE(WS-CAT-IDX)
                       / WS-CAT-PRIOR(WS-CAT-IDX) * 100
               ELSE
                   MOVE 0
                       TO WS-CAT-PCT-CHG(WS-CAT-IDX)
               END-IF
               ADD WS-CAT-CURRENT(WS-CAT-IDX)
                   TO WS-TOTAL-CURRENT
               ADD WS-CAT-PRIOR(WS-CAT-IDX)
                   TO WS-TOTAL-PRIOR
           END-PERFORM
           COMPUTE WS-TOTAL-CHANGE =
               WS-TOTAL-CURRENT - WS-TOTAL-PRIOR
           IF WS-TOTAL-PRIOR > 0
               COMPUTE WS-TOTAL-PCT-CHG ROUNDED =
                   WS-TOTAL-CHANGE / WS-TOTAL-PRIOR * 100
           END-IF.

       4000-FIND-TOP-PERFORMER.
           MOVE 1 TO WS-TOP-CAT-IDX
           MOVE WS-CAT-CURRENT(1) TO WS-TOP-REVENUE
           PERFORM VARYING WS-CAT-IDX FROM 2 BY 1
               UNTIL WS-CAT-IDX > WS-CAT-COUNT
               IF WS-CAT-CURRENT(WS-CAT-IDX) >
                   WS-TOP-REVENUE
                   MOVE WS-CAT-IDX TO WS-TOP-CAT-IDX
                   MOVE WS-CAT-CURRENT(WS-CAT-IDX)
                       TO WS-TOP-REVENUE
               END-IF
           END-PERFORM
           MOVE WS-CAT-NAME(WS-TOP-CAT-IDX) TO WS-TOP-NAME.

       5000-CHECK-TARGET.
           IF WS-TOTAL-CURRENT >= WS-MONTHLY-TARGET
               MOVE 1 TO WS-ON-TARGET
           ELSE
               MOVE 0 TO WS-ON-TARGET
           END-IF
           IF WS-MONTHLY-TARGET > 0
               COMPUTE WS-TARGET-PCT ROUNDED =
                   WS-TOTAL-CURRENT
                   / WS-MONTHLY-TARGET * 100
           END-IF.

       6000-DISPLAY-REPORT.
           DISPLAY "========================================"
           DISPLAY "   FEE REVENUE REPORT"
           DISPLAY "========================================"
           DISPLAY "BRANCH: " WS-BRANCH-ID
               " MONTH: " WS-REPORT-MONTH
           PERFORM VARYING WS-CAT-IDX FROM 1 BY 1
               UNTIL WS-CAT-IDX > WS-CAT-COUNT
               MOVE 0 TO WS-NAME-TALLY
               INSPECT WS-CAT-NAME(WS-CAT-IDX)
                   TALLYING WS-NAME-TALLY FOR ALL SPACES
               MOVE WS-CAT-CURRENT(WS-CAT-IDX)
                   TO WS-DISP-AMT
               MOVE WS-CAT-PCT-CHG(WS-CAT-IDX)
                   TO WS-DISP-PCT
               DISPLAY WS-CAT-NAME(WS-CAT-IDX)
                   " " WS-DISP-AMT
                   " (" WS-DISP-PCT "%)"
           END-PERFORM
           DISPLAY "--- TOTALS ---"
           MOVE WS-TOTAL-CURRENT TO WS-DISP-AMT
           DISPLAY "CURRENT:   " WS-DISP-AMT
           MOVE WS-TOTAL-PRIOR TO WS-DISP-AMT
           DISPLAY "PRIOR:     " WS-DISP-AMT
           MOVE WS-TOTAL-PCT-CHG TO WS-DISP-PCT
           DISPLAY "CHANGE:    " WS-DISP-PCT "%"
           DISPLAY "TOP: " WS-TOP-NAME
           IF WS-ABOVE-TARGET
               DISPLAY "TARGET: ACHIEVED"
           ELSE
               DISPLAY "TARGET: BELOW"
           END-IF
           DISPLAY "========================================".
