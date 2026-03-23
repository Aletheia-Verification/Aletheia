       IDENTIFICATION DIVISION.
       PROGRAM-ID. BASEL3-LCR-CALC.
      *================================================================
      * Basel III Liquidity Coverage Ratio Calculator
      * Computes HQLA stock, net cash outflows over 30-day
      * stress horizon, and LCR compliance assessment.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-BANK-ID                  PIC X(10).
       01 WS-HQLA-ASSETS.
           05 WS-LEVEL1-ASSETS.
               10 WS-CASH             PIC S9(13)V99 COMP-3.
               10 WS-CENTRAL-BANK-RES PIC S9(13)V99 COMP-3.
               10 WS-GOV-SECURITIES   PIC S9(13)V99 COMP-3.
               10 WS-L1-TOTAL         PIC S9(13)V99 COMP-3.
           05 WS-LEVEL2A-ASSETS.
               10 WS-AGENCY-SECURITIES
                                      PIC S9(13)V99 COMP-3.
               10 WS-CORP-BONDS-AA    PIC S9(13)V99 COMP-3.
               10 WS-L2A-HAIRCUT      PIC S9(1)V9(4) COMP-3
                   VALUE 0.1500.
               10 WS-L2A-TOTAL        PIC S9(13)V99 COMP-3.
           05 WS-LEVEL2B-ASSETS.
               10 WS-CORP-BONDS-BBB   PIC S9(13)V99 COMP-3.
               10 WS-EQUITIES         PIC S9(13)V99 COMP-3.
               10 WS-RMBS             PIC S9(13)V99 COMP-3.
               10 WS-L2B-HAIRCUT      PIC S9(1)V9(4) COMP-3
                   VALUE 0.5000.
               10 WS-L2B-TOTAL        PIC S9(13)V99 COMP-3.
       01 WS-HQLA-TOTAL               PIC S9(13)V99 COMP-3.
       01 WS-HQLA-CAP-FIELDS.
           05 WS-L2-CAP               PIC S9(13)V99 COMP-3.
           05 WS-L2B-CAP              PIC S9(13)V99 COMP-3.
       01 WS-OUTFLOW-TABLE.
           05 WS-OUTFLOW OCCURS 8
              ASCENDING KEY IS WS-OF-CODE
              INDEXED BY WS-OF-IDX.
               10 WS-OF-CODE          PIC X(3).
               10 WS-OF-NAME          PIC X(20).
               10 WS-OF-BALANCE       PIC S9(13)V99 COMP-3.
               10 WS-OF-RUNOFF-RT     PIC S9(1)V9(4) COMP-3.
               10 WS-OF-AMOUNT        PIC S9(13)V99 COMP-3.
       01 WS-OF-COUNT                 PIC 9(1) VALUE 8.
       01 WS-INFLOW-TABLE.
           05 WS-INFLOW OCCURS 5
              ASCENDING KEY IS WS-IF-CODE
              INDEXED BY WS-IF-IDX.
               10 WS-IF-CODE          PIC X(3).
               10 WS-IF-NAME          PIC X(20).
               10 WS-IF-BALANCE       PIC S9(13)V99 COMP-3.
               10 WS-IF-RATE          PIC S9(1)V9(4) COMP-3.
               10 WS-IF-AMOUNT        PIC S9(13)V99 COMP-3.
       01 WS-IF-COUNT                 PIC 9(1) VALUE 5.
       01 WS-NET-FIELDS.
           05 WS-TOTAL-OUTFLOWS       PIC S9(13)V99 COMP-3.
           05 WS-TOTAL-INFLOWS        PIC S9(13)V99 COMP-3.
           05 WS-INFLOW-CAP           PIC S9(13)V99 COMP-3.
           05 WS-NET-OUTFLOWS         PIC S9(13)V99 COMP-3.
       01 WS-LCR-FIELDS.
           05 WS-LCR-RATIO            PIC S9(5)V9(4) COMP-3.
           05 WS-LCR-MINIMUM          PIC S9(3)V9(4) COMP-3
               VALUE 100.0000.
           05 WS-LCR-SURPLUS          PIC S9(13)V99 COMP-3.
       01 WS-COMPLIANCE               PIC X(1).
           88 WS-LCR-COMPLIANT        VALUE 'Y'.
           88 WS-LCR-BREACH           VALUE 'N'.
       01 WS-PROCESS-DATE             PIC 9(8).
       66 WS-PROCESS-YYYYMM
           RENAMES WS-PROCESS-DATE.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-HQLA
           PERFORM 3000-CALC-OUTFLOWS
           PERFORM 4000-CALC-INFLOWS
           PERFORM 5000-CALC-NET-OUTFLOWS
           PERFORM 6000-COMPUTE-LCR
           PERFORM 7000-DISPLAY-REPORT
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-PROCESS-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-HQLA-TOTAL
           MOVE 0 TO WS-TOTAL-OUTFLOWS
           MOVE 0 TO WS-TOTAL-INFLOWS.
       2000-CALC-HQLA.
           COMPUTE WS-L1-TOTAL =
               WS-CASH + WS-CENTRAL-BANK-RES +
               WS-GOV-SECURITIES
           COMPUTE WS-L2A-TOTAL =
               (WS-AGENCY-SECURITIES + WS-CORP-BONDS-AA)
               * (1 - WS-L2A-HAIRCUT)
           COMPUTE WS-L2B-TOTAL =
               (WS-CORP-BONDS-BBB + WS-EQUITIES +
                WS-RMBS) * (1 - WS-L2B-HAIRCUT)
           COMPUTE WS-L2-CAP =
               WS-L1-TOTAL * 0.6667
           COMPUTE WS-L2B-CAP =
               WS-HQLA-TOTAL * 0.15
           IF WS-L2A-TOTAL + WS-L2B-TOTAL > WS-L2-CAP
               COMPUTE WS-HQLA-TOTAL =
                   WS-L1-TOTAL + WS-L2-CAP
           ELSE
               COMPUTE WS-HQLA-TOTAL =
                   WS-L1-TOTAL + WS-L2A-TOTAL +
                   WS-L2B-TOTAL
           END-IF.
       3000-CALC-OUTFLOWS.
           PERFORM VARYING WS-OF-IDX FROM 1 BY 1
               UNTIL WS-OF-IDX > WS-OF-COUNT
               COMPUTE WS-OF-AMOUNT(WS-OF-IDX) =
                   WS-OF-BALANCE(WS-OF-IDX) *
                   WS-OF-RUNOFF-RT(WS-OF-IDX)
               ADD WS-OF-AMOUNT(WS-OF-IDX)
                   TO WS-TOTAL-OUTFLOWS
           END-PERFORM.
       4000-CALC-INFLOWS.
           PERFORM VARYING WS-IF-IDX FROM 1 BY 1
               UNTIL WS-IF-IDX > WS-IF-COUNT
               COMPUTE WS-IF-AMOUNT(WS-IF-IDX) =
                   WS-IF-BALANCE(WS-IF-IDX) *
                   WS-IF-RATE(WS-IF-IDX)
               ADD WS-IF-AMOUNT(WS-IF-IDX)
                   TO WS-TOTAL-INFLOWS
           END-PERFORM.
       5000-CALC-NET-OUTFLOWS.
           COMPUTE WS-INFLOW-CAP =
               WS-TOTAL-OUTFLOWS * 0.75
           IF WS-TOTAL-INFLOWS > WS-INFLOW-CAP
               MOVE WS-INFLOW-CAP TO WS-TOTAL-INFLOWS
           END-IF
           COMPUTE WS-NET-OUTFLOWS =
               WS-TOTAL-OUTFLOWS - WS-TOTAL-INFLOWS
           IF WS-NET-OUTFLOWS < 0
               MOVE 0 TO WS-NET-OUTFLOWS
           END-IF.
       6000-COMPUTE-LCR.
           IF WS-NET-OUTFLOWS > 0
               COMPUTE WS-LCR-RATIO =
                   (WS-HQLA-TOTAL / WS-NET-OUTFLOWS)
                   * 100
           ELSE
               MOVE 999.0 TO WS-LCR-RATIO
           END-IF
           IF WS-LCR-RATIO >= WS-LCR-MINIMUM
               SET WS-LCR-COMPLIANT TO TRUE
               COMPUTE WS-LCR-SURPLUS =
                   WS-HQLA-TOTAL - WS-NET-OUTFLOWS
           ELSE
               SET WS-LCR-BREACH TO TRUE
               COMPUTE WS-LCR-SURPLUS =
                   WS-HQLA-TOTAL - WS-NET-OUTFLOWS
           END-IF.
       7000-DISPLAY-REPORT.
           DISPLAY "BASEL III LCR REPORT"
           DISPLAY "BANK: " WS-BANK-ID
           DISPLAY "DATE: " WS-PROCESS-DATE
           DISPLAY "HQLA L1: " WS-L1-TOTAL
           DISPLAY "HQLA L2A: " WS-L2A-TOTAL
           DISPLAY "HQLA L2B: " WS-L2B-TOTAL
           DISPLAY "TOTAL HQLA: " WS-HQLA-TOTAL
           DISPLAY "OUTFLOWS: " WS-TOTAL-OUTFLOWS
           DISPLAY "INFLOWS: " WS-TOTAL-INFLOWS
           DISPLAY "NET OUTFLOWS: " WS-NET-OUTFLOWS
           DISPLAY "LCR: " WS-LCR-RATIO "%"
           IF WS-LCR-COMPLIANT
               DISPLAY "STATUS: COMPLIANT"
           ELSE
               DISPLAY "STATUS: BREACH - ACTION REQUIRED"
           END-IF
           DISPLAY "SURPLUS/DEFICIT: " WS-LCR-SURPLUS.
