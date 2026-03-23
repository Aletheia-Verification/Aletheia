       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-SQL-PENSION-REPORT.
      *---------------------------------------------------------------
      * MANUAL REVIEW: Contains EXEC SQL for pension fund
      * reporting from DB2 tables.
      *---------------------------------------------------------------

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01 WS-SQLCODE                   PIC S9(9) COMP-3.

       01 WS-PARTICIPANT-DATA.
           05 WS-PART-ID              PIC X(10).
           05 WS-PART-NAME            PIC X(30).
           05 WS-PART-DOB             PIC X(10).
           05 WS-PART-HIRE-DATE       PIC X(10).
           05 WS-PLAN-ID              PIC X(6).
           05 WS-VESTING-PCT          PIC S9(3)V99 COMP-3.
           05 WS-BALANCE              PIC S9(13)V99 COMP-3.
           05 WS-EMPLOYER-CONTRIB     PIC S9(11)V99 COMP-3.
           05 WS-EMPLOYEE-CONTRIB     PIC S9(11)V99 COMP-3.

       01 WS-REPORT-TOTALS.
           05 WS-TOT-BALANCE          PIC S9(15)V99 COMP-3
               VALUE 0.
           05 WS-TOT-EMPLOYER         PIC S9(13)V99 COMP-3
               VALUE 0.
           05 WS-TOT-EMPLOYEE         PIC S9(13)V99 COMP-3
               VALUE 0.
           05 WS-FULLY-VESTED-CNT     PIC S9(7) COMP-3 VALUE 0.
           05 WS-PARTIAL-VESTED-CNT   PIC S9(7) COMP-3 VALUE 0.

       01 WS-EOF-FLAG                 PIC X VALUE 'N'.
           88 WS-EOF                   VALUE 'Y'.

       01 WS-COUNTERS.
           05 WS-TOTAL-READ           PIC S9(7) COMP-3 VALUE 0.
           05 WS-ERRORS               PIC S9(7) COMP-3 VALUE 0.

       01 WS-PLAN-FILTER              PIC X(6) VALUE '401K01'.
       01 WS-MIN-BALANCE              PIC S9(13)V99 COMP-3
           VALUE 1000.00.

       01 WS-VESTED-AMT               PIC S9(13)V99 COMP-3.
       01 WS-FORFEITURE               PIC S9(13)V99 COMP-3.

       01 WS-DETAIL-BUF               PIC X(80).
       01 WS-DETAIL-PTR               PIC 9(3).
       01 WS-NAME-TALLY               PIC 9(3).

       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-OPEN-CURSOR
           IF WS-SQLCODE = 0
               PERFORM 3000-FETCH-LOOP
                   UNTIL WS-EOF
               PERFORM 4000-CLOSE-CURSOR
           END-IF
           PERFORM 5000-DISPLAY-REPORT
           STOP RUN.

       1000-INITIALIZE.
           MOVE 'N' TO WS-EOF-FLAG
           MOVE 0 TO WS-TOTAL-READ
           MOVE 0 TO WS-ERRORS.

       2000-OPEN-CURSOR.
           EXEC SQL
               DECLARE PENSION_CURSOR CURSOR FOR
               SELECT PARTICIPANT_ID,
                      PARTICIPANT_NAME,
                      DATE_OF_BIRTH,
                      HIRE_DATE,
                      PLAN_ID,
                      VESTING_PERCENTAGE,
                      ACCOUNT_BALANCE,
                      EMPLOYER_CONTRIBUTIONS,
                      EMPLOYEE_CONTRIBUTIONS
               FROM PENSION_PARTICIPANTS
               WHERE PLAN_ID = :WS-PLAN-FILTER
                 AND ACCOUNT_BALANCE >= :WS-MIN-BALANCE
               ORDER BY PARTICIPANT_NAME
           END-EXEC
           EXEC SQL
               OPEN PENSION_CURSOR
           END-EXEC
           MOVE SQLCODE TO WS-SQLCODE
           IF WS-SQLCODE NOT = 0
               DISPLAY 'CURSOR OPEN FAILED: '
                   WS-SQLCODE
           END-IF.

       3000-FETCH-LOOP.
           EXEC SQL
               FETCH PENSION_CURSOR
               INTO :WS-PART-ID,
                    :WS-PART-NAME,
                    :WS-PART-DOB,
                    :WS-PART-HIRE-DATE,
                    :WS-PLAN-ID,
                    :WS-VESTING-PCT,
                    :WS-BALANCE,
                    :WS-EMPLOYER-CONTRIB,
                    :WS-EMPLOYEE-CONTRIB
           END-EXEC
           MOVE SQLCODE TO WS-SQLCODE
           IF WS-SQLCODE = 100
               MOVE 'Y' TO WS-EOF-FLAG
           ELSE
               IF WS-SQLCODE = 0
                   ADD 1 TO WS-TOTAL-READ
                   PERFORM 3100-PROCESS-PARTICIPANT
               ELSE
                   ADD 1 TO WS-ERRORS
               END-IF
           END-IF.

       3100-PROCESS-PARTICIPANT.
           ADD WS-BALANCE TO WS-TOT-BALANCE
           ADD WS-EMPLOYER-CONTRIB TO WS-TOT-EMPLOYER
           ADD WS-EMPLOYEE-CONTRIB TO WS-TOT-EMPLOYEE
           COMPUTE WS-VESTED-AMT =
               WS-EMPLOYER-CONTRIB *
               (WS-VESTING-PCT / 100)
           COMPUTE WS-FORFEITURE =
               WS-EMPLOYER-CONTRIB - WS-VESTED-AMT
           IF WS-VESTING-PCT >= 100.00
               ADD 1 TO WS-FULLY-VESTED-CNT
           ELSE
               ADD 1 TO WS-PARTIAL-VESTED-CNT
           END-IF
           MOVE SPACES TO WS-DETAIL-BUF
           MOVE 1 TO WS-DETAIL-PTR
           STRING WS-PART-ID ' '
               WS-PART-NAME ' VEST='
               WS-VESTING-PCT '%'
               DELIMITED BY SIZE
               INTO WS-DETAIL-BUF
               WITH POINTER WS-DETAIL-PTR
           END-STRING
           MOVE 0 TO WS-NAME-TALLY
           INSPECT WS-PART-NAME
               TALLYING WS-NAME-TALLY FOR ALL ' '
           DISPLAY WS-DETAIL-BUF.

       4000-CLOSE-CURSOR.
           EXEC SQL
               CLOSE PENSION_CURSOR
           END-EXEC.

       5000-DISPLAY-REPORT.
           DISPLAY '=== PENSION FUND REPORT ==='
           DISPLAY 'PLAN: ' WS-PLAN-FILTER
           DISPLAY 'PARTICIPANTS:     ' WS-TOTAL-READ
           DISPLAY 'FULLY VESTED:     ' WS-FULLY-VESTED-CNT
           DISPLAY 'PARTIALLY VESTED: '
               WS-PARTIAL-VESTED-CNT
           DISPLAY 'TOTAL BALANCE:    ' WS-TOT-BALANCE
           DISPLAY 'TOTAL EMPLOYER:   ' WS-TOT-EMPLOYER
           DISPLAY 'TOTAL EMPLOYEE:   ' WS-TOT-EMPLOYEE
           DISPLAY 'SQL ERRORS:       ' WS-ERRORS.
