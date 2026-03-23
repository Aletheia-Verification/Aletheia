       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACH-NACHA-FORMAT.
      *================================================================*
      * ACH NACHA File Formatter                                        *
      * Builds NACHA-compliant ACH files with batch headers,            *
      * entry detail records, addenda, and control totals.              *
      *================================================================*
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT TRANS-FILE ASSIGN TO 'ACHTRANS.DAT'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-TRN-STATUS.
           SELECT NACHA-FILE ASSIGN TO 'NACHA.OUT'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-NCH-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD  TRANS-FILE.
       01  TRANS-RECORD.
           05  TR-BATCH-NUM         PIC 9(07).
           05  TR-SEQ-NUM           PIC 9(06).
           05  TR-ROUTING           PIC X(09).
           05  TR-ACCT-NUM          PIC X(17).
           05  TR-AMOUNT            PIC 9(10)V99.
           05  TR-TRAN-CODE         PIC X(02).
           05  TR-INDIV-NAME        PIC X(22).
           05  TR-COMPANY-ID        PIC X(10).
           05  TR-ADDENDA-FLAG      PIC X(01).
           05  TR-ADDENDA-INFO      PIC X(80).
       FD  NACHA-FILE.
       01  NACHA-RECORD            PIC X(94).
       WORKING-STORAGE SECTION.
       01  WS-TRN-STATUS           PIC XX VALUE SPACES.
       01  WS-NCH-STATUS           PIC XX VALUE SPACES.
       01  WS-EOF                  PIC X VALUE 'N'.
           88  END-OF-FILE         VALUE 'Y'.
       01  WS-NACHA-LINE           PIC X(94) VALUE SPACES.
       01  WS-ENTRY-HASH           PIC 9(10) VALUE 0.
       01  WS-BATCH-DEBIT          PIC 9(12)V99 VALUE 0.
       01  WS-BATCH-CREDIT         PIC 9(12)V99 VALUE 0.
       01  WS-TOTAL-DEBIT          PIC 9(14)V99 VALUE 0.
       01  WS-TOTAL-CREDIT         PIC 9(14)V99 VALUE 0.
       01  WS-ENTRY-COUNT          PIC 9(08) VALUE 0.
       01  WS-BATCH-COUNT          PIC 9(06) VALUE 0.
       01  WS-BLOCK-COUNT          PIC 9(06).
       01  WS-ADDENDA-COUNT        PIC 9(06) VALUE 0.
       01  WS-PREV-BATCH           PIC 9(07) VALUE 0.
       01  WS-ROUTING-HASH-WK     PIC 9(10).
       01  WS-BATCH-ENTRY-CNT     PIC 9(06) VALUE 0.
       01  WS-RECORD-TOTAL        PIC 9(08) VALUE 0.
       01  WS-CURRENT-DATE.
           05  WS-FILE-YEAR        PIC 9(04).
           05  WS-FILE-MONTH       PIC 9(02).
           05  WS-FILE-DAY         PIC 9(02).
       01  WS-FILE-DATE-6          PIC 9(06).
       01  WS-ORIG-ROUTING         PIC X(09) VALUE '021000021'.
       01  WS-ORIG-NAME            PIC X(23)
                                   VALUE 'ALETHEIA BANK CORP     '.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 1500-WRITE-FILE-HEADER
           PERFORM 2000-PROCESS-TRANS UNTIL END-OF-FILE
           IF WS-BATCH-COUNT > 0
               PERFORM 6000-WRITE-BATCH-CONTROL
           END-IF
           PERFORM 7000-WRITE-FILE-CONTROL
           PERFORM 9000-FINALIZE
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           COMPUTE WS-FILE-DATE-6 =
               (WS-FILE-YEAR - 2000) * 10000 +
               WS-FILE-MONTH * 100 + WS-FILE-DAY
           OPEN INPUT TRANS-FILE
           OPEN OUTPUT NACHA-FILE
           IF WS-TRN-STATUS NOT = '00'
               DISPLAY 'TRANS FILE ERROR: ' WS-TRN-STATUS
               STOP RUN
           END-IF
           PERFORM 1100-READ-TRANS.
       1100-READ-TRANS.
           READ TRANS-FILE
               AT END SET END-OF-FILE TO TRUE
           END-READ.
       1500-WRITE-FILE-HEADER.
           MOVE SPACES TO WS-NACHA-LINE
           STRING '1'
               DELIMITED BY SIZE
               '01'
               DELIMITED BY SIZE
               WS-ORIG-ROUTING
               DELIMITED BY SIZE
               INTO WS-NACHA-LINE
           WRITE NACHA-RECORD FROM WS-NACHA-LINE
           ADD 1 TO WS-RECORD-TOTAL.
       2000-PROCESS-TRANS.
           IF TR-BATCH-NUM NOT = WS-PREV-BATCH
               IF WS-BATCH-COUNT > 0
                   PERFORM 6000-WRITE-BATCH-CONTROL
               END-IF
               PERFORM 3000-WRITE-BATCH-HEADER
           END-IF
           PERFORM 4000-WRITE-ENTRY-DETAIL
           IF TR-ADDENDA-FLAG = 'Y'
               PERFORM 5000-WRITE-ADDENDA
           END-IF
           PERFORM 1100-READ-TRANS.
       3000-WRITE-BATCH-HEADER.
           ADD 1 TO WS-BATCH-COUNT
           MOVE ZERO TO WS-ENTRY-HASH
           MOVE ZERO TO WS-BATCH-DEBIT
           MOVE ZERO TO WS-BATCH-CREDIT
           MOVE ZERO TO WS-BATCH-ENTRY-CNT
           MOVE TR-BATCH-NUM TO WS-PREV-BATCH
           MOVE SPACES TO WS-NACHA-LINE
           STRING '5'
               DELIMITED BY SIZE
               TR-COMPANY-ID
               DELIMITED BY SIZE
               WS-ORIG-NAME
               DELIMITED BY SIZE
               INTO WS-NACHA-LINE
           WRITE NACHA-RECORD FROM WS-NACHA-LINE
           ADD 1 TO WS-RECORD-TOTAL.
       4000-WRITE-ENTRY-DETAIL.
           ADD 1 TO WS-ENTRY-COUNT
           ADD 1 TO WS-BATCH-ENTRY-CNT
           MOVE SPACES TO WS-NACHA-LINE
           STRING '6'
               DELIMITED BY SIZE
               TR-TRAN-CODE
               DELIMITED BY SIZE
               TR-ROUTING
               DELIMITED BY SIZE
               TR-ACCT-NUM
               DELIMITED BY SIZE
               TR-INDIV-NAME
               DELIMITED BY SIZE
               INTO WS-NACHA-LINE
           WRITE NACHA-RECORD FROM WS-NACHA-LINE
           ADD 1 TO WS-RECORD-TOTAL
           EVALUATE TR-TRAN-CODE
               WHEN '27'
                   ADD TR-AMOUNT TO WS-BATCH-DEBIT
                   ADD TR-AMOUNT TO WS-TOTAL-DEBIT
               WHEN '37'
                   ADD TR-AMOUNT TO WS-BATCH-DEBIT
                   ADD TR-AMOUNT TO WS-TOTAL-DEBIT
               WHEN '22'
                   ADD TR-AMOUNT TO WS-BATCH-CREDIT
                   ADD TR-AMOUNT TO WS-TOTAL-CREDIT
               WHEN '32'
                   ADD TR-AMOUNT TO WS-BATCH-CREDIT
                   ADD TR-AMOUNT TO WS-TOTAL-CREDIT
               WHEN OTHER
                   ADD TR-AMOUNT TO WS-BATCH-CREDIT
                   ADD TR-AMOUNT TO WS-TOTAL-CREDIT
           END-EVALUATE.
       5000-WRITE-ADDENDA.
           ADD 1 TO WS-ADDENDA-COUNT
           MOVE SPACES TO WS-NACHA-LINE
           STRING '7'
               DELIMITED BY SIZE
               TR-ADDENDA-INFO
               DELIMITED BY SIZE
               INTO WS-NACHA-LINE
           WRITE NACHA-RECORD FROM WS-NACHA-LINE
           ADD 1 TO WS-RECORD-TOTAL.
       6000-WRITE-BATCH-CONTROL.
           MOVE SPACES TO WS-NACHA-LINE
           STRING '8'
               DELIMITED BY SIZE
               INTO WS-NACHA-LINE
           WRITE NACHA-RECORD FROM WS-NACHA-LINE
           ADD 1 TO WS-RECORD-TOTAL.
       7000-WRITE-FILE-CONTROL.
           COMPUTE WS-BLOCK-COUNT ROUNDED =
               (WS-RECORD-TOTAL + 10) / 10
           MOVE SPACES TO WS-NACHA-LINE
           STRING '9'
               DELIMITED BY SIZE
               INTO WS-NACHA-LINE
           WRITE NACHA-RECORD FROM WS-NACHA-LINE
           ADD 1 TO WS-RECORD-TOTAL.
       9000-FINALIZE.
           CLOSE TRANS-FILE
           CLOSE NACHA-FILE
           DISPLAY 'NACHA FILE COMPLETE'
           DISPLAY 'BATCHES:  ' WS-BATCH-COUNT
           DISPLAY 'ENTRIES:  ' WS-ENTRY-COUNT
           DISPLAY 'ADDENDA:  ' WS-ADDENDA-COUNT
           DISPLAY 'DEBIT:    ' WS-TOTAL-DEBIT
           DISPLAY 'CREDIT:   ' WS-TOTAL-CREDIT.
