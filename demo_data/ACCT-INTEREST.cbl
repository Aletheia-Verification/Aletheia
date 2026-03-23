       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCT-INTEREST.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-ACCOUNT-TYPE       PIC X(1).
           88  IS-SAVINGS         VALUE 'S'.
           88  IS-CHECKING        VALUE 'C'.
           88  IS-PREMIUM          VALUE 'P'.
           88  IS-BUSINESS         VALUE 'B'.
       01  WS-BALANCE            PIC S9(9)V99.
       01  WS-ANNUAL-RATE        PIC S9(1)V9(6).
       01  WS-MONTHLY-RATE       PIC S9(1)V9(8).
       01  WS-INTEREST           PIC S9(7)V99.
       01  WS-NEW-BALANCE        PIC S9(9)V99.
       01  WS-MONTHS             PIC 9(2).
       01  WS-MONTH-CTR          PIC 9(2).
       01  WS-COMPOUND-BAL       PIC S9(9)V99.
       01  WS-TOTAL-INTEREST     PIC S9(9)V99.
       01  WS-MIN-BALANCE        PIC S9(9)V99.
       01  WS-FEE                PIC S9(5)V99.
       01  WS-NET-INTEREST       PIC S9(7)V99.
       01  WS-TIER               PIC 9(1).
       01  WS-BONUS-RATE         PIC S9(1)V9(6).
       01  WS-PENALTY            PIC S9(5)V99.
       01  WS-DAYS-INACTIVE      PIC 9(3).
       01  WS-RESULT-CODE        PIC 9(2).
       01  WS-RESULT-MSG         PIC X(40).

       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INIT-FIELDS.
           PERFORM 2000-DETERMINE-RATE.
           PERFORM 3000-CALC-COMPOUND-INTEREST.
           PERFORM 4000-APPLY-FEES.
           PERFORM 5000-FINALIZE.
           STOP RUN.

       1000-INIT-FIELDS.
           MOVE 0 TO WS-TOTAL-INTEREST.
           MOVE 0 TO WS-FEE.
           MOVE 0 TO WS-PENALTY.
           MOVE 0 TO WS-BONUS-RATE.
           MOVE WS-BALANCE TO WS-COMPOUND-BAL.
           MOVE WS-BALANCE TO WS-MIN-BALANCE.
           MOVE 0 TO WS-RESULT-CODE.
           MOVE SPACES TO WS-RESULT-MSG.

       2000-DETERMINE-RATE.
           EVALUATE TRUE
               WHEN IS-SAVINGS
                   EVALUATE TRUE
                       WHEN WS-BALANCE > 100000
                           MOVE 0.0425 TO WS-ANNUAL-RATE
                           MOVE 3 TO WS-TIER
                       WHEN WS-BALANCE > 25000
                           MOVE 0.0325 TO WS-ANNUAL-RATE
                           MOVE 2 TO WS-TIER
                       WHEN OTHER
                           MOVE 0.0200 TO WS-ANNUAL-RATE
                           MOVE 1 TO WS-TIER
                   END-EVALUATE
               WHEN IS-CHECKING
                   MOVE 0.0100 TO WS-ANNUAL-RATE
                   MOVE 1 TO WS-TIER
               WHEN IS-PREMIUM
                   MOVE 0.0500 TO WS-ANNUAL-RATE
                   MOVE 3 TO WS-TIER
                   MOVE 0.005 TO WS-BONUS-RATE
               WHEN IS-BUSINESS
                   EVALUATE TRUE
                       WHEN WS-BALANCE > 500000
                           MOVE 0.0375 TO WS-ANNUAL-RATE
                           MOVE 3 TO WS-TIER
                       WHEN WS-BALANCE > 100000
                           MOVE 0.0275 TO WS-ANNUAL-RATE
                           MOVE 2 TO WS-TIER
                       WHEN OTHER
                           MOVE 0.0175 TO WS-ANNUAL-RATE
                           MOVE 1 TO WS-TIER
                   END-EVALUATE
               WHEN OTHER
                   MOVE 0.0100 TO WS-ANNUAL-RATE
                   MOVE 0 TO WS-TIER
                   MOVE 99 TO WS-RESULT-CODE
                   MOVE 'UNKNOWN ACCOUNT TYPE' TO WS-RESULT-MSG
           END-EVALUATE.
           DIVIDE WS-ANNUAL-RATE BY 12
               GIVING WS-MONTHLY-RATE.
           ADD WS-BONUS-RATE TO WS-MONTHLY-RATE.

       3000-CALC-COMPOUND-INTEREST.
           PERFORM 3100-CALC-ONE-MONTH
               VARYING WS-MONTH-CTR FROM 1 BY 1
               UNTIL WS-MONTH-CTR > WS-MONTHS.

       3100-CALC-ONE-MONTH.
           MULTIPLY WS-COMPOUND-BAL BY WS-MONTHLY-RATE
               GIVING WS-INTEREST.
           ADD WS-INTEREST TO WS-COMPOUND-BAL.
           ADD WS-INTEREST TO WS-TOTAL-INTEREST.
           IF WS-COMPOUND-BAL < WS-MIN-BALANCE
               MOVE WS-COMPOUND-BAL TO WS-MIN-BALANCE
           END-IF.

       4000-APPLY-FEES.
           IF WS-MIN-BALANCE < 1000
               MOVE 12.50 TO WS-FEE
           END-IF.
           IF WS-DAYS-INACTIVE > 180
               COMPUTE WS-PENALTY =
                   WS-TOTAL-INTEREST * 0.10
           END-IF.
           SUBTRACT WS-FEE FROM WS-TOTAL-INTEREST.
           SUBTRACT WS-PENALTY FROM WS-TOTAL-INTEREST
               GIVING WS-NET-INTEREST.

       5000-FINALIZE.
           ADD WS-NET-INTEREST TO WS-BALANCE
               GIVING WS-NEW-BALANCE.
           IF WS-RESULT-CODE = 0
               MOVE 'INTEREST APPLIED SUCCESSFULLY'
                   TO WS-RESULT-MSG
           END-IF.
