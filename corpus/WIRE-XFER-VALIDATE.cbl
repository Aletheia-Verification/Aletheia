       IDENTIFICATION DIVISION.
       PROGRAM-ID. WIRE-XFER-VALIDATE.
      *================================================================*
      * WIRE TRANSFER VALIDATION ENGINE                                *
      * Validates SWIFT MT103 wire fields, checks IBAN structure,      *
      * applies velocity limits and correspondent bank routing.        *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-WIRE-MSG.
           05 WS-MSG-TYPE           PIC X(6).
           05 WS-SENDER-BIC        PIC X(11).
           05 WS-RECEIVER-BIC      PIC X(11).
           05 WS-ORDERING-ACCT     PIC X(34).
           05 WS-BENEF-ACCT        PIC X(34).
           05 WS-AMOUNT            PIC S9(13)V99 COMP-3.
           05 WS-CURRENCY          PIC X(3).
           05 WS-VALUE-DATE        PIC 9(8).
           05 WS-REMIT-INFO        PIC X(140).
       01 WS-VALIDATION.
           05 WS-BIC-LEN           PIC S9(2) COMP-3.
           05 WS-IBAN-LEN          PIC S9(2) COMP-3.
           05 WS-IBAN-COUNTRY      PIC X(2).
           05 WS-IBAN-CHECK        PIC X(2).
           05 WS-ERR-COUNT         PIC S9(3) COMP-3.
           05 WS-ERR-TABLE.
               10 WS-ERR-ENTRY OCCURS 10.
                   15 WS-ERR-CODE  PIC X(6).
                   15 WS-ERR-DESC  PIC X(40).
       01 WS-VELOCITY.
           05 WS-DAILY-COUNT       PIC S9(5) COMP-3.
           05 WS-DAILY-TOTAL       PIC S9(13)V99 COMP-3.
           05 WS-MAX-DAILY-COUNT   PIC S9(5) COMP-3 VALUE 50.
           05 WS-MAX-DAILY-AMT     PIC S9(13)V99 COMP-3
               VALUE 5000000.00.
           05 WS-MAX-SINGLE        PIC S9(13)V99 COMP-3
               VALUE 1000000.00.
       01 WS-COMPLIANCE.
           05 WS-OFAC-FLAG         PIC X VALUE 'N'.
               88 WS-OFAC-HIT      VALUE 'Y'.
           05 WS-PEP-FLAG          PIC X VALUE 'N'.
               88 WS-PEP-HIT       VALUE 'Y'.
           05 WS-COUNTRY-RISK      PIC X VALUE 'L'.
               88 WS-LOW-RISK      VALUE 'L'.
               88 WS-MED-RISK      VALUE 'M'.
               88 WS-HIGH-RISK     VALUE 'H'.
           05 WS-CTR-REQUIRED      PIC X VALUE 'N'.
               88 WS-NEEDS-CTR     VALUE 'Y'.
       01 WS-ROUTING.
           05 WS-CORRESP-COUNT     PIC S9(1) COMP-3.
           05 WS-ROUTE-FEE         PIC S9(7)V99 COMP-3.
           05 WS-ROUTE-STATUS      PIC X(10).
       01 WS-IDX                   PIC S9(3) COMP-3.
       01 WS-TEMP-STR              PIC X(40).
       01 WS-OVERALL-STATUS        PIC X VALUE 'P'.
           88 WS-PASSED            VALUE 'P'.
           88 WS-FAILED            VALUE 'F'.
           88 WS-REVIEW            VALUE 'R'.
       01 WS-ERR-MSG-BUILT         PIC X(200).
       01 WS-ERR-POS               PIC S9(3) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-VALIDATE-MSG-TYPE
           PERFORM 3000-VALIDATE-BIC-CODES
           PERFORM 4000-VALIDATE-ACCOUNTS
           PERFORM 5000-CHECK-AMOUNT-LIMITS
           PERFORM 6000-COMPLIANCE-SCREEN
           PERFORM 7000-DETERMINE-ROUTING
           PERFORM 8000-BUILD-RESULT
           PERFORM 9000-DISPLAY-OUTCOME
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-ERR-COUNT
           MOVE 'MT103 ' TO WS-MSG-TYPE
           MOVE 'BOFAUS3NXXX' TO WS-SENDER-BIC
           MOVE 'DEUTDEFFXXX' TO WS-RECEIVER-BIC
           MOVE 'DE89370400440532013000' TO WS-BENEF-ACCT
           MOVE 'US33000123456789' TO WS-ORDERING-ACCT
           MOVE 75000.00 TO WS-AMOUNT
           MOVE 'USD' TO WS-CURRENCY
           MOVE 20260315 TO WS-VALUE-DATE
           MOVE 23 TO WS-DAILY-COUNT
           MOVE 1500000.00 TO WS-DAILY-TOTAL
           MOVE SPACES TO WS-ERR-MSG-BUILT
           MOVE 1 TO WS-ERR-POS.
       2000-VALIDATE-MSG-TYPE.
           EVALUATE WS-MSG-TYPE
               WHEN 'MT103 '
                   CONTINUE
               WHEN 'MT202 '
                   CONTINUE
               WHEN 'MT200 '
                   CONTINUE
               WHEN OTHER
                   PERFORM 2500-ADD-ERROR
           END-EVALUATE.
       2500-ADD-ERROR.
           ADD 1 TO WS-ERR-COUNT
           IF WS-ERR-COUNT <= 10
               MOVE 'E00001' TO WS-ERR-CODE(WS-ERR-COUNT)
               MOVE 'INVALID MESSAGE TYPE'
                   TO WS-ERR-DESC(WS-ERR-COUNT)
           END-IF.
       3000-VALIDATE-BIC-CODES.
           INSPECT WS-SENDER-BIC TALLYING WS-BIC-LEN
               FOR ALL SPACES
           COMPUTE WS-BIC-LEN = 11 - WS-BIC-LEN
           IF WS-BIC-LEN < 8
               ADD 1 TO WS-ERR-COUNT
               IF WS-ERR-COUNT <= 10
                   MOVE 'E00002' TO WS-ERR-CODE(WS-ERR-COUNT)
                   MOVE 'SENDER BIC TOO SHORT'
                       TO WS-ERR-DESC(WS-ERR-COUNT)
               END-IF
           END-IF
           MOVE 0 TO WS-BIC-LEN
           INSPECT WS-RECEIVER-BIC TALLYING WS-BIC-LEN
               FOR ALL SPACES
           COMPUTE WS-BIC-LEN = 11 - WS-BIC-LEN
           IF WS-BIC-LEN < 8
               ADD 1 TO WS-ERR-COUNT
               IF WS-ERR-COUNT <= 10
                   MOVE 'E00003' TO WS-ERR-CODE(WS-ERR-COUNT)
                   MOVE 'RECEIVER BIC TOO SHORT'
                       TO WS-ERR-DESC(WS-ERR-COUNT)
               END-IF
           END-IF.
       4000-VALIDATE-ACCOUNTS.
           MOVE 0 TO WS-IBAN-LEN
           INSPECT WS-BENEF-ACCT TALLYING WS-IBAN-LEN
               FOR ALL SPACES
           COMPUTE WS-IBAN-LEN = 34 - WS-IBAN-LEN
           MOVE WS-BENEF-ACCT(1:2) TO WS-IBAN-COUNTRY
           MOVE WS-BENEF-ACCT(3:2) TO WS-IBAN-CHECK
           IF WS-IBAN-COUNTRY IS NOT ALPHABETIC
               ADD 1 TO WS-ERR-COUNT
               IF WS-ERR-COUNT <= 10
                   MOVE 'E00004' TO WS-ERR-CODE(WS-ERR-COUNT)
                   MOVE 'IBAN COUNTRY CODE INVALID'
                       TO WS-ERR-DESC(WS-ERR-COUNT)
               END-IF
           END-IF
           IF WS-IBAN-LEN < 15
               ADD 1 TO WS-ERR-COUNT
               IF WS-ERR-COUNT <= 10
                   MOVE 'E00005' TO WS-ERR-CODE(WS-ERR-COUNT)
                   MOVE 'IBAN TOO SHORT'
                       TO WS-ERR-DESC(WS-ERR-COUNT)
               END-IF
           END-IF.
       5000-CHECK-AMOUNT-LIMITS.
           IF WS-AMOUNT <= 0
               ADD 1 TO WS-ERR-COUNT
               IF WS-ERR-COUNT <= 10
                   MOVE 'E00006' TO WS-ERR-CODE(WS-ERR-COUNT)
                   MOVE 'AMOUNT MUST BE POSITIVE'
                       TO WS-ERR-DESC(WS-ERR-COUNT)
               END-IF
           END-IF
           IF WS-AMOUNT > WS-MAX-SINGLE
               MOVE 'R' TO WS-OVERALL-STATUS
           END-IF
           COMPUTE WS-DAILY-TOTAL =
               WS-DAILY-TOTAL + WS-AMOUNT
           ADD 1 TO WS-DAILY-COUNT
           IF WS-DAILY-COUNT > WS-MAX-DAILY-COUNT
               MOVE 'R' TO WS-OVERALL-STATUS
           END-IF
           IF WS-DAILY-TOTAL > WS-MAX-DAILY-AMT
               MOVE 'R' TO WS-OVERALL-STATUS
           END-IF
           IF WS-AMOUNT > 10000
               MOVE 'Y' TO WS-CTR-REQUIRED
           END-IF.
       6000-COMPLIANCE-SCREEN.
           EVALUATE TRUE
               WHEN WS-OFAC-HIT
                   MOVE 'F' TO WS-OVERALL-STATUS
                   ADD 1 TO WS-ERR-COUNT
                   IF WS-ERR-COUNT <= 10
                       MOVE 'E00007'
                           TO WS-ERR-CODE(WS-ERR-COUNT)
                       MOVE 'OFAC MATCH DETECTED'
                           TO WS-ERR-DESC(WS-ERR-COUNT)
                   END-IF
               WHEN WS-PEP-HIT
                   MOVE 'R' TO WS-OVERALL-STATUS
               WHEN WS-HIGH-RISK
                   MOVE 'R' TO WS-OVERALL-STATUS
           END-EVALUATE.
       7000-DETERMINE-ROUTING.
           IF WS-SENDER-BIC(1:4) = WS-RECEIVER-BIC(1:4)
               MOVE 0 TO WS-CORRESP-COUNT
               MOVE 0 TO WS-ROUTE-FEE
               MOVE 'DIRECT' TO WS-ROUTE-STATUS
           ELSE
               MOVE 1 TO WS-CORRESP-COUNT
               EVALUATE TRUE
                   WHEN WS-AMOUNT > 100000
                       COMPUTE WS-ROUTE-FEE = 35.00
                   WHEN WS-AMOUNT > 10000
                       COMPUTE WS-ROUTE-FEE = 25.00
                   WHEN OTHER
                       COMPUTE WS-ROUTE-FEE = 15.00
               END-EVALUATE
               MOVE 'CORRESP' TO WS-ROUTE-STATUS
           END-IF.
       8000-BUILD-RESULT.
           IF WS-ERR-COUNT > 0
               IF WS-PASSED
                   MOVE 'F' TO WS-OVERALL-STATUS
               END-IF
               PERFORM VARYING WS-IDX FROM 1 BY 1
                   UNTIL WS-IDX > WS-ERR-COUNT
                   OR WS-IDX > 10
                   STRING WS-ERR-CODE(WS-IDX) DELIMITED
                       BY SIZE
                       ': ' DELIMITED BY SIZE
                       WS-ERR-DESC(WS-IDX) DELIMITED
                       BY SPACES
                       '; ' DELIMITED BY SIZE
                       INTO WS-ERR-MSG-BUILT
               END-PERFORM
           END-IF.
       9000-DISPLAY-OUTCOME.
           DISPLAY '======================================='
           DISPLAY 'WIRE TRANSFER VALIDATION RESULT'
           DISPLAY '======================================='
           DISPLAY 'MSG TYPE:    ' WS-MSG-TYPE
           DISPLAY 'SENDER BIC:  ' WS-SENDER-BIC
           DISPLAY 'RECEIVER:    ' WS-RECEIVER-BIC
           DISPLAY 'AMOUNT:      ' WS-AMOUNT ' ' WS-CURRENCY
           DISPLAY 'ROUTING:     ' WS-ROUTE-STATUS
           DISPLAY 'ROUTE FEE:   ' WS-ROUTE-FEE
           DISPLAY 'ERROR COUNT: ' WS-ERR-COUNT
           EVALUATE TRUE
               WHEN WS-PASSED
                   DISPLAY 'STATUS: APPROVED'
               WHEN WS-REVIEW
                   DISPLAY 'STATUS: REVIEW REQUIRED'
               WHEN WS-FAILED
                   DISPLAY 'STATUS: REJECTED'
           END-EVALUATE
           IF WS-NEEDS-CTR
               DISPLAY 'CTR FILING REQUIRED'
           END-IF
           IF WS-ERR-COUNT > 0
               DISPLAY 'ERRORS: ' WS-ERR-MSG-BUILT
           END-IF
           DISPLAY '======================================='.
