       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-SQL-DELINQ-NOTICE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-SQLCODE             PIC S9(9) COMP-3.
       01 WS-DELINQ-REC.
           05 WS-DL-LOAN         PIC X(12).
           05 WS-DL-BORROWER     PIC X(30).
           05 WS-DL-ADDRESS      PIC X(50).
           05 WS-DL-DPD          PIC 9(3).
           05 WS-DL-PAST-DUE-AMT PIC S9(7)V99 COMP-3.
           05 WS-DL-LAST-PMT     PIC X(10).
       01 WS-EOF-FLAG            PIC X VALUE 'N'.
           88 WS-EOF             VALUE 'Y'.
       01 WS-NOTICE-TYPE         PIC X(10).
       01 WS-TOTAL-30            PIC 9(5).
       01 WS-TOTAL-60            PIC 9(5).
       01 WS-TOTAL-90            PIC 9(5).
       01 WS-TOTAL-120           PIC 9(5).
       01 WS-TOTAL-AMT           PIC S9(11)V99 COMP-3.
       01 WS-LETTERS-GEN         PIC 9(5).
       01 WS-RUN-DATE            PIC 9(8).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-OPEN-CURSOR
           PERFORM 3000-PROCESS UNTIL WS-EOF
           PERFORM 4000-CLOSE-CURSOR
           PERFORM 5000-REPORT
           STOP RUN.
       1000-INIT.
           MOVE 0 TO WS-TOTAL-30
           MOVE 0 TO WS-TOTAL-60
           MOVE 0 TO WS-TOTAL-90
           MOVE 0 TO WS-TOTAL-120
           MOVE 0 TO WS-TOTAL-AMT
           MOVE 0 TO WS-LETTERS-GEN
           ACCEPT WS-RUN-DATE FROM DATE YYYYMMDD.
       2000-OPEN-CURSOR.
           EXEC SQL
               DECLARE DELINQ_CUR CURSOR FOR
               SELECT LOAN_NUM, BORROWER_NAME,
                      MAILING_ADDRESS, DAYS_PAST_DUE,
                      PAST_DUE_AMT, LAST_PMT_DATE
               FROM LOAN_DELINQUENCY_V
               WHERE DAYS_PAST_DUE >= 30
               ORDER BY DAYS_PAST_DUE DESC
           END-EXEC
           EXEC SQL OPEN DELINQ_CUR END-EXEC.
       3000-PROCESS.
           EXEC SQL
               FETCH DELINQ_CUR
               INTO :WS-DL-LOAN, :WS-DL-BORROWER,
                    :WS-DL-ADDRESS, :WS-DL-DPD,
                    :WS-DL-PAST-DUE-AMT, :WS-DL-LAST-PMT
           END-EXEC
           IF WS-SQLCODE = 100
               SET WS-EOF TO TRUE
           ELSE
               IF WS-SQLCODE = 0
                   PERFORM 3100-CLASSIFY-AND-NOTIFY
               END-IF
           END-IF.
       3100-CLASSIFY-AND-NOTIFY.
           ADD WS-DL-PAST-DUE-AMT TO WS-TOTAL-AMT
           ADD 1 TO WS-LETTERS-GEN
           EVALUATE TRUE
               WHEN WS-DL-DPD < 60
                   MOVE 'REMINDER  ' TO WS-NOTICE-TYPE
                   ADD 1 TO WS-TOTAL-30
               WHEN WS-DL-DPD < 90
                   MOVE 'DEMAND    ' TO WS-NOTICE-TYPE
                   ADD 1 TO WS-TOTAL-60
               WHEN WS-DL-DPD < 120
                   MOVE 'DEFAULT   ' TO WS-NOTICE-TYPE
                   ADD 1 TO WS-TOTAL-90
               WHEN OTHER
                   MOVE 'FORECLOSURE' TO WS-NOTICE-TYPE
                   ADD 1 TO WS-TOTAL-120
           END-EVALUATE
           DISPLAY WS-DL-LOAN ' ' WS-NOTICE-TYPE
               ' DPD=' WS-DL-DPD
               ' $' WS-DL-PAST-DUE-AMT.
       4000-CLOSE-CURSOR.
           EXEC SQL CLOSE DELINQ_CUR END-EXEC.
       5000-REPORT.
           DISPLAY 'DELINQUENCY NOTICE REPORT'
           DISPLAY '========================='
           DISPLAY 'DATE:     ' WS-RUN-DATE
           DISPLAY '30-DAY:   ' WS-TOTAL-30
           DISPLAY '60-DAY:   ' WS-TOTAL-60
           DISPLAY '90-DAY:   ' WS-TOTAL-90
           DISPLAY '120+ DAY: ' WS-TOTAL-120
           DISPLAY 'LETTERS:  ' WS-LETTERS-GEN
           DISPLAY 'TOTAL DUE:$' WS-TOTAL-AMT.
