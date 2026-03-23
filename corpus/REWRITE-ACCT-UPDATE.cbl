       IDENTIFICATION DIVISION.
       PROGRAM-ID. REWRITE-ACCT-UPDATE.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ACCT-FILE ASSIGN TO 'ACCOUNTS.DAT'
               FILE STATUS IS WS-ACCT-STATUS
               ORGANIZATION IS SEQUENTIAL.
       DATA DIVISION.
       FILE SECTION.
       FD ACCT-FILE.
       01 ACCT-RECORD.
           05 AR-ACCT-NUM            PIC X(12).
           05 AR-BALANCE             PIC S9(9)V99.
           05 AR-STATUS              PIC X(2).
           05 AR-LAST-TXN-DATE       PIC 9(8).
       WORKING-STORAGE SECTION.
       01 WS-ACCT-STATUS             PIC XX.
       01 WS-TARGET-ACCT             PIC X(12).
       01 WS-NEW-BALANCE             PIC S9(9)V99 COMP-3.
       01 WS-ADJUSTMENT              PIC S9(7)V99 COMP-3.
       01 WS-FOUND-FLAG              PIC X VALUE 'N'.
           88 WS-FOUND               VALUE 'Y'.
       01 WS-EOF-FLAG                PIC X VALUE 'N'.
           88 WS-EOF                  VALUE 'Y'.
       01 WS-UPDATED-FLAG            PIC X VALUE 'N'.
           88 WS-WAS-UPDATED         VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 1100-OPEN-FILE
           PERFORM 2000-FIND-AND-UPDATE UNTIL WS-EOF
           PERFORM 3000-CLOSE-FILE
           PERFORM 4000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'N' TO WS-FOUND-FLAG
           MOVE 'N' TO WS-EOF-FLAG
           MOVE 'N' TO WS-UPDATED-FLAG.
       1100-OPEN-FILE.
           OPEN I-O ACCT-FILE.
       2000-FIND-AND-UPDATE.
           READ ACCT-FILE
               AT END SET WS-EOF TO TRUE
               NOT AT END PERFORM 2100-CHECK-RECORD
           END-READ.
       2100-CHECK-RECORD.
           IF AR-ACCT-NUM = WS-TARGET-ACCT
               MOVE 'Y' TO WS-FOUND-FLAG
               COMPUTE WS-NEW-BALANCE =
                   AR-BALANCE + WS-ADJUSTMENT
               MOVE WS-NEW-BALANCE TO AR-BALANCE
               MOVE 'AC' TO AR-STATUS
               REWRITE ACCT-RECORD
               IF WS-ACCT-STATUS = '00'
                   MOVE 'Y' TO WS-UPDATED-FLAG
               END-IF
           END-IF.
       3000-CLOSE-FILE.
           CLOSE ACCT-FILE.
       4000-DISPLAY-RESULTS.
           DISPLAY 'REWRITE ACCOUNT UPDATE'
           DISPLAY '======================'
           DISPLAY 'TARGET:  ' WS-TARGET-ACCT
           DISPLAY 'ADJUST:  ' WS-ADJUSTMENT
           IF WS-WAS-UPDATED
               DISPLAY 'STATUS: UPDATED'
               DISPLAY 'NEW BAL: ' WS-NEW-BALANCE
           ELSE
               IF WS-FOUND
                   DISPLAY 'STATUS: REWRITE FAILED'
               ELSE
                   DISPLAY 'STATUS: NOT FOUND'
               END-IF
           END-IF.
