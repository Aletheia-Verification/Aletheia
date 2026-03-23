       IDENTIFICATION DIVISION.
       PROGRAM-ID. INS-RIDER-CALC.
      *================================================================
      * INSURANCE RIDER PREMIUM CALCULATOR
      * Prices optional riders: waiver of premium, accelerated death
      * benefit, long-term care, and guaranteed insurability.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-BASE-POLICY.
           05 WS-POL-NUM              PIC X(12).
           05 WS-BASE-PREMIUM         PIC S9(7)V99 COMP-3.
           05 WS-FACE-AMOUNT          PIC S9(9)V99 COMP-3.
           05 WS-INSURED-AGE          PIC 9(3).
           05 WS-INSURED-GENDER       PIC X(1).
               88 GENDER-MALE         VALUE 'M'.
               88 GENDER-FEMALE       VALUE 'F'.
           05 WS-RISK-CLASS           PIC X(2).
               88 RC-PREFERRED        VALUE 'PP'.
               88 RC-STANDARD         VALUE 'ST'.
               88 RC-RATED            VALUE 'RT'.
       01 WS-RIDERS.
           05 WS-RIDER-COUNT          PIC 9(1) VALUE 0.
           05 WS-RIDER-TABLE OCCURS 5 TIMES.
               10 WS-RD-CODE          PIC X(3).
                   88 RD-WOP           VALUE 'WOP'.
                   88 RD-ADB           VALUE 'ADB'.
                   88 RD-LTC           VALUE 'LTC'.
                   88 RD-GIO           VALUE 'GIO'.
                   88 RD-CTR           VALUE 'CTR'.
               10 WS-RD-SELECTED      PIC X VALUE 'N'.
                   88 RD-ACTIVE        VALUE 'Y'.
               10 WS-RD-BASE-RATE     PIC S9(1)V9(4) COMP-3.
               10 WS-RD-AGE-MULT      PIC S9(1)V9(4) COMP-3.
               10 WS-RD-GENDER-MULT   PIC S9(1)V9(4) COMP-3.
               10 WS-RD-RISK-MULT     PIC S9(1)V9(4) COMP-3.
               10 WS-RD-PREMIUM       PIC S9(7)V99 COMP-3.
       01 WS-CALC.
           05 WS-TOTAL-RIDER-PREM     PIC S9(7)V99 COMP-3
               VALUE 0.
           05 WS-COMBINED-PREMIUM     PIC S9(7)V99 COMP-3.
           05 WS-RIDER-PCT-OF-BASE    PIC S9(3)V99 COMP-3.
           05 WS-MAX-RIDER-PCT        PIC S9(3)V99 COMP-3
               VALUE 40.00.
           05 WS-RIDER-CAPPED         PIC X VALUE 'N'.
               88 RIDERS-CAPPED       VALUE 'Y'.
           05 WS-CAP-AMOUNT           PIC S9(7)V99 COMP-3.
       01 WS-IDX                      PIC 9(1).
       01 WS-RATE-FACTOR              PIC S9(3)V9(4) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-SETUP-RIDERS
           PERFORM 3000-CALC-RIDER-PREMIUMS
           PERFORM 4000-APPLY-CAP
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'POL-RL-55001' TO WS-POL-NUM
           MOVE 2400.00 TO WS-BASE-PREMIUM
           MOVE 500000.00 TO WS-FACE-AMOUNT
           MOVE 45 TO WS-INSURED-AGE
           MOVE 'M' TO WS-INSURED-GENDER
           MOVE 'ST' TO WS-RISK-CLASS
           MOVE 4 TO WS-RIDER-COUNT.
       2000-SETUP-RIDERS.
           MOVE 'WOP' TO WS-RD-CODE(1)
           MOVE 'Y' TO WS-RD-SELECTED(1)
           MOVE 0.0045 TO WS-RD-BASE-RATE(1)
           MOVE 'ADB' TO WS-RD-CODE(2)
           MOVE 'Y' TO WS-RD-SELECTED(2)
           MOVE 0.0008 TO WS-RD-BASE-RATE(2)
           MOVE 'LTC' TO WS-RD-CODE(3)
           MOVE 'Y' TO WS-RD-SELECTED(3)
           MOVE 0.0120 TO WS-RD-BASE-RATE(3)
           MOVE 'GIO' TO WS-RD-CODE(4)
           MOVE 'Y' TO WS-RD-SELECTED(4)
           MOVE 0.0025 TO WS-RD-BASE-RATE(4).
       3000-CALC-RIDER-PREMIUMS.
           MOVE 0 TO WS-TOTAL-RIDER-PREM
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-RIDER-COUNT
               IF RD-ACTIVE(WS-IDX)
                   PERFORM 3100-CALC-AGE-MULT
                   PERFORM 3200-CALC-GENDER-MULT
                   PERFORM 3300-CALC-RISK-MULT
                   COMPUTE WS-RATE-FACTOR =
                       WS-RD-BASE-RATE(WS-IDX)
                       * WS-RD-AGE-MULT(WS-IDX)
                       * WS-RD-GENDER-MULT(WS-IDX)
                       * WS-RD-RISK-MULT(WS-IDX)
                   COMPUTE WS-RD-PREMIUM(WS-IDX) =
                       WS-FACE-AMOUNT * WS-RATE-FACTOR
                   ADD WS-RD-PREMIUM(WS-IDX)
                       TO WS-TOTAL-RIDER-PREM
               END-IF
           END-PERFORM.
       3100-CALC-AGE-MULT.
           IF WS-INSURED-AGE < 35
               MOVE 0.8000 TO WS-RD-AGE-MULT(WS-IDX)
           ELSE
               IF WS-INSURED-AGE < 45
                   MOVE 1.0000 TO WS-RD-AGE-MULT(WS-IDX)
               ELSE
                   IF WS-INSURED-AGE < 55
                       MOVE 1.3000 TO WS-RD-AGE-MULT(WS-IDX)
                   ELSE
                       MOVE 1.7000 TO WS-RD-AGE-MULT(WS-IDX)
                   END-IF
               END-IF
           END-IF.
       3200-CALC-GENDER-MULT.
           EVALUATE TRUE
               WHEN GENDER-MALE
                   EVALUATE TRUE
                       WHEN RD-LTC(WS-IDX)
                           MOVE 0.9000
                               TO WS-RD-GENDER-MULT(WS-IDX)
                       WHEN OTHER
                           MOVE 1.0000
                               TO WS-RD-GENDER-MULT(WS-IDX)
                   END-EVALUATE
               WHEN GENDER-FEMALE
                   EVALUATE TRUE
                       WHEN RD-LTC(WS-IDX)
                           MOVE 1.1500
                               TO WS-RD-GENDER-MULT(WS-IDX)
                       WHEN OTHER
                           MOVE 0.9500
                               TO WS-RD-GENDER-MULT(WS-IDX)
                   END-EVALUATE
               WHEN OTHER
                   MOVE 1.0000
                       TO WS-RD-GENDER-MULT(WS-IDX)
           END-EVALUATE.
       3300-CALC-RISK-MULT.
           EVALUATE TRUE
               WHEN RC-PREFERRED
                   MOVE 0.8500 TO WS-RD-RISK-MULT(WS-IDX)
               WHEN RC-STANDARD
                   MOVE 1.0000 TO WS-RD-RISK-MULT(WS-IDX)
               WHEN RC-RATED
                   MOVE 1.5000 TO WS-RD-RISK-MULT(WS-IDX)
               WHEN OTHER
                   MOVE 1.0000 TO WS-RD-RISK-MULT(WS-IDX)
           END-EVALUATE.
       4000-APPLY-CAP.
           IF WS-BASE-PREMIUM > 0
               COMPUTE WS-RIDER-PCT-OF-BASE =
                   (WS-TOTAL-RIDER-PREM / WS-BASE-PREMIUM)
                   * 100
           ELSE
               MOVE 0 TO WS-RIDER-PCT-OF-BASE
           END-IF
           IF WS-RIDER-PCT-OF-BASE > WS-MAX-RIDER-PCT
               MOVE 'Y' TO WS-RIDER-CAPPED
               COMPUTE WS-CAP-AMOUNT =
                   WS-BASE-PREMIUM *
                   (WS-MAX-RIDER-PCT / 100)
               MOVE WS-CAP-AMOUNT TO WS-TOTAL-RIDER-PREM
           END-IF
           COMPUTE WS-COMBINED-PREMIUM =
               WS-BASE-PREMIUM + WS-TOTAL-RIDER-PREM.
       5000-DISPLAY-RESULTS.
           DISPLAY 'RIDER PREMIUM CALCULATION'
           DISPLAY '========================='
           DISPLAY 'POLICY:        ' WS-POL-NUM
           DISPLAY 'FACE AMOUNT:   ' WS-FACE-AMOUNT
           DISPLAY 'BASE PREMIUM:  ' WS-BASE-PREMIUM
           DISPLAY '-------------------------'
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-RIDER-COUNT
               IF RD-ACTIVE(WS-IDX)
                   DISPLAY 'RIDER '
                       WS-RD-CODE(WS-IDX)
                       ' PREMIUM: '
                       WS-RD-PREMIUM(WS-IDX)
               END-IF
           END-PERFORM
           DISPLAY '-------------------------'
           DISPLAY 'TOTAL RIDERS:  ' WS-TOTAL-RIDER-PREM
           DISPLAY 'RIDER % BASE:  ' WS-RIDER-PCT-OF-BASE
           IF RIDERS-CAPPED
               DISPLAY 'RIDERS CAPPED: YES'
           END-IF
           DISPLAY 'COMBINED PREM: ' WS-COMBINED-PREMIUM.
