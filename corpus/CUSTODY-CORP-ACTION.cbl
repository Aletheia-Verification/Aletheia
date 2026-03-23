       IDENTIFICATION DIVISION.
       PROGRAM-ID. CUSTODY-CORP-ACTION.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT EVENT-FILE ASSIGN TO 'CAEVENTS'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-EVT-STATUS.
           SELECT HOLDING-FILE ASSIGN TO 'HOLDFILE'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-HLD-STATUS.
           SELECT OUTPUT-FILE ASSIGN TO 'CAOUT'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-OUT-STATUS.
           SELECT SORT-FILE ASSIGN TO 'SORTWORK'.

       DATA DIVISION.
       FILE SECTION.

       FD EVENT-FILE.
       01 EVENT-RECORD.
           05 EVT-CUSIP               PIC X(9).
           05 EVT-TYPE                PIC X(2).
               88 EVT-DIVIDEND        VALUE 'DV'.
               88 EVT-STOCK-SPLIT     VALUE 'SP'.
               88 EVT-MERGER          VALUE 'MG'.
               88 EVT-SPIN-OFF        VALUE 'SO'.
               88 EVT-RIGHTS-ISSUE    VALUE 'RI'.
           05 EVT-EX-DATE             PIC 9(8).
           05 EVT-RECORD-DATE         PIC 9(8).
           05 EVT-PAY-DATE            PIC 9(8).
           05 EVT-RATIO-NUM           PIC S9(5) COMP-3.
           05 EVT-RATIO-DEN           PIC S9(5) COMP-3.
           05 EVT-CASH-AMT            PIC S9(9)V9(4) COMP-3.
           05 EVT-NEW-CUSIP           PIC X(9).

       SD SORT-FILE.
       01 SORT-RECORD.
           05 SORT-CUSIP              PIC X(9).
           05 SORT-TYPE               PIC X(2).
           05 SORT-EX-DATE            PIC 9(8).
           05 SORT-REC-DATE           PIC 9(8).
           05 SORT-PAY-DATE           PIC 9(8).
           05 SORT-RATIO-NUM          PIC S9(5) COMP-3.
           05 SORT-RATIO-DEN          PIC S9(5) COMP-3.
           05 SORT-CASH-AMT           PIC S9(9)V9(4) COMP-3.
           05 SORT-NEW-CUSIP          PIC X(9).

       FD HOLDING-FILE.
       01 HOLD-RECORD.
           05 HLD-ACCT-ID             PIC X(12).
           05 HLD-CUSIP               PIC X(9).
           05 HLD-SHARES              PIC S9(9) COMP-3.

       FD OUTPUT-FILE.
       01 OUT-RECORD.
           05 OUT-ACCT-ID             PIC X(12).
           05 OUT-CUSIP               PIC X(9).
           05 OUT-EVENT-TYPE          PIC X(12).
           05 OUT-SHARES-BEFORE       PIC S9(9) COMP-3.
           05 OUT-SHARES-AFTER        PIC S9(9) COMP-3.
           05 OUT-CASH-ENTITLE        PIC S9(11)V99 COMP-3.
           05 OUT-NEW-CUSIP           PIC X(9).

       WORKING-STORAGE SECTION.

       01 WS-EVT-STATUS               PIC X(2).
       01 WS-HLD-STATUS               PIC X(2).
       01 WS-OUT-STATUS               PIC X(2).
       01 WS-EVT-EOF                  PIC X VALUE 'N'.
           88 WS-EVT-DONE             VALUE 'Y'.
       01 WS-HLD-EOF                  PIC X VALUE 'N'.
           88 WS-HLD-DONE             VALUE 'Y'.

       01 WS-NEW-SHARES               PIC S9(11) COMP-3.
       01 WS-CASH-AMOUNT              PIC S9(11)V99 COMP-3.
       01 WS-FRACTIONAL               PIC S9(9)V9(6) COMP-3.

       01 WS-COUNTERS.
           05 WS-EVENTS-PROC          PIC S9(5) COMP-3 VALUE 0.
           05 WS-HOLDINGS-PROC        PIC S9(7) COMP-3 VALUE 0.
           05 WS-ENTRIES-WRITTEN       PIC S9(7) COMP-3 VALUE 0.
           05 WS-TOTAL-CASH           PIC S9(13)V99 COMP-3
               VALUE 0.

       01 WS-EVT-LABEL                PIC X(12).
       01 WS-CUSIP-TALLY              PIC 9(3).

       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           SORT SORT-FILE
               ON ASCENDING KEY SORT-CUSIP SORT-EX-DATE
               USING EVENT-FILE
               GIVING EVENT-FILE
           PERFORM 1000-OPEN-FILES
           PERFORM 1100-READ-EVENT
           PERFORM 2000-PROCESS-EVENT
               UNTIL WS-EVT-DONE
           PERFORM 3000-CLOSE-FILES
           PERFORM 4000-DISPLAY-SUMMARY
           STOP RUN.

       1000-OPEN-FILES.
           OPEN INPUT EVENT-FILE
           OPEN INPUT HOLDING-FILE
           OPEN OUTPUT OUTPUT-FILE
           MOVE 'N' TO WS-EVT-EOF
           MOVE 'N' TO WS-HLD-EOF.

       1100-READ-EVENT.
           READ EVENT-FILE
               AT END MOVE 'Y' TO WS-EVT-EOF
           END-READ.

       2000-PROCESS-EVENT.
           ADD 1 TO WS-EVENTS-PROC
           EVALUATE TRUE
               WHEN EVT-DIVIDEND
                   MOVE 'DIVIDEND    ' TO WS-EVT-LABEL
               WHEN EVT-STOCK-SPLIT
                   MOVE 'STOCK SPLIT ' TO WS-EVT-LABEL
               WHEN EVT-MERGER
                   MOVE 'MERGER      ' TO WS-EVT-LABEL
               WHEN EVT-SPIN-OFF
                   MOVE 'SPIN-OFF    ' TO WS-EVT-LABEL
               WHEN EVT-RIGHTS-ISSUE
                   MOVE 'RIGHTS      ' TO WS-EVT-LABEL
               WHEN OTHER
                   MOVE 'UNKNOWN     ' TO WS-EVT-LABEL
           END-EVALUATE
           CLOSE HOLDING-FILE
           OPEN INPUT HOLDING-FILE
           MOVE 'N' TO WS-HLD-EOF
           READ HOLDING-FILE
               AT END MOVE 'Y' TO WS-HLD-EOF
           END-READ
           PERFORM 2100-SCAN-HOLDINGS
               UNTIL WS-HLD-DONE
           READ EVENT-FILE
               AT END MOVE 'Y' TO WS-EVT-EOF
           END-READ.

       2100-SCAN-HOLDINGS.
           IF HLD-CUSIP = EVT-CUSIP
               ADD 1 TO WS-HOLDINGS-PROC
               PERFORM 2200-APPLY-ACTION
           END-IF
           READ HOLDING-FILE
               AT END MOVE 'Y' TO WS-HLD-EOF
           END-READ.

       2200-APPLY-ACTION.
           MOVE HLD-ACCT-ID TO OUT-ACCT-ID
           MOVE HLD-CUSIP TO OUT-CUSIP
           MOVE WS-EVT-LABEL TO OUT-EVENT-TYPE
           MOVE HLD-SHARES TO OUT-SHARES-BEFORE
           EVALUATE TRUE
               WHEN EVT-DIVIDEND
                   COMPUTE WS-CASH-AMOUNT =
                       HLD-SHARES * EVT-CASH-AMT
                   MOVE HLD-SHARES TO OUT-SHARES-AFTER
                   MOVE WS-CASH-AMOUNT TO OUT-CASH-ENTITLE
                   ADD WS-CASH-AMOUNT TO WS-TOTAL-CASH
               WHEN EVT-STOCK-SPLIT
                   IF EVT-RATIO-DEN > 0
                       COMPUTE WS-FRACTIONAL =
                           HLD-SHARES *
                           EVT-RATIO-NUM /
                           EVT-RATIO-DEN
                       COMPUTE WS-NEW-SHARES =
                           WS-FRACTIONAL
                   ELSE
                       MOVE HLD-SHARES TO WS-NEW-SHARES
                   END-IF
                   MOVE WS-NEW-SHARES TO OUT-SHARES-AFTER
                   MOVE 0 TO OUT-CASH-ENTITLE
               WHEN EVT-MERGER
                   IF EVT-RATIO-DEN > 0
                       COMPUTE WS-NEW-SHARES =
                           HLD-SHARES *
                           EVT-RATIO-NUM /
                           EVT-RATIO-DEN
                   ELSE
                       MOVE 0 TO WS-NEW-SHARES
                   END-IF
                   MOVE WS-NEW-SHARES TO OUT-SHARES-AFTER
                   COMPUTE WS-CASH-AMOUNT =
                       HLD-SHARES * EVT-CASH-AMT
                   MOVE WS-CASH-AMOUNT TO OUT-CASH-ENTITLE
                   ADD WS-CASH-AMOUNT TO WS-TOTAL-CASH
               WHEN OTHER
                   MOVE HLD-SHARES TO OUT-SHARES-AFTER
                   MOVE 0 TO OUT-CASH-ENTITLE
           END-EVALUATE
           MOVE EVT-NEW-CUSIP TO OUT-NEW-CUSIP
           WRITE OUT-RECORD
           ADD 1 TO WS-ENTRIES-WRITTEN.

       3000-CLOSE-FILES.
           CLOSE EVENT-FILE
           CLOSE HOLDING-FILE
           CLOSE OUTPUT-FILE.

       4000-DISPLAY-SUMMARY.
           MOVE 0 TO WS-CUSIP-TALLY
           INSPECT EVT-CUSIP
               TALLYING WS-CUSIP-TALLY FOR ALL '0'
           DISPLAY 'CORPORATE ACTION PROCESSING COMPLETE'
           DISPLAY 'EVENTS PROCESSED:   ' WS-EVENTS-PROC
           DISPLAY 'HOLDINGS AFFECTED:  ' WS-HOLDINGS-PROC
           DISPLAY 'ENTRIES WRITTEN:    ' WS-ENTRIES-WRITTEN
           DISPLAY 'TOTAL CASH ENTITLE: ' WS-TOTAL-CASH.
