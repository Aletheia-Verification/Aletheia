       IDENTIFICATION DIVISION.
       PROGRAM-ID. DORMANT-ACCT-SWEEP.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01 WS-ACCOUNT-DATA.
          05 WS-ACCOUNT-NUM           PIC X(12).
          05 WS-ACCOUNT-BALANCE       PIC S9(9)V99 COMP-3.
          05 WS-LAST-ACTIVITY-MONTH   PIC 9(6).
          05 WS-CURRENT-MONTH         PIC 9(6).
          05 WS-STATE-CODE            PIC X(2).
          05 WS-ACCOUNT-TYPE          PIC X(1).
             88 ACCT-CHECKING         VALUE 'C'.
             88 ACCT-SAVINGS          VALUE 'S'.
             88 ACCT-CD               VALUE 'D'.
             88 ACCT-MONEY-MARKET     VALUE 'M'.

       01 WS-DORMANCY-FIELDS.
          05 WS-MONTHS-INACTIVE       PIC 9(4).
          05 WS-DORMANT-THRESHOLD     PIC 9(3).
          05 WS-ESCHEAT-THRESHOLD     PIC 9(3).
          05 WS-NOTICE-PERIOD         PIC 9(3).

       01 WS-ACCOUNT-STATUS.
          05 WS-STATUS-CODE           PIC X(1).
             88 STATUS-ACTIVE         VALUE 'A'.
             88 STATUS-DORMANT        VALUE 'D'.
             88 STATUS-NOTICE-SENT    VALUE 'S'.
             88 STATUS-NOTICE-PENDING VALUE 'P'.
             88 STATUS-ESCHEATED      VALUE 'E'.
          05 WS-PREV-STATUS           PIC X(1).

       01 WS-FEE-FIELDS.
          05 WS-DORMANT-FEE           PIC S9(5)V99 COMP-3.
          05 WS-MONTHLY-FEE           PIC S9(5)V99 COMP-3.
          05 WS-TOTAL-FEES            PIC S9(7)V99 COMP-3.
          05 WS-FEE-MONTHS            PIC 9(3).
          05 WS-FEE-IDX               PIC 9(3).
          05 WS-MIN-BAL-EXEMPT        PIC S9(7)V99 COMP-3.

       01 WS-TRANSFER-FIELDS.
          05 WS-HOLDING-ACCT-BAL      PIC S9(11)V99 COMP-3.
          05 WS-TRANSFER-AMOUNT       PIC S9(9)V99 COMP-3.
          05 WS-NET-BALANCE           PIC S9(9)V99 COMP-3.

       01 WS-REACTIVATION.
          05 WS-REACTIVATE-FLAG       PIC X(1).
             88 DO-REACTIVATE         VALUE 'Y'.
             88 NO-REACTIVATE         VALUE 'N'.
          05 WS-REACTIVATION-FEE      PIC S9(5)V99 COMP-3.
          05 WS-DAYS-SINCE-NOTICE     PIC 9(3).

       01 WS-PROCESSING-COUNTS.
          05 WS-ACTIVE-COUNT          PIC 9(6).
          05 WS-DORMANT-COUNT         PIC 9(6).
          05 WS-ESCHEAT-COUNT         PIC 9(6).
          05 WS-REACTIVATED-COUNT     PIC 9(6).
          05 WS-NOTICE-COUNT          PIC 9(6).
          05 WS-TOTAL-PROCESSED       PIC 9(6).

       01 WS-WORK-FIELDS.
          05 WS-TEMP-AMT              PIC S9(9)V99 COMP-3.
          05 WS-YEAR-DIFF             PIC 9(4).
          05 WS-MONTH-DIFF            PIC 9(2).

       PROCEDURE DIVISION.

       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-INACTIVITY
           PERFORM 3000-DETERMINE-ESCHEAT-RULES
           PERFORM 4000-ASSESS-DORMANCY
           PERFORM 5000-APPLY-FEES
           PERFORM 6000-CHECK-REACTIVATION
           PERFORM 7000-PROCESS-ESCHEATMENT
           PERFORM 8000-DISPLAY-RESULTS
           STOP RUN.

       1000-INITIALIZE.
           INITIALIZE WS-DORMANCY-FIELDS
           INITIALIZE WS-FEE-FIELDS
           INITIALIZE WS-TRANSFER-FIELDS
           INITIALIZE WS-REACTIVATION
           INITIALIZE WS-PROCESSING-COUNTS
           SET NO-REACTIVATE TO TRUE
           MOVE 5.00 TO WS-MONTHLY-FEE
           MOVE 25.00 TO WS-REACTIVATION-FEE
           MOVE 500.00 TO WS-MIN-BAL-EXEMPT.

       2000-CALC-INACTIVITY.
           IF WS-CURRENT-MONTH > WS-LAST-ACTIVITY-MONTH
              COMPUTE WS-YEAR-DIFF =
                 (WS-CURRENT-MONTH / 100) -
                 (WS-LAST-ACTIVITY-MONTH / 100)
              COMPUTE WS-MONTH-DIFF =
                 WS-CURRENT-MONTH - WS-LAST-ACTIVITY-MONTH
                 - (WS-YEAR-DIFF * 100)
                 + (WS-YEAR-DIFF * 12)
              MOVE WS-MONTH-DIFF TO WS-MONTHS-INACTIVE
           ELSE
              MOVE 0 TO WS-MONTHS-INACTIVE
           END-IF.

       3000-DETERMINE-ESCHEAT-RULES.
           EVALUATE TRUE
              WHEN WS-STATE-CODE = 'NY'
                 MOVE 36 TO WS-DORMANT-THRESHOLD
                 MOVE 60 TO WS-ESCHEAT-THRESHOLD
                 MOVE 6 TO WS-NOTICE-PERIOD
              WHEN WS-STATE-CODE = 'CA'
                 MOVE 36 TO WS-DORMANT-THRESHOLD
                 MOVE 36 TO WS-ESCHEAT-THRESHOLD
                 MOVE 3 TO WS-NOTICE-PERIOD
              WHEN WS-STATE-CODE = 'TX'
                 MOVE 36 TO WS-DORMANT-THRESHOLD
                 MOVE 60 TO WS-ESCHEAT-THRESHOLD
                 MOVE 6 TO WS-NOTICE-PERIOD
              WHEN WS-STATE-CODE = 'FL'
                 MOVE 60 TO WS-DORMANT-THRESHOLD
                 MOVE 60 TO WS-ESCHEAT-THRESHOLD
                 MOVE 12 TO WS-NOTICE-PERIOD
              WHEN WS-STATE-CODE = 'IL'
                 MOVE 60 TO WS-DORMANT-THRESHOLD
                 MOVE 84 TO WS-ESCHEAT-THRESHOLD
                 MOVE 6 TO WS-NOTICE-PERIOD
              WHEN OTHER
                 MOVE 60 TO WS-DORMANT-THRESHOLD
                 MOVE 60 TO WS-ESCHEAT-THRESHOLD
                 MOVE 6 TO WS-NOTICE-PERIOD
           END-EVALUATE.

       4000-ASSESS-DORMANCY.
           MOVE WS-STATUS-CODE TO WS-PREV-STATUS
           IF WS-MONTHS-INACTIVE < WS-DORMANT-THRESHOLD
              SET STATUS-ACTIVE TO TRUE
              ADD 1 TO WS-ACTIVE-COUNT
           ELSE
              IF WS-MONTHS-INACTIVE >=
                 WS-ESCHEAT-THRESHOLD
                 IF STATUS-NOTICE-SENT
                    SET STATUS-ESCHEATED TO TRUE
                    ADD 1 TO WS-ESCHEAT-COUNT
                 ELSE
                    SET STATUS-NOTICE-PENDING TO TRUE
                    ADD 1 TO WS-NOTICE-COUNT
                 END-IF
              ELSE
                 SET STATUS-DORMANT TO TRUE
                 ADD 1 TO WS-DORMANT-COUNT
              END-IF
           END-IF
           ADD 1 TO WS-TOTAL-PROCESSED.

       5000-APPLY-FEES.
           IF STATUS-DORMANT
              IF WS-ACCOUNT-BALANCE > WS-MIN-BAL-EXEMPT
                 MOVE 0 TO WS-TOTAL-FEES
              ELSE
                 COMPUTE WS-FEE-MONTHS =
                    WS-MONTHS-INACTIVE -
                    WS-DORMANT-THRESHOLD
                 IF WS-FEE-MONTHS > 0
                    MOVE 0 TO WS-TOTAL-FEES
                    PERFORM VARYING WS-FEE-IDX
                       FROM 1 BY 1
                       UNTIL WS-FEE-IDX > WS-FEE-MONTHS
                       ADD WS-MONTHLY-FEE TO WS-TOTAL-FEES
                    END-PERFORM
                    IF WS-TOTAL-FEES > WS-ACCOUNT-BALANCE
                       MOVE WS-ACCOUNT-BALANCE
                          TO WS-TOTAL-FEES
                    END-IF
                    SUBTRACT WS-TOTAL-FEES
                       FROM WS-ACCOUNT-BALANCE
                 END-IF
              END-IF
           END-IF.

       6000-CHECK-REACTIVATION.
           IF DO-REACTIVATE
              IF STATUS-DORMANT
                 SET STATUS-ACTIVE TO TRUE
                 SUBTRACT WS-REACTIVATION-FEE
                    FROM WS-ACCOUNT-BALANCE
                 IF WS-ACCOUNT-BALANCE < 0
                    MOVE 0 TO WS-ACCOUNT-BALANCE
                 END-IF
                 ADD 1 TO WS-REACTIVATED-COUNT
              ELSE
                 IF STATUS-NOTICE-PENDING
                    SET STATUS-ACTIVE TO TRUE
                    SUBTRACT WS-REACTIVATION-FEE
                       FROM WS-ACCOUNT-BALANCE
                    ADD 1 TO WS-REACTIVATED-COUNT
                 END-IF
              END-IF
           END-IF.

       7000-PROCESS-ESCHEATMENT.
           IF STATUS-ESCHEATED
              MOVE WS-ACCOUNT-BALANCE
                 TO WS-TRANSFER-AMOUNT
              ADD WS-TRANSFER-AMOUNT
                 TO WS-HOLDING-ACCT-BAL
              MOVE 0 TO WS-ACCOUNT-BALANCE
              DISPLAY "ESCHEATED: " WS-ACCOUNT-NUM
                 " AMT: " WS-TRANSFER-AMOUNT
                 " STATE: " WS-STATE-CODE
           END-IF.

       8000-DISPLAY-RESULTS.
           DISPLAY "===== DORMANT ACCOUNT SWEEP ====="
           DISPLAY "ACTIVE: " WS-ACTIVE-COUNT
           DISPLAY "DORMANT: " WS-DORMANT-COUNT
           DISPLAY "NOTICES: " WS-NOTICE-COUNT
           DISPLAY "ESCHEATED: " WS-ESCHEAT-COUNT
           DISPLAY "REACTIVATED: " WS-REACTIVATED-COUNT
           DISPLAY "TOTAL PROCESSED: " WS-TOTAL-PROCESSED
           DISPLAY "HOLDING BAL: " WS-HOLDING-ACCT-BAL.
