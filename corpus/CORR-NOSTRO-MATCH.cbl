       IDENTIFICATION DIVISION.
       PROGRAM-ID. CORR-NOSTRO-MATCH.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT INTERNAL-FILE ASSIGN TO 'INTFILE'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-INT-STATUS.
           SELECT EXTERNAL-FILE ASSIGN TO 'EXTFILE'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-EXT-STATUS.
           SELECT BREAK-FILE ASSIGN TO 'BREAKOUT'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-BRK-STATUS.

       DATA DIVISION.
       FILE SECTION.

       FD INTERNAL-FILE.
       01 INT-RECORD.
           05 INT-ACCT-ID             PIC X(12).
           05 INT-TXN-REF             PIC X(16).
           05 INT-AMOUNT              PIC S9(13)V99 COMP-3.
           05 INT-CURRENCY            PIC X(3).
           05 INT-VALUE-DATE          PIC 9(8).
           05 INT-MATCHED-FLAG        PIC X VALUE 'N'.
               88 INT-MATCHED         VALUE 'Y'.

       FD EXTERNAL-FILE.
       01 EXT-RECORD.
           05 EXT-STMT-REF            PIC X(16).
           05 EXT-AMOUNT              PIC S9(13)V99 COMP-3.
           05 EXT-CURRENCY            PIC X(3).
           05 EXT-VALUE-DATE          PIC 9(8).
           05 EXT-NARRATIVE           PIC X(35).

       FD BREAK-FILE.
       01 BREAK-RECORD.
           05 BRK-TYPE                PIC X(1).
               88 BRK-INTERNAL        VALUE 'I'.
               88 BRK-EXTERNAL        VALUE 'E'.
               88 BRK-AMOUNT-DIFF     VALUE 'D'.
           05 BRK-REF                 PIC X(16).
           05 BRK-INT-AMT             PIC S9(13)V99 COMP-3.
           05 BRK-EXT-AMT             PIC S9(13)V99 COMP-3.
           05 BRK-VARIANCE            PIC S9(13)V99 COMP-3.
           05 BRK-DESCRIPTION         PIC X(40).

       WORKING-STORAGE SECTION.

       01 WS-INT-STATUS               PIC X(2).
       01 WS-EXT-STATUS               PIC X(2).
       01 WS-BRK-STATUS               PIC X(2).

       01 WS-INT-EOF                  PIC X VALUE 'N'.
           88 WS-INT-DONE             VALUE 'Y'.
       01 WS-EXT-EOF                  PIC X VALUE 'N'.
           88 WS-EXT-DONE             VALUE 'Y'.

       01 WS-EXT-TABLE.
           05 WS-EXT OCCURS 50.
               10 WS-ET-REF           PIC X(16).
               10 WS-ET-AMT           PIC S9(13)V99 COMP-3.
               10 WS-ET-CCY           PIC X(3).
               10 WS-ET-DATE          PIC 9(8).
               10 WS-ET-MATCHED       PIC X VALUE 'N'.
       01 WS-EXT-COUNT                PIC 9(2) VALUE 0.
       01 WS-EXT-IDX                  PIC 9(2).

       01 WS-TOLERANCE                PIC S9(5)V99 COMP-3
           VALUE 0.01.
       01 WS-VARIANCE                 PIC S9(13)V99 COMP-3.
       01 WS-ABS-VARIANCE             PIC S9(13)V99 COMP-3.
       01 WS-MATCH-FOUND              PIC X VALUE 'N'.
           88 WS-IS-MATCHED           VALUE 'Y'.

       01 WS-COUNTERS.
           05 WS-INT-READ             PIC S9(7) COMP-3 VALUE 0.
           05 WS-EXT-READ             PIC S9(7) COMP-3 VALUE 0.
           05 WS-MATCHED-COUNT        PIC S9(7) COMP-3 VALUE 0.
           05 WS-BREAK-COUNT          PIC S9(7) COMP-3 VALUE 0.

       01 WS-DESC-BUF                 PIC X(40).
       01 WS-DESC-PTR                 PIC 9(3).
       01 WS-DIGIT-TALLY              PIC 9(3).

       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-LOAD-EXTERNAL
           PERFORM 1100-OPEN-REMAINING
           PERFORM 1200-READ-INTERNAL
           PERFORM 2000-MATCH-RECORDS
               UNTIL WS-INT-DONE
           PERFORM 3000-REPORT-UNMATCHED-EXT
           PERFORM 4000-CLOSE-ALL
           PERFORM 5000-DISPLAY-SUMMARY
           STOP RUN.

       1000-LOAD-EXTERNAL.
           OPEN INPUT EXTERNAL-FILE
           MOVE 'N' TO WS-EXT-EOF
           MOVE 0 TO WS-EXT-COUNT
           READ EXTERNAL-FILE
               AT END MOVE 'Y' TO WS-EXT-EOF
           END-READ
           PERFORM UNTIL WS-EXT-DONE
               OR WS-EXT-COUNT >= 50
               ADD 1 TO WS-EXT-COUNT
               ADD 1 TO WS-EXT-READ
               MOVE EXT-STMT-REF TO
                   WS-ET-REF(WS-EXT-COUNT)
               MOVE EXT-AMOUNT TO
                   WS-ET-AMT(WS-EXT-COUNT)
               MOVE EXT-CURRENCY TO
                   WS-ET-CCY(WS-EXT-COUNT)
               MOVE EXT-VALUE-DATE TO
                   WS-ET-DATE(WS-EXT-COUNT)
               MOVE 'N' TO WS-ET-MATCHED(WS-EXT-COUNT)
               READ EXTERNAL-FILE
                   AT END MOVE 'Y' TO WS-EXT-EOF
               END-READ
           END-PERFORM
           CLOSE EXTERNAL-FILE.

       1100-OPEN-REMAINING.
           OPEN INPUT INTERNAL-FILE
           OPEN OUTPUT BREAK-FILE
           MOVE 'N' TO WS-INT-EOF.

       1200-READ-INTERNAL.
           READ INTERNAL-FILE
               AT END MOVE 'Y' TO WS-INT-EOF
           END-READ.

       2000-MATCH-RECORDS.
           ADD 1 TO WS-INT-READ
           MOVE 'N' TO WS-MATCH-FOUND
           PERFORM VARYING WS-EXT-IDX FROM 1 BY 1
               UNTIL WS-EXT-IDX > WS-EXT-COUNT
               OR WS-IS-MATCHED
               IF WS-ET-MATCHED(WS-EXT-IDX) = 'N'
                   IF INT-CURRENCY =
                       WS-ET-CCY(WS-EXT-IDX)
                       COMPUTE WS-VARIANCE =
                           INT-AMOUNT -
                           WS-ET-AMT(WS-EXT-IDX)
                       IF WS-VARIANCE < 0
                           COMPUTE WS-ABS-VARIANCE =
                               0 - WS-VARIANCE
                       ELSE
                           MOVE WS-VARIANCE TO
                               WS-ABS-VARIANCE
                       END-IF
                       IF WS-ABS-VARIANCE <= WS-TOLERANCE
                           MOVE 'Y' TO WS-MATCH-FOUND
                           MOVE 'Y' TO
                               WS-ET-MATCHED(WS-EXT-IDX)
                           ADD 1 TO WS-MATCHED-COUNT
                       ELSE
                           IF INT-VALUE-DATE =
                               WS-ET-DATE(WS-EXT-IDX)
                               PERFORM 2100-REPORT-AMT-DIFF
                           END-IF
                       END-IF
                   END-IF
               END-IF
           END-PERFORM
           IF NOT WS-IS-MATCHED
               PERFORM 2200-REPORT-INT-BREAK
           END-IF
           READ INTERNAL-FILE
               AT END MOVE 'Y' TO WS-INT-EOF
           END-READ.

       2100-REPORT-AMT-DIFF.
           MOVE SPACES TO WS-DESC-BUF
           MOVE 1 TO WS-DESC-PTR
           STRING 'AMOUNT MISMATCH ON DATE '
               INT-VALUE-DATE
               DELIMITED BY SIZE
               INTO WS-DESC-BUF
               WITH POINTER WS-DESC-PTR
           END-STRING
           MOVE 'D' TO BRK-TYPE
           MOVE INT-TXN-REF TO BRK-REF
           MOVE INT-AMOUNT TO BRK-INT-AMT
           MOVE WS-ET-AMT(WS-EXT-IDX) TO BRK-EXT-AMT
           MOVE WS-VARIANCE TO BRK-VARIANCE
           MOVE WS-DESC-BUF TO BRK-DESCRIPTION
           WRITE BREAK-RECORD
           ADD 1 TO WS-BREAK-COUNT.

       2200-REPORT-INT-BREAK.
           MOVE 'I' TO BRK-TYPE
           MOVE INT-TXN-REF TO BRK-REF
           MOVE INT-AMOUNT TO BRK-INT-AMT
           MOVE 0 TO BRK-EXT-AMT
           MOVE INT-AMOUNT TO BRK-VARIANCE
           MOVE 'UNMATCHED INTERNAL ITEM'
               TO BRK-DESCRIPTION
           WRITE BREAK-RECORD
           ADD 1 TO WS-BREAK-COUNT.

       3000-REPORT-UNMATCHED-EXT.
           PERFORM VARYING WS-EXT-IDX FROM 1 BY 1
               UNTIL WS-EXT-IDX > WS-EXT-COUNT
               IF WS-ET-MATCHED(WS-EXT-IDX) = 'N'
                   MOVE 'E' TO BRK-TYPE
                   MOVE WS-ET-REF(WS-EXT-IDX) TO BRK-REF
                   MOVE 0 TO BRK-INT-AMT
                   MOVE WS-ET-AMT(WS-EXT-IDX) TO BRK-EXT-AMT
                   MOVE WS-ET-AMT(WS-EXT-IDX) TO
                       BRK-VARIANCE
                   MOVE 'UNMATCHED EXTERNAL ITEM'
                       TO BRK-DESCRIPTION
                   WRITE BREAK-RECORD
                   ADD 1 TO WS-BREAK-COUNT
               END-IF
           END-PERFORM.

       4000-CLOSE-ALL.
           CLOSE INTERNAL-FILE
           CLOSE BREAK-FILE.

       5000-DISPLAY-SUMMARY.
           MOVE 0 TO WS-DIGIT-TALLY
           INSPECT WS-DESC-BUF
               TALLYING WS-DIGIT-TALLY FOR ALL '0'
           DISPLAY 'NOSTRO RECONCILIATION COMPLETE'
           DISPLAY 'INTERNAL ITEMS:   ' WS-INT-READ
           DISPLAY 'EXTERNAL ITEMS:   ' WS-EXT-READ
           DISPLAY 'MATCHED:          ' WS-MATCHED-COUNT
           DISPLAY 'BREAKS REPORTED:  ' WS-BREAK-COUNT.
