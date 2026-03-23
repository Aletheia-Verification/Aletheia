       IDENTIFICATION DIVISION.
       PROGRAM-ID. TAX-1099-INT-GEN.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ACCT-FILE ASSIGN TO 'ACCOUNTS.DAT'
               FILE STATUS IS WS-ACCT-STATUS.
           SELECT TAX-FILE ASSIGN TO 'TAX-1099.DAT'
               FILE STATUS IS WS-TAX-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD ACCT-FILE.
       01 ACCT-RECORD.
           05 AR-ACCT-NUM            PIC X(12).
           05 AR-SSN                 PIC X(9).
           05 AR-NAME                PIC X(30).
           05 AR-INT-EARNED          PIC 9(9)V99.
           05 AR-WITHHELD            PIC 9(7)V99.
       FD TAX-FILE.
       01 TAX-RECORD.
           05 TR-SSN                 PIC X(9).
           05 TR-NAME                PIC X(30).
           05 TR-INT-INCOME          PIC 9(9)V99.
           05 TR-FED-WITHHELD        PIC 9(7)V99.
           05 TR-1099-FLAG           PIC X(1).
       WORKING-STORAGE SECTION.
       01 WS-ACCT-STATUS             PIC XX.
       01 WS-TAX-STATUS              PIC XX.
       01 WS-EOF-FLAG                PIC X VALUE 'N'.
           88 WS-EOF                  VALUE 'Y'.
       01 WS-MIN-REPORT-AMT          PIC S9(5)V99 COMP-3
           VALUE 10.00.
       01 WS-TOTALS.
           05 WS-TOTAL-INT           PIC S9(11)V99 COMP-3.
           05 WS-TOTAL-WITHHELD      PIC S9(9)V99 COMP-3.
           05 WS-RECORDS-READ        PIC S9(5) COMP-3.
           05 WS-RECORDS-WRITTEN     PIC S9(5) COMP-3.
           05 WS-BELOW-THRESHOLD     PIC S9(5) COMP-3.
       01 WS-FORM-MSG                PIC X(60).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 1100-OPEN-FILES
           PERFORM 2000-READ-ACCOUNTS UNTIL WS-EOF
           PERFORM 3000-CLOSE-FILES
           PERFORM 4000-DISPLAY-SUMMARY
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-INT
           MOVE 0 TO WS-TOTAL-WITHHELD
           MOVE 0 TO WS-RECORDS-READ
           MOVE 0 TO WS-RECORDS-WRITTEN
           MOVE 0 TO WS-BELOW-THRESHOLD.
       1100-OPEN-FILES.
           OPEN INPUT ACCT-FILE
           OPEN OUTPUT TAX-FILE.
       2000-READ-ACCOUNTS.
           READ ACCT-FILE
               AT END SET WS-EOF TO TRUE
               NOT AT END PERFORM 2100-PROCESS-ACCT
           END-READ.
       2100-PROCESS-ACCT.
           ADD 1 TO WS-RECORDS-READ
           ADD AR-INT-EARNED TO WS-TOTAL-INT
           ADD AR-WITHHELD TO WS-TOTAL-WITHHELD
           IF AR-INT-EARNED >= WS-MIN-REPORT-AMT
               MOVE AR-SSN TO TR-SSN
               MOVE AR-NAME TO TR-NAME
               MOVE AR-INT-EARNED TO TR-INT-INCOME
               MOVE AR-WITHHELD TO TR-FED-WITHHELD
               MOVE 'Y' TO TR-1099-FLAG
               WRITE TAX-RECORD
               ADD 1 TO WS-RECORDS-WRITTEN
               STRING '1099 ' DELIMITED BY SIZE
                      AR-SSN DELIMITED BY SIZE
                      ' INT=' DELIMITED BY SIZE
                      AR-INT-EARNED DELIMITED BY SIZE
                      INTO WS-FORM-MSG
               END-STRING
           ELSE
               ADD 1 TO WS-BELOW-THRESHOLD
           END-IF.
       3000-CLOSE-FILES.
           CLOSE ACCT-FILE
           CLOSE TAX-FILE.
       4000-DISPLAY-SUMMARY.
           DISPLAY '1099-INT GENERATION'
           DISPLAY '==================='
           DISPLAY 'ACCOUNTS READ:    ' WS-RECORDS-READ
           DISPLAY '1099S GENERATED:  ' WS-RECORDS-WRITTEN
           DISPLAY 'BELOW THRESHOLD:  ' WS-BELOW-THRESHOLD
           DISPLAY 'TOTAL INTEREST:   ' WS-TOTAL-INT
           DISPLAY 'TOTAL WITHHELD:   ' WS-TOTAL-WITHHELD.
