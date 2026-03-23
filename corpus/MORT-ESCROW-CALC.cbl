       IDENTIFICATION DIVISION.
       PROGRAM-ID. MORT-ESCROW-CALC.
      *================================================================*
      * MORTGAGE ESCROW ANALYSIS                                       *
      * Computes annual escrow requirements for taxes, insurance,      *
      * and PMI. Identifies shortage/surplus and payment adjustments.  *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-LOAN-INFO.
           05 WS-LOAN-NUM           PIC X(12).
           05 WS-ORIG-BAL           PIC S9(9)V99 COMP-3.
           05 WS-CURRENT-BAL        PIC S9(9)V99 COMP-3.
           05 WS-APPRAISED-VAL      PIC S9(9)V99 COMP-3.
           05 WS-MONTHLY-PI         PIC S9(7)V99 COMP-3.
       01 WS-ESCROW-ITEMS.
           05 WS-ANNUAL-TAX         PIC S9(7)V99 COMP-3.
           05 WS-ANNUAL-INS         PIC S9(7)V99 COMP-3.
           05 WS-ANNUAL-PMI         PIC S9(7)V99 COMP-3.
           05 WS-ANNUAL-FLOOD       PIC S9(7)V99 COMP-3.
           05 WS-ANNUAL-HOA         PIC S9(7)V99 COMP-3.
       01 WS-MONTHLY-ESCROW.
           05 WS-MO-TAX             PIC S9(5)V99 COMP-3.
           05 WS-MO-INS             PIC S9(5)V99 COMP-3.
           05 WS-MO-PMI             PIC S9(5)V99 COMP-3.
           05 WS-MO-FLOOD           PIC S9(5)V99 COMP-3.
           05 WS-MO-HOA             PIC S9(5)V99 COMP-3.
           05 WS-MO-TOTAL-ESC       PIC S9(7)V99 COMP-3.
       01 WS-ANALYSIS.
           05 WS-CURRENT-ESC-BAL    PIC S9(9)V99 COMP-3.
           05 WS-REQUIRED-BAL       PIC S9(9)V99 COMP-3.
           05 WS-CUSHION-MONTHS     PIC S9(2) COMP-3
               VALUE 2.
           05 WS-CUSHION-AMT        PIC S9(7)V99 COMP-3.
           05 WS-SHORTAGE           PIC S9(7)V99 COMP-3.
           05 WS-SURPLUS            PIC S9(7)V99 COMP-3.
           05 WS-ADJUSTMENT         PIC S9(5)V99 COMP-3.
       01 WS-PROJECTED-BAL.
           05 WS-PROJ-ENTRY OCCURS 12.
               10 WS-PROJ-DEPOSIT   PIC S9(7)V99 COMP-3.
               10 WS-PROJ-DISBURSE  PIC S9(7)V99 COMP-3.
               10 WS-PROJ-BALANCE   PIC S9(9)V99 COMP-3.
               10 WS-PROJ-LOW-FLAG  PIC X VALUE 'N'.
                   88 WS-IS-LOW     VALUE 'Y'.
       01 WS-IDX                    PIC S9(2) COMP-3.
       01 WS-LTV                    PIC S9(3)V99 COMP-3.
       01 WS-MIN-PROJ-BAL          PIC S9(9)V99 COMP-3.
       01 WS-TOTAL-PITI            PIC S9(7)V99 COMP-3.
       01 WS-NEW-TOTAL-PITI        PIC S9(7)V99 COMP-3.
       01 WS-STATUS                PIC X(15).
       01 WS-PREV-BAL              PIC S9(9)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CHECK-PMI-REQUIRED
           PERFORM 3000-CALC-MONTHLY-ESCROW
           PERFORM 4000-PROJECT-12-MONTHS
           PERFORM 5000-ANALYZE-SHORTAGE
               THRU 5500-CALC-ADJUSTMENT
           PERFORM 6000-DISPLAY-REPORT
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'LN0000123456' TO WS-LOAN-NUM
           MOVE 300000.00 TO WS-ORIG-BAL
           MOVE 275000.00 TO WS-CURRENT-BAL
           MOVE 350000.00 TO WS-APPRAISED-VAL
           MOVE 1798.65 TO WS-MONTHLY-PI
           MOVE 4800.00 TO WS-ANNUAL-TAX
           MOVE 1800.00 TO WS-ANNUAL-INS
           MOVE 0 TO WS-ANNUAL-PMI
           MOVE 450.00 TO WS-ANNUAL-FLOOD
           MOVE 0 TO WS-ANNUAL-HOA
           MOVE 2850.00 TO WS-CURRENT-ESC-BAL
           MOVE 0 TO WS-SHORTAGE
           MOVE 0 TO WS-SURPLUS
           MOVE 0 TO WS-ADJUSTMENT
           MOVE 999999999.99 TO WS-MIN-PROJ-BAL.
       2000-CHECK-PMI-REQUIRED.
           COMPUTE WS-LTV ROUNDED =
               (WS-CURRENT-BAL / WS-APPRAISED-VAL) * 100
           IF WS-LTV > 80
               COMPUTE WS-ANNUAL-PMI ROUNDED =
                   WS-CURRENT-BAL * 0.005
           ELSE
               MOVE 0 TO WS-ANNUAL-PMI
           END-IF.
       3000-CALC-MONTHLY-ESCROW.
           COMPUTE WS-MO-TAX ROUNDED =
               WS-ANNUAL-TAX / 12
           COMPUTE WS-MO-INS ROUNDED =
               WS-ANNUAL-INS / 12
           COMPUTE WS-MO-PMI ROUNDED =
               WS-ANNUAL-PMI / 12
           COMPUTE WS-MO-FLOOD ROUNDED =
               WS-ANNUAL-FLOOD / 12
           COMPUTE WS-MO-HOA ROUNDED =
               WS-ANNUAL-HOA / 12
           COMPUTE WS-MO-TOTAL-ESC =
               WS-MO-TAX + WS-MO-INS + WS-MO-PMI +
               WS-MO-FLOOD + WS-MO-HOA.
       4000-PROJECT-12-MONTHS.
           MOVE WS-CURRENT-ESC-BAL TO WS-PREV-BAL
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > 12
               MOVE WS-MO-TOTAL-ESC TO
                   WS-PROJ-DEPOSIT(WS-IDX)
               MOVE 0 TO WS-PROJ-DISBURSE(WS-IDX)
               EVALUATE WS-IDX
                   WHEN 3
                       MOVE WS-ANNUAL-TAX TO
                           WS-PROJ-DISBURSE(WS-IDX)
                   WHEN 6
                       COMPUTE WS-PROJ-DISBURSE(WS-IDX) =
                           WS-ANNUAL-INS + WS-ANNUAL-FLOOD
                   WHEN 9
                       MOVE WS-ANNUAL-TAX TO
                           WS-PROJ-DISBURSE(WS-IDX)
               END-EVALUATE
               COMPUTE WS-PROJ-BALANCE(WS-IDX) =
                   WS-PREV-BAL +
                   WS-PROJ-DEPOSIT(WS-IDX) -
                   WS-PROJ-DISBURSE(WS-IDX)
               MOVE WS-PROJ-BALANCE(WS-IDX) TO WS-PREV-BAL
               IF WS-PROJ-BALANCE(WS-IDX) < WS-MIN-PROJ-BAL
                   MOVE WS-PROJ-BALANCE(WS-IDX) TO
                       WS-MIN-PROJ-BAL
               END-IF
               IF WS-PROJ-BALANCE(WS-IDX) < 0
                   MOVE 'Y' TO WS-PROJ-LOW-FLAG(WS-IDX)
               END-IF
           END-PERFORM.
       5000-ANALYZE-SHORTAGE.
           COMPUTE WS-CUSHION-AMT ROUNDED =
               WS-MO-TOTAL-ESC * WS-CUSHION-MONTHS
           COMPUTE WS-REQUIRED-BAL =
               WS-CUSHION-AMT
           IF WS-MIN-PROJ-BAL < WS-REQUIRED-BAL
               COMPUTE WS-SHORTAGE =
                   WS-REQUIRED-BAL - WS-MIN-PROJ-BAL
               MOVE 0 TO WS-SURPLUS
               MOVE 'SHORTAGE' TO WS-STATUS
           ELSE
               MOVE 0 TO WS-SHORTAGE
               COMPUTE WS-SURPLUS =
                   WS-MIN-PROJ-BAL - WS-REQUIRED-BAL
               IF WS-SURPLUS > 50
                   MOVE 'SURPLUS' TO WS-STATUS
               ELSE
                   MOVE 'ADEQUATE' TO WS-STATUS
               END-IF
           END-IF.
       5500-CALC-ADJUSTMENT.
           IF WS-SHORTAGE > 0
               COMPUTE WS-ADJUSTMENT ROUNDED =
                   WS-SHORTAGE / 12
           ELSE
               IF WS-SURPLUS > 50
                   COMPUTE WS-ADJUSTMENT ROUNDED =
                       (WS-SURPLUS / 12) * -1
               ELSE
                   MOVE 0 TO WS-ADJUSTMENT
               END-IF
           END-IF
           COMPUTE WS-TOTAL-PITI =
               WS-MONTHLY-PI + WS-MO-TOTAL-ESC
           COMPUTE WS-NEW-TOTAL-PITI =
               WS-TOTAL-PITI + WS-ADJUSTMENT.
       6000-DISPLAY-REPORT.
           DISPLAY '========================================='
           DISPLAY 'ESCROW ANALYSIS REPORT'
           DISPLAY '========================================='
           DISPLAY 'LOAN:            ' WS-LOAN-NUM
           DISPLAY 'CURRENT BALANCE: ' WS-CURRENT-BAL
           DISPLAY 'LTV:             ' WS-LTV
           DISPLAY '----- MONTHLY ESCROW -----'
           DISPLAY 'TAX:             ' WS-MO-TAX
           DISPLAY 'INSURANCE:       ' WS-MO-INS
           DISPLAY 'PMI:             ' WS-MO-PMI
           DISPLAY 'FLOOD:           ' WS-MO-FLOOD
           DISPLAY 'TOTAL ESCROW:    ' WS-MO-TOTAL-ESC
           DISPLAY '----- PROJECTION -----'
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > 12
               DISPLAY 'MONTH ' WS-IDX
                   ' BAL: ' WS-PROJ-BALANCE(WS-IDX)
               IF WS-IS-LOW(WS-IDX)
                   DISPLAY '  *** NEGATIVE BALANCE'
               END-IF
           END-PERFORM
           DISPLAY '----- ANALYSIS -----'
           DISPLAY 'STATUS:          ' WS-STATUS
           DISPLAY 'SHORTAGE:        ' WS-SHORTAGE
           DISPLAY 'SURPLUS:         ' WS-SURPLUS
           DISPLAY 'ADJUSTMENT:      ' WS-ADJUSTMENT
           DISPLAY 'CURRENT PITI:    ' WS-TOTAL-PITI
           DISPLAY 'NEW PITI:        ' WS-NEW-TOTAL-PITI
           DISPLAY '========================================='.
