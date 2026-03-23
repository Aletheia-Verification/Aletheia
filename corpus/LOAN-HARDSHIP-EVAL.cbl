       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOAN-HARDSHIP-EVAL.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-BORROWER-INFO.
           05 WS-BOR-ACCT        PIC X(12).
           05 WS-BOR-NAME        PIC X(30).
           05 WS-MONTHLY-INCOME  PIC S9(7)V99 COMP-3.
           05 WS-MONTHLY-EXPENSE PIC S9(7)V99 COMP-3.
           05 WS-HARDSHIP-TYPE   PIC X(2).
               88 HS-JOB-LOSS    VALUE 'JL'.
               88 HS-MEDICAL     VALUE 'MD'.
               88 HS-DISASTER    VALUE 'DS'.
               88 HS-DIVORCE     VALUE 'DV'.
               88 HS-MILITARY    VALUE 'ML'.
       01 WS-LOAN-INFO.
           05 WS-LN-BALANCE     PIC S9(9)V99 COMP-3.
           05 WS-LN-PAYMENT     PIC S9(7)V99 COMP-3.
           05 WS-LN-RATE        PIC S9(2)V9(4) COMP-3.
           05 WS-LN-REMAINING   PIC 9(3).
       01 WS-DISPOSITION-AMT    PIC S9(7)V99 COMP-3.
       01 WS-SURPLUS-DEFICIT    PIC S9(7)V99 COMP-3.
       01 WS-AFFORD-PCT         PIC S9(3)V99 COMP-3.
       01 WS-MODIFIED-PMT       PIC S9(7)V99 COMP-3.
       01 WS-RELIEF-TYPE        PIC X(15).
       01 WS-RELIEF-TERM        PIC 9(2).
       01 WS-APPROVED           PIC X VALUE 'N'.
           88 IS-APPROVED       VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-ASSESS-FINANCIAL
           PERFORM 2000-DETERMINE-RELIEF
           PERFORM 3000-CALC-MODIFIED-PMT
           PERFORM 4000-OUTPUT
           STOP RUN.
       1000-ASSESS-FINANCIAL.
           COMPUTE WS-DISPOSITION-AMT =
               WS-MONTHLY-INCOME - WS-MONTHLY-EXPENSE
           IF WS-MONTHLY-INCOME > 0
               COMPUTE WS-AFFORD-PCT =
                   (WS-LN-PAYMENT / WS-MONTHLY-INCOME) * 100
           ELSE
               MOVE 999.99 TO WS-AFFORD-PCT
           END-IF
           COMPUTE WS-SURPLUS-DEFICIT =
               WS-DISPOSITION-AMT - WS-LN-PAYMENT.
       2000-DETERMINE-RELIEF.
           MOVE 'N' TO WS-APPROVED
           EVALUATE TRUE
               WHEN HS-JOB-LOSS
                   MOVE 'FORBEARANCE    ' TO WS-RELIEF-TYPE
                   MOVE 6 TO WS-RELIEF-TERM
                   MOVE 'Y' TO WS-APPROVED
               WHEN HS-MEDICAL
                   MOVE 'PMT REDUCTION  ' TO WS-RELIEF-TYPE
                   MOVE 12 TO WS-RELIEF-TERM
                   MOVE 'Y' TO WS-APPROVED
               WHEN HS-DISASTER
                   MOVE 'FORBEARANCE    ' TO WS-RELIEF-TYPE
                   MOVE 12 TO WS-RELIEF-TERM
                   MOVE 'Y' TO WS-APPROVED
               WHEN HS-DIVORCE
                   IF WS-SURPLUS-DEFICIT < 0
                       MOVE 'PMT REDUCTION  ' TO
                           WS-RELIEF-TYPE
                       MOVE 6 TO WS-RELIEF-TERM
                       MOVE 'Y' TO WS-APPROVED
                   ELSE
                       MOVE 'NOT QUALIFIED  ' TO
                           WS-RELIEF-TYPE
                   END-IF
               WHEN HS-MILITARY
                   MOVE 'SCRA PROTECTION' TO WS-RELIEF-TYPE
                   MOVE 36 TO WS-RELIEF-TERM
                   MOVE 'Y' TO WS-APPROVED
               WHEN OTHER
                   MOVE 'REVIEW REQUIRED' TO WS-RELIEF-TYPE
           END-EVALUATE.
       3000-CALC-MODIFIED-PMT.
           IF IS-APPROVED
               IF WS-RELIEF-TYPE = 'FORBEARANCE    '
                   MOVE 0 TO WS-MODIFIED-PMT
               ELSE
                   IF WS-RELIEF-TYPE = 'SCRA PROTECTION'
                       COMPUTE WS-MODIFIED-PMT =
                           WS-LN-BALANCE * 0.06 / 12
                   ELSE
                       IF WS-DISPOSITION-AMT > 0
                           COMPUTE WS-MODIFIED-PMT =
                               WS-DISPOSITION-AMT * 0.31
                       ELSE
                           MOVE 0 TO WS-MODIFIED-PMT
                       END-IF
                   END-IF
               END-IF
           ELSE
               MOVE WS-LN-PAYMENT TO WS-MODIFIED-PMT
           END-IF.
       4000-OUTPUT.
           DISPLAY 'HARDSHIP EVALUATION REPORT'
           DISPLAY '=========================='
           DISPLAY 'BORROWER:  ' WS-BOR-NAME
           DISPLAY 'ACCOUNT:   ' WS-BOR-ACCT
           DISPLAY 'HARDSHIP:  ' WS-HARDSHIP-TYPE
           DISPLAY 'INCOME:    $' WS-MONTHLY-INCOME
           DISPLAY 'EXPENSES:  $' WS-MONTHLY-EXPENSE
           DISPLAY 'CURRENT PMT:$' WS-LN-PAYMENT
           DISPLAY 'AFFORD PCT: ' WS-AFFORD-PCT
           DISPLAY 'SURPLUS:    $' WS-SURPLUS-DEFICIT
           DISPLAY 'RELIEF:     ' WS-RELIEF-TYPE
           IF IS-APPROVED
               DISPLAY 'STATUS: APPROVED'
               DISPLAY 'MODIFIED PMT:$' WS-MODIFIED-PMT
               DISPLAY 'TERM (MO):   ' WS-RELIEF-TERM
           ELSE
               DISPLAY 'STATUS: NOT APPROVED'
           END-IF.
