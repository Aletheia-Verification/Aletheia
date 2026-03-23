       IDENTIFICATION DIVISION.
       PROGRAM-ID. MTG-ESCROW-CALC.
      *================================================================*
      * Mortgage Escrow Analysis Calculator                             *
      * Calculates monthly escrow payments for taxes, insurance,        *
      * and PMI, with annual shortage/surplus adjustment.               *
      *================================================================*
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ESCROW-FILE ASSIGN TO 'ESCROW.DAT'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-FILE-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD  ESCROW-FILE.
       01  ESCROW-RECORD.
           05  ER-LOAN-NUMBER         PIC X(10).
           05  ER-ANNUAL-TAX          PIC 9(7)V99.
           05  ER-ANNUAL-INS          PIC 9(7)V99.
           05  ER-PMI-MONTHLY         PIC 9(5)V99.
           05  ER-CURRENT-BAL         PIC S9(9)V99.
           05  ER-TARGET-BAL          PIC S9(9)V99.
           05  ER-STATUS              PIC X(01).
       WORKING-STORAGE SECTION.
       01  WS-FILE-STATUS             PIC XX VALUE SPACES.
       01  WS-EOF-FLAG                PIC X VALUE 'N'.
           88  WS-EOF                 VALUE 'Y'.
       01  WS-MONTHLY-TAX            PIC S9(7)V99.
       01  WS-MONTHLY-INS            PIC S9(7)V99.
       01  WS-TOTAL-MONTHLY          PIC S9(7)V99.
       01  WS-ANNUAL-REQUIRED        PIC S9(9)V99.
       01  WS-SHORTAGE               PIC S9(9)V99.
       01  WS-SURPLUS                PIC S9(9)V99.
       01  WS-ADJUSTMENT             PIC S9(7)V99.
       01  WS-CUSHION-AMT            PIC S9(7)V99.
       01  WS-CUSHION-MONTHS         PIC 9(02) VALUE 2.
       01  WS-PROCESSED-CNT          PIC 9(06) VALUE 0.
       01  WS-ERROR-CNT              PIC 9(06) VALUE 0.
       01  WS-SKIP-CNT               PIC 9(06) VALUE 0.
       01  WS-ERR-MSG                PIC X(80) VALUE SPACES.
       01  WS-IDX                    PIC 9(02).
       01  WS-MONTH-BALANCES.
           05  WS-MONTH-BAL          PIC S9(9)V99
                                     OCCURS 12 TIMES.
       01  WS-MIN-BAL                PIC S9(9)V99.
       01  WS-PROJECTION-OK          PIC X VALUE 'Y'.
           88  PROJECTION-VALID      VALUE 'Y'.
           88  PROJECTION-FAILED     VALUE 'N'.
       01  WS-DISBURSE-MONTH.
           05  WS-TAX-DISBURSE       PIC 9(02) OCCURS 2 TIMES.
           05  WS-INS-DISBURSE       PIC 9(02) VALUE 3.
       01  WS-CURRENT-DATE.
           05  WS-CURR-YEAR          PIC 9(04).
           05  WS-CURR-MONTH         PIC 9(02).
           05  WS-CURR-DAY           PIC 9(02).
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PROCESS-ESCROW
               UNTIL WS-EOF
           PERFORM 9000-FINALIZE
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           MOVE 6 TO WS-TAX-DISBURSE(1)
           MOVE 12 TO WS-TAX-DISBURSE(2)
           OPEN INPUT ESCROW-FILE
           IF WS-FILE-STATUS NOT = '00'
               DISPLAY 'ERROR OPENING ESCROW FILE: ' WS-FILE-STATUS
               STOP RUN
           END-IF
           PERFORM 2100-READ-ESCROW.
       2000-PROCESS-ESCROW.
           EVALUATE TRUE
               WHEN ER-STATUS = 'A'
                   PERFORM 3000-CALC-MONTHLY
                   PERFORM 4000-PROJECT-BALANCE
                   IF PROJECTION-VALID
                       PERFORM 5000-CALC-ADJUSTMENT
                       ADD 1 TO WS-PROCESSED-CNT
                   ELSE
                       PERFORM 6000-BUILD-ERROR
                       ADD 1 TO WS-ERROR-CNT
                   END-IF
               WHEN ER-STATUS = 'C'
                   ADD 1 TO WS-SKIP-CNT
               WHEN ER-STATUS = 'H'
                   ADD 1 TO WS-SKIP-CNT
               WHEN OTHER
                   PERFORM 6000-BUILD-ERROR
                   ADD 1 TO WS-ERROR-CNT
           END-EVALUATE
           PERFORM 2100-READ-ESCROW.
       2100-READ-ESCROW.
           READ ESCROW-FILE
               AT END SET WS-EOF TO TRUE
           END-READ.
       3000-CALC-MONTHLY.
           COMPUTE WS-MONTHLY-TAX ROUNDED =
               ER-ANNUAL-TAX / 12
           COMPUTE WS-MONTHLY-INS ROUNDED =
               ER-ANNUAL-INS / 12
           COMPUTE WS-TOTAL-MONTHLY ROUNDED =
               WS-MONTHLY-TAX + WS-MONTHLY-INS +
               ER-PMI-MONTHLY
           COMPUTE WS-CUSHION-AMT ROUNDED =
               WS-TOTAL-MONTHLY * WS-CUSHION-MONTHS.
       4000-PROJECT-BALANCE.
           MOVE 'Y' TO WS-PROJECTION-OK
           MOVE ER-CURRENT-BAL TO WS-MONTH-BAL(1)
           MOVE ER-CURRENT-BAL TO WS-MIN-BAL
           PERFORM VARYING WS-IDX FROM 2 BY 1
               UNTIL WS-IDX > 12
               COMPUTE WS-MONTH-BAL(WS-IDX) =
                   WS-MONTH-BAL(WS-IDX - 1) +
                   WS-TOTAL-MONTHLY
               IF WS-IDX = WS-TAX-DISBURSE(1) OR
                  WS-IDX = WS-TAX-DISBURSE(2)
                   SUBTRACT ER-ANNUAL-TAX FROM
                       WS-MONTH-BAL(WS-IDX)
               END-IF
               IF WS-IDX = WS-INS-DISBURSE
                   SUBTRACT ER-ANNUAL-INS FROM
                       WS-MONTH-BAL(WS-IDX)
               END-IF
               IF WS-MONTH-BAL(WS-IDX) < WS-MIN-BAL
                   MOVE WS-MONTH-BAL(WS-IDX) TO WS-MIN-BAL
               END-IF
           END-PERFORM
           IF WS-MIN-BAL < ZERO
               MOVE 'N' TO WS-PROJECTION-OK
           END-IF.
       5000-CALC-ADJUSTMENT.
           COMPUTE WS-ANNUAL-REQUIRED =
               ER-ANNUAL-TAX + ER-ANNUAL-INS +
               (ER-PMI-MONTHLY * 12) + WS-CUSHION-AMT
           COMPUTE WS-SHORTAGE =
               WS-ANNUAL-REQUIRED - ER-CURRENT-BAL
           IF WS-SHORTAGE > ZERO
               COMPUTE WS-ADJUSTMENT ROUNDED =
                   WS-SHORTAGE / 12
               DISPLAY 'LOAN ' ER-LOAN-NUMBER
                   ' SHORTAGE ADJ: ' WS-ADJUSTMENT
           ELSE
               COMPUTE WS-SURPLUS =
                   ER-CURRENT-BAL - WS-ANNUAL-REQUIRED
               IF WS-SURPLUS > 50
                   DISPLAY 'LOAN ' ER-LOAN-NUMBER
                       ' SURPLUS REFUND: ' WS-SURPLUS
               ELSE
                   DISPLAY 'LOAN ' ER-LOAN-NUMBER
                       ' BALANCE OK'
               END-IF
           END-IF.
       6000-BUILD-ERROR.
           MOVE SPACES TO WS-ERR-MSG
           STRING 'ESCROW ERR LOAN='
               DELIMITED BY SIZE
               ER-LOAN-NUMBER
               DELIMITED BY SIZE
               ' STATUS='
               DELIMITED BY SIZE
               ER-STATUS
               DELIMITED BY SIZE
               INTO WS-ERR-MSG
           DISPLAY WS-ERR-MSG.
       9000-FINALIZE.
           CLOSE ESCROW-FILE
           DISPLAY 'ESCROW ANALYSIS COMPLETE'
           DISPLAY 'PROCESSED: ' WS-PROCESSED-CNT
           DISPLAY 'ERRORS:    ' WS-ERROR-CNT
           DISPLAY 'SKIPPED:   ' WS-SKIP-CNT.
