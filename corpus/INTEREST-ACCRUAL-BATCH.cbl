       IDENTIFICATION DIVISION.
       PROGRAM-ID. INTEREST-ACCRUAL-BATCH.
      *================================================================*
      * Daily Interest Accrual Batch                                   *
      * Reads account portfolio, applies tiered interest rates,        *
      * performs multi-day catch-up accrual, writes updated records.   *
      *================================================================*

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ACCOUNT-INPUT ASSIGN TO "ACCT-IN.DAT"
               FILE STATUS IS WS-IN-STATUS.
           SELECT ACCOUNT-OUTPUT ASSIGN TO "ACCT-OUT.DAT"
               FILE STATUS IS WS-OUT-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  ACCOUNT-INPUT.
       01  ACCT-IN-RECORD.
           05  AI-ACCOUNT-NUM        PIC 9(10).
           05  AI-ACCOUNT-TYPE       PIC X(2).
           05  AI-BALANCE            PIC 9(11)V99.
           05  AI-RATE-CODE          PIC 9(2).
           05  AI-LAST-ACCRUAL-DATE  PIC 9(8).
           05  AI-ACCRUED-INT        PIC 9(9)V99.
           05  AI-MIN-BALANCE        PIC 9(11)V99.
           05  AI-FILLER             PIC X(23).

       FD  ACCOUNT-OUTPUT.
       01  ACCT-OUT-RECORD.
           05  AO-ACCOUNT-NUM        PIC 9(10).
           05  AO-ACCOUNT-TYPE       PIC X(2).
           05  AO-BALANCE            PIC 9(11)V99.
           05  AO-RATE-CODE          PIC 9(2).
           05  AO-LAST-ACCRUAL-DATE  PIC 9(8).
           05  AO-ACCRUED-INT        PIC 9(9)V99.
           05  AO-MIN-BALANCE        PIC 9(11)V99.
           05  AO-FILLER             PIC X(23).

       WORKING-STORAGE SECTION.

      *--- File Control ---*
       01  WS-IN-STATUS              PIC XX.
       01  WS-OUT-STATUS             PIC XX.
       01  WS-EOF-FLAG               PIC 9 VALUE 0.

      *--- Account Table ---*
       01  WS-ACCOUNT-TABLE.
           05  WS-ACCT-ENTRY OCCURS 100.
               10  WA-ACCOUNT-NUM    PIC 9(10).
               10  WA-BALANCE        PIC S9(13)V99 COMP-3.
               10  WA-ANNUAL-RATE    PIC S9(3)V9(6) COMP-3.
               10  WA-DAILY-RATE     PIC S9(1)V9(8) COMP-3.
               10  WA-ACCRUED        PIC S9(11)V99 COMP-3.
               10  WA-DAYS-BEHIND    PIC S9(3) COMP-3.
               10  WA-MIN-BAL        PIC S9(13)V99 COMP-3.
               10  WA-ACTIVE         PIC 9.

      *--- Processing Fields ---*
       01  WS-CURRENT-DATE           PIC 9(8).
       01  WS-PROCESS-DATE           PIC 9(8).
       01  WS-ACCT-INDEX             PIC S9(5) COMP-3.
       01  WS-ACCT-COUNT             PIC S9(5) COMP-3.
       01  WS-DAY-INDEX              PIC S9(3) COMP-3.
       01  WS-DAYS-TO-ACCRUE         PIC S9(3) COMP-3.
       01  WS-LOOP-INDEX             PIC S9(5) COMP-3.

      *--- Interest Calculation ---*
       01  WS-DAILY-AMOUNT           PIC S9(9)V9(4) COMP-3.
       01  WS-PERIOD-ACCRUAL         PIC S9(11)V99 COMP-3.
       01  WS-ACCRUAL-CAP            PIC S9(11)V99 COMP-3.
       01  WS-TIER-RATE              PIC S9(3)V9(6) COMP-3.
       01  WS-MIN-BAL-REQUIRED       PIC S9(11)V99 COMP-3.

      *--- Totals ---*
       01  WS-TOTAL-ACCRUED          PIC S9(13)V99 COMP-3.
       01  WS-TOTAL-ACCOUNTS         PIC S9(5) COMP-3.
       01  WS-SKIPPED-ACCOUNTS       PIC S9(5) COMP-3.
       01  WS-CAPPED-ACCOUNTS        PIC S9(5) COMP-3.
       01  WS-CAPITALIZED-COUNT      PIC S9(5) COMP-3.
       01  WS-RECORDS-WRITTEN        PIC S9(5) COMP-3.

      *--- Month-End Detection ---*
       01  WS-CURRENT-DAY            PIC 9(2).
       01  WS-MONTH-END-FLAG         PIC 9.

      *--- Display ---*
       01  WS-DISP-AMOUNT            PIC $$$,$$$,$$9.99.
       01  WS-DISP-COUNT             PIC Z,ZZ9.
       01  WS-DISP-RATE              PIC Z9.999999.

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-ACCOUNTS
           PERFORM 3000-ACCRUE-INTEREST
           PERFORM 4000-WRITE-UPDATED
           PERFORM 5000-DISPLAY-SUMMARY
           STOP RUN.

       1000-INITIALIZE.
           MOVE 0 TO WS-ACCT-COUNT
           MOVE 0 TO WS-TOTAL-ACCRUED
           MOVE 0 TO WS-TOTAL-ACCOUNTS
           MOVE 0 TO WS-SKIPPED-ACCOUNTS
           MOVE 0 TO WS-CAPPED-ACCOUNTS
           MOVE 0 TO WS-CAPITALIZED-COUNT
           MOVE 0 TO WS-RECORDS-WRITTEN
           MOVE 0 TO WS-MONTH-END-FLAG
           MOVE 20260315 TO WS-CURRENT-DATE
           MOVE 15 TO WS-CURRENT-DAY
           MOVE 500000.00 TO WS-ACCRUAL-CAP
           MOVE 100.00 TO WS-MIN-BAL-REQUIRED
           PERFORM VARYING WS-LOOP-INDEX FROM 1 BY 1
               UNTIL WS-LOOP-INDEX > 100
               MOVE 0 TO WA-ACTIVE(WS-LOOP-INDEX)
               MOVE 0 TO WA-BALANCE(WS-LOOP-INDEX)
               MOVE 0 TO WA-ACCRUED(WS-LOOP-INDEX)
           END-PERFORM.

       2000-LOAD-ACCOUNTS.
           OPEN INPUT ACCOUNT-INPUT
           MOVE 0 TO WS-EOF-FLAG
           PERFORM 2100-READ-ACCOUNT
           PERFORM UNTIL WS-EOF-FLAG = 1
               IF WS-ACCT-COUNT < 100
                   ADD 1 TO WS-ACCT-COUNT
                   PERFORM 2200-STORE-ACCOUNT
               END-IF
               PERFORM 2100-READ-ACCOUNT
           END-PERFORM
           CLOSE ACCOUNT-INPUT.

       2100-READ-ACCOUNT.
           READ ACCOUNT-INPUT
               AT END
                   MOVE 1 TO WS-EOF-FLAG
           END-READ
           IF WS-EOF-FLAG = 0
               ADD 1 TO WS-TOTAL-ACCOUNTS
           END-IF.

       2200-STORE-ACCOUNT.
           MOVE AI-ACCOUNT-NUM TO
               WA-ACCOUNT-NUM(WS-ACCT-COUNT)
           MOVE AI-BALANCE TO WA-BALANCE(WS-ACCT-COUNT)
           MOVE AI-ACCRUED-INT TO WA-ACCRUED(WS-ACCT-COUNT)
           MOVE AI-MIN-BALANCE TO WA-MIN-BAL(WS-ACCT-COUNT)
           MOVE 1 TO WA-ACTIVE(WS-ACCT-COUNT)
           PERFORM 2300-DETERMINE-RATE
           DIVIDE WA-ANNUAL-RATE(WS-ACCT-COUNT) BY 36500
               GIVING WA-DAILY-RATE(WS-ACCT-COUNT)
           END-DIVIDE
           MOVE 1 TO WA-DAYS-BEHIND(WS-ACCT-COUNT).

       2300-DETERMINE-RATE.
           IF WA-BALANCE(WS-ACCT-COUNT) < 10000
               MOVE 0.500000 TO
                   WA-ANNUAL-RATE(WS-ACCT-COUNT)
           ELSE
               IF WA-BALANCE(WS-ACCT-COUNT) < 50000
                   MOVE 1.250000 TO
                       WA-ANNUAL-RATE(WS-ACCT-COUNT)
               ELSE
                   IF WA-BALANCE(WS-ACCT-COUNT) < 100000
                       MOVE 2.100000 TO
                           WA-ANNUAL-RATE(WS-ACCT-COUNT)
                   ELSE
                       MOVE 3.500000 TO
                           WA-ANNUAL-RATE(WS-ACCT-COUNT)
                   END-IF
               END-IF
           END-IF.

       3000-ACCRUE-INTEREST.
           PERFORM VARYING WS-ACCT-INDEX FROM 1 BY 1
               UNTIL WS-ACCT-INDEX > WS-ACCT-COUNT
               IF WA-ACTIVE(WS-ACCT-INDEX) = 1
                   PERFORM 3100-CHECK-MINIMUM-BALANCE
               END-IF
           END-PERFORM.

       3100-CHECK-MINIMUM-BALANCE.
           IF WA-BALANCE(WS-ACCT-INDEX) < WS-MIN-BAL-REQUIRED
               ADD 1 TO WS-SKIPPED-ACCOUNTS
           ELSE
               MOVE WA-DAYS-BEHIND(WS-ACCT-INDEX)
                   TO WS-DAYS-TO-ACCRUE
               PERFORM 3200-MULTI-DAY-ACCRUAL
           END-IF.

       3200-MULTI-DAY-ACCRUAL.
           MOVE 0 TO WS-PERIOD-ACCRUAL
           PERFORM WS-DAYS-TO-ACCRUE TIMES
               COMPUTE WS-DAILY-AMOUNT =
                   WA-BALANCE(WS-ACCT-INDEX)
                   * WA-DAILY-RATE(WS-ACCT-INDEX)
               ADD WS-DAILY-AMOUNT TO WS-PERIOD-ACCRUAL
               ADD WS-DAILY-AMOUNT TO WA-ACCRUED(WS-ACCT-INDEX)
           END-PERFORM
           IF WA-ACCRUED(WS-ACCT-INDEX) > WS-ACCRUAL-CAP
               MOVE WS-ACCRUAL-CAP TO
                   WA-ACCRUED(WS-ACCT-INDEX)
               ADD 1 TO WS-CAPPED-ACCOUNTS
           END-IF
           ADD WS-PERIOD-ACCRUAL TO WS-TOTAL-ACCRUED
           PERFORM 3300-CHECK-MONTH-END.

       3300-CHECK-MONTH-END.
           IF WS-MONTH-END-FLAG = 1
               ADD WA-ACCRUED(WS-ACCT-INDEX) TO
                   WA-BALANCE(WS-ACCT-INDEX)
               MOVE 0 TO WA-ACCRUED(WS-ACCT-INDEX)
               ADD 1 TO WS-CAPITALIZED-COUNT
           END-IF.

       4000-WRITE-UPDATED.
           OPEN OUTPUT ACCOUNT-OUTPUT
           PERFORM VARYING WS-ACCT-INDEX FROM 1 BY 1
               UNTIL WS-ACCT-INDEX > WS-ACCT-COUNT
               IF WA-ACTIVE(WS-ACCT-INDEX) = 1
                   PERFORM 4100-FORMAT-OUTPUT
               END-IF
           END-PERFORM
           CLOSE ACCOUNT-OUTPUT.

       4100-FORMAT-OUTPUT.
           MOVE WA-ACCOUNT-NUM(WS-ACCT-INDEX)
               TO AO-ACCOUNT-NUM
           MOVE "SA" TO AO-ACCOUNT-TYPE
           MOVE WA-BALANCE(WS-ACCT-INDEX) TO AO-BALANCE
           MOVE 1 TO AO-RATE-CODE
           MOVE WS-CURRENT-DATE TO AO-LAST-ACCRUAL-DATE
           MOVE WA-ACCRUED(WS-ACCT-INDEX) TO AO-ACCRUED-INT
           MOVE WA-MIN-BAL(WS-ACCT-INDEX) TO AO-MIN-BALANCE
           MOVE SPACES TO AO-FILLER
           WRITE ACCT-OUT-RECORD FROM ACCT-OUT-RECORD
           ADD 1 TO WS-RECORDS-WRITTEN.

       5000-DISPLAY-SUMMARY.
           DISPLAY "=== INTEREST ACCRUAL BATCH SUMMARY ==="
           MOVE WS-TOTAL-ACCOUNTS TO WS-DISP-COUNT
           DISPLAY "ACCOUNTS READ:     " WS-DISP-COUNT
           MOVE WS-ACCT-COUNT TO WS-DISP-COUNT
           DISPLAY "ACCOUNTS LOADED:   " WS-DISP-COUNT
           MOVE WS-SKIPPED-ACCOUNTS TO WS-DISP-COUNT
           DISPLAY "BELOW MINIMUM:     " WS-DISP-COUNT
           MOVE WS-CAPPED-ACCOUNTS TO WS-DISP-COUNT
           DISPLAY "ACCRUAL CAPPED:    " WS-DISP-COUNT
           MOVE WS-CAPITALIZED-COUNT TO WS-DISP-COUNT
           DISPLAY "CAPITALIZED:       " WS-DISP-COUNT
           MOVE WS-TOTAL-ACCRUED TO WS-DISP-AMOUNT
           DISPLAY "TOTAL ACCRUED:     " WS-DISP-AMOUNT
           MOVE WS-RECORDS-WRITTEN TO WS-DISP-COUNT
           DISPLAY "RECORDS WRITTEN:   " WS-DISP-COUNT
           DISPLAY "=== END BATCH SUMMARY ===".
