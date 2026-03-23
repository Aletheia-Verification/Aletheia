       IDENTIFICATION DIVISION.
       PROGRAM-ID. REG-FAIR-LENDING.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-DECISION-TABLE.
           05 WS-DECISION OCCURS 25 TIMES.
               10 WS-DEC-APP-ID  PIC X(10).
               10 WS-DEC-RESULT  PIC X(1).
                   88 DR-APPROVED VALUE 'A'.
                   88 DR-DENIED   VALUE 'D'.
               10 WS-DEC-RACE    PIC X(2).
               10 WS-DEC-GENDER  PIC X(1).
               10 WS-DEC-AGE     PIC 9(3).
               10 WS-DEC-INCOME  PIC S9(9)V99 COMP-3.
               10 WS-DEC-SCORE   PIC 9(3).
               10 WS-DEC-DTI     PIC S9(3)V99 COMP-3.
       01 WS-DEC-COUNT           PIC 99 VALUE 25.
       01 WS-IDX                 PIC 99.
       01 WS-TOTAL-APPS          PIC 99.
       01 WS-TOTAL-APPROVED      PIC 99.
       01 WS-TOTAL-DENIED        PIC 99.
       01 WS-GROUP-APPROVED      PIC 99.
       01 WS-GROUP-TOTAL         PIC 99.
       01 WS-CONTROL-APPROVED    PIC 99.
       01 WS-CONTROL-TOTAL       PIC 99.
       01 WS-GROUP-RATE          PIC S9(3)V99 COMP-3.
       01 WS-CONTROL-RATE        PIC S9(3)V99 COMP-3.
       01 WS-DISPARITY-RATIO     PIC S9(3)V99 COMP-3.
       01 WS-THRESHOLD           PIC S9(1)V99 COMP-3
           VALUE 0.80.
       01 WS-DISPARITY-FLAG      PIC X VALUE 'N'.
           88 HAS-DISPARITY      VALUE 'Y'.
       01 WS-TEST-GROUP          PIC X(2).
       01 WS-CONTROL-GROUP       PIC X(2).
       01 WS-REPORT-DATE         PIC 9(8).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-CALC-OVERALL
           PERFORM 3000-CALC-GROUP-RATES
           PERFORM 4000-CHECK-DISPARITY
           PERFORM 5000-OUTPUT
           STOP RUN.
       1000-INIT.
           ACCEPT WS-REPORT-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-TOTAL-APPS
           MOVE 0 TO WS-TOTAL-APPROVED
           MOVE 0 TO WS-TOTAL-DENIED
           MOVE 0 TO WS-GROUP-APPROVED
           MOVE 0 TO WS-GROUP-TOTAL
           MOVE 0 TO WS-CONTROL-APPROVED
           MOVE 0 TO WS-CONTROL-TOTAL.
       2000-CALC-OVERALL.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-DEC-COUNT
               ADD 1 TO WS-TOTAL-APPS
               IF DR-APPROVED(WS-IDX)
                   ADD 1 TO WS-TOTAL-APPROVED
               ELSE
                   ADD 1 TO WS-TOTAL-DENIED
               END-IF
           END-PERFORM.
       3000-CALC-GROUP-RATES.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-DEC-COUNT
               IF WS-DEC-RACE(WS-IDX) = WS-TEST-GROUP
                   ADD 1 TO WS-GROUP-TOTAL
                   IF DR-APPROVED(WS-IDX)
                       ADD 1 TO WS-GROUP-APPROVED
                   END-IF
               END-IF
               IF WS-DEC-RACE(WS-IDX) = WS-CONTROL-GROUP
                   ADD 1 TO WS-CONTROL-TOTAL
                   IF DR-APPROVED(WS-IDX)
                       ADD 1 TO WS-CONTROL-APPROVED
                   END-IF
               END-IF
           END-PERFORM
           IF WS-GROUP-TOTAL > 0
               COMPUTE WS-GROUP-RATE =
                   (WS-GROUP-APPROVED / WS-GROUP-TOTAL) * 100
           END-IF
           IF WS-CONTROL-TOTAL > 0
               COMPUTE WS-CONTROL-RATE =
                   (WS-CONTROL-APPROVED /
                    WS-CONTROL-TOTAL) * 100
           END-IF.
       4000-CHECK-DISPARITY.
           IF WS-CONTROL-RATE > 0
               COMPUTE WS-DISPARITY-RATIO =
                   WS-GROUP-RATE / WS-CONTROL-RATE
               IF WS-DISPARITY-RATIO < WS-THRESHOLD
                   MOVE 'Y' TO WS-DISPARITY-FLAG
               END-IF
           END-IF.
       5000-OUTPUT.
           DISPLAY 'FAIR LENDING ANALYSIS'
           DISPLAY '====================='
           DISPLAY 'DATE:         ' WS-REPORT-DATE
           DISPLAY 'TOTAL APPS:   ' WS-TOTAL-APPS
           DISPLAY 'APPROVED:     ' WS-TOTAL-APPROVED
           DISPLAY 'DENIED:       ' WS-TOTAL-DENIED
           DISPLAY 'TEST GROUP:   ' WS-TEST-GROUP
               ' RATE=' WS-GROUP-RATE '%'
           DISPLAY 'CONTROL GRP:  ' WS-CONTROL-GROUP
               ' RATE=' WS-CONTROL-RATE '%'
           DISPLAY 'DISPARITY:    ' WS-DISPARITY-RATIO
           IF HAS-DISPARITY
               DISPLAY 'DISPARITY DETECTED - REVIEW NEEDED'
           ELSE
               DISPLAY 'NO SIGNIFICANT DISPARITY'
           END-IF.
