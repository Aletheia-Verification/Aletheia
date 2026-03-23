       IDENTIFICATION DIVISION.
       PROGRAM-ID. WIRE-TRANSFER-CALC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-TRANSFER-REQUEST.
           05 WS-SENDER-ACCT      PIC X(16).
           05 WS-BENEF-ACCT       PIC X(34).
           05 WS-SEND-AMOUNT      PIC S9(11)V99 COMP-3.
           05 WS-SOURCE-CURR      PIC X(3).
           05 WS-DEST-CURRENCY    PIC X(3).
           05 WS-PRIORITY         PIC X(1).
               88 WS-URGENT       VALUE 'U'.
               88 WS-NORMAL       VALUE 'N'.
               88 WS-ECONOMY      VALUE 'E'.
           05 WS-CHARGE-TYPE      PIC X(3).
               88 WS-OUR-CHARGE   VALUE 'OUR'.
               88 WS-BEN-CHARGE   VALUE 'BEN'.
               88 WS-SHA-CHARGE   VALUE 'SHA'.
       01 WS-FX-RATE              PIC S9(3)V9(6) COMP-3.
       01 WS-CONVERTED-AMT        PIC S9(11)V99 COMP-3.
       01 WS-FEE-STRUCTURE.
           05 WS-BASE-FEE         PIC S9(5)V99 COMP-3.
           05 WS-TIER-FEE         PIC S9(5)V99 COMP-3.
           05 WS-SWIFT-FEE        PIC S9(5)V99 COMP-3.
           05 WS-CORRESP-FEE-1    PIC S9(5)V99 COMP-3.
           05 WS-CORRESP-FEE-2    PIC S9(5)V99 COMP-3.
           05 WS-PRIORITY-FEE     PIC S9(5)V99 COMP-3.
           05 WS-REGULATORY-FEE   PIC S9(5)V99 COMP-3.
           05 WS-TOTAL-FEES       PIC S9(7)V99 COMP-3.
       01 WS-BENEF-FIELDS.
           05 WS-BENEF-AMOUNT     PIC S9(11)V99 COMP-3.
           05 WS-BENEF-FEE-SHARE  PIC S9(5)V99 COMP-3.
           05 WS-SENDER-COST      PIC S9(11)V99 COMP-3.
       01 WS-REGULATORY.
           05 WS-HOLD-FLAG        PIC X VALUE 'N'.
               88 WS-ON-HOLD      VALUE 'Y'.
           05 WS-AML-CHECK        PIC X VALUE 'P'.
               88 WS-AML-PASS     VALUE 'P'.
               88 WS-AML-FAIL     VALUE 'F'.
               88 WS-AML-REVIEW   VALUE 'R'.
           05 WS-SANCTION-FLAG    PIC X VALUE 'N'.
               88 WS-SANCTIONED   VALUE 'Y'.
           05 WS-CTR-FLAG         PIC X VALUE 'N'.
               88 WS-NEEDS-CTR    VALUE 'Y'.
           05 WS-HOLD-REASON      PIC X(40).
       01 WS-LIMITS.
           05 WS-DAILY-LIMIT      PIC S9(11)V99
               VALUE 250000.00.
           05 WS-DAILY-USED       PIC S9(11)V99 COMP-3.
           05 WS-DAILY-REMAIN     PIC S9(11)V99 COMP-3.
           05 WS-SINGLE-LIMIT     PIC S9(11)V99
               VALUE 100000.00.
       01 WS-CORR-BANK-TABLE.
           05 WS-CORR-ENTRY OCCURS 5.
               10 WS-CORR-SWIFT   PIC X(11).
               10 WS-CORR-NAME    PIC X(20).
               10 WS-CORR-FEE-PCT PIC S9(1)V9(4) COMP-3.
       01 WS-CORR-COUNT           PIC 9(1).
       01 WS-CORR-IDX             PIC 9(1).
       01 WS-PROCESS-STATUS       PIC X VALUE 'Y'.
           88 WS-PROCEED          VALUE 'Y'.
           88 WS-HALT             VALUE 'N'.
       01 WS-RESULT-CODE          PIC X(4).
       01 WS-TEMP-AMT             PIC S9(11)V99 COMP-3.
       01 WS-SPLIT-FEE            PIC S9(5)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 0100-INITIALIZE
           PERFORM 1000-CHECK-LIMITS
           IF WS-PROCEED
               PERFORM 2000-REGULATORY-CHECK
           END-IF
           IF WS-PROCEED
               PERFORM 3000-CONVERT-CURRENCY
           END-IF
           IF WS-PROCEED
               PERFORM 4000-CALC-BASE-FEE
               THRU 4500-CALC-PRIORITY-FEE
           END-IF
           IF WS-PROCEED
               PERFORM 5000-CALC-CORRESP-FEES
           END-IF
           IF WS-PROCEED
               PERFORM 6000-CALC-TOTAL-COST
           END-IF
           PERFORM 7000-DISPLAY-RESULT
           STOP RUN.
       0100-INITIALIZE.
           MOVE 'Y' TO WS-PROCESS-STATUS
           MOVE 0 TO WS-TOTAL-FEES
           MOVE 0 TO WS-BASE-FEE
           MOVE 0 TO WS-TIER-FEE
           MOVE 0 TO WS-SWIFT-FEE
           MOVE 0 TO WS-CORRESP-FEE-1
           MOVE 0 TO WS-CORRESP-FEE-2
           MOVE 0 TO WS-PRIORITY-FEE
           MOVE 0 TO WS-REGULATORY-FEE
           MOVE 0 TO WS-BENEF-FEE-SHARE
           MOVE 'N' TO WS-HOLD-FLAG
           MOVE 'N' TO WS-SANCTION-FLAG
           MOVE 'N' TO WS-CTR-FLAG
           MOVE '0000' TO WS-RESULT-CODE
           MOVE 2 TO WS-CORR-COUNT
           MOVE 'CHASUS33XXX' TO WS-CORR-SWIFT(1)
           MOVE 'JP MORGAN CHASE' TO WS-CORR-NAME(1)
           MOVE 0.0010 TO WS-CORR-FEE-PCT(1)
           MOVE 'DEUTDEFFXXX' TO WS-CORR-SWIFT(2)
           MOVE 'DEUTSCHE BANK' TO WS-CORR-NAME(2)
           MOVE 0.0015 TO WS-CORR-FEE-PCT(2)
           COMPUTE WS-DAILY-REMAIN =
               WS-DAILY-LIMIT - WS-DAILY-USED.
       1000-CHECK-LIMITS.
           IF WS-SEND-AMOUNT > WS-SINGLE-LIMIT
               MOVE 'Y' TO WS-HOLD-FLAG
               MOVE 'EXCEEDS SINGLE TRANSFER LIMIT' TO
                   WS-HOLD-REASON
           END-IF
           IF WS-SEND-AMOUNT > WS-DAILY-REMAIN
               MOVE 'N' TO WS-PROCESS-STATUS
               MOVE 'E001' TO WS-RESULT-CODE
               DISPLAY 'DAILY LIMIT EXCEEDED'
           END-IF
           IF WS-SEND-AMOUNT < 1
               MOVE 'N' TO WS-PROCESS-STATUS
               MOVE 'E002' TO WS-RESULT-CODE
               DISPLAY 'INVALID AMOUNT'
           END-IF.
       2000-REGULATORY-CHECK.
           IF WS-SEND-AMOUNT > 10000
               MOVE 'Y' TO WS-CTR-FLAG
               COMPUTE WS-REGULATORY-FEE = 15.00
           END-IF
           IF WS-SANCTIONED
               MOVE 'N' TO WS-PROCESS-STATUS
               MOVE 'E003' TO WS-RESULT-CODE
               DISPLAY 'SANCTIONED DESTINATION'
           END-IF
           IF WS-AML-FAIL
               MOVE 'N' TO WS-PROCESS-STATUS
               MOVE 'E004' TO WS-RESULT-CODE
               DISPLAY 'AML CHECK FAILED'
           END-IF
           IF WS-AML-REVIEW
               MOVE 'Y' TO WS-HOLD-FLAG
               MOVE 'PENDING AML REVIEW' TO
                   WS-HOLD-REASON
           END-IF.
       3000-CONVERT-CURRENCY.
           IF WS-SOURCE-CURR = WS-DEST-CURRENCY
               MOVE WS-SEND-AMOUNT TO WS-CONVERTED-AMT
               MOVE 1.000000 TO WS-FX-RATE
           ELSE
               EVALUATE WS-DEST-CURRENCY
                   WHEN 'EUR'
                       MOVE 0.920000 TO WS-FX-RATE
                   WHEN 'GBP'
                       MOVE 0.790000 TO WS-FX-RATE
                   WHEN 'JPY'
                       MOVE 149.500000 TO WS-FX-RATE
                   WHEN 'CHF'
                       MOVE 0.880000 TO WS-FX-RATE
                   WHEN 'CAD'
                       MOVE 1.360000 TO WS-FX-RATE
                   WHEN 'AUD'
                       MOVE 1.530000 TO WS-FX-RATE
                   WHEN OTHER
                       MOVE 1.000000 TO WS-FX-RATE
               END-EVALUATE
               COMPUTE WS-CONVERTED-AMT =
                   WS-SEND-AMOUNT * WS-FX-RATE
           END-IF.
       4000-CALC-BASE-FEE.
           IF WS-SEND-AMOUNT > 50000
               COMPUTE WS-BASE-FEE = 45.00
               COMPUTE WS-TIER-FEE =
                   WS-SEND-AMOUNT * 0.0003
           ELSE
               IF WS-SEND-AMOUNT > 10000
                   COMPUTE WS-BASE-FEE = 35.00
                   COMPUTE WS-TIER-FEE =
                       WS-SEND-AMOUNT * 0.0005
               ELSE
                   IF WS-SEND-AMOUNT > 1000
                       COMPUTE WS-BASE-FEE = 25.00
                       COMPUTE WS-TIER-FEE =
                           WS-SEND-AMOUNT * 0.0008
                   ELSE
                       COMPUTE WS-BASE-FEE = 15.00
                       MOVE 0 TO WS-TIER-FEE
                   END-IF
               END-IF
           END-IF.
       4200-CALC-SWIFT-FEE.
           COMPUTE WS-SWIFT-FEE = 12.50
           IF WS-SOURCE-CURR NOT = WS-DEST-CURRENCY
               ADD 5.00 TO WS-SWIFT-FEE
           END-IF.
       4500-CALC-PRIORITY-FEE.
           IF WS-URGENT
               COMPUTE WS-PRIORITY-FEE = 25.00
           ELSE
               IF WS-NORMAL
                   COMPUTE WS-PRIORITY-FEE = 10.00
               ELSE
                   MOVE 0 TO WS-PRIORITY-FEE
               END-IF
           END-IF.
       5000-CALC-CORRESP-FEES.
           MOVE 0 TO WS-CORRESP-FEE-1
           MOVE 0 TO WS-CORRESP-FEE-2
           IF WS-CORR-COUNT > 0
               COMPUTE WS-CORRESP-FEE-1 =
                   WS-SEND-AMOUNT *
                   WS-CORR-FEE-PCT(1)
               IF WS-CORRESP-FEE-1 < 15
                   MOVE 15 TO WS-CORRESP-FEE-1
               END-IF
           END-IF
           IF WS-CORR-COUNT > 1
               COMPUTE WS-CORRESP-FEE-2 =
                   WS-SEND-AMOUNT *
                   WS-CORR-FEE-PCT(2)
               IF WS-CORRESP-FEE-2 < 15
                   MOVE 15 TO WS-CORRESP-FEE-2
               END-IF
           END-IF.
       6000-CALC-TOTAL-COST.
           COMPUTE WS-TOTAL-FEES =
               WS-BASE-FEE + WS-TIER-FEE +
               WS-SWIFT-FEE + WS-CORRESP-FEE-1 +
               WS-CORRESP-FEE-2 + WS-PRIORITY-FEE +
               WS-REGULATORY-FEE
           IF WS-OUR-CHARGE
               COMPUTE WS-SENDER-COST =
                   WS-SEND-AMOUNT + WS-TOTAL-FEES
               MOVE WS-CONVERTED-AMT TO WS-BENEF-AMOUNT
               MOVE 0 TO WS-BENEF-FEE-SHARE
           ELSE
               IF WS-BEN-CHARGE
                   MOVE WS-SEND-AMOUNT TO WS-SENDER-COST
                   COMPUTE WS-BENEF-FEE-SHARE =
                       WS-TOTAL-FEES
                   COMPUTE WS-BENEF-AMOUNT =
                       WS-CONVERTED-AMT - WS-TOTAL-FEES
               ELSE
                   COMPUTE WS-SPLIT-FEE =
                       WS-TOTAL-FEES / 2
                   COMPUTE WS-SENDER-COST =
                       WS-SEND-AMOUNT + WS-SPLIT-FEE
                   MOVE WS-SPLIT-FEE TO
                       WS-BENEF-FEE-SHARE
                   COMPUTE WS-BENEF-AMOUNT =
                       WS-CONVERTED-AMT - WS-SPLIT-FEE
               END-IF
           END-IF
           ADD WS-SEND-AMOUNT TO WS-DAILY-USED
           COMPUTE WS-DAILY-REMAIN =
               WS-DAILY-LIMIT - WS-DAILY-USED.
       7000-DISPLAY-RESULT.
           DISPLAY 'WIRE TRANSFER CALCULATION'
           DISPLAY 'SENDER ACCOUNT:  ' WS-SENDER-ACCT
           DISPLAY 'BENEF ACCOUNT:   ' WS-BENEF-ACCT
           DISPLAY 'SEND AMOUNT:     ' WS-SEND-AMOUNT
               ' ' WS-SOURCE-CURR
           DISPLAY 'CONVERTED:       ' WS-CONVERTED-AMT
               ' ' WS-DEST-CURRENCY
           DISPLAY 'FX RATE:         ' WS-FX-RATE
           DISPLAY 'BASE FEE:        ' WS-BASE-FEE
           DISPLAY 'TIER FEE:        ' WS-TIER-FEE
           DISPLAY 'SWIFT FEE:       ' WS-SWIFT-FEE
           DISPLAY 'CORRESP FEE 1:   ' WS-CORRESP-FEE-1
           DISPLAY 'CORRESP FEE 2:   ' WS-CORRESP-FEE-2
           DISPLAY 'PRIORITY FEE:    ' WS-PRIORITY-FEE
           DISPLAY 'REGULATORY FEE:  ' WS-REGULATORY-FEE
           DISPLAY 'TOTAL FEES:      ' WS-TOTAL-FEES
           DISPLAY 'SENDER TOTAL:    ' WS-SENDER-COST
           DISPLAY 'BENEF RECEIVES:  ' WS-BENEF-AMOUNT
           DISPLAY 'BENEF FEE SHARE: ' WS-BENEF-FEE-SHARE
           IF WS-ON-HOLD
               DISPLAY 'HOLD: ' WS-HOLD-REASON
           END-IF
           IF WS-NEEDS-CTR
               DISPLAY 'CTR FILING REQUIRED'
           END-IF
           DISPLAY 'RESULT CODE:     ' WS-RESULT-CODE
           DISPLAY 'DAILY REMAINING: ' WS-DAILY-REMAIN.
