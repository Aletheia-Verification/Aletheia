       IDENTIFICATION DIVISION.
       PROGRAM-ID. COMML-COVENANT-CHK.
      *================================================================*
      * Commercial Loan Covenant Compliance Checker                     *
      * Tests borrower financial covenants (DSCR, leverage, current    *
      * ratio, tangible net worth), generates violation notices,        *
      * and applies cure period logic.                                  *
      *================================================================*
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT COVENANT-FILE ASSIGN TO 'COVENANT.DAT'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-COV-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD  COVENANT-FILE.
       01  COVENANT-RECORD.
           05  CV-LOAN-NUM          PIC X(12).
           05  CV-BORROWER          PIC X(25).
           05  CV-NET-INCOME        PIC S9(11)V99.
           05  CV-DEBT-SERVICE      PIC 9(09)V99.
           05  CV-TOTAL-DEBT        PIC 9(11)V99.
           05  CV-TOTAL-EQUITY      PIC S9(11)V99.
           05  CV-CURRENT-ASSETS    PIC 9(11)V99.
           05  CV-CURRENT-LIAB     PIC 9(11)V99.
           05  CV-TANG-NET-WORTH    PIC S9(11)V99.
           05  CV-REQ-DSCR          PIC 9V99.
           05  CV-REQ-LEVERAGE      PIC 9(02)V99.
           05  CV-REQ-CURRENT       PIC 9V99.
           05  CV-REQ-TNW           PIC 9(11)V99.
           05  CV-CURE-DAYS         PIC 9(03).
       WORKING-STORAGE SECTION.
       01  WS-COV-STATUS          PIC XX VALUE SPACES.
       01  WS-EOF                 PIC X VALUE 'N'.
           88  END-OF-FILE        VALUE 'Y'.
       01  WS-ACTUAL-DSCR        PIC 9(03)V99.
       01  WS-ACTUAL-LEVERAGE    PIC 9(03)V99.
       01  WS-ACTUAL-CURRENT     PIC 9(03)V99.
       01  WS-VIOLATION-CT       PIC 9(02) VALUE 0.
       01  WS-VIOLATION-TABLE.
           05  WS-VIOL-ENTRY     OCCURS 4 TIMES.
               10  VE-TYPE       PIC X(15).
               10  VE-REQUIRED   PIC 9(11)V99.
               10  VE-ACTUAL     PIC S9(11)V99.
               10  VE-SEVERITY   PIC X(01).
       01  WS-TOTAL-CHECKED      PIC 9(06) VALUE 0.
       01  WS-COMPLIANT-CNT      PIC 9(06) VALUE 0.
       01  WS-VIOLATION-CNT      PIC 9(06) VALUE 0.
       01  WS-CURE-CNT           PIC 9(06) VALUE 0.
       01  WS-DEFAULT-CNT        PIC 9(06) VALUE 0.
       01  WS-IDX                PIC 9(02).
       01  WS-NOTICE-LINE        PIC X(120) VALUE SPACES.
       01  WS-CURRENT-DATE.
           05  WS-CUR-YEAR       PIC 9(04).
           05  WS-CUR-MONTH      PIC 9(02).
           05  WS-CUR-DAY        PIC 9(02).
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PROCESS-COVENANTS
               UNTIL END-OF-FILE
           PERFORM 9000-FINALIZE
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           OPEN INPUT COVENANT-FILE
           IF WS-COV-STATUS NOT = '00'
               DISPLAY 'COVENANT FILE ERROR: ' WS-COV-STATUS
               STOP RUN
           END-IF
           PERFORM 1100-READ-COVENANT.
       1100-READ-COVENANT.
           READ COVENANT-FILE
               AT END SET END-OF-FILE TO TRUE
           END-READ.
       2000-PROCESS-COVENANTS.
           ADD 1 TO WS-TOTAL-CHECKED
           MOVE ZERO TO WS-VIOLATION-CT
           INITIALIZE WS-VIOLATION-TABLE
           PERFORM 3000-TEST-DSCR
           PERFORM 3100-TEST-LEVERAGE
           PERFORM 3200-TEST-CURRENT-RATIO
           PERFORM 3300-TEST-TNW
           EVALUATE TRUE
               WHEN WS-VIOLATION-CT = 0
                   ADD 1 TO WS-COMPLIANT-CNT
               WHEN WS-VIOLATION-CT > 0 AND
                    CV-CURE-DAYS > 0
                   ADD 1 TO WS-CURE-CNT
                   PERFORM 4000-SEND-CURE-NOTICE
               WHEN WS-VIOLATION-CT > 0 AND
                    CV-CURE-DAYS = 0
                   ADD 1 TO WS-DEFAULT-CNT
                   PERFORM 5000-SEND-DEFAULT-NOTICE
           END-EVALUATE
           ADD WS-VIOLATION-CT TO WS-VIOLATION-CNT
           PERFORM 1100-READ-COVENANT.
       3000-TEST-DSCR.
           IF CV-DEBT-SERVICE > ZERO
               COMPUTE WS-ACTUAL-DSCR ROUNDED =
                   CV-NET-INCOME / CV-DEBT-SERVICE
           ELSE
               MOVE 999.99 TO WS-ACTUAL-DSCR
           END-IF
           IF WS-ACTUAL-DSCR < CV-REQ-DSCR
               ADD 1 TO WS-VIOLATION-CT
               MOVE 'DSCR' TO VE-TYPE(WS-VIOLATION-CT)
               MOVE CV-REQ-DSCR TO
                   VE-REQUIRED(WS-VIOLATION-CT)
               MOVE WS-ACTUAL-DSCR TO
                   VE-ACTUAL(WS-VIOLATION-CT)
               IF WS-ACTUAL-DSCR < 1.00
                   MOVE 'H' TO
                       VE-SEVERITY(WS-VIOLATION-CT)
               ELSE
                   MOVE 'M' TO
                       VE-SEVERITY(WS-VIOLATION-CT)
               END-IF
           END-IF.
       3100-TEST-LEVERAGE.
           IF CV-TOTAL-EQUITY > ZERO
               COMPUTE WS-ACTUAL-LEVERAGE ROUNDED =
                   CV-TOTAL-DEBT / CV-TOTAL-EQUITY
           ELSE
               MOVE 999.99 TO WS-ACTUAL-LEVERAGE
           END-IF
           IF WS-ACTUAL-LEVERAGE > CV-REQ-LEVERAGE
               ADD 1 TO WS-VIOLATION-CT
               MOVE 'LEVERAGE' TO
                   VE-TYPE(WS-VIOLATION-CT)
               MOVE CV-REQ-LEVERAGE TO
                   VE-REQUIRED(WS-VIOLATION-CT)
               MOVE WS-ACTUAL-LEVERAGE TO
                   VE-ACTUAL(WS-VIOLATION-CT)
               MOVE 'M' TO
                   VE-SEVERITY(WS-VIOLATION-CT)
           END-IF.
       3200-TEST-CURRENT-RATIO.
           IF CV-CURRENT-LIAB > ZERO
               COMPUTE WS-ACTUAL-CURRENT ROUNDED =
                   CV-CURRENT-ASSETS / CV-CURRENT-LIAB
           ELSE
               MOVE 999.99 TO WS-ACTUAL-CURRENT
           END-IF
           IF WS-ACTUAL-CURRENT < CV-REQ-CURRENT
               ADD 1 TO WS-VIOLATION-CT
               MOVE 'CURRENT RATIO' TO
                   VE-TYPE(WS-VIOLATION-CT)
               MOVE CV-REQ-CURRENT TO
                   VE-REQUIRED(WS-VIOLATION-CT)
               MOVE WS-ACTUAL-CURRENT TO
                   VE-ACTUAL(WS-VIOLATION-CT)
               MOVE 'L' TO
                   VE-SEVERITY(WS-VIOLATION-CT)
           END-IF.
       3300-TEST-TNW.
           IF CV-TANG-NET-WORTH < CV-REQ-TNW
               ADD 1 TO WS-VIOLATION-CT
               MOVE 'TANGIBLE NW' TO
                   VE-TYPE(WS-VIOLATION-CT)
               MOVE CV-REQ-TNW TO
                   VE-REQUIRED(WS-VIOLATION-CT)
               MOVE CV-TANG-NET-WORTH TO
                   VE-ACTUAL(WS-VIOLATION-CT)
               MOVE 'H' TO
                   VE-SEVERITY(WS-VIOLATION-CT)
           END-IF.
       4000-SEND-CURE-NOTICE.
           MOVE SPACES TO WS-NOTICE-LINE
           STRING 'CURE NOTICE: '
               DELIMITED BY SIZE
               CV-LOAN-NUM
               DELIMITED BY SIZE
               ' VIOLATIONS='
               DELIMITED BY SIZE
               INTO WS-NOTICE-LINE
           DISPLAY WS-NOTICE-LINE
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-VIOLATION-CT
               DISPLAY '  ' VE-TYPE(WS-IDX)
                   ' REQ=' VE-REQUIRED(WS-IDX)
                   ' ACT=' VE-ACTUAL(WS-IDX)
           END-PERFORM.
       5000-SEND-DEFAULT-NOTICE.
           MOVE SPACES TO WS-NOTICE-LINE
           STRING 'DEFAULT: '
               DELIMITED BY SIZE
               CV-LOAN-NUM
               DELIMITED BY SIZE
               ' BORROWER='
               DELIMITED BY SIZE
               CV-BORROWER
               DELIMITED BY SIZE
               INTO WS-NOTICE-LINE
           DISPLAY WS-NOTICE-LINE.
       9000-FINALIZE.
           CLOSE COVENANT-FILE
           DISPLAY 'COVENANT COMPLIANCE CHECK COMPLETE'
           DISPLAY 'CHECKED:    ' WS-TOTAL-CHECKED
           DISPLAY 'COMPLIANT:  ' WS-COMPLIANT-CNT
           DISPLAY 'VIOLATIONS: ' WS-VIOLATION-CNT
           DISPLAY 'CURE PERIOD:' WS-CURE-CNT
           DISPLAY 'DEFAULTS:   ' WS-DEFAULT-CNT.
