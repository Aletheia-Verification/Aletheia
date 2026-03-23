       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCT-GARNISHMENT.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-GARNISH-ORDER.
           05 WS-COURT-ORDER-NUM  PIC X(12).
           05 WS-ORDER-TYPE       PIC X(2).
               88 OT-CHILD-SUPP  VALUE 'CS'.
               88 OT-TAX-LEVY   VALUE 'TL'.
               88 OT-CREDITOR   VALUE 'CR'.
               88 OT-STUDENT    VALUE 'SL'.
           05 WS-ORDER-AMT       PIC S9(7)V99 COMP-3.
           05 WS-PRIORITY        PIC 9.
       01 WS-ACCT-INFO.
           05 WS-ACCT-NUM        PIC X(12).
           05 WS-ACCT-BALANCE    PIC S9(9)V99 COMP-3.
           05 WS-ACCT-TYPE       PIC X(2).
           05 WS-PROTECTED-AMT   PIC S9(7)V99 COMP-3.
       01 WS-EXEMPT-AMT          PIC S9(7)V99 COMP-3.
       01 WS-AVAILABLE-AMT       PIC S9(9)V99 COMP-3.
       01 WS-GARNISH-AMT         PIC S9(7)V99 COMP-3.
       01 WS-MAX-GARNISH-PCT     PIC S9(1)V99 COMP-3.
       01 WS-FEDERAL-EXEMPT      PIC S9(7)V99 COMP-3
           VALUE 2500.00.
       01 WS-RESULT              PIC X(15).
       01 WS-HOLD-AMT            PIC S9(7)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-CALC-EXEMPT
           PERFORM 2000-CALC-AVAILABLE
           PERFORM 3000-APPLY-GARNISHMENT
           PERFORM 4000-OUTPUT
           STOP RUN.
       1000-CALC-EXEMPT.
           EVALUATE TRUE
               WHEN OT-CHILD-SUPP
                   MOVE 0.65 TO WS-MAX-GARNISH-PCT
                   MOVE 0 TO WS-EXEMPT-AMT
               WHEN OT-TAX-LEVY
                   MOVE 1.00 TO WS-MAX-GARNISH-PCT
                   MOVE WS-FEDERAL-EXEMPT TO WS-EXEMPT-AMT
               WHEN OT-CREDITOR
                   MOVE 0.25 TO WS-MAX-GARNISH-PCT
                   MOVE WS-FEDERAL-EXEMPT TO WS-EXEMPT-AMT
                   IF WS-PROTECTED-AMT > WS-EXEMPT-AMT
                       MOVE WS-PROTECTED-AMT TO WS-EXEMPT-AMT
                   END-IF
               WHEN OT-STUDENT
                   MOVE 0.15 TO WS-MAX-GARNISH-PCT
                   MOVE WS-FEDERAL-EXEMPT TO WS-EXEMPT-AMT
               WHEN OTHER
                   MOVE 0.25 TO WS-MAX-GARNISH-PCT
                   MOVE WS-FEDERAL-EXEMPT TO WS-EXEMPT-AMT
           END-EVALUATE.
       2000-CALC-AVAILABLE.
           COMPUTE WS-AVAILABLE-AMT =
               WS-ACCT-BALANCE - WS-EXEMPT-AMT
           IF WS-AVAILABLE-AMT < 0
               MOVE 0 TO WS-AVAILABLE-AMT
           END-IF.
       3000-APPLY-GARNISHMENT.
           IF WS-AVAILABLE-AMT = 0
               MOVE 'EXEMPT         ' TO WS-RESULT
               MOVE 0 TO WS-GARNISH-AMT
           ELSE
               COMPUTE WS-HOLD-AMT =
                   WS-AVAILABLE-AMT * WS-MAX-GARNISH-PCT
               IF WS-HOLD-AMT > WS-ORDER-AMT
                   MOVE WS-ORDER-AMT TO WS-GARNISH-AMT
               ELSE
                   MOVE WS-HOLD-AMT TO WS-GARNISH-AMT
               END-IF
               SUBTRACT WS-GARNISH-AMT FROM WS-ACCT-BALANCE
               IF WS-GARNISH-AMT >= WS-ORDER-AMT
                   MOVE 'FULL GARNISH   ' TO WS-RESULT
               ELSE
                   MOVE 'PARTIAL GARNISH' TO WS-RESULT
               END-IF
           END-IF.
       4000-OUTPUT.
           DISPLAY 'GARNISHMENT PROCESSING'
           DISPLAY '======================'
           DISPLAY 'ORDER:     ' WS-COURT-ORDER-NUM
           DISPLAY 'TYPE:      ' WS-ORDER-TYPE
           DISPLAY 'ORDER AMT: $' WS-ORDER-AMT
           DISPLAY 'ACCT BAL:  $' WS-ACCT-BALANCE
           DISPLAY 'EXEMPT:    $' WS-EXEMPT-AMT
           DISPLAY 'AVAILABLE: $' WS-AVAILABLE-AMT
           DISPLAY 'GARNISHED: $' WS-GARNISH-AMT
           DISPLAY 'RESULT:    ' WS-RESULT.
