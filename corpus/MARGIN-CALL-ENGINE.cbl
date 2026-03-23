       IDENTIFICATION DIVISION.
       PROGRAM-ID. MARGIN-CALL-ENGINE.
      *================================================================*
      * MARGIN CALL CALCULATION ENGINE                                 *
      * Evaluates portfolio margin requirements, identifies deficit,   *
      * determines deadline and liquidation priority.                  *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-MARGIN-ACCT.
           05 WS-ACCT-ID            PIC X(10).
           05 WS-CASH-BALANCE       PIC S9(11)V99 COMP-3.
           05 WS-LOAN-BALANCE       PIC S9(11)V99 COMP-3.
       01 WS-POSITIONS.
           05 WS-POS-ENTRY OCCURS 8.
               10 WS-POS-SYMBOL     PIC X(6).
               10 WS-POS-SHARES     PIC S9(7) COMP-3.
               10 WS-POS-PRICE      PIC S9(5)V99 COMP-3.
               10 WS-POS-MKT-VAL    PIC S9(11)V99 COMP-3.
               10 WS-POS-MARGIN-REQ PIC S9(1)V99 COMP-3.
               10 WS-POS-REQUIRED   PIC S9(11)V99 COMP-3.
               10 WS-POS-LIQUID-PRI PIC S9(1) COMP-3.
       01 WS-POS-COUNT              PIC S9(2) COMP-3.
       01 WS-PORTFOLIO.
           05 WS-TOTAL-MKT-VAL      PIC S9(13)V99 COMP-3.
           05 WS-TOTAL-REQUIRED     PIC S9(13)V99 COMP-3.
           05 WS-EQUITY             PIC S9(13)V99 COMP-3.
           05 WS-EQUITY-PCT         PIC S9(3)V99 COMP-3.
           05 WS-MARGIN-EXCESS      PIC S9(13)V99 COMP-3.
           05 WS-MARGIN-DEFICIT     PIC S9(13)V99 COMP-3.
       01 WS-THRESHOLDS.
           05 WS-MAINT-REQ-PCT      PIC S9(1)V99 COMP-3
               VALUE 0.25.
           05 WS-INIT-REQ-PCT       PIC S9(1)V99 COMP-3
               VALUE 0.50.
           05 WS-HOUSE-REQ-PCT      PIC S9(1)V99 COMP-3
               VALUE 0.30.
       01 WS-CALL-DETAILS.
           05 WS-CALL-TYPE          PIC X(10).
           05 WS-CALL-AMOUNT        PIC S9(11)V99 COMP-3.
           05 WS-DEADLINE-HOURS     PIC S9(3) COMP-3.
           05 WS-LIQUIDATE-FLAG     PIC X VALUE 'N'.
               88 WS-FORCE-LIQUID   VALUE 'Y'.
       01 WS-IDX                    PIC S9(2) COMP-3.
       01 WS-LIQUID-TOTAL           PIC S9(11)V99 COMP-3.
       01 WS-SORTED-FLAG            PIC X VALUE 'N'.
       01 WS-TEMP-SYMBOL            PIC X(6).
       01 WS-TEMP-PRI               PIC S9(1) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-POSITIONS
           PERFORM 3000-CALC-MARKET-VALUES
           PERFORM 4000-CALC-REQUIREMENTS
           PERFORM 5000-EVALUATE-MARGIN
               THRU 5500-DETERMINE-CALL
           PERFORM 6000-PLAN-LIQUIDATION
           PERFORM 7000-DISPLAY-REPORT
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'MRG0001234' TO WS-ACCT-ID
           MOVE 15000.00 TO WS-CASH-BALANCE
           MOVE 120000.00 TO WS-LOAN-BALANCE
           MOVE 0 TO WS-TOTAL-MKT-VAL
           MOVE 0 TO WS-TOTAL-REQUIRED
           MOVE 0 TO WS-MARGIN-EXCESS
           MOVE 0 TO WS-MARGIN-DEFICIT
           MOVE 0 TO WS-CALL-AMOUNT
           MOVE SPACES TO WS-CALL-TYPE.
       2000-LOAD-POSITIONS.
           MOVE 5 TO WS-POS-COUNT
           MOVE 'AAPL  ' TO WS-POS-SYMBOL(1)
           MOVE 200 TO WS-POS-SHARES(1)
           MOVE 178.50 TO WS-POS-PRICE(1)
           MOVE 0.25 TO WS-POS-MARGIN-REQ(1)
           MOVE 3 TO WS-POS-LIQUID-PRI(1)
           MOVE 'TSLA  ' TO WS-POS-SYMBOL(2)
           MOVE 100 TO WS-POS-SHARES(2)
           MOVE 245.00 TO WS-POS-PRICE(2)
           MOVE 0.40 TO WS-POS-MARGIN-REQ(2)
           MOVE 1 TO WS-POS-LIQUID-PRI(2)
           MOVE 'MSFT  ' TO WS-POS-SYMBOL(3)
           MOVE 150 TO WS-POS-SHARES(3)
           MOVE 415.25 TO WS-POS-PRICE(3)
           MOVE 0.25 TO WS-POS-MARGIN-REQ(3)
           MOVE 4 TO WS-POS-LIQUID-PRI(3)
           MOVE 'NVDA  ' TO WS-POS-SYMBOL(4)
           MOVE 80 TO WS-POS-SHARES(4)
           MOVE 890.00 TO WS-POS-PRICE(4)
           MOVE 0.30 TO WS-POS-MARGIN-REQ(4)
           MOVE 2 TO WS-POS-LIQUID-PRI(4)
           MOVE 'AMD   ' TO WS-POS-SYMBOL(5)
           MOVE 300 TO WS-POS-SHARES(5)
           MOVE 165.75 TO WS-POS-PRICE(5)
           MOVE 0.35 TO WS-POS-MARGIN-REQ(5)
           MOVE 1 TO WS-POS-LIQUID-PRI(5).
       3000-CALC-MARKET-VALUES.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-POS-COUNT
               COMPUTE WS-POS-MKT-VAL(WS-IDX) =
                   WS-POS-SHARES(WS-IDX) *
                   WS-POS-PRICE(WS-IDX)
               ADD WS-POS-MKT-VAL(WS-IDX) TO
                   WS-TOTAL-MKT-VAL
           END-PERFORM.
       4000-CALC-REQUIREMENTS.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-POS-COUNT
               COMPUTE WS-POS-REQUIRED(WS-IDX) ROUNDED =
                   WS-POS-MKT-VAL(WS-IDX) *
                   WS-POS-MARGIN-REQ(WS-IDX)
               ADD WS-POS-REQUIRED(WS-IDX) TO
                   WS-TOTAL-REQUIRED
           END-PERFORM.
       5000-EVALUATE-MARGIN.
           COMPUTE WS-EQUITY =
               WS-TOTAL-MKT-VAL + WS-CASH-BALANCE -
               WS-LOAN-BALANCE
           IF WS-TOTAL-MKT-VAL > 0
               COMPUTE WS-EQUITY-PCT ROUNDED =
                   WS-EQUITY / WS-TOTAL-MKT-VAL * 100
           ELSE
               MOVE 0 TO WS-EQUITY-PCT
           END-IF
           IF WS-EQUITY > WS-TOTAL-REQUIRED
               COMPUTE WS-MARGIN-EXCESS =
                   WS-EQUITY - WS-TOTAL-REQUIRED
               MOVE 0 TO WS-MARGIN-DEFICIT
           ELSE
               MOVE 0 TO WS-MARGIN-EXCESS
               COMPUTE WS-MARGIN-DEFICIT =
                   WS-TOTAL-REQUIRED - WS-EQUITY
           END-IF.
       5500-DETERMINE-CALL.
           IF WS-MARGIN-DEFICIT > 0
               IF WS-EQUITY-PCT < 25
                   MOVE 'HOUSE CALL' TO WS-CALL-TYPE
                   MOVE WS-MARGIN-DEFICIT TO WS-CALL-AMOUNT
                   MOVE 24 TO WS-DEADLINE-HOURS
                   IF WS-EQUITY-PCT < 15
                       MOVE 'Y' TO WS-LIQUIDATE-FLAG
                   END-IF
               ELSE
                   MOVE 'MAINT CALL' TO WS-CALL-TYPE
                   MOVE WS-MARGIN-DEFICIT TO WS-CALL-AMOUNT
                   MOVE 72 TO WS-DEADLINE-HOURS
               END-IF
           ELSE
               MOVE 'NO CALL' TO WS-CALL-TYPE
               MOVE 0 TO WS-CALL-AMOUNT
               MOVE 0 TO WS-DEADLINE-HOURS
           END-IF.
       6000-PLAN-LIQUIDATION.
           IF WS-FORCE-LIQUID
               MOVE 0 TO WS-LIQUID-TOTAL
               PERFORM VARYING WS-IDX FROM 1 BY 1
                   UNTIL WS-IDX > WS-POS-COUNT
                   OR WS-LIQUID-TOTAL >= WS-CALL-AMOUNT
                   IF WS-POS-LIQUID-PRI(WS-IDX) <= 2
                       ADD WS-POS-MKT-VAL(WS-IDX) TO
                           WS-LIQUID-TOTAL
                       DISPLAY 'LIQUIDATE: '
                           WS-POS-SYMBOL(WS-IDX) ' $'
                           WS-POS-MKT-VAL(WS-IDX)
                   END-IF
               END-PERFORM
           END-IF.
       7000-DISPLAY-REPORT.
           DISPLAY '========================================='
           DISPLAY 'MARGIN CALL REPORT'
           DISPLAY '========================================='
           DISPLAY 'ACCOUNT:         ' WS-ACCT-ID
           DISPLAY '----- POSITIONS -----'
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-POS-COUNT
               DISPLAY WS-POS-SYMBOL(WS-IDX)
                   ' SHARES: ' WS-POS-SHARES(WS-IDX)
                   ' MKT: ' WS-POS-MKT-VAL(WS-IDX)
                   ' REQ: ' WS-POS-REQUIRED(WS-IDX)
           END-PERFORM
           DISPLAY '----- SUMMARY -----'
           DISPLAY 'PORTFOLIO VALUE: ' WS-TOTAL-MKT-VAL
           DISPLAY 'CASH BALANCE:    ' WS-CASH-BALANCE
           DISPLAY 'LOAN BALANCE:    ' WS-LOAN-BALANCE
           DISPLAY 'EQUITY:          ' WS-EQUITY
           DISPLAY 'EQUITY PCT:      ' WS-EQUITY-PCT
           DISPLAY 'REQUIRED:        ' WS-TOTAL-REQUIRED
           DISPLAY 'EXCESS:          ' WS-MARGIN-EXCESS
           DISPLAY 'DEFICIT:         ' WS-MARGIN-DEFICIT
           DISPLAY '----- CALL -----'
           DISPLAY 'CALL TYPE:       ' WS-CALL-TYPE
           DISPLAY 'CALL AMOUNT:     ' WS-CALL-AMOUNT
           DISPLAY 'DEADLINE HRS:    ' WS-DEADLINE-HOURS
           IF WS-FORCE-LIQUID
               DISPLAY 'FORCED LIQUIDATION REQUIRED'
           END-IF
           DISPLAY '========================================='.
