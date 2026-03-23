       IDENTIFICATION DIVISION.
       PROGRAM-ID. PAY-SAME-DAY-ACH.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-TXN-DATA.
           05 WS-TXN-ID              PIC X(15).
           05 WS-TXN-AMOUNT          PIC S9(9)V99 COMP-3.
           05 WS-ORIGINATOR-ID       PIC X(10).
           05 WS-RECEIVER-ACCT       PIC X(17).
           05 WS-RECEIVER-NAME       PIC X(30).
           05 WS-SUBMIT-TIME         PIC 9(6).
       01 WS-TXN-CLASS               PIC X(3).
           88 WS-CREDIT-TXN          VALUE 'CCD'.
           88 WS-DEBIT-TXN           VALUE 'PPD'.
           88 WS-PAYROLL-TXN         VALUE 'CTX'.
       01 WS-CUTOFF-TIMES.
           05 WS-WINDOW-1-CUT        PIC 9(6) VALUE 104500.
           05 WS-WINDOW-2-CUT        PIC 9(6) VALUE 140000.
           05 WS-WINDOW-3-CUT        PIC 9(6) VALUE 165000.
       01 WS-WINDOW-RESULT           PIC X(1).
           88 WS-WIN-1               VALUE '1'.
           88 WS-WIN-2               VALUE '2'.
           88 WS-WIN-3               VALUE '3'.
           88 WS-MISSED-CUTOFF       VALUE 'X'.
       01 WS-MAX-AMOUNT              PIC S9(9)V99 COMP-3
           VALUE 1000000.00.
       01 WS-SD-FEE                  PIC S9(5)V99 COMP-3.
       01 WS-ELIGIBLE-FLAG           PIC X VALUE 'N'.
           88 WS-IS-ELIGIBLE         VALUE 'Y'.
       01 WS-DENIAL-REASON           PIC X(40).
       01 WS-SETTLE-TIME             PIC X(20).
       01 WS-ALERT-MSG               PIC X(80).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CHECK-AMOUNT-LIMIT
           PERFORM 3000-DETERMINE-WINDOW
           PERFORM 4000-VALIDATE-ELIGIBILITY
           PERFORM 5000-CALC-FEES
           PERFORM 6000-BUILD-ALERT
           PERFORM 7000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-SD-FEE
           MOVE 'N' TO WS-ELIGIBLE-FLAG
           MOVE SPACES TO WS-DENIAL-REASON.
       2000-CHECK-AMOUNT-LIMIT.
           IF WS-TXN-AMOUNT > WS-MAX-AMOUNT
               MOVE 'EXCEEDS SAME-DAY LIMIT' TO
                   WS-DENIAL-REASON
           END-IF
           IF WS-TXN-AMOUNT <= 0
               MOVE 'INVALID AMOUNT' TO WS-DENIAL-REASON
           END-IF.
       3000-DETERMINE-WINDOW.
           IF WS-DENIAL-REASON NOT = SPACES
               SET WS-MISSED-CUTOFF TO TRUE
           ELSE
               EVALUATE TRUE
                   WHEN WS-SUBMIT-TIME <= WS-WINDOW-1-CUT
                       SET WS-WIN-1 TO TRUE
                       MOVE 'SETTLE BY 13:00 ET'
                           TO WS-SETTLE-TIME
                   WHEN WS-SUBMIT-TIME <= WS-WINDOW-2-CUT
                       SET WS-WIN-2 TO TRUE
                       MOVE 'SETTLE BY 16:00 ET'
                           TO WS-SETTLE-TIME
                   WHEN WS-SUBMIT-TIME <= WS-WINDOW-3-CUT
                       SET WS-WIN-3 TO TRUE
                       MOVE 'SETTLE BY 18:00 ET'
                           TO WS-SETTLE-TIME
                   WHEN OTHER
                       SET WS-MISSED-CUTOFF TO TRUE
                       MOVE 'PAST ALL CUTOFF WINDOWS'
                           TO WS-DENIAL-REASON
               END-EVALUATE
           END-IF.
       4000-VALIDATE-ELIGIBILITY.
           IF WS-DENIAL-REASON = SPACES
               IF WS-CREDIT-TXN OR WS-DEBIT-TXN
                       OR WS-PAYROLL-TXN
                   MOVE 'Y' TO WS-ELIGIBLE-FLAG
               ELSE
                   MOVE 'UNSUPPORTED SEC CODE' TO
                       WS-DENIAL-REASON
               END-IF
           END-IF.
       5000-CALC-FEES.
           IF WS-IS-ELIGIBLE
               EVALUATE TRUE
                   WHEN WS-TXN-AMOUNT <= 25000
                       MOVE 1.00 TO WS-SD-FEE
                   WHEN WS-TXN-AMOUNT <= 100000
                       MOVE 2.50 TO WS-SD-FEE
                   WHEN WS-TXN-AMOUNT <= 500000
                       MOVE 5.00 TO WS-SD-FEE
                   WHEN OTHER
                       MOVE 10.00 TO WS-SD-FEE
               END-EVALUATE
               IF WS-WIN-3
                   COMPUTE WS-SD-FEE =
                       WS-SD-FEE * 1.50
               END-IF
           END-IF.
       6000-BUILD-ALERT.
           IF WS-IS-ELIGIBLE
               STRING 'SDACH ' DELIMITED BY SIZE
                      WS-TXN-ID DELIMITED BY SIZE
                      ' WIN=' DELIMITED BY SIZE
                      WS-WINDOW-RESULT DELIMITED BY SIZE
                      ' AMT=' DELIMITED BY SIZE
                      WS-TXN-AMOUNT DELIMITED BY SIZE
                      INTO WS-ALERT-MSG
               END-STRING
           ELSE
               STRING 'DENY ' DELIMITED BY SIZE
                      WS-TXN-ID DELIMITED BY SIZE
                      ' ' DELIMITED BY SIZE
                      WS-DENIAL-REASON DELIMITED BY SIZE
                      INTO WS-ALERT-MSG
               END-STRING
           END-IF.
       7000-DISPLAY-RESULTS.
           DISPLAY 'SAME-DAY ACH PROCESSING'
           DISPLAY '======================='
           DISPLAY 'TXN ID:      ' WS-TXN-ID
           DISPLAY 'AMOUNT:      ' WS-TXN-AMOUNT
           DISPLAY 'SEC CODE:    ' WS-TXN-CLASS
           DISPLAY 'SUBMIT TIME: ' WS-SUBMIT-TIME
           IF WS-IS-ELIGIBLE
               DISPLAY 'STATUS: ELIGIBLE'
               DISPLAY 'WINDOW:      ' WS-WINDOW-RESULT
               DISPLAY 'SETTLE:      ' WS-SETTLE-TIME
               DISPLAY 'SD FEE:      ' WS-SD-FEE
           ELSE
               DISPLAY 'STATUS: DENIED'
               DISPLAY 'REASON:      ' WS-DENIAL-REASON
           END-IF
           DISPLAY 'ALERT: ' WS-ALERT-MSG.
