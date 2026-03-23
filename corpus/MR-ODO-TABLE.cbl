       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-ODO-TABLE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-BATCH-HEADER.
           05 WS-BATCH-ID            PIC X(10).
           05 WS-BATCH-DATE          PIC 9(8).
           05 WS-TXN-COUNT           PIC 9(3).
       01 WS-TXN-TABLE.
           05 WS-TXN-ENTRY OCCURS 1 TO 100 TIMES
               DEPENDING ON WS-TXN-COUNT.
               10 WS-TE-ACCT         PIC X(12).
               10 WS-TE-TYPE         PIC X(2).
               10 WS-TE-AMOUNT       PIC S9(9)V99 COMP-3.
               10 WS-TE-STATUS       PIC X(1).
                   88 WS-TE-PENDING  VALUE 'P'.
                   88 WS-TE-POSTED   VALUE 'D'.
                   88 WS-TE-REJECTED VALUE 'R'.
       01 WS-IDX                     PIC 9(3).
       01 WS-TOTALS.
           05 WS-TOTAL-DEBITS        PIC S9(11)V99 COMP-3.
           05 WS-TOTAL-CREDITS       PIC S9(11)V99 COMP-3.
           05 WS-NET-AMOUNT          PIC S9(11)V99 COMP-3.
           05 WS-POSTED-COUNT        PIC S9(3) COMP-3.
           05 WS-REJECTED-COUNT      PIC S9(3) COMP-3.
       01 WS-PROCESS-FLAG            PIC X VALUE 'Y'.
           88 WS-CONTINUE             VALUE 'Y'.
       01 WS-VALID-FLAG              PIC X VALUE 'Y'.
           88 WS-VALID-TXN            VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           IF WS-TXN-COUNT > 0
               PERFORM 2000-PROCESS-BATCH
               PERFORM 3000-CALC-TOTALS
           END-IF
           PERFORM 4000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-DEBITS
           MOVE 0 TO WS-TOTAL-CREDITS
           MOVE 0 TO WS-NET-AMOUNT
           MOVE 0 TO WS-POSTED-COUNT
           MOVE 0 TO WS-REJECTED-COUNT.
       2000-PROCESS-BATCH.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-TXN-COUNT
               MOVE 'Y' TO WS-VALID-FLAG
               PERFORM 2100-VALIDATE-TXN
               IF WS-VALID-TXN
                   PERFORM 2200-POST-TXN
               ELSE
                   MOVE 'R' TO WS-TE-STATUS(WS-IDX)
                   ADD 1 TO WS-REJECTED-COUNT
               END-IF
           END-PERFORM.
       2100-VALIDATE-TXN.
           IF WS-TE-AMOUNT(WS-IDX) <= 0
               MOVE 'N' TO WS-VALID-FLAG
           END-IF
           IF WS-TE-ACCT(WS-IDX) = SPACES
               MOVE 'N' TO WS-VALID-FLAG
           END-IF.
       2200-POST-TXN.
           EVALUATE WS-TE-TYPE(WS-IDX)
               WHEN 'DB'
                   ADD WS-TE-AMOUNT(WS-IDX) TO
                       WS-TOTAL-DEBITS
               WHEN 'CR'
                   ADD WS-TE-AMOUNT(WS-IDX) TO
                       WS-TOTAL-CREDITS
               WHEN OTHER
                   MOVE 'R' TO WS-TE-STATUS(WS-IDX)
                   ADD 1 TO WS-REJECTED-COUNT
           END-EVALUATE
           IF WS-TE-STATUS(WS-IDX) NOT = 'R'
               MOVE 'D' TO WS-TE-STATUS(WS-IDX)
               ADD 1 TO WS-POSTED-COUNT
           END-IF.
       3000-CALC-TOTALS.
           COMPUTE WS-NET-AMOUNT =
               WS-TOTAL-DEBITS - WS-TOTAL-CREDITS.
       4000-DISPLAY-RESULTS.
           DISPLAY 'ODO BATCH PROCESSING REPORT'
           DISPLAY '==========================='
           DISPLAY 'BATCH ID:      ' WS-BATCH-ID
           DISPLAY 'TXN COUNT:     ' WS-TXN-COUNT
           DISPLAY 'POSTED:        ' WS-POSTED-COUNT
           DISPLAY 'REJECTED:      ' WS-REJECTED-COUNT
           DISPLAY 'TOTAL DEBITS:  ' WS-TOTAL-DEBITS
           DISPLAY 'TOTAL CREDITS: ' WS-TOTAL-CREDITS
           DISPLAY 'NET AMOUNT:    ' WS-NET-AMOUNT.
