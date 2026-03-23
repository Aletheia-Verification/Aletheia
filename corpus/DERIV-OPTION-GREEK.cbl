       IDENTIFICATION DIVISION.
       PROGRAM-ID. DERIV-OPTION-GREEK.
      *================================================================*
      * Options Greek Calculator (Simplified Black-Scholes)             *
      * Approximates Delta, Gamma, Theta, and Vega for European        *
      * equity options using a simplified normal distribution.          *
      *================================================================*
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-OPTION-TABLE.
           05  WS-OPT-ENTRY       OCCURS 10 TIMES.
               10  OE-SYMBOL      PIC X(06).
               10  OE-TYPE        PIC X(01).
               10  OE-SPOT        PIC 9(05)V9(04).
               10  OE-STRIKE      PIC 9(05)V9(04).
               10  OE-TIME-YRS    PIC 9V9(04).
               10  OE-VOL         PIC 9V9(04).
               10  OE-RATE        PIC 9V9(06).
               10  OE-DELTA       PIC S9V9(06).
               10  OE-GAMMA       PIC S9V9(08).
               10  OE-THETA       PIC S9(05)V99.
               10  OE-VEGA        PIC S9(05)V99.
               10  OE-PRICE       PIC S9(05)V99.
       01  WS-NUM-OPTIONS         PIC 9(02) VALUE 6.
       01  WS-IDX                 PIC 9(02).
       01  WS-D1                  PIC S9(03)V9(08).
       01  WS-D2                  PIC S9(03)V9(08).
       01  WS-VOL-SQRT            PIC 9(03)V9(08).
       01  WS-LN-RATIO            PIC S9(03)V9(08).
       01  WS-ND1                 PIC 9V9(08).
       01  WS-ND2                 PIC 9V9(08).
       01  WS-PDF-D1              PIC 9V9(08).
       01  WS-SQRT-T              PIC 9V9(08).
       01  WS-EXP-RT              PIC 9V9(08).
       01  WS-CALL-PRICE          PIC S9(05)V99.
       01  WS-PUT-PRICE           PIC S9(05)V99.
       01  WS-TOTAL-DELTA         PIC S9(07)V9(04) VALUE 0.
       01  WS-TOTAL-GAMMA         PIC S9(07)V9(04) VALUE 0.
       01  WS-TOTAL-THETA         PIC S9(09)V99 VALUE 0.
       01  WS-TOTAL-VEGA          PIC S9(09)V99 VALUE 0.
       01  WS-CONTRACTS           PIC 9(04) VALUE 100.
       01  WS-PI                  PIC 9V9(08)
                                  VALUE 3.14159265.
       01  WS-TEMP-CALC           PIC S9(05)V9(08).
       01  WS-ABS-D1              PIC 9(03)V9(08).
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-GREEKS
           PERFORM 9000-REPORT
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'AAPL  ' TO OE-SYMBOL(1)
           MOVE 'C' TO OE-TYPE(1)
           MOVE 185.5000 TO OE-SPOT(1)
           MOVE 190.0000 TO OE-STRIKE(1)
           MOVE 0.2500 TO OE-TIME-YRS(1)
           MOVE 0.2200 TO OE-VOL(1)
           MOVE 0.050000 TO OE-RATE(1)
           MOVE 'AAPL  ' TO OE-SYMBOL(2)
           MOVE 'P' TO OE-TYPE(2)
           MOVE 185.5000 TO OE-SPOT(2)
           MOVE 180.0000 TO OE-STRIKE(2)
           MOVE 0.2500 TO OE-TIME-YRS(2)
           MOVE 0.2200 TO OE-VOL(2)
           MOVE 0.050000 TO OE-RATE(2)
           MOVE 'MSFT  ' TO OE-SYMBOL(3)
           MOVE 'C' TO OE-TYPE(3)
           MOVE 420.0000 TO OE-SPOT(3)
           MOVE 430.0000 TO OE-STRIKE(3)
           MOVE 0.5000 TO OE-TIME-YRS(3)
           MOVE 0.2500 TO OE-VOL(3)
           MOVE 0.050000 TO OE-RATE(3)
           MOVE 'MSFT  ' TO OE-SYMBOL(4)
           MOVE 'P' TO OE-TYPE(4)
           MOVE 420.0000 TO OE-SPOT(4)
           MOVE 410.0000 TO OE-STRIKE(4)
           MOVE 0.5000 TO OE-TIME-YRS(4)
           MOVE 0.2500 TO OE-VOL(4)
           MOVE 0.050000 TO OE-RATE(4)
           MOVE 'JPM   ' TO OE-SYMBOL(5)
           MOVE 'C' TO OE-TYPE(5)
           MOVE 195.0000 TO OE-SPOT(5)
           MOVE 200.0000 TO OE-STRIKE(5)
           MOVE 0.7500 TO OE-TIME-YRS(5)
           MOVE 0.2800 TO OE-VOL(5)
           MOVE 0.050000 TO OE-RATE(5)
           MOVE 'JPM   ' TO OE-SYMBOL(6)
           MOVE 'P' TO OE-TYPE(6)
           MOVE 195.0000 TO OE-SPOT(6)
           MOVE 190.0000 TO OE-STRIKE(6)
           MOVE 0.7500 TO OE-TIME-YRS(6)
           MOVE 0.2800 TO OE-VOL(6)
           MOVE 0.050000 TO OE-RATE(6).
       2000-CALC-GREEKS.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-NUM-OPTIONS
               PERFORM 2100-CALC-D1-D2
               PERFORM 2200-APPROX-NORMAL
               PERFORM 2300-CALC-DELTA
               PERFORM 2400-CALC-GAMMA
               PERFORM 2500-CALC-THETA
               PERFORM 2600-CALC-VEGA
               ADD OE-DELTA(WS-IDX) TO WS-TOTAL-DELTA
               ADD OE-GAMMA(WS-IDX) TO WS-TOTAL-GAMMA
               ADD OE-THETA(WS-IDX) TO WS-TOTAL-THETA
               ADD OE-VEGA(WS-IDX) TO WS-TOTAL-VEGA
           END-PERFORM.
       2100-CALC-D1-D2.
           IF OE-TIME-YRS(WS-IDX) > ZERO
               COMPUTE WS-SQRT-T ROUNDED =
                   FUNCTION SQRT(OE-TIME-YRS(WS-IDX))
           ELSE
               MOVE 0.01 TO WS-SQRT-T
           END-IF
           COMPUTE WS-VOL-SQRT ROUNDED =
               OE-VOL(WS-IDX) * WS-SQRT-T
           IF OE-STRIKE(WS-IDX) > ZERO AND
              OE-SPOT(WS-IDX) > ZERO
               COMPUTE WS-LN-RATIO ROUNDED =
                   FUNCTION LOG(OE-SPOT(WS-IDX) /
                   OE-STRIKE(WS-IDX))
           ELSE
               MOVE 0 TO WS-LN-RATIO
           END-IF
           IF WS-VOL-SQRT > ZERO
               COMPUTE WS-D1 ROUNDED =
                   (WS-LN-RATIO + (OE-RATE(WS-IDX) +
                   OE-VOL(WS-IDX) * OE-VOL(WS-IDX) / 2)
                   * OE-TIME-YRS(WS-IDX)) / WS-VOL-SQRT
               COMPUTE WS-D2 ROUNDED =
                   WS-D1 - WS-VOL-SQRT
           ELSE
               MOVE 0 TO WS-D1
               MOVE 0 TO WS-D2
           END-IF.
       2200-APPROX-NORMAL.
           MOVE WS-D1 TO WS-ABS-D1
           IF WS-D1 < ZERO
               COMPUTE WS-ABS-D1 = WS-D1 * -1
           END-IF
           COMPUTE WS-PDF-D1 ROUNDED =
               1 / FUNCTION SQRT(2 * WS-PI) *
               FUNCTION EXP(-0.5 * WS-D1 * WS-D1)
           COMPUTE WS-ND1 ROUNDED =
               0.50 + 0.50 *
               (1 - FUNCTION EXP(-0.7 * WS-ABS-D1))
           IF WS-D1 < ZERO
               COMPUTE WS-ND1 = 1 - WS-ND1
           END-IF
           MOVE WS-D2 TO WS-ABS-D1
           IF WS-D2 < ZERO
               COMPUTE WS-ABS-D1 = WS-D2 * -1
           END-IF
           COMPUTE WS-ND2 ROUNDED =
               0.50 + 0.50 *
               (1 - FUNCTION EXP(-0.7 * WS-ABS-D1))
           IF WS-D2 < ZERO
               COMPUTE WS-ND2 = 1 - WS-ND2
           END-IF.
       2300-CALC-DELTA.
           IF OE-TYPE(WS-IDX) = 'C'
               MOVE WS-ND1 TO OE-DELTA(WS-IDX)
           ELSE
               COMPUTE OE-DELTA(WS-IDX) = WS-ND1 - 1
           END-IF.
       2400-CALC-GAMMA.
           IF WS-VOL-SQRT > ZERO AND
              OE-SPOT(WS-IDX) > ZERO
               COMPUTE OE-GAMMA(WS-IDX) ROUNDED =
                   WS-PDF-D1 /
                   (OE-SPOT(WS-IDX) * WS-VOL-SQRT)
           ELSE
               MOVE ZERO TO OE-GAMMA(WS-IDX)
           END-IF.
       2500-CALC-THETA.
           COMPUTE WS-EXP-RT ROUNDED =
               FUNCTION EXP(-1 * OE-RATE(WS-IDX) *
               OE-TIME-YRS(WS-IDX))
           IF OE-TYPE(WS-IDX) = 'C'
               COMPUTE OE-THETA(WS-IDX) ROUNDED =
                   (-1 * OE-SPOT(WS-IDX) * WS-PDF-D1 *
                   OE-VOL(WS-IDX) / (2 * WS-SQRT-T)) -
                   OE-RATE(WS-IDX) * OE-STRIKE(WS-IDX) *
                   WS-EXP-RT * WS-ND2
           ELSE
               COMPUTE OE-THETA(WS-IDX) ROUNDED =
                   (-1 * OE-SPOT(WS-IDX) * WS-PDF-D1 *
                   OE-VOL(WS-IDX) / (2 * WS-SQRT-T)) +
                   OE-RATE(WS-IDX) * OE-STRIKE(WS-IDX) *
                   WS-EXP-RT * (1 - WS-ND2)
           END-IF
           COMPUTE OE-THETA(WS-IDX) ROUNDED =
               OE-THETA(WS-IDX) / 365.
       2600-CALC-VEGA.
           COMPUTE OE-VEGA(WS-IDX) ROUNDED =
               OE-SPOT(WS-IDX) * WS-PDF-D1 * WS-SQRT-T
               / 100.
       9000-REPORT.
           DISPLAY 'OPTIONS GREEK SUMMARY'
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-NUM-OPTIONS
               DISPLAY OE-SYMBOL(WS-IDX) ' '
                   OE-TYPE(WS-IDX)
                   ' K=' OE-STRIKE(WS-IDX)
                   ' D=' OE-DELTA(WS-IDX)
                   ' G=' OE-GAMMA(WS-IDX)
           END-PERFORM
           DISPLAY 'PORTFOLIO DELTA: ' WS-TOTAL-DELTA
           DISPLAY 'PORTFOLIO GAMMA: ' WS-TOTAL-GAMMA
           DISPLAY 'PORTFOLIO THETA: ' WS-TOTAL-THETA
           DISPLAY 'PORTFOLIO VEGA:  ' WS-TOTAL-VEGA.
