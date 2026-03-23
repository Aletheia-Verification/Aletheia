       IDENTIFICATION DIVISION.
       PROGRAM-ID. PAY-WIRE-OUTBOUND.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-WIRE-REQUEST.
           05 WS-ORIG-ACCT        PIC X(12).
           05 WS-ORIG-NAME        PIC X(30).
           05 WS-BENE-ACCT        PIC X(20).
           05 WS-BENE-NAME        PIC X(30).
           05 WS-BENE-BANK-ABA    PIC X(9).
           05 WS-AMOUNT            PIC S9(11)V99 COMP-3.
           05 WS-CURRENCY          PIC X(3).
           05 WS-PURPOSE-CODE      PIC X(4).
           05 WS-REF-NUMBER        PIC X(16).
       01 WS-VALIDATION.
           05 WS-VALID-WIRE        PIC X VALUE 'N'.
               88 WIRE-VALID       VALUE 'Y'.
           05 WS-ERROR-CODE        PIC X(4).
           05 WS-ERROR-DESC        PIC X(40).
       01 WS-ABA-CHECK.
           05 WS-ABA-DIGITS        PIC 9(9).
           05 WS-ABA-SUM           PIC 9(5).
           05 WS-ABA-MOD           PIC 9(2).
           05 WS-ABA-D REDEFINES WS-ABA-DIGITS.
               10 WS-D1            PIC 9.
               10 WS-D2            PIC 9.
               10 WS-D3            PIC 9.
               10 WS-D4            PIC 9.
               10 WS-D5            PIC 9.
               10 WS-D6            PIC 9.
               10 WS-D7            PIC 9.
               10 WS-D8            PIC 9.
               10 WS-D9            PIC 9.
       01 WS-OFAC-HIT              PIC X VALUE 'N'.
           88 IS-OFAC-HIT          VALUE 'Y'.
       01 WS-DAILY-LIMIT           PIC S9(11)V99 COMP-3
           VALUE 1000000.00.
       01 WS-DAILY-TOTAL           PIC S9(11)V99 COMP-3.
       01 WS-FEE-AMOUNT            PIC S9(5)V99 COMP-3.
       01 WS-NET-AMOUNT            PIC S9(11)V99 COMP-3.
       01 WS-WIRE-STATUS           PIC X(10).
       01 WS-SWIFT-MSG             PIC X(80).
       01 WS-CURRENT-DATE          PIC 9(8).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-VALIDATE-WIRE
           IF WIRE-VALID
               PERFORM 2000-CHECK-COMPLIANCE
           END-IF
           IF WIRE-VALID
               PERFORM 3000-CALC-FEES
               PERFORM 4000-FORMAT-MSG
           END-IF
           PERFORM 5000-OUTPUT
           STOP RUN.
       1000-VALIDATE-WIRE.
           MOVE 'N' TO WS-VALID-WIRE
           IF WS-AMOUNT <= 0
               MOVE 'E001' TO WS-ERROR-CODE
               MOVE 'AMOUNT MUST BE POSITIVE' TO WS-ERROR-DESC
           ELSE
               IF WS-BENE-ACCT = SPACES
                   MOVE 'E002' TO WS-ERROR-CODE
                   MOVE 'BENEFICIARY ACCT REQUIRED'
                       TO WS-ERROR-DESC
               ELSE
                   PERFORM 1100-VALIDATE-ABA
               END-IF
           END-IF.
       1100-VALIDATE-ABA.
           IF WS-BENE-BANK-ABA IS NUMERIC
               MOVE WS-BENE-BANK-ABA TO WS-ABA-DIGITS
               COMPUTE WS-ABA-SUM =
                   (WS-D1 * 3) + (WS-D2 * 7) + WS-D3 +
                   (WS-D4 * 3) + (WS-D5 * 7) + WS-D6 +
                   (WS-D7 * 3) + (WS-D8 * 7) + WS-D9
               DIVIDE WS-ABA-SUM BY 10
                   GIVING WS-ABA-MOD
                   REMAINDER WS-ABA-MOD
               IF WS-ABA-MOD = 0
                   MOVE 'Y' TO WS-VALID-WIRE
               ELSE
                   MOVE 'E003' TO WS-ERROR-CODE
                   MOVE 'INVALID ABA ROUTING NUMBER'
                       TO WS-ERROR-DESC
               END-IF
           ELSE
               MOVE 'E004' TO WS-ERROR-CODE
               MOVE 'ABA MUST BE NUMERIC' TO WS-ERROR-DESC
           END-IF.
       2000-CHECK-COMPLIANCE.
           IF IS-OFAC-HIT
               MOVE 'N' TO WS-VALID-WIRE
               MOVE 'C001' TO WS-ERROR-CODE
               MOVE 'OFAC MATCH - WIRE BLOCKED'
                   TO WS-ERROR-DESC
           END-IF
           COMPUTE WS-DAILY-TOTAL =
               WS-DAILY-TOTAL + WS-AMOUNT
           IF WS-DAILY-TOTAL > WS-DAILY-LIMIT
               MOVE 'N' TO WS-VALID-WIRE
               MOVE 'C002' TO WS-ERROR-CODE
               MOVE 'DAILY WIRE LIMIT EXCEEDED'
                   TO WS-ERROR-DESC
           END-IF.
       3000-CALC-FEES.
           IF WS-CURRENCY = 'USD'
               MOVE 25.00 TO WS-FEE-AMOUNT
           ELSE
               MOVE 45.00 TO WS-FEE-AMOUNT
           END-IF
           IF WS-AMOUNT > 100000.00
               ADD 10.00 TO WS-FEE-AMOUNT
           END-IF
           COMPUTE WS-NET-AMOUNT =
               WS-AMOUNT + WS-FEE-AMOUNT.
       4000-FORMAT-MSG.
           STRING WS-REF-NUMBER DELIMITED BY ' '
               ' ' DELIMITED BY SIZE
               WS-BENE-NAME DELIMITED BY '  '
               ' $' DELIMITED BY SIZE
               WS-AMOUNT DELIMITED BY SIZE
               INTO WS-SWIFT-MSG
           END-STRING
           MOVE 'SENT      ' TO WS-WIRE-STATUS.
       5000-OUTPUT.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           DISPLAY 'OUTBOUND WIRE TRANSFER'
           DISPLAY '======================'
           DISPLAY 'DATE: ' WS-CURRENT-DATE
           IF WIRE-VALID
               DISPLAY 'STATUS:    ' WS-WIRE-STATUS
               DISPLAY 'AMOUNT:    $' WS-AMOUNT
               DISPLAY 'FEE:       $' WS-FEE-AMOUNT
               DISPLAY 'NET DEBIT: $' WS-NET-AMOUNT
               DISPLAY 'MSG: ' WS-SWIFT-MSG
           ELSE
               DISPLAY 'STATUS: REJECTED'
               DISPLAY 'ERROR:  ' WS-ERROR-CODE
               DISPLAY 'DESC:   ' WS-ERROR-DESC
           END-IF.
