       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-SQL-OVERDRAFT-RPT.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-SQLCODE             PIC S9(9) COMP-3.
       01 WS-OD-RECORD.
           05 WS-OD-ACCT        PIC X(12).
           05 WS-OD-NAME        PIC X(30).
           05 WS-OD-BALANCE     PIC S9(9)V99 COMP-3.
           05 WS-OD-LIMIT       PIC S9(7)V99 COMP-3.
           05 WS-OD-DAYS        PIC 9(3).
           05 WS-OD-FEE-YTD     PIC S9(5)V99 COMP-3.
       01 WS-EOF-FLAG           PIC X VALUE 'N'.
           88 WS-EOF            VALUE 'Y'.
       01 WS-TOTALS.
           05 WS-T-ACCTS        PIC 9(5).
           05 WS-T-BALANCE      PIC S9(11)V99 COMP-3.
           05 WS-T-FEES         PIC S9(7)V99 COMP-3.
           05 WS-T-CHRONIC      PIC 9(3).
       01 WS-CHRONIC-DAYS       PIC 9(3) VALUE 30.
       01 WS-REPORT-DATE        PIC 9(8).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-OPEN-CURSOR
           PERFORM 3000-FETCH-LOOP UNTIL WS-EOF
           PERFORM 4000-CLOSE
           PERFORM 5000-REPORT
           STOP RUN.
       1000-INIT.
           MOVE 0 TO WS-T-ACCTS
           MOVE 0 TO WS-T-BALANCE
           MOVE 0 TO WS-T-FEES
           MOVE 0 TO WS-T-CHRONIC
           ACCEPT WS-REPORT-DATE FROM DATE YYYYMMDD.
       2000-OPEN-CURSOR.
           EXEC SQL
               DECLARE OD_CURSOR CURSOR FOR
               SELECT ACCT_NUM, CUST_NAME,
                      BALANCE, OD_LIMIT,
                      DAYS_OVERDRAWN, FEE_YTD
               FROM OVERDRAFT_REPORT_V
               WHERE BALANCE < 0
               ORDER BY BALANCE
           END-EXEC
           EXEC SQL OPEN OD_CURSOR END-EXEC.
       3000-FETCH-LOOP.
           EXEC SQL
               FETCH OD_CURSOR
               INTO :WS-OD-ACCT, :WS-OD-NAME,
                    :WS-OD-BALANCE, :WS-OD-LIMIT,
                    :WS-OD-DAYS, :WS-OD-FEE-YTD
           END-EXEC
           IF WS-SQLCODE = 100
               SET WS-EOF TO TRUE
           ELSE
               IF WS-SQLCODE = 0
                   PERFORM 3100-PROCESS
               END-IF
           END-IF.
       3100-PROCESS.
           ADD 1 TO WS-T-ACCTS
           ADD WS-OD-BALANCE TO WS-T-BALANCE
           ADD WS-OD-FEE-YTD TO WS-T-FEES
           IF WS-OD-DAYS > WS-CHRONIC-DAYS
               ADD 1 TO WS-T-CHRONIC
           END-IF
           DISPLAY WS-OD-ACCT ' ' WS-OD-NAME
               ' BAL=$' WS-OD-BALANCE
               ' DAYS=' WS-OD-DAYS.
       4000-CLOSE.
           EXEC SQL CLOSE OD_CURSOR END-EXEC.
       5000-REPORT.
           DISPLAY 'OVERDRAFT REPORT'
           DISPLAY '================'
           DISPLAY 'DATE:    ' WS-REPORT-DATE
           DISPLAY 'ACCTS:   ' WS-T-ACCTS
           DISPLAY 'TOTAL:   $' WS-T-BALANCE
           DISPLAY 'FEES YTD:$' WS-T-FEES
           DISPLAY 'CHRONIC: ' WS-T-CHRONIC.
