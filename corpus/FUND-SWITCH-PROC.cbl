       IDENTIFICATION DIVISION.
       PROGRAM-ID. FUND-SWITCH-PROC.
      *================================================================
      * MUTUAL FUND SWITCH PROCESSOR
      * Handles fund-to-fund exchanges within the same fund family,
      * applying exchange limits and tracking cost basis carryover.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-SWITCH-REQUEST.
           05 WS-ACCT-NUM             PIC X(10).
           05 WS-FROM-FUND            PIC X(6).
           05 WS-TO-FUND              PIC X(6).
           05 WS-SWITCH-SHARES        PIC S9(9)V9(4) COMP-3.
           05 WS-SWITCH-DATE          PIC 9(8).
           05 WS-SWITCH-TYPE          PIC X(1).
               88 SW-FULL             VALUE 'F'.
               88 SW-PARTIAL          VALUE 'P'.
       01 WS-FROM-FUND-DATA.
           05 WS-FF-NAV              PIC S9(5)V9(4) COMP-3.
           05 WS-FF-SHARES-HELD      PIC S9(9)V9(4) COMP-3.
           05 WS-FF-COST-BASIS       PIC S9(9)V99 COMP-3.
           05 WS-FF-SHARE-CLASS      PIC X(1).
               88 FF-CLASS-A         VALUE 'A'.
               88 FF-CLASS-B         VALUE 'B'.
               88 FF-CLASS-C         VALUE 'C'.
       01 WS-TO-FUND-DATA.
           05 WS-TF-NAV              PIC S9(5)V9(4) COMP-3.
           05 WS-TF-SHARE-CLASS      PIC X(1).
       01 WS-EXCHANGE-LIMITS.
           05 WS-MAX-EXCHANGES        PIC 9(2) VALUE 6.
           05 WS-EXCHANGES-YTD        PIC 9(2).
           05 WS-MIN-HOLD-DAYS        PIC 9(2) VALUE 30.
           05 WS-LAST-SWITCH-DATE     PIC 9(8).
           05 WS-DAYS-SINCE-SWITCH    PIC S9(5) COMP-3.
       01 WS-CALC.
           05 WS-REDEEM-VALUE        PIC S9(11)V99 COMP-3.
           05 WS-NEW-SHARES          PIC S9(9)V9(4) COMP-3.
           05 WS-CARRIED-BASIS       PIC S9(9)V99 COMP-3.
           05 WS-BASIS-PER-SHARE     PIC S9(5)V9(4) COMP-3.
           05 WS-REALIZED-GAIN       PIC S9(9)V99 COMP-3.
       01 WS-VALIDATION.
           05 WS-VALID-FLAG          PIC X VALUE 'Y'.
               88 IS-VALID           VALUE 'Y'.
               88 IS-INVALID         VALUE 'N'.
           05 WS-ERROR-MSG           PIC X(30).
       01 WS-SAME-FAMILY             PIC X VALUE 'Y'.
           88 SAME-FAMILY-YES        VALUE 'Y'.
       01 WS-SWITCH-FEE-RATE         PIC S9(1)V99 COMP-3
           VALUE 0.
       01 WS-SWITCH-FEE              PIC S9(5)V99 COMP-3.
       01 WS-RESULT-STATUS           PIC X(10).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-VALIDATE-REQUEST
           IF IS-VALID
               PERFORM 3000-CALC-REDEMPTION
               PERFORM 4000-CALC-PURCHASE
               PERFORM 5000-CARRY-COST-BASIS
               PERFORM 6000-APPLY-FEES
               MOVE 'COMPLETED ' TO WS-RESULT-STATUS
           ELSE
               MOVE 'REJECTED  ' TO WS-RESULT-STATUS
           END-IF
           PERFORM 7000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'ACCT-SW-001' TO WS-ACCT-NUM
           MOVE 'GRTX01' TO WS-FROM-FUND
           MOVE 'BNDX02' TO WS-TO-FUND
           MOVE 500.0000 TO WS-SWITCH-SHARES
           MOVE 20260321 TO WS-SWITCH-DATE
           MOVE 'P' TO WS-SWITCH-TYPE
           MOVE 47.8500 TO WS-FF-NAV
           MOVE 1200.0000 TO WS-FF-SHARES-HELD
           MOVE 48000.00 TO WS-FF-COST-BASIS
           MOVE 'A' TO WS-FF-SHARE-CLASS
           MOVE 25.4200 TO WS-TF-NAV
           MOVE 'A' TO WS-TF-SHARE-CLASS
           MOVE 3 TO WS-EXCHANGES-YTD
           MOVE 20260201 TO WS-LAST-SWITCH-DATE.
       2000-VALIDATE-REQUEST.
           MOVE 'Y' TO WS-VALID-FLAG
           IF WS-SWITCH-SHARES > WS-FF-SHARES-HELD
               MOVE 'N' TO WS-VALID-FLAG
               MOVE 'INSUFFICIENT SHARES       '
                   TO WS-ERROR-MSG
           END-IF
           IF WS-EXCHANGES-YTD >= WS-MAX-EXCHANGES
               MOVE 'N' TO WS-VALID-FLAG
               MOVE 'EXCHANGE LIMIT REACHED    '
                   TO WS-ERROR-MSG
           END-IF
           COMPUTE WS-DAYS-SINCE-SWITCH =
               WS-SWITCH-DATE - WS-LAST-SWITCH-DATE
           IF WS-DAYS-SINCE-SWITCH < WS-MIN-HOLD-DAYS
               MOVE 'N' TO WS-VALID-FLAG
               MOVE 'MIN HOLD PERIOD NOT MET   '
                   TO WS-ERROR-MSG
           END-IF
           IF WS-FROM-FUND = WS-TO-FUND
               MOVE 'N' TO WS-VALID-FLAG
               MOVE 'SAME FUND NOT ALLOWED     '
                   TO WS-ERROR-MSG
           END-IF.
       3000-CALC-REDEMPTION.
           COMPUTE WS-REDEEM-VALUE =
               WS-SWITCH-SHARES * WS-FF-NAV.
       4000-CALC-PURCHASE.
           IF WS-TF-NAV > 0
               COMPUTE WS-NEW-SHARES =
                   WS-REDEEM-VALUE / WS-TF-NAV
           ELSE
               MOVE 0 TO WS-NEW-SHARES
           END-IF.
       5000-CARRY-COST-BASIS.
           IF WS-FF-SHARES-HELD > 0
               COMPUTE WS-BASIS-PER-SHARE =
                   WS-FF-COST-BASIS / WS-FF-SHARES-HELD
           ELSE
               MOVE 0 TO WS-BASIS-PER-SHARE
           END-IF
           COMPUTE WS-CARRIED-BASIS =
               WS-SWITCH-SHARES * WS-BASIS-PER-SHARE
           COMPUTE WS-REALIZED-GAIN =
               WS-REDEEM-VALUE - WS-CARRIED-BASIS.
       6000-APPLY-FEES.
           IF NOT SAME-FAMILY-YES
               MOVE 0.01 TO WS-SWITCH-FEE-RATE
           END-IF
           COMPUTE WS-SWITCH-FEE =
               WS-REDEEM-VALUE * WS-SWITCH-FEE-RATE.
       7000-DISPLAY-RESULTS.
           DISPLAY 'FUND SWITCH PROCESSING'
           DISPLAY '======================'
           DISPLAY 'ACCOUNT:         ' WS-ACCT-NUM
           DISPLAY 'STATUS:          ' WS-RESULT-STATUS
           IF IS-VALID
               DISPLAY 'FROM FUND:       ' WS-FROM-FUND
               DISPLAY 'TO FUND:         ' WS-TO-FUND
               DISPLAY 'SHARES SWITCHED: ' WS-SWITCH-SHARES
               DISPLAY 'REDEEM VALUE:    ' WS-REDEEM-VALUE
               DISPLAY 'NEW SHARES:      ' WS-NEW-SHARES
               DISPLAY 'CARRIED BASIS:   ' WS-CARRIED-BASIS
               DISPLAY 'REALIZED GAIN:   ' WS-REALIZED-GAIN
               DISPLAY 'SWITCH FEE:      ' WS-SWITCH-FEE
               DISPLAY 'EXCHANGES YTD:   ' WS-EXCHANGES-YTD
           ELSE
               DISPLAY 'ERROR:           ' WS-ERROR-MSG
           END-IF.
