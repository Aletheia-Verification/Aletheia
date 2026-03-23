       IDENTIFICATION DIVISION.
       PROGRAM-ID. INS-COINSURE-SPLIT.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CLAIM-AMOUNT            PIC S9(9)V99 COMP-3.
       01 WS-COINSURE-TABLE.
           05 WS-CARRIER OCCURS 5.
               10 WS-CR-NAME         PIC X(15).
               10 WS-CR-PCT          PIC S9(3)V99 COMP-3.
               10 WS-CR-SHARE        PIC S9(9)V99 COMP-3.
               10 WS-CR-MAX          PIC S9(9)V99 COMP-3.
               10 WS-CR-ACTUAL       PIC S9(9)V99 COMP-3.
       01 WS-CR-IDX                  PIC 9(1).
       01 WS-CARRIER-COUNT           PIC 9(1).
       01 WS-TOTAL-PCT               PIC S9(3)V99 COMP-3.
       01 WS-TOTAL-ALLOC             PIC S9(9)V99 COMP-3.
       01 WS-REMAINDER               PIC S9(7)V99 COMP-3.
       01 WS-VALID-FLAG              PIC X VALUE 'N'.
           88 WS-IS-VALID            VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-VALIDATE-SPLIT
           IF WS-IS-VALID
               PERFORM 3000-CALC-SHARES
               PERFORM 4000-APPLY-LIMITS
           END-IF
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-PCT
           MOVE 0 TO WS-TOTAL-ALLOC
           MOVE 0 TO WS-REMAINDER
           MOVE 'N' TO WS-VALID-FLAG.
       2000-VALIDATE-SPLIT.
           PERFORM VARYING WS-CR-IDX FROM 1 BY 1
               UNTIL WS-CR-IDX > WS-CARRIER-COUNT
               ADD WS-CR-PCT(WS-CR-IDX) TO WS-TOTAL-PCT
           END-PERFORM
           IF WS-TOTAL-PCT = 100
               MOVE 'Y' TO WS-VALID-FLAG
           END-IF.
       3000-CALC-SHARES.
           PERFORM VARYING WS-CR-IDX FROM 1 BY 1
               UNTIL WS-CR-IDX > WS-CARRIER-COUNT
               COMPUTE WS-CR-SHARE(WS-CR-IDX) =
                   WS-CLAIM-AMOUNT *
                   WS-CR-PCT(WS-CR-IDX) / 100
               MOVE WS-CR-SHARE(WS-CR-IDX) TO
                   WS-CR-ACTUAL(WS-CR-IDX)
           END-PERFORM.
       4000-APPLY-LIMITS.
           MOVE 0 TO WS-TOTAL-ALLOC
           PERFORM VARYING WS-CR-IDX FROM 1 BY 1
               UNTIL WS-CR-IDX > WS-CARRIER-COUNT
               IF WS-CR-ACTUAL(WS-CR-IDX) >
                   WS-CR-MAX(WS-CR-IDX)
                   IF WS-CR-MAX(WS-CR-IDX) > 0
                       MOVE WS-CR-MAX(WS-CR-IDX) TO
                           WS-CR-ACTUAL(WS-CR-IDX)
                   END-IF
               END-IF
               ADD WS-CR-ACTUAL(WS-CR-IDX) TO
                   WS-TOTAL-ALLOC
           END-PERFORM
           COMPUTE WS-REMAINDER =
               WS-CLAIM-AMOUNT - WS-TOTAL-ALLOC.
       5000-DISPLAY-RESULTS.
           DISPLAY 'COINSURANCE SPLIT'
           DISPLAY '================='
           DISPLAY 'CLAIM AMOUNT: ' WS-CLAIM-AMOUNT
           IF WS-IS-VALID
               PERFORM VARYING WS-CR-IDX FROM 1 BY 1
                   UNTIL WS-CR-IDX > WS-CARRIER-COUNT
                   DISPLAY '  ' WS-CR-NAME(WS-CR-IDX)
                       ' PCT=' WS-CR-PCT(WS-CR-IDX)
                       ' SHARE=' WS-CR-ACTUAL(WS-CR-IDX)
               END-PERFORM
               DISPLAY 'TOTAL ALLOC:  ' WS-TOTAL-ALLOC
               IF WS-REMAINDER > 0
                   DISPLAY 'REMAINDER:    ' WS-REMAINDER
               END-IF
           ELSE
               DISPLAY 'ERROR: PERCENTAGES DO NOT SUM TO 100'
           END-IF.
