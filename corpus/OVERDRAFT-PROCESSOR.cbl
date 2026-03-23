       IDENTIFICATION DIVISION.
       PROGRAM-ID. OVERDRAFT-PROCESSOR.
      *================================================================*
      * Overdraft Protection and Fee Assessment Engine                  *
      * Processes overdraft events, applies tiered fees, handles       *
      * linked savings transfers, enforces daily fee caps.             *
      *================================================================*

       DATA DIVISION.
       WORKING-STORAGE SECTION.

      *--- Account Fields ---*
       01  WS-ACCOUNT-NUM            PIC 9(10).
       01  WS-CHECKING-BAL           PIC S9(11)V99 COMP-3.
       01  WS-SAVINGS-BAL            PIC S9(11)V99 COMP-3.
       01  WS-TRANSACTION-AMT        PIC S9(9)V99 COMP-3.
       01  WS-AVAILABLE-BAL          PIC S9(11)V99 COMP-3.
       01  WS-SHORTFALL              PIC S9(9)V99 COMP-3.

      *--- Overdraft Status ---*
       01  WS-OD-STATUS              PIC 9.
           88  WS-OPT-IN             VALUE 1.
           88  WS-OPT-OUT            VALUE 2.
           88  WS-PENDING            VALUE 3.

      *--- Daily Tracking ---*
       01  WS-DAILY-OD-COUNT         PIC S9(3) COMP-3.
       01  WS-DAILY-FEE-TOTAL        PIC S9(7)V99 COMP-3.
       01  WS-DAILY-FEE-CAP          PIC S9(7)V99 COMP-3.
       01  WS-MAX-OD-PER-DAY         PIC S9(3) COMP-3.

      *--- Fee Calculation ---*
       01  WS-CURRENT-FEE            PIC S9(5)V99 COMP-3.
       01  WS-FEE-ASSESSED           PIC S9(5)V99 COMP-3.
       01  WS-REMAINING-CAP          PIC S9(7)V99 COMP-3.
       01  WS-TOTAL-FEES-TODAY       PIC S9(7)V99 COMP-3.
       01  WS-FEE-WAIVED-FLAG        PIC 9.

      *--- Grace Period ---*
       01  WS-HOURS-SINCE-OD         PIC S9(5) COMP-3.
       01  WS-GRACE-HOURS            PIC S9(3) COMP-3.
       01  WS-GRACE-ELIGIBLE         PIC 9.
       01  WS-OD-TIMESTAMP           PIC 9(8).
       01  WS-CURRENT-TIMESTAMP      PIC 9(8).

      *--- Linked Savings Transfer ---*
       01  WS-SAVINGS-LINKED         PIC 9.
       01  WS-TRANSFER-AMT           PIC S9(9)V99 COMP-3.
       01  WS-TRANSFER-FEE           PIC S9(5)V99 COMP-3.
       01  WS-TRANSFER-SUCCESS       PIC 9.
       01  WS-SAVINGS-MINIMUM        PIC S9(9)V99 COMP-3.
       01  WS-SAVINGS-AVAILABLE      PIC S9(9)V99 COMP-3.

      *--- Net Position ---*
       01  WS-NET-POSITION           PIC S9(11)V99 COMP-3.
       01  WS-TOTAL-TRANSFERS        PIC S9(9)V99 COMP-3.
       01  WS-TOTAL-TRANSFER-FEES    PIC S9(7)V99 COMP-3.

      *--- Processing Loop ---*
       01  WS-TRAN-INDEX             PIC S9(3) COMP-3.
       01  WS-TRAN-COUNT             PIC S9(3) COMP-3.
       01  WS-PROCESS-FLAG           PIC 9.

      *--- Transaction Queue ---*
       01  WS-TRAN-AMOUNTS.
           05  WS-TRAN-AMT           PIC S9(9)V99 COMP-3
                                     OCCURS 10.

      *--- Display ---*
       01  WS-DISP-AMOUNT            PIC -$$$,$$9.99.
       01  WS-DISP-BAL               PIC -$$$,$$$,$$9.99.
       01  WS-DISP-COUNT             PIC Z,ZZ9.

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-TRANSACTIONS
           PERFORM 3000-PROCESS-OVERDRAFTS
           PERFORM 4000-COMPUTE-NET-POSITION
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.

       1000-INITIALIZE.
           MOVE 1234567890 TO WS-ACCOUNT-NUM
           MOVE 150.00 TO WS-CHECKING-BAL
           MOVE 2500.00 TO WS-SAVINGS-BAL
           MOVE 1 TO WS-OD-STATUS
           MOVE 0 TO WS-DAILY-OD-COUNT
           MOVE 0 TO WS-DAILY-FEE-TOTAL
           MOVE 100.00 TO WS-DAILY-FEE-CAP
           MOVE 6 TO WS-MAX-OD-PER-DAY
           MOVE 24 TO WS-GRACE-HOURS
           MOVE 0 TO WS-HOURS-SINCE-OD
           MOVE 1 TO WS-SAVINGS-LINKED
           MOVE 10.00 TO WS-TRANSFER-FEE
           MOVE 100.00 TO WS-SAVINGS-MINIMUM
           MOVE 0 TO WS-TOTAL-TRANSFERS
           MOVE 0 TO WS-TOTAL-TRANSFER-FEES
           MOVE 0 TO WS-TOTAL-FEES-TODAY
           MOVE 0 TO WS-FEE-WAIVED-FLAG
           MOVE 5 TO WS-TRAN-COUNT.

       2000-LOAD-TRANSACTIONS.
           MOVE 75.00 TO WS-TRAN-AMT(1)
           MOVE 200.00 TO WS-TRAN-AMT(2)
           MOVE 50.00 TO WS-TRAN-AMT(3)
           MOVE 125.00 TO WS-TRAN-AMT(4)
           MOVE 35.00 TO WS-TRAN-AMT(5).

       3000-PROCESS-OVERDRAFTS.
           PERFORM VARYING WS-TRAN-INDEX FROM 1 BY 1
               UNTIL WS-TRAN-INDEX > WS-TRAN-COUNT
               MOVE WS-TRAN-AMT(WS-TRAN-INDEX)
                   TO WS-TRANSACTION-AMT
               PERFORM 3100-CHECK-AVAILABLE
               IF WS-PROCESS-FLAG = 1
                   PERFORM 3200-HANDLE-OVERDRAFT
               END-IF
           END-PERFORM.

       3100-CHECK-AVAILABLE.
           MOVE 0 TO WS-PROCESS-FLAG
           COMPUTE WS-AVAILABLE-BAL =
               WS-CHECKING-BAL - WS-TRANSACTION-AMT
           IF WS-AVAILABLE-BAL < 0
               MOVE 1 TO WS-PROCESS-FLAG
               COMPUTE WS-SHORTFALL =
                   WS-TRANSACTION-AMT - WS-CHECKING-BAL
               IF WS-SHORTFALL < 0
                   MOVE 0 TO WS-SHORTFALL
               END-IF
           ELSE
               SUBTRACT WS-TRANSACTION-AMT
                   FROM WS-CHECKING-BAL
           END-IF.

       3200-HANDLE-OVERDRAFT.
           IF WS-OPT-OUT
               DISPLAY "TRANSACTION DECLINED - OPT OUT"
           ELSE
               IF WS-PENDING
                   DISPLAY "OVERDRAFT STATUS PENDING"
               ELSE
                   PERFORM 3300-CHECK-GRACE-PERIOD
                   IF WS-GRACE-ELIGIBLE = 1
                       MOVE 1 TO WS-FEE-WAIVED-FLAG
                       SUBTRACT WS-TRANSACTION-AMT
                           FROM WS-CHECKING-BAL
                   ELSE
                       PERFORM 3400-ATTEMPT-SAVINGS-TRANSFER
                       IF WS-TRANSFER-SUCCESS = 0
                           PERFORM 3500-ASSESS-FEE
                       END-IF
                       SUBTRACT WS-TRANSACTION-AMT
                           FROM WS-CHECKING-BAL
                   END-IF
               END-IF
           END-IF.

       3300-CHECK-GRACE-PERIOD.
           MOVE 0 TO WS-GRACE-ELIGIBLE
           IF WS-HOURS-SINCE-OD < WS-GRACE-HOURS
               IF WS-DAILY-OD-COUNT = 0
                   MOVE 1 TO WS-GRACE-ELIGIBLE
               END-IF
           END-IF
           ADD 1 TO WS-DAILY-OD-COUNT.

       3400-ATTEMPT-SAVINGS-TRANSFER.
           MOVE 0 TO WS-TRANSFER-SUCCESS
           IF WS-SAVINGS-LINKED = 1
               COMPUTE WS-SAVINGS-AVAILABLE =
                   WS-SAVINGS-BAL - WS-SAVINGS-MINIMUM
               IF WS-SAVINGS-AVAILABLE >= WS-SHORTFALL
                   MOVE WS-SHORTFALL TO WS-TRANSFER-AMT
                   SUBTRACT WS-TRANSFER-AMT FROM WS-SAVINGS-BAL
                   ADD WS-TRANSFER-AMT TO WS-CHECKING-BAL
                   ADD WS-TRANSFER-AMT TO WS-TOTAL-TRANSFERS
                   SUBTRACT WS-TRANSFER-FEE
                       FROM WS-CHECKING-BAL
                   ADD WS-TRANSFER-FEE
                       TO WS-TOTAL-TRANSFER-FEES
                   MOVE 1 TO WS-TRANSFER-SUCCESS
               END-IF
           END-IF.

       3500-ASSESS-FEE.
           EVALUATE TRUE
               WHEN WS-DAILY-OD-COUNT = 1
                   MOVE 25.00 TO WS-CURRENT-FEE
               WHEN WS-DAILY-OD-COUNT = 2
                   MOVE 30.00 TO WS-CURRENT-FEE
               WHEN WS-DAILY-OD-COUNT >= 3
                   MOVE 35.00 TO WS-CURRENT-FEE
           END-EVALUATE
           COMPUTE WS-REMAINING-CAP =
               WS-DAILY-FEE-CAP - WS-DAILY-FEE-TOTAL
           IF WS-CURRENT-FEE > WS-REMAINING-CAP
               IF WS-REMAINING-CAP > 0
                   MOVE WS-REMAINING-CAP TO WS-FEE-ASSESSED
               ELSE
                   MOVE 0 TO WS-FEE-ASSESSED
               END-IF
           ELSE
               MOVE WS-CURRENT-FEE TO WS-FEE-ASSESSED
           END-IF
           IF WS-DAILY-OD-COUNT > WS-MAX-OD-PER-DAY
               MOVE 0 TO WS-FEE-ASSESSED
           END-IF
           SUBTRACT WS-FEE-ASSESSED FROM WS-CHECKING-BAL
           ADD WS-FEE-ASSESSED TO WS-DAILY-FEE-TOTAL
           ADD WS-FEE-ASSESSED TO WS-TOTAL-FEES-TODAY.

       4000-COMPUTE-NET-POSITION.
           ADD WS-CHECKING-BAL TO WS-SAVINGS-BAL
               GIVING WS-NET-POSITION.

       5000-DISPLAY-RESULTS.
           DISPLAY "=== OVERDRAFT PROCESSING REPORT ==="
           DISPLAY "ACCOUNT: " WS-ACCOUNT-NUM
           MOVE WS-CHECKING-BAL TO WS-DISP-BAL
           DISPLAY "CHECKING BAL:  " WS-DISP-BAL
           MOVE WS-SAVINGS-BAL TO WS-DISP-BAL
           DISPLAY "SAVINGS BAL:   " WS-DISP-BAL
           MOVE WS-NET-POSITION TO WS-DISP-BAL
           DISPLAY "NET POSITION:  " WS-DISP-BAL
           DISPLAY "--- FEE SUMMARY ---"
           MOVE WS-DAILY-OD-COUNT TO WS-DISP-COUNT
           DISPLAY "OD EVENTS:     " WS-DISP-COUNT
           MOVE WS-TOTAL-FEES-TODAY TO WS-DISP-AMOUNT
           DISPLAY "TOTAL FEES:    " WS-DISP-AMOUNT
           MOVE WS-TOTAL-TRANSFERS TO WS-DISP-AMOUNT
           DISPLAY "SAV TRANSFERS: " WS-DISP-AMOUNT
           MOVE WS-TOTAL-TRANSFER-FEES TO WS-DISP-AMOUNT
           DISPLAY "TRANSFER FEES: " WS-DISP-AMOUNT
           IF WS-FEE-WAIVED-FLAG = 1
               DISPLAY "GRACE WAIVER APPLIED"
           END-IF
           DISPLAY "=== END REPORT ===".
