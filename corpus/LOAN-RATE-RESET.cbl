       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOAN-RATE-RESET.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-LOAN-INFO.
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-CURRENT-BAL         PIC S9(9)V99 COMP-3.
           05 WS-CURRENT-RATE        PIC S9(3)V9(6) COMP-3.
           05 WS-INDEX-RATE          PIC S9(3)V9(6) COMP-3.
           05 WS-MARGIN              PIC S9(1)V9(4) COMP-3.
           05 WS-REMAINING-TERM      PIC 9(3).
           05 WS-CURRENT-PMT         PIC S9(7)V99 COMP-3.
       01 WS-RATE-CAPS.
           05 WS-PERIODIC-CAP        PIC S9(1)V9(4) COMP-3.
           05 WS-LIFETIME-CAP        PIC S9(3)V9(4) COMP-3.
           05 WS-LIFETIME-FLOOR      PIC S9(3)V9(4) COMP-3.
           05 WS-INITIAL-RATE        PIC S9(3)V9(6) COMP-3.
       01 WS-INDEX-TYPE              PIC X(1).
           88 WS-SOFR                 VALUE 'S'.
           88 WS-PRIME                VALUE 'P'.
           88 WS-LIBOR                VALUE 'L'.
           88 WS-CMT                  VALUE 'C'.
       01 WS-RESET-FREQ              PIC X(1).
           88 WS-ANNUAL               VALUE 'A'.
           88 WS-SEMI-ANNUAL          VALUE 'S'.
           88 WS-MONTHLY-RESET        VALUE 'M'.
       01 WS-CALC-FIELDS.
           05 WS-NEW-RATE            PIC S9(3)V9(6) COMP-3.
           05 WS-RATE-CHANGE         PIC S9(3)V9(6) COMP-3.
           05 WS-NEW-PMT             PIC S9(7)V99 COMP-3.
           05 WS-PMT-CHANGE          PIC S9(7)V99 COMP-3.
           05 WS-MAX-RATE            PIC S9(3)V9(6) COMP-3.
           05 WS-MIN-RATE            PIC S9(3)V9(6) COMP-3.
           05 WS-MONTHLY-RATE        PIC S9(1)V9(8) COMP-3.
           05 WS-TOTAL-INT-COST      PIC S9(11)V99 COMP-3.
       01 WS-SHOCK-TABLE.
           05 WS-SHOCK-SCENARIO OCCURS 5.
               10 WS-SHOCK-BPS       PIC S9(5) COMP-3.
               10 WS-SHOCK-RATE      PIC S9(3)V9(6) COMP-3.
               10 WS-SHOCK-PMT       PIC S9(7)V99 COMP-3.
       01 WS-SHOCK-IDX              PIC 9(1).
       01 WS-CAP-HIT-FLAG           PIC X VALUE 'N'.
           88 WS-CAP-HIT             VALUE 'Y'.
       01 WS-FLOOR-HIT-FLAG         PIC X VALUE 'N'.
           88 WS-FLOOR-HIT           VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-NEW-RATE
           PERFORM 3000-APPLY-CAPS
           PERFORM 4000-CALC-NEW-PAYMENT
           PERFORM 5000-RUN-SCENARIOS
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'N' TO WS-CAP-HIT-FLAG
           MOVE 'N' TO WS-FLOOR-HIT-FLAG
           COMPUTE WS-MAX-RATE =
               WS-INITIAL-RATE + WS-LIFETIME-CAP
           COMPUTE WS-MIN-RATE =
               WS-LIFETIME-FLOOR.
       2000-CALC-NEW-RATE.
           COMPUTE WS-NEW-RATE =
               WS-INDEX-RATE + WS-MARGIN
           COMPUTE WS-RATE-CHANGE =
               WS-NEW-RATE - WS-CURRENT-RATE.
       3000-APPLY-CAPS.
           IF WS-RATE-CHANGE > WS-PERIODIC-CAP
               COMPUTE WS-NEW-RATE =
                   WS-CURRENT-RATE + WS-PERIODIC-CAP
               MOVE 'Y' TO WS-CAP-HIT-FLAG
           ELSE
               IF WS-RATE-CHANGE < (0 - WS-PERIODIC-CAP)
                   COMPUTE WS-NEW-RATE =
                       WS-CURRENT-RATE - WS-PERIODIC-CAP
               END-IF
           END-IF
           IF WS-NEW-RATE > WS-MAX-RATE
               MOVE WS-MAX-RATE TO WS-NEW-RATE
               MOVE 'Y' TO WS-CAP-HIT-FLAG
           END-IF
           IF WS-NEW-RATE < WS-MIN-RATE
               MOVE WS-MIN-RATE TO WS-NEW-RATE
               MOVE 'Y' TO WS-FLOOR-HIT-FLAG
           END-IF
           COMPUTE WS-RATE-CHANGE =
               WS-NEW-RATE - WS-CURRENT-RATE.
       4000-CALC-NEW-PAYMENT.
           COMPUTE WS-MONTHLY-RATE =
               WS-NEW-RATE / 12
           IF WS-MONTHLY-RATE > 0
               COMPUTE WS-NEW-PMT =
                   WS-CURRENT-BAL * WS-MONTHLY-RATE /
                   (1 - (1 + WS-MONTHLY-RATE) **
                   (0 - WS-REMAINING-TERM))
           ELSE
               COMPUTE WS-NEW-PMT =
                   WS-CURRENT-BAL / WS-REMAINING-TERM
           END-IF
           COMPUTE WS-PMT-CHANGE =
               WS-NEW-PMT - WS-CURRENT-PMT
           COMPUTE WS-TOTAL-INT-COST =
               (WS-NEW-PMT * WS-REMAINING-TERM) -
               WS-CURRENT-BAL.
       5000-RUN-SCENARIOS.
           PERFORM VARYING WS-SHOCK-IDX FROM 1 BY 1
               UNTIL WS-SHOCK-IDX > 5
               EVALUATE WS-SHOCK-IDX
                   WHEN 1
                       MOVE -200 TO
                           WS-SHOCK-BPS(WS-SHOCK-IDX)
                   WHEN 2
                       MOVE -100 TO
                           WS-SHOCK-BPS(WS-SHOCK-IDX)
                   WHEN 3
                       MOVE 0 TO
                           WS-SHOCK-BPS(WS-SHOCK-IDX)
                   WHEN 4
                       MOVE 100 TO
                           WS-SHOCK-BPS(WS-SHOCK-IDX)
                   WHEN 5
                       MOVE 200 TO
                           WS-SHOCK-BPS(WS-SHOCK-IDX)
               END-EVALUATE
               COMPUTE WS-SHOCK-RATE(WS-SHOCK-IDX) =
                   WS-NEW-RATE +
                   (WS-SHOCK-BPS(WS-SHOCK-IDX) / 10000)
               IF WS-SHOCK-RATE(WS-SHOCK-IDX) < WS-MIN-RATE
                   MOVE WS-MIN-RATE TO
                       WS-SHOCK-RATE(WS-SHOCK-IDX)
               END-IF
               IF WS-SHOCK-RATE(WS-SHOCK-IDX) > WS-MAX-RATE
                   MOVE WS-MAX-RATE TO
                       WS-SHOCK-RATE(WS-SHOCK-IDX)
               END-IF
               COMPUTE WS-SHOCK-PMT(WS-SHOCK-IDX) =
                   WS-CURRENT-BAL *
                   (WS-SHOCK-RATE(WS-SHOCK-IDX) / 12) /
                   (1 - (1 +
                   WS-SHOCK-RATE(WS-SHOCK-IDX) / 12) **
                   (0 - WS-REMAINING-TERM))
           END-PERFORM.
       6000-DISPLAY-RESULTS.
           DISPLAY 'ARM RATE RESET ANALYSIS'
           DISPLAY '======================='
           DISPLAY 'ACCOUNT:        ' WS-ACCT-NUM
           DISPLAY 'CURRENT RATE:   ' WS-CURRENT-RATE
           DISPLAY 'INDEX + MARGIN: ' WS-INDEX-RATE
               ' + ' WS-MARGIN
           DISPLAY 'NEW RATE:       ' WS-NEW-RATE
           DISPLAY 'RATE CHANGE:    ' WS-RATE-CHANGE
           IF WS-CAP-HIT
               DISPLAY '** PERIODIC/LIFETIME CAP HIT **'
           END-IF
           IF WS-FLOOR-HIT
               DISPLAY '** LIFETIME FLOOR HIT **'
           END-IF
           DISPLAY 'CURRENT PMT:    ' WS-CURRENT-PMT
           DISPLAY 'NEW PMT:        ' WS-NEW-PMT
           DISPLAY 'PMT CHANGE:     ' WS-PMT-CHANGE
           DISPLAY 'TOTAL INT COST: ' WS-TOTAL-INT-COST
           DISPLAY 'SHOCK SCENARIOS:'
           PERFORM VARYING WS-SHOCK-IDX FROM 1 BY 1
               UNTIL WS-SHOCK-IDX > 5
               DISPLAY '  BPS: '
                   WS-SHOCK-BPS(WS-SHOCK-IDX)
                   ' RATE: '
                   WS-SHOCK-RATE(WS-SHOCK-IDX)
                   ' PMT: '
                   WS-SHOCK-PMT(WS-SHOCK-IDX)
           END-PERFORM.
