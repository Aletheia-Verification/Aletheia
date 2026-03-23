       IDENTIFICATION DIVISION.
       PROGRAM-ID. AML-TXN-MONITOR.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT TXN-FILE ASSIGN TO 'TXNFILE'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-TXN-STATUS.
           SELECT ALERT-FILE ASSIGN TO 'AMLALERT'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-ALT-STATUS.
           SELECT SORT-FILE ASSIGN TO 'SORTWORK'.

       DATA DIVISION.
       FILE SECTION.

       FD TXN-FILE.
       01 TXN-RECORD.
           05 TXN-ACCT-ID             PIC X(12).
           05 TXN-DATE                PIC 9(8).
           05 TXN-AMOUNT              PIC S9(11)V99 COMP-3.
           05 TXN-TYPE                PIC X(2).
               88 TXN-CASH-DEP        VALUE 'CD'.
               88 TXN-CASH-WDL        VALUE 'CW'.
               88 TXN-WIRE-IN         VALUE 'WI'.
               88 TXN-WIRE-OUT        VALUE 'WO'.
               88 TXN-ACH-IN          VALUE 'AI'.
               88 TXN-ACH-OUT         VALUE 'AO'.
           05 TXN-COUNTRY-ORIG        PIC X(3).
           05 TXN-NARRATIVE           PIC X(35).

       SD SORT-FILE.
       01 SORT-RECORD.
           05 SR-ACCT-ID              PIC X(12).
           05 SR-DATE                 PIC 9(8).
           05 SR-AMOUNT               PIC S9(11)V99 COMP-3.
           05 SR-TYPE                 PIC X(2).
           05 SR-COUNTRY              PIC X(3).
           05 SR-NARRATIVE            PIC X(35).

       FD ALERT-FILE.
       01 ALERT-RECORD.
           05 ALT-ACCT-ID             PIC X(12).
           05 ALT-RULE-CODE           PIC X(4).
           05 ALT-TOTAL-AMT           PIC S9(13)V99 COMP-3.
           05 ALT-TXN-COUNT           PIC 9(5).
           05 ALT-SEVERITY            PIC X(1).
               88 ALT-HIGH            VALUE 'H'.
               88 ALT-MEDIUM          VALUE 'M'.
               88 ALT-LOW             VALUE 'L'.
           05 ALT-DESCRIPTION         PIC X(60).

       WORKING-STORAGE SECTION.

       01 WS-TXN-STATUS               PIC X(2).
       01 WS-ALT-STATUS               PIC X(2).

       01 WS-EOF-FLAG                 PIC X VALUE 'N'.
           88 WS-EOF                   VALUE 'Y'.

       01 WS-PREV-ACCT                PIC X(12) VALUE SPACES.

       01 WS-ACCT-ACCUM.
           05 WS-CASH-TOTAL           PIC S9(13)V99 COMP-3.
           05 WS-WIRE-TOTAL           PIC S9(13)V99 COMP-3.
           05 WS-TXN-COUNT            PIC 9(5).
           05 WS-CASH-COUNT           PIC 9(5).
           05 WS-HIGH-RISK-CTY-CNT    PIC 9(5).
           05 WS-STRUCTURING-FLAG     PIC X VALUE 'N'.
               88 WS-STRUCTURING      VALUE 'Y'.

       01 WS-THRESHOLDS.
           05 WS-CTR-LIMIT            PIC S9(11)V99 COMP-3
               VALUE 10000.00.
           05 WS-STRUCT-LOWER         PIC S9(11)V99 COMP-3
               VALUE 8000.00.
           05 WS-STRUCT-UPPER         PIC S9(11)V99 COMP-3
               VALUE 10000.00.
           05 WS-VELOCITY-LIMIT       PIC 9(5) VALUE 25.
           05 WS-WIRE-ALERT-AMT       PIC S9(11)V99 COMP-3
               VALUE 50000.00.

       01 WS-HIGH-RISK-COUNTRIES.
           05 WS-HR-CTY OCCURS 5      PIC X(3).
       01 WS-HR-COUNT                 PIC 9(1) VALUE 5.
       01 WS-HR-IDX                   PIC 9(1).

       01 WS-COUNTERS.
           05 WS-TOTAL-TXN            PIC S9(7) COMP-3 VALUE 0.
           05 WS-ALERTS-GEN           PIC S9(7) COMP-3 VALUE 0.
           05 WS-ACCTS-PROCESSED      PIC S9(7) COMP-3 VALUE 0.

       01 WS-DESC-BUF                 PIC X(60).
       01 WS-DESC-PTR                 PIC 9(3).
       01 WS-SPACE-TALLY              PIC 9(3).

       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           SORT SORT-FILE
               ON ASCENDING KEY SR-ACCT-ID SR-DATE
               USING TXN-FILE
               GIVING TXN-FILE
           PERFORM 1100-OPEN-FILES
           PERFORM 1200-READ-FIRST
           PERFORM 2000-PROCESS-TRANSACTION
               UNTIL WS-EOF
           IF WS-PREV-ACCT NOT = SPACES
               PERFORM 3000-CHECK-RULES
           END-IF
           PERFORM 4000-CLOSE-FILES
           PERFORM 5000-DISPLAY-SUMMARY
           STOP RUN.

       1000-INITIALIZE.
           MOVE 'N' TO WS-EOF-FLAG
           MOVE SPACES TO WS-PREV-ACCT
           MOVE 'IRN' TO WS-HR-CTY(1)
           MOVE 'PRK' TO WS-HR-CTY(2)
           MOVE 'SYR' TO WS-HR-CTY(3)
           MOVE 'CUB' TO WS-HR-CTY(4)
           MOVE 'MMR' TO WS-HR-CTY(5)
           PERFORM 1010-RESET-ACCUMULATORS.

       1010-RESET-ACCUMULATORS.
           MOVE 0 TO WS-CASH-TOTAL
           MOVE 0 TO WS-WIRE-TOTAL
           MOVE 0 TO WS-TXN-COUNT
           MOVE 0 TO WS-CASH-COUNT
           MOVE 0 TO WS-HIGH-RISK-CTY-CNT
           MOVE 'N' TO WS-STRUCTURING-FLAG.

       1100-OPEN-FILES.
           OPEN INPUT TXN-FILE
           OPEN OUTPUT ALERT-FILE.

       1200-READ-FIRST.
           READ TXN-FILE
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ
           IF NOT WS-EOF
               MOVE TXN-ACCT-ID TO WS-PREV-ACCT
           END-IF.

       2000-PROCESS-TRANSACTION.
           IF TXN-ACCT-ID NOT = WS-PREV-ACCT
               PERFORM 3000-CHECK-RULES
               PERFORM 1010-RESET-ACCUMULATORS
               MOVE TXN-ACCT-ID TO WS-PREV-ACCT
               ADD 1 TO WS-ACCTS-PROCESSED
           END-IF
           ADD 1 TO WS-TOTAL-TXN
           ADD 1 TO WS-TXN-COUNT
           EVALUATE TRUE
               WHEN TXN-CASH-DEP
                   ADD TXN-AMOUNT TO WS-CASH-TOTAL
                   ADD 1 TO WS-CASH-COUNT
                   IF TXN-AMOUNT >= WS-STRUCT-LOWER
                       AND TXN-AMOUNT < WS-STRUCT-UPPER
                       MOVE 'Y' TO WS-STRUCTURING-FLAG
                   END-IF
               WHEN TXN-CASH-WDL
                   ADD TXN-AMOUNT TO WS-CASH-TOTAL
                   ADD 1 TO WS-CASH-COUNT
               WHEN TXN-WIRE-IN
                   ADD TXN-AMOUNT TO WS-WIRE-TOTAL
               WHEN TXN-WIRE-OUT
                   ADD TXN-AMOUNT TO WS-WIRE-TOTAL
               WHEN OTHER
                   CONTINUE
           END-EVALUATE
           PERFORM 2100-CHECK-HIGH-RISK-COUNTRY
           READ TXN-FILE
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ.

       2100-CHECK-HIGH-RISK-COUNTRY.
           PERFORM VARYING WS-HR-IDX FROM 1 BY 1
               UNTIL WS-HR-IDX > WS-HR-COUNT
               IF TXN-COUNTRY-ORIG = WS-HR-CTY(WS-HR-IDX)
                   ADD 1 TO WS-HIGH-RISK-CTY-CNT
               END-IF
           END-PERFORM.

       3000-CHECK-RULES.
           PERFORM 3100-CHECK-CTR-RULE
           PERFORM 3200-CHECK-STRUCTURING
           PERFORM 3300-CHECK-VELOCITY
           PERFORM 3400-CHECK-WIRE-THRESHOLD
           PERFORM 3500-CHECK-HIGH-RISK.

       3100-CHECK-CTR-RULE.
           IF WS-CASH-TOTAL > WS-CTR-LIMIT
               MOVE SPACES TO WS-DESC-BUF
               MOVE 1 TO WS-DESC-PTR
               STRING 'CASH TOTAL EXCEEDS CTR LIMIT '
                   DELIMITED BY SIZE
                   INTO WS-DESC-BUF
                   WITH POINTER WS-DESC-PTR
               END-STRING
               MOVE WS-PREV-ACCT TO ALT-ACCT-ID
               MOVE 'CTR ' TO ALT-RULE-CODE
               MOVE WS-CASH-TOTAL TO ALT-TOTAL-AMT
               MOVE WS-CASH-COUNT TO ALT-TXN-COUNT
               MOVE 'H' TO ALT-SEVERITY
               MOVE WS-DESC-BUF TO ALT-DESCRIPTION
               WRITE ALERT-RECORD
               ADD 1 TO WS-ALERTS-GEN
           END-IF.

       3200-CHECK-STRUCTURING.
           IF WS-STRUCTURING
               MOVE SPACES TO WS-DESC-BUF
               MOVE 1 TO WS-DESC-PTR
               STRING 'POSSIBLE STRUCTURING DETECTED '
                   DELIMITED BY SIZE
                   INTO WS-DESC-BUF
                   WITH POINTER WS-DESC-PTR
               END-STRING
               MOVE WS-PREV-ACCT TO ALT-ACCT-ID
               MOVE 'STRC' TO ALT-RULE-CODE
               MOVE WS-CASH-TOTAL TO ALT-TOTAL-AMT
               MOVE WS-CASH-COUNT TO ALT-TXN-COUNT
               MOVE 'H' TO ALT-SEVERITY
               MOVE WS-DESC-BUF TO ALT-DESCRIPTION
               WRITE ALERT-RECORD
               ADD 1 TO WS-ALERTS-GEN
           END-IF.

       3300-CHECK-VELOCITY.
           IF WS-TXN-COUNT > WS-VELOCITY-LIMIT
               MOVE WS-PREV-ACCT TO ALT-ACCT-ID
               MOVE 'VELC' TO ALT-RULE-CODE
               MOVE 0 TO ALT-TOTAL-AMT
               MOVE WS-TXN-COUNT TO ALT-TXN-COUNT
               MOVE 'M' TO ALT-SEVERITY
               MOVE 'HIGH TRANSACTION VELOCITY'
                   TO ALT-DESCRIPTION
               WRITE ALERT-RECORD
               ADD 1 TO WS-ALERTS-GEN
           END-IF.

       3400-CHECK-WIRE-THRESHOLD.
           IF WS-WIRE-TOTAL > WS-WIRE-ALERT-AMT
               MOVE WS-PREV-ACCT TO ALT-ACCT-ID
               MOVE 'WIRE' TO ALT-RULE-CODE
               MOVE WS-WIRE-TOTAL TO ALT-TOTAL-AMT
               MOVE WS-TXN-COUNT TO ALT-TXN-COUNT
               MOVE 'M' TO ALT-SEVERITY
               MOVE 'WIRE VOLUME EXCEEDS THRESHOLD'
                   TO ALT-DESCRIPTION
               WRITE ALERT-RECORD
               ADD 1 TO WS-ALERTS-GEN
           END-IF.

       3500-CHECK-HIGH-RISK.
           IF WS-HIGH-RISK-CTY-CNT > 0
               MOVE SPACES TO WS-DESC-BUF
               MOVE 0 TO WS-SPACE-TALLY
               INSPECT WS-PREV-ACCT
                   TALLYING WS-SPACE-TALLY FOR ALL ' '
               MOVE WS-PREV-ACCT TO ALT-ACCT-ID
               MOVE 'HRSK' TO ALT-RULE-CODE
               MOVE 0 TO ALT-TOTAL-AMT
               MOVE WS-HIGH-RISK-CTY-CNT TO ALT-TXN-COUNT
               MOVE 'H' TO ALT-SEVERITY
               MOVE 'TRANSACTIONS FROM HIGH-RISK COUNTRIES'
                   TO ALT-DESCRIPTION
               WRITE ALERT-RECORD
               ADD 1 TO WS-ALERTS-GEN
           END-IF.

       4000-CLOSE-FILES.
           CLOSE TXN-FILE
           CLOSE ALERT-FILE.

       5000-DISPLAY-SUMMARY.
           DISPLAY 'AML TRANSACTION MONITORING COMPLETE'
           DISPLAY 'TRANSACTIONS READ:   ' WS-TOTAL-TXN
           DISPLAY 'ACCOUNTS PROCESSED:  ' WS-ACCTS-PROCESSED
           DISPLAY 'ALERTS GENERATED:    ' WS-ALERTS-GEN.
