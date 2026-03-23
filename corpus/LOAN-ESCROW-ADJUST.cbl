       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOAN-ESCROW-ADJUST.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ESCROW-INFO.
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-ESCROW-BAL          PIC S9(7)V99 COMP-3.
           05 WS-TARGET-BAL          PIC S9(7)V99 COMP-3.
           05 WS-MONTHLY-PMT         PIC S9(7)V99 COMP-3.
           05 WS-NEW-MONTHLY         PIC S9(7)V99 COMP-3.
           05 WS-CUSHION             PIC S9(7)V99 COMP-3.
       01 WS-DISBURSEMENTS.
           05 WS-ANNUAL-TAX          PIC S9(7)V99 COMP-3.
           05 WS-ANNUAL-INS          PIC S9(7)V99 COMP-3.
           05 WS-ANNUAL-PMI          PIC S9(7)V99 COMP-3.
           05 WS-ANNUAL-FLOOD        PIC S9(7)V99 COMP-3.
           05 WS-TOTAL-ANNUAL        PIC S9(7)V99 COMP-3.
       01 WS-ANALYSIS.
           05 WS-PROJECTED-BAL       PIC S9(7)V99 COMP-3.
           05 WS-LOW-POINT           PIC S9(7)V99 COMP-3.
           05 WS-LOW-MONTH           PIC 9(2).
           05 WS-SURPLUS             PIC S9(7)V99 COMP-3.
           05 WS-SHORTAGE            PIC S9(7)V99 COMP-3.
           05 WS-ADJUSTMENT          PIC S9(7)V99 COMP-3.
       01 WS-RESULT-TYPE             PIC X(1).
           88 WS-SURPLUS-FOUND       VALUE 'S'.
           88 WS-SHORTAGE-FOUND      VALUE 'H'.
           88 WS-BALANCED            VALUE 'B'.
       01 WS-REFUND-FLAG             PIC X VALUE 'N'.
           88 WS-REFUND-DUE          VALUE 'Y'.
       01 WS-MONTH-IDX               PIC 9(2).
       01 WS-MONTH-DISB              PIC S9(7)V99 COMP-3.
       01 WS-CUSHION-MONTHS          PIC 9(1) VALUE 2.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-ANNUAL-DISB
           PERFORM 3000-PROJECT-BALANCE
           PERFORM 4000-ANALYZE-RESULT
           PERFORM 5000-CALC-ADJUSTMENT
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           INITIALIZE WS-ANALYSIS
           MOVE 999999.99 TO WS-LOW-POINT
           MOVE 0 TO WS-SURPLUS
           MOVE 0 TO WS-SHORTAGE
           MOVE 'B' TO WS-RESULT-TYPE
           MOVE 'N' TO WS-REFUND-FLAG.
       2000-CALC-ANNUAL-DISB.
           COMPUTE WS-TOTAL-ANNUAL =
               WS-ANNUAL-TAX + WS-ANNUAL-INS +
               WS-ANNUAL-PMI + WS-ANNUAL-FLOOD
           COMPUTE WS-CUSHION =
               (WS-TOTAL-ANNUAL / 12) * WS-CUSHION-MONTHS
           COMPUTE WS-TARGET-BAL =
               WS-TOTAL-ANNUAL + WS-CUSHION.
       3000-PROJECT-BALANCE.
           MOVE WS-ESCROW-BAL TO WS-PROJECTED-BAL
           PERFORM VARYING WS-MONTH-IDX FROM 1 BY 1
               UNTIL WS-MONTH-IDX > 12
               ADD WS-MONTHLY-PMT TO WS-PROJECTED-BAL
               PERFORM 3100-APPLY-DISBURSEMENT
               IF WS-PROJECTED-BAL < WS-LOW-POINT
                   MOVE WS-PROJECTED-BAL TO WS-LOW-POINT
                   MOVE WS-MONTH-IDX TO WS-LOW-MONTH
               END-IF
           END-PERFORM.
       3100-APPLY-DISBURSEMENT.
           MOVE 0 TO WS-MONTH-DISB
           IF WS-MONTH-IDX = 3 OR WS-MONTH-IDX = 9
               ADD WS-ANNUAL-TAX TO WS-MONTH-DISB
           END-IF
           IF WS-MONTH-IDX = 6
               ADD WS-ANNUAL-INS TO WS-MONTH-DISB
               ADD WS-ANNUAL-FLOOD TO WS-MONTH-DISB
           END-IF
           IF WS-ANNUAL-PMI > 0
               COMPUTE WS-MONTH-DISB =
                   WS-MONTH-DISB + (WS-ANNUAL-PMI / 12)
           END-IF
           SUBTRACT WS-MONTH-DISB FROM WS-PROJECTED-BAL.
       4000-ANALYZE-RESULT.
           IF WS-LOW-POINT < 0
               SET WS-SHORTAGE-FOUND TO TRUE
               COMPUTE WS-SHORTAGE =
                   0 - WS-LOW-POINT + WS-CUSHION
           ELSE
               IF WS-LOW-POINT > WS-CUSHION * 2
                   SET WS-SURPLUS-FOUND TO TRUE
                   COMPUTE WS-SURPLUS =
                       WS-LOW-POINT - WS-CUSHION
                   IF WS-SURPLUS > 50
                       MOVE 'Y' TO WS-REFUND-FLAG
                   END-IF
               ELSE
                   SET WS-BALANCED TO TRUE
               END-IF
           END-IF.
       5000-CALC-ADJUSTMENT.
           IF WS-SHORTAGE-FOUND
               COMPUTE WS-ADJUSTMENT =
                   WS-SHORTAGE / 12
               COMPUTE WS-NEW-MONTHLY =
                   WS-MONTHLY-PMT + WS-ADJUSTMENT
           ELSE
               IF WS-SURPLUS-FOUND
                   IF WS-REFUND-DUE
                       COMPUTE WS-ADJUSTMENT =
                           0 - (WS-SURPLUS / 12)
                       COMPUTE WS-NEW-MONTHLY =
                           WS-MONTHLY-PMT + WS-ADJUSTMENT
                   ELSE
                       MOVE WS-MONTHLY-PMT TO WS-NEW-MONTHLY
                   END-IF
               ELSE
                   MOVE WS-MONTHLY-PMT TO WS-NEW-MONTHLY
               END-IF
           END-IF.
       6000-DISPLAY-RESULTS.
           DISPLAY 'ESCROW ANALYSIS REPORT'
           DISPLAY '======================'
           DISPLAY 'ACCOUNT:         ' WS-ACCT-NUM
           DISPLAY 'CURRENT BALANCE: ' WS-ESCROW-BAL
           DISPLAY 'ANNUAL DISBURS:  ' WS-TOTAL-ANNUAL
           DISPLAY 'CUSHION REQUIRED:' WS-CUSHION
           DISPLAY 'LOW POINT:       ' WS-LOW-POINT
           DISPLAY 'LOW MONTH:       ' WS-LOW-MONTH
           IF WS-SHORTAGE-FOUND
               DISPLAY 'RESULT: SHORTAGE'
               DISPLAY 'SHORTAGE AMOUNT: ' WS-SHORTAGE
           END-IF
           IF WS-SURPLUS-FOUND
               DISPLAY 'RESULT: SURPLUS'
               DISPLAY 'SURPLUS AMOUNT:  ' WS-SURPLUS
               IF WS-REFUND-DUE
                   DISPLAY 'REFUND ELIGIBLE'
               END-IF
           END-IF
           IF WS-BALANCED
               DISPLAY 'RESULT: BALANCED'
           END-IF
           DISPLAY 'CURRENT PMT:     ' WS-MONTHLY-PMT
           DISPLAY 'NEW PMT:         ' WS-NEW-MONTHLY
           DISPLAY 'ADJUSTMENT:      ' WS-ADJUSTMENT.
