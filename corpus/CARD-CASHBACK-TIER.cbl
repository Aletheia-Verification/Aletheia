       IDENTIFICATION DIVISION.
       PROGRAM-ID. CARD-CASHBACK-TIER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-PROGRAM-DATA.
           05 WS-CARD-NUM        PIC X(16).
           05 WS-PROGRAM-TYPE    PIC X(1).
               88 PG-FLAT        VALUE 'F'.
               88 PG-TIERED      VALUE 'T'.
               88 PG-ROTATING    VALUE 'R'.
           05 WS-QTR-SPEND       PIC S9(9)V99 COMP-3.
           05 WS-YTD-CASHBACK    PIC S9(7)V99 COMP-3.
       01 WS-MONTHLY-TXNS.
           05 WS-MO-TXN OCCURS 20 TIMES.
               10 WS-MT-AMT      PIC S9(5)V99 COMP-3.
               10 WS-MT-CAT      PIC X(2).
               10 WS-MT-DATE     PIC 9(8).
       01 WS-MT-COUNT            PIC 99 VALUE 20.
       01 WS-IDX                 PIC 99.
       01 WS-CAT-GROCERY         PIC S9(7)V99 COMP-3.
       01 WS-CAT-GAS             PIC S9(7)V99 COMP-3.
       01 WS-CAT-DINING          PIC S9(7)V99 COMP-3.
       01 WS-CAT-OTHER           PIC S9(7)V99 COMP-3.
       01 WS-CB-GROCERY          PIC S9(5)V99 COMP-3.
       01 WS-CB-GAS              PIC S9(5)V99 COMP-3.
       01 WS-CB-DINING           PIC S9(5)V99 COMP-3.
       01 WS-CB-OTHER            PIC S9(5)V99 COMP-3.
       01 WS-TOTAL-CB            PIC S9(7)V99 COMP-3.
       01 WS-CAP-REACHED         PIC X VALUE 'N'.
           88 HIT-CAP            VALUE 'Y'.
       01 WS-QUARTERLY-CAP       PIC S9(5)V99 COMP-3
           VALUE 75.00.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-CATEGORIZE
           PERFORM 3000-CALC-CASHBACK
           PERFORM 4000-APPLY-CAP
           PERFORM 5000-OUTPUT
           STOP RUN.
       1000-INIT.
           MOVE 0 TO WS-CAT-GROCERY
           MOVE 0 TO WS-CAT-GAS
           MOVE 0 TO WS-CAT-DINING
           MOVE 0 TO WS-CAT-OTHER
           MOVE 0 TO WS-TOTAL-CB.
       2000-CATEGORIZE.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-MT-COUNT
               EVALUATE WS-MT-CAT(WS-IDX)
                   WHEN 'GR'
                       ADD WS-MT-AMT(WS-IDX)
                           TO WS-CAT-GROCERY
                   WHEN 'GS'
                       ADD WS-MT-AMT(WS-IDX)
                           TO WS-CAT-GAS
                   WHEN 'DN'
                       ADD WS-MT-AMT(WS-IDX)
                           TO WS-CAT-DINING
                   WHEN OTHER
                       ADD WS-MT-AMT(WS-IDX)
                           TO WS-CAT-OTHER
               END-EVALUATE
           END-PERFORM.
       3000-CALC-CASHBACK.
           IF PG-FLAT
               COMPUTE WS-TOTAL-CB =
                   (WS-CAT-GROCERY + WS-CAT-GAS +
                    WS-CAT-DINING + WS-CAT-OTHER) * 0.015
           ELSE
               COMPUTE WS-CB-GROCERY =
                   WS-CAT-GROCERY * 0.03
               COMPUTE WS-CB-GAS =
                   WS-CAT-GAS * 0.03
               COMPUTE WS-CB-DINING =
                   WS-CAT-DINING * 0.02
               COMPUTE WS-CB-OTHER =
                   WS-CAT-OTHER * 0.01
               COMPUTE WS-TOTAL-CB =
                   WS-CB-GROCERY + WS-CB-GAS +
                   WS-CB-DINING + WS-CB-OTHER
           END-IF.
       4000-APPLY-CAP.
           IF PG-TIERED OR PG-ROTATING
               IF WS-TOTAL-CB > WS-QUARTERLY-CAP
                   MOVE WS-QUARTERLY-CAP TO WS-TOTAL-CB
                   MOVE 'Y' TO WS-CAP-REACHED
               END-IF
           END-IF
           ADD WS-TOTAL-CB TO WS-YTD-CASHBACK.
       5000-OUTPUT.
           DISPLAY 'CASHBACK CALCULATION'
           DISPLAY '===================='
           DISPLAY 'CARD:      ' WS-CARD-NUM
           DISPLAY 'PROGRAM:   ' WS-PROGRAM-TYPE
           DISPLAY 'GROCERY:   $' WS-CAT-GROCERY
               ' CB=$' WS-CB-GROCERY
           DISPLAY 'GAS:       $' WS-CAT-GAS
               ' CB=$' WS-CB-GAS
           DISPLAY 'DINING:    $' WS-CAT-DINING
               ' CB=$' WS-CB-DINING
           DISPLAY 'OTHER:     $' WS-CAT-OTHER
               ' CB=$' WS-CB-OTHER
           DISPLAY 'TOTAL CB:  $' WS-TOTAL-CB
           DISPLAY 'YTD CB:    $' WS-YTD-CASHBACK
           IF HIT-CAP
               DISPLAY 'QUARTERLY CAP REACHED'
           END-IF.
