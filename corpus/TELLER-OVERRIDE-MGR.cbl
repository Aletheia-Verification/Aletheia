       IDENTIFICATION DIVISION.
       PROGRAM-ID. TELLER-OVERRIDE-MGR.
      *================================================================*
      * Teller Override Authorization Manager                          *
      * Processes override requests for transactions exceeding teller  *
      * authority, routes to appropriate approval level, logs all      *
      * override events for compliance audit.                          *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- Override Request ---
       01  WS-OVERRIDE-TABLE.
           05  WS-OVR-ENTRY OCCURS 6 TIMES.
               10  WS-OVR-TELLER     PIC X(8).
               10  WS-OVR-TYPE       PIC X(4).
               10  WS-OVR-AMOUNT     PIC S9(9)V99 COMP-3.
               10  WS-OVR-ACCT       PIC 9(10).
               10  WS-OVR-LEVEL      PIC 9.
               10  WS-OVR-APPROVED   PIC 9.
               10  WS-OVR-APPROVER   PIC X(8).
       01  WS-OVR-IDX                PIC 9(3).
       01  WS-OVR-COUNT              PIC 9(3).
      *--- Authority Levels ---
       01  WS-AUTH-LEVEL              PIC 9.
           88  WS-AUTH-TELLER         VALUE 1.
           88  WS-AUTH-SENIOR         VALUE 2.
           88  WS-AUTH-SUPERVISOR     VALUE 3.
           88  WS-AUTH-MANAGER        VALUE 4.
      *--- Threshold Amounts ---
       01  WS-TELLER-LIMIT           PIC S9(9)V99 COMP-3.
       01  WS-SENIOR-LIMIT           PIC S9(9)V99 COMP-3.
       01  WS-SUPV-LIMIT             PIC S9(9)V99 COMP-3.
       01  WS-MGR-LIMIT              PIC S9(9)V99 COMP-3.
      *--- Override Types ---
       01  WS-OVR-TYPE-FLAG          PIC X(4).
           88  WS-TYPE-CASH-WTH      VALUE "CWTH".
           88  WS-TYPE-CHECK-CSH     VALUE "CCSH".
           88  WS-TYPE-WIRE          VALUE "WIRE".
           88  WS-TYPE-HOLD-REL      VALUE "HREL".
      *--- Counters ---
       01  WS-APPROVED-CT            PIC S9(3) COMP-3.
       01  WS-DENIED-CT              PIC S9(3) COMP-3.
       01  WS-PENDING-CT             PIC S9(3) COMP-3.
       01  WS-TOTAL-APPROVED-AMT     PIC S9(11)V99 COMP-3.
       01  WS-TOTAL-DENIED-AMT       PIC S9(9)V99 COMP-3.
      *--- Compliance Check ---
       01  WS-DUAL-CONTROL           PIC 9.
       01  WS-SAME-DAY-OVR-CT        PIC S9(3) COMP-3.
       01  WS-MAX-DAILY-OVERRIDES    PIC S9(3) COMP-3.
       01  WS-COMPLIANCE-FLAG        PIC 9.
           88  WS-COMPLIANT          VALUE 1.
           88  WS-NON-COMPLIANT      VALUE 0.
      *--- Display ---
       01  WS-DISP-AMT               PIC -$$$,$$$,$$9.99.
       01  WS-DISP-CT                PIC ZZ9.
      *--- String/Tally ---
       01  WS-AUDIT-LINE             PIC X(72).
       01  WS-TYPE-TALLY             PIC S9(3) COMP-3.

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-OVERRIDES
           PERFORM 3000-ROUTE-APPROVALS
           PERFORM 4000-PROCESS-APPROVALS
           PERFORM 5000-CHECK-COMPLIANCE
           PERFORM 6000-DISPLAY-REPORT
           STOP RUN.

       1000-INITIALIZE.
           MOVE 5000.00 TO WS-TELLER-LIMIT
           MOVE 10000.00 TO WS-SENIOR-LIMIT
           MOVE 25000.00 TO WS-SUPV-LIMIT
           MOVE 100000.00 TO WS-MGR-LIMIT
           MOVE 0 TO WS-APPROVED-CT
           MOVE 0 TO WS-DENIED-CT
           MOVE 0 TO WS-PENDING-CT
           MOVE 0 TO WS-TOTAL-APPROVED-AMT
           MOVE 0 TO WS-TOTAL-DENIED-AMT
           MOVE 0 TO WS-SAME-DAY-OVR-CT
           MOVE 10 TO WS-MAX-DAILY-OVERRIDES
           MOVE 1 TO WS-COMPLIANCE-FLAG.

       2000-LOAD-OVERRIDES.
           MOVE 5 TO WS-OVR-COUNT
           MOVE "TLR00201" TO WS-OVR-TELLER(1)
           MOVE "CWTH" TO WS-OVR-TYPE(1)
           MOVE 7500.00 TO WS-OVR-AMOUNT(1)
           MOVE 2233445566 TO WS-OVR-ACCT(1)
           MOVE 0 TO WS-OVR-APPROVED(1)
           MOVE "TLR00202" TO WS-OVR-TELLER(2)
           MOVE "CCSH" TO WS-OVR-TYPE(2)
           MOVE 15000.00 TO WS-OVR-AMOUNT(2)
           MOVE 3344556677 TO WS-OVR-ACCT(2)
           MOVE 0 TO WS-OVR-APPROVED(2)
           MOVE "TLR00201" TO WS-OVR-TELLER(3)
           MOVE "WIRE" TO WS-OVR-TYPE(3)
           MOVE 50000.00 TO WS-OVR-AMOUNT(3)
           MOVE 4455667788 TO WS-OVR-ACCT(3)
           MOVE 0 TO WS-OVR-APPROVED(3)
           MOVE "TLR00203" TO WS-OVR-TELLER(4)
           MOVE "HREL" TO WS-OVR-TYPE(4)
           MOVE 3000.00 TO WS-OVR-AMOUNT(4)
           MOVE 5566778899 TO WS-OVR-ACCT(4)
           MOVE 0 TO WS-OVR-APPROVED(4)
           MOVE "TLR00202" TO WS-OVR-TELLER(5)
           MOVE "CWTH" TO WS-OVR-TYPE(5)
           MOVE 120000.00 TO WS-OVR-AMOUNT(5)
           MOVE 6677889900 TO WS-OVR-ACCT(5)
           MOVE 0 TO WS-OVR-APPROVED(5).

       3000-ROUTE-APPROVALS.
           PERFORM VARYING WS-OVR-IDX FROM 1 BY 1
               UNTIL WS-OVR-IDX > WS-OVR-COUNT
               EVALUATE TRUE
                   WHEN WS-OVR-AMOUNT(WS-OVR-IDX)
                       <= WS-TELLER-LIMIT
                       MOVE 1 TO WS-OVR-LEVEL(WS-OVR-IDX)
                   WHEN WS-OVR-AMOUNT(WS-OVR-IDX)
                       <= WS-SENIOR-LIMIT
                       MOVE 2 TO WS-OVR-LEVEL(WS-OVR-IDX)
                   WHEN WS-OVR-AMOUNT(WS-OVR-IDX)
                       <= WS-SUPV-LIMIT
                       MOVE 3 TO WS-OVR-LEVEL(WS-OVR-IDX)
                   WHEN WS-OVR-AMOUNT(WS-OVR-IDX)
                       <= WS-MGR-LIMIT
                       MOVE 4 TO WS-OVR-LEVEL(WS-OVR-IDX)
                   WHEN OTHER
                       MOVE 0 TO WS-OVR-LEVEL(WS-OVR-IDX)
               END-EVALUATE
           END-PERFORM.

       4000-PROCESS-APPROVALS.
           PERFORM VARYING WS-OVR-IDX FROM 1 BY 1
               UNTIL WS-OVR-IDX > WS-OVR-COUNT
               IF WS-OVR-LEVEL(WS-OVR-IDX) = 0
                   MOVE 0 TO WS-OVR-APPROVED(WS-OVR-IDX)
                   ADD 1 TO WS-DENIED-CT
                   ADD WS-OVR-AMOUNT(WS-OVR-IDX)
                       TO WS-TOTAL-DENIED-AMT
               ELSE
                   MOVE 1 TO WS-OVR-APPROVED(WS-OVR-IDX)
                   ADD 1 TO WS-APPROVED-CT
                   ADD WS-OVR-AMOUNT(WS-OVR-IDX)
                       TO WS-TOTAL-APPROVED-AMT
                   ADD 1 TO WS-SAME-DAY-OVR-CT
                   EVALUATE WS-OVR-LEVEL(WS-OVR-IDX)
                       WHEN 1
                           MOVE WS-OVR-TELLER(WS-OVR-IDX)
                               TO WS-OVR-APPROVER(WS-OVR-IDX)
                       WHEN 2
                           MOVE "SR-TLR01"
                               TO WS-OVR-APPROVER(WS-OVR-IDX)
                       WHEN 3
                           MOVE "SUP-0001"
                               TO WS-OVR-APPROVER(WS-OVR-IDX)
                       WHEN 4
                           MOVE "MGR-0001"
                               TO WS-OVR-APPROVER(WS-OVR-IDX)
                   END-EVALUATE
               END-IF
           END-PERFORM.

       5000-CHECK-COMPLIANCE.
           IF WS-SAME-DAY-OVR-CT > WS-MAX-DAILY-OVERRIDES
               MOVE 0 TO WS-COMPLIANCE-FLAG
           END-IF
           MOVE 0 TO WS-TYPE-TALLY
           PERFORM VARYING WS-OVR-IDX FROM 1 BY 1
               UNTIL WS-OVR-IDX > WS-OVR-COUNT
               IF WS-OVR-AMOUNT(WS-OVR-IDX) > WS-SUPV-LIMIT
                   IF WS-OVR-APPROVED(WS-OVR-IDX) = 1
                       ADD 1 TO WS-TYPE-TALLY
                   END-IF
               END-IF
           END-PERFORM
           IF WS-TYPE-TALLY > 0
               MOVE 1 TO WS-DUAL-CONTROL
           END-IF.

       6000-DISPLAY-REPORT.
           DISPLAY "========================================"
           DISPLAY "   OVERRIDE AUTHORIZATION REPORT"
           DISPLAY "========================================"
           PERFORM VARYING WS-OVR-IDX FROM 1 BY 1
               UNTIL WS-OVR-IDX > WS-OVR-COUNT
               MOVE WS-OVR-AMOUNT(WS-OVR-IDX)
                   TO WS-DISP-AMT
               STRING WS-OVR-TELLER(WS-OVR-IDX) " "
                   WS-OVR-TYPE(WS-OVR-IDX)
                   DELIMITED BY SIZE
                   INTO WS-AUDIT-LINE
               IF WS-OVR-APPROVED(WS-OVR-IDX) = 1
                   DISPLAY WS-AUDIT-LINE " " WS-DISP-AMT
                       " APPROVED BY "
                       WS-OVR-APPROVER(WS-OVR-IDX)
               ELSE
                   DISPLAY WS-AUDIT-LINE " " WS-DISP-AMT
                       " DENIED"
               END-IF
           END-PERFORM
           DISPLAY "--- SUMMARY ---"
           MOVE WS-APPROVED-CT TO WS-DISP-CT
           DISPLAY "APPROVED:      " WS-DISP-CT
           MOVE WS-DENIED-CT TO WS-DISP-CT
           DISPLAY "DENIED:        " WS-DISP-CT
           MOVE WS-TOTAL-APPROVED-AMT TO WS-DISP-AMT
           DISPLAY "APPROVED AMT:  " WS-DISP-AMT
           IF WS-NON-COMPLIANT
               DISPLAY "*** COMPLIANCE ALERT ***"
           END-IF
           DISPLAY "========================================".
