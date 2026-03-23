       IDENTIFICATION DIVISION.
       PROGRAM-ID. POLICY-RENEW-PROC.
      *================================================================
      * POLICY RENEWAL BATCH PROCESSOR
      * Reads policy master file, applies renewal pricing rules,
      * writes renewed policies to output and rejection report.
      *================================================================
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT POLICY-FILE ASSIGN TO 'POLMAST'
               FILE STATUS IS WS-POL-FS.
           SELECT RENEW-FILE ASSIGN TO 'POLRNEW'
               FILE STATUS IS WS-RNW-FS.
           SELECT REJECT-FILE ASSIGN TO 'POLRJCT'
               FILE STATUS IS WS-RJT-FS.
       DATA DIVISION.
       FILE SECTION.
       FD POLICY-FILE.
       01 POL-RECORD.
           05 POL-NUMBER               PIC X(12).
           05 POL-LINE-OF-BUS          PIC X(3).
               88 LOB-LIFE             VALUE 'LIF'.
               88 LOB-AUTO             VALUE 'AUT'.
               88 LOB-HOME             VALUE 'HOM'.
               88 LOB-HEALTH           VALUE 'HLT'.
           05 POL-EFF-DATE             PIC 9(8).
           05 POL-EXP-DATE             PIC 9(8).
           05 POL-ANNUAL-PREM          PIC S9(7)V99 COMP-3.
           05 POL-CLAIM-COUNT          PIC 9(3).
           05 POL-RISK-TIER            PIC 9(1).
           05 POL-HOLDER-STATE         PIC X(2).
       FD RENEW-FILE.
       01 RNW-RECORD.
           05 RNW-NUMBER               PIC X(12).
           05 RNW-LINE-OF-BUS          PIC X(3).
           05 RNW-OLD-PREMIUM          PIC S9(7)V99 COMP-3.
           05 RNW-NEW-PREMIUM          PIC S9(7)V99 COMP-3.
           05 RNW-EFF-DATE             PIC 9(8).
           05 RNW-CHANGE-PCT           PIC S9(3)V99 COMP-3.
       FD REJECT-FILE.
       01 RJT-RECORD.
           05 RJT-NUMBER               PIC X(12).
           05 RJT-REASON               PIC X(30).
       WORKING-STORAGE SECTION.
       01 WS-FILE-STATUS.
           05 WS-POL-FS               PIC X(2).
           05 WS-RNW-FS               PIC X(2).
           05 WS-RJT-FS               PIC X(2).
       01 WS-FLAGS.
           05 WS-EOF-FLAG             PIC X VALUE 'N'.
               88 WS-EOF              VALUE 'Y'.
           05 WS-REJECT-FLAG          PIC X VALUE 'N'.
               88 WS-REJECTED         VALUE 'Y'.
       01 WS-COUNTERS.
           05 WS-READ-COUNT           PIC 9(7) VALUE 0.
           05 WS-RENEW-COUNT          PIC 9(7) VALUE 0.
           05 WS-REJECT-COUNT         PIC 9(7) VALUE 0.
       01 WS-CALC-FIELDS.
           05 WS-BASE-FACTOR          PIC S9(1)V9(4) COMP-3.
           05 WS-CLAIM-SURCHARGE      PIC S9(1)V9(4) COMP-3.
           05 WS-TIER-FACTOR          PIC S9(1)V9(4) COMP-3.
           05 WS-STATE-LOAD           PIC S9(1)V9(4) COMP-3.
           05 WS-CALC-PREMIUM         PIC S9(7)V99 COMP-3.
           05 WS-MAX-INCREASE         PIC S9(3)V99 COMP-3
               VALUE 25.00.
           05 WS-CHANGE-AMT           PIC S9(7)V99 COMP-3.
           05 WS-CHANGE-PCT           PIC S9(3)V99 COMP-3.
       01 WS-CURRENT-DATE             PIC 9(8).
       01 WS-IDX                       PIC 9(3).
       01 WS-TIER-TABLE.
           05 WS-TIER-RATE OCCURS 5 TIMES
                                       PIC S9(1)V9(4) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-OPEN-FILES
           PERFORM 1100-INIT-TABLES
           PERFORM 2000-READ-POLICY
           PERFORM 3000-PROCESS-POLICIES
               UNTIL WS-EOF
           PERFORM 8000-DISPLAY-TOTALS
           PERFORM 9000-CLOSE-FILES
           STOP RUN.
       1000-OPEN-FILES.
           OPEN INPUT POLICY-FILE
           OPEN OUTPUT RENEW-FILE
           OPEN OUTPUT REJECT-FILE
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD.
       1100-INIT-TABLES.
           MOVE 0.9500 TO WS-TIER-RATE(1)
           MOVE 1.0000 TO WS-TIER-RATE(2)
           MOVE 1.0500 TO WS-TIER-RATE(3)
           MOVE 1.1500 TO WS-TIER-RATE(4)
           MOVE 1.3000 TO WS-TIER-RATE(5).
       2000-READ-POLICY.
           READ POLICY-FILE
               AT END
                   MOVE 'Y' TO WS-EOF-FLAG
           END-READ
           IF NOT WS-EOF
               ADD 1 TO WS-READ-COUNT
           END-IF.
       3000-PROCESS-POLICIES.
           MOVE 'N' TO WS-REJECT-FLAG
           PERFORM 3100-VALIDATE-POLICY
           IF WS-REJECTED
               PERFORM 5000-WRITE-REJECT
           ELSE
               PERFORM 4000-CALCULATE-RENEWAL
               IF WS-CHANGE-PCT > WS-MAX-INCREASE
                   MOVE 'EXCEEDS MAX RATE INCREASE'
                       TO RJT-REASON
                   MOVE 'Y' TO WS-REJECT-FLAG
                   PERFORM 5000-WRITE-REJECT
               ELSE
                   PERFORM 6000-WRITE-RENEWAL
               END-IF
           END-IF
           PERFORM 2000-READ-POLICY.
       3100-VALIDATE-POLICY.
           IF POL-EXP-DATE < WS-CURRENT-DATE
               MOVE 'POLICY ALREADY EXPIRED'
                   TO RJT-REASON
               MOVE 'Y' TO WS-REJECT-FLAG
           END-IF
           IF POL-ANNUAL-PREM <= 0
               MOVE 'ZERO OR NEGATIVE PREMIUM'
                   TO RJT-REASON
               MOVE 'Y' TO WS-REJECT-FLAG
           END-IF.
       4000-CALCULATE-RENEWAL.
           EVALUATE TRUE
               WHEN LOB-LIFE
                   MOVE 1.0350 TO WS-BASE-FACTOR
               WHEN LOB-AUTO
                   MOVE 1.0500 TO WS-BASE-FACTOR
               WHEN LOB-HOME
                   MOVE 1.0400 TO WS-BASE-FACTOR
               WHEN LOB-HEALTH
                   MOVE 1.0700 TO WS-BASE-FACTOR
               WHEN OTHER
                   MOVE 1.0300 TO WS-BASE-FACTOR
           END-EVALUATE
           IF POL-CLAIM-COUNT = 0
               MOVE 1.0000 TO WS-CLAIM-SURCHARGE
           ELSE
               IF POL-CLAIM-COUNT < 3
                   MOVE 1.0500 TO WS-CLAIM-SURCHARGE
               ELSE
                   MOVE 1.1500 TO WS-CLAIM-SURCHARGE
               END-IF
           END-IF
           IF POL-RISK-TIER >= 1 AND POL-RISK-TIER <= 5
               MOVE WS-TIER-RATE(POL-RISK-TIER)
                   TO WS-TIER-FACTOR
           ELSE
               MOVE 1.0000 TO WS-TIER-FACTOR
           END-IF
           EVALUATE POL-HOLDER-STATE
               WHEN 'FL'
                   MOVE 1.0800 TO WS-STATE-LOAD
               WHEN 'CA'
                   MOVE 1.0600 TO WS-STATE-LOAD
               WHEN 'TX'
                   MOVE 1.0300 TO WS-STATE-LOAD
               WHEN 'NY'
                   MOVE 1.0700 TO WS-STATE-LOAD
               WHEN OTHER
                   MOVE 1.0000 TO WS-STATE-LOAD
           END-EVALUATE
           COMPUTE WS-CALC-PREMIUM =
               POL-ANNUAL-PREM
               * WS-BASE-FACTOR
               * WS-CLAIM-SURCHARGE
               * WS-TIER-FACTOR
               * WS-STATE-LOAD
           COMPUTE WS-CHANGE-AMT =
               WS-CALC-PREMIUM - POL-ANNUAL-PREM
           IF POL-ANNUAL-PREM > 0
               COMPUTE WS-CHANGE-PCT =
                   (WS-CHANGE-AMT / POL-ANNUAL-PREM) * 100
           ELSE
               MOVE 0 TO WS-CHANGE-PCT
           END-IF.
       5000-WRITE-REJECT.
           MOVE POL-NUMBER TO RJT-NUMBER
           WRITE RJT-RECORD
           ADD 1 TO WS-REJECT-COUNT.
       6000-WRITE-RENEWAL.
           MOVE POL-NUMBER TO RNW-NUMBER
           MOVE POL-LINE-OF-BUS TO RNW-LINE-OF-BUS
           MOVE POL-ANNUAL-PREM TO RNW-OLD-PREMIUM
           MOVE WS-CALC-PREMIUM TO RNW-NEW-PREMIUM
           MOVE POL-EXP-DATE TO RNW-EFF-DATE
           MOVE WS-CHANGE-PCT TO RNW-CHANGE-PCT
           WRITE RNW-RECORD
           ADD 1 TO WS-RENEW-COUNT.
       8000-DISPLAY-TOTALS.
           DISPLAY 'POLICY RENEWAL BATCH COMPLETE'
           DISPLAY '=============================='
           DISPLAY 'POLICIES READ:    ' WS-READ-COUNT
           DISPLAY 'POLICIES RENEWED: ' WS-RENEW-COUNT
           DISPLAY 'POLICIES REJECTED:' WS-REJECT-COUNT.
       9000-CLOSE-FILES.
           CLOSE POLICY-FILE
           CLOSE RENEW-FILE
           CLOSE REJECT-FILE.
