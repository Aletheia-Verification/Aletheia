       IDENTIFICATION DIVISION.
       PROGRAM-ID. BRANCH-ACCT-POST.
      *================================================================*
      * Branch General Ledger Posting Engine                           *
      * Posts debits and credits to GL accounts, maintains trial       *
      * balance, detects out-of-balance conditions per cost center.    *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- GL Entry Table ---
       01  WS-GL-TABLE.
           05  WS-GL-ENTRY OCCURS 10 TIMES.
               10  WS-GL-ACCT-NUM    PIC 9(8).
               10  WS-GL-COST-CTR    PIC X(4).
               10  WS-GL-TYPE        PIC X(1).
               10  WS-GL-AMOUNT      PIC S9(11)V99 COMP-3.
               10  WS-GL-DESC        PIC X(30).
       01  WS-GL-IDX                 PIC 9(3).
       01  WS-GL-COUNT               PIC 9(3).
      *--- Accumulators ---
       01  WS-TOTAL-DEBITS           PIC S9(13)V99 COMP-3.
       01  WS-TOTAL-CREDITS          PIC S9(13)V99 COMP-3.
       01  WS-NET-BALANCE            PIC S9(13)V99 COMP-3.
       01  WS-ABS-DIFF               PIC S9(13)V99 COMP-3.
      *--- Cost Center Totals ---
       01  WS-CC-TABLE.
           05  WS-CC-ENTRY OCCURS 4 TIMES.
               10  WS-CC-CODE        PIC X(4).
               10  WS-CC-DEBITS      PIC S9(11)V99 COMP-3.
               10  WS-CC-CREDITS     PIC S9(11)V99 COMP-3.
               10  WS-CC-NET         PIC S9(11)V99 COMP-3.
       01  WS-CC-IDX                 PIC 9(3).
       01  WS-CC-COUNT               PIC 9(3).
       01  WS-CC-FOUND               PIC 9.
      *--- Validation ---
       01  WS-BALANCED-FLAG          PIC 9.
           88  WS-IN-BALANCE         VALUE 1.
           88  WS-OUT-OF-BALANCE     VALUE 0.
       01  WS-TOLERANCE              PIC S9(3)V99 COMP-3.
       01  WS-ERROR-FLAG             PIC 9.
       01  WS-ERROR-COUNT            PIC 9(3).
      *--- Date/Time ---
       01  WS-POST-DATE              PIC 9(8).
       01  WS-POST-TIME              PIC 9(6).
       01  WS-BATCH-ID               PIC X(12).
      *--- Display ---
       01  WS-DISP-AMT               PIC -$$$,$$$,$$$,$$9.99.
       01  WS-DISP-CT                PIC ZZ9.
      *--- String Work ---
       01  WS-MSG-LINE               PIC X(80).
       01  WS-TALLY-D                PIC S9(5) COMP-3.

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-ENTRIES
           PERFORM 3000-POST-ENTRIES
           PERFORM 4000-CHECK-BALANCE
           PERFORM 5000-SUMMARIZE-COST-CTRS
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.

       1000-INITIALIZE.
           ACCEPT WS-POST-DATE FROM DATE YYYYMMDD
           ACCEPT WS-POST-TIME FROM TIME
           MOVE 0 TO WS-TOTAL-DEBITS
           MOVE 0 TO WS-TOTAL-CREDITS
           MOVE 0 TO WS-ERROR-COUNT
           MOVE 0.01 TO WS-TOLERANCE
           MOVE 0 TO WS-CC-COUNT
           STRING "BATCH" WS-POST-DATE
               DELIMITED BY SIZE
               INTO WS-BATCH-ID
           INITIALIZE WS-CC-TABLE.

       2000-LOAD-ENTRIES.
           MOVE 8 TO WS-GL-COUNT
           MOVE 10010001 TO WS-GL-ACCT-NUM(1)
           MOVE "OPSA" TO WS-GL-COST-CTR(1)
           MOVE "D" TO WS-GL-TYPE(1)
           MOVE 15000.00 TO WS-GL-AMOUNT(1)
           MOVE "CASH RECEIVED"
               TO WS-GL-DESC(1)
           MOVE 20010001 TO WS-GL-ACCT-NUM(2)
           MOVE "OPSA" TO WS-GL-COST-CTR(2)
           MOVE "C" TO WS-GL-TYPE(2)
           MOVE 15000.00 TO WS-GL-AMOUNT(2)
           MOVE "CUSTOMER DEPOSITS"
               TO WS-GL-DESC(2)
           MOVE 10020001 TO WS-GL-ACCT-NUM(3)
           MOVE "LNDA" TO WS-GL-COST-CTR(3)
           MOVE "D" TO WS-GL-TYPE(3)
           MOVE 250000.00 TO WS-GL-AMOUNT(3)
           MOVE "LOAN DISBURSEMENT"
               TO WS-GL-DESC(3)
           MOVE 30010001 TO WS-GL-ACCT-NUM(4)
           MOVE "LNDA" TO WS-GL-COST-CTR(4)
           MOVE "C" TO WS-GL-TYPE(4)
           MOVE 250000.00 TO WS-GL-AMOUNT(4)
           MOVE "LOAN FUND TRANSFER"
               TO WS-GL-DESC(4)
           MOVE 40010001 TO WS-GL-ACCT-NUM(5)
           MOVE "FESA" TO WS-GL-COST-CTR(5)
           MOVE "D" TO WS-GL-TYPE(5)
           MOVE 450.00 TO WS-GL-AMOUNT(5)
           MOVE "FEE RECEIVABLE"
               TO WS-GL-DESC(5)
           MOVE 50010001 TO WS-GL-ACCT-NUM(6)
           MOVE "FESA" TO WS-GL-COST-CTR(6)
           MOVE "C" TO WS-GL-TYPE(6)
           MOVE 450.00 TO WS-GL-AMOUNT(6)
           MOVE "FEE INCOME"
               TO WS-GL-DESC(6)
           MOVE 10030001 TO WS-GL-ACCT-NUM(7)
           MOVE "OPSA" TO WS-GL-COST-CTR(7)
           MOVE "D" TO WS-GL-TYPE(7)
           MOVE 8500.00 TO WS-GL-AMOUNT(7)
           MOVE "TELLER WITHDRAWAL"
               TO WS-GL-DESC(7)
           MOVE 20020001 TO WS-GL-ACCT-NUM(8)
           MOVE "OPSA" TO WS-GL-COST-CTR(8)
           MOVE "C" TO WS-GL-TYPE(8)
           MOVE 8500.00 TO WS-GL-AMOUNT(8)
           MOVE "CHECKING DEBIT"
               TO WS-GL-DESC(8).

       3000-POST-ENTRIES.
           PERFORM VARYING WS-GL-IDX FROM 1 BY 1
               UNTIL WS-GL-IDX > WS-GL-COUNT
               MOVE 0 TO WS-ERROR-FLAG
               IF WS-GL-AMOUNT(WS-GL-IDX) <= 0
                   ADD 1 TO WS-ERROR-COUNT
                   MOVE 1 TO WS-ERROR-FLAG
               END-IF
               IF WS-ERROR-FLAG = 0
                   IF WS-GL-TYPE(WS-GL-IDX) = "D"
                       ADD WS-GL-AMOUNT(WS-GL-IDX)
                           TO WS-TOTAL-DEBITS
                   ELSE
                       ADD WS-GL-AMOUNT(WS-GL-IDX)
                           TO WS-TOTAL-CREDITS
                   END-IF
                   PERFORM 3100-UPDATE-COST-CENTER
               END-IF
           END-PERFORM.

       3100-UPDATE-COST-CENTER.
           MOVE 0 TO WS-CC-FOUND
           PERFORM VARYING WS-CC-IDX FROM 1 BY 1
               UNTIL WS-CC-IDX > WS-CC-COUNT
                  OR WS-CC-FOUND = 1
               IF WS-CC-CODE(WS-CC-IDX) =
                   WS-GL-COST-CTR(WS-GL-IDX)
                   MOVE 1 TO WS-CC-FOUND
               END-IF
           END-PERFORM
           IF WS-CC-FOUND = 0
               ADD 1 TO WS-CC-COUNT
               MOVE WS-GL-COST-CTR(WS-GL-IDX)
                   TO WS-CC-CODE(WS-CC-COUNT)
               MOVE WS-CC-COUNT TO WS-CC-IDX
           ELSE
               SUBTRACT 1 FROM WS-CC-IDX
           END-IF
           IF WS-GL-TYPE(WS-GL-IDX) = "D"
               ADD WS-GL-AMOUNT(WS-GL-IDX)
                   TO WS-CC-DEBITS(WS-CC-IDX)
           ELSE
               ADD WS-GL-AMOUNT(WS-GL-IDX)
                   TO WS-CC-CREDITS(WS-CC-IDX)
           END-IF.

       4000-CHECK-BALANCE.
           COMPUTE WS-NET-BALANCE =
               WS-TOTAL-DEBITS - WS-TOTAL-CREDITS
           IF WS-NET-BALANCE < 0
               COMPUTE WS-ABS-DIFF =
                   WS-NET-BALANCE * -1
           ELSE
               MOVE WS-NET-BALANCE TO WS-ABS-DIFF
           END-IF
           IF WS-ABS-DIFF <= WS-TOLERANCE
               MOVE 1 TO WS-BALANCED-FLAG
           ELSE
               MOVE 0 TO WS-BALANCED-FLAG
           END-IF.

       5000-SUMMARIZE-COST-CTRS.
           PERFORM VARYING WS-CC-IDX FROM 1 BY 1
               UNTIL WS-CC-IDX > WS-CC-COUNT
               COMPUTE WS-CC-NET(WS-CC-IDX) =
                   WS-CC-DEBITS(WS-CC-IDX)
                   - WS-CC-CREDITS(WS-CC-IDX)
           END-PERFORM.

       6000-DISPLAY-RESULTS.
           DISPLAY "========================================"
           DISPLAY "   GL POSTING SUMMARY"
           DISPLAY "========================================"
           DISPLAY "BATCH: " WS-BATCH-ID
           MOVE WS-TOTAL-DEBITS TO WS-DISP-AMT
           DISPLAY "TOTAL DEBITS:  " WS-DISP-AMT
           MOVE WS-TOTAL-CREDITS TO WS-DISP-AMT
           DISPLAY "TOTAL CREDITS: " WS-DISP-AMT
           IF WS-IN-BALANCE
               DISPLAY "STATUS: IN BALANCE"
           ELSE
               DISPLAY "*** OUT OF BALANCE ***"
               MOVE WS-NET-BALANCE TO WS-DISP-AMT
               DISPLAY "DIFFERENCE:    " WS-DISP-AMT
           END-IF
           MOVE WS-GL-COUNT TO WS-DISP-CT
           DISPLAY "ENTRIES POSTED:" WS-DISP-CT
           MOVE WS-ERROR-COUNT TO WS-DISP-CT
           DISPLAY "ERRORS:        " WS-DISP-CT
           DISPLAY "========================================".
