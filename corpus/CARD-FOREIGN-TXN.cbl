       IDENTIFICATION DIVISION.
       PROGRAM-ID. CARD-FOREIGN-TXN.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-TRANSACTION.
           05 WS-PAN             PIC X(16).
           05 WS-TXN-AMT-LOCAL   PIC S9(9)V99 COMP-3.
           05 WS-TXN-CCY         PIC X(3).
           05 WS-MERCHANT-COUNTRY PIC X(2).
           05 WS-TXN-DATE        PIC 9(8).
       01 WS-CARD-SETTINGS.
           05 WS-INTL-ENABLED    PIC X VALUE 'Y'.
               88 INTL-OK       VALUE 'Y'.
           05 WS-HOME-COUNTRY    PIC X(2) VALUE 'US'.
           05 WS-FX-FEE-PCT     PIC S9(1)V99 COMP-3
               VALUE 0.03.
           05 WS-TRAVEL-NOTICE   PIC X VALUE 'N'.
               88 HAS-NOTICE    VALUE 'Y'.
       01 WS-COUNTRY-TABLE.
           05 WS-BLOCKED OCCURS 5 TIMES.
               10 WS-BLK-CC     PIC X(2).
       01 WS-BLK-COUNT          PIC 9 VALUE 5.
       01 WS-IDX                PIC 9.
       01 WS-FX-RATE            PIC S9(3)V9(6) COMP-3.
       01 WS-USD-AMOUNT         PIC S9(9)V99 COMP-3.
       01 WS-FX-FEE             PIC S9(5)V99 COMP-3.
       01 WS-TOTAL-CHARGE       PIC S9(9)V99 COMP-3.
       01 WS-IS-FOREIGN         PIC X VALUE 'N'.
           88 IS-FOREIGN-TXN   VALUE 'Y'.
       01 WS-IS-BLOCKED         PIC X VALUE 'N'.
           88 COUNTRY-BLOCKED  VALUE 'Y'.
       01 WS-AUTH-RESULT        PIC X(12).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-CHECK-FOREIGN
           IF IS-FOREIGN-TXN
               PERFORM 2000-CHECK-BLOCKED
               IF NOT COUNTRY-BLOCKED
                   PERFORM 3000-CHECK-TRAVEL
                   PERFORM 4000-CONVERT-CURRENCY
                   PERFORM 5000-CALC-FEES
               END-IF
           ELSE
               MOVE WS-TXN-AMT-LOCAL TO WS-USD-AMOUNT
               MOVE 0 TO WS-FX-FEE
               MOVE WS-USD-AMOUNT TO WS-TOTAL-CHARGE
               MOVE 'APPROVED    ' TO WS-AUTH-RESULT
           END-IF
           PERFORM 6000-OUTPUT
           STOP RUN.
       1000-CHECK-FOREIGN.
           IF WS-MERCHANT-COUNTRY NOT = WS-HOME-COUNTRY
               MOVE 'Y' TO WS-IS-FOREIGN
           END-IF.
       2000-CHECK-BLOCKED.
           IF NOT INTL-OK
               MOVE 'INTL DISABLED' TO WS-AUTH-RESULT
               MOVE 'Y' TO WS-IS-BLOCKED
           ELSE
               PERFORM VARYING WS-IDX FROM 1 BY 1
                   UNTIL WS-IDX > WS-BLK-COUNT
                   IF WS-BLK-CC(WS-IDX) =
                       WS-MERCHANT-COUNTRY
                       MOVE 'Y' TO WS-IS-BLOCKED
                       MOVE 'BLOCKED CNTRY' TO
                           WS-AUTH-RESULT
                   END-IF
               END-PERFORM
           END-IF.
       3000-CHECK-TRAVEL.
           IF NOT HAS-NOTICE
               DISPLAY 'WARNING: NO TRAVEL NOTICE ON FILE'
           END-IF.
       4000-CONVERT-CURRENCY.
           IF WS-FX-RATE > 0
               COMPUTE WS-USD-AMOUNT =
                   WS-TXN-AMT-LOCAL / WS-FX-RATE
           ELSE
               MOVE WS-TXN-AMT-LOCAL TO WS-USD-AMOUNT
           END-IF.
       5000-CALC-FEES.
           COMPUTE WS-FX-FEE =
               WS-USD-AMOUNT * WS-FX-FEE-PCT
           COMPUTE WS-TOTAL-CHARGE =
               WS-USD-AMOUNT + WS-FX-FEE
           MOVE 'APPROVED    ' TO WS-AUTH-RESULT.
       6000-OUTPUT.
           DISPLAY 'FOREIGN TRANSACTION PROCESSING'
           DISPLAY '=============================='
           DISPLAY 'PAN:       ' WS-PAN
           DISPLAY 'COUNTRY:   ' WS-MERCHANT-COUNTRY
           DISPLAY 'LOCAL AMT: ' WS-TXN-CCY ' '
               WS-TXN-AMT-LOCAL
           DISPLAY 'USD AMT:   $' WS-USD-AMOUNT
           DISPLAY 'FX FEE:    $' WS-FX-FEE
           DISPLAY 'TOTAL:     $' WS-TOTAL-CHARGE
           DISPLAY 'RESULT:    ' WS-AUTH-RESULT.
