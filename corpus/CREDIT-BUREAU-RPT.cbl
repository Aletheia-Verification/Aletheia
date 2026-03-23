       IDENTIFICATION DIVISION.
       PROGRAM-ID. CREDIT-BUREAU-RPT.
      *================================================================*
      * Credit Bureau Metro2 Reporting Generator                        *
      * Formats consumer credit data for Equifax/Experian/TransUnion    *
      * reporting in Metro2 standard layout.                            *
      *================================================================*
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ACCT-FILE ASSIGN TO 'ACCTMSTR.DAT'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-ACCT-STATUS.
           SELECT REPORT-FILE ASSIGN TO 'METRO2.DAT'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-RPT-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD  ACCT-FILE.
       01  ACCT-RECORD.
           05  AR-SSN                 PIC X(09).
           05  AR-ACCT-NUM            PIC X(12).
           05  AR-LAST-NAME           PIC X(25).
           05  AR-FIRST-NAME          PIC X(15).
           05  AR-OPEN-DATE           PIC 9(08).
           05  AR-CREDIT-LIMIT        PIC 9(09)V99.
           05  AR-CURR-BALANCE        PIC 9(09)V99.
           05  AR-HIGH-BALANCE        PIC 9(09)V99.
           05  AR-SCHED-PAYMENT       PIC 9(07)V99.
           05  AR-ACTUAL-PAYMENT      PIC 9(07)V99.
           05  AR-DAYS-PAST-DUE       PIC 9(03).
           05  AR-ACCT-TYPE           PIC X(02).
           05  AR-PORTFOLIO-TYPE      PIC X(01).
       WORKING-STORAGE SECTION.
       01  WS-ACCT-STATUS            PIC XX VALUE SPACES.
       01  WS-RPT-STATUS             PIC XX VALUE SPACES.
       01  WS-EOF                    PIC X VALUE 'N'.
           88  END-OF-FILE           VALUE 'Y'.
       01  WS-RECORD-CNT            PIC 9(08) VALUE 0.
       01  WS-DELINQ-CNT            PIC 9(08) VALUE 0.
       01  WS-CURRENT-CNT           PIC 9(08) VALUE 0.
       01  WS-TOTAL-BALANCE         PIC S9(13)V99 VALUE 0.
       01  WS-TOTAL-CREDIT          PIC S9(13)V99 VALUE 0.
       01  WS-UTILIZATION           PIC 9(03)V99.
       01  WS-PAY-STATUS            PIC X(02).
       01  WS-SPECIAL-COMMENT       PIC X(02).
       01  WS-COMPLIANCE-CODE       PIC X(02).
       01  WS-METRO2-LINE           PIC X(426) VALUE SPACES.
       01  WS-CURRENT-DATE.
           05  WS-RPT-YEAR          PIC 9(04).
           05  WS-RPT-MONTH         PIC 9(02).
           05  WS-RPT-DAY           PIC 9(02).
       01  WS-PAY-HISTORY.
           05  WS-PAY-RATING        PIC X(01)
                                    OCCURS 24 TIMES.
       01  WS-PAY-IDX              PIC 9(02).
       01  WS-RATIO                PIC 9(03)V99.
       01  WS-MASKED-SSN           PIC X(09).
       01  WS-HEADER-REC           PIC X(426).
       01  WS-TRAILER-REC          PIC X(426).
       FD  REPORT-FILE.
       01  RPT-RECORD              PIC X(426).
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-WRITE-HEADER
           PERFORM 3000-PROCESS-ACCOUNTS UNTIL END-OF-FILE
           PERFORM 8000-WRITE-TRAILER
           PERFORM 9000-FINALIZE
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           OPEN INPUT ACCT-FILE
           OPEN OUTPUT REPORT-FILE
           IF WS-ACCT-STATUS NOT = '00'
               DISPLAY 'ACCT FILE OPEN ERROR: ' WS-ACCT-STATUS
               STOP RUN
           END-IF
           PERFORM 1100-READ-ACCT.
       1100-READ-ACCT.
           READ ACCT-FILE
               AT END SET END-OF-FILE TO TRUE
           END-READ.
       2000-WRITE-HEADER.
           MOVE SPACES TO WS-HEADER-REC
           STRING 'HEADER'
               DELIMITED BY SIZE
               WS-RPT-YEAR
               DELIMITED BY SIZE
               WS-RPT-MONTH
               DELIMITED BY SIZE
               INTO WS-HEADER-REC
           WRITE RPT-RECORD FROM WS-HEADER-REC.
       3000-PROCESS-ACCOUNTS.
           PERFORM 3100-DETERMINE-PAY-STATUS
           PERFORM 3200-SET-SPECIAL-COMMENT
           PERFORM 3300-MASK-SSN
           PERFORM 3400-BUILD-METRO2-LINE
           PERFORM 3500-UPDATE-TOTALS
           PERFORM 1100-READ-ACCT.
       3100-DETERMINE-PAY-STATUS.
           EVALUATE TRUE
               WHEN AR-DAYS-PAST-DUE = 0
                   MOVE '11' TO WS-PAY-STATUS
                   ADD 1 TO WS-CURRENT-CNT
               WHEN AR-DAYS-PAST-DUE < 30
                   MOVE '11' TO WS-PAY-STATUS
                   ADD 1 TO WS-CURRENT-CNT
               WHEN AR-DAYS-PAST-DUE < 60
                   MOVE '30' TO WS-PAY-STATUS
                   ADD 1 TO WS-DELINQ-CNT
               WHEN AR-DAYS-PAST-DUE < 90
                   MOVE '60' TO WS-PAY-STATUS
                   ADD 1 TO WS-DELINQ-CNT
               WHEN AR-DAYS-PAST-DUE < 120
                   MOVE '90' TO WS-PAY-STATUS
                   ADD 1 TO WS-DELINQ-CNT
               WHEN AR-DAYS-PAST-DUE < 150
                   MOVE 'CA' TO WS-PAY-STATUS
                   ADD 1 TO WS-DELINQ-CNT
               WHEN OTHER
                   MOVE 'CO' TO WS-PAY-STATUS
                   ADD 1 TO WS-DELINQ-CNT
           END-EVALUATE.
       3200-SET-SPECIAL-COMMENT.
           MOVE SPACES TO WS-SPECIAL-COMMENT
           MOVE SPACES TO WS-COMPLIANCE-CODE
           IF AR-ACTUAL-PAYMENT > ZERO AND
              AR-ACTUAL-PAYMENT < AR-SCHED-PAYMENT
               MOVE 'AU' TO WS-SPECIAL-COMMENT
           END-IF
           IF AR-PORTFOLIO-TYPE = 'M'
               MOVE 'XA' TO WS-COMPLIANCE-CODE
           END-IF.
       3300-MASK-SSN.
           MOVE AR-SSN TO WS-MASKED-SSN
           INSPECT WS-MASKED-SSN
               REPLACING ALL 'A' BY 'X'
               ALL 'B' BY 'X'.
       3400-BUILD-METRO2-LINE.
           MOVE SPACES TO WS-METRO2-LINE
           STRING AR-ACCT-NUM
               DELIMITED BY SIZE
               WS-PAY-STATUS
               DELIMITED BY SIZE
               WS-SPECIAL-COMMENT
               DELIMITED BY SIZE
               AR-PORTFOLIO-TYPE
               DELIMITED BY SIZE
               INTO WS-METRO2-LINE
           WRITE RPT-RECORD FROM WS-METRO2-LINE
           ADD 1 TO WS-RECORD-CNT.
       3500-UPDATE-TOTALS.
           ADD AR-CURR-BALANCE TO WS-TOTAL-BALANCE
           ADD AR-CREDIT-LIMIT TO WS-TOTAL-CREDIT
           IF WS-TOTAL-CREDIT > ZERO
               COMPUTE WS-UTILIZATION ROUNDED =
                   (WS-TOTAL-BALANCE / WS-TOTAL-CREDIT)
                   * 100
           END-IF.
       8000-WRITE-TRAILER.
           MOVE SPACES TO WS-TRAILER-REC
           STRING 'TRAILER'
               DELIMITED BY SIZE
               INTO WS-TRAILER-REC
           WRITE RPT-RECORD FROM WS-TRAILER-REC.
       9000-FINALIZE.
           CLOSE ACCT-FILE
           CLOSE REPORT-FILE
           DISPLAY 'METRO2 REPORT COMPLETE'
           DISPLAY 'RECORDS:     ' WS-RECORD-CNT
           DISPLAY 'CURRENT:     ' WS-CURRENT-CNT
           DISPLAY 'DELINQUENT:  ' WS-DELINQ-CNT
           DISPLAY 'UTILIZATION: ' WS-UTILIZATION '%'.
