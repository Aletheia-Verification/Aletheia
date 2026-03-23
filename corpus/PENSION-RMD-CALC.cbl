       IDENTIFICATION DIVISION.
       PROGRAM-ID. PENSION-RMD-CALC.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ACCT-FILE ASSIGN TO 'RMDACCTS'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-ACCT-STATUS.
           SELECT RMD-FILE ASSIGN TO 'RMDOUT'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-RMD-STATUS.

       DATA DIVISION.
       FILE SECTION.

       FD ACCT-FILE.
       01 ACCT-RECORD.
           05 AR-ACCT-ID              PIC X(12).
           05 AR-PARTICIPANT-NAME     PIC X(30).
           05 AR-DOB                  PIC 9(8).
           05 AR-AGE                  PIC 9(3).
           05 AR-YE-BALANCE           PIC S9(13)V99 COMP-3.
           05 AR-PLAN-TYPE            PIC X(2).
               88 AR-TRAD-IRA         VALUE 'TI'.
               88 AR-SEP-IRA          VALUE 'SI'.
               88 AR-SIMPLE-IRA       VALUE 'SM'.
               88 AR-PLAN-401K        VALUE '4K'.
               88 AR-ROTH-IRA         VALUE 'RI'.
           05 AR-PRIOR-RMD-TAKEN      PIC S9(11)V99 COMP-3.
           05 AR-BENEFICIARY-AGE      PIC 9(3).

       FD RMD-FILE.
       01 RMD-RECORD.
           05 RMD-ACCT-ID             PIC X(12).
           05 RMD-PARTICIPANT         PIC X(30).
           05 RMD-YE-BALANCE          PIC S9(13)V99 COMP-3.
           05 RMD-LIFE-EXPECT         PIC S9(3)V9 COMP-3.
           05 RMD-AMOUNT              PIC S9(11)V99 COMP-3.
           05 RMD-REMAINING           PIC S9(11)V99 COMP-3.
           05 RMD-STATUS              PIC X(10).

       WORKING-STORAGE SECTION.

       01 WS-ACCT-STATUS              PIC X(2).
       01 WS-RMD-STATUS               PIC X(2).
       01 WS-EOF-FLAG                 PIC X VALUE 'N'.
           88 WS-EOF                   VALUE 'Y'.

       01 WS-LIFE-TABLE.
           05 WS-LIFE OCCURS 10.
               10 WS-LT-AGE           PIC 9(3).
               10 WS-LT-FACTOR        PIC S9(3)V9 COMP-3.
       01 WS-LIFE-COUNT               PIC 9(2) VALUE 10.
       01 WS-LIFE-IDX                 PIC 9(2).

       01 WS-CALC.
           05 WS-DIST-PERIOD          PIC S9(3)V9 COMP-3.
           05 WS-RMD-AMOUNT           PIC S9(11)V99 COMP-3.
           05 WS-REMAINING            PIC S9(11)V99 COMP-3.

       01 WS-COUNTERS.
           05 WS-TOTAL-READ           PIC S9(7) COMP-3 VALUE 0.
           05 WS-RMD-REQUIRED         PIC S9(7) COMP-3 VALUE 0.
           05 WS-EXEMPT-COUNT         PIC S9(7) COMP-3 VALUE 0.
           05 WS-SHORTFALL-COUNT      PIC S9(7) COMP-3 VALUE 0.

       01 WS-TOTAL-RMD                PIC S9(15)V99 COMP-3
           VALUE 0.
       01 WS-AGE-TALLY                PIC 9(3).

       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INIT-LIFE-TABLE
           PERFORM 1100-OPEN-FILES
           PERFORM 1200-READ-FIRST
           PERFORM 2000-PROCESS-ACCOUNT
               UNTIL WS-EOF
           PERFORM 3000-CLOSE-FILES
           PERFORM 4000-DISPLAY-SUMMARY
           STOP RUN.

       1000-INIT-LIFE-TABLE.
           MOVE 72 TO WS-LT-AGE(1)
           MOVE 27.4 TO WS-LT-FACTOR(1)
           MOVE 73 TO WS-LT-AGE(2)
           MOVE 26.5 TO WS-LT-FACTOR(2)
           MOVE 74 TO WS-LT-AGE(3)
           MOVE 25.5 TO WS-LT-FACTOR(3)
           MOVE 75 TO WS-LT-AGE(4)
           MOVE 24.6 TO WS-LT-FACTOR(4)
           MOVE 76 TO WS-LT-AGE(5)
           MOVE 23.7 TO WS-LT-FACTOR(5)
           MOVE 77 TO WS-LT-AGE(6)
           MOVE 22.9 TO WS-LT-FACTOR(6)
           MOVE 78 TO WS-LT-AGE(7)
           MOVE 22.0 TO WS-LT-FACTOR(7)
           MOVE 79 TO WS-LT-AGE(8)
           MOVE 21.1 TO WS-LT-FACTOR(8)
           MOVE 80 TO WS-LT-AGE(9)
           MOVE 20.2 TO WS-LT-FACTOR(9)
           MOVE 81 TO WS-LT-AGE(10)
           MOVE 19.4 TO WS-LT-FACTOR(10)
           MOVE 'N' TO WS-EOF-FLAG.

       1100-OPEN-FILES.
           OPEN INPUT ACCT-FILE
           OPEN OUTPUT RMD-FILE.

       1200-READ-FIRST.
           READ ACCT-FILE
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ.

       2000-PROCESS-ACCOUNT.
           ADD 1 TO WS-TOTAL-READ
           IF AR-ROTH-IRA
               ADD 1 TO WS-EXEMPT-COUNT
               MOVE AR-ACCT-ID TO RMD-ACCT-ID
               MOVE AR-PARTICIPANT-NAME TO RMD-PARTICIPANT
               MOVE AR-YE-BALANCE TO RMD-YE-BALANCE
               MOVE 0 TO RMD-LIFE-EXPECT
               MOVE 0 TO RMD-AMOUNT
               MOVE 0 TO RMD-REMAINING
               MOVE 'ROTH-EXMPT' TO RMD-STATUS
               WRITE RMD-RECORD
           ELSE
               IF AR-AGE >= 72
                   PERFORM 2100-LOOKUP-LIFE-EXPECT
                   PERFORM 2200-CALCULATE-RMD
                   PERFORM 2300-WRITE-RMD-RECORD
               ELSE
                   ADD 1 TO WS-EXEMPT-COUNT
               END-IF
           END-IF
           READ ACCT-FILE
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ.

       2100-LOOKUP-LIFE-EXPECT.
           MOVE 20.0 TO WS-DIST-PERIOD
           PERFORM VARYING WS-LIFE-IDX FROM 1 BY 1
               UNTIL WS-LIFE-IDX > WS-LIFE-COUNT
               IF AR-AGE = WS-LT-AGE(WS-LIFE-IDX)
                   MOVE WS-LT-FACTOR(WS-LIFE-IDX)
                       TO WS-DIST-PERIOD
               END-IF
           END-PERFORM
           IF AR-AGE > 81
               COMPUTE WS-DIST-PERIOD =
                   19.4 - ((AR-AGE - 81) * 0.9)
               IF WS-DIST-PERIOD < 1.0
                   MOVE 1.0 TO WS-DIST-PERIOD
               END-IF
           END-IF.

       2200-CALCULATE-RMD.
           ADD 1 TO WS-RMD-REQUIRED
           COMPUTE WS-RMD-AMOUNT =
               AR-YE-BALANCE / WS-DIST-PERIOD
           COMPUTE WS-REMAINING =
               WS-RMD-AMOUNT - AR-PRIOR-RMD-TAKEN
           IF WS-REMAINING < 0
               MOVE 0 TO WS-REMAINING
           END-IF
           IF AR-PRIOR-RMD-TAKEN < WS-RMD-AMOUNT
               ADD 1 TO WS-SHORTFALL-COUNT
           END-IF
           ADD WS-RMD-AMOUNT TO WS-TOTAL-RMD.

       2300-WRITE-RMD-RECORD.
           MOVE AR-ACCT-ID TO RMD-ACCT-ID
           MOVE AR-PARTICIPANT-NAME TO RMD-PARTICIPANT
           MOVE AR-YE-BALANCE TO RMD-YE-BALANCE
           MOVE WS-DIST-PERIOD TO RMD-LIFE-EXPECT
           MOVE WS-RMD-AMOUNT TO RMD-AMOUNT
           MOVE WS-REMAINING TO RMD-REMAINING
           IF WS-REMAINING > 0
               MOVE 'RMD-DUE   ' TO RMD-STATUS
           ELSE
               MOVE 'RMD-MET   ' TO RMD-STATUS
           END-IF
           WRITE RMD-RECORD.

       3000-CLOSE-FILES.
           CLOSE ACCT-FILE
           CLOSE RMD-FILE.

       4000-DISPLAY-SUMMARY.
           MOVE 0 TO WS-AGE-TALLY
           INSPECT AR-PARTICIPANT-NAME
               TALLYING WS-AGE-TALLY FOR ALL ' '
           DISPLAY 'REQUIRED MINIMUM DISTRIBUTION CALC'
           DISPLAY 'ACCOUNTS READ:     ' WS-TOTAL-READ
           DISPLAY 'RMD REQUIRED:      ' WS-RMD-REQUIRED
           DISPLAY 'EXEMPT:            ' WS-EXEMPT-COUNT
           DISPLAY 'SHORTFALL:         ' WS-SHORTFALL-COUNT
           DISPLAY 'TOTAL RMD AMOUNT:  ' WS-TOTAL-RMD.
