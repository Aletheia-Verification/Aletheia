       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-ODO-CUSTODY-STMT.
      *---------------------------------------------------------------
      * MANUAL REVIEW: Contains OCCURS DEPENDING ON for variable-
      * length custody statement generation.
      *---------------------------------------------------------------

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT STMT-FILE ASSIGN TO 'STMTOUT'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-STMT-STATUS.

       DATA DIVISION.
       FILE SECTION.

       FD STMT-FILE.
       01 STMT-RECORD                 PIC X(200).

       WORKING-STORAGE SECTION.

       01 WS-STMT-STATUS              PIC X(2).

       01 WS-ACCT-HEADER.
           05 WS-ACCT-ID              PIC X(12).
           05 WS-ACCT-NAME            PIC X(35).
           05 WS-STMT-DATE            PIC 9(8).
           05 WS-STMT-PERIOD          PIC X(7).
           05 WS-TOTAL-HOLDINGS       PIC 9(3).

       01 WS-HOLDING-COUNT            PIC 9(3) VALUE 0.

       01 WS-CUSTODY-HOLDINGS.
           05 WS-NUM-HOLDINGS         PIC 9(3).
           05 WS-HOLDING OCCURS 1 TO 100
               DEPENDING ON WS-NUM-HOLDINGS.
               10 WS-HL-CUSIP         PIC X(9).
               10 WS-HL-DESC          PIC X(25).
               10 WS-HL-SHARES        PIC S9(9)V99 COMP-3.
               10 WS-HL-PRICE         PIC S9(7)V9(4) COMP-3.
               10 WS-HL-MKT-VALUE     PIC S9(13)V99 COMP-3.
               10 WS-HL-ASSET-TYPE    PIC X(2).
                   88 WS-HL-EQUITY    VALUE 'EQ'.
                   88 WS-HL-BOND      VALUE 'BD'.
                   88 WS-HL-CASH      VALUE 'CA'.
                   88 WS-HL-FUND      VALUE 'MF'.

       01 WS-TOTALS.
           05 WS-TOT-MARKET           PIC S9(15)V99 COMP-3
               VALUE 0.
           05 WS-TOT-EQUITY           PIC S9(15)V99 COMP-3
               VALUE 0.
           05 WS-TOT-BONDS            PIC S9(15)V99 COMP-3
               VALUE 0.
           05 WS-TOT-CASH             PIC S9(15)V99 COMP-3
               VALUE 0.
           05 WS-TOT-OTHER            PIC S9(15)V99 COMP-3
               VALUE 0.

       01 WS-HOLD-IDX                 PIC 9(3).
       01 WS-LINE-BUF                 PIC X(200).
       01 WS-LINE-PTR                 PIC 9(3).

       01 WS-EQUITY-PCT               PIC S9(3)V99 COMP-3.
       01 WS-BOND-PCT                 PIC S9(3)V99 COMP-3.
       01 WS-CASH-PCT                 PIC S9(3)V99 COMP-3.

       01 WS-CUSIP-TALLY              PIC 9(3).

       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 1100-OPEN-FILES
           PERFORM 2000-CALC-MARKET-VALUES
           PERFORM 3000-WRITE-HEADER
           PERFORM 4000-WRITE-DETAILS
           PERFORM 5000-WRITE-SUMMARY
           PERFORM 6000-CLOSE-FILES
           PERFORM 7000-DISPLAY-RESULTS
           STOP RUN.

       1000-INITIALIZE.
           MOVE 0 TO WS-TOT-MARKET
           MOVE 0 TO WS-TOT-EQUITY
           MOVE 0 TO WS-TOT-BONDS
           MOVE 0 TO WS-TOT-CASH
           MOVE 0 TO WS-TOT-OTHER
           ACCEPT WS-STMT-DATE FROM DATE YYYYMMDD.

       1100-OPEN-FILES.
           OPEN OUTPUT STMT-FILE.

       2000-CALC-MARKET-VALUES.
           PERFORM VARYING WS-HOLD-IDX FROM 1 BY 1
               UNTIL WS-HOLD-IDX > WS-NUM-HOLDINGS
               COMPUTE WS-HL-MKT-VALUE(WS-HOLD-IDX) =
                   WS-HL-SHARES(WS-HOLD-IDX) *
                   WS-HL-PRICE(WS-HOLD-IDX)
               ADD WS-HL-MKT-VALUE(WS-HOLD-IDX)
                   TO WS-TOT-MARKET
               EVALUATE TRUE
                   WHEN WS-HL-EQUITY(WS-HOLD-IDX)
                       ADD WS-HL-MKT-VALUE(WS-HOLD-IDX)
                           TO WS-TOT-EQUITY
                   WHEN WS-HL-BOND(WS-HOLD-IDX)
                       ADD WS-HL-MKT-VALUE(WS-HOLD-IDX)
                           TO WS-TOT-BONDS
                   WHEN WS-HL-CASH(WS-HOLD-IDX)
                       ADD WS-HL-MKT-VALUE(WS-HOLD-IDX)
                           TO WS-TOT-CASH
                   WHEN OTHER
                       ADD WS-HL-MKT-VALUE(WS-HOLD-IDX)
                           TO WS-TOT-OTHER
               END-EVALUATE
           END-PERFORM.

       3000-WRITE-HEADER.
           MOVE SPACES TO WS-LINE-BUF
           MOVE 1 TO WS-LINE-PTR
           STRING 'CUSTODY STATEMENT - '
               WS-ACCT-NAME ' - ' WS-STMT-DATE
               DELIMITED BY SIZE
               INTO WS-LINE-BUF
               WITH POINTER WS-LINE-PTR
           END-STRING
           MOVE WS-LINE-BUF TO STMT-RECORD
           WRITE STMT-RECORD
           MOVE SPACES TO STMT-RECORD
           WRITE STMT-RECORD.

       4000-WRITE-DETAILS.
           PERFORM VARYING WS-HOLD-IDX FROM 1 BY 1
               UNTIL WS-HOLD-IDX > WS-NUM-HOLDINGS
               MOVE SPACES TO WS-LINE-BUF
               MOVE 1 TO WS-LINE-PTR
               STRING WS-HL-CUSIP(WS-HOLD-IDX) ' '
                   WS-HL-DESC(WS-HOLD-IDX) ' '
                   WS-HL-ASSET-TYPE(WS-HOLD-IDX)
                   DELIMITED BY SIZE
                   INTO WS-LINE-BUF
                   WITH POINTER WS-LINE-PTR
               END-STRING
               MOVE 0 TO WS-CUSIP-TALLY
               INSPECT WS-HL-CUSIP(WS-HOLD-IDX)
                   TALLYING WS-CUSIP-TALLY FOR ALL '0'
               MOVE WS-LINE-BUF TO STMT-RECORD
               WRITE STMT-RECORD
           END-PERFORM.

       5000-WRITE-SUMMARY.
           IF WS-TOT-MARKET > 0
               COMPUTE WS-EQUITY-PCT =
                   (WS-TOT-EQUITY / WS-TOT-MARKET) * 100
               COMPUTE WS-BOND-PCT =
                   (WS-TOT-BONDS / WS-TOT-MARKET) * 100
               COMPUTE WS-CASH-PCT =
                   (WS-TOT-CASH / WS-TOT-MARKET) * 100
           ELSE
               MOVE 0 TO WS-EQUITY-PCT
               MOVE 0 TO WS-BOND-PCT
               MOVE 0 TO WS-CASH-PCT
           END-IF
           MOVE SPACES TO WS-LINE-BUF
           MOVE 1 TO WS-LINE-PTR
           STRING 'TOTAL MARKET VALUE: '
               DELIMITED BY SIZE
               INTO WS-LINE-BUF
               WITH POINTER WS-LINE-PTR
           END-STRING
           MOVE WS-LINE-BUF TO STMT-RECORD
           WRITE STMT-RECORD.

       6000-CLOSE-FILES.
           CLOSE STMT-FILE.

       7000-DISPLAY-RESULTS.
           DISPLAY 'CUSTODY STATEMENT GENERATED'
           DISPLAY 'ACCOUNT:    ' WS-ACCT-ID
           DISPLAY 'HOLDINGS:   ' WS-NUM-HOLDINGS
           DISPLAY 'TOTAL MKT:  ' WS-TOT-MARKET
           DISPLAY 'EQUITY %:   ' WS-EQUITY-PCT
           DISPLAY 'BOND %:     ' WS-BOND-PCT
           DISPLAY 'CASH %:     ' WS-CASH-PCT.
