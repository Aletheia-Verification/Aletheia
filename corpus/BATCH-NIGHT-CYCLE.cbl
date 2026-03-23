       IDENTIFICATION DIVISION.
       PROGRAM-ID. BATCH-NIGHT-CYCLE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CYCLE-STEPS.
           05 WS-STEP OCCURS 8 TIMES.
               10 WS-STEP-NAME     PIC X(20).
               10 WS-STEP-STATUS   PIC X(1).
                   88 STEP-PENDING  VALUE 'P'.
                   88 STEP-RUNNING  VALUE 'R'.
                   88 STEP-DONE     VALUE 'D'.
                   88 STEP-FAILED   VALUE 'F'.
               10 WS-STEP-START    PIC 9(8).
               10 WS-STEP-END      PIC 9(8).
               10 WS-STEP-RECS     PIC 9(7).
       01 WS-TOTAL-STEPS          PIC 9 VALUE 8.
       01 WS-STEP-IDX             PIC 9.
       01 WS-CYCLE-DATE           PIC 9(8).
       01 WS-CYCLE-STATUS         PIC X(10).
       01 WS-FAILED-STEP          PIC X(20).
       01 WS-TOTAL-RECORDS        PIC 9(9).
       01 WS-INTEREST-AMT         PIC S9(11)V99 COMP-3.
       01 WS-FEE-AMT              PIC S9(9)V99 COMP-3.
       01 WS-SWEEP-AMT            PIC S9(11)V99 COMP-3.
       01 WS-GL-ENTRIES           PIC 9(7).
       01 WS-REPORT-LINE          PIC X(80).
       01 WS-ABORT-FLAG           PIC X VALUE 'N'.
           88 CYCLE-ABORTED       VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT-CYCLE
           PERFORM 2000-RUN-STEPS
           PERFORM 3000-CYCLE-SUMMARY
           STOP RUN.
       1000-INIT-CYCLE.
           ACCEPT WS-CYCLE-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-TOTAL-RECORDS
           MOVE 0 TO WS-INTEREST-AMT
           MOVE 0 TO WS-FEE-AMT
           MOVE 0 TO WS-SWEEP-AMT
           MOVE 0 TO WS-GL-ENTRIES
           MOVE 'N' TO WS-ABORT-FLAG
           PERFORM VARYING WS-STEP-IDX FROM 1 BY 1
               UNTIL WS-STEP-IDX > WS-TOTAL-STEPS
               MOVE 'P' TO WS-STEP-STATUS(WS-STEP-IDX)
               MOVE 0 TO WS-STEP-RECS(WS-STEP-IDX)
           END-PERFORM.
       2000-RUN-STEPS.
           PERFORM VARYING WS-STEP-IDX FROM 1 BY 1
               UNTIL WS-STEP-IDX > WS-TOTAL-STEPS
               OR CYCLE-ABORTED
               MOVE 'R' TO WS-STEP-STATUS(WS-STEP-IDX)
               ACCEPT WS-STEP-START(WS-STEP-IDX) FROM TIME
               PERFORM 2100-EXECUTE-STEP
               ACCEPT WS-STEP-END(WS-STEP-IDX) FROM TIME
               ADD WS-STEP-RECS(WS-STEP-IDX)
                   TO WS-TOTAL-RECORDS
           END-PERFORM.
       2100-EXECUTE-STEP.
           EVALUATE WS-STEP-IDX
               WHEN 1
                   MOVE 'INTEREST ACCRUAL' TO
                       WS-STEP-NAME(WS-STEP-IDX)
                   COMPUTE WS-INTEREST-AMT =
                       WS-INTEREST-AMT + 125000.50
                   MOVE 15000 TO WS-STEP-RECS(WS-STEP-IDX)
                   MOVE 'D' TO WS-STEP-STATUS(WS-STEP-IDX)
               WHEN 2
                   MOVE 'FEE ASSESSMENT  ' TO
                       WS-STEP-NAME(WS-STEP-IDX)
                   COMPUTE WS-FEE-AMT =
                       WS-FEE-AMT + 8500.00
                   MOVE 3200 TO WS-STEP-RECS(WS-STEP-IDX)
                   MOVE 'D' TO WS-STEP-STATUS(WS-STEP-IDX)
               WHEN 3
                   MOVE 'SWEEP PROCESSING' TO
                       WS-STEP-NAME(WS-STEP-IDX)
                   COMPUTE WS-SWEEP-AMT =
                       WS-SWEEP-AMT + 5000000.00
                   MOVE 450 TO WS-STEP-RECS(WS-STEP-IDX)
                   MOVE 'D' TO WS-STEP-STATUS(WS-STEP-IDX)
               WHEN 4
                   MOVE 'GL POSTING      ' TO
                       WS-STEP-NAME(WS-STEP-IDX)
                   ADD 25000 TO WS-GL-ENTRIES
                   MOVE 25000 TO WS-STEP-RECS(WS-STEP-IDX)
                   MOVE 'D' TO WS-STEP-STATUS(WS-STEP-IDX)
               WHEN 5
                   MOVE 'STATEMENT GEN   ' TO
                       WS-STEP-NAME(WS-STEP-IDX)
                   MOVE 12000 TO WS-STEP-RECS(WS-STEP-IDX)
                   MOVE 'D' TO WS-STEP-STATUS(WS-STEP-IDX)
               WHEN 6
                   MOVE 'REPORT EXTRACT  ' TO
                       WS-STEP-NAME(WS-STEP-IDX)
                   MOVE 5 TO WS-STEP-RECS(WS-STEP-IDX)
                   MOVE 'D' TO WS-STEP-STATUS(WS-STEP-IDX)
               WHEN 7
                   MOVE 'ARCHIVE OLD     ' TO
                       WS-STEP-NAME(WS-STEP-IDX)
                   MOVE 800 TO WS-STEP-RECS(WS-STEP-IDX)
                   MOVE 'D' TO WS-STEP-STATUS(WS-STEP-IDX)
               WHEN 8
                   MOVE 'CHECKPOINT      ' TO
                       WS-STEP-NAME(WS-STEP-IDX)
                   MOVE 1 TO WS-STEP-RECS(WS-STEP-IDX)
                   MOVE 'D' TO WS-STEP-STATUS(WS-STEP-IDX)
               WHEN OTHER
                   MOVE 'F' TO WS-STEP-STATUS(WS-STEP-IDX)
                   MOVE 'Y' TO WS-ABORT-FLAG
           END-EVALUATE.
       3000-CYCLE-SUMMARY.
           IF CYCLE-ABORTED
               MOVE 'ABORTED   ' TO WS-CYCLE-STATUS
           ELSE
               MOVE 'COMPLETE  ' TO WS-CYCLE-STATUS
           END-IF
           DISPLAY 'NIGHTLY BATCH CYCLE REPORT'
           DISPLAY '=========================='
           DISPLAY 'DATE:    ' WS-CYCLE-DATE
           DISPLAY 'STATUS:  ' WS-CYCLE-STATUS
           PERFORM VARYING WS-STEP-IDX FROM 1 BY 1
               UNTIL WS-STEP-IDX > WS-TOTAL-STEPS
               STRING WS-STEP-NAME(WS-STEP-IDX)
                   DELIMITED BY '  '
                   ' [' DELIMITED BY SIZE
                   WS-STEP-STATUS(WS-STEP-IDX)
                   DELIMITED BY SIZE
                   '] RECS=' DELIMITED BY SIZE
                   WS-STEP-RECS(WS-STEP-IDX)
                   DELIMITED BY SIZE
                   INTO WS-REPORT-LINE
               END-STRING
               DISPLAY '  ' WS-REPORT-LINE
           END-PERFORM
           DISPLAY 'TOTAL RECORDS: ' WS-TOTAL-RECORDS
           DISPLAY 'INTEREST:      $' WS-INTEREST-AMT
           DISPLAY 'FEES:          $' WS-FEE-AMT
           DISPLAY 'SWEEPS:        $' WS-SWEEP-AMT.
