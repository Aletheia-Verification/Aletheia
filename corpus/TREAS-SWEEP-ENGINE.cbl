       IDENTIFICATION DIVISION.
       PROGRAM-ID. TREAS-SWEEP-ENGINE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-MASTER-ACCT.
           05 WS-MASTER-NUM          PIC X(12).
           05 WS-MASTER-BAL          PIC S9(11)V99 COMP-3.
           05 WS-TARGET-BAL          PIC S9(11)V99 COMP-3.
           05 WS-MIN-SWEEP           PIC S9(7)V99 COMP-3
               VALUE 1000.00.
       01 WS-SWEEP-TYPE              PIC X(1).
           88 WS-TO-INVEST           VALUE 'I'.
           88 WS-TO-MASTER           VALUE 'M'.
           88 WS-BALANCED            VALUE 'B'.
       01 WS-INVEST-ACCT.
           05 WS-INVEST-NUM          PIC X(12).
           05 WS-INVEST-BAL          PIC S9(11)V99 COMP-3.
           05 WS-INVEST-RATE         PIC S9(1)V9(6) COMP-3.
       01 WS-SWEEP-FIELDS.
           05 WS-EXCESS              PIC S9(11)V99 COMP-3.
           05 WS-DEFICIT             PIC S9(11)V99 COMP-3.
           05 WS-SWEEP-AMT           PIC S9(11)V99 COMP-3.
           05 WS-DAILY-EARN          PIC S9(7)V99 COMP-3.
       01 WS-SWEEP-IDX              PIC 9(2).
       01 WS-DAYS-IN-PERIOD          PIC 9(2) VALUE 30.
       01 WS-PROJECTED-EARN          PIC S9(9)V99 COMP-3.
       01 WS-SWEEP-FEE              PIC S9(5)V99 COMP-3.
       01 WS-NET-BENEFIT            PIC S9(9)V99 COMP-3.
       01 WS-SWEEP-STATUS           PIC X(1).
           88 WS-EXECUTED            VALUE 'E'.
           88 WS-SKIPPED             VALUE 'S'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-DETERMINE-SWEEP
           PERFORM 3000-CALC-AMOUNT
           PERFORM 4000-EXECUTE-SWEEP
           PERFORM 5000-PROJECT-EARNINGS
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-EXCESS
           MOVE 0 TO WS-DEFICIT
           MOVE 0 TO WS-SWEEP-AMT
           MOVE 0 TO WS-SWEEP-FEE
           SET WS-SKIPPED TO TRUE.
       2000-DETERMINE-SWEEP.
           IF WS-MASTER-BAL > WS-TARGET-BAL
               COMPUTE WS-EXCESS =
                   WS-MASTER-BAL - WS-TARGET-BAL
               IF WS-EXCESS >= WS-MIN-SWEEP
                   SET WS-TO-INVEST TO TRUE
               ELSE
                   SET WS-BALANCED TO TRUE
               END-IF
           ELSE
               IF WS-MASTER-BAL < WS-TARGET-BAL
                   COMPUTE WS-DEFICIT =
                       WS-TARGET-BAL - WS-MASTER-BAL
                   SET WS-TO-MASTER TO TRUE
               ELSE
                   SET WS-BALANCED TO TRUE
               END-IF
           END-IF.
       3000-CALC-AMOUNT.
           EVALUATE TRUE
               WHEN WS-TO-INVEST
                   MOVE WS-EXCESS TO WS-SWEEP-AMT
                   COMPUTE WS-SWEEP-FEE =
                       WS-SWEEP-AMT * 0.0001
               WHEN WS-TO-MASTER
                   IF WS-DEFICIT > WS-INVEST-BAL
                       MOVE WS-INVEST-BAL TO WS-SWEEP-AMT
                   ELSE
                       MOVE WS-DEFICIT TO WS-SWEEP-AMT
                   END-IF
                   MOVE 0 TO WS-SWEEP-FEE
               WHEN WS-BALANCED
                   MOVE 0 TO WS-SWEEP-AMT
           END-EVALUATE.
       4000-EXECUTE-SWEEP.
           IF WS-SWEEP-AMT > 0
               IF WS-TO-INVEST
                   SUBTRACT WS-SWEEP-AMT FROM WS-MASTER-BAL
                   SUBTRACT WS-SWEEP-FEE FROM WS-MASTER-BAL
                   ADD WS-SWEEP-AMT TO WS-INVEST-BAL
               ELSE
                   IF WS-TO-MASTER
                       SUBTRACT WS-SWEEP-AMT FROM
                           WS-INVEST-BAL
                       ADD WS-SWEEP-AMT TO WS-MASTER-BAL
                   END-IF
               END-IF
               SET WS-EXECUTED TO TRUE
           END-IF.
       5000-PROJECT-EARNINGS.
           IF WS-INVEST-BAL > 0
               COMPUTE WS-DAILY-EARN =
                   WS-INVEST-BAL * WS-INVEST-RATE / 360
               PERFORM VARYING WS-SWEEP-IDX FROM 1 BY 1
                   UNTIL WS-SWEEP-IDX > WS-DAYS-IN-PERIOD
                   ADD WS-DAILY-EARN TO WS-PROJECTED-EARN
               END-PERFORM
               COMPUTE WS-NET-BENEFIT =
                   WS-PROJECTED-EARN - WS-SWEEP-FEE
           END-IF.
       6000-DISPLAY-RESULTS.
           DISPLAY 'CASH SWEEP ENGINE'
           DISPLAY '================='
           DISPLAY 'MASTER ACCT:     ' WS-MASTER-NUM
           DISPLAY 'MASTER BAL:      ' WS-MASTER-BAL
           DISPLAY 'TARGET BAL:      ' WS-TARGET-BAL
           DISPLAY 'INVEST BAL:      ' WS-INVEST-BAL
           IF WS-EXECUTED
               DISPLAY 'SWEEP EXECUTED'
               DISPLAY 'SWEEP AMOUNT:    ' WS-SWEEP-AMT
               DISPLAY 'SWEEP FEE:       ' WS-SWEEP-FEE
           ELSE
               DISPLAY 'NO SWEEP NEEDED'
           END-IF
           DISPLAY 'PROJECTED EARN:  ' WS-PROJECTED-EARN
           DISPLAY 'NET BENEFIT:     ' WS-NET-BENEFIT.
