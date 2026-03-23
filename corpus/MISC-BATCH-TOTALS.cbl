       IDENTIFICATION DIVISION.
       PROGRAM-ID. MISC-BATCH-TOTALS.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-BATCH-TABLE.
           05 WS-BATCH OCCURS 10.
               10 WS-BT-ID           PIC X(8).
               10 WS-BT-DEBITS       PIC S9(11)V99 COMP-3.
               10 WS-BT-CREDITS      PIC S9(11)V99 COMP-3.
               10 WS-BT-COUNT        PIC S9(5) COMP-3.
               10 WS-BT-HASH         PIC S9(11) COMP-3.
       01 WS-BT-IDX                  PIC 9(2).
       01 WS-BATCH-COUNT             PIC 9(2).
       01 WS-GRAND-DB                PIC S9(13)V99 COMP-3.
       01 WS-GRAND-CR                PIC S9(13)V99 COMP-3.
       01 WS-GRAND-COUNT             PIC S9(7) COMP-3.
       01 WS-GRAND-HASH              PIC S9(13) COMP-3.
       01 WS-EXPECTED-DB             PIC S9(13)V99 COMP-3.
       01 WS-EXPECTED-CR             PIC S9(13)V99 COMP-3.
       01 WS-VARIANCE-DB             PIC S9(11)V99 COMP-3.
       01 WS-VARIANCE-CR             PIC S9(11)V99 COMP-3.
       01 WS-BALANCED-FLAG           PIC X VALUE 'N'.
           88 WS-IS-BALANCED         VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-ACCUMULATE
           PERFORM 3000-CHECK-BALANCE
           PERFORM 4000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-GRAND-DB
           MOVE 0 TO WS-GRAND-CR
           MOVE 0 TO WS-GRAND-COUNT
           MOVE 0 TO WS-GRAND-HASH.
       2000-ACCUMULATE.
           PERFORM VARYING WS-BT-IDX FROM 1 BY 1
               UNTIL WS-BT-IDX > WS-BATCH-COUNT
               ADD WS-BT-DEBITS(WS-BT-IDX) TO WS-GRAND-DB
               ADD WS-BT-CREDITS(WS-BT-IDX) TO WS-GRAND-CR
               ADD WS-BT-COUNT(WS-BT-IDX) TO WS-GRAND-COUNT
               ADD WS-BT-HASH(WS-BT-IDX) TO WS-GRAND-HASH
           END-PERFORM.
       3000-CHECK-BALANCE.
           COMPUTE WS-VARIANCE-DB =
               WS-GRAND-DB - WS-EXPECTED-DB
           COMPUTE WS-VARIANCE-CR =
               WS-GRAND-CR - WS-EXPECTED-CR
           IF WS-VARIANCE-DB = 0
               IF WS-VARIANCE-CR = 0
                   MOVE 'Y' TO WS-BALANCED-FLAG
               END-IF
           END-IF.
       4000-DISPLAY-RESULTS.
           DISPLAY 'BATCH CONTROL TOTALS'
           DISPLAY '===================='
           DISPLAY 'BATCHES:   ' WS-BATCH-COUNT
           DISPLAY 'DEBITS:    ' WS-GRAND-DB
           DISPLAY 'CREDITS:   ' WS-GRAND-CR
           DISPLAY 'TXN COUNT: ' WS-GRAND-COUNT
           DISPLAY 'HASH:      ' WS-GRAND-HASH
           IF WS-IS-BALANCED
               DISPLAY 'STATUS: BALANCED'
           ELSE
               DISPLAY 'STATUS: OUT OF BALANCE'
               DISPLAY 'DB VAR:    ' WS-VARIANCE-DB
               DISPLAY 'CR VAR:    ' WS-VARIANCE-CR
           END-IF.
