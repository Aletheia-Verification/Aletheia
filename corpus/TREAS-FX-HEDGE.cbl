       IDENTIFICATION DIVISION.
       PROGRAM-ID. TREAS-FX-HEDGE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-EXPOSURE-TABLE.
           05 WS-EXPOSURE OCCURS 10 TIMES.
               10 WS-EXP-CCY       PIC X(3).
               10 WS-EXP-AMOUNT    PIC S9(11)V99 COMP-3.
               10 WS-EXP-MATURITY  PIC 9(8).
               10 WS-EXP-TYPE      PIC X(1).
                   88 EXP-RECEIVABLE VALUE 'R'.
                   88 EXP-PAYABLE    VALUE 'P'.
               10 WS-HEDGE-RATIO   PIC S9(1)V99 COMP-3.
               10 WS-HEDGE-AMT     PIC S9(11)V99 COMP-3.
       01 WS-FX-RATES.
           05 WS-RATE-ENTRY OCCURS 5 TIMES.
               10 WS-RATE-CCY      PIC X(3).
               10 WS-SPOT-RATE     PIC S9(3)V9(6) COMP-3.
               10 WS-FWD-RATE      PIC S9(3)V9(6) COMP-3.
               10 WS-FWD-POINTS    PIC S9(5)V99 COMP-3.
       01 WS-EXP-COUNT            PIC 99 VALUE 10.
       01 WS-RATE-COUNT            PIC 99 VALUE 5.
       01 WS-IDX                   PIC 99.
       01 WS-JDX                   PIC 99.
       01 WS-NET-EXPOSURE          PIC S9(13)V99 COMP-3.
       01 WS-USD-EQUIVALENT        PIC S9(13)V99 COMP-3.
       01 WS-TOTAL-HEDGED          PIC S9(13)V99 COMP-3.
       01 WS-TOTAL-UNHEDGED        PIC S9(13)V99 COMP-3.
       01 WS-MATCHED-RATE          PIC S9(3)V9(6) COMP-3.
       01 WS-RATE-FOUND            PIC X VALUE 'N'.
           88 RATE-FOUND           VALUE 'Y'.
       01 WS-CURRENT-DATE          PIC 9(8).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-CALC-HEDGES
           PERFORM 3000-NET-EXPOSURES
           PERFORM 4000-REPORT
           STOP RUN.
       1000-INIT.
           MOVE 0 TO WS-TOTAL-HEDGED
           MOVE 0 TO WS-TOTAL-UNHEDGED
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD.
       2000-CALC-HEDGES.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-EXP-COUNT
               PERFORM 2100-FIND-RATE
               IF RATE-FOUND
                   PERFORM 2200-APPLY-HEDGE
               ELSE
                   MOVE 0 TO WS-HEDGE-AMT(WS-IDX)
               END-IF
           END-PERFORM.
       2100-FIND-RATE.
           MOVE 'N' TO WS-RATE-FOUND
           PERFORM VARYING WS-JDX FROM 1 BY 1
               UNTIL WS-JDX > WS-RATE-COUNT
               IF WS-RATE-CCY(WS-JDX) =
                   WS-EXP-CCY(WS-IDX)
                   MOVE WS-FWD-RATE(WS-JDX) TO
                       WS-MATCHED-RATE
                   MOVE 'Y' TO WS-RATE-FOUND
               END-IF
           END-PERFORM.
       2200-APPLY-HEDGE.
           COMPUTE WS-HEDGE-AMT(WS-IDX) =
               WS-EXP-AMOUNT(WS-IDX) *
               WS-HEDGE-RATIO(WS-IDX)
           COMPUTE WS-USD-EQUIVALENT =
               WS-HEDGE-AMT(WS-IDX) * WS-MATCHED-RATE
           ADD WS-USD-EQUIVALENT TO WS-TOTAL-HEDGED
           COMPUTE WS-NET-EXPOSURE =
               WS-EXP-AMOUNT(WS-IDX) - WS-HEDGE-AMT(WS-IDX)
           COMPUTE WS-USD-EQUIVALENT =
               WS-NET-EXPOSURE * WS-MATCHED-RATE
           ADD WS-USD-EQUIVALENT TO WS-TOTAL-UNHEDGED.
       3000-NET-EXPOSURES.
           COMPUTE WS-NET-EXPOSURE =
               WS-TOTAL-HEDGED + WS-TOTAL-UNHEDGED.
       4000-REPORT.
           DISPLAY 'FX HEDGE POSITION REPORT'
           DISPLAY '========================'
           DISPLAY 'DATE: ' WS-CURRENT-DATE
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-EXP-COUNT
               IF WS-EXP-AMOUNT(WS-IDX) NOT = 0
                   DISPLAY '  ' WS-EXP-CCY(WS-IDX)
                       ' EXP=' WS-EXP-AMOUNT(WS-IDX)
                       ' HDG=' WS-HEDGE-AMT(WS-IDX)
               END-IF
           END-PERFORM
           DISPLAY 'TOTAL HEDGED (USD):   $' WS-TOTAL-HEDGED
           DISPLAY 'TOTAL UNHEDGED (USD): $' WS-TOTAL-UNHEDGED
           DISPLAY 'NET POSITION:         $' WS-NET-EXPOSURE.
