       IDENTIFICATION DIVISION.
       PROGRAM-ID. FED-FUNDS-APPLY.
      *================================================================
      * Federal Funds Rate Application Engine
      * Applies FOMC rate decisions to bank product pricing,
      * computes prime rate, deposit rate adjustments, margin impact.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-RATE-DECISION.
           05 WS-FOMC-DATE             PIC 9(8).
           05 WS-TARGET-LOW            PIC S9(2)V9(4) COMP-3.
           05 WS-TARGET-HIGH           PIC S9(2)V9(4) COMP-3.
           05 WS-EFFECTIVE-RATE        PIC S9(2)V9(4) COMP-3.
           05 WS-PRIOR-RATE            PIC S9(2)V9(4) COMP-3.
           05 WS-RATE-CHANGE           PIC S9(2)V9(4) COMP-3.
           05 WS-DIRECTION             PIC X(1).
               88 WS-HIKE              VALUE 'H'.
               88 WS-CUT               VALUE 'C'.
               88 WS-HOLD              VALUE 'X'.
       01 WS-PRODUCT-TABLE.
           05 WS-PRODUCT OCCURS 10
              ASCENDING KEY IS WS-PROD-CODE
              INDEXED BY WS-PROD-IDX.
               10 WS-PROD-CODE         PIC X(4).
               10 WS-PROD-NAME         PIC X(20).
               10 WS-PROD-SPREAD       PIC S9(2)V9(4) COMP-3.
               10 WS-PROD-FLOOR        PIC S9(2)V9(4) COMP-3.
               10 WS-PROD-CEILING      PIC S9(2)V9(4) COMP-3.
               10 WS-PROD-OLD-RATE     PIC S9(2)V9(4) COMP-3.
               10 WS-PROD-NEW-RATE     PIC S9(2)V9(4) COMP-3.
               10 WS-PROD-BALANCE      PIC S9(13)V99 COMP-3.
       01 WS-PROD-COUNT                PIC 9(2) VALUE 10.
       01 WS-PRICING-FIELDS.
           05 WS-PRIME-RATE            PIC S9(2)V9(4) COMP-3.
           05 WS-PRIME-SPREAD          PIC S9(2)V9(4) COMP-3
               VALUE 3.0000.
           05 WS-NEW-PRIME             PIC S9(2)V9(4) COMP-3.
       01 WS-MARGIN-IMPACT.
           05 WS-TOTAL-ASSET-BAL       PIC S9(15)V99 COMP-3.
           05 WS-TOTAL-LIAB-BAL        PIC S9(15)V99 COMP-3.
           05 WS-ASSET-REPRICING       PIC S9(13)V99 COMP-3.
           05 WS-LIAB-REPRICING        PIC S9(13)V99 COMP-3.
           05 WS-GAP                   PIC S9(13)V99 COMP-3.
           05 WS-NII-IMPACT            PIC S9(11)V99 COMP-3.
       01 WS-DEPOSIT-BETA.
           05 WS-SAVINGS-BETA          PIC S9(1)V9(4) COMP-3
               VALUE 0.3000.
           05 WS-MMDA-BETA             PIC S9(1)V9(4) COMP-3
               VALUE 0.5000.
           05 WS-CD-BETA               PIC S9(1)V9(4) COMP-3
               VALUE 0.8000.
       01 WS-WORK-FIELDS.
           05 WS-TEMP-RATE             PIC S9(2)V9(4) COMP-3.
           05 WS-TEMP-IMPACT           PIC S9(11)V99 COMP-3.
           05 WS-SEARCH-PROD           PIC X(4).
       01 WS-SIGN-IMPACT
           PIC S9(9)V99 SIGN IS LEADING SEPARATE.
       01 WS-PROCESS-DATE              PIC 9(8).
       01 WS-REPORT-LINE               PIC X(80).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-DETERMINE-DIRECTION
           PERFORM 3000-CALC-PRIME
           PERFORM 4000-REPRICE-PRODUCTS
           PERFORM 5000-CALC-MARGIN-IMPACT
           PERFORM 6000-FORMAT-SIGN-OUTPUT
           PERFORM 7000-DISPLAY-REPORT
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-PROCESS-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-NII-IMPACT
           MOVE 0 TO WS-GAP.
       2000-DETERMINE-DIRECTION.
           COMPUTE WS-RATE-CHANGE =
               WS-EFFECTIVE-RATE - WS-PRIOR-RATE
           IF WS-RATE-CHANGE > 0
               SET WS-HIKE TO TRUE
           ELSE IF WS-RATE-CHANGE < 0
               SET WS-CUT TO TRUE
           ELSE
               SET WS-HOLD TO TRUE
           END-IF.
       3000-CALC-PRIME.
           COMPUTE WS-NEW-PRIME =
               WS-EFFECTIVE-RATE + WS-PRIME-SPREAD.
       4000-REPRICE-PRODUCTS.
           PERFORM VARYING WS-PROD-IDX FROM 1 BY 1
               UNTIL WS-PROD-IDX > WS-PROD-COUNT
               MOVE WS-PROD-NEW-RATE(WS-PROD-IDX)
                   TO WS-PROD-OLD-RATE(WS-PROD-IDX)
               COMPUTE WS-TEMP-RATE =
                   WS-EFFECTIVE-RATE +
                   WS-PROD-SPREAD(WS-PROD-IDX)
               IF WS-TEMP-RATE < WS-PROD-FLOOR(WS-PROD-IDX)
                   MOVE WS-PROD-FLOOR(WS-PROD-IDX)
                       TO WS-PROD-NEW-RATE(WS-PROD-IDX)
               ELSE IF WS-TEMP-RATE >
                   WS-PROD-CEILING(WS-PROD-IDX)
                   MOVE WS-PROD-CEILING(WS-PROD-IDX)
                       TO WS-PROD-NEW-RATE(WS-PROD-IDX)
               ELSE
                   MOVE WS-TEMP-RATE
                       TO WS-PROD-NEW-RATE(WS-PROD-IDX)
               END-IF
           END-PERFORM.
       5000-CALC-MARGIN-IMPACT.
           COMPUTE WS-GAP =
               WS-ASSET-REPRICING - WS-LIAB-REPRICING
           COMPUTE WS-NII-IMPACT =
               WS-GAP * (WS-RATE-CHANGE / 100).
       6000-FORMAT-SIGN-OUTPUT.
           COMPUTE WS-SIGN-IMPACT = WS-NII-IMPACT.
       7000-DISPLAY-REPORT.
           DISPLAY "FED FUNDS RATE APPLICATION"
           DISPLAY "DATE: " WS-PROCESS-DATE
           DISPLAY "FOMC DATE: " WS-FOMC-DATE
           DISPLAY "PRIOR RATE: " WS-PRIOR-RATE "%"
           DISPLAY "NEW RATE: " WS-EFFECTIVE-RATE "%"
           DISPLAY "CHANGE: " WS-RATE-CHANGE
           EVALUATE TRUE
               WHEN WS-HIKE
                   DISPLAY "DIRECTION: RATE HIKE"
               WHEN WS-CUT
                   DISPLAY "DIRECTION: RATE CUT"
               WHEN WS-HOLD
                   DISPLAY "DIRECTION: NO CHANGE"
           END-EVALUATE
           DISPLAY "NEW PRIME: " WS-NEW-PRIME "%"
           DISPLAY "RATE GAP: " WS-GAP
           DISPLAY "NII IMPACT: " WS-SIGN-IMPACT
           PERFORM VARYING WS-PROD-IDX FROM 1 BY 1
               UNTIL WS-PROD-IDX > WS-PROD-COUNT
               DISPLAY "  " WS-PROD-CODE(WS-PROD-IDX)
                   " " WS-PROD-OLD-RATE(WS-PROD-IDX)
                   " -> " WS-PROD-NEW-RATE(WS-PROD-IDX)
           END-PERFORM.
