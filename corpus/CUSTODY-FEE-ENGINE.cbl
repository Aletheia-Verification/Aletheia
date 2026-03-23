       IDENTIFICATION DIVISION.
       PROGRAM-ID. CUSTODY-FEE-ENGINE.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01 WS-ACCT-DATA.
           05 WS-ACCT-ID               PIC X(12).
           05 WS-ACCT-AUM              PIC S9(13)V99 COMP-3.
           05 WS-ACCT-TXN-COUNT        PIC S9(7) COMP-3.
           05 WS-ACCT-CUSTODY-TYPE     PIC X(2).
               88 WS-TYPE-DOMESTIC      VALUE 'DM'.
               88 WS-TYPE-INTL          VALUE 'IN'.
               88 WS-TYPE-GLOBAL        VALUE 'GL'.

       01 WS-FEE-SCHEDULE.
           05 WS-TIER OCCURS 5.
               10 WS-TIER-FLOOR        PIC S9(13)V99 COMP-3.
               10 WS-TIER-CEIL         PIC S9(13)V99 COMP-3.
               10 WS-TIER-BPS          PIC S9(3)V99 COMP-3.

       01 WS-FEE-CALC.
           05 WS-BASE-FEE              PIC S9(11)V99 COMP-3.
           05 WS-TXN-FEE               PIC S9(9)V99 COMP-3.
           05 WS-SAFEKEEP-FEE          PIC S9(9)V99 COMP-3.
           05 WS-SURCHARGE             PIC S9(9)V99 COMP-3.
           05 WS-TOTAL-FEE             PIC S9(11)V99 COMP-3.
           05 WS-MIN-FEE               PIC S9(9)V99 COMP-3
               VALUE 250.00.
           05 WS-TXN-RATE              PIC S9(3)V99 COMP-3
               VALUE 15.00.

       01 WS-TIER-IDX                  PIC 9(1).
       01 WS-TIER-AMT                  PIC S9(13)V99 COMP-3.
       01 WS-REMAINING-AUM            PIC S9(13)V99 COMP-3.

       01 WS-INTL-SURCHARGE-PCT       PIC S9(1)V99 COMP-3
           VALUE 0.15.
       01 WS-GLOBAL-SURCHARGE-PCT     PIC S9(1)V99 COMP-3
           VALUE 0.25.

       01 WS-PROCESS-COUNT            PIC S9(7) COMP-3 VALUE 0.
       01 WS-TOTAL-FEES-CHARGED       PIC S9(13)V99 COMP-3
           VALUE 0.
       01 WS-ERROR-MSG                PIC X(60).
       01 WS-DASH-TALLY               PIC 9(3).

       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INIT-FEE-SCHEDULE
           PERFORM 2000-CALC-CUSTODY-FEE
           PERFORM 3000-DISPLAY-RESULTS
           STOP RUN.

       1000-INIT-FEE-SCHEDULE.
           MOVE 0 TO WS-BASE-FEE
           MOVE 0 TO WS-TXN-FEE
           MOVE 0 TO WS-SAFEKEEP-FEE
           MOVE 0 TO WS-SURCHARGE
           MOVE 0 TO WS-TIER-FLOOR(1)
           MOVE 10000000.00 TO WS-TIER-CEIL(1)
           MOVE 5.00 TO WS-TIER-BPS(1)
           MOVE 10000000.00 TO WS-TIER-FLOOR(2)
           MOVE 50000000.00 TO WS-TIER-CEIL(2)
           MOVE 3.50 TO WS-TIER-BPS(2)
           MOVE 50000000.00 TO WS-TIER-FLOOR(3)
           MOVE 100000000.00 TO WS-TIER-CEIL(3)
           MOVE 2.50 TO WS-TIER-BPS(3)
           MOVE 100000000.00 TO WS-TIER-FLOOR(4)
           MOVE 500000000.00 TO WS-TIER-CEIL(4)
           MOVE 1.50 TO WS-TIER-BPS(4)
           MOVE 500000000.00 TO WS-TIER-FLOOR(5)
           MOVE 999999999999.99 TO WS-TIER-CEIL(5)
           MOVE 0.75 TO WS-TIER-BPS(5).

       2000-CALC-CUSTODY-FEE.
           MOVE WS-ACCT-AUM TO WS-REMAINING-AUM
           MOVE 0 TO WS-BASE-FEE
           PERFORM VARYING WS-TIER-IDX FROM 1 BY 1
               UNTIL WS-TIER-IDX > 5
               OR WS-REMAINING-AUM <= 0
               IF WS-REMAINING-AUM >
                   WS-TIER-CEIL(WS-TIER-IDX)
                   COMPUTE WS-TIER-AMT =
                       WS-TIER-CEIL(WS-TIER-IDX) -
                       WS-TIER-FLOOR(WS-TIER-IDX)
               ELSE
                   IF WS-REMAINING-AUM >
                       WS-TIER-FLOOR(WS-TIER-IDX)
                       COMPUTE WS-TIER-AMT =
                           WS-REMAINING-AUM -
                           WS-TIER-FLOOR(WS-TIER-IDX)
                   ELSE
                       MOVE 0 TO WS-TIER-AMT
                   END-IF
               END-IF
               COMPUTE WS-BASE-FEE = WS-BASE-FEE +
                   (WS-TIER-AMT *
                   WS-TIER-BPS(WS-TIER-IDX) / 10000)
               SUBTRACT WS-TIER-AMT FROM WS-REMAINING-AUM
           END-PERFORM
           COMPUTE WS-TXN-FEE =
               WS-ACCT-TXN-COUNT * WS-TXN-RATE
           PERFORM 2100-CALC-SURCHARGE
           COMPUTE WS-TOTAL-FEE =
               WS-BASE-FEE + WS-TXN-FEE + WS-SURCHARGE
           IF WS-TOTAL-FEE < WS-MIN-FEE
               MOVE WS-MIN-FEE TO WS-TOTAL-FEE
           END-IF
           ADD 1 TO WS-PROCESS-COUNT
           ADD WS-TOTAL-FEE TO WS-TOTAL-FEES-CHARGED.

       2100-CALC-SURCHARGE.
           MOVE 0 TO WS-SURCHARGE
           EVALUATE TRUE
               WHEN WS-TYPE-DOMESTIC
                   MOVE 0 TO WS-SURCHARGE
               WHEN WS-TYPE-INTL
                   COMPUTE WS-SURCHARGE =
                       WS-BASE-FEE * WS-INTL-SURCHARGE-PCT
               WHEN WS-TYPE-GLOBAL
                   COMPUTE WS-SURCHARGE =
                       WS-BASE-FEE * WS-GLOBAL-SURCHARGE-PCT
               WHEN OTHER
                   MOVE SPACES TO WS-ERROR-MSG
                   STRING 'UNKNOWN CUSTODY TYPE: '
                       WS-ACCT-CUSTODY-TYPE
                       DELIMITED BY SIZE
                       INTO WS-ERROR-MSG
                   END-STRING
                   DISPLAY WS-ERROR-MSG
                   MOVE 0 TO WS-SURCHARGE
           END-EVALUATE.

       3000-DISPLAY-RESULTS.
           MOVE 0 TO WS-DASH-TALLY
           INSPECT WS-ACCT-ID
               TALLYING WS-DASH-TALLY FOR ALL '-'
           DISPLAY 'CUSTODY FEE CALCULATION'
           DISPLAY 'ACCOUNT:       ' WS-ACCT-ID
           DISPLAY 'AUM:           ' WS-ACCT-AUM
           DISPLAY 'BASE FEE:      ' WS-BASE-FEE
           DISPLAY 'TXN FEE:       ' WS-TXN-FEE
           DISPLAY 'SURCHARGE:     ' WS-SURCHARGE
           DISPLAY 'TOTAL FEE:     ' WS-TOTAL-FEE
           DISPLAY 'MIN FEE:       ' WS-MIN-FEE
           DISPLAY 'ACCTS DONE:    ' WS-PROCESS-COUNT.
