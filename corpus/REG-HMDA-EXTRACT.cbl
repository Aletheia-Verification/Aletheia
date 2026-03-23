       IDENTIFICATION DIVISION.
       PROGRAM-ID. REG-HMDA-EXTRACT.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT LOAN-FILE ASSIGN TO 'HMDA-LOANS.DAT'
               FILE STATUS IS WS-LOAN-STATUS.
           SELECT HMDA-FILE ASSIGN TO 'HMDA-RPT.DAT'
               FILE STATUS IS WS-HMDA-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD LOAN-FILE.
       01 LOAN-RECORD.
           05 LR-LOAN-ID             PIC X(12).
           05 LR-AMOUNT              PIC 9(7)V99.
           05 LR-PURPOSE             PIC X(1).
           05 LR-ACTION              PIC X(1).
           05 LR-RATE                PIC 9(2)V9(4).
           05 LR-CENSUS-TRACT        PIC X(11).
       FD HMDA-FILE.
       01 HMDA-RECORD.
           05 HR-LOAN-ID             PIC X(12).
           05 HR-AMOUNT              PIC 9(7)V99.
           05 HR-PURPOSE             PIC X(1).
           05 HR-ACTION              PIC X(1).
           05 HR-RATE-SPREAD         PIC S9(2)V9(4).
           05 HR-HOEPA               PIC X(1).
       WORKING-STORAGE SECTION.
       01 WS-LOAN-STATUS             PIC XX.
       01 WS-HMDA-STATUS             PIC XX.
       01 WS-EOF-FLAG                PIC X VALUE 'N'.
           88 WS-EOF                  VALUE 'Y'.
       01 WS-APOR                    PIC S9(2)V9(4) COMP-3
           VALUE 05.5000.
       01 WS-RATE-SPREAD             PIC S9(2)V9(4) COMP-3.
       01 WS-HOEPA-THRESHOLD         PIC S9(2)V9(4) COMP-3
           VALUE 06.5000.
       01 WS-ACTION-FLAG             PIC X(1).
           88 WS-ORIGINATED          VALUE '1'.
           88 WS-APPROVED            VALUE '2'.
           88 WS-DENIED              VALUE '3'.
           88 WS-WITHDRAWN           VALUE '4'.
       01 WS-TOTALS.
           05 WS-TOTAL-LOANS         PIC S9(5) COMP-3.
           05 WS-TOTAL-ORIGINATED    PIC S9(5) COMP-3.
           05 WS-TOTAL-DENIED        PIC S9(5) COMP-3.
           05 WS-TOTAL-AMOUNT        PIC S9(11)V99 COMP-3.
           05 WS-HOEPA-COUNT         PIC S9(5) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 1100-OPEN-FILES
           PERFORM 2000-READ-LOANS UNTIL WS-EOF
           PERFORM 3000-CLOSE-FILES
           PERFORM 4000-DISPLAY-SUMMARY
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-LOANS
           MOVE 0 TO WS-TOTAL-ORIGINATED
           MOVE 0 TO WS-TOTAL-DENIED
           MOVE 0 TO WS-TOTAL-AMOUNT
           MOVE 0 TO WS-HOEPA-COUNT.
       1100-OPEN-FILES.
           OPEN INPUT LOAN-FILE
           OPEN OUTPUT HMDA-FILE.
       2000-READ-LOANS.
           READ LOAN-FILE
               AT END SET WS-EOF TO TRUE
               NOT AT END PERFORM 2100-PROCESS-LOAN
           END-READ.
       2100-PROCESS-LOAN.
           ADD 1 TO WS-TOTAL-LOANS
           MOVE LR-ACTION TO WS-ACTION-FLAG
           EVALUATE TRUE
               WHEN WS-ORIGINATED
                   ADD 1 TO WS-TOTAL-ORIGINATED
                   ADD LR-AMOUNT TO WS-TOTAL-AMOUNT
               WHEN WS-DENIED
                   ADD 1 TO WS-TOTAL-DENIED
               WHEN OTHER
                   CONTINUE
           END-EVALUATE
           COMPUTE WS-RATE-SPREAD =
               LR-RATE - WS-APOR
           IF WS-RATE-SPREAD < 0
               MOVE 0 TO WS-RATE-SPREAD
           END-IF
           MOVE LR-LOAN-ID TO HR-LOAN-ID
           MOVE LR-AMOUNT TO HR-AMOUNT
           MOVE LR-PURPOSE TO HR-PURPOSE
           MOVE LR-ACTION TO HR-ACTION
           MOVE WS-RATE-SPREAD TO HR-RATE-SPREAD
           IF LR-RATE > WS-HOEPA-THRESHOLD
               MOVE 'Y' TO HR-HOEPA
               ADD 1 TO WS-HOEPA-COUNT
           ELSE
               MOVE 'N' TO HR-HOEPA
           END-IF
           WRITE HMDA-RECORD.
       3000-CLOSE-FILES.
           CLOSE LOAN-FILE
           CLOSE HMDA-FILE.
       4000-DISPLAY-SUMMARY.
           DISPLAY 'HMDA EXTRACT SUMMARY'
           DISPLAY '===================='
           DISPLAY 'TOTAL LOANS:     ' WS-TOTAL-LOANS
           DISPLAY 'ORIGINATED:      ' WS-TOTAL-ORIGINATED
           DISPLAY 'DENIED:          ' WS-TOTAL-DENIED
           DISPLAY 'TOTAL AMOUNT:    ' WS-TOTAL-AMOUNT
           DISPLAY 'HOEPA FLAGS:     ' WS-HOEPA-COUNT.
