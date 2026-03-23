       IDENTIFICATION DIVISION.
       PROGRAM-ID. CARD-EMV-AUTH.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-AUTH-REQUEST.
           05 WS-PAN              PIC X(16).
           05 WS-ENTRY-MODE       PIC X(2).
               88 EM-CHIP         VALUE 'CP'.
               88 EM-SWIPE        VALUE 'SW'.
               88 EM-CONTACTLESS  VALUE 'CL'.
               88 EM-MANUAL       VALUE 'MN'.
           05 WS-AUTH-AMT         PIC S9(9)V99 COMP-3.
           05 WS-MERCHANT-ID      PIC X(15).
           05 WS-TERMINAL-ID      PIC X(8).
           05 WS-AUTH-DATE        PIC 9(8).
           05 WS-AUTH-TIME        PIC 9(6).
       01 WS-CARD-DATA.
           05 WS-CARD-STATUS      PIC X(1).
               88 CS-ACTIVE       VALUE 'A'.
               88 CS-BLOCKED      VALUE 'B'.
               88 CS-LOST         VALUE 'L'.
           05 WS-CREDIT-LIMIT     PIC S9(7)V99 COMP-3.
           05 WS-CURRENT-BAL      PIC S9(7)V99 COMP-3.
           05 WS-AVAILABLE        PIC S9(7)V99 COMP-3.
           05 WS-EXPIRY-DATE      PIC 9(4).
       01 WS-RISK-FLAGS.
           05 WS-CVV-MATCH        PIC X VALUE 'N'.
               88 CVV-OK          VALUE 'Y'.
           05 WS-AVS-MATCH        PIC X VALUE 'N'.
               88 AVS-OK          VALUE 'Y'.
           05 WS-PIN-VERIFIED     PIC X VALUE 'N'.
               88 PIN-OK          VALUE 'Y'.
           05 WS-VELOCITY-OK      PIC X VALUE 'Y'.
               88 VEL-OK          VALUE 'Y'.
       01 WS-AUTH-RESPONSE.
           05 WS-RESP-CODE        PIC X(2).
           05 WS-RESP-MSG         PIC X(30).
           05 WS-AUTH-CODE        PIC X(6).
       01 WS-RISK-SCORE           PIC 9(3).
       01 WS-FRAUD-THRESHOLD      PIC 9(3) VALUE 80.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-CHECK-CARD-STATUS
           IF CS-ACTIVE
               PERFORM 2000-CHECK-BALANCE
               PERFORM 3000-RISK-ASSESS
               PERFORM 4000-MAKE-DECISION
           END-IF
           PERFORM 5000-OUTPUT
           STOP RUN.
       1000-CHECK-CARD-STATUS.
           IF CS-BLOCKED
               MOVE '05' TO WS-RESP-CODE
               MOVE 'CARD BLOCKED' TO WS-RESP-MSG
           END-IF
           IF CS-LOST
               MOVE '41' TO WS-RESP-CODE
               MOVE 'CARD REPORTED LOST' TO WS-RESP-MSG
           END-IF.
       2000-CHECK-BALANCE.
           COMPUTE WS-AVAILABLE =
               WS-CREDIT-LIMIT - WS-CURRENT-BAL
           IF WS-AUTH-AMT > WS-AVAILABLE
               MOVE '51' TO WS-RESP-CODE
               MOVE 'INSUFFICIENT CREDIT' TO WS-RESP-MSG
           END-IF.
       3000-RISK-ASSESS.
           IF WS-RESP-CODE NOT = SPACES
               MOVE 0 TO WS-RISK-SCORE
           ELSE
               MOVE 0 TO WS-RISK-SCORE
               EVALUATE TRUE
                   WHEN EM-CHIP
                       ADD 0 TO WS-RISK-SCORE
                   WHEN EM-CONTACTLESS
                       ADD 5 TO WS-RISK-SCORE
                   WHEN EM-SWIPE
                       ADD 20 TO WS-RISK-SCORE
                   WHEN EM-MANUAL
                       ADD 40 TO WS-RISK-SCORE
               END-EVALUATE
               IF NOT CVV-OK
                   ADD 25 TO WS-RISK-SCORE
               END-IF
               IF NOT AVS-OK
                   ADD 15 TO WS-RISK-SCORE
               END-IF
               IF NOT VEL-OK
                   ADD 30 TO WS-RISK-SCORE
               END-IF
               IF WS-AUTH-AMT > 5000.00
                   ADD 10 TO WS-RISK-SCORE
               END-IF
           END-IF.
       4000-MAKE-DECISION.
           IF WS-RESP-CODE = SPACES
               IF WS-RISK-SCORE >= WS-FRAUD-THRESHOLD
                   MOVE '59' TO WS-RESP-CODE
                   MOVE 'SUSPECTED FRAUD' TO WS-RESP-MSG
               ELSE
                   MOVE '00' TO WS-RESP-CODE
                   MOVE 'APPROVED' TO WS-RESP-MSG
                   MOVE 'A12345' TO WS-AUTH-CODE
                   ADD WS-AUTH-AMT TO WS-CURRENT-BAL
               END-IF
           END-IF.
       5000-OUTPUT.
           DISPLAY 'EMV AUTHORIZATION'
           DISPLAY '================='
           DISPLAY 'PAN:      ' WS-PAN
           DISPLAY 'AMOUNT:   $' WS-AUTH-AMT
           DISPLAY 'ENTRY:    ' WS-ENTRY-MODE
           DISPLAY 'RISK:     ' WS-RISK-SCORE
           DISPLAY 'RESPONSE: ' WS-RESP-CODE
           DISPLAY 'MESSAGE:  ' WS-RESP-MSG
           IF WS-RESP-CODE = '00'
               DISPLAY 'AUTH CODE:' WS-AUTH-CODE
               DISPLAY 'NEW BAL:  $' WS-CURRENT-BAL
           END-IF.
