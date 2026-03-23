       IDENTIFICATION DIVISION.
       PROGRAM-ID. TELLER-TXN-LOG.
      *================================================================*
      * Teller Transaction Log Processor                               *
      * Captures each teller operation, validates limits, builds       *
      * formatted log entries with sequence numbers and timestamps.    *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- Teller Info ---
       01  WS-TELLER-ID              PIC X(8).
       01  WS-BRANCH-NUM             PIC X(6).
       01  WS-WINDOW-NUM             PIC 9(2).
       01  WS-SESSION-DATE           PIC 9(8).
       01  WS-SESSION-TIME           PIC 9(6).
      *--- Transaction Buffer ---
       01  WS-TXN-BUFFER.
           05  WS-TXN-RECORD OCCURS 10 TIMES.
               10  WS-TXN-SEQ        PIC 9(6).
               10  WS-TXN-TIME       PIC 9(6).
               10  WS-TXN-TYPE       PIC X(3).
               10  WS-TXN-ACCT       PIC 9(10).
               10  WS-TXN-AMT        PIC S9(9)V99 COMP-3.
               10  WS-TXN-STATUS     PIC X(1).
       01  WS-TXN-IDX                PIC 9(3).
       01  WS-TXN-COUNT              PIC 9(3).
       01  WS-NEXT-SEQ               PIC 9(6).
      *--- Transaction Types ---
       01  WS-TYPE-FLAG               PIC X(3).
           88  WS-TYPE-DEPOSIT        VALUE "DEP".
           88  WS-TYPE-WITHDRAW       VALUE "WTH".
           88  WS-TYPE-TRANSFER       VALUE "XFR".
           88  WS-TYPE-CHECK-CASH     VALUE "CCH".
           88  WS-TYPE-MONEY-ORDER    VALUE "MOR".
      *--- Limits ---
       01  WS-CTR-THRESHOLD          PIC S9(9)V99 COMP-3.
       01  WS-SINGLE-TXN-LIMIT       PIC S9(9)V99 COMP-3.
       01  WS-DAILY-CASH-TOTAL       PIC S9(11)V99 COMP-3.
       01  WS-CTR-REQUIRED           PIC 9.
      *--- Running Totals ---
       01  WS-SESSION-DEPOSITS       PIC S9(11)V99 COMP-3.
       01  WS-SESSION-WITHDRAWALS    PIC S9(11)V99 COMP-3.
       01  WS-SESSION-CHECKS         PIC S9(9)V99 COMP-3.
       01  WS-APPROVED-CT            PIC S9(5) COMP-3.
       01  WS-DECLINED-CT            PIC S9(5) COMP-3.
       01  WS-CTR-CT                 PIC S9(3) COMP-3.
      *--- Log Line ---
       01  WS-LOG-LINE               PIC X(80).
       01  WS-FORMATTED-TIME         PIC X(8).
       01  WS-DISP-AMT               PIC -$$$,$$$,$$9.99.
       01  WS-DISP-CT                PIC ZZZ,ZZ9.
      *--- Tally ---
       01  WS-SPACE-TALLY            PIC S9(3) COMP-3.

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-TRANSACTIONS
           PERFORM 3000-PROCESS-LOG
           PERFORM 4000-CHECK-CTR
           PERFORM 5000-DISPLAY-SESSION
           STOP RUN.

       1000-INITIALIZE.
           MOVE "TLR00203" TO WS-TELLER-ID
           MOVE "BR0015" TO WS-BRANCH-NUM
           MOVE 3 TO WS-WINDOW-NUM
           ACCEPT WS-SESSION-DATE FROM DATE YYYYMMDD
           ACCEPT WS-SESSION-TIME FROM TIME
           MOVE 10000.00 TO WS-CTR-THRESHOLD
           MOVE 25000.00 TO WS-SINGLE-TXN-LIMIT
           MOVE 0 TO WS-DAILY-CASH-TOTAL
           MOVE 0 TO WS-CTR-REQUIRED
           MOVE 0 TO WS-SESSION-DEPOSITS
           MOVE 0 TO WS-SESSION-WITHDRAWALS
           MOVE 0 TO WS-SESSION-CHECKS
           MOVE 0 TO WS-APPROVED-CT
           MOVE 0 TO WS-DECLINED-CT
           MOVE 0 TO WS-CTR-CT
           MOVE 100001 TO WS-NEXT-SEQ.

       2000-LOAD-TRANSACTIONS.
           MOVE 7 TO WS-TXN-COUNT
           MOVE "DEP" TO WS-TXN-TYPE(1)
           MOVE 3344556677 TO WS-TXN-ACCT(1)
           MOVE 2500.00 TO WS-TXN-AMT(1)
           MOVE "WTH" TO WS-TXN-TYPE(2)
           MOVE 4455667788 TO WS-TXN-ACCT(2)
           MOVE 500.00 TO WS-TXN-AMT(2)
           MOVE "CCH" TO WS-TXN-TYPE(3)
           MOVE 5566778899 TO WS-TXN-ACCT(3)
           MOVE 1250.00 TO WS-TXN-AMT(3)
           MOVE "DEP" TO WS-TXN-TYPE(4)
           MOVE 6677889900 TO WS-TXN-ACCT(4)
           MOVE 8500.00 TO WS-TXN-AMT(4)
           MOVE "MOR" TO WS-TXN-TYPE(5)
           MOVE 7788990011 TO WS-TXN-ACCT(5)
           MOVE 750.00 TO WS-TXN-AMT(5)
           MOVE "WTH" TO WS-TXN-TYPE(6)
           MOVE 8899001122 TO WS-TXN-ACCT(6)
           MOVE 30000.00 TO WS-TXN-AMT(6)
           MOVE "XFR" TO WS-TXN-TYPE(7)
           MOVE 9900112233 TO WS-TXN-ACCT(7)
           MOVE 1500.00 TO WS-TXN-AMT(7).

       3000-PROCESS-LOG.
           PERFORM VARYING WS-TXN-IDX FROM 1 BY 1
               UNTIL WS-TXN-IDX > WS-TXN-COUNT
               MOVE WS-NEXT-SEQ
                   TO WS-TXN-SEQ(WS-TXN-IDX)
               ADD 1 TO WS-NEXT-SEQ
               MOVE WS-SESSION-TIME
                   TO WS-TXN-TIME(WS-TXN-IDX)
               IF WS-TXN-AMT(WS-TXN-IDX) >
                   WS-SINGLE-TXN-LIMIT
                   MOVE "D" TO WS-TXN-STATUS(WS-TXN-IDX)
                   ADD 1 TO WS-DECLINED-CT
               ELSE
                   MOVE "A" TO WS-TXN-STATUS(WS-TXN-IDX)
                   ADD 1 TO WS-APPROVED-CT
                   EVALUATE WS-TXN-TYPE(WS-TXN-IDX)
                       WHEN "DEP"
                           ADD WS-TXN-AMT(WS-TXN-IDX)
                               TO WS-SESSION-DEPOSITS
                           ADD WS-TXN-AMT(WS-TXN-IDX)
                               TO WS-DAILY-CASH-TOTAL
                       WHEN "WTH"
                           ADD WS-TXN-AMT(WS-TXN-IDX)
                               TO WS-SESSION-WITHDRAWALS
                           ADD WS-TXN-AMT(WS-TXN-IDX)
                               TO WS-DAILY-CASH-TOTAL
                       WHEN "CCH"
                           ADD WS-TXN-AMT(WS-TXN-IDX)
                               TO WS-SESSION-CHECKS
                           ADD WS-TXN-AMT(WS-TXN-IDX)
                               TO WS-DAILY-CASH-TOTAL
                       WHEN "MOR"
                           ADD WS-TXN-AMT(WS-TXN-IDX)
                               TO WS-SESSION-WITHDRAWALS
                       WHEN "XFR"
                           CONTINUE
                   END-EVALUATE
               END-IF
           END-PERFORM.

       4000-CHECK-CTR.
           IF WS-DAILY-CASH-TOTAL > WS-CTR-THRESHOLD
               MOVE 1 TO WS-CTR-REQUIRED
               ADD 1 TO WS-CTR-CT
           END-IF.

       5000-DISPLAY-SESSION.
           DISPLAY "========================================"
           DISPLAY "   TELLER SESSION LOG"
           DISPLAY "========================================"
           DISPLAY "TELLER: " WS-TELLER-ID
               " WINDOW: " WS-WINDOW-NUM
           PERFORM VARYING WS-TXN-IDX FROM 1 BY 1
               UNTIL WS-TXN-IDX > WS-TXN-COUNT
               MOVE WS-TXN-AMT(WS-TXN-IDX)
                   TO WS-DISP-AMT
               MOVE 0 TO WS-SPACE-TALLY
               INSPECT WS-TXN-TYPE(WS-TXN-IDX)
                   TALLYING WS-SPACE-TALLY
                   FOR ALL SPACES
               STRING WS-TXN-SEQ(WS-TXN-IDX) " "
                   WS-TXN-TYPE(WS-TXN-IDX) " "
                   WS-TXN-STATUS(WS-TXN-IDX)
                   DELIMITED BY SIZE
                   INTO WS-LOG-LINE
               DISPLAY WS-LOG-LINE " " WS-DISP-AMT
           END-PERFORM
           DISPLAY "--- SESSION TOTALS ---"
           MOVE WS-SESSION-DEPOSITS TO WS-DISP-AMT
           DISPLAY "DEPOSITS:    " WS-DISP-AMT
           MOVE WS-SESSION-WITHDRAWALS TO WS-DISP-AMT
           DISPLAY "WITHDRAWALS: " WS-DISP-AMT
           MOVE WS-SESSION-CHECKS TO WS-DISP-AMT
           DISPLAY "CHECKS:      " WS-DISP-AMT
           MOVE WS-APPROVED-CT TO WS-DISP-CT
           DISPLAY "APPROVED:    " WS-DISP-CT
           MOVE WS-DECLINED-CT TO WS-DISP-CT
           DISPLAY "DECLINED:    " WS-DISP-CT
           IF WS-CTR-REQUIRED = 1
               DISPLAY "*** CTR FILING REQUIRED ***"
           END-IF
           DISPLAY "========================================".
