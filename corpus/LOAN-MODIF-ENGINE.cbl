       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOAN-MODIF-ENGINE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-LOAN-DATA.
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-CURRENT-BAL         PIC S9(9)V99 COMP-3.
           05 WS-CURRENT-RATE        PIC S9(3)V9(6) COMP-3.
           05 WS-CURRENT-TERM        PIC 9(3).
           05 WS-CURRENT-PMT         PIC S9(7)V99 COMP-3.
           05 WS-MONTHLY-INCOME      PIC S9(7)V99 COMP-3.
           05 WS-ARREARS-AMT         PIC S9(7)V99 COMP-3.
       01 WS-TARGET-DTI              PIC S9(1)V9(4) COMP-3
           VALUE 0.3100.
       01 WS-TARGET-PMT              PIC S9(7)V99 COMP-3.
       01 WS-MOD-TYPE                PIC X(1).
           88 WS-RATE-REDUCE         VALUE 'R'.
           88 WS-TERM-EXTEND         VALUE 'T'.
           88 WS-PRINCIPAL-REDUCE    VALUE 'P'.
           88 WS-COMBINATION         VALUE 'C'.
       01 WS-SCENARIO-TABLE.
           05 WS-SCENARIO OCCURS 5.
               10 WS-SC-LABEL        PIC X(15).
               10 WS-SC-RATE         PIC S9(3)V9(6) COMP-3.
               10 WS-SC-TERM         PIC 9(3).
               10 WS-SC-BAL          PIC S9(9)V99 COMP-3.
               10 WS-SC-PMT          PIC S9(7)V99 COMP-3.
               10 WS-SC-DTI          PIC S9(1)V9(4) COMP-3.
               10 WS-SC-VIABLE       PIC X VALUE 'N'.
                   88 WS-SC-IS-VIABLE VALUE 'Y'.
               10 WS-SC-SAVINGS      PIC S9(7)V99 COMP-3.
       01 WS-SC-IDX                  PIC 9(1).
       01 WS-BEST-IDX                PIC 9(1).
       01 WS-BEST-PMT                PIC S9(7)V99 COMP-3.
       01 WS-MONTHLY-RATE            PIC S9(1)V9(8) COMP-3.
       01 WS-CALC-PMT                PIC S9(7)V99 COMP-3.
       01 WS-NPV-ORIG                PIC S9(11)V99 COMP-3.
       01 WS-NPV-MOD                 PIC S9(11)V99 COMP-3.
       01 WS-APPROVAL-FLAG           PIC X VALUE 'N'.
           88 WS-APPROVED            VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-TARGET-PMT
           PERFORM 3000-GENERATE-SCENARIOS
           PERFORM 4000-EVALUATE-SCENARIOS
           PERFORM 5000-SELECT-BEST
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 999999.99 TO WS-BEST-PMT
           MOVE 0 TO WS-BEST-IDX
           MOVE 'N' TO WS-APPROVAL-FLAG.
       2000-CALC-TARGET-PMT.
           COMPUTE WS-TARGET-PMT =
               WS-MONTHLY-INCOME * WS-TARGET-DTI.
       3000-GENERATE-SCENARIOS.
           MOVE 'RATE REDUCE' TO WS-SC-LABEL(1)
           COMPUTE WS-SC-RATE(1) =
               WS-CURRENT-RATE - 0.0200
           IF WS-SC-RATE(1) < 0.0200
               MOVE 0.0200 TO WS-SC-RATE(1)
           END-IF
           MOVE WS-CURRENT-TERM TO WS-SC-TERM(1)
           MOVE WS-CURRENT-BAL TO WS-SC-BAL(1)
           MOVE 'TERM EXTEND' TO WS-SC-LABEL(2)
           MOVE WS-CURRENT-RATE TO WS-SC-RATE(2)
           COMPUTE WS-SC-TERM(2) =
               WS-CURRENT-TERM + 120
           IF WS-SC-TERM(2) > 480
               MOVE 480 TO WS-SC-TERM(2)
           END-IF
           MOVE WS-CURRENT-BAL TO WS-SC-BAL(2)
           MOVE 'PRIN REDUCE' TO WS-SC-LABEL(3)
           MOVE WS-CURRENT-RATE TO WS-SC-RATE(3)
           MOVE WS-CURRENT-TERM TO WS-SC-TERM(3)
           COMPUTE WS-SC-BAL(3) =
               WS-CURRENT-BAL * 0.90
           MOVE 'RATE+TERM' TO WS-SC-LABEL(4)
           COMPUTE WS-SC-RATE(4) =
               WS-CURRENT-RATE - 0.0100
           COMPUTE WS-SC-TERM(4) =
               WS-CURRENT-TERM + 60
           MOVE WS-CURRENT-BAL TO WS-SC-BAL(4)
           MOVE 'FULL COMBO' TO WS-SC-LABEL(5)
           COMPUTE WS-SC-RATE(5) =
               WS-CURRENT-RATE - 0.0150
           COMPUTE WS-SC-TERM(5) =
               WS-CURRENT-TERM + 60
           COMPUTE WS-SC-BAL(5) =
               WS-CURRENT-BAL * 0.95.
       4000-EVALUATE-SCENARIOS.
           PERFORM VARYING WS-SC-IDX FROM 1 BY 1
               UNTIL WS-SC-IDX > 5
               COMPUTE WS-MONTHLY-RATE =
                   WS-SC-RATE(WS-SC-IDX) / 12
               IF WS-MONTHLY-RATE > 0
                   COMPUTE WS-SC-PMT(WS-SC-IDX) =
                       WS-SC-BAL(WS-SC-IDX) *
                       WS-MONTHLY-RATE /
                       (1 - (1 + WS-MONTHLY-RATE) **
                       (0 - WS-SC-TERM(WS-SC-IDX)))
               ELSE
                   COMPUTE WS-SC-PMT(WS-SC-IDX) =
                       WS-SC-BAL(WS-SC-IDX) /
                       WS-SC-TERM(WS-SC-IDX)
               END-IF
               COMPUTE WS-SC-DTI(WS-SC-IDX) =
                   WS-SC-PMT(WS-SC-IDX) /
                   WS-MONTHLY-INCOME
               IF WS-SC-DTI(WS-SC-IDX) <= WS-TARGET-DTI
                   MOVE 'Y' TO WS-SC-VIABLE(WS-SC-IDX)
               END-IF
               COMPUTE WS-SC-SAVINGS(WS-SC-IDX) =
                   WS-CURRENT-PMT - WS-SC-PMT(WS-SC-IDX)
           END-PERFORM.
       5000-SELECT-BEST.
           PERFORM VARYING WS-SC-IDX FROM 1 BY 1
               UNTIL WS-SC-IDX > 5
               IF WS-SC-VIABLE(WS-SC-IDX) = 'Y'
                   IF WS-SC-PMT(WS-SC-IDX) < WS-BEST-PMT
                       MOVE WS-SC-PMT(WS-SC-IDX) TO
                           WS-BEST-PMT
                       MOVE WS-SC-IDX TO WS-BEST-IDX
                   END-IF
               END-IF
           END-PERFORM
           IF WS-BEST-IDX > 0
               MOVE 'Y' TO WS-APPROVAL-FLAG
           END-IF.
       6000-DISPLAY-RESULTS.
           DISPLAY 'LOAN MODIFICATION ANALYSIS'
           DISPLAY '=========================='
           DISPLAY 'ACCOUNT:         ' WS-ACCT-NUM
           DISPLAY 'CURRENT BAL:     ' WS-CURRENT-BAL
           DISPLAY 'CURRENT RATE:    ' WS-CURRENT-RATE
           DISPLAY 'CURRENT PMT:     ' WS-CURRENT-PMT
           DISPLAY 'MONTHLY INCOME:  ' WS-MONTHLY-INCOME
           DISPLAY 'TARGET DTI:      ' WS-TARGET-DTI
           DISPLAY 'TARGET PMT:      ' WS-TARGET-PMT
           DISPLAY ' '
           DISPLAY 'SCENARIOS:'
           PERFORM VARYING WS-SC-IDX FROM 1 BY 1
               UNTIL WS-SC-IDX > 5
               DISPLAY '  ' WS-SC-LABEL(WS-SC-IDX)
                   ' PMT=' WS-SC-PMT(WS-SC-IDX)
                   ' DTI=' WS-SC-DTI(WS-SC-IDX)
                   ' VIABLE=' WS-SC-VIABLE(WS-SC-IDX)
           END-PERFORM
           IF WS-APPROVED
               DISPLAY 'RECOMMENDED: '
                   WS-SC-LABEL(WS-BEST-IDX)
               DISPLAY 'NEW PMT:     ' WS-BEST-PMT
           ELSE
               DISPLAY 'NO VIABLE MODIFICATION FOUND'
           END-IF.
