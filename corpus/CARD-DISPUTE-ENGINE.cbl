       IDENTIFICATION DIVISION.
       PROGRAM-ID. CARD-DISPUTE-ENGINE.
      *================================================================*
      * CARD DISPUTE RESOLUTION ENGINE                                 *
      * Processes cardholder disputes: categorizes, applies REG E/Z    *
      * timelines, calculates provisional credit, tracks aging.        *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-DISPUTE.
           05 WS-DISP-ID            PIC X(12).
           05 WS-CARD-NUM           PIC X(16).
           05 WS-DISP-AMOUNT        PIC S9(9)V99 COMP-3.
           05 WS-DISP-DATE          PIC 9(8).
           05 WS-TXN-DATE           PIC 9(8).
           05 WS-DISP-REASON        PIC X(2).
               88 WS-UNAUTHORIZED   VALUE '01'.
               88 WS-NOT-RECEIVED   VALUE '02'.
               88 WS-DEFECTIVE      VALUE '03'.
               88 WS-WRONG-AMT      VALUE '04'.
               88 WS-DUPLICATE      VALUE '05'.
               88 WS-CANCELLED      VALUE '06'.
           05 WS-CARD-TYPE          PIC X(1).
               88 WS-DEBIT          VALUE 'D'.
               88 WS-CREDIT         VALUE 'C'.
           05 WS-MERCH-NAME         PIC X(30).
           05 WS-MERCH-RESPONSE     PIC X(1).
               88 WS-MERCH-ACCEPT   VALUE 'A'.
               88 WS-MERCH-DENY     VALUE 'D'.
               88 WS-MERCH-PARTIAL  VALUE 'P'.
               88 WS-MERCH-NONE     VALUE 'N'.
       01 WS-TIMELINE.
           05 WS-DAYS-SINCE-TXN     PIC S9(5) COMP-3.
           05 WS-DAYS-SINCE-DISP    PIC S9(5) COMP-3.
           05 WS-REG-DEADLINE       PIC S9(3) COMP-3.
           05 WS-PROV-CREDIT-DAYS   PIC S9(3) COMP-3.
           05 WS-INVESTIG-DAYS      PIC S9(3) COMP-3.
           05 WS-DEADLINE-DATE      PIC 9(8).
       01 WS-PROVISIONAL.
           05 WS-PROV-AMOUNT        PIC S9(9)V99 COMP-3.
           05 WS-PROV-ISSUED        PIC X VALUE 'N'.
               88 WS-HAS-PROV       VALUE 'Y'.
           05 WS-PROV-DUE           PIC X VALUE 'N'.
               88 WS-NEEDS-PROV     VALUE 'Y'.
       01 WS-RESOLUTION.
           05 WS-RESOLUTION-CODE    PIC X(2).
               88 WS-RESOLVED-CUST  VALUE 'CC'.
               88 WS-RESOLVED-MERCH VALUE 'CM'.
               88 WS-RESOLVED-SPLIT VALUE 'SP'.
               88 WS-PENDING-INVEST VALUE 'PI'.
               88 WS-EXPIRED        VALUE 'EX'.
           05 WS-CUST-REFUND        PIC S9(9)V99 COMP-3.
           05 WS-MERCH-CHARGE       PIC S9(9)V99 COMP-3.
           05 WS-NETWORK-FEE        PIC S9(5)V99 COMP-3.
       01 WS-CURRENT-DATE           PIC 9(8).
       01 WS-ERROR-MSG              PIC X(60).
       01 WS-VALID-FLAG             PIC X VALUE 'Y'.
           88 WS-IS-VALID           VALUE 'Y'.
       01 WS-REG-TYPE               PIC X(5).
       01 WS-PARTIAL-PCT            PIC S9(1)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-VALIDATE-DISPUTE
           IF WS-IS-VALID
               PERFORM 3000-CALC-TIMELINES
               PERFORM 4000-DETERMINE-REGULATION
               PERFORM 5000-ASSESS-PROVISIONAL
               PERFORM 6000-RESOLVE-DISPUTE
               PERFORM 7000-CALC-FINANCIALS
           END-IF
           PERFORM 8000-DISPLAY-RESULT
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'DSP202603001' TO WS-DISP-ID
           MOVE '4111222233334444' TO WS-CARD-NUM
           MOVE 549.99 TO WS-DISP-AMOUNT
           MOVE 20260315 TO WS-DISP-DATE
           MOVE 20260228 TO WS-TXN-DATE
           MOVE '01' TO WS-DISP-REASON
           MOVE 'D' TO WS-CARD-TYPE
           MOVE 'ELECTRONICS WHOLESALE INC' TO WS-MERCH-NAME
           MOVE 'D' TO WS-MERCH-RESPONSE
           MOVE 20260321 TO WS-CURRENT-DATE
           MOVE 0 TO WS-PROV-AMOUNT
           MOVE 0 TO WS-CUST-REFUND
           MOVE 0 TO WS-MERCH-CHARGE
           MOVE 0 TO WS-NETWORK-FEE
           MOVE SPACES TO WS-ERROR-MSG.
       2000-VALIDATE-DISPUTE.
           IF WS-DISP-AMOUNT <= 0
               MOVE 'N' TO WS-VALID-FLAG
               MOVE 'DISPUTE AMOUNT MUST BE POSITIVE'
                   TO WS-ERROR-MSG
           END-IF
           IF WS-TXN-DATE > WS-DISP-DATE
               MOVE 'N' TO WS-VALID-FLAG
               MOVE 'TXN DATE CANNOT BE AFTER DISPUTE DATE'
                   TO WS-ERROR-MSG
           END-IF
           COMPUTE WS-DAYS-SINCE-TXN =
               WS-DISP-DATE - WS-TXN-DATE
           IF WS-DAYS-SINCE-TXN > 120
               MOVE 'N' TO WS-VALID-FLAG
               MOVE 'DISPUTE FILED BEYOND 120 DAY WINDOW'
                   TO WS-ERROR-MSG
           END-IF.
       3000-CALC-TIMELINES.
           COMPUTE WS-DAYS-SINCE-DISP =
               WS-CURRENT-DATE - WS-DISP-DATE.
       4000-DETERMINE-REGULATION.
           IF WS-DEBIT
               MOVE 'REG E' TO WS-REG-TYPE
               IF WS-UNAUTHORIZED
                   MOVE 10 TO WS-PROV-CREDIT-DAYS
                   MOVE 45 TO WS-INVESTIG-DAYS
               ELSE
                   MOVE 10 TO WS-PROV-CREDIT-DAYS
                   MOVE 45 TO WS-INVESTIG-DAYS
               END-IF
               IF WS-DAYS-SINCE-TXN > 60
                   MOVE 90 TO WS-INVESTIG-DAYS
               END-IF
           ELSE
               MOVE 'REG Z' TO WS-REG-TYPE
               MOVE 0 TO WS-PROV-CREDIT-DAYS
               MOVE 60 TO WS-INVESTIG-DAYS
           END-IF
           COMPUTE WS-DEADLINE-DATE =
               WS-DISP-DATE + WS-INVESTIG-DAYS.
       5000-ASSESS-PROVISIONAL.
           IF WS-DEBIT
               IF WS-DAYS-SINCE-DISP >= WS-PROV-CREDIT-DAYS
                   IF NOT WS-HAS-PROV
                       MOVE 'Y' TO WS-PROV-DUE
                       MOVE WS-DISP-AMOUNT TO WS-PROV-AMOUNT
                   END-IF
               END-IF
           END-IF.
       6000-RESOLVE-DISPUTE.
           EVALUATE TRUE
               WHEN WS-MERCH-ACCEPT
                   MOVE 'CC' TO WS-RESOLUTION-CODE
               WHEN WS-MERCH-PARTIAL
                   MOVE 'SP' TO WS-RESOLUTION-CODE
                   MOVE 0.50 TO WS-PARTIAL-PCT
               WHEN WS-MERCH-DENY
                   IF WS-UNAUTHORIZED
                       MOVE 'CC' TO WS-RESOLUTION-CODE
                   ELSE
                       IF WS-DAYS-SINCE-DISP >
                           WS-INVESTIG-DAYS
                           MOVE 'CC' TO WS-RESOLUTION-CODE
                       ELSE
                           MOVE 'PI' TO WS-RESOLUTION-CODE
                       END-IF
                   END-IF
               WHEN WS-MERCH-NONE
                   IF WS-DAYS-SINCE-DISP >
                       WS-INVESTIG-DAYS
                       MOVE 'CC' TO WS-RESOLUTION-CODE
                   ELSE
                       MOVE 'PI' TO WS-RESOLUTION-CODE
                   END-IF
           END-EVALUATE.
       7000-CALC-FINANCIALS.
           EVALUATE TRUE
               WHEN WS-RESOLVED-CUST
                   MOVE WS-DISP-AMOUNT TO WS-CUST-REFUND
                   MOVE WS-DISP-AMOUNT TO WS-MERCH-CHARGE
                   COMPUTE WS-NETWORK-FEE = 25.00
               WHEN WS-RESOLVED-SPLIT
                   COMPUTE WS-CUST-REFUND ROUNDED =
                       WS-DISP-AMOUNT * WS-PARTIAL-PCT
                   COMPUTE WS-MERCH-CHARGE ROUNDED =
                       WS-DISP-AMOUNT * WS-PARTIAL-PCT
                   COMPUTE WS-NETWORK-FEE = 15.00
               WHEN WS-PENDING-INVEST
                   MOVE 0 TO WS-CUST-REFUND
                   MOVE 0 TO WS-MERCH-CHARGE
                   MOVE 0 TO WS-NETWORK-FEE
               WHEN OTHER
                   MOVE 0 TO WS-CUST-REFUND
                   MOVE 0 TO WS-MERCH-CHARGE
                   MOVE 0 TO WS-NETWORK-FEE
           END-EVALUATE.
       8000-DISPLAY-RESULT.
           DISPLAY '========================================='
           DISPLAY 'DISPUTE RESOLUTION REPORT'
           DISPLAY '========================================='
           DISPLAY 'DISPUTE ID:      ' WS-DISP-ID
           DISPLAY 'CARD:            ' WS-CARD-NUM
           IF WS-IS-VALID
               DISPLAY 'AMOUNT:          ' WS-DISP-AMOUNT
               DISPLAY 'REASON:          ' WS-DISP-REASON
               DISPLAY 'REGULATION:      ' WS-REG-TYPE
               DISPLAY 'DAYS SINCE TXN:  ' WS-DAYS-SINCE-TXN
               DISPLAY 'DAYS IN DISPUTE: ' WS-DAYS-SINCE-DISP
               DISPLAY 'DEADLINE:        ' WS-DEADLINE-DATE
               DISPLAY 'MERCHANT RESP:   ' WS-MERCH-RESPONSE
               DISPLAY 'RESOLUTION:      ' WS-RESOLUTION-CODE
               DISPLAY 'CUST REFUND:     ' WS-CUST-REFUND
               DISPLAY 'MERCH CHARGE:    ' WS-MERCH-CHARGE
               DISPLAY 'NETWORK FEE:     ' WS-NETWORK-FEE
               IF WS-NEEDS-PROV
                   DISPLAY 'PROVISIONAL DUE: ' WS-PROV-AMOUNT
               END-IF
           ELSE
               DISPLAY 'ERROR: ' WS-ERROR-MSG
           END-IF
           DISPLAY '========================================='.
