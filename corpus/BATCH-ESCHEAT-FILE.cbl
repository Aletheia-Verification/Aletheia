       IDENTIFICATION DIVISION.
       PROGRAM-ID. BATCH-ESCHEAT-FILE.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ESCHEAT-FILE ASSIGN TO 'ESCHEAT.DAT'
               FILE STATUS IS WS-ESC-FS.
       DATA DIVISION.
       FILE SECTION.
       FD ESCHEAT-FILE.
       01 ESC-RECORD.
           05 ESC-ACCT            PIC X(12).
           05 ESC-NAME            PIC X(30).
           05 ESC-SSN             PIC X(9).
           05 ESC-BALANCE         PIC S9(9)V99.
           05 ESC-LAST-ACTIVITY   PIC 9(8).
           05 ESC-STATE           PIC X(2).
           05 ESC-TYPE            PIC X(2).
       WORKING-STORAGE SECTION.
       01 WS-ESC-FS              PIC XX.
       01 WS-DORMANCY-TABLE.
           05 WS-DT OCCURS 6 TIMES.
               10 WS-DT-STATE    PIC X(2).
               10 WS-DT-YEARS    PIC 9(2).
       01 WS-DT-COUNT            PIC 9 VALUE 6.
       01 WS-IDX                 PIC 9.
       01 WS-CURRENT-DATE        PIC 9(8).
       01 WS-INACTIVE-YEARS      PIC 9(3).
       01 WS-STATE-YEARS         PIC 9(2).
       01 WS-FOUND-STATE         PIC X VALUE 'N'.
           88 STATE-FOUND        VALUE 'Y'.
       01 WS-TOTAL-ESCHEATED     PIC S9(11)V99 COMP-3.
       01 WS-ESCHEAT-COUNT       PIC 9(5).
       01 WS-TOTAL-PROCESSED     PIC 9(5).
       01 WS-EOF-FLAG            PIC X VALUE 'N'.
           88 AT-EOF             VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-OPEN
           PERFORM 3000-PROCESS UNTIL AT-EOF
           PERFORM 4000-CLOSE
           PERFORM 5000-REPORT
           STOP RUN.
       1000-INIT.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-TOTAL-ESCHEATED
           MOVE 0 TO WS-ESCHEAT-COUNT
           MOVE 0 TO WS-TOTAL-PROCESSED.
       2000-OPEN.
           OPEN INPUT ESCHEAT-FILE.
       3000-PROCESS.
           READ ESCHEAT-FILE
               AT END SET AT-EOF TO TRUE
               NOT AT END PERFORM 3100-CHECK-ESCHEAT
           END-READ.
       3100-CHECK-ESCHEAT.
           ADD 1 TO WS-TOTAL-PROCESSED
           COMPUTE WS-INACTIVE-YEARS =
               (WS-CURRENT-DATE - ESC-LAST-ACTIVITY) / 10000
           MOVE 'N' TO WS-FOUND-STATE
           MOVE 5 TO WS-STATE-YEARS
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-DT-COUNT
               IF WS-DT-STATE(WS-IDX) = ESC-STATE
                   MOVE WS-DT-YEARS(WS-IDX) TO WS-STATE-YEARS
                   MOVE 'Y' TO WS-FOUND-STATE
               END-IF
           END-PERFORM
           IF WS-INACTIVE-YEARS >= WS-STATE-YEARS
               ADD 1 TO WS-ESCHEAT-COUNT
               ADD ESC-BALANCE TO WS-TOTAL-ESCHEATED
               DISPLAY 'ESCHEAT: ' ESC-ACCT
                   ' ' ESC-STATE
                   ' $' ESC-BALANCE
           END-IF.
       4000-CLOSE.
           CLOSE ESCHEAT-FILE.
       5000-REPORT.
           DISPLAY 'ESCHEAT FILING REPORT'
           DISPLAY '====================='
           DISPLAY 'DATE:      ' WS-CURRENT-DATE
           DISPLAY 'PROCESSED: ' WS-TOTAL-PROCESSED
           DISPLAY 'ESCHEATED: ' WS-ESCHEAT-COUNT
           DISPLAY 'TOTAL AMT: $' WS-TOTAL-ESCHEATED.
