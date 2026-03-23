       IDENTIFICATION DIVISION.
       PROGRAM-ID. FX-SPOT-CONVERTER.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT FX-RATE-FILE ASSIGN TO 'FXRATES'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-RATE-STATUS.
           SELECT TXN-FILE ASSIGN TO 'FXTXNS'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-TXN-STATUS.
           SELECT OUTPUT-FILE ASSIGN TO 'FXOUT'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-OUT-STATUS.

       DATA DIVISION.
       FILE SECTION.

       FD FX-RATE-FILE.
       01 RATE-RECORD.
           05 RT-CCY-PAIR              PIC X(7).
           05 RT-BID                   PIC S9(5)V9(6) COMP-3.
           05 RT-ASK                   PIC S9(5)V9(6) COMP-3.
           05 RT-MID                   PIC S9(5)V9(6) COMP-3.
           05 RT-EFFECTIVE-DATE        PIC 9(8).

       FD TXN-FILE.
       01 TXN-RECORD.
           05 TX-REF                   PIC X(16).
           05 TX-FROM-CCY              PIC X(3).
           05 TX-TO-CCY                PIC X(3).
           05 TX-AMOUNT                PIC S9(13)V99 COMP-3.
           05 TX-DIRECTION             PIC X(1).
               88 TX-BUY               VALUE 'B'.
               88 TX-SELL              VALUE 'S'.
           05 TX-VALUE-DATE            PIC 9(8).

       FD OUTPUT-FILE.
       01 OUT-RECORD.
           05 OUT-REF                  PIC X(16).
           05 OUT-FROM-AMT             PIC S9(13)V99 COMP-3.
           05 OUT-TO-AMT               PIC S9(13)V99 COMP-3.
           05 OUT-RATE-USED            PIC S9(5)V9(6) COMP-3.
           05 OUT-SPREAD               PIC S9(3)V9(6) COMP-3.
           05 OUT-STATUS               PIC X(8).

       WORKING-STORAGE SECTION.

       01 WS-RATE-STATUS               PIC X(2).
       01 WS-TXN-STATUS                PIC X(2).
       01 WS-OUT-STATUS                PIC X(2).

       01 WS-RATE-EOF                  PIC X VALUE 'N'.
           88 WS-RATE-DONE             VALUE 'Y'.
       01 WS-TXN-EOF                   PIC X VALUE 'N'.
           88 WS-TXN-DONE             VALUE 'Y'.

       01 WS-RATE-TABLE.
           05 WS-RATE-ENTRY OCCURS 20.
               10 WS-RT-PAIR           PIC X(7).
               10 WS-RT-BID            PIC S9(5)V9(6) COMP-3.
               10 WS-RT-ASK            PIC S9(5)V9(6) COMP-3.
               10 WS-RT-MID            PIC S9(5)V9(6) COMP-3.
       01 WS-RATE-COUNT                PIC 9(2) VALUE 0.
       01 WS-RATE-IDX                  PIC 9(2).

       01 WS-SEARCH-PAIR              PIC X(7).
       01 WS-FOUND-FLAG               PIC X VALUE 'N'.
           88 WS-RATE-FOUND            VALUE 'Y'.
       01 WS-APPLIED-RATE             PIC S9(5)V9(6) COMP-3.
       01 WS-CONVERTED-AMT            PIC S9(13)V99 COMP-3.
       01 WS-SPREAD                   PIC S9(3)V9(6) COMP-3.

       01 WS-COUNTERS.
           05 WS-TXN-READ              PIC S9(7) COMP-3 VALUE 0.
           05 WS-TXN-OK                PIC S9(7) COMP-3 VALUE 0.
           05 WS-TXN-FAIL              PIC S9(7) COMP-3 VALUE 0.

       01 WS-TOTAL-FROM-AMT           PIC S9(15)V99 COMP-3
           VALUE 0.
       01 WS-TOTAL-TO-AMT             PIC S9(15)V99 COMP-3
           VALUE 0.
       01 WS-SPACE-COUNT              PIC 9(3).

       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-LOAD-RATES
           PERFORM 1100-OPEN-TXN-FILES
           PERFORM 2000-PROCESS-TRANSACTIONS
               UNTIL WS-TXN-DONE
           PERFORM 3000-CLOSE-ALL
           PERFORM 4000-DISPLAY-SUMMARY
           STOP RUN.

       1000-LOAD-RATES.
           OPEN INPUT FX-RATE-FILE
           MOVE 0 TO WS-RATE-COUNT
           MOVE 'N' TO WS-RATE-EOF
           READ FX-RATE-FILE
               AT END MOVE 'Y' TO WS-RATE-EOF
           END-READ
           PERFORM UNTIL WS-RATE-DONE
               OR WS-RATE-COUNT >= 20
               ADD 1 TO WS-RATE-COUNT
               MOVE RT-CCY-PAIR TO
                   WS-RT-PAIR(WS-RATE-COUNT)
               MOVE RT-BID TO WS-RT-BID(WS-RATE-COUNT)
               MOVE RT-ASK TO WS-RT-ASK(WS-RATE-COUNT)
               MOVE RT-MID TO WS-RT-MID(WS-RATE-COUNT)
               READ FX-RATE-FILE
                   AT END MOVE 'Y' TO WS-RATE-EOF
               END-READ
           END-PERFORM
           CLOSE FX-RATE-FILE.

       1100-OPEN-TXN-FILES.
           OPEN INPUT TXN-FILE
           OPEN OUTPUT OUTPUT-FILE
           READ TXN-FILE
               AT END MOVE 'Y' TO WS-TXN-EOF
           END-READ.

       2000-PROCESS-TRANSACTIONS.
           ADD 1 TO WS-TXN-READ
           STRING TX-FROM-CCY '/' TX-TO-CCY
               DELIMITED BY SIZE
               INTO WS-SEARCH-PAIR
           END-STRING
           MOVE 'N' TO WS-FOUND-FLAG
           PERFORM VARYING WS-RATE-IDX FROM 1 BY 1
               UNTIL WS-RATE-IDX > WS-RATE-COUNT
               OR WS-RATE-FOUND
               IF WS-RT-PAIR(WS-RATE-IDX) = WS-SEARCH-PAIR
                   MOVE 'Y' TO WS-FOUND-FLAG
               END-IF
           END-PERFORM
           IF WS-RATE-FOUND
               SUBTRACT 1 FROM WS-RATE-IDX
               PERFORM 2100-APPLY-RATE
               ADD 1 TO WS-TXN-OK
           ELSE
               PERFORM 2200-HANDLE-NO-RATE
               ADD 1 TO WS-TXN-FAIL
           END-IF
           WRITE OUT-RECORD
           READ TXN-FILE
               AT END MOVE 'Y' TO WS-TXN-EOF
           END-READ.

       2100-APPLY-RATE.
           EVALUATE TRUE
               WHEN TX-BUY
                   MOVE WS-RT-ASK(WS-RATE-IDX)
                       TO WS-APPLIED-RATE
               WHEN TX-SELL
                   MOVE WS-RT-BID(WS-RATE-IDX)
                       TO WS-APPLIED-RATE
               WHEN OTHER
                   MOVE WS-RT-MID(WS-RATE-IDX)
                       TO WS-APPLIED-RATE
           END-EVALUATE
           COMPUTE WS-CONVERTED-AMT =
               TX-AMOUNT * WS-APPLIED-RATE
           COMPUTE WS-SPREAD =
               WS-RT-ASK(WS-RATE-IDX) -
               WS-RT-BID(WS-RATE-IDX)
           MOVE TX-REF TO OUT-REF
           MOVE TX-AMOUNT TO OUT-FROM-AMT
           MOVE WS-CONVERTED-AMT TO OUT-TO-AMT
           MOVE WS-APPLIED-RATE TO OUT-RATE-USED
           MOVE WS-SPREAD TO OUT-SPREAD
           MOVE 'CONVERT ' TO OUT-STATUS
           ADD TX-AMOUNT TO WS-TOTAL-FROM-AMT
           ADD WS-CONVERTED-AMT TO WS-TOTAL-TO-AMT.

       2200-HANDLE-NO-RATE.
           MOVE TX-REF TO OUT-REF
           MOVE TX-AMOUNT TO OUT-FROM-AMT
           MOVE 0 TO OUT-TO-AMT
           MOVE 0 TO OUT-RATE-USED
           MOVE 0 TO OUT-SPREAD
           MOVE 'NO-RATE ' TO OUT-STATUS.

       3000-CLOSE-ALL.
           CLOSE TXN-FILE
           CLOSE OUTPUT-FILE.

       4000-DISPLAY-SUMMARY.
           MOVE 0 TO WS-SPACE-COUNT
           INSPECT WS-SEARCH-PAIR
               TALLYING WS-SPACE-COUNT FOR ALL ' '
           DISPLAY 'FX SPOT CONVERSION COMPLETE'
           DISPLAY 'TRANSACTIONS READ:   ' WS-TXN-READ
           DISPLAY 'CONVERTED OK:        ' WS-TXN-OK
           DISPLAY 'NO RATE FOUND:       ' WS-TXN-FAIL
           DISPLAY 'TOTAL FROM AMOUNT:   ' WS-TOTAL-FROM-AMT
           DISPLAY 'TOTAL TO AMOUNT:     ' WS-TOTAL-TO-AMT.
