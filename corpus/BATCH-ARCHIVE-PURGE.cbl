       IDENTIFICATION DIVISION.
       PROGRAM-ID. BATCH-ARCHIVE-PURGE.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARCHIVE-FILE ASSIGN TO 'ARCHIVE.DAT'
               FILE STATUS IS WS-ARC-FS.
       DATA DIVISION.
       FILE SECTION.
       FD ARCHIVE-FILE.
       01 ARC-RECORD.
           05 ARC-KEY             PIC X(20).
           05 ARC-DATE            PIC 9(8).
           05 ARC-TYPE            PIC X(2).
           05 ARC-DATA            PIC X(100).
       WORKING-STORAGE SECTION.
       01 WS-ARC-FS              PIC XX.
       01 WS-EOF                 PIC X VALUE 'N'.
           88 AT-EOF             VALUE 'Y'.
       01 WS-CURRENT-DATE        PIC 9(8).
       01 WS-RETENTION-DAYS      PIC 9(5).
       01 WS-CUTOFF-DATE         PIC 9(8).
       01 WS-AGE-DAYS            PIC 9(5).
       01 WS-TOTAL-READ          PIC 9(7).
       01 WS-RETAINED            PIC 9(7).
       01 WS-PURGED              PIC 9(7).
       01 WS-PURGE-TYPE.
           05 WS-PT-TXNS         PIC 9(5).
           05 WS-PT-STMTS        PIC 9(5).
           05 WS-PT-AUDIT        PIC 9(5).
           05 WS-PT-OTHER        PIC 9(5).
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
           MOVE 2555 TO WS-RETENTION-DAYS
           COMPUTE WS-CUTOFF-DATE =
               WS-CURRENT-DATE - WS-RETENTION-DAYS
           MOVE 0 TO WS-TOTAL-READ
           MOVE 0 TO WS-RETAINED
           MOVE 0 TO WS-PURGED
           MOVE 0 TO WS-PT-TXNS
           MOVE 0 TO WS-PT-STMTS
           MOVE 0 TO WS-PT-AUDIT
           MOVE 0 TO WS-PT-OTHER.
       2000-OPEN.
           OPEN INPUT ARCHIVE-FILE
           IF WS-ARC-FS NOT = '00'
               DISPLAY 'ARCHIVE OPEN ERROR: ' WS-ARC-FS
               STOP RUN
           END-IF.
       3000-PROCESS.
           READ ARCHIVE-FILE
               AT END SET AT-EOF TO TRUE
               NOT AT END PERFORM 3100-EVALUATE
           END-READ.
       3100-EVALUATE.
           ADD 1 TO WS-TOTAL-READ
           IF ARC-DATE < WS-CUTOFF-DATE
               ADD 1 TO WS-PURGED
               EVALUATE ARC-TYPE
                   WHEN 'TX'
                       ADD 1 TO WS-PT-TXNS
                   WHEN 'ST'
                       ADD 1 TO WS-PT-STMTS
                   WHEN 'AU'
                       ADD 1 TO WS-PT-AUDIT
                   WHEN OTHER
                       ADD 1 TO WS-PT-OTHER
               END-EVALUATE
           ELSE
               ADD 1 TO WS-RETAINED
           END-IF.
       4000-CLOSE.
           CLOSE ARCHIVE-FILE.
       5000-REPORT.
           DISPLAY 'ARCHIVE PURGE REPORT'
           DISPLAY '===================='
           DISPLAY 'DATE:       ' WS-CURRENT-DATE
           DISPLAY 'RETENTION:  ' WS-RETENTION-DAYS ' DAYS'
           DISPLAY 'CUTOFF:     ' WS-CUTOFF-DATE
           DISPLAY 'TOTAL READ: ' WS-TOTAL-READ
           DISPLAY 'RETAINED:   ' WS-RETAINED
           DISPLAY 'PURGED:     ' WS-PURGED
           DISPLAY '  TXN:      ' WS-PT-TXNS
           DISPLAY '  STMT:     ' WS-PT-STMTS
           DISPLAY '  AUDIT:    ' WS-PT-AUDIT
           DISPLAY '  OTHER:    ' WS-PT-OTHER.
