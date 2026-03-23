       IDENTIFICATION DIVISION.
       PROGRAM-ID. PERFORM-VARYING-TEST.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-COUNTER             PIC 9(3).
       01  WS-TOTAL               PIC S9(7)V99.
       01  WS-INNER-CTR           PIC 9(3).
       01  WS-OUTER-CTR           PIC 9(3).
       01  WS-PRODUCT             PIC S9(9)V99.
       01  WS-FACTORIAL           PIC S9(15).
       01  WS-TEMP                PIC S9(15).
       01  WS-BALANCE             PIC S9(7)V99.
       01  WS-RATE                PIC 9V9(4).
       01  WS-PERIODS             PIC 9(3).
       01  WS-INTEREST            PIC S9(7)V99.
       01  WS-ITER                PIC 9(3).
       01  WS-DONE-FLAG           PIC X(1).
           88 WS-DONE             VALUE 'Y'.

       PROCEDURE DIVISION.
       MAIN-LOGIC.
           MOVE 0 TO WS-TOTAL

           PERFORM VARYING WS-COUNTER FROM 1 BY 1
               UNTIL WS-COUNTER > 10
               ADD WS-COUNTER TO WS-TOTAL
           END-PERFORM

           MOVE 1 TO WS-FACTORIAL
           MOVE 1 TO WS-TEMP
           PERFORM 5 TIMES
               MULTIPLY WS-TEMP BY WS-FACTORIAL
               ADD 1 TO WS-TEMP
           END-PERFORM

           MOVE 0 TO WS-PRODUCT
           PERFORM VARYING WS-OUTER-CTR FROM 1 BY 1
               UNTIL WS-OUTER-CTR > 5
               PERFORM VARYING WS-INNER-CTR FROM 1 BY 1
                   UNTIL WS-INNER-CTR > 5
                   COMPUTE WS-PRODUCT =
                       WS-PRODUCT +
                       (WS-OUTER-CTR * WS-INNER-CTR)
               END-PERFORM
           END-PERFORM

           MOVE 1000.00 TO WS-BALANCE
           MOVE 0.0500 TO WS-RATE
           MOVE 'N' TO WS-DONE-FLAG
           MOVE 0 TO WS-ITER
           PERFORM UNTIL WS-DONE
               COMPUTE WS-INTEREST =
                   WS-BALANCE * WS-RATE
               ADD WS-INTEREST TO WS-BALANCE
               ADD 1 TO WS-ITER
               IF WS-ITER >= 12
                   MOVE 'Y' TO WS-DONE-FLAG
               END-IF
           END-PERFORM

           MOVE 0 TO WS-TOTAL
           PERFORM CALC-SQUARE
               VARYING WS-COUNTER FROM 1 BY 1
               UNTIL WS-COUNTER > 10

           STOP RUN.

       CALC-SQUARE.
           COMPUTE WS-TEMP = WS-COUNTER * WS-COUNTER
           ADD WS-TEMP TO WS-TOTAL.
