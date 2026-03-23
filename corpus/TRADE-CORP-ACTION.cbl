       IDENTIFICATION DIVISION.
       PROGRAM-ID. TRADE-CORP-ACTION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CORP-ACTION.
           05 WS-ACTION-ID           PIC X(10).
           05 WS-SECURITY-ID         PIC X(10).
           05 WS-SECURITY-NAME       PIC X(30).
       01 WS-ACTION-TYPE             PIC X(1).
           88 WS-STOCK-SPLIT         VALUE 'S'.
           88 WS-REVERSE-SPLIT       VALUE 'R'.
           88 WS-MERGER              VALUE 'M'.
           88 WS-SPINOFF             VALUE 'P'.
       01 WS-SPLIT-RATIO-NUM         PIC 9(2).
       01 WS-SPLIT-RATIO-DEN         PIC 9(2).
       01 WS-HOLDER-TABLE.
           05 WS-HOLDER OCCURS 15.
               10 WS-HD-ACCT         PIC X(12).
               10 WS-HD-OLD-SHARES   PIC S9(9) COMP-3.
               10 WS-HD-NEW-SHARES   PIC S9(9) COMP-3.
               10 WS-HD-OLD-PRICE    PIC S9(7)V99 COMP-3.
               10 WS-HD-NEW-PRICE    PIC S9(7)V99 COMP-3.
               10 WS-HD-CASH-LIEU    PIC S9(7)V99 COMP-3.
       01 WS-HD-IDX                  PIC 9(2).
       01 WS-HOLDER-COUNT            PIC 9(2).
       01 WS-FRACTIONAL              PIC S9(9)V99 COMP-3.
       01 WS-TOTAL-OLD-SHARES        PIC S9(11) COMP-3.
       01 WS-TOTAL-NEW-SHARES        PIC S9(11) COMP-3.
       01 WS-TOTAL-CASH-LIEU         PIC S9(9)V99 COMP-3.
       01 WS-SUMMARY-MSG             PIC X(80).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PROCESS-ACTION
           PERFORM 3000-BUILD-SUMMARY
           PERFORM 4000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-OLD-SHARES
           MOVE 0 TO WS-TOTAL-NEW-SHARES
           MOVE 0 TO WS-TOTAL-CASH-LIEU.
       2000-PROCESS-ACTION.
           PERFORM VARYING WS-HD-IDX FROM 1 BY 1
               UNTIL WS-HD-IDX > WS-HOLDER-COUNT
               ADD WS-HD-OLD-SHARES(WS-HD-IDX) TO
                   WS-TOTAL-OLD-SHARES
               EVALUATE TRUE
                   WHEN WS-STOCK-SPLIT
                       COMPUTE WS-HD-NEW-SHARES(WS-HD-IDX) =
                           WS-HD-OLD-SHARES(WS-HD-IDX) *
                           WS-SPLIT-RATIO-NUM /
                           WS-SPLIT-RATIO-DEN
                       IF WS-HD-OLD-PRICE(WS-HD-IDX) > 0
                           COMPUTE WS-HD-NEW-PRICE
                               (WS-HD-IDX) =
                               WS-HD-OLD-PRICE(WS-HD-IDX) *
                               WS-SPLIT-RATIO-DEN /
                               WS-SPLIT-RATIO-NUM
                       END-IF
                   WHEN WS-REVERSE-SPLIT
                       COMPUTE WS-HD-NEW-SHARES(WS-HD-IDX) =
                           WS-HD-OLD-SHARES(WS-HD-IDX) *
                           WS-SPLIT-RATIO-NUM /
                           WS-SPLIT-RATIO-DEN
                   WHEN WS-MERGER
                       COMPUTE WS-HD-NEW-SHARES(WS-HD-IDX) =
                           WS-HD-OLD-SHARES(WS-HD-IDX) *
                           WS-SPLIT-RATIO-NUM /
                           WS-SPLIT-RATIO-DEN
                   WHEN WS-SPINOFF
                       MOVE WS-HD-OLD-SHARES(WS-HD-IDX) TO
                           WS-HD-NEW-SHARES(WS-HD-IDX)
               END-EVALUATE
               ADD WS-HD-NEW-SHARES(WS-HD-IDX) TO
                   WS-TOTAL-NEW-SHARES
               MOVE 0 TO WS-HD-CASH-LIEU(WS-HD-IDX)
           END-PERFORM.
       3000-BUILD-SUMMARY.
           STRING WS-ACTION-TYPE DELIMITED BY SIZE
                  ' ' DELIMITED BY SIZE
                  WS-SECURITY-NAME DELIMITED BY '  '
                  ' OLD=' DELIMITED BY SIZE
                  WS-TOTAL-OLD-SHARES DELIMITED BY SIZE
                  ' NEW=' DELIMITED BY SIZE
                  WS-TOTAL-NEW-SHARES DELIMITED BY SIZE
                  INTO WS-SUMMARY-MSG
           END-STRING.
       4000-DISPLAY-RESULTS.
           DISPLAY 'CORPORATE ACTION PROCESSING'
           DISPLAY '==========================='
           DISPLAY 'ACTION ID:     ' WS-ACTION-ID
           DISPLAY 'SECURITY:      ' WS-SECURITY-NAME
           DISPLAY 'OLD SHARES:    ' WS-TOTAL-OLD-SHARES
           DISPLAY 'NEW SHARES:    ' WS-TOTAL-NEW-SHARES
           DISPLAY 'CASH IN LIEU:  ' WS-TOTAL-CASH-LIEU
           DISPLAY 'SUMMARY: ' WS-SUMMARY-MSG
           PERFORM VARYING WS-HD-IDX FROM 1 BY 1
               UNTIL WS-HD-IDX > WS-HOLDER-COUNT
               DISPLAY '  ACCT=' WS-HD-ACCT(WS-HD-IDX)
                   ' OLD=' WS-HD-OLD-SHARES(WS-HD-IDX)
                   ' NEW=' WS-HD-NEW-SHARES(WS-HD-IDX)
           END-PERFORM.
