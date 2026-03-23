       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-SQL-TELLER-AUDIT.
      *================================================================*
      * Teller Transaction Audit via Embedded SQL                      *
      * Queries DB2 for teller activity, computes session totals,      *
      * flags suspicious patterns using SQL aggregation.               *
      * INTENTIONAL: Uses EXEC SQL to trigger MANUAL REVIEW.           *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- Host Variables ---
       01  WS-SQLCODE                PIC S9(9) COMP-3.
       01  WS-TELLER-ID             PIC X(8).
       01  WS-SESSION-DATE          PIC X(10).
       01  WS-TXN-TYPE              PIC X(3).
       01  WS-TXN-AMOUNT            PIC S9(9)V99 COMP-3.
       01  WS-TXN-ACCT              PIC 9(10).
      *--- Accumulation ---
       01  WS-CASH-IN-TOTAL         PIC S9(11)V99 COMP-3.
       01  WS-CASH-OUT-TOTAL        PIC S9(11)V99 COMP-3.
       01  WS-TXN-COUNT             PIC S9(5) COMP-3.
       01  WS-LARGEST-TXN           PIC S9(9)V99 COMP-3.
      *--- Suspicious Pattern ---
       01  WS-SAME-ACCT-CT          PIC S9(3) COMP-3.
       01  WS-RAPID-TXN-CT          PIC S9(3) COMP-3.
       01  WS-ALERT-FLAG            PIC 9.
           88  WS-NO-ALERT          VALUE 0.
           88  WS-PATTERN-ALERT     VALUE 1.
      *--- EOF Control ---
       01  WS-EOF-FLAG              PIC X VALUE 'N'.
           88  WS-AT-EOF            VALUE 'Y'.
           88  WS-NOT-EOF           VALUE 'N'.
      *--- Display ---
       01  WS-DISP-AMT              PIC -$$$,$$$,$$9.99.
       01  WS-DISP-CT               PIC ZZ,ZZ9.
      *--- Work ---
       01  WS-PREV-ACCT             PIC 9(10).
       01  WS-TALLY-WORK            PIC S9(3) COMP-3.

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-OPEN-CURSOR
           IF WS-SQLCODE = 0
               PERFORM 3000-FETCH-LOOP
                   UNTIL WS-AT-EOF
               PERFORM 4000-CLOSE-CURSOR
           END-IF
           PERFORM 5000-ANALYZE-PATTERNS
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.

       1000-INITIALIZE.
           MOVE "TLR00301" TO WS-TELLER-ID
           MOVE "2026-03-21" TO WS-SESSION-DATE
           MOVE 0 TO WS-CASH-IN-TOTAL
           MOVE 0 TO WS-CASH-OUT-TOTAL
           MOVE 0 TO WS-TXN-COUNT
           MOVE 0 TO WS-LARGEST-TXN
           MOVE 0 TO WS-SAME-ACCT-CT
           MOVE 0 TO WS-RAPID-TXN-CT
           MOVE 0 TO WS-ALERT-FLAG
           MOVE 0 TO WS-PREV-ACCT
           MOVE 'N' TO WS-EOF-FLAG.

       2000-OPEN-CURSOR.
           EXEC SQL
               DECLARE TELLER_TXN_CUR CURSOR FOR
               SELECT TXN_TYPE, TXN_AMOUNT, ACCT_NUM
               FROM TELLER_TRANSACTIONS
               WHERE TELLER_ID = :WS-TELLER-ID
                 AND TXN_DATE = :WS-SESSION-DATE
               ORDER BY TXN_TIMESTAMP
           END-EXEC
           MOVE 0 TO WS-SQLCODE
           EXEC SQL
               OPEN TELLER_TXN_CUR
           END-EXEC.

       3000-FETCH-LOOP.
           EXEC SQL
               FETCH TELLER_TXN_CUR
               INTO :WS-TXN-TYPE, :WS-TXN-AMOUNT,
                    :WS-TXN-ACCT
           END-EXEC
           IF WS-SQLCODE NOT = 0
               MOVE 'Y' TO WS-EOF-FLAG
           ELSE
               ADD 1 TO WS-TXN-COUNT
               IF WS-TXN-TYPE = "DEP"
                   ADD WS-TXN-AMOUNT TO WS-CASH-IN-TOTAL
               ELSE
                   ADD WS-TXN-AMOUNT TO WS-CASH-OUT-TOTAL
               END-IF
               IF WS-TXN-AMOUNT > WS-LARGEST-TXN
                   MOVE WS-TXN-AMOUNT TO WS-LARGEST-TXN
               END-IF
               IF WS-TXN-ACCT = WS-PREV-ACCT
                   ADD 1 TO WS-SAME-ACCT-CT
               END-IF
               MOVE WS-TXN-ACCT TO WS-PREV-ACCT
           END-IF.

       4000-CLOSE-CURSOR.
           EXEC SQL
               CLOSE TELLER_TXN_CUR
           END-EXEC.

       5000-ANALYZE-PATTERNS.
           IF WS-SAME-ACCT-CT > 5
               MOVE 1 TO WS-ALERT-FLAG
           END-IF
           MOVE 0 TO WS-TALLY-WORK
           INSPECT WS-TELLER-ID
               TALLYING WS-TALLY-WORK FOR ALL "0".

       6000-DISPLAY-RESULTS.
           DISPLAY "========================================"
           DISPLAY "   TELLER AUDIT REPORT"
           DISPLAY "========================================"
           DISPLAY "TELLER: " WS-TELLER-ID
           DISPLAY "DATE:   " WS-SESSION-DATE
           MOVE WS-TXN-COUNT TO WS-DISP-CT
           DISPLAY "TRANSACTIONS: " WS-DISP-CT
           MOVE WS-CASH-IN-TOTAL TO WS-DISP-AMT
           DISPLAY "CASH IN:      " WS-DISP-AMT
           MOVE WS-CASH-OUT-TOTAL TO WS-DISP-AMT
           DISPLAY "CASH OUT:     " WS-DISP-AMT
           MOVE WS-LARGEST-TXN TO WS-DISP-AMT
           DISPLAY "LARGEST:      " WS-DISP-AMT
           IF WS-PATTERN-ALERT
               DISPLAY "*** SUSPICIOUS PATTERN ALERT ***"
           END-IF
           DISPLAY "========================================".
