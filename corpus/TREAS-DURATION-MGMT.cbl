       IDENTIFICATION DIVISION.
       PROGRAM-ID. TREAS-DURATION-MGMT.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-PORTFOLIO.
           05 WS-ASSET OCCURS 10 TIMES.
               10 WS-AS-ID       PIC X(10).
               10 WS-AS-MKT-VAL  PIC S9(11)V99 COMP-3.
               10 WS-AS-DURATION PIC S9(2)V9(4) COMP-3.
               10 WS-AS-YIELD    PIC S9(2)V9(4) COMP-3.
               10 WS-AS-TYPE     PIC X(2).
                   88 TP-BOND    VALUE 'BD'.
                   88 TP-MBS     VALUE 'MB'.
                   88 TP-AGENCY  VALUE 'AG'.
                   88 TP-MUNI    VALUE 'MU'.
       01 WS-ASSET-COUNT         PIC 99 VALUE 10.
       01 WS-IDX                 PIC 99.
       01 WS-TOTAL-MKT           PIC S9(13)V99 COMP-3.
       01 WS-WEIGHTED-DUR        PIC S9(5)V9(4) COMP-3.
       01 WS-PORT-DURATION       PIC S9(2)V9(4) COMP-3.
       01 WS-TARGET-DURATION     PIC S9(2)V9(4) COMP-3
           VALUE 3.5000.
       01 WS-DURATION-GAP        PIC S9(2)V9(4) COMP-3.
       01 WS-WEIGHTED-YIELD      PIC S9(5)V9(4) COMP-3.
       01 WS-PORT-YIELD          PIC S9(2)V9(4) COMP-3.
       01 WS-RATE-SENSITIVITY    PIC S9(11)V99 COMP-3.
       01 WS-REBAL-NEEDED        PIC X VALUE 'N'.
           88 NEEDS-REBALANCE    VALUE 'Y'.
       01 WS-TOLERANCE           PIC S9(1)V9(4) COMP-3
           VALUE 0.5000.
       01 WS-ACTION              PIC X(20).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-CALC-PORTFOLIO
           PERFORM 3000-CHECK-DURATION
           PERFORM 4000-CALC-SENSITIVITY
           PERFORM 5000-REPORT
           STOP RUN.
       1000-INIT.
           MOVE 0 TO WS-TOTAL-MKT
           MOVE 0 TO WS-WEIGHTED-DUR
           MOVE 0 TO WS-WEIGHTED-YIELD.
       2000-CALC-PORTFOLIO.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-ASSET-COUNT
               ADD WS-AS-MKT-VAL(WS-IDX) TO WS-TOTAL-MKT
               COMPUTE WS-WEIGHTED-DUR =
                   WS-WEIGHTED-DUR +
                   (WS-AS-DURATION(WS-IDX) *
                    WS-AS-MKT-VAL(WS-IDX))
               COMPUTE WS-WEIGHTED-YIELD =
                   WS-WEIGHTED-YIELD +
                   (WS-AS-YIELD(WS-IDX) *
                    WS-AS-MKT-VAL(WS-IDX))
           END-PERFORM
           IF WS-TOTAL-MKT > 0
               COMPUTE WS-PORT-DURATION =
                   WS-WEIGHTED-DUR / WS-TOTAL-MKT
               COMPUTE WS-PORT-YIELD =
                   WS-WEIGHTED-YIELD / WS-TOTAL-MKT
           END-IF.
       3000-CHECK-DURATION.
           COMPUTE WS-DURATION-GAP =
               WS-PORT-DURATION - WS-TARGET-DURATION
           IF WS-DURATION-GAP > WS-TOLERANCE
               MOVE 'Y' TO WS-REBAL-NEEDED
               MOVE 'SHORTEN DURATION    ' TO WS-ACTION
           ELSE
               IF WS-DURATION-GAP < (0 - WS-TOLERANCE)
                   MOVE 'Y' TO WS-REBAL-NEEDED
                   MOVE 'EXTEND DURATION     ' TO WS-ACTION
               ELSE
                   MOVE 'WITHIN TOLERANCE    ' TO WS-ACTION
               END-IF
           END-IF.
       4000-CALC-SENSITIVITY.
           COMPUTE WS-RATE-SENSITIVITY =
               WS-TOTAL-MKT * WS-PORT-DURATION * 0.01.
       5000-REPORT.
           DISPLAY 'DURATION MANAGEMENT REPORT'
           DISPLAY '========================='
           DISPLAY 'TOTAL MKT:  $' WS-TOTAL-MKT
           DISPLAY 'PORT DUR:   ' WS-PORT-DURATION
           DISPLAY 'TARGET DUR: ' WS-TARGET-DURATION
           DISPLAY 'DUR GAP:    ' WS-DURATION-GAP
           DISPLAY 'PORT YIELD: ' WS-PORT-YIELD
           DISPLAY 'RATE SENS:  $' WS-RATE-SENSITIVITY
           DISPLAY 'ACTION:     ' WS-ACTION
           IF NEEDS-REBALANCE
               DISPLAY 'REBALANCE REQUIRED'
           END-IF.
