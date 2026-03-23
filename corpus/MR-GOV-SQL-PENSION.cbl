       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-GOV-SQL-PENSION.
      *================================================================
      * Government Pension Fund SQL Data Access
      * Reads pension records from DB2 via EXEC SQL,
      * computes benefit accrual. (MANUAL REVIEW - EXEC SQL)
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-SQLCODE                   PIC S9(9) COMP-3.
       01 WS-EMPLOYEE.
           05 WS-EMP-ID               PIC X(10).
           05 WS-EMP-NAME             PIC X(30).
           05 WS-EMP-AGENCY           PIC X(4).
           05 WS-HIRE-DATE            PIC 9(8).
           05 WS-FERS-CSRS            PIC X(1).
               88 WS-FERS             VALUE 'F'.
               88 WS-CSRS             VALUE 'C'.
       01 WS-SERVICE-DATA.
           05 WS-YEARS-OF-SERVICE     PIC 9(2).
           05 WS-MONTHS-OF-SERVICE    PIC 9(2).
           05 WS-HIGH-3-SALARY        PIC S9(7)V99 COMP-3.
           05 WS-CURRENT-SALARY       PIC S9(7)V99 COMP-3.
           05 WS-UNUSED-SICK-HOURS    PIC 9(4).
       01 WS-BENEFIT-CALC.
           05 WS-ACCRUAL-RATE         PIC S9(1)V9(4) COMP-3.
           05 WS-BASE-ANNUITY         PIC S9(7)V99 COMP-3.
           05 WS-SICK-LEAVE-CREDIT    PIC S9(3)V99 COMP-3.
           05 WS-TOTAL-MONTHS         PIC 9(4).
           05 WS-ADJUSTED-ANNUITY     PIC S9(7)V99 COMP-3.
           05 WS-MONTHLY-BENEFIT      PIC S9(5)V99 COMP-3.
       01 WS-SURVIVOR-FIELDS.
           05 WS-SURVIVOR-OPTION      PIC X(1).
               88 WS-FULL-SURVIVOR    VALUE 'F'.
               88 WS-PARTIAL-SURVIVOR VALUE 'P'.
               88 WS-NO-SURVIVOR      VALUE 'N'.
           05 WS-SURVIVOR-REDUCTION   PIC S9(1)V9(4) COMP-3.
       01 WS-COUNTERS.
           05 WS-RECORDS-READ         PIC 9(5).
           05 WS-RECORDS-PROCESSED    PIC 9(5).
           05 WS-RECORDS-ERROR        PIC 9(5).
       01 WS-EOF-FLAG                  PIC X VALUE 'N'.
           88 WS-EOF                   VALUE 'Y'.
       01 WS-PROCESS-DATE             PIC 9(8).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-OPEN-CURSOR
           PERFORM 3000-PROCESS-RECORDS
               UNTIL WS-EOF
           PERFORM 4000-CLOSE-CURSOR
           PERFORM 5000-DISPLAY-SUMMARY
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-PROCESS-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-RECORDS-READ
           MOVE 0 TO WS-RECORDS-PROCESSED
           MOVE 0 TO WS-RECORDS-ERROR.
       2000-OPEN-CURSOR.
           EXEC SQL
               DECLARE PENSION_CUR CURSOR FOR
               SELECT EMP_ID, EMP_NAME, AGENCY_CODE,
                      HIRE_DATE, FERS_CSRS_IND,
                      YEARS_SVC, HIGH_3_SALARY,
                      CURRENT_SALARY, SICK_HOURS
               FROM PENSION_MASTER
               WHERE STATUS = 'ACTIVE'
               ORDER BY EMP_ID
           END-EXEC
           EXEC SQL
               OPEN PENSION_CUR
           END-EXEC
           IF WS-SQLCODE NOT = 0
               DISPLAY "CURSOR OPEN ERROR: " WS-SQLCODE
           END-IF.
       3000-PROCESS-RECORDS.
           EXEC SQL
               FETCH PENSION_CUR
               INTO :WS-EMP-ID, :WS-EMP-NAME,
                    :WS-EMP-AGENCY, :WS-HIRE-DATE,
                    :WS-FERS-CSRS,
                    :WS-YEARS-OF-SERVICE,
                    :WS-HIGH-3-SALARY,
                    :WS-CURRENT-SALARY,
                    :WS-UNUSED-SICK-HOURS
           END-EXEC
           IF WS-SQLCODE = 100
               MOVE 'Y' TO WS-EOF-FLAG
           ELSE IF WS-SQLCODE NOT = 0
               ADD 1 TO WS-RECORDS-ERROR
           ELSE
               ADD 1 TO WS-RECORDS-READ
               PERFORM 3100-CALC-BENEFIT
               ADD 1 TO WS-RECORDS-PROCESSED
           END-IF.
       3100-CALC-BENEFIT.
           EVALUATE TRUE
               WHEN WS-FERS
                   IF WS-YEARS-OF-SERVICE >= 20
                       MOVE 0.0110 TO WS-ACCRUAL-RATE
                   ELSE
                       MOVE 0.0100 TO WS-ACCRUAL-RATE
                   END-IF
               WHEN WS-CSRS
                   IF WS-YEARS-OF-SERVICE > 10
                       MOVE 0.0200 TO WS-ACCRUAL-RATE
                   ELSE
                       MOVE 0.0175 TO WS-ACCRUAL-RATE
                   END-IF
           END-EVALUATE
           COMPUTE WS-SICK-LEAVE-CREDIT =
               WS-UNUSED-SICK-HOURS / 2087
           COMPUTE WS-TOTAL-MONTHS =
               (WS-YEARS-OF-SERVICE * 12) +
               WS-MONTHS-OF-SERVICE
           COMPUTE WS-BASE-ANNUITY =
               WS-HIGH-3-SALARY * WS-ACCRUAL-RATE *
               WS-YEARS-OF-SERVICE
           EVALUATE TRUE
               WHEN WS-FULL-SURVIVOR
                   MOVE 0.10 TO WS-SURVIVOR-REDUCTION
               WHEN WS-PARTIAL-SURVIVOR
                   MOVE 0.05 TO WS-SURVIVOR-REDUCTION
               WHEN WS-NO-SURVIVOR
                   MOVE 0 TO WS-SURVIVOR-REDUCTION
           END-EVALUATE
           COMPUTE WS-ADJUSTED-ANNUITY =
               WS-BASE-ANNUITY *
               (1 - WS-SURVIVOR-REDUCTION)
           COMPUTE WS-MONTHLY-BENEFIT =
               WS-ADJUSTED-ANNUITY / 12
           DISPLAY WS-EMP-ID " " WS-EMP-NAME
               " MONTHLY: " WS-MONTHLY-BENEFIT.
       4000-CLOSE-CURSOR.
           EXEC SQL
               CLOSE PENSION_CUR
           END-EXEC.
       5000-DISPLAY-SUMMARY.
           DISPLAY "PENSION BATCH COMPLETE"
           DISPLAY "DATE: " WS-PROCESS-DATE
           DISPLAY "READ: " WS-RECORDS-READ
           DISPLAY "PROCESSED: " WS-RECORDS-PROCESSED
           DISPLAY "ERRORS: " WS-RECORDS-ERROR.
