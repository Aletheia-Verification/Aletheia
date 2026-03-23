       IDENTIFICATION DIVISION.
       PROGRAM-ID. INS-COVERAGE-GAP.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-POLICY-TABLE.
           05 WS-POL OCCURS 5 TIMES.
               10 WS-PL-NUMBER   PIC X(12).
               10 WS-PL-TYPE     PIC X(2).
                   88 PL-LIFE    VALUE 'LF'.
                   88 PL-HEALTH  VALUE 'HE'.
                   88 PL-DISAB   VALUE 'DI'.
                   88 PL-AUTO    VALUE 'AU'.
                   88 PL-HOME    VALUE 'HO'.
               10 WS-PL-COVERAGE PIC S9(9)V99 COMP-3.
               10 WS-PL-DEDUCT   PIC S9(5)V99 COMP-3.
               10 WS-PL-ACTIVE   PIC X.
                   88 IS-ACTIVE  VALUE 'Y'.
       01 WS-NEEDS.
           05 WS-NEED-LIFE       PIC S9(9)V99 COMP-3.
           05 WS-NEED-HEALTH     PIC S9(9)V99 COMP-3.
           05 WS-NEED-DISAB      PIC S9(7)V99 COMP-3.
           05 WS-NEED-AUTO       PIC S9(7)V99 COMP-3.
           05 WS-NEED-HOME       PIC S9(9)V99 COMP-3.
       01 WS-ACTUAL.
           05 WS-ACT-LIFE        PIC S9(9)V99 COMP-3.
           05 WS-ACT-HEALTH      PIC S9(9)V99 COMP-3.
           05 WS-ACT-DISAB       PIC S9(7)V99 COMP-3.
           05 WS-ACT-AUTO        PIC S9(7)V99 COMP-3.
           05 WS-ACT-HOME        PIC S9(9)V99 COMP-3.
       01 WS-GAPS.
           05 WS-GAP-LIFE        PIC S9(9)V99 COMP-3.
           05 WS-GAP-HEALTH      PIC S9(9)V99 COMP-3.
           05 WS-GAP-DISAB       PIC S9(7)V99 COMP-3.
           05 WS-GAP-AUTO        PIC S9(7)V99 COMP-3.
           05 WS-GAP-HOME        PIC S9(9)V99 COMP-3.
       01 WS-POL-COUNT           PIC 9 VALUE 5.
       01 WS-IDX                 PIC 9.
       01 WS-GAP-COUNT           PIC 9.
       01 WS-TOTAL-GAP           PIC S9(11)V99 COMP-3.
       01 WS-RISK-LEVEL          PIC X(8).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-TALLY-COVERAGE
           PERFORM 3000-CALC-GAPS
           PERFORM 4000-ASSESS-RISK
           PERFORM 5000-OUTPUT
           STOP RUN.
       1000-INIT.
           MOVE 0 TO WS-ACT-LIFE
           MOVE 0 TO WS-ACT-HEALTH
           MOVE 0 TO WS-ACT-DISAB
           MOVE 0 TO WS-ACT-AUTO
           MOVE 0 TO WS-ACT-HOME
           MOVE 0 TO WS-GAP-COUNT
           MOVE 0 TO WS-TOTAL-GAP.
       2000-TALLY-COVERAGE.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-POL-COUNT
               IF IS-ACTIVE(WS-IDX)
                   EVALUATE TRUE
                       WHEN PL-LIFE(WS-IDX)
                           ADD WS-PL-COVERAGE(WS-IDX)
                               TO WS-ACT-LIFE
                       WHEN PL-HEALTH(WS-IDX)
                           ADD WS-PL-COVERAGE(WS-IDX)
                               TO WS-ACT-HEALTH
                       WHEN PL-DISAB(WS-IDX)
                           ADD WS-PL-COVERAGE(WS-IDX)
                               TO WS-ACT-DISAB
                       WHEN PL-AUTO(WS-IDX)
                           ADD WS-PL-COVERAGE(WS-IDX)
                               TO WS-ACT-AUTO
                       WHEN PL-HOME(WS-IDX)
                           ADD WS-PL-COVERAGE(WS-IDX)
                               TO WS-ACT-HOME
                   END-EVALUATE
               END-IF
           END-PERFORM.
       3000-CALC-GAPS.
           COMPUTE WS-GAP-LIFE =
               WS-NEED-LIFE - WS-ACT-LIFE
           IF WS-GAP-LIFE > 0
               ADD 1 TO WS-GAP-COUNT
               ADD WS-GAP-LIFE TO WS-TOTAL-GAP
           ELSE
               MOVE 0 TO WS-GAP-LIFE
           END-IF
           COMPUTE WS-GAP-HEALTH =
               WS-NEED-HEALTH - WS-ACT-HEALTH
           IF WS-GAP-HEALTH > 0
               ADD 1 TO WS-GAP-COUNT
               ADD WS-GAP-HEALTH TO WS-TOTAL-GAP
           ELSE
               MOVE 0 TO WS-GAP-HEALTH
           END-IF
           COMPUTE WS-GAP-DISAB =
               WS-NEED-DISAB - WS-ACT-DISAB
           IF WS-GAP-DISAB > 0
               ADD 1 TO WS-GAP-COUNT
               ADD WS-GAP-DISAB TO WS-TOTAL-GAP
           ELSE
               MOVE 0 TO WS-GAP-DISAB
           END-IF
           COMPUTE WS-GAP-AUTO =
               WS-NEED-AUTO - WS-ACT-AUTO
           IF WS-GAP-AUTO > 0
               ADD 1 TO WS-GAP-COUNT
               ADD WS-GAP-AUTO TO WS-TOTAL-GAP
           ELSE
               MOVE 0 TO WS-GAP-AUTO
           END-IF
           COMPUTE WS-GAP-HOME =
               WS-NEED-HOME - WS-ACT-HOME
           IF WS-GAP-HOME > 0
               ADD 1 TO WS-GAP-COUNT
               ADD WS-GAP-HOME TO WS-TOTAL-GAP
           ELSE
               MOVE 0 TO WS-GAP-HOME
           END-IF.
       4000-ASSESS-RISK.
           IF WS-GAP-COUNT >= 3
               MOVE 'HIGH    ' TO WS-RISK-LEVEL
           ELSE
               IF WS-GAP-COUNT >= 1
                   MOVE 'MEDIUM  ' TO WS-RISK-LEVEL
               ELSE
                   MOVE 'LOW     ' TO WS-RISK-LEVEL
               END-IF
           END-IF.
       5000-OUTPUT.
           DISPLAY 'COVERAGE GAP ANALYSIS'
           DISPLAY '====================='
           DISPLAY 'GAPS FOUND:  ' WS-GAP-COUNT
           DISPLAY 'TOTAL GAP:   $' WS-TOTAL-GAP
           DISPLAY 'RISK LEVEL:  ' WS-RISK-LEVEL
           IF WS-GAP-LIFE > 0
               DISPLAY '  LIFE GAP:  $' WS-GAP-LIFE
           END-IF
           IF WS-GAP-HEALTH > 0
               DISPLAY '  HEALTH GAP:$' WS-GAP-HEALTH
           END-IF
           IF WS-GAP-DISAB > 0
               DISPLAY '  DISAB GAP: $' WS-GAP-DISAB
           END-IF
           IF WS-GAP-AUTO > 0
               DISPLAY '  AUTO GAP:  $' WS-GAP-AUTO
           END-IF
           IF WS-GAP-HOME > 0
               DISPLAY '  HOME GAP:  $' WS-GAP-HOME
           END-IF.
