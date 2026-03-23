       IDENTIFICATION DIVISION.
       PROGRAM-ID. BATCH-CHECK-CLEAR.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT CHECK-FILE ASSIGN TO 'CHECKS.DAT'
               FILE STATUS IS WS-CHK-FS.
       DATA DIVISION.
       FILE SECTION.
       FD CHECK-FILE.
       01 CHECK-RECORD.
           05 CHK-SERIAL          PIC X(10).
           05 CHK-DRAWER-ACCT     PIC X(12).
           05 CHK-PAYEE-NAME      PIC X(30).
           05 CHK-AMOUNT          PIC 9(7)V99.
           05 CHK-DATE            PIC 9(8).
           05 CHK-BANK-ROUTING    PIC X(9).
       WORKING-STORAGE SECTION.
       01 WS-CHK-FS              PIC XX.
       01 WS-EOF-FLAG            PIC X VALUE 'N'.
           88 WS-EOF             VALUE 'Y'.
       01 WS-CHECK-COUNT         PIC 9(5).
       01 WS-CLEARED-COUNT       PIC 9(5).
       01 WS-REJECT-COUNT        PIC 9(5).
       01 WS-STALE-COUNT         PIC 9(5).
       01 WS-TOTAL-CLEARED       PIC S9(11)V99 COMP-3.
       01 WS-TOTAL-REJECTED      PIC S9(11)V99 COMP-3.
       01 WS-CURRENT-DATE        PIC 9(8).
       01 WS-AGE-DAYS            PIC 9(5).
       01 WS-STALE-THRESHOLD     PIC 9(3) VALUE 180.
       01 WS-LARGE-CHECK         PIC S9(7)V99 COMP-3
           VALUE 5000.00.
       01 WS-LARGE-COUNT         PIC 9(5).
       01 WS-STATUS              PIC X(8).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-OPEN-FILE
           PERFORM 3000-PROCESS-CHECKS UNTIL WS-EOF
           PERFORM 4000-CLOSE-FILE
           PERFORM 5000-REPORT
           STOP RUN.
       1000-INIT.
           MOVE 0 TO WS-CHECK-COUNT
           MOVE 0 TO WS-CLEARED-COUNT
           MOVE 0 TO WS-REJECT-COUNT
           MOVE 0 TO WS-STALE-COUNT
           MOVE 0 TO WS-TOTAL-CLEARED
           MOVE 0 TO WS-TOTAL-REJECTED
           MOVE 0 TO WS-LARGE-COUNT
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD.
       2000-OPEN-FILE.
           OPEN INPUT CHECK-FILE
           IF WS-CHK-FS NOT = '00'
               DISPLAY 'CHECK FILE OPEN ERROR: ' WS-CHK-FS
               STOP RUN
           END-IF.
       3000-PROCESS-CHECKS.
           READ CHECK-FILE
               AT END SET WS-EOF TO TRUE
               NOT AT END PERFORM 3100-EVALUATE-CHECK
           END-READ.
       3100-EVALUATE-CHECK.
           ADD 1 TO WS-CHECK-COUNT
           COMPUTE WS-AGE-DAYS =
               WS-CURRENT-DATE - CHK-DATE
           IF WS-AGE-DAYS > WS-STALE-THRESHOLD
               ADD 1 TO WS-STALE-COUNT
               ADD 1 TO WS-REJECT-COUNT
               ADD CHK-AMOUNT TO WS-TOTAL-REJECTED
               MOVE 'STALE   ' TO WS-STATUS
           ELSE
               IF CHK-AMOUNT > WS-LARGE-CHECK
                   ADD 1 TO WS-LARGE-COUNT
               END-IF
               IF CHK-DRAWER-ACCT = SPACES
                   ADD 1 TO WS-REJECT-COUNT
                   ADD CHK-AMOUNT TO WS-TOTAL-REJECTED
                   MOVE 'REJECTED' TO WS-STATUS
               ELSE
                   ADD 1 TO WS-CLEARED-COUNT
                   ADD CHK-AMOUNT TO WS-TOTAL-CLEARED
                   MOVE 'CLEARED ' TO WS-STATUS
               END-IF
           END-IF
           DISPLAY CHK-SERIAL ' ' WS-STATUS
               ' $' CHK-AMOUNT.
       4000-CLOSE-FILE.
           CLOSE CHECK-FILE.
       5000-REPORT.
           DISPLAY 'CHECK CLEARING BATCH REPORT'
           DISPLAY '==========================='
           DISPLAY 'DATE:     ' WS-CURRENT-DATE
           DISPLAY 'TOTAL:    ' WS-CHECK-COUNT
           DISPLAY 'CLEARED:  ' WS-CLEARED-COUNT
           DISPLAY 'REJECTED: ' WS-REJECT-COUNT
           DISPLAY 'STALE:    ' WS-STALE-COUNT
           DISPLAY 'LARGE:    ' WS-LARGE-COUNT
           DISPLAY 'CLEARED$: $' WS-TOTAL-CLEARED
           DISPLAY 'REJECTED$:$' WS-TOTAL-REJECTED.
