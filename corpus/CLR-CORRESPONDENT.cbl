       IDENTIFICATION DIVISION.
       PROGRAM-ID. CLR-CORRESPONDENT.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ROUTING-NUM             PIC X(9).
       01 WS-CORR-TABLE.
           05 WS-CORR OCCURS 10.
               10 WS-CR-ABA          PIC X(9).
               10 WS-CR-NAME         PIC X(25).
               10 WS-CR-REGION       PIC X(2).
               10 WS-CR-FEE          PIC S9(5)V99 COMP-3.
       01 WS-CR-IDX                  PIC 9(2).
       01 WS-CORR-COUNT              PIC 9(2).
       01 WS-FOUND-FLAG              PIC X VALUE 'N'.
           88 WS-FOUND               VALUE 'Y'.
       01 WS-MATCH-IDX               PIC 9(2).
       01 WS-TXN-AMOUNT              PIC S9(9)V99 COMP-3.
       01 WS-TOTAL-FEE               PIC S9(5)V99 COMP-3.
       01 WS-ROUTE-METHOD            PIC X(1).
           88 WS-DIRECT              VALUE 'D'.
           88 WS-INTERMEDIARY        VALUE 'I'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-FIND-CORRESPONDENT
           PERFORM 3000-CALC-FEE
           PERFORM 4000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'N' TO WS-FOUND-FLAG
           MOVE 0 TO WS-TOTAL-FEE.
       2000-FIND-CORRESPONDENT.
           PERFORM VARYING WS-CR-IDX FROM 1 BY 1
               UNTIL WS-CR-IDX > WS-CORR-COUNT
               OR WS-FOUND
               IF WS-CR-ABA(WS-CR-IDX) = WS-ROUTING-NUM
                   MOVE 'Y' TO WS-FOUND-FLAG
                   MOVE WS-CR-IDX TO WS-MATCH-IDX
                   SET WS-DIRECT TO TRUE
               END-IF
           END-PERFORM
           IF WS-FOUND-FLAG = 'N'
               SET WS-INTERMEDIARY TO TRUE
           END-IF.
       3000-CALC-FEE.
           IF WS-FOUND
               MOVE WS-CR-FEE(WS-MATCH-IDX) TO
                   WS-TOTAL-FEE
           ELSE
               COMPUTE WS-TOTAL-FEE =
                   WS-TXN-AMOUNT * 0.001
               IF WS-TOTAL-FEE < 15
                   MOVE 15.00 TO WS-TOTAL-FEE
               END-IF
           END-IF.
       4000-DISPLAY-RESULTS.
           DISPLAY 'CORRESPONDENT ROUTING'
           DISPLAY '====================='
           DISPLAY 'ROUTING: ' WS-ROUTING-NUM
           DISPLAY 'AMOUNT:  ' WS-TXN-AMOUNT
           IF WS-FOUND
               DISPLAY 'BANK:    '
                   WS-CR-NAME(WS-MATCH-IDX)
               DISPLAY 'ROUTE:   DIRECT'
           ELSE
               DISPLAY 'ROUTE:   INTERMEDIARY'
           END-IF
           DISPLAY 'FEE:     ' WS-TOTAL-FEE.
