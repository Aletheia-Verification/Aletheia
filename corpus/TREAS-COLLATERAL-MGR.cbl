       IDENTIFICATION DIVISION.
       PROGRAM-ID. TREAS-COLLATERAL-MGR.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-PLEDGED-ASSETS.
           05 WS-PA OCCURS 8 TIMES.
               10 WS-PA-CUSIP    PIC X(9).
               10 WS-PA-DESC     PIC X(20).
               10 WS-PA-PAR      PIC S9(11)V99 COMP-3.
               10 WS-PA-MKT      PIC S9(11)V99 COMP-3.
               10 WS-PA-HAIRCUT  PIC S9(1)V99 COMP-3.
               10 WS-PA-PLEDGED  PIC S9(11)V99 COMP-3.
       01 WS-PA-COUNT            PIC 9 VALUE 8.
       01 WS-IDX                 PIC 9.
       01 WS-TOTAL-PAR           PIC S9(13)V99 COMP-3.
       01 WS-TOTAL-MKT           PIC S9(13)V99 COMP-3.
       01 WS-TOTAL-PLEDGED       PIC S9(13)V99 COMP-3.
       01 WS-REQUIRED-COLL       PIC S9(13)V99 COMP-3.
       01 WS-EXCESS-COLL         PIC S9(13)V99 COMP-3.
       01 WS-COVERAGE-RATIO      PIC S9(3)V99 COMP-3.
       01 WS-MIN-COVERAGE        PIC S9(3)V99 COMP-3
           VALUE 102.00.
       01 WS-STATUS              PIC X(12).
       01 WS-ACTION              PIC X(25).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-CALC-PLEDGED
           PERFORM 3000-CHECK-COVERAGE
           PERFORM 4000-OUTPUT
           STOP RUN.
       1000-INIT.
           MOVE 0 TO WS-TOTAL-PAR
           MOVE 0 TO WS-TOTAL-MKT
           MOVE 0 TO WS-TOTAL-PLEDGED.
       2000-CALC-PLEDGED.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-PA-COUNT
               ADD WS-PA-PAR(WS-IDX) TO WS-TOTAL-PAR
               ADD WS-PA-MKT(WS-IDX) TO WS-TOTAL-MKT
               COMPUTE WS-PA-PLEDGED(WS-IDX) =
                   WS-PA-MKT(WS-IDX) *
                   (1 - WS-PA-HAIRCUT(WS-IDX))
               ADD WS-PA-PLEDGED(WS-IDX) TO
                   WS-TOTAL-PLEDGED
           END-PERFORM.
       3000-CHECK-COVERAGE.
           IF WS-REQUIRED-COLL > 0
               COMPUTE WS-COVERAGE-RATIO =
                   (WS-TOTAL-PLEDGED /
                    WS-REQUIRED-COLL) * 100
           ELSE
               MOVE 999.99 TO WS-COVERAGE-RATIO
           END-IF
           COMPUTE WS-EXCESS-COLL =
               WS-TOTAL-PLEDGED - WS-REQUIRED-COLL
           IF WS-COVERAGE-RATIO >= WS-MIN-COVERAGE
               MOVE 'ADEQUATE    ' TO WS-STATUS
               IF WS-EXCESS-COLL > 1000000.00
                   MOVE 'RELEASE EXCESS COLL' TO WS-ACTION
               ELSE
                   MOVE SPACES TO WS-ACTION
               END-IF
           ELSE
               MOVE 'DEFICIENT   ' TO WS-STATUS
               MOVE 'PLEDGE ADDITIONAL COLL' TO WS-ACTION
           END-IF.
       4000-OUTPUT.
           DISPLAY 'COLLATERAL MANAGEMENT REPORT'
           DISPLAY '============================'
           DISPLAY 'TOTAL PAR:    $' WS-TOTAL-PAR
           DISPLAY 'TOTAL MKT:    $' WS-TOTAL-MKT
           DISPLAY 'PLEDGED VALUE:$' WS-TOTAL-PLEDGED
           DISPLAY 'REQUIRED:     $' WS-REQUIRED-COLL
           DISPLAY 'EXCESS:       $' WS-EXCESS-COLL
           DISPLAY 'COVERAGE:     ' WS-COVERAGE-RATIO '%'
           DISPLAY 'STATUS:       ' WS-STATUS
           IF WS-ACTION NOT = SPACES
               DISPLAY 'ACTION:       ' WS-ACTION
           END-IF.
