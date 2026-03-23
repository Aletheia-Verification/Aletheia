       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-ALTER-ANNUITY-ROUTE.
      *================================================================
      * MANUAL REVIEW: ALTER statement
      * Legacy annuity routing program that uses ALTER to dynamically
      * switch between fixed, variable, and indexed payout paragraphs.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CONTRACT.
           05 WS-CONTRACT-ID          PIC X(12).
           05 WS-ANNUITY-TYPE         PIC X(1).
               88 ANN-FIXED           VALUE 'F'.
               88 ANN-VARIABLE        VALUE 'V'.
               88 ANN-INDEXED         VALUE 'I'.
           05 WS-ACCOUNT-VALUE        PIC S9(11)V99 COMP-3.
           05 WS-PAYOUT-AMT           PIC S9(9)V99 COMP-3.
       01 WS-RATES.
           05 WS-FIXED-RATE           PIC S9(1)V9(4) COMP-3
               VALUE 0.0350.
           05 WS-VARIABLE-RETURN      PIC S9(3)V9(4) COMP-3
               VALUE 0.0820.
           05 WS-INDEX-CAP            PIC S9(1)V9(4) COMP-3
               VALUE 0.0700.
           05 WS-INDEX-FLOOR          PIC S9(1)V9(4) COMP-3
               VALUE 0.0100.
           05 WS-INDEX-RETURN         PIC S9(3)V9(4) COMP-3
               VALUE 0.0550.
       01 WS-RESULT                   PIC X(20).
       01 WS-CALC-RATE                PIC S9(1)V9(4) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-SET-ROUTING
           PERFORM 3000-DISPATCH
           PERFORM 4000-CALC-PAYOUT
           PERFORM 5000-DISPLAY
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'ANN-ALT-0099' TO WS-CONTRACT-ID
           MOVE 'V' TO WS-ANNUITY-TYPE
           MOVE 350000.00 TO WS-ACCOUNT-VALUE.
       2000-SET-ROUTING.
           IF ANN-FIXED
               ALTER 3000-DISPATCH TO PROCEED TO
                   3100-FIXED-CALC
           END-IF
           IF ANN-VARIABLE
               ALTER 3000-DISPATCH TO PROCEED TO
                   3200-VARIABLE-CALC
           END-IF
           IF ANN-INDEXED
               ALTER 3000-DISPATCH TO PROCEED TO
                   3300-INDEXED-CALC
           END-IF.
       3000-DISPATCH.
           GO TO 3100-FIXED-CALC.
       3100-FIXED-CALC.
           MOVE WS-FIXED-RATE TO WS-CALC-RATE
           MOVE 'FIXED ANNUITY       ' TO WS-RESULT
           GO TO 4000-CALC-PAYOUT.
       3200-VARIABLE-CALC.
           MOVE WS-VARIABLE-RETURN TO WS-CALC-RATE
           MOVE 'VARIABLE ANNUITY    ' TO WS-RESULT
           GO TO 4000-CALC-PAYOUT.
       3300-INDEXED-CALC.
           IF WS-INDEX-RETURN > WS-INDEX-CAP
               MOVE WS-INDEX-CAP TO WS-CALC-RATE
           ELSE
               IF WS-INDEX-RETURN < WS-INDEX-FLOOR
                   MOVE WS-INDEX-FLOOR TO WS-CALC-RATE
               ELSE
                   MOVE WS-INDEX-RETURN TO WS-CALC-RATE
               END-IF
           END-IF
           MOVE 'INDEXED ANNUITY     ' TO WS-RESULT
           GO TO 4000-CALC-PAYOUT.
       4000-CALC-PAYOUT.
           COMPUTE WS-PAYOUT-AMT =
               WS-ACCOUNT-VALUE * WS-CALC-RATE.
       5000-DISPLAY.
           DISPLAY 'ALTER-BASED ANNUITY ROUTING'
           DISPLAY '==========================='
           DISPLAY 'CONTRACT:    ' WS-CONTRACT-ID
           DISPLAY 'TYPE:        ' WS-RESULT
           DISPLAY 'ACCT VALUE:  ' WS-ACCOUNT-VALUE
           DISPLAY 'CALC RATE:   ' WS-CALC-RATE
           DISPLAY 'PAYOUT:      ' WS-PAYOUT-AMT.
