       IDENTIFICATION DIVISION.
       PROGRAM-ID. CLR-NET-SETTLE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-BANK-TABLE.
           05 WS-BANK OCCURS 8.
               10 WS-BK-ID           PIC X(8).
               10 WS-BK-DEBITS       PIC S9(11)V99 COMP-3.
               10 WS-BK-CREDITS      PIC S9(11)V99 COMP-3.
               10 WS-BK-NET          PIC S9(11)V99 COMP-3.
       01 WS-BK-IDX                  PIC 9(1).
       01 WS-BANK-COUNT              PIC 9(1).
       01 WS-GRAND-DEBITS            PIC S9(13)V99 COMP-3.
       01 WS-GRAND-CREDITS           PIC S9(13)V99 COMP-3.
       01 WS-GRAND-NET               PIC S9(13)V99 COMP-3.
       01 WS-BALANCED-FLAG           PIC X VALUE 'N'.
           88 WS-IS-BALANCED         VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-NETS
           PERFORM 3000-CHECK-BALANCE
           PERFORM 4000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-GRAND-DEBITS
           MOVE 0 TO WS-GRAND-CREDITS
           MOVE 0 TO WS-GRAND-NET.
       2000-CALC-NETS.
           PERFORM VARYING WS-BK-IDX FROM 1 BY 1
               UNTIL WS-BK-IDX > WS-BANK-COUNT
               COMPUTE WS-BK-NET(WS-BK-IDX) =
                   WS-BK-DEBITS(WS-BK-IDX) -
                   WS-BK-CREDITS(WS-BK-IDX)
               ADD WS-BK-DEBITS(WS-BK-IDX) TO
                   WS-GRAND-DEBITS
               ADD WS-BK-CREDITS(WS-BK-IDX) TO
                   WS-GRAND-CREDITS
           END-PERFORM
           COMPUTE WS-GRAND-NET =
               WS-GRAND-DEBITS - WS-GRAND-CREDITS.
       3000-CHECK-BALANCE.
           IF WS-GRAND-NET = 0
               MOVE 'Y' TO WS-BALANCED-FLAG
           END-IF.
       4000-DISPLAY-RESULTS.
           DISPLAY 'NET SETTLEMENT'
           DISPLAY '=============='
           DISPLAY 'BANKS:    ' WS-BANK-COUNT
           DISPLAY 'DEBITS:   ' WS-GRAND-DEBITS
           DISPLAY 'CREDITS:  ' WS-GRAND-CREDITS
           DISPLAY 'NET:      ' WS-GRAND-NET
           IF WS-IS-BALANCED
               DISPLAY 'STATUS: BALANCED'
           ELSE
               DISPLAY 'STATUS: OUT OF BALANCE'
           END-IF
           PERFORM VARYING WS-BK-IDX FROM 1 BY 1
               UNTIL WS-BK-IDX > WS-BANK-COUNT
               DISPLAY '  ' WS-BK-ID(WS-BK-IDX)
                   ' NET=' WS-BK-NET(WS-BK-IDX)
           END-PERFORM.
