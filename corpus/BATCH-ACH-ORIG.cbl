       IDENTIFICATION DIVISION.
       PROGRAM-ID. BATCH-ACH-ORIG.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ACH-FILE ASSIGN TO 'ACHOUT.DAT'
               FILE STATUS IS WS-ACH-FS.
       DATA DIVISION.
       FILE SECTION.
       FD ACH-FILE.
       01 ACH-RECORD              PIC X(94).
       WORKING-STORAGE SECTION.
       01 WS-ACH-FS               PIC XX.
       01 WS-BATCH-HDR.
           05 WS-BH-REC-TYPE      PIC X(1) VALUE '5'.
           05 WS-BH-SVC-CODE      PIC X(3).
           05 WS-BH-CO-NAME       PIC X(16).
           05 WS-BH-CO-ID         PIC X(10).
           05 WS-BH-SEC-CODE      PIC X(3).
           05 WS-BH-DESC          PIC X(10).
           05 WS-BH-EFF-DATE      PIC 9(6).
           05 WS-BH-SETTLE-DATE   PIC 9(6).
           05 WS-BH-ORIG-DFI      PIC X(8).
           05 WS-BH-BATCH-NUM     PIC 9(7).
       01 WS-DETAIL-REC.
           05 WS-DR-REC-TYPE      PIC X(1) VALUE '6'.
           05 WS-DR-TXN-CODE      PIC X(2).
           05 WS-DR-RDFI          PIC X(8).
           05 WS-DR-CHECK-DIG     PIC X(1).
           05 WS-DR-ACCT-NUM      PIC X(17).
           05 WS-DR-AMOUNT        PIC 9(10).
           05 WS-DR-INDIV-ID      PIC X(15).
           05 WS-DR-NAME          PIC X(22).
       01 WS-BATCH-CTRL.
           05 WS-BC-REC-TYPE      PIC X(1) VALUE '8'.
           05 WS-BC-SVC-CODE      PIC X(3).
           05 WS-BC-ENTRY-COUNT   PIC 9(6).
           05 WS-BC-ENTRY-HASH    PIC 9(10).
           05 WS-BC-TOTAL-DEBIT   PIC 9(12).
           05 WS-BC-TOTAL-CREDIT  PIC 9(12).
           05 WS-BC-CO-ID         PIC X(10).
       01 WS-ENTRY-TBL.
           05 WS-ENTRY OCCURS 25 TIMES.
               10 WS-E-RDFI       PIC X(8).
               10 WS-E-ACCT       PIC X(17).
               10 WS-E-AMT        PIC 9(10).
               10 WS-E-NAME       PIC X(22).
               10 WS-E-TYPE       PIC X(1).
                   88 E-CREDIT    VALUE 'C'.
                   88 E-DEBIT     VALUE 'D'.
       01 WS-ENTRY-COUNT          PIC 99 VALUE 25.
       01 WS-IDX                  PIC 99.
       01 WS-HASH-TOTAL           PIC 9(10).
       01 WS-DEBIT-TOTAL          PIC 9(12).
       01 WS-CREDIT-TOTAL         PIC 9(12).
       01 WS-REC-COUNT            PIC 9(6).
       01 WS-BATCH-SEQ            PIC 9(7).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-OPEN-FILE
           PERFORM 3000-WRITE-BATCH-HDR
           PERFORM 4000-WRITE-DETAILS
           PERFORM 5000-WRITE-BATCH-CTRL
           PERFORM 6000-CLOSE-FILE
           STOP RUN.
       1000-INIT.
           MOVE 0 TO WS-HASH-TOTAL
           MOVE 0 TO WS-DEBIT-TOTAL
           MOVE 0 TO WS-CREDIT-TOTAL
           MOVE 0 TO WS-REC-COUNT
           MOVE 1 TO WS-BATCH-SEQ.
       2000-OPEN-FILE.
           OPEN OUTPUT ACH-FILE
           IF WS-ACH-FS NOT = '00'
               DISPLAY 'FILE OPEN ERROR: ' WS-ACH-FS
               STOP RUN
           END-IF.
       3000-WRITE-BATCH-HDR.
           MOVE WS-BH-REC-TYPE TO ACH-RECORD(1:1)
           MOVE WS-BH-SVC-CODE TO ACH-RECORD(2:3)
           MOVE WS-BH-CO-NAME TO ACH-RECORD(5:16)
           WRITE ACH-RECORD.
       4000-WRITE-DETAILS.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-ENTRY-COUNT
               MOVE WS-E-RDFI(WS-IDX) TO WS-DR-RDFI
               MOVE WS-E-ACCT(WS-IDX) TO WS-DR-ACCT-NUM
               MOVE WS-E-AMT(WS-IDX) TO WS-DR-AMOUNT
               MOVE WS-E-NAME(WS-IDX) TO WS-DR-NAME
               IF E-CREDIT(WS-IDX)
                   MOVE '22' TO WS-DR-TXN-CODE
                   ADD WS-E-AMT(WS-IDX) TO WS-CREDIT-TOTAL
               ELSE
                   MOVE '27' TO WS-DR-TXN-CODE
                   ADD WS-E-AMT(WS-IDX) TO WS-DEBIT-TOTAL
               END-IF
               ADD 1 TO WS-REC-COUNT
               MOVE WS-DR-REC-TYPE TO ACH-RECORD(1:1)
               WRITE ACH-RECORD
           END-PERFORM.
       5000-WRITE-BATCH-CTRL.
           MOVE WS-REC-COUNT TO WS-BC-ENTRY-COUNT
           MOVE WS-HASH-TOTAL TO WS-BC-ENTRY-HASH
           MOVE WS-DEBIT-TOTAL TO WS-BC-TOTAL-DEBIT
           MOVE WS-CREDIT-TOTAL TO WS-BC-TOTAL-CREDIT
           MOVE WS-BC-REC-TYPE TO ACH-RECORD(1:1)
           WRITE ACH-RECORD
           DISPLAY 'BATCH COMPLETE'
           DISPLAY 'ENTRIES:  ' WS-REC-COUNT
           DISPLAY 'DEBITS:   ' WS-DEBIT-TOTAL
           DISPLAY 'CREDITS:  ' WS-CREDIT-TOTAL.
       6000-CLOSE-FILE.
           CLOSE ACH-FILE.
