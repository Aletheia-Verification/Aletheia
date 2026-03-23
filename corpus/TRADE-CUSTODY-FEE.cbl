       IDENTIFICATION DIVISION.
       PROGRAM-ID. TRADE-CUSTODY-FEE.
      *================================================================*
      * Trade custody fee calculator with tiered asset-class rates.    *
      * Constructs: EVALUATE, PERFORM VARYING, IF/ELSE, COMPUTE, ADD, *
      *   DISPLAY, 88-level, OCCURS subscript, COMP-3                 *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-PORTFOLIO-DATA.
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-TOTAL-AUM           PIC S9(13)V99 COMP-3.
       01 WS-ASSET-TABLE.
           05 WS-ASSET OCCURS 6.
               10 WS-AS-TYPE         PIC X(10).
               10 WS-AS-VALUE        PIC S9(11)V99 COMP-3.
               10 WS-AS-FEE-RATE     PIC S9(1)V9(6) COMP-3.
               10 WS-AS-FEE          PIC S9(7)V99 COMP-3.
       01 WS-AS-IDX                  PIC 9(1).
       01 WS-TOTAL-FEE               PIC S9(9)V99 COMP-3.
       01 WS-MIN-FEE                 PIC S9(7)V99 COMP-3
           VALUE 500.00.
       01 WS-QUARTERLY-FEE           PIC S9(9)V99 COMP-3.
       01 WS-TIER-TYPE               PIC X(1).
           88 WS-STANDARD-TIER       VALUE 'S'.
           88 WS-INSTITUTIONAL       VALUE 'I'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-SET-RATES
           PERFORM 3000-CALC-FEES
           PERFORM 4000-APPLY-MINIMUM
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-FEE.
       2000-SET-RATES.
           EVALUATE TRUE
               WHEN WS-STANDARD-TIER
                   PERFORM 2100-SET-STANDARD-RATES
               WHEN WS-INSTITUTIONAL
                   PERFORM 2200-SET-INST-RATES
           END-EVALUATE.
       2100-SET-STANDARD-RATES.
           PERFORM VARYING WS-AS-IDX FROM 1 BY 1
               UNTIL WS-AS-IDX > 6
               IF WS-AS-TYPE(WS-AS-IDX) = 'EQUITY'
                   MOVE 0.0025 TO WS-AS-FEE-RATE(WS-AS-IDX)
               ELSE
                   IF WS-AS-TYPE(WS-AS-IDX) = 'FIXED-INC'
                       MOVE 0.0015 TO
                           WS-AS-FEE-RATE(WS-AS-IDX)
                   ELSE
                       MOVE 0.0020 TO
                           WS-AS-FEE-RATE(WS-AS-IDX)
                   END-IF
               END-IF
           END-PERFORM.
       2200-SET-INST-RATES.
           PERFORM VARYING WS-AS-IDX FROM 1 BY 1
               UNTIL WS-AS-IDX > 6
               MOVE 0.0010 TO WS-AS-FEE-RATE(WS-AS-IDX)
           END-PERFORM.
       3000-CALC-FEES.
           PERFORM VARYING WS-AS-IDX FROM 1 BY 1
               UNTIL WS-AS-IDX > 6
               COMPUTE WS-AS-FEE(WS-AS-IDX) =
                   WS-AS-VALUE(WS-AS-IDX) *
                   WS-AS-FEE-RATE(WS-AS-IDX)
               ADD WS-AS-FEE(WS-AS-IDX) TO WS-TOTAL-FEE
           END-PERFORM
           COMPUTE WS-QUARTERLY-FEE =
               WS-TOTAL-FEE / 4.
       4000-APPLY-MINIMUM.
           IF WS-TOTAL-FEE < WS-MIN-FEE
               MOVE WS-MIN-FEE TO WS-TOTAL-FEE
               COMPUTE WS-QUARTERLY-FEE =
                   WS-TOTAL-FEE / 4
           END-IF.
       5000-DISPLAY-RESULTS.
           DISPLAY 'CUSTODY FEE CALCULATION'
           DISPLAY '======================='
           DISPLAY 'ACCOUNT:        ' WS-ACCT-NUM
           DISPLAY 'TOTAL AUM:      ' WS-TOTAL-AUM
           DISPLAY 'ANNUAL FEE:     ' WS-TOTAL-FEE
           DISPLAY 'QUARTERLY FEE:  ' WS-QUARTERLY-FEE
           PERFORM VARYING WS-AS-IDX FROM 1 BY 1
               UNTIL WS-AS-IDX > 6
               IF WS-AS-VALUE(WS-AS-IDX) > 0
                   DISPLAY '  ' WS-AS-TYPE(WS-AS-IDX)
                       ' VAL=' WS-AS-VALUE(WS-AS-IDX)
                       ' RATE=' WS-AS-FEE-RATE(WS-AS-IDX)
                       ' FEE=' WS-AS-FEE(WS-AS-IDX)
               END-IF
           END-PERFORM.
