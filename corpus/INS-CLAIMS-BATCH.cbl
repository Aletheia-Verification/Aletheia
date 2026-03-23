       IDENTIFICATION DIVISION.
       PROGRAM-ID. INS-CLAIMS-BATCH.
      *================================================================*
      * INSURANCE CLAIMS BATCH PROCESSOR                               *
      * Processes batch of health insurance claims, applies deductible *
      * and coinsurance, checks policy limits, and calculates payable. *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-POLICY.
           05 WS-POL-NUMBER         PIC X(10).
           05 WS-POL-DEDUCTIBLE     PIC S9(7)V99 COMP-3.
           05 WS-POL-YTD-DEDUCT     PIC S9(7)V99 COMP-3.
           05 WS-POL-COINS-PCT      PIC S9(1)V99 COMP-3.
           05 WS-POL-OOP-MAX        PIC S9(7)V99 COMP-3.
           05 WS-POL-YTD-OOP        PIC S9(7)V99 COMP-3.
           05 WS-POL-ANNUAL-MAX     PIC S9(9)V99 COMP-3.
           05 WS-POL-YTD-PAID       PIC S9(9)V99 COMP-3.
       01 WS-CLAIM-TABLE.
           05 WS-CLM-ENTRY OCCURS 8.
               10 WS-CLM-NUM        PIC X(12).
               10 WS-CLM-TYPE       PIC X(2).
                   88 WS-CLM-INPAT  VALUE 'IP'.
                   88 WS-CLM-OUTPAT VALUE 'OP'.
                   88 WS-CLM-RX     VALUE 'RX'.
                   88 WS-CLM-EMERG  VALUE 'ER'.
               10 WS-CLM-BILLED     PIC S9(9)V99 COMP-3.
               10 WS-CLM-ALLOWED    PIC S9(9)V99 COMP-3.
               10 WS-CLM-DEDUCT-AMT PIC S9(7)V99 COMP-3.
               10 WS-CLM-COINS-AMT  PIC S9(7)V99 COMP-3.
               10 WS-CLM-PAYABLE    PIC S9(9)V99 COMP-3.
               10 WS-CLM-STATUS     PIC X(2).
                   88 WS-CLM-PAID   VALUE 'PD'.
                   88 WS-CLM-DENIED VALUE 'DN'.
                   88 WS-CLM-PEND   VALUE 'PN'.
       01 WS-CLAIM-COUNT            PIC S9(2) COMP-3.
       01 WS-IDX                    PIC S9(2) COMP-3.
       01 WS-DEDUCT-REMAINING       PIC S9(7)V99 COMP-3.
       01 WS-OOP-REMAINING          PIC S9(7)V99 COMP-3.
       01 WS-LIMIT-REMAINING        PIC S9(9)V99 COMP-3.
       01 WS-AFTER-DEDUCT           PIC S9(9)V99 COMP-3.
       01 WS-PATIENT-SHARE          PIC S9(7)V99 COMP-3.
       01 WS-BATCH-TOTALS.
           05 WS-BT-BILLED          PIC S9(11)V99 COMP-3.
           05 WS-BT-ALLOWED         PIC S9(11)V99 COMP-3.
           05 WS-BT-PAYABLE         PIC S9(11)V99 COMP-3.
           05 WS-BT-PATIENT         PIC S9(9)V99 COMP-3.
           05 WS-BT-DENIED-CNT      PIC S9(3) COMP-3.
           05 WS-BT-PAID-CNT        PIC S9(3) COMP-3.
       01 WS-DISCOUNT-RATE          PIC S9(1)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-CLAIMS
           PERFORM 3000-PROCESS-CLAIMS
           PERFORM 4000-SUMMARIZE
           PERFORM 5000-DISPLAY-REPORT
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'POL00045678' TO WS-POL-NUMBER
           MOVE 2500.00 TO WS-POL-DEDUCTIBLE
           MOVE 1800.00 TO WS-POL-YTD-DEDUCT
           MOVE 0.20 TO WS-POL-COINS-PCT
           MOVE 8000.00 TO WS-POL-OOP-MAX
           MOVE 3200.00 TO WS-POL-YTD-OOP
           MOVE 1000000.00 TO WS-POL-ANNUAL-MAX
           MOVE 45000.00 TO WS-POL-YTD-PAID
           MOVE 0 TO WS-BT-BILLED
           MOVE 0 TO WS-BT-ALLOWED
           MOVE 0 TO WS-BT-PAYABLE
           MOVE 0 TO WS-BT-PATIENT
           MOVE 0 TO WS-BT-DENIED-CNT
           MOVE 0 TO WS-BT-PAID-CNT.
       2000-LOAD-CLAIMS.
           MOVE 6 TO WS-CLAIM-COUNT
           MOVE 'CLM202603001' TO WS-CLM-NUM(1)
           MOVE 'OP' TO WS-CLM-TYPE(1)
           MOVE 1200.00 TO WS-CLM-BILLED(1)
           MOVE 0 TO WS-CLM-ALLOWED(1)
           MOVE 'PN' TO WS-CLM-STATUS(1)
           MOVE 'CLM202603002' TO WS-CLM-NUM(2)
           MOVE 'IP' TO WS-CLM-TYPE(2)
           MOVE 35000.00 TO WS-CLM-BILLED(2)
           MOVE 0 TO WS-CLM-ALLOWED(2)
           MOVE 'PN' TO WS-CLM-STATUS(2)
           MOVE 'CLM202603003' TO WS-CLM-NUM(3)
           MOVE 'RX' TO WS-CLM-TYPE(3)
           MOVE 450.00 TO WS-CLM-BILLED(3)
           MOVE 0 TO WS-CLM-ALLOWED(3)
           MOVE 'PN' TO WS-CLM-STATUS(3)
           MOVE 'CLM202603004' TO WS-CLM-NUM(4)
           MOVE 'ER' TO WS-CLM-TYPE(4)
           MOVE 8500.00 TO WS-CLM-BILLED(4)
           MOVE 0 TO WS-CLM-ALLOWED(4)
           MOVE 'PN' TO WS-CLM-STATUS(4)
           MOVE 'CLM202603005' TO WS-CLM-NUM(5)
           MOVE 'OP' TO WS-CLM-TYPE(5)
           MOVE 600.00 TO WS-CLM-BILLED(5)
           MOVE 0 TO WS-CLM-ALLOWED(5)
           MOVE 'PN' TO WS-CLM-STATUS(5)
           MOVE 'CLM202603006' TO WS-CLM-NUM(6)
           MOVE 'RX' TO WS-CLM-TYPE(6)
           MOVE 125.00 TO WS-CLM-BILLED(6)
           MOVE 0 TO WS-CLM-ALLOWED(6)
           MOVE 'PN' TO WS-CLM-STATUS(6).
       3000-PROCESS-CLAIMS.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-CLAIM-COUNT
               PERFORM 3100-CALC-ALLOWED
               PERFORM 3200-APPLY-DEDUCTIBLE
               PERFORM 3300-APPLY-COINSURANCE
               PERFORM 3400-CHECK-LIMITS
           END-PERFORM.
       3100-CALC-ALLOWED.
           EVALUATE TRUE
               WHEN WS-CLM-INPAT(WS-IDX)
                   MOVE 0.85 TO WS-DISCOUNT-RATE
               WHEN WS-CLM-OUTPAT(WS-IDX)
                   MOVE 0.75 TO WS-DISCOUNT-RATE
               WHEN WS-CLM-RX(WS-IDX)
                   MOVE 0.60 TO WS-DISCOUNT-RATE
               WHEN WS-CLM-EMERG(WS-IDX)
                   MOVE 0.80 TO WS-DISCOUNT-RATE
               WHEN OTHER
                   MOVE 0.70 TO WS-DISCOUNT-RATE
           END-EVALUATE
           COMPUTE WS-CLM-ALLOWED(WS-IDX) ROUNDED =
               WS-CLM-BILLED(WS-IDX) * WS-DISCOUNT-RATE.
       3200-APPLY-DEDUCTIBLE.
           COMPUTE WS-DEDUCT-REMAINING =
               WS-POL-DEDUCTIBLE - WS-POL-YTD-DEDUCT
           IF WS-DEDUCT-REMAINING > 0
               IF WS-CLM-ALLOWED(WS-IDX) <=
                   WS-DEDUCT-REMAINING
                   MOVE WS-CLM-ALLOWED(WS-IDX) TO
                       WS-CLM-DEDUCT-AMT(WS-IDX)
               ELSE
                   MOVE WS-DEDUCT-REMAINING TO
                       WS-CLM-DEDUCT-AMT(WS-IDX)
               END-IF
               ADD WS-CLM-DEDUCT-AMT(WS-IDX) TO
                   WS-POL-YTD-DEDUCT
           ELSE
               MOVE 0 TO WS-CLM-DEDUCT-AMT(WS-IDX)
           END-IF
           COMPUTE WS-AFTER-DEDUCT =
               WS-CLM-ALLOWED(WS-IDX) -
               WS-CLM-DEDUCT-AMT(WS-IDX).
       3300-APPLY-COINSURANCE.
           COMPUTE WS-OOP-REMAINING =
               WS-POL-OOP-MAX - WS-POL-YTD-OOP
           IF WS-OOP-REMAINING <= 0
               MOVE 0 TO WS-CLM-COINS-AMT(WS-IDX)
               MOVE WS-AFTER-DEDUCT TO
                   WS-CLM-PAYABLE(WS-IDX)
           ELSE
               COMPUTE WS-CLM-COINS-AMT(WS-IDX) ROUNDED =
                   WS-AFTER-DEDUCT * WS-POL-COINS-PCT
               IF WS-CLM-COINS-AMT(WS-IDX) >
                   WS-OOP-REMAINING
                   MOVE WS-OOP-REMAINING TO
                       WS-CLM-COINS-AMT(WS-IDX)
               END-IF
               COMPUTE WS-CLM-PAYABLE(WS-IDX) =
                   WS-AFTER-DEDUCT -
                   WS-CLM-COINS-AMT(WS-IDX)
               COMPUTE WS-PATIENT-SHARE =
                   WS-CLM-DEDUCT-AMT(WS-IDX) +
                   WS-CLM-COINS-AMT(WS-IDX)
               ADD WS-PATIENT-SHARE TO WS-POL-YTD-OOP
           END-IF.
       3400-CHECK-LIMITS.
           COMPUTE WS-LIMIT-REMAINING =
               WS-POL-ANNUAL-MAX - WS-POL-YTD-PAID
           IF WS-CLM-PAYABLE(WS-IDX) > WS-LIMIT-REMAINING
               IF WS-LIMIT-REMAINING > 0
                   MOVE WS-LIMIT-REMAINING TO
                       WS-CLM-PAYABLE(WS-IDX)
               ELSE
                   MOVE 0 TO WS-CLM-PAYABLE(WS-IDX)
                   MOVE 'DN' TO WS-CLM-STATUS(WS-IDX)
               END-IF
           END-IF
           IF WS-CLM-PAYABLE(WS-IDX) > 0
               MOVE 'PD' TO WS-CLM-STATUS(WS-IDX)
               ADD WS-CLM-PAYABLE(WS-IDX) TO WS-POL-YTD-PAID
           ELSE
               IF NOT WS-CLM-DENIED(WS-IDX)
                   MOVE 'DN' TO WS-CLM-STATUS(WS-IDX)
               END-IF
           END-IF.
       4000-SUMMARIZE.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-CLAIM-COUNT
               ADD WS-CLM-BILLED(WS-IDX) TO WS-BT-BILLED
               ADD WS-CLM-ALLOWED(WS-IDX) TO WS-BT-ALLOWED
               ADD WS-CLM-PAYABLE(WS-IDX) TO WS-BT-PAYABLE
               COMPUTE WS-PATIENT-SHARE =
                   WS-CLM-DEDUCT-AMT(WS-IDX) +
                   WS-CLM-COINS-AMT(WS-IDX)
               ADD WS-PATIENT-SHARE TO WS-BT-PATIENT
               IF WS-CLM-PAID(WS-IDX)
                   ADD 1 TO WS-BT-PAID-CNT
               END-IF
               IF WS-CLM-DENIED(WS-IDX)
                   ADD 1 TO WS-BT-DENIED-CNT
               END-IF
           END-PERFORM.
       5000-DISPLAY-REPORT.
           DISPLAY '========================================='
           DISPLAY 'CLAIMS PROCESSING REPORT'
           DISPLAY '========================================='
           DISPLAY 'POLICY: ' WS-POL-NUMBER
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-CLAIM-COUNT
               DISPLAY WS-CLM-NUM(WS-IDX) ' '
                   WS-CLM-TYPE(WS-IDX) ' BILLED: '
                   WS-CLM-BILLED(WS-IDX) ' PAYABLE: '
                   WS-CLM-PAYABLE(WS-IDX) ' '
                   WS-CLM-STATUS(WS-IDX)
           END-PERFORM
           DISPLAY '-----------------------------------------'
           DISPLAY 'TOTAL BILLED:    ' WS-BT-BILLED
           DISPLAY 'TOTAL ALLOWED:   ' WS-BT-ALLOWED
           DISPLAY 'TOTAL PAYABLE:   ' WS-BT-PAYABLE
           DISPLAY 'PATIENT SHARE:   ' WS-BT-PATIENT
           DISPLAY 'PAID COUNT:      ' WS-BT-PAID-CNT
           DISPLAY 'DENIED COUNT:    ' WS-BT-DENIED-CNT
           DISPLAY 'YTD OOP:         ' WS-POL-YTD-OOP
           DISPLAY 'YTD PAID:        ' WS-POL-YTD-PAID
           DISPLAY '========================================='.
