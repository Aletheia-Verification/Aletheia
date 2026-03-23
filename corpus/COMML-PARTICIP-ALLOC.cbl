       IDENTIFICATION DIVISION.
       PROGRAM-ID. COMML-PARTICIP-ALLOC.
      *================================================================*
      * Commercial Loan Participation Allocator                         *
      * Allocates principal, interest, and fees among loan              *
      * participation holders based on pro-rata shares.                 *
      *================================================================*
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-LOAN-DATA.
           05  LD-LOAN-NUM         PIC X(12)
                                   VALUE 'CML-2025-001'.
           05  LD-TOTAL-COMMIT     PIC 9(11)V99
                                   VALUE 25000000.00.
           05  LD-OUTSTANDING      PIC 9(11)V99
                                   VALUE 18000000.00.
           05  LD-INT-RATE         PIC 9V9(06)
                                   VALUE 0.065000.
           05  LD-UPFRONT-FEE      PIC 9(09)V99
                                   VALUE 125000.00.
           05  LD-UNUSED-FEE-RT    PIC 9V9(04) VALUE 0.0025.
       01  WS-PARTICIPANT-TABLE.
           05  WS-PART-ENTRY      OCCURS 8 TIMES.
               10  PT-BANK-NAME   PIC X(20).
               10  PT-SHARE-PCT   PIC 9(03)V99.
               10  PT-COMMIT-AMT  PIC S9(11)V99.
               10  PT-OUTSTAND    PIC S9(11)V99.
               10  PT-INT-SHARE   PIC S9(09)V99.
               10  PT-FEE-SHARE   PIC S9(09)V99.
               10  PT-UNUSED-FEE  PIC S9(09)V99.
               10  PT-TOTAL-INC   PIC S9(11)V99.
       01  WS-NUM-PARTS           PIC 9(02) VALUE 5.
       01  WS-IDX                 PIC 9(02).
       01  WS-MONTHLY-INT         PIC S9(09)V99.
       01  WS-UNUSED-AMT          PIC S9(11)V99.
       01  WS-TOTAL-UNUSED-FEE    PIC S9(09)V99.
       01  WS-ALLOC-CHECK         PIC S9(11)V99 VALUE 0.
       01  WS-INT-CHECK           PIC S9(09)V99 VALUE 0.
       01  WS-ROUNDING-DIFF       PIC S9(07)V99.
       01  WS-TOTAL-PCT           PIC 9(03)V99 VALUE 0.
       01  WS-VERIFY-FLAG         PIC X VALUE 'P'.
           88  ALLOC-PASS          VALUE 'P'.
           88  ALLOC-FAIL          VALUE 'F'.
       01  WS-MSG-BUF             PIC X(80) VALUE SPACES.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-POOL-TOTALS
           PERFORM 3000-ALLOCATE-SHARES
           PERFORM 4000-VERIFY-ALLOCATION
           PERFORM 9000-REPORT
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'LEAD BANK CORP     ' TO PT-BANK-NAME(1)
           MOVE 35.00 TO PT-SHARE-PCT(1)
           MOVE 'REGIONAL SAVINGS   ' TO PT-BANK-NAME(2)
           MOVE 25.00 TO PT-SHARE-PCT(2)
           MOVE 'METRO COMMUNITY    ' TO PT-BANK-NAME(3)
           MOVE 20.00 TO PT-SHARE-PCT(3)
           MOVE 'STATE TRUST CO     ' TO PT-BANK-NAME(4)
           MOVE 12.50 TO PT-SHARE-PCT(4)
           MOVE 'RURAL CREDIT UNION ' TO PT-BANK-NAME(5)
           MOVE 7.50 TO PT-SHARE-PCT(5).
       2000-CALC-POOL-TOTALS.
           COMPUTE WS-MONTHLY-INT ROUNDED =
               LD-OUTSTANDING * LD-INT-RATE / 12
           COMPUTE WS-UNUSED-AMT =
               LD-TOTAL-COMMIT - LD-OUTSTANDING
           COMPUTE WS-TOTAL-UNUSED-FEE ROUNDED =
               WS-UNUSED-AMT * LD-UNUSED-FEE-RT / 12.
       3000-ALLOCATE-SHARES.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-NUM-PARTS
               COMPUTE PT-COMMIT-AMT(WS-IDX) ROUNDED =
                   LD-TOTAL-COMMIT *
                   PT-SHARE-PCT(WS-IDX) / 100
               COMPUTE PT-OUTSTAND(WS-IDX) ROUNDED =
                   LD-OUTSTANDING *
                   PT-SHARE-PCT(WS-IDX) / 100
               COMPUTE PT-INT-SHARE(WS-IDX) ROUNDED =
                   WS-MONTHLY-INT *
                   PT-SHARE-PCT(WS-IDX) / 100
               COMPUTE PT-FEE-SHARE(WS-IDX) ROUNDED =
                   LD-UPFRONT-FEE *
                   PT-SHARE-PCT(WS-IDX) / 100
               COMPUTE PT-UNUSED-FEE(WS-IDX) ROUNDED =
                   WS-TOTAL-UNUSED-FEE *
                   PT-SHARE-PCT(WS-IDX) / 100
               COMPUTE PT-TOTAL-INC(WS-IDX) =
                   PT-INT-SHARE(WS-IDX) +
                   PT-FEE-SHARE(WS-IDX) +
                   PT-UNUSED-FEE(WS-IDX)
               ADD PT-SHARE-PCT(WS-IDX) TO WS-TOTAL-PCT
           END-PERFORM.
       4000-VERIFY-ALLOCATION.
           MOVE ZERO TO WS-ALLOC-CHECK
           MOVE ZERO TO WS-INT-CHECK
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-NUM-PARTS
               ADD PT-OUTSTAND(WS-IDX) TO WS-ALLOC-CHECK
               ADD PT-INT-SHARE(WS-IDX) TO WS-INT-CHECK
           END-PERFORM
           COMPUTE WS-ROUNDING-DIFF =
               LD-OUTSTANDING - WS-ALLOC-CHECK
           IF WS-ROUNDING-DIFF NOT = ZERO
               IF WS-ROUNDING-DIFF < 1 AND
                  WS-ROUNDING-DIFF > -1
                   ADD WS-ROUNDING-DIFF TO
                       PT-OUTSTAND(1)
               ELSE
                   MOVE 'F' TO WS-VERIFY-FLAG
                   DISPLAY 'ALLOCATION MISMATCH: '
                       WS-ROUNDING-DIFF
               END-IF
           END-IF
           IF WS-TOTAL-PCT NOT = 100.00
               MOVE 'F' TO WS-VERIFY-FLAG
               DISPLAY 'SHARE PCT TOTAL: ' WS-TOTAL-PCT
           END-IF.
       9000-REPORT.
           DISPLAY 'PARTICIPATION ALLOCATION REPORT'
           DISPLAY 'LOAN: ' LD-LOAN-NUM
           DISPLAY 'COMMITMENT:  ' LD-TOTAL-COMMIT
           DISPLAY 'OUTSTANDING: ' LD-OUTSTANDING
           DISPLAY 'MONTHLY INT: ' WS-MONTHLY-INT
           DISPLAY '---------- PARTICIPANTS ----------'
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-NUM-PARTS
               MOVE SPACES TO WS-MSG-BUF
               STRING PT-BANK-NAME(WS-IDX)
                   DELIMITED BY SIZE
                   INTO WS-MSG-BUF
               DISPLAY WS-MSG-BUF
               DISPLAY '  SHARE:   ' PT-SHARE-PCT(WS-IDX)
                   '%'
               DISPLAY '  OUTSTAND:' PT-OUTSTAND(WS-IDX)
               DISPLAY '  INT:     ' PT-INT-SHARE(WS-IDX)
               DISPLAY '  TOTAL:   ' PT-TOTAL-INC(WS-IDX)
           END-PERFORM
           IF ALLOC-PASS
               DISPLAY 'ALLOCATION VERIFIED'
           ELSE
               DISPLAY 'ALLOCATION FAILED VERIFICATION'
           END-IF.
