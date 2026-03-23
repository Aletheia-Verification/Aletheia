       IDENTIFICATION DIVISION.
       PROGRAM-ID. MISC-FEE-WAIVER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ACCT-NUM                PIC X(12).
       01 WS-FEE-TYPE                PIC X(2).
           88 WS-MONTHLY-FEE         VALUE 'MF'.
           88 WS-ATM-FEE             VALUE 'AT'.
           88 WS-WIRE-FEE            VALUE 'WR'.
           88 WS-OD-FEE              VALUE 'OD'.
       01 WS-FEE-AMOUNT              PIC S9(5)V99 COMP-3.
       01 WS-AVG-BALANCE             PIC S9(9)V99 COMP-3.
       01 WS-TIER                    PIC X(1).
           88 WS-BASIC               VALUE 'B'.
           88 WS-PREFERRED           VALUE 'P'.
           88 WS-PREMIUM             VALUE 'R'.
       01 WS-WAIVER-RESULT           PIC X(1).
           88 WS-WAIVED              VALUE 'W'.
           88 WS-CHARGED             VALUE 'C'.
       01 WS-WAIVER-REASON           PIC X(20).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CHECK-WAIVER
           PERFORM 3000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           SET WS-CHARGED TO TRUE
           MOVE SPACES TO WS-WAIVER-REASON.
       2000-CHECK-WAIVER.
           EVALUATE TRUE
               WHEN WS-PREMIUM
                   SET WS-WAIVED TO TRUE
                   MOVE 'PREMIUM TIER' TO WS-WAIVER-REASON
               WHEN WS-PREFERRED
                   IF WS-MONTHLY-FEE
                       IF WS-AVG-BALANCE > 5000
                           SET WS-WAIVED TO TRUE
                           MOVE 'BALANCE THRESHOLD' TO
                               WS-WAIVER-REASON
                       END-IF
                   END-IF
               WHEN WS-BASIC
                   IF WS-AVG-BALANCE > 25000
                       SET WS-WAIVED TO TRUE
                       MOVE 'HIGH BALANCE' TO
                           WS-WAIVER-REASON
                   END-IF
           END-EVALUATE
           IF WS-WAIVED
               MOVE 0 TO WS-FEE-AMOUNT
               DISPLAY 'FEE WAIVED'
           END-IF.
       3000-DISPLAY-RESULTS.
           DISPLAY 'FEE WAIVER CHECK'
           DISPLAY '================'
           DISPLAY 'ACCOUNT:  ' WS-ACCT-NUM
           DISPLAY 'FEE TYPE: ' WS-FEE-TYPE
           DISPLAY 'FEE:      ' WS-FEE-AMOUNT
           IF WS-WAIVED
               DISPLAY 'STATUS: WAIVED'
               DISPLAY 'REASON: ' WS-WAIVER-REASON
           ELSE
               DISPLAY 'STATUS: CHARGED'
           END-IF.
