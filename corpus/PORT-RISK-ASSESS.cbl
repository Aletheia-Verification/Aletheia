       IDENTIFICATION DIVISION.
       PROGRAM-ID. PORT-RISK-ASSESS.
      *================================================================
      * PORTFOLIO RISK ASSESSMENT ENGINE
      * Computes portfolio beta, standard deviation estimate, Sharpe
      * ratio, and Value at Risk for a multi-asset portfolio.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-PORTFOLIO.
           05 WS-PORT-ID              PIC X(10).
           05 WS-PORT-VALUE           PIC S9(13)V99 COMP-3.
           05 WS-RISK-FREE-RATE       PIC S9(1)V9(6) COMP-3
               VALUE 0.042000.
       01 WS-HOLDINGS.
           05 WS-HOLD-ENTRY OCCURS 8 TIMES.
               10 WS-HE-NAME          PIC X(12).
               10 WS-HE-VALUE         PIC S9(11)V99 COMP-3.
               10 WS-HE-WEIGHT        PIC S9(1)V9(6) COMP-3.
               10 WS-HE-RETURN        PIC S9(3)V9(6) COMP-3.
               10 WS-HE-BETA          PIC S9(1)V9(4) COMP-3.
               10 WS-HE-STDEV         PIC S9(1)V9(6) COMP-3.
       01 WS-HOLD-COUNT               PIC 9(1) VALUE 0.
       01 WS-IDX                      PIC 9(1).
       01 WS-JDEX                     PIC 9(1).
       01 WS-PORT-METRICS.
           05 WS-PORT-BETA            PIC S9(3)V9(4) COMP-3
               VALUE 0.
           05 WS-PORT-RETURN          PIC S9(3)V9(6) COMP-3
               VALUE 0.
           05 WS-PORT-VARIANCE        PIC S9(3)V9(8) COMP-3
               VALUE 0.
           05 WS-PORT-STDEV           PIC S9(1)V9(6) COMP-3.
           05 WS-SHARPE-RATIO         PIC S9(3)V9(4) COMP-3.
           05 WS-VAR-95               PIC S9(11)V99 COMP-3.
           05 WS-VAR-99               PIC S9(11)V99 COMP-3.
           05 WS-EXCESS-RETURN        PIC S9(3)V9(6) COMP-3.
       01 WS-VAR-MULT-95              PIC S9(1)V9(4) COMP-3
           VALUE 1.6449.
       01 WS-VAR-MULT-99              PIC S9(1)V9(4) COMP-3
           VALUE 2.3263.
       01 WS-RISK-CATEGORY            PIC X(12).
       01 WS-WEIGHTED-CONTRIB         PIC S9(3)V9(8) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-WEIGHTS
           PERFORM 3000-CALC-PORT-BETA
           PERFORM 4000-CALC-PORT-RETURN
           PERFORM 5000-CALC-PORT-VARIANCE
           PERFORM 6000-CALC-SHARPE
           PERFORM 7000-CALC-VAR
           PERFORM 8000-CLASSIFY-RISK
           PERFORM 9000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'PORT-RK-001' TO WS-PORT-ID
           MOVE 5000000.00 TO WS-PORT-VALUE
           MOVE 'US LARGE CAP ' TO WS-HE-NAME(1)
           MOVE 1500000.00 TO WS-HE-VALUE(1)
           MOVE 0.120000 TO WS-HE-RETURN(1)
           MOVE 1.0000 TO WS-HE-BETA(1)
           MOVE 0.150000 TO WS-HE-STDEV(1)
           MOVE 'US SMALL CAP ' TO WS-HE-NAME(2)
           MOVE 750000.00 TO WS-HE-VALUE(2)
           MOVE 0.140000 TO WS-HE-RETURN(2)
           MOVE 1.2500 TO WS-HE-BETA(2)
           MOVE 0.200000 TO WS-HE-STDEV(2)
           MOVE 'INTL EQUITY  ' TO WS-HE-NAME(3)
           MOVE 500000.00 TO WS-HE-VALUE(3)
           MOVE 0.080000 TO WS-HE-RETURN(3)
           MOVE 1.1000 TO WS-HE-BETA(3)
           MOVE 0.180000 TO WS-HE-STDEV(3)
           MOVE 'US BONDS     ' TO WS-HE-NAME(4)
           MOVE 1250000.00 TO WS-HE-VALUE(4)
           MOVE 0.045000 TO WS-HE-RETURN(4)
           MOVE 0.2000 TO WS-HE-BETA(4)
           MOVE 0.060000 TO WS-HE-STDEV(4)
           MOVE 'REAL ESTATE  ' TO WS-HE-NAME(5)
           MOVE 500000.00 TO WS-HE-VALUE(5)
           MOVE 0.090000 TO WS-HE-RETURN(5)
           MOVE 0.8000 TO WS-HE-BETA(5)
           MOVE 0.140000 TO WS-HE-STDEV(5)
           MOVE 'CASH         ' TO WS-HE-NAME(6)
           MOVE 500000.00 TO WS-HE-VALUE(6)
           MOVE 0.040000 TO WS-HE-RETURN(6)
           MOVE 0.0000 TO WS-HE-BETA(6)
           MOVE 0.005000 TO WS-HE-STDEV(6)
           MOVE 6 TO WS-HOLD-COUNT.
       2000-CALC-WEIGHTS.
           IF WS-PORT-VALUE > 0
               PERFORM VARYING WS-IDX FROM 1 BY 1
                   UNTIL WS-IDX > WS-HOLD-COUNT
                   COMPUTE WS-HE-WEIGHT(WS-IDX) =
                       WS-HE-VALUE(WS-IDX) / WS-PORT-VALUE
               END-PERFORM
           END-IF.
       3000-CALC-PORT-BETA.
           MOVE 0 TO WS-PORT-BETA
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-HOLD-COUNT
               COMPUTE WS-WEIGHTED-CONTRIB =
                   WS-HE-WEIGHT(WS-IDX) *
                   WS-HE-BETA(WS-IDX)
               ADD WS-WEIGHTED-CONTRIB TO WS-PORT-BETA
           END-PERFORM.
       4000-CALC-PORT-RETURN.
           MOVE 0 TO WS-PORT-RETURN
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-HOLD-COUNT
               COMPUTE WS-WEIGHTED-CONTRIB =
                   WS-HE-WEIGHT(WS-IDX) *
                   WS-HE-RETURN(WS-IDX)
               ADD WS-WEIGHTED-CONTRIB TO WS-PORT-RETURN
           END-PERFORM.
       5000-CALC-PORT-VARIANCE.
           MOVE 0 TO WS-PORT-VARIANCE
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-HOLD-COUNT
               COMPUTE WS-WEIGHTED-CONTRIB =
                   (WS-HE-WEIGHT(WS-IDX) ** 2) *
                   (WS-HE-STDEV(WS-IDX) ** 2)
               ADD WS-WEIGHTED-CONTRIB TO WS-PORT-VARIANCE
           END-PERFORM
           COMPUTE WS-PORT-STDEV =
               WS-PORT-VARIANCE ** 0.5.
       6000-CALC-SHARPE.
           COMPUTE WS-EXCESS-RETURN =
               WS-PORT-RETURN - WS-RISK-FREE-RATE
           IF WS-PORT-STDEV > 0
               COMPUTE WS-SHARPE-RATIO =
                   WS-EXCESS-RETURN / WS-PORT-STDEV
           ELSE
               MOVE 0 TO WS-SHARPE-RATIO
           END-IF.
       7000-CALC-VAR.
           COMPUTE WS-VAR-95 =
               WS-PORT-VALUE * WS-PORT-STDEV *
               WS-VAR-MULT-95
           COMPUTE WS-VAR-99 =
               WS-PORT-VALUE * WS-PORT-STDEV *
               WS-VAR-MULT-99.
       8000-CLASSIFY-RISK.
           IF WS-PORT-BETA < 0.50
               MOVE 'CONSERVATIVE' TO WS-RISK-CATEGORY
           ELSE
               IF WS-PORT-BETA < 0.80
                   MOVE 'MODERATE    ' TO WS-RISK-CATEGORY
               ELSE
                   IF WS-PORT-BETA < 1.10
                       MOVE 'BALANCED    ' TO WS-RISK-CATEGORY
                   ELSE
                       IF WS-PORT-BETA < 1.30
                           MOVE 'GROWTH      '
                               TO WS-RISK-CATEGORY
                       ELSE
                           MOVE 'AGGRESSIVE  '
                               TO WS-RISK-CATEGORY
                       END-IF
                   END-IF
               END-IF
           END-IF.
       9000-DISPLAY-RESULTS.
           DISPLAY 'PORTFOLIO RISK ASSESSMENT'
           DISPLAY '========================='
           DISPLAY 'PORTFOLIO:     ' WS-PORT-ID
           DISPLAY 'VALUE:         ' WS-PORT-VALUE
           DISPLAY 'BETA:          ' WS-PORT-BETA
           DISPLAY 'EXP RETURN:    ' WS-PORT-RETURN
           DISPLAY 'STD DEV:       ' WS-PORT-STDEV
           DISPLAY 'SHARPE RATIO:  ' WS-SHARPE-RATIO
           DISPLAY 'VAR 95%:       ' WS-VAR-95
           DISPLAY 'VAR 99%:       ' WS-VAR-99
           DISPLAY 'RISK CATEGORY: ' WS-RISK-CATEGORY
           DISPLAY '-------------------------'
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-HOLD-COUNT
               DISPLAY WS-HE-NAME(WS-IDX)
                   ' WT: ' WS-HE-WEIGHT(WS-IDX)
                   ' B: ' WS-HE-BETA(WS-IDX)
           END-PERFORM.
