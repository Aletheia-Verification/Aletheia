       IDENTIFICATION DIVISION.
       PROGRAM-ID. FRAUD-SCORE-ENGINE.
      *================================================================*
      * CARD FRAUD SCORING ENGINE                                      *
      * Computes weighted risk score from velocity, geo, merchant,     *
      * amount deviation, and time-of-day factors. Threshold-based     *
      * disposition: APPROVE / REVIEW / DECLINE.                       *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-TXN-DATA.
           05 WS-CARD-NUM           PIC X(16).
           05 WS-TXN-AMOUNT         PIC S9(9)V99 COMP-3.
           05 WS-MERCH-CAT          PIC X(4).
           05 WS-MERCH-COUNTRY      PIC X(3).
           05 WS-TXN-HOUR           PIC S9(2) COMP-3.
           05 WS-TXN-CHANNEL        PIC X(3).
               88 WS-POS-TXN        VALUE 'POS'.
               88 WS-ATM-TXN        VALUE 'ATM'.
               88 WS-CNP-TXN        VALUE 'CNP'.
               88 WS-MOB-TXN        VALUE 'MOB'.
       01 WS-CARDHOLDER-PROFILE.
           05 WS-AVG-TXN-AMT        PIC S9(9)V99 COMP-3.
           05 WS-MAX-TXN-AMT        PIC S9(9)V99 COMP-3.
           05 WS-HOME-COUNTRY       PIC X(3).
           05 WS-ACCT-AGE-MONTHS    PIC S9(3) COMP-3.
           05 WS-PRIOR-FRAUD-CNT    PIC S9(2) COMP-3.
           05 WS-LAST-TXN-HOUR      PIC S9(2) COMP-3.
           05 WS-DAILY-TXN-CNT      PIC S9(3) COMP-3.
           05 WS-DAILY-TXN-TOTAL    PIC S9(11)V99 COMP-3.
       01 WS-SCORE-COMPONENTS.
           05 WS-AMT-SCORE          PIC S9(3) COMP-3.
           05 WS-VEL-SCORE          PIC S9(3) COMP-3.
           05 WS-GEO-SCORE          PIC S9(3) COMP-3.
           05 WS-MERCH-SCORE        PIC S9(3) COMP-3.
           05 WS-TIME-SCORE         PIC S9(3) COMP-3.
           05 WS-CHANNEL-SCORE      PIC S9(3) COMP-3.
           05 WS-HISTORY-SCORE      PIC S9(3) COMP-3.
       01 WS-WEIGHTS.
           05 WS-AMT-WEIGHT         PIC S9(1)V99 COMP-3
               VALUE 0.25.
           05 WS-VEL-WEIGHT         PIC S9(1)V99 COMP-3
               VALUE 0.20.
           05 WS-GEO-WEIGHT         PIC S9(1)V99 COMP-3
               VALUE 0.15.
           05 WS-MERCH-WEIGHT       PIC S9(1)V99 COMP-3
               VALUE 0.10.
           05 WS-TIME-WEIGHT        PIC S9(1)V99 COMP-3
               VALUE 0.10.
           05 WS-CHAN-WEIGHT         PIC S9(1)V99 COMP-3
               VALUE 0.10.
           05 WS-HIST-WEIGHT        PIC S9(1)V99 COMP-3
               VALUE 0.10.
       01 WS-FINAL-SCORE            PIC S9(5)V99 COMP-3.
       01 WS-WEIGHTED-TOTAL         PIC S9(5)V99 COMP-3.
       01 WS-AMT-DEVIATION          PIC S9(5)V99 COMP-3.
       01 WS-DISPOSITION            PIC X(10).
       01 WS-DECLINE-THRESH         PIC S9(3) COMP-3 VALUE 80.
       01 WS-REVIEW-THRESH          PIC S9(3) COMP-3 VALUE 50.
       01 WS-REASON-CODES           PIC X(60).
       01 WS-TEMP-SCORE             PIC S9(3) COMP-3.
       01 WS-HOUR-DIFF              PIC S9(2) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INIT-DATA
           PERFORM 2000-SCORE-AMOUNT
           PERFORM 3000-SCORE-VELOCITY
           PERFORM 4000-SCORE-GEO
           PERFORM 5000-SCORE-MERCHANT
           PERFORM 6000-SCORE-TIME
           PERFORM 7000-SCORE-CHANNEL
           PERFORM 8000-SCORE-HISTORY
           PERFORM 9000-CALC-FINAL
               THRU 9500-DETERMINE-DISPOSITION
           PERFORM 9900-DISPLAY-RESULT
           STOP RUN.
       1000-INIT-DATA.
           MOVE '4111222233334444' TO WS-CARD-NUM
           MOVE 2500.00 TO WS-TXN-AMOUNT
           MOVE '5411' TO WS-MERCH-CAT
           MOVE 'RUS' TO WS-MERCH-COUNTRY
           MOVE 3 TO WS-TXN-HOUR
           MOVE 'CNP' TO WS-TXN-CHANNEL
           MOVE 150.00 TO WS-AVG-TXN-AMT
           MOVE 800.00 TO WS-MAX-TXN-AMT
           MOVE 'USA' TO WS-HOME-COUNTRY
           MOVE 36 TO WS-ACCT-AGE-MONTHS
           MOVE 0 TO WS-PRIOR-FRAUD-CNT
           MOVE 14 TO WS-LAST-TXN-HOUR
           MOVE 5 TO WS-DAILY-TXN-CNT
           MOVE 850.00 TO WS-DAILY-TXN-TOTAL
           MOVE SPACES TO WS-REASON-CODES
           MOVE 0 TO WS-FINAL-SCORE
           MOVE 0 TO WS-WEIGHTED-TOTAL.
       2000-SCORE-AMOUNT.
           IF WS-AVG-TXN-AMT > 0
               COMPUTE WS-AMT-DEVIATION =
                   WS-TXN-AMOUNT / WS-AVG-TXN-AMT
           ELSE
               MOVE 100 TO WS-AMT-DEVIATION
           END-IF
           EVALUATE TRUE
               WHEN WS-AMT-DEVIATION > 10
                   MOVE 100 TO WS-AMT-SCORE
               WHEN WS-AMT-DEVIATION > 5
                   MOVE 75 TO WS-AMT-SCORE
               WHEN WS-AMT-DEVIATION > 3
                   MOVE 50 TO WS-AMT-SCORE
               WHEN WS-AMT-DEVIATION > 2
                   MOVE 30 TO WS-AMT-SCORE
               WHEN OTHER
                   MOVE 10 TO WS-AMT-SCORE
           END-EVALUATE
           IF WS-TXN-AMOUNT > WS-MAX-TXN-AMT
               ADD 15 TO WS-AMT-SCORE
               IF WS-AMT-SCORE > 100
                   MOVE 100 TO WS-AMT-SCORE
               END-IF
           END-IF.
       3000-SCORE-VELOCITY.
           EVALUATE TRUE
               WHEN WS-DAILY-TXN-CNT > 20
                   MOVE 100 TO WS-VEL-SCORE
               WHEN WS-DAILY-TXN-CNT > 10
                   MOVE 70 TO WS-VEL-SCORE
               WHEN WS-DAILY-TXN-CNT > 5
                   MOVE 40 TO WS-VEL-SCORE
               WHEN OTHER
                   MOVE 10 TO WS-VEL-SCORE
           END-EVALUATE
           COMPUTE WS-TEMP-SCORE =
               WS-DAILY-TXN-TOTAL + WS-TXN-AMOUNT
           IF WS-TEMP-SCORE > 5000
               ADD 20 TO WS-VEL-SCORE
           END-IF
           IF WS-VEL-SCORE > 100
               MOVE 100 TO WS-VEL-SCORE
           END-IF.
       4000-SCORE-GEO.
           IF WS-MERCH-COUNTRY NOT = WS-HOME-COUNTRY
               MOVE 40 TO WS-GEO-SCORE
               EVALUATE WS-MERCH-COUNTRY
                   WHEN 'RUS'
                       ADD 40 TO WS-GEO-SCORE
                   WHEN 'NGA'
                       ADD 40 TO WS-GEO-SCORE
                   WHEN 'PRK'
                       ADD 50 TO WS-GEO-SCORE
                   WHEN 'IRN'
                       ADD 50 TO WS-GEO-SCORE
                   WHEN OTHER
                       ADD 10 TO WS-GEO-SCORE
               END-EVALUATE
           ELSE
               MOVE 5 TO WS-GEO-SCORE
           END-IF
           IF WS-GEO-SCORE > 100
               MOVE 100 TO WS-GEO-SCORE
           END-IF.
       5000-SCORE-MERCHANT.
           EVALUATE WS-MERCH-CAT
               WHEN '5967'
                   MOVE 80 TO WS-MERCH-SCORE
               WHEN '7995'
                   MOVE 70 TO WS-MERCH-SCORE
               WHEN '6051'
                   MOVE 90 TO WS-MERCH-SCORE
               WHEN '5411'
                   MOVE 10 TO WS-MERCH-SCORE
               WHEN '5812'
                   MOVE 10 TO WS-MERCH-SCORE
               WHEN OTHER
                   MOVE 20 TO WS-MERCH-SCORE
           END-EVALUATE.
       6000-SCORE-TIME.
           IF WS-TXN-HOUR >= 0 AND WS-TXN-HOUR < 6
               MOVE 60 TO WS-TIME-SCORE
           ELSE
               IF WS-TXN-HOUR >= 22
                   MOVE 40 TO WS-TIME-SCORE
               ELSE
                   MOVE 10 TO WS-TIME-SCORE
               END-IF
           END-IF
           COMPUTE WS-HOUR-DIFF =
               FUNCTION ABS(WS-TXN-HOUR - WS-LAST-TXN-HOUR)
           IF WS-HOUR-DIFF > 12
               COMPUTE WS-HOUR-DIFF = 24 - WS-HOUR-DIFF
           END-IF
           IF WS-HOUR-DIFF < 2
               ADD 15 TO WS-TIME-SCORE
           END-IF
           IF WS-TIME-SCORE > 100
               MOVE 100 TO WS-TIME-SCORE
           END-IF.
       7000-SCORE-CHANNEL.
           EVALUATE TRUE
               WHEN WS-CNP-TXN
                   MOVE 50 TO WS-CHANNEL-SCORE
               WHEN WS-ATM-TXN
                   MOVE 30 TO WS-CHANNEL-SCORE
               WHEN WS-MOB-TXN
                   MOVE 20 TO WS-CHANNEL-SCORE
               WHEN WS-POS-TXN
                   MOVE 10 TO WS-CHANNEL-SCORE
               WHEN OTHER
                   MOVE 40 TO WS-CHANNEL-SCORE
           END-EVALUATE.
       8000-SCORE-HISTORY.
           IF WS-PRIOR-FRAUD-CNT > 0
               COMPUTE WS-HISTORY-SCORE =
                   WS-PRIOR-FRAUD-CNT * 30
               IF WS-HISTORY-SCORE > 100
                   MOVE 100 TO WS-HISTORY-SCORE
               END-IF
           ELSE
               IF WS-ACCT-AGE-MONTHS < 3
                   MOVE 50 TO WS-HISTORY-SCORE
               ELSE
                   IF WS-ACCT-AGE-MONTHS < 12
                       MOVE 25 TO WS-HISTORY-SCORE
                   ELSE
                       MOVE 5 TO WS-HISTORY-SCORE
                   END-IF
               END-IF
           END-IF.
       9000-CALC-FINAL.
           COMPUTE WS-WEIGHTED-TOTAL ROUNDED =
               (WS-AMT-SCORE * WS-AMT-WEIGHT) +
               (WS-VEL-SCORE * WS-VEL-WEIGHT) +
               (WS-GEO-SCORE * WS-GEO-WEIGHT) +
               (WS-MERCH-SCORE * WS-MERCH-WEIGHT) +
               (WS-TIME-SCORE * WS-TIME-WEIGHT) +
               (WS-CHANNEL-SCORE * WS-CHAN-WEIGHT) +
               (WS-HISTORY-SCORE * WS-HIST-WEIGHT)
           MOVE WS-WEIGHTED-TOTAL TO WS-FINAL-SCORE.
       9500-DETERMINE-DISPOSITION.
           EVALUATE TRUE
               WHEN WS-FINAL-SCORE >= WS-DECLINE-THRESH
                   MOVE 'DECLINE' TO WS-DISPOSITION
               WHEN WS-FINAL-SCORE >= WS-REVIEW-THRESH
                   MOVE 'REVIEW' TO WS-DISPOSITION
               WHEN OTHER
                   MOVE 'APPROVE' TO WS-DISPOSITION
           END-EVALUATE
           STRING 'AMT:' DELIMITED BY SIZE
               WS-AMT-SCORE DELIMITED BY SIZE
               ' VEL:' DELIMITED BY SIZE
               WS-VEL-SCORE DELIMITED BY SIZE
               ' GEO:' DELIMITED BY SIZE
               WS-GEO-SCORE DELIMITED BY SIZE
               INTO WS-REASON-CODES.
       9900-DISPLAY-RESULT.
           DISPLAY '======================================='
           DISPLAY 'FRAUD SCORING RESULT'
           DISPLAY '======================================='
           DISPLAY 'CARD:        ' WS-CARD-NUM
           DISPLAY 'AMOUNT:      ' WS-TXN-AMOUNT
           DISPLAY 'MERCHANT:    ' WS-MERCH-CAT
           DISPLAY 'COUNTRY:     ' WS-MERCH-COUNTRY
           DISPLAY 'CHANNEL:     ' WS-TXN-CHANNEL
           DISPLAY 'AMT SCORE:   ' WS-AMT-SCORE
           DISPLAY 'VEL SCORE:   ' WS-VEL-SCORE
           DISPLAY 'GEO SCORE:   ' WS-GEO-SCORE
           DISPLAY 'MERCH SCORE: ' WS-MERCH-SCORE
           DISPLAY 'TIME SCORE:  ' WS-TIME-SCORE
           DISPLAY 'CHAN SCORE:  ' WS-CHANNEL-SCORE
           DISPLAY 'HIST SCORE:  ' WS-HISTORY-SCORE
           DISPLAY 'FINAL SCORE: ' WS-FINAL-SCORE
           DISPLAY 'DISPOSITION: ' WS-DISPOSITION
           DISPLAY 'REASONS:     ' WS-REASON-CODES
           DISPLAY '======================================='.
