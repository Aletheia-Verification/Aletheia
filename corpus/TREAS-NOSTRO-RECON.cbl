       IDENTIFICATION DIVISION.
       PROGRAM-ID. TREAS-NOSTRO-RECON.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT NOSTRO-FILE ASSIGN TO 'NOSTRO.DAT'
               FILE STATUS IS WS-NOSTRO-STATUS.
           SELECT RECON-FILE ASSIGN TO 'RECON-OUT.DAT'
               FILE STATUS IS WS-RECON-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD NOSTRO-FILE.
       01 NOSTRO-RECORD.
           05 NR-CORR-BANK           PIC X(8).
           05 NR-TXN-REF             PIC X(16).
           05 NR-AMOUNT              PIC S9(11)V99.
           05 NR-CURRENCY            PIC X(3).
           05 NR-VALUE-DATE          PIC 9(8).
       FD RECON-FILE.
       01 RECON-RECORD.
           05 RR-CORR-BANK           PIC X(8).
           05 RR-MATCHED             PIC 9(5).
           05 RR-UNMATCHED           PIC 9(5).
           05 RR-NET-VARIANCE        PIC S9(11)V99.
           05 RR-STATUS              PIC X(8).
       WORKING-STORAGE SECTION.
       01 WS-NOSTRO-STATUS            PIC XX.
       01 WS-RECON-STATUS             PIC XX.
       01 WS-EOF-FLAG                 PIC X VALUE 'N'.
           88 WS-EOF                   VALUE 'Y'.
       01 WS-CORR-TABLE.
           05 WS-CORR OCCURS 10.
               10 WS-CR-BANK         PIC X(8).
               10 WS-CR-DEBITS       PIC S9(11)V99 COMP-3.
               10 WS-CR-CREDITS      PIC S9(11)V99 COMP-3.
               10 WS-CR-COUNT        PIC S9(5) COMP-3.
               10 WS-CR-DASH-CNT     PIC 9(3).
       01 WS-CR-IDX                   PIC 9(2).
       01 WS-CR-COUNT-USED            PIC 9(2).
       01 WS-FOUND-IDX                PIC 9(2).
       01 WS-TOTAL-RECORDS            PIC S9(5) COMP-3.
       01 WS-VARIANCE                 PIC S9(11)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 1100-OPEN-FILES
           PERFORM 2000-READ-NOSTRO UNTIL WS-EOF
           PERFORM 3000-WRITE-RECON
           PERFORM 4000-CLOSE-FILES
           PERFORM 5000-DISPLAY-SUMMARY
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-RECORDS
           MOVE 0 TO WS-CR-COUNT-USED
           PERFORM VARYING WS-CR-IDX FROM 1 BY 1
               UNTIL WS-CR-IDX > 10
               MOVE SPACES TO WS-CR-BANK(WS-CR-IDX)
               MOVE 0 TO WS-CR-DEBITS(WS-CR-IDX)
               MOVE 0 TO WS-CR-CREDITS(WS-CR-IDX)
               MOVE 0 TO WS-CR-COUNT(WS-CR-IDX)
               MOVE 0 TO WS-CR-DASH-CNT(WS-CR-IDX)
           END-PERFORM.
       1100-OPEN-FILES.
           OPEN INPUT NOSTRO-FILE
           OPEN OUTPUT RECON-FILE.
       2000-READ-NOSTRO.
           READ NOSTRO-FILE
               AT END SET WS-EOF TO TRUE
               NOT AT END PERFORM 2100-PROCESS-RECORD
           END-READ.
       2100-PROCESS-RECORD.
           ADD 1 TO WS-TOTAL-RECORDS
           MOVE 0 TO WS-FOUND-IDX
           PERFORM VARYING WS-CR-IDX FROM 1 BY 1
               UNTIL WS-CR-IDX > WS-CR-COUNT-USED
               OR WS-FOUND-IDX > 0
               IF WS-CR-BANK(WS-CR-IDX) = NR-CORR-BANK
                   MOVE WS-CR-IDX TO WS-FOUND-IDX
               END-IF
           END-PERFORM
           IF WS-FOUND-IDX = 0
               ADD 1 TO WS-CR-COUNT-USED
               MOVE WS-CR-COUNT-USED TO WS-FOUND-IDX
               MOVE NR-CORR-BANK TO
                   WS-CR-BANK(WS-FOUND-IDX)
           END-IF
           ADD 1 TO WS-CR-COUNT(WS-FOUND-IDX)
           IF NR-AMOUNT >= 0
               ADD NR-AMOUNT TO
                   WS-CR-DEBITS(WS-FOUND-IDX)
           ELSE
               ADD NR-AMOUNT TO
                   WS-CR-CREDITS(WS-FOUND-IDX)
           END-IF
           INSPECT NR-TXN-REF
               TALLYING WS-CR-DASH-CNT(WS-FOUND-IDX)
               FOR ALL '-'.
       3000-WRITE-RECON.
           PERFORM VARYING WS-CR-IDX FROM 1 BY 1
               UNTIL WS-CR-IDX > WS-CR-COUNT-USED
               MOVE WS-CR-BANK(WS-CR-IDX) TO RR-CORR-BANK
               MOVE WS-CR-COUNT(WS-CR-IDX) TO RR-MATCHED
               MOVE 0 TO RR-UNMATCHED
               COMPUTE RR-NET-VARIANCE =
                   WS-CR-DEBITS(WS-CR-IDX) +
                   WS-CR-CREDITS(WS-CR-IDX)
               IF RR-NET-VARIANCE = 0
                   MOVE 'BALANCED' TO RR-STATUS
               ELSE
                   MOVE 'VARIANCE' TO RR-STATUS
               END-IF
               WRITE RECON-RECORD
           END-PERFORM.
       4000-CLOSE-FILES.
           CLOSE NOSTRO-FILE
           CLOSE RECON-FILE.
       5000-DISPLAY-SUMMARY.
           DISPLAY 'NOSTRO RECONCILIATION'
           DISPLAY '====================='
           DISPLAY 'RECORDS:      ' WS-TOTAL-RECORDS
           DISPLAY 'CORR BANKS:   ' WS-CR-COUNT-USED
           PERFORM VARYING WS-CR-IDX FROM 1 BY 1
               UNTIL WS-CR-IDX > WS-CR-COUNT-USED
               DISPLAY '  BANK=' WS-CR-BANK(WS-CR-IDX)
                   ' TXN=' WS-CR-COUNT(WS-CR-IDX)
           END-PERFORM.
