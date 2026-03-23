       IDENTIFICATION DIVISION.
       PROGRAM-ID. TRUST-ACCT-VALUATION.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT HOLDING-FILE ASSIGN TO 'HOLDFILE'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-HOLD-STATUS.
           SELECT VALUATION-FILE ASSIGN TO 'VALFILE'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-VAL-STATUS.

       DATA DIVISION.
       FILE SECTION.

       FD HOLDING-FILE.
       01 HOLD-RECORD.
           05 HLD-TRUST-ID             PIC X(12).
           05 HLD-ASSET-TYPE           PIC X(2).
               88 HLD-EQUITY           VALUE 'EQ'.
               88 HLD-FIXED-INCOME     VALUE 'FI'.
               88 HLD-CASH             VALUE 'CA'.
               88 HLD-REAL-ESTATE      VALUE 'RE'.
               88 HLD-ALTERNATIVE      VALUE 'AL'.
           05 HLD-CUSIP                PIC X(9).
           05 HLD-QUANTITY             PIC S9(9)V99 COMP-3.
           05 HLD-COST-BASIS           PIC S9(11)V99 COMP-3.
           05 HLD-MARKET-PRICE         PIC S9(7)V9(4) COMP-3.
           05 HLD-ACCRUED-INCOME       PIC S9(9)V99 COMP-3.

       FD VALUATION-FILE.
       01 VAL-RECORD.
           05 VAL-TRUST-ID             PIC X(12).
           05 VAL-TOTAL-MARKET         PIC S9(13)V99 COMP-3.
           05 VAL-TOTAL-COST           PIC S9(13)V99 COMP-3.
           05 VAL-UNREAL-GAIN          PIC S9(13)V99 COMP-3.
           05 VAL-INCOME-DUE           PIC S9(11)V99 COMP-3.
           05 VAL-ASSET-MIX            PIC X(30).

       WORKING-STORAGE SECTION.

       01 WS-HOLD-STATUS               PIC X(2).
       01 WS-VAL-STATUS                PIC X(2).

       01 WS-EOF-FLAG                  PIC X VALUE 'N'.
           88 WS-EOF                    VALUE 'Y'.

       01 WS-PREV-TRUST-ID            PIC X(12) VALUE SPACES.

       01 WS-ACCUMULATORS.
           05 WS-SUM-MARKET            PIC S9(13)V99 COMP-3.
           05 WS-SUM-COST              PIC S9(13)V99 COMP-3.
           05 WS-SUM-INCOME            PIC S9(11)V99 COMP-3.
           05 WS-MKT-VALUE             PIC S9(13)V99 COMP-3.

       01 WS-ASSET-COUNTS.
           05 WS-EQ-COUNT              PIC S9(5) COMP-3 VALUE 0.
           05 WS-FI-COUNT              PIC S9(5) COMP-3 VALUE 0.
           05 WS-CA-COUNT              PIC S9(5) COMP-3 VALUE 0.
           05 WS-RE-COUNT              PIC S9(5) COMP-3 VALUE 0.
           05 WS-AL-COUNT              PIC S9(5) COMP-3 VALUE 0.

       01 WS-COUNTERS.
           05 WS-TRUST-COUNT           PIC S9(7) COMP-3 VALUE 0.
           05 WS-HOLDING-COUNT         PIC S9(7) COMP-3 VALUE 0.
           05 WS-TOTAL-MKT-ALL        PIC S9(15)V99 COMP-3
               VALUE 0.

       01 WS-MIX-STRING               PIC X(30).
       01 WS-MIX-EQ                   PIC X(5).
       01 WS-MIX-FI                   PIC X(5).
       01 WS-MIX-OTHER                PIC X(5).
       01 WS-LOOP-IDX                 PIC 9(3).

       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 1100-OPEN-FILES
           PERFORM 1200-READ-FIRST
           PERFORM 2000-PROCESS-HOLDINGS
               UNTIL WS-EOF
           IF WS-PREV-TRUST-ID NOT = SPACES
               PERFORM 3000-WRITE-TRUST-TOTAL
           END-IF
           PERFORM 4000-CLOSE-FILES
           PERFORM 5000-DISPLAY-GRAND-TOTAL
           STOP RUN.

       1000-INITIALIZE.
           MOVE 'N' TO WS-EOF-FLAG
           MOVE SPACES TO WS-PREV-TRUST-ID
           PERFORM 1010-CLEAR-ACCUMULATORS.

       1010-CLEAR-ACCUMULATORS.
           MOVE 0 TO WS-SUM-MARKET
           MOVE 0 TO WS-SUM-COST
           MOVE 0 TO WS-SUM-INCOME
           MOVE 0 TO WS-EQ-COUNT
           MOVE 0 TO WS-FI-COUNT
           MOVE 0 TO WS-CA-COUNT
           MOVE 0 TO WS-RE-COUNT
           MOVE 0 TO WS-AL-COUNT.

       1100-OPEN-FILES.
           OPEN INPUT HOLDING-FILE
           OPEN OUTPUT VALUATION-FILE.

       1200-READ-FIRST.
           READ HOLDING-FILE
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ
           IF NOT WS-EOF
               MOVE HLD-TRUST-ID TO WS-PREV-TRUST-ID
           END-IF.

       2000-PROCESS-HOLDINGS.
           IF HLD-TRUST-ID NOT = WS-PREV-TRUST-ID
               PERFORM 3000-WRITE-TRUST-TOTAL
               PERFORM 1010-CLEAR-ACCUMULATORS
               MOVE HLD-TRUST-ID TO WS-PREV-TRUST-ID
           END-IF
           ADD 1 TO WS-HOLDING-COUNT
           COMPUTE WS-MKT-VALUE =
               HLD-QUANTITY * HLD-MARKET-PRICE
           ADD WS-MKT-VALUE TO WS-SUM-MARKET
           ADD HLD-COST-BASIS TO WS-SUM-COST
           ADD HLD-ACCRUED-INCOME TO WS-SUM-INCOME
           EVALUATE TRUE
               WHEN HLD-EQUITY
                   ADD 1 TO WS-EQ-COUNT
               WHEN HLD-FIXED-INCOME
                   ADD 1 TO WS-FI-COUNT
               WHEN HLD-CASH
                   ADD 1 TO WS-CA-COUNT
               WHEN HLD-REAL-ESTATE
                   ADD 1 TO WS-RE-COUNT
               WHEN HLD-ALTERNATIVE
                   ADD 1 TO WS-AL-COUNT
               WHEN OTHER
                   DISPLAY 'UNKNOWN ASSET TYPE: '
                       HLD-ASSET-TYPE
                       ' FOR CUSIP ' HLD-CUSIP
           END-EVALUATE
           READ HOLDING-FILE
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ.

       3000-WRITE-TRUST-TOTAL.
           ADD 1 TO WS-TRUST-COUNT
           MOVE WS-PREV-TRUST-ID TO VAL-TRUST-ID
           MOVE WS-SUM-MARKET TO VAL-TOTAL-MARKET
           MOVE WS-SUM-COST TO VAL-TOTAL-COST
           COMPUTE VAL-UNREAL-GAIN =
               WS-SUM-MARKET - WS-SUM-COST
           MOVE WS-SUM-INCOME TO VAL-INCOME-DUE
           ADD WS-SUM-MARKET TO WS-TOTAL-MKT-ALL
           PERFORM 3100-BUILD-MIX-STRING
           MOVE WS-MIX-STRING TO VAL-ASSET-MIX
           WRITE VAL-RECORD.

       3100-BUILD-MIX-STRING.
           MOVE SPACES TO WS-MIX-STRING
           MOVE SPACES TO WS-MIX-EQ
           MOVE SPACES TO WS-MIX-FI
           MOVE SPACES TO WS-MIX-OTHER
           IF WS-EQ-COUNT > 0
               STRING 'EQ:' WS-EQ-COUNT
                   DELIMITED BY SIZE
                   INTO WS-MIX-EQ
               END-STRING
           END-IF
           IF WS-FI-COUNT > 0
               STRING 'FI:' WS-FI-COUNT
                   DELIMITED BY SIZE
                   INTO WS-MIX-FI
               END-STRING
           END-IF
           COMPUTE WS-LOOP-IDX =
               WS-CA-COUNT + WS-RE-COUNT + WS-AL-COUNT
           IF WS-LOOP-IDX > 0
               STRING 'OT:' WS-LOOP-IDX
                   DELIMITED BY SIZE
                   INTO WS-MIX-OTHER
               END-STRING
           END-IF
           STRING WS-MIX-EQ ' ' WS-MIX-FI ' '
               WS-MIX-OTHER
               DELIMITED BY SIZE
               INTO WS-MIX-STRING
           END-STRING.

       4000-CLOSE-FILES.
           CLOSE HOLDING-FILE
           CLOSE VALUATION-FILE.

       5000-DISPLAY-GRAND-TOTAL.
           DISPLAY 'TRUST VALUATION COMPLETE'
           DISPLAY 'TRUSTS PROCESSED:   ' WS-TRUST-COUNT
           DISPLAY 'HOLDINGS PROCESSED: ' WS-HOLDING-COUNT
           DISPLAY 'TOTAL MARKET VALUE: ' WS-TOTAL-MKT-ALL.
