       IDENTIFICATION DIVISION.
       PROGRAM-ID. TREAS-SWAP-VALUE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-SWAP-CONTRACT.
           05 WS-SWAP-ID         PIC X(12).
           05 WS-NOTIONAL        PIC S9(13)V99 COMP-3.
           05 WS-FIXED-RATE      PIC S9(2)V9(6) COMP-3.
           05 WS-FLOAT-RATE      PIC S9(2)V9(6) COMP-3.
           05 WS-FLOAT-SPREAD    PIC S9(1)V9(4) COMP-3.
           05 WS-REMAINING-YRS   PIC 9(2).
           05 WS-PAY-FREQ        PIC 9.
               88 PF-MONTHLY     VALUE 1.
               88 PF-QUARTERLY   VALUE 4.
               88 PF-SEMI        VALUE 2.
           05 WS-PAY-RECEIVE     PIC X(1).
               88 IS-PAYER       VALUE 'P'.
               88 IS-RECEIVER    VALUE 'R'.
       01 WS-VALUATION.
           05 WS-FIXED-LEG-PV    PIC S9(13)V99 COMP-3.
           05 WS-FLOAT-LEG-PV    PIC S9(13)V99 COMP-3.
           05 WS-NET-VALUE       PIC S9(13)V99 COMP-3.
           05 WS-DV01            PIC S9(9)V99 COMP-3.
       01 WS-PERIODS             PIC 9(3).
       01 WS-PERIOD-IDX          PIC 9(3).
       01 WS-FIXED-CF            PIC S9(11)V99 COMP-3.
       01 WS-FLOAT-CF            PIC S9(11)V99 COMP-3.
       01 WS-DISC-RATE           PIC S9(1)V9(8) COMP-3.
       01 WS-DISC-FACTOR         PIC S9(1)V9(8) COMP-3.
       01 WS-EFFECTIVE-FLOAT     PIC S9(2)V9(6) COMP-3.
       01 WS-MTM-STATUS          PIC X(12).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-CALC-PERIODS
           PERFORM 2000-CALC-FIXED-LEG
           PERFORM 3000-CALC-FLOAT-LEG
           PERFORM 4000-CALC-NET-VALUE
           PERFORM 5000-CALC-DV01
           PERFORM 6000-OUTPUT
           STOP RUN.
       1000-CALC-PERIODS.
           IF PF-MONTHLY
               COMPUTE WS-PERIODS =
                   WS-REMAINING-YRS * 12
           ELSE
               IF PF-QUARTERLY
                   COMPUTE WS-PERIODS =
                       WS-REMAINING-YRS * 4
               ELSE
                   COMPUTE WS-PERIODS =
                       WS-REMAINING-YRS * 2
               END-IF
           END-IF
           COMPUTE WS-EFFECTIVE-FLOAT =
               WS-FLOAT-RATE + WS-FLOAT-SPREAD.
       2000-CALC-FIXED-LEG.
           MOVE 0 TO WS-FIXED-LEG-PV
           COMPUTE WS-FIXED-CF =
               WS-NOTIONAL * WS-FIXED-RATE /
               WS-PERIODS * WS-REMAINING-YRS
           PERFORM VARYING WS-PERIOD-IDX FROM 1 BY 1
               UNTIL WS-PERIOD-IDX > WS-PERIODS
               COMPUTE WS-DISC-RATE =
                   WS-EFFECTIVE-FLOAT / WS-PERIODS *
                   WS-REMAINING-YRS
               COMPUTE WS-DISC-FACTOR =
                   1 / (1 + WS-DISC-RATE)
               COMPUTE WS-FIXED-LEG-PV =
                   WS-FIXED-LEG-PV +
                   WS-FIXED-CF * WS-DISC-FACTOR
           END-PERFORM.
       3000-CALC-FLOAT-LEG.
           MOVE 0 TO WS-FLOAT-LEG-PV
           COMPUTE WS-FLOAT-CF =
               WS-NOTIONAL * WS-EFFECTIVE-FLOAT /
               WS-PERIODS * WS-REMAINING-YRS
           PERFORM VARYING WS-PERIOD-IDX FROM 1 BY 1
               UNTIL WS-PERIOD-IDX > WS-PERIODS
               COMPUTE WS-DISC-FACTOR =
                   1 / (1 + WS-DISC-RATE)
               COMPUTE WS-FLOAT-LEG-PV =
                   WS-FLOAT-LEG-PV +
                   WS-FLOAT-CF * WS-DISC-FACTOR
           END-PERFORM.
       4000-CALC-NET-VALUE.
           IF IS-PAYER
               COMPUTE WS-NET-VALUE =
                   WS-FLOAT-LEG-PV - WS-FIXED-LEG-PV
           ELSE
               COMPUTE WS-NET-VALUE =
                   WS-FIXED-LEG-PV - WS-FLOAT-LEG-PV
           END-IF
           IF WS-NET-VALUE > 0
               MOVE 'ASSET       ' TO WS-MTM-STATUS
           ELSE
               IF WS-NET-VALUE < 0
                   MOVE 'LIABILITY   ' TO WS-MTM-STATUS
               ELSE
                   MOVE 'AT-PAR      ' TO WS-MTM-STATUS
               END-IF
           END-IF.
       5000-CALC-DV01.
           COMPUTE WS-DV01 =
               WS-NET-VALUE * 0.0001 * WS-REMAINING-YRS.
       6000-OUTPUT.
           DISPLAY 'SWAP VALUATION REPORT'
           DISPLAY '====================='
           DISPLAY 'SWAP ID:    ' WS-SWAP-ID
           DISPLAY 'NOTIONAL:   $' WS-NOTIONAL
           DISPLAY 'FIXED RATE: ' WS-FIXED-RATE
           DISPLAY 'FLOAT RATE: ' WS-EFFECTIVE-FLOAT
           DISPLAY 'PERIODS:    ' WS-PERIODS
           DISPLAY 'FIXED PV:   $' WS-FIXED-LEG-PV
           DISPLAY 'FLOAT PV:   $' WS-FLOAT-LEG-PV
           DISPLAY 'NET VALUE:  $' WS-NET-VALUE
           DISPLAY 'DV01:       $' WS-DV01
           DISPLAY 'STATUS:     ' WS-MTM-STATUS.
