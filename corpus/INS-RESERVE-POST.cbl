       IDENTIFICATION DIVISION.
       PROGRAM-ID. INS-RESERVE-POST.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-RESERVE-TABLE.
           05 WS-RESERVE OCCURS 6.
               10 WS-RV-LINE         PIC X(15).
               10 WS-RV-INCURRED     PIC S9(9)V99 COMP-3.
               10 WS-RV-PAID         PIC S9(9)V99 COMP-3.
               10 WS-RV-FACTOR       PIC S9(1)V9(4) COMP-3.
               10 WS-RV-IBNR         PIC S9(9)V99 COMP-3.
               10 WS-RV-TOTAL        PIC S9(9)V99 COMP-3.
       01 WS-RV-IDX                  PIC 9(1).
       01 WS-TOTALS.
           05 WS-TOTAL-INCURRED      PIC S9(11)V99 COMP-3.
           05 WS-TOTAL-PAID          PIC S9(11)V99 COMP-3.
           05 WS-TOTAL-IBNR          PIC S9(11)V99 COMP-3.
           05 WS-TOTAL-RESERVE       PIC S9(11)V99 COMP-3.
       01 WS-ADEQUACY                PIC X(1).
           88 WS-ADEQUATE            VALUE 'A'.
           88 WS-DEFICIENT           VALUE 'D'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-RESERVES
           PERFORM 3000-ASSESS-ADEQUACY
           PERFORM 4000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-INCURRED
           MOVE 0 TO WS-TOTAL-PAID
           MOVE 0 TO WS-TOTAL-IBNR
           MOVE 0 TO WS-TOTAL-RESERVE.
       2000-CALC-RESERVES.
           PERFORM VARYING WS-RV-IDX FROM 1 BY 1
               UNTIL WS-RV-IDX > 6
               COMPUTE WS-RV-IBNR(WS-RV-IDX) =
                   WS-RV-INCURRED(WS-RV-IDX) *
                   WS-RV-FACTOR(WS-RV-IDX)
               COMPUTE WS-RV-TOTAL(WS-RV-IDX) =
                   (WS-RV-INCURRED(WS-RV-IDX) -
                   WS-RV-PAID(WS-RV-IDX)) +
                   WS-RV-IBNR(WS-RV-IDX)
               ADD WS-RV-INCURRED(WS-RV-IDX) TO
                   WS-TOTAL-INCURRED
               ADD WS-RV-PAID(WS-RV-IDX) TO
                   WS-TOTAL-PAID
               ADD WS-RV-IBNR(WS-RV-IDX) TO
                   WS-TOTAL-IBNR
               ADD WS-RV-TOTAL(WS-RV-IDX) TO
                   WS-TOTAL-RESERVE
           END-PERFORM.
       3000-ASSESS-ADEQUACY.
           IF WS-TOTAL-RESERVE > 0
               IF WS-TOTAL-RESERVE >=
                   WS-TOTAL-INCURRED - WS-TOTAL-PAID
                   SET WS-ADEQUATE TO TRUE
               ELSE
                   SET WS-DEFICIENT TO TRUE
               END-IF
           ELSE
               SET WS-DEFICIENT TO TRUE
           END-IF.
       4000-DISPLAY-RESULTS.
           DISPLAY 'LOSS RESERVE POSTING'
           DISPLAY '===================='
           DISPLAY 'TOTAL INCURRED: ' WS-TOTAL-INCURRED
           DISPLAY 'TOTAL PAID:     ' WS-TOTAL-PAID
           DISPLAY 'TOTAL IBNR:     ' WS-TOTAL-IBNR
           DISPLAY 'TOTAL RESERVE:  ' WS-TOTAL-RESERVE
           IF WS-ADEQUATE
               DISPLAY 'ADEQUACY: ADEQUATE'
           ELSE
               DISPLAY 'ADEQUACY: DEFICIENT'
           END-IF
           PERFORM VARYING WS-RV-IDX FROM 1 BY 1
               UNTIL WS-RV-IDX > 6
               DISPLAY '  ' WS-RV-LINE(WS-RV-IDX)
                   ' RES=' WS-RV-TOTAL(WS-RV-IDX)
                   ' IBNR=' WS-RV-IBNR(WS-RV-IDX)
           END-PERFORM.
