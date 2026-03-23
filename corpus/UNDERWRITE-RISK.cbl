       IDENTIFICATION DIVISION.
       PROGRAM-ID. UNDERWRITE-RISK.
      *================================================================
      * UNDERWRITING RISK SCORING ENGINE
      * Scores applicants across medical, financial, and lifestyle
      * dimensions to produce a composite risk tier.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-APPLICANT.
           05 WS-APP-ID               PIC X(10).
           05 WS-APP-AGE              PIC 9(3).
           05 WS-APP-GENDER           PIC X(1).
               88 APP-MALE            VALUE 'M'.
               88 APP-FEMALE          VALUE 'F'.
           05 WS-APP-SMOKER           PIC X(1).
               88 APP-SMOKER-YES      VALUE 'Y'.
               88 APP-SMOKER-NO       VALUE 'N'.
           05 WS-APP-BMI              PIC 9(2)V9(1).
           05 WS-APP-INCOME           PIC S9(9)V99 COMP-3.
           05 WS-APP-DEBT-RATIO       PIC S9(1)V99 COMP-3.
           05 WS-APP-CREDIT-SCORE     PIC 9(3).
           05 WS-APP-OCCUPATION       PIC X(3).
               88 OCC-OFFICE          VALUE 'OFF'.
               88 OCC-MANUAL          VALUE 'MAN'.
               88 OCC-HAZARD          VALUE 'HAZ'.
           05 WS-APP-COVERAGE-REQ     PIC S9(9)V99 COMP-3.
       01 WS-RISK-SCORES.
           05 WS-MED-SCORE            PIC S9(3)V99 COMP-3.
           05 WS-FIN-SCORE            PIC S9(3)V99 COMP-3.
           05 WS-LIFE-SCORE           PIC S9(3)V99 COMP-3.
           05 WS-OCC-SCORE            PIC S9(3)V99 COMP-3.
           05 WS-COMPOSITE-SCORE      PIC S9(3)V99 COMP-3.
       01 WS-WEIGHTS.
           05 WS-MED-WEIGHT           PIC S9(1)V99 COMP-3
               VALUE 0.35.
           05 WS-FIN-WEIGHT           PIC S9(1)V99 COMP-3
               VALUE 0.25.
           05 WS-LIFE-WEIGHT          PIC S9(1)V99 COMP-3
               VALUE 0.25.
           05 WS-OCC-WEIGHT           PIC S9(1)V99 COMP-3
               VALUE 0.15.
       01 WS-RISK-TIER                PIC X(2).
           88 TIER-PREFERRED           VALUE 'PP'.
           88 TIER-STANDARD            VALUE 'ST'.
           88 TIER-SUBSTANDARD         VALUE 'SS'.
           88 TIER-DECLINED            VALUE 'DC'.
       01 WS-DECISION                 PIC X(8).
       01 WS-PREMIUM-FACTOR           PIC S9(1)V9(4) COMP-3.
       01 WS-BASE-RATE                PIC S9(5)V99 COMP-3.
       01 WS-QUOTED-PREMIUM           PIC S9(7)V99 COMP-3.
       01 WS-AGE-BRACKETS.
           05 WS-AGE-RATE OCCURS 5 TIMES
                                       PIC S9(3)V99 COMP-3.
       01 WS-IDX                       PIC 9(1).
       01 WS-AGE-BRACKET              PIC 9(1).
       01 WS-COVERAGE-MULTIPLE        PIC S9(3)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-SCORE-MEDICAL
           PERFORM 3000-SCORE-FINANCIAL
           PERFORM 4000-SCORE-LIFESTYLE
           PERFORM 5000-SCORE-OCCUPATION
           PERFORM 6000-CALC-COMPOSITE
           PERFORM 7000-DETERMINE-TIER
           PERFORM 8000-CALC-PREMIUM
           PERFORM 9000-DISPLAY-RESULT
           STOP RUN.
       1000-INITIALIZE.
           INITIALIZE WS-RISK-SCORES
           MOVE 10.00 TO WS-AGE-RATE(1)
           MOVE 15.50 TO WS-AGE-RATE(2)
           MOVE 25.00 TO WS-AGE-RATE(3)
           MOVE 45.00 TO WS-AGE-RATE(4)
           MOVE 80.00 TO WS-AGE-RATE(5).
       2000-SCORE-MEDICAL.
           IF WS-APP-AGE < 30
               MOVE 1 TO WS-AGE-BRACKET
               MOVE 90.00 TO WS-MED-SCORE
           ELSE
               IF WS-APP-AGE < 40
                   MOVE 2 TO WS-AGE-BRACKET
                   MOVE 80.00 TO WS-MED-SCORE
               ELSE
                   IF WS-APP-AGE < 50
                       MOVE 3 TO WS-AGE-BRACKET
                       MOVE 65.00 TO WS-MED-SCORE
                   ELSE
                       IF WS-APP-AGE < 60
                           MOVE 4 TO WS-AGE-BRACKET
                           MOVE 50.00 TO WS-MED-SCORE
                       ELSE
                           MOVE 5 TO WS-AGE-BRACKET
                           MOVE 30.00 TO WS-MED-SCORE
                       END-IF
                   END-IF
               END-IF
           END-IF
           IF WS-APP-BMI > 30.0
               SUBTRACT 15.00 FROM WS-MED-SCORE
           ELSE
               IF WS-APP-BMI > 25.0
                   SUBTRACT 5.00 FROM WS-MED-SCORE
               END-IF
           END-IF
           IF APP-SMOKER-YES
               SUBTRACT 20.00 FROM WS-MED-SCORE
           END-IF
           IF WS-MED-SCORE < 0
               MOVE 0 TO WS-MED-SCORE
           END-IF.
       3000-SCORE-FINANCIAL.
           IF WS-APP-CREDIT-SCORE >= 750
               MOVE 95.00 TO WS-FIN-SCORE
           ELSE
               IF WS-APP-CREDIT-SCORE >= 700
                   MOVE 80.00 TO WS-FIN-SCORE
               ELSE
                   IF WS-APP-CREDIT-SCORE >= 650
                       MOVE 60.00 TO WS-FIN-SCORE
                   ELSE
                       MOVE 30.00 TO WS-FIN-SCORE
                   END-IF
               END-IF
           END-IF
           IF WS-APP-DEBT-RATIO > 0.40
               SUBTRACT 20.00 FROM WS-FIN-SCORE
           ELSE
               IF WS-APP-DEBT-RATIO > 0.30
                   SUBTRACT 10.00 FROM WS-FIN-SCORE
               END-IF
           END-IF
           COMPUTE WS-COVERAGE-MULTIPLE =
               WS-APP-COVERAGE-REQ / WS-APP-INCOME
           IF WS-COVERAGE-MULTIPLE > 15.00
               SUBTRACT 15.00 FROM WS-FIN-SCORE
           END-IF
           IF WS-FIN-SCORE < 0
               MOVE 0 TO WS-FIN-SCORE
           END-IF.
       4000-SCORE-LIFESTYLE.
           MOVE 70.00 TO WS-LIFE-SCORE
           IF APP-SMOKER-YES
               SUBTRACT 25.00 FROM WS-LIFE-SCORE
           END-IF
           IF WS-APP-AGE > 55 AND APP-SMOKER-YES
               SUBTRACT 10.00 FROM WS-LIFE-SCORE
           END-IF
           IF WS-LIFE-SCORE < 0
               MOVE 0 TO WS-LIFE-SCORE
           END-IF.
       5000-SCORE-OCCUPATION.
           EVALUATE TRUE
               WHEN OCC-OFFICE
                   MOVE 90.00 TO WS-OCC-SCORE
               WHEN OCC-MANUAL
                   MOVE 65.00 TO WS-OCC-SCORE
               WHEN OCC-HAZARD
                   MOVE 30.00 TO WS-OCC-SCORE
               WHEN OTHER
                   MOVE 50.00 TO WS-OCC-SCORE
           END-EVALUATE.
       6000-CALC-COMPOSITE.
           COMPUTE WS-COMPOSITE-SCORE =
               (WS-MED-SCORE * WS-MED-WEIGHT) +
               (WS-FIN-SCORE * WS-FIN-WEIGHT) +
               (WS-LIFE-SCORE * WS-LIFE-WEIGHT) +
               (WS-OCC-SCORE * WS-OCC-WEIGHT).
       7000-DETERMINE-TIER.
           IF WS-COMPOSITE-SCORE >= 80.00
               SET TIER-PREFERRED TO TRUE
               MOVE 'APPROVED' TO WS-DECISION
               MOVE 0.8500 TO WS-PREMIUM-FACTOR
           ELSE
               IF WS-COMPOSITE-SCORE >= 60.00
                   SET TIER-STANDARD TO TRUE
                   MOVE 'APPROVED' TO WS-DECISION
                   MOVE 1.0000 TO WS-PREMIUM-FACTOR
               ELSE
                   IF WS-COMPOSITE-SCORE >= 40.00
                       SET TIER-SUBSTANDARD TO TRUE
                       MOVE 'APPROVED' TO WS-DECISION
                       MOVE 1.5000 TO WS-PREMIUM-FACTOR
                   ELSE
                       SET TIER-DECLINED TO TRUE
                       MOVE 'DECLINED' TO WS-DECISION
                       MOVE 0 TO WS-PREMIUM-FACTOR
                   END-IF
               END-IF
           END-IF.
       8000-CALC-PREMIUM.
           IF NOT TIER-DECLINED
               MOVE WS-AGE-RATE(WS-AGE-BRACKET)
                   TO WS-BASE-RATE
               COMPUTE WS-QUOTED-PREMIUM =
                   (WS-APP-COVERAGE-REQ / 1000)
                   * WS-BASE-RATE
                   * WS-PREMIUM-FACTOR
           ELSE
               MOVE 0 TO WS-QUOTED-PREMIUM
           END-IF.
       9000-DISPLAY-RESULT.
           DISPLAY 'UNDERWRITING RISK ASSESSMENT'
           DISPLAY '============================'
           DISPLAY 'APPLICANT:    ' WS-APP-ID
           DISPLAY 'AGE:          ' WS-APP-AGE
           DISPLAY 'MEDICAL:      ' WS-MED-SCORE
           DISPLAY 'FINANCIAL:    ' WS-FIN-SCORE
           DISPLAY 'LIFESTYLE:    ' WS-LIFE-SCORE
           DISPLAY 'OCCUPATION:   ' WS-OCC-SCORE
           DISPLAY 'COMPOSITE:    ' WS-COMPOSITE-SCORE
           DISPLAY 'RISK TIER:    ' WS-RISK-TIER
           DISPLAY 'DECISION:     ' WS-DECISION
           DISPLAY 'QUOTED PREM:  ' WS-QUOTED-PREMIUM.
