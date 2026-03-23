       IDENTIFICATION DIVISION.
       PROGRAM-ID. TELLER-CASH-BUY.
      *================================================================*
      * Teller Cash Buy/Sell (Vault to Drawer Transfer)                *
      * Manages currency exchanges between vault and teller drawers,   *
      * tracks denomination mix, enforces dual-control requirements.   *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- Transfer Request ---
       01  WS-TELLER-ID              PIC X(8).
       01  WS-VAULT-CLERK-ID         PIC X(8).
       01  WS-TRANSFER-DATE          PIC 9(8).
       01  WS-TRANSFER-TYPE          PIC 9.
           88  WS-BUY-FROM-VAULT     VALUE 1.
           88  WS-SELL-TO-VAULT      VALUE 2.
      *--- Denomination Detail ---
       01  WS-XFER-TABLE.
           05  WS-XFER-ENTRY OCCURS 7 TIMES.
               10  WS-XFER-DENOM     PIC 9(5).
               10  WS-XFER-QTY       PIC S9(5) COMP-3.
               10  WS-XFER-VALUE     PIC S9(9)V99 COMP-3.
       01  WS-XFER-IDX              PIC 9(3).
      *--- Drawer Balance ---
       01  WS-DRAWER-BEFORE         PIC S9(9)V99 COMP-3.
       01  WS-DRAWER-AFTER          PIC S9(9)V99 COMP-3.
       01  WS-DRAWER-TARGET         PIC S9(9)V99 COMP-3.
       01  WS-DRAWER-VARIANCE       PIC S9(7)V99 COMP-3.
      *--- Vault Balance ---
       01  WS-VAULT-BEFORE          PIC S9(11)V99 COMP-3.
       01  WS-VAULT-AFTER           PIC S9(11)V99 COMP-3.
      *--- Transfer Totals ---
       01  WS-XFER-TOTAL            PIC S9(9)V99 COMP-3.
       01  WS-DUAL-CONTROL-OK       PIC 9.
           88  WS-DUAL-VERIFIED     VALUE 1.
           88  WS-DUAL-FAILED       VALUE 0.
      *--- Limits ---
       01  WS-MAX-BUY               PIC S9(9)V99 COMP-3.
       01  WS-MAX-SELL              PIC S9(9)V99 COMP-3.
       01  WS-OVER-LIMIT            PIC 9.
      *--- Display ---
       01  WS-DISP-AMT              PIC -$$$,$$$,$$9.99.
       01  WS-DISP-QTY              PIC ZZ,ZZ9.
       01  WS-DISP-CT               PIC ZZ9.
      *--- Audit ---
       01  WS-AUDIT-LINE            PIC X(72).
       01  WS-WORK-TALLY            PIC S9(3) COMP-3.

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-TRANSFER
           PERFORM 3000-VALIDATE-TRANSFER
           PERFORM 4000-EXECUTE-TRANSFER
           PERFORM 5000-DISPLAY-RECEIPT
           STOP RUN.

       1000-INITIALIZE.
           MOVE "TLR00105" TO WS-TELLER-ID
           MOVE "VLT00201" TO WS-VAULT-CLERK-ID
           ACCEPT WS-TRANSFER-DATE FROM DATE YYYYMMDD
           MOVE 1 TO WS-TRANSFER-TYPE
           MOVE 4200.00 TO WS-DRAWER-BEFORE
           MOVE 10000.00 TO WS-DRAWER-TARGET
           MOVE 750000.00 TO WS-VAULT-BEFORE
           MOVE 25000.00 TO WS-MAX-BUY
           MOVE 15000.00 TO WS-MAX-SELL
           MOVE 0 TO WS-XFER-TOTAL
           MOVE 0 TO WS-OVER-LIMIT
           MOVE 100 TO WS-XFER-DENOM(1)
           MOVE 50  TO WS-XFER-DENOM(2)
           MOVE 20  TO WS-XFER-DENOM(3)
           MOVE 10  TO WS-XFER-DENOM(4)
           MOVE 5   TO WS-XFER-DENOM(5)
           MOVE 2   TO WS-XFER-DENOM(6)
           MOVE 1   TO WS-XFER-DENOM(7)
           MOVE 30  TO WS-XFER-QTY(1)
           MOVE 20  TO WS-XFER-QTY(2)
           MOVE 50  TO WS-XFER-QTY(3)
           MOVE 30  TO WS-XFER-QTY(4)
           MOVE 20  TO WS-XFER-QTY(5)
           MOVE 10  TO WS-XFER-QTY(6)
           MOVE 10  TO WS-XFER-QTY(7).

       2000-LOAD-TRANSFER.
           PERFORM VARYING WS-XFER-IDX FROM 1 BY 1
               UNTIL WS-XFER-IDX > 7
               COMPUTE WS-XFER-VALUE(WS-XFER-IDX) =
                   WS-XFER-DENOM(WS-XFER-IDX)
                   * WS-XFER-QTY(WS-XFER-IDX)
               ADD WS-XFER-VALUE(WS-XFER-IDX)
                   TO WS-XFER-TOTAL
           END-PERFORM.

       3000-VALIDATE-TRANSFER.
           MOVE 1 TO WS-DUAL-CONTROL-OK
           IF WS-TELLER-ID = WS-VAULT-CLERK-ID
               MOVE 0 TO WS-DUAL-CONTROL-OK
           END-IF
           IF WS-BUY-FROM-VAULT
               IF WS-XFER-TOTAL > WS-MAX-BUY
                   MOVE 1 TO WS-OVER-LIMIT
               END-IF
               IF WS-XFER-TOTAL > WS-VAULT-BEFORE
                   MOVE 1 TO WS-OVER-LIMIT
               END-IF
           ELSE
               IF WS-XFER-TOTAL > WS-MAX-SELL
                   MOVE 1 TO WS-OVER-LIMIT
               END-IF
               IF WS-XFER-TOTAL > WS-DRAWER-BEFORE
                   MOVE 1 TO WS-OVER-LIMIT
               END-IF
           END-IF.

       4000-EXECUTE-TRANSFER.
           IF WS-DUAL-VERIFIED
               IF WS-OVER-LIMIT = 0
                   IF WS-BUY-FROM-VAULT
                       COMPUTE WS-DRAWER-AFTER =
                           WS-DRAWER-BEFORE + WS-XFER-TOTAL
                       COMPUTE WS-VAULT-AFTER =
                           WS-VAULT-BEFORE - WS-XFER-TOTAL
                   ELSE
                       COMPUTE WS-DRAWER-AFTER =
                           WS-DRAWER-BEFORE - WS-XFER-TOTAL
                       COMPUTE WS-VAULT-AFTER =
                           WS-VAULT-BEFORE + WS-XFER-TOTAL
                   END-IF
                   COMPUTE WS-DRAWER-VARIANCE =
                       WS-DRAWER-AFTER - WS-DRAWER-TARGET
               ELSE
                   MOVE WS-DRAWER-BEFORE TO WS-DRAWER-AFTER
                   MOVE WS-VAULT-BEFORE TO WS-VAULT-AFTER
               END-IF
           ELSE
               MOVE WS-DRAWER-BEFORE TO WS-DRAWER-AFTER
               MOVE WS-VAULT-BEFORE TO WS-VAULT-AFTER
           END-IF.

       5000-DISPLAY-RECEIPT.
           DISPLAY "========================================"
           DISPLAY "   CASH BUY/SELL RECEIPT"
           DISPLAY "========================================"
           DISPLAY "TELLER: " WS-TELLER-ID
           DISPLAY "VAULT:  " WS-VAULT-CLERK-ID
           IF WS-BUY-FROM-VAULT
               DISPLAY "TYPE:   BUY FROM VAULT"
           ELSE
               DISPLAY "TYPE:   SELL TO VAULT"
           END-IF
           DISPLAY "--- DENOMINATIONS ---"
           PERFORM VARYING WS-XFER-IDX FROM 1 BY 1
               UNTIL WS-XFER-IDX > 7
               IF WS-XFER-QTY(WS-XFER-IDX) > 0
                   MOVE WS-XFER-VALUE(WS-XFER-IDX)
                       TO WS-DISP-AMT
                   MOVE WS-XFER-QTY(WS-XFER-IDX)
                       TO WS-DISP-QTY
                   DISPLAY "$" WS-XFER-DENOM(WS-XFER-IDX)
                       " x" WS-DISP-QTY
                       " = " WS-DISP-AMT
               END-IF
           END-PERFORM
           MOVE WS-XFER-TOTAL TO WS-DISP-AMT
           DISPLAY "TOTAL:  " WS-DISP-AMT
           MOVE 0 TO WS-WORK-TALLY
           INSPECT WS-TELLER-ID
               TALLYING WS-WORK-TALLY FOR ALL "0"
           IF WS-DUAL-FAILED
               DISPLAY "*** DUAL CONTROL VIOLATION ***"
           END-IF
           IF WS-OVER-LIMIT = 1
               DISPLAY "*** EXCEEDS LIMIT - DENIED ***"
           END-IF
           MOVE WS-DRAWER-AFTER TO WS-DISP-AMT
           DISPLAY "DRAWER: " WS-DISP-AMT
           DISPLAY "========================================".
