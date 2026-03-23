       IDENTIFICATION DIVISION.
       PROGRAM-ID. PAY-ORIGINATOR-FEE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ORIGINATOR-DATA.
           05 WS-ORIG-ID             PIC X(10).
           05 WS-ORIG-NAME           PIC X(30).
           05 WS-MONTHLY-VOLUME      PIC S9(9) COMP-3.
           05 WS-MONTHLY-AMOUNT      PIC S9(13)V99 COMP-3.
       01 WS-ORIG-TIER               PIC X(1).
           88 WS-TIER-SMALL          VALUE 'S'.
           88 WS-TIER-MEDIUM         VALUE 'M'.
           88 WS-TIER-LARGE          VALUE 'L'.
           88 WS-TIER-ENTERPRISE     VALUE 'E'.
       01 WS-FEE-SCHEDULE.
           05 WS-TIER-ENTRY OCCURS 4.
               10 WS-TE-LABEL        PIC X(10).
               10 WS-TE-PER-TXN      PIC S9(1)V9(4) COMP-3.
               10 WS-TE-MONTHLY-MIN  PIC S9(5)V99 COMP-3.
               10 WS-TE-DISCOUNT     PIC S9(1)V9(4) COMP-3.
       01 WS-TE-IDX                  PIC 9(1).
       01 WS-FEE-FIELDS.
           05 WS-BASE-FEE            PIC S9(9)V99 COMP-3.
           05 WS-VOLUME-DISCOUNT     PIC S9(9)V99 COMP-3.
           05 WS-NET-FEE             PIC S9(9)V99 COMP-3.
           05 WS-MONTHLY-MIN         PIC S9(5)V99 COMP-3.
           05 WS-PER-TXN-RATE        PIC S9(1)V9(4) COMP-3.
       01 WS-SELECTED-TIER           PIC 9(1).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-BUILD-FEE-SCHEDULE
           PERFORM 3000-DETERMINE-TIER
           PERFORM 4000-CALC-FEES
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-BASE-FEE
           MOVE 0 TO WS-VOLUME-DISCOUNT
           MOVE 0 TO WS-NET-FEE.
       2000-BUILD-FEE-SCHEDULE.
           MOVE 'SMALL' TO WS-TE-LABEL(1)
           MOVE 0.2500 TO WS-TE-PER-TXN(1)
           MOVE 50.00 TO WS-TE-MONTHLY-MIN(1)
           MOVE 0 TO WS-TE-DISCOUNT(1)
           MOVE 'MEDIUM' TO WS-TE-LABEL(2)
           MOVE 0.1500 TO WS-TE-PER-TXN(2)
           MOVE 200.00 TO WS-TE-MONTHLY-MIN(2)
           MOVE 0.0500 TO WS-TE-DISCOUNT(2)
           MOVE 'LARGE' TO WS-TE-LABEL(3)
           MOVE 0.0800 TO WS-TE-PER-TXN(3)
           MOVE 500.00 TO WS-TE-MONTHLY-MIN(3)
           MOVE 0.1000 TO WS-TE-DISCOUNT(3)
           MOVE 'ENTERPRISE' TO WS-TE-LABEL(4)
           MOVE 0.0300 TO WS-TE-PER-TXN(4)
           MOVE 2000.00 TO WS-TE-MONTHLY-MIN(4)
           MOVE 0.1500 TO WS-TE-DISCOUNT(4).
       3000-DETERMINE-TIER.
           EVALUATE TRUE
               WHEN WS-MONTHLY-VOLUME < 1000
                   SET WS-TIER-SMALL TO TRUE
                   MOVE 1 TO WS-SELECTED-TIER
               WHEN WS-MONTHLY-VOLUME < 10000
                   SET WS-TIER-MEDIUM TO TRUE
                   MOVE 2 TO WS-SELECTED-TIER
               WHEN WS-MONTHLY-VOLUME < 100000
                   SET WS-TIER-LARGE TO TRUE
                   MOVE 3 TO WS-SELECTED-TIER
               WHEN OTHER
                   SET WS-TIER-ENTERPRISE TO TRUE
                   MOVE 4 TO WS-SELECTED-TIER
           END-EVALUATE
           MOVE WS-TE-PER-TXN(WS-SELECTED-TIER) TO
               WS-PER-TXN-RATE
           MOVE WS-TE-MONTHLY-MIN(WS-SELECTED-TIER) TO
               WS-MONTHLY-MIN.
       4000-CALC-FEES.
           COMPUTE WS-BASE-FEE =
               WS-MONTHLY-VOLUME * WS-PER-TXN-RATE
           COMPUTE WS-VOLUME-DISCOUNT =
               WS-BASE-FEE *
               WS-TE-DISCOUNT(WS-SELECTED-TIER)
           COMPUTE WS-NET-FEE =
               WS-BASE-FEE - WS-VOLUME-DISCOUNT
           IF WS-NET-FEE < WS-MONTHLY-MIN
               MOVE WS-MONTHLY-MIN TO WS-NET-FEE
           END-IF.
       5000-DISPLAY-RESULTS.
           DISPLAY 'ACH ORIGINATOR FEE REPORT'
           DISPLAY '========================='
           DISPLAY 'ORIGINATOR:      ' WS-ORIG-NAME
           DISPLAY 'MONTHLY VOLUME:  ' WS-MONTHLY-VOLUME
           DISPLAY 'MONTHLY AMOUNT:  ' WS-MONTHLY-AMOUNT
           DISPLAY 'TIER:            '
               WS-TE-LABEL(WS-SELECTED-TIER)
           DISPLAY 'PER-TXN RATE:    ' WS-PER-TXN-RATE
           DISPLAY 'BASE FEE:        ' WS-BASE-FEE
           DISPLAY 'DISCOUNT:        ' WS-VOLUME-DISCOUNT
           DISPLAY 'NET FEE:         ' WS-NET-FEE
           DISPLAY 'MINIMUM:         ' WS-MONTHLY-MIN.
