       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-EXEC-SQL-REPORT.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-SQLCODE                  PIC S9(9) COMP-3.
       01 WS-REPORT-DATE             PIC X(10).
       01 WS-CTR-FIELDS.
           05 WS-ACCT-ID             PIC X(12).
           05 WS-CUST-NAME           PIC X(30).
           05 WS-TXN-AMOUNT          PIC S9(9)V99 COMP-3.
           05 WS-TXN-DATE            PIC X(10).
           05 WS-TXN-TYPE            PIC X(2).
       01 WS-CTR-THRESHOLD           PIC S9(7)V99 COMP-3
           VALUE 10000.00.
       01 WS-TOTALS.
           05 WS-RECORDS-READ        PIC S9(5) COMP-3.
           05 WS-CTR-COUNT           PIC S9(5) COMP-3.
           05 WS-TOTAL-AMOUNT        PIC S9(11)V99 COMP-3.
       01 WS-EOF-FLAG                PIC X VALUE 'N'.
           88 WS-EOF                  VALUE 'Y'.
       01 WS-REPORT-LINE             PIC X(80).
       01 WS-PROCESS-FLAG            PIC X VALUE 'Y'.
           88 WS-CONTINUE             VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-OPEN-CURSOR
           IF WS-CONTINUE
               PERFORM 3000-FETCH-LOOP UNTIL WS-EOF
               PERFORM 4000-CLOSE-CURSOR
           END-IF
           PERFORM 5000-DISPLAY-REPORT
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-RECORDS-READ
           MOVE 0 TO WS-CTR-COUNT
           MOVE 0 TO WS-TOTAL-AMOUNT
           MOVE 'N' TO WS-EOF-FLAG.
       2000-OPEN-CURSOR.
           EXEC SQL
               DECLARE CTR_CURSOR CURSOR FOR
               SELECT A.ACCT_ID, C.CUST_NAME,
                      T.TXN_AMOUNT, T.TXN_DATE,
                      T.TXN_TYPE
               FROM TRANSACTIONS T
               JOIN ACCOUNT_MASTER A
                   ON T.ACCT_ID = A.ACCT_ID
               JOIN CUSTOMER C
                   ON A.CUST_ID = C.CUST_ID
               WHERE T.TXN_AMOUNT >= :WS-CTR-THRESHOLD
                 AND T.TXN_DATE = :WS-REPORT-DATE
               ORDER BY T.TXN_AMOUNT DESC
           END-EXEC
           EXEC SQL
               OPEN CTR_CURSOR
           END-EXEC
           IF WS-SQLCODE NOT = 0
               MOVE 'N' TO WS-PROCESS-FLAG
               DISPLAY 'CURSOR OPEN ERROR: ' WS-SQLCODE
           END-IF.
       3000-FETCH-LOOP.
           EXEC SQL
               FETCH CTR_CURSOR
               INTO :WS-ACCT-ID,
                    :WS-CUST-NAME,
                    :WS-TXN-AMOUNT,
                    :WS-TXN-DATE,
                    :WS-TXN-TYPE
           END-EXEC
           IF WS-SQLCODE = 100
               SET WS-EOF TO TRUE
           ELSE
               IF WS-SQLCODE = 0
                   ADD 1 TO WS-RECORDS-READ
                   ADD 1 TO WS-CTR-COUNT
                   ADD WS-TXN-AMOUNT TO WS-TOTAL-AMOUNT
                   PERFORM 3100-FORMAT-LINE
               END-IF
           END-IF.
       3100-FORMAT-LINE.
           STRING WS-ACCT-ID DELIMITED BY SIZE
                  '|' DELIMITED BY SIZE
                  WS-CUST-NAME DELIMITED BY '  '
                  '|' DELIMITED BY SIZE
                  WS-TXN-AMOUNT DELIMITED BY SIZE
                  '|' DELIMITED BY SIZE
                  WS-TXN-TYPE DELIMITED BY SIZE
                  INTO WS-REPORT-LINE
           END-STRING
           DISPLAY WS-REPORT-LINE.
       4000-CLOSE-CURSOR.
           EXEC SQL
               CLOSE CTR_CURSOR
           END-EXEC.
       5000-DISPLAY-REPORT.
           DISPLAY 'CTR EXTRACT REPORT'
           DISPLAY '=================='
           DISPLAY 'REPORT DATE:   ' WS-REPORT-DATE
           DISPLAY 'THRESHOLD:     ' WS-CTR-THRESHOLD
           DISPLAY 'RECORDS:       ' WS-RECORDS-READ
           DISPLAY 'CTR COUNT:     ' WS-CTR-COUNT
           DISPLAY 'TOTAL AMOUNT:  ' WS-TOTAL-AMOUNT.
