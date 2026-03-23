       IDENTIFICATION DIVISION.
       PROGRAM-ID. TELLER-CTR-REPORT.
      *================================================================*
      * Currency Transaction Report (CTR) Generator                    *
      * Detects cash transactions exceeding BSA threshold ($10K),      *
      * aggregates related transactions, generates FinCEN CTR data.    *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- Customer Transaction Log ---
       01  WS-TXN-LOG-TABLE.
           05  WS-TXN-LOG OCCURS 10 TIMES.
               10  WS-TL-CUST-ID     PIC 9(10).
               10  WS-TL-CUST-NAME   PIC X(30).
               10  WS-TL-TXN-TYPE    PIC X(3).
               10  WS-TL-AMOUNT      PIC S9(9)V99 COMP-3.
               10  WS-TL-CASH-FLAG   PIC 9.
               10  WS-TL-CTR-FLAG    PIC 9.
       01  WS-TL-IDX                 PIC 9(3).
       01  WS-TL-COUNT               PIC 9(3).
      *--- Customer Aggregation ---
       01  WS-CUST-AGG-TABLE.
           05  WS-CUST-AGG OCCURS 5 TIMES.
               10  WS-AGG-CUST-ID    PIC 9(10).
               10  WS-AGG-CUST-NAME  PIC X(30).
               10  WS-AGG-CASH-IN    PIC S9(11)V99 COMP-3.
               10  WS-AGG-CASH-OUT   PIC S9(11)V99 COMP-3.
               10  WS-AGG-TOTAL      PIC S9(11)V99 COMP-3.
               10  WS-AGG-CTR-REQ    PIC 9.
               10  WS-AGG-TXN-CT     PIC S9(3) COMP-3.
       01  WS-AGG-IDX                PIC 9(3).
       01  WS-AGG-COUNT              PIC 9(3).
       01  WS-AGG-FOUND              PIC 9.
      *--- BSA Thresholds ---
       01  WS-CTR-THRESHOLD          PIC S9(9)V99 COMP-3.
       01  WS-STRUCTURING-LIMIT     PIC S9(9)V99 COMP-3.
      *--- Counters ---
       01  WS-CTR-REQUIRED-CT        PIC S9(3) COMP-3.
       01  WS-STRUCTURING-ALERT-CT   PIC S9(3) COMP-3.
       01  WS-TOTAL-CASH-IN          PIC S9(11)V99 COMP-3.
       01  WS-TOTAL-CASH-OUT         PIC S9(11)V99 COMP-3.
      *--- Display ---
       01  WS-DISP-AMT               PIC -$$$,$$$,$$9.99.
       01  WS-DISP-CT                PIC ZZ9.
      *--- Tally/String ---
       01  WS-NAME-TALLY             PIC S9(5) COMP-3.
       01  WS-CTR-LINE               PIC X(72).

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-TRANSACTIONS
           PERFORM 3000-AGGREGATE-BY-CUSTOMER
           PERFORM 4000-CHECK-CTR-THRESHOLD
           PERFORM 5000-CHECK-STRUCTURING
           PERFORM 6000-DISPLAY-REPORT
           STOP RUN.

       1000-INITIALIZE.
           MOVE 10000.00 TO WS-CTR-THRESHOLD
           MOVE 8000.00 TO WS-STRUCTURING-LIMIT
           MOVE 0 TO WS-AGG-COUNT
           MOVE 0 TO WS-CTR-REQUIRED-CT
           MOVE 0 TO WS-STRUCTURING-ALERT-CT
           MOVE 0 TO WS-TOTAL-CASH-IN
           MOVE 0 TO WS-TOTAL-CASH-OUT.

       2000-LOAD-TRANSACTIONS.
           MOVE 8 TO WS-TL-COUNT
           MOVE 1001001001 TO WS-TL-CUST-ID(1)
           MOVE "SMITH, ROBERT J"
               TO WS-TL-CUST-NAME(1)
           MOVE "DEP" TO WS-TL-TXN-TYPE(1)
           MOVE 7500.00 TO WS-TL-AMOUNT(1)
           MOVE 1 TO WS-TL-CASH-FLAG(1)
           MOVE 0 TO WS-TL-CTR-FLAG(1)
           MOVE 1001001001 TO WS-TL-CUST-ID(2)
           MOVE "SMITH, ROBERT J"
               TO WS-TL-CUST-NAME(2)
           MOVE "DEP" TO WS-TL-TXN-TYPE(2)
           MOVE 4500.00 TO WS-TL-AMOUNT(2)
           MOVE 1 TO WS-TL-CASH-FLAG(2)
           MOVE 0 TO WS-TL-CTR-FLAG(2)
           MOVE 2002002002 TO WS-TL-CUST-ID(3)
           MOVE "JONES, PATRICIA A"
               TO WS-TL-CUST-NAME(3)
           MOVE "WTH" TO WS-TL-TXN-TYPE(3)
           MOVE 15000.00 TO WS-TL-AMOUNT(3)
           MOVE 1 TO WS-TL-CASH-FLAG(3)
           MOVE 0 TO WS-TL-CTR-FLAG(3)
           MOVE 3003003003 TO WS-TL-CUST-ID(4)
           MOVE "CHEN, WEI M"
               TO WS-TL-CUST-NAME(4)
           MOVE "DEP" TO WS-TL-TXN-TYPE(4)
           MOVE 9500.00 TO WS-TL-AMOUNT(4)
           MOVE 1 TO WS-TL-CASH-FLAG(4)
           MOVE 0 TO WS-TL-CTR-FLAG(4)
           MOVE 3003003003 TO WS-TL-CUST-ID(5)
           MOVE "CHEN, WEI M"
               TO WS-TL-CUST-NAME(5)
           MOVE "DEP" TO WS-TL-TXN-TYPE(5)
           MOVE 9800.00 TO WS-TL-AMOUNT(5)
           MOVE 1 TO WS-TL-CASH-FLAG(5)
           MOVE 0 TO WS-TL-CTR-FLAG(5)
           MOVE 4004004004 TO WS-TL-CUST-ID(6)
           MOVE "GARCIA, MARIA L"
               TO WS-TL-CUST-NAME(6)
           MOVE "DEP" TO WS-TL-TXN-TYPE(6)
           MOVE 3000.00 TO WS-TL-AMOUNT(6)
           MOVE 1 TO WS-TL-CASH-FLAG(6)
           MOVE 0 TO WS-TL-CTR-FLAG(6)
           MOVE 1001001001 TO WS-TL-CUST-ID(7)
           MOVE "SMITH, ROBERT J"
               TO WS-TL-CUST-NAME(7)
           MOVE "WTH" TO WS-TL-TXN-TYPE(7)
           MOVE 2000.00 TO WS-TL-AMOUNT(7)
           MOVE 1 TO WS-TL-CASH-FLAG(7)
           MOVE 0 TO WS-TL-CTR-FLAG(7)
           MOVE 2002002002 TO WS-TL-CUST-ID(8)
           MOVE "JONES, PATRICIA A"
               TO WS-TL-CUST-NAME(8)
           MOVE "DEP" TO WS-TL-TXN-TYPE(8)
           MOVE 5000.00 TO WS-TL-AMOUNT(8)
           MOVE 1 TO WS-TL-CASH-FLAG(8)
           MOVE 0 TO WS-TL-CTR-FLAG(8).

       3000-AGGREGATE-BY-CUSTOMER.
           PERFORM VARYING WS-TL-IDX FROM 1 BY 1
               UNTIL WS-TL-IDX > WS-TL-COUNT
               IF WS-TL-CASH-FLAG(WS-TL-IDX) = 1
                   PERFORM 3100-FIND-OR-ADD-CUSTOMER
                   IF WS-TL-TXN-TYPE(WS-TL-IDX) = "DEP"
                       ADD WS-TL-AMOUNT(WS-TL-IDX)
                           TO WS-AGG-CASH-IN(WS-AGG-IDX)
                       ADD WS-TL-AMOUNT(WS-TL-IDX)
                           TO WS-TOTAL-CASH-IN
                   ELSE
                       ADD WS-TL-AMOUNT(WS-TL-IDX)
                           TO WS-AGG-CASH-OUT(WS-AGG-IDX)
                       ADD WS-TL-AMOUNT(WS-TL-IDX)
                           TO WS-TOTAL-CASH-OUT
                   END-IF
                   ADD 1 TO WS-AGG-TXN-CT(WS-AGG-IDX)
               END-IF
           END-PERFORM.

       3100-FIND-OR-ADD-CUSTOMER.
           MOVE 0 TO WS-AGG-FOUND
           PERFORM VARYING WS-AGG-IDX FROM 1 BY 1
               UNTIL WS-AGG-IDX > WS-AGG-COUNT
                  OR WS-AGG-FOUND = 1
               IF WS-AGG-CUST-ID(WS-AGG-IDX) =
                   WS-TL-CUST-ID(WS-TL-IDX)
                   MOVE 1 TO WS-AGG-FOUND
               END-IF
           END-PERFORM
           IF WS-AGG-FOUND = 0
               ADD 1 TO WS-AGG-COUNT
               MOVE WS-AGG-COUNT TO WS-AGG-IDX
               MOVE WS-TL-CUST-ID(WS-TL-IDX)
                   TO WS-AGG-CUST-ID(WS-AGG-IDX)
               MOVE WS-TL-CUST-NAME(WS-TL-IDX)
                   TO WS-AGG-CUST-NAME(WS-AGG-IDX)
               MOVE 0 TO WS-AGG-CASH-IN(WS-AGG-IDX)
               MOVE 0 TO WS-AGG-CASH-OUT(WS-AGG-IDX)
               MOVE 0 TO WS-AGG-TXN-CT(WS-AGG-IDX)
               MOVE 0 TO WS-AGG-CTR-REQ(WS-AGG-IDX)
           ELSE
               SUBTRACT 1 FROM WS-AGG-IDX
           END-IF.

       4000-CHECK-CTR-THRESHOLD.
           PERFORM VARYING WS-AGG-IDX FROM 1 BY 1
               UNTIL WS-AGG-IDX > WS-AGG-COUNT
               COMPUTE WS-AGG-TOTAL(WS-AGG-IDX) =
                   WS-AGG-CASH-IN(WS-AGG-IDX)
                   + WS-AGG-CASH-OUT(WS-AGG-IDX)
               IF WS-AGG-TOTAL(WS-AGG-IDX) >
                   WS-CTR-THRESHOLD
                   MOVE 1 TO WS-AGG-CTR-REQ(WS-AGG-IDX)
                   ADD 1 TO WS-CTR-REQUIRED-CT
               END-IF
           END-PERFORM.

       5000-CHECK-STRUCTURING.
           PERFORM VARYING WS-AGG-IDX FROM 1 BY 1
               UNTIL WS-AGG-IDX > WS-AGG-COUNT
               IF WS-AGG-CTR-REQ(WS-AGG-IDX) = 0
                   IF WS-AGG-TOTAL(WS-AGG-IDX) >
                       WS-STRUCTURING-LIMIT
                       IF WS-AGG-TXN-CT(WS-AGG-IDX) > 1
                           ADD 1
                               TO WS-STRUCTURING-ALERT-CT
                       END-IF
                   END-IF
               END-IF
           END-PERFORM.

       6000-DISPLAY-REPORT.
           DISPLAY "========================================"
           DISPLAY "   CTR ANALYSIS REPORT"
           DISPLAY "========================================"
           PERFORM VARYING WS-AGG-IDX FROM 1 BY 1
               UNTIL WS-AGG-IDX > WS-AGG-COUNT
               MOVE 0 TO WS-NAME-TALLY
               INSPECT WS-AGG-CUST-NAME(WS-AGG-IDX)
                   TALLYING WS-NAME-TALLY FOR ALL ","
               DISPLAY WS-AGG-CUST-NAME(WS-AGG-IDX)
               MOVE WS-AGG-TOTAL(WS-AGG-IDX)
                   TO WS-DISP-AMT
               DISPLAY "  TOTAL CASH: " WS-DISP-AMT
               IF WS-AGG-CTR-REQ(WS-AGG-IDX) = 1
                   DISPLAY "  *** CTR REQUIRED ***"
               END-IF
           END-PERFORM
           DISPLAY "--- SUMMARY ---"
           MOVE WS-CTR-REQUIRED-CT TO WS-DISP-CT
           DISPLAY "CTR FILINGS:   " WS-DISP-CT
           MOVE WS-STRUCTURING-ALERT-CT TO WS-DISP-CT
           DISPLAY "STRUCT ALERTS: " WS-DISP-CT
           MOVE WS-TOTAL-CASH-IN TO WS-DISP-AMT
           DISPLAY "TOTAL CASH IN: " WS-DISP-AMT
           MOVE WS-TOTAL-CASH-OUT TO WS-DISP-AMT
           DISPLAY "TOTAL CASH OUT:" WS-DISP-AMT
           DISPLAY "========================================".
