       IDENTIFICATION DIVISION.
       PROGRAM-ID. PAY-RETURN-PROC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-PAYMENT-DATA.
           05 WS-PAY-ID              PIC X(15).
           05 WS-PAY-AMOUNT          PIC S9(9)V99 COMP-3.
           05 WS-PAY-TYPE            PIC X(3).
           05 WS-ORIG-DATE           PIC 9(8).
           05 WS-RETURN-DATE         PIC 9(8).
       01 WS-RETURN-CODE             PIC X(3).
           88 WS-RC-NSF              VALUE 'R01'.
           88 WS-RC-CLOSED           VALUE 'R02'.
           88 WS-RC-NO-ACCT          VALUE 'R03'.
           88 WS-RC-INVALID-NUM      VALUE 'R04'.
           88 WS-RC-UNAUTHORIZED     VALUE 'R10'.
           88 WS-RC-REVOKED          VALUE 'R07'.
       01 WS-RETURN-FIELDS.
           05 WS-RETURN-FEE          PIC S9(5)V99 COMP-3.
           05 WS-PENALTY-FEE         PIC S9(5)V99 COMP-3.
           05 WS-TOTAL-FEE           PIC S9(5)V99 COMP-3.
           05 WS-REVERSAL-AMT        PIC S9(9)V99 COMP-3.
           05 WS-RETRY-ELIGIBLE      PIC X VALUE 'N'.
               88 WS-CAN-RETRY       VALUE 'Y'.
           05 WS-RETRY-COUNT         PIC 9(1).
           05 WS-MAX-RETRIES         PIC 9(1) VALUE 2.
       01 WS-REASON-DESC             PIC X(40).
       01 WS-RETURN-MSG              PIC X(80).
       01 WS-SEVERITY                PIC X(1).
           88 WS-LOW-SEV             VALUE 'L'.
           88 WS-MED-SEV             VALUE 'M'.
           88 WS-HIGH-SEV            VALUE 'H'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CLASSIFY-RETURN
           PERFORM 3000-CALC-FEES
           PERFORM 4000-CHECK-RETRY
           PERFORM 5000-BUILD-RETURN-MSG
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-RETURN-FEE
           MOVE 0 TO WS-PENALTY-FEE
           MOVE 0 TO WS-TOTAL-FEE
           MOVE 'N' TO WS-RETRY-ELIGIBLE
           MOVE 0 TO WS-RETRY-COUNT.
       2000-CLASSIFY-RETURN.
           EVALUATE TRUE
               WHEN WS-RC-NSF
                   MOVE 'INSUFFICIENT FUNDS' TO
                       WS-REASON-DESC
                   SET WS-LOW-SEV TO TRUE
               WHEN WS-RC-CLOSED
                   MOVE 'ACCOUNT CLOSED' TO WS-REASON-DESC
                   SET WS-HIGH-SEV TO TRUE
               WHEN WS-RC-NO-ACCT
                   MOVE 'NO SUCH ACCOUNT' TO WS-REASON-DESC
                   SET WS-HIGH-SEV TO TRUE
               WHEN WS-RC-INVALID-NUM
                   MOVE 'INVALID ACCOUNT NUMBER' TO
                       WS-REASON-DESC
                   SET WS-MED-SEV TO TRUE
               WHEN WS-RC-UNAUTHORIZED
                   MOVE 'NOT AUTHORIZED' TO WS-REASON-DESC
                   SET WS-HIGH-SEV TO TRUE
               WHEN WS-RC-REVOKED
                   MOVE 'AUTHORIZATION REVOKED' TO
                       WS-REASON-DESC
                   SET WS-HIGH-SEV TO TRUE
               WHEN OTHER
                   MOVE 'UNKNOWN RETURN REASON' TO
                       WS-REASON-DESC
                   SET WS-MED-SEV TO TRUE
           END-EVALUATE.
       3000-CALC-FEES.
           IF WS-LOW-SEV
               MOVE 25.00 TO WS-RETURN-FEE
               MOVE 0 TO WS-PENALTY-FEE
           ELSE
               IF WS-MED-SEV
                   MOVE 35.00 TO WS-RETURN-FEE
                   COMPUTE WS-PENALTY-FEE =
                       WS-PAY-AMOUNT * 0.02
               ELSE
                   MOVE 50.00 TO WS-RETURN-FEE
                   COMPUTE WS-PENALTY-FEE =
                       WS-PAY-AMOUNT * 0.05
               END-IF
           END-IF
           COMPUTE WS-TOTAL-FEE =
               WS-RETURN-FEE + WS-PENALTY-FEE
           COMPUTE WS-REVERSAL-AMT =
               WS-PAY-AMOUNT + WS-TOTAL-FEE.
       4000-CHECK-RETRY.
           IF WS-RC-NSF
               IF WS-RETRY-COUNT < WS-MAX-RETRIES
                   MOVE 'Y' TO WS-RETRY-ELIGIBLE
               END-IF
           END-IF.
       5000-BUILD-RETURN-MSG.
           STRING 'RTN ' DELIMITED BY SIZE
                  WS-PAY-ID DELIMITED BY SIZE
                  ' RC=' DELIMITED BY SIZE
                  WS-RETURN-CODE DELIMITED BY SIZE
                  ' AMT=' DELIMITED BY SIZE
                  WS-REVERSAL-AMT DELIMITED BY SIZE
                  INTO WS-RETURN-MSG
           END-STRING.
       6000-DISPLAY-RESULTS.
           DISPLAY 'PAYMENT RETURN PROCESSING'
           DISPLAY '========================='
           DISPLAY 'PAYMENT ID:    ' WS-PAY-ID
           DISPLAY 'AMOUNT:        ' WS-PAY-AMOUNT
           DISPLAY 'RETURN CODE:   ' WS-RETURN-CODE
           DISPLAY 'REASON:        ' WS-REASON-DESC
           DISPLAY 'RETURN FEE:    ' WS-RETURN-FEE
           DISPLAY 'PENALTY FEE:   ' WS-PENALTY-FEE
           DISPLAY 'TOTAL FEE:     ' WS-TOTAL-FEE
           DISPLAY 'REVERSAL AMT:  ' WS-REVERSAL-AMT
           IF WS-CAN-RETRY
               DISPLAY 'RETRY: ELIGIBLE'
           ELSE
               DISPLAY 'RETRY: NOT ELIGIBLE'
           END-IF
           DISPLAY 'MESSAGE: ' WS-RETURN-MSG.
