       IDENTIFICATION DIVISION.
       PROGRAM-ID. DEP-IRA-CONTRIB.
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ACCT-NUM                PIC X(12).
       01 WS-AGE                     PIC 9(3).
       01 WS-YTD-CONTRIB             PIC S9(7)V99 COMP-3.
       01 WS-NEW-CONTRIB             PIC S9(7)V99 COMP-3.
       01 WS-IRA-TYPE                PIC X(1).
           88 WS-TRADITIONAL         VALUE 'T'.
           88 WS-ROTH                VALUE 'R'.
       01 WS-BASE-LIMIT              PIC S9(7)V99 COMP-3.
       01 WS-CATCHUP-LIMIT           PIC S9(7)V99 COMP-3.
       01 WS-TOTAL-LIMIT             PIC S9(7)V99 COMP-3.
       01 WS-REMAINING-ROOM          PIC S9(7)V99 COMP-3.
       01 WS-ALLOWED-CONTRIB         PIC S9(7)V99 COMP-3.
       01 WS-EXCESS-AMT              PIC S9(7)V99 COMP-3.
       01 WS-CATCHUP-FLAG            PIC X VALUE 'N'.
           88 WS-CATCHUP-ELIGIBLE    VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-SET-LIMITS
           PERFORM 3000-CALC-ALLOWED
           PERFORM 4000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 7000,00 TO WS-BASE-LIMIT
           MOVE 1000,00 TO WS-CATCHUP-LIMIT
           MOVE 0 TO WS-EXCESS-AMT
           MOVE 'N' TO WS-CATCHUP-FLAG.
       2000-SET-LIMITS.
           IF WS-AGE >= 50
               MOVE 'Y' TO WS-CATCHUP-FLAG
               COMPUTE WS-TOTAL-LIMIT =
                   WS-BASE-LIMIT + WS-CATCHUP-LIMIT
           ELSE
               MOVE WS-BASE-LIMIT TO WS-TOTAL-LIMIT
           END-IF.
       3000-CALC-ALLOWED.
           COMPUTE WS-REMAINING-ROOM =
               WS-TOTAL-LIMIT - WS-YTD-CONTRIB
           IF WS-REMAINING-ROOM < 0
               MOVE 0 TO WS-REMAINING-ROOM
           END-IF
           IF WS-NEW-CONTRIB <= WS-REMAINING-ROOM
               MOVE WS-NEW-CONTRIB TO WS-ALLOWED-CONTRIB
           ELSE
               MOVE WS-REMAINING-ROOM TO WS-ALLOWED-CONTRIB
               COMPUTE WS-EXCESS-AMT =
                   WS-NEW-CONTRIB - WS-REMAINING-ROOM
           END-IF.
       4000-DISPLAY-RESULTS.
           DISPLAY 'IRA CONTRIBUTION'
           DISPLAY '================'
           DISPLAY 'ACCOUNT:    ' WS-ACCT-NUM
           DISPLAY 'AGE:        ' WS-AGE
           DISPLAY 'LIMIT:      ' WS-TOTAL-LIMIT
           DISPLAY 'ROOM:       ' WS-REMAINING-ROOM
           DISPLAY 'ALLOWED:    ' WS-ALLOWED-CONTRIB
           IF WS-EXCESS-AMT > 0
               DISPLAY 'EXCESS:     ' WS-EXCESS-AMT
           END-IF.
