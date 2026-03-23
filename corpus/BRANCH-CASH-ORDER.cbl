       IDENTIFICATION DIVISION.
       PROGRAM-ID. BRANCH-CASH-ORDER.
      *================================================================*
      * Branch Cash Order Processing                                   *
      * Generates denomination-specific cash orders based on teller    *
      * drawer needs, vault reserves, and upcoming payroll dates.      *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- Branch Info ---
       01  WS-BRANCH-ID              PIC X(6).
       01  WS-ORDER-DATE             PIC 9(8).
       01  WS-DELIVERY-DATE          PIC 9(8).
      *--- Teller Drawer Needs ---
       01  WS-DRAWER-TABLE.
           05  WS-DRAWER-ENTRY OCCURS 6 TIMES.
               10  WS-DRW-TELLER     PIC X(8).
               10  WS-DRW-CURRENT    PIC S9(7)V99 COMP-3.
               10  WS-DRW-TARGET     PIC S9(7)V99 COMP-3.
               10  WS-DRW-NEED       PIC S9(7)V99 COMP-3.
       01  WS-DRW-IDX                PIC 9(3).
       01  WS-DRW-COUNT              PIC 9(3).
      *--- Denomination Order ---
       01  WS-DENOM-ORDER.
           05  WS-DENOM-LINE OCCURS 7 TIMES.
               10  WS-ORD-DENOM      PIC 9(5).
               10  WS-ORD-QUANTITY   PIC S9(7) COMP-3.
               10  WS-ORD-VALUE      PIC S9(9)V99 COMP-3.
       01  WS-ORD-IDX                PIC 9(3).
      *--- Payroll Adjustment ---
       01  WS-IS-PAYROLL-WEEK        PIC 9.
           88  WS-PAYROLL-WEEK       VALUE 1.
           88  WS-NORMAL-WEEK        VALUE 0.
       01  WS-PAYROLL-MULTIPLIER     PIC S9(3)V99 COMP-3.
      *--- Totals ---
       01  WS-DRAWER-TOTAL-NEED      PIC S9(9)V99 COMP-3.
       01  WS-ORDER-TOTAL            PIC S9(9)V99 COMP-3.
       01  WS-ADJUSTED-TOTAL         PIC S9(9)V99 COMP-3.
       01  WS-VAULT-RESERVE          PIC S9(11)V99 COMP-3.
       01  WS-VAULT-AFTER            PIC S9(11)V99 COMP-3.
      *--- Validation ---
       01  WS-MAX-ORDER              PIC S9(9)V99 COMP-3.
       01  WS-ORDER-VALID            PIC 9.
           88  WS-ORDER-OK           VALUE 1.
           88  WS-ORDER-EXCEED       VALUE 0.
      *--- Display ---
       01  WS-DISP-AMT               PIC -$$$,$$$,$$9.99.
       01  WS-DISP-QTY               PIC ZZZ,ZZ9.
       01  WS-DISP-CT                PIC ZZ9.
      *--- Work ---
       01  WS-WORK-AMT               PIC S9(9)V99 COMP-3.
       01  WS-WORK-QTY               PIC S9(7) COMP-3.
       01  WS-TELLER-TALLY           PIC S9(3) COMP-3.

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-ASSESS-DRAWER-NEEDS
           PERFORM 3000-BUILD-DENOM-ORDER
           PERFORM 4000-APPLY-PAYROLL-ADJUST
           PERFORM 5000-VALIDATE-ORDER
           PERFORM 6000-DISPLAY-ORDER
           STOP RUN.

       1000-INITIALIZE.
           MOVE "BR0042" TO WS-BRANCH-ID
           ACCEPT WS-ORDER-DATE FROM DATE YYYYMMDD
           MOVE 1 TO WS-IS-PAYROLL-WEEK
           MOVE 1.35 TO WS-PAYROLL-MULTIPLIER
           MOVE 500000.00 TO WS-VAULT-RESERVE
           MOVE 250000.00 TO WS-MAX-ORDER
           MOVE 0 TO WS-DRAWER-TOTAL-NEED
           MOVE 0 TO WS-ORDER-TOTAL
           MOVE 4 TO WS-DRW-COUNT
           MOVE "TLR00101" TO WS-DRW-TELLER(1)
           MOVE 3500.00 TO WS-DRW-CURRENT(1)
           MOVE 10000.00 TO WS-DRW-TARGET(1)
           MOVE "TLR00102" TO WS-DRW-TELLER(2)
           MOVE 5200.00 TO WS-DRW-CURRENT(2)
           MOVE 10000.00 TO WS-DRW-TARGET(2)
           MOVE "TLR00103" TO WS-DRW-TELLER(3)
           MOVE 1800.00 TO WS-DRW-CURRENT(3)
           MOVE 10000.00 TO WS-DRW-TARGET(3)
           MOVE "TLR00104" TO WS-DRW-TELLER(4)
           MOVE 7500.00 TO WS-DRW-CURRENT(4)
           MOVE 10000.00 TO WS-DRW-TARGET(4)
           MOVE 100 TO WS-ORD-DENOM(1)
           MOVE 50  TO WS-ORD-DENOM(2)
           MOVE 20  TO WS-ORD-DENOM(3)
           MOVE 10  TO WS-ORD-DENOM(4)
           MOVE 5   TO WS-ORD-DENOM(5)
           MOVE 2   TO WS-ORD-DENOM(6)
           MOVE 1   TO WS-ORD-DENOM(7).

       2000-ASSESS-DRAWER-NEEDS.
           PERFORM VARYING WS-DRW-IDX FROM 1 BY 1
               UNTIL WS-DRW-IDX > WS-DRW-COUNT
               COMPUTE WS-DRW-NEED(WS-DRW-IDX) =
                   WS-DRW-TARGET(WS-DRW-IDX)
                   - WS-DRW-CURRENT(WS-DRW-IDX)
               IF WS-DRW-NEED(WS-DRW-IDX) < 0
                   MOVE 0 TO WS-DRW-NEED(WS-DRW-IDX)
               END-IF
               ADD WS-DRW-NEED(WS-DRW-IDX)
                   TO WS-DRAWER-TOTAL-NEED
           END-PERFORM.

       3000-BUILD-DENOM-ORDER.
           COMPUTE WS-ORD-QUANTITY(1) =
               WS-DRAWER-TOTAL-NEED * 40 / 100
               / WS-ORD-DENOM(1)
           COMPUTE WS-ORD-QUANTITY(2) =
               WS-DRAWER-TOTAL-NEED * 25 / 100
               / WS-ORD-DENOM(2)
           COMPUTE WS-ORD-QUANTITY(3) =
               WS-DRAWER-TOTAL-NEED * 20 / 100
               / WS-ORD-DENOM(3)
           COMPUTE WS-ORD-QUANTITY(4) =
               WS-DRAWER-TOTAL-NEED * 8 / 100
               / WS-ORD-DENOM(4)
           COMPUTE WS-ORD-QUANTITY(5) =
               WS-DRAWER-TOTAL-NEED * 4 / 100
               / WS-ORD-DENOM(5)
           COMPUTE WS-ORD-QUANTITY(6) =
               WS-DRAWER-TOTAL-NEED * 2 / 100
               / WS-ORD-DENOM(6)
           COMPUTE WS-ORD-QUANTITY(7) =
               WS-DRAWER-TOTAL-NEED * 1 / 100
               / WS-ORD-DENOM(7)
           PERFORM VARYING WS-ORD-IDX FROM 1 BY 1
               UNTIL WS-ORD-IDX > 7
               COMPUTE WS-ORD-VALUE(WS-ORD-IDX) =
                   WS-ORD-QUANTITY(WS-ORD-IDX)
                   * WS-ORD-DENOM(WS-ORD-IDX)
               ADD WS-ORD-VALUE(WS-ORD-IDX)
                   TO WS-ORDER-TOTAL
           END-PERFORM.

       4000-APPLY-PAYROLL-ADJUST.
           IF WS-PAYROLL-WEEK
               COMPUTE WS-ADJUSTED-TOTAL ROUNDED =
                   WS-ORDER-TOTAL * WS-PAYROLL-MULTIPLIER
           ELSE
               MOVE WS-ORDER-TOTAL TO WS-ADJUSTED-TOTAL
           END-IF.

       5000-VALIDATE-ORDER.
           IF WS-ADJUSTED-TOTAL > WS-MAX-ORDER
               MOVE 0 TO WS-ORDER-VALID
           ELSE
               MOVE 1 TO WS-ORDER-VALID
           END-IF
           COMPUTE WS-VAULT-AFTER =
               WS-VAULT-RESERVE - WS-ADJUSTED-TOTAL.

       6000-DISPLAY-ORDER.
           DISPLAY "========================================"
           DISPLAY "   BRANCH CASH ORDER"
           DISPLAY "========================================"
           DISPLAY "BRANCH: " WS-BRANCH-ID
           DISPLAY "--- TELLER NEEDS ---"
           PERFORM VARYING WS-DRW-IDX FROM 1 BY 1
               UNTIL WS-DRW-IDX > WS-DRW-COUNT
               MOVE 0 TO WS-TELLER-TALLY
               INSPECT WS-DRW-TELLER(WS-DRW-IDX)
                   TALLYING WS-TELLER-TALLY
                   FOR ALL "0"
               MOVE WS-DRW-NEED(WS-DRW-IDX) TO WS-DISP-AMT
               DISPLAY WS-DRW-TELLER(WS-DRW-IDX)
                   " NEED: " WS-DISP-AMT
           END-PERFORM
           DISPLAY "--- DENOMINATION ORDER ---"
           PERFORM VARYING WS-ORD-IDX FROM 1 BY 1
               UNTIL WS-ORD-IDX > 7
               MOVE WS-ORD-QUANTITY(WS-ORD-IDX)
                   TO WS-DISP-QTY
               MOVE WS-ORD-VALUE(WS-ORD-IDX)
                   TO WS-DISP-AMT
               DISPLAY "$" WS-ORD-DENOM(WS-ORD-IDX)
                   " x " WS-DISP-QTY
                   " = " WS-DISP-AMT
           END-PERFORM
           MOVE WS-ADJUSTED-TOTAL TO WS-DISP-AMT
           DISPLAY "ADJUSTED ORDER:" WS-DISP-AMT
           IF WS-ORDER-EXCEED
               DISPLAY "*** EXCEEDS MAX ORDER LIMIT ***"
           END-IF
           DISPLAY "========================================".
