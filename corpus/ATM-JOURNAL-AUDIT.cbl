       IDENTIFICATION DIVISION.
       PROGRAM-ID. ATM-JOURNAL-AUDIT.
      *================================================================*
      * ATM Electronic Journal Auditor                                 *
      * Reads ATM journal entries, detects anomalies (reversals,       *
      * partial dispense, timeouts), generates audit exceptions.       *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- Journal Entries ---
       01  WS-JOURNAL-TABLE.
           05  WS-JRN-ENTRY OCCURS 10 TIMES.
               10  WS-JRN-SEQ        PIC 9(8).
               10  WS-JRN-TYPE       PIC 9.
               10  WS-JRN-AMOUNT     PIC S9(7)V99 COMP-3.
               10  WS-JRN-DISPENSED  PIC S9(7)V99 COMP-3.
               10  WS-JRN-CARD       PIC X(16).
               10  WS-JRN-STATUS     PIC 9.
               10  WS-JRN-ANOMALY    PIC 9.
       01  WS-JRN-IDX               PIC 9(3).
       01  WS-JRN-COUNT             PIC 9(3).
      *--- Journal Types ---
       01  WS-J-TYPE                 PIC 9.
           88  WS-J-WITHDRAWAL       VALUE 1.
           88  WS-J-INQUIRY          VALUE 2.
           88  WS-J-REVERSAL         VALUE 3.
           88  WS-J-DEPOSIT          VALUE 4.
           88  WS-J-TRANSFER         VALUE 5.
      *--- Status Values ---
       01  WS-J-STATUS               PIC 9.
           88  WS-J-SUCCESS          VALUE 1.
           88  WS-J-TIMEOUT          VALUE 2.
           88  WS-J-HARDWARE-ERR     VALUE 3.
           88  WS-J-PARTIAL          VALUE 4.
           88  WS-J-CANCELLED        VALUE 5.
      *--- Anomaly Detection ---
       01  WS-ANOMALY-TABLE.
           05  WS-ANOM-ENTRY OCCURS 5 TIMES.
               10  WS-ANOM-SEQ       PIC 9(8).
               10  WS-ANOM-TYPE      PIC X(15).
               10  WS-ANOM-AMOUNT    PIC S9(7)V99 COMP-3.
               10  WS-ANOM-DESC      PIC X(30).
       01  WS-ANOM-IDX              PIC 9(3).
       01  WS-ANOM-COUNT            PIC 9(3).
      *--- Counters ---
       01  WS-SUCCESS-CT            PIC S9(5) COMP-3.
       01  WS-FAILURE-CT            PIC S9(5) COMP-3.
       01  WS-REVERSAL-CT           PIC S9(5) COMP-3.
       01  WS-PARTIAL-CT            PIC S9(5) COMP-3.
       01  WS-TIMEOUT-CT            PIC S9(5) COMP-3.
       01  WS-TOTAL-DISPENSED       PIC S9(9)V99 COMP-3.
       01  WS-TOTAL-REQUESTED       PIC S9(9)V99 COMP-3.
       01  WS-DISPENSE-DIFF         PIC S9(7)V99 COMP-3.
      *--- Card Masking ---
       01  WS-MASKED-CARD           PIC X(16).
       01  WS-CARD-PREFIX           PIC X(4).
       01  WS-CARD-SUFFIX           PIC X(4).
       01  WS-CARD-TALLY            PIC S9(3) COMP-3.
      *--- Display ---
       01  WS-DISP-AMT              PIC -$$,$$$,$$9.99.
       01  WS-DISP-CT               PIC ZZ,ZZ9.

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-JOURNAL
           PERFORM 3000-DETECT-ANOMALIES
           PERFORM 4000-COMPUTE-TOTALS
           PERFORM 5000-DISPLAY-AUDIT
           STOP RUN.

       1000-INITIALIZE.
           MOVE 0 TO WS-ANOM-COUNT
           MOVE 0 TO WS-SUCCESS-CT
           MOVE 0 TO WS-FAILURE-CT
           MOVE 0 TO WS-REVERSAL-CT
           MOVE 0 TO WS-PARTIAL-CT
           MOVE 0 TO WS-TIMEOUT-CT
           MOVE 0 TO WS-TOTAL-DISPENSED
           MOVE 0 TO WS-TOTAL-REQUESTED.

       2000-LOAD-JOURNAL.
           MOVE 8 TO WS-JRN-COUNT
           MOVE 10000001 TO WS-JRN-SEQ(1)
           MOVE 1 TO WS-JRN-TYPE(1)
           MOVE 200.00 TO WS-JRN-AMOUNT(1)
           MOVE 200.00 TO WS-JRN-DISPENSED(1)
           MOVE "4532XXXX1234XXXX" TO WS-JRN-CARD(1)
           MOVE 1 TO WS-JRN-STATUS(1)
           MOVE 10000002 TO WS-JRN-SEQ(2)
           MOVE 1 TO WS-JRN-TYPE(2)
           MOVE 500.00 TO WS-JRN-AMOUNT(2)
           MOVE 400.00 TO WS-JRN-DISPENSED(2)
           MOVE "5412XXXX5678XXXX" TO WS-JRN-CARD(2)
           MOVE 4 TO WS-JRN-STATUS(2)
           MOVE 10000003 TO WS-JRN-SEQ(3)
           MOVE 2 TO WS-JRN-TYPE(3)
           MOVE 0 TO WS-JRN-AMOUNT(3)
           MOVE 0 TO WS-JRN-DISPENSED(3)
           MOVE "4532XXXX1234XXXX" TO WS-JRN-CARD(3)
           MOVE 1 TO WS-JRN-STATUS(3)
           MOVE 10000004 TO WS-JRN-SEQ(4)
           MOVE 3 TO WS-JRN-TYPE(4)
           MOVE -400.00 TO WS-JRN-AMOUNT(4)
           MOVE 0 TO WS-JRN-DISPENSED(4)
           MOVE "5412XXXX5678XXXX" TO WS-JRN-CARD(4)
           MOVE 1 TO WS-JRN-STATUS(4)
           MOVE 10000005 TO WS-JRN-SEQ(5)
           MOVE 1 TO WS-JRN-TYPE(5)
           MOVE 300.00 TO WS-JRN-AMOUNT(5)
           MOVE 0 TO WS-JRN-DISPENSED(5)
           MOVE "6011XXXX9876XXXX" TO WS-JRN-CARD(5)
           MOVE 2 TO WS-JRN-STATUS(5)
           MOVE 10000006 TO WS-JRN-SEQ(6)
           MOVE 1 TO WS-JRN-TYPE(6)
           MOVE 100.00 TO WS-JRN-AMOUNT(6)
           MOVE 100.00 TO WS-JRN-DISPENSED(6)
           MOVE "4532XXXX4321XXXX" TO WS-JRN-CARD(6)
           MOVE 1 TO WS-JRN-STATUS(6)
           MOVE 10000007 TO WS-JRN-SEQ(7)
           MOVE 1 TO WS-JRN-TYPE(7)
           MOVE 200.00 TO WS-JRN-AMOUNT(7)
           MOVE 0 TO WS-JRN-DISPENSED(7)
           MOVE "3782XXXX0000XXXX" TO WS-JRN-CARD(7)
           MOVE 3 TO WS-JRN-STATUS(7)
           MOVE 10000008 TO WS-JRN-SEQ(8)
           MOVE 4 TO WS-JRN-TYPE(8)
           MOVE 250.00 TO WS-JRN-AMOUNT(8)
           MOVE 250.00 TO WS-JRN-DISPENSED(8)
           MOVE "4532XXXX1234XXXX" TO WS-JRN-CARD(8)
           MOVE 1 TO WS-JRN-STATUS(8).

       3000-DETECT-ANOMALIES.
           PERFORM VARYING WS-JRN-IDX FROM 1 BY 1
               UNTIL WS-JRN-IDX > WS-JRN-COUNT
               MOVE 0 TO WS-JRN-ANOMALY(WS-JRN-IDX)
               EVALUATE WS-JRN-STATUS(WS-JRN-IDX)
                   WHEN 1
                       ADD 1 TO WS-SUCCESS-CT
                   WHEN 2
                       ADD 1 TO WS-TIMEOUT-CT
                       ADD 1 TO WS-FAILURE-CT
                       PERFORM 3100-LOG-ANOMALY
                   WHEN 3
                       ADD 1 TO WS-FAILURE-CT
                       PERFORM 3100-LOG-ANOMALY
                   WHEN 4
                       ADD 1 TO WS-PARTIAL-CT
                       PERFORM 3100-LOG-ANOMALY
                   WHEN 5
                       ADD 1 TO WS-FAILURE-CT
               END-EVALUATE
               IF WS-JRN-TYPE(WS-JRN-IDX) = 3
                   ADD 1 TO WS-REVERSAL-CT
               END-IF
               IF WS-JRN-TYPE(WS-JRN-IDX) = 1
                   ADD WS-JRN-AMOUNT(WS-JRN-IDX)
                       TO WS-TOTAL-REQUESTED
                   ADD WS-JRN-DISPENSED(WS-JRN-IDX)
                       TO WS-TOTAL-DISPENSED
               END-IF
           END-PERFORM
           COMPUTE WS-DISPENSE-DIFF =
               WS-TOTAL-REQUESTED - WS-TOTAL-DISPENSED.

       3100-LOG-ANOMALY.
           IF WS-ANOM-COUNT < 5
               ADD 1 TO WS-ANOM-COUNT
               MOVE WS-JRN-SEQ(WS-JRN-IDX)
                   TO WS-ANOM-SEQ(WS-ANOM-COUNT)
               MOVE WS-JRN-AMOUNT(WS-JRN-IDX)
                   TO WS-ANOM-AMOUNT(WS-ANOM-COUNT)
               EVALUATE WS-JRN-STATUS(WS-JRN-IDX)
                   WHEN 2
                       MOVE "TIMEOUT"
                           TO WS-ANOM-TYPE(WS-ANOM-COUNT)
                   WHEN 3
                       MOVE "HARDWARE ERROR"
                           TO WS-ANOM-TYPE(WS-ANOM-COUNT)
                   WHEN 4
                       MOVE "PARTIAL DISP"
                           TO WS-ANOM-TYPE(WS-ANOM-COUNT)
               END-EVALUATE
               MOVE 1 TO WS-JRN-ANOMALY(WS-JRN-IDX)
           END-IF.

       4000-COMPUTE-TOTALS.
           MOVE 0 TO WS-CARD-TALLY
           INSPECT WS-JRN-CARD(1)
               TALLYING WS-CARD-TALLY FOR ALL "X".

       5000-DISPLAY-AUDIT.
           DISPLAY "========================================"
           DISPLAY "   ATM JOURNAL AUDIT"
           DISPLAY "========================================"
           MOVE WS-SUCCESS-CT TO WS-DISP-CT
           DISPLAY "SUCCESSFUL:   " WS-DISP-CT
           MOVE WS-FAILURE-CT TO WS-DISP-CT
           DISPLAY "FAILED:       " WS-DISP-CT
           MOVE WS-REVERSAL-CT TO WS-DISP-CT
           DISPLAY "REVERSALS:    " WS-DISP-CT
           MOVE WS-PARTIAL-CT TO WS-DISP-CT
           DISPLAY "PARTIAL:      " WS-DISP-CT
           MOVE WS-TOTAL-REQUESTED TO WS-DISP-AMT
           DISPLAY "REQUESTED:    " WS-DISP-AMT
           MOVE WS-TOTAL-DISPENSED TO WS-DISP-AMT
           DISPLAY "DISPENSED:    " WS-DISP-AMT
           IF WS-ANOM-COUNT > 0
               DISPLAY "--- ANOMALIES ---"
               PERFORM VARYING WS-ANOM-IDX FROM 1 BY 1
                   UNTIL WS-ANOM-IDX > WS-ANOM-COUNT
                   MOVE WS-ANOM-AMOUNT(WS-ANOM-IDX)
                       TO WS-DISP-AMT
                   DISPLAY "SEQ "
                       WS-ANOM-SEQ(WS-ANOM-IDX) " "
                       WS-ANOM-TYPE(WS-ANOM-IDX) " "
                       WS-DISP-AMT
               END-PERFORM
           END-IF
           DISPLAY "========================================".
