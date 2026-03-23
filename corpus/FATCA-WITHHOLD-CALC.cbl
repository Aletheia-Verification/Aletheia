       IDENTIFICATION DIVISION.
       PROGRAM-ID. FATCA-WITHHOLD-CALC.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT INCOME-FILE ASSIGN TO 'INCOMEIN'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-INC-STATUS.
           SELECT WITHHOLD-FILE ASSIGN TO 'WHOUT'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-WH-STATUS.

       DATA DIVISION.
       FILE SECTION.

       FD INCOME-FILE.
       01 INCOME-RECORD.
           05 INC-ACCT-ID             PIC X(12).
           05 INC-PAYEE-NAME          PIC X(35).
           05 INC-INCOME-TYPE         PIC X(2).
               88 INC-DIVIDEND        VALUE 'DV'.
               88 INC-INTEREST        VALUE 'IN'.
               88 INC-ROYALTY         VALUE 'RY'.
               88 INC-RENTAL          VALUE 'RN'.
               88 INC-CAPITAL-GAIN    VALUE 'CG'.
           05 INC-GROSS-AMOUNT        PIC S9(11)V99 COMP-3.
           05 INC-COUNTRY             PIC X(3).
           05 INC-TREATY-RATE         PIC S9(2)V99 COMP-3.
           05 INC-W8-ON-FILE          PIC X VALUE 'N'.
               88 INC-HAS-W8          VALUE 'Y'.
           05 INC-PAYEE-TYPE          PIC X(1).
               88 INC-INDIVIDUAL      VALUE 'I'.
               88 INC-ENTITY          VALUE 'E'.
               88 INC-EXEMPT          VALUE 'X'.

       FD WITHHOLD-FILE.
       01 WH-RECORD.
           05 WH-ACCT-ID              PIC X(12).
           05 WH-INCOME-TYPE          PIC X(2).
           05 WH-GROSS-AMT            PIC S9(11)V99 COMP-3.
           05 WH-RATE-APPLIED         PIC S9(2)V99 COMP-3.
           05 WH-TAX-WITHHELD         PIC S9(9)V99 COMP-3.
           05 WH-NET-AMT              PIC S9(11)V99 COMP-3.
           05 WH-STATUS               PIC X(12).
           05 WH-REASON               PIC X(40).

       WORKING-STORAGE SECTION.

       01 WS-INC-STATUS               PIC X(2).
       01 WS-WH-STATUS                PIC X(2).
       01 WS-EOF-FLAG                 PIC X VALUE 'N'.
           88 WS-EOF                   VALUE 'Y'.

       01 WS-DEFAULT-RATE             PIC S9(2)V99 COMP-3
           VALUE 30.00.
       01 WS-APPLIED-RATE             PIC S9(2)V99 COMP-3.
       01 WS-TAX-AMT                  PIC S9(9)V99 COMP-3.
       01 WS-NET-AMT                  PIC S9(11)V99 COMP-3.

       01 WS-TREATY-COUNTRIES.
           05 WS-TREATY OCCURS 8.
               10 WS-TR-COUNTRY       PIC X(3).
               10 WS-TR-DIV-RATE      PIC S9(2)V99 COMP-3.
               10 WS-TR-INT-RATE      PIC S9(2)V99 COMP-3.
       01 WS-TREATY-COUNT             PIC 9(1) VALUE 8.
       01 WS-TREATY-IDX               PIC 9(1).
       01 WS-TREATY-FOUND             PIC X VALUE 'N'.
           88 WS-HAS-TREATY           VALUE 'Y'.

       01 WS-REASON-BUF               PIC X(40).
       01 WS-REASON-PTR               PIC 9(3).

       01 WS-COUNTERS.
           05 WS-TOTAL-PAYMENTS       PIC S9(7) COMP-3 VALUE 0.
           05 WS-WITHHOLDING-CNT      PIC S9(7) COMP-3 VALUE 0.
           05 WS-EXEMPT-CNT           PIC S9(7) COMP-3 VALUE 0.
           05 WS-TREATY-REDUCED       PIC S9(7) COMP-3 VALUE 0.

       01 WS-TOTALS.
           05 WS-TOT-GROSS            PIC S9(13)V99 COMP-3
               VALUE 0.
           05 WS-TOT-TAX              PIC S9(11)V99 COMP-3
               VALUE 0.
           05 WS-TOT-NET              PIC S9(13)V99 COMP-3
               VALUE 0.

       01 WS-TALLY-WORK               PIC 9(3).

       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INIT-TREATIES
           PERFORM 1100-OPEN-FILES
           PERFORM 1200-READ-FIRST
           PERFORM 2000-PROCESS-INCOME
               UNTIL WS-EOF
           PERFORM 3000-CLOSE-FILES
           PERFORM 4000-DISPLAY-SUMMARY
           STOP RUN.

       1000-INIT-TREATIES.
           MOVE 'GBR' TO WS-TR-COUNTRY(1)
           MOVE 15.00 TO WS-TR-DIV-RATE(1)
           MOVE 0 TO WS-TR-INT-RATE(1)
           MOVE 'CAN' TO WS-TR-COUNTRY(2)
           MOVE 15.00 TO WS-TR-DIV-RATE(2)
           MOVE 0 TO WS-TR-INT-RATE(2)
           MOVE 'DEU' TO WS-TR-COUNTRY(3)
           MOVE 15.00 TO WS-TR-DIV-RATE(3)
           MOVE 0 TO WS-TR-INT-RATE(3)
           MOVE 'JPN' TO WS-TR-COUNTRY(4)
           MOVE 10.00 TO WS-TR-DIV-RATE(4)
           MOVE 10.00 TO WS-TR-INT-RATE(4)
           MOVE 'AUS' TO WS-TR-COUNTRY(5)
           MOVE 15.00 TO WS-TR-DIV-RATE(5)
           MOVE 10.00 TO WS-TR-INT-RATE(5)
           MOVE 'FRA' TO WS-TR-COUNTRY(6)
           MOVE 15.00 TO WS-TR-DIV-RATE(6)
           MOVE 0 TO WS-TR-INT-RATE(6)
           MOVE 'CHE' TO WS-TR-COUNTRY(7)
           MOVE 15.00 TO WS-TR-DIV-RATE(7)
           MOVE 0 TO WS-TR-INT-RATE(7)
           MOVE 'NLD' TO WS-TR-COUNTRY(8)
           MOVE 15.00 TO WS-TR-DIV-RATE(8)
           MOVE 0 TO WS-TR-INT-RATE(8)
           MOVE 'N' TO WS-EOF-FLAG.

       1100-OPEN-FILES.
           OPEN INPUT INCOME-FILE
           OPEN OUTPUT WITHHOLD-FILE.

       1200-READ-FIRST.
           READ INCOME-FILE
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ.

       2000-PROCESS-INCOME.
           ADD 1 TO WS-TOTAL-PAYMENTS
           MOVE SPACES TO WS-REASON-BUF
           MOVE 1 TO WS-REASON-PTR
           IF INC-EXEMPT
               MOVE 0 TO WS-APPLIED-RATE
               MOVE 0 TO WS-TAX-AMT
               MOVE INC-GROSS-AMOUNT TO WS-NET-AMT
               ADD 1 TO WS-EXEMPT-CNT
               STRING 'EXEMPT ENTITY'
                   DELIMITED BY SIZE
                   INTO WS-REASON-BUF
                   WITH POINTER WS-REASON-PTR
               END-STRING
               MOVE 'EXEMPT      ' TO WH-STATUS
           ELSE
               PERFORM 2100-DETERMINE-RATE
               COMPUTE WS-TAX-AMT =
                   INC-GROSS-AMOUNT *
                   (WS-APPLIED-RATE / 100)
               COMPUTE WS-NET-AMT =
                   INC-GROSS-AMOUNT - WS-TAX-AMT
               ADD 1 TO WS-WITHHOLDING-CNT
               IF WS-APPLIED-RATE < WS-DEFAULT-RATE
                   MOVE 'TREATY-RATE ' TO WH-STATUS
               ELSE
                   MOVE 'STANDARD    ' TO WH-STATUS
               END-IF
           END-IF
           PERFORM 2200-WRITE-RECORD
           READ INCOME-FILE
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ.

       2100-DETERMINE-RATE.
           MOVE WS-DEFAULT-RATE TO WS-APPLIED-RATE
           IF INC-HAS-W8
               MOVE 'N' TO WS-TREATY-FOUND
               PERFORM VARYING WS-TREATY-IDX FROM 1 BY 1
                   UNTIL WS-TREATY-IDX > WS-TREATY-COUNT
                   OR WS-HAS-TREATY
                   IF INC-COUNTRY =
                       WS-TR-COUNTRY(WS-TREATY-IDX)
                       MOVE 'Y' TO WS-TREATY-FOUND
                       EVALUATE TRUE
                           WHEN INC-DIVIDEND
                               MOVE WS-TR-DIV-RATE(
                                   WS-TREATY-IDX)
                                   TO WS-APPLIED-RATE
                           WHEN INC-INTEREST
                               MOVE WS-TR-INT-RATE(
                                   WS-TREATY-IDX)
                                   TO WS-APPLIED-RATE
                           WHEN OTHER
                               MOVE WS-DEFAULT-RATE TO
                                   WS-APPLIED-RATE
                       END-EVALUATE
                       ADD 1 TO WS-TREATY-REDUCED
                       STRING 'TREATY WITH '
                           INC-COUNTRY
                           DELIMITED BY SIZE
                           INTO WS-REASON-BUF
                           WITH POINTER WS-REASON-PTR
                       END-STRING
                   END-IF
               END-PERFORM
               IF NOT WS-HAS-TREATY
                   STRING 'NO TREATY - DEFAULT RATE'
                       DELIMITED BY SIZE
                       INTO WS-REASON-BUF
                       WITH POINTER WS-REASON-PTR
                   END-STRING
               END-IF
           ELSE
               STRING 'NO W-8 - DEFAULT 30%'
                   DELIMITED BY SIZE
                   INTO WS-REASON-BUF
                   WITH POINTER WS-REASON-PTR
               END-STRING
           END-IF.

       2200-WRITE-RECORD.
           MOVE INC-ACCT-ID TO WH-ACCT-ID
           MOVE INC-INCOME-TYPE TO WH-INCOME-TYPE
           MOVE INC-GROSS-AMOUNT TO WH-GROSS-AMT
           MOVE WS-APPLIED-RATE TO WH-RATE-APPLIED
           MOVE WS-TAX-AMT TO WH-TAX-WITHHELD
           MOVE WS-NET-AMT TO WH-NET-AMT
           MOVE WS-REASON-BUF TO WH-REASON
           WRITE WH-RECORD
           ADD INC-GROSS-AMOUNT TO WS-TOT-GROSS
           ADD WS-TAX-AMT TO WS-TOT-TAX
           ADD WS-NET-AMT TO WS-TOT-NET.

       3000-CLOSE-FILES.
           CLOSE INCOME-FILE
           CLOSE WITHHOLD-FILE.

       4000-DISPLAY-SUMMARY.
           MOVE 0 TO WS-TALLY-WORK
           INSPECT WS-REASON-BUF
               TALLYING WS-TALLY-WORK FOR ALL 'T'
           DISPLAY 'FATCA WITHHOLDING COMPLETE'
           DISPLAY 'PAYMENTS PROCESSED: ' WS-TOTAL-PAYMENTS
           DISPLAY 'WITHHELD:           ' WS-WITHHOLDING-CNT
           DISPLAY 'EXEMPT:             ' WS-EXEMPT-CNT
           DISPLAY 'TREATY REDUCED:     ' WS-TREATY-REDUCED
           DISPLAY 'TOTAL GROSS:        ' WS-TOT-GROSS
           DISPLAY 'TOTAL TAX:          ' WS-TOT-TAX
           DISPLAY 'TOTAL NET:          ' WS-TOT-NET.
