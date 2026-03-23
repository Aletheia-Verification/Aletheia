       IDENTIFICATION DIVISION.
       PROGRAM-ID. PENSION-CONTRIB-CALC.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT EMPLOYEE-FILE ASSIGN TO 'EMPFILE'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-EMP-STATUS.
           SELECT CONTRIB-FILE ASSIGN TO 'CONTFILE'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-CONT-STATUS.

       DATA DIVISION.
       FILE SECTION.

       FD EMPLOYEE-FILE.
       01 EMP-RECORD.
           05 EMP-ID                    PIC X(10).
           05 EMP-NAME                  PIC X(30).
           05 EMP-HIRE-DATE             PIC 9(8).
           05 EMP-SALARY                PIC S9(9)V99 COMP-3.
           05 EMP-TIER-CODE             PIC X(1).
               88 EMP-TIER-BASIC        VALUE 'B'.
               88 EMP-TIER-STANDARD     VALUE 'S'.
               88 EMP-TIER-PREMIUM      VALUE 'P'.
           05 EMP-DEFERRAL-PCT          PIC S9(2)V99 COMP-3.
           05 EMP-AGE                   PIC 9(2).
           05 EMP-CATCH-UP-FLAG         PIC X(1).
               88 EMP-CATCH-UP          VALUE 'Y'.

       FD CONTRIB-FILE.
       01 CONT-RECORD.
           05 CONT-EMP-ID              PIC X(10).
           05 CONT-EMPLOYEE-AMT        PIC S9(9)V99 COMP-3.
           05 CONT-EMPLOYER-AMT        PIC S9(9)V99 COMP-3.
           05 CONT-CATCH-UP-AMT        PIC S9(9)V99 COMP-3.
           05 CONT-TOTAL-AMT           PIC S9(9)V99 COMP-3.
           05 CONT-STATUS              PIC X(8).
           05 CONT-ERROR-MSG           PIC X(50).

       WORKING-STORAGE SECTION.

       01 WS-FILE-STATUS.
           05 WS-EMP-STATUS            PIC X(2).
           05 WS-CONT-STATUS           PIC X(2).

       01 WS-EOF-FLAG                  PIC X VALUE 'N'.
           88 WS-EOF                    VALUE 'Y'.

       01 WS-COUNTERS.
           05 WS-READ-COUNT            PIC S9(7) COMP-3 VALUE 0.
           05 WS-WRITE-COUNT           PIC S9(7) COMP-3 VALUE 0.
           05 WS-ERROR-COUNT           PIC S9(7) COMP-3 VALUE 0.
           05 WS-CATCH-UP-COUNT        PIC S9(7) COMP-3 VALUE 0.

       01 WS-CALC-FIELDS.
           05 WS-ANNUAL-LIMIT          PIC S9(9)V99 COMP-3.
           05 WS-CATCH-UP-LIMIT        PIC S9(9)V99 COMP-3
               VALUE 7500.00.
           05 WS-EMPLOYER-MATCH-PCT    PIC S9(2)V99 COMP-3.
           05 WS-EMPLOYER-MATCH-CAP    PIC S9(2)V99 COMP-3.
           05 WS-EMPLOYEE-CONTRIB      PIC S9(9)V99 COMP-3.
           05 WS-EMPLOYER-CONTRIB      PIC S9(9)V99 COMP-3.
           05 WS-CATCH-UP-AMT          PIC S9(9)V99 COMP-3.
           05 WS-TOTAL-CONTRIB         PIC S9(9)V99 COMP-3.

       01 WS-TIER-TABLE.
           05 WS-TIER-ENTRY OCCURS 3.
               10 WS-TIER-MATCH-PCT    PIC S9(2)V99 COMP-3.
               10 WS-TIER-MATCH-CAP    PIC S9(2)V99 COMP-3.
               10 WS-TIER-LIMIT        PIC S9(9)V99 COMP-3.

       01 WS-TIER-IDX                  PIC 9(1).
       01 WS-ERR-DETAIL                PIC X(50).
       01 WS-DASH-COUNT                PIC 9(3).

       01 WS-TOTALS.
           05 WS-TOTAL-EMP-CONTRIB     PIC S9(11)V99 COMP-3
               VALUE 0.
           05 WS-TOTAL-EER-CONTRIB     PIC S9(11)V99 COMP-3
               VALUE 0.

       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 1100-OPEN-FILES
           IF WS-EMP-STATUS = '00'
               PERFORM 2000-PROCESS-EMPLOYEE
                   UNTIL WS-EOF
               PERFORM 3000-WRITE-SUMMARY
           END-IF
           PERFORM 4000-CLOSE-FILES
           PERFORM 5000-DISPLAY-TOTALS
           STOP RUN.

       1000-INITIALIZE.
           MOVE 23000.00 TO WS-ANNUAL-LIMIT
           MOVE 'N' TO WS-EOF-FLAG
           MOVE 0.50 TO WS-TIER-MATCH-PCT(1)
           MOVE 3.00 TO WS-TIER-MATCH-CAP(1)
           MOVE 23000.00 TO WS-TIER-LIMIT(1)
           MOVE 0.75 TO WS-TIER-MATCH-PCT(2)
           MOVE 5.00 TO WS-TIER-MATCH-CAP(2)
           MOVE 23000.00 TO WS-TIER-LIMIT(2)
           MOVE 1.00 TO WS-TIER-MATCH-PCT(3)
           MOVE 6.00 TO WS-TIER-MATCH-CAP(3)
           MOVE 23000.00 TO WS-TIER-LIMIT(3).

       1100-OPEN-FILES.
           OPEN INPUT EMPLOYEE-FILE
           OPEN OUTPUT CONTRIB-FILE
           IF WS-EMP-STATUS NOT = '00'
               DISPLAY 'OPEN EMPLOYEE FILE FAILED: '
                   WS-EMP-STATUS
           END-IF
           READ EMPLOYEE-FILE
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ.

       2000-PROCESS-EMPLOYEE.
           ADD 1 TO WS-READ-COUNT
           MOVE SPACES TO CONT-ERROR-MSG
           MOVE SPACES TO WS-ERR-DETAIL
           MOVE EMP-ID TO CONT-EMP-ID
           EVALUATE TRUE
               WHEN EMP-TIER-BASIC
                   MOVE 1 TO WS-TIER-IDX
               WHEN EMP-TIER-STANDARD
                   MOVE 2 TO WS-TIER-IDX
               WHEN EMP-TIER-PREMIUM
                   MOVE 3 TO WS-TIER-IDX
               WHEN OTHER
                   MOVE 1 TO WS-TIER-IDX
                   STRING 'UNKNOWN TIER ' EMP-TIER-CODE
                       DELIMITED BY SIZE
                       INTO WS-ERR-DETAIL
                   END-STRING
                   ADD 1 TO WS-ERROR-COUNT
           END-EVALUATE
           PERFORM 2100-CALC-EMPLOYEE-CONTRIB
           PERFORM 2200-CALC-EMPLOYER-MATCH
           PERFORM 2300-CALC-CATCH-UP
           PERFORM 2400-BUILD-OUTPUT-RECORD
           WRITE CONT-RECORD
           ADD 1 TO WS-WRITE-COUNT
           READ EMPLOYEE-FILE
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ.

       2100-CALC-EMPLOYEE-CONTRIB.
           COMPUTE WS-EMPLOYEE-CONTRIB =
               EMP-SALARY * (EMP-DEFERRAL-PCT / 100)
           IF WS-EMPLOYEE-CONTRIB >
               WS-TIER-LIMIT(WS-TIER-IDX)
               MOVE WS-TIER-LIMIT(WS-TIER-IDX) TO
                   WS-EMPLOYEE-CONTRIB
           END-IF
           IF WS-EMPLOYEE-CONTRIB < 0
               MOVE 0 TO WS-EMPLOYEE-CONTRIB
               STRING 'NEG DEFERRAL RESET '
                   DELIMITED BY SIZE
                   INTO WS-ERR-DETAIL
               END-STRING
               ADD 1 TO WS-ERROR-COUNT
           END-IF.

       2200-CALC-EMPLOYER-MATCH.
           MOVE WS-TIER-MATCH-PCT(WS-TIER-IDX)
               TO WS-EMPLOYER-MATCH-PCT
           MOVE WS-TIER-MATCH-CAP(WS-TIER-IDX)
               TO WS-EMPLOYER-MATCH-CAP
           IF EMP-DEFERRAL-PCT > WS-EMPLOYER-MATCH-CAP
               COMPUTE WS-EMPLOYER-CONTRIB =
                   EMP-SALARY *
                   (WS-EMPLOYER-MATCH-CAP / 100) *
                   WS-EMPLOYER-MATCH-PCT
           ELSE
               COMPUTE WS-EMPLOYER-CONTRIB =
                   EMP-SALARY *
                   (EMP-DEFERRAL-PCT / 100) *
                   WS-EMPLOYER-MATCH-PCT
           END-IF.

       2300-CALC-CATCH-UP.
           MOVE 0 TO WS-CATCH-UP-AMT
           IF EMP-CATCH-UP
               IF EMP-AGE >= 50
                   MOVE WS-CATCH-UP-LIMIT TO
                       WS-CATCH-UP-AMT
                   ADD 1 TO WS-CATCH-UP-COUNT
               END-IF
           END-IF.

       2400-BUILD-OUTPUT-RECORD.
           MOVE WS-EMPLOYEE-CONTRIB TO CONT-EMPLOYEE-AMT
           MOVE WS-EMPLOYER-CONTRIB TO CONT-EMPLOYER-AMT
           MOVE WS-CATCH-UP-AMT TO CONT-CATCH-UP-AMT
           COMPUTE WS-TOTAL-CONTRIB =
               WS-EMPLOYEE-CONTRIB + WS-EMPLOYER-CONTRIB
               + WS-CATCH-UP-AMT
           MOVE WS-TOTAL-CONTRIB TO CONT-TOTAL-AMT
           ADD WS-EMPLOYEE-CONTRIB TO WS-TOTAL-EMP-CONTRIB
           ADD WS-EMPLOYER-CONTRIB TO WS-TOTAL-EER-CONTRIB
           IF WS-ERR-DETAIL NOT = SPACES
               MOVE 'WARNING ' TO CONT-STATUS
               MOVE WS-ERR-DETAIL TO CONT-ERROR-MSG
           ELSE
               MOVE 'OK      ' TO CONT-STATUS
           END-IF.

       3000-WRITE-SUMMARY.
           MOVE 0 TO WS-DASH-COUNT
           INSPECT WS-ERR-DETAIL
               TALLYING WS-DASH-COUNT FOR ALL '-'
           DISPLAY 'SUMMARY DASH COUNT: ' WS-DASH-COUNT.

       4000-CLOSE-FILES.
           CLOSE EMPLOYEE-FILE
           CLOSE CONTRIB-FILE.

       5000-DISPLAY-TOTALS.
           DISPLAY 'PENSION CONTRIBUTION CALCULATION COMPLETE'
           DISPLAY 'RECORDS READ:      ' WS-READ-COUNT
           DISPLAY 'RECORDS WRITTEN:   ' WS-WRITE-COUNT
           DISPLAY 'ERRORS:            ' WS-ERROR-COUNT
           DISPLAY 'CATCH-UP ELIGIBLE: ' WS-CATCH-UP-COUNT
           DISPLAY 'TOTAL EMP CONTRIB: ' WS-TOTAL-EMP-CONTRIB
           DISPLAY 'TOTAL EER CONTRIB: ' WS-TOTAL-EER-CONTRIB.
