       IDENTIFICATION DIVISION.
       PROGRAM-ID. CARD-AUTH-PROCESSOR.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CARD-INFO.
           05 WS-CARD-NUM         PIC X(16).
           05 WS-CARD-STATUS      PIC X(1).
               88 WS-ACTIVE       VALUE 'A'.
               88 WS-BLOCKED      VALUE 'B'.
               88 WS-EXPIRED      VALUE 'E'.
               88 WS-STOLEN       VALUE 'S'.
           05 WS-CARD-TYPE        PIC X(1).
               88 WS-VISA         VALUE 'V'.
               88 WS-MASTER       VALUE 'M'.
               88 WS-AMEX         VALUE 'A'.
           05 WS-CREDIT-LIMIT     PIC S9(7)V99 COMP-3.
           05 WS-CURRENT-BAL      PIC S9(7)V99 COMP-3.
           05 WS-AVAILABLE        PIC S9(7)V99 COMP-3.
           05 WS-EXPIRY-YYYYMM    PIC 9(6).
           05 WS-CURRENT-YYYYMM   PIC 9(6).
       01 WS-TRANSACTION.
           05 WS-TRAN-AMOUNT      PIC S9(7)V99 COMP-3.
           05 WS-TRAN-MERCHANT    PIC X(25).
           05 WS-TRAN-MCC         PIC X(4).
           05 WS-TRAN-COUNTRY     PIC X(3).
           05 WS-TRAN-TIMESTAMP   PIC X(14).
       01 WS-AUTH-RESULT.
           05 WS-AUTH-CODE        PIC X(20).
           05 WS-AUTH-STATUS      PIC X(1).
               88 WS-APPROVED     VALUE 'A'.
               88 WS-DECLINED     VALUE 'D'.
           05 WS-DECLINE-REASON   PIC X(40).
           05 WS-RESPONSE-CODE    PIC X(2).
       01 WS-VELOCITY-TABLE.
           05 WS-VEL-ENTRY OCCURS 20.
               10 WS-VEL-TIME     PIC X(14).
               10 WS-VEL-AMOUNT   PIC S9(7)V99 COMP-3.
               10 WS-VEL-MCC      PIC X(4).
       01 WS-VEL-COUNT            PIC 9(2).
       01 WS-VEL-IDX              PIC 9(2).
       01 WS-DAILY-TOTAL          PIC S9(9)V99 COMP-3.
       01 WS-DAILY-COUNT          PIC S9(3) COMP-3.
       01 WS-DAILY-LIMIT          PIC S9(7)V99 VALUE 5000.00.
       01 WS-DAILY-TXN-LIMIT     PIC S9(3) VALUE 25.
       01 WS-FRAUD-FIELDS.
           05 WS-FRAUD-SCORE      PIC S9(3) COMP-3.
           05 WS-FRAUD-TIER       PIC X(1).
               88 WS-LOW-RISK     VALUE 'L'.
               88 WS-MED-RISK     VALUE 'M'.
               88 WS-HIGH-RISK    VALUE 'H'.
               88 WS-BLOCK-RISK   VALUE 'X'.
           05 WS-RISK-POINTS      PIC S9(3) COMP-3.
           05 WS-INTL-FLAG        PIC X VALUE 'N'.
               88 WS-IS-INTL      VALUE 'Y'.
           05 WS-HIGH-RISK-MCC    PIC X VALUE 'N'.
               88 WS-IS-HIGH-MCC  VALUE 'Y'.
       01 WS-FEE-FIELDS.
           05 WS-BASE-FEE         PIC S9(5)V99 COMP-3.
           05 WS-INTL-FEE         PIC S9(5)V99 COMP-3.
           05 WS-CASH-ADV-FEE     PIC S9(5)V99 COMP-3.
           05 WS-TOTAL-FEE        PIC S9(5)V99 COMP-3.
           05 WS-FEE-RATE         PIC S9(1)V9(4) COMP-3.
       01 WS-AUTH-CODE-PARTS.
           05 WS-AUTH-PREFIX       PIC X(2).
           05 WS-AUTH-SEQ          PIC X(6).
           05 WS-AUTH-SUFFIX       PIC X(2).
       01 WS-UTIL-RATIO           PIC S9(1)V9(4) COMP-3.
       01 WS-PROCESS-FLAG         PIC X VALUE 'Y'.
           88 WS-CONTINUE         VALUE 'Y'.
           88 WS-STOP-PROC        VALUE 'N'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 0100-INITIALIZE
           PERFORM 1000-CHECK-CARD-STATUS
           IF WS-CONTINUE
               PERFORM 2000-CHECK-EXPIRY
           END-IF
           IF WS-CONTINUE
               PERFORM 3000-CHECK-CREDIT-LIMIT
           END-IF
           IF WS-CONTINUE
               PERFORM 4000-CHECK-VELOCITY
           END-IF
           IF WS-CONTINUE
               PERFORM 5000-CALC-FRAUD-SCORE
           END-IF
           IF WS-CONTINUE
               PERFORM 6000-CALC-FEES
           END-IF
           IF WS-CONTINUE
               PERFORM 7000-BUILD-AUTH-CODE
               PERFORM 7500-APPROVE-TRAN
           END-IF
           PERFORM 8000-DISPLAY-RESULT
           STOP RUN.
       0100-INITIALIZE.
           MOVE 'Y' TO WS-PROCESS-FLAG
           MOVE SPACES TO WS-AUTH-CODE
           MOVE SPACES TO WS-DECLINE-REASON
           MOVE '00' TO WS-RESPONSE-CODE
           MOVE 0 TO WS-FRAUD-SCORE
           MOVE 0 TO WS-RISK-POINTS
           MOVE 0 TO WS-DAILY-TOTAL
           MOVE 0 TO WS-DAILY-COUNT
           MOVE 0 TO WS-TOTAL-FEE
           MOVE 'N' TO WS-INTL-FLAG
           MOVE 'N' TO WS-HIGH-RISK-MCC
           COMPUTE WS-AVAILABLE =
               WS-CREDIT-LIMIT - WS-CURRENT-BAL.
       1000-CHECK-CARD-STATUS.
           IF WS-BLOCKED
               MOVE 'CARD BLOCKED BY ISSUER' TO
                   WS-DECLINE-REASON
               MOVE '14' TO WS-RESPONSE-CODE
               PERFORM 9000-DECLINE-TRAN
           END-IF
           IF WS-STOLEN
               MOVE 'CARD REPORTED STOLEN' TO
                   WS-DECLINE-REASON
               MOVE '43' TO WS-RESPONSE-CODE
               PERFORM 9000-DECLINE-TRAN
           END-IF
           IF WS-EXPIRED
               MOVE 'CARD EXPIRED' TO
                   WS-DECLINE-REASON
               MOVE '54' TO WS-RESPONSE-CODE
               PERFORM 9000-DECLINE-TRAN
           END-IF.
       2000-CHECK-EXPIRY.
           IF WS-EXPIRY-YYYYMM < WS-CURRENT-YYYYMM
               MOVE 'CARD PAST EXPIRATION' TO
                   WS-DECLINE-REASON
               MOVE '54' TO WS-RESPONSE-CODE
               PERFORM 9000-DECLINE-TRAN
           END-IF.
       3000-CHECK-CREDIT-LIMIT.
           IF WS-TRAN-AMOUNT > WS-AVAILABLE
               MOVE 'INSUFFICIENT CREDIT' TO
                   WS-DECLINE-REASON
               MOVE '51' TO WS-RESPONSE-CODE
               PERFORM 9000-DECLINE-TRAN
           END-IF
           COMPUTE WS-UTIL-RATIO =
               (WS-CURRENT-BAL + WS-TRAN-AMOUNT) /
               WS-CREDIT-LIMIT
           IF WS-UTIL-RATIO > 0.95
               ADD 20 TO WS-RISK-POINTS
           ELSE
               IF WS-UTIL-RATIO > 0.80
                   ADD 10 TO WS-RISK-POINTS
               END-IF
           END-IF.
       4000-CHECK-VELOCITY.
           MOVE 0 TO WS-DAILY-TOTAL
           MOVE 0 TO WS-DAILY-COUNT
           PERFORM VARYING WS-VEL-IDX FROM 1 BY 1
               UNTIL WS-VEL-IDX > 20
               IF WS-VEL-TIME(WS-VEL-IDX) NOT = SPACES
                   ADD 1 TO WS-DAILY-COUNT
                   ADD WS-VEL-AMOUNT(WS-VEL-IDX) TO
                       WS-DAILY-TOTAL
               END-IF
           END-PERFORM
           ADD WS-TRAN-AMOUNT TO WS-DAILY-TOTAL
           ADD 1 TO WS-DAILY-COUNT
           IF WS-DAILY-TOTAL > WS-DAILY-LIMIT
               MOVE 'DAILY SPENDING LIMIT EXCEEDED' TO
                   WS-DECLINE-REASON
               MOVE '65' TO WS-RESPONSE-CODE
               PERFORM 9000-DECLINE-TRAN
           END-IF
           IF WS-DAILY-COUNT > WS-DAILY-TXN-LIMIT
               ADD 15 TO WS-RISK-POINTS
           END-IF.
       5000-CALC-FRAUD-SCORE.
           IF WS-TRAN-COUNTRY NOT = 'USA'
               MOVE 'Y' TO WS-INTL-FLAG
               ADD 25 TO WS-RISK-POINTS
           END-IF
           IF WS-TRAN-MCC = '5411'
               ADD 0 TO WS-RISK-POINTS
           ELSE
               IF WS-TRAN-MCC = '5912'
                   ADD 5 TO WS-RISK-POINTS
               ELSE
                   IF WS-TRAN-MCC = '7995'
                       ADD 30 TO WS-RISK-POINTS
                       MOVE 'Y' TO WS-HIGH-RISK-MCC
                   ELSE
                       ADD 10 TO WS-RISK-POINTS
                   END-IF
               END-IF
           END-IF
           IF WS-TRAN-AMOUNT > 1000
               ADD 15 TO WS-RISK-POINTS
           ELSE
               IF WS-TRAN-AMOUNT > 500
                   ADD 5 TO WS-RISK-POINTS
               END-IF
           END-IF
           MOVE WS-RISK-POINTS TO WS-FRAUD-SCORE
           EVALUATE TRUE
               WHEN WS-FRAUD-SCORE < 25
                   MOVE 'L' TO WS-FRAUD-TIER
               WHEN WS-FRAUD-SCORE < 50
                   MOVE 'M' TO WS-FRAUD-TIER
               WHEN WS-FRAUD-SCORE < 75
                   MOVE 'H' TO WS-FRAUD-TIER
                   DISPLAY 'HIGH RISK TRANSACTION'
               WHEN OTHER
                   MOVE 'X' TO WS-FRAUD-TIER
                   MOVE 'FRAUD SCORE EXCEEDS THRESHOLD'
                       TO WS-DECLINE-REASON
                   MOVE '59' TO WS-RESPONSE-CODE
                   PERFORM 9000-DECLINE-TRAN
           END-EVALUATE.
       6000-CALC-FEES.
           MOVE 0 TO WS-BASE-FEE
           MOVE 0 TO WS-INTL-FEE
           MOVE 0 TO WS-CASH-ADV-FEE
           IF WS-VISA
               MOVE 0.0175 TO WS-FEE-RATE
           ELSE
               IF WS-MASTER
                   MOVE 0.0185 TO WS-FEE-RATE
               ELSE
                   MOVE 0.0250 TO WS-FEE-RATE
               END-IF
           END-IF
           COMPUTE WS-BASE-FEE =
               WS-TRAN-AMOUNT * WS-FEE-RATE
           IF WS-IS-INTL
               COMPUTE WS-INTL-FEE =
                   WS-TRAN-AMOUNT * 0.03
           END-IF
           IF WS-TRAN-MCC = '6010'
               COMPUTE WS-CASH-ADV-FEE =
                   WS-TRAN-AMOUNT * 0.05
               IF WS-CASH-ADV-FEE < 10
                   MOVE 10 TO WS-CASH-ADV-FEE
               END-IF
           END-IF
           COMPUTE WS-TOTAL-FEE =
               WS-BASE-FEE + WS-INTL-FEE +
               WS-CASH-ADV-FEE.
       7000-BUILD-AUTH-CODE.
           IF WS-VISA
               MOVE 'VA' TO WS-AUTH-PREFIX
           ELSE
               IF WS-MASTER
                   MOVE 'MC' TO WS-AUTH-PREFIX
               ELSE
                   MOVE 'AX' TO WS-AUTH-PREFIX
               END-IF
           END-IF
           MOVE '123456' TO WS-AUTH-SEQ
           IF WS-IS-INTL
               MOVE 'IX' TO WS-AUTH-SUFFIX
           ELSE
               MOVE 'DM' TO WS-AUTH-SUFFIX
           END-IF
           STRING WS-AUTH-PREFIX DELIMITED BY SIZE
                  WS-AUTH-SEQ DELIMITED BY SIZE
                  WS-AUTH-SUFFIX DELIMITED BY SIZE
                  INTO WS-AUTH-CODE
           END-STRING.
       7500-APPROVE-TRAN.
           MOVE 'A' TO WS-AUTH-STATUS
           MOVE '00' TO WS-RESPONSE-CODE
           ADD WS-TRAN-AMOUNT TO WS-CURRENT-BAL
           ADD WS-TOTAL-FEE TO WS-CURRENT-BAL
           COMPUTE WS-AVAILABLE =
               WS-CREDIT-LIMIT - WS-CURRENT-BAL.
       8000-DISPLAY-RESULT.
           DISPLAY 'CARD AUTH RESULT'
           DISPLAY 'CARD:         ' WS-CARD-NUM
           DISPLAY 'AMOUNT:       ' WS-TRAN-AMOUNT
           DISPLAY 'MERCHANT:     ' WS-TRAN-MERCHANT
           IF WS-APPROVED
               DISPLAY 'STATUS:       APPROVED'
               DISPLAY 'AUTH CODE:    ' WS-AUTH-CODE
               DISPLAY 'FEE:          ' WS-TOTAL-FEE
               DISPLAY 'NEW BALANCE:  ' WS-CURRENT-BAL
               DISPLAY 'AVAILABLE:    ' WS-AVAILABLE
               DISPLAY 'FRAUD TIER:   ' WS-FRAUD-TIER
           ELSE
               DISPLAY 'STATUS:       DECLINED'
               DISPLAY 'REASON:       ' WS-DECLINE-REASON
               DISPLAY 'RESP CODE:    ' WS-RESPONSE-CODE
           END-IF.
       9000-DECLINE-TRAN.
           MOVE 'D' TO WS-AUTH-STATUS
           MOVE 'N' TO WS-PROCESS-FLAG
           DISPLAY 'DECLINED: ' WS-DECLINE-REASON.
