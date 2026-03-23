       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCT-TRUST-DIST.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-TRUST-INFO.
           05 WS-TRUST-ID        PIC X(12).
           05 WS-TRUST-TYPE      PIC X(1).
               88 TT-REVOCABLE   VALUE 'R'.
               88 TT-IRREVOCABLE VALUE 'I'.
               88 TT-CHARITABLE  VALUE 'C'.
           05 WS-TRUST-BALANCE   PIC S9(11)V99 COMP-3.
           05 WS-INCOME-EARNED   PIC S9(9)V99 COMP-3.
       01 WS-BENEFICIARIES.
           05 WS-BENE OCCURS 4 TIMES.
               10 WS-BN-NAME     PIC X(25).
               10 WS-BN-PCT      PIC 9(3).
               10 WS-BN-TYPE     PIC X(1).
                   88 BN-INCOME  VALUE 'I'.
                   88 BN-PRINCIPAL VALUE 'P'.
                   88 BN-BOTH    VALUE 'B'.
               10 WS-BN-DIST-AMT PIC S9(9)V99 COMP-3.
       01 WS-BENE-COUNT          PIC 9 VALUE 4.
       01 WS-IDX                 PIC 9.
       01 WS-DIST-TYPE           PIC X(1).
           88 DT-INCOME          VALUE 'I'.
           88 DT-PRINCIPAL       VALUE 'P'.
       01 WS-TOTAL-DIST          PIC S9(9)V99 COMP-3.
       01 WS-TAX-WITHHOLD        PIC S9(7)V99 COMP-3.
       01 WS-NET-DIST            PIC S9(9)V99 COMP-3.
       01 WS-TAX-RATE            PIC S9(1)V99 COMP-3.
       01 WS-CHECK-TOTAL-PCT     PIC 9(3).
       01 WS-VALID               PIC X VALUE 'N'.
           88 IS-VALID           VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-VALIDATE
           IF IS-VALID
               PERFORM 2000-CALC-DISTRIBUTIONS
               PERFORM 3000-CALC-TAX
               PERFORM 4000-DEDUCT-FROM-TRUST
           END-IF
           PERFORM 5000-OUTPUT
           STOP RUN.
       1000-VALIDATE.
           MOVE 0 TO WS-CHECK-TOTAL-PCT
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-BENE-COUNT
               ADD WS-BN-PCT(WS-IDX) TO WS-CHECK-TOTAL-PCT
           END-PERFORM
           IF WS-CHECK-TOTAL-PCT <= 100
               MOVE 'Y' TO WS-VALID
           ELSE
               DISPLAY 'TOTAL PCT EXCEEDS 100'
           END-IF.
       2000-CALC-DISTRIBUTIONS.
           MOVE 0 TO WS-TOTAL-DIST
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-BENE-COUNT
               IF DT-INCOME
                   IF BN-INCOME(WS-IDX) OR BN-BOTH(WS-IDX)
                       COMPUTE WS-BN-DIST-AMT(WS-IDX) =
                           WS-INCOME-EARNED *
                           WS-BN-PCT(WS-IDX) / 100
                   ELSE
                       MOVE 0 TO WS-BN-DIST-AMT(WS-IDX)
                   END-IF
               ELSE
                   IF BN-PRINCIPAL(WS-IDX)
                       OR BN-BOTH(WS-IDX)
                       COMPUTE WS-BN-DIST-AMT(WS-IDX) =
                           WS-TRUST-BALANCE *
                           WS-BN-PCT(WS-IDX) / 100
                   ELSE
                       MOVE 0 TO WS-BN-DIST-AMT(WS-IDX)
                   END-IF
               END-IF
               ADD WS-BN-DIST-AMT(WS-IDX) TO WS-TOTAL-DIST
           END-PERFORM.
       3000-CALC-TAX.
           EVALUATE TRUE
               WHEN TT-REVOCABLE
                   MOVE 0 TO WS-TAX-RATE
               WHEN TT-IRREVOCABLE
                   MOVE 0.37 TO WS-TAX-RATE
               WHEN TT-CHARITABLE
                   MOVE 0 TO WS-TAX-RATE
           END-EVALUATE
           COMPUTE WS-TAX-WITHHOLD =
               WS-TOTAL-DIST * WS-TAX-RATE
           COMPUTE WS-NET-DIST =
               WS-TOTAL-DIST - WS-TAX-WITHHOLD.
       4000-DEDUCT-FROM-TRUST.
           IF DT-INCOME
               SUBTRACT WS-TOTAL-DIST FROM WS-INCOME-EARNED
           ELSE
               SUBTRACT WS-TOTAL-DIST FROM WS-TRUST-BALANCE
           END-IF.
       5000-OUTPUT.
           DISPLAY 'TRUST DISTRIBUTION REPORT'
           DISPLAY '========================='
           DISPLAY 'TRUST:     ' WS-TRUST-ID
           DISPLAY 'TYPE:      ' WS-TRUST-TYPE
           DISPLAY 'BALANCE:   $' WS-TRUST-BALANCE
           IF IS-VALID
               PERFORM VARYING WS-IDX FROM 1 BY 1
                   UNTIL WS-IDX > WS-BENE-COUNT
                   IF WS-BN-DIST-AMT(WS-IDX) > 0
                       DISPLAY '  ' WS-BN-NAME(WS-IDX)
                           ' ' WS-BN-PCT(WS-IDX) '%'
                           ' $' WS-BN-DIST-AMT(WS-IDX)
                   END-IF
               END-PERFORM
               DISPLAY 'GROSS DIST:$' WS-TOTAL-DIST
               DISPLAY 'TAX W/H:   $' WS-TAX-WITHHOLD
               DISPLAY 'NET DIST:  $' WS-NET-DIST
           ELSE
               DISPLAY 'INVALID DISTRIBUTION REQUEST'
           END-IF.
