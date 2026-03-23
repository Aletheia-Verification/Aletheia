       IDENTIFICATION DIVISION.
       PROGRAM-ID. CCAR-LOSS-PROJ.
      *================================================================
      * CCAR Loss Projection Engine
      * Projects credit losses over 9-quarter horizon using
      * vintage-based transition matrices and recovery rates.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-PROJECTION-PARAMS.
           05 WS-HORIZON-QTR          PIC 9(2) VALUE 9.
           05 WS-CURRENT-QTR          PIC 9(2).
           05 WS-SCENARIO-TYPE        PIC X(1).
               88 WS-BASELINE         VALUE 'B'.
               88 WS-ADVERSE          VALUE 'A'.
               88 WS-SEVERELY-ADV     VALUE 'S'.
       01 WS-LOAN-SEGMENTS.
           05 WS-LSEG OCCURS 6
              ASCENDING KEY IS WS-LSEG-ID
              INDEXED BY WS-LSEG-IDX.
               10 WS-LSEG-ID          PIC X(3).
               10 WS-LSEG-NAME        PIC X(15).
               10 WS-LSEG-BALANCE     PIC S9(13)V99 COMP-3.
               10 WS-LSEG-PD-BASE     PIC S9(1)V9(6) COMP-3.
               10 WS-LSEG-LGD         PIC S9(1)V9(4) COMP-3.
               10 WS-LSEG-RECOV-RT    PIC S9(1)V9(4) COMP-3.
               10 WS-LSEG-GROWTH      PIC S9(1)V9(4) COMP-3.
       01 WS-LSEG-COUNT               PIC 9(1) VALUE 6.
       01 WS-QUARTERLY-LOSSES.
           05 WS-QTR-LOSS OCCURS 9.
               10 WS-QL-GROSS         PIC S9(11)V99 COMP-3.
               10 WS-QL-RECOVERY      PIC S9(11)V99 COMP-3.
               10 WS-QL-NET           PIC S9(11)V99 COMP-3.
       01 WS-QTR-IDX                  PIC 9(2).
       01 WS-CUMULATIVE.
           05 WS-CUM-GROSS            PIC S9(13)V99 COMP-3.
           05 WS-CUM-RECOVERY         PIC S9(13)V99 COMP-3.
           05 WS-CUM-NET              PIC S9(13)V99 COMP-3.
           05 WS-CUM-LOSS-RATE        PIC S9(3)V9(6) COMP-3.
       01 WS-STRESS-MULT-TABLE.
           05 WS-SMULT OCCURS 9.
               10 WS-SM-VALUE         PIC S9(2)V9(4) COMP-3.
       01 WS-WORK-FIELDS.
           05 WS-PERIOD-PD            PIC S9(1)V9(6) COMP-3.
           05 WS-PERIOD-LOSS          PIC S9(11)V99 COMP-3.
           05 WS-PERIOD-RECOV         PIC S9(11)V99 COMP-3.
           05 WS-ADJUSTED-BAL         PIC S9(13)V99 COMP-3.
           05 WS-TOTAL-ORIG-BAL       PIC S9(13)V99 COMP-3.
       01 WS-DIV-FIELDS.
           05 WS-LOSS-PER-SEG         PIC S9(11)V99 COMP-3.
           05 WS-DIV-REMAINDER        PIC S9(9)V99 COMP-3.
       01 WS-SEARCH-SEG               PIC X(3).
       01 WS-PROCESS-DATE             PIC 9(8).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-STRESS-MULTS
           PERFORM 3000-PROJECT-LOSSES
           PERFORM 4000-CUMULATE-RESULTS
           PERFORM 5000-CALC-LOSS-RATE
           PERFORM 6000-DISPLAY-PROJECTION
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-PROCESS-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-CUM-GROSS
           MOVE 0 TO WS-CUM-RECOVERY
           MOVE 0 TO WS-CUM-NET
           MOVE 0 TO WS-TOTAL-ORIG-BAL
           PERFORM VARYING WS-QTR-IDX FROM 1 BY 1
               UNTIL WS-QTR-IDX > WS-HORIZON-QTR
               MOVE 0 TO WS-QL-GROSS(WS-QTR-IDX)
               MOVE 0 TO WS-QL-RECOVERY(WS-QTR-IDX)
               MOVE 0 TO WS-QL-NET(WS-QTR-IDX)
           END-PERFORM
           PERFORM VARYING WS-LSEG-IDX FROM 1 BY 1
               UNTIL WS-LSEG-IDX > WS-LSEG-COUNT
               ADD WS-LSEG-BALANCE(WS-LSEG-IDX)
                   TO WS-TOTAL-ORIG-BAL
           END-PERFORM.
       2000-LOAD-STRESS-MULTS.
           EVALUATE TRUE
               WHEN WS-BASELINE
                   PERFORM VARYING WS-QTR-IDX FROM 1 BY 1
                       UNTIL WS-QTR-IDX > 9
                       MOVE 1.0000
                           TO WS-SM-VALUE(WS-QTR-IDX)
                   END-PERFORM
               WHEN WS-ADVERSE
                   MOVE 1.5 TO WS-SM-VALUE(1)
                   MOVE 2.0 TO WS-SM-VALUE(2)
                   MOVE 2.5 TO WS-SM-VALUE(3)
                   MOVE 2.8 TO WS-SM-VALUE(4)
                   MOVE 2.5 TO WS-SM-VALUE(5)
                   MOVE 2.0 TO WS-SM-VALUE(6)
                   MOVE 1.8 TO WS-SM-VALUE(7)
                   MOVE 1.5 TO WS-SM-VALUE(8)
                   MOVE 1.2 TO WS-SM-VALUE(9)
               WHEN WS-SEVERELY-ADV
                   MOVE 2.0 TO WS-SM-VALUE(1)
                   MOVE 3.5 TO WS-SM-VALUE(2)
                   MOVE 4.5 TO WS-SM-VALUE(3)
                   MOVE 5.0 TO WS-SM-VALUE(4)
                   MOVE 4.5 TO WS-SM-VALUE(5)
                   MOVE 3.5 TO WS-SM-VALUE(6)
                   MOVE 2.8 TO WS-SM-VALUE(7)
                   MOVE 2.0 TO WS-SM-VALUE(8)
                   MOVE 1.5 TO WS-SM-VALUE(9)
           END-EVALUATE.
       3000-PROJECT-LOSSES.
           PERFORM VARYING WS-QTR-IDX FROM 1 BY 1
               UNTIL WS-QTR-IDX > WS-HORIZON-QTR
               PERFORM VARYING WS-LSEG-IDX FROM 1 BY 1
                   UNTIL WS-LSEG-IDX > WS-LSEG-COUNT
                   COMPUTE WS-ADJUSTED-BAL =
                       WS-LSEG-BALANCE(WS-LSEG-IDX) *
                       (1 + WS-LSEG-GROWTH(WS-LSEG-IDX)
                       * WS-QTR-IDX)
                   COMPUTE WS-PERIOD-PD =
                       WS-LSEG-PD-BASE(WS-LSEG-IDX) *
                       WS-SM-VALUE(WS-QTR-IDX)
                   IF WS-PERIOD-PD > 1.0
                       MOVE 1.0 TO WS-PERIOD-PD
                   END-IF
                   COMPUTE WS-PERIOD-LOSS =
                       WS-ADJUSTED-BAL * WS-PERIOD-PD *
                       WS-LSEG-LGD(WS-LSEG-IDX)
                   ADD WS-PERIOD-LOSS
                       TO WS-QL-GROSS(WS-QTR-IDX)
                   COMPUTE WS-PERIOD-RECOV =
                       WS-PERIOD-LOSS *
                       WS-LSEG-RECOV-RT(WS-LSEG-IDX)
                   ADD WS-PERIOD-RECOV
                       TO WS-QL-RECOVERY(WS-QTR-IDX)
               END-PERFORM
               COMPUTE WS-QL-NET(WS-QTR-IDX) =
                   WS-QL-GROSS(WS-QTR-IDX) -
                   WS-QL-RECOVERY(WS-QTR-IDX)
           END-PERFORM.
       4000-CUMULATE-RESULTS.
           PERFORM VARYING WS-QTR-IDX FROM 1 BY 1
               UNTIL WS-QTR-IDX > WS-HORIZON-QTR
               ADD WS-QL-GROSS(WS-QTR-IDX)
                   TO WS-CUM-GROSS
               ADD WS-QL-RECOVERY(WS-QTR-IDX)
                   TO WS-CUM-RECOVERY
               ADD WS-QL-NET(WS-QTR-IDX)
                   TO WS-CUM-NET
           END-PERFORM.
       5000-CALC-LOSS-RATE.
           IF WS-TOTAL-ORIG-BAL > 0
               COMPUTE WS-CUM-LOSS-RATE =
                   (WS-CUM-NET / WS-TOTAL-ORIG-BAL) * 100
           ELSE
               MOVE 0 TO WS-CUM-LOSS-RATE
           END-IF
           IF WS-LSEG-COUNT > 0
               DIVIDE WS-CUM-NET BY WS-LSEG-COUNT
                   GIVING WS-LOSS-PER-SEG
                   REMAINDER WS-DIV-REMAINDER
           END-IF.
       6000-DISPLAY-PROJECTION.
           DISPLAY "CCAR LOSS PROJECTION"
           DISPLAY "DATE: " WS-PROCESS-DATE
           DISPLAY "SCENARIO: " WS-SCENARIO-TYPE
           DISPLAY "HORIZON: " WS-HORIZON-QTR " QTRS"
           PERFORM VARYING WS-QTR-IDX FROM 1 BY 1
               UNTIL WS-QTR-IDX > WS-HORIZON-QTR
               DISPLAY "  Q" WS-QTR-IDX
                   " GROSS=" WS-QL-GROSS(WS-QTR-IDX)
                   " NET=" WS-QL-NET(WS-QTR-IDX)
           END-PERFORM
           DISPLAY "CUMULATIVE GROSS: " WS-CUM-GROSS
           DISPLAY "CUMULATIVE NET: " WS-CUM-NET
           DISPLAY "LOSS RATE: " WS-CUM-LOSS-RATE "%"
           DISPLAY "PER SEGMENT AVG: " WS-LOSS-PER-SEG.
