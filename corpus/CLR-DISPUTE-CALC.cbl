       IDENTIFICATION DIVISION.
       PROGRAM-ID. CLR-DISPUTE-CALC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-DISPUTE-DATA.
           05 WS-CASE-ID             PIC X(12).
           05 WS-ORIG-AMOUNT         PIC S9(9)V99 COMP-3.
           05 WS-DISPUTE-AMOUNT      PIC S9(9)V99 COMP-3.
           05 WS-FILING-DATE         PIC 9(8).
           05 WS-CURRENT-DATE        PIC 9(8).
       01 WS-DISPUTE-TYPE            PIC X(1).
           88 WS-FULL-DISPUTE        VALUE 'F'.
           88 WS-PARTIAL-DISPUTE     VALUE 'P'.
       01 WS-DAYS-OPEN               PIC S9(3) COMP-3.
       01 WS-MAX-DAYS                PIC 9(3) VALUE 120.
       01 WS-PROVISIONAL-AMT         PIC S9(9)V99 COMP-3.
       01 WS-INT-CREDIT              PIC S9(5)V99 COMP-3.
       01 WS-DAILY-RATE              PIC S9(1)V9(8) COMP-3
           VALUE 0.000137.
       01 WS-STATUS                  PIC X(1).
           88 WS-OPEN                VALUE 'O'.
           88 WS-RESOLVED            VALUE 'R'.
           88 WS-EXPIRED             VALUE 'E'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-TIMELINE
           PERFORM 3000-CALC-PROVISIONAL
           PERFORM 4000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-PROVISIONAL-AMT
           MOVE 0 TO WS-INT-CREDIT
           SET WS-OPEN TO TRUE.
       2000-CALC-TIMELINE.
           COMPUTE WS-DAYS-OPEN =
               WS-CURRENT-DATE - WS-FILING-DATE
           IF WS-DAYS-OPEN > WS-MAX-DAYS
               SET WS-EXPIRED TO TRUE
           END-IF.
       3000-CALC-PROVISIONAL.
           IF WS-FULL-DISPUTE
               MOVE WS-ORIG-AMOUNT TO WS-PROVISIONAL-AMT
           ELSE
               MOVE WS-DISPUTE-AMOUNT TO WS-PROVISIONAL-AMT
           END-IF
           IF WS-DAYS-OPEN > 10
               COMPUTE WS-INT-CREDIT =
                   WS-PROVISIONAL-AMT * WS-DAILY-RATE *
                   (WS-DAYS-OPEN - 10)
           END-IF.
       4000-DISPLAY-RESULTS.
           DISPLAY 'DISPUTE CALCULATION'
           DISPLAY '==================='
           DISPLAY 'CASE:        ' WS-CASE-ID
           DISPLAY 'ORIG AMT:    ' WS-ORIG-AMOUNT
           DISPLAY 'DISPUTE AMT: ' WS-DISPUTE-AMOUNT
           DISPLAY 'DAYS OPEN:   ' WS-DAYS-OPEN
           DISPLAY 'PROVISIONAL: ' WS-PROVISIONAL-AMT
           DISPLAY 'INT CREDIT:  ' WS-INT-CREDIT
           IF WS-OPEN
               DISPLAY 'STATUS: OPEN'
           END-IF
           IF WS-EXPIRED
               DISPLAY 'STATUS: EXPIRED'
           END-IF.
