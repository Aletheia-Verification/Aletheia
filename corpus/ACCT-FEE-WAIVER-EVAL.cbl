       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCT-FEE-WAIVER-EVAL.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ACCT-INFO.
           05 WS-ACCT-NUM         PIC X(12).
           05 WS-ACCT-TYPE        PIC X(2).
               88 AT-CHECKING     VALUE 'CK'.
               88 AT-SAVINGS      VALUE 'SV'.
               88 AT-MMA          VALUE 'MM'.
           05 WS-AVG-BALANCE      PIC S9(9)V99 COMP-3.
           05 WS-DIRECT-DEP       PIC X VALUE 'N'.
               88 HAS-DD          VALUE 'Y'.
           05 WS-COMBINED-BAL     PIC S9(11)V99 COMP-3.
       01 WS-FEE-TABLE.
           05 WS-FEE OCCURS 6 TIMES.
               10 WS-FEE-CODE     PIC X(4).
               10 WS-FEE-DESC     PIC X(20).
               10 WS-FEE-AMT      PIC S9(5)V99 COMP-3.
               10 WS-FEE-WAIVED   PIC X VALUE 'N'.
                   88 IS-WAIVED   VALUE 'Y'.
               10 WS-WAIVE-REASON PIC X(20).
       01 WS-FEE-COUNT            PIC 9 VALUE 6.
       01 WS-FEE-IDX              PIC 9.
       01 WS-TOTAL-FEES           PIC S9(7)V99 COMP-3.
       01 WS-TOTAL-WAIVED         PIC S9(7)V99 COMP-3.
       01 WS-NET-FEES             PIC S9(7)V99 COMP-3.
       01 WS-WAIVE-COUNT          PIC 9.
       01 WS-MIN-BAL-WAIVER       PIC S9(9)V99 COMP-3
           VALUE 5000.00.
       01 WS-COMBINED-WAIVER      PIC S9(9)V99 COMP-3
           VALUE 25000.00.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-EVALUATE-WAIVERS
           PERFORM 3000-CALC-TOTALS
           PERFORM 4000-OUTPUT
           STOP RUN.
       1000-INIT.
           MOVE 0 TO WS-TOTAL-FEES
           MOVE 0 TO WS-TOTAL-WAIVED
           MOVE 0 TO WS-WAIVE-COUNT.
       2000-EVALUATE-WAIVERS.
           PERFORM VARYING WS-FEE-IDX FROM 1 BY 1
               UNTIL WS-FEE-IDX > WS-FEE-COUNT
               PERFORM 2100-CHECK-WAIVER-RULES
           END-PERFORM.
       2100-CHECK-WAIVER-RULES.
           IF WS-AVG-BALANCE >= WS-MIN-BAL-WAIVER
               MOVE 'Y' TO WS-FEE-WAIVED(WS-FEE-IDX)
               MOVE 'MIN BALANCE MET     '
                   TO WS-WAIVE-REASON(WS-FEE-IDX)
           ELSE
               IF HAS-DD
                   IF AT-CHECKING
                       MOVE 'Y' TO WS-FEE-WAIVED(WS-FEE-IDX)
                       MOVE 'DIRECT DEPOSIT      '
                           TO WS-WAIVE-REASON(WS-FEE-IDX)
                   END-IF
               ELSE
                   IF WS-COMBINED-BAL >= WS-COMBINED-WAIVER
                       MOVE 'Y' TO WS-FEE-WAIVED(WS-FEE-IDX)
                       MOVE 'COMBINED BALANCE    '
                           TO WS-WAIVE-REASON(WS-FEE-IDX)
                   END-IF
               END-IF
           END-IF.
       3000-CALC-TOTALS.
           PERFORM VARYING WS-FEE-IDX FROM 1 BY 1
               UNTIL WS-FEE-IDX > WS-FEE-COUNT
               ADD WS-FEE-AMT(WS-FEE-IDX) TO WS-TOTAL-FEES
               IF IS-WAIVED(WS-FEE-IDX)
                   ADD WS-FEE-AMT(WS-FEE-IDX)
                       TO WS-TOTAL-WAIVED
                   ADD 1 TO WS-WAIVE-COUNT
               END-IF
           END-PERFORM
           COMPUTE WS-NET-FEES =
               WS-TOTAL-FEES - WS-TOTAL-WAIVED.
       4000-OUTPUT.
           DISPLAY 'FEE WAIVER EVALUATION'
           DISPLAY '====================='
           DISPLAY 'ACCOUNT:     ' WS-ACCT-NUM
           DISPLAY 'TYPE:        ' WS-ACCT-TYPE
           DISPLAY 'AVG BALANCE: $' WS-AVG-BALANCE
           PERFORM VARYING WS-FEE-IDX FROM 1 BY 1
               UNTIL WS-FEE-IDX > WS-FEE-COUNT
               IF IS-WAIVED(WS-FEE-IDX)
                   DISPLAY '  ' WS-FEE-DESC(WS-FEE-IDX)
                       ' $' WS-FEE-AMT(WS-FEE-IDX)
                       ' WAIVED: '
                       WS-WAIVE-REASON(WS-FEE-IDX)
               ELSE
                   DISPLAY '  ' WS-FEE-DESC(WS-FEE-IDX)
                       ' $' WS-FEE-AMT(WS-FEE-IDX)
                       ' CHARGED'
               END-IF
           END-PERFORM
           DISPLAY 'TOTAL FEES:  $' WS-TOTAL-FEES
           DISPLAY 'WAIVED:      $' WS-TOTAL-WAIVED
           DISPLAY 'NET FEES:    $' WS-NET-FEES.
