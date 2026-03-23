       IDENTIFICATION DIVISION.
       PROGRAM-ID. INS-RISK-POOL-ALLOC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-POOL-TABLE.
           05 WS-POOL OCCURS 6 TIMES.
               10 WS-POOL-ID      PIC X(4).
               10 WS-POOL-NAME    PIC X(15).
               10 WS-POOL-LIMIT   PIC S9(11)V99 COMP-3.
               10 WS-POOL-USED    PIC S9(11)V99 COMP-3.
               10 WS-POOL-AVAIL   PIC S9(11)V99 COMP-3.
               10 WS-POOL-PCT     PIC S9(3)V99 COMP-3.
       01 WS-POOL-COUNT           PIC 9 VALUE 6.
       01 WS-IDX                  PIC 9.
       01 WS-JDX                  PIC 9.
       01 WS-POLICY.
           05 WS-POL-NUM          PIC X(12).
           05 WS-POL-FACE         PIC S9(9)V99 COMP-3.
           05 WS-POL-RISK-CLASS   PIC X(2).
               88 RC-PREFERRED    VALUE 'PP'.
               88 RC-STANDARD     VALUE 'ST'.
               88 RC-RATED        VALUE 'RT'.
               88 RC-DECLINE      VALUE 'DC'.
           05 WS-POL-LINE         PIC X(2).
               88 LINE-LIFE       VALUE 'LF'.
               88 LINE-HEALTH     VALUE 'HE'.
               88 LINE-PROPERTY   VALUE 'PR'.
       01 WS-ALLOC-AMT            PIC S9(9)V99 COMP-3.
       01 WS-REMAINING            PIC S9(9)V99 COMP-3.
       01 WS-ALLOC-STATUS         PIC X(12).
       01 WS-BEST-POOL            PIC 9.
       01 WS-MAX-AVAIL            PIC S9(11)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-CALC-AVAILABILITY
           PERFORM 3000-SELECT-POOL
           PERFORM 4000-ALLOCATE
           PERFORM 5000-REPORT
           STOP RUN.
       1000-INIT.
           MOVE WS-POL-FACE TO WS-REMAINING
           MOVE 0 TO WS-BEST-POOL
           MOVE 0 TO WS-MAX-AVAIL.
       2000-CALC-AVAILABILITY.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-POOL-COUNT
               COMPUTE WS-POOL-AVAIL(WS-IDX) =
                   WS-POOL-LIMIT(WS-IDX) -
                   WS-POOL-USED(WS-IDX)
               IF WS-POOL-LIMIT(WS-IDX) > 0
                   COMPUTE WS-POOL-PCT(WS-IDX) =
                       (WS-POOL-USED(WS-IDX) /
                        WS-POOL-LIMIT(WS-IDX)) * 100
               ELSE
                   MOVE 100.00 TO WS-POOL-PCT(WS-IDX)
               END-IF
           END-PERFORM.
       3000-SELECT-POOL.
           IF RC-DECLINE
               MOVE 'DECLINED    ' TO WS-ALLOC-STATUS
           ELSE
               PERFORM VARYING WS-IDX FROM 1 BY 1
                   UNTIL WS-IDX > WS-POOL-COUNT
                   IF WS-POOL-AVAIL(WS-IDX) > WS-MAX-AVAIL
                       MOVE WS-POOL-AVAIL(WS-IDX)
                           TO WS-MAX-AVAIL
                       MOVE WS-IDX TO WS-BEST-POOL
                   END-IF
               END-PERFORM
               IF WS-BEST-POOL = 0
                   MOVE 'NO CAPACITY ' TO WS-ALLOC-STATUS
               END-IF
           END-IF.
       4000-ALLOCATE.
           IF WS-BEST-POOL > 0
               IF WS-REMAINING <= WS-MAX-AVAIL
                   MOVE WS-REMAINING TO WS-ALLOC-AMT
                   ADD WS-ALLOC-AMT TO
                       WS-POOL-USED(WS-BEST-POOL)
                   SUBTRACT WS-ALLOC-AMT FROM
                       WS-POOL-AVAIL(WS-BEST-POOL)
                   MOVE 0 TO WS-REMAINING
                   MOVE 'FULL ALLOC  ' TO WS-ALLOC-STATUS
               ELSE
                   MOVE WS-MAX-AVAIL TO WS-ALLOC-AMT
                   ADD WS-ALLOC-AMT TO
                       WS-POOL-USED(WS-BEST-POOL)
                   MOVE 0 TO WS-POOL-AVAIL(WS-BEST-POOL)
                   SUBTRACT WS-ALLOC-AMT FROM WS-REMAINING
                   MOVE 'PARTIAL     ' TO WS-ALLOC-STATUS
               END-IF
           END-IF.
       5000-REPORT.
           DISPLAY 'RISK POOL ALLOCATION'
           DISPLAY '===================='
           DISPLAY 'POLICY: ' WS-POL-NUM
           DISPLAY 'FACE:   $' WS-POL-FACE
           DISPLAY 'RISK:   ' WS-POL-RISK-CLASS
           DISPLAY 'STATUS: ' WS-ALLOC-STATUS
           IF WS-BEST-POOL > 0
               DISPLAY 'POOL:   '
                   WS-POOL-NAME(WS-BEST-POOL)
               DISPLAY 'ALLOC:  $' WS-ALLOC-AMT
           END-IF
           IF WS-REMAINING > 0
               DISPLAY 'UNALLOC:$' WS-REMAINING
           END-IF
           DISPLAY 'POOL CAPACITIES:'
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-POOL-COUNT
               DISPLAY '  ' WS-POOL-NAME(WS-IDX)
                   ' USED=' WS-POOL-PCT(WS-IDX) '%'
                   ' AVAIL=$' WS-POOL-AVAIL(WS-IDX)
           END-PERFORM.
