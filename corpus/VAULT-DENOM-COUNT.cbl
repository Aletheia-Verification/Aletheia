       IDENTIFICATION DIVISION.
       PROGRAM-ID. VAULT-DENOM-COUNT.
      *================================================================*
      * Vault Denomination Counter and Strap Verifier                  *
      * Processes physical cash count by strap/bundle, verifies        *
      * counts against expected, identifies counterfeits tracked.      *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- Count Session ---
       01  WS-COUNT-DATE             PIC 9(8).
       01  WS-COUNTER-ID            PIC X(8).
       01  WS-VERIFIER-ID           PIC X(8).
       01  WS-COUNT-SESSION          PIC 9(6).
      *--- Currency Straps ---
       01  WS-STRAP-TABLE.
           05  WS-STRAP-ENTRY OCCURS 7 TIMES.
               10  WS-STRAP-DENOM    PIC 9(5).
               10  WS-STRAP-BILLS    PIC 9(3).
               10  WS-FULL-STRAPS    PIC S9(5) COMP-3.
               10  WS-LOOSE-BILLS    PIC S9(5) COMP-3.
               10  WS-STRAP-VALUE    PIC S9(9)V99 COMP-3.
               10  WS-EXPECTED-CT    PIC S9(7) COMP-3.
               10  WS-ACTUAL-CT      PIC S9(7) COMP-3.
               10  WS-VARIANCE-CT    PIC S9(5) COMP-3.
       01  WS-STRAP-IDX             PIC 9(3).
      *--- Totals ---
       01  WS-TOTAL-COUNTED         PIC S9(11)V99 COMP-3.
       01  WS-TOTAL-EXPECTED        PIC S9(11)V99 COMP-3.
       01  WS-TOTAL-VARIANCE        PIC S9(9)V99 COMP-3.
       01  WS-ABS-VARIANCE          PIC S9(9)V99 COMP-3.
      *--- Counterfeit Tracking ---
       01  WS-CF-TABLE.
           05  WS-CF-ENTRY OCCURS 3 TIMES.
               10  WS-CF-DENOM       PIC 9(5).
               10  WS-CF-COUNT       PIC S9(3) COMP-3.
               10  WS-CF-SERIAL      PIC X(12).
       01  WS-CF-IDX                 PIC 9(3).
       01  WS-CF-TOTAL-CT            PIC S9(5) COMP-3.
       01  WS-CF-TOTAL-VAL           PIC S9(7)V99 COMP-3.
      *--- Dual Control ---
       01  WS-DUAL-COUNT-MATCH       PIC 9.
           88  WS-COUNTS-MATCH       VALUE 1.
           88  WS-COUNTS-DIFFER      VALUE 0.
       01  WS-RECOUNT-NEEDED         PIC 9.
       01  WS-THRESHOLD-VAR          PIC S9(3) COMP-3.
      *--- Display ---
       01  WS-DISP-AMT               PIC -$$$,$$$,$$$,$$9.99.
       01  WS-DISP-CT                PIC ZZZ,ZZ9.
       01  WS-DISP-VAR               PIC -ZZ,ZZ9.
      *--- String ---
       01  WS-COUNT-LINE             PIC X(72).
       01  WS-SERIAL-TALLY          PIC S9(3) COMP-3.

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-COUNT-STRAPS
           PERFORM 3000-CHECK-COUNTERFEITS
           PERFORM 4000-RECONCILE-COUNTS
           PERFORM 5000-DUAL-CONTROL-CHECK
           PERFORM 6000-DISPLAY-REPORT
           STOP RUN.

       1000-INITIALIZE.
           ACCEPT WS-COUNT-DATE FROM DATE YYYYMMDD
           MOVE "CNT00301" TO WS-COUNTER-ID
           MOVE "VRF00101" TO WS-VERIFIER-ID
           MOVE 100001 TO WS-COUNT-SESSION
           MOVE 0 TO WS-TOTAL-COUNTED
           MOVE 0 TO WS-TOTAL-EXPECTED
           MOVE 0 TO WS-CF-TOTAL-CT
           MOVE 0 TO WS-CF-TOTAL-VAL
           MOVE 0 TO WS-RECOUNT-NEEDED
           MOVE 5 TO WS-THRESHOLD-VAR
           MOVE 100 TO WS-STRAP-DENOM(1)
           MOVE 100 TO WS-STRAP-BILLS(1)
           MOVE 45  TO WS-FULL-STRAPS(1)
           MOVE 23  TO WS-LOOSE-BILLS(1)
           MOVE 4525 TO WS-EXPECTED-CT(1)
           MOVE 50  TO WS-STRAP-DENOM(2)
           MOVE 100 TO WS-STRAP-BILLS(2)
           MOVE 22  TO WS-FULL-STRAPS(2)
           MOVE 47  TO WS-LOOSE-BILLS(2)
           MOVE 2250 TO WS-EXPECTED-CT(2)
           MOVE 20  TO WS-STRAP-DENOM(3)
           MOVE 100 TO WS-STRAP-BILLS(3)
           MOVE 50  TO WS-FULL-STRAPS(3)
           MOVE 65  TO WS-LOOSE-BILLS(3)
           MOVE 5070 TO WS-EXPECTED-CT(3)
           MOVE 10  TO WS-STRAP-DENOM(4)
           MOVE 100 TO WS-STRAP-BILLS(4)
           MOVE 15  TO WS-FULL-STRAPS(4)
           MOVE 30  TO WS-LOOSE-BILLS(4)
           MOVE 1530 TO WS-EXPECTED-CT(4)
           MOVE 5   TO WS-STRAP-DENOM(5)
           MOVE 100 TO WS-STRAP-BILLS(5)
           MOVE 8   TO WS-FULL-STRAPS(5)
           MOVE 15  TO WS-LOOSE-BILLS(5)
           MOVE 815  TO WS-EXPECTED-CT(5)
           MOVE 2   TO WS-STRAP-DENOM(6)
           MOVE 100 TO WS-STRAP-BILLS(6)
           MOVE 2   TO WS-FULL-STRAPS(6)
           MOVE 45  TO WS-LOOSE-BILLS(6)
           MOVE 245  TO WS-EXPECTED-CT(6)
           MOVE 1   TO WS-STRAP-DENOM(7)
           MOVE 100 TO WS-STRAP-BILLS(7)
           MOVE 1   TO WS-FULL-STRAPS(7)
           MOVE 50  TO WS-LOOSE-BILLS(7)
           MOVE 150  TO WS-EXPECTED-CT(7)
           MOVE 100 TO WS-CF-DENOM(1)
           MOVE 1 TO WS-CF-COUNT(1)
           MOVE "AB12345678" TO WS-CF-SERIAL(1)
           MOVE 50  TO WS-CF-DENOM(2)
           MOVE 2 TO WS-CF-COUNT(2)
           MOVE "CD98765432" TO WS-CF-SERIAL(2)
           MOVE 20  TO WS-CF-DENOM(3)
           MOVE 0 TO WS-CF-COUNT(3)
           MOVE SPACES TO WS-CF-SERIAL(3).

       2000-COUNT-STRAPS.
           PERFORM VARYING WS-STRAP-IDX FROM 1 BY 1
               UNTIL WS-STRAP-IDX > 7
               COMPUTE WS-ACTUAL-CT(WS-STRAP-IDX) =
                   WS-FULL-STRAPS(WS-STRAP-IDX)
                   * WS-STRAP-BILLS(WS-STRAP-IDX)
                   + WS-LOOSE-BILLS(WS-STRAP-IDX)
               COMPUTE WS-STRAP-VALUE(WS-STRAP-IDX) =
                   WS-ACTUAL-CT(WS-STRAP-IDX)
                   * WS-STRAP-DENOM(WS-STRAP-IDX)
               ADD WS-STRAP-VALUE(WS-STRAP-IDX)
                   TO WS-TOTAL-COUNTED
               COMPUTE WS-VARIANCE-CT(WS-STRAP-IDX) =
                   WS-ACTUAL-CT(WS-STRAP-IDX)
                   - WS-EXPECTED-CT(WS-STRAP-IDX)
           END-PERFORM.

       3000-CHECK-COUNTERFEITS.
           PERFORM VARYING WS-CF-IDX FROM 1 BY 1
               UNTIL WS-CF-IDX > 3
               IF WS-CF-COUNT(WS-CF-IDX) > 0
                   ADD WS-CF-COUNT(WS-CF-IDX)
                       TO WS-CF-TOTAL-CT
                   COMPUTE WS-CF-TOTAL-VAL =
                       WS-CF-TOTAL-VAL
                       + (WS-CF-DENOM(WS-CF-IDX)
                          * WS-CF-COUNT(WS-CF-IDX))
                   MOVE 0 TO WS-SERIAL-TALLY
                   INSPECT WS-CF-SERIAL(WS-CF-IDX)
                       TALLYING WS-SERIAL-TALLY
                       FOR ALL SPACES
               END-IF
           END-PERFORM.

       4000-RECONCILE-COUNTS.
           PERFORM VARYING WS-STRAP-IDX FROM 1 BY 1
               UNTIL WS-STRAP-IDX > 7
               COMPUTE WS-TOTAL-EXPECTED =
                   WS-TOTAL-EXPECTED
                   + (WS-EXPECTED-CT(WS-STRAP-IDX)
                      * WS-STRAP-DENOM(WS-STRAP-IDX))
           END-PERFORM
           COMPUTE WS-TOTAL-VARIANCE =
               WS-TOTAL-COUNTED - WS-TOTAL-EXPECTED
           IF WS-TOTAL-VARIANCE < 0
               COMPUTE WS-ABS-VARIANCE =
                   WS-TOTAL-VARIANCE * -1
           ELSE
               MOVE WS-TOTAL-VARIANCE TO WS-ABS-VARIANCE
           END-IF.

       5000-DUAL-CONTROL-CHECK.
           MOVE 1 TO WS-DUAL-COUNT-MATCH
           PERFORM VARYING WS-STRAP-IDX FROM 1 BY 1
               UNTIL WS-STRAP-IDX > 7
               IF WS-VARIANCE-CT(WS-STRAP-IDX) > 0
                   IF WS-VARIANCE-CT(WS-STRAP-IDX)
                       > WS-THRESHOLD-VAR
                       MOVE 0 TO WS-DUAL-COUNT-MATCH
                       MOVE 1 TO WS-RECOUNT-NEEDED
                   END-IF
               END-IF
               IF WS-VARIANCE-CT(WS-STRAP-IDX) < 0
                   COMPUTE WS-VARIANCE-CT(WS-STRAP-IDX) =
                       WS-VARIANCE-CT(WS-STRAP-IDX) * -1
                   IF WS-VARIANCE-CT(WS-STRAP-IDX)
                       > WS-THRESHOLD-VAR
                       MOVE 0 TO WS-DUAL-COUNT-MATCH
                       MOVE 1 TO WS-RECOUNT-NEEDED
                   END-IF
               END-IF
           END-PERFORM.

       6000-DISPLAY-REPORT.
           DISPLAY "========================================"
           DISPLAY "   VAULT DENOMINATION COUNT"
           DISPLAY "========================================"
           DISPLAY "COUNTER:  " WS-COUNTER-ID
           DISPLAY "VERIFIER: " WS-VERIFIER-ID
           DISPLAY "SESSION:  " WS-COUNT-SESSION
           PERFORM VARYING WS-STRAP-IDX FROM 1 BY 1
               UNTIL WS-STRAP-IDX > 7
               MOVE WS-STRAP-VALUE(WS-STRAP-IDX)
                   TO WS-DISP-AMT
               MOVE WS-ACTUAL-CT(WS-STRAP-IDX)
                   TO WS-DISP-CT
               DISPLAY "$" WS-STRAP-DENOM(WS-STRAP-IDX)
                   " CT:" WS-DISP-CT
                   " VAL:" WS-DISP-AMT
           END-PERFORM
           MOVE WS-TOTAL-COUNTED TO WS-DISP-AMT
           DISPLAY "TOTAL COUNTED:  " WS-DISP-AMT
           MOVE WS-TOTAL-EXPECTED TO WS-DISP-AMT
           DISPLAY "TOTAL EXPECTED: " WS-DISP-AMT
           IF WS-CF-TOTAL-CT > 0
               DISPLAY "*** COUNTERFEITS DETECTED: "
                   WS-CF-TOTAL-CT " ***"
           END-IF
           IF WS-RECOUNT-NEEDED = 1
               DISPLAY "*** RECOUNT REQUIRED ***"
           END-IF
           DISPLAY "========================================".
