       IDENTIFICATION DIVISION.
       PROGRAM-ID. REG-BSA-AGGREGATE.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT TXN-FILE ASSIGN TO 'BSA-TXN.DAT'
               FILE STATUS IS WS-TXN-STATUS.
           SELECT RPT-FILE ASSIGN TO 'BSA-RPT.DAT'
               FILE STATUS IS WS-RPT-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD TXN-FILE.
       01 TXN-RECORD.
           05 TX-CUST-ID             PIC X(10).
           05 TX-ACCT-NUM            PIC X(12).
           05 TX-AMOUNT              PIC 9(9)V99.
           05 TX-TYPE                PIC X(2).
           05 TX-DATE                PIC 9(8).
       FD RPT-FILE.
       01 RPT-RECORD.
           05 RP-CUST-ID             PIC X(10).
           05 RP-TOTAL-AMT           PIC 9(11)V99.
           05 RP-TXN-COUNT           PIC 9(5).
           05 RP-FLAG                PIC X(3).
       WORKING-STORAGE SECTION.
       01 WS-TXN-STATUS              PIC XX.
       01 WS-RPT-STATUS              PIC XX.
       01 WS-EOF-FLAG                PIC X VALUE 'N'.
           88 WS-EOF                  VALUE 'Y'.
       01 WS-AGG-TABLE.
           05 WS-AGG OCCURS 20.
               10 WS-AG-CUST         PIC X(10).
               10 WS-AG-TOTAL        PIC S9(11)V99 COMP-3.
               10 WS-AG-COUNT        PIC S9(5) COMP-3.
       01 WS-AG-IDX                  PIC 9(2).
       01 WS-AG-USED                 PIC 9(2).
       01 WS-FOUND                   PIC 9(2).
       01 WS-CTR-THRESHOLD           PIC S9(7)V99 COMP-3
           VALUE 10000.00.
       01 WS-TOTAL-FLAGGED           PIC S9(5) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 1100-OPEN-FILES
           PERFORM 2000-READ-TXNS UNTIL WS-EOF
           PERFORM 3000-WRITE-REPORT
           PERFORM 4000-CLOSE-FILES
           PERFORM 5000-DISPLAY-SUMMARY
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-AG-USED
           MOVE 0 TO WS-TOTAL-FLAGGED
           PERFORM VARYING WS-AG-IDX FROM 1 BY 1
               UNTIL WS-AG-IDX > 20
               MOVE SPACES TO WS-AG-CUST(WS-AG-IDX)
               MOVE 0 TO WS-AG-TOTAL(WS-AG-IDX)
               MOVE 0 TO WS-AG-COUNT(WS-AG-IDX)
           END-PERFORM.
       1100-OPEN-FILES.
           OPEN INPUT TXN-FILE
           OPEN OUTPUT RPT-FILE.
       2000-READ-TXNS.
           READ TXN-FILE
               AT END SET WS-EOF TO TRUE
               NOT AT END PERFORM 2100-AGGREGATE
           END-READ.
       2100-AGGREGATE.
           MOVE 0 TO WS-FOUND
           PERFORM VARYING WS-AG-IDX FROM 1 BY 1
               UNTIL WS-AG-IDX > WS-AG-USED
               OR WS-FOUND > 0
               IF WS-AG-CUST(WS-AG-IDX) = TX-CUST-ID
                   MOVE WS-AG-IDX TO WS-FOUND
               END-IF
           END-PERFORM
           IF WS-FOUND = 0
               ADD 1 TO WS-AG-USED
               MOVE WS-AG-USED TO WS-FOUND
               MOVE TX-CUST-ID TO WS-AG-CUST(WS-FOUND)
           END-IF
           ADD TX-AMOUNT TO WS-AG-TOTAL(WS-FOUND)
           ADD 1 TO WS-AG-COUNT(WS-FOUND).
       3000-WRITE-REPORT.
           PERFORM VARYING WS-AG-IDX FROM 1 BY 1
               UNTIL WS-AG-IDX > WS-AG-USED
               MOVE WS-AG-CUST(WS-AG-IDX) TO RP-CUST-ID
               MOVE WS-AG-TOTAL(WS-AG-IDX) TO RP-TOTAL-AMT
               MOVE WS-AG-COUNT(WS-AG-IDX) TO RP-TXN-COUNT
               IF WS-AG-TOTAL(WS-AG-IDX) >
                   WS-CTR-THRESHOLD
                   MOVE 'CTR' TO RP-FLAG
                   ADD 1 TO WS-TOTAL-FLAGGED
               ELSE
                   MOVE '   ' TO RP-FLAG
               END-IF
               WRITE RPT-RECORD
           END-PERFORM.
       4000-CLOSE-FILES.
           CLOSE TXN-FILE
           CLOSE RPT-FILE.
       5000-DISPLAY-SUMMARY.
           DISPLAY 'BSA AGGREGATION REPORT'
           DISPLAY '======================'
           DISPLAY 'CUSTOMERS:     ' WS-AG-USED
           DISPLAY 'CTR FLAGGED:   ' WS-TOTAL-FLAGGED.
