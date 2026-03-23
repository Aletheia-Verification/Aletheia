       IDENTIFICATION DIVISION.
       PROGRAM-ID. BSA-CTR-FILING.
      *================================================================
      * BSA Currency Transaction Report Filing
      * Aggregates daily cash transactions per customer, triggers
      * CTR when aggregate exceeds $10,000, builds filing record.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CUSTOMER-INFO.
           05 WS-CUST-ID               PIC X(12).
           05 WS-CUST-NAME             PIC X(30).
           05 WS-CUST-TIN              PIC X(9).
           05 WS-CUST-DOB              PIC 9(8).
           05 WS-CUST-ADDRESS          PIC X(50).
       01 WS-TXN-TABLE.
           05 WS-TXN-ENTRY OCCURS 20
              ASCENDING KEY IS WS-TXN-TIME
              INDEXED BY WS-TXN-IDX.
               10 WS-TXN-TIME          PIC 9(6).
               10 WS-TXN-TYPE          PIC X(2).
                   88 WS-CASH-IN       VALUE 'CI'.
                   88 WS-CASH-OUT      VALUE 'CO'.
                   88 WS-WIRE-IN       VALUE 'WI'.
                   88 WS-WIRE-OUT      VALUE 'WO'.
               10 WS-TXN-AMOUNT        PIC S9(9)V99 COMP-3.
               10 WS-TXN-BRANCH        PIC X(4).
               10 WS-TXN-TELLER        PIC X(6).
       01 WS-TXN-COUNT                 PIC 9(2).
       01 WS-AGGREGATE-FIELDS.
           05 WS-CASH-IN-TOTAL         PIC S9(11)V99 COMP-3.
           05 WS-CASH-OUT-TOTAL        PIC S9(11)V99 COMP-3.
           05 WS-WIRE-IN-TOTAL         PIC S9(11)V99 COMP-3.
           05 WS-WIRE-OUT-TOTAL        PIC S9(11)V99 COMP-3.
           05 WS-GRAND-TOTAL           PIC S9(11)V99 COMP-3.
       01 WS-THRESHOLD-AMT             PIC S9(11)V99 COMP-3
           VALUE 10000.00.
       01 WS-CTR-FIELDS.
           05 WS-CTR-REQUIRED          PIC X(1).
               88 WS-NEEDS-CTR         VALUE 'Y'.
               88 WS-NO-CTR            VALUE 'N'.
           05 WS-CTR-FILE-NUM          PIC 9(8).
           05 WS-CTR-FILING-DATE       PIC 9(8).
           05 WS-CTR-REASON            PIC X(20).
       01 WS-STRUCTURING-FIELDS.
           05 WS-STRUCT-FLAG           PIC X(1).
               88 WS-POSSIBLE-STRUCT   VALUE 'Y'.
           05 WS-NEAR-THRESH           PIC S9(11)V99 COMP-3
               VALUE 8000.00.
           05 WS-TXN-JUST-UNDER        PIC 9(2).
       01 WS-WORK-FIELDS.
           05 WS-TEMP-AMT              PIC S9(11)V99 COMP-3.
           05 WS-BRANCH-COUNT          PIC 9(2).
           05 WS-MULTI-BRANCH          PIC X(1).
               88 WS-IS-MULTI-BRANCH   VALUE 'Y'.
           05 WS-PREV-BRANCH           PIC X(4).
       01 WS-REPORT-DATE               PIC 9(8).
       01 WS-COUNTERS.
           05 WS-CASH-TXN-CT           PIC 9(3).
           05 WS-WIRE-TXN-CT           PIC 9(3).
       01 WS-DIVIDE-FIELDS.
           05 WS-AVG-TXN               PIC S9(9)V99 COMP-3.
           05 WS-DIV-REMAINDER         PIC S9(7)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-AGGREGATE-TXNS
           PERFORM 3000-CHECK-THRESHOLD
           PERFORM 4000-DETECT-STRUCTURING
           PERFORM 5000-BUILD-CTR-RECORD
           PERFORM 6000-DISPLAY-REPORT
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-REPORT-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-CASH-IN-TOTAL
           MOVE 0 TO WS-CASH-OUT-TOTAL
           MOVE 0 TO WS-WIRE-IN-TOTAL
           MOVE 0 TO WS-WIRE-OUT-TOTAL
           MOVE 0 TO WS-GRAND-TOTAL
           SET WS-NO-CTR TO TRUE
           MOVE 'N' TO WS-STRUCT-FLAG
           MOVE 0 TO WS-TXN-JUST-UNDER
           MOVE 0 TO WS-CASH-TXN-CT
           MOVE 0 TO WS-WIRE-TXN-CT
           MOVE SPACES TO WS-PREV-BRANCH
           MOVE 0 TO WS-BRANCH-COUNT.
       2000-AGGREGATE-TXNS.
           PERFORM VARYING WS-TXN-IDX FROM 1 BY 1
               UNTIL WS-TXN-IDX > WS-TXN-COUNT
               EVALUATE TRUE
                   WHEN WS-CASH-IN(WS-TXN-IDX)
                       ADD WS-TXN-AMOUNT(WS-TXN-IDX)
                           TO WS-CASH-IN-TOTAL
                       ADD 1 TO WS-CASH-TXN-CT
                   WHEN WS-CASH-OUT(WS-TXN-IDX)
                       ADD WS-TXN-AMOUNT(WS-TXN-IDX)
                           TO WS-CASH-OUT-TOTAL
                       ADD 1 TO WS-CASH-TXN-CT
                   WHEN WS-WIRE-IN(WS-TXN-IDX)
                       ADD WS-TXN-AMOUNT(WS-TXN-IDX)
                           TO WS-WIRE-IN-TOTAL
                       ADD 1 TO WS-WIRE-TXN-CT
                   WHEN WS-WIRE-OUT(WS-TXN-IDX)
                       ADD WS-TXN-AMOUNT(WS-TXN-IDX)
                           TO WS-WIRE-OUT-TOTAL
                       ADD 1 TO WS-WIRE-TXN-CT
               END-EVALUATE
               IF WS-TXN-BRANCH(WS-TXN-IDX) NOT =
                   WS-PREV-BRANCH
                   ADD 1 TO WS-BRANCH-COUNT
                   MOVE WS-TXN-BRANCH(WS-TXN-IDX)
                       TO WS-PREV-BRANCH
               END-IF
           END-PERFORM
           COMPUTE WS-GRAND-TOTAL =
               WS-CASH-IN-TOTAL + WS-CASH-OUT-TOTAL +
               WS-WIRE-IN-TOTAL + WS-WIRE-OUT-TOTAL
           IF WS-BRANCH-COUNT > 1
               SET WS-IS-MULTI-BRANCH TO TRUE
           END-IF.
       3000-CHECK-THRESHOLD.
           IF WS-CASH-IN-TOTAL > WS-THRESHOLD-AMT
               SET WS-NEEDS-CTR TO TRUE
               MOVE "CASH IN OVER 10K" TO WS-CTR-REASON
           END-IF
           IF WS-CASH-OUT-TOTAL > WS-THRESHOLD-AMT
               SET WS-NEEDS-CTR TO TRUE
               MOVE "CASH OUT OVER 10K" TO WS-CTR-REASON
           END-IF.
       4000-DETECT-STRUCTURING.
           PERFORM VARYING WS-TXN-IDX FROM 1 BY 1
               UNTIL WS-TXN-IDX > WS-TXN-COUNT
               IF WS-TXN-AMOUNT(WS-TXN-IDX) >
                   WS-NEAR-THRESH
               AND WS-TXN-AMOUNT(WS-TXN-IDX) <
                   WS-THRESHOLD-AMT
                   ADD 1 TO WS-TXN-JUST-UNDER
               END-IF
           END-PERFORM
           IF WS-TXN-JUST-UNDER >= 2
               SET WS-POSSIBLE-STRUCT TO TRUE
               SET WS-NEEDS-CTR TO TRUE
               MOVE "POSSIBLE STRUCTURING"
                   TO WS-CTR-REASON
           END-IF.
       5000-BUILD-CTR-RECORD.
           IF WS-NEEDS-CTR
               ADD 1 TO WS-CTR-FILE-NUM
               MOVE WS-REPORT-DATE TO WS-CTR-FILING-DATE
               IF WS-CASH-TXN-CT > 0
                   DIVIDE WS-CASH-IN-TOTAL
                       BY WS-CASH-TXN-CT
                       GIVING WS-AVG-TXN
                       REMAINDER WS-DIV-REMAINDER
               END-IF
               DISPLAY "CTR RECORD BUILT"
           ELSE
               DISPLAY "NO CTR REQUIRED"
           END-IF.
       6000-DISPLAY-REPORT.
           DISPLAY "BSA CTR FILING REPORT"
           DISPLAY "DATE: " WS-REPORT-DATE
           DISPLAY "CUSTOMER: " WS-CUST-NAME
           DISPLAY "TIN: " WS-CUST-TIN
           DISPLAY "CASH IN: " WS-CASH-IN-TOTAL
           DISPLAY "CASH OUT: " WS-CASH-OUT-TOTAL
           DISPLAY "WIRE IN: " WS-WIRE-IN-TOTAL
           DISPLAY "WIRE OUT: " WS-WIRE-OUT-TOTAL
           DISPLAY "GRAND TOTAL: " WS-GRAND-TOTAL
           DISPLAY "CTR REQUIRED: " WS-CTR-REQUIRED
           IF WS-NEEDS-CTR
               DISPLAY "REASON: " WS-CTR-REASON
               DISPLAY "FILE NUMBER: " WS-CTR-FILE-NUM
           END-IF
           IF WS-POSSIBLE-STRUCT
               DISPLAY "WARNING: STRUCTURING SUSPECTED"
               DISPLAY "NEAR-THRESHOLD TXNS: "
                   WS-TXN-JUST-UNDER
           END-IF
           IF WS-IS-MULTI-BRANCH
               DISPLAY "NOTE: MULTI-BRANCH ACTIVITY"
           END-IF.
