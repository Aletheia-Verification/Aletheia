       IDENTIFICATION DIVISION.
       PROGRAM-ID. TRADE-FIN-LC.
      *================================================================*
      * Trade Finance Letter of Credit Processor                        *
      * Manages LC lifecycle: issuance, amendment, document checking,   *
      * discrepancy handling, and payment/acceptance decisions.          *
      *================================================================*
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT LC-FILE ASSIGN TO 'LETTCRED.DAT'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-LC-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD  LC-FILE.
       01  LC-RECORD.
           05  LC-NUMBER            PIC X(12).
           05  LC-TYPE              PIC X(02).
           05  LC-AMOUNT            PIC 9(11)V99.
           05  LC-CURRENCY          PIC X(03).
           05  LC-ISSUE-DATE        PIC 9(08).
           05  LC-EXPIRY-DATE       PIC 9(08).
           05  LC-APPLICANT         PIC X(30).
           05  LC-BENEFICIARY       PIC X(30).
           05  LC-ADV-BANK          PIC X(11).
           05  LC-DOC-STATUS        PIC X(01).
           05  LC-DISCREPANCY-CT    PIC 9(02).
           05  LC-TOLERANCE-PCT     PIC 9(02)V99.
       WORKING-STORAGE SECTION.
       01  WS-LC-STATUS            PIC XX VALUE SPACES.
       01  WS-EOF                  PIC X VALUE 'N'.
           88  END-OF-FILE         VALUE 'Y'.
       01  WS-LC-CNT              PIC 9(06) VALUE 0.
       01  WS-PAID-CNT            PIC 9(06) VALUE 0.
       01  WS-REFUSED-CNT         PIC 9(06) VALUE 0.
       01  WS-AMENDED-CNT         PIC 9(06) VALUE 0.
       01  WS-EXPIRED-CNT         PIC 9(06) VALUE 0.
       01  WS-TOTAL-EXPOSURE      PIC S9(15)V99 VALUE 0.
       01  WS-PAID-AMT            PIC S9(15)V99 VALUE 0.
       01  WS-FEE-INCOME          PIC S9(11)V99 VALUE 0.
       01  WS-ISSUANCE-FEE-RT     PIC 9V9(04) VALUE 0.01500.
       01  WS-AMEND-FEE           PIC 9(05)V99 VALUE 250.00.
       01  WS-DISC-FEE            PIC 9(05)V99 VALUE 75.00.
       01  WS-USD-AMOUNT          PIC S9(13)V99.
       01  WS-FX-RATE             PIC 9(04)V9(06).
       01  WS-TOLERANCE-AMT       PIC S9(11)V99.
       01  WS-MAX-DRAW            PIC S9(11)V99.
       01  WS-DECISION            PIC X(10).
       01  WS-MSG-LINE            PIC X(120) VALUE SPACES.
       01  WS-FEE-CALC            PIC S9(09)V99.
       01  WS-CURRENT-DATE.
           05  WS-CUR-YEAR        PIC 9(04).
           05  WS-CUR-MONTH       PIC 9(02).
           05  WS-CUR-DAY         PIC 9(02).
       01  WS-TODAY-NUM           PIC 9(08).
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PROCESS-LC UNTIL END-OF-FILE
           PERFORM 9000-FINALIZE
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           COMPUTE WS-TODAY-NUM =
               WS-CUR-YEAR * 10000 +
               WS-CUR-MONTH * 100 + WS-CUR-DAY
           OPEN INPUT LC-FILE
           IF WS-LC-STATUS NOT = '00'
               DISPLAY 'LC FILE ERROR: ' WS-LC-STATUS
               STOP RUN
           END-IF
           PERFORM 1100-READ-LC.
       1100-READ-LC.
           READ LC-FILE
               AT END SET END-OF-FILE TO TRUE
           END-READ.
       2000-PROCESS-LC.
           ADD 1 TO WS-LC-CNT
           PERFORM 3000-CONVERT-CURRENCY
           PERFORM 3500-CHECK-EXPIRY
           IF WS-DECISION NOT = 'EXPIRED'
               EVALUATE LC-DOC-STATUS
                   WHEN 'C'
                       PERFORM 4000-DOCS-COMPLIANT
                   WHEN 'D'
                       PERFORM 5000-DOCS-DISCREPANT
                   WHEN 'P'
                       PERFORM 4500-DOCS-PARTIAL
                   WHEN 'A'
                       PERFORM 6000-AMENDMENT
                   WHEN OTHER
                       MOVE 'PENDING' TO WS-DECISION
               END-EVALUATE
           END-IF
           PERFORM 7000-CALC-FEES
           ADD WS-USD-AMOUNT TO WS-TOTAL-EXPOSURE
           PERFORM 1100-READ-LC.
       3000-CONVERT-CURRENCY.
           EVALUATE LC-CURRENCY
               WHEN 'USD'
                   MOVE LC-AMOUNT TO WS-USD-AMOUNT
                   MOVE 1.000000 TO WS-FX-RATE
               WHEN 'EUR'
                   MOVE 1.085000 TO WS-FX-RATE
                   COMPUTE WS-USD-AMOUNT ROUNDED =
                       LC-AMOUNT * WS-FX-RATE
               WHEN 'GBP'
                   MOVE 1.265000 TO WS-FX-RATE
                   COMPUTE WS-USD-AMOUNT ROUNDED =
                       LC-AMOUNT * WS-FX-RATE
               WHEN 'JPY'
                   MOVE 0.006700 TO WS-FX-RATE
                   COMPUTE WS-USD-AMOUNT ROUNDED =
                       LC-AMOUNT * WS-FX-RATE
               WHEN OTHER
                   MOVE 1.000000 TO WS-FX-RATE
                   MOVE LC-AMOUNT TO WS-USD-AMOUNT
           END-EVALUATE.
       3500-CHECK-EXPIRY.
           MOVE SPACES TO WS-DECISION
           IF LC-EXPIRY-DATE < WS-TODAY-NUM
               MOVE 'EXPIRED' TO WS-DECISION
               ADD 1 TO WS-EXPIRED-CNT
           END-IF.
       4000-DOCS-COMPLIANT.
           COMPUTE WS-TOLERANCE-AMT ROUNDED =
               LC-AMOUNT * LC-TOLERANCE-PCT / 100
           COMPUTE WS-MAX-DRAW =
               LC-AMOUNT + WS-TOLERANCE-AMT
           IF WS-USD-AMOUNT <= WS-MAX-DRAW
               MOVE 'PAY' TO WS-DECISION
               ADD WS-USD-AMOUNT TO WS-PAID-AMT
               ADD 1 TO WS-PAID-CNT
           ELSE
               MOVE 'OVER-DRAW' TO WS-DECISION
               ADD 1 TO WS-REFUSED-CNT
           END-IF.
       4500-DOCS-PARTIAL.
           MOVE 'HOLD' TO WS-DECISION
           DISPLAY 'PARTIAL DOCS LC=' LC-NUMBER.
       5000-DOCS-DISCREPANT.
           IF LC-DISCREPANCY-CT > 3
               MOVE 'REFUSE' TO WS-DECISION
               ADD 1 TO WS-REFUSED-CNT
           ELSE
               MOVE 'WAIVER-REQ' TO WS-DECISION
               MOVE SPACES TO WS-MSG-LINE
               STRING 'DISC WAIVER LC='
                   DELIMITED BY SIZE
                   LC-NUMBER
                   DELIMITED BY SIZE
                   ' COUNT='
                   DELIMITED BY SIZE
                   INTO WS-MSG-LINE
               DISPLAY WS-MSG-LINE
           END-IF.
       6000-AMENDMENT.
           ADD 1 TO WS-AMENDED-CNT
           MOVE 'AMENDED' TO WS-DECISION.
       7000-CALC-FEES.
           MOVE ZERO TO WS-FEE-CALC
           EVALUATE WS-DECISION
               WHEN 'PAY'
                   COMPUTE WS-FEE-CALC ROUNDED =
                       WS-USD-AMOUNT * WS-ISSUANCE-FEE-RT
               WHEN 'AMENDED'
                   MOVE WS-AMEND-FEE TO WS-FEE-CALC
               WHEN 'WAIVER-REQ'
                   COMPUTE WS-FEE-CALC =
                       WS-DISC-FEE * LC-DISCREPANCY-CT
               WHEN OTHER
                   MOVE ZERO TO WS-FEE-CALC
           END-EVALUATE
           ADD WS-FEE-CALC TO WS-FEE-INCOME.
       9000-FINALIZE.
           CLOSE LC-FILE
           DISPLAY 'TRADE FINANCE LC PROCESSING COMPLETE'
           DISPLAY 'TOTAL LCs:    ' WS-LC-CNT
           DISPLAY 'PAID:         ' WS-PAID-CNT
           DISPLAY 'REFUSED:      ' WS-REFUSED-CNT
           DISPLAY 'AMENDED:      ' WS-AMENDED-CNT
           DISPLAY 'EXPIRED:      ' WS-EXPIRED-CNT
           DISPLAY 'EXPOSURE USD: ' WS-TOTAL-EXPOSURE
           DISPLAY 'PAID AMT:     ' WS-PAID-AMT
           DISPLAY 'FEE INCOME:   ' WS-FEE-INCOME.
