       IDENTIFICATION DIVISION.
       PROGRAM-ID. FRAUD-THRESHOLD-ADJ.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-THRESHOLD-DATA.
           05 WS-CURRENT-THRESH      PIC S9(5) COMP-3.
           05 WS-NEW-THRESH          PIC S9(5) COMP-3.
           05 WS-FALSE-POS-RATE      PIC S9(1)V9(4) COMP-3.
           05 WS-FALSE-NEG-RATE      PIC S9(1)V9(4) COMP-3.
           05 WS-TARGET-FP-RATE      PIC S9(1)V9(4) COMP-3
               VALUE 0.0200.
       01 WS-METRICS.
           05 WS-TOTAL-TXNS          PIC S9(7) COMP-3.
           05 WS-FLAGGED-TXNS        PIC S9(5) COMP-3.
           05 WS-TRUE-FRAUD          PIC S9(5) COMP-3.
           05 WS-FALSE-ALERTS        PIC S9(5) COMP-3.
           05 WS-MISSED-FRAUD        PIC S9(5) COMP-3.
       01 WS-ADJUSTMENT              PIC X(1).
           88 WS-INCREASE            VALUE 'I'.
           88 WS-DECREASE            VALUE 'D'.
           88 WS-NO-CHANGE           VALUE 'N'.
       01 WS-ADJ-AMOUNT              PIC S9(3) COMP-3.
       01 WS-STEP-SIZE               PIC S9(3) COMP-3
           VALUE 5.
       01 WS-ITER-IDX                PIC 9(2).
       01 WS-MAX-ITERATIONS          PIC 9(2) VALUE 10.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-RATES
           PERFORM 3000-DETERMINE-ADJUSTMENT
           PERFORM 4000-APPLY-ADJUSTMENT
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE WS-CURRENT-THRESH TO WS-NEW-THRESH
           MOVE 0 TO WS-ADJ-AMOUNT
           SET WS-NO-CHANGE TO TRUE.
       2000-CALC-RATES.
           IF WS-FLAGGED-TXNS > 0
               COMPUTE WS-FALSE-POS-RATE =
                   WS-FALSE-ALERTS / WS-FLAGGED-TXNS
           END-IF
           IF WS-TOTAL-TXNS > 0
               COMPUTE WS-FALSE-NEG-RATE =
                   WS-MISSED-FRAUD / WS-TOTAL-TXNS
           END-IF.
       3000-DETERMINE-ADJUSTMENT.
           IF WS-FALSE-POS-RATE > WS-TARGET-FP-RATE
               SET WS-INCREASE TO TRUE
           ELSE
               IF WS-FALSE-NEG-RATE > 0.0010
                   SET WS-DECREASE TO TRUE
               ELSE
                   SET WS-NO-CHANGE TO TRUE
               END-IF
           END-IF.
       4000-APPLY-ADJUSTMENT.
           PERFORM VARYING WS-ITER-IDX FROM 1 BY 1
               UNTIL WS-ITER-IDX > WS-MAX-ITERATIONS
               IF WS-INCREASE
                   ADD WS-STEP-SIZE TO WS-NEW-THRESH
                   ADD WS-STEP-SIZE TO WS-ADJ-AMOUNT
               END-IF
               IF WS-DECREASE
                   SUBTRACT WS-STEP-SIZE FROM WS-NEW-THRESH
                   SUBTRACT WS-STEP-SIZE FROM WS-ADJ-AMOUNT
               END-IF
           END-PERFORM
           IF WS-NEW-THRESH < 10
               MOVE 10 TO WS-NEW-THRESH
           END-IF
           IF WS-NEW-THRESH > 100
               MOVE 100 TO WS-NEW-THRESH
           END-IF.
       5000-DISPLAY-RESULTS.
           DISPLAY 'THRESHOLD ADJUSTMENT'
           DISPLAY '===================='
           DISPLAY 'CURRENT THRESH: ' WS-CURRENT-THRESH
           DISPLAY 'NEW THRESH:     ' WS-NEW-THRESH
           DISPLAY 'ADJUSTMENT:     ' WS-ADJ-AMOUNT
           DISPLAY 'FALSE POS RATE: ' WS-FALSE-POS-RATE
           DISPLAY 'FALSE NEG RATE: ' WS-FALSE-NEG-RATE
           DISPLAY 'TOTAL TXNS:     ' WS-TOTAL-TXNS
           DISPLAY 'TRUE FRAUD:     ' WS-TRUE-FRAUD
           IF WS-INCREASE
               DISPLAY 'DIRECTION: INCREASE'
           END-IF
           IF WS-DECREASE
               DISPLAY 'DIRECTION: DECREASE'
           END-IF
           IF WS-NO-CHANGE
               DISPLAY 'DIRECTION: NO CHANGE'
           END-IF.
