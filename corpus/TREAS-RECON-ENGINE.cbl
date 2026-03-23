       IDENTIFICATION DIVISION.
       PROGRAM-ID. TREAS-RECON-ENGINE.
      *================================================================*
      * TREASURY RECONCILIATION ENGINE                                 *
      * Matches internal ledger entries against bank statements,       *
      * identifies breaks, computes aging, and tallies tolerance.      *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-LEDGER-TABLE.
           05 WS-LEDGER-ENTRY OCCURS 20.
               10 WS-LED-REF        PIC X(12).
               10 WS-LED-AMOUNT     PIC S9(11)V99 COMP-3.
               10 WS-LED-DATE       PIC 9(8).
               10 WS-LED-TYPE       PIC X(2).
                   88 WS-LED-DR     VALUE 'DR'.
                   88 WS-LED-CR     VALUE 'CR'.
               10 WS-LED-MATCHED    PIC X VALUE 'N'.
                   88 WS-LED-IS-MATCHED VALUE 'Y'.
       01 WS-STMT-TABLE.
           05 WS-STMT-ENTRY OCCURS 20.
               10 WS-STM-REF        PIC X(12).
               10 WS-STM-AMOUNT     PIC S9(11)V99 COMP-3.
               10 WS-STM-DATE       PIC 9(8).
               10 WS-STM-TYPE       PIC X(2).
               10 WS-STM-MATCHED    PIC X VALUE 'N'.
                   88 WS-STM-IS-MATCHED VALUE 'Y'.
       01 WS-COUNTS.
           05 WS-LEDGER-COUNT       PIC S9(3) COMP-3.
           05 WS-STMT-COUNT         PIC S9(3) COMP-3.
           05 WS-MATCHED-COUNT      PIC S9(3) COMP-3.
           05 WS-LED-BREAK-COUNT    PIC S9(3) COMP-3.
           05 WS-STM-BREAK-COUNT    PIC S9(3) COMP-3.
       01 WS-TOTALS.
           05 WS-LED-TOTAL-DR       PIC S9(13)V99 COMP-3.
           05 WS-LED-TOTAL-CR       PIC S9(13)V99 COMP-3.
           05 WS-STM-TOTAL-DR       PIC S9(13)V99 COMP-3.
           05 WS-STM-TOTAL-CR       PIC S9(13)V99 COMP-3.
           05 WS-NET-DIFF           PIC S9(13)V99 COMP-3.
           05 WS-BREAK-AMT-TOTAL    PIC S9(13)V99 COMP-3.
       01 WS-TOLERANCE              PIC S9(3)V99 COMP-3
           VALUE 0.05.
       01 WS-AMT-DIFF               PIC S9(11)V99 COMP-3.
       01 WS-ABS-DIFF               PIC S9(11)V99 COMP-3.
       01 WS-RECON-STATUS           PIC X(15).
       01 WS-IDX-L                  PIC S9(3) COMP-3.
       01 WS-IDX-S                  PIC S9(3) COMP-3.
       01 WS-AGING-BUCKET.
           05 WS-AGE-0-7            PIC S9(3) COMP-3.
           05 WS-AGE-8-30           PIC S9(3) COMP-3.
           05 WS-AGE-31-90          PIC S9(3) COMP-3.
           05 WS-AGE-OVER-90        PIC S9(3) COMP-3.
       01 WS-CURRENT-DATE           PIC 9(8).
       01 WS-DAY-DIFF               PIC S9(5) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-LEDGER
           PERFORM 3000-LOAD-STATEMENT
           PERFORM 4000-MATCH-ENTRIES
           PERFORM 5000-TALLY-TOTALS
           PERFORM 6000-AGE-BREAKS
           PERFORM 7000-DETERMINE-STATUS
           PERFORM 8000-DISPLAY-REPORT
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-MATCHED-COUNT
           MOVE 0 TO WS-LED-BREAK-COUNT
           MOVE 0 TO WS-STM-BREAK-COUNT
           MOVE 0 TO WS-LED-TOTAL-DR
           MOVE 0 TO WS-LED-TOTAL-CR
           MOVE 0 TO WS-STM-TOTAL-DR
           MOVE 0 TO WS-STM-TOTAL-CR
           MOVE 0 TO WS-NET-DIFF
           MOVE 0 TO WS-BREAK-AMT-TOTAL
           MOVE 0 TO WS-AGE-0-7
           MOVE 0 TO WS-AGE-8-30
           MOVE 0 TO WS-AGE-31-90
           MOVE 0 TO WS-AGE-OVER-90
           MOVE 20260315 TO WS-CURRENT-DATE.
       2000-LOAD-LEDGER.
           MOVE 5 TO WS-LEDGER-COUNT
           MOVE 'REF000000001' TO WS-LED-REF(1)
           MOVE 50000.00 TO WS-LED-AMOUNT(1)
           MOVE 20260310 TO WS-LED-DATE(1)
           MOVE 'DR' TO WS-LED-TYPE(1)
           MOVE 'N' TO WS-LED-MATCHED(1)
           MOVE 'REF000000002' TO WS-LED-REF(2)
           MOVE 25000.00 TO WS-LED-AMOUNT(2)
           MOVE 20260311 TO WS-LED-DATE(2)
           MOVE 'CR' TO WS-LED-TYPE(2)
           MOVE 'N' TO WS-LED-MATCHED(2)
           MOVE 'REF000000003' TO WS-LED-REF(3)
           MOVE 75000.00 TO WS-LED-AMOUNT(3)
           MOVE 20260312 TO WS-LED-DATE(3)
           MOVE 'DR' TO WS-LED-TYPE(3)
           MOVE 'N' TO WS-LED-MATCHED(3)
           MOVE 'REF000000004' TO WS-LED-REF(4)
           MOVE 12500.50 TO WS-LED-AMOUNT(4)
           MOVE 20260205 TO WS-LED-DATE(4)
           MOVE 'DR' TO WS-LED-TYPE(4)
           MOVE 'N' TO WS-LED-MATCHED(4)
           MOVE 'REF000000005' TO WS-LED-REF(5)
           MOVE 8000.00 TO WS-LED-AMOUNT(5)
           MOVE 20260314 TO WS-LED-DATE(5)
           MOVE 'CR' TO WS-LED-TYPE(5)
           MOVE 'N' TO WS-LED-MATCHED(5).
       3000-LOAD-STATEMENT.
           MOVE 4 TO WS-STMT-COUNT
           MOVE 'REF000000001' TO WS-STM-REF(1)
           MOVE 50000.00 TO WS-STM-AMOUNT(1)
           MOVE 20260310 TO WS-STM-DATE(1)
           MOVE 'DR' TO WS-STM-TYPE(1)
           MOVE 'N' TO WS-STM-MATCHED(1)
           MOVE 'REF000000002' TO WS-STM-REF(2)
           MOVE 25000.00 TO WS-STM-AMOUNT(2)
           MOVE 20260311 TO WS-STM-DATE(2)
           MOVE 'CR' TO WS-STM-TYPE(2)
           MOVE 'N' TO WS-STM-MATCHED(2)
           MOVE 'REF000000003' TO WS-STM-REF(3)
           MOVE 75000.02 TO WS-STM-AMOUNT(3)
           MOVE 20260312 TO WS-STM-DATE(3)
           MOVE 'DR' TO WS-STM-TYPE(3)
           MOVE 'N' TO WS-STM-MATCHED(3)
           MOVE 'REFEXTERNAL1' TO WS-STM-REF(4)
           MOVE 3200.00 TO WS-STM-AMOUNT(4)
           MOVE 20260313 TO WS-STM-DATE(4)
           MOVE 'CR' TO WS-STM-TYPE(4)
           MOVE 'N' TO WS-STM-MATCHED(4).
       4000-MATCH-ENTRIES.
           PERFORM VARYING WS-IDX-L FROM 1 BY 1
               UNTIL WS-IDX-L > WS-LEDGER-COUNT
               IF NOT WS-LED-IS-MATCHED(WS-IDX-L)
                   PERFORM VARYING WS-IDX-S FROM 1 BY 1
                       UNTIL WS-IDX-S > WS-STMT-COUNT
                       IF NOT WS-STM-IS-MATCHED(WS-IDX-S)
                           IF WS-LED-REF(WS-IDX-L) =
                               WS-STM-REF(WS-IDX-S)
                               PERFORM 4100-CHECK-TOLERANCE
                           END-IF
                       END-IF
                   END-PERFORM
               END-IF
           END-PERFORM.
       4100-CHECK-TOLERANCE.
           COMPUTE WS-AMT-DIFF =
               WS-LED-AMOUNT(WS-IDX-L) -
               WS-STM-AMOUNT(WS-IDX-S)
           COMPUTE WS-ABS-DIFF =
               FUNCTION ABS(WS-AMT-DIFF)
           IF WS-ABS-DIFF <= WS-TOLERANCE
               MOVE 'Y' TO WS-LED-MATCHED(WS-IDX-L)
               MOVE 'Y' TO WS-STM-MATCHED(WS-IDX-S)
               ADD 1 TO WS-MATCHED-COUNT
           ELSE
               ADD WS-ABS-DIFF TO WS-BREAK-AMT-TOTAL
           END-IF.
       5000-TALLY-TOTALS.
           PERFORM VARYING WS-IDX-L FROM 1 BY 1
               UNTIL WS-IDX-L > WS-LEDGER-COUNT
               IF WS-LED-DR(WS-IDX-L)
                   ADD WS-LED-AMOUNT(WS-IDX-L) TO
                       WS-LED-TOTAL-DR
               ELSE
                   ADD WS-LED-AMOUNT(WS-IDX-L) TO
                       WS-LED-TOTAL-CR
               END-IF
               IF NOT WS-LED-IS-MATCHED(WS-IDX-L)
                   ADD 1 TO WS-LED-BREAK-COUNT
               END-IF
           END-PERFORM
           PERFORM VARYING WS-IDX-S FROM 1 BY 1
               UNTIL WS-IDX-S > WS-STMT-COUNT
               IF WS-STM-TYPE(WS-IDX-S) = 'DR'
                   ADD WS-STM-AMOUNT(WS-IDX-S) TO
                       WS-STM-TOTAL-DR
               ELSE
                   ADD WS-STM-AMOUNT(WS-IDX-S) TO
                       WS-STM-TOTAL-CR
               END-IF
               IF NOT WS-STM-IS-MATCHED(WS-IDX-S)
                   ADD 1 TO WS-STM-BREAK-COUNT
               END-IF
           END-PERFORM
           COMPUTE WS-NET-DIFF =
               (WS-LED-TOTAL-DR - WS-LED-TOTAL-CR) -
               (WS-STM-TOTAL-DR - WS-STM-TOTAL-CR).
       6000-AGE-BREAKS.
           PERFORM VARYING WS-IDX-L FROM 1 BY 1
               UNTIL WS-IDX-L > WS-LEDGER-COUNT
               IF NOT WS-LED-IS-MATCHED(WS-IDX-L)
                   COMPUTE WS-DAY-DIFF =
                       WS-CURRENT-DATE - WS-LED-DATE(WS-IDX-L)
                   EVALUATE TRUE
                       WHEN WS-DAY-DIFF <= 7
                           ADD 1 TO WS-AGE-0-7
                       WHEN WS-DAY-DIFF <= 30
                           ADD 1 TO WS-AGE-8-30
                       WHEN WS-DAY-DIFF <= 90
                           ADD 1 TO WS-AGE-31-90
                       WHEN OTHER
                           ADD 1 TO WS-AGE-OVER-90
                   END-EVALUATE
               END-IF
           END-PERFORM.
       7000-DETERMINE-STATUS.
           IF WS-LED-BREAK-COUNT = 0
               AND WS-STM-BREAK-COUNT = 0
               MOVE 'FULLY MATCHED' TO WS-RECON-STATUS
           ELSE
               IF WS-BREAK-AMT-TOTAL < 100
                   MOVE 'MINOR BREAKS' TO WS-RECON-STATUS
               ELSE
                   MOVE 'BREAKS FOUND' TO WS-RECON-STATUS
               END-IF
           END-IF.
       8000-DISPLAY-REPORT.
           DISPLAY '========================================='
           DISPLAY 'TREASURY RECONCILIATION REPORT'
           DISPLAY '========================================='
           DISPLAY 'LEDGER ENTRIES:     ' WS-LEDGER-COUNT
           DISPLAY 'STATEMENT ENTRIES:  ' WS-STMT-COUNT
           DISPLAY 'MATCHED:            ' WS-MATCHED-COUNT
           DISPLAY 'LEDGER BREAKS:      ' WS-LED-BREAK-COUNT
           DISPLAY 'STATEMENT BREAKS:   ' WS-STM-BREAK-COUNT
           DISPLAY 'LEDGER DEBITS:      ' WS-LED-TOTAL-DR
           DISPLAY 'LEDGER CREDITS:     ' WS-LED-TOTAL-CR
           DISPLAY 'STMT DEBITS:        ' WS-STM-TOTAL-DR
           DISPLAY 'STMT CREDITS:       ' WS-STM-TOTAL-CR
           DISPLAY 'NET DIFFERENCE:     ' WS-NET-DIFF
           DISPLAY 'BREAK AMOUNT:       ' WS-BREAK-AMT-TOTAL
           DISPLAY 'AGE 0-7 DAYS:       ' WS-AGE-0-7
           DISPLAY 'AGE 8-30 DAYS:      ' WS-AGE-8-30
           DISPLAY 'AGE 31-90 DAYS:     ' WS-AGE-31-90
           DISPLAY 'AGE OVER 90 DAYS:   ' WS-AGE-OVER-90
           DISPLAY 'STATUS:             ' WS-RECON-STATUS
           DISPLAY '========================================='.
