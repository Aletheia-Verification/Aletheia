       IDENTIFICATION DIVISION.
       PROGRAM-ID. DEP-UNCLM-PROP.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ACCT-FILE ASSIGN TO 'DORMANT.DAT'
               FILE STATUS IS WS-ACCT-STATUS.
           SELECT RPT-FILE ASSIGN TO 'ESCHEAT.DAT'
               FILE STATUS IS WS-RPT-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD ACCT-FILE.
       01 ACCT-RECORD.
           05 AR-ACCT-NUM            PIC X(12).
           05 AR-BALANCE             PIC 9(9)V99.
           05 AR-LAST-ACTIVITY       PIC 9(8).
           05 AR-STATE               PIC X(2).
       FD RPT-FILE.
       01 RPT-RECORD.
           05 RR-ACCT-NUM            PIC X(12).
           05 RR-BALANCE             PIC 9(9)V99.
           05 RR-STATE               PIC X(2).
           05 RR-STATUS              PIC X(8).
       WORKING-STORAGE SECTION.
       01 WS-ACCT-STATUS             PIC XX.
       01 WS-RPT-STATUS              PIC XX.
       01 WS-EOF-FLAG                PIC X VALUE 'N'.
           88 WS-EOF                  VALUE 'Y'.
       01 WS-CURRENT-DATE            PIC 9(8).
       01 WS-YEARS-DORMANT           PIC 9(2).
       01 WS-THRESHOLD-YEARS         PIC 9(2) VALUE 3.
       01 WS-TOTAL-READ              PIC S9(5) COMP-3.
       01 WS-TOTAL-ESCHEAT           PIC S9(5) COMP-3.
       01 WS-TOTAL-AMOUNT            PIC S9(11)V99 COMP-3.
       01 WS-REPORT-LINE             PIC X(60).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 1100-OPEN-FILES
           PERFORM 2000-READ-ACCTS UNTIL WS-EOF
           PERFORM 3000-CLOSE-FILES
           PERFORM 4000-DISPLAY-SUMMARY
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-READ
           MOVE 0 TO WS-TOTAL-ESCHEAT
           MOVE 0 TO WS-TOTAL-AMOUNT.
       1100-OPEN-FILES.
           OPEN INPUT ACCT-FILE
           OPEN OUTPUT RPT-FILE.
       2000-READ-ACCTS.
           READ ACCT-FILE
               AT END SET WS-EOF TO TRUE
               NOT AT END PERFORM 2100-PROCESS-ACCT
           END-READ.
       2100-PROCESS-ACCT.
           ADD 1 TO WS-TOTAL-READ
           COMPUTE WS-YEARS-DORMANT =
               (WS-CURRENT-DATE - AR-LAST-ACTIVITY) / 10000
           IF WS-YEARS-DORMANT >= WS-THRESHOLD-YEARS
               ADD 1 TO WS-TOTAL-ESCHEAT
               ADD AR-BALANCE TO WS-TOTAL-AMOUNT
               MOVE AR-ACCT-NUM TO RR-ACCT-NUM
               MOVE AR-BALANCE TO RR-BALANCE
               MOVE AR-STATE TO RR-STATE
               MOVE 'ESCHEAT ' TO RR-STATUS
               WRITE RPT-RECORD
               STRING 'ESCHEAT ' DELIMITED BY SIZE
                      AR-ACCT-NUM DELIMITED BY SIZE
                      ' BAL=' DELIMITED BY SIZE
                      AR-BALANCE DELIMITED BY SIZE
                      INTO WS-REPORT-LINE
               END-STRING
           END-IF.
       3000-CLOSE-FILES.
           CLOSE ACCT-FILE
           CLOSE RPT-FILE.
       4000-DISPLAY-SUMMARY.
           DISPLAY 'UNCLAIMED PROPERTY'
           DISPLAY '=================='
           DISPLAY 'ACCOUNTS READ:    ' WS-TOTAL-READ
           DISPLAY 'ESCHEAT ELIGIBLE: ' WS-TOTAL-ESCHEAT
           DISPLAY 'TOTAL AMOUNT:     ' WS-TOTAL-AMOUNT.
