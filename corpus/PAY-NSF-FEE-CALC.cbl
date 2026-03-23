       IDENTIFICATION DIVISION.
       PROGRAM-ID. PAY-NSF-FEE-CALC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ACCOUNT-DATA.
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-ACCT-BALANCE        PIC S9(9)V99 COMP-3.
           05 WS-AVAILABLE-BAL       PIC S9(9)V99 COMP-3.
           05 WS-OVERDRAFT-LIMIT     PIC S9(7)V99 COMP-3.
       01 WS-ACCT-TIER               PIC X(1).
           88 WS-BASIC               VALUE 'B'.
           88 WS-PREFERRED           VALUE 'P'.
           88 WS-PREMIUM             VALUE 'R'.
           88 WS-PRIVATE             VALUE 'V'.
       01 WS-TXN-AMOUNT              PIC S9(9)V99 COMP-3.
       01 WS-NSF-FIELDS.
           05 WS-NSF-FEE             PIC S9(5)V99 COMP-3.
           05 WS-OD-FEE              PIC S9(5)V99 COMP-3.
           05 WS-DAILY-CAP           PIC S9(5)V99 COMP-3.
           05 WS-TODAY-FEES          PIC S9(5)V99 COMP-3.
           05 WS-TODAY-COUNT         PIC 9(2).
           05 WS-MAX-DAILY-FEES      PIC 9(2).
           05 WS-SHORTFALL           PIC S9(9)V99 COMP-3.
           05 WS-TOTAL-FEE           PIC S9(5)V99 COMP-3.
       01 WS-OD-PROTECT-FLAG         PIC X VALUE 'N'.
           88 WS-HAS-OD-PROTECT      VALUE 'Y'.
       01 WS-DECISION                PIC X(1).
           88 WS-PAY-ITEM            VALUE 'P'.
           88 WS-RETURN-ITEM         VALUE 'R'.
       01 WS-WAIVER-FLAG             PIC X VALUE 'N'.
           88 WS-FEE-WAIVED          VALUE 'Y'.
       01 WS-MONTH-IDX               PIC 9(2).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CHECK-FUNDS
           PERFORM 3000-DETERMINE-ACTION
           PERFORM 4000-CALC-FEES
           PERFORM 5000-CHECK-WAIVER
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-NSF-FEE
           MOVE 0 TO WS-OD-FEE
           MOVE 0 TO WS-TOTAL-FEE
           MOVE 'N' TO WS-WAIVER-FLAG.
       2000-CHECK-FUNDS.
           COMPUTE WS-SHORTFALL =
               WS-TXN-AMOUNT - WS-AVAILABLE-BAL
           IF WS-SHORTFALL <= 0
               MOVE 0 TO WS-SHORTFALL
           END-IF.
       3000-DETERMINE-ACTION.
           IF WS-SHORTFALL <= 0
               SET WS-PAY-ITEM TO TRUE
           ELSE
               IF WS-HAS-OD-PROTECT
                   IF WS-SHORTFALL <= WS-OVERDRAFT-LIMIT
                       SET WS-PAY-ITEM TO TRUE
                   ELSE
                       SET WS-RETURN-ITEM TO TRUE
                   END-IF
               ELSE
                   EVALUATE TRUE
                       WHEN WS-PREMIUM
                           IF WS-SHORTFALL <= 500
                               SET WS-PAY-ITEM TO TRUE
                           ELSE
                               SET WS-RETURN-ITEM TO TRUE
                           END-IF
                       WHEN WS-PRIVATE
                           SET WS-PAY-ITEM TO TRUE
                       WHEN OTHER
                           SET WS-RETURN-ITEM TO TRUE
                   END-EVALUATE
               END-IF
           END-IF.
       4000-CALC-FEES.
           IF WS-SHORTFALL <= 0
               MOVE 0 TO WS-TOTAL-FEE
           ELSE
               EVALUATE TRUE
                   WHEN WS-BASIC
                       MOVE 36.00 TO WS-NSF-FEE
                       MOVE 150.00 TO WS-DAILY-CAP
                       MOVE 4 TO WS-MAX-DAILY-FEES
                   WHEN WS-PREFERRED
                       MOVE 28.00 TO WS-NSF-FEE
                       MOVE 112.00 TO WS-DAILY-CAP
                       MOVE 3 TO WS-MAX-DAILY-FEES
                   WHEN WS-PREMIUM
                       MOVE 15.00 TO WS-NSF-FEE
                       MOVE 45.00 TO WS-DAILY-CAP
                       MOVE 2 TO WS-MAX-DAILY-FEES
                   WHEN WS-PRIVATE
                       MOVE 0 TO WS-NSF-FEE
                       MOVE 0 TO WS-DAILY-CAP
                       MOVE 0 TO WS-MAX-DAILY-FEES
               END-EVALUATE
               IF WS-PAY-ITEM
                   IF WS-HAS-OD-PROTECT
                       COMPUTE WS-OD-FEE =
                           WS-SHORTFALL * 0.18 / 360
                       IF WS-OD-FEE < 5
                           MOVE 5.00 TO WS-OD-FEE
                       END-IF
                       MOVE WS-OD-FEE TO WS-TOTAL-FEE
                   ELSE
                       MOVE WS-NSF-FEE TO WS-TOTAL-FEE
                   END-IF
               ELSE
                   MOVE WS-NSF-FEE TO WS-TOTAL-FEE
               END-IF
               IF WS-TODAY-COUNT >= WS-MAX-DAILY-FEES
                   MOVE 0 TO WS-TOTAL-FEE
               END-IF
               COMPUTE WS-TODAY-FEES =
                   WS-TODAY-FEES + WS-TOTAL-FEE
               IF WS-TODAY-FEES > WS-DAILY-CAP
                   COMPUTE WS-TOTAL-FEE =
                       WS-TOTAL-FEE -
                       (WS-TODAY-FEES - WS-DAILY-CAP)
                   IF WS-TOTAL-FEE < 0
                       MOVE 0 TO WS-TOTAL-FEE
                   END-IF
               END-IF
           END-IF.
       5000-CHECK-WAIVER.
           IF WS-SHORTFALL > 0
               IF WS-SHORTFALL <= 5.00
                   MOVE 'Y' TO WS-WAIVER-FLAG
                   MOVE 0 TO WS-TOTAL-FEE
               END-IF
           END-IF.
       6000-DISPLAY-RESULTS.
           DISPLAY 'NSF FEE CALCULATION'
           DISPLAY '==================='
           DISPLAY 'ACCOUNT:    ' WS-ACCT-NUM
           DISPLAY 'BALANCE:    ' WS-ACCT-BALANCE
           DISPLAY 'TXN AMOUNT: ' WS-TXN-AMOUNT
           DISPLAY 'SHORTFALL:  ' WS-SHORTFALL
           IF WS-PAY-ITEM
               DISPLAY 'DECISION: PAY ITEM'
           ELSE
               DISPLAY 'DECISION: RETURN ITEM'
           END-IF
           DISPLAY 'FEE:        ' WS-TOTAL-FEE
           IF WS-FEE-WAIVED
               DISPLAY 'FEE WAIVED (DE MINIMIS)'
           END-IF.
