       IDENTIFICATION DIVISION.
       PROGRAM-ID. CHECK-HOLD-POLICY.
      *================================================================*
      * Check Hold Policy Engine (Reg CC Compliance)                   *
      * Determines hold periods based on check type, amount,           *
      * account age, and exception conditions per Regulation CC.       *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- Deposit Info ---
       01  WS-DEPOSIT-TABLE.
           05  WS-DEP-ENTRY OCCURS 8 TIMES.
               10  WS-DEP-CHK-TYPE   PIC 9.
               10  WS-DEP-AMOUNT     PIC S9(9)V99 COMP-3.
               10  WS-DEP-HOLD-DAYS  PIC S9(3) COMP-3.
               10  WS-DEP-AVAIL-AMT  PIC S9(9)V99 COMP-3.
               10  WS-DEP-HOLD-AMT   PIC S9(9)V99 COMP-3.
               10  WS-DEP-EXCEPTION  PIC 9.
       01  WS-DEP-IDX               PIC 9(3).
       01  WS-DEP-COUNT             PIC 9(3).
      *--- Check Type Values ---
       01  WS-CHK-TYPE-VAL          PIC 9.
           88  WS-CHK-LOCAL         VALUE 1.
           88  WS-CHK-NON-LOCAL     VALUE 2.
           88  WS-CHK-GOVERNMENT    VALUE 3.
           88  WS-CHK-CASHIER       VALUE 4.
           88  WS-CHK-ON-US         VALUE 5.
      *--- Account Characteristics ---
       01  WS-ACCT-AGE-DAYS         PIC S9(5) COMP-3.
       01  WS-ACCT-NEW              PIC 9.
           88  WS-IS-NEW-ACCT       VALUE 1.
           88  WS-IS-ESTABLISHED    VALUE 0.
       01  WS-PRIOR-NSF-CT          PIC S9(3) COMP-3.
       01  WS-LARGE-DEPOSIT-FLAG    PIC 9.
       01  WS-REDEPOSIT-FLAG        PIC 9.
      *--- Reg CC Thresholds ---
       01  WS-NEXT-DAY-LIMIT        PIC S9(9)V99 COMP-3.
       01  WS-LARGE-DEP-THRESHOLD   PIC S9(9)V99 COMP-3.
       01  WS-NEW-ACCT-DAYS         PIC S9(3) COMP-3.
      *--- Hold Period Schedule ---
       01  WS-LOCAL-HOLD            PIC S9(3) COMP-3.
       01  WS-NONLOCAL-HOLD        PIC S9(3) COMP-3.
       01  WS-GOVT-HOLD             PIC S9(3) COMP-3.
       01  WS-CASHIER-HOLD          PIC S9(3) COMP-3.
       01  WS-ONUS-HOLD             PIC S9(3) COMP-3.
       01  WS-EXCEPTION-HOLD        PIC S9(3) COMP-3.
      *--- Totals ---
       01  WS-TOTAL-DEPOSITED       PIC S9(11)V99 COMP-3.
       01  WS-TOTAL-AVAILABLE       PIC S9(11)V99 COMP-3.
       01  WS-TOTAL-ON-HOLD         PIC S9(11)V99 COMP-3.
      *--- Display ---
       01  WS-DISP-AMT              PIC -$$$,$$$,$$9.99.
       01  WS-DISP-DAYS             PIC ZZ9.
       01  WS-DISP-CT               PIC ZZ9.
      *--- Work ---
       01  WS-WORK-AMT              PIC S9(9)V99 COMP-3.
       01  WS-TYPE-NAME             PIC X(15).
       01  WS-TYPE-TALLY            PIC S9(3) COMP-3.

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-DEPOSITS
           PERFORM 3000-APPLY-HOLD-POLICY
           PERFORM 4000-COMPUTE-AVAILABILITY
           PERFORM 5000-DISPLAY-SCHEDULE
           STOP RUN.

       1000-INITIALIZE.
           MOVE 365 TO WS-ACCT-AGE-DAYS
           MOVE 0 TO WS-ACCT-NEW
           MOVE 1 TO WS-PRIOR-NSF-CT
           MOVE 225.00 TO WS-NEXT-DAY-LIMIT
           MOVE 5525.00 TO WS-LARGE-DEP-THRESHOLD
           MOVE 30 TO WS-NEW-ACCT-DAYS
           MOVE 2 TO WS-LOCAL-HOLD
           MOVE 5 TO WS-NONLOCAL-HOLD
           MOVE 1 TO WS-GOVT-HOLD
           MOVE 1 TO WS-CASHIER-HOLD
           MOVE 1 TO WS-ONUS-HOLD
           MOVE 7 TO WS-EXCEPTION-HOLD
           MOVE 0 TO WS-TOTAL-DEPOSITED
           MOVE 0 TO WS-TOTAL-AVAILABLE
           MOVE 0 TO WS-TOTAL-ON-HOLD
           IF WS-ACCT-AGE-DAYS <= WS-NEW-ACCT-DAYS
               MOVE 1 TO WS-ACCT-NEW
           END-IF.

       2000-LOAD-DEPOSITS.
           MOVE 6 TO WS-DEP-COUNT
           MOVE 3 TO WS-DEP-CHK-TYPE(1)
           MOVE 1500.00 TO WS-DEP-AMOUNT(1)
           MOVE 0 TO WS-DEP-EXCEPTION(1)
           MOVE 1 TO WS-DEP-CHK-TYPE(2)
           MOVE 3200.00 TO WS-DEP-AMOUNT(2)
           MOVE 0 TO WS-DEP-EXCEPTION(2)
           MOVE 2 TO WS-DEP-CHK-TYPE(3)
           MOVE 8500.00 TO WS-DEP-AMOUNT(3)
           MOVE 0 TO WS-DEP-EXCEPTION(3)
           MOVE 4 TO WS-DEP-CHK-TYPE(4)
           MOVE 2000.00 TO WS-DEP-AMOUNT(4)
           MOVE 0 TO WS-DEP-EXCEPTION(4)
           MOVE 5 TO WS-DEP-CHK-TYPE(5)
           MOVE 750.00 TO WS-DEP-AMOUNT(5)
           MOVE 0 TO WS-DEP-EXCEPTION(5)
           MOVE 1 TO WS-DEP-CHK-TYPE(6)
           MOVE 450.00 TO WS-DEP-AMOUNT(6)
           MOVE 1 TO WS-DEP-EXCEPTION(6).

       3000-APPLY-HOLD-POLICY.
           PERFORM VARYING WS-DEP-IDX FROM 1 BY 1
               UNTIL WS-DEP-IDX > WS-DEP-COUNT
               EVALUATE WS-DEP-CHK-TYPE(WS-DEP-IDX)
                   WHEN 3
                       MOVE WS-GOVT-HOLD
                           TO WS-DEP-HOLD-DAYS(WS-DEP-IDX)
                   WHEN 4
                       MOVE WS-CASHIER-HOLD
                           TO WS-DEP-HOLD-DAYS(WS-DEP-IDX)
                   WHEN 5
                       MOVE WS-ONUS-HOLD
                           TO WS-DEP-HOLD-DAYS(WS-DEP-IDX)
                   WHEN 1
                       MOVE WS-LOCAL-HOLD
                           TO WS-DEP-HOLD-DAYS(WS-DEP-IDX)
                   WHEN 2
                       MOVE WS-NONLOCAL-HOLD
                           TO WS-DEP-HOLD-DAYS(WS-DEP-IDX)
               END-EVALUATE
               IF WS-DEP-AMOUNT(WS-DEP-IDX) >
                   WS-LARGE-DEP-THRESHOLD
                   MOVE WS-EXCEPTION-HOLD
                       TO WS-DEP-HOLD-DAYS(WS-DEP-IDX)
                   MOVE 1 TO WS-DEP-EXCEPTION(WS-DEP-IDX)
               END-IF
               IF WS-IS-NEW-ACCT
                   IF WS-DEP-HOLD-DAYS(WS-DEP-IDX) <
                       WS-EXCEPTION-HOLD
                       MOVE WS-EXCEPTION-HOLD
                           TO WS-DEP-HOLD-DAYS(WS-DEP-IDX)
                   END-IF
               END-IF
               IF WS-DEP-EXCEPTION(WS-DEP-IDX) = 1
                   IF WS-PRIOR-NSF-CT > 0
                       ADD 2 TO WS-DEP-HOLD-DAYS(WS-DEP-IDX)
                   END-IF
               END-IF
           END-PERFORM.

       4000-COMPUTE-AVAILABILITY.
           PERFORM VARYING WS-DEP-IDX FROM 1 BY 1
               UNTIL WS-DEP-IDX > WS-DEP-COUNT
               ADD WS-DEP-AMOUNT(WS-DEP-IDX)
                   TO WS-TOTAL-DEPOSITED
               IF WS-DEP-HOLD-DAYS(WS-DEP-IDX) <= 1
                   MOVE WS-DEP-AMOUNT(WS-DEP-IDX)
                       TO WS-DEP-AVAIL-AMT(WS-DEP-IDX)
                   MOVE 0
                       TO WS-DEP-HOLD-AMT(WS-DEP-IDX)
               ELSE
                   IF WS-DEP-AMOUNT(WS-DEP-IDX) <=
                       WS-NEXT-DAY-LIMIT
                       MOVE WS-DEP-AMOUNT(WS-DEP-IDX)
                           TO WS-DEP-AVAIL-AMT(WS-DEP-IDX)
                       MOVE 0
                           TO WS-DEP-HOLD-AMT(WS-DEP-IDX)
                   ELSE
                       MOVE WS-NEXT-DAY-LIMIT
                           TO WS-DEP-AVAIL-AMT(WS-DEP-IDX)
                       COMPUTE WS-DEP-HOLD-AMT(WS-DEP-IDX) =
                           WS-DEP-AMOUNT(WS-DEP-IDX)
                           - WS-NEXT-DAY-LIMIT
                   END-IF
               END-IF
               ADD WS-DEP-AVAIL-AMT(WS-DEP-IDX)
                   TO WS-TOTAL-AVAILABLE
               ADD WS-DEP-HOLD-AMT(WS-DEP-IDX)
                   TO WS-TOTAL-ON-HOLD
           END-PERFORM.

       5000-DISPLAY-SCHEDULE.
           DISPLAY "========================================"
           DISPLAY "   CHECK HOLD SCHEDULE"
           DISPLAY "========================================"
           PERFORM VARYING WS-DEP-IDX FROM 1 BY 1
               UNTIL WS-DEP-IDX > WS-DEP-COUNT
               EVALUATE WS-DEP-CHK-TYPE(WS-DEP-IDX)
                   WHEN 1
                       MOVE "LOCAL" TO WS-TYPE-NAME
                   WHEN 2
                       MOVE "NON-LOCAL" TO WS-TYPE-NAME
                   WHEN 3
                       MOVE "GOVERNMENT" TO WS-TYPE-NAME
                   WHEN 4
                       MOVE "CASHIER" TO WS-TYPE-NAME
                   WHEN 5
                       MOVE "ON-US" TO WS-TYPE-NAME
               END-EVALUATE
               MOVE WS-DEP-AMOUNT(WS-DEP-IDX)
                   TO WS-DISP-AMT
               MOVE WS-DEP-HOLD-DAYS(WS-DEP-IDX)
                   TO WS-DISP-DAYS
               MOVE 0 TO WS-TYPE-TALLY
               INSPECT WS-TYPE-NAME
                   TALLYING WS-TYPE-TALLY
                   FOR ALL SPACES
               DISPLAY WS-TYPE-NAME " " WS-DISP-AMT
                   " HOLD:" WS-DISP-DAYS " DAYS"
               IF WS-DEP-EXCEPTION(WS-DEP-IDX) = 1
                   DISPLAY "  ** EXCEPTION HOLD **"
               END-IF
           END-PERFORM
           DISPLAY "--- AVAILABILITY ---"
           MOVE WS-TOTAL-DEPOSITED TO WS-DISP-AMT
           DISPLAY "DEPOSITED:  " WS-DISP-AMT
           MOVE WS-TOTAL-AVAILABLE TO WS-DISP-AMT
           DISPLAY "AVAILABLE:  " WS-DISP-AMT
           MOVE WS-TOTAL-ON-HOLD TO WS-DISP-AMT
           DISPLAY "ON HOLD:    " WS-DISP-AMT
           DISPLAY "========================================".
