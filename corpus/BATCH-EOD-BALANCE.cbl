       IDENTIFICATION DIVISION.
       PROGRAM-ID. BATCH-EOD-BALANCE.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT TXN-FILE ASSIGN TO 'DAILYTXN.DAT'
               FILE STATUS IS WS-TXN-FS.
       DATA DIVISION.
       FILE SECTION.
       FD TXN-FILE.
       01 TXN-REC.
           05 TR-ACCT-NUM         PIC X(12).
           05 TR-TXN-TYPE         PIC X(2).
           05 TR-AMOUNT           PIC S9(9)V99.
           05 TR-TIMESTAMP        PIC X(14).
       WORKING-STORAGE SECTION.
       01 WS-TXN-FS              PIC XX.
       01 WS-EOF-FLAG            PIC X VALUE 'N'.
           88 AT-EOF             VALUE 'Y'.
       01 WS-ACCT-SUMMARY.
           05 WS-AS OCCURS 20 TIMES.
               10 WS-AS-ACCT     PIC X(12).
               10 WS-AS-OPEN     PIC S9(11)V99 COMP-3.
               10 WS-AS-DEBITS   PIC S9(9)V99 COMP-3.
               10 WS-AS-CREDITS  PIC S9(9)V99 COMP-3.
               10 WS-AS-CLOSE    PIC S9(11)V99 COMP-3.
               10 WS-AS-TXN-CT   PIC 9(5).
       01 WS-MAX-ACCTS           PIC 99 VALUE 20.
       01 WS-ACCT-CT             PIC 99.
       01 WS-IDX                 PIC 99.
       01 WS-JDX                 PIC 99.
       01 WS-FOUND               PIC X VALUE 'N'.
           88 ACCT-FOUND         VALUE 'Y'.
       01 WS-TOTAL-TXNS          PIC 9(7).
       01 WS-RUN-DATE            PIC 9(8).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-OPEN
           PERFORM 3000-PROCESS UNTIL AT-EOF
           PERFORM 4000-CALC-CLOSE
           PERFORM 5000-CLOSE
           PERFORM 6000-REPORT
           STOP RUN.
       1000-INIT.
           ACCEPT WS-RUN-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-ACCT-CT
           MOVE 0 TO WS-TOTAL-TXNS.
       2000-OPEN.
           OPEN INPUT TXN-FILE
           IF WS-TXN-FS NOT = '00'
               DISPLAY 'TXN FILE ERROR: ' WS-TXN-FS
               STOP RUN
           END-IF.
       3000-PROCESS.
           READ TXN-FILE
               AT END SET AT-EOF TO TRUE
               NOT AT END PERFORM 3100-APPLY-TXN
           END-READ.
       3100-APPLY-TXN.
           ADD 1 TO WS-TOTAL-TXNS
           MOVE 'N' TO WS-FOUND
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-ACCT-CT
               IF WS-AS-ACCT(WS-IDX) = TR-ACCT-NUM
                   MOVE 'Y' TO WS-FOUND
                   MOVE WS-IDX TO WS-JDX
               END-IF
           END-PERFORM
           IF NOT ACCT-FOUND
               ADD 1 TO WS-ACCT-CT
               MOVE WS-ACCT-CT TO WS-JDX
               MOVE TR-ACCT-NUM TO WS-AS-ACCT(WS-JDX)
               MOVE 0 TO WS-AS-DEBITS(WS-JDX)
               MOVE 0 TO WS-AS-CREDITS(WS-JDX)
               MOVE 0 TO WS-AS-TXN-CT(WS-JDX)
           END-IF
           ADD 1 TO WS-AS-TXN-CT(WS-JDX)
           IF TR-TXN-TYPE = 'DB'
               ADD TR-AMOUNT TO WS-AS-DEBITS(WS-JDX)
           ELSE
               ADD TR-AMOUNT TO WS-AS-CREDITS(WS-JDX)
           END-IF.
       4000-CALC-CLOSE.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-ACCT-CT
               COMPUTE WS-AS-CLOSE(WS-IDX) =
                   WS-AS-OPEN(WS-IDX) +
                   WS-AS-CREDITS(WS-IDX) -
                   WS-AS-DEBITS(WS-IDX)
           END-PERFORM.
       5000-CLOSE.
           CLOSE TXN-FILE.
       6000-REPORT.
           DISPLAY 'END-OF-DAY BALANCE REPORT'
           DISPLAY '========================='
           DISPLAY 'DATE:  ' WS-RUN-DATE
           DISPLAY 'ACCTS: ' WS-ACCT-CT
           DISPLAY 'TXNS:  ' WS-TOTAL-TXNS
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-ACCT-CT
               DISPLAY '  ' WS-AS-ACCT(WS-IDX)
                   ' OPEN=$' WS-AS-OPEN(WS-IDX)
                   ' CLOSE=$' WS-AS-CLOSE(WS-IDX)
                   ' TXN=' WS-AS-TXN-CT(WS-IDX)
           END-PERFORM.
