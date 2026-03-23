       IDENTIFICATION DIVISION.
       PROGRAM-ID. BRANCH-DAILY-CLOSE.
      *================================================================*
      * Branch End-of-Day Close Processing                             *
      * Aggregates all teller positions, reconciles ATMs, posts        *
      * branch-level GL entries, generates close certification.        *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- Branch Header ---
       01  WS-BRANCH-ID             PIC X(6).
       01  WS-CLOSE-DATE            PIC 9(8).
       01  WS-CLOSE-TIME            PIC 9(6).
       01  WS-MANAGER-ID            PIC X(8).
      *--- Teller Position Summary ---
       01  WS-TELLER-POS-TABLE.
           05  WS-TLR-POS OCCURS 6 TIMES.
               10  WS-TLR-ID         PIC X(8).
               10  WS-TLR-OPENING    PIC S9(9)V99 COMP-3.
               10  WS-TLR-CLOSING    PIC S9(9)V99 COMP-3.
               10  WS-TLR-TXN-CT     PIC S9(5) COMP-3.
               10  WS-TLR-VARIANCE   PIC S9(7)V99 COMP-3.
               10  WS-TLR-STATUS     PIC 9.
       01  WS-TLR-IDX               PIC 9(3).
       01  WS-TLR-COUNT             PIC 9(3).
      *--- Teller Status Values ---
       01  WS-TLR-STATUS-VAL        PIC 9.
           88  WS-TLR-BALANCED      VALUE 1.
           88  WS-TLR-SHORT         VALUE 2.
           88  WS-TLR-OVER          VALUE 3.
      *--- Branch Aggregates ---
       01  WS-BRANCH-OPEN-TOTAL     PIC S9(11)V99 COMP-3.
       01  WS-BRANCH-CLOSE-TOTAL    PIC S9(11)V99 COMP-3.
       01  WS-BRANCH-TXN-TOTAL      PIC S9(7) COMP-3.
       01  WS-BRANCH-VARIANCE       PIC S9(9)V99 COMP-3.
       01  WS-ABS-BRANCH-VAR        PIC S9(9)V99 COMP-3.
      *--- ATM Summary ---
       01  WS-ATM-CLOSE-TABLE.
           05  WS-ATM-CLS OCCURS 3 TIMES.
               10  WS-ATM-CLS-ID     PIC X(8).
               10  WS-ATM-CLS-BAL    PIC S9(9)V99 COMP-3.
               10  WS-ATM-CLS-TXN    PIC S9(5) COMP-3.
       01  WS-ATM-CLS-IDX           PIC 9(3).
       01  WS-ATM-TOTAL-BAL         PIC S9(11)V99 COMP-3.
       01  WS-ATM-TOTAL-TXN         PIC S9(7) COMP-3.
      *--- Grand Totals ---
       01  WS-GRAND-CASH-POS        PIC S9(11)V99 COMP-3.
       01  WS-GL-BOOK-BAL           PIC S9(11)V99 COMP-3.
       01  WS-GL-VARIANCE           PIC S9(9)V99 COMP-3.
       01  WS-CERTIFIED             PIC 9.
           88  WS-CLOSE-CERTIFIED   VALUE 1.
           88  WS-CLOSE-EXCEPTION   VALUE 0.
      *--- Certification Threshold ---
       01  WS-CERT-THRESHOLD        PIC S9(5)V99 COMP-3.
       01  WS-BALANCED-CT           PIC S9(3) COMP-3.
       01  WS-EXCEPTION-CT          PIC S9(3) COMP-3.
      *--- Display ---
       01  WS-DISP-AMT              PIC -$$$,$$$,$$9.99.
       01  WS-DISP-CT               PIC ZZ,ZZ9.
       01  WS-DISP-VAR              PIC -$$,$$9.99.
      *--- String ---
       01  WS-CERT-LINE             PIC X(50).

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-AGGREGATE-TELLERS
           PERFORM 3000-AGGREGATE-ATMS
           PERFORM 4000-COMPUTE-GRAND-POSITION
           PERFORM 5000-CERTIFY-CLOSE
           PERFORM 6000-DISPLAY-CLOSE-REPORT
           STOP RUN.

       1000-INITIALIZE.
           MOVE "BR0042" TO WS-BRANCH-ID
           ACCEPT WS-CLOSE-DATE FROM DATE YYYYMMDD
           ACCEPT WS-CLOSE-TIME FROM TIME
           MOVE "MGR00001" TO WS-MANAGER-ID
           MOVE 50.00 TO WS-CERT-THRESHOLD
           MOVE 0 TO WS-BRANCH-OPEN-TOTAL
           MOVE 0 TO WS-BRANCH-CLOSE-TOTAL
           MOVE 0 TO WS-BRANCH-TXN-TOTAL
           MOVE 0 TO WS-ATM-TOTAL-BAL
           MOVE 0 TO WS-ATM-TOTAL-TXN
           MOVE 0 TO WS-BALANCED-CT
           MOVE 0 TO WS-EXCEPTION-CT
           MOVE 1275000.00 TO WS-GL-BOOK-BAL
           MOVE 4 TO WS-TLR-COUNT
           MOVE "TLR00101" TO WS-TLR-ID(1)
           MOVE 10000.00 TO WS-TLR-OPENING(1)
           MOVE 9985.50 TO WS-TLR-CLOSING(1)
           MOVE 47 TO WS-TLR-TXN-CT(1)
           MOVE "TLR00102" TO WS-TLR-ID(2)
           MOVE 10000.00 TO WS-TLR-OPENING(2)
           MOVE 10025.00 TO WS-TLR-CLOSING(2)
           MOVE 32 TO WS-TLR-TXN-CT(2)
           MOVE "TLR00103" TO WS-TLR-ID(3)
           MOVE 10000.00 TO WS-TLR-OPENING(3)
           MOVE 10000.00 TO WS-TLR-CLOSING(3)
           MOVE 55 TO WS-TLR-TXN-CT(3)
           MOVE "TLR00104" TO WS-TLR-ID(4)
           MOVE 10000.00 TO WS-TLR-OPENING(4)
           MOVE 9950.00 TO WS-TLR-CLOSING(4)
           MOVE 41 TO WS-TLR-TXN-CT(4)
           MOVE "ATM-1001" TO WS-ATM-CLS-ID(1)
           MOVE 45000.00 TO WS-ATM-CLS-BAL(1)
           MOVE 120 TO WS-ATM-CLS-TXN(1)
           MOVE "ATM-1002" TO WS-ATM-CLS-ID(2)
           MOVE 28000.00 TO WS-ATM-CLS-BAL(2)
           MOVE 85 TO WS-ATM-CLS-TXN(2)
           MOVE "ATM-1003" TO WS-ATM-CLS-ID(3)
           MOVE 15000.00 TO WS-ATM-CLS-BAL(3)
           MOVE 200 TO WS-ATM-CLS-TXN(3).

       2000-AGGREGATE-TELLERS.
           PERFORM VARYING WS-TLR-IDX FROM 1 BY 1
               UNTIL WS-TLR-IDX > WS-TLR-COUNT
               ADD WS-TLR-OPENING(WS-TLR-IDX)
                   TO WS-BRANCH-OPEN-TOTAL
               ADD WS-TLR-CLOSING(WS-TLR-IDX)
                   TO WS-BRANCH-CLOSE-TOTAL
               ADD WS-TLR-TXN-CT(WS-TLR-IDX)
                   TO WS-BRANCH-TXN-TOTAL
               COMPUTE WS-TLR-VARIANCE(WS-TLR-IDX) =
                   WS-TLR-CLOSING(WS-TLR-IDX)
                   - WS-TLR-OPENING(WS-TLR-IDX)
               EVALUATE TRUE
                   WHEN WS-TLR-VARIANCE(WS-TLR-IDX) = 0
                       MOVE 1 TO WS-TLR-STATUS(WS-TLR-IDX)
                       ADD 1 TO WS-BALANCED-CT
                   WHEN WS-TLR-VARIANCE(WS-TLR-IDX) < 0
                       MOVE 2 TO WS-TLR-STATUS(WS-TLR-IDX)
                       ADD 1 TO WS-EXCEPTION-CT
                   WHEN WS-TLR-VARIANCE(WS-TLR-IDX) > 0
                       MOVE 3 TO WS-TLR-STATUS(WS-TLR-IDX)
                       ADD 1 TO WS-EXCEPTION-CT
               END-EVALUATE
           END-PERFORM
           COMPUTE WS-BRANCH-VARIANCE =
               WS-BRANCH-CLOSE-TOTAL
               - WS-BRANCH-OPEN-TOTAL.

       3000-AGGREGATE-ATMS.
           PERFORM VARYING WS-ATM-CLS-IDX FROM 1 BY 1
               UNTIL WS-ATM-CLS-IDX > 3
               ADD WS-ATM-CLS-BAL(WS-ATM-CLS-IDX)
                   TO WS-ATM-TOTAL-BAL
               ADD WS-ATM-CLS-TXN(WS-ATM-CLS-IDX)
                   TO WS-ATM-TOTAL-TXN
           END-PERFORM.

       4000-COMPUTE-GRAND-POSITION.
           COMPUTE WS-GRAND-CASH-POS =
               WS-BRANCH-CLOSE-TOTAL + WS-ATM-TOTAL-BAL
           COMPUTE WS-GL-VARIANCE =
               WS-GRAND-CASH-POS - WS-GL-BOOK-BAL
           IF WS-GL-VARIANCE < 0
               COMPUTE WS-ABS-BRANCH-VAR =
                   WS-GL-VARIANCE * -1
           ELSE
               MOVE WS-GL-VARIANCE TO WS-ABS-BRANCH-VAR
           END-IF.

       5000-CERTIFY-CLOSE.
           IF WS-ABS-BRANCH-VAR <= WS-CERT-THRESHOLD
               MOVE 1 TO WS-CERTIFIED
               STRING "CERTIFIED BY " WS-MANAGER-ID
                   DELIMITED BY SIZE
                   INTO WS-CERT-LINE
           ELSE
               MOVE 0 TO WS-CERTIFIED
               STRING "EXCEPTION - REVIEW BY "
                   WS-MANAGER-ID
                   DELIMITED BY SIZE
                   INTO WS-CERT-LINE
           END-IF.

       6000-DISPLAY-CLOSE-REPORT.
           DISPLAY "========================================"
           DISPLAY "   BRANCH END-OF-DAY CLOSE"
           DISPLAY "========================================"
           DISPLAY "BRANCH: " WS-BRANCH-ID
           DISPLAY "--- TELLER SUMMARY ---"
           PERFORM VARYING WS-TLR-IDX FROM 1 BY 1
               UNTIL WS-TLR-IDX > WS-TLR-COUNT
               MOVE WS-TLR-VARIANCE(WS-TLR-IDX)
                   TO WS-DISP-VAR
               EVALUATE WS-TLR-STATUS(WS-TLR-IDX)
                   WHEN 1
                       DISPLAY WS-TLR-ID(WS-TLR-IDX)
                           " BALANCED"
                   WHEN 2
                       DISPLAY WS-TLR-ID(WS-TLR-IDX)
                           " SHORT " WS-DISP-VAR
                   WHEN 3
                       DISPLAY WS-TLR-ID(WS-TLR-IDX)
                           " OVER  " WS-DISP-VAR
               END-EVALUATE
           END-PERFORM
           DISPLAY "--- ATM SUMMARY ---"
           MOVE WS-ATM-TOTAL-BAL TO WS-DISP-AMT
           DISPLAY "ATM CASH:     " WS-DISP-AMT
           MOVE WS-ATM-TOTAL-TXN TO WS-DISP-CT
           DISPLAY "ATM TXNS:     " WS-DISP-CT
           DISPLAY "--- BRANCH POSITION ---"
           MOVE WS-GRAND-CASH-POS TO WS-DISP-AMT
           DISPLAY "CASH POSITION:" WS-DISP-AMT
           MOVE WS-GL-BOOK-BAL TO WS-DISP-AMT
           DISPLAY "BOOK BALANCE: " WS-DISP-AMT
           MOVE WS-GL-VARIANCE TO WS-DISP-VAR
           DISPLAY "GL VARIANCE:  " WS-DISP-VAR
           DISPLAY WS-CERT-LINE
           DISPLAY "========================================".
