       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-GOV-ODO-BENEFIT.
      *================================================================
      * Government Benefits Statement with OCCURS DEPENDING ON
      * Generates variable-length benefit statements with
      * dynamic payment history. (MANUAL REVIEW - ODO)
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-BENEFICIARY.
           05 WS-BENE-SSN             PIC X(9).
           05 WS-BENE-NAME            PIC X(30).
           05 WS-BENE-TYPE            PIC X(1).
               88 WS-SS-RETIREMENT    VALUE 'R'.
               88 WS-SS-DISABILITY    VALUE 'D'.
               88 WS-SS-SURVIVOR      VALUE 'S'.
               88 WS-SSI              VALUE 'I'.
           05 WS-BENE-STATUS          PIC X(1).
               88 WS-ACTIVE           VALUE 'A'.
               88 WS-SUSPENDED        VALUE 'S'.
               88 WS-TERMINATED       VALUE 'T'.
       01 WS-CURRENT-BENEFIT.
           05 WS-GROSS-BENEFIT        PIC S9(5)V99 COMP-3.
           05 WS-MEDICARE-DEDUCT      PIC S9(5)V99 COMP-3.
           05 WS-TAX-WITHHOLD         PIC S9(5)V99 COMP-3.
           05 WS-OTHER-DEDUCT         PIC S9(5)V99 COMP-3.
           05 WS-NET-BENEFIT          PIC S9(5)V99 COMP-3.
       01 WS-PAYMENT-COUNT            PIC 9(2).
       01 WS-PAYMENT-HISTORY.
           05 WS-PAYMENT OCCURS 1 TO 24
               DEPENDING ON WS-PAYMENT-COUNT.
               10 WS-PMT-DATE         PIC 9(8).
               10 WS-PMT-GROSS        PIC S9(5)V99 COMP-3.
               10 WS-PMT-NET          PIC S9(5)V99 COMP-3.
               10 WS-PMT-STATUS       PIC X(1).
                   88 WS-PMT-PAID     VALUE 'P'.
                   88 WS-PMT-PENDING  VALUE 'E'.
                   88 WS-PMT-RETURNED VALUE 'R'.
       01 WS-STATEMENT-TOTALS.
           05 WS-YTD-GROSS            PIC S9(7)V99 COMP-3.
           05 WS-YTD-DEDUCTIONS       PIC S9(5)V99 COMP-3.
           05 WS-YTD-NET              PIC S9(7)V99 COMP-3.
           05 WS-YTD-MEDICARE         PIC S9(5)V99 COMP-3.
           05 WS-YTD-TAX              PIC S9(5)V99 COMP-3.
       01 WS-PMT-IDX                  PIC 9(2).
       01 WS-PAID-COUNT               PIC 9(2).
       01 WS-RETURNED-COUNT           PIC 9(2).
       01 WS-PENDING-COUNT            PIC 9(2).
       01 WS-WORK-FIELDS.
           05 WS-TEMP-AMT             PIC S9(7)V99 COMP-3.
           05 WS-AVG-PAYMENT          PIC S9(5)V99 COMP-3.
       01 WS-DIVIDE-FIELDS.
           05 WS-DIV-RESULT           PIC S9(5)V99 COMP-3.
           05 WS-DIV-REMAINDER        PIC S9(3)V99 COMP-3.
       01 WS-PROCESS-DATE             PIC 9(8).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-NET-BENEFIT
           PERFORM 3000-PROCESS-HISTORY
           PERFORM 4000-CALC-YTD-TOTALS
           PERFORM 5000-CALC-AVERAGES
           PERFORM 6000-DISPLAY-STATEMENT
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-PROCESS-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-YTD-GROSS
           MOVE 0 TO WS-YTD-DEDUCTIONS
           MOVE 0 TO WS-YTD-NET
           MOVE 0 TO WS-YTD-MEDICARE
           MOVE 0 TO WS-YTD-TAX
           MOVE 0 TO WS-PAID-COUNT
           MOVE 0 TO WS-RETURNED-COUNT
           MOVE 0 TO WS-PENDING-COUNT.
       2000-CALC-NET-BENEFIT.
           COMPUTE WS-NET-BENEFIT =
               WS-GROSS-BENEFIT -
               WS-MEDICARE-DEDUCT -
               WS-TAX-WITHHOLD -
               WS-OTHER-DEDUCT
           IF WS-NET-BENEFIT < 0
               MOVE 0 TO WS-NET-BENEFIT
           END-IF.
       3000-PROCESS-HISTORY.
           PERFORM VARYING WS-PMT-IDX FROM 1 BY 1
               UNTIL WS-PMT-IDX > WS-PAYMENT-COUNT
               EVALUATE TRUE
                   WHEN WS-PMT-PAID(WS-PMT-IDX)
                       ADD 1 TO WS-PAID-COUNT
                       ADD WS-PMT-GROSS(WS-PMT-IDX)
                           TO WS-YTD-GROSS
                       ADD WS-PMT-NET(WS-PMT-IDX)
                           TO WS-YTD-NET
                   WHEN WS-PMT-RETURNED(WS-PMT-IDX)
                       ADD 1 TO WS-RETURNED-COUNT
                   WHEN WS-PMT-PENDING(WS-PMT-IDX)
                       ADD 1 TO WS-PENDING-COUNT
                       ADD WS-PMT-GROSS(WS-PMT-IDX)
                           TO WS-YTD-GROSS
               END-EVALUATE
           END-PERFORM.
       4000-CALC-YTD-TOTALS.
           COMPUTE WS-YTD-DEDUCTIONS =
               WS-YTD-GROSS - WS-YTD-NET
           COMPUTE WS-YTD-MEDICARE =
               WS-MEDICARE-DEDUCT * WS-PAID-COUNT
           COMPUTE WS-YTD-TAX =
               WS-TAX-WITHHOLD * WS-PAID-COUNT.
       5000-CALC-AVERAGES.
           IF WS-PAID-COUNT > 0
               DIVIDE WS-YTD-NET BY WS-PAID-COUNT
                   GIVING WS-AVG-PAYMENT
                   REMAINDER WS-DIV-REMAINDER
           END-IF.
       6000-DISPLAY-STATEMENT.
           DISPLAY "BENEFIT STATEMENT"
           DISPLAY "DATE: " WS-PROCESS-DATE
           DISPLAY "SSN: " WS-BENE-SSN
           DISPLAY "NAME: " WS-BENE-NAME
           DISPLAY "TYPE: " WS-BENE-TYPE
           DISPLAY "STATUS: " WS-BENE-STATUS
           DISPLAY "--- CURRENT MONTH ---"
           DISPLAY "GROSS: " WS-GROSS-BENEFIT
           DISPLAY "MEDICARE: " WS-MEDICARE-DEDUCT
           DISPLAY "TAX: " WS-TAX-WITHHOLD
           DISPLAY "NET: " WS-NET-BENEFIT
           DISPLAY "--- YTD TOTALS ---"
           DISPLAY "YTD GROSS: " WS-YTD-GROSS
           DISPLAY "YTD NET: " WS-YTD-NET
           DISPLAY "AVG PAYMENT: " WS-AVG-PAYMENT
           DISPLAY "PAYMENTS: " WS-PAYMENT-COUNT
           DISPLAY "  PAID: " WS-PAID-COUNT
           DISPLAY "  PENDING: " WS-PENDING-COUNT
           DISPLAY "  RETURNED: " WS-RETURNED-COUNT.
