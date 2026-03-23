       IDENTIFICATION DIVISION.
       PROGRAM-ID. COLLATERAL-LTV-CALC.
      *================================================================*
      * COLLATERAL LTV (LOAN-TO-VALUE) CALCULATOR                     *
      * Computes LTV ratios for various collateral types, applies      *
      * depreciation schedules, haircut percentages, and checks        *
      * margin call thresholds and concentration limits.               *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- Loan and Collateral Fields ---
       01  WS-LOAN-AMOUNT            PIC S9(9)V99 COMP-3.
       01  WS-ORIGINAL-APPRAISAL     PIC S9(9)V99 COMP-3.
       01  WS-CURRENT-APPRAISAL      PIC S9(9)V99 COMP-3.
       01  WS-DEPRECIATED-VALUE      PIC S9(9)V99 COMP-3.
       01  WS-COLLATERAL-TYPE        PIC X(12).
       01  WS-COLLATERAL-AGE-YEARS   PIC 9(3).
       01  WS-DEPRECIATION-RATE      PIC S9(3)V9(4) COMP-3.
       01  WS-ANNUAL-DEPRECIATION    PIC S9(9)V99 COMP-3.
       01  WS-TOTAL-DEPRECIATION     PIC S9(9)V99 COMP-3.
       01  WS-DEPR-YEAR              PIC 9(3).
      *--- LTV Computation ---
       01  WS-LTV-RATIO              PIC S9(3)V9(4) COMP-3.
       01  WS-LTV-PERCENT            PIC S9(5)V99 COMP-3.
       01  WS-ADJUSTED-VALUE         PIC S9(9)V99 COMP-3.
       01  WS-HAIRCUT-PCT            PIC S9(3)V9(4) COMP-3.
       01  WS-HAIRCUT-AMOUNT         PIC S9(9)V99 COMP-3.
      *--- Margin Call Detection ---
       01  WS-MARGIN-THRESHOLD       PIC S9(3)V9(4) COMP-3.
       01  WS-MARGIN-CALL-FLAG       PIC X(1).
       01  WS-MARGIN-SHORTFALL       PIC S9(9)V99 COMP-3.
       01  WS-REQUIRED-COLLATERAL    PIC S9(9)V99 COMP-3.
      *--- Concentration Limits ---
       01  WS-PORTFOLIO-TOTAL        PIC S9(11)V99 COMP-3.
       01  WS-TYPE-TOTAL             PIC S9(11)V99 COMP-3.
       01  WS-CONCENTRATION-PCT      PIC S9(3)V9(4) COMP-3.
       01  WS-CONCENTRATION-LIMIT    PIC S9(3)V9(4) COMP-3.
       01  WS-CONCENTRATION-BREACH   PIC X(1).
      *--- Classification Result ---
       01  WS-RISK-CATEGORY          PIC X(10).
       01  WS-MAX-LTV-ALLOWED        PIC S9(3)V9(4) COMP-3.
       01  WS-LTV-STATUS             PIC X(15).
      *--- Counters ---
       01  WS-ITEMS-PROCESSED        PIC 9(5).
       01  WS-MARGIN-CALLS           PIC 9(5).
       01  WS-CONC-BREACHES          PIC 9(5).
       01  WS-WORK-VALUE             PIC S9(9)V99 COMP-3.

       PROCEDURE DIVISION.
       MAIN-PROGRAM.
           PERFORM INITIALIZE-FIELDS
           PERFORM LOAD-COLLATERAL-DATA
           PERFORM APPLY-DEPRECIATION THRU
                   APPLY-DEPRECIATION-EXIT
           PERFORM CLASSIFY-COLLATERAL-TYPE
           PERFORM COMPUTE-HAIRCUT
           PERFORM COMPUTE-LTV-RATIO
           PERFORM CHECK-MARGIN-CALL THRU
                   CHECK-MARGIN-CALL-EXIT
           PERFORM CHECK-CONCENTRATION-LIMIT
           PERFORM DISPLAY-RESULTS
           STOP RUN.

       INITIALIZE-FIELDS.
           MOVE 0 TO WS-LOAN-AMOUNT
           MOVE 0 TO WS-ORIGINAL-APPRAISAL
           MOVE 0 TO WS-CURRENT-APPRAISAL
           MOVE 0 TO WS-DEPRECIATED-VALUE
           MOVE 0 TO WS-TOTAL-DEPRECIATION
           MOVE 0 TO WS-LTV-RATIO
           MOVE 0 TO WS-LTV-PERCENT
           MOVE 0 TO WS-HAIRCUT-PCT
           MOVE 0 TO WS-HAIRCUT-AMOUNT
           MOVE 0 TO WS-MARGIN-SHORTFALL
           MOVE 0 TO WS-ITEMS-PROCESSED
           MOVE 0 TO WS-MARGIN-CALLS
           MOVE 0 TO WS-CONC-BREACHES
           MOVE 'N' TO WS-MARGIN-CALL-FLAG
           MOVE 'N' TO WS-CONCENTRATION-BREACH.

       LOAD-COLLATERAL-DATA.
           MOVE 500000.00 TO WS-LOAN-AMOUNT
           MOVE 750000.00 TO WS-ORIGINAL-APPRAISAL
           MOVE 750000.00 TO WS-CURRENT-APPRAISAL
           MOVE 'REAL-ESTATE' TO WS-COLLATERAL-TYPE
           MOVE 5 TO WS-COLLATERAL-AGE-YEARS
           MOVE 2500000.00 TO WS-PORTFOLIO-TOTAL
           MOVE 800000.00 TO WS-TYPE-TOTAL
           ADD 1 TO WS-ITEMS-PROCESSED.

       APPLY-DEPRECIATION.
           EVALUATE WS-COLLATERAL-TYPE
               WHEN 'REAL-ESTATE'
                   MOVE 0.0200 TO WS-DEPRECIATION-RATE
               WHEN 'VEHICLE'
                   MOVE 0.1500 TO WS-DEPRECIATION-RATE
               WHEN 'SECURITIES'
                   MOVE 0.0000 TO WS-DEPRECIATION-RATE
               WHEN 'EQUIPMENT'
                   MOVE 0.1000 TO WS-DEPRECIATION-RATE
               WHEN OTHER
                   MOVE 0.0500 TO WS-DEPRECIATION-RATE
           END-EVALUATE
           MOVE WS-CURRENT-APPRAISAL TO WS-DEPRECIATED-VALUE
           MOVE 0 TO WS-TOTAL-DEPRECIATION
           MOVE 1 TO WS-DEPR-YEAR
           PERFORM UNTIL WS-DEPR-YEAR > WS-COLLATERAL-AGE-YEARS
               COMPUTE WS-ANNUAL-DEPRECIATION =
                   WS-DEPRECIATED-VALUE * WS-DEPRECIATION-RATE
               SUBTRACT WS-ANNUAL-DEPRECIATION
                   FROM WS-DEPRECIATED-VALUE
               ADD WS-ANNUAL-DEPRECIATION
                   TO WS-TOTAL-DEPRECIATION
               ADD 1 TO WS-DEPR-YEAR
           END-PERFORM.

       APPLY-DEPRECIATION-EXIT.
           EXIT.

       CLASSIFY-COLLATERAL-TYPE.
           EVALUATE WS-COLLATERAL-TYPE
               WHEN 'REAL-ESTATE'
                   MOVE 'LOW-RISK' TO WS-RISK-CATEGORY
                   MOVE 0.8000 TO WS-MAX-LTV-ALLOWED
               WHEN 'VEHICLE'
                   MOVE 'MED-RISK' TO WS-RISK-CATEGORY
                   MOVE 0.7000 TO WS-MAX-LTV-ALLOWED
               WHEN 'SECURITIES'
                   MOVE 'LOW-RISK' TO WS-RISK-CATEGORY
                   MOVE 0.7500 TO WS-MAX-LTV-ALLOWED
               WHEN 'EQUIPMENT'
                   MOVE 'HIGH-RISK' TO WS-RISK-CATEGORY
                   MOVE 0.6000 TO WS-MAX-LTV-ALLOWED
               WHEN OTHER
                   MOVE 'UNKNOWN' TO WS-RISK-CATEGORY
                   MOVE 0.5000 TO WS-MAX-LTV-ALLOWED
           END-EVALUATE.

       COMPUTE-HAIRCUT.
           EVALUATE TRUE
               WHEN WS-RISK-CATEGORY = 'LOW-RISK'
                   MOVE 0.0500 TO WS-HAIRCUT-PCT
               WHEN WS-RISK-CATEGORY = 'MED-RISK'
                   MOVE 0.1500 TO WS-HAIRCUT-PCT
               WHEN WS-RISK-CATEGORY = 'HIGH-RISK'
                   MOVE 0.2500 TO WS-HAIRCUT-PCT
               WHEN OTHER
                   MOVE 0.3500 TO WS-HAIRCUT-PCT
           END-EVALUATE
           COMPUTE WS-HAIRCUT-AMOUNT =
               WS-DEPRECIATED-VALUE * WS-HAIRCUT-PCT
           COMPUTE WS-ADJUSTED-VALUE =
               WS-DEPRECIATED-VALUE - WS-HAIRCUT-AMOUNT.

       COMPUTE-LTV-RATIO.
           IF WS-ADJUSTED-VALUE > 0
               COMPUTE WS-LTV-RATIO =
                   WS-LOAN-AMOUNT / WS-ADJUSTED-VALUE
               COMPUTE WS-LTV-PERCENT =
                   WS-LTV-RATIO * 100
           ELSE
               MOVE 999.9999 TO WS-LTV-RATIO
               MOVE 99999.99 TO WS-LTV-PERCENT
           END-IF
           IF WS-LTV-RATIO > WS-MAX-LTV-ALLOWED
               MOVE 'OVER-LIMIT' TO WS-LTV-STATUS
           ELSE
               MOVE 'WITHIN-LIMIT' TO WS-LTV-STATUS
           END-IF.

       CHECK-MARGIN-CALL.
           MOVE 0.9000 TO WS-MARGIN-THRESHOLD
           IF WS-LTV-RATIO > WS-MARGIN-THRESHOLD
               MOVE 'Y' TO WS-MARGIN-CALL-FLAG
               ADD 1 TO WS-MARGIN-CALLS
               COMPUTE WS-REQUIRED-COLLATERAL =
                   WS-LOAN-AMOUNT / WS-MARGIN-THRESHOLD
               COMPUTE WS-MARGIN-SHORTFALL =
                   WS-REQUIRED-COLLATERAL - WS-ADJUSTED-VALUE
               IF WS-MARGIN-SHORTFALL < 0
                   MOVE 0 TO WS-MARGIN-SHORTFALL
               END-IF
           ELSE
               MOVE 'N' TO WS-MARGIN-CALL-FLAG
               MOVE 0 TO WS-MARGIN-SHORTFALL
           END-IF.

       CHECK-MARGIN-CALL-EXIT.
           EXIT.

       CHECK-CONCENTRATION-LIMIT.
           EVALUATE WS-COLLATERAL-TYPE
               WHEN 'REAL-ESTATE'
                   MOVE 0.4000 TO WS-CONCENTRATION-LIMIT
               WHEN 'VEHICLE'
                   MOVE 0.2000 TO WS-CONCENTRATION-LIMIT
               WHEN 'SECURITIES'
                   MOVE 0.3000 TO WS-CONCENTRATION-LIMIT
               WHEN 'EQUIPMENT'
                   MOVE 0.1500 TO WS-CONCENTRATION-LIMIT
               WHEN OTHER
                   MOVE 0.1000 TO WS-CONCENTRATION-LIMIT
           END-EVALUATE
           IF WS-PORTFOLIO-TOTAL > 0
               COMPUTE WS-CONCENTRATION-PCT =
                   WS-TYPE-TOTAL / WS-PORTFOLIO-TOTAL
           ELSE
               MOVE 0 TO WS-CONCENTRATION-PCT
           END-IF
           IF WS-CONCENTRATION-PCT > WS-CONCENTRATION-LIMIT
               MOVE 'Y' TO WS-CONCENTRATION-BREACH
               ADD 1 TO WS-CONC-BREACHES
           ELSE
               MOVE 'N' TO WS-CONCENTRATION-BREACH
           END-IF.

       DISPLAY-RESULTS.
           DISPLAY 'COLLATERAL LTV REPORT'
           DISPLAY '====================='
           DISPLAY 'TYPE: ' WS-COLLATERAL-TYPE
           DISPLAY 'RISK: ' WS-RISK-CATEGORY
           DISPLAY 'ORIGINAL APPRAISAL: ' WS-ORIGINAL-APPRAISAL
           DISPLAY 'DEPRECIATED VALUE:  ' WS-DEPRECIATED-VALUE
           DISPLAY 'TOTAL DEPRECIATION: ' WS-TOTAL-DEPRECIATION
           DISPLAY 'HAIRCUT AMOUNT:     ' WS-HAIRCUT-AMOUNT
           DISPLAY 'ADJUSTED VALUE:     ' WS-ADJUSTED-VALUE
           DISPLAY 'LTV RATIO:          ' WS-LTV-PERCENT
           DISPLAY 'MAX LTV ALLOWED:    ' WS-MAX-LTV-ALLOWED
           DISPLAY 'LTV STATUS:         ' WS-LTV-STATUS
           DISPLAY 'MARGIN CALL:        ' WS-MARGIN-CALL-FLAG
           DISPLAY 'MARGIN SHORTFALL:   ' WS-MARGIN-SHORTFALL
           DISPLAY 'CONC BREACH:        ' WS-CONCENTRATION-BREACH
           DISPLAY 'CONC PCT:           ' WS-CONCENTRATION-PCT
           DISPLAY 'ITEMS PROCESSED:    ' WS-ITEMS-PROCESSED.
