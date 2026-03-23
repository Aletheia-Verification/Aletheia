       IDENTIFICATION DIVISION.
       PROGRAM-ID. BATCH-PAYMENT.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-PAYMENT-TYPE        PIC X(2).
           88  IS-MORTGAGE         VALUE 'MG'.
           88  IS-AUTO-LOAN        VALUE 'AL'.
           88  IS-CREDIT-CARD      VALUE 'CC'.
           88  IS-PERSONAL         VALUE 'PL'.
       01  WS-PRINCIPAL           PIC S9(9)V99 COMP-3.
       01  WS-ANNUAL-RATE         PIC S9(1)V9(6) COMP-3.
       01  WS-MONTHLY-RATE        PIC S9(1)V9(8) COMP-3.
       01  WS-TERM-MONTHS         PIC S9(3) COMP-3.
       01  WS-PAYMENT-AMT         PIC S9(7)V99 COMP-3.
       01  WS-INTEREST-PART       PIC S9(7)V99 COMP-3.
       01  WS-PRINCIPAL-PART      PIC S9(7)V99 COMP-3.
       01  WS-REMAINING-BAL       PIC S9(9)V99 COMP-3.
       01  WS-TOTAL-INTEREST      PIC S9(9)V99 COMP-3.
       01  WS-TOTAL-PAID          PIC S9(9)V99 COMP-3.
       01  WS-MONTH-CTR           PIC 9(3).
       01  WS-LATE-DAYS           PIC 9(3).
       01  WS-LATE-FEE            PIC S9(5)V99 COMP-3.
       01  WS-LATE-FEE-RATE       PIC S9(1)V9(4) COMP-3.
       01  WS-ESCROW-AMT          PIC S9(7)V99 COMP-3.
       01  WS-TAX-AMT             PIC S9(7)V99 COMP-3.
       01  WS-INSURANCE-AMT       PIC S9(7)V99 COMP-3.
       01  WS-TOTAL-MONTHLY       PIC S9(7)V99 COMP-3.
       01  WS-MIN-PAYMENT         PIC S9(7)V99 COMP-3.
       01  WS-MAX-PAYMENT         PIC S9(9)V99 COMP-3.
       01  WS-OVERPAYMENT         PIC S9(7)V99 COMP-3.
       01  WS-UNDERPAYMENT        PIC S9(7)V99 COMP-3.
       01  WS-STATUS              PIC X(15).
       01  WS-ERROR-CODE          PIC 9(4).
       01  WS-AMORT-FACTOR        PIC S9(1)V9(10) COMP-3.
       01  WS-TEMP-CALC           PIC S9(11)V99 COMP-3.

       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE.
           PERFORM 2000-DETERMINE-TERMS.
           PERFORM 3000-CALC-PAYMENT.
           PERFORM 4000-AMORTIZE.
           PERFORM 5000-APPLY-LATE-FEES.
           PERFORM 6000-CALC-ESCROW.
           PERFORM 7000-FINALIZE.
           STOP RUN.

       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-INTEREST.
           MOVE 0 TO WS-TOTAL-PAID.
           MOVE 0 TO WS-LATE-FEE.
           MOVE 0 TO WS-OVERPAYMENT.
           MOVE 0 TO WS-UNDERPAYMENT.
           MOVE 0 TO WS-ERROR-CODE.
           MOVE WS-PRINCIPAL TO WS-REMAINING-BAL.
           MOVE SPACES TO WS-STATUS.

       2000-DETERMINE-TERMS.
           EVALUATE TRUE
               WHEN IS-MORTGAGE
                   MOVE 0.0025 TO WS-LATE-FEE-RATE
                   IF WS-ANNUAL-RATE = 0
                       MOVE 0.0650 TO WS-ANNUAL-RATE
                   END-IF
                   IF WS-TERM-MONTHS = 0
                       MOVE 360 TO WS-TERM-MONTHS
                   END-IF
               WHEN IS-AUTO-LOAN
                   MOVE 0.0050 TO WS-LATE-FEE-RATE
                   IF WS-ANNUAL-RATE = 0
                       MOVE 0.0750 TO WS-ANNUAL-RATE
                   END-IF
                   IF WS-TERM-MONTHS = 0
                       MOVE 60 TO WS-TERM-MONTHS
                   END-IF
               WHEN IS-CREDIT-CARD
                   MOVE 0.0100 TO WS-LATE-FEE-RATE
                   IF WS-ANNUAL-RATE = 0
                       MOVE 0.2199 TO WS-ANNUAL-RATE
                   END-IF
                   MOVE 0 TO WS-TERM-MONTHS
               WHEN IS-PERSONAL
                   MOVE 0.0075 TO WS-LATE-FEE-RATE
                   IF WS-ANNUAL-RATE = 0
                       MOVE 0.1100 TO WS-ANNUAL-RATE
                   END-IF
                   IF WS-TERM-MONTHS = 0
                       MOVE 36 TO WS-TERM-MONTHS
                   END-IF
               WHEN OTHER
                   MOVE 9999 TO WS-ERROR-CODE
                   MOVE 'INVALID TYPE' TO WS-STATUS
           END-EVALUATE.
           DIVIDE WS-ANNUAL-RATE BY 12
               GIVING WS-MONTHLY-RATE.

       3000-CALC-PAYMENT.
           IF WS-ERROR-CODE > 0
               MOVE 0 TO WS-PAYMENT-AMT
           ELSE
               IF IS-CREDIT-CARD
                   COMPUTE WS-MIN-PAYMENT =
                       WS-PRINCIPAL * 0.02
                   IF WS-MIN-PAYMENT < 25
                       MOVE 25.00 TO WS-MIN-PAYMENT
                   END-IF
                   MOVE WS-MIN-PAYMENT TO WS-PAYMENT-AMT
               ELSE
                   COMPUTE WS-AMORT-FACTOR =
                       WS-MONTHLY-RATE /
                       (1 - (1 + WS-MONTHLY-RATE) **
                       (0 - WS-TERM-MONTHS))
                   MULTIPLY WS-PRINCIPAL BY WS-AMORT-FACTOR
                       GIVING WS-PAYMENT-AMT
               END-IF
           END-IF.

       4000-AMORTIZE.
           IF IS-CREDIT-CARD
               PERFORM 4100-CC-AMORTIZE
           ELSE
               PERFORM 4200-LOAN-AMORTIZE
           END-IF.

       4100-CC-AMORTIZE.
           MULTIPLY WS-REMAINING-BAL BY WS-MONTHLY-RATE
               GIVING WS-INTEREST-PART.
           SUBTRACT WS-INTEREST-PART FROM WS-PAYMENT-AMT
               GIVING WS-PRINCIPAL-PART.
           SUBTRACT WS-PRINCIPAL-PART FROM WS-REMAINING-BAL.
           ADD WS-INTEREST-PART TO WS-TOTAL-INTEREST.
           ADD WS-PAYMENT-AMT TO WS-TOTAL-PAID.

       4200-LOAN-AMORTIZE.
           PERFORM 4210-CALC-MONTH
               VARYING WS-MONTH-CTR FROM 1 BY 1
               UNTIL WS-MONTH-CTR > WS-TERM-MONTHS.

       4210-CALC-MONTH.
           MULTIPLY WS-REMAINING-BAL BY WS-MONTHLY-RATE
               GIVING WS-INTEREST-PART.
           SUBTRACT WS-INTEREST-PART FROM WS-PAYMENT-AMT
               GIVING WS-PRINCIPAL-PART.
           IF WS-PRINCIPAL-PART > WS-REMAINING-BAL
               MOVE WS-REMAINING-BAL TO WS-PRINCIPAL-PART
           END-IF.
           SUBTRACT WS-PRINCIPAL-PART FROM WS-REMAINING-BAL.
           ADD WS-INTEREST-PART TO WS-TOTAL-INTEREST.
           ADD WS-PAYMENT-AMT TO WS-TOTAL-PAID.

       5000-APPLY-LATE-FEES.
           IF WS-LATE-DAYS > 0
               IF WS-LATE-DAYS > 30
                   MULTIPLY WS-PAYMENT-AMT BY WS-LATE-FEE-RATE
                       GIVING WS-LATE-FEE
                   MULTIPLY WS-LATE-FEE BY 2
               ELSE
                   MULTIPLY WS-PAYMENT-AMT BY WS-LATE-FEE-RATE
                       GIVING WS-LATE-FEE
               END-IF
               ADD WS-LATE-FEE TO WS-TOTAL-PAID
           END-IF.

       6000-CALC-ESCROW.
           IF IS-MORTGAGE
               DIVIDE WS-TAX-AMT BY 12
                   GIVING WS-TEMP-CALC
               ADD WS-TEMP-CALC TO WS-ESCROW-AMT
               DIVIDE WS-INSURANCE-AMT BY 12
                   GIVING WS-TEMP-CALC
               ADD WS-TEMP-CALC TO WS-ESCROW-AMT
               ADD WS-PAYMENT-AMT TO WS-ESCROW-AMT
                   GIVING WS-TOTAL-MONTHLY
           ELSE
               MOVE WS-PAYMENT-AMT TO WS-TOTAL-MONTHLY
               MOVE 0 TO WS-ESCROW-AMT
           END-IF.

       7000-FINALIZE.
           EVALUATE TRUE
               WHEN WS-ERROR-CODE > 0
                   MOVE 'ERROR' TO WS-STATUS
               WHEN WS-REMAINING-BAL <= 0
                   MOVE 'PAID IN FULL' TO WS-STATUS
               WHEN WS-LATE-DAYS > 60
                   MOVE 'DELINQUENT' TO WS-STATUS
               WHEN WS-LATE-DAYS > 0
                   MOVE 'LATE' TO WS-STATUS
               WHEN OTHER
                   MOVE 'CURRENT' TO WS-STATUS
           END-EVALUATE.
