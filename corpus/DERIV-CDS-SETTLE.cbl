       IDENTIFICATION DIVISION.
       PROGRAM-ID. DERIV-CDS-SETTLE.
      *================================================================*
      * Credit Default Swap Settlement Calculator                       *
      * Calculates CDS premium legs, default leg, accrued premium,     *
      * and physical/cash settlement amounts upon credit event.         *
      *================================================================*
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-CDS-PORTFOLIO.
           05  WS-CDS-ENTRY       OCCURS 10 TIMES.
               10  CD-REF-ENTITY  PIC X(20).
               10  CD-NOTIONAL    PIC S9(13)V99.
               10  CD-SPREAD-BPS  PIC 9(05).
               10  CD-RECOVERY    PIC 9V99.
               10  CD-TENOR-YRS   PIC 9(02).
               10  CD-CREDIT-EVT  PIC X(01).
               10  CD-PREMIUM-PV  PIC S9(11)V99.
               10  CD-DEFAULT-PV  PIC S9(11)V99.
               10  CD-MTM         PIC S9(11)V99.
               10  CD-SETTLE-AMT  PIC S9(11)V99.
       01  WS-NUM-CDS             PIC 9(02) VALUE 5.
       01  WS-IDX                 PIC 9(02).
       01  WS-PERIOD-IDX          PIC 9(02).
       01  WS-NUM-PERIODS         PIC 9(03).
       01  WS-SPREAD-DECIMAL      PIC 9V9(06).
       01  WS-QUARTERLY-PREM      PIC S9(11)V99.
       01  WS-DF                  PIC 9V9(10).
       01  WS-SURV-PROB           PIC 9V9(10).
       01  WS-HAZARD-RATE         PIC 9V9(08).
       01  WS-LGD                 PIC 9V9(06).
       01  WS-DISC-PREM           PIC S9(11)V99.
       01  WS-DISC-DEFAULT        PIC S9(11)V99.
       01  WS-RISK-FREE           PIC 9V9(06) VALUE 0.045000.
       01  WS-YEAR-FRAC           PIC 9V9(06).
       01  WS-TOTAL-MTM           PIC S9(13)V99 VALUE 0.
       01  WS-TOTAL-NOTIONAL      PIC S9(15)V99 VALUE 0.
       01  WS-EVENT-CNT           PIC 9(02) VALUE 0.
       01  WS-TOTAL-SETTLE        PIC S9(13)V99 VALUE 0.
       01  WS-ACCRUED-PREM        PIC S9(09)V99.
       01  WS-DAYS-ACCRUED        PIC 9(03) VALUE 45.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-VALUE-CDS-BOOK
           PERFORM 9000-REPORT
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'ACME INDUSTRIES    ' TO CD-REF-ENTITY(1)
           MOVE 10000000.00 TO CD-NOTIONAL(1)
           MOVE 150 TO CD-SPREAD-BPS(1)
           MOVE 0.40 TO CD-RECOVERY(1)
           MOVE 5 TO CD-TENOR-YRS(1)
           MOVE 'N' TO CD-CREDIT-EVT(1)
           MOVE 'BETA CORP          ' TO CD-REF-ENTITY(2)
           MOVE 5000000.00 TO CD-NOTIONAL(2)
           MOVE 320 TO CD-SPREAD-BPS(2)
           MOVE 0.35 TO CD-RECOVERY(2)
           MOVE 3 TO CD-TENOR-YRS(2)
           MOVE 'N' TO CD-CREDIT-EVT(2)
           MOVE 'GAMMA BANK         ' TO CD-REF-ENTITY(3)
           MOVE 15000000.00 TO CD-NOTIONAL(3)
           MOVE 85 TO CD-SPREAD-BPS(3)
           MOVE 0.40 TO CD-RECOVERY(3)
           MOVE 5 TO CD-TENOR-YRS(3)
           MOVE 'N' TO CD-CREDIT-EVT(3)
           MOVE 'DELTA ENERGY       ' TO CD-REF-ENTITY(4)
           MOVE 8000000.00 TO CD-NOTIONAL(4)
           MOVE 450 TO CD-SPREAD-BPS(4)
           MOVE 0.25 TO CD-RECOVERY(4)
           MOVE 5 TO CD-TENOR-YRS(4)
           MOVE 'Y' TO CD-CREDIT-EVT(4)
           MOVE 'EPSILON TELECOM    ' TO CD-REF-ENTITY(5)
           MOVE 12000000.00 TO CD-NOTIONAL(5)
           MOVE 200 TO CD-SPREAD-BPS(5)
           MOVE 0.40 TO CD-RECOVERY(5)
           MOVE 7 TO CD-TENOR-YRS(5)
           MOVE 'N' TO CD-CREDIT-EVT(5).
       2000-VALUE-CDS-BOOK.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-NUM-CDS
               ADD CD-NOTIONAL(WS-IDX) TO WS-TOTAL-NOTIONAL
               IF CD-CREDIT-EVT(WS-IDX) = 'Y'
                   PERFORM 3000-CALC-SETTLEMENT
                   ADD 1 TO WS-EVENT-CNT
               ELSE
                   PERFORM 4000-CALC-MTM
               END-IF
               ADD CD-MTM(WS-IDX) TO WS-TOTAL-MTM
           END-PERFORM.
       3000-CALC-SETTLEMENT.
           COMPUTE WS-LGD = 1 - CD-RECOVERY(WS-IDX)
           COMPUTE CD-SETTLE-AMT(WS-IDX) ROUNDED =
               CD-NOTIONAL(WS-IDX) * WS-LGD
           COMPUTE WS-SPREAD-DECIMAL =
               CD-SPREAD-BPS(WS-IDX) / 10000
           COMPUTE WS-ACCRUED-PREM ROUNDED =
               CD-NOTIONAL(WS-IDX) * WS-SPREAD-DECIMAL
               * WS-DAYS-ACCRUED / 360
           COMPUTE CD-MTM(WS-IDX) =
               CD-SETTLE-AMT(WS-IDX) - WS-ACCRUED-PREM
           ADD CD-SETTLE-AMT(WS-IDX) TO WS-TOTAL-SETTLE
           DISPLAY 'CREDIT EVENT: '
               CD-REF-ENTITY(WS-IDX)
               ' SETTLE=' CD-SETTLE-AMT(WS-IDX).
       4000-CALC-MTM.
           COMPUTE WS-SPREAD-DECIMAL =
               CD-SPREAD-BPS(WS-IDX) / 10000
           COMPUTE WS-LGD = 1 - CD-RECOVERY(WS-IDX)
           IF WS-LGD > ZERO
               COMPUTE WS-HAZARD-RATE ROUNDED =
                   WS-SPREAD-DECIMAL / WS-LGD
           ELSE
               MOVE 0.01 TO WS-HAZARD-RATE
           END-IF
           COMPUTE WS-NUM-PERIODS =
               CD-TENOR-YRS(WS-IDX) * 4
           MOVE ZERO TO CD-PREMIUM-PV(WS-IDX)
           MOVE ZERO TO CD-DEFAULT-PV(WS-IDX)
           PERFORM VARYING WS-PERIOD-IDX FROM 1 BY 1
               UNTIL WS-PERIOD-IDX > WS-NUM-PERIODS
               COMPUTE WS-YEAR-FRAC =
                   WS-PERIOD-IDX * 0.25
               COMPUTE WS-DF ROUNDED =
                   1 / (1 + WS-RISK-FREE *
                   WS-YEAR-FRAC)
               COMPUTE WS-SURV-PROB ROUNDED =
                   FUNCTION EXP(-1 * WS-HAZARD-RATE
                   * WS-YEAR-FRAC)
               COMPUTE WS-QUARTERLY-PREM ROUNDED =
                   CD-NOTIONAL(WS-IDX) *
                   WS-SPREAD-DECIMAL * 0.25
               COMPUTE WS-DISC-PREM ROUNDED =
                   WS-QUARTERLY-PREM * WS-DF *
                   WS-SURV-PROB
               ADD WS-DISC-PREM TO
                   CD-PREMIUM-PV(WS-IDX)
               COMPUTE WS-DISC-DEFAULT ROUNDED =
                   CD-NOTIONAL(WS-IDX) * WS-LGD *
                   WS-DF * WS-HAZARD-RATE * 0.25
               ADD WS-DISC-DEFAULT TO
                   CD-DEFAULT-PV(WS-IDX)
           END-PERFORM
           COMPUTE CD-MTM(WS-IDX) =
               CD-DEFAULT-PV(WS-IDX) -
               CD-PREMIUM-PV(WS-IDX).
       9000-REPORT.
           DISPLAY 'CDS BOOK VALUATION'
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-NUM-CDS
               DISPLAY CD-REF-ENTITY(WS-IDX)
                   ' MTM=' CD-MTM(WS-IDX)
           END-PERFORM
           DISPLAY 'TOTAL NOTIONAL: ' WS-TOTAL-NOTIONAL
           DISPLAY 'TOTAL MTM:      ' WS-TOTAL-MTM
           DISPLAY 'CREDIT EVENTS:  ' WS-EVENT-CNT
           DISPLAY 'TOTAL SETTLED:  ' WS-TOTAL-SETTLE.
