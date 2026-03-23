       IDENTIFICATION DIVISION.
       PROGRAM-ID. BATCH-STMT-RENDER.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ACCT-FILE ASSIGN TO 'ACCOUNTS.DAT'
               FILE STATUS IS WS-ACCT-FS.
           SELECT STMT-FILE ASSIGN TO 'STMTS.DAT'
               FILE STATUS IS WS-STMT-FS.
       DATA DIVISION.
       FILE SECTION.
       FD ACCT-FILE.
       01 ACCT-REC.
           05 AR-ACCT-NUM         PIC X(12).
           05 AR-CUST-NAME        PIC X(30).
           05 AR-CYCLE-DAY        PIC 9(2).
           05 AR-BALANCE          PIC S9(9)V99.
           05 AR-STMT-TYPE        PIC X(1).
       FD STMT-FILE.
       01 STMT-REC                PIC X(132).
       WORKING-STORAGE SECTION.
       01 WS-ACCT-FS              PIC XX.
       01 WS-STMT-FS              PIC XX.
       01 WS-EOF                  PIC X VALUE 'N'.
           88 AT-EOF              VALUE 'Y'.
       01 WS-CURRENT-DATE         PIC 9(8).
       01 WS-CURRENT-DAY          PIC 9(2).
       01 WS-ACCTS-READ           PIC 9(5).
       01 WS-STMTS-WRITTEN        PIC 9(5).
       01 WS-SKIPPED              PIC 9(5).
       01 WS-HEADER-LINE          PIC X(132).
       01 WS-DETAIL-LINE          PIC X(132).
       01 WS-FOOTER-LINE          PIC X(132).
       01 WS-PAGE-COUNT           PIC 9(3).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-OPEN-FILES
           PERFORM 3000-PROCESS UNTIL AT-EOF
           PERFORM 4000-CLOSE-FILES
           PERFORM 5000-SUMMARY
           STOP RUN.
       1000-INIT.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           MOVE WS-CURRENT-DATE(7:2) TO WS-CURRENT-DAY
           MOVE 0 TO WS-ACCTS-READ
           MOVE 0 TO WS-STMTS-WRITTEN
           MOVE 0 TO WS-SKIPPED
           MOVE 0 TO WS-PAGE-COUNT.
       2000-OPEN-FILES.
           OPEN INPUT ACCT-FILE
           IF WS-ACCT-FS NOT = '00'
               DISPLAY 'ACCT FILE ERROR: ' WS-ACCT-FS
               STOP RUN
           END-IF
           OPEN OUTPUT STMT-FILE.
       3000-PROCESS.
           READ ACCT-FILE
               AT END SET AT-EOF TO TRUE
               NOT AT END PERFORM 3100-EVAL-ACCOUNT
           END-READ.
       3100-EVAL-ACCOUNT.
           ADD 1 TO WS-ACCTS-READ
           IF AR-CYCLE-DAY = WS-CURRENT-DAY
               PERFORM 3200-RENDER-STMT
           ELSE
               ADD 1 TO WS-SKIPPED
           END-IF.
       3200-RENDER-STMT.
           ADD 1 TO WS-STMTS-WRITTEN
           ADD 1 TO WS-PAGE-COUNT
           STRING 'STATEMENT FOR '
               DELIMITED BY SIZE
               AR-CUST-NAME DELIMITED BY '  '
               ' ACCT=' DELIMITED BY SIZE
               AR-ACCT-NUM DELIMITED BY SIZE
               INTO WS-HEADER-LINE
           END-STRING
           MOVE WS-HEADER-LINE TO STMT-REC
           WRITE STMT-REC
           STRING 'BALANCE: $' DELIMITED BY SIZE
               AR-BALANCE DELIMITED BY SIZE
               ' AS OF ' DELIMITED BY SIZE
               WS-CURRENT-DATE DELIMITED BY SIZE
               INTO WS-DETAIL-LINE
           END-STRING
           MOVE WS-DETAIL-LINE TO STMT-REC
           WRITE STMT-REC
           MOVE 'END OF STATEMENT' TO WS-FOOTER-LINE
           MOVE WS-FOOTER-LINE TO STMT-REC
           WRITE STMT-REC.
       4000-CLOSE-FILES.
           CLOSE ACCT-FILE
           CLOSE STMT-FILE.
       5000-SUMMARY.
           DISPLAY 'STATEMENT BATCH REPORT'
           DISPLAY '======================'
           DISPLAY 'DATE:     ' WS-CURRENT-DATE
           DISPLAY 'CYCLE:    ' WS-CURRENT-DAY
           DISPLAY 'READ:     ' WS-ACCTS-READ
           DISPLAY 'RENDERED: ' WS-STMTS-WRITTEN
           DISPLAY 'SKIPPED:  ' WS-SKIPPED
           DISPLAY 'PAGES:    ' WS-PAGE-COUNT.
