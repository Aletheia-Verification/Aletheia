       IDENTIFICATION DIVISION.
       PROGRAM-ID. OD-PROTECT-LINK.
      *================================================================*
      * Overdraft Protection Linked Account Transfer                   *
      * Manages automatic transfers from savings/LOC to cover          *
      * overdrafts, tracks transfer history, enforces daily limits.    *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- Primary Account ---
       01  WS-PRIMARY-ACCT            PIC 9(10).
       01  WS-PRIMARY-BAL             PIC S9(11)V99 COMP-3.
       01  WS-PRIMARY-AVAIL           PIC S9(11)V99 COMP-3.
      *--- Linked Account ---
       01  WS-LINKED-ACCT             PIC 9(10).
       01  WS-LINKED-BAL              PIC S9(11)V99 COMP-3.
       01  WS-LINKED-TYPE             PIC 9.
           88  WS-LINKED-SAVINGS      VALUE 1.
           88  WS-LINKED-LOC          VALUE 2.
           88  WS-LINKED-NONE         VALUE 0.
       01  WS-LINKED-AVAIL            PIC S9(11)V99 COMP-3.
       01  WS-LOC-LIMIT               PIC S9(11)V99 COMP-3.
       01  WS-LOC-USED                PIC S9(11)V99 COMP-3.
      *--- Pending Debits ---
       01  WS-DEBIT-TABLE.
           05  WS-DEBIT-ENTRY OCCURS 8 TIMES.
               10  WS-DBT-AMOUNT      PIC S9(9)V99 COMP-3.
               10  WS-DBT-DESC        PIC X(25).
               10  WS-DBT-RESULT      PIC 9.
       01  WS-DBT-IDX                 PIC 9(3).
       01  WS-DBT-COUNT               PIC 9(3).
      *--- Result Codes ---
       01  WS-RESULT-CODE             PIC 9.
           88  WS-RESULT-OK           VALUE 1.
           88  WS-RESULT-TRANSFER     VALUE 2.
           88  WS-RESULT-PARTIAL      VALUE 3.
           88  WS-RESULT-DECLINE      VALUE 4.
      *--- Transfer Tracking ---
       01  WS-XFER-COUNT-TODAY        PIC S9(3) COMP-3.
       01  WS-XFER-MAX-DAY            PIC S9(3) COMP-3.
       01  WS-XFER-TOTAL-TODAY        PIC S9(9)V99 COMP-3.
       01  WS-XFER-FEE-EACH          PIC S9(5)V99 COMP-3.
       01  WS-XFER-FEE-TOTAL         PIC S9(7)V99 COMP-3.
       01  WS-MIN-XFER               PIC S9(5)V99 COMP-3.
       01  WS-XFER-INCREMENT          PIC S9(5)V99 COMP-3.
      *--- Shortfall Calculation ---
       01  WS-SHORTFALL               PIC S9(9)V99 COMP-3.
       01  WS-NEEDED-AMT              PIC S9(9)V99 COMP-3.
       01  WS-ROUNDED-AMT             PIC S9(9)V99 COMP-3.
       01  WS-ACTUAL-XFER             PIC S9(9)V99 COMP-3.
      *--- Counters ---
       01  WS-PAID-CT                 PIC S9(3) COMP-3.
       01  WS-XFER-CT                 PIC S9(3) COMP-3.
       01  WS-DECLINE-CT              PIC S9(3) COMP-3.
      *--- Display ---
       01  WS-DISP-AMT                PIC -$$$,$$$,$$9.99.
       01  WS-DISP-CT                 PIC ZZ9.

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-DEBITS
           PERFORM 3000-PROCESS-DEBITS
           PERFORM 4000-DISPLAY-RESULTS
           STOP RUN.

       1000-INITIALIZE.
           MOVE 1122334455 TO WS-PRIMARY-ACCT
           MOVE 450.00 TO WS-PRIMARY-BAL
           MOVE 450.00 TO WS-PRIMARY-AVAIL
           MOVE 6677889900 TO WS-LINKED-ACCT
           MOVE 1 TO WS-LINKED-TYPE
           MOVE 8500.00 TO WS-LINKED-BAL
           MOVE 8500.00 TO WS-LINKED-AVAIL
           MOVE 0 TO WS-LOC-LIMIT
           MOVE 0 TO WS-LOC-USED
           MOVE 0 TO WS-XFER-COUNT-TODAY
           MOVE 6 TO WS-XFER-MAX-DAY
           MOVE 0 TO WS-XFER-TOTAL-TODAY
           MOVE 12.50 TO WS-XFER-FEE-EACH
           MOVE 0 TO WS-XFER-FEE-TOTAL
           MOVE 100.00 TO WS-MIN-XFER
           MOVE 100.00 TO WS-XFER-INCREMENT
           MOVE 0 TO WS-PAID-CT
           MOVE 0 TO WS-XFER-CT
           MOVE 0 TO WS-DECLINE-CT.

       2000-LOAD-DEBITS.
           MOVE 5 TO WS-DBT-COUNT
           MOVE 200.00 TO WS-DBT-AMOUNT(1)
           MOVE "UTILITY PAYMENT"
               TO WS-DBT-DESC(1)
           MOVE 0 TO WS-DBT-RESULT(1)
           MOVE 175.00 TO WS-DBT-AMOUNT(2)
           MOVE "GROCERY STORE"
               TO WS-DBT-DESC(2)
           MOVE 0 TO WS-DBT-RESULT(2)
           MOVE 350.00 TO WS-DBT-AMOUNT(3)
           MOVE "AUTO PAYMENT"
               TO WS-DBT-DESC(3)
           MOVE 0 TO WS-DBT-RESULT(3)
           MOVE 125.00 TO WS-DBT-AMOUNT(4)
           MOVE "PHONE BILL"
               TO WS-DBT-DESC(4)
           MOVE 0 TO WS-DBT-RESULT(4)
           MOVE 600.00 TO WS-DBT-AMOUNT(5)
           MOVE "RENT PAYMENT"
               TO WS-DBT-DESC(5)
           MOVE 0 TO WS-DBT-RESULT(5).

       3000-PROCESS-DEBITS.
           PERFORM VARYING WS-DBT-IDX FROM 1 BY 1
               UNTIL WS-DBT-IDX > WS-DBT-COUNT
               IF WS-DBT-AMOUNT(WS-DBT-IDX) <=
                   WS-PRIMARY-AVAIL
                   SUBTRACT WS-DBT-AMOUNT(WS-DBT-IDX)
                       FROM WS-PRIMARY-AVAIL
                   SUBTRACT WS-DBT-AMOUNT(WS-DBT-IDX)
                       FROM WS-PRIMARY-BAL
                   MOVE 1 TO WS-DBT-RESULT(WS-DBT-IDX)
                   ADD 1 TO WS-PAID-CT
               ELSE
                   PERFORM 3100-ATTEMPT-TRANSFER
               END-IF
           END-PERFORM.

       3100-ATTEMPT-TRANSFER.
           IF WS-LINKED-NONE
               MOVE 4 TO WS-DBT-RESULT(WS-DBT-IDX)
               ADD 1 TO WS-DECLINE-CT
           ELSE IF WS-XFER-COUNT-TODAY >= WS-XFER-MAX-DAY
               MOVE 4 TO WS-DBT-RESULT(WS-DBT-IDX)
               ADD 1 TO WS-DECLINE-CT
           ELSE
               COMPUTE WS-SHORTFALL =
                   WS-DBT-AMOUNT(WS-DBT-IDX)
                   - WS-PRIMARY-AVAIL
               PERFORM 3200-ROUND-UP-TRANSFER
               IF WS-ROUNDED-AMT <= WS-LINKED-AVAIL
                   SUBTRACT WS-ROUNDED-AMT
                       FROM WS-LINKED-AVAIL
                   SUBTRACT WS-ROUNDED-AMT
                       FROM WS-LINKED-BAL
                   ADD WS-ROUNDED-AMT TO WS-PRIMARY-AVAIL
                   ADD WS-ROUNDED-AMT TO WS-PRIMARY-BAL
                   SUBTRACT WS-DBT-AMOUNT(WS-DBT-IDX)
                       FROM WS-PRIMARY-AVAIL
                   SUBTRACT WS-DBT-AMOUNT(WS-DBT-IDX)
                       FROM WS-PRIMARY-BAL
                   SUBTRACT WS-XFER-FEE-EACH
                       FROM WS-PRIMARY-BAL
                   ADD WS-XFER-FEE-EACH
                       TO WS-XFER-FEE-TOTAL
                   ADD 1 TO WS-XFER-COUNT-TODAY
                   ADD WS-ROUNDED-AMT
                       TO WS-XFER-TOTAL-TODAY
                   MOVE 2 TO WS-DBT-RESULT(WS-DBT-IDX)
                   ADD 1 TO WS-XFER-CT
                   ADD 1 TO WS-PAID-CT
               ELSE
                   MOVE 4 TO WS-DBT-RESULT(WS-DBT-IDX)
                   ADD 1 TO WS-DECLINE-CT
               END-IF
           END-IF.

       3200-ROUND-UP-TRANSFER.
           IF WS-SHORTFALL < WS-MIN-XFER
               MOVE WS-MIN-XFER TO WS-ROUNDED-AMT
           ELSE
               COMPUTE WS-ROUNDED-AMT ROUNDED =
                   WS-SHORTFALL / WS-XFER-INCREMENT
               COMPUTE WS-ROUNDED-AMT =
                   WS-ROUNDED-AMT * WS-XFER-INCREMENT
               IF WS-ROUNDED-AMT < WS-SHORTFALL
                   ADD WS-XFER-INCREMENT
                       TO WS-ROUNDED-AMT
               END-IF
           END-IF.

       4000-DISPLAY-RESULTS.
           DISPLAY "========================================"
           DISPLAY "   OD PROTECTION TRANSFER REPORT"
           DISPLAY "========================================"
           PERFORM VARYING WS-DBT-IDX FROM 1 BY 1
               UNTIL WS-DBT-IDX > WS-DBT-COUNT
               MOVE WS-DBT-AMOUNT(WS-DBT-IDX)
                   TO WS-DISP-AMT
               EVALUATE WS-DBT-RESULT(WS-DBT-IDX)
                   WHEN 1
                       DISPLAY WS-DBT-DESC(WS-DBT-IDX)
                           " " WS-DISP-AMT " PAID"
                   WHEN 2
                       DISPLAY WS-DBT-DESC(WS-DBT-IDX)
                           " " WS-DISP-AMT " TRANSFER"
                   WHEN 4
                       DISPLAY WS-DBT-DESC(WS-DBT-IDX)
                           " " WS-DISP-AMT " DECLINED"
               END-EVALUATE
           END-PERFORM
           DISPLAY "--- SUMMARY ---"
           MOVE WS-PAID-CT TO WS-DISP-CT
           DISPLAY "ITEMS PAID:    " WS-DISP-CT
           MOVE WS-XFER-CT TO WS-DISP-CT
           DISPLAY "TRANSFERS:     " WS-DISP-CT
           MOVE WS-DECLINE-CT TO WS-DISP-CT
           DISPLAY "DECLINED:      " WS-DISP-CT
           MOVE WS-XFER-FEE-TOTAL TO WS-DISP-AMT
           DISPLAY "XFER FEES:     " WS-DISP-AMT
           MOVE WS-PRIMARY-BAL TO WS-DISP-AMT
           DISPLAY "PRIMARY BAL:   " WS-DISP-AMT
           MOVE WS-LINKED-BAL TO WS-DISP-AMT
           DISPLAY "LINKED BAL:    " WS-DISP-AMT
           DISPLAY "========================================".
