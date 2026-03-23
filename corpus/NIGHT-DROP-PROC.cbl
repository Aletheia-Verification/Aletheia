       IDENTIFICATION DIVISION.
       PROGRAM-ID. NIGHT-DROP-PROC.
      *================================================================*
      * Night Drop Processing and Verification                         *
      * Opens sealed bags, verifies declared amounts against actual,   *
      * posts credits, handles discrepancies with dual verification.   *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- Night Drop Bags ---
       01  WS-BAG-TABLE.
           05  WS-BAG-ENTRY OCCURS 8 TIMES.
               10  WS-BAG-ID          PIC X(10).
               10  WS-BAG-CUST-ID     PIC 9(10).
               10  WS-BAG-CUST-NAME   PIC X(25).
               10  WS-BAG-DECLARED    PIC S9(9)V99 COMP-3.
               10  WS-BAG-ACTUAL      PIC S9(9)V99 COMP-3.
               10  WS-BAG-VARIANCE    PIC S9(7)V99 COMP-3.
               10  WS-BAG-STATUS      PIC 9.
       01  WS-BAG-IDX                PIC 9(3).
       01  WS-BAG-COUNT              PIC 9(3).
      *--- Status Values ---
       01  WS-BAG-STATUS-VAL        PIC 9.
           88  WS-BAG-MATCHED       VALUE 1.
           88  WS-BAG-OVER          VALUE 2.
           88  WS-BAG-SHORT         VALUE 3.
           88  WS-BAG-EMPTY         VALUE 4.
      *--- Totals ---
       01  WS-TOTAL-DECLARED        PIC S9(11)V99 COMP-3.
       01  WS-TOTAL-ACTUAL          PIC S9(11)V99 COMP-3.
       01  WS-TOTAL-VARIANCE        PIC S9(9)V99 COMP-3.
       01  WS-ABS-VARIANCE          PIC S9(9)V99 COMP-3.
       01  WS-MATCHED-CT            PIC S9(3) COMP-3.
       01  WS-OVER-CT               PIC S9(3) COMP-3.
       01  WS-SHORT-CT              PIC S9(3) COMP-3.
      *--- Processing ---
       01  WS-PROCESSOR-ID          PIC X(8).
       01  WS-VERIFIER-ID           PIC X(8).
       01  WS-PROCESS-DATE          PIC 9(8).
       01  WS-PROCESS-TIME          PIC 9(6).
       01  WS-TOLERANCE             PIC S9(5)V99 COMP-3.
      *--- Display ---
       01  WS-DISP-AMT              PIC -$$$,$$$,$$9.99.
       01  WS-DISP-VAR              PIC -$$,$$9.99.
       01  WS-DISP-CT               PIC ZZ9.
      *--- String/Tally ---
       01  WS-STATUS-TEXT           PIC X(10).
       01  WS-CUSTNAME-TALLY       PIC S9(3) COMP-3.

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-BAGS
           PERFORM 3000-VERIFY-BAGS
           PERFORM 4000-COMPUTE-TOTALS
           PERFORM 5000-DISPLAY-REPORT
           STOP RUN.

       1000-INITIALIZE.
           MOVE "PRC00401" TO WS-PROCESSOR-ID
           MOVE "VRF00201" TO WS-VERIFIER-ID
           ACCEPT WS-PROCESS-DATE FROM DATE YYYYMMDD
           ACCEPT WS-PROCESS-TIME FROM TIME
           MOVE 1.00 TO WS-TOLERANCE
           MOVE 0 TO WS-TOTAL-DECLARED
           MOVE 0 TO WS-TOTAL-ACTUAL
           MOVE 0 TO WS-MATCHED-CT
           MOVE 0 TO WS-OVER-CT
           MOVE 0 TO WS-SHORT-CT.

       2000-LOAD-BAGS.
           MOVE 6 TO WS-BAG-COUNT
           MOVE "ND-100001" TO WS-BAG-ID(1)
           MOVE 5001001001 TO WS-BAG-CUST-ID(1)
           MOVE "MAIN ST DELI"
               TO WS-BAG-CUST-NAME(1)
           MOVE 1250.00 TO WS-BAG-DECLARED(1)
           MOVE 1250.00 TO WS-BAG-ACTUAL(1)
           MOVE "ND-100002" TO WS-BAG-ID(2)
           MOVE 5002002002 TO WS-BAG-CUST-ID(2)
           MOVE "CORNER PHARMACY"
               TO WS-BAG-CUST-NAME(2)
           MOVE 3475.50 TO WS-BAG-DECLARED(2)
           MOVE 3470.50 TO WS-BAG-ACTUAL(2)
           MOVE "ND-100003" TO WS-BAG-ID(3)
           MOVE 5003003003 TO WS-BAG-CUST-ID(3)
           MOVE "OAKWOOD HARDWARE"
               TO WS-BAG-CUST-NAME(3)
           MOVE 875.00 TO WS-BAG-DECLARED(3)
           MOVE 900.00 TO WS-BAG-ACTUAL(3)
           MOVE "ND-100004" TO WS-BAG-ID(4)
           MOVE 5004004004 TO WS-BAG-CUST-ID(4)
           MOVE "TONY PIZZA PARLOR"
               TO WS-BAG-CUST-NAME(4)
           MOVE 2100.00 TO WS-BAG-DECLARED(4)
           MOVE 2100.00 TO WS-BAG-ACTUAL(4)
           MOVE "ND-100005" TO WS-BAG-ID(5)
           MOVE 5005005005 TO WS-BAG-CUST-ID(5)
           MOVE "LOTUS SPA SALON"
               TO WS-BAG-CUST-NAME(5)
           MOVE 1800.00 TO WS-BAG-DECLARED(5)
           MOVE 1750.25 TO WS-BAG-ACTUAL(5)
           MOVE "ND-100006" TO WS-BAG-ID(6)
           MOVE 5006006006 TO WS-BAG-CUST-ID(6)
           MOVE "VALLEY AUTO PARTS"
               TO WS-BAG-CUST-NAME(6)
           MOVE 4500.00 TO WS-BAG-DECLARED(6)
           MOVE 4500.00 TO WS-BAG-ACTUAL(6).

       3000-VERIFY-BAGS.
           PERFORM VARYING WS-BAG-IDX FROM 1 BY 1
               UNTIL WS-BAG-IDX > WS-BAG-COUNT
               COMPUTE WS-BAG-VARIANCE(WS-BAG-IDX) =
                   WS-BAG-ACTUAL(WS-BAG-IDX)
                   - WS-BAG-DECLARED(WS-BAG-IDX)
               EVALUATE TRUE
                   WHEN WS-BAG-ACTUAL(WS-BAG-IDX) = 0
                       MOVE 4 TO WS-BAG-STATUS(WS-BAG-IDX)
                   WHEN WS-BAG-VARIANCE(WS-BAG-IDX) > 0
                       IF WS-BAG-VARIANCE(WS-BAG-IDX)
                           <= WS-TOLERANCE
                           MOVE 1
                               TO WS-BAG-STATUS(WS-BAG-IDX)
                           ADD 1 TO WS-MATCHED-CT
                       ELSE
                           MOVE 2
                               TO WS-BAG-STATUS(WS-BAG-IDX)
                           ADD 1 TO WS-OVER-CT
                       END-IF
                   WHEN WS-BAG-VARIANCE(WS-BAG-IDX) < 0
                       COMPUTE WS-ABS-VARIANCE =
                           WS-BAG-VARIANCE(WS-BAG-IDX) * -1
                       IF WS-ABS-VARIANCE <= WS-TOLERANCE
                           MOVE 1
                               TO WS-BAG-STATUS(WS-BAG-IDX)
                           ADD 1 TO WS-MATCHED-CT
                       ELSE
                           MOVE 3
                               TO WS-BAG-STATUS(WS-BAG-IDX)
                           ADD 1 TO WS-SHORT-CT
                       END-IF
                   WHEN OTHER
                       MOVE 1 TO WS-BAG-STATUS(WS-BAG-IDX)
                       ADD 1 TO WS-MATCHED-CT
               END-EVALUATE
               ADD WS-BAG-DECLARED(WS-BAG-IDX)
                   TO WS-TOTAL-DECLARED
               ADD WS-BAG-ACTUAL(WS-BAG-IDX)
                   TO WS-TOTAL-ACTUAL
           END-PERFORM.

       4000-COMPUTE-TOTALS.
           COMPUTE WS-TOTAL-VARIANCE =
               WS-TOTAL-ACTUAL - WS-TOTAL-DECLARED.

       5000-DISPLAY-REPORT.
           DISPLAY "========================================"
           DISPLAY "   NIGHT DROP PROCESSING"
           DISPLAY "========================================"
           DISPLAY "PROCESSOR: " WS-PROCESSOR-ID
           DISPLAY "VERIFIER:  " WS-VERIFIER-ID
           PERFORM VARYING WS-BAG-IDX FROM 1 BY 1
               UNTIL WS-BAG-IDX > WS-BAG-COUNT
               EVALUATE WS-BAG-STATUS(WS-BAG-IDX)
                   WHEN 1
                       MOVE "MATCHED" TO WS-STATUS-TEXT
                   WHEN 2
                       MOVE "OVER" TO WS-STATUS-TEXT
                   WHEN 3
                       MOVE "SHORT" TO WS-STATUS-TEXT
                   WHEN 4
                       MOVE "EMPTY" TO WS-STATUS-TEXT
               END-EVALUATE
               MOVE 0 TO WS-CUSTNAME-TALLY
               INSPECT WS-BAG-CUST-NAME(WS-BAG-IDX)
                   TALLYING WS-CUSTNAME-TALLY
                   FOR ALL SPACES
               MOVE WS-BAG-ACTUAL(WS-BAG-IDX)
                   TO WS-DISP-AMT
               DISPLAY WS-BAG-ID(WS-BAG-IDX)
                   " " WS-BAG-CUST-NAME(WS-BAG-IDX)
               DISPLAY "  ACTUAL: " WS-DISP-AMT
                   " " WS-STATUS-TEXT
               IF WS-BAG-VARIANCE(WS-BAG-IDX) NOT = 0
                   MOVE WS-BAG-VARIANCE(WS-BAG-IDX)
                       TO WS-DISP-VAR
                   DISPLAY "  VARIANCE: " WS-DISP-VAR
               END-IF
           END-PERFORM
           DISPLAY "--- SUMMARY ---"
           MOVE WS-MATCHED-CT TO WS-DISP-CT
           DISPLAY "MATCHED: " WS-DISP-CT
           MOVE WS-SHORT-CT TO WS-DISP-CT
           DISPLAY "SHORT:   " WS-DISP-CT
           MOVE WS-OVER-CT TO WS-DISP-CT
           DISPLAY "OVER:    " WS-DISP-CT
           MOVE WS-TOTAL-ACTUAL TO WS-DISP-AMT
           DISPLAY "TOTAL:   " WS-DISP-AMT
           DISPLAY "========================================".
