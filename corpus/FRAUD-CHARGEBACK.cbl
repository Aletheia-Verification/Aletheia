       IDENTIFICATION DIVISION.
       PROGRAM-ID. FRAUD-CHARGEBACK.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CB-DATA.
           05 WS-CASE-NUM            PIC X(12).
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-ORIG-AMOUNT         PIC S9(9)V99 COMP-3.
           05 WS-CB-AMOUNT           PIC S9(9)V99 COMP-3.
           05 WS-MERCHANT-NAME       PIC X(25).
       01 WS-CB-REASON               PIC X(2).
           88 WS-FRAUD               VALUE '10'.
           88 WS-NOT-RECEIVED        VALUE '13'.
           88 WS-NOT-AS-DESC         VALUE '53'.
           88 WS-DUPLICATE           VALUE '82'.
           88 WS-CANCELLED           VALUE '41'.
       01 WS-CB-STAGE                PIC X(1).
           88 WS-FIRST-CB            VALUE '1'.
           88 WS-RE-PRESENTMENT      VALUE '2'.
           88 WS-ARBITRATION         VALUE '3'.
       01 WS-FEE-FIELDS.
           05 WS-CB-FEE              PIC S9(5)V99 COMP-3.
           05 WS-PROCESSING-FEE      PIC S9(5)V99 COMP-3.
           05 WS-TOTAL-FEE           PIC S9(5)V99 COMP-3.
           05 WS-NET-CREDIT          PIC S9(9)V99 COMP-3.
       01 WS-PROVISIONAL-FLAG        PIC X VALUE 'N'.
           88 WS-PROVISIONAL         VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CLASSIFY-CB
           PERFORM 3000-CALC-FEES
           PERFORM 4000-CALC-CREDIT
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-CB-FEE
           MOVE 0 TO WS-PROCESSING-FEE
           MOVE 0 TO WS-TOTAL-FEE
           MOVE 'N' TO WS-PROVISIONAL-FLAG.
       2000-CLASSIFY-CB.
           EVALUATE TRUE
               WHEN WS-FRAUD
                   MOVE 'Y' TO WS-PROVISIONAL-FLAG
                   MOVE 25.00 TO WS-CB-FEE
               WHEN WS-NOT-RECEIVED
                   MOVE 'Y' TO WS-PROVISIONAL-FLAG
                   MOVE 25.00 TO WS-CB-FEE
               WHEN WS-NOT-AS-DESC
                   MOVE 25.00 TO WS-CB-FEE
               WHEN WS-DUPLICATE
                   MOVE 15.00 TO WS-CB-FEE
               WHEN WS-CANCELLED
                   MOVE 25.00 TO WS-CB-FEE
               WHEN OTHER
                   MOVE 35.00 TO WS-CB-FEE
           END-EVALUATE.
       3000-CALC-FEES.
           EVALUATE TRUE
               WHEN WS-FIRST-CB
                   MOVE 10.00 TO WS-PROCESSING-FEE
               WHEN WS-RE-PRESENTMENT
                   MOVE 25.00 TO WS-PROCESSING-FEE
               WHEN WS-ARBITRATION
                   MOVE 100.00 TO WS-PROCESSING-FEE
           END-EVALUATE
           COMPUTE WS-TOTAL-FEE =
               WS-CB-FEE + WS-PROCESSING-FEE.
       4000-CALC-CREDIT.
           COMPUTE WS-NET-CREDIT =
               WS-CB-AMOUNT - WS-TOTAL-FEE
           IF WS-NET-CREDIT < 0
               MOVE 0 TO WS-NET-CREDIT
           END-IF.
       5000-DISPLAY-RESULTS.
           DISPLAY 'CHARGEBACK PROCESSING'
           DISPLAY '====================='
           DISPLAY 'CASE:       ' WS-CASE-NUM
           DISPLAY 'ACCOUNT:    ' WS-ACCT-NUM
           DISPLAY 'ORIG AMT:   ' WS-ORIG-AMOUNT
           DISPLAY 'CB AMOUNT:  ' WS-CB-AMOUNT
           DISPLAY 'REASON:     ' WS-CB-REASON
           DISPLAY 'CB FEE:     ' WS-CB-FEE
           DISPLAY 'PROC FEE:   ' WS-PROCESSING-FEE
           DISPLAY 'TOTAL FEE:  ' WS-TOTAL-FEE
           DISPLAY 'NET CREDIT: ' WS-NET-CREDIT
           IF WS-PROVISIONAL
               DISPLAY 'PROVISIONAL CREDIT: YES'
           END-IF.
