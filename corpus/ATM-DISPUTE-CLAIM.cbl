       IDENTIFICATION DIVISION.
       PROGRAM-ID. ATM-DISPUTE-CLAIM.
      *================================================================*
      * ATM Dispute and Provisional Credit Engine                      *
      * Processes ATM transaction disputes, issues provisional         *
      * credits within Reg E timelines, tracks investigation status.   *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- Dispute Table ---
       01  WS-DISPUTE-TABLE.
           05  WS-DISP-ENTRY OCCURS 6 TIMES.
               10  WS-DISP-ID         PIC 9(8).
               10  WS-DISP-ACCT       PIC 9(10).
               10  WS-DISP-AMT        PIC S9(7)V99 COMP-3.
               10  WS-DISP-TXN-DATE   PIC 9(8).
               10  WS-DISP-FILE-DATE  PIC 9(8).
               10  WS-DISP-REASON     PIC 9.
               10  WS-DISP-STATUS     PIC 9.
               10  WS-DISP-PROV-CR    PIC S9(7)V99 COMP-3.
               10  WS-DISP-DAYS-OPEN  PIC S9(3) COMP-3.
       01  WS-DISP-IDX               PIC 9(3).
       01  WS-DISP-COUNT             PIC 9(3).
      *--- Dispute Reasons ---
       01  WS-RSN-FLAG                PIC 9.
           88  WS-RSN-NOT-DISPENSED   VALUE 1.
           88  WS-RSN-WRONG-AMOUNT   VALUE 2.
           88  WS-RSN-UNAUTHORIZED    VALUE 3.
           88  WS-RSN-DUPLICATE       VALUE 4.
      *--- Status Values ---
       01  WS-STAT-FLAG               PIC 9.
           88  WS-STAT-NEW           VALUE 1.
           88  WS-STAT-INVESTIGATING VALUE 2.
           88  WS-STAT-PROV-CREDIT   VALUE 3.
           88  WS-STAT-RESOLVED      VALUE 4.
      *--- Reg E Timelines ---
       01  WS-PROV-CREDIT-DAYS       PIC S9(3) COMP-3.
       01  WS-INVESTIGATION-DAYS     PIC S9(3) COMP-3.
       01  WS-FINAL-DEADLINE         PIC S9(3) COMP-3.
       01  WS-IS-NEW-ACCT            PIC 9.
      *--- Totals ---
       01  WS-TOTAL-DISPUTED         PIC S9(9)V99 COMP-3.
       01  WS-TOTAL-PROV-CREDITS     PIC S9(9)V99 COMP-3.
       01  WS-NEW-COUNT              PIC S9(3) COMP-3.
       01  WS-INVESTIGATING-CT       PIC S9(3) COMP-3.
       01  WS-PROV-CREDIT-CT         PIC S9(3) COMP-3.
       01  WS-RESOLVED-CT            PIC S9(3) COMP-3.
       01  WS-DEADLINE-RISK-CT       PIC S9(3) COMP-3.
      *--- Display ---
       01  WS-DSP-AMT                PIC -$$,$$$,$$9.99.
       01  WS-DSP-CT                 PIC ZZ9.
       01  WS-DSP-DAYS               PIC ZZ9.
      *--- String ---
       01  WS-REASON-TEXT            PIC X(20).
       01  WS-STATUS-TEXT            PIC X(15).
       01  WS-REASON-TALLY          PIC S9(3) COMP-3.

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-DISPUTES
           PERFORM 3000-PROCESS-DISPUTES
           PERFORM 4000-COMPUTE-TOTALS
           PERFORM 5000-DISPLAY-REPORT
           STOP RUN.

       1000-INITIALIZE.
           MOVE 10 TO WS-PROV-CREDIT-DAYS
           MOVE 45 TO WS-INVESTIGATION-DAYS
           MOVE 90 TO WS-FINAL-DEADLINE
           MOVE 0 TO WS-IS-NEW-ACCT
           MOVE 0 TO WS-TOTAL-DISPUTED
           MOVE 0 TO WS-TOTAL-PROV-CREDITS
           MOVE 0 TO WS-NEW-COUNT
           MOVE 0 TO WS-INVESTIGATING-CT
           MOVE 0 TO WS-PROV-CREDIT-CT
           MOVE 0 TO WS-RESOLVED-CT
           MOVE 0 TO WS-DEADLINE-RISK-CT.

       2000-LOAD-DISPUTES.
           MOVE 5 TO WS-DISP-COUNT
           MOVE 30000001 TO WS-DISP-ID(1)
           MOVE 1122334455 TO WS-DISP-ACCT(1)
           MOVE 200.00 TO WS-DISP-AMT(1)
           MOVE 20260310 TO WS-DISP-TXN-DATE(1)
           MOVE 20260312 TO WS-DISP-FILE-DATE(1)
           MOVE 1 TO WS-DISP-REASON(1)
           MOVE 1 TO WS-DISP-STATUS(1)
           MOVE 0 TO WS-DISP-PROV-CR(1)
           MOVE 9 TO WS-DISP-DAYS-OPEN(1)
           MOVE 30000002 TO WS-DISP-ID(2)
           MOVE 2233445566 TO WS-DISP-ACCT(2)
           MOVE 500.00 TO WS-DISP-AMT(2)
           MOVE 20260301 TO WS-DISP-TXN-DATE(2)
           MOVE 20260303 TO WS-DISP-FILE-DATE(2)
           MOVE 3 TO WS-DISP-REASON(2)
           MOVE 2 TO WS-DISP-STATUS(2)
           MOVE 0 TO WS-DISP-PROV-CR(2)
           MOVE 18 TO WS-DISP-DAYS-OPEN(2)
           MOVE 30000003 TO WS-DISP-ID(3)
           MOVE 3344556677 TO WS-DISP-ACCT(3)
           MOVE 100.00 TO WS-DISP-AMT(3)
           MOVE 20260215 TO WS-DISP-TXN-DATE(3)
           MOVE 20260218 TO WS-DISP-FILE-DATE(3)
           MOVE 2 TO WS-DISP-REASON(3)
           MOVE 3 TO WS-DISP-STATUS(3)
           MOVE 100.00 TO WS-DISP-PROV-CR(3)
           MOVE 31 TO WS-DISP-DAYS-OPEN(3)
           MOVE 30000004 TO WS-DISP-ID(4)
           MOVE 4455667788 TO WS-DISP-ACCT(4)
           MOVE 300.00 TO WS-DISP-AMT(4)
           MOVE 20260101 TO WS-DISP-TXN-DATE(4)
           MOVE 20260105 TO WS-DISP-FILE-DATE(4)
           MOVE 4 TO WS-DISP-REASON(4)
           MOVE 4 TO WS-DISP-STATUS(4)
           MOVE 300.00 TO WS-DISP-PROV-CR(4)
           MOVE 75 TO WS-DISP-DAYS-OPEN(4)
           MOVE 30000005 TO WS-DISP-ID(5)
           MOVE 5566778899 TO WS-DISP-ACCT(5)
           MOVE 1000.00 TO WS-DISP-AMT(5)
           MOVE 20260201 TO WS-DISP-TXN-DATE(5)
           MOVE 20260204 TO WS-DISP-FILE-DATE(5)
           MOVE 1 TO WS-DISP-REASON(5)
           MOVE 2 TO WS-DISP-STATUS(5)
           MOVE 0 TO WS-DISP-PROV-CR(5)
           MOVE 45 TO WS-DISP-DAYS-OPEN(5).

       3000-PROCESS-DISPUTES.
           PERFORM VARYING WS-DISP-IDX FROM 1 BY 1
               UNTIL WS-DISP-IDX > WS-DISP-COUNT
               ADD WS-DISP-AMT(WS-DISP-IDX)
                   TO WS-TOTAL-DISPUTED
               EVALUATE WS-DISP-STATUS(WS-DISP-IDX)
                   WHEN 1
                       ADD 1 TO WS-NEW-COUNT
                       IF WS-DISP-DAYS-OPEN(WS-DISP-IDX)
                           >= WS-PROV-CREDIT-DAYS
                           MOVE WS-DISP-AMT(WS-DISP-IDX)
                               TO WS-DISP-PROV-CR(WS-DISP-IDX)
                           MOVE 3
                               TO WS-DISP-STATUS(WS-DISP-IDX)
                       END-IF
                   WHEN 2
                       ADD 1 TO WS-INVESTIGATING-CT
                       IF WS-DISP-DAYS-OPEN(WS-DISP-IDX)
                           >= WS-PROV-CREDIT-DAYS
                           IF WS-DISP-PROV-CR(WS-DISP-IDX)
                               = 0
                               MOVE WS-DISP-AMT(WS-DISP-IDX)
                                   TO WS-DISP-PROV-CR
                                       (WS-DISP-IDX)
                               MOVE 3
                                   TO WS-DISP-STATUS
                                       (WS-DISP-IDX)
                           END-IF
                       END-IF
                   WHEN 3
                       ADD 1 TO WS-PROV-CREDIT-CT
                   WHEN 4
                       ADD 1 TO WS-RESOLVED-CT
               END-EVALUATE
               IF WS-DISP-DAYS-OPEN(WS-DISP-IDX) >=
                   WS-INVESTIGATION-DAYS
                   IF WS-DISP-STATUS(WS-DISP-IDX) NOT = 4
                       ADD 1 TO WS-DEADLINE-RISK-CT
                   END-IF
               END-IF
               ADD WS-DISP-PROV-CR(WS-DISP-IDX)
                   TO WS-TOTAL-PROV-CREDITS
           END-PERFORM.

       4000-COMPUTE-TOTALS.
           MOVE 0 TO WS-REASON-TALLY
           PERFORM VARYING WS-DISP-IDX FROM 1 BY 1
               UNTIL WS-DISP-IDX > WS-DISP-COUNT
               IF WS-DISP-REASON(WS-DISP-IDX) = 3
                   ADD 1 TO WS-REASON-TALLY
               END-IF
           END-PERFORM.

       5000-DISPLAY-REPORT.
           DISPLAY "========================================"
           DISPLAY "   ATM DISPUTE STATUS"
           DISPLAY "========================================"
           PERFORM VARYING WS-DISP-IDX FROM 1 BY 1
               UNTIL WS-DISP-IDX > WS-DISP-COUNT
               EVALUATE WS-DISP-REASON(WS-DISP-IDX)
                   WHEN 1
                       MOVE "NOT DISPENSED"
                           TO WS-REASON-TEXT
                   WHEN 2
                       MOVE "WRONG AMOUNT"
                           TO WS-REASON-TEXT
                   WHEN 3
                       MOVE "UNAUTHORIZED"
                           TO WS-REASON-TEXT
                   WHEN 4
                       MOVE "DUPLICATE"
                           TO WS-REASON-TEXT
               END-EVALUATE
               EVALUATE WS-DISP-STATUS(WS-DISP-IDX)
                   WHEN 1
                       MOVE "NEW" TO WS-STATUS-TEXT
                   WHEN 2
                       MOVE "INVESTIGATING"
                           TO WS-STATUS-TEXT
                   WHEN 3
                       MOVE "PROV CREDIT"
                           TO WS-STATUS-TEXT
                   WHEN 4
                       MOVE "RESOLVED"
                           TO WS-STATUS-TEXT
               END-EVALUATE
               MOVE WS-DISP-AMT(WS-DISP-IDX)
                   TO WS-DSP-AMT
               DISPLAY WS-DISP-ID(WS-DISP-IDX) " "
                   WS-REASON-TEXT " "
                   WS-DSP-AMT " " WS-STATUS-TEXT
           END-PERFORM
           DISPLAY "--- SUMMARY ---"
           MOVE WS-TOTAL-DISPUTED TO WS-DSP-AMT
           DISPLAY "TOTAL DISPUTED: " WS-DSP-AMT
           MOVE WS-TOTAL-PROV-CREDITS TO WS-DSP-AMT
           DISPLAY "PROV CREDITS:   " WS-DSP-AMT
           MOVE WS-DEADLINE-RISK-CT TO WS-DSP-CT
           DISPLAY "DEADLINE RISK:  " WS-DSP-CT
           IF WS-REASON-TALLY > 0
               DISPLAY "*** UNAUTHORIZED CLAIMS: "
                   WS-REASON-TALLY " ***"
           END-IF
           DISPLAY "========================================".
