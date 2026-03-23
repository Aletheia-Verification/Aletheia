       IDENTIFICATION DIVISION.
       PROGRAM-ID. CARD-TEMP-INCREASE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CARD-ACCT.
           05 WS-PAN             PIC X(16).
           05 WS-PERM-LIMIT      PIC S9(7)V99 COMP-3.
           05 WS-TEMP-LIMIT      PIC S9(7)V99 COMP-3.
           05 WS-CURRENT-BAL     PIC S9(7)V99 COMP-3.
           05 WS-TEMP-ACTIVE     PIC X VALUE 'N'.
               88 TEMP-IS-ACTIVE VALUE 'Y'.
           05 WS-TEMP-EXPIRY     PIC 9(8).
       01 WS-REQUEST.
           05 WS-REQ-AMOUNT      PIC S9(7)V99 COMP-3.
           05 WS-REQ-DURATION    PIC 9(2).
           05 WS-REQ-REASON      PIC X(2).
               88 RR-TRAVEL      VALUE 'TR'.
               88 RR-EMERGENCY   VALUE 'EM'.
               88 RR-PURCHASE    VALUE 'PU'.
       01 WS-CREDIT-SCORE        PIC 9(3).
       01 WS-MAX-TEMP-PCT        PIC S9(1)V99 COMP-3.
       01 WS-MAX-TEMP-AMT        PIC S9(7)V99 COMP-3.
       01 WS-MAX-DURATION        PIC 9(2) VALUE 90.
       01 WS-EFFECTIVE-LIMIT     PIC S9(7)V99 COMP-3.
       01 WS-RESULT              PIC X(12).
       01 WS-CURRENT-DATE        PIC 9(8).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-CHECK-ELIGIBILITY
           PERFORM 2000-CALC-MAX-INCREASE
           PERFORM 3000-APPLY-INCREASE
           PERFORM 4000-OUTPUT
           STOP RUN.
       1000-CHECK-ELIGIBILITY.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           IF TEMP-IS-ACTIVE
               IF WS-TEMP-EXPIRY > WS-CURRENT-DATE
                   MOVE 'ALREADY TEMP' TO WS-RESULT
               ELSE
                   MOVE 'N' TO WS-TEMP-ACTIVE
               END-IF
           END-IF
           IF WS-CREDIT-SCORE < 650
               MOVE 'SCORE LOW   ' TO WS-RESULT
           END-IF.
       2000-CALC-MAX-INCREASE.
           IF WS-RESULT = SPACES
               IF WS-CREDIT-SCORE >= 750
                   MOVE 0.50 TO WS-MAX-TEMP-PCT
               ELSE
                   IF WS-CREDIT-SCORE >= 700
                       MOVE 0.30 TO WS-MAX-TEMP-PCT
                   ELSE
                       MOVE 0.15 TO WS-MAX-TEMP-PCT
                   END-IF
               END-IF
               COMPUTE WS-MAX-TEMP-AMT =
                   WS-PERM-LIMIT * WS-MAX-TEMP-PCT
               IF RR-EMERGENCY
                   COMPUTE WS-MAX-TEMP-AMT =
                       WS-MAX-TEMP-AMT * 1.25
               END-IF
           END-IF.
       3000-APPLY-INCREASE.
           IF WS-RESULT = SPACES
               IF WS-REQ-AMOUNT > WS-MAX-TEMP-AMT
                   MOVE WS-MAX-TEMP-AMT TO WS-TEMP-LIMIT
                   MOVE 'PARTIAL     ' TO WS-RESULT
               ELSE
                   MOVE WS-REQ-AMOUNT TO WS-TEMP-LIMIT
                   MOVE 'APPROVED    ' TO WS-RESULT
               END-IF
               IF WS-REQ-DURATION > WS-MAX-DURATION
                   MOVE WS-MAX-DURATION TO WS-REQ-DURATION
               END-IF
               COMPUTE WS-TEMP-EXPIRY =
                   WS-CURRENT-DATE + WS-REQ-DURATION
               MOVE 'Y' TO WS-TEMP-ACTIVE
               COMPUTE WS-EFFECTIVE-LIMIT =
                   WS-PERM-LIMIT + WS-TEMP-LIMIT
           END-IF.
       4000-OUTPUT.
           DISPLAY 'TEMPORARY LIMIT INCREASE'
           DISPLAY '========================'
           DISPLAY 'PAN:       ' WS-PAN
           DISPLAY 'PERM LMT:  $' WS-PERM-LIMIT
           DISPLAY 'RESULT:    ' WS-RESULT
           IF WS-RESULT = 'APPROVED    '
               OR WS-RESULT = 'PARTIAL     '
               DISPLAY 'TEMP LMT:  $' WS-TEMP-LIMIT
               DISPLAY 'EFF LMT:   $' WS-EFFECTIVE-LIMIT
               DISPLAY 'DURATION:  ' WS-REQ-DURATION ' DAYS'
               DISPLAY 'EXPIRES:   ' WS-TEMP-EXPIRY
           END-IF.
