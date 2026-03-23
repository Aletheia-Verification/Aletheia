       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACH-RETURN-PROC.
      *================================================================*
      * ACH Return Processing Engine                                    *
      * Processes ACH return/NOC entries, classifies return reasons,    *
      * enforces NACHA return timeframes, and generates notices.        *
      *================================================================*
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT RETURN-FILE ASSIGN TO 'ACHRET.DAT'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-RET-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD  RETURN-FILE.
       01  RETURN-RECORD.
           05  RR-TRACE-NUM         PIC X(15).
           05  RR-ORIG-ROUTING      PIC X(09).
           05  RR-ORIG-ACCT         PIC X(17).
           05  RR-AMOUNT            PIC 9(10)V99.
           05  RR-RETURN-CODE       PIC X(03).
           05  RR-ORIG-DATE         PIC 9(08).
           05  RR-RETURN-DATE       PIC 9(08).
           05  RR-ORIG-COMPANY      PIC X(16).
           05  RR-ADDENDA-INFO      PIC X(80).
       WORKING-STORAGE SECTION.
       01  WS-RET-STATUS           PIC XX VALUE SPACES.
       01  WS-EOF                  PIC X VALUE 'N'.
           88  END-OF-FILE         VALUE 'Y'.
       01  WS-RETURN-CNT          PIC 9(08) VALUE 0.
       01  WS-NOC-CNT             PIC 9(08) VALUE 0.
       01  WS-ADMIN-CNT           PIC 9(08) VALUE 0.
       01  WS-UNAUTH-CNT          PIC 9(08) VALUE 0.
       01  WS-NSF-CNT             PIC 9(08) VALUE 0.
       01  WS-LATE-RETURN-CNT     PIC 9(08) VALUE 0.
       01  WS-TOTAL-RETURNED      PIC S9(13)V99 VALUE 0.
       01  WS-RETURN-CLASS        PIC X(10).
       01  WS-DAYS-ELAPSED        PIC 9(03).
       01  WS-ADMIN-DEADLINE      PIC 9(03) VALUE 2.
       01  WS-UNAUTH-DEADLINE     PIC 9(03) VALUE 60.
       01  WS-LATE-FLAG           PIC X VALUE 'N'.
           88  IS-LATE             VALUE 'Y'.
       01  WS-NOTICE-LINE         PIC X(120) VALUE SPACES.
       01  WS-REASON-DESC         PIC X(40).
       01  WS-REDEPOSIT-FLAG      PIC X VALUE 'N'.
           88  CAN-REDEPOSIT       VALUE 'Y'.
       01  WS-REDEPOSIT-CNT       PIC 9(06) VALUE 0.
       01  WS-CURRENT-DATE.
           05  WS-CUR-YEAR        PIC 9(04).
           05  WS-CUR-MONTH       PIC 9(02).
           05  WS-CUR-DAY         PIC 9(02).
       01  WS-TODAY-NUM           PIC 9(08).
       01  WS-ACTION              PIC X(15).
       01  WS-IDX                 PIC 9(02).
       01  WS-RETURN-STATS.
           05  WS-CODE-ENTRY      OCCURS 10 TIMES.
               10  CE-CODE        PIC X(03).
               10  CE-COUNT       PIC 9(06).
       01  WS-STAT-PTR            PIC 9(02) VALUE 0.
       01  WS-FOUND               PIC X VALUE 'N'.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PROCESS-RETURNS UNTIL END-OF-FILE
           PERFORM 8000-PRINT-STATS
           PERFORM 9000-FINALIZE
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           COMPUTE WS-TODAY-NUM =
               WS-CUR-YEAR * 10000 +
               WS-CUR-MONTH * 100 + WS-CUR-DAY
           INITIALIZE WS-RETURN-STATS
           OPEN INPUT RETURN-FILE
           IF WS-RET-STATUS NOT = '00'
               DISPLAY 'RETURN FILE ERROR: ' WS-RET-STATUS
               STOP RUN
           END-IF
           PERFORM 1100-READ-RETURN.
       1100-READ-RETURN.
           READ RETURN-FILE
               AT END SET END-OF-FILE TO TRUE
           END-READ.
       2000-PROCESS-RETURNS.
           ADD 1 TO WS-RETURN-CNT
           PERFORM 3000-CLASSIFY-RETURN
           PERFORM 4000-CHECK-TIMELINESS
           PERFORM 5000-DETERMINE-ACTION
           PERFORM 6000-BUILD-NOTICE
           PERFORM 7000-UPDATE-STATS
           ADD RR-AMOUNT TO WS-TOTAL-RETURNED
           PERFORM 1100-READ-RETURN.
       3000-CLASSIFY-RETURN.
           MOVE 'N' TO WS-REDEPOSIT-FLAG
           EVALUATE RR-RETURN-CODE
               WHEN 'R01'
                   MOVE 'NSF' TO WS-RETURN-CLASS
                   MOVE 'INSUFFICIENT FUNDS' TO
                       WS-REASON-DESC
                   MOVE 'Y' TO WS-REDEPOSIT-FLAG
                   ADD 1 TO WS-NSF-CNT
               WHEN 'R02'
                   MOVE 'ADMIN' TO WS-RETURN-CLASS
                   MOVE 'ACCOUNT CLOSED' TO WS-REASON-DESC
                   ADD 1 TO WS-ADMIN-CNT
               WHEN 'R03'
                   MOVE 'ADMIN' TO WS-RETURN-CLASS
                   MOVE 'NO ACCOUNT/UNABLE TO LOCATE'
                       TO WS-REASON-DESC
                   ADD 1 TO WS-ADMIN-CNT
               WHEN 'R07'
                   MOVE 'UNAUTH' TO WS-RETURN-CLASS
                   MOVE 'AUTH REVOKED BY CUSTOMER'
                       TO WS-REASON-DESC
                   ADD 1 TO WS-UNAUTH-CNT
               WHEN 'R10'
                   MOVE 'UNAUTH' TO WS-RETURN-CLASS
                   MOVE 'CUSTOMER ADVISES UNAUTHORIZED'
                       TO WS-REASON-DESC
                   ADD 1 TO WS-UNAUTH-CNT
               WHEN 'C01'
                   MOVE 'NOC' TO WS-RETURN-CLASS
                   MOVE 'INCORRECT ACCOUNT NUMBER'
                       TO WS-REASON-DESC
                   ADD 1 TO WS-NOC-CNT
               WHEN 'C02'
                   MOVE 'NOC' TO WS-RETURN-CLASS
                   MOVE 'INCORRECT ROUTING NUMBER'
                       TO WS-REASON-DESC
                   ADD 1 TO WS-NOC-CNT
               WHEN OTHER
                   MOVE 'OTHER' TO WS-RETURN-CLASS
                   MOVE 'UNCLASSIFIED RETURN' TO
                       WS-REASON-DESC
                   ADD 1 TO WS-ADMIN-CNT
           END-EVALUATE.
       4000-CHECK-TIMELINESS.
           MOVE 'N' TO WS-LATE-FLAG
           IF RR-RETURN-DATE > RR-ORIG-DATE
               COMPUTE WS-DAYS-ELAPSED =
                   RR-RETURN-DATE - RR-ORIG-DATE
           ELSE
               MOVE 0 TO WS-DAYS-ELAPSED
           END-IF
           EVALUATE WS-RETURN-CLASS
               WHEN 'ADMIN'
                   IF WS-DAYS-ELAPSED > WS-ADMIN-DEADLINE
                       MOVE 'Y' TO WS-LATE-FLAG
                       ADD 1 TO WS-LATE-RETURN-CNT
                   END-IF
               WHEN 'UNAUTH'
                   IF WS-DAYS-ELAPSED > WS-UNAUTH-DEADLINE
                       MOVE 'Y' TO WS-LATE-FLAG
                       ADD 1 TO WS-LATE-RETURN-CNT
                   END-IF
               WHEN OTHER
                   CONTINUE
           END-EVALUATE.
       5000-DETERMINE-ACTION.
           IF IS-LATE
               MOVE 'REJECT-LATE' TO WS-ACTION
           ELSE
               IF CAN-REDEPOSIT
                   MOVE 'REDEPOSIT' TO WS-ACTION
                   ADD 1 TO WS-REDEPOSIT-CNT
               ELSE
                   MOVE 'PROCESS' TO WS-ACTION
               END-IF
           END-IF.
       6000-BUILD-NOTICE.
           MOVE SPACES TO WS-NOTICE-LINE
           STRING 'RET='
               DELIMITED BY SIZE
               RR-RETURN-CODE
               DELIMITED BY SIZE
               ' TRC='
               DELIMITED BY SIZE
               RR-TRACE-NUM
               DELIMITED BY SIZE
               ' ACT='
               DELIMITED BY SIZE
               WS-ACTION
               DELIMITED BY SIZE
               INTO WS-NOTICE-LINE
           DISPLAY WS-NOTICE-LINE.
       7000-UPDATE-STATS.
           MOVE 'N' TO WS-FOUND
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-STAT-PTR
               IF CE-CODE(WS-IDX) = RR-RETURN-CODE
                   ADD 1 TO CE-COUNT(WS-IDX)
                   MOVE 'Y' TO WS-FOUND
               END-IF
           END-PERFORM
           IF WS-FOUND = 'N' AND WS-STAT-PTR < 10
               ADD 1 TO WS-STAT-PTR
               MOVE RR-RETURN-CODE TO
                   CE-CODE(WS-STAT-PTR)
               MOVE 1 TO CE-COUNT(WS-STAT-PTR)
           END-IF.
       8000-PRINT-STATS.
           DISPLAY 'ACH RETURN CODE DISTRIBUTION:'
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-STAT-PTR
               DISPLAY '  ' CE-CODE(WS-IDX) ': '
                   CE-COUNT(WS-IDX)
           END-PERFORM.
       9000-FINALIZE.
           CLOSE RETURN-FILE
           DISPLAY 'ACH RETURN PROCESSING COMPLETE'
           DISPLAY 'TOTAL RETURNS:  ' WS-RETURN-CNT
           DISPLAY 'NSF:            ' WS-NSF-CNT
           DISPLAY 'UNAUTHORIZED:   ' WS-UNAUTH-CNT
           DISPLAY 'NOC:            ' WS-NOC-CNT
           DISPLAY 'LATE RETURNS:   ' WS-LATE-RETURN-CNT
           DISPLAY 'REDEPOSITS:     ' WS-REDEPOSIT-CNT
           DISPLAY 'TOTAL AMOUNT:   ' WS-TOTAL-RETURNED.
