       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOAN-PMT-APPLY.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-LOAN-ACCOUNT.
           05 WS-LOAN-NUM         PIC X(12).
           05 WS-PRINCIPAL-BAL    PIC S9(9)V99 COMP-3.
           05 WS-INTEREST-BAL     PIC S9(7)V99 COMP-3.
           05 WS-ESCROW-BAL       PIC S9(7)V99 COMP-3.
           05 WS-LATE-FEE-BAL     PIC S9(5)V99 COMP-3.
           05 WS-ANNUAL-RATE      PIC S9(2)V9(4) COMP-3.
           05 WS-SCHEDULED-PMT    PIC S9(7)V99 COMP-3.
           05 WS-DUE-DATE         PIC 9(8).
           05 WS-LAST-PMT-DATE    PIC 9(8).
       01 WS-PAYMENT.
           05 WS-PMT-AMOUNT       PIC S9(7)V99 COMP-3.
           05 WS-PMT-DATE         PIC 9(8).
           05 WS-PMT-SOURCE       PIC X(2).
               88 SRC-CHECK       VALUE 'CK'.
               88 SRC-ACH         VALUE 'AC'.
               88 SRC-WIRE        VALUE 'WR'.
       01 WS-ALLOCATION.
           05 WS-ALLOC-LATE-FEE   PIC S9(5)V99 COMP-3.
           05 WS-ALLOC-INTEREST   PIC S9(7)V99 COMP-3.
           05 WS-ALLOC-ESCROW     PIC S9(7)V99 COMP-3.
           05 WS-ALLOC-PRINCIPAL  PIC S9(7)V99 COMP-3.
           05 WS-ALLOC-EXTRA      PIC S9(7)V99 COMP-3.
       01 WS-REMAINING            PIC S9(7)V99 COMP-3.
       01 WS-DAILY-RATE           PIC S9(1)V9(8) COMP-3.
       01 WS-DAYS-SINCE-PMT       PIC 9(5).
       01 WS-ACCRUED-INT          PIC S9(7)V99 COMP-3.
       01 WS-IS-LATE              PIC X VALUE 'N'.
           88 PMT-IS-LATE         VALUE 'Y'.
       01 WS-LATE-FEE             PIC S9(5)V99 COMP-3
           VALUE 35.00.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-ACCRUE-INTEREST
           PERFORM 2000-CHECK-LATE
           PERFORM 3000-APPLY-PAYMENT
           PERFORM 4000-OUTPUT
           STOP RUN.
       1000-ACCRUE-INTEREST.
           COMPUTE WS-DAILY-RATE =
               WS-ANNUAL-RATE / 365
           COMPUTE WS-DAYS-SINCE-PMT =
               WS-PMT-DATE - WS-LAST-PMT-DATE
           COMPUTE WS-ACCRUED-INT =
               WS-PRINCIPAL-BAL * WS-DAILY-RATE *
               WS-DAYS-SINCE-PMT
           ADD WS-ACCRUED-INT TO WS-INTEREST-BAL.
       2000-CHECK-LATE.
           IF WS-PMT-DATE > WS-DUE-DATE
               MOVE 'Y' TO WS-IS-LATE
               ADD WS-LATE-FEE TO WS-LATE-FEE-BAL
           END-IF.
       3000-APPLY-PAYMENT.
           MOVE WS-PMT-AMOUNT TO WS-REMAINING
           MOVE 0 TO WS-ALLOC-LATE-FEE
           MOVE 0 TO WS-ALLOC-INTEREST
           MOVE 0 TO WS-ALLOC-ESCROW
           MOVE 0 TO WS-ALLOC-PRINCIPAL
           MOVE 0 TO WS-ALLOC-EXTRA
           IF WS-LATE-FEE-BAL > 0
               IF WS-REMAINING >= WS-LATE-FEE-BAL
                   MOVE WS-LATE-FEE-BAL TO WS-ALLOC-LATE-FEE
                   SUBTRACT WS-LATE-FEE-BAL FROM WS-REMAINING
                   MOVE 0 TO WS-LATE-FEE-BAL
               ELSE
                   MOVE WS-REMAINING TO WS-ALLOC-LATE-FEE
                   SUBTRACT WS-REMAINING FROM WS-LATE-FEE-BAL
                   MOVE 0 TO WS-REMAINING
               END-IF
           END-IF
           IF WS-REMAINING > 0
               IF WS-REMAINING >= WS-INTEREST-BAL
                   MOVE WS-INTEREST-BAL TO WS-ALLOC-INTEREST
                   SUBTRACT WS-INTEREST-BAL FROM WS-REMAINING
                   MOVE 0 TO WS-INTEREST-BAL
               ELSE
                   MOVE WS-REMAINING TO WS-ALLOC-INTEREST
                   SUBTRACT WS-REMAINING FROM WS-INTEREST-BAL
                   MOVE 0 TO WS-REMAINING
               END-IF
           END-IF
           IF WS-REMAINING > 0
               IF WS-ESCROW-BAL > 0
                   IF WS-REMAINING >= WS-ESCROW-BAL
                       MOVE WS-ESCROW-BAL TO WS-ALLOC-ESCROW
                       SUBTRACT WS-ESCROW-BAL FROM
                           WS-REMAINING
                       MOVE 0 TO WS-ESCROW-BAL
                   END-IF
               END-IF
           END-IF
           IF WS-REMAINING > 0
               MOVE WS-REMAINING TO WS-ALLOC-PRINCIPAL
               SUBTRACT WS-REMAINING FROM WS-PRINCIPAL-BAL
               IF WS-PRINCIPAL-BAL < 0
                   MOVE 0 TO WS-PRINCIPAL-BAL
               END-IF
           END-IF
           MOVE WS-PMT-DATE TO WS-LAST-PMT-DATE.
       4000-OUTPUT.
           DISPLAY 'LOAN PAYMENT APPLICATION'
           DISPLAY '========================'
           DISPLAY 'LOAN:       ' WS-LOAN-NUM
           DISPLAY 'PMT AMOUNT: $' WS-PMT-AMOUNT
           DISPLAY 'PMT DATE:   ' WS-PMT-DATE
           IF PMT-IS-LATE
               DISPLAY 'STATUS:     LATE'
               DISPLAY 'LATE FEE:   $' WS-LATE-FEE
           END-IF
           DISPLAY 'ALLOCATION:'
           DISPLAY '  LATE FEES: $' WS-ALLOC-LATE-FEE
           DISPLAY '  INTEREST:  $' WS-ALLOC-INTEREST
           DISPLAY '  ESCROW:    $' WS-ALLOC-ESCROW
           DISPLAY '  PRINCIPAL: $' WS-ALLOC-PRINCIPAL
           DISPLAY 'NEW BALANCES:'
           DISPLAY '  PRINCIPAL: $' WS-PRINCIPAL-BAL
           DISPLAY '  INTEREST:  $' WS-INTEREST-BAL
           DISPLAY '  LATE FEES: $' WS-LATE-FEE-BAL.
