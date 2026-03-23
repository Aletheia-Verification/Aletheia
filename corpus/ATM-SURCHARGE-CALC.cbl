       IDENTIFICATION DIVISION.
       PROGRAM-ID. ATM-SURCHARGE-CALC.
      *================================================================*
      * ATM Surcharge and Interchange Calculator                       *
      * Computes surcharges for on-us/foreign transactions,            *
      * interchange fees, network assessments per card brand.          *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- Transaction Data ---
       01  WS-CARD-BIN                PIC 9(6).
       01  WS-CARD-NETWORK            PIC 9.
           88  WS-NET-VISA            VALUE 1.
           88  WS-NET-MASTERCARD      VALUE 2.
           88  WS-NET-DISCOVER        VALUE 3.
           88  WS-NET-AMEX            VALUE 4.
       01  WS-TXN-AMOUNT              PIC S9(7)V99 COMP-3.
       01  WS-IS-ON-US                PIC 9.
           88  WS-ON-US-YES           VALUE 1.
           88  WS-ON-US-NO            VALUE 0.
      *--- Fee Rate Table (per network) ---
       01  WS-RATE-TABLE.
           05  WS-RATE-ENTRY OCCURS 4 TIMES.
               10  WS-NET-NAME        PIC X(12).
               10  WS-INTERCHANGE-RT  PIC S9(3)V9(4) COMP-3.
               10  WS-ASSESS-RT       PIC S9(3)V9(4) COMP-3.
               10  WS-SWITCH-FEE      PIC S9(3)V99 COMP-3.
       01  WS-RATE-IDX                PIC 9(3).
      *--- Computed Fees ---
       01  WS-SURCHARGE               PIC S9(5)V99 COMP-3.
       01  WS-INTERCHANGE-FEE         PIC S9(5)V99 COMP-3.
       01  WS-ASSESSMENT-FEE          PIC S9(5)V99 COMP-3.
       01  WS-SWITCH-COST             PIC S9(5)V99 COMP-3.
       01  WS-TOTAL-COST              PIC S9(5)V99 COMP-3.
       01  WS-NET-REVENUE             PIC S9(5)V99 COMP-3.
      *--- Surcharge Schedule ---
       01  WS-ON-US-SURCHARGE         PIC S9(3)V99 COMP-3.
       01  WS-FOREIGN-SURCHARGE       PIC S9(3)V99 COMP-3.
       01  WS-INTL-SURCHARGE          PIC S9(3)V99 COMP-3.
       01  WS-IS-INTL                 PIC 9.
      *--- Batch Processing ---
       01  WS-BATCH-TABLE.
           05  WS-BATCH-ENTRY OCCURS 6 TIMES.
               10  WS-B-NETWORK       PIC 9.
               10  WS-B-ON-US         PIC 9.
               10  WS-B-AMOUNT        PIC S9(7)V99 COMP-3.
               10  WS-B-SURCHARGE     PIC S9(5)V99 COMP-3.
               10  WS-B-INTERCHANGE   PIC S9(5)V99 COMP-3.
               10  WS-B-TOTAL-FEE     PIC S9(5)V99 COMP-3.
       01  WS-B-IDX                   PIC 9(3).
       01  WS-B-COUNT                 PIC 9(3).
      *--- Accumulators ---
       01  WS-TOTAL-SURCHARGES        PIC S9(7)V99 COMP-3.
       01  WS-TOTAL-INTERCHANGE       PIC S9(7)V99 COMP-3.
       01  WS-TOTAL-REVENUE           PIC S9(7)V99 COMP-3.
       01  WS-TOTAL-COSTS             PIC S9(7)V99 COMP-3.
      *--- Display ---
       01  WS-DISP-AMT                PIC -$$,$$9.99.
       01  WS-DISP-TOTAL              PIC -$$$,$$9.99.
       01  WS-DISP-CT                 PIC ZZ9.
      *--- Work ---
       01  WS-WORK-RATE               PIC S9(3)V9(4) COMP-3.
       01  WS-BIN-TEXT                 PIC X(6).
       01  WS-BIN-TALLY               PIC S9(3) COMP-3.

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-RATES
           PERFORM 3000-LOAD-BATCH
           PERFORM 4000-PROCESS-BATCH
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.

       1000-INITIALIZE.
           MOVE 0.00 TO WS-ON-US-SURCHARGE
           MOVE 3.00 TO WS-FOREIGN-SURCHARGE
           MOVE 5.00 TO WS-INTL-SURCHARGE
           MOVE 0 TO WS-TOTAL-SURCHARGES
           MOVE 0 TO WS-TOTAL-INTERCHANGE
           MOVE 0 TO WS-TOTAL-REVENUE
           MOVE 0 TO WS-TOTAL-COSTS.

       2000-LOAD-RATES.
           MOVE "VISA" TO WS-NET-NAME(1)
           MOVE 0.0015 TO WS-INTERCHANGE-RT(1)
           MOVE 0.0005 TO WS-ASSESS-RT(1)
           MOVE 0.25 TO WS-SWITCH-FEE(1)
           MOVE "MASTERCARD" TO WS-NET-NAME(2)
           MOVE 0.0015 TO WS-INTERCHANGE-RT(2)
           MOVE 0.0004 TO WS-ASSESS-RT(2)
           MOVE 0.20 TO WS-SWITCH-FEE(2)
           MOVE "DISCOVER" TO WS-NET-NAME(3)
           MOVE 0.0010 TO WS-INTERCHANGE-RT(3)
           MOVE 0.0003 TO WS-ASSESS-RT(3)
           MOVE 0.15 TO WS-SWITCH-FEE(3)
           MOVE "AMEX" TO WS-NET-NAME(4)
           MOVE 0.0020 TO WS-INTERCHANGE-RT(4)
           MOVE 0.0006 TO WS-ASSESS-RT(4)
           MOVE 0.30 TO WS-SWITCH-FEE(4).

       3000-LOAD-BATCH.
           MOVE 6 TO WS-B-COUNT
           MOVE 1 TO WS-B-NETWORK(1)
           MOVE 0 TO WS-B-ON-US(1)
           MOVE 200.00 TO WS-B-AMOUNT(1)
           MOVE 2 TO WS-B-NETWORK(2)
           MOVE 1 TO WS-B-ON-US(2)
           MOVE 500.00 TO WS-B-AMOUNT(2)
           MOVE 1 TO WS-B-NETWORK(3)
           MOVE 0 TO WS-B-ON-US(3)
           MOVE 100.00 TO WS-B-AMOUNT(3)
           MOVE 3 TO WS-B-NETWORK(4)
           MOVE 0 TO WS-B-ON-US(4)
           MOVE 300.00 TO WS-B-AMOUNT(4)
           MOVE 4 TO WS-B-NETWORK(5)
           MOVE 0 TO WS-B-ON-US(5)
           MOVE 400.00 TO WS-B-AMOUNT(5)
           MOVE 2 TO WS-B-NETWORK(6)
           MOVE 0 TO WS-B-ON-US(6)
           MOVE 250.00 TO WS-B-AMOUNT(6).

       4000-PROCESS-BATCH.
           PERFORM VARYING WS-B-IDX FROM 1 BY 1
               UNTIL WS-B-IDX > WS-B-COUNT
               MOVE WS-B-NETWORK(WS-B-IDX) TO WS-RATE-IDX
               IF WS-B-ON-US(WS-B-IDX) = 1
                   MOVE WS-ON-US-SURCHARGE
                       TO WS-B-SURCHARGE(WS-B-IDX)
               ELSE
                   MOVE WS-FOREIGN-SURCHARGE
                       TO WS-B-SURCHARGE(WS-B-IDX)
               END-IF
               COMPUTE WS-B-INTERCHANGE(WS-B-IDX) ROUNDED =
                   WS-B-AMOUNT(WS-B-IDX)
                   * WS-INTERCHANGE-RT(WS-RATE-IDX)
               COMPUTE WS-ASSESSMENT-FEE ROUNDED =
                   WS-B-AMOUNT(WS-B-IDX)
                   * WS-ASSESS-RT(WS-RATE-IDX)
               COMPUTE WS-B-TOTAL-FEE(WS-B-IDX) =
                   WS-B-INTERCHANGE(WS-B-IDX)
                   + WS-ASSESSMENT-FEE
                   + WS-SWITCH-FEE(WS-RATE-IDX)
               ADD WS-B-SURCHARGE(WS-B-IDX)
                   TO WS-TOTAL-SURCHARGES
               ADD WS-B-INTERCHANGE(WS-B-IDX)
                   TO WS-TOTAL-INTERCHANGE
               ADD WS-B-TOTAL-FEE(WS-B-IDX)
                   TO WS-TOTAL-COSTS
           END-PERFORM
           COMPUTE WS-TOTAL-REVENUE =
               WS-TOTAL-SURCHARGES + WS-TOTAL-INTERCHANGE
               - WS-TOTAL-COSTS.

       5000-DISPLAY-RESULTS.
           DISPLAY "========================================"
           DISPLAY "   ATM FEE ANALYSIS"
           DISPLAY "========================================"
           PERFORM VARYING WS-B-IDX FROM 1 BY 1
               UNTIL WS-B-IDX > WS-B-COUNT
               MOVE WS-B-NETWORK(WS-B-IDX) TO WS-RATE-IDX
               MOVE WS-B-AMOUNT(WS-B-IDX) TO WS-DISP-AMT
               DISPLAY WS-NET-NAME(WS-RATE-IDX)
                   " " WS-DISP-AMT
               MOVE WS-B-SURCHARGE(WS-B-IDX)
                   TO WS-DISP-AMT
               DISPLAY "  SURCHARGE: " WS-DISP-AMT
               MOVE WS-B-TOTAL-FEE(WS-B-IDX)
                   TO WS-DISP-AMT
               DISPLAY "  COST:      " WS-DISP-AMT
           END-PERFORM
           DISPLAY "--- TOTALS ---"
           MOVE WS-TOTAL-SURCHARGES TO WS-DISP-TOTAL
           DISPLAY "SURCHARGES:  " WS-DISP-TOTAL
           MOVE WS-TOTAL-INTERCHANGE TO WS-DISP-TOTAL
           DISPLAY "INTERCHANGE: " WS-DISP-TOTAL
           MOVE WS-TOTAL-COSTS TO WS-DISP-TOTAL
           DISPLAY "COSTS:       " WS-DISP-TOTAL
           MOVE WS-TOTAL-REVENUE TO WS-DISP-TOTAL
           DISPLAY "NET REVENUE: " WS-DISP-TOTAL
           DISPLAY "========================================".
