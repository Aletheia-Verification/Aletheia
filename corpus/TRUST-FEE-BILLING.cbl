       IDENTIFICATION DIVISION.
       PROGRAM-ID. TRUST-FEE-BILLING.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT TRUST-FILE ASSIGN TO 'TRUSTIN'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-TRU-STATUS.
           SELECT BILL-FILE ASSIGN TO 'BILLOUT'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-BIL-STATUS.

       DATA DIVISION.
       FILE SECTION.

       FD TRUST-FILE.
       01 TRUST-RECORD.
           05 TF-TRUST-ID             PIC X(12).
           05 TF-TRUST-TYPE           PIC X(2).
               88 TF-REVOCABLE        VALUE 'RV'.
               88 TF-IRREVOCABLE      VALUE 'IR'.
               88 TF-CHARITABLE       VALUE 'CH'.
               88 TF-SPECIAL-NEEDS    VALUE 'SN'.
           05 TF-MARKET-VALUE         PIC S9(13)V99 COMP-3.
           05 TF-INCOME-EARNED        PIC S9(11)V99 COMP-3.
           05 TF-TXN-COUNT            PIC S9(5) COMP-3.
           05 TF-FEE-SCHEDULE         PIC X(1).
               88 TF-STANDARD-FEE     VALUE 'S'.
               88 TF-PREMIUM-FEE      VALUE 'P'.
               88 TF-CUSTOM-FEE       VALUE 'C'.
           05 TF-CUSTOM-BPS           PIC S9(3)V99 COMP-3.

       FD BILL-FILE.
       01 BILL-RECORD.
           05 BL-TRUST-ID             PIC X(12).
           05 BL-ADMIN-FEE            PIC S9(9)V99 COMP-3.
           05 BL-INVESTMENT-FEE       PIC S9(9)V99 COMP-3.
           05 BL-TXN-FEE              PIC S9(9)V99 COMP-3.
           05 BL-TOTAL-FEE            PIC S9(11)V99 COMP-3.
           05 BL-FEE-TYPE             PIC X(10).
           05 BL-WAIVER-APPLIED       PIC X VALUE 'N'.

       WORKING-STORAGE SECTION.

       01 WS-TRU-STATUS               PIC X(2).
       01 WS-BIL-STATUS               PIC X(2).
       01 WS-EOF-FLAG                 PIC X VALUE 'N'.
           88 WS-EOF                   VALUE 'Y'.

       01 WS-FEE-TIERS.
           05 WS-TIER OCCURS 4.
               10 WS-FT-FLOOR         PIC S9(13)V99 COMP-3.
               10 WS-FT-CEIL          PIC S9(13)V99 COMP-3.
               10 WS-FT-STD-BPS       PIC S9(3)V99 COMP-3.
               10 WS-FT-PREM-BPS      PIC S9(3)V99 COMP-3.
       01 WS-TIER-IDX                 PIC 9(1).

       01 WS-CALC.
           05 WS-ADMIN-FEE            PIC S9(9)V99 COMP-3.
           05 WS-INVEST-FEE           PIC S9(9)V99 COMP-3.
           05 WS-TXN-FEE              PIC S9(9)V99 COMP-3.
           05 WS-TOTAL-FEE            PIC S9(11)V99 COMP-3.
           05 WS-BPS-RATE             PIC S9(3)V99 COMP-3.
           05 WS-TIER-AMT             PIC S9(13)V99 COMP-3.
           05 WS-REMAINING            PIC S9(13)V99 COMP-3.
           05 WS-TXN-RATE             PIC S9(3)V99 COMP-3
               VALUE 20.00.

       01 WS-MIN-ANNUAL-FEE           PIC S9(9)V99 COMP-3
           VALUE 3000.00.
       01 WS-CHARITABLE-DISC          PIC S9(1)V99 COMP-3
           VALUE 0.25.

       01 WS-COUNTERS.
           05 WS-TOTAL-BILLED         PIC S9(7) COMP-3 VALUE 0.
           05 WS-WAIVER-COUNT         PIC S9(7) COMP-3 VALUE 0.
           05 WS-TOTAL-FEES           PIC S9(13)V99 COMP-3
               VALUE 0.

       01 WS-TALLY-WORK               PIC 9(3).

       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INIT-FEE-TIERS
           PERFORM 1100-OPEN-FILES
           PERFORM 1200-READ-FIRST
           PERFORM 2000-PROCESS-TRUST
               UNTIL WS-EOF
           PERFORM 3000-CLOSE-FILES
           PERFORM 4000-DISPLAY-SUMMARY
           STOP RUN.

       1000-INIT-FEE-TIERS.
           MOVE 0 TO WS-FT-FLOOR(1)
           MOVE 2000000.00 TO WS-FT-CEIL(1)
           MOVE 8.00 TO WS-FT-STD-BPS(1)
           MOVE 12.00 TO WS-FT-PREM-BPS(1)
           MOVE 2000000.00 TO WS-FT-FLOOR(2)
           MOVE 10000000.00 TO WS-FT-CEIL(2)
           MOVE 6.00 TO WS-FT-STD-BPS(2)
           MOVE 10.00 TO WS-FT-PREM-BPS(2)
           MOVE 10000000.00 TO WS-FT-FLOOR(3)
           MOVE 50000000.00 TO WS-FT-CEIL(3)
           MOVE 4.00 TO WS-FT-STD-BPS(3)
           MOVE 7.00 TO WS-FT-PREM-BPS(3)
           MOVE 50000000.00 TO WS-FT-FLOOR(4)
           MOVE 999999999999.99 TO WS-FT-CEIL(4)
           MOVE 2.50 TO WS-FT-STD-BPS(4)
           MOVE 5.00 TO WS-FT-PREM-BPS(4)
           MOVE 'N' TO WS-EOF-FLAG.

       1100-OPEN-FILES.
           OPEN INPUT TRUST-FILE
           OPEN OUTPUT BILL-FILE.

       1200-READ-FIRST.
           READ TRUST-FILE
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ.

       2000-PROCESS-TRUST.
           ADD 1 TO WS-TOTAL-BILLED
           MOVE 0 TO WS-ADMIN-FEE
           MOVE 0 TO WS-INVEST-FEE
           MOVE 0 TO WS-TXN-FEE
           MOVE 'N' TO BL-WAIVER-APPLIED
           PERFORM 2100-CALC-ADMIN-FEE
           PERFORM 2200-CALC-INVEST-FEE
           PERFORM 2300-CALC-TXN-FEE
           PERFORM 2400-APPLY-DISCOUNTS
           PERFORM 2500-ENFORCE-MINIMUM
           PERFORM 2600-WRITE-BILL
           READ TRUST-FILE
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ.

       2100-CALC-ADMIN-FEE.
           MOVE TF-MARKET-VALUE TO WS-REMAINING
           MOVE 0 TO WS-ADMIN-FEE
           PERFORM VARYING WS-TIER-IDX FROM 1 BY 1
               UNTIL WS-TIER-IDX > 4
               OR WS-REMAINING <= 0
               IF WS-REMAINING >
                   WS-FT-CEIL(WS-TIER-IDX)
                   COMPUTE WS-TIER-AMT =
                       WS-FT-CEIL(WS-TIER-IDX) -
                       WS-FT-FLOOR(WS-TIER-IDX)
               ELSE
                   IF WS-REMAINING >
                       WS-FT-FLOOR(WS-TIER-IDX)
                       COMPUTE WS-TIER-AMT =
                           WS-REMAINING -
                           WS-FT-FLOOR(WS-TIER-IDX)
                   ELSE
                       MOVE 0 TO WS-TIER-AMT
                   END-IF
               END-IF
               EVALUATE TRUE
                   WHEN TF-STANDARD-FEE
                       MOVE WS-FT-STD-BPS(WS-TIER-IDX)
                           TO WS-BPS-RATE
                   WHEN TF-PREMIUM-FEE
                       MOVE WS-FT-PREM-BPS(WS-TIER-IDX)
                           TO WS-BPS-RATE
                   WHEN TF-CUSTOM-FEE
                       MOVE TF-CUSTOM-BPS TO WS-BPS-RATE
                   WHEN OTHER
                       MOVE WS-FT-STD-BPS(WS-TIER-IDX)
                           TO WS-BPS-RATE
               END-EVALUATE
               COMPUTE WS-ADMIN-FEE = WS-ADMIN-FEE +
                   (WS-TIER-AMT * WS-BPS-RATE / 10000)
               SUBTRACT WS-TIER-AMT FROM WS-REMAINING
           END-PERFORM.

       2200-CALC-INVEST-FEE.
           IF TF-INCOME-EARNED > 0
               COMPUTE WS-INVEST-FEE =
                   TF-INCOME-EARNED * 0.05
           ELSE
               MOVE 0 TO WS-INVEST-FEE
           END-IF.

       2300-CALC-TXN-FEE.
           COMPUTE WS-TXN-FEE =
               TF-TXN-COUNT * WS-TXN-RATE.

       2400-APPLY-DISCOUNTS.
           IF TF-CHARITABLE
               COMPUTE WS-ADMIN-FEE =
                   WS-ADMIN-FEE *
                   (1 - WS-CHARITABLE-DISC)
               MOVE 'Y' TO BL-WAIVER-APPLIED
               ADD 1 TO WS-WAIVER-COUNT
           END-IF.

       2500-ENFORCE-MINIMUM.
           COMPUTE WS-TOTAL-FEE =
               WS-ADMIN-FEE + WS-INVEST-FEE + WS-TXN-FEE
           IF WS-TOTAL-FEE < WS-MIN-ANNUAL-FEE
               MOVE WS-MIN-ANNUAL-FEE TO WS-TOTAL-FEE
           END-IF.

       2600-WRITE-BILL.
           MOVE TF-TRUST-ID TO BL-TRUST-ID
           MOVE WS-ADMIN-FEE TO BL-ADMIN-FEE
           MOVE WS-INVEST-FEE TO BL-INVESTMENT-FEE
           MOVE WS-TXN-FEE TO BL-TXN-FEE
           MOVE WS-TOTAL-FEE TO BL-TOTAL-FEE
           EVALUATE TRUE
               WHEN TF-STANDARD-FEE
                   MOVE 'STANDARD  ' TO BL-FEE-TYPE
               WHEN TF-PREMIUM-FEE
                   MOVE 'PREMIUM   ' TO BL-FEE-TYPE
               WHEN TF-CUSTOM-FEE
                   MOVE 'CUSTOM    ' TO BL-FEE-TYPE
               WHEN OTHER
                   MOVE 'UNKNOWN   ' TO BL-FEE-TYPE
           END-EVALUATE
           WRITE BILL-RECORD
           ADD WS-TOTAL-FEE TO WS-TOTAL-FEES.

       3000-CLOSE-FILES.
           CLOSE TRUST-FILE
           CLOSE BILL-FILE.

       4000-DISPLAY-SUMMARY.
           MOVE 0 TO WS-TALLY-WORK
           INSPECT BL-FEE-TYPE
               TALLYING WS-TALLY-WORK FOR ALL 'M'
           DISPLAY 'TRUST FEE BILLING COMPLETE'
           DISPLAY 'TRUSTS BILLED:     ' WS-TOTAL-BILLED
           DISPLAY 'WAIVERS APPLIED:   ' WS-WAIVER-COUNT
           DISPLAY 'TOTAL FEES:        ' WS-TOTAL-FEES.
