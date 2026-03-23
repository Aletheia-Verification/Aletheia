       IDENTIFICATION DIVISION.
       PROGRAM-ID. MISC-RATE-COMPARE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-RATE-TABLE.
           05 WS-RATE-ENTRY OCCURS 6.
               10 WS-RE-INST         PIC X(15).
               10 WS-RE-RATE         PIC S9(1)V9(6) COMP-3.
               10 WS-RE-TERM         PIC 9(3).
               10 WS-RE-DIFF         PIC S9(1)V9(6) COMP-3.
       01 WS-RE-IDX                  PIC 9(1).
       01 WS-OUR-RATE                PIC S9(1)V9(6) COMP-3.
       01 WS-BEST-RATE               PIC S9(1)V9(6) COMP-3.
       01 WS-BEST-IDX                PIC 9(1).
       01 WS-COMPETITIVE             PIC X VALUE 'N'.
           88 WS-IS-COMPETITIVE      VALUE 'Y'.
       01 WS-LOAN-AMOUNT             PIC S9(9)V99 COMP-3.
       01 WS-SAVINGS-DIFF            PIC S9(7)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-COMPARE-RATES
           PERFORM 3000-CALC-IMPACT
           PERFORM 4000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-BEST-RATE
           MOVE 0 TO WS-BEST-IDX.
       2000-COMPARE-RATES.
           PERFORM VARYING WS-RE-IDX FROM 1 BY 1
               UNTIL WS-RE-IDX > 6
               COMPUTE WS-RE-DIFF(WS-RE-IDX) =
                   WS-OUR-RATE - WS-RE-RATE(WS-RE-IDX)
               IF WS-RE-RATE(WS-RE-IDX) > WS-BEST-RATE
                   MOVE WS-RE-RATE(WS-RE-IDX) TO
                       WS-BEST-RATE
                   MOVE WS-RE-IDX TO WS-BEST-IDX
               END-IF
           END-PERFORM
           IF WS-OUR-RATE >= WS-BEST-RATE
               MOVE 'Y' TO WS-COMPETITIVE
           END-IF.
       3000-CALC-IMPACT.
           IF WS-BEST-IDX > 0
               COMPUTE WS-SAVINGS-DIFF =
                   WS-LOAN-AMOUNT *
                   (WS-OUR-RATE - WS-BEST-RATE)
           END-IF.
       4000-DISPLAY-RESULTS.
           DISPLAY 'RATE COMPARISON'
           DISPLAY '==============='
           DISPLAY 'OUR RATE:    ' WS-OUR-RATE
           DISPLAY 'BEST MARKET: ' WS-BEST-RATE
           IF WS-IS-COMPETITIVE
               DISPLAY 'STATUS: COMPETITIVE'
           ELSE
               DISPLAY 'STATUS: BELOW MARKET'
           END-IF
           PERFORM VARYING WS-RE-IDX FROM 1 BY 1
               UNTIL WS-RE-IDX > 6
               DISPLAY '  ' WS-RE-INST(WS-RE-IDX)
                   ' RATE=' WS-RE-RATE(WS-RE-IDX)
                   ' DIFF=' WS-RE-DIFF(WS-RE-IDX)
           END-PERFORM.
