       IDENTIFICATION DIVISION.
       PROGRAM-ID. TREAS-WIRE-FEE-CALC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-WIRE-DATA.
           05 WS-WIRE-ID             PIC X(15).
           05 WS-WIRE-AMOUNT         PIC S9(11)V99 COMP-3.
           05 WS-SENDER-ACCT         PIC X(12).
       01 WS-WIRE-TYPE               PIC X(1).
           88 WS-DOMESTIC            VALUE 'D'.
           88 WS-INTERNATIONAL       VALUE 'I'.
           88 WS-FED-WIRE            VALUE 'F'.
       01 WS-PRIORITY                PIC X(1).
           88 WS-STANDARD            VALUE 'S'.
           88 WS-URGENT              VALUE 'U'.
       01 WS-ACCT-TIER               PIC X(1).
           88 WS-CONSUMER            VALUE 'C'.
           88 WS-BUSINESS            VALUE 'B'.
           88 WS-TREASURY            VALUE 'T'.
       01 WS-FEE-FIELDS.
           05 WS-BASE-FEE            PIC S9(5)V99 COMP-3.
           05 WS-INTL-SURCHARGE      PIC S9(5)V99 COMP-3.
           05 WS-URGENT-SURCHARGE    PIC S9(5)V99 COMP-3.
           05 WS-TOTAL-FEE           PIC S9(5)V99 COMP-3.
       01 WS-WAIVER-FLAG             PIC X VALUE 'N'.
           88 WS-FEE-WAIVED          VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-BASE-FEE
           PERFORM 3000-APPLY-SURCHARGES
           PERFORM 4000-CHECK-WAIVER
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-BASE-FEE
           MOVE 0 TO WS-INTL-SURCHARGE
           MOVE 0 TO WS-URGENT-SURCHARGE
           MOVE 0 TO WS-TOTAL-FEE
           MOVE 'N' TO WS-WAIVER-FLAG.
       2000-CALC-BASE-FEE.
           EVALUATE TRUE
               WHEN WS-DOMESTIC
                   IF WS-CONSUMER
                       MOVE 25.00 TO WS-BASE-FEE
                   ELSE
                       IF WS-BUSINESS
                           MOVE 15.00 TO WS-BASE-FEE
                       ELSE
                           MOVE 10.00 TO WS-BASE-FEE
                       END-IF
                   END-IF
               WHEN WS-INTERNATIONAL
                   IF WS-CONSUMER
                       MOVE 45.00 TO WS-BASE-FEE
                   ELSE
                       MOVE 35.00 TO WS-BASE-FEE
                   END-IF
               WHEN WS-FED-WIRE
                   MOVE 20.00 TO WS-BASE-FEE
               WHEN OTHER
                   MOVE 30.00 TO WS-BASE-FEE
           END-EVALUATE.
       3000-APPLY-SURCHARGES.
           IF WS-INTERNATIONAL
               COMPUTE WS-INTL-SURCHARGE =
                   WS-WIRE-AMOUNT * 0.0010
               IF WS-INTL-SURCHARGE < 10
                   MOVE 10.00 TO WS-INTL-SURCHARGE
               END-IF
           END-IF
           IF WS-URGENT
               MOVE 15.00 TO WS-URGENT-SURCHARGE
           END-IF
           COMPUTE WS-TOTAL-FEE =
               WS-BASE-FEE + WS-INTL-SURCHARGE +
               WS-URGENT-SURCHARGE.
       4000-CHECK-WAIVER.
           IF WS-TREASURY
               IF WS-WIRE-AMOUNT > 1000000
                   MOVE 'Y' TO WS-WAIVER-FLAG
                   MOVE 0 TO WS-TOTAL-FEE
               END-IF
           END-IF.
       5000-DISPLAY-RESULTS.
           DISPLAY 'WIRE TRANSFER FEE'
           DISPLAY '================='
           DISPLAY 'WIRE ID:     ' WS-WIRE-ID
           DISPLAY 'AMOUNT:      ' WS-WIRE-AMOUNT
           IF WS-DOMESTIC
               DISPLAY 'TYPE: DOMESTIC'
           END-IF
           IF WS-INTERNATIONAL
               DISPLAY 'TYPE: INTERNATIONAL'
           END-IF
           IF WS-FED-WIRE
               DISPLAY 'TYPE: FED WIRE'
           END-IF
           DISPLAY 'BASE FEE:    ' WS-BASE-FEE
           DISPLAY 'INTL SURCH:  ' WS-INTL-SURCHARGE
           DISPLAY 'URGENT SURCH:' WS-URGENT-SURCHARGE
           DISPLAY 'TOTAL FEE:   ' WS-TOTAL-FEE
           IF WS-FEE-WAIVED
               DISPLAY 'FEE WAIVED (TREASURY TIER)'
           END-IF.
