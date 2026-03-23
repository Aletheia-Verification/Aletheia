       IDENTIFICATION DIVISION.
       PROGRAM-ID. FED-DISCOUNT-WIN.
      *================================================================
      * Federal Reserve Discount Window Borrowing Calculator
      * Computes borrowing costs, collateral haircuts, and
      * available capacity for primary/secondary credit.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-BORROWER-INFO.
           05 WS-FRB-DISTRICT         PIC 9(2).
           05 WS-BANK-ABA             PIC X(9).
           05 WS-BANK-NAME            PIC X(30).
           05 WS-CREDIT-PROGRAM       PIC X(1).
               88 WS-PRIMARY           VALUE 'P'.
               88 WS-SECONDARY         VALUE 'S'.
               88 WS-SEASONAL          VALUE 'E'.
       01 WS-RATE-DATA.
           05 WS-PRIMARY-RATE         PIC S9(2)V9(4) COMP-3.
           05 WS-SECONDARY-RATE       PIC S9(2)V9(4) COMP-3.
           05 WS-SEASONAL-RATE        PIC S9(2)V9(4) COMP-3.
           05 WS-APPLICABLE-RATE      PIC S9(2)V9(4) COMP-3.
       01 WS-COLLATERAL-TABLE.
           05 WS-COLL OCCURS 8
              ASCENDING KEY IS WS-CL-TYPE
              INDEXED BY WS-CL-IDX.
               10 WS-CL-TYPE          PIC X(3).
               10 WS-CL-DESC          PIC X(20).
               10 WS-CL-MARKET-VALUE  PIC S9(13)V99 COMP-3.
               10 WS-CL-HAIRCUT       PIC S9(1)V9(4) COMP-3.
               10 WS-CL-LENDABLE      PIC S9(13)V99 COMP-3.
       01 WS-CL-COUNT                 PIC 9(1) VALUE 8.
       01 WS-BORROWING-FIELDS.
           05 WS-REQUESTED-AMT        PIC S9(13)V99 COMP-3.
           05 WS-TOTAL-LENDABLE       PIC S9(13)V99 COMP-3.
           05 WS-APPROVED-AMT         PIC S9(13)V99 COMP-3.
           05 WS-AVAILABLE-CAP        PIC S9(13)V99 COMP-3.
       01 WS-COST-FIELDS.
           05 WS-DAYS-BORROWED        PIC 9(3).
           05 WS-DAILY-COST           PIC S9(9)V99 COMP-3.
           05 WS-TOTAL-COST           PIC S9(9)V99 COMP-3.
           05 WS-DAY-COUNT-BASIS      PIC 9(3) VALUE 360.
       01 WS-FREQUENCY-CHECK.
           05 WS-BORROWS-THIS-QTR     PIC 9(3).
           05 WS-FREQUENCY-ALERT      PIC X(1).
               88 WS-FREQ-OK          VALUE 'N'.
               88 WS-FREQ-HIGH        VALUE 'Y'.
           05 WS-FREQ-THRESHOLD       PIC 9(3) VALUE 3.
       01 WS-WORK-FIELDS.
           05 WS-TEMP-AMT             PIC S9(13)V99 COMP-3.
           05 WS-TEMP-RATE            PIC S9(2)V9(4) COMP-3.
           05 WS-SEARCH-TYPE          PIC X(3).
       01 WS-MULT-FIELDS.
           05 WS-RATE-TIMES-DAYS      PIC S9(9)V99 COMP-3.
           05 WS-MULT-REMAINDER       PIC S9(5)V99 COMP-3.
       01 WS-PROCESS-DATE             PIC 9(8).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-SET-RATE
           PERFORM 3000-VALUE-COLLATERAL
           PERFORM 4000-APPROVE-BORROWING
           PERFORM 5000-CALC-COST
           PERFORM 6000-CHECK-FREQUENCY
           PERFORM 7000-DISPLAY-REPORT
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-PROCESS-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-TOTAL-LENDABLE
           MOVE 0 TO WS-TOTAL-COST
           SET WS-FREQ-OK TO TRUE.
       2000-SET-RATE.
           EVALUATE TRUE
               WHEN WS-PRIMARY
                   MOVE WS-PRIMARY-RATE
                       TO WS-APPLICABLE-RATE
               WHEN WS-SECONDARY
                   MOVE WS-SECONDARY-RATE
                       TO WS-APPLICABLE-RATE
               WHEN WS-SEASONAL
                   MOVE WS-SEASONAL-RATE
                       TO WS-APPLICABLE-RATE
               WHEN OTHER
                   MOVE WS-PRIMARY-RATE
                       TO WS-APPLICABLE-RATE
           END-EVALUATE.
       3000-VALUE-COLLATERAL.
           PERFORM VARYING WS-CL-IDX FROM 1 BY 1
               UNTIL WS-CL-IDX > WS-CL-COUNT
               COMPUTE WS-CL-LENDABLE(WS-CL-IDX) =
                   WS-CL-MARKET-VALUE(WS-CL-IDX) *
                   (1 - WS-CL-HAIRCUT(WS-CL-IDX))
               ADD WS-CL-LENDABLE(WS-CL-IDX)
                   TO WS-TOTAL-LENDABLE
           END-PERFORM.
       4000-APPROVE-BORROWING.
           IF WS-REQUESTED-AMT <= WS-TOTAL-LENDABLE
               MOVE WS-REQUESTED-AMT TO WS-APPROVED-AMT
           ELSE
               MOVE WS-TOTAL-LENDABLE TO WS-APPROVED-AMT
           END-IF
           COMPUTE WS-AVAILABLE-CAP =
               WS-TOTAL-LENDABLE - WS-APPROVED-AMT.
       5000-CALC-COST.
           COMPUTE WS-DAILY-COST =
               WS-APPROVED-AMT * WS-APPLICABLE-RATE /
               100 / WS-DAY-COUNT-BASIS
           MULTIPLY WS-DAILY-COST BY WS-DAYS-BORROWED
               GIVING WS-TOTAL-COST
               REMAINDER WS-MULT-REMAINDER.
       6000-CHECK-FREQUENCY.
           ADD 1 TO WS-BORROWS-THIS-QTR
           IF WS-BORROWS-THIS-QTR > WS-FREQ-THRESHOLD
               SET WS-FREQ-HIGH TO TRUE
           END-IF.
       7000-DISPLAY-REPORT.
           DISPLAY "DISCOUNT WINDOW BORROWING"
           DISPLAY "DATE: " WS-PROCESS-DATE
           DISPLAY "BANK: " WS-BANK-NAME
           DISPLAY "ABA: " WS-BANK-ABA
           DISPLAY "PROGRAM: " WS-CREDIT-PROGRAM
           DISPLAY "RATE: " WS-APPLICABLE-RATE "%"
           DISPLAY "COLLATERAL VALUE: "
               WS-TOTAL-LENDABLE
           DISPLAY "REQUESTED: " WS-REQUESTED-AMT
           DISPLAY "APPROVED: " WS-APPROVED-AMT
           DISPLAY "DAYS: " WS-DAYS-BORROWED
           DISPLAY "TOTAL COST: " WS-TOTAL-COST
           DISPLAY "REMAINING CAPACITY: "
               WS-AVAILABLE-CAP
           IF WS-FREQ-HIGH
               DISPLAY "ALERT: FREQUENT BORROWER"
           END-IF.
