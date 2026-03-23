       IDENTIFICATION DIVISION.
       PROGRAM-ID. PAY-CHECK-HOLD-CALC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-DEPOSIT.
           05 WS-DEP-ACCT        PIC X(12).
           05 WS-DEP-AMOUNT      PIC S9(9)V99 COMP-3.
           05 WS-DEP-TYPE        PIC X(2).
               88 DT-LOCAL       VALUE 'LC'.
               88 DT-NON-LOCAL   VALUE 'NL'.
               88 DT-TREASURY    VALUE 'TR'.
               88 DT-CASHIER     VALUE 'CA'.
               88 DT-WIRE        VALUE 'WR'.
           05 WS-DEP-DATE        PIC 9(8).
       01 WS-ACCT-PROFILE.
           05 WS-ACCT-AGE-DAYS   PIC 9(5).
           05 WS-NEW-ACCT-FLAG   PIC X VALUE 'N'.
               88 IS-NEW-ACCT    VALUE 'Y'.
           05 WS-NSF-HISTORY     PIC 9(2).
           05 WS-LARGE-CHECK     PIC X VALUE 'N'.
               88 IS-LARGE       VALUE 'Y'.
       01 WS-HOLD-CALC.
           05 WS-FIRST-DAY-AVAIL PIC S9(9)V99 COMP-3.
           05 WS-HOLD-AMOUNT     PIC S9(9)V99 COMP-3.
           05 WS-HOLD-DAYS       PIC 9(2).
           05 WS-RELEASE-DATE    PIC 9(8).
       01 WS-REG-CC-FIRST-DAY    PIC S9(5)V99 COMP-3
           VALUE 225.00.
       01 WS-LARGE-THRESHOLD     PIC S9(7)V99 COMP-3
           VALUE 5525.00.
       01 WS-EXCEPTION-HOLD      PIC X VALUE 'N'.
           88 IS-EXCEPTION       VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-CHECK-DEPOSIT-TYPE
           PERFORM 2000-CHECK-EXCEPTIONS
           PERFORM 3000-CALC-HOLD
           PERFORM 4000-OUTPUT
           STOP RUN.
       1000-CHECK-DEPOSIT-TYPE.
           EVALUATE TRUE
               WHEN DT-WIRE
                   MOVE 0 TO WS-HOLD-DAYS
                   MOVE WS-DEP-AMOUNT TO WS-FIRST-DAY-AVAIL
                   MOVE 0 TO WS-HOLD-AMOUNT
               WHEN DT-TREASURY
                   MOVE 1 TO WS-HOLD-DAYS
                   MOVE WS-DEP-AMOUNT TO WS-FIRST-DAY-AVAIL
                   MOVE 0 TO WS-HOLD-AMOUNT
               WHEN DT-CASHIER
                   MOVE 1 TO WS-HOLD-DAYS
                   MOVE WS-DEP-AMOUNT TO WS-FIRST-DAY-AVAIL
                   MOVE 0 TO WS-HOLD-AMOUNT
               WHEN DT-LOCAL
                   MOVE 2 TO WS-HOLD-DAYS
                   MOVE WS-REG-CC-FIRST-DAY TO
                       WS-FIRST-DAY-AVAIL
                   COMPUTE WS-HOLD-AMOUNT =
                       WS-DEP-AMOUNT - WS-REG-CC-FIRST-DAY
               WHEN DT-NON-LOCAL
                   MOVE 5 TO WS-HOLD-DAYS
                   MOVE WS-REG-CC-FIRST-DAY TO
                       WS-FIRST-DAY-AVAIL
                   COMPUTE WS-HOLD-AMOUNT =
                       WS-DEP-AMOUNT - WS-REG-CC-FIRST-DAY
               WHEN OTHER
                   MOVE 5 TO WS-HOLD-DAYS
                   MOVE 0 TO WS-FIRST-DAY-AVAIL
                   MOVE WS-DEP-AMOUNT TO WS-HOLD-AMOUNT
           END-EVALUATE
           IF WS-HOLD-AMOUNT < 0
               MOVE 0 TO WS-HOLD-AMOUNT
           END-IF.
       2000-CHECK-EXCEPTIONS.
           IF WS-ACCT-AGE-DAYS < 30
               MOVE 'Y' TO WS-NEW-ACCT-FLAG
               ADD 5 TO WS-HOLD-DAYS
               MOVE 'Y' TO WS-EXCEPTION-HOLD
           END-IF
           IF WS-DEP-AMOUNT > WS-LARGE-THRESHOLD
               MOVE 'Y' TO WS-LARGE-CHECK
               ADD 2 TO WS-HOLD-DAYS
               MOVE 'Y' TO WS-EXCEPTION-HOLD
           END-IF
           IF WS-NSF-HISTORY > 3
               ADD 3 TO WS-HOLD-DAYS
               MOVE 'Y' TO WS-EXCEPTION-HOLD
           END-IF.
       3000-CALC-HOLD.
           COMPUTE WS-RELEASE-DATE =
               WS-DEP-DATE + WS-HOLD-DAYS.
       4000-OUTPUT.
           DISPLAY 'CHECK HOLD CALCULATION'
           DISPLAY '======================'
           DISPLAY 'ACCOUNT:   ' WS-DEP-ACCT
           DISPLAY 'AMOUNT:    $' WS-DEP-AMOUNT
           DISPLAY 'TYPE:      ' WS-DEP-TYPE
           DISPLAY 'FIRST DAY: $' WS-FIRST-DAY-AVAIL
           DISPLAY 'HELD:      $' WS-HOLD-AMOUNT
           DISPLAY 'HOLD DAYS: ' WS-HOLD-DAYS
           DISPLAY 'RELEASE:   ' WS-RELEASE-DATE
           IF IS-EXCEPTION
               DISPLAY 'EXCEPTION HOLD APPLIED'
               IF IS-NEW-ACCT
                   DISPLAY '  - NEW ACCOUNT'
               END-IF
               IF IS-LARGE
                   DISPLAY '  - LARGE DEPOSIT'
               END-IF
           END-IF.
