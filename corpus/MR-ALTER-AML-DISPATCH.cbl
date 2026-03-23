       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-ALTER-AML-DISPATCH.
      *---------------------------------------------------------------
      * MANUAL REVIEW: Uses ALTER statement for dynamic AML alert
      * routing dispatch based on severity changes.
      *---------------------------------------------------------------

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01 WS-ALERT-DATA.
           05 WS-ALERT-ID             PIC X(16).
           05 WS-ACCT-ID              PIC X(12).
           05 WS-ALERT-TYPE           PIC X(4).
           05 WS-SEVERITY             PIC X(1).
               88 WS-SEV-CRITICAL     VALUE 'C'.
               88 WS-SEV-HIGH         VALUE 'H'.
               88 WS-SEV-MEDIUM       VALUE 'M'.
               88 WS-SEV-LOW          VALUE 'L'.
           05 WS-AMOUNT               PIC S9(13)V99 COMP-3.
           05 WS-TXN-COUNT            PIC 9(5).
           05 WS-COUNTRY-CODE         PIC X(3).

       01 WS-DISPATCH-TARGET.
           05 WS-TEAM                 PIC X(12).
           05 WS-PRIORITY             PIC 9(1).
           05 WS-SLA-HOURS            PIC 9(3).
           05 WS-ESCALATION-FLAG      PIC X VALUE 'N'.
               88 WS-ESCALATE         VALUE 'Y'.

       01 WS-COUNTERS.
           05 WS-TOTAL-ALERTS         PIC S9(7) COMP-3 VALUE 0.
           05 WS-DISPATCHED           PIC S9(7) COMP-3 VALUE 0.
           05 WS-ESCALATED            PIC S9(7) COMP-3 VALUE 0.
           05 WS-DROPPED              PIC S9(7) COMP-3 VALUE 0.

       01 WS-HIGH-RISK-COUNTRIES.
           05 WS-HR OCCURS 5          PIC X(3).
       01 WS-HR-IDX                   PIC 9(1).
       01 WS-HR-HIT                   PIC X VALUE 'N'.
           88 WS-IS-HIGH-RISK-CTY     VALUE 'Y'.

       01 WS-RESULT-BUF               PIC X(60).
       01 WS-RESULT-PTR               PIC 9(3).
       01 WS-TALLY-WORK               PIC 9(3).

       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           ALTER 2000-ROUTE-DISPATCH TO PROCEED TO
               2100-ROUTE-CRITICAL
           PERFORM 2000-ROUTE-DISPATCH
           PERFORM 3000-CHECK-ESCALATION
           PERFORM 4000-DISPLAY-RESULTS
           STOP RUN.

       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-ALERTS
           MOVE 0 TO WS-DISPATCHED
           MOVE 0 TO WS-ESCALATED
           MOVE 0 TO WS-DROPPED
           MOVE 'N' TO WS-ESCALATION-FLAG
           MOVE 'IRN' TO WS-HR(1)
           MOVE 'PRK' TO WS-HR(2)
           MOVE 'SYR' TO WS-HR(3)
           MOVE 'CUB' TO WS-HR(4)
           MOVE 'MMR' TO WS-HR(5).

       2000-ROUTE-DISPATCH.
           GO TO 2100-ROUTE-CRITICAL.

       2100-ROUTE-CRITICAL.
           ADD 1 TO WS-TOTAL-ALERTS
           EVALUATE TRUE
               WHEN WS-SEV-CRITICAL
                   MOVE 'SAR-TEAM    ' TO WS-TEAM
                   MOVE 1 TO WS-PRIORITY
                   MOVE 4 TO WS-SLA-HOURS
                   MOVE 'Y' TO WS-ESCALATION-FLAG
                   ADD 1 TO WS-DISPATCHED
                   ADD 1 TO WS-ESCALATED
               WHEN WS-SEV-HIGH
                   MOVE 'INVESTIGATE ' TO WS-TEAM
                   MOVE 2 TO WS-PRIORITY
                   MOVE 24 TO WS-SLA-HOURS
                   ADD 1 TO WS-DISPATCHED
                   PERFORM 2200-CHECK-COUNTRY-RISK
               WHEN WS-SEV-MEDIUM
                   MOVE 'L1-REVIEW   ' TO WS-TEAM
                   MOVE 3 TO WS-PRIORITY
                   MOVE 72 TO WS-SLA-HOURS
                   ADD 1 TO WS-DISPATCHED
               WHEN WS-SEV-LOW
                   MOVE 'AUTO-CLOSE  ' TO WS-TEAM
                   MOVE 4 TO WS-PRIORITY
                   MOVE 168 TO WS-SLA-HOURS
                   IF WS-AMOUNT < 1000.00
                       ADD 1 TO WS-DROPPED
                   ELSE
                       ADD 1 TO WS-DISPATCHED
                   END-IF
               WHEN OTHER
                   MOVE 'UNASSIGNED  ' TO WS-TEAM
                   MOVE 9 TO WS-PRIORITY
                   MOVE 24 TO WS-SLA-HOURS
                   ADD 1 TO WS-DISPATCHED
           END-EVALUATE.

       2200-CHECK-COUNTRY-RISK.
           MOVE 'N' TO WS-HR-HIT
           PERFORM VARYING WS-HR-IDX FROM 1 BY 1
               UNTIL WS-HR-IDX > 5
               OR WS-IS-HIGH-RISK-CTY
               IF WS-COUNTRY-CODE = WS-HR(WS-HR-IDX)
                   MOVE 'Y' TO WS-HR-HIT
                   MOVE 'Y' TO WS-ESCALATION-FLAG
                   ADD 1 TO WS-ESCALATED
               END-IF
           END-PERFORM.

       3000-CHECK-ESCALATION.
           MOVE SPACES TO WS-RESULT-BUF
           MOVE 1 TO WS-RESULT-PTR
           IF WS-ESCALATE
               STRING 'ALERT ' WS-ALERT-ID
                   ' ESCALATED TO ' WS-TEAM
                   DELIMITED BY SIZE
                   INTO WS-RESULT-BUF
                   WITH POINTER WS-RESULT-PTR
               END-STRING
           ELSE
               STRING 'ALERT ' WS-ALERT-ID
                   ' ROUTED TO ' WS-TEAM
                   DELIMITED BY SIZE
                   INTO WS-RESULT-BUF
                   WITH POINTER WS-RESULT-PTR
               END-STRING
           END-IF
           MOVE 0 TO WS-TALLY-WORK
           INSPECT WS-ALERT-ID
               TALLYING WS-TALLY-WORK FOR ALL '-'.

       4000-DISPLAY-RESULTS.
           DISPLAY WS-RESULT-BUF
           DISPLAY 'AML DISPATCH RESULTS'
           DISPLAY 'TOTAL ALERTS:   ' WS-TOTAL-ALERTS
           DISPLAY 'DISPATCHED:     ' WS-DISPATCHED
           DISPLAY 'ESCALATED:      ' WS-ESCALATED
           DISPLAY 'DROPPED:        ' WS-DROPPED
           DISPLAY 'TEAM:           ' WS-TEAM
           DISPLAY 'PRIORITY:       ' WS-PRIORITY
           DISPLAY 'SLA HOURS:      ' WS-SLA-HOURS.
