       IDENTIFICATION DIVISION.
       PROGRAM-ID. CLAIMS-ADJUDICATE.
      *================================================================
      * CLAIMS ADJUDICATION ENGINE
      * Reads pending claims, validates coverage, applies deductibles,
      * co-pay, and benefit limits, then writes payment or denial.
      *================================================================
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT CLAIM-FILE ASSIGN TO 'CLAIMFL'
               FILE STATUS IS WS-CLM-FS.
           SELECT PAYMENT-FILE ASSIGN TO 'CLMPAY'
               FILE STATUS IS WS-PAY-FS.
       DATA DIVISION.
       FILE SECTION.
       FD CLAIM-FILE.
       01 CLM-RECORD.
           05 CLM-ID                   PIC X(15).
           05 CLM-POLICY-NUM           PIC X(12).
           05 CLM-TYPE                 PIC X(3).
               88 CLM-MEDICAL          VALUE 'MED'.
               88 CLM-DENTAL           VALUE 'DEN'.
               88 CLM-VISION           VALUE 'VIS'.
               88 CLM-PHARMACY         VALUE 'PHR'.
           05 CLM-DATE-OF-SVC          PIC 9(8).
           05 CLM-DATE-FILED           PIC 9(8).
           05 CLM-BILLED-AMT           PIC S9(7)V99 COMP-3.
           05 CLM-PROVIDER-ID          PIC X(10).
           05 CLM-DIAG-CODE            PIC X(7).
           05 CLM-IN-NETWORK           PIC X(1).
               88 CLM-NETWORK-YES      VALUE 'Y'.
               88 CLM-NETWORK-NO       VALUE 'N'.
       FD PAYMENT-FILE.
       01 PAY-RECORD.
           05 PAY-CLAIM-ID             PIC X(15).
           05 PAY-STATUS               PIC X(3).
           05 PAY-ALLOWED-AMT          PIC S9(7)V99 COMP-3.
           05 PAY-DEDUCTIBLE           PIC S9(7)V99 COMP-3.
           05 PAY-COPAY-AMT            PIC S9(5)V99 COMP-3.
           05 PAY-PLAN-PAYS            PIC S9(7)V99 COMP-3.
           05 PAY-PATIENT-RESP         PIC S9(7)V99 COMP-3.
           05 PAY-DENIAL-CODE          PIC X(5).
       WORKING-STORAGE SECTION.
       01 WS-FILE-STATUS.
           05 WS-CLM-FS               PIC X(2).
           05 WS-PAY-FS               PIC X(2).
       01 WS-FLAGS.
           05 WS-EOF-FLAG             PIC X VALUE 'N'.
               88 WS-EOF              VALUE 'Y'.
           05 WS-DENY-FLAG            PIC X VALUE 'N'.
               88 WS-DENIED           VALUE 'Y'.
       01 WS-BENEFIT-LIMITS.
           05 WS-MED-MAX              PIC S9(9)V99 COMP-3
               VALUE 500000.00.
           05 WS-DEN-MAX              PIC S9(7)V99 COMP-3
               VALUE 5000.00.
           05 WS-VIS-MAX              PIC S9(7)V99 COMP-3
               VALUE 1000.00.
           05 WS-PHR-MAX              PIC S9(7)V99 COMP-3
               VALUE 10000.00.
       01 WS-DEDUCTIBLES.
           05 WS-ANNUAL-DEDUCT        PIC S9(7)V99 COMP-3
               VALUE 2500.00.
           05 WS-DEDUCT-MET           PIC S9(7)V99 COMP-3.
           05 WS-DEDUCT-REMAINING     PIC S9(7)V99 COMP-3.
       01 WS-COPAY-RATES.
           05 WS-IN-NET-COPAY-PCT     PIC S9(1)V99 COMP-3
               VALUE 0.20.
           05 WS-OUT-NET-COPAY-PCT    PIC S9(1)V99 COMP-3
               VALUE 0.40.
       01 WS-CALC.
           05 WS-ALLOWED-AMT          PIC S9(7)V99 COMP-3.
           05 WS-APPLIED-DEDUCT       PIC S9(7)V99 COMP-3.
           05 WS-AFTER-DEDUCT         PIC S9(7)V99 COMP-3.
           05 WS-COPAY-AMT            PIC S9(5)V99 COMP-3.
           05 WS-PLAN-PORTION         PIC S9(7)V99 COMP-3.
           05 WS-PATIENT-PORTION      PIC S9(7)V99 COMP-3.
           05 WS-BENEFIT-LIMIT        PIC S9(9)V99 COMP-3.
           05 WS-COPAY-RATE           PIC S9(1)V99 COMP-3.
       01 WS-COUNTERS.
           05 WS-TOTAL-READ           PIC 9(7) VALUE 0.
           05 WS-TOTAL-PAID           PIC 9(7) VALUE 0.
           05 WS-TOTAL-DENIED         PIC 9(7) VALUE 0.
           05 WS-TOTAL-PAID-AMT       PIC S9(11)V99 COMP-3
               VALUE 0.
       01 WS-FILING-LIMIT             PIC 9(3) VALUE 365.
       01 WS-DAYS-SINCE-SVC           PIC S9(5) COMP-3.
       01 WS-CURRENT-DATE             PIC 9(8).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-OPEN-FILES
           PERFORM 2000-READ-CLAIM
           PERFORM 3000-PROCESS-CLAIMS
               UNTIL WS-EOF
           PERFORM 8000-REPORT-TOTALS
           PERFORM 9000-CLOSE-FILES
           STOP RUN.
       1000-OPEN-FILES.
           OPEN INPUT CLAIM-FILE
           OPEN OUTPUT PAYMENT-FILE
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-DEDUCT-MET.
       2000-READ-CLAIM.
           READ CLAIM-FILE
               AT END
                   MOVE 'Y' TO WS-EOF-FLAG
           END-READ
           IF NOT WS-EOF
               ADD 1 TO WS-TOTAL-READ
           END-IF.
       3000-PROCESS-CLAIMS.
           INITIALIZE PAY-RECORD
           MOVE CLM-ID TO PAY-CLAIM-ID
           MOVE 'N' TO WS-DENY-FLAG
           PERFORM 3100-CHECK-TIMELY-FILING
           IF NOT WS-DENIED
               PERFORM 3200-DETERMINE-BENEFIT-LIMIT
               PERFORM 3300-CALC-ALLOWED-AMT
               PERFORM 3400-APPLY-DEDUCTIBLE
               PERFORM 3500-APPLY-COPAY
               PERFORM 3600-FINALIZE-PAYMENT
           END-IF
           PERFORM 4000-WRITE-PAYMENT
           PERFORM 2000-READ-CLAIM.
       3100-CHECK-TIMELY-FILING.
           COMPUTE WS-DAYS-SINCE-SVC =
               CLM-DATE-FILED - CLM-DATE-OF-SVC
           IF WS-DAYS-SINCE-SVC > WS-FILING-LIMIT
               MOVE 'Y' TO WS-DENY-FLAG
               MOVE 'DEN' TO PAY-STATUS
               MOVE 'TF001' TO PAY-DENIAL-CODE
           END-IF.
       3200-DETERMINE-BENEFIT-LIMIT.
           EVALUATE TRUE
               WHEN CLM-MEDICAL
                   MOVE WS-MED-MAX TO WS-BENEFIT-LIMIT
               WHEN CLM-DENTAL
                   MOVE WS-DEN-MAX TO WS-BENEFIT-LIMIT
               WHEN CLM-VISION
                   MOVE WS-VIS-MAX TO WS-BENEFIT-LIMIT
               WHEN CLM-PHARMACY
                   MOVE WS-PHR-MAX TO WS-BENEFIT-LIMIT
               WHEN OTHER
                   MOVE 0 TO WS-BENEFIT-LIMIT
                   MOVE 'Y' TO WS-DENY-FLAG
                   MOVE 'DEN' TO PAY-STATUS
                   MOVE 'TP001' TO PAY-DENIAL-CODE
           END-EVALUATE.
       3300-CALC-ALLOWED-AMT.
           IF CLM-BILLED-AMT > WS-BENEFIT-LIMIT
               MOVE WS-BENEFIT-LIMIT TO WS-ALLOWED-AMT
           ELSE
               MOVE CLM-BILLED-AMT TO WS-ALLOWED-AMT
           END-IF
           IF CLM-NETWORK-NO
               COMPUTE WS-ALLOWED-AMT =
                   WS-ALLOWED-AMT * 0.70
           END-IF.
       3400-APPLY-DEDUCTIBLE.
           COMPUTE WS-DEDUCT-REMAINING =
               WS-ANNUAL-DEDUCT - WS-DEDUCT-MET
           IF WS-DEDUCT-REMAINING > 0
               IF WS-ALLOWED-AMT <= WS-DEDUCT-REMAINING
                   MOVE WS-ALLOWED-AMT
                       TO WS-APPLIED-DEDUCT
               ELSE
                   MOVE WS-DEDUCT-REMAINING
                       TO WS-APPLIED-DEDUCT
               END-IF
               ADD WS-APPLIED-DEDUCT TO WS-DEDUCT-MET
           ELSE
               MOVE 0 TO WS-APPLIED-DEDUCT
           END-IF
           COMPUTE WS-AFTER-DEDUCT =
               WS-ALLOWED-AMT - WS-APPLIED-DEDUCT.
       3500-APPLY-COPAY.
           IF CLM-NETWORK-YES
               MOVE WS-IN-NET-COPAY-PCT TO WS-COPAY-RATE
           ELSE
               MOVE WS-OUT-NET-COPAY-PCT TO WS-COPAY-RATE
           END-IF
           COMPUTE WS-COPAY-AMT =
               WS-AFTER-DEDUCT * WS-COPAY-RATE
           COMPUTE WS-PLAN-PORTION =
               WS-AFTER-DEDUCT - WS-COPAY-AMT
           COMPUTE WS-PATIENT-PORTION =
               WS-APPLIED-DEDUCT + WS-COPAY-AMT.
       3600-FINALIZE-PAYMENT.
           IF WS-PLAN-PORTION <= 0
               MOVE 'DEN' TO PAY-STATUS
               MOVE 'AM001' TO PAY-DENIAL-CODE
               ADD 1 TO WS-TOTAL-DENIED
           ELSE
               MOVE 'PAY' TO PAY-STATUS
               MOVE SPACES TO PAY-DENIAL-CODE
               ADD 1 TO WS-TOTAL-PAID
               ADD WS-PLAN-PORTION TO WS-TOTAL-PAID-AMT
           END-IF
           MOVE WS-ALLOWED-AMT TO PAY-ALLOWED-AMT
           MOVE WS-APPLIED-DEDUCT TO PAY-DEDUCTIBLE
           MOVE WS-COPAY-AMT TO PAY-COPAY-AMT
           MOVE WS-PLAN-PORTION TO PAY-PLAN-PAYS
           MOVE WS-PATIENT-PORTION TO PAY-PATIENT-RESP.
       4000-WRITE-PAYMENT.
           WRITE PAY-RECORD.
       8000-REPORT-TOTALS.
           DISPLAY 'CLAIMS ADJUDICATION SUMMARY'
           DISPLAY '==========================='
           DISPLAY 'CLAIMS READ:     ' WS-TOTAL-READ
           DISPLAY 'CLAIMS PAID:     ' WS-TOTAL-PAID
           DISPLAY 'CLAIMS DENIED:   ' WS-TOTAL-DENIED
           DISPLAY 'TOTAL PAID AMT:  ' WS-TOTAL-PAID-AMT.
       9000-CLOSE-FILES.
           CLOSE CLAIM-FILE
           CLOSE PAYMENT-FILE.
