       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-ODO-AMORT-SCHED.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-LOAN-PARAMS.
           05 WS-LOAN-ID         PIC X(12).
           05 WS-PRINCIPAL       PIC S9(9)V99 COMP-3.
           05 WS-RATE             PIC S9(2)V9(4) COMP-3.
           05 WS-TERM-MONTHS     PIC 9(3).
       01 WS-PAYMENT-COUNT       PIC 9(3).
       01 WS-SCHEDULE.
           05 WS-PMT OCCURS 1 TO 360 TIMES
               DEPENDING ON WS-PAYMENT-COUNT.
               10 WS-PM-NUM       PIC 9(3).
               10 WS-PM-TOTAL     PIC S9(7)V99 COMP-3.
               10 WS-PM-INTEREST  PIC S9(7)V99 COMP-3.
               10 WS-PM-PRINCIPAL PIC S9(7)V99 COMP-3.
               10 WS-PM-BALANCE   PIC S9(9)V99 COMP-3.
       01 WS-IDX                 PIC 9(3).
       01 WS-MONTHLY-RATE        PIC S9(1)V9(8) COMP-3.
       01 WS-MONTHLY-PMT         PIC S9(7)V99 COMP-3.
       01 WS-BALANCE             PIC S9(9)V99 COMP-3.
       01 WS-TOTAL-INTEREST      PIC S9(9)V99 COMP-3.
       01 WS-TOTAL-PRINCIPAL     PIC S9(9)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-CALC-PAYMENT
           PERFORM 3000-GEN-SCHEDULE
           PERFORM 4000-OUTPUT
           STOP RUN.
       1000-INIT.
           MOVE WS-TERM-MONTHS TO WS-PAYMENT-COUNT
           MOVE WS-PRINCIPAL TO WS-BALANCE
           MOVE 0 TO WS-TOTAL-INTEREST
           MOVE 0 TO WS-TOTAL-PRINCIPAL
           COMPUTE WS-MONTHLY-RATE =
               WS-RATE / 12.
       2000-CALC-PAYMENT.
           IF WS-TERM-MONTHS > 0
               COMPUTE WS-MONTHLY-PMT =
                   WS-PRINCIPAL / WS-TERM-MONTHS +
                   WS-PRINCIPAL * WS-MONTHLY-RATE / 2
           ELSE
               MOVE 0 TO WS-MONTHLY-PMT
           END-IF.
       3000-GEN-SCHEDULE.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-PAYMENT-COUNT
               OR WS-BALANCE <= 0
               MOVE WS-IDX TO WS-PM-NUM(WS-IDX)
               COMPUTE WS-PM-INTEREST(WS-IDX) =
                   WS-BALANCE * WS-MONTHLY-RATE
               COMPUTE WS-PM-PRINCIPAL(WS-IDX) =
                   WS-MONTHLY-PMT - WS-PM-INTEREST(WS-IDX)
               IF WS-PM-PRINCIPAL(WS-IDX) > WS-BALANCE
                   MOVE WS-BALANCE TO
                       WS-PM-PRINCIPAL(WS-IDX)
                   COMPUTE WS-MONTHLY-PMT =
                       WS-PM-PRINCIPAL(WS-IDX) +
                       WS-PM-INTEREST(WS-IDX)
               END-IF
               MOVE WS-MONTHLY-PMT TO WS-PM-TOTAL(WS-IDX)
               SUBTRACT WS-PM-PRINCIPAL(WS-IDX) FROM
                   WS-BALANCE
               MOVE WS-BALANCE TO WS-PM-BALANCE(WS-IDX)
               ADD WS-PM-INTEREST(WS-IDX) TO
                   WS-TOTAL-INTEREST
               ADD WS-PM-PRINCIPAL(WS-IDX) TO
                   WS-TOTAL-PRINCIPAL
           END-PERFORM.
       4000-OUTPUT.
           DISPLAY 'AMORTIZATION SCHEDULE'
           DISPLAY '====================='
           DISPLAY 'LOAN:      ' WS-LOAN-ID
           DISPLAY 'PRINCIPAL: $' WS-PRINCIPAL
           DISPLAY 'RATE:      ' WS-RATE
           DISPLAY 'TERM:      ' WS-TERM-MONTHS ' MO'
           DISPLAY 'PAYMENT:   $' WS-MONTHLY-PMT
           DISPLAY 'TOT INT:   $' WS-TOTAL-INTEREST
           DISPLAY 'TOT PRIN:  $' WS-TOTAL-PRINCIPAL
           DISPLAY 'FINAL BAL: $' WS-BALANCE.
