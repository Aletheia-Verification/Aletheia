       IDENTIFICATION DIVISION.
       PROGRAM-ID. TRADE-MARGIN-CALC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-POSITION-DATA.
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-MARKET-VALUE        PIC S9(11)V99 COMP-3.
           05 WS-LOAN-BALANCE        PIC S9(11)V99 COMP-3.
           05 WS-CASH-BALANCE        PIC S9(9)V99 COMP-3.
       01 WS-SECURITY-TYPE           PIC X(1).
           88 WS-EQUITY              VALUE 'E'.
           88 WS-BOND                VALUE 'B'.
           88 WS-OPTION              VALUE 'O'.
           88 WS-MUTUAL-FUND         VALUE 'M'.
       01 WS-MARGIN-FIELDS.
           05 WS-INIT-MARGIN-PCT     PIC S9(1)V9(4) COMP-3.
           05 WS-MAINT-MARGIN-PCT    PIC S9(1)V9(4) COMP-3.
           05 WS-INIT-MARGIN-REQ     PIC S9(11)V99 COMP-3.
           05 WS-MAINT-MARGIN-REQ    PIC S9(11)V99 COMP-3.
           05 WS-EQUITY-VALUE        PIC S9(11)V99 COMP-3.
           05 WS-EQUITY-PCT          PIC S9(1)V9(4) COMP-3.
           05 WS-MARGIN-EXCESS       PIC S9(11)V99 COMP-3.
           05 WS-MARGIN-CALL         PIC S9(11)V99 COMP-3.
       01 WS-CALL-STATUS             PIC X(1).
           88 WS-NO-CALL             VALUE 'N'.
           88 WS-MARGIN-WARNING      VALUE 'W'.
           88 WS-MARGIN-CALL-DUE     VALUE 'C'.
           88 WS-LIQUIDATION         VALUE 'L'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-SET-REQUIREMENTS
           PERFORM 3000-CALC-EQUITY
           PERFORM 4000-CHECK-MARGIN
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-MARGIN-EXCESS
           MOVE 0 TO WS-MARGIN-CALL
           SET WS-NO-CALL TO TRUE.
       2000-SET-REQUIREMENTS.
           EVALUATE TRUE
               WHEN WS-EQUITY
                   MOVE 0.5000 TO WS-INIT-MARGIN-PCT
                   MOVE 0.2500 TO WS-MAINT-MARGIN-PCT
               WHEN WS-BOND
                   MOVE 0.3000 TO WS-INIT-MARGIN-PCT
                   MOVE 0.1500 TO WS-MAINT-MARGIN-PCT
               WHEN WS-OPTION
                   MOVE 1.0000 TO WS-INIT-MARGIN-PCT
                   MOVE 1.0000 TO WS-MAINT-MARGIN-PCT
               WHEN WS-MUTUAL-FUND
                   MOVE 0.5000 TO WS-INIT-MARGIN-PCT
                   MOVE 0.2500 TO WS-MAINT-MARGIN-PCT
               WHEN OTHER
                   MOVE 0.5000 TO WS-INIT-MARGIN-PCT
                   MOVE 0.2500 TO WS-MAINT-MARGIN-PCT
           END-EVALUATE
           COMPUTE WS-INIT-MARGIN-REQ =
               WS-MARKET-VALUE * WS-INIT-MARGIN-PCT
           COMPUTE WS-MAINT-MARGIN-REQ =
               WS-MARKET-VALUE * WS-MAINT-MARGIN-PCT.
       3000-CALC-EQUITY.
           COMPUTE WS-EQUITY-VALUE =
               WS-MARKET-VALUE - WS-LOAN-BALANCE +
               WS-CASH-BALANCE
           IF WS-MARKET-VALUE > 0
               COMPUTE WS-EQUITY-PCT =
                   WS-EQUITY-VALUE / WS-MARKET-VALUE
           END-IF
           COMPUTE WS-MARGIN-EXCESS =
               WS-EQUITY-VALUE - WS-MAINT-MARGIN-REQ.
       4000-CHECK-MARGIN.
           IF WS-MARGIN-EXCESS < 0
               COMPUTE WS-MARGIN-CALL =
                   0 - WS-MARGIN-EXCESS
               IF WS-EQUITY-PCT < 0.15
                   SET WS-LIQUIDATION TO TRUE
               ELSE
                   SET WS-MARGIN-CALL-DUE TO TRUE
               END-IF
           ELSE
               IF WS-EQUITY-PCT < 0.30
                   SET WS-MARGIN-WARNING TO TRUE
               ELSE
                   SET WS-NO-CALL TO TRUE
               END-IF
           END-IF.
       5000-DISPLAY-RESULTS.
           DISPLAY 'MARGIN CALCULATION'
           DISPLAY '=================='
           DISPLAY 'ACCOUNT:         ' WS-ACCT-NUM
           DISPLAY 'MARKET VALUE:    ' WS-MARKET-VALUE
           DISPLAY 'LOAN BALANCE:    ' WS-LOAN-BALANCE
           DISPLAY 'EQUITY VALUE:    ' WS-EQUITY-VALUE
           DISPLAY 'EQUITY PCT:      ' WS-EQUITY-PCT
           DISPLAY 'MAINT REQUIRED:  ' WS-MAINT-MARGIN-REQ
           DISPLAY 'MARGIN EXCESS:   ' WS-MARGIN-EXCESS
           IF WS-MARGIN-CALL-DUE
               DISPLAY 'STATUS: MARGIN CALL'
               DISPLAY 'CALL AMOUNT:     ' WS-MARGIN-CALL
           END-IF
           IF WS-LIQUIDATION
               DISPLAY 'STATUS: LIQUIDATION REQUIRED'
               DISPLAY 'CALL AMOUNT:     ' WS-MARGIN-CALL
           END-IF
           IF WS-MARGIN-WARNING
               DISPLAY 'STATUS: WARNING'
           END-IF
           IF WS-NO-CALL
               DISPLAY 'STATUS: ADEQUATE'
           END-IF.
