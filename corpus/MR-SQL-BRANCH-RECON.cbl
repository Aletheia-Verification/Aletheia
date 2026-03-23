       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-SQL-BRANCH-RECON.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-SQLCODE              PIC S9(9) COMP-3.
       01 WS-BRANCH-REC.
           05 WS-BRANCH-ID        PIC X(4).
           05 WS-BRANCH-NAME      PIC X(20).
           05 WS-GL-BALANCE       PIC S9(11)V99 COMP-3.
           05 WS-SUBLEDGER-BAL    PIC S9(11)V99 COMP-3.
           05 WS-VARIANCE         PIC S9(9)V99 COMP-3.
       01 WS-EOF-FLAG             PIC X VALUE 'N'.
           88 WS-EOF              VALUE 'Y'.
       01 WS-TOTAL-GL             PIC S9(13)V99 COMP-3.
       01 WS-TOTAL-SUB            PIC S9(13)V99 COMP-3.
       01 WS-TOTAL-VAR            PIC S9(11)V99 COMP-3.
       01 WS-BRANCHES-READ        PIC 9(3).
       01 WS-MATCHED              PIC 9(3).
       01 WS-UNMATCHED            PIC 9(3).
       01 WS-TOLERANCE            PIC S9(3)V99 COMP-3
           VALUE 0.01.
       01 WS-ABS-VAR              PIC S9(9)V99 COMP-3.
       01 WS-RECON-DATE           PIC 9(8).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-OPEN-CURSOR
           PERFORM 3000-PROCESS UNTIL WS-EOF
           PERFORM 4000-CLOSE-CURSOR
           PERFORM 5000-REPORT
           STOP RUN.
       1000-INIT.
           MOVE 0 TO WS-TOTAL-GL
           MOVE 0 TO WS-TOTAL-SUB
           MOVE 0 TO WS-TOTAL-VAR
           MOVE 0 TO WS-BRANCHES-READ
           MOVE 0 TO WS-MATCHED
           MOVE 0 TO WS-UNMATCHED
           ACCEPT WS-RECON-DATE FROM DATE YYYYMMDD.
       2000-OPEN-CURSOR.
           EXEC SQL
               DECLARE BRANCH_CUR CURSOR FOR
               SELECT BRANCH_ID, BRANCH_NAME,
                      GL_BALANCE, SUBLEDGER_BAL
               FROM BRANCH_BALANCES
               ORDER BY BRANCH_ID
           END-EXEC
           EXEC SQL
               OPEN BRANCH_CUR
           END-EXEC.
       3000-PROCESS.
           EXEC SQL
               FETCH BRANCH_CUR
               INTO :WS-BRANCH-ID, :WS-BRANCH-NAME,
                    :WS-GL-BALANCE, :WS-SUBLEDGER-BAL
           END-EXEC
           IF WS-SQLCODE = 100
               SET WS-EOF TO TRUE
           ELSE
               IF WS-SQLCODE = 0
                   PERFORM 3100-RECONCILE
               END-IF
           END-IF.
       3100-RECONCILE.
           ADD 1 TO WS-BRANCHES-READ
           COMPUTE WS-VARIANCE =
               WS-GL-BALANCE - WS-SUBLEDGER-BAL
           MOVE WS-VARIANCE TO WS-ABS-VAR
           IF WS-ABS-VAR < 0
               MULTIPLY -1 BY WS-ABS-VAR
           END-IF
           IF WS-ABS-VAR <= WS-TOLERANCE
               ADD 1 TO WS-MATCHED
           ELSE
               ADD 1 TO WS-UNMATCHED
               DISPLAY 'BREAK: ' WS-BRANCH-ID
                   ' VAR=' WS-VARIANCE
           END-IF
           ADD WS-GL-BALANCE TO WS-TOTAL-GL
           ADD WS-SUBLEDGER-BAL TO WS-TOTAL-SUB
           ADD WS-VARIANCE TO WS-TOTAL-VAR.
       4000-CLOSE-CURSOR.
           EXEC SQL
               CLOSE BRANCH_CUR
           END-EXEC.
       5000-REPORT.
           DISPLAY 'BRANCH RECONCILIATION REPORT'
           DISPLAY '============================'
           DISPLAY 'DATE:      ' WS-RECON-DATE
           DISPLAY 'BRANCHES:  ' WS-BRANCHES-READ
           DISPLAY 'MATCHED:   ' WS-MATCHED
           DISPLAY 'UNMATCHED: ' WS-UNMATCHED
           DISPLAY 'TOTAL GL:  $' WS-TOTAL-GL
           DISPLAY 'TOTAL SUB: $' WS-TOTAL-SUB
           DISPLAY 'TOTAL VAR: $' WS-TOTAL-VAR.
