       IDENTIFICATION DIVISION.
       PROGRAM-ID. PORT-ASSET-ALLOC.
      *================================================================
      * PORTFOLIO ASSET ALLOCATION OPTIMIZER
      * Applies age-based glide path rules to determine target
      * allocations and generates rebalancing recommendations.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CLIENT.
           05 WS-CLIENT-ID            PIC X(10).
           05 WS-CLIENT-AGE           PIC 9(3).
           05 WS-RETIRE-AGE           PIC 9(3) VALUE 65.
           05 WS-RISK-TOLERANCE        PIC X(1).
               88 RT-CONSERVATIVE      VALUE 'C'.
               88 RT-MODERATE          VALUE 'M'.
               88 RT-AGGRESSIVE        VALUE 'A'.
           05 WS-TOTAL-ASSETS         PIC S9(13)V99 COMP-3.
           05 WS-ANNUAL-CONTRIB       PIC S9(7)V99 COMP-3.
       01 WS-TARGETS.
           05 WS-TGT-EQUITY           PIC S9(3)V99 COMP-3.
           05 WS-TGT-FIXED-INC        PIC S9(3)V99 COMP-3.
           05 WS-TGT-ALTERNATIVES     PIC S9(3)V99 COMP-3.
           05 WS-TGT-CASH             PIC S9(3)V99 COMP-3.
       01 WS-CURRENT-ALLOC.
           05 WS-CUR-EQUITY           PIC S9(11)V99 COMP-3.
           05 WS-CUR-FIXED            PIC S9(11)V99 COMP-3.
           05 WS-CUR-ALT              PIC S9(11)V99 COMP-3.
           05 WS-CUR-CASH             PIC S9(11)V99 COMP-3.
       01 WS-CURRENT-PCTS.
           05 WS-CUR-EQT-PCT          PIC S9(3)V99 COMP-3.
           05 WS-CUR-FIX-PCT          PIC S9(3)V99 COMP-3.
           05 WS-CUR-ALT-PCT          PIC S9(3)V99 COMP-3.
           05 WS-CUR-CSH-PCT          PIC S9(3)V99 COMP-3.
       01 WS-ADJUSTMENTS.
           05 WS-ADJ-EQUITY           PIC S9(11)V99 COMP-3.
           05 WS-ADJ-FIXED            PIC S9(11)V99 COMP-3.
           05 WS-ADJ-ALT              PIC S9(11)V99 COMP-3.
           05 WS-ADJ-CASH             PIC S9(11)V99 COMP-3.
       01 WS-CALC.
           05 WS-YEARS-TO-RETIRE      PIC S9(3) COMP-3.
           05 WS-EQUITY-BASE          PIC S9(3)V99 COMP-3.
           05 WS-RISK-ADJUST          PIC S9(3)V99 COMP-3.
           05 WS-REMAINING            PIC S9(3)V99 COMP-3.
           05 WS-TARGET-VALUE         PIC S9(11)V99 COMP-3.
       01 WS-GLIDE-PATH.
           05 WS-GP-ENTRY OCCURS 5 TIMES.
               10 WS-GP-YEARS-OUT     PIC 9(2).
               10 WS-GP-EQUITY-PCT    PIC S9(3)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-GLIDE-PATH
           PERFORM 3000-APPLY-RISK-TOLERANCE
           PERFORM 4000-FILL-REMAINING
           PERFORM 5000-CALC-CURRENT-PCTS
           PERFORM 6000-CALC-ADJUSTMENTS
           PERFORM 7000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'CLI-AA-8901' TO WS-CLIENT-ID
           MOVE 42 TO WS-CLIENT-AGE
           MOVE 'M' TO WS-RISK-TOLERANCE
           MOVE 1500000.00 TO WS-TOTAL-ASSETS
           MOVE 50000.00 TO WS-ANNUAL-CONTRIB
           MOVE 975000.00 TO WS-CUR-EQUITY
           MOVE 300000.00 TO WS-CUR-FIXED
           MOVE 150000.00 TO WS-CUR-ALT
           MOVE 75000.00 TO WS-CUR-CASH
           MOVE 30 TO WS-GP-YEARS-OUT(1)
           MOVE 90.00 TO WS-GP-EQUITY-PCT(1)
           MOVE 20 TO WS-GP-YEARS-OUT(2)
           MOVE 80.00 TO WS-GP-EQUITY-PCT(2)
           MOVE 10 TO WS-GP-YEARS-OUT(3)
           MOVE 65.00 TO WS-GP-EQUITY-PCT(3)
           MOVE 5 TO WS-GP-YEARS-OUT(4)
           MOVE 50.00 TO WS-GP-EQUITY-PCT(4)
           MOVE 0 TO WS-GP-YEARS-OUT(5)
           MOVE 35.00 TO WS-GP-EQUITY-PCT(5).
       2000-CALC-GLIDE-PATH.
           COMPUTE WS-YEARS-TO-RETIRE =
               WS-RETIRE-AGE - WS-CLIENT-AGE
           IF WS-YEARS-TO-RETIRE < 0
               MOVE 0 TO WS-YEARS-TO-RETIRE
           END-IF
           IF WS-YEARS-TO-RETIRE >= 30
               MOVE 90.00 TO WS-EQUITY-BASE
           ELSE
               IF WS-YEARS-TO-RETIRE >= 20
                   MOVE 80.00 TO WS-EQUITY-BASE
               ELSE
                   IF WS-YEARS-TO-RETIRE >= 10
                       MOVE 65.00 TO WS-EQUITY-BASE
                   ELSE
                       IF WS-YEARS-TO-RETIRE >= 5
                           MOVE 50.00 TO WS-EQUITY-BASE
                       ELSE
                           MOVE 35.00 TO WS-EQUITY-BASE
                       END-IF
                   END-IF
               END-IF
           END-IF.
       3000-APPLY-RISK-TOLERANCE.
           EVALUATE TRUE
               WHEN RT-CONSERVATIVE
                   MOVE -10.00 TO WS-RISK-ADJUST
               WHEN RT-MODERATE
                   MOVE 0.00 TO WS-RISK-ADJUST
               WHEN RT-AGGRESSIVE
                   MOVE 10.00 TO WS-RISK-ADJUST
               WHEN OTHER
                   MOVE 0.00 TO WS-RISK-ADJUST
           END-EVALUATE
           COMPUTE WS-TGT-EQUITY =
               WS-EQUITY-BASE + WS-RISK-ADJUST
           IF WS-TGT-EQUITY > 95.00
               MOVE 95.00 TO WS-TGT-EQUITY
           END-IF
           IF WS-TGT-EQUITY < 20.00
               MOVE 20.00 TO WS-TGT-EQUITY
           END-IF.
       4000-FILL-REMAINING.
           COMPUTE WS-REMAINING =
               100.00 - WS-TGT-EQUITY
           IF WS-YEARS-TO-RETIRE > 15
               COMPUTE WS-TGT-ALTERNATIVES =
                   WS-REMAINING * 0.15
               MOVE 5.00 TO WS-TGT-CASH
               COMPUTE WS-TGT-FIXED-INC =
                   WS-REMAINING
                   - WS-TGT-ALTERNATIVES
                   - WS-TGT-CASH
           ELSE
               COMPUTE WS-TGT-ALTERNATIVES =
                   WS-REMAINING * 0.10
               MOVE 10.00 TO WS-TGT-CASH
               COMPUTE WS-TGT-FIXED-INC =
                   WS-REMAINING
                   - WS-TGT-ALTERNATIVES
                   - WS-TGT-CASH
           END-IF.
       5000-CALC-CURRENT-PCTS.
           IF WS-TOTAL-ASSETS > 0
               COMPUTE WS-CUR-EQT-PCT =
                   (WS-CUR-EQUITY / WS-TOTAL-ASSETS) * 100
               COMPUTE WS-CUR-FIX-PCT =
                   (WS-CUR-FIXED / WS-TOTAL-ASSETS) * 100
               COMPUTE WS-CUR-ALT-PCT =
                   (WS-CUR-ALT / WS-TOTAL-ASSETS) * 100
               COMPUTE WS-CUR-CSH-PCT =
                   (WS-CUR-CASH / WS-TOTAL-ASSETS) * 100
           ELSE
               MOVE 0 TO WS-CUR-EQT-PCT
               MOVE 0 TO WS-CUR-FIX-PCT
               MOVE 0 TO WS-CUR-ALT-PCT
               MOVE 0 TO WS-CUR-CSH-PCT
           END-IF.
       6000-CALC-ADJUSTMENTS.
           COMPUTE WS-TARGET-VALUE =
               WS-TOTAL-ASSETS * (WS-TGT-EQUITY / 100)
           COMPUTE WS-ADJ-EQUITY =
               WS-TARGET-VALUE - WS-CUR-EQUITY
           COMPUTE WS-TARGET-VALUE =
               WS-TOTAL-ASSETS *
               (WS-TGT-FIXED-INC / 100)
           COMPUTE WS-ADJ-FIXED =
               WS-TARGET-VALUE - WS-CUR-FIXED
           COMPUTE WS-TARGET-VALUE =
               WS-TOTAL-ASSETS *
               (WS-TGT-ALTERNATIVES / 100)
           COMPUTE WS-ADJ-ALT =
               WS-TARGET-VALUE - WS-CUR-ALT
           COMPUTE WS-TARGET-VALUE =
               WS-TOTAL-ASSETS * (WS-TGT-CASH / 100)
           COMPUTE WS-ADJ-CASH =
               WS-TARGET-VALUE - WS-CUR-CASH.
       7000-DISPLAY-RESULTS.
           DISPLAY 'ASSET ALLOCATION REPORT'
           DISPLAY '======================='
           DISPLAY 'CLIENT:          ' WS-CLIENT-ID
           DISPLAY 'AGE:             ' WS-CLIENT-AGE
           DISPLAY 'YEARS TO RETIRE: ' WS-YEARS-TO-RETIRE
           DISPLAY 'TOTAL ASSETS:    ' WS-TOTAL-ASSETS
           DISPLAY '-----------------------'
           DISPLAY 'TARGET EQUITY:   ' WS-TGT-EQUITY '%'
           DISPLAY 'TARGET FIXED:    ' WS-TGT-FIXED-INC '%'
           DISPLAY 'TARGET ALTS:     ' WS-TGT-ALTERNATIVES '%'
           DISPLAY 'TARGET CASH:     ' WS-TGT-CASH '%'
           DISPLAY '-----------------------'
           DISPLAY 'CURRENT EQUITY:  ' WS-CUR-EQT-PCT '%'
           DISPLAY 'CURRENT FIXED:   ' WS-CUR-FIX-PCT '%'
           DISPLAY 'CURRENT ALTS:    ' WS-CUR-ALT-PCT '%'
           DISPLAY 'CURRENT CASH:    ' WS-CUR-CSH-PCT '%'
           DISPLAY '-----------------------'
           DISPLAY 'ADJ EQUITY:      ' WS-ADJ-EQUITY
           DISPLAY 'ADJ FIXED:       ' WS-ADJ-FIXED
           DISPLAY 'ADJ ALTS:        ' WS-ADJ-ALT
           DISPLAY 'ADJ CASH:        ' WS-ADJ-CASH.
