       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCT-ESCHEAT-SCAN.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ACCT-DATA.
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-ACCT-BALANCE        PIC S9(9)V99 COMP-3.
           05 WS-LAST-ACTIVITY       PIC 9(8).
           05 WS-CURRENT-DATE        PIC 9(8).
           05 WS-OWNER-NAME          PIC X(30).
       01 WS-ACCT-TYPE               PIC X(1).
           88 WS-CHECKING            VALUE 'C'.
           88 WS-SAVINGS             VALUE 'S'.
           88 WS-CD                  VALUE 'D'.
       01 WS-STATE-CODE              PIC X(2).
       01 WS-DORMANCY-YEARS          PIC 9(2).
       01 WS-ESCHEAT-THRESHOLD       PIC 9(2).
       01 WS-DAYS-INACTIVE           PIC S9(5) COMP-3.
       01 WS-YEARS-INACTIVE          PIC 9(2).
       01 WS-ESCHEAT-STATUS          PIC X(1).
           88 WS-ACTIVE              VALUE 'A'.
           88 WS-DORMANT             VALUE 'D'.
           88 WS-PRE-ESCHEAT         VALUE 'P'.
           88 WS-ESCHEAT-READY       VALUE 'E'.
       01 WS-NOTICE-SENT             PIC X VALUE 'N'.
           88 WS-NOTIFIED            VALUE 'Y'.
       01 WS-ACTION-REQUIRED         PIC X(20).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-INACTIVITY
           PERFORM 3000-SET-THRESHOLD
           PERFORM 4000-DETERMINE-STATUS
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           SET WS-ACTIVE TO TRUE
           MOVE 'NONE' TO WS-ACTION-REQUIRED
           MOVE 0 TO WS-DAYS-INACTIVE.
       2000-CALC-INACTIVITY.
           IF WS-CURRENT-DATE > WS-LAST-ACTIVITY
               COMPUTE WS-DAYS-INACTIVE =
                   WS-CURRENT-DATE - WS-LAST-ACTIVITY
               COMPUTE WS-YEARS-INACTIVE =
                   WS-DAYS-INACTIVE / 365
           ELSE
               MOVE 0 TO WS-YEARS-INACTIVE
           END-IF.
       3000-SET-THRESHOLD.
           EVALUATE TRUE
               WHEN WS-CHECKING
                   MOVE 3 TO WS-ESCHEAT-THRESHOLD
               WHEN WS-SAVINGS
                   MOVE 5 TO WS-ESCHEAT-THRESHOLD
               WHEN WS-CD
                   MOVE 5 TO WS-ESCHEAT-THRESHOLD
               WHEN OTHER
                   MOVE 3 TO WS-ESCHEAT-THRESHOLD
           END-EVALUATE
           IF WS-ACCT-BALANCE < 25.00
               IF WS-ESCHEAT-THRESHOLD > 1
                   SUBTRACT 1 FROM WS-ESCHEAT-THRESHOLD
               END-IF
           END-IF.
       4000-DETERMINE-STATUS.
           EVALUATE TRUE
               WHEN WS-YEARS-INACTIVE < 1
                   SET WS-ACTIVE TO TRUE
                   MOVE 'NONE' TO WS-ACTION-REQUIRED
               WHEN WS-YEARS-INACTIVE <
                       WS-ESCHEAT-THRESHOLD
                   SET WS-DORMANT TO TRUE
                   MOVE 'SEND DORMANT NOTICE'
                       TO WS-ACTION-REQUIRED
               WHEN WS-YEARS-INACTIVE =
                       WS-ESCHEAT-THRESHOLD
                   SET WS-PRE-ESCHEAT TO TRUE
                   MOVE 'SEND FINAL NOTICE'
                       TO WS-ACTION-REQUIRED
               WHEN OTHER
                   SET WS-ESCHEAT-READY TO TRUE
                   MOVE 'REMIT TO STATE'
                       TO WS-ACTION-REQUIRED
           END-EVALUATE
           IF WS-ACCT-BALANCE <= 0
               SET WS-ACTIVE TO TRUE
               MOVE 'CLOSE ZERO BALANCE'
                   TO WS-ACTION-REQUIRED
           END-IF.
       5000-DISPLAY-RESULTS.
           DISPLAY 'ESCHEATMENT SCAN REPORT'
           DISPLAY '======================='
           DISPLAY 'ACCOUNT:         ' WS-ACCT-NUM
           DISPLAY 'OWNER:           ' WS-OWNER-NAME
           DISPLAY 'BALANCE:         ' WS-ACCT-BALANCE
           DISPLAY 'LAST ACTIVITY:   ' WS-LAST-ACTIVITY
           DISPLAY 'YEARS INACTIVE:  ' WS-YEARS-INACTIVE
           DISPLAY 'THRESHOLD:       ' WS-ESCHEAT-THRESHOLD
           IF WS-ACTIVE
               DISPLAY 'STATUS: ACTIVE'
           END-IF
           IF WS-DORMANT
               DISPLAY 'STATUS: DORMANT'
           END-IF
           IF WS-PRE-ESCHEAT
               DISPLAY 'STATUS: PRE-ESCHEAT'
           END-IF
           IF WS-ESCHEAT-READY
               DISPLAY 'STATUS: ESCHEAT READY'
           END-IF
           DISPLAY 'ACTION: ' WS-ACTION-REQUIRED.
