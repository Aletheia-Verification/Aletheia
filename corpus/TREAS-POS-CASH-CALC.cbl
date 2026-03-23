       IDENTIFICATION DIVISION.
       PROGRAM-ID. TREAS-POS-CASH-CALC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-POSITION-TABLE.
           05 WS-POS-ENTRY OCCURS 10.
               10 WS-PE-ACCT         PIC X(12).
               10 WS-PE-BALANCE      PIC S9(11)V99 COMP-3.
               10 WS-PE-PENDING-IN   PIC S9(9)V99 COMP-3.
               10 WS-PE-PENDING-OUT  PIC S9(9)V99 COMP-3.
               10 WS-PE-AVAIL        PIC S9(11)V99 COMP-3.
       01 WS-POS-IDX                 PIC 9(2).
       01 WS-POS-COUNT               PIC 9(2).
       01 WS-TOTALS.
           05 WS-TOTAL-BAL           PIC S9(13)V99 COMP-3.
           05 WS-TOTAL-PENDING-IN    PIC S9(11)V99 COMP-3.
           05 WS-TOTAL-PENDING-OUT   PIC S9(11)V99 COMP-3.
           05 WS-NET-POSITION        PIC S9(13)V99 COMP-3.
           05 WS-AVAIL-CASH          PIC S9(13)V99 COMP-3.
       01 WS-CASH-STATUS             PIC X(1).
           88 WS-SURPLUS             VALUE 'S'.
           88 WS-ADEQUATE            VALUE 'A'.
           88 WS-DEFICIT             VALUE 'D'.
       01 WS-THRESHOLD               PIC S9(11)V99 COMP-3
           VALUE 1000000.00.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-POSITIONS
           PERFORM 3000-CALC-NET
           PERFORM 4000-ASSESS-STATUS
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-BAL
           MOVE 0 TO WS-TOTAL-PENDING-IN
           MOVE 0 TO WS-TOTAL-PENDING-OUT
           MOVE 0 TO WS-NET-POSITION.
       2000-CALC-POSITIONS.
           PERFORM VARYING WS-POS-IDX FROM 1 BY 1
               UNTIL WS-POS-IDX > WS-POS-COUNT
               COMPUTE WS-PE-AVAIL(WS-POS-IDX) =
                   WS-PE-BALANCE(WS-POS-IDX) +
                   WS-PE-PENDING-IN(WS-POS-IDX) -
                   WS-PE-PENDING-OUT(WS-POS-IDX)
               ADD WS-PE-BALANCE(WS-POS-IDX) TO
                   WS-TOTAL-BAL
               ADD WS-PE-PENDING-IN(WS-POS-IDX) TO
                   WS-TOTAL-PENDING-IN
               ADD WS-PE-PENDING-OUT(WS-POS-IDX) TO
                   WS-TOTAL-PENDING-OUT
           END-PERFORM.
       3000-CALC-NET.
           COMPUTE WS-NET-POSITION =
               WS-TOTAL-BAL + WS-TOTAL-PENDING-IN -
               WS-TOTAL-PENDING-OUT
           COMPUTE WS-AVAIL-CASH = WS-NET-POSITION.
       4000-ASSESS-STATUS.
           IF WS-AVAIL-CASH > WS-THRESHOLD
               SET WS-SURPLUS TO TRUE
           ELSE
               IF WS-AVAIL-CASH > 0
                   SET WS-ADEQUATE TO TRUE
               ELSE
                   SET WS-DEFICIT TO TRUE
               END-IF
           END-IF.
       5000-DISPLAY-RESULTS.
           DISPLAY 'CASH POSITION REPORT'
           DISPLAY '===================='
           DISPLAY 'ACCOUNTS:     ' WS-POS-COUNT
           DISPLAY 'TOTAL BAL:    ' WS-TOTAL-BAL
           DISPLAY 'PENDING IN:   ' WS-TOTAL-PENDING-IN
           DISPLAY 'PENDING OUT:  ' WS-TOTAL-PENDING-OUT
           DISPLAY 'NET POSITION: ' WS-NET-POSITION
           IF WS-SURPLUS
               DISPLAY 'STATUS: SURPLUS'
           END-IF
           IF WS-ADEQUATE
               DISPLAY 'STATUS: ADEQUATE'
           END-IF
           IF WS-DEFICIT
               DISPLAY 'STATUS: DEFICIT'
           END-IF
           PERFORM VARYING WS-POS-IDX FROM 1 BY 1
               UNTIL WS-POS-IDX > WS-POS-COUNT
               DISPLAY '  ' WS-PE-ACCT(WS-POS-IDX)
                   ' BAL=' WS-PE-BALANCE(WS-POS-IDX)
                   ' AVAIL=' WS-PE-AVAIL(WS-POS-IDX)
           END-PERFORM.
