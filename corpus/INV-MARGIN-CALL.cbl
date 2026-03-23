       IDENTIFICATION DIVISION.
       PROGRAM-ID. INV-MARGIN-CALL.
      *================================================================
      * MARGIN CALL PROCESSOR
      * Evaluates margin accounts for maintenance margin violations,
      * calculates required deposits, and generates margin calls.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-MARGIN-ACCT.
           05 WS-MA-ACCT-NUM          PIC X(10).
           05 WS-MA-ACCT-TYPE         PIC X(1).
               88 MA-REG-T            VALUE 'T'.
               88 MA-PORTFOLIO        VALUE 'P'.
           05 WS-MA-EQUITY            PIC S9(11)V99 COMP-3.
           05 WS-MA-DEBIT-BAL         PIC S9(11)V99 COMP-3.
           05 WS-MA-LONG-MKT-VAL     PIC S9(13)V99 COMP-3.
           05 WS-MA-SHORT-MKT-VAL    PIC S9(13)V99 COMP-3.
       01 WS-POSITIONS.
           05 WS-POS-ENTRY OCCURS 10 TIMES.
               10 WS-PE-SYMBOL        PIC X(6).
               10 WS-PE-SHARES        PIC S9(9) COMP-3.
               10 WS-PE-PRICE         PIC S9(5)V9(4) COMP-3.
               10 WS-PE-MKT-VALUE     PIC S9(11)V99 COMP-3.
               10 WS-PE-MAINT-REQ     PIC S9(1)V99 COMP-3.
               10 WS-PE-TYPE          PIC X(1).
                   88 PE-LONG         VALUE 'L'.
                   88 PE-SHORT        VALUE 'S'.
       01 WS-POS-COUNT                PIC 9(2) VALUE 0.
       01 WS-IDX                      PIC 9(2).
       01 WS-MAINT-CALC.
           05 WS-TOTAL-MAINT-REQ     PIC S9(11)V99 COMP-3
               VALUE 0.
           05 WS-MARGIN-RATIO        PIC S9(3)V9(4) COMP-3.
           05 WS-DEFAULT-MAINT       PIC S9(1)V99 COMP-3
               VALUE 0.25.
           05 WS-CONCENTRATED-MAINT  PIC S9(1)V99 COMP-3
               VALUE 0.50.
           05 WS-CONCENTRATION-LIM   PIC S9(1)V99 COMP-3
               VALUE 0.60.
           05 WS-POS-WEIGHT          PIC S9(1)V9(4) COMP-3.
           05 WS-IS-CONCENTRATED     PIC X VALUE 'N'.
               88 WS-CONC-YES        VALUE 'Y'.
       01 WS-MARGIN-CALL.
           05 WS-CALL-REQUIRED       PIC X VALUE 'N'.
               88 CALL-YES           VALUE 'Y'.
               88 CALL-NO            VALUE 'N'.
           05 WS-CALL-AMOUNT         PIC S9(11)V99 COMP-3.
           05 WS-EXCESS-EQUITY       PIC S9(11)V99 COMP-3.
           05 WS-CALL-DUE-DAYS       PIC 9(1) VALUE 3.
           05 WS-LIQUIDATION-AMT     PIC S9(11)V99 COMP-3.
       01 WS-REG-T-INITIAL           PIC S9(1)V99 COMP-3
           VALUE 0.50.
       01 WS-HOUSE-CALL-AMT          PIC S9(11)V99 COMP-3
           VALUE 0.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-LOAD-ACCOUNT
           PERFORM 2000-CALC-MARKET-VALUES
           PERFORM 3000-CALC-EQUITY
           PERFORM 4000-CALC-MAINT-REQUIREMENT
           PERFORM 5000-EVALUATE-MARGIN
           PERFORM 6000-CALC-CALL-AMOUNT
           PERFORM 7000-DISPLAY-RESULTS
           STOP RUN.
       1000-LOAD-ACCOUNT.
           MOVE 'MRG-098765' TO WS-MA-ACCT-NUM
           MOVE 'T' TO WS-MA-ACCT-TYPE
           MOVE 0 TO WS-MA-DEBIT-BAL
           MOVE 'AAPL  ' TO WS-PE-SYMBOL(1)
           MOVE 500 TO WS-PE-SHARES(1)
           MOVE 175.5000 TO WS-PE-PRICE(1)
           MOVE 0.25 TO WS-PE-MAINT-REQ(1)
           MOVE 'L' TO WS-PE-TYPE(1)
           MOVE 'MSFT  ' TO WS-PE-SYMBOL(2)
           MOVE 300 TO WS-PE-SHARES(2)
           MOVE 420.0000 TO WS-PE-PRICE(2)
           MOVE 0.25 TO WS-PE-MAINT-REQ(2)
           MOVE 'L' TO WS-PE-TYPE(2)
           MOVE 'TSLA  ' TO WS-PE-SYMBOL(3)
           MOVE 200 TO WS-PE-SHARES(3)
           MOVE 250.0000 TO WS-PE-PRICE(3)
           MOVE 0.30 TO WS-PE-MAINT-REQ(3)
           MOVE 'L' TO WS-PE-TYPE(3)
           MOVE 3 TO WS-POS-COUNT
           MOVE 100000.00 TO WS-MA-DEBIT-BAL.
       2000-CALC-MARKET-VALUES.
           MOVE 0 TO WS-MA-LONG-MKT-VAL
           MOVE 0 TO WS-MA-SHORT-MKT-VAL
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-POS-COUNT
               COMPUTE WS-PE-MKT-VALUE(WS-IDX) =
                   WS-PE-SHARES(WS-IDX) *
                   WS-PE-PRICE(WS-IDX)
               IF PE-LONG(WS-IDX)
                   ADD WS-PE-MKT-VALUE(WS-IDX)
                       TO WS-MA-LONG-MKT-VAL
               ELSE
                   ADD WS-PE-MKT-VALUE(WS-IDX)
                       TO WS-MA-SHORT-MKT-VAL
               END-IF
           END-PERFORM.
       3000-CALC-EQUITY.
           COMPUTE WS-MA-EQUITY =
               WS-MA-LONG-MKT-VAL - WS-MA-DEBIT-BAL.
       4000-CALC-MAINT-REQUIREMENT.
           MOVE 0 TO WS-TOTAL-MAINT-REQ
           MOVE 'N' TO WS-IS-CONCENTRATED
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-POS-COUNT
               IF WS-MA-LONG-MKT-VAL > 0
                   COMPUTE WS-POS-WEIGHT =
                       WS-PE-MKT-VALUE(WS-IDX) /
                       WS-MA-LONG-MKT-VAL
               ELSE
                   MOVE 0 TO WS-POS-WEIGHT
               END-IF
               IF WS-POS-WEIGHT > WS-CONCENTRATION-LIM
                   MOVE 'Y' TO WS-IS-CONCENTRATED
                   MOVE WS-CONCENTRATED-MAINT
                       TO WS-PE-MAINT-REQ(WS-IDX)
               END-IF
               COMPUTE WS-HOUSE-CALL-AMT =
                   WS-PE-MKT-VALUE(WS-IDX) *
                   WS-PE-MAINT-REQ(WS-IDX)
               ADD WS-HOUSE-CALL-AMT TO WS-TOTAL-MAINT-REQ
           END-PERFORM.
       5000-EVALUATE-MARGIN.
           IF WS-MA-LONG-MKT-VAL > 0
               COMPUTE WS-MARGIN-RATIO =
                   WS-MA-EQUITY / WS-MA-LONG-MKT-VAL
           ELSE
               MOVE 0 TO WS-MARGIN-RATIO
           END-IF
           IF WS-MA-EQUITY < WS-TOTAL-MAINT-REQ
               MOVE 'Y' TO WS-CALL-REQUIRED
           ELSE
               MOVE 'N' TO WS-CALL-REQUIRED
           END-IF.
       6000-CALC-CALL-AMOUNT.
           IF CALL-YES
               COMPUTE WS-CALL-AMOUNT =
                   WS-TOTAL-MAINT-REQ - WS-MA-EQUITY
               COMPUTE WS-EXCESS-EQUITY = 0
               COMPUTE WS-LIQUIDATION-AMT =
                   WS-CALL-AMOUNT * 1.33
           ELSE
               MOVE 0 TO WS-CALL-AMOUNT
               COMPUTE WS-EXCESS-EQUITY =
                   WS-MA-EQUITY - WS-TOTAL-MAINT-REQ
               MOVE 0 TO WS-LIQUIDATION-AMT
           END-IF.
       7000-DISPLAY-RESULTS.
           DISPLAY 'MARGIN ACCOUNT EVALUATION'
           DISPLAY '========================='
           DISPLAY 'ACCOUNT:       ' WS-MA-ACCT-NUM
           DISPLAY 'LONG MKT VAL:  ' WS-MA-LONG-MKT-VAL
           DISPLAY 'DEBIT BAL:     ' WS-MA-DEBIT-BAL
           DISPLAY 'EQUITY:        ' WS-MA-EQUITY
           DISPLAY 'MAINT REQ:     ' WS-TOTAL-MAINT-REQ
           DISPLAY 'MARGIN RATIO:  ' WS-MARGIN-RATIO
           IF CALL-YES
               DISPLAY 'MARGIN CALL:   YES'
               DISPLAY 'CALL AMOUNT:   ' WS-CALL-AMOUNT
               DISPLAY 'DUE IN DAYS:   ' WS-CALL-DUE-DAYS
               DISPLAY 'LIQUIDATION:   ' WS-LIQUIDATION-AMT
           ELSE
               DISPLAY 'MARGIN CALL:   NO'
               DISPLAY 'EXCESS EQUITY: ' WS-EXCESS-EQUITY
           END-IF
           IF WS-CONC-YES
               DISPLAY 'WARNING: CONCENTRATED POSITION'
           END-IF.
