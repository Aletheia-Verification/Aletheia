       IDENTIFICATION DIVISION.
       PROGRAM-ID. WIRE-VALIDATE.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-RAW-MESSAGE        PIC X(200).
       01  WS-SENDER-ACCT        PIC X(20).
       01  WS-RECEIVER-ACCT      PIC X(20).
       01  WS-AMOUNT-STR         PIC X(15).
       01  WS-CURRENCY            PIC X(3).
       01  WS-REFERENCE           PIC X(35).
       01  WS-TRANSFER-AMT       PIC S9(11)V99.
       01  WS-FEE-AMT            PIC S9(7)V99.
       01  WS-NET-AMT            PIC S9(11)V99.
       01  WS-SENDER-BAL         PIC S9(11)V99.
       01  WS-RESULT             PIC X(80).
       01  WS-ERROR-COUNT        PIC 9(3).
       01  WS-SPACE-COUNT        PIC 9(3).
       01  WS-DIGIT-COUNT        PIC 9(3).
       01  WS-FORMATTED-AMT      PIC X(20).
       01  WS-CLEAN-ACCT         PIC X(20).
       01  WS-STATUS-CODE        PIC 9(2).
           88  WIRE-OK            VALUE 0.
           88  WIRE-INSUFFICIENT  VALUE 1.
           88  WIRE-BAD-ACCT      VALUE 2.
           88  WIRE-OVERLIMIT     VALUE 3.
           88  WIRE-BAD-FORMAT    VALUE 9.
       01  WS-DAILY-LIMIT        PIC S9(11)V99.
       01  WS-DAILY-TOTAL        PIC S9(11)V99.
       01  WS-FEE-RATE           PIC S9(1)V9(4).
       01  WS-MIN-FEE            PIC S9(5)V99.
       01  WS-TEMP-FEE           PIC S9(7)V99.

       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INIT.
           PERFORM 2000-PARSE-MESSAGE.
           PERFORM 3000-VALIDATE-ACCOUNTS.
           PERFORM 4000-CALC-FEES.
           PERFORM 5000-CHECK-LIMITS.
           PERFORM 6000-FORMAT-RESULT.
           STOP RUN.

       1000-INIT.
           MOVE 0 TO WS-ERROR-COUNT.
           MOVE 0 TO WS-STATUS-CODE.
           MOVE 0 TO WS-FEE-AMT.
           MOVE SPACES TO WS-RESULT.
           MOVE 0.0025 TO WS-FEE-RATE.
           MOVE 25.00 TO WS-MIN-FEE.

       2000-PARSE-MESSAGE.
           UNSTRING WS-RAW-MESSAGE
               DELIMITED BY "|"
               INTO WS-SENDER-ACCT
                    WS-RECEIVER-ACCT
                    WS-AMOUNT-STR
                    WS-CURRENCY
                    WS-REFERENCE.

       3000-VALIDATE-ACCOUNTS.
           INSPECT WS-SENDER-ACCT
               TALLYING WS-SPACE-COUNT
               FOR ALL SPACES.
           IF WS-SPACE-COUNT > 15
               MOVE 2 TO WS-STATUS-CODE
           END-IF.
           INSPECT WS-SENDER-ACCT
               REPLACING ALL '-' BY ' '.
           MOVE WS-SENDER-ACCT TO WS-CLEAN-ACCT.

       4000-CALC-FEES.
           EVALUATE WS-CURRENCY
               WHEN 'USD'
                   MOVE 0.0025 TO WS-FEE-RATE
                   MOVE 25.00 TO WS-MIN-FEE
               WHEN 'EUR'
                   MOVE 0.0030 TO WS-FEE-RATE
                   MOVE 30.00 TO WS-MIN-FEE
               WHEN 'GBP'
                   MOVE 0.0035 TO WS-FEE-RATE
                   MOVE 35.00 TO WS-MIN-FEE
               WHEN OTHER
                   MOVE 0.0050 TO WS-FEE-RATE
                   MOVE 50.00 TO WS-MIN-FEE
           END-EVALUATE.
           MULTIPLY WS-TRANSFER-AMT BY WS-FEE-RATE
               GIVING WS-TEMP-FEE.
           IF WS-TEMP-FEE < WS-MIN-FEE
               MOVE WS-MIN-FEE TO WS-FEE-AMT
           ELSE
               MOVE WS-TEMP-FEE TO WS-FEE-AMT
           END-IF.
           ADD WS-TRANSFER-AMT TO WS-FEE-AMT
               GIVING WS-NET-AMT.

       5000-CHECK-LIMITS.
           IF WS-NET-AMT > WS-SENDER-BAL
               MOVE 1 TO WS-STATUS-CODE
           END-IF.
           ADD WS-TRANSFER-AMT TO WS-DAILY-TOTAL.
           IF WS-DAILY-TOTAL > WS-DAILY-LIMIT
               MOVE 3 TO WS-STATUS-CODE
           END-IF.

       6000-FORMAT-RESULT.
           EVALUATE TRUE
               WHEN WIRE-OK
                   STRING 'APPROVED|'
                       DELIMITED BY SIZE
                       WS-SENDER-ACCT
                       DELIMITED BY SIZE
                       '|'
                       DELIMITED BY SIZE
                       WS-RECEIVER-ACCT
                       DELIMITED BY SIZE
                       INTO WS-RESULT
               WHEN WIRE-INSUFFICIENT
                   MOVE 'DECLINED: INSUFFICIENT FUNDS'
                       TO WS-RESULT
               WHEN WIRE-BAD-ACCT
                   MOVE 'DECLINED: INVALID ACCOUNT'
                       TO WS-RESULT
               WHEN WIRE-OVERLIMIT
                   MOVE 'DECLINED: DAILY LIMIT EXCEEDED'
                       TO WS-RESULT
               WHEN OTHER
                   MOVE 'ERROR: UNKNOWN STATUS'
                       TO WS-RESULT
           END-EVALUATE.
