       IDENTIFICATION DIVISION.
       PROGRAM-ID. TRADE-FAIL-TRACKER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-FAIL-DATA.
           05 WS-TRADE-ID            PIC X(12).
           05 WS-SECURITY-ID         PIC X(10).
           05 WS-TRADE-DATE          PIC 9(8).
           05 WS-SETTLE-DATE         PIC 9(8).
           05 WS-CURRENT-DATE        PIC 9(8).
           05 WS-NET-AMOUNT          PIC S9(11)V99 COMP-3.
       01 WS-FAIL-TYPE               PIC X(1).
           88 WS-DELIVER-FAIL        VALUE 'D'.
           88 WS-RECEIVE-FAIL        VALUE 'R'.
       01 WS-DAYS-FAILED             PIC S9(3) COMP-3.
       01 WS-AGING-BUCKET            PIC X(1).
           88 WS-BUCKET-1            VALUE '1'.
           88 WS-BUCKET-2            VALUE '2'.
           88 WS-BUCKET-3            VALUE '3'.
           88 WS-BUCKET-4            VALUE '4'.
       01 WS-PENALTY-FIELDS.
           05 WS-PENALTY-RATE        PIC S9(1)V9(6) COMP-3.
           05 WS-DAILY-PENALTY       PIC S9(7)V99 COMP-3.
           05 WS-TOTAL-PENALTY       PIC S9(9)V99 COMP-3.
       01 WS-ESCALATION              PIC X(1).
           88 WS-AUTO-RESOLVE        VALUE 'A'.
           88 WS-MANUAL-REVIEW       VALUE 'M'.
           88 WS-BUYOUT-REQ          VALUE 'B'.
       01 WS-FAIL-MSG                PIC X(80).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-AGING
           PERFORM 3000-CALC-PENALTY
           PERFORM 4000-DETERMINE-ESCALATION
           PERFORM 5000-BUILD-MESSAGE
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-PENALTY
           SET WS-AUTO-RESOLVE TO TRUE.
       2000-CALC-AGING.
           COMPUTE WS-DAYS-FAILED =
               WS-CURRENT-DATE - WS-SETTLE-DATE
           IF WS-DAYS-FAILED < 0
               MOVE 0 TO WS-DAYS-FAILED
           END-IF
           EVALUATE TRUE
               WHEN WS-DAYS-FAILED <= 3
                   SET WS-BUCKET-1 TO TRUE
               WHEN WS-DAYS-FAILED <= 10
                   SET WS-BUCKET-2 TO TRUE
               WHEN WS-DAYS-FAILED <= 30
                   SET WS-BUCKET-3 TO TRUE
               WHEN OTHER
                   SET WS-BUCKET-4 TO TRUE
           END-EVALUATE.
       3000-CALC-PENALTY.
           EVALUATE TRUE
               WHEN WS-BUCKET-1
                   MOVE 0.0001 TO WS-PENALTY-RATE
               WHEN WS-BUCKET-2
                   MOVE 0.0003 TO WS-PENALTY-RATE
               WHEN WS-BUCKET-3
                   MOVE 0.0005 TO WS-PENALTY-RATE
               WHEN OTHER
                   MOVE 0.0010 TO WS-PENALTY-RATE
           END-EVALUATE
           COMPUTE WS-DAILY-PENALTY =
               WS-NET-AMOUNT * WS-PENALTY-RATE
           COMPUTE WS-TOTAL-PENALTY =
               WS-DAILY-PENALTY * WS-DAYS-FAILED.
       4000-DETERMINE-ESCALATION.
           EVALUATE TRUE
               WHEN WS-BUCKET-1
                   SET WS-AUTO-RESOLVE TO TRUE
               WHEN WS-BUCKET-2
                   SET WS-MANUAL-REVIEW TO TRUE
               WHEN WS-BUCKET-3
                   SET WS-MANUAL-REVIEW TO TRUE
               WHEN WS-BUCKET-4
                   SET WS-BUYOUT-REQ TO TRUE
           END-EVALUATE.
       5000-BUILD-MESSAGE.
           STRING 'FAIL ' DELIMITED BY SIZE
                  WS-TRADE-ID DELIMITED BY SIZE
                  ' DAYS=' DELIMITED BY SIZE
                  WS-DAYS-FAILED DELIMITED BY SIZE
                  ' PEN=' DELIMITED BY SIZE
                  WS-TOTAL-PENALTY DELIMITED BY SIZE
                  INTO WS-FAIL-MSG
           END-STRING.
       6000-DISPLAY-RESULTS.
           DISPLAY 'FAILED TRADE TRACKER'
           DISPLAY '===================='
           DISPLAY 'TRADE ID:      ' WS-TRADE-ID
           DISPLAY 'SECURITY:      ' WS-SECURITY-ID
           DISPLAY 'NET AMOUNT:    ' WS-NET-AMOUNT
           DISPLAY 'DAYS FAILED:   ' WS-DAYS-FAILED
           IF WS-DELIVER-FAIL
               DISPLAY 'TYPE: DELIVER FAIL'
           ELSE
               DISPLAY 'TYPE: RECEIVE FAIL'
           END-IF
           DISPLAY 'DAILY PENALTY: ' WS-DAILY-PENALTY
           DISPLAY 'TOTAL PENALTY: ' WS-TOTAL-PENALTY
           IF WS-AUTO-RESOLVE
               DISPLAY 'ESCALATION: AUTO-RESOLVE'
           END-IF
           IF WS-MANUAL-REVIEW
               DISPLAY 'ESCALATION: MANUAL REVIEW'
           END-IF
           IF WS-BUYOUT-REQ
               DISPLAY 'ESCALATION: BUY-IN REQUIRED'
           END-IF
           DISPLAY WS-FAIL-MSG.
