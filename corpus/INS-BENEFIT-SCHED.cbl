       IDENTIFICATION DIVISION.
       PROGRAM-ID. INS-BENEFIT-SCHED.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT SCHED-FILE ASSIGN TO 'BENEFITS.DAT'
               FILE STATUS IS WS-SCHED-STATUS.
           SELECT RPT-FILE ASSIGN TO 'BENEFIT-RPT.DAT'
               FILE STATUS IS WS-RPT-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD SCHED-FILE.
       01 SCHED-RECORD.
           05 SD-PLAN-CODE           PIC X(4).
           05 SD-BENEFIT-TYPE        PIC X(2).
           05 SD-MAX-AMOUNT          PIC 9(7)V99.
           05 SD-COPAY-PCT           PIC 9(2)V99.
       FD RPT-FILE.
       01 RPT-RECORD.
           05 RP-PLAN-CODE           PIC X(4).
           05 RP-BENEFIT-COUNT       PIC 9(3).
           05 RP-TOTAL-MAX           PIC 9(9)V99.
           05 RP-STATUS              PIC X(6).
       WORKING-STORAGE SECTION.
       01 WS-SCHED-STATUS            PIC XX.
       01 WS-RPT-STATUS              PIC XX.
       01 WS-EOF-FLAG                PIC X VALUE 'N'.
           88 WS-EOF                  VALUE 'Y'.
       01 WS-PLAN-TABLE.
           05 WS-PLAN OCCURS 8.
               10 WS-PL-CODE         PIC X(4).
               10 WS-PL-COUNT        PIC S9(3) COMP-3.
               10 WS-PL-TOTAL-MAX    PIC S9(9)V99 COMP-3.
       01 WS-PL-IDX                  PIC 9(1).
       01 WS-PL-USED                 PIC 9(1).
       01 WS-FOUND                   PIC 9(1).
       01 WS-TOTAL-BENEFITS          PIC S9(5) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 1100-OPEN-FILES
           PERFORM 2000-READ-SCHED UNTIL WS-EOF
           PERFORM 3000-WRITE-REPORT
           PERFORM 4000-CLOSE-FILES
           PERFORM 5000-DISPLAY-SUMMARY
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-PL-USED
           MOVE 0 TO WS-TOTAL-BENEFITS
           PERFORM VARYING WS-PL-IDX FROM 1 BY 1
               UNTIL WS-PL-IDX > 8
               MOVE SPACES TO WS-PL-CODE(WS-PL-IDX)
               MOVE 0 TO WS-PL-COUNT(WS-PL-IDX)
               MOVE 0 TO WS-PL-TOTAL-MAX(WS-PL-IDX)
           END-PERFORM.
       1100-OPEN-FILES.
           OPEN INPUT SCHED-FILE
           OPEN OUTPUT RPT-FILE.
       2000-READ-SCHED.
           READ SCHED-FILE
               AT END SET WS-EOF TO TRUE
               NOT AT END PERFORM 2100-PROCESS-BENEFIT
           END-READ.
       2100-PROCESS-BENEFIT.
           ADD 1 TO WS-TOTAL-BENEFITS
           MOVE 0 TO WS-FOUND
           PERFORM VARYING WS-PL-IDX FROM 1 BY 1
               UNTIL WS-PL-IDX > WS-PL-USED
               OR WS-FOUND > 0
               IF WS-PL-CODE(WS-PL-IDX) = SD-PLAN-CODE
                   MOVE WS-PL-IDX TO WS-FOUND
               END-IF
           END-PERFORM
           IF WS-FOUND = 0
               ADD 1 TO WS-PL-USED
               MOVE WS-PL-USED TO WS-FOUND
               MOVE SD-PLAN-CODE TO WS-PL-CODE(WS-FOUND)
           END-IF
           ADD 1 TO WS-PL-COUNT(WS-FOUND)
           ADD SD-MAX-AMOUNT TO WS-PL-TOTAL-MAX(WS-FOUND).
       3000-WRITE-REPORT.
           PERFORM VARYING WS-PL-IDX FROM 1 BY 1
               UNTIL WS-PL-IDX > WS-PL-USED
               MOVE WS-PL-CODE(WS-PL-IDX) TO RP-PLAN-CODE
               MOVE WS-PL-COUNT(WS-PL-IDX) TO
                   RP-BENEFIT-COUNT
               MOVE WS-PL-TOTAL-MAX(WS-PL-IDX) TO
                   RP-TOTAL-MAX
               MOVE 'ACTIVE' TO RP-STATUS
               WRITE RPT-RECORD
           END-PERFORM.
       4000-CLOSE-FILES.
           CLOSE SCHED-FILE
           CLOSE RPT-FILE.
       5000-DISPLAY-SUMMARY.
           DISPLAY 'BENEFIT SCHEDULE REPORT'
           DISPLAY '======================='
           DISPLAY 'TOTAL BENEFITS: ' WS-TOTAL-BENEFITS
           DISPLAY 'PLANS:          ' WS-PL-USED
           PERFORM VARYING WS-PL-IDX FROM 1 BY 1
               UNTIL WS-PL-IDX > WS-PL-USED
               DISPLAY '  PLAN=' WS-PL-CODE(WS-PL-IDX)
                   ' BENEFITS=' WS-PL-COUNT(WS-PL-IDX)
                   ' MAX=' WS-PL-TOTAL-MAX(WS-PL-IDX)
           END-PERFORM.
