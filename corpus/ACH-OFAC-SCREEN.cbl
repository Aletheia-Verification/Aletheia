       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACH-OFAC-SCREEN.
      *================================================================*
      * ACH OFAC Screening Engine                                       *
      * Screens ACH originations against SDN list using name matching,  *
      * generates alerts, applies dispositions, and logs results.       *
      *================================================================*
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ACH-FILE ASSIGN TO 'ACHSCREEN.DAT'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-ACH-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD  ACH-FILE.
       01  ACH-RECORD.
           05  AR-TRACE-NUM        PIC X(15).
           05  AR-ORIG-NAME        PIC X(30).
           05  AR-RECV-NAME        PIC X(30).
           05  AR-AMOUNT           PIC 9(10)V99.
           05  AR-ORIG-COUNTRY     PIC X(02).
           05  AR-RECV-COUNTRY     PIC X(02).
       WORKING-STORAGE SECTION.
       01  WS-ACH-STATUS          PIC XX VALUE SPACES.
       01  WS-EOF                 PIC X VALUE 'N'.
           88  END-OF-FILE        VALUE 'Y'.
       01  WS-SDN-TABLE.
           05  WS-SDN-ENTRY       OCCURS 20 TIMES.
               10  SDN-NAME       PIC X(30).
               10  SDN-COUNTRY    PIC X(02).
               10  SDN-TYPE       PIC X(01).
       01  WS-SDN-COUNT           PIC 9(02) VALUE 10.
       01  WS-SDN-IDX             PIC 9(02).
       01  WS-ACH-CNT             PIC 9(08) VALUE 0.
       01  WS-MATCH-CNT           PIC 9(06) VALUE 0.
       01  WS-CLEAR-CNT           PIC 9(08) VALUE 0.
       01  WS-HOLD-CNT            PIC 9(06) VALUE 0.
       01  WS-MATCH-SCORE         PIC 9(03).
       01  WS-BEST-SCORE          PIC 9(03).
       01  WS-BEST-IDX            PIC 9(02).
       01  WS-THRESHOLD           PIC 9(03) VALUE 70.
       01  WS-DISPOSITION         PIC X(10).
       01  WS-ORIG-TALLY          PIC 9(03).
       01  WS-SDN-TALLY           PIC 9(03).
       01  WS-COMMON-TALLY        PIC 9(03).
       01  WS-ORIG-UPPER          PIC X(30).
       01  WS-SDN-UPPER           PIC X(30).
       01  WS-TOTAL-HELD-AMT      PIC S9(13)V99 VALUE 0.
       01  WS-MSG                 PIC X(100) VALUE SPACES.
       01  WS-CHAR-IDX            PIC 9(02).
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PROCESS-ENTRIES UNTIL END-OF-FILE
           PERFORM 9000-FINALIZE
           STOP RUN.
       1000-INITIALIZE.
           PERFORM 1200-LOAD-SDN
           OPEN INPUT ACH-FILE
           IF WS-ACH-STATUS NOT = '00'
               DISPLAY 'ACH FILE ERROR: ' WS-ACH-STATUS
               STOP RUN
           END-IF
           PERFORM 1100-READ-ACH.
       1100-READ-ACH.
           READ ACH-FILE
               AT END SET END-OF-FILE TO TRUE
           END-READ.
       1200-LOAD-SDN.
           MOVE 'SANCTIONED ENTITY A       ' TO SDN-NAME(1)
           MOVE 'IR' TO SDN-COUNTRY(1)
           MOVE 'E' TO SDN-TYPE(1)
           MOVE 'BLOCKED PERSON B          ' TO SDN-NAME(2)
           MOVE 'KP' TO SDN-COUNTRY(2)
           MOVE 'I' TO SDN-TYPE(2)
           MOVE 'PROHIBITED CORP C         ' TO SDN-NAME(3)
           MOVE 'SY' TO SDN-COUNTRY(3)
           MOVE 'E' TO SDN-TYPE(3)
           MOVE 'RESTRICTED BANK D         ' TO SDN-NAME(4)
           MOVE 'CU' TO SDN-COUNTRY(4)
           MOVE 'E' TO SDN-TYPE(4)
           MOVE 'SDN INDIVIDUAL E          ' TO SDN-NAME(5)
           MOVE 'RU' TO SDN-COUNTRY(5)
           MOVE 'I' TO SDN-TYPE(5)
           MOVE 'DESIGNATED FIRM F         ' TO SDN-NAME(6)
           MOVE 'IR' TO SDN-COUNTRY(6)
           MOVE 'E' TO SDN-TYPE(6)
           MOVE 'BLOCKED ENTITY G          ' TO SDN-NAME(7)
           MOVE 'VE' TO SDN-COUNTRY(7)
           MOVE 'E' TO SDN-TYPE(7)
           MOVE 'SANCTIONED PERSON H       ' TO SDN-NAME(8)
           MOVE 'BY' TO SDN-COUNTRY(8)
           MOVE 'I' TO SDN-TYPE(8)
           MOVE 'PROHIBITED TRADER I       ' TO SDN-NAME(9)
           MOVE 'MM' TO SDN-COUNTRY(9)
           MOVE 'I' TO SDN-TYPE(9)
           MOVE 'SDN COMPANY J             ' TO SDN-NAME(10)
           MOVE 'CN' TO SDN-COUNTRY(10)
           MOVE 'E' TO SDN-TYPE(10).
       2000-PROCESS-ENTRIES.
           ADD 1 TO WS-ACH-CNT
           MOVE 0 TO WS-BEST-SCORE
           MOVE 0 TO WS-BEST-IDX
           PERFORM 3000-SCREEN-ORIGINATOR
           PERFORM 4000-SCREEN-RECEIVER
           PERFORM 5000-APPLY-DISPOSITION
           PERFORM 1100-READ-ACH.
       3000-SCREEN-ORIGINATOR.
           MOVE AR-ORIG-NAME TO WS-ORIG-UPPER
           PERFORM VARYING WS-SDN-IDX FROM 1 BY 1
               UNTIL WS-SDN-IDX > WS-SDN-COUNT
               PERFORM 3500-CALC-MATCH-SCORE
               IF WS-MATCH-SCORE > WS-BEST-SCORE
                   MOVE WS-MATCH-SCORE TO WS-BEST-SCORE
                   MOVE WS-SDN-IDX TO WS-BEST-IDX
               END-IF
           END-PERFORM.
       3500-CALC-MATCH-SCORE.
           MOVE ZERO TO WS-ORIG-TALLY
           MOVE ZERO TO WS-SDN-TALLY
           MOVE SDN-NAME(WS-SDN-IDX) TO WS-SDN-UPPER
           INSPECT WS-ORIG-UPPER
               TALLYING WS-ORIG-TALLY
               FOR ALL SPACES
           INSPECT WS-SDN-UPPER
               TALLYING WS-SDN-TALLY
               FOR ALL SPACES
           COMPUTE WS-COMMON-TALLY =
               30 - WS-ORIG-TALLY
           IF WS-COMMON-TALLY > 0
               COMPUTE WS-MATCH-SCORE =
                   WS-COMMON-TALLY * 100 / 30
           ELSE
               MOVE 0 TO WS-MATCH-SCORE
           END-IF
           IF AR-ORIG-COUNTRY = SDN-COUNTRY(WS-SDN-IDX)
               ADD 20 TO WS-MATCH-SCORE
           END-IF
           IF WS-MATCH-SCORE > 100
               MOVE 100 TO WS-MATCH-SCORE
           END-IF.
       4000-SCREEN-RECEIVER.
           MOVE AR-RECV-NAME TO WS-ORIG-UPPER
           PERFORM VARYING WS-SDN-IDX FROM 1 BY 1
               UNTIL WS-SDN-IDX > WS-SDN-COUNT
               PERFORM 3500-CALC-MATCH-SCORE
               IF WS-MATCH-SCORE > WS-BEST-SCORE
                   MOVE WS-MATCH-SCORE TO WS-BEST-SCORE
                   MOVE WS-SDN-IDX TO WS-BEST-IDX
               END-IF
           END-PERFORM.
       5000-APPLY-DISPOSITION.
           EVALUATE TRUE
               WHEN WS-BEST-SCORE >= 90
                   MOVE 'BLOCK' TO WS-DISPOSITION
                   ADD 1 TO WS-HOLD-CNT
                   ADD AR-AMOUNT TO WS-TOTAL-HELD-AMT
                   MOVE SPACES TO WS-MSG
                   STRING 'BLOCKED TRC='
                       DELIMITED BY SIZE
                       AR-TRACE-NUM
                       DELIMITED BY SIZE
                       ' MATCH='
                       DELIMITED BY SIZE
                       SDN-NAME(WS-BEST-IDX)
                       DELIMITED BY SIZE
                       INTO WS-MSG
                   DISPLAY WS-MSG
               WHEN WS-BEST-SCORE >= WS-THRESHOLD
                   MOVE 'REVIEW' TO WS-DISPOSITION
                   ADD 1 TO WS-MATCH-CNT
               WHEN OTHER
                   MOVE 'CLEAR' TO WS-DISPOSITION
                   ADD 1 TO WS-CLEAR-CNT
           END-EVALUATE.
       9000-FINALIZE.
           CLOSE ACH-FILE
           DISPLAY 'OFAC SCREENING COMPLETE'
           DISPLAY 'TOTAL SCREENED: ' WS-ACH-CNT
           DISPLAY 'CLEARED:        ' WS-CLEAR-CNT
           DISPLAY 'REVIEW:         ' WS-MATCH-CNT
           DISPLAY 'BLOCKED:        ' WS-HOLD-CNT
           DISPLAY 'HELD AMOUNT:    ' WS-TOTAL-HELD-AMT.
