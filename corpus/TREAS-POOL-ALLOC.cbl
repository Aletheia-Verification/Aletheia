       IDENTIFICATION DIVISION.
       PROGRAM-ID. TREAS-POOL-ALLOC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-POOL-DATA.
           05 WS-POOL-ID             PIC X(8).
           05 WS-TOTAL-POOL          PIC S9(13)V99 COMP-3.
       01 WS-ALLOC-TABLE.
           05 WS-ALLOC OCCURS 8.
               10 WS-AL-NAME         PIC X(15).
               10 WS-AL-PCT          PIC S9(3)V99 COMP-3.
               10 WS-AL-AMOUNT       PIC S9(11)V99 COMP-3.
               10 WS-AL-MIN          PIC S9(9)V99 COMP-3.
               10 WS-AL-MAX          PIC S9(11)V99 COMP-3.
               10 WS-AL-ACTUAL       PIC S9(11)V99 COMP-3.
       01 WS-AL-IDX                  PIC 9(1).
       01 WS-TOTAL-PCT               PIC S9(3)V99 COMP-3.
       01 WS-TOTAL-ALLOC             PIC S9(13)V99 COMP-3.
       01 WS-REMAINDER               PIC S9(9)V99 COMP-3.
       01 WS-VALID-FLAG              PIC X VALUE 'N'.
           88 WS-IS-VALID            VALUE 'Y'.
       01 WS-REBAL-NEEDED            PIC X VALUE 'N'.
           88 WS-NEEDS-REBAL         VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-VALIDATE-PCTS
           IF WS-IS-VALID
               PERFORM 3000-CALC-ALLOCATIONS
               PERFORM 4000-APPLY-LIMITS
               PERFORM 5000-DISTRIBUTE-REMAINDER
           END-IF
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-PCT
           MOVE 0 TO WS-TOTAL-ALLOC
           MOVE 0 TO WS-REMAINDER
           MOVE 'N' TO WS-VALID-FLAG
           MOVE 'N' TO WS-REBAL-NEEDED.
       2000-VALIDATE-PCTS.
           PERFORM VARYING WS-AL-IDX FROM 1 BY 1
               UNTIL WS-AL-IDX > 8
               ADD WS-AL-PCT(WS-AL-IDX) TO WS-TOTAL-PCT
           END-PERFORM
           IF WS-TOTAL-PCT = 100
               MOVE 'Y' TO WS-VALID-FLAG
           ELSE
               DISPLAY 'ALLOCATION ERROR: PCT='
                   WS-TOTAL-PCT
           END-IF.
       3000-CALC-ALLOCATIONS.
           PERFORM VARYING WS-AL-IDX FROM 1 BY 1
               UNTIL WS-AL-IDX > 8
               COMPUTE WS-AL-AMOUNT(WS-AL-IDX) =
                   WS-TOTAL-POOL *
                   WS-AL-PCT(WS-AL-IDX) / 100
               MOVE WS-AL-AMOUNT(WS-AL-IDX) TO
                   WS-AL-ACTUAL(WS-AL-IDX)
               ADD WS-AL-ACTUAL(WS-AL-IDX) TO
                   WS-TOTAL-ALLOC
           END-PERFORM.
       4000-APPLY-LIMITS.
           PERFORM VARYING WS-AL-IDX FROM 1 BY 1
               UNTIL WS-AL-IDX > 8
               IF WS-AL-ACTUAL(WS-AL-IDX) <
                   WS-AL-MIN(WS-AL-IDX)
                   MOVE WS-AL-MIN(WS-AL-IDX) TO
                       WS-AL-ACTUAL(WS-AL-IDX)
                   MOVE 'Y' TO WS-REBAL-NEEDED
               END-IF
               IF WS-AL-ACTUAL(WS-AL-IDX) >
                   WS-AL-MAX(WS-AL-IDX)
                   MOVE WS-AL-MAX(WS-AL-IDX) TO
                       WS-AL-ACTUAL(WS-AL-IDX)
                   MOVE 'Y' TO WS-REBAL-NEEDED
               END-IF
           END-PERFORM
           MOVE 0 TO WS-TOTAL-ALLOC
           PERFORM VARYING WS-AL-IDX FROM 1 BY 1
               UNTIL WS-AL-IDX > 8
               ADD WS-AL-ACTUAL(WS-AL-IDX) TO
                   WS-TOTAL-ALLOC
           END-PERFORM
           COMPUTE WS-REMAINDER =
               WS-TOTAL-POOL - WS-TOTAL-ALLOC.
       5000-DISTRIBUTE-REMAINDER.
           IF WS-REMAINDER > 0
               DIVIDE WS-REMAINDER BY 8
                   GIVING WS-REMAINDER
               PERFORM VARYING WS-AL-IDX FROM 1 BY 1
                   UNTIL WS-AL-IDX > 8
                   ADD WS-REMAINDER TO
                       WS-AL-ACTUAL(WS-AL-IDX)
               END-PERFORM
           END-IF.
       6000-DISPLAY-RESULTS.
           DISPLAY 'TREASURY POOL ALLOCATION'
           DISPLAY '========================'
           DISPLAY 'POOL ID:    ' WS-POOL-ID
           DISPLAY 'TOTAL POOL: ' WS-TOTAL-POOL
           PERFORM VARYING WS-AL-IDX FROM 1 BY 1
               UNTIL WS-AL-IDX > 8
               DISPLAY '  ' WS-AL-NAME(WS-AL-IDX)
                   ' PCT=' WS-AL-PCT(WS-AL-IDX)
                   ' TARGET=' WS-AL-AMOUNT(WS-AL-IDX)
                   ' ACTUAL=' WS-AL-ACTUAL(WS-AL-IDX)
           END-PERFORM
           IF WS-NEEDS-REBAL
               DISPLAY 'REBALANCE WAS REQUIRED'
           END-IF.
