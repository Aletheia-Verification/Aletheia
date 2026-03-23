       IDENTIFICATION DIVISION.
       PROGRAM-ID. TREAS-REPO-SETTLE.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT REPO-FILE ASSIGN TO 'REPOS.DAT'
               FILE STATUS IS WS-REPO-STATUS.
           SELECT SETTLE-FILE ASSIGN TO 'SETTLE.DAT'
               FILE STATUS IS WS-SETTLE-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD REPO-FILE.
       01 REPO-RECORD.
           05 RP-DEAL-ID             PIC X(12).
           05 RP-COLLATERAL          PIC X(10).
           05 RP-PRINCIPAL           PIC 9(11)V99.
           05 RP-RATE                PIC 9(1)V9(6).
           05 RP-TERM-DAYS           PIC 9(3).
           05 RP-DIRECTION           PIC X(1).
       FD SETTLE-FILE.
       01 SETTLE-RECORD.
           05 ST-DEAL-ID             PIC X(12).
           05 ST-PRINCIPAL           PIC 9(11)V99.
           05 ST-INTEREST            PIC 9(9)V99.
           05 ST-SETTLE-AMT          PIC 9(11)V99.
           05 ST-STATUS              PIC X(6).
       WORKING-STORAGE SECTION.
       01 WS-REPO-STATUS             PIC XX.
       01 WS-SETTLE-STATUS           PIC XX.
       01 WS-EOF-FLAG                PIC X VALUE 'N'.
           88 WS-EOF                  VALUE 'Y'.
       01 WS-CALC-FIELDS.
           05 WS-INTEREST            PIC S9(9)V99 COMP-3.
           05 WS-SETTLE-AMT          PIC S9(11)V99 COMP-3.
           05 WS-HAIRCUT             PIC S9(9)V99 COMP-3.
           05 WS-HAIRCUT-PCT         PIC S9(1)V9(4) COMP-3.
       01 WS-DIRECTION-FLAG          PIC X(1).
           88 WS-REPO                VALUE 'R'.
           88 WS-REVERSE             VALUE 'V'.
       01 WS-TOTALS.
           05 WS-TOTAL-PRIN          PIC S9(13)V99 COMP-3.
           05 WS-TOTAL-INT           PIC S9(11)V99 COMP-3.
           05 WS-DEAL-COUNT          PIC S9(5) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 1100-OPEN-FILES
           PERFORM 2000-PROCESS-REPOS UNTIL WS-EOF
           PERFORM 3000-CLOSE-FILES
           PERFORM 4000-DISPLAY-SUMMARY
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-PRIN
           MOVE 0 TO WS-TOTAL-INT
           MOVE 0 TO WS-DEAL-COUNT.
       1100-OPEN-FILES.
           OPEN INPUT REPO-FILE
           OPEN OUTPUT SETTLE-FILE.
       2000-PROCESS-REPOS.
           READ REPO-FILE
               AT END SET WS-EOF TO TRUE
               NOT AT END PERFORM 2100-CALC-SETTLE
           END-READ.
       2100-CALC-SETTLE.
           ADD 1 TO WS-DEAL-COUNT
           MOVE RP-DIRECTION TO WS-DIRECTION-FLAG
           COMPUTE WS-INTEREST =
               RP-PRINCIPAL * RP-RATE * RP-TERM-DAYS / 360
           COMPUTE WS-SETTLE-AMT =
               RP-PRINCIPAL + WS-INTEREST
           EVALUATE TRUE
               WHEN WS-REPO
                   MOVE 0.0200 TO WS-HAIRCUT-PCT
               WHEN WS-REVERSE
                   MOVE 0.0300 TO WS-HAIRCUT-PCT
               WHEN OTHER
                   MOVE 0.0500 TO WS-HAIRCUT-PCT
           END-EVALUATE
           COMPUTE WS-HAIRCUT =
               RP-PRINCIPAL * WS-HAIRCUT-PCT
           ADD RP-PRINCIPAL TO WS-TOTAL-PRIN
           ADD WS-INTEREST TO WS-TOTAL-INT
           MOVE RP-DEAL-ID TO ST-DEAL-ID
           MOVE RP-PRINCIPAL TO ST-PRINCIPAL
           MOVE WS-INTEREST TO ST-INTEREST
           MOVE WS-SETTLE-AMT TO ST-SETTLE-AMT
           MOVE 'SETTLD' TO ST-STATUS
           WRITE SETTLE-RECORD.
       3000-CLOSE-FILES.
           CLOSE REPO-FILE
           CLOSE SETTLE-FILE.
       4000-DISPLAY-SUMMARY.
           DISPLAY 'REPO SETTLEMENT SUMMARY'
           DISPLAY '======================='
           DISPLAY 'DEALS:         ' WS-DEAL-COUNT
           DISPLAY 'TOTAL PRIN:    ' WS-TOTAL-PRIN
           DISPLAY 'TOTAL INT:     ' WS-TOTAL-INT.
