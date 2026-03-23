       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCT-RECON-DAILY.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT TXN-FILE ASSIGN TO 'DAILY-TXN.DAT'
               FILE STATUS IS WS-TXN-STATUS.
           SELECT RECON-FILE ASSIGN TO 'RECON-RPT.DAT'
               FILE STATUS IS WS-RECON-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD TXN-FILE.
       01 TXN-RECORD.
           05 TR-ACCT-NUM            PIC X(12).
           05 TR-TXN-TYPE            PIC X(2).
           05 TR-AMOUNT              PIC 9(9)V99.
           05 TR-BATCH-ID            PIC X(6).
       FD RECON-FILE.
       01 RECON-RECORD.
           05 RR-BATCH-ID            PIC X(6).
           05 RR-DEBIT-TOTAL         PIC 9(11)V99.
           05 RR-CREDIT-TOTAL        PIC 9(11)V99.
           05 RR-NET                 PIC S9(11)V99.
           05 RR-COUNT               PIC 9(5).
           05 RR-STATUS              PIC X(8).
       WORKING-STORAGE SECTION.
       01 WS-TXN-STATUS              PIC XX.
       01 WS-RECON-STATUS            PIC XX.
       01 WS-EOF-FLAG                PIC X VALUE 'N'.
           88 WS-EOF                  VALUE 'Y'.
       01 WS-BATCH-TABLE.
           05 WS-BATCH OCCURS 10.
               10 WS-BT-ID           PIC X(6).
               10 WS-BT-DEBITS       PIC S9(11)V99 COMP-3.
               10 WS-BT-CREDITS      PIC S9(11)V99 COMP-3.
               10 WS-BT-COUNT        PIC S9(5) COMP-3.
       01 WS-BT-IDX                  PIC 9(2).
       01 WS-BT-COUNT-USED           PIC 9(2).
       01 WS-FOUND-IDX               PIC 9(2).
       01 WS-GRAND-DEBITS            PIC S9(13)V99 COMP-3.
       01 WS-GRAND-CREDITS           PIC S9(13)V99 COMP-3.
       01 WS-GRAND-COUNT             PIC S9(7) COMP-3.
       01 WS-VARIANCE                PIC S9(13)V99 COMP-3.
       01 WS-BALANCED-FLAG           PIC X VALUE 'N'.
           88 WS-IS-BALANCED         VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 1100-OPEN-FILES
           PERFORM 2000-READ-TRANSACTIONS UNTIL WS-EOF
           PERFORM 3000-WRITE-RECON-RECORDS
           PERFORM 4000-CHECK-BALANCE
           PERFORM 5000-CLOSE-FILES
           PERFORM 6000-DISPLAY-SUMMARY
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-GRAND-DEBITS
           MOVE 0 TO WS-GRAND-CREDITS
           MOVE 0 TO WS-GRAND-COUNT
           MOVE 0 TO WS-BT-COUNT-USED
           PERFORM VARYING WS-BT-IDX FROM 1 BY 1
               UNTIL WS-BT-IDX > 10
               MOVE SPACES TO WS-BT-ID(WS-BT-IDX)
               MOVE 0 TO WS-BT-DEBITS(WS-BT-IDX)
               MOVE 0 TO WS-BT-CREDITS(WS-BT-IDX)
               MOVE 0 TO WS-BT-COUNT(WS-BT-IDX)
           END-PERFORM.
       1100-OPEN-FILES.
           OPEN INPUT TXN-FILE
           OPEN OUTPUT RECON-FILE.
       2000-READ-TRANSACTIONS.
           READ TXN-FILE
               AT END SET WS-EOF TO TRUE
               NOT AT END PERFORM 2100-PROCESS-TXN
           END-READ.
       2100-PROCESS-TXN.
           ADD 1 TO WS-GRAND-COUNT
           MOVE 0 TO WS-FOUND-IDX
           PERFORM VARYING WS-BT-IDX FROM 1 BY 1
               UNTIL WS-BT-IDX > WS-BT-COUNT-USED
               OR WS-FOUND-IDX > 0
               IF WS-BT-ID(WS-BT-IDX) = TR-BATCH-ID
                   MOVE WS-BT-IDX TO WS-FOUND-IDX
               END-IF
           END-PERFORM
           IF WS-FOUND-IDX = 0
               ADD 1 TO WS-BT-COUNT-USED
               MOVE WS-BT-COUNT-USED TO WS-FOUND-IDX
               MOVE TR-BATCH-ID TO
                   WS-BT-ID(WS-FOUND-IDX)
           END-IF
           ADD 1 TO WS-BT-COUNT(WS-FOUND-IDX)
           IF TR-TXN-TYPE = 'DB'
               ADD TR-AMOUNT TO
                   WS-BT-DEBITS(WS-FOUND-IDX)
               ADD TR-AMOUNT TO WS-GRAND-DEBITS
           ELSE
               ADD TR-AMOUNT TO
                   WS-BT-CREDITS(WS-FOUND-IDX)
               ADD TR-AMOUNT TO WS-GRAND-CREDITS
           END-IF.
       3000-WRITE-RECON-RECORDS.
           PERFORM VARYING WS-BT-IDX FROM 1 BY 1
               UNTIL WS-BT-IDX > WS-BT-COUNT-USED
               MOVE WS-BT-ID(WS-BT-IDX) TO RR-BATCH-ID
               MOVE WS-BT-DEBITS(WS-BT-IDX) TO
                   RR-DEBIT-TOTAL
               MOVE WS-BT-CREDITS(WS-BT-IDX) TO
                   RR-CREDIT-TOTAL
               COMPUTE RR-NET =
                   WS-BT-DEBITS(WS-BT-IDX) -
                   WS-BT-CREDITS(WS-BT-IDX)
               MOVE WS-BT-COUNT(WS-BT-IDX) TO RR-COUNT
               IF RR-NET = 0
                   MOVE 'BALANCED' TO RR-STATUS
               ELSE
                   MOVE 'VARIANCE' TO RR-STATUS
               END-IF
               WRITE RECON-RECORD
           END-PERFORM.
       4000-CHECK-BALANCE.
           COMPUTE WS-VARIANCE =
               WS-GRAND-DEBITS - WS-GRAND-CREDITS
           IF WS-VARIANCE = 0
               MOVE 'Y' TO WS-BALANCED-FLAG
           END-IF.
       5000-CLOSE-FILES.
           CLOSE TXN-FILE
           CLOSE RECON-FILE.
       6000-DISPLAY-SUMMARY.
           DISPLAY 'DAILY RECONCILIATION SUMMARY'
           DISPLAY '============================'
           DISPLAY 'TRANSACTIONS:  ' WS-GRAND-COUNT
           DISPLAY 'TOTAL DEBITS:  ' WS-GRAND-DEBITS
           DISPLAY 'TOTAL CREDITS: ' WS-GRAND-CREDITS
           DISPLAY 'VARIANCE:      ' WS-VARIANCE
           DISPLAY 'BATCHES:       ' WS-BT-COUNT-USED
           IF WS-IS-BALANCED
               DISPLAY 'STATUS: BALANCED'
           ELSE
               DISPLAY 'STATUS: OUT OF BALANCE'
           END-IF.
