       IDENTIFICATION DIVISION.
       PROGRAM-ID. CASH-MGMT-ENGINE.
      *================================================================*
      * Branch Cash Management Engine                                  *
      * Forecasts daily cash needs, manages armored car schedules,     *
      * optimizes denomination mix across ATMs and teller drawers.     *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- Branch Parameters ---
       01  WS-BRANCH-NUM              PIC X(6).
       01  WS-FORECAST-DATE           PIC 9(8).
       01  WS-DAY-OF-WEEK             PIC 9.
           88  WS-WEEKDAY             VALUE 1 THRU 5.
           88  WS-SATURDAY            VALUE 6.
           88  WS-SUNDAY              VALUE 7.
      *--- Historical Averages (5 days) ---
       01  WS-HIST-TABLE.
           05  WS-HIST-ENTRY OCCURS 5 TIMES.
               10  WS-HIST-INFLOW     PIC S9(9)V99 COMP-3.
               10  WS-HIST-OUTFLOW    PIC S9(9)V99 COMP-3.
               10  WS-HIST-NET        PIC S9(9)V99 COMP-3.
       01  WS-HIST-IDX                PIC 9(3).
      *--- Forecast Fields ---
       01  WS-AVG-INFLOW              PIC S9(9)V99 COMP-3.
       01  WS-AVG-OUTFLOW             PIC S9(9)V99 COMP-3.
       01  WS-SUM-INFLOW              PIC S9(11)V99 COMP-3.
       01  WS-SUM-OUTFLOW             PIC S9(11)V99 COMP-3.
       01  WS-FORECAST-NET            PIC S9(9)V99 COMP-3.
       01  WS-SEASONAL-FACTOR         PIC S9(3)V9(4) COMP-3.
       01  WS-ADJUSTED-FORECAST       PIC S9(9)V99 COMP-3.
      *--- Current Cash Position ---
       01  WS-VAULT-CASH              PIC S9(11)V99 COMP-3.
       01  WS-TELLER-CASH             PIC S9(9)V99 COMP-3.
       01  WS-ATM-CASH                PIC S9(9)V99 COMP-3.
       01  WS-TOTAL-ON-HAND           PIC S9(11)V99 COMP-3.
       01  WS-PROJECTED-EOD           PIC S9(11)V99 COMP-3.
      *--- Target Levels ---
       01  WS-TARGET-LEVEL            PIC S9(11)V99 COMP-3.
       01  WS-BUFFER-PCT              PIC S9(3)V99 COMP-3.
       01  WS-BUFFER-AMT              PIC S9(9)V99 COMP-3.
       01  WS-TARGET-WITH-BUFFER      PIC S9(11)V99 COMP-3.
       01  WS-SHORTFALL               PIC S9(11)V99 COMP-3.
       01  WS-SURPLUS                 PIC S9(11)V99 COMP-3.
      *--- Armored Car ---
       01  WS-DELIVERY-NEEDED         PIC 9.
       01  WS-DELIVERY-AMOUNT         PIC S9(9)V99 COMP-3.
       01  WS-PICKUP-AMOUNT           PIC S9(9)V99 COMP-3.
       01  WS-DELIVERY-COST           PIC S9(5)V99 COMP-3.
       01  WS-COST-PER-TRIP           PIC S9(5)V99 COMP-3.
      *--- ATM Replenishment ---
       01  WS-ATM-TABLE.
           05  WS-ATM-ENTRY OCCURS 3 TIMES.
               10  WS-ATM-ID          PIC X(8).
               10  WS-ATM-CURRENT     PIC S9(9)V99 COMP-3.
               10  WS-ATM-CAPACITY    PIC S9(9)V99 COMP-3.
               10  WS-ATM-FILL-AMT    PIC S9(9)V99 COMP-3.
       01  WS-ATM-IDX                 PIC 9(3).
       01  WS-ATM-FILL-TOTAL          PIC S9(9)V99 COMP-3.
       01  WS-ATM-FILL-PCT            PIC S9(3)V99 COMP-3.
      *--- Display ---
       01  WS-DISP-AMT                PIC -$$$,$$$,$$9.99.
       01  WS-DISP-PCT                PIC ZZ9.99.
      *--- Work Fields ---
       01  WS-WORK-AMT                PIC S9(11)V99 COMP-3.
       01  WS-COUNT-DAYS              PIC S9(3) COMP-3.

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-COMPUTE-AVERAGES
           PERFORM 3000-APPLY-SEASONAL
           PERFORM 4000-PROJECT-POSITION
           PERFORM 5000-CHECK-ATM-LEVELS
           PERFORM 6000-DETERMINE-DELIVERY
           PERFORM 7000-DISPLAY-FORECAST
           STOP RUN.

       1000-INITIALIZE.
           MOVE "BR0042" TO WS-BRANCH-NUM
           ACCEPT WS-FORECAST-DATE FROM DATE YYYYMMDD
           MOVE 2 TO WS-DAY-OF-WEEK
           MOVE 500000.00 TO WS-VAULT-CASH
           MOVE 80000.00 TO WS-TELLER-CASH
           MOVE 120000.00 TO WS-ATM-CASH
           MOVE 350000.00 TO WS-TARGET-LEVEL
           MOVE 15.00 TO WS-BUFFER-PCT
           MOVE 275.00 TO WS-COST-PER-TRIP
           MOVE 0 TO WS-ATM-FILL-TOTAL
           MOVE 5 TO WS-COUNT-DAYS
           MOVE 1.00 TO WS-SEASONAL-FACTOR
           MOVE 120000.00 TO WS-HIST-INFLOW(1)
           MOVE 95000.00 TO WS-HIST-OUTFLOW(1)
           MOVE 135000.00 TO WS-HIST-INFLOW(2)
           MOVE 110000.00 TO WS-HIST-OUTFLOW(2)
           MOVE 98000.00 TO WS-HIST-INFLOW(3)
           MOVE 88000.00 TO WS-HIST-OUTFLOW(3)
           MOVE 145000.00 TO WS-HIST-INFLOW(4)
           MOVE 125000.00 TO WS-HIST-OUTFLOW(4)
           MOVE 112000.00 TO WS-HIST-INFLOW(5)
           MOVE 105000.00 TO WS-HIST-OUTFLOW(5)
           MOVE "ATM-0001" TO WS-ATM-ID(1)
           MOVE 25000.00 TO WS-ATM-CURRENT(1)
           MOVE 80000.00 TO WS-ATM-CAPACITY(1)
           MOVE "ATM-0002" TO WS-ATM-ID(2)
           MOVE 15000.00 TO WS-ATM-CURRENT(2)
           MOVE 60000.00 TO WS-ATM-CAPACITY(2)
           MOVE "ATM-0003" TO WS-ATM-ID(3)
           MOVE 45000.00 TO WS-ATM-CURRENT(3)
           MOVE 80000.00 TO WS-ATM-CAPACITY(3).

       2000-COMPUTE-AVERAGES.
           MOVE 0 TO WS-SUM-INFLOW
           MOVE 0 TO WS-SUM-OUTFLOW
           PERFORM VARYING WS-HIST-IDX FROM 1 BY 1
               UNTIL WS-HIST-IDX > WS-COUNT-DAYS
               COMPUTE WS-HIST-NET(WS-HIST-IDX) =
                   WS-HIST-INFLOW(WS-HIST-IDX)
                   - WS-HIST-OUTFLOW(WS-HIST-IDX)
               ADD WS-HIST-INFLOW(WS-HIST-IDX)
                   TO WS-SUM-INFLOW
               ADD WS-HIST-OUTFLOW(WS-HIST-IDX)
                   TO WS-SUM-OUTFLOW
           END-PERFORM
           COMPUTE WS-AVG-INFLOW ROUNDED =
               WS-SUM-INFLOW / WS-COUNT-DAYS
           COMPUTE WS-AVG-OUTFLOW ROUNDED =
               WS-SUM-OUTFLOW / WS-COUNT-DAYS.

       3000-APPLY-SEASONAL.
           EVALUATE TRUE
               WHEN WS-SATURDAY
                   MOVE 0.60 TO WS-SEASONAL-FACTOR
               WHEN WS-SUNDAY
                   MOVE 0.20 TO WS-SEASONAL-FACTOR
               WHEN OTHER
                   MOVE 1.00 TO WS-SEASONAL-FACTOR
           END-EVALUATE
           COMPUTE WS-FORECAST-NET ROUNDED =
               (WS-AVG-INFLOW - WS-AVG-OUTFLOW)
               * WS-SEASONAL-FACTOR
           MOVE WS-FORECAST-NET TO WS-ADJUSTED-FORECAST.

       4000-PROJECT-POSITION.
           COMPUTE WS-TOTAL-ON-HAND =
               WS-VAULT-CASH + WS-TELLER-CASH + WS-ATM-CASH
           COMPUTE WS-PROJECTED-EOD =
               WS-TOTAL-ON-HAND + WS-ADJUSTED-FORECAST
           COMPUTE WS-BUFFER-AMT ROUNDED =
               WS-TARGET-LEVEL * WS-BUFFER-PCT / 100
           COMPUTE WS-TARGET-WITH-BUFFER =
               WS-TARGET-LEVEL + WS-BUFFER-AMT
           MOVE 0 TO WS-SHORTFALL
           MOVE 0 TO WS-SURPLUS
           IF WS-PROJECTED-EOD < WS-TARGET-LEVEL
               COMPUTE WS-SHORTFALL =
                   WS-TARGET-WITH-BUFFER - WS-PROJECTED-EOD
           END-IF
           IF WS-PROJECTED-EOD > WS-TARGET-WITH-BUFFER
               COMPUTE WS-SURPLUS =
                   WS-PROJECTED-EOD - WS-TARGET-WITH-BUFFER
           END-IF.

       5000-CHECK-ATM-LEVELS.
           PERFORM VARYING WS-ATM-IDX FROM 1 BY 1
               UNTIL WS-ATM-IDX > 3
               COMPUTE WS-ATM-FILL-PCT ROUNDED =
                   WS-ATM-CURRENT(WS-ATM-IDX)
                   / WS-ATM-CAPACITY(WS-ATM-IDX) * 100
               IF WS-ATM-FILL-PCT < 40
                   COMPUTE WS-ATM-FILL-AMT(WS-ATM-IDX) =
                       WS-ATM-CAPACITY(WS-ATM-IDX)
                       - WS-ATM-CURRENT(WS-ATM-IDX)
                   ADD WS-ATM-FILL-AMT(WS-ATM-IDX)
                       TO WS-ATM-FILL-TOTAL
               ELSE
                   MOVE 0 TO WS-ATM-FILL-AMT(WS-ATM-IDX)
               END-IF
           END-PERFORM.

       6000-DETERMINE-DELIVERY.
           MOVE 0 TO WS-DELIVERY-NEEDED
           IF WS-SHORTFALL > 0
               MOVE 1 TO WS-DELIVERY-NEEDED
               COMPUTE WS-DELIVERY-AMOUNT =
                   WS-SHORTFALL + WS-ATM-FILL-TOTAL
               MOVE WS-COST-PER-TRIP TO WS-DELIVERY-COST
           ELSE IF WS-ATM-FILL-TOTAL > 0
               MOVE 1 TO WS-DELIVERY-NEEDED
               MOVE WS-ATM-FILL-TOTAL
                   TO WS-DELIVERY-AMOUNT
               MOVE WS-COST-PER-TRIP TO WS-DELIVERY-COST
           END-IF
           IF WS-SURPLUS > 50000.00
               MOVE WS-SURPLUS TO WS-PICKUP-AMOUNT
           END-IF.

       7000-DISPLAY-FORECAST.
           DISPLAY "========================================"
           DISPLAY "   CASH MANAGEMENT FORECAST"
           DISPLAY "========================================"
           DISPLAY "BRANCH: " WS-BRANCH-NUM
           MOVE WS-TOTAL-ON-HAND TO WS-DISP-AMT
           DISPLAY "ON HAND:   " WS-DISP-AMT
           MOVE WS-ADJUSTED-FORECAST TO WS-DISP-AMT
           DISPLAY "FORECAST:  " WS-DISP-AMT
           MOVE WS-PROJECTED-EOD TO WS-DISP-AMT
           DISPLAY "PROJ EOD:  " WS-DISP-AMT
           MOVE WS-TARGET-LEVEL TO WS-DISP-AMT
           DISPLAY "TARGET:    " WS-DISP-AMT
           IF WS-DELIVERY-NEEDED = 1
               MOVE WS-DELIVERY-AMOUNT TO WS-DISP-AMT
               DISPLAY "ORDER:     " WS-DISP-AMT
           END-IF
           DISPLAY "========================================".
