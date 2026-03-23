       IDENTIFICATION DIVISION.
       PROGRAM-ID. ATM-CASH-REPLEN.
      *================================================================*
      * ATM Cash Replenishment Scheduler                               *
      * Analyzes ATM usage patterns, predicts depletion dates,         *
      * generates replenishment orders by denomination.                *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- ATM Fleet Table ---
       01  WS-ATM-FLEET.
           05  WS-ATM-UNIT OCCURS 5 TIMES.
               10  WS-ATM-ID          PIC X(8).
               10  WS-ATM-LOCATION    PIC X(20).
               10  WS-ATM-BALANCE     PIC S9(9)V99 COMP-3.
               10  WS-ATM-CAPACITY    PIC S9(9)V99 COMP-3.
               10  WS-ATM-DAILY-AVG   PIC S9(7)V99 COMP-3.
               10  WS-ATM-DAYS-LEFT   PIC S9(3) COMP-3.
               10  WS-ATM-PRIORITY    PIC 9.
               10  WS-ATM-ORDER-AMT   PIC S9(9)V99 COMP-3.
       01  WS-ATM-IDX                 PIC 9(3).
       01  WS-ATM-COUNT               PIC 9(3).
      *--- Priority Levels ---
       01  WS-PRIORITY-VAL            PIC 9.
           88  WS-PRI-CRITICAL        VALUE 1.
           88  WS-PRI-URGENT          VALUE 2.
           88  WS-PRI-NORMAL          VALUE 3.
           88  WS-PRI-LOW             VALUE 4.
      *--- Thresholds ---
       01  WS-CRITICAL-DAYS           PIC S9(3) COMP-3.
       01  WS-URGENT-DAYS             PIC S9(3) COMP-3.
       01  WS-FILL-TARGET-PCT         PIC S9(3)V99 COMP-3.
      *--- Totals ---
       01  WS-TOTAL-ORDER             PIC S9(11)V99 COMP-3.
       01  WS-TOTAL-ON-HAND           PIC S9(11)V99 COMP-3.
       01  WS-TOTAL-CAPACITY          PIC S9(11)V99 COMP-3.
       01  WS-FLEET-FILL-PCT          PIC S9(3)V99 COMP-3.
      *--- Schedule ---
       01  WS-CURRENT-DATE            PIC 9(8).
       01  WS-NEXT-SERVICE-DATE       PIC 9(8).
       01  WS-CRITICAL-COUNT          PIC S9(3) COMP-3.
       01  WS-URGENT-COUNT            PIC S9(3) COMP-3.
       01  WS-NORMAL-COUNT            PIC S9(3) COMP-3.
      *--- Display ---
       01  WS-DISP-AMT                PIC -$$$,$$$,$$9.99.
       01  WS-DISP-PCT                PIC ZZ9.99.
       01  WS-DISP-DAYS               PIC ZZ9.
      *--- Work ---
       01  WS-WORK-PCT                PIC S9(3)V99 COMP-3.
       01  WS-FILL-AMT                PIC S9(9)V99 COMP-3.
       01  WS-ATM-NAME-TALLY          PIC S9(3) COMP-3.

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-ANALYZE-FLEET
           PERFORM 3000-GENERATE-ORDERS
           PERFORM 4000-COMPUTE-FLEET-STATS
           PERFORM 5000-DISPLAY-SCHEDULE
           STOP RUN.

       1000-INITIALIZE.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           MOVE 1 TO WS-CRITICAL-DAYS
           MOVE 3 TO WS-URGENT-DAYS
           MOVE 85.00 TO WS-FILL-TARGET-PCT
           MOVE 0 TO WS-TOTAL-ORDER
           MOVE 0 TO WS-TOTAL-ON-HAND
           MOVE 0 TO WS-TOTAL-CAPACITY
           MOVE 0 TO WS-CRITICAL-COUNT
           MOVE 0 TO WS-URGENT-COUNT
           MOVE 0 TO WS-NORMAL-COUNT
           MOVE 5 TO WS-ATM-COUNT
           MOVE "ATM-1001" TO WS-ATM-ID(1)
           MOVE "MAIN LOBBY" TO WS-ATM-LOCATION(1)
           MOVE 12500.00 TO WS-ATM-BALANCE(1)
           MOVE 80000.00 TO WS-ATM-CAPACITY(1)
           MOVE 8500.00 TO WS-ATM-DAILY-AVG(1)
           MOVE "ATM-1002" TO WS-ATM-ID(2)
           MOVE "DRIVE-THRU" TO WS-ATM-LOCATION(2)
           MOVE 35000.00 TO WS-ATM-BALANCE(2)
           MOVE 60000.00 TO WS-ATM-CAPACITY(2)
           MOVE 5200.00 TO WS-ATM-DAILY-AVG(2)
           MOVE "ATM-1003" TO WS-ATM-ID(3)
           MOVE "MALL KIOSK" TO WS-ATM-LOCATION(3)
           MOVE 5000.00 TO WS-ATM-BALANCE(3)
           MOVE 40000.00 TO WS-ATM-CAPACITY(3)
           MOVE 7800.00 TO WS-ATM-DAILY-AVG(3)
           MOVE "ATM-1004" TO WS-ATM-ID(4)
           MOVE "GROCERY STORE" TO WS-ATM-LOCATION(4)
           MOVE 42000.00 TO WS-ATM-BALANCE(4)
           MOVE 60000.00 TO WS-ATM-CAPACITY(4)
           MOVE 3100.00 TO WS-ATM-DAILY-AVG(4)
           MOVE "ATM-1005" TO WS-ATM-ID(5)
           MOVE "HOSPITAL" TO WS-ATM-LOCATION(5)
           MOVE 18000.00 TO WS-ATM-BALANCE(5)
           MOVE 40000.00 TO WS-ATM-CAPACITY(5)
           MOVE 4500.00 TO WS-ATM-DAILY-AVG(5).

       2000-ANALYZE-FLEET.
           PERFORM VARYING WS-ATM-IDX FROM 1 BY 1
               UNTIL WS-ATM-IDX > WS-ATM-COUNT
               IF WS-ATM-DAILY-AVG(WS-ATM-IDX) > 0
                   COMPUTE WS-ATM-DAYS-LEFT(WS-ATM-IDX) =
                       WS-ATM-BALANCE(WS-ATM-IDX)
                       / WS-ATM-DAILY-AVG(WS-ATM-IDX)
               ELSE
                   MOVE 999 TO WS-ATM-DAYS-LEFT(WS-ATM-IDX)
               END-IF
               EVALUATE TRUE
                   WHEN WS-ATM-DAYS-LEFT(WS-ATM-IDX)
                       <= WS-CRITICAL-DAYS
                       MOVE 1 TO WS-ATM-PRIORITY(WS-ATM-IDX)
                       ADD 1 TO WS-CRITICAL-COUNT
                   WHEN WS-ATM-DAYS-LEFT(WS-ATM-IDX)
                       <= WS-URGENT-DAYS
                       MOVE 2 TO WS-ATM-PRIORITY(WS-ATM-IDX)
                       ADD 1 TO WS-URGENT-COUNT
                   WHEN OTHER
                       MOVE 3 TO WS-ATM-PRIORITY(WS-ATM-IDX)
                       ADD 1 TO WS-NORMAL-COUNT
               END-EVALUATE
               ADD WS-ATM-BALANCE(WS-ATM-IDX)
                   TO WS-TOTAL-ON-HAND
               ADD WS-ATM-CAPACITY(WS-ATM-IDX)
                   TO WS-TOTAL-CAPACITY
           END-PERFORM.

       3000-GENERATE-ORDERS.
           PERFORM VARYING WS-ATM-IDX FROM 1 BY 1
               UNTIL WS-ATM-IDX > WS-ATM-COUNT
               IF WS-ATM-PRIORITY(WS-ATM-IDX) <= 2
                   COMPUTE WS-FILL-AMT ROUNDED =
                       WS-ATM-CAPACITY(WS-ATM-IDX)
                       * WS-FILL-TARGET-PCT / 100
                   COMPUTE WS-ATM-ORDER-AMT(WS-ATM-IDX) =
                       WS-FILL-AMT
                       - WS-ATM-BALANCE(WS-ATM-IDX)
                   IF WS-ATM-ORDER-AMT(WS-ATM-IDX) < 0
                       MOVE 0
                           TO WS-ATM-ORDER-AMT(WS-ATM-IDX)
                   END-IF
                   ADD WS-ATM-ORDER-AMT(WS-ATM-IDX)
                       TO WS-TOTAL-ORDER
               ELSE
                   MOVE 0 TO WS-ATM-ORDER-AMT(WS-ATM-IDX)
               END-IF
           END-PERFORM.

       4000-COMPUTE-FLEET-STATS.
           IF WS-TOTAL-CAPACITY > 0
               COMPUTE WS-FLEET-FILL-PCT ROUNDED =
                   WS-TOTAL-ON-HAND
                   / WS-TOTAL-CAPACITY * 100
           END-IF.

       5000-DISPLAY-SCHEDULE.
           DISPLAY "========================================"
           DISPLAY "   ATM REPLENISHMENT SCHEDULE"
           DISPLAY "========================================"
           PERFORM VARYING WS-ATM-IDX FROM 1 BY 1
               UNTIL WS-ATM-IDX > WS-ATM-COUNT
               MOVE 0 TO WS-ATM-NAME-TALLY
               INSPECT WS-ATM-LOCATION(WS-ATM-IDX)
                   TALLYING WS-ATM-NAME-TALLY
                   FOR ALL SPACES
               DISPLAY WS-ATM-ID(WS-ATM-IDX) " "
                   WS-ATM-LOCATION(WS-ATM-IDX)
               MOVE WS-ATM-BALANCE(WS-ATM-IDX)
                   TO WS-DISP-AMT
               DISPLAY "  BAL: " WS-DISP-AMT
               MOVE WS-ATM-DAYS-LEFT(WS-ATM-IDX)
                   TO WS-DISP-DAYS
               DISPLAY "  DAYS LEFT: " WS-DISP-DAYS
               IF WS-ATM-ORDER-AMT(WS-ATM-IDX) > 0
                   MOVE WS-ATM-ORDER-AMT(WS-ATM-IDX)
                       TO WS-DISP-AMT
                   DISPLAY "  ORDER: " WS-DISP-AMT
               END-IF
           END-PERFORM
           DISPLAY "--- FLEET SUMMARY ---"
           MOVE WS-FLEET-FILL-PCT TO WS-DISP-PCT
           DISPLAY "FLEET FILL:    " WS-DISP-PCT "%"
           MOVE WS-TOTAL-ORDER TO WS-DISP-AMT
           DISPLAY "TOTAL ORDER:   " WS-DISP-AMT
           DISPLAY "========================================".
