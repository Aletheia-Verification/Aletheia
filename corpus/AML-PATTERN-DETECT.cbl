       IDENTIFICATION DIVISION.
       PROGRAM-ID. AML-PATTERN-DETECT.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01 WS-CUSTOMER-PROFILE.
           05 WS-CUST-ID              PIC X(12).
           05 WS-CUST-NAME            PIC X(35).
           05 WS-CUST-RISK-SCORE      PIC S9(3) COMP-3.
           05 WS-CUST-CATEGORY        PIC X(2).
               88 WS-RETAIL           VALUE 'RT'.
               88 WS-CORPORATE        VALUE 'CO'.
               88 WS-PEP              VALUE 'PE'.
               88 WS-FI-CORR          VALUE 'FI'.

       01 WS-TXN-HISTORY.
           05 WS-TXN OCCURS 20.
               10 WS-TH-DATE          PIC 9(8).
               10 WS-TH-AMOUNT        PIC S9(11)V99 COMP-3.
               10 WS-TH-TYPE          PIC X(2).
               10 WS-TH-COUNTRY       PIC X(3).
       01 WS-TXN-TOTAL                PIC 9(2) VALUE 0.
       01 WS-TXN-IDX                  PIC 9(2).

       01 WS-PATTERN-FLAGS.
           05 WS-RAPID-MOVEMENT       PIC X VALUE 'N'.
               88 WS-RAPID-MOVE       VALUE 'Y'.
           05 WS-ROUND-AMT-FLAG       PIC X VALUE 'N'.
               88 WS-ROUND-AMTS       VALUE 'Y'.
           05 WS-MULTI-COUNTRY        PIC X VALUE 'N'.
               88 WS-MANY-COUNTRIES   VALUE 'Y'.
           05 WS-FUNNEL-FLAG          PIC X VALUE 'N'.
               88 WS-FUNNEL-PATTERN   VALUE 'Y'.

       01 WS-ANALYSIS-WORK.
           05 WS-IN-TOTAL             PIC S9(13)V99 COMP-3.
           05 WS-OUT-TOTAL            PIC S9(13)V99 COMP-3.
           05 WS-ROUND-COUNT          PIC 9(3).
           05 WS-COUNTRY-LIST.
               10 WS-CTY OCCURS 10    PIC X(3).
           05 WS-CTY-USED             PIC 9(2) VALUE 0.
           05 WS-CTY-IDX              PIC 9(2).
           05 WS-CTY-FOUND            PIC X VALUE 'N'.
               88 WS-CTY-EXISTS       VALUE 'Y'.
           05 WS-REMAINDER            PIC S9(11)V99 COMP-3.

       01 WS-RISK-WEIGHTS.
           05 WS-RAPID-WT             PIC S9(3) COMP-3 VALUE 30.
           05 WS-ROUND-WT             PIC S9(3) COMP-3 VALUE 15.
           05 WS-MULTI-CTY-WT         PIC S9(3) COMP-3 VALUE 25.
           05 WS-FUNNEL-WT            PIC S9(3) COMP-3 VALUE 20.
           05 WS-PEP-WT               PIC S9(3) COMP-3 VALUE 10.

       01 WS-FINAL-SCORE              PIC S9(3) COMP-3 VALUE 0.
       01 WS-ALERT-LEVEL              PIC X(1).
           88 WS-ALERT-HIGH           VALUE 'H'.
           88 WS-ALERT-MED            VALUE 'M'.
           88 WS-ALERT-LOW            VALUE 'L'.
           88 WS-ALERT-NONE           VALUE 'N'.

       01 WS-ALERT-BUF                PIC X(80).
       01 WS-ALERT-PTR                PIC 9(3).
       01 WS-SPACE-TALLY              PIC 9(3).

       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-ANALYZE-RAPID-MOVEMENT
           PERFORM 3000-ANALYZE-ROUND-AMOUNTS
           PERFORM 4000-ANALYZE-COUNTRIES
           PERFORM 5000-ANALYZE-FUNNEL
           PERFORM 6000-CALCULATE-SCORE
           PERFORM 7000-DISPLAY-RESULTS
           STOP RUN.

       1000-INITIALIZE.
           MOVE 0 TO WS-IN-TOTAL
           MOVE 0 TO WS-OUT-TOTAL
           MOVE 0 TO WS-ROUND-COUNT
           MOVE 0 TO WS-CTY-USED
           MOVE 0 TO WS-FINAL-SCORE
           MOVE 'N' TO WS-RAPID-MOVEMENT
           MOVE 'N' TO WS-ROUND-AMT-FLAG
           MOVE 'N' TO WS-MULTI-COUNTRY
           MOVE 'N' TO WS-FUNNEL-FLAG
           MOVE 'N' TO WS-ALERT-LEVEL.

       2000-ANALYZE-RAPID-MOVEMENT.
           PERFORM VARYING WS-TXN-IDX FROM 1 BY 1
               UNTIL WS-TXN-IDX > WS-TXN-TOTAL
               IF WS-TH-TYPE(WS-TXN-IDX) = 'WI'
                   OR WS-TH-TYPE(WS-TXN-IDX) = 'AI'
                   ADD WS-TH-AMOUNT(WS-TXN-IDX) TO
                       WS-IN-TOTAL
               END-IF
               IF WS-TH-TYPE(WS-TXN-IDX) = 'WO'
                   OR WS-TH-TYPE(WS-TXN-IDX) = 'AO'
                   ADD WS-TH-AMOUNT(WS-TXN-IDX) TO
                       WS-OUT-TOTAL
               END-IF
           END-PERFORM
           IF WS-IN-TOTAL > 0 AND WS-OUT-TOTAL > 0
               IF WS-OUT-TOTAL > (WS-IN-TOTAL * 0.90)
                   MOVE 'Y' TO WS-RAPID-MOVEMENT
               END-IF
           END-IF.

       3000-ANALYZE-ROUND-AMOUNTS.
           MOVE 0 TO WS-ROUND-COUNT
           PERFORM VARYING WS-TXN-IDX FROM 1 BY 1
               UNTIL WS-TXN-IDX > WS-TXN-TOTAL
               DIVIDE WS-TH-AMOUNT(WS-TXN-IDX) BY 1000
                   GIVING WS-REMAINDER
                   REMAINDER WS-REMAINDER
               IF WS-REMAINDER = 0
                   ADD 1 TO WS-ROUND-COUNT
               END-IF
           END-PERFORM
           IF WS-TXN-TOTAL > 0
               IF WS-ROUND-COUNT > (WS-TXN-TOTAL / 2)
                   MOVE 'Y' TO WS-ROUND-AMT-FLAG
               END-IF
           END-IF.

       4000-ANALYZE-COUNTRIES.
           MOVE 0 TO WS-CTY-USED
           PERFORM VARYING WS-TXN-IDX FROM 1 BY 1
               UNTIL WS-TXN-IDX > WS-TXN-TOTAL
               MOVE 'N' TO WS-CTY-FOUND
               PERFORM VARYING WS-CTY-IDX FROM 1 BY 1
                   UNTIL WS-CTY-IDX > WS-CTY-USED
                   OR WS-CTY-EXISTS
                   IF WS-CTY(WS-CTY-IDX) =
                       WS-TH-COUNTRY(WS-TXN-IDX)
                       MOVE 'Y' TO WS-CTY-FOUND
                   END-IF
               END-PERFORM
               IF NOT WS-CTY-EXISTS
                   IF WS-CTY-USED < 10
                       ADD 1 TO WS-CTY-USED
                       MOVE WS-TH-COUNTRY(WS-TXN-IDX)
                           TO WS-CTY(WS-CTY-USED)
                   END-IF
               END-IF
           END-PERFORM
           IF WS-CTY-USED >= 4
               MOVE 'Y' TO WS-MULTI-COUNTRY
           END-IF.

       5000-ANALYZE-FUNNEL.
           IF WS-IN-TOTAL > 0
               IF WS-TXN-TOTAL > 5
                   COMPUTE WS-REMAINDER =
                       WS-IN-TOTAL / WS-TXN-TOTAL
                   IF WS-REMAINDER < 5000
                       AND WS-OUT-TOTAL >
                       (WS-IN-TOTAL * 0.80)
                       MOVE 'Y' TO WS-FUNNEL-FLAG
                   END-IF
               END-IF
           END-IF.

       6000-CALCULATE-SCORE.
           MOVE 0 TO WS-FINAL-SCORE
           IF WS-RAPID-MOVE
               ADD WS-RAPID-WT TO WS-FINAL-SCORE
           END-IF
           IF WS-ROUND-AMTS
               ADD WS-ROUND-WT TO WS-FINAL-SCORE
           END-IF
           IF WS-MANY-COUNTRIES
               ADD WS-MULTI-CTY-WT TO WS-FINAL-SCORE
           END-IF
           IF WS-FUNNEL-PATTERN
               ADD WS-FUNNEL-WT TO WS-FINAL-SCORE
           END-IF
           IF WS-PEP
               ADD WS-PEP-WT TO WS-FINAL-SCORE
           END-IF
           EVALUATE TRUE
               WHEN WS-FINAL-SCORE >= 70
                   MOVE 'H' TO WS-ALERT-LEVEL
               WHEN WS-FINAL-SCORE >= 40
                   MOVE 'M' TO WS-ALERT-LEVEL
               WHEN WS-FINAL-SCORE >= 20
                   MOVE 'L' TO WS-ALERT-LEVEL
               WHEN OTHER
                   MOVE 'N' TO WS-ALERT-LEVEL
           END-EVALUATE.

       7000-DISPLAY-RESULTS.
           MOVE SPACES TO WS-ALERT-BUF
           MOVE 1 TO WS-ALERT-PTR
           STRING 'CUST=' WS-CUST-ID ' SCORE='
               WS-FINAL-SCORE
               DELIMITED BY SIZE
               INTO WS-ALERT-BUF
               WITH POINTER WS-ALERT-PTR
           END-STRING
           MOVE 0 TO WS-SPACE-TALLY
           INSPECT WS-CUST-NAME
               TALLYING WS-SPACE-TALLY FOR ALL ' '
           DISPLAY 'AML PATTERN DETECTION RESULTS'
           DISPLAY WS-ALERT-BUF
           DISPLAY 'CATEGORY:        ' WS-CUST-CATEGORY
           DISPLAY 'RAPID MOVEMENT:  ' WS-RAPID-MOVEMENT
           DISPLAY 'ROUND AMOUNTS:   ' WS-ROUND-AMT-FLAG
           DISPLAY 'MULTI-COUNTRY:   ' WS-MULTI-COUNTRY
           DISPLAY 'FUNNEL PATTERN:  ' WS-FUNNEL-FLAG
           DISPLAY 'RISK SCORE:      ' WS-FINAL-SCORE
           DISPLAY 'ALERT LEVEL:     ' WS-ALERT-LEVEL
           DISPLAY 'INFLOWS:         ' WS-IN-TOTAL
           DISPLAY 'OUTFLOWS:        ' WS-OUT-TOTAL
           DISPLAY 'COUNTRIES:       ' WS-CTY-USED.
