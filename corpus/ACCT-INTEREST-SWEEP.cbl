       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCT-INTEREST-SWEEP.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-SWEEP-TABLE.
           05 WS-SWEEP-ENTRY OCCURS 20 TIMES.
               10 WS-SRC-ACCT         PIC X(12).
               10 WS-DST-ACCT         PIC X(12).
               10 WS-THRESHOLD        PIC S9(9)V99 COMP-3.
               10 WS-SRC-BALANCE      PIC S9(11)V99 COMP-3.
               10 WS-SWEEP-AMT        PIC S9(9)V99 COMP-3.
               10 WS-STATUS           PIC X(8).
       01 WS-ENTRY-COUNT              PIC 99 VALUE 20.
       01 WS-IDX                      PIC 99.
       01 WS-EXCESS                   PIC S9(11)V99 COMP-3.
       01 WS-TOTAL-SWEPT              PIC S9(11)V99 COMP-3.
       01 WS-SWEEP-COUNT              PIC 9(3).
       01 WS-SKIP-COUNT               PIC 9(3).
       01 WS-ERROR-COUNT              PIC 9(3).
       01 WS-MIN-SWEEP                PIC S9(5)V99 COMP-3
           VALUE 100.00.
       01 WS-PROCESS-DATE             PIC 9(8).
       01 WS-RPT-LINE                 PIC X(80).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-PROCESS-SWEEPS
           PERFORM 3000-SUMMARY
           STOP RUN.
       1000-INIT.
           MOVE 0 TO WS-TOTAL-SWEPT
           MOVE 0 TO WS-SWEEP-COUNT
           MOVE 0 TO WS-SKIP-COUNT
           MOVE 0 TO WS-ERROR-COUNT
           ACCEPT WS-PROCESS-DATE FROM DATE YYYYMMDD.
       2000-PROCESS-SWEEPS.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-ENTRY-COUNT
               PERFORM 2100-EVALUATE-SWEEP
           END-PERFORM.
       2100-EVALUATE-SWEEP.
           COMPUTE WS-EXCESS =
               WS-SRC-BALANCE(WS-IDX) -
               WS-THRESHOLD(WS-IDX)
           IF WS-EXCESS > WS-MIN-SWEEP
               MOVE WS-EXCESS TO WS-SWEEP-AMT(WS-IDX)
               SUBTRACT WS-EXCESS FROM
                   WS-SRC-BALANCE(WS-IDX)
               MOVE 'SWEPT   ' TO WS-STATUS(WS-IDX)
               ADD WS-EXCESS TO WS-TOTAL-SWEPT
               ADD 1 TO WS-SWEEP-COUNT
           ELSE
               IF WS-SRC-BALANCE(WS-IDX) < 0
                   MOVE 'ERROR   ' TO WS-STATUS(WS-IDX)
                   ADD 1 TO WS-ERROR-COUNT
               ELSE
                   MOVE 'SKIPPED ' TO WS-STATUS(WS-IDX)
                   MOVE 0 TO WS-SWEEP-AMT(WS-IDX)
                   ADD 1 TO WS-SKIP-COUNT
               END-IF
           END-IF.
       3000-SUMMARY.
           DISPLAY 'INTEREST SWEEP BATCH REPORT'
           DISPLAY '==========================='
           DISPLAY 'DATE: ' WS-PROCESS-DATE
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-ENTRY-COUNT
               IF WS-STATUS(WS-IDX) = 'SWEPT   '
                   STRING WS-SRC-ACCT(WS-IDX)
                       DELIMITED BY ' '
                       ' -> ' DELIMITED BY SIZE
                       WS-DST-ACCT(WS-IDX)
                       DELIMITED BY ' '
                       ' $' DELIMITED BY SIZE
                       WS-SWEEP-AMT(WS-IDX)
                       DELIMITED BY SIZE
                       INTO WS-RPT-LINE
                   END-STRING
                   DISPLAY WS-RPT-LINE
               END-IF
           END-PERFORM
           DISPLAY 'SWEPT:   ' WS-SWEEP-COUNT
           DISPLAY 'SKIPPED: ' WS-SKIP-COUNT
           DISPLAY 'ERRORS:  ' WS-ERROR-COUNT
           DISPLAY 'TOTAL:   $' WS-TOTAL-SWEPT.
