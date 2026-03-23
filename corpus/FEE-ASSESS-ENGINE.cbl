       IDENTIFICATION DIVISION.
       PROGRAM-ID. FEE-ASSESS-ENGINE.
      *================================================================*
      * Retail Fee Assessment Engine                                   *
      * Calculates maintenance, ATM, wire, and service fees based      *
      * on account tier, applies waivers and relationship discounts.   *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- Account Info ---
       01  WS-ACCOUNT-NUM             PIC 9(10).
       01  WS-TIER-CODE               PIC 9.
           88  WS-TIER-BASIC          VALUE 1.
           88  WS-TIER-PREFERRED      VALUE 2.
           88  WS-TIER-PREMIUM        VALUE 3.
           88  WS-TIER-PRIVATE        VALUE 4.
       01  WS-RELATIONSHIP-BAL        PIC S9(13)V99 COMP-3.
       01  WS-AVG-BALANCE             PIC S9(11)V99 COMP-3.
      *--- Fee Schedule Table ---
       01  WS-FEE-SCHEDULE.
           05  WS-FEE-ITEM OCCURS 8 TIMES.
               10  WS-FEE-CODE        PIC X(4).
               10  WS-FEE-DESC        PIC X(25).
               10  WS-FEE-BASE-AMT    PIC S9(5)V99 COMP-3.
               10  WS-FEE-ASSESSED    PIC S9(5)V99 COMP-3.
               10  WS-FEE-WAIVED      PIC 9.
               10  WS-FEE-COUNT       PIC S9(3) COMP-3.
       01  WS-FEE-IDX                 PIC 9(3).
       01  WS-FEE-COUNT-LOADED        PIC 9(3).
      *--- Waiver Rules ---
       01  WS-WAIVER-THRESHOLD        PIC S9(11)V99 COMP-3.
       01  WS-RELATIONSHIP-WAIVER     PIC 9.
       01  WS-SENIOR-DISCOUNT         PIC 9.
       01  WS-MILITARY-DISCOUNT       PIC 9.
       01  WS-DISCOUNT-PCT            PIC S9(3)V99 COMP-3.
      *--- Fee Accumulators ---
       01  WS-GROSS-FEES              PIC S9(7)V99 COMP-3.
       01  WS-DISCOUNT-AMT            PIC S9(7)V99 COMP-3.
       01  WS-NET-FEES                PIC S9(7)V99 COMP-3.
       01  WS-FEES-WAIVED             PIC S9(7)V99 COMP-3.
       01  WS-WAIVED-COUNT            PIC S9(3) COMP-3.
      *--- Work Fields ---
       01  WS-WORK-FEE                PIC S9(5)V99 COMP-3.
       01  WS-WORK-TOTAL              PIC S9(7)V99 COMP-3.
       01  WS-FEE-LINE                PIC X(80).
      *--- Display ---
       01  WS-DISP-AMT                PIC -$$,$$9.99.
       01  WS-DISP-TOTAL              PIC -$$$,$$9.99.
       01  WS-DISP-BAL                PIC -$$$,$$$,$$$,$$9.99.
       01  WS-DISP-CT                 PIC ZZ9.

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-FEES
           PERFORM 3000-APPLY-TIER-RULES
           PERFORM 4000-CHECK-WAIVERS
           PERFORM 5000-CALCULATE-NET
           PERFORM 6000-DISPLAY-ASSESSMENT
           STOP RUN.

       1000-INITIALIZE.
           MOVE 5566778899 TO WS-ACCOUNT-NUM
           MOVE 2 TO WS-TIER-CODE
           MOVE 75000.00 TO WS-RELATIONSHIP-BAL
           MOVE 8500.00 TO WS-AVG-BALANCE
           MOVE 50000.00 TO WS-WAIVER-THRESHOLD
           MOVE 0 TO WS-RELATIONSHIP-WAIVER
           MOVE 0 TO WS-SENIOR-DISCOUNT
           MOVE 0 TO WS-MILITARY-DISCOUNT
           MOVE 0 TO WS-GROSS-FEES
           MOVE 0 TO WS-DISCOUNT-AMT
           MOVE 0 TO WS-NET-FEES
           MOVE 0 TO WS-FEES-WAIVED
           MOVE 0 TO WS-WAIVED-COUNT.

       2000-LOAD-FEES.
           MOVE 6 TO WS-FEE-COUNT-LOADED
           MOVE "MNTC" TO WS-FEE-CODE(1)
           MOVE "MONTHLY MAINTENANCE"
               TO WS-FEE-DESC(1)
           MOVE 12.00 TO WS-FEE-BASE-AMT(1)
           MOVE 1 TO WS-FEE-COUNT(1)
           MOVE "ATMF" TO WS-FEE-CODE(2)
           MOVE "ATM FOREIGN USE"
               TO WS-FEE-DESC(2)
           MOVE 3.00 TO WS-FEE-BASE-AMT(2)
           MOVE 4 TO WS-FEE-COUNT(2)
           MOVE "WIRE" TO WS-FEE-CODE(3)
           MOVE "DOMESTIC WIRE"
               TO WS-FEE-DESC(3)
           MOVE 25.00 TO WS-FEE-BASE-AMT(3)
           MOVE 1 TO WS-FEE-COUNT(3)
           MOVE "STMT" TO WS-FEE-CODE(4)
           MOVE "PAPER STATEMENT"
               TO WS-FEE-DESC(4)
           MOVE 5.00 TO WS-FEE-BASE-AMT(4)
           MOVE 1 TO WS-FEE-COUNT(4)
           MOVE "ODFP" TO WS-FEE-CODE(5)
           MOVE "OVERDRAFT PROTECTION"
               TO WS-FEE-DESC(5)
           MOVE 10.00 TO WS-FEE-BASE-AMT(5)
           MOVE 2 TO WS-FEE-COUNT(5)
           MOVE "STPF" TO WS-FEE-CODE(6)
           MOVE "STOP PAYMENT"
               TO WS-FEE-DESC(6)
           MOVE 35.00 TO WS-FEE-BASE-AMT(6)
           MOVE 1 TO WS-FEE-COUNT(6)
           PERFORM VARYING WS-FEE-IDX FROM 1 BY 1
               UNTIL WS-FEE-IDX > WS-FEE-COUNT-LOADED
               MOVE 0 TO WS-FEE-WAIVED(WS-FEE-IDX)
               MOVE 0 TO WS-FEE-ASSESSED(WS-FEE-IDX)
           END-PERFORM.

       3000-APPLY-TIER-RULES.
           PERFORM VARYING WS-FEE-IDX FROM 1 BY 1
               UNTIL WS-FEE-IDX > WS-FEE-COUNT-LOADED
               EVALUATE TRUE
                   WHEN WS-TIER-BASIC
                       COMPUTE WS-FEE-ASSESSED(WS-FEE-IDX) =
                           WS-FEE-BASE-AMT(WS-FEE-IDX)
                           * WS-FEE-COUNT(WS-FEE-IDX)
                   WHEN WS-TIER-PREFERRED
                       COMPUTE WS-FEE-ASSESSED(WS-FEE-IDX)
                           ROUNDED =
                           WS-FEE-BASE-AMT(WS-FEE-IDX)
                           * WS-FEE-COUNT(WS-FEE-IDX)
                           * 0.75
                   WHEN WS-TIER-PREMIUM
                       COMPUTE WS-FEE-ASSESSED(WS-FEE-IDX)
                           ROUNDED =
                           WS-FEE-BASE-AMT(WS-FEE-IDX)
                           * WS-FEE-COUNT(WS-FEE-IDX)
                           * 0.50
                   WHEN WS-TIER-PRIVATE
                       MOVE 0
                           TO WS-FEE-ASSESSED(WS-FEE-IDX)
                       MOVE 1
                           TO WS-FEE-WAIVED(WS-FEE-IDX)
               END-EVALUATE
               ADD WS-FEE-ASSESSED(WS-FEE-IDX)
                   TO WS-GROSS-FEES
           END-PERFORM.

       4000-CHECK-WAIVERS.
           IF WS-RELATIONSHIP-BAL >= WS-WAIVER-THRESHOLD
               MOVE 1 TO WS-RELATIONSHIP-WAIVER
           END-IF
           IF WS-RELATIONSHIP-WAIVER = 1
               IF WS-FEE-ASSESSED(1) > 0
                   ADD WS-FEE-ASSESSED(1)
                       TO WS-FEES-WAIVED
                   MOVE 0 TO WS-FEE-ASSESSED(1)
                   MOVE 1 TO WS-FEE-WAIVED(1)
                   ADD 1 TO WS-WAIVED-COUNT
               END-IF
           END-IF
           MOVE 0 TO WS-DISCOUNT-PCT
           IF WS-SENIOR-DISCOUNT = 1
               ADD 10.00 TO WS-DISCOUNT-PCT
           END-IF
           IF WS-MILITARY-DISCOUNT = 1
               ADD 15.00 TO WS-DISCOUNT-PCT
           END-IF.

       5000-CALCULATE-NET.
           MOVE 0 TO WS-WORK-TOTAL
           PERFORM VARYING WS-FEE-IDX FROM 1 BY 1
               UNTIL WS-FEE-IDX > WS-FEE-COUNT-LOADED
               IF WS-FEE-WAIVED(WS-FEE-IDX) = 0
                   ADD WS-FEE-ASSESSED(WS-FEE-IDX)
                       TO WS-WORK-TOTAL
               END-IF
           END-PERFORM
           IF WS-DISCOUNT-PCT > 0
               COMPUTE WS-DISCOUNT-AMT ROUNDED =
                   WS-WORK-TOTAL * WS-DISCOUNT-PCT / 100
           ELSE
               MOVE 0 TO WS-DISCOUNT-AMT
           END-IF
           COMPUTE WS-NET-FEES =
               WS-WORK-TOTAL - WS-DISCOUNT-AMT.

       6000-DISPLAY-ASSESSMENT.
           DISPLAY "========================================"
           DISPLAY "   FEE ASSESSMENT REPORT"
           DISPLAY "========================================"
           DISPLAY "ACCOUNT: " WS-ACCOUNT-NUM
           PERFORM VARYING WS-FEE-IDX FROM 1 BY 1
               UNTIL WS-FEE-IDX > WS-FEE-COUNT-LOADED
               MOVE WS-FEE-ASSESSED(WS-FEE-IDX)
                   TO WS-DISP-AMT
               IF WS-FEE-WAIVED(WS-FEE-IDX) = 1
                   STRING WS-FEE-DESC(WS-FEE-IDX)
                       " WAIVED"
                       DELIMITED BY SIZE
                       INTO WS-FEE-LINE
                   DISPLAY WS-FEE-LINE
               ELSE
                   DISPLAY WS-FEE-DESC(WS-FEE-IDX)
                       " " WS-DISP-AMT
               END-IF
           END-PERFORM
           DISPLAY "--- TOTALS ---"
           MOVE WS-GROSS-FEES TO WS-DISP-TOTAL
           DISPLAY "GROSS FEES:  " WS-DISP-TOTAL
           MOVE WS-FEES-WAIVED TO WS-DISP-TOTAL
           DISPLAY "WAIVED:      " WS-DISP-TOTAL
           MOVE WS-DISCOUNT-AMT TO WS-DISP-TOTAL
           DISPLAY "DISCOUNT:    " WS-DISP-TOTAL
           MOVE WS-NET-FEES TO WS-DISP-TOTAL
           DISPLAY "NET FEES:    " WS-DISP-TOTAL
           DISPLAY "========================================".
