       IDENTIFICATION DIVISION.
       PROGRAM-ID. PAY-CUTOFF-CHECK.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-TXN-DATA.
           05 WS-TXN-ID              PIC X(15).
           05 WS-TXN-TIME            PIC 9(6).
           05 WS-TXN-AMOUNT          PIC S9(9)V99 COMP-3.
           05 WS-TXN-PRIORITY        PIC X(1).
       01 WS-CHANNEL                 PIC X(1).
           88 WS-WIRE                VALUE 'W'.
           88 WS-ACH                 VALUE 'A'.
           88 WS-BOOK                VALUE 'B'.
           88 WS-CHECK               VALUE 'C'.
       01 WS-CUTOFF-TIME             PIC 9(6).
       01 WS-RESULT                  PIC X(1).
           88 WS-WITHIN-CUTOFF       VALUE 'W'.
           88 WS-PAST-CUTOFF         VALUE 'P'.
           88 WS-NEXT-DAY            VALUE 'N'.
       01 WS-VALUE-DATE              PIC 9(8).
       01 WS-CURRENT-DATE-WS         PIC 9(8).
       01 WS-NEXT-BUS-DATE           PIC 9(8).
       01 WS-TIME-REMAINING          PIC 9(6).
       01 WS-URGENCY                 PIC X(1).
           88 WS-URGENT              VALUE 'U'.
           88 WS-NORMAL              VALUE 'N'.
       01 WS-EXPEDITE-FEE            PIC S9(5)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-SET-CUTOFF
           PERFORM 3000-EVALUATE-TIMING
           PERFORM 4000-CALC-FEES
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-EXPEDITE-FEE
           SET WS-NORMAL TO TRUE.
       2000-SET-CUTOFF.
           EVALUATE TRUE
               WHEN WS-WIRE
                   MOVE 170000 TO WS-CUTOFF-TIME
               WHEN WS-ACH
                   MOVE 165000 TO WS-CUTOFF-TIME
               WHEN WS-BOOK
                   MOVE 200000 TO WS-CUTOFF-TIME
               WHEN WS-CHECK
                   MOVE 140000 TO WS-CUTOFF-TIME
               WHEN OTHER
                   MOVE 160000 TO WS-CUTOFF-TIME
           END-EVALUATE.
       3000-EVALUATE-TIMING.
           IF WS-TXN-TIME <= WS-CUTOFF-TIME
               SET WS-WITHIN-CUTOFF TO TRUE
               MOVE WS-CURRENT-DATE-WS TO WS-VALUE-DATE
               COMPUTE WS-TIME-REMAINING =
                   WS-CUTOFF-TIME - WS-TXN-TIME
               IF WS-TIME-REMAINING < 3000
                   SET WS-URGENT TO TRUE
               END-IF
           ELSE
               SET WS-PAST-CUTOFF TO TRUE
               MOVE WS-NEXT-BUS-DATE TO WS-VALUE-DATE
               IF WS-TXN-PRIORITY = 'H'
                   IF WS-WIRE
                       SUBTRACT WS-CUTOFF-TIME FROM
                           WS-TXN-TIME
                           GIVING WS-TIME-REMAINING
                       IF WS-TIME-REMAINING < 10000
                           SET WS-WITHIN-CUTOFF TO TRUE
                           MOVE WS-CURRENT-DATE-WS TO
                               WS-VALUE-DATE
                           SET WS-URGENT TO TRUE
                       END-IF
                   END-IF
               END-IF
           END-IF.
       4000-CALC-FEES.
           IF WS-URGENT
               EVALUATE TRUE
                   WHEN WS-WIRE
                       MOVE 25.00 TO WS-EXPEDITE-FEE
                   WHEN WS-ACH
                       MOVE 10.00 TO WS-EXPEDITE-FEE
                   WHEN OTHER
                       MOVE 15.00 TO WS-EXPEDITE-FEE
               END-EVALUATE
           END-IF.
       5000-DISPLAY-RESULTS.
           DISPLAY 'PAYMENT CUTOFF CHECK'
           DISPLAY '===================='
           DISPLAY 'TXN ID:        ' WS-TXN-ID
           DISPLAY 'TXN TIME:      ' WS-TXN-TIME
           DISPLAY 'CUTOFF TIME:   ' WS-CUTOFF-TIME
           DISPLAY 'VALUE DATE:    ' WS-VALUE-DATE
           IF WS-WITHIN-CUTOFF
               DISPLAY 'STATUS: WITHIN CUTOFF'
           ELSE
               DISPLAY 'STATUS: PAST CUTOFF - NEXT DAY'
           END-IF
           IF WS-URGENT
               DISPLAY 'URGENCY: HIGH'
               DISPLAY 'EXPEDITE FEE:  ' WS-EXPEDITE-FEE
           END-IF.
