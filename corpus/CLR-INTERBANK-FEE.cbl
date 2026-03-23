       IDENTIFICATION DIVISION.
       PROGRAM-ID. CLR-INTERBANK-FEE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-TXN-DATA.
           05 WS-TXN-AMOUNT          PIC S9(9)V99 COMP-3.
           05 WS-TXN-TYPE            PIC X(2).
       01 WS-CARD-TYPE               PIC X(1).
           88 WS-DEBIT               VALUE 'D'.
           88 WS-CREDIT              VALUE 'C'.
           88 WS-PREPAID             VALUE 'P'.
       01 WS-MCC-CODE                PIC X(4).
       01 WS-FEE-FIELDS.
           05 WS-INTERCHANGE-RATE    PIC S9(1)V9(4) COMP-3.
           05 WS-INTERCHANGE-FEE     PIC S9(5)V99 COMP-3.
           05 WS-NETWORK-FEE         PIC S9(5)V99 COMP-3.
           05 WS-TOTAL-FEE           PIC S9(5)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-SET-INTERCHANGE
           PERFORM 3000-CALC-FEES
           PERFORM 4000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-INTERCHANGE-FEE
           MOVE 0 TO WS-NETWORK-FEE
           MOVE 0 TO WS-TOTAL-FEE.
       2000-SET-INTERCHANGE.
           EVALUATE TRUE
               WHEN WS-DEBIT
                   MOVE 0.0050 TO WS-INTERCHANGE-RATE
                   MOVE 0.04 TO WS-NETWORK-FEE
               WHEN WS-CREDIT
                   MOVE 0.0175 TO WS-INTERCHANGE-RATE
                   MOVE 0.10 TO WS-NETWORK-FEE
               WHEN WS-PREPAID
                   MOVE 0.0150 TO WS-INTERCHANGE-RATE
                   MOVE 0.08 TO WS-NETWORK-FEE
               WHEN OTHER
                   MOVE 0.0200 TO WS-INTERCHANGE-RATE
                   MOVE 0.10 TO WS-NETWORK-FEE
           END-EVALUATE.
       3000-CALC-FEES.
           COMPUTE WS-INTERCHANGE-FEE =
               WS-TXN-AMOUNT * WS-INTERCHANGE-RATE
           IF WS-INTERCHANGE-FEE < 0.21
               MOVE 0.21 TO WS-INTERCHANGE-FEE
           END-IF
           COMPUTE WS-TOTAL-FEE =
               WS-INTERCHANGE-FEE + WS-NETWORK-FEE.
       4000-DISPLAY-RESULTS.
           DISPLAY 'INTERBANK FEE'
           DISPLAY '============='
           DISPLAY 'AMOUNT:       ' WS-TXN-AMOUNT
           DISPLAY 'INTERCHANGE:  ' WS-INTERCHANGE-FEE
           DISPLAY 'NETWORK FEE:  ' WS-NETWORK-FEE
           DISPLAY 'TOTAL FEE:    ' WS-TOTAL-FEE.
