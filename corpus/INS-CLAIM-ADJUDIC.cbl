       IDENTIFICATION DIVISION.
       PROGRAM-ID. INS-CLAIM-ADJUDIC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CLAIM-DATA.
           05 WS-CLAIM-NUM           PIC X(12).
           05 WS-POLICY-NUM          PIC X(12).
           05 WS-CLAIM-AMOUNT        PIC S9(9)V99 COMP-3.
           05 WS-DEDUCTIBLE          PIC S9(7)V99 COMP-3.
           05 WS-COPAY-PCT           PIC S9(1)V9(4) COMP-3.
           05 WS-MAX-BENEFIT         PIC S9(9)V99 COMP-3.
       01 WS-CLAIM-TYPE              PIC X(1).
           88 WS-MEDICAL             VALUE 'M'.
           88 WS-DENTAL              VALUE 'D'.
           88 WS-VISION              VALUE 'V'.
           88 WS-PHARMACY            VALUE 'P'.
       01 WS-ADJUD-FIELDS.
           05 WS-ALLOWED-AMT         PIC S9(9)V99 COMP-3.
           05 WS-DEDUCT-APPLIED      PIC S9(7)V99 COMP-3.
           05 WS-COPAY-AMT           PIC S9(7)V99 COMP-3.
           05 WS-PLAN-PAYS           PIC S9(9)V99 COMP-3.
           05 WS-PATIENT-PAYS        PIC S9(7)V99 COMP-3.
       01 WS-ADJUD-STATUS            PIC X(1).
           88 WS-APPROVED            VALUE 'A'.
           88 WS-DENIED              VALUE 'D'.
           88 WS-PENDING             VALUE 'P'.
       01 WS-DENIAL-REASON           PIC X(30).
       01 WS-MSG-LINE                PIC X(60).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-VALIDATE-CLAIM
           IF WS-APPROVED
               PERFORM 3000-CALC-ALLOWED
               PERFORM 4000-CALC-PAYMENT
               PERFORM 5000-BUILD-MSG
           END-IF
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-ALLOWED-AMT
           MOVE 0 TO WS-PLAN-PAYS
           MOVE 0 TO WS-PATIENT-PAYS
           SET WS-PENDING TO TRUE
           MOVE SPACES TO WS-DENIAL-REASON.
       2000-VALIDATE-CLAIM.
           IF WS-CLAIM-AMOUNT <= 0
               SET WS-DENIED TO TRUE
               MOVE 'ZERO OR NEGATIVE AMOUNT' TO
                   WS-DENIAL-REASON
           ELSE
               IF WS-CLAIM-AMOUNT > WS-MAX-BENEFIT
                   SET WS-APPROVED TO TRUE
                   MOVE WS-MAX-BENEFIT TO WS-ALLOWED-AMT
               ELSE
                   SET WS-APPROVED TO TRUE
                   MOVE WS-CLAIM-AMOUNT TO WS-ALLOWED-AMT
               END-IF
           END-IF.
       3000-CALC-ALLOWED.
           EVALUATE TRUE
               WHEN WS-MEDICAL
                   CONTINUE
               WHEN WS-DENTAL
                   IF WS-ALLOWED-AMT > 5000
                       MOVE 5000.00 TO WS-ALLOWED-AMT
                   END-IF
               WHEN WS-VISION
                   IF WS-ALLOWED-AMT > 1000
                       MOVE 1000.00 TO WS-ALLOWED-AMT
                   END-IF
               WHEN WS-PHARMACY
                   IF WS-ALLOWED-AMT > 2500
                       MOVE 2500.00 TO WS-ALLOWED-AMT
                   END-IF
           END-EVALUATE.
       4000-CALC-PAYMENT.
           IF WS-DEDUCTIBLE > 0
               IF WS-ALLOWED-AMT > WS-DEDUCTIBLE
                   MOVE WS-DEDUCTIBLE TO WS-DEDUCT-APPLIED
                   SUBTRACT WS-DEDUCTIBLE FROM
                       WS-ALLOWED-AMT
               ELSE
                   MOVE WS-ALLOWED-AMT TO WS-DEDUCT-APPLIED
                   MOVE 0 TO WS-ALLOWED-AMT
               END-IF
           END-IF
           COMPUTE WS-COPAY-AMT =
               WS-ALLOWED-AMT * WS-COPAY-PCT
           COMPUTE WS-PLAN-PAYS =
               WS-ALLOWED-AMT - WS-COPAY-AMT
           COMPUTE WS-PATIENT-PAYS =
               WS-DEDUCT-APPLIED + WS-COPAY-AMT.
       5000-BUILD-MSG.
           STRING 'CLM ' DELIMITED BY SIZE
                  WS-CLAIM-NUM DELIMITED BY SIZE
                  ' PLAN=' DELIMITED BY SIZE
                  WS-PLAN-PAYS DELIMITED BY SIZE
                  ' PAT=' DELIMITED BY SIZE
                  WS-PATIENT-PAYS DELIMITED BY SIZE
                  INTO WS-MSG-LINE
           END-STRING.
       6000-DISPLAY-RESULTS.
           DISPLAY 'CLAIM ADJUDICATION'
           DISPLAY '=================='
           DISPLAY 'CLAIM:       ' WS-CLAIM-NUM
           DISPLAY 'CLAIM AMT:   ' WS-CLAIM-AMOUNT
           IF WS-APPROVED
               DISPLAY 'STATUS: APPROVED'
               DISPLAY 'ALLOWED:     ' WS-ALLOWED-AMT
               DISPLAY 'DEDUCTIBLE:  ' WS-DEDUCT-APPLIED
               DISPLAY 'COPAY:       ' WS-COPAY-AMT
               DISPLAY 'PLAN PAYS:   ' WS-PLAN-PAYS
               DISPLAY 'PATIENT PAYS:' WS-PATIENT-PAYS
               DISPLAY WS-MSG-LINE
           END-IF
           IF WS-DENIED
               DISPLAY 'STATUS: DENIED'
               DISPLAY 'REASON: ' WS-DENIAL-REASON
           END-IF.
