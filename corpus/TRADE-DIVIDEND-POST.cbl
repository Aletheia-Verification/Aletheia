       IDENTIFICATION DIVISION.
       PROGRAM-ID. TRADE-DIVIDEND-POST.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-DIV-DATA.
           05 WS-SECURITY-ID         PIC X(10).
           05 WS-DIV-PER-SHARE       PIC S9(3)V9(6) COMP-3.
           05 WS-EX-DATE             PIC 9(8).
           05 WS-PAY-DATE            PIC 9(8).
       01 WS-HOLDER-TABLE.
           05 WS-HOLDER OCCURS 20.
               10 WS-HD-ACCT         PIC X(12).
               10 WS-HD-SHARES       PIC S9(9) COMP-3.
               10 WS-HD-DIV-AMT      PIC S9(9)V99 COMP-3.
               10 WS-HD-TAX-RATE     PIC S9(1)V9(4) COMP-3.
               10 WS-HD-TAX-AMT      PIC S9(7)V99 COMP-3.
               10 WS-HD-NET          PIC S9(9)V99 COMP-3.
       01 WS-HD-IDX                  PIC 9(2).
       01 WS-HOLDER-COUNT            PIC 9(2).
       01 WS-TOTALS.
           05 WS-TOTAL-SHARES        PIC S9(11) COMP-3.
           05 WS-TOTAL-DIVIDEND      PIC S9(11)V99 COMP-3.
           05 WS-TOTAL-TAX           PIC S9(9)V99 COMP-3.
           05 WS-TOTAL-NET           PIC S9(11)V99 COMP-3.
       01 WS-DIV-TYPE                PIC X(1).
           88 WS-CASH-DIV            VALUE 'C'.
           88 WS-STOCK-DIV           VALUE 'S'.
           88 WS-SPECIAL-DIV         VALUE 'X'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-DIVIDENDS
           PERFORM 3000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-SHARES
           MOVE 0 TO WS-TOTAL-DIVIDEND
           MOVE 0 TO WS-TOTAL-TAX
           MOVE 0 TO WS-TOTAL-NET.
       2000-CALC-DIVIDENDS.
           PERFORM VARYING WS-HD-IDX FROM 1 BY 1
               UNTIL WS-HD-IDX > WS-HOLDER-COUNT
               COMPUTE WS-HD-DIV-AMT(WS-HD-IDX) =
                   WS-HD-SHARES(WS-HD-IDX) *
                   WS-DIV-PER-SHARE
               EVALUATE TRUE
                   WHEN WS-SPECIAL-DIV
                       MOVE 0.2000 TO
                           WS-HD-TAX-RATE(WS-HD-IDX)
                   WHEN OTHER
                       MOVE 0.1500 TO
                           WS-HD-TAX-RATE(WS-HD-IDX)
               END-EVALUATE
               COMPUTE WS-HD-TAX-AMT(WS-HD-IDX) =
                   WS-HD-DIV-AMT(WS-HD-IDX) *
                   WS-HD-TAX-RATE(WS-HD-IDX)
               COMPUTE WS-HD-NET(WS-HD-IDX) =
                   WS-HD-DIV-AMT(WS-HD-IDX) -
                   WS-HD-TAX-AMT(WS-HD-IDX)
               ADD WS-HD-SHARES(WS-HD-IDX) TO
                   WS-TOTAL-SHARES
               ADD WS-HD-DIV-AMT(WS-HD-IDX) TO
                   WS-TOTAL-DIVIDEND
               ADD WS-HD-TAX-AMT(WS-HD-IDX) TO
                   WS-TOTAL-TAX
               ADD WS-HD-NET(WS-HD-IDX) TO WS-TOTAL-NET
           END-PERFORM.
       3000-DISPLAY-RESULTS.
           DISPLAY 'DIVIDEND POSTING REPORT'
           DISPLAY '======================'
           DISPLAY 'SECURITY:      ' WS-SECURITY-ID
           DISPLAY 'DIV/SHARE:     ' WS-DIV-PER-SHARE
           DISPLAY 'HOLDERS:       ' WS-HOLDER-COUNT
           DISPLAY 'TOTAL SHARES:  ' WS-TOTAL-SHARES
           DISPLAY 'TOTAL DIV:     ' WS-TOTAL-DIVIDEND
           DISPLAY 'TOTAL TAX:     ' WS-TOTAL-TAX
           DISPLAY 'TOTAL NET:     ' WS-TOTAL-NET
           PERFORM VARYING WS-HD-IDX FROM 1 BY 1
               UNTIL WS-HD-IDX > WS-HOLDER-COUNT
               DISPLAY '  ACCT=' WS-HD-ACCT(WS-HD-IDX)
                   ' SHR=' WS-HD-SHARES(WS-HD-IDX)
                   ' DIV=' WS-HD-DIV-AMT(WS-HD-IDX)
                   ' NET=' WS-HD-NET(WS-HD-IDX)
           END-PERFORM.
