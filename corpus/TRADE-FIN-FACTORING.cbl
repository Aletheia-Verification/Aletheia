       IDENTIFICATION DIVISION.
       PROGRAM-ID. TRADE-FIN-FACTORING.
      *================================================================*
      * Trade Finance Receivables Factoring Engine                      *
      * Purchases accounts receivable at discount, calculates advance   *
      * amounts, reserve holdbacks, and fee structures.                 *
      *================================================================*
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT INVOICE-FILE ASSIGN TO 'INVOICES.DAT'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-INV-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD  INVOICE-FILE.
       01  INVOICE-RECORD.
           05  IR-INVOICE-NUM       PIC X(12).
           05  IR-SELLER            PIC X(25).
           05  IR-BUYER             PIC X(25).
           05  IR-FACE-VALUE        PIC 9(09)V99.
           05  IR-INVOICE-DATE      PIC 9(08).
           05  IR-DUE-DATE          PIC 9(08).
           05  IR-CREDIT-RATING     PIC X(02).
           05  IR-RECOURSE          PIC X(01).
           05  IR-AGING-DAYS        PIC 9(03).
       WORKING-STORAGE SECTION.
       01  WS-INV-STATUS          PIC XX VALUE SPACES.
       01  WS-EOF                 PIC X VALUE 'N'.
           88  END-OF-FILE        VALUE 'Y'.
       01  WS-ADVANCE-RATE        PIC 9V99.
       01  WS-ADVANCE-AMT         PIC S9(09)V99.
       01  WS-RESERVE-AMT         PIC S9(09)V99.
       01  WS-DISCOUNT-FEE        PIC S9(07)V99.
       01  WS-SERVICE-FEE         PIC S9(07)V99.
       01  WS-TOTAL-ADVANCE       PIC S9(13)V99 VALUE 0.
       01  WS-TOTAL-RESERVE       PIC S9(13)V99 VALUE 0.
       01  WS-TOTAL-DISCOUNT      PIC S9(11)V99 VALUE 0.
       01  WS-TOTAL-SERVICE       PIC S9(11)V99 VALUE 0.
       01  WS-TOTAL-FACE          PIC S9(13)V99 VALUE 0.
       01  WS-INVOICE-CNT         PIC 9(06) VALUE 0.
       01  WS-REJECTED-CNT        PIC 9(06) VALUE 0.
       01  WS-PURCHASED-CNT       PIC 9(06) VALUE 0.
       01  WS-DISCOUNT-RATE       PIC 9V9(04).
       01  WS-SERVICE-RATE        PIC 9V9(04) VALUE 0.0100.
       01  WS-DAYS-TO-DUE         PIC 9(03).
       01  WS-BASE-RATE           PIC 9V9(06) VALUE 0.055000.
       01  WS-CREDIT-ADJ          PIC S9V9(04).
       01  WS-DECISION            PIC X(10).
       01  WS-MSG                 PIC X(80) VALUE SPACES.
       01  WS-CURRENT-DATE.
           05  WS-CUR-YEAR        PIC 9(04).
           05  WS-CUR-MONTH       PIC 9(02).
           05  WS-CUR-DAY         PIC 9(02).
       01  WS-TODAY-NUM           PIC 9(08).
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PROCESS-INVOICES UNTIL END-OF-FILE
           PERFORM 9000-FINALIZE
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           COMPUTE WS-TODAY-NUM =
               WS-CUR-YEAR * 10000 +
               WS-CUR-MONTH * 100 + WS-CUR-DAY
           OPEN INPUT INVOICE-FILE
           IF WS-INV-STATUS NOT = '00'
               DISPLAY 'INVOICE FILE ERROR: ' WS-INV-STATUS
               STOP RUN
           END-IF
           PERFORM 1100-READ-INVOICE.
       1100-READ-INVOICE.
           READ INVOICE-FILE
               AT END SET END-OF-FILE TO TRUE
           END-READ.
       2000-PROCESS-INVOICES.
           ADD 1 TO WS-INVOICE-CNT
           PERFORM 3000-EVALUATE-CREDIT
           IF WS-DECISION NOT = 'REJECT'
               PERFORM 4000-CALC-ADVANCE
               PERFORM 5000-CALC-FEES
               ADD 1 TO WS-PURCHASED-CNT
           ELSE
               ADD 1 TO WS-REJECTED-CNT
           END-IF
           PERFORM 1100-READ-INVOICE.
       3000-EVALUATE-CREDIT.
           MOVE 'PURCHASE' TO WS-DECISION
           EVALUATE IR-CREDIT-RATING
               WHEN 'AA'
                   MOVE 0.90 TO WS-ADVANCE-RATE
                   MOVE -0.0050 TO WS-CREDIT-ADJ
               WHEN 'A '
                   MOVE 0.85 TO WS-ADVANCE-RATE
                   MOVE 0.0000 TO WS-CREDIT-ADJ
               WHEN 'BB'
                   MOVE 0.80 TO WS-ADVANCE-RATE
                   MOVE 0.0100 TO WS-CREDIT-ADJ
               WHEN 'B '
                   MOVE 0.75 TO WS-ADVANCE-RATE
                   MOVE 0.0200 TO WS-CREDIT-ADJ
               WHEN OTHER
                   MOVE 'REJECT' TO WS-DECISION
                   MOVE 0 TO WS-ADVANCE-RATE
           END-EVALUATE
           IF IR-AGING-DAYS > 90
               MOVE 'REJECT' TO WS-DECISION
           END-IF
           IF IR-RECOURSE = 'N' AND
              WS-ADVANCE-RATE > 0
               SUBTRACT 0.05 FROM WS-ADVANCE-RATE
           END-IF.
       4000-CALC-ADVANCE.
           COMPUTE WS-ADVANCE-AMT ROUNDED =
               IR-FACE-VALUE * WS-ADVANCE-RATE
           COMPUTE WS-RESERVE-AMT =
               IR-FACE-VALUE - WS-ADVANCE-AMT
           ADD IR-FACE-VALUE TO WS-TOTAL-FACE
           ADD WS-ADVANCE-AMT TO WS-TOTAL-ADVANCE
           ADD WS-RESERVE-AMT TO WS-TOTAL-RESERVE.
       5000-CALC-FEES.
           IF IR-DUE-DATE > WS-TODAY-NUM
               COMPUTE WS-DAYS-TO-DUE =
                   IR-DUE-DATE - WS-TODAY-NUM
           ELSE
               MOVE 30 TO WS-DAYS-TO-DUE
           END-IF
           COMPUTE WS-DISCOUNT-RATE ROUNDED =
               (WS-BASE-RATE + WS-CREDIT-ADJ) *
               WS-DAYS-TO-DUE / 360
           COMPUTE WS-DISCOUNT-FEE ROUNDED =
               IR-FACE-VALUE * WS-DISCOUNT-RATE
           COMPUTE WS-SERVICE-FEE ROUNDED =
               IR-FACE-VALUE * WS-SERVICE-RATE
           ADD WS-DISCOUNT-FEE TO WS-TOTAL-DISCOUNT
           ADD WS-SERVICE-FEE TO WS-TOTAL-SERVICE.
       9000-FINALIZE.
           CLOSE INVOICE-FILE
           DISPLAY 'FACTORING ENGINE COMPLETE'
           DISPLAY 'TOTAL INVOICES: ' WS-INVOICE-CNT
           DISPLAY 'PURCHASED:      ' WS-PURCHASED-CNT
           DISPLAY 'REJECTED:       ' WS-REJECTED-CNT
           DISPLAY 'FACE VALUE:     ' WS-TOTAL-FACE
           DISPLAY 'ADVANCED:       ' WS-TOTAL-ADVANCE
           DISPLAY 'RESERVE:        ' WS-TOTAL-RESERVE
           DISPLAY 'DISCOUNT FEES:  ' WS-TOTAL-DISCOUNT
           DISPLAY 'SERVICE FEES:   ' WS-TOTAL-SERVICE.
