       IDENTIFICATION DIVISION.
       PROGRAM-ID. VAULT-RECON.
      *================================================================*
      * Branch Vault Reconciliation                                    *
      * Counts denomination inventory, compares against book           *
      * balance, calculates insurance limits, flags discrepancies.     *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- Vault Identity ---
       01  WS-BRANCH-ID              PIC X(6).
       01  WS-VAULT-DATE             PIC 9(8).
       01  WS-VAULT-TYPE             PIC 9.
           88  WS-MAIN-VAULT         VALUE 1.
           88  WS-ATM-VAULT          VALUE 2.
           88  WS-NIGHT-DROP         VALUE 3.
      *--- Currency Denomination Table ---
       01  WS-CURRENCY-TBL.
           05  WS-CURR-ENTRY OCCURS 7 TIMES.
               10  WS-CURR-DENOM     PIC 9(5).
               10  WS-CURR-COUNT     PIC S9(7) COMP-3.
               10  WS-CURR-SUBTOTAL  PIC S9(11)V99 COMP-3.
       01  WS-CURR-IDX               PIC 9(3).
      *--- Coin Inventory ---
       01  WS-COIN-TBL.
           05  WS-COIN-ENTRY OCCURS 4 TIMES.
               10  WS-COIN-VALUE     PIC S9(3)V99 COMP-3.
               10  WS-COIN-ROLLS     PIC S9(5) COMP-3.
               10  WS-COINS-PER-ROLL PIC S9(3) COMP-3.
               10  WS-COIN-SUBTOTAL  PIC S9(9)V99 COMP-3.
       01  WS-COIN-IDX               PIC 9(3).
      *--- Totals ---
       01  WS-CURRENCY-TOTAL         PIC S9(11)V99 COMP-3.
       01  WS-COIN-TOTAL             PIC S9(9)V99 COMP-3.
       01  WS-PHYSICAL-TOTAL         PIC S9(11)V99 COMP-3.
       01  WS-BOOK-BALANCE           PIC S9(11)V99 COMP-3.
       01  WS-VARIANCE               PIC S9(11)V99 COMP-3.
       01  WS-ABS-VARIANCE           PIC S9(11)V99 COMP-3.
      *--- Insurance/Limits ---
       01  WS-INSURANCE-LIMIT        PIC S9(11)V99 COMP-3.
       01  WS-EXCESS-CASH            PIC S9(11)V99 COMP-3.
       01  WS-MIN-OPERATING          PIC S9(11)V99 COMP-3.
       01  WS-MAX-HOLDING            PIC S9(11)V99 COMP-3.
       01  WS-CASH-LEVEL-STATUS      PIC 9.
           88  WS-BELOW-MIN          VALUE 1.
           88  WS-NORMAL-RANGE       VALUE 2.
           88  WS-ABOVE-MAX          VALUE 3.
      *--- Shipment Needs ---
       01  WS-ORDER-NEEDED           PIC 9.
       01  WS-ORDER-AMOUNT           PIC S9(9)V99 COMP-3.
       01  WS-EXCESS-SHIP            PIC S9(9)V99 COMP-3.
      *--- Audit String ---
       01  WS-AUDIT-LINE             PIC X(80).
       01  WS-DENOM-NAME             PIC X(10).
      *--- Display ---
       01  WS-DISP-AMT               PIC -$$$,$$$,$$$,$$9.99.
       01  WS-DISP-CT                PIC ZZ,ZZZ,ZZ9.
       01  WS-DISP-VAR               PIC -$$,$$$,$$9.99.
      *--- Totals Check ---
       01  WS-RECOUNT-TOTAL          PIC S9(11)V99 COMP-3.
       01  WS-TALLY-COUNT            PIC S9(5) COMP-3.

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-COUNT-CURRENCY
           PERFORM 3000-COUNT-COINS
           PERFORM 4000-COMPUTE-TOTALS
           PERFORM 5000-RECONCILE
           PERFORM 6000-CHECK-LIMITS
           PERFORM 7000-DETERMINE-SHIPMENT
           PERFORM 8000-DISPLAY-REPORT
           STOP RUN.

       1000-INITIALIZE.
           MOVE "BR0042" TO WS-BRANCH-ID
           ACCEPT WS-VAULT-DATE FROM DATE YYYYMMDD
           MOVE 1 TO WS-VAULT-TYPE
           MOVE 750000.00 TO WS-BOOK-BALANCE
           MOVE 1000000.00 TO WS-INSURANCE-LIMIT
           MOVE 200000.00 TO WS-MIN-OPERATING
           MOVE 900000.00 TO WS-MAX-HOLDING
           MOVE 0 TO WS-CURRENCY-TOTAL
           MOVE 0 TO WS-COIN-TOTAL
           MOVE 0 TO WS-ORDER-NEEDED
           MOVE 100 TO WS-CURR-DENOM(1)
           MOVE 50  TO WS-CURR-DENOM(2)
           MOVE 20  TO WS-CURR-DENOM(3)
           MOVE 10  TO WS-CURR-DENOM(4)
           MOVE 5   TO WS-CURR-DENOM(5)
           MOVE 2   TO WS-CURR-DENOM(6)
           MOVE 1   TO WS-CURR-DENOM(7)
           MOVE 4500 TO WS-CURR-COUNT(1)
           MOVE 2200 TO WS-CURR-COUNT(2)
           MOVE 5000 TO WS-CURR-COUNT(3)
           MOVE 1500 TO WS-CURR-COUNT(4)
           MOVE 800  TO WS-CURR-COUNT(5)
           MOVE 200  TO WS-CURR-COUNT(6)
           MOVE 150  TO WS-CURR-COUNT(7)
           MOVE 0.25 TO WS-COIN-VALUE(1)
           MOVE 0.10 TO WS-COIN-VALUE(2)
           MOVE 0.05 TO WS-COIN-VALUE(3)
           MOVE 0.01 TO WS-COIN-VALUE(4)
           MOVE 50 TO WS-COIN-ROLLS(1)
           MOVE 40 TO WS-COIN-ROLLS(2)
           MOVE 30 TO WS-COIN-ROLLS(3)
           MOVE 20 TO WS-COIN-ROLLS(4)
           MOVE 40 TO WS-COINS-PER-ROLL(1)
           MOVE 50 TO WS-COINS-PER-ROLL(2)
           MOVE 40 TO WS-COINS-PER-ROLL(3)
           MOVE 50 TO WS-COINS-PER-ROLL(4).

       2000-COUNT-CURRENCY.
           PERFORM VARYING WS-CURR-IDX FROM 1 BY 1
               UNTIL WS-CURR-IDX > 7
               COMPUTE WS-CURR-SUBTOTAL(WS-CURR-IDX) =
                   WS-CURR-DENOM(WS-CURR-IDX)
                   * WS-CURR-COUNT(WS-CURR-IDX)
               ADD WS-CURR-SUBTOTAL(WS-CURR-IDX)
                   TO WS-CURRENCY-TOTAL
           END-PERFORM.

       3000-COUNT-COINS.
           PERFORM VARYING WS-COIN-IDX FROM 1 BY 1
               UNTIL WS-COIN-IDX > 4
               COMPUTE WS-COIN-SUBTOTAL(WS-COIN-IDX) =
                   WS-COIN-VALUE(WS-COIN-IDX)
                   * WS-COIN-ROLLS(WS-COIN-IDX)
                   * WS-COINS-PER-ROLL(WS-COIN-IDX)
               ADD WS-COIN-SUBTOTAL(WS-COIN-IDX)
                   TO WS-COIN-TOTAL
           END-PERFORM.

       4000-COMPUTE-TOTALS.
           COMPUTE WS-PHYSICAL-TOTAL =
               WS-CURRENCY-TOTAL + WS-COIN-TOTAL
           MOVE 0 TO WS-TALLY-COUNT
           INSPECT WS-BRANCH-ID
               TALLYING WS-TALLY-COUNT
               FOR ALL "0".

       5000-RECONCILE.
           COMPUTE WS-VARIANCE =
               WS-PHYSICAL-TOTAL - WS-BOOK-BALANCE
           IF WS-VARIANCE < 0
               COMPUTE WS-ABS-VARIANCE =
                   WS-VARIANCE * -1
           ELSE
               MOVE WS-VARIANCE TO WS-ABS-VARIANCE
           END-IF.

       6000-CHECK-LIMITS.
           EVALUATE TRUE
               WHEN WS-PHYSICAL-TOTAL < WS-MIN-OPERATING
                   MOVE 1 TO WS-CASH-LEVEL-STATUS
               WHEN WS-PHYSICAL-TOTAL > WS-MAX-HOLDING
                   MOVE 3 TO WS-CASH-LEVEL-STATUS
               WHEN OTHER
                   MOVE 2 TO WS-CASH-LEVEL-STATUS
           END-EVALUATE
           IF WS-PHYSICAL-TOTAL > WS-INSURANCE-LIMIT
               COMPUTE WS-EXCESS-CASH =
                   WS-PHYSICAL-TOTAL - WS-INSURANCE-LIMIT
           ELSE
               MOVE 0 TO WS-EXCESS-CASH
           END-IF.

       7000-DETERMINE-SHIPMENT.
           IF WS-BELOW-MIN
               MOVE 1 TO WS-ORDER-NEEDED
               COMPUTE WS-ORDER-AMOUNT =
                   WS-MIN-OPERATING - WS-PHYSICAL-TOTAL
                   + 50000
           END-IF
           IF WS-ABOVE-MAX
               COMPUTE WS-EXCESS-SHIP =
                   WS-PHYSICAL-TOTAL - WS-MAX-HOLDING
           END-IF.

       8000-DISPLAY-REPORT.
           DISPLAY "========================================"
           DISPLAY "   VAULT RECONCILIATION REPORT"
           DISPLAY "========================================"
           DISPLAY "BRANCH: " WS-BRANCH-ID
           MOVE WS-CURRENCY-TOTAL TO WS-DISP-AMT
           DISPLAY "CURRENCY:  " WS-DISP-AMT
           MOVE WS-COIN-TOTAL TO WS-DISP-AMT
           DISPLAY "COIN:      " WS-DISP-AMT
           MOVE WS-PHYSICAL-TOTAL TO WS-DISP-AMT
           DISPLAY "PHYSICAL:  " WS-DISP-AMT
           MOVE WS-BOOK-BALANCE TO WS-DISP-AMT
           DISPLAY "BOOK BAL:  " WS-DISP-AMT
           MOVE WS-VARIANCE TO WS-DISP-VAR
           DISPLAY "VARIANCE:  " WS-DISP-VAR
           IF WS-ORDER-NEEDED = 1
               MOVE WS-ORDER-AMOUNT TO WS-DISP-AMT
               DISPLAY "ORDER CASH:" WS-DISP-AMT
           END-IF
           IF WS-EXCESS-CASH > 0
               DISPLAY "*** EXCEEDS INSURANCE LIMIT ***"
           END-IF
           DISPLAY "========================================".
