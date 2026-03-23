       IDENTIFICATION DIVISION.
       PROGRAM-ID. NSF-CHECK-HANDLER.
      *================================================================*
      * NSF (Non-Sufficient Funds) Check Processing                    *
      * Handles returned checks, assesses NSF fees, manages re-        *
      * presentment attempts, tracks cumulative penalties.             *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- Account Data ---
       01  WS-ACCOUNT-NUM             PIC 9(10).
       01  WS-CURRENT-BALANCE         PIC S9(11)V99 COMP-3.
       01  WS-AVAILABLE-BAL           PIC S9(11)V99 COMP-3.
       01  WS-HOLD-TOTAL              PIC S9(9)V99 COMP-3.
      *--- Check Queue ---
       01  WS-CHECK-TABLE.
           05  WS-CHECK-ENTRY OCCURS 6 TIMES.
               10  WS-CHK-NUM         PIC 9(6).
               10  WS-CHK-AMOUNT      PIC S9(9)V99 COMP-3.
               10  WS-CHK-PAYEE       PIC X(25).
               10  WS-CHK-STATUS      PIC 9.
               10  WS-CHK-ATTEMPTS    PIC 9.
               10  WS-CHK-FEE         PIC S9(5)V99 COMP-3.
       01  WS-CHK-IDX                 PIC 9(3).
       01  WS-CHK-COUNT               PIC 9(3).
      *--- Status Values ---
       01  WS-STATUS-VALS             PIC 9.
           88  WS-STATUS-PENDING      VALUE 0.
           88  WS-STATUS-PAID         VALUE 1.
           88  WS-STATUS-RETURNED     VALUE 2.
           88  WS-STATUS-REPRESENT    VALUE 3.
      *--- NSF Fee Structure ---
       01  WS-NSF-FEE                 PIC S9(5)V99 COMP-3.
       01  WS-DAILY-FEE-CAP          PIC S9(7)V99 COMP-3.
       01  WS-DAILY-FEE-TOTAL        PIC S9(7)V99 COMP-3.
       01  WS-MAX-REPRESENT           PIC 9.
      *--- Counters ---
       01  WS-PAID-COUNT              PIC S9(3) COMP-3.
       01  WS-RETURNED-COUNT          PIC S9(3) COMP-3.
       01  WS-REPRESENT-COUNT         PIC S9(3) COMP-3.
       01  WS-TOTAL-PAID-AMT         PIC S9(11)V99 COMP-3.
       01  WS-TOTAL-RETURNED-AMT     PIC S9(9)V99 COMP-3.
       01  WS-TOTAL-FEES             PIC S9(7)V99 COMP-3.
      *--- De Minimis Threshold ---
       01  WS-DE-MINIMIS             PIC S9(5)V99 COMP-3.
       01  WS-BELOW-THRESHOLD        PIC 9.
      *--- Display ---
       01  WS-DISP-AMT               PIC -$$$,$$9.99.
       01  WS-DISP-BAL               PIC -$$$,$$$,$$9.99.
       01  WS-DISP-CT                PIC ZZ9.
      *--- String Work ---
       01  WS-STATUS-TEXT             PIC X(12).
       01  WS-REPORT-LINE            PIC X(72).
      *--- Tally ---
       01  WS-PAYEE-TALLY            PIC S9(5) COMP-3.

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-CHECKS
           PERFORM 3000-PROCESS-CHECKS
           PERFORM 4000-HANDLE-RETURNS
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.

       1000-INITIALIZE.
           MOVE 7788990011 TO WS-ACCOUNT-NUM
           MOVE 847.32 TO WS-CURRENT-BALANCE
           MOVE 150.00 TO WS-HOLD-TOTAL
           COMPUTE WS-AVAILABLE-BAL =
               WS-CURRENT-BALANCE - WS-HOLD-TOTAL
           MOVE 36.00 TO WS-NSF-FEE
           MOVE 144.00 TO WS-DAILY-FEE-CAP
           MOVE 0 TO WS-DAILY-FEE-TOTAL
           MOVE 2 TO WS-MAX-REPRESENT
           MOVE 25.00 TO WS-DE-MINIMIS
           MOVE 0 TO WS-PAID-COUNT
           MOVE 0 TO WS-RETURNED-COUNT
           MOVE 0 TO WS-REPRESENT-COUNT
           MOVE 0 TO WS-TOTAL-PAID-AMT
           MOVE 0 TO WS-TOTAL-RETURNED-AMT
           MOVE 0 TO WS-TOTAL-FEES.

       2000-LOAD-CHECKS.
           MOVE 5 TO WS-CHK-COUNT
           MOVE 001042 TO WS-CHK-NUM(1)
           MOVE 125.00 TO WS-CHK-AMOUNT(1)
           MOVE "ELECTRIC COMPANY"
               TO WS-CHK-PAYEE(1)
           MOVE 0 TO WS-CHK-STATUS(1)
           MOVE 0 TO WS-CHK-ATTEMPTS(1)
           MOVE 001043 TO WS-CHK-NUM(2)
           MOVE 350.00 TO WS-CHK-AMOUNT(2)
           MOVE "RENT PAYMENT"
               TO WS-CHK-PAYEE(2)
           MOVE 0 TO WS-CHK-STATUS(2)
           MOVE 0 TO WS-CHK-ATTEMPTS(2)
           MOVE 001044 TO WS-CHK-NUM(3)
           MOVE 15.00 TO WS-CHK-AMOUNT(3)
           MOVE "MAGAZINE SUBSCRIPTION"
               TO WS-CHK-PAYEE(3)
           MOVE 0 TO WS-CHK-STATUS(3)
           MOVE 0 TO WS-CHK-ATTEMPTS(3)
           MOVE 001045 TO WS-CHK-NUM(4)
           MOVE 500.00 TO WS-CHK-AMOUNT(4)
           MOVE "AUTO INSURANCE"
               TO WS-CHK-PAYEE(4)
           MOVE 0 TO WS-CHK-STATUS(4)
           MOVE 1 TO WS-CHK-ATTEMPTS(4)
           MOVE 001046 TO WS-CHK-NUM(5)
           MOVE 200.00 TO WS-CHK-AMOUNT(5)
           MOVE "CREDIT CARD PMT"
               TO WS-CHK-PAYEE(5)
           MOVE 0 TO WS-CHK-STATUS(5)
           MOVE 0 TO WS-CHK-ATTEMPTS(5).

       3000-PROCESS-CHECKS.
           PERFORM VARYING WS-CHK-IDX FROM 1 BY 1
               UNTIL WS-CHK-IDX > WS-CHK-COUNT
               IF WS-CHK-STATUS(WS-CHK-IDX) = 0
                   IF WS-CHK-AMOUNT(WS-CHK-IDX) <=
                       WS-AVAILABLE-BAL
                       MOVE 1 TO WS-CHK-STATUS(WS-CHK-IDX)
                       SUBTRACT WS-CHK-AMOUNT(WS-CHK-IDX)
                           FROM WS-AVAILABLE-BAL
                       SUBTRACT WS-CHK-AMOUNT(WS-CHK-IDX)
                           FROM WS-CURRENT-BALANCE
                       ADD WS-CHK-AMOUNT(WS-CHK-IDX)
                           TO WS-TOTAL-PAID-AMT
                       ADD 1 TO WS-PAID-COUNT
                   ELSE
                       PERFORM 3100-CHECK-DE-MINIMIS
                       IF WS-BELOW-THRESHOLD = 1
                           MOVE 1
                               TO WS-CHK-STATUS(WS-CHK-IDX)
                           SUBTRACT WS-CHK-AMOUNT(WS-CHK-IDX)
                               FROM WS-AVAILABLE-BAL
                           SUBTRACT WS-CHK-AMOUNT(WS-CHK-IDX)
                               FROM WS-CURRENT-BALANCE
                           ADD 1 TO WS-PAID-COUNT
                       ELSE
                           MOVE 2
                               TO WS-CHK-STATUS(WS-CHK-IDX)
                           ADD 1
                               TO WS-CHK-ATTEMPTS(WS-CHK-IDX)
                           ADD 1 TO WS-RETURNED-COUNT
                           ADD WS-CHK-AMOUNT(WS-CHK-IDX)
                               TO WS-TOTAL-RETURNED-AMT
                           PERFORM 3200-ASSESS-NSF-FEE
                       END-IF
                   END-IF
               END-IF
           END-PERFORM.

       3100-CHECK-DE-MINIMIS.
           MOVE 0 TO WS-BELOW-THRESHOLD
           COMPUTE WS-WORK-AMT =
               WS-CHK-AMOUNT(WS-CHK-IDX)
               - WS-AVAILABLE-BAL
           IF WS-WORK-AMT <= WS-DE-MINIMIS
               MOVE 1 TO WS-BELOW-THRESHOLD
           END-IF.

       3200-ASSESS-NSF-FEE.
           IF WS-DAILY-FEE-TOTAL + WS-NSF-FEE
               <= WS-DAILY-FEE-CAP
               MOVE WS-NSF-FEE
                   TO WS-CHK-FEE(WS-CHK-IDX)
               ADD WS-NSF-FEE TO WS-DAILY-FEE-TOTAL
               ADD WS-NSF-FEE TO WS-TOTAL-FEES
               SUBTRACT WS-NSF-FEE
                   FROM WS-CURRENT-BALANCE
           ELSE
               MOVE 0 TO WS-CHK-FEE(WS-CHK-IDX)
           END-IF.

       4000-HANDLE-RETURNS.
           PERFORM VARYING WS-CHK-IDX FROM 1 BY 1
               UNTIL WS-CHK-IDX > WS-CHK-COUNT
               IF WS-CHK-STATUS(WS-CHK-IDX) = 2
                   IF WS-CHK-ATTEMPTS(WS-CHK-IDX) <
                       WS-MAX-REPRESENT
                       MOVE 3 TO WS-CHK-STATUS(WS-CHK-IDX)
                       ADD 1 TO WS-REPRESENT-COUNT
                   END-IF
               END-IF
           END-PERFORM.

       5000-DISPLAY-RESULTS.
           DISPLAY "========================================"
           DISPLAY "   NSF CHECK PROCESSING REPORT"
           DISPLAY "========================================"
           DISPLAY "ACCOUNT: " WS-ACCOUNT-NUM
           PERFORM VARYING WS-CHK-IDX FROM 1 BY 1
               UNTIL WS-CHK-IDX > WS-CHK-COUNT
               EVALUATE WS-CHK-STATUS(WS-CHK-IDX)
                   WHEN 1
                       MOVE "PAID" TO WS-STATUS-TEXT
                   WHEN 2
                       MOVE "RETURNED" TO WS-STATUS-TEXT
                   WHEN 3
                       MOVE "RE-PRESENT" TO WS-STATUS-TEXT
                   WHEN OTHER
                       MOVE "PENDING" TO WS-STATUS-TEXT
               END-EVALUATE
               MOVE 0 TO WS-PAYEE-TALLY
               INSPECT WS-CHK-PAYEE(WS-CHK-IDX)
                   TALLYING WS-PAYEE-TALLY
                   FOR ALL SPACES
               MOVE WS-CHK-AMOUNT(WS-CHK-IDX)
                   TO WS-DISP-AMT
               DISPLAY "CHK " WS-CHK-NUM(WS-CHK-IDX)
                   " " WS-DISP-AMT
                   " " WS-STATUS-TEXT
           END-PERFORM
           DISPLAY "--- SUMMARY ---"
           MOVE WS-PAID-COUNT TO WS-DISP-CT
           DISPLAY "PAID:       " WS-DISP-CT
           MOVE WS-RETURNED-COUNT TO WS-DISP-CT
           DISPLAY "RETURNED:   " WS-DISP-CT
           MOVE WS-REPRESENT-COUNT TO WS-DISP-CT
           DISPLAY "RE-PRESENT: " WS-DISP-CT
           MOVE WS-TOTAL-FEES TO WS-DISP-AMT
           DISPLAY "NSF FEES:   " WS-DISP-AMT
           MOVE WS-CURRENT-BALANCE TO WS-DISP-BAL
           DISPLAY "BALANCE:    " WS-DISP-BAL
           DISPLAY "========================================".
