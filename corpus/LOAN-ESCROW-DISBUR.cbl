       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOAN-ESCROW-DISBUR.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ESCROW-ACCT.
           05 WS-LOAN-NUM        PIC X(12).
           05 WS-ESCROW-BAL      PIC S9(9)V99 COMP-3.
           05 WS-MONTHLY-ESCROW  PIC S9(5)V99 COMP-3.
       01 WS-DISBURSEMENTS.
           05 WS-DISB OCCURS 6 TIMES.
               10 WS-DB-TYPE     PIC X(2).
                   88 DB-PROP-TAX VALUE 'PT'.
                   88 DB-INS-PREM VALUE 'IP'.
                   88 DB-PMI      VALUE 'PM'.
                   88 DB-HOA      VALUE 'HO'.
                   88 DB-FLOOD    VALUE 'FL'.
               10 WS-DB-PAYEE    PIC X(25).
               10 WS-DB-AMOUNT   PIC S9(7)V99 COMP-3.
               10 WS-DB-DUE-DATE PIC 9(8).
               10 WS-DB-PAID     PIC X VALUE 'N'.
                   88 IS-PAID    VALUE 'Y'.
       01 WS-DISB-COUNT         PIC 9 VALUE 6.
       01 WS-IDX                PIC 9.
       01 WS-TOTAL-DUE          PIC S9(7)V99 COMP-3.
       01 WS-TOTAL-PAID         PIC S9(7)V99 COMP-3.
       01 WS-SHORTFALL          PIC S9(7)V99 COMP-3.
       01 WS-CURRENT-DATE       PIC 9(8).
       01 WS-DAYS-UNTIL-DUE     PIC S9(5) COMP-3.
       01 WS-URGENT-COUNT       PIC 9.
       01 WS-PAID-COUNT         PIC 9.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-PROCESS-DISBURSEMENTS
           PERFORM 3000-ASSESS-SHORTFALL
           PERFORM 4000-OUTPUT
           STOP RUN.
       1000-INIT.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-TOTAL-DUE
           MOVE 0 TO WS-TOTAL-PAID
           MOVE 0 TO WS-URGENT-COUNT
           MOVE 0 TO WS-PAID-COUNT.
       2000-PROCESS-DISBURSEMENTS.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-DISB-COUNT
               COMPUTE WS-DAYS-UNTIL-DUE =
                   WS-DB-DUE-DATE(WS-IDX) - WS-CURRENT-DATE
               ADD WS-DB-AMOUNT(WS-IDX) TO WS-TOTAL-DUE
               IF WS-DAYS-UNTIL-DUE <= 30
                   AND WS-DAYS-UNTIL-DUE >= 0
                   IF WS-ESCROW-BAL >= WS-DB-AMOUNT(WS-IDX)
                       SUBTRACT WS-DB-AMOUNT(WS-IDX) FROM
                           WS-ESCROW-BAL
                       ADD WS-DB-AMOUNT(WS-IDX) TO
                           WS-TOTAL-PAID
                       MOVE 'Y' TO WS-DB-PAID(WS-IDX)
                       ADD 1 TO WS-PAID-COUNT
                   ELSE
                       ADD 1 TO WS-URGENT-COUNT
                   END-IF
               END-IF
               IF WS-DAYS-UNTIL-DUE < 0
                   ADD 1 TO WS-URGENT-COUNT
               END-IF
           END-PERFORM.
       3000-ASSESS-SHORTFALL.
           COMPUTE WS-SHORTFALL =
               WS-TOTAL-DUE - WS-ESCROW-BAL - WS-TOTAL-PAID
           IF WS-SHORTFALL < 0
               MOVE 0 TO WS-SHORTFALL
           END-IF.
       4000-OUTPUT.
           DISPLAY 'ESCROW DISBURSEMENT REPORT'
           DISPLAY '========================='
           DISPLAY 'LOAN:      ' WS-LOAN-NUM
           DISPLAY 'ESCROW BAL:$' WS-ESCROW-BAL
           DISPLAY 'TOTAL DUE: $' WS-TOTAL-DUE
           DISPLAY 'PAID:      $' WS-TOTAL-PAID
           DISPLAY 'SHORTFALL: $' WS-SHORTFALL
           DISPLAY 'PAID CT:   ' WS-PAID-COUNT
           DISPLAY 'URGENT CT: ' WS-URGENT-COUNT
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-DISB-COUNT
               IF IS-PAID(WS-IDX)
                   DISPLAY '  PAID: ' WS-DB-TYPE(WS-IDX)
                       ' $' WS-DB-AMOUNT(WS-IDX)
                       ' ' WS-DB-PAYEE(WS-IDX)
               ELSE
                   DISPLAY '  DUE:  ' WS-DB-TYPE(WS-IDX)
                       ' $' WS-DB-AMOUNT(WS-IDX)
                       ' ' WS-DB-DUE-DATE(WS-IDX)
               END-IF
           END-PERFORM.
