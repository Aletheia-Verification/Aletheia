       IDENTIFICATION DIVISION.
       PROGRAM-ID. INS-GRACE-PERIOD.
      *================================================================
      * INSURANCE GRACE PERIOD MANAGER
      * Tracks premium payment grace periods, sends graduated notices,
      * and processes automatic premium loan provisions.
      *================================================================
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT POLICY-FILE ASSIGN TO 'GRACEPOL'
               FILE STATUS IS WS-POL-FS.
           SELECT NOTICE-FILE ASSIGN TO 'GRACENOTICE'
               FILE STATUS IS WS-NTC-FS.
       DATA DIVISION.
       FILE SECTION.
       FD POLICY-FILE.
       01 PF-RECORD.
           05 PF-POL-NUM              PIC X(12).
           05 PF-PREM-DUE-DATE        PIC 9(8).
           05 PF-PREMIUM-AMT          PIC S9(7)V99 COMP-3.
           05 PF-CASH-VALUE           PIC S9(9)V99 COMP-3.
           05 PF-LOAN-BALANCE         PIC S9(9)V99 COMP-3.
           05 PF-APL-ENABLED          PIC X(1).
               88 APL-YES             VALUE 'Y'.
               88 APL-NO              VALUE 'N'.
           05 PF-PAY-MODE             PIC X(1).
               88 PM-MONTHLY          VALUE 'M'.
               88 PM-QUARTERLY        VALUE 'Q'.
               88 PM-ANNUAL           VALUE 'A'.
       FD NOTICE-FILE.
       01 NF-RECORD.
           05 NF-POL-NUM              PIC X(12).
           05 NF-NOTICE-TYPE          PIC X(10).
           05 NF-DAYS-OVERDUE         PIC 9(3).
           05 NF-ACTION-TAKEN         PIC X(15).
           05 NF-AMOUNT-DUE           PIC S9(7)V99 COMP-3.
       WORKING-STORAGE SECTION.
       01 WS-FILE-STATUS.
           05 WS-POL-FS              PIC X(2).
           05 WS-NTC-FS              PIC X(2).
       01 WS-EOF-FLAG                PIC X VALUE 'N'.
           88 WS-EOF                 VALUE 'Y'.
       01 WS-CURRENT-DATE            PIC 9(8).
       01 WS-DAYS-OVERDUE            PIC S9(5) COMP-3.
       01 WS-GRACE-DAYS              PIC 9(2) VALUE 31.
       01 WS-NOTICE-THRESHOLDS.
           05 WS-FIRST-NOTICE        PIC 9(2) VALUE 10.
           05 WS-SECOND-NOTICE       PIC 9(2) VALUE 20.
           05 WS-FINAL-NOTICE        PIC 9(2) VALUE 28.
       01 WS-CALC.
           05 WS-NOTICE-TYPE         PIC X(10).
           05 WS-ACTION-TAKEN        PIC X(15).
           05 WS-AVL-FOR-APL         PIC S9(9)V99 COMP-3.
           05 WS-APL-POSSIBLE        PIC X VALUE 'N'.
               88 APL-CAN-PAY        VALUE 'Y'.
           05 WS-LATE-FEE-RATE       PIC S9(1)V9(4) COMP-3
               VALUE 0.0200.
           05 WS-LATE-FEE            PIC S9(5)V99 COMP-3.
           05 WS-TOTAL-DUE           PIC S9(7)V99 COMP-3.
       01 WS-COUNTERS.
           05 WS-READ-COUNT          PIC 9(5) VALUE 0.
           05 WS-IN-GRACE            PIC 9(5) VALUE 0.
           05 WS-APL-APPLIED         PIC 9(5) VALUE 0.
           05 WS-LAPSED              PIC 9(5) VALUE 0.
           05 WS-NOTICES-SENT        PIC 9(5) VALUE 0.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-OPEN-FILES
           PERFORM 1500-READ-POLICY
           PERFORM 2000-PROCESS-POLICIES
               UNTIL WS-EOF
           PERFORM 8000-DISPLAY-SUMMARY
           PERFORM 9000-CLOSE-FILES
           STOP RUN.
       1000-OPEN-FILES.
           OPEN INPUT POLICY-FILE
           OPEN OUTPUT NOTICE-FILE
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD.
       1500-READ-POLICY.
           READ POLICY-FILE
               AT END
                   MOVE 'Y' TO WS-EOF-FLAG
           END-READ
           IF NOT WS-EOF
               ADD 1 TO WS-READ-COUNT
           END-IF.
       2000-PROCESS-POLICIES.
           COMPUTE WS-DAYS-OVERDUE =
               WS-CURRENT-DATE - PF-PREM-DUE-DATE
           IF WS-DAYS-OVERDUE > 0
               ADD 1 TO WS-IN-GRACE
               PERFORM 3000-DETERMINE-NOTICE
               PERFORM 4000-CALC-LATE-FEE
               IF WS-DAYS-OVERDUE > WS-GRACE-DAYS
                   PERFORM 5000-GRACE-EXPIRED
               ELSE
                   PERFORM 6000-WRITE-NOTICE
               END-IF
           END-IF
           PERFORM 1500-READ-POLICY.
       3000-DETERMINE-NOTICE.
           EVALUATE TRUE
               WHEN WS-DAYS-OVERDUE <=
                   WS-FIRST-NOTICE
                   MOVE 'REMINDER  ' TO WS-NOTICE-TYPE
               WHEN WS-DAYS-OVERDUE <=
                   WS-SECOND-NOTICE
                   MOVE 'WARNING   ' TO WS-NOTICE-TYPE
               WHEN WS-DAYS-OVERDUE <=
                   WS-FINAL-NOTICE
                   MOVE 'FINAL     ' TO WS-NOTICE-TYPE
               WHEN OTHER
                   MOVE 'LAPSE WARN' TO WS-NOTICE-TYPE
           END-EVALUATE.
       4000-CALC-LATE-FEE.
           IF WS-DAYS-OVERDUE > WS-FIRST-NOTICE
               COMPUTE WS-LATE-FEE =
                   PF-PREMIUM-AMT * WS-LATE-FEE-RATE
           ELSE
               MOVE 0 TO WS-LATE-FEE
           END-IF
           COMPUTE WS-TOTAL-DUE =
               PF-PREMIUM-AMT + WS-LATE-FEE.
       5000-GRACE-EXPIRED.
           IF APL-YES
               COMPUTE WS-AVL-FOR-APL =
                   PF-CASH-VALUE - PF-LOAN-BALANCE
               IF WS-AVL-FOR-APL >= WS-TOTAL-DUE
                   MOVE 'Y' TO WS-APL-POSSIBLE
                   MOVE 'APL APPLIED    ' TO WS-ACTION-TAKEN
                   ADD 1 TO WS-APL-APPLIED
               ELSE
                   MOVE 'N' TO WS-APL-POSSIBLE
                   MOVE 'LAPSED         ' TO WS-ACTION-TAKEN
                   ADD 1 TO WS-LAPSED
               END-IF
           ELSE
               MOVE 'LAPSED         ' TO WS-ACTION-TAKEN
               ADD 1 TO WS-LAPSED
           END-IF
           PERFORM 6000-WRITE-NOTICE.
       6000-WRITE-NOTICE.
           MOVE PF-POL-NUM TO NF-POL-NUM
           MOVE WS-NOTICE-TYPE TO NF-NOTICE-TYPE
           MOVE WS-DAYS-OVERDUE TO NF-DAYS-OVERDUE
           IF WS-DAYS-OVERDUE > WS-GRACE-DAYS
               MOVE WS-ACTION-TAKEN TO NF-ACTION-TAKEN
           ELSE
               MOVE 'IN GRACE       ' TO NF-ACTION-TAKEN
           END-IF
           MOVE WS-TOTAL-DUE TO NF-AMOUNT-DUE
           WRITE NF-RECORD
           ADD 1 TO WS-NOTICES-SENT.
       8000-DISPLAY-SUMMARY.
           DISPLAY 'GRACE PERIOD PROCESSING SUMMARY'
           DISPLAY '================================'
           DISPLAY 'POLICIES READ:   ' WS-READ-COUNT
           DISPLAY 'IN GRACE PERIOD: ' WS-IN-GRACE
           DISPLAY 'APL APPLIED:     ' WS-APL-APPLIED
           DISPLAY 'LAPSED:          ' WS-LAPSED
           DISPLAY 'NOTICES SENT:    ' WS-NOTICES-SENT.
       9000-CLOSE-FILES.
           CLOSE POLICY-FILE
           CLOSE NOTICE-FILE.
