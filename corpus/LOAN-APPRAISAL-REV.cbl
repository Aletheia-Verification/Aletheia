       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOAN-APPRAISAL-REV.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-APPRAISAL.
           05 WS-LOAN-NUM        PIC X(12).
           05 WS-APPRAISED-VAL   PIC S9(11)V99 COMP-3.
           05 WS-PURCHASE-PRICE  PIC S9(11)V99 COMP-3.
           05 WS-APPRAISAL-DATE  PIC 9(8).
       01 WS-COMPARABLES.
           05 WS-COMP OCCURS 6 TIMES.
               10 WS-CP-ADDRESS  PIC X(30).
               10 WS-CP-PRICE    PIC S9(9)V99 COMP-3.
               10 WS-CP-SQFT     PIC 9(5).
               10 WS-CP-DISTANCE PIC S9(2)V99 COMP-3.
               10 WS-CP-AGE-MO   PIC 9(3).
       01 WS-COMP-COUNT          PIC 9 VALUE 6.
       01 WS-IDX                 PIC 9.
       01 WS-AVG-PRICE           PIC S9(9)V99 COMP-3.
       01 WS-PRICE-SUM           PIC S9(11)V99 COMP-3.
       01 WS-VALID-COMPS         PIC 9.
       01 WS-VARIANCE-PCT        PIC S9(3)V99 COMP-3.
       01 WS-MAX-VARIANCE        PIC S9(3)V99 COMP-3
           VALUE 15.00.
       01 WS-LTV                 PIC S9(3)V99 COMP-3.
       01 WS-LOWER-VALUE         PIC S9(11)V99 COMP-3.
       01 WS-REVIEW-STATUS       PIC X(15).
       01 WS-ACTION              PIC X(25).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-FILTER-COMPS
           PERFORM 2000-CALC-AVERAGE
           PERFORM 3000-COMPARE-APPRAISAL
           PERFORM 4000-CALC-LTV
           PERFORM 5000-OUTPUT
           STOP RUN.
       1000-FILTER-COMPS.
           MOVE 0 TO WS-VALID-COMPS
           MOVE 0 TO WS-PRICE-SUM
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-COMP-COUNT
               IF WS-CP-AGE-MO(WS-IDX) <= 6
                   AND WS-CP-DISTANCE(WS-IDX) <= 1.00
                   ADD 1 TO WS-VALID-COMPS
                   ADD WS-CP-PRICE(WS-IDX)
                       TO WS-PRICE-SUM
               END-IF
           END-PERFORM.
       2000-CALC-AVERAGE.
           IF WS-VALID-COMPS > 0
               COMPUTE WS-AVG-PRICE =
                   WS-PRICE-SUM / WS-VALID-COMPS
           ELSE
               MOVE 0 TO WS-AVG-PRICE
           END-IF.
       3000-COMPARE-APPRAISAL.
           IF WS-AVG-PRICE > 0
               COMPUTE WS-VARIANCE-PCT =
                   ((WS-APPRAISED-VAL - WS-AVG-PRICE) /
                    WS-AVG-PRICE) * 100
               IF WS-VARIANCE-PCT < 0
                   MULTIPLY -1 BY WS-VARIANCE-PCT
               END-IF
               IF WS-VARIANCE-PCT > WS-MAX-VARIANCE
                   MOVE 'REVIEW REQUIRED' TO WS-REVIEW-STATUS
                   MOVE 'ORDER SECOND APPRAISAL'
                       TO WS-ACTION
               ELSE
                   MOVE 'ACCEPTABLE     ' TO WS-REVIEW-STATUS
                   MOVE SPACES TO WS-ACTION
               END-IF
           ELSE
               MOVE 'INSUFF DATA    ' TO WS-REVIEW-STATUS
               MOVE 'NEED MORE COMPARABLES'
                   TO WS-ACTION
           END-IF.
       4000-CALC-LTV.
           IF WS-APPRAISED-VAL < WS-PURCHASE-PRICE
               MOVE WS-APPRAISED-VAL TO WS-LOWER-VALUE
           ELSE
               MOVE WS-PURCHASE-PRICE TO WS-LOWER-VALUE
           END-IF
           IF WS-LOWER-VALUE > 0
               COMPUTE WS-LTV =
                   (WS-PURCHASE-PRICE / WS-LOWER-VALUE) * 100
           END-IF.
       5000-OUTPUT.
           DISPLAY 'APPRAISAL REVIEW REPORT'
           DISPLAY '======================='
           DISPLAY 'LOAN:       ' WS-LOAN-NUM
           DISPLAY 'APPRAISED:  $' WS-APPRAISED-VAL
           DISPLAY 'PURCHASE:   $' WS-PURCHASE-PRICE
           DISPLAY 'AVG COMPS:  $' WS-AVG-PRICE
           DISPLAY 'VALID COMPS:' WS-VALID-COMPS
           DISPLAY 'VARIANCE:   ' WS-VARIANCE-PCT '%'
           DISPLAY 'LTV:        ' WS-LTV '%'
           DISPLAY 'STATUS:     ' WS-REVIEW-STATUS
           IF WS-ACTION NOT = SPACES
               DISPLAY 'ACTION:     ' WS-ACTION
           END-IF.
