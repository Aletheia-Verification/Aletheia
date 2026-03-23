       IDENTIFICATION DIVISION.
       PROGRAM-ID. TREAS-CASH-POSITION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-BANK-ACCOUNTS.
           05 WS-BANK-ACCT OCCURS 8 TIMES.
               10 WS-BA-BANK-ID   PIC X(8).
               10 WS-BA-ACCT-NUM  PIC X(15).
               10 WS-BA-LEDGER    PIC S9(13)V99 COMP-3.
               10 WS-BA-COLLECTED PIC S9(13)V99 COMP-3.
               10 WS-BA-FLOAT     PIC S9(11)V99 COMP-3.
               10 WS-BA-TYPE      PIC X(2).
                   88 BA-DDA      VALUE 'DD'.
                   88 BA-SAVINGS  VALUE 'SV'.
                   88 BA-MM       VALUE 'MM'.
       01 WS-BA-COUNT             PIC 9 VALUE 8.
       01 WS-IDX                  PIC 9.
       01 WS-CASH-SUMMARY.
           05 WS-TOTAL-LEDGER     PIC S9(15)V99 COMP-3.
           05 WS-TOTAL-COLLECTED  PIC S9(15)V99 COMP-3.
           05 WS-TOTAL-FLOAT      PIC S9(13)V99 COMP-3.
           05 WS-AVAILABLE-CASH   PIC S9(15)V99 COMP-3.
       01 WS-FORECAST.
           05 WS-EXPECTED-IN      PIC S9(13)V99 COMP-3.
           05 WS-EXPECTED-OUT     PIC S9(13)V99 COMP-3.
           05 WS-NET-FORECAST     PIC S9(13)V99 COMP-3.
           05 WS-END-OF-DAY       PIC S9(15)V99 COMP-3.
       01 WS-MIN-CASH-TARGET      PIC S9(11)V99 COMP-3
           VALUE 5000000.00.
       01 WS-SURPLUS-DEFICIT       PIC S9(15)V99 COMP-3.
       01 WS-ACTION               PIC X(20).
       01 WS-POSITION-DATE        PIC 9(8).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-AGGREGATE-BALANCES
           PERFORM 3000-FORECAST
           PERFORM 4000-DETERMINE-ACTION
           PERFORM 5000-REPORT
           STOP RUN.
       1000-INIT.
           ACCEPT WS-POSITION-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-TOTAL-LEDGER
           MOVE 0 TO WS-TOTAL-COLLECTED
           MOVE 0 TO WS-TOTAL-FLOAT.
       2000-AGGREGATE-BALANCES.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-BA-COUNT
               ADD WS-BA-LEDGER(WS-IDX)
                   TO WS-TOTAL-LEDGER
               ADD WS-BA-COLLECTED(WS-IDX)
                   TO WS-TOTAL-COLLECTED
               COMPUTE WS-BA-FLOAT(WS-IDX) =
                   WS-BA-LEDGER(WS-IDX) -
                   WS-BA-COLLECTED(WS-IDX)
               ADD WS-BA-FLOAT(WS-IDX)
                   TO WS-TOTAL-FLOAT
           END-PERFORM
           MOVE WS-TOTAL-COLLECTED TO WS-AVAILABLE-CASH.
       3000-FORECAST.
           COMPUTE WS-NET-FORECAST =
               WS-EXPECTED-IN - WS-EXPECTED-OUT
           COMPUTE WS-END-OF-DAY =
               WS-AVAILABLE-CASH + WS-NET-FORECAST
           COMPUTE WS-SURPLUS-DEFICIT =
               WS-END-OF-DAY - WS-MIN-CASH-TARGET.
       4000-DETERMINE-ACTION.
           IF WS-SURPLUS-DEFICIT > 10000000.00
               MOVE 'INVEST EXCESS       ' TO WS-ACTION
           ELSE
               IF WS-SURPLUS-DEFICIT > 0
                   MOVE 'MONITOR             ' TO WS-ACTION
               ELSE
                   IF WS-SURPLUS-DEFICIT > -5000000.00
                       MOVE 'ARRANGE SHORT BORROW' TO
                           WS-ACTION
                   ELSE
                       MOVE 'URGENT FUNDING NEED ' TO
                           WS-ACTION
                   END-IF
               END-IF
           END-IF.
       5000-REPORT.
           DISPLAY 'DAILY CASH POSITION REPORT'
           DISPLAY '=========================='
           DISPLAY 'DATE:       ' WS-POSITION-DATE
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-BA-COUNT
               DISPLAY '  ' WS-BA-BANK-ID(WS-IDX)
                   ' ' WS-BA-TYPE(WS-IDX)
                   ' LEDGER=$' WS-BA-LEDGER(WS-IDX)
                   ' COLL=$' WS-BA-COLLECTED(WS-IDX)
           END-PERFORM
           DISPLAY 'TOTAL LEDGER:    $' WS-TOTAL-LEDGER
           DISPLAY 'TOTAL COLLECTED: $' WS-TOTAL-COLLECTED
           DISPLAY 'TOTAL FLOAT:     $' WS-TOTAL-FLOAT
           DISPLAY 'AVAILABLE:       $' WS-AVAILABLE-CASH
           DISPLAY 'EXPECTED IN:     $' WS-EXPECTED-IN
           DISPLAY 'EXPECTED OUT:    $' WS-EXPECTED-OUT
           DISPLAY 'END-OF-DAY:      $' WS-END-OF-DAY
           DISPLAY 'TARGET:          $' WS-MIN-CASH-TARGET
           DISPLAY 'SURPLUS/DEFICIT: $' WS-SURPLUS-DEFICIT
           DISPLAY 'ACTION:          ' WS-ACTION.
