       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACH-RETURN-HANDLER.
      *================================================================*
      * ACH RETURN PROCESSING ENGINE                                   *
      * Processes ACH return entries by reason code, applies fees,     *
      * updates account balances, generates notification records.      *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-RETURN-TABLE.
           05 WS-RET-ENTRY OCCURS 10.
               10 WS-RET-TRACE      PIC X(15).
               10 WS-RET-ACCT       PIC X(12).
               10 WS-RET-AMOUNT     PIC S9(9)V99 COMP-3.
               10 WS-RET-REASON     PIC X(3).
                   88 WS-NSF        VALUE 'R01'.
                   88 WS-CLOSED     VALUE 'R02'.
                   88 WS-NO-ACCT    VALUE 'R03'.
                   88 WS-INVALID-NUM VALUE 'R04'.
                   88 WS-UNAUTH     VALUE 'R10'.
                   88 WS-RDFI-LATE  VALUE 'R12'.
               10 WS-RET-ORIG-DATE  PIC 9(8).
               10 WS-RET-FEE        PIC S9(5)V99 COMP-3.
               10 WS-RET-ACTION     PIC X(10).
               10 WS-RET-NOTIFY     PIC X VALUE 'N'.
                   88 WS-SEND-NOTE  VALUE 'Y'.
       01 WS-RET-COUNT              PIC S9(3) COMP-3.
       01 WS-IDX                    PIC S9(3) COMP-3.
       01 WS-FEE-SCHEDULE.
           05 WS-NSF-FEE            PIC S9(5)V99 COMP-3
               VALUE 35.00.
           05 WS-UNAUTH-FEE         PIC S9(5)V99 COMP-3
               VALUE 25.00.
           05 WS-DEFAULT-FEE        PIC S9(5)V99 COMP-3
               VALUE 15.00.
       01 WS-SUMMARY.
           05 WS-TOTAL-RETURNS      PIC S9(11)V99 COMP-3.
           05 WS-TOTAL-FEES         PIC S9(9)V99 COMP-3.
           05 WS-NSF-COUNT          PIC S9(3) COMP-3.
           05 WS-CLOSED-COUNT       PIC S9(3) COMP-3.
           05 WS-UNAUTH-COUNT       PIC S9(3) COMP-3.
           05 WS-OTHER-COUNT        PIC S9(3) COMP-3.
           05 WS-NOTIFY-COUNT       PIC S9(3) COMP-3.
       01 WS-CURRENT-DATE           PIC 9(8).
       01 WS-DAYS-SINCE             PIC S9(5) COMP-3.
       01 WS-RESUBMIT-FLAG          PIC X VALUE 'N'.
           88 WS-CAN-RESUBMIT       VALUE 'Y'.
       01 WS-DETAIL-LINE            PIC X(100).
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-RETURNS
           PERFORM 3000-PROCESS-RETURNS
           PERFORM 4000-CALC-SUMMARY
           PERFORM 5000-DISPLAY-REPORT
           STOP RUN.
       1000-INITIALIZE.
           MOVE 20260321 TO WS-CURRENT-DATE
           MOVE 0 TO WS-TOTAL-RETURNS
           MOVE 0 TO WS-TOTAL-FEES
           MOVE 0 TO WS-NSF-COUNT
           MOVE 0 TO WS-CLOSED-COUNT
           MOVE 0 TO WS-UNAUTH-COUNT
           MOVE 0 TO WS-OTHER-COUNT
           MOVE 0 TO WS-NOTIFY-COUNT.
       2000-LOAD-RETURNS.
           MOVE 6 TO WS-RET-COUNT
           MOVE '091000010000001' TO WS-RET-TRACE(1)
           MOVE 'ACCT00001234' TO WS-RET-ACCT(1)
           MOVE 1500.00 TO WS-RET-AMOUNT(1)
           MOVE 'R01' TO WS-RET-REASON(1)
           MOVE 20260318 TO WS-RET-ORIG-DATE(1)
           MOVE '091000010000002' TO WS-RET-TRACE(2)
           MOVE 'ACCT00005678' TO WS-RET-ACCT(2)
           MOVE 250.00 TO WS-RET-AMOUNT(2)
           MOVE 'R02' TO WS-RET-REASON(2)
           MOVE 20260316 TO WS-RET-ORIG-DATE(2)
           MOVE '091000010000003' TO WS-RET-TRACE(3)
           MOVE 'ACCT00009012' TO WS-RET-ACCT(3)
           MOVE 75.50 TO WS-RET-AMOUNT(3)
           MOVE 'R03' TO WS-RET-REASON(3)
           MOVE 20260319 TO WS-RET-ORIG-DATE(3)
           MOVE '091000010000004' TO WS-RET-TRACE(4)
           MOVE 'ACCT00003456' TO WS-RET-ACCT(4)
           MOVE 5000.00 TO WS-RET-AMOUNT(4)
           MOVE 'R10' TO WS-RET-REASON(4)
           MOVE 20260310 TO WS-RET-ORIG-DATE(4)
           MOVE '091000010000005' TO WS-RET-TRACE(5)
           MOVE 'ACCT00001234' TO WS-RET-ACCT(5)
           MOVE 800.00 TO WS-RET-AMOUNT(5)
           MOVE 'R01' TO WS-RET-REASON(5)
           MOVE 20260320 TO WS-RET-ORIG-DATE(5)
           MOVE '091000010000006' TO WS-RET-TRACE(6)
           MOVE 'ACCT00007890' TO WS-RET-ACCT(6)
           MOVE 125.00 TO WS-RET-AMOUNT(6)
           MOVE 'R04' TO WS-RET-REASON(6)
           MOVE 20260317 TO WS-RET-ORIG-DATE(6).
       3000-PROCESS-RETURNS.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-RET-COUNT
               PERFORM 3100-DETERMINE-FEE
               PERFORM 3200-DETERMINE-ACTION
               PERFORM 3300-CHECK-NOTIFY
           END-PERFORM.
       3100-DETERMINE-FEE.
           EVALUATE TRUE
               WHEN WS-NSF(WS-IDX)
                   MOVE WS-NSF-FEE TO WS-RET-FEE(WS-IDX)
               WHEN WS-UNAUTH(WS-IDX)
                   MOVE WS-UNAUTH-FEE TO WS-RET-FEE(WS-IDX)
               WHEN WS-CLOSED(WS-IDX)
                   MOVE 0 TO WS-RET-FEE(WS-IDX)
               WHEN WS-NO-ACCT(WS-IDX)
                   MOVE 0 TO WS-RET-FEE(WS-IDX)
               WHEN OTHER
                   MOVE WS-DEFAULT-FEE TO
                       WS-RET-FEE(WS-IDX)
           END-EVALUATE.
       3200-DETERMINE-ACTION.
           EVALUATE TRUE
               WHEN WS-NSF(WS-IDX)
                   COMPUTE WS-DAYS-SINCE =
                       WS-CURRENT-DATE -
                       WS-RET-ORIG-DATE(WS-IDX)
                   IF WS-DAYS-SINCE <= 3
                       MOVE 'RESUBMIT' TO
                           WS-RET-ACTION(WS-IDX)
                   ELSE
                       MOVE 'COLLECT' TO
                           WS-RET-ACTION(WS-IDX)
                   END-IF
               WHEN WS-CLOSED(WS-IDX)
                   MOVE 'UPDATE ACCT' TO
                       WS-RET-ACTION(WS-IDX)
               WHEN WS-NO-ACCT(WS-IDX)
                   MOVE 'VOID ENTRY' TO
                       WS-RET-ACTION(WS-IDX)
               WHEN WS-UNAUTH(WS-IDX)
                   MOVE 'INVESTIGATE' TO
                       WS-RET-ACTION(WS-IDX)
               WHEN OTHER
                   MOVE 'REVIEW' TO
                       WS-RET-ACTION(WS-IDX)
           END-EVALUATE.
       3300-CHECK-NOTIFY.
           IF WS-NSF(WS-IDX) OR WS-UNAUTH(WS-IDX)
               MOVE 'Y' TO WS-RET-NOTIFY(WS-IDX)
           END-IF
           IF WS-RET-AMOUNT(WS-IDX) > 1000
               MOVE 'Y' TO WS-RET-NOTIFY(WS-IDX)
           END-IF.
       4000-CALC-SUMMARY.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-RET-COUNT
               ADD WS-RET-AMOUNT(WS-IDX) TO WS-TOTAL-RETURNS
               ADD WS-RET-FEE(WS-IDX) TO WS-TOTAL-FEES
               EVALUATE TRUE
                   WHEN WS-NSF(WS-IDX)
                       ADD 1 TO WS-NSF-COUNT
                   WHEN WS-CLOSED(WS-IDX)
                       ADD 1 TO WS-CLOSED-COUNT
                   WHEN WS-UNAUTH(WS-IDX)
                       ADD 1 TO WS-UNAUTH-COUNT
                   WHEN OTHER
                       ADD 1 TO WS-OTHER-COUNT
               END-EVALUATE
               IF WS-SEND-NOTE(WS-IDX)
                   ADD 1 TO WS-NOTIFY-COUNT
               END-IF
           END-PERFORM.
       5000-DISPLAY-REPORT.
           DISPLAY '========================================='
           DISPLAY 'ACH RETURN PROCESSING REPORT'
           DISPLAY '========================================='
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-RET-COUNT
               MOVE SPACES TO WS-DETAIL-LINE
               STRING WS-RET-TRACE(WS-IDX) DELIMITED BY SIZE
                   ' ' DELIMITED BY SIZE
                   WS-RET-REASON(WS-IDX) DELIMITED BY SIZE
                   ' $' DELIMITED BY SIZE
                   WS-RET-AMOUNT(WS-IDX) DELIMITED BY SIZE
                   ' -> ' DELIMITED BY SIZE
                   WS-RET-ACTION(WS-IDX) DELIMITED BY SIZE
                   INTO WS-DETAIL-LINE
               DISPLAY WS-DETAIL-LINE
           END-PERFORM
           DISPLAY '-----------------------------------------'
           DISPLAY 'TOTAL RETURNS:   ' WS-TOTAL-RETURNS
           DISPLAY 'TOTAL FEES:      ' WS-TOTAL-FEES
           DISPLAY 'NSF COUNT:       ' WS-NSF-COUNT
           DISPLAY 'CLOSED COUNT:    ' WS-CLOSED-COUNT
           DISPLAY 'UNAUTH COUNT:    ' WS-UNAUTH-COUNT
           DISPLAY 'OTHER COUNT:     ' WS-OTHER-COUNT
           DISPLAY 'NOTIFICATIONS:   ' WS-NOTIFY-COUNT
           DISPLAY '========================================='.
