       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOAN-ASSUMABILITY.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-EXISTING-LOAN.
           05 WS-LOAN-NUM        PIC X(12).
           05 WS-LOAN-TYPE       PIC X(2).
               88 LT-FHA         VALUE 'FH'.
               88 LT-VA          VALUE 'VA'.
               88 LT-CONV        VALUE 'CV'.
               88 LT-USDA        VALUE 'UD'.
           05 WS-ORIG-BAL        PIC S9(9)V99 COMP-3.
           05 WS-CURRENT-BAL     PIC S9(9)V99 COMP-3.
           05 WS-RATE             PIC S9(2)V9(4) COMP-3.
           05 WS-ORIG-DATE       PIC 9(8).
       01 WS-NEW-BORROWER.
           05 WS-NB-NAME         PIC X(30).
           05 WS-NB-SCORE        PIC 9(3).
           05 WS-NB-INCOME       PIC S9(9)V99 COMP-3.
           05 WS-NB-DTI          PIC S9(3)V99 COMP-3.
       01 WS-PROPERTY-VALUE      PIC S9(11)V99 COMP-3.
       01 WS-ASSUMABLE           PIC X VALUE 'N'.
           88 IS-ASSUMABLE       VALUE 'Y'.
       01 WS-QUALIFY-STATUS      PIC X(15).
       01 WS-LTV                 PIC S9(3)V99 COMP-3.
       01 WS-EQUITY              PIC S9(9)V99 COMP-3.
       01 WS-DOWN-PAYMENT        PIC S9(9)V99 COMP-3.
       01 WS-SAVINGS             PIC S9(9)V99 COMP-3.
       01 WS-MARKET-RATE         PIC S9(2)V9(4) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-CHECK-ASSUMABILITY
           IF IS-ASSUMABLE
               PERFORM 2000-QUALIFY-BORROWER
               PERFORM 3000-CALC-EQUITY
               PERFORM 4000-CALC-SAVINGS
           END-IF
           PERFORM 5000-OUTPUT
           STOP RUN.
       1000-CHECK-ASSUMABILITY.
           EVALUATE TRUE
               WHEN LT-FHA
                   MOVE 'Y' TO WS-ASSUMABLE
               WHEN LT-VA
                   MOVE 'Y' TO WS-ASSUMABLE
               WHEN LT-USDA
                   MOVE 'Y' TO WS-ASSUMABLE
               WHEN LT-CONV
                   MOVE 'N' TO WS-ASSUMABLE
                   MOVE 'NOT ASSUMABLE  ' TO
                       WS-QUALIFY-STATUS
               WHEN OTHER
                   MOVE 'N' TO WS-ASSUMABLE
           END-EVALUATE.
       2000-QUALIFY-BORROWER.
           IF WS-NB-SCORE < 620
               MOVE 'SCORE TOO LOW  ' TO WS-QUALIFY-STATUS
               MOVE 'N' TO WS-ASSUMABLE
           ELSE
               IF WS-NB-DTI > 43.00
                   MOVE 'DTI TOO HIGH   ' TO
                       WS-QUALIFY-STATUS
                   MOVE 'N' TO WS-ASSUMABLE
               ELSE
                   MOVE 'QUALIFIED      ' TO
                       WS-QUALIFY-STATUS
               END-IF
           END-IF.
       3000-CALC-EQUITY.
           COMPUTE WS-EQUITY =
               WS-PROPERTY-VALUE - WS-CURRENT-BAL
           MOVE WS-EQUITY TO WS-DOWN-PAYMENT
           IF WS-PROPERTY-VALUE > 0
               COMPUTE WS-LTV =
                   (WS-CURRENT-BAL /
                    WS-PROPERTY-VALUE) * 100
           END-IF.
       4000-CALC-SAVINGS.
           COMPUTE WS-SAVINGS =
               (WS-MARKET-RATE - WS-RATE) *
               WS-CURRENT-BAL.
       5000-OUTPUT.
           DISPLAY 'LOAN ASSUMPTION ANALYSIS'
           DISPLAY '========================'
           DISPLAY 'LOAN:       ' WS-LOAN-NUM
           DISPLAY 'TYPE:       ' WS-LOAN-TYPE
           DISPLAY 'RATE:       ' WS-RATE
           DISPLAY 'BALANCE:    $' WS-CURRENT-BAL
           DISPLAY 'ASSUMABLE:  ' WS-ASSUMABLE
           DISPLAY 'STATUS:     ' WS-QUALIFY-STATUS
           IF IS-ASSUMABLE
               DISPLAY 'BORROWER:   ' WS-NB-NAME
               DISPLAY 'EQUITY:     $' WS-EQUITY
               DISPLAY 'DOWN PMT:   $' WS-DOWN-PAYMENT
               DISPLAY 'LTV:        ' WS-LTV '%'
               DISPLAY 'MKT RATE:   ' WS-MARKET-RATE
               DISPLAY 'RATE SAVE:  $' WS-SAVINGS
           END-IF.
