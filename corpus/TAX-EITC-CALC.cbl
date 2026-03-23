       IDENTIFICATION DIVISION.
       PROGRAM-ID. TAX-EITC-CALC.
      *================================================================
      * Earned Income Tax Credit Calculation
      * Determines EITC eligibility and amount based on filing
      * status, qualifying children, and earned income phase-out.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-TAXPAYER.
           05 WS-TIN                   PIC X(9).
           05 WS-FILING-STATUS         PIC X(1).
               88 WS-SINGLE            VALUE 'S'.
               88 WS-MFJ               VALUE 'M'.
               88 WS-HOH               VALUE 'H'.
           05 WS-QUAL-CHILDREN         PIC 9(1).
               88 WS-NO-CHILDREN       VALUE 0.
               88 WS-ONE-CHILD         VALUE 1.
               88 WS-TWO-CHILDREN      VALUE 2.
               88 WS-THREE-PLUS        VALUES 3 THRU 9.
           05 WS-EARNED-INCOME         PIC S9(7)V99 COMP-3.
           05 WS-AGI                   PIC S9(7)V99 COMP-3.
           05 WS-INVEST-INCOME         PIC S9(7)V99 COMP-3.
       01 WS-EITC-PARAMS.
           05 WS-CREDIT-RATE           PIC S9(1)V9(4) COMP-3.
           05 WS-PHASE-IN-END          PIC S9(7)V99 COMP-3.
           05 WS-PHASE-OUT-START       PIC S9(7)V99 COMP-3.
           05 WS-PHASE-OUT-END         PIC S9(7)V99 COMP-3.
           05 WS-PHASE-OUT-RATE        PIC S9(1)V9(4) COMP-3.
           05 WS-MAX-CREDIT            PIC S9(5)V99 COMP-3.
       01 WS-INVEST-LIMIT             PIC S9(5)V99 COMP-3
           VALUE 11600.00.
       01 WS-CALC-FIELDS.
           05 WS-PHASE-IN-AMT          PIC S9(5)V99 COMP-3.
           05 WS-PHASE-OUT-AMT         PIC S9(5)V99 COMP-3.
           05 WS-INCOME-FOR-CALC       PIC S9(7)V99 COMP-3.
           05 WS-EITC-AMOUNT           PIC S9(5)V99 COMP-3.
           05 WS-ELIGIBLE              PIC X(1).
               88 WS-IS-ELIGIBLE       VALUE 'Y'.
               88 WS-NOT-ELIGIBLE      VALUE 'N'.
       01 WS-AGE-FIELDS.
           05 WS-TAXPAYER-AGE          PIC 9(2).
           05 WS-MIN-AGE-NO-CHILD      PIC 9(2) VALUE 25.
           05 WS-MAX-AGE-NO-CHILD      PIC 9(2) VALUE 64.
       01 WS-MULTIPLY-FIELDS.
           05 WS-MULT-RESULT           PIC S9(9)V99 COMP-3.
           05 WS-MULT-REMAINDER        PIC S9(5)V99 COMP-3.
       01 WS-PROCESS-DATE              PIC 9(8).
       01 WS-REPORT-LINE               PIC X(80).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CHECK-ELIGIBILITY
           PERFORM 3000-SET-PARAMETERS
           PERFORM 4000-CALC-PHASE-IN
           PERFORM 5000-CALC-PHASE-OUT
           PERFORM 6000-DETERMINE-CREDIT
           PERFORM 7000-DISPLAY-RESULT
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-PROCESS-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-EITC-AMOUNT
           SET WS-IS-ELIGIBLE TO TRUE.
       2000-CHECK-ELIGIBILITY.
           IF WS-INVEST-INCOME > WS-INVEST-LIMIT
               SET WS-NOT-ELIGIBLE TO TRUE
           END-IF
           IF WS-NO-CHILDREN
               IF WS-TAXPAYER-AGE < WS-MIN-AGE-NO-CHILD
               OR WS-TAXPAYER-AGE > WS-MAX-AGE-NO-CHILD
                   SET WS-NOT-ELIGIBLE TO TRUE
               END-IF
           END-IF.
       3000-SET-PARAMETERS.
           IF WS-NOT-ELIGIBLE
               MOVE 0 TO WS-MAX-CREDIT
           ELSE
               EVALUATE TRUE
                   WHEN WS-NO-CHILDREN
                       MOVE 0.0765 TO WS-CREDIT-RATE
                       MOVE 7840.00 TO WS-PHASE-IN-END
                       MOVE 0.0765 TO WS-PHASE-OUT-RATE
                       MOVE 600.00 TO WS-MAX-CREDIT
                       IF WS-MFJ
                           MOVE 17250 TO WS-PHASE-OUT-START
                           MOVE 25010 TO WS-PHASE-OUT-END
                       ELSE
                           MOVE 10330 TO WS-PHASE-OUT-START
                           MOVE 18090 TO WS-PHASE-OUT-END
                       END-IF
                   WHEN WS-ONE-CHILD
                       MOVE 0.3400 TO WS-CREDIT-RATE
                       MOVE 11750 TO WS-PHASE-IN-END
                       MOVE 0.1598 TO WS-PHASE-OUT-RATE
                       MOVE 3995.00 TO WS-MAX-CREDIT
                       IF WS-MFJ
                           MOVE 27380 TO WS-PHASE-OUT-START
                           MOVE 52370 TO WS-PHASE-OUT-END
                       ELSE
                           MOVE 21370 TO WS-PHASE-OUT-START
                           MOVE 46370 TO WS-PHASE-OUT-END
                       END-IF
                   WHEN WS-TWO-CHILDREN
                       MOVE 0.4000 TO WS-CREDIT-RATE
                       MOVE 16510 TO WS-PHASE-IN-END
                       MOVE 0.2106 TO WS-PHASE-OUT-RATE
                       MOVE 6604.00 TO WS-MAX-CREDIT
                       IF WS-MFJ
                           MOVE 27380 TO WS-PHASE-OUT-START
                           MOVE 58730 TO WS-PHASE-OUT-END
                       ELSE
                           MOVE 21370 TO WS-PHASE-OUT-START
                           MOVE 52730 TO WS-PHASE-OUT-END
                       END-IF
                   WHEN WS-THREE-PLUS
                       MOVE 0.4500 TO WS-CREDIT-RATE
                       MOVE 16510 TO WS-PHASE-IN-END
                       MOVE 0.2106 TO WS-PHASE-OUT-RATE
                       MOVE 7430.00 TO WS-MAX-CREDIT
                       IF WS-MFJ
                           MOVE 27380 TO WS-PHASE-OUT-START
                           MOVE 62650 TO WS-PHASE-OUT-END
                       ELSE
                           MOVE 21370 TO WS-PHASE-OUT-START
                           MOVE 56650 TO WS-PHASE-OUT-END
                       END-IF
               END-EVALUATE
           END-IF.
       4000-CALC-PHASE-IN.
           IF WS-NOT-ELIGIBLE
               MOVE 0 TO WS-PHASE-IN-AMT
           ELSE
               IF WS-EARNED-INCOME > WS-AGI
                   MOVE WS-AGI TO WS-INCOME-FOR-CALC
               ELSE
                   MOVE WS-EARNED-INCOME
                       TO WS-INCOME-FOR-CALC
               END-IF
               MULTIPLY WS-INCOME-FOR-CALC
                   BY WS-CREDIT-RATE
                   GIVING WS-PHASE-IN-AMT
               IF WS-PHASE-IN-AMT > WS-MAX-CREDIT
                   MOVE WS-MAX-CREDIT TO WS-PHASE-IN-AMT
               END-IF
           END-IF.
       5000-CALC-PHASE-OUT.
           MOVE 0 TO WS-PHASE-OUT-AMT
           IF WS-IS-ELIGIBLE
               IF WS-AGI > WS-PHASE-OUT-START
                   COMPUTE WS-PHASE-OUT-AMT =
                       (WS-AGI - WS-PHASE-OUT-START) *
                       WS-PHASE-OUT-RATE
                   IF WS-PHASE-OUT-AMT > WS-MAX-CREDIT
                       MOVE WS-MAX-CREDIT
                           TO WS-PHASE-OUT-AMT
                   END-IF
               END-IF
           END-IF.
       6000-DETERMINE-CREDIT.
           IF WS-IS-ELIGIBLE
               COMPUTE WS-EITC-AMOUNT =
                   WS-PHASE-IN-AMT - WS-PHASE-OUT-AMT
               IF WS-EITC-AMOUNT < 0
                   MOVE 0 TO WS-EITC-AMOUNT
                   SET WS-NOT-ELIGIBLE TO TRUE
               END-IF
           ELSE
               MOVE 0 TO WS-EITC-AMOUNT
           END-IF.
       7000-DISPLAY-RESULT.
           DISPLAY "EITC CALCULATION RESULT"
           DISPLAY "DATE: " WS-PROCESS-DATE
           DISPLAY "TIN: " WS-TIN
           DISPLAY "FILING: " WS-FILING-STATUS
           DISPLAY "CHILDREN: " WS-QUAL-CHILDREN
           DISPLAY "EARNED INCOME: " WS-EARNED-INCOME
           DISPLAY "AGI: " WS-AGI
           IF WS-IS-ELIGIBLE
               DISPLAY "ELIGIBLE: YES"
               DISPLAY "EITC AMOUNT: " WS-EITC-AMOUNT
           ELSE
               DISPLAY "ELIGIBLE: NO"
               DISPLAY "EITC AMOUNT: $0.00"
           END-IF.
