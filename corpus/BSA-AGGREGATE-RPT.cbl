       IDENTIFICATION DIVISION.
       PROGRAM-ID. BSA-AGGREGATE-RPT.
      *================================================================*
      * BSA AGGREGATION REPORT GENERATOR                               *
      * Aggregates multi-day cash transactions per customer for BSA    *
      * structuring detection. Flags patterns below CTR threshold.     *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CUSTOMER.
           05 WS-CUST-ID            PIC X(10).
           05 WS-CUST-NAME          PIC X(30).
           05 WS-CUST-TIN           PIC X(9).
           05 WS-CUST-RISK-TIER     PIC X(1).
               88 WS-TIER-LOW       VALUE 'L'.
               88 WS-TIER-MED       VALUE 'M'.
               88 WS-TIER-HIGH      VALUE 'H'.
       01 WS-TXN-DAYS.
           05 WS-DAY-ENTRY OCCURS 7.
               10 WS-DAY-DATE       PIC 9(8).
               10 WS-DAY-CASH-IN    PIC S9(9)V99 COMP-3.
               10 WS-DAY-CASH-OUT   PIC S9(9)V99 COMP-3.
               10 WS-DAY-TXN-CNT    PIC S9(3) COMP-3.
               10 WS-DAY-FLAG       PIC X VALUE 'N'.
                   88 WS-DAY-ALERT  VALUE 'Y'.
       01 WS-CTR-THRESHOLD          PIC S9(7)V99 COMP-3
           VALUE 10000.00.
       01 WS-STRUCT-THRESHOLD       PIC S9(7)V99 COMP-3
           VALUE 8000.00.
       01 WS-ANALYSIS.
           05 WS-TOTAL-CASH-IN      PIC S9(11)V99 COMP-3.
           05 WS-TOTAL-CASH-OUT     PIC S9(11)V99 COMP-3.
           05 WS-TOTAL-TXN          PIC S9(5) COMP-3.
           05 WS-ALERT-DAYS         PIC S9(2) COMP-3.
           05 WS-NEAR-CTR-DAYS      PIC S9(2) COMP-3.
           05 WS-ABOVE-CTR-DAYS     PIC S9(2) COMP-3.
           05 WS-STRUCT-FLAG        PIC X VALUE 'N'.
               88 WS-IS-STRUCTURED  VALUE 'Y'.
           05 WS-STRUCT-PATTERN     PIC X(30).
       01 WS-IDX                    PIC S9(2) COMP-3.
       01 WS-CONSEC-NEAR            PIC S9(2) COMP-3.
       01 WS-DAY-TOTAL              PIC S9(9)V99 COMP-3.
       01 WS-REPORT-LINE            PIC X(80).
       01 WS-FILING-ACTION          PIC X(20).
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-TRANSACTIONS
           PERFORM 3000-ANALYZE-DAYS
           PERFORM 4000-DETECT-STRUCTURING
           PERFORM 5000-DETERMINE-FILING
           PERFORM 6000-DISPLAY-REPORT
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'CUST002345' TO WS-CUST-ID
           MOVE 'CHEN WEI IMPORT LLC' TO WS-CUST-NAME
           MOVE '123456789' TO WS-CUST-TIN
           MOVE 'M' TO WS-CUST-RISK-TIER
           MOVE 0 TO WS-TOTAL-CASH-IN
           MOVE 0 TO WS-TOTAL-CASH-OUT
           MOVE 0 TO WS-TOTAL-TXN
           MOVE 0 TO WS-ALERT-DAYS
           MOVE 0 TO WS-NEAR-CTR-DAYS
           MOVE 0 TO WS-ABOVE-CTR-DAYS
           MOVE 0 TO WS-CONSEC-NEAR
           MOVE SPACES TO WS-STRUCT-PATTERN.
       2000-LOAD-TRANSACTIONS.
           MOVE 20260315 TO WS-DAY-DATE(1)
           MOVE 9500.00 TO WS-DAY-CASH-IN(1)
           MOVE 0 TO WS-DAY-CASH-OUT(1)
           MOVE 3 TO WS-DAY-TXN-CNT(1)
           MOVE 20260316 TO WS-DAY-DATE(2)
           MOVE 9200.00 TO WS-DAY-CASH-IN(2)
           MOVE 500.00 TO WS-DAY-CASH-OUT(2)
           MOVE 2 TO WS-DAY-TXN-CNT(2)
           MOVE 20260317 TO WS-DAY-DATE(3)
           MOVE 9800.00 TO WS-DAY-CASH-IN(3)
           MOVE 0 TO WS-DAY-CASH-OUT(3)
           MOVE 4 TO WS-DAY-TXN-CNT(3)
           MOVE 20260318 TO WS-DAY-DATE(4)
           MOVE 8500.00 TO WS-DAY-CASH-IN(4)
           MOVE 200.00 TO WS-DAY-CASH-OUT(4)
           MOVE 2 TO WS-DAY-TXN-CNT(4)
           MOVE 20260319 TO WS-DAY-DATE(5)
           MOVE 0 TO WS-DAY-CASH-IN(5)
           MOVE 0 TO WS-DAY-CASH-OUT(5)
           MOVE 0 TO WS-DAY-TXN-CNT(5)
           MOVE 20260320 TO WS-DAY-DATE(6)
           MOVE 9700.00 TO WS-DAY-CASH-IN(6)
           MOVE 0 TO WS-DAY-CASH-OUT(6)
           MOVE 3 TO WS-DAY-TXN-CNT(6)
           MOVE 20260321 TO WS-DAY-DATE(7)
           MOVE 12000.00 TO WS-DAY-CASH-IN(7)
           MOVE 1500.00 TO WS-DAY-CASH-OUT(7)
           MOVE 5 TO WS-DAY-TXN-CNT(7).
       3000-ANALYZE-DAYS.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > 7
               COMPUTE WS-DAY-TOTAL =
                   WS-DAY-CASH-IN(WS-IDX) +
                   WS-DAY-CASH-OUT(WS-IDX)
               ADD WS-DAY-CASH-IN(WS-IDX) TO
                   WS-TOTAL-CASH-IN
               ADD WS-DAY-CASH-OUT(WS-IDX) TO
                   WS-TOTAL-CASH-OUT
               ADD WS-DAY-TXN-CNT(WS-IDX) TO WS-TOTAL-TXN
               IF WS-DAY-TOTAL > WS-CTR-THRESHOLD
                   MOVE 'Y' TO WS-DAY-FLAG(WS-IDX)
                   ADD 1 TO WS-ABOVE-CTR-DAYS
                   ADD 1 TO WS-ALERT-DAYS
               ELSE
                   IF WS-DAY-CASH-IN(WS-IDX) >=
                       WS-STRUCT-THRESHOLD
                       MOVE 'Y' TO WS-DAY-FLAG(WS-IDX)
                       ADD 1 TO WS-NEAR-CTR-DAYS
                       ADD 1 TO WS-ALERT-DAYS
                   END-IF
               END-IF
           END-PERFORM.
       4000-DETECT-STRUCTURING.
           MOVE 0 TO WS-CONSEC-NEAR
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > 7
               IF WS-DAY-CASH-IN(WS-IDX) >=
                   WS-STRUCT-THRESHOLD
                   AND WS-DAY-CASH-IN(WS-IDX) <
                   WS-CTR-THRESHOLD
                   ADD 1 TO WS-CONSEC-NEAR
               ELSE
                   IF WS-DAY-CASH-IN(WS-IDX) > 0
                       MOVE 0 TO WS-CONSEC-NEAR
                   END-IF
               END-IF
               IF WS-CONSEC-NEAR >= 3
                   MOVE 'Y' TO WS-STRUCT-FLAG
               END-IF
           END-PERFORM
           IF WS-IS-STRUCTURED
               MOVE 'CONSECUTIVE NEAR-CTR DEPOSITS'
                   TO WS-STRUCT-PATTERN
           ELSE
               IF WS-NEAR-CTR-DAYS >= 4
                   MOVE 'Y' TO WS-STRUCT-FLAG
                   MOVE 'FREQUENT NEAR-CTR DEPOSITS'
                       TO WS-STRUCT-PATTERN
               END-IF
           END-IF.
       5000-DETERMINE-FILING.
           EVALUATE TRUE
               WHEN WS-IS-STRUCTURED
                   MOVE 'FILE SAR - PRIORITY' TO
                       WS-FILING-ACTION
               WHEN WS-ABOVE-CTR-DAYS > 0
                   MOVE 'FILE CTR' TO WS-FILING-ACTION
               WHEN WS-ALERT-DAYS >= 3
                   MOVE 'REVIEW FOR SAR' TO
                       WS-FILING-ACTION
               WHEN OTHER
                   MOVE 'MONITOR ONLY' TO
                       WS-FILING-ACTION
           END-EVALUATE
           IF WS-TIER-HIGH
               IF WS-ALERT-DAYS > 0
                   MOVE 'FILE SAR - PRIORITY' TO
                       WS-FILING-ACTION
               END-IF
           END-IF.
       6000-DISPLAY-REPORT.
           DISPLAY '========================================='
           DISPLAY 'BSA AGGREGATION REPORT'
           DISPLAY '========================================='
           DISPLAY 'CUSTOMER:        ' WS-CUST-NAME
           DISPLAY 'ID:              ' WS-CUST-ID
           DISPLAY 'TIN:             ' WS-CUST-TIN
           DISPLAY 'RISK TIER:       ' WS-CUST-RISK-TIER
           DISPLAY '----- DAILY BREAKDOWN -----'
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > 7
               MOVE SPACES TO WS-REPORT-LINE
               STRING WS-DAY-DATE(WS-IDX) DELIMITED BY SIZE
                   ' IN: ' DELIMITED BY SIZE
                   WS-DAY-CASH-IN(WS-IDX) DELIMITED BY SIZE
                   ' OUT: ' DELIMITED BY SIZE
                   WS-DAY-CASH-OUT(WS-IDX) DELIMITED BY SIZE
                   INTO WS-REPORT-LINE
               DISPLAY WS-REPORT-LINE
               IF WS-DAY-ALERT(WS-IDX)
                   DISPLAY '  *** ALERT'
               END-IF
           END-PERFORM
           DISPLAY '----- ANALYSIS -----'
           DISPLAY 'TOTAL CASH IN:   ' WS-TOTAL-CASH-IN
           DISPLAY 'TOTAL CASH OUT:  ' WS-TOTAL-CASH-OUT
           DISPLAY 'TOTAL TXNS:      ' WS-TOTAL-TXN
           DISPLAY 'ALERT DAYS:      ' WS-ALERT-DAYS
           DISPLAY 'ABOVE CTR:       ' WS-ABOVE-CTR-DAYS
           DISPLAY 'NEAR CTR:        ' WS-NEAR-CTR-DAYS
           IF WS-IS-STRUCTURED
               DISPLAY 'STRUCTURING:     YES'
               DISPLAY 'PATTERN:         ' WS-STRUCT-PATTERN
           END-IF
           DISPLAY 'ACTION:          ' WS-FILING-ACTION
           DISPLAY '========================================='.
