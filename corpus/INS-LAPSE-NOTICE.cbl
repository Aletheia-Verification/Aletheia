       IDENTIFICATION DIVISION.
       PROGRAM-ID. INS-LAPSE-NOTICE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-POLICY-DATA.
           05 WS-POLICY-NUM          PIC X(12).
           05 WS-INSURED-NAME        PIC X(30).
           05 WS-PREMIUM-DUE         PIC S9(7)V99 COMP-3.
           05 WS-LAST-PMT-DATE       PIC 9(8).
           05 WS-CURRENT-DATE        PIC 9(8).
           05 WS-GRACE-END-DATE      PIC 9(8).
       01 WS-LAPSE-STATUS            PIC X(1).
           88 WS-CURRENT             VALUE 'C'.
           88 WS-GRACE-PERIOD        VALUE 'G'.
           88 WS-LAPSED              VALUE 'L'.
       01 WS-DAYS-PAST-DUE           PIC S9(3) COMP-3.
       01 WS-NOTICE-TYPE             PIC X(1).
           88 WS-REMINDER            VALUE 'R'.
           88 WS-FINAL-NOTICE        VALUE 'F'.
           88 WS-LAPSE-NOTICE        VALUE 'L'.
       01 WS-REINSTATE-ELIGIBLE      PIC X VALUE 'Y'.
           88 WS-CAN-REINSTATE       VALUE 'Y'.
       01 WS-REINSTATE-FEE           PIC S9(5)V99 COMP-3.
       01 WS-NOTICE-MSG              PIC X(60).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-DETERMINE-STATUS
           PERFORM 3000-SET-NOTICE-TYPE
           PERFORM 4000-CALC-REINSTATE
           PERFORM 5000-BUILD-NOTICE
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-REINSTATE-FEE
           SET WS-CURRENT TO TRUE.
       2000-DETERMINE-STATUS.
           COMPUTE WS-DAYS-PAST-DUE =
               WS-CURRENT-DATE - WS-LAST-PMT-DATE
           IF WS-DAYS-PAST-DUE <= 30
               SET WS-CURRENT TO TRUE
           ELSE
               IF WS-DAYS-PAST-DUE <= 60
                   SET WS-GRACE-PERIOD TO TRUE
               ELSE
                   SET WS-LAPSED TO TRUE
               END-IF
           END-IF.
       3000-SET-NOTICE-TYPE.
           EVALUATE TRUE
               WHEN WS-CURRENT
                   SET WS-REMINDER TO TRUE
               WHEN WS-GRACE-PERIOD
                   SET WS-FINAL-NOTICE TO TRUE
               WHEN WS-LAPSED
                   SET WS-LAPSE-NOTICE TO TRUE
           END-EVALUATE.
       4000-CALC-REINSTATE.
           IF WS-LAPSED
               IF WS-DAYS-PAST-DUE <= 180
                   MOVE 'Y' TO WS-REINSTATE-ELIGIBLE
                   COMPUTE WS-REINSTATE-FEE =
                       WS-PREMIUM-DUE * 0.10
                   IF WS-REINSTATE-FEE < 50
                       MOVE 50.00 TO WS-REINSTATE-FEE
                   END-IF
               ELSE
                   MOVE 'N' TO WS-REINSTATE-ELIGIBLE
               END-IF
           END-IF.
       5000-BUILD-NOTICE.
           STRING 'NOTICE ' DELIMITED BY SIZE
                  WS-POLICY-NUM DELIMITED BY SIZE
                  ' DPD=' DELIMITED BY SIZE
                  WS-DAYS-PAST-DUE DELIMITED BY SIZE
                  ' DUE=' DELIMITED BY SIZE
                  WS-PREMIUM-DUE DELIMITED BY SIZE
                  INTO WS-NOTICE-MSG
           END-STRING.
       6000-DISPLAY-RESULTS.
           DISPLAY 'LAPSE NOTICE REPORT'
           DISPLAY '==================='
           DISPLAY 'POLICY:     ' WS-POLICY-NUM
           DISPLAY 'INSURED:    ' WS-INSURED-NAME
           DISPLAY 'PREMIUM DUE:' WS-PREMIUM-DUE
           DISPLAY 'DAYS PAST:  ' WS-DAYS-PAST-DUE
           IF WS-REMINDER
               DISPLAY 'NOTICE: PAYMENT REMINDER'
           END-IF
           IF WS-FINAL-NOTICE
               DISPLAY 'NOTICE: FINAL NOTICE'
           END-IF
           IF WS-LAPSE-NOTICE
               DISPLAY 'NOTICE: POLICY LAPSED'
               IF WS-CAN-REINSTATE
                   DISPLAY 'REINSTATE: ELIGIBLE'
                   DISPLAY 'REINSTATE FEE: '
                       WS-REINSTATE-FEE
               ELSE
                   DISPLAY 'REINSTATE: NOT ELIGIBLE'
               END-IF
           END-IF
           DISPLAY WS-NOTICE-MSG.
