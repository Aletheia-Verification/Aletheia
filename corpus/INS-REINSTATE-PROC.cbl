       IDENTIFICATION DIVISION.
       PROGRAM-ID. INS-REINSTATE-PROC.
      *================================================================
      * POLICY REINSTATEMENT PROCESSOR
      * Evaluates lapsed policies for reinstatement eligibility,
      * calculates back premiums and reinstatement fees.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-LAPSED-POLICY.
           05 WS-POL-NUM              PIC X(12).
           05 WS-POL-TYPE             PIC X(2).
               88 PT-TERM             VALUE 'TL'.
               88 PT-WHOLE            VALUE 'WL'.
               88 PT-UNIVERSAL        VALUE 'UL'.
           05 WS-LAPSE-DATE           PIC 9(8).
           05 WS-ORIGINAL-PREM        PIC S9(7)V99 COMP-3.
           05 WS-PAY-FREQUENCY        PIC X(1).
               88 FREQ-MONTHLY        VALUE 'M'.
               88 FREQ-QUARTERLY      VALUE 'Q'.
               88 FREQ-SEMI           VALUE 'S'.
               88 FREQ-ANNUAL         VALUE 'A'.
           05 WS-FACE-AMT             PIC S9(9)V99 COMP-3.
           05 WS-INSURED-AGE          PIC 9(3).
           05 WS-HEALTH-STATUS        PIC X(1).
               88 HS-GOOD             VALUE 'G'.
               88 HS-FAIR             VALUE 'F'.
               88 HS-POOR             VALUE 'P'.
               88 HS-UNKNOWN          VALUE 'U'.
       01 WS-REINSTATE-RULES.
           05 WS-MAX-LAPSE-DAYS-TL    PIC 9(4) VALUE 365.
           05 WS-MAX-LAPSE-DAYS-WL    PIC 9(4) VALUE 1095.
           05 WS-MAX-LAPSE-DAYS-UL    PIC 9(4) VALUE 730.
           05 WS-REINSTATE-FEE-RATE   PIC S9(1)V99 COMP-3
               VALUE 0.05.
           05 WS-INTEREST-RATE        PIC S9(1)V9(4) COMP-3
               VALUE 0.0600.
           05 WS-MAX-AGE              PIC 9(3) VALUE 70.
       01 WS-CALC.
           05 WS-DAYS-LAPSED          PIC S9(5) COMP-3.
           05 WS-MAX-ALLOWED-DAYS     PIC 9(4).
           05 WS-ELIGIBLE             PIC X VALUE 'N'.
               88 IS-ELIGIBLE         VALUE 'Y'.
           05 WS-DENIAL-REASON        PIC X(25).
           05 WS-PERIODS-OWED         PIC 9(3).
           05 WS-PERIOD-PREMIUM       PIC S9(7)V99 COMP-3.
           05 WS-BACK-PREMIUMS        PIC S9(9)V99 COMP-3.
           05 WS-INTEREST-AMT         PIC S9(7)V99 COMP-3.
           05 WS-REINSTATE-FEE        PIC S9(7)V99 COMP-3.
           05 WS-TOTAL-DUE            PIC S9(9)V99 COMP-3.
           05 WS-EVIDENCE-REQUIRED    PIC X VALUE 'N'.
               88 NEEDS-EVIDENCE      VALUE 'Y'.
       01 WS-CURRENT-DATE             PIC 9(8).
       01 WS-MONTHS-LAPSED            PIC 9(3).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CHECK-ELIGIBILITY
           IF IS-ELIGIBLE
               PERFORM 3000-CALC-BACK-PREMIUMS
               PERFORM 4000-CALC-INTEREST
               PERFORM 5000-CALC-FEES
               PERFORM 6000-CHECK-EVIDENCE-REQ
               PERFORM 7000-CALC-TOTAL
           END-IF
           PERFORM 8000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           MOVE 'POL-RI-44001' TO WS-POL-NUM
           MOVE 'WL' TO WS-POL-TYPE
           MOVE 20250901 TO WS-LAPSE-DATE
           MOVE 285.00 TO WS-ORIGINAL-PREM
           MOVE 'M' TO WS-PAY-FREQUENCY
           MOVE 250000.00 TO WS-FACE-AMT
           MOVE 52 TO WS-INSURED-AGE
           MOVE 'G' TO WS-HEALTH-STATUS.
       2000-CHECK-ELIGIBILITY.
           COMPUTE WS-DAYS-LAPSED =
               WS-CURRENT-DATE - WS-LAPSE-DATE
           EVALUATE TRUE
               WHEN PT-TERM
                   MOVE WS-MAX-LAPSE-DAYS-TL
                       TO WS-MAX-ALLOWED-DAYS
               WHEN PT-WHOLE
                   MOVE WS-MAX-LAPSE-DAYS-WL
                       TO WS-MAX-ALLOWED-DAYS
               WHEN PT-UNIVERSAL
                   MOVE WS-MAX-LAPSE-DAYS-UL
                       TO WS-MAX-ALLOWED-DAYS
               WHEN OTHER
                   MOVE 365 TO WS-MAX-ALLOWED-DAYS
           END-EVALUATE
           MOVE 'Y' TO WS-ELIGIBLE
           IF WS-DAYS-LAPSED > WS-MAX-ALLOWED-DAYS
               MOVE 'N' TO WS-ELIGIBLE
               MOVE 'EXCEEDS MAX LAPSE PERIOD  '
                   TO WS-DENIAL-REASON
           END-IF
           IF WS-INSURED-AGE > WS-MAX-AGE
               MOVE 'N' TO WS-ELIGIBLE
               MOVE 'EXCEEDS MAX AGE           '
                   TO WS-DENIAL-REASON
           END-IF
           IF HS-POOR
               MOVE 'N' TO WS-ELIGIBLE
               MOVE 'POOR HEALTH STATUS        '
                   TO WS-DENIAL-REASON
           END-IF.
       3000-CALC-BACK-PREMIUMS.
           EVALUATE TRUE
               WHEN FREQ-MONTHLY
                   MOVE WS-ORIGINAL-PREM
                       TO WS-PERIOD-PREMIUM
               WHEN FREQ-QUARTERLY
                   COMPUTE WS-PERIOD-PREMIUM =
                       WS-ORIGINAL-PREM * 3
               WHEN FREQ-SEMI
                   COMPUTE WS-PERIOD-PREMIUM =
                       WS-ORIGINAL-PREM * 6
               WHEN FREQ-ANNUAL
                   COMPUTE WS-PERIOD-PREMIUM =
                       WS-ORIGINAL-PREM * 12
               WHEN OTHER
                   MOVE WS-ORIGINAL-PREM
                       TO WS-PERIOD-PREMIUM
           END-EVALUATE
           COMPUTE WS-MONTHS-LAPSED =
               WS-DAYS-LAPSED / 30
           IF WS-MONTHS-LAPSED < 1
               MOVE 1 TO WS-MONTHS-LAPSED
           END-IF
           EVALUATE TRUE
               WHEN FREQ-MONTHLY
                   MOVE WS-MONTHS-LAPSED TO WS-PERIODS-OWED
               WHEN FREQ-QUARTERLY
                   COMPUTE WS-PERIODS-OWED =
                       (WS-MONTHS-LAPSED / 3) + 1
               WHEN FREQ-SEMI
                   COMPUTE WS-PERIODS-OWED =
                       (WS-MONTHS-LAPSED / 6) + 1
               WHEN FREQ-ANNUAL
                   COMPUTE WS-PERIODS-OWED =
                       (WS-MONTHS-LAPSED / 12) + 1
               WHEN OTHER
                   MOVE WS-MONTHS-LAPSED TO WS-PERIODS-OWED
           END-EVALUATE
           COMPUTE WS-BACK-PREMIUMS =
               WS-PERIOD-PREMIUM * WS-PERIODS-OWED.
       4000-CALC-INTEREST.
           COMPUTE WS-INTEREST-AMT =
               WS-BACK-PREMIUMS
               * WS-INTEREST-RATE
               * (WS-MONTHS-LAPSED / 12).
       5000-CALC-FEES.
           COMPUTE WS-REINSTATE-FEE =
               WS-BACK-PREMIUMS * WS-REINSTATE-FEE-RATE.
       6000-CHECK-EVIDENCE-REQ.
           IF WS-DAYS-LAPSED > 180
               MOVE 'Y' TO WS-EVIDENCE-REQUIRED
           END-IF
           IF WS-INSURED-AGE > 55
               MOVE 'Y' TO WS-EVIDENCE-REQUIRED
           END-IF
           IF WS-FACE-AMT > 500000.00
               MOVE 'Y' TO WS-EVIDENCE-REQUIRED
           END-IF.
       7000-CALC-TOTAL.
           COMPUTE WS-TOTAL-DUE =
               WS-BACK-PREMIUMS
               + WS-INTEREST-AMT
               + WS-REINSTATE-FEE.
       8000-DISPLAY-RESULTS.
           DISPLAY 'POLICY REINSTATEMENT EVALUATION'
           DISPLAY '==============================='
           DISPLAY 'POLICY:          ' WS-POL-NUM
           DISPLAY 'TYPE:            ' WS-POL-TYPE
           DISPLAY 'LAPSE DATE:      ' WS-LAPSE-DATE
           DISPLAY 'DAYS LAPSED:     ' WS-DAYS-LAPSED
           IF IS-ELIGIBLE
               DISPLAY 'ELIGIBLE:        YES'
               DISPLAY 'BACK PREMIUMS:   ' WS-BACK-PREMIUMS
               DISPLAY 'INTEREST:        ' WS-INTEREST-AMT
               DISPLAY 'REINSTATE FEE:   ' WS-REINSTATE-FEE
               DISPLAY 'TOTAL DUE:       ' WS-TOTAL-DUE
               IF NEEDS-EVIDENCE
                   DISPLAY 'EVIDENCE OF INSURABILITY REQUIRED'
               END-IF
           ELSE
               DISPLAY 'ELIGIBLE:        NO'
               DISPLAY 'REASON:          ' WS-DENIAL-REASON
           END-IF.
