       IDENTIFICATION DIVISION.
       PROGRAM-ID. REG-REPORT-BUILDER.
      *================================================================*
      * REGULATORY REPORTING BUILDER                                   *
      * Aggregates transaction data into regulatory report format,     *
      * computes summary statistics, flags threshold breaches,         *
      * builds formatted output lines using STRING operations.         *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-REPORT-HEADER.
           05 WS-RPT-ID             PIC X(10).
           05 WS-RPT-DATE           PIC 9(8).
           05 WS-RPT-TYPE           PIC X(3).
               88 WS-RPT-CTR        VALUE 'CTR'.
               88 WS-RPT-SAR        VALUE 'SAR'.
               88 WS-RPT-BSA        VALUE 'BSA'.
           05 WS-FILING-INST        PIC X(20).
           05 WS-INST-RSSD          PIC X(10).
       01 WS-ACCT-TABLE.
           05 WS-ACCT-ENTRY OCCURS 10.
               10 WS-ACT-NUM        PIC X(12).
               10 WS-ACT-NAME       PIC X(30).
               10 WS-ACT-TXN-CNT    PIC S9(5) COMP-3.
               10 WS-ACT-CASH-IN    PIC S9(11)V99 COMP-3.
               10 WS-ACT-CASH-OUT   PIC S9(11)V99 COMP-3.
               10 WS-ACT-WIRE-IN    PIC S9(11)V99 COMP-3.
               10 WS-ACT-WIRE-OUT   PIC S9(11)V99 COMP-3.
               10 WS-ACT-FLAG       PIC X VALUE 'N'.
                   88 WS-ACT-FLAGGED VALUE 'Y'.
       01 WS-ACCT-COUNT             PIC S9(3) COMP-3.
       01 WS-THRESHOLDS.
           05 WS-CTR-LIMIT          PIC S9(11)V99 COMP-3
               VALUE 10000.00.
           05 WS-SAR-VELOCITY       PIC S9(5) COMP-3
               VALUE 25.
           05 WS-WIRE-LIMIT         PIC S9(11)V99 COMP-3
               VALUE 50000.00.
       01 WS-SUMMARY.
           05 WS-TOTAL-CASH-IN      PIC S9(13)V99 COMP-3.
           05 WS-TOTAL-CASH-OUT     PIC S9(13)V99 COMP-3.
           05 WS-TOTAL-WIRE-IN      PIC S9(13)V99 COMP-3.
           05 WS-TOTAL-WIRE-OUT     PIC S9(13)V99 COMP-3.
           05 WS-FLAGGED-COUNT      PIC S9(3) COMP-3.
           05 WS-TOTAL-TXN          PIC S9(7) COMP-3.
       01 WS-OUTPUT-LINE            PIC X(132).
       01 WS-LINE-POS               PIC S9(3) COMP-3.
       01 WS-IDX                    PIC S9(3) COMP-3.
       01 WS-ACT-TOTAL              PIC S9(11)V99 COMP-3.
       01 WS-BREACH-TYPE            PIC X(15).
       01 WS-FORMATTED-AMT          PIC Z(10)9.99.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-DATA
           PERFORM 3000-SCREEN-ACCOUNTS
           PERFORM 4000-AGGREGATE-TOTALS
           PERFORM 5000-BUILD-REPORT-LINES
           PERFORM 6000-DISPLAY-REPORT
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'RPT2026031' TO WS-RPT-ID
           MOVE 20260315 TO WS-RPT-DATE
           MOVE 'CTR' TO WS-RPT-TYPE
           MOVE 'FIRST NATIONAL BANK' TO WS-FILING-INST
           MOVE 'RSSD001234' TO WS-INST-RSSD
           MOVE 0 TO WS-TOTAL-CASH-IN
           MOVE 0 TO WS-TOTAL-CASH-OUT
           MOVE 0 TO WS-TOTAL-WIRE-IN
           MOVE 0 TO WS-TOTAL-WIRE-OUT
           MOVE 0 TO WS-FLAGGED-COUNT
           MOVE 0 TO WS-TOTAL-TXN.
       2000-LOAD-DATA.
           MOVE 5 TO WS-ACCT-COUNT
           MOVE 'ACCT00000001' TO WS-ACT-NUM(1)
           MOVE 'JOHNSON ENTERPRISES LLC' TO WS-ACT-NAME(1)
           MOVE 45 TO WS-ACT-TXN-CNT(1)
           MOVE 12500.00 TO WS-ACT-CASH-IN(1)
           MOVE 8200.00 TO WS-ACT-CASH-OUT(1)
           MOVE 55000.00 TO WS-ACT-WIRE-IN(1)
           MOVE 23000.00 TO WS-ACT-WIRE-OUT(1)
           MOVE 'N' TO WS-ACT-FLAG(1)
           MOVE 'ACCT00000002' TO WS-ACT-NUM(2)
           MOVE 'SMITH FAMILY TRUST' TO WS-ACT-NAME(2)
           MOVE 12 TO WS-ACT-TXN-CNT(2)
           MOVE 3200.00 TO WS-ACT-CASH-IN(2)
           MOVE 1500.00 TO WS-ACT-CASH-OUT(2)
           MOVE 0 TO WS-ACT-WIRE-IN(2)
           MOVE 0 TO WS-ACT-WIRE-OUT(2)
           MOVE 'N' TO WS-ACT-FLAG(2)
           MOVE 'ACCT00000003' TO WS-ACT-NUM(3)
           MOVE 'GLOBAL IMPORT EXPORT CO' TO WS-ACT-NAME(3)
           MOVE 78 TO WS-ACT-TXN-CNT(3)
           MOVE 9800.00 TO WS-ACT-CASH-IN(3)
           MOVE 9700.00 TO WS-ACT-CASH-OUT(3)
           MOVE 120000.00 TO WS-ACT-WIRE-IN(3)
           MOVE 115000.00 TO WS-ACT-WIRE-OUT(3)
           MOVE 'N' TO WS-ACT-FLAG(3)
           MOVE 'ACCT00000004' TO WS-ACT-NUM(4)
           MOVE 'MARIA GARCIA' TO WS-ACT-NAME(4)
           MOVE 5 TO WS-ACT-TXN-CNT(4)
           MOVE 500.00 TO WS-ACT-CASH-IN(4)
           MOVE 200.00 TO WS-ACT-CASH-OUT(4)
           MOVE 0 TO WS-ACT-WIRE-IN(4)
           MOVE 0 TO WS-ACT-WIRE-OUT(4)
           MOVE 'N' TO WS-ACT-FLAG(4)
           MOVE 'ACCT00000005' TO WS-ACT-NUM(5)
           MOVE 'PACIFIC RIM TRADING INC' TO WS-ACT-NAME(5)
           MOVE 30 TO WS-ACT-TXN-CNT(5)
           MOVE 9990.00 TO WS-ACT-CASH-IN(5)
           MOVE 9950.00 TO WS-ACT-CASH-OUT(5)
           MOVE 75000.00 TO WS-ACT-WIRE-IN(5)
           MOVE 74500.00 TO WS-ACT-WIRE-OUT(5)
           MOVE 'N' TO WS-ACT-FLAG(5).
       3000-SCREEN-ACCOUNTS.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-ACCT-COUNT
               PERFORM 3100-CHECK-THRESHOLDS
           END-PERFORM.
       3100-CHECK-THRESHOLDS.
           IF WS-ACT-CASH-IN(WS-IDX) > WS-CTR-LIMIT
               MOVE 'Y' TO WS-ACT-FLAG(WS-IDX)
           END-IF
           IF WS-ACT-CASH-OUT(WS-IDX) > WS-CTR-LIMIT
               MOVE 'Y' TO WS-ACT-FLAG(WS-IDX)
           END-IF
           IF WS-ACT-TXN-CNT(WS-IDX) > WS-SAR-VELOCITY
               MOVE 'Y' TO WS-ACT-FLAG(WS-IDX)
           END-IF
           COMPUTE WS-ACT-TOTAL =
               WS-ACT-WIRE-IN(WS-IDX) +
               WS-ACT-WIRE-OUT(WS-IDX)
           IF WS-ACT-TOTAL > WS-WIRE-LIMIT
               MOVE 'Y' TO WS-ACT-FLAG(WS-IDX)
           END-IF
           COMPUTE WS-ACT-TOTAL =
               WS-ACT-CASH-IN(WS-IDX) +
               WS-ACT-CASH-OUT(WS-IDX)
           IF WS-ACT-TOTAL > 0
               IF WS-ACT-CASH-IN(WS-IDX) > 9000
                   IF WS-ACT-CASH-IN(WS-IDX) < WS-CTR-LIMIT
                       MOVE 'Y' TO WS-ACT-FLAG(WS-IDX)
                   END-IF
               END-IF
           END-IF.
       4000-AGGREGATE-TOTALS.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-ACCT-COUNT
               ADD WS-ACT-CASH-IN(WS-IDX) TO
                   WS-TOTAL-CASH-IN
               ADD WS-ACT-CASH-OUT(WS-IDX) TO
                   WS-TOTAL-CASH-OUT
               ADD WS-ACT-WIRE-IN(WS-IDX) TO
                   WS-TOTAL-WIRE-IN
               ADD WS-ACT-WIRE-OUT(WS-IDX) TO
                   WS-TOTAL-WIRE-OUT
               ADD WS-ACT-TXN-CNT(WS-IDX) TO WS-TOTAL-TXN
               IF WS-ACT-FLAGGED(WS-IDX)
                   ADD 1 TO WS-FLAGGED-COUNT
               END-IF
           END-PERFORM.
       5000-BUILD-REPORT-LINES.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-ACCT-COUNT
               IF WS-ACT-FLAGGED(WS-IDX)
                   MOVE SPACES TO WS-OUTPUT-LINE
                   STRING WS-ACT-NUM(WS-IDX)
                       DELIMITED BY SIZE
                       ' | ' DELIMITED BY SIZE
                       WS-ACT-NAME(WS-IDX)
                       DELIMITED BY SIZE
                       ' | FLAGGED'
                       DELIMITED BY SIZE
                       INTO WS-OUTPUT-LINE
                   DISPLAY WS-OUTPUT-LINE
               END-IF
           END-PERFORM.
       6000-DISPLAY-REPORT.
           DISPLAY '========================================='
           DISPLAY 'REGULATORY REPORT'
           DISPLAY '========================================='
           DISPLAY 'REPORT ID:       ' WS-RPT-ID
           DISPLAY 'DATE:            ' WS-RPT-DATE
           DISPLAY 'TYPE:            ' WS-RPT-TYPE
           DISPLAY 'INSTITUTION:     ' WS-FILING-INST
           DISPLAY 'RSSD:            ' WS-INST-RSSD
           DISPLAY '-----------------------------------------'
           DISPLAY 'ACCOUNTS:        ' WS-ACCT-COUNT
           DISPLAY 'FLAGGED:         ' WS-FLAGGED-COUNT
           DISPLAY 'TOTAL TXNS:      ' WS-TOTAL-TXN
           DISPLAY 'CASH IN:         ' WS-TOTAL-CASH-IN
           DISPLAY 'CASH OUT:        ' WS-TOTAL-CASH-OUT
           DISPLAY 'WIRE IN:         ' WS-TOTAL-WIRE-IN
           DISPLAY 'WIRE OUT:        ' WS-TOTAL-WIRE-OUT
           DISPLAY '========================================='.
