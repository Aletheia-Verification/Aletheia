       IDENTIFICATION DIVISION.
       PROGRAM-ID. FDIC-ASSESS-CALC.
      *================================================================*
      * FDIC Assessment Calculator                                      *
      * Computes quarterly FDIC insurance premiums using risk-based     *
      * assessment methodology with CAMELS adjustments and              *
      * large bank surcharges.                                          *
      *================================================================*
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-BANK-DATA.
           05  BD-BANK-NAME         PIC X(30)
                                    VALUE 'ALETHEIA NATIONAL BANK'.
           05  BD-TOTAL-ASSETS      PIC 9(13)V99
                                    VALUE 8500000000.00.
           05  BD-TOTAL-DEPOSITS    PIC 9(13)V99
                                    VALUE 6200000000.00.
           05  BD-TIER1-CAPITAL     PIC 9(11)V99
                                    VALUE 680000000.00.
           05  BD-TOTAL-CAPITAL     PIC 9(11)V99
                                    VALUE 750000000.00.
           05  BD-RISK-WT-ASSETS    PIC 9(13)V99
                                    VALUE 5800000000.00.
           05  BD-CAMELS-RATING     PIC 9(01) VALUE 2.
           05  BD-BROKERED-DEP      PIC 9(11)V99
                                    VALUE 250000000.00.
       01  WS-ASSESS-BASE         PIC S9(13)V99.
       01  WS-INITIAL-RATE        PIC 9V9(06).
       01  WS-ADJUSTED-RATE       PIC 9V9(06).
       01  WS-CAMELS-ADJ          PIC S9V9(06).
       01  WS-BROKERED-ADJ        PIC S9V9(06).
       01  WS-QUARTERLY-ASSESS    PIC S9(11)V99.
       01  WS-ANNUAL-ASSESS       PIC S9(11)V99.
       01  WS-SURCHARGE-AMT       PIC S9(09)V99 VALUE 0.
       01  WS-LEVERAGE-RATIO      PIC 9(03)V99.
       01  WS-TIER1-RATIO         PIC 9(03)V99.
       01  WS-TOTAL-CAP-RATIO     PIC 9(03)V99.
       01  WS-BROKERED-PCT        PIC 9(03)V99.
       01  WS-WELL-CAP-FLAG       PIC X VALUE 'N'.
           88  IS-WELL-CAP         VALUE 'Y'.
       01  WS-LARGE-BANK-FLAG     PIC X VALUE 'N'.
           88  IS-LARGE-BANK       VALUE 'Y'.
       01  WS-LARGE-THRESHOLD     PIC 9(13)V99
                                   VALUE 10000000000.00.
       01  WS-SURCHARGE-RATE      PIC 9V9(06) VALUE 0.000045.
       01  WS-RISK-CATEGORY       PIC 9(01).
       01  WS-CAT-DESC            PIC X(20).
       01  WS-RATE-TABLE.
           05  WS-RATE-ENTRY      OCCURS 4 TIMES.
               10  RE-CAT         PIC 9(01).
               10  RE-MIN-RATE    PIC 9V9(06).
               10  RE-MAX-RATE    PIC 9V9(06).
       01  WS-IDX                 PIC 9(02).
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-RATIOS
           PERFORM 3000-DETERMINE-CATEGORY
           PERFORM 4000-CALC-BASE-RATE
           PERFORM 5000-APPLY-ADJUSTMENTS
           PERFORM 6000-CALC-ASSESSMENT
           PERFORM 7000-CHECK-SURCHARGE
           PERFORM 9000-REPORT
           STOP RUN.
       1000-INITIALIZE.
           MOVE 1 TO RE-CAT(1)
           MOVE 0.000150 TO RE-MIN-RATE(1)
           MOVE 0.000700 TO RE-MAX-RATE(1)
           MOVE 2 TO RE-CAT(2)
           MOVE 0.000300 TO RE-MIN-RATE(2)
           MOVE 0.001500 TO RE-MAX-RATE(2)
           MOVE 3 TO RE-CAT(3)
           MOVE 0.000800 TO RE-MIN-RATE(3)
           MOVE 0.002300 TO RE-MAX-RATE(3)
           MOVE 4 TO RE-CAT(4)
           MOVE 0.001200 TO RE-MIN-RATE(4)
           MOVE 0.003000 TO RE-MAX-RATE(4).
       2000-CALC-RATIOS.
           IF BD-TOTAL-ASSETS > ZERO
               COMPUTE WS-LEVERAGE-RATIO ROUNDED =
                   (BD-TIER1-CAPITAL / BD-TOTAL-ASSETS)
                   * 100
           END-IF
           IF BD-RISK-WT-ASSETS > ZERO
               COMPUTE WS-TIER1-RATIO ROUNDED =
                   (BD-TIER1-CAPITAL / BD-RISK-WT-ASSETS)
                   * 100
               COMPUTE WS-TOTAL-CAP-RATIO ROUNDED =
                   (BD-TOTAL-CAPITAL / BD-RISK-WT-ASSETS)
                   * 100
           END-IF
           IF BD-TOTAL-DEPOSITS > ZERO
               COMPUTE WS-BROKERED-PCT ROUNDED =
                   (BD-BROKERED-DEP / BD-TOTAL-DEPOSITS)
                   * 100
           END-IF
           IF WS-LEVERAGE-RATIO >= 5 AND
              WS-TIER1-RATIO >= 6 AND
              WS-TOTAL-CAP-RATIO >= 10
               MOVE 'Y' TO WS-WELL-CAP-FLAG
           END-IF.
       3000-DETERMINE-CATEGORY.
           EVALUATE TRUE
               WHEN IS-WELL-CAP AND
                    BD-CAMELS-RATING <= 2
                   MOVE 1 TO WS-RISK-CATEGORY
                   MOVE 'RISK CATEGORY I' TO WS-CAT-DESC
               WHEN IS-WELL-CAP AND
                    BD-CAMELS-RATING = 3
                   MOVE 2 TO WS-RISK-CATEGORY
                   MOVE 'RISK CATEGORY II' TO WS-CAT-DESC
               WHEN BD-CAMELS-RATING = 4
                   MOVE 3 TO WS-RISK-CATEGORY
                   MOVE 'RISK CATEGORY III' TO WS-CAT-DESC
               WHEN OTHER
                   MOVE 4 TO WS-RISK-CATEGORY
                   MOVE 'RISK CATEGORY IV' TO WS-CAT-DESC
           END-EVALUATE.
       4000-CALC-BASE-RATE.
           IF WS-RISK-CATEGORY >= 1 AND
              WS-RISK-CATEGORY <= 4
               MOVE RE-MIN-RATE(WS-RISK-CATEGORY) TO
                   WS-INITIAL-RATE
           ELSE
               MOVE 0.001000 TO WS-INITIAL-RATE
           END-IF.
       5000-APPLY-ADJUSTMENTS.
           MOVE ZERO TO WS-CAMELS-ADJ
           MOVE ZERO TO WS-BROKERED-ADJ
           EVALUATE BD-CAMELS-RATING
               WHEN 1
                   COMPUTE WS-CAMELS-ADJ =
                       WS-INITIAL-RATE * -0.10
               WHEN 2
                   MOVE ZERO TO WS-CAMELS-ADJ
               WHEN 3
                   COMPUTE WS-CAMELS-ADJ =
                       WS-INITIAL-RATE * 0.15
               WHEN 4
                   COMPUTE WS-CAMELS-ADJ =
                       WS-INITIAL-RATE * 0.30
               WHEN 5
                   COMPUTE WS-CAMELS-ADJ =
                       WS-INITIAL-RATE * 0.50
               WHEN OTHER
                   MOVE ZERO TO WS-CAMELS-ADJ
           END-EVALUATE
           IF WS-BROKERED-PCT > 10.00
               COMPUTE WS-BROKERED-ADJ =
                   WS-INITIAL-RATE * 0.05
           END-IF
           COMPUTE WS-ADJUSTED-RATE =
               WS-INITIAL-RATE + WS-CAMELS-ADJ +
               WS-BROKERED-ADJ.
       6000-CALC-ASSESSMENT.
           COMPUTE WS-ASSESS-BASE =
               BD-TOTAL-ASSETS - BD-TIER1-CAPITAL
           COMPUTE WS-QUARTERLY-ASSESS ROUNDED =
               WS-ASSESS-BASE * WS-ADJUSTED-RATE / 4
           COMPUTE WS-ANNUAL-ASSESS =
               WS-QUARTERLY-ASSESS * 4.
       7000-CHECK-SURCHARGE.
           IF BD-TOTAL-ASSETS >= WS-LARGE-THRESHOLD
               MOVE 'Y' TO WS-LARGE-BANK-FLAG
               COMPUTE WS-SURCHARGE-AMT ROUNDED =
                   WS-ASSESS-BASE * WS-SURCHARGE-RATE / 4
               ADD WS-SURCHARGE-AMT TO WS-QUARTERLY-ASSESS
           END-IF.
       9000-REPORT.
           DISPLAY 'FDIC ASSESSMENT CALCULATION'
           DISPLAY 'BANK:          ' BD-BANK-NAME
           DISPLAY 'TOTAL ASSETS:  ' BD-TOTAL-ASSETS
           DISPLAY 'LEVERAGE:      ' WS-LEVERAGE-RATIO '%'
           DISPLAY 'TIER1 RATIO:   ' WS-TIER1-RATIO '%'
           DISPLAY 'TOTAL CAP:     ' WS-TOTAL-CAP-RATIO '%'
           DISPLAY 'CATEGORY:      ' WS-CAT-DESC
           DISPLAY 'BASE RATE:     ' WS-INITIAL-RATE
           DISPLAY 'ADJ RATE:      ' WS-ADJUSTED-RATE
           DISPLAY 'QTR ASSESS:    ' WS-QUARTERLY-ASSESS
           IF IS-LARGE-BANK
               DISPLAY 'SURCHARGE:     ' WS-SURCHARGE-AMT
           END-IF.
