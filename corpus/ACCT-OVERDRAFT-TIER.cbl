       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCT-OVERDRAFT-TIER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CUSTOMER-REC.
           05 WS-CUST-ID              PIC X(10).
           05 WS-CUST-NAME            PIC X(25).
           05 WS-CUST-TIER            PIC 9.
               88 TIER-BRONZE          VALUE 1.
               88 TIER-SILVER          VALUE 2.
               88 TIER-GOLD            VALUE 3.
               88 TIER-PLATINUM        VALUE 4.
           05 WS-MONTHLY-INCOME       PIC S9(7)V99 COMP-3.
           05 WS-ACCT-AGE-MONTHS      PIC 9(4).
       01 WS-OD-CONFIG.
           05 WS-OD-LIMIT             PIC S9(7)V99 COMP-3.
           05 WS-OD-RATE              PIC S9(2)V9(4) COMP-3.
           05 WS-OD-FEE               PIC S9(3)V99 COMP-3.
           05 WS-MAX-DAILY-OD         PIC 9(2).
       01 WS-TRANSACTION.
           05 WS-TXN-AMOUNT           PIC S9(7)V99 COMP-3.
           05 WS-TXN-TYPE             PIC X(3).
           05 WS-TXN-DATE             PIC 9(8).
       01 WS-CURRENT-BAL              PIC S9(9)V99 COMP-3.
       01 WS-AVAILABLE-BAL            PIC S9(9)V99 COMP-3.
       01 WS-OD-USED                  PIC S9(7)V99 COMP-3.
       01 WS-OD-CHARGE                PIC S9(5)V99 COMP-3.
       01 WS-DAILY-OD-COUNT           PIC 9(2).
       01 WS-APPROVED-FLAG            PIC X VALUE 'N'.
           88 WS-APPROVED              VALUE 'Y'.
       01 WS-DECLINE-REASON           PIC X(30).
       01 WS-AUDIT-MSG                PIC X(80).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-SET-TIER-LIMITS
           PERFORM 2000-CHECK-TRANSACTION
           PERFORM 3000-APPLY-CHARGES
           PERFORM 4000-LOG-RESULT
           STOP RUN.
       1000-SET-TIER-LIMITS.
           EVALUATE TRUE
               WHEN TIER-BRONZE
                   MOVE 500.00 TO WS-OD-LIMIT
                   MOVE 0.2199 TO WS-OD-RATE
                   MOVE 35.00 TO WS-OD-FEE
                   MOVE 3 TO WS-MAX-DAILY-OD
               WHEN TIER-SILVER
                   MOVE 1500.00 TO WS-OD-LIMIT
                   MOVE 0.1799 TO WS-OD-RATE
                   MOVE 25.00 TO WS-OD-FEE
                   MOVE 5 TO WS-MAX-DAILY-OD
               WHEN TIER-GOLD
                   MOVE 5000.00 TO WS-OD-LIMIT
                   MOVE 0.1299 TO WS-OD-RATE
                   MOVE 15.00 TO WS-OD-FEE
                   MOVE 8 TO WS-MAX-DAILY-OD
               WHEN TIER-PLATINUM
                   MOVE 25000.00 TO WS-OD-LIMIT
                   MOVE 0.0899 TO WS-OD-RATE
                   MOVE 0 TO WS-OD-FEE
                   MOVE 99 TO WS-MAX-DAILY-OD
               WHEN OTHER
                   MOVE 0 TO WS-OD-LIMIT
                   MOVE 0 TO WS-OD-RATE
                   MOVE 0 TO WS-OD-FEE
                   MOVE 0 TO WS-MAX-DAILY-OD
           END-EVALUATE.
       2000-CHECK-TRANSACTION.
           MOVE 'N' TO WS-APPROVED-FLAG
           COMPUTE WS-AVAILABLE-BAL =
               WS-CURRENT-BAL + WS-OD-LIMIT - WS-OD-USED
           IF WS-TXN-AMOUNT > WS-AVAILABLE-BAL
               MOVE 'INSUFFICIENT FUNDS+OD' TO
                   WS-DECLINE-REASON
           ELSE
               IF WS-DAILY-OD-COUNT >= WS-MAX-DAILY-OD
                   MOVE 'MAX DAILY OD EXCEEDED' TO
                       WS-DECLINE-REASON
               ELSE
                   IF WS-CURRENT-BAL < WS-TXN-AMOUNT
                       PERFORM 2100-USE-OVERDRAFT
                   ELSE
                       SUBTRACT WS-TXN-AMOUNT FROM
                           WS-CURRENT-BAL
                       MOVE 'Y' TO WS-APPROVED-FLAG
                   END-IF
               END-IF
           END-IF.
       2100-USE-OVERDRAFT.
           COMPUTE WS-OD-CHARGE =
               WS-TXN-AMOUNT - WS-CURRENT-BAL
           ADD WS-OD-CHARGE TO WS-OD-USED
           MOVE 0 TO WS-CURRENT-BAL
           ADD 1 TO WS-DAILY-OD-COUNT
           MOVE 'Y' TO WS-APPROVED-FLAG.
       3000-APPLY-CHARGES.
           IF WS-APPROVED
               IF WS-OD-USED > 0
                   IF WS-OD-FEE > 0
                       ADD WS-OD-FEE TO WS-OD-USED
                       DISPLAY 'OD FEE CHARGED: ' WS-OD-FEE
                   END-IF
               END-IF
           END-IF.
       4000-LOG-RESULT.
           STRING 'TXN ' DELIMITED BY SIZE
               WS-TXN-TYPE DELIMITED BY SIZE
               ' AMT=' DELIMITED BY SIZE
               WS-TXN-AMOUNT DELIMITED BY SIZE
               INTO WS-AUDIT-MSG
           END-STRING
           IF WS-APPROVED
               DISPLAY 'APPROVED: ' WS-AUDIT-MSG
               DISPLAY 'BAL=' WS-CURRENT-BAL
                   ' OD=' WS-OD-USED
           ELSE
               DISPLAY 'DECLINED: ' WS-AUDIT-MSG
               DISPLAY 'REASON: ' WS-DECLINE-REASON
           END-IF.
