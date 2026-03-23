       IDENTIFICATION DIVISION.
       PROGRAM-ID. TRUST-DISTRIB-CALC.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT TRUST-FILE ASSIGN TO 'TRUSTIN'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-TRUST-STATUS.
           SELECT DIST-FILE ASSIGN TO 'DISTOUT'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-DIST-STATUS.

       DATA DIVISION.
       FILE SECTION.

       FD TRUST-FILE.
       01 TRUST-RECORD.
           05 TR-TRUST-ID             PIC X(12).
           05 TR-BENE-ID              PIC X(10).
           05 TR-BENE-NAME            PIC X(30).
           05 TR-DIST-TYPE            PIC X(1).
               88 TR-MANDATORY        VALUE 'M'.
               88 TR-DISCRETIONARY    VALUE 'D'.
               88 TR-INCOME-ONLY      VALUE 'I'.
           05 TR-SHARE-PCT            PIC S9(3)V99 COMP-3.
           05 TR-TRUST-BALANCE        PIC S9(13)V99 COMP-3.
           05 TR-INCOME-EARNED        PIC S9(11)V99 COMP-3.
           05 TR-TAX-RATE             PIC S9(2)V99 COMP-3.
           05 TR-ANNUAL-LIMIT         PIC S9(11)V99 COMP-3.

       FD DIST-FILE.
       01 DIST-RECORD.
           05 DS-TRUST-ID             PIC X(12).
           05 DS-BENE-ID              PIC X(10).
           05 DS-GROSS-DIST           PIC S9(11)V99 COMP-3.
           05 DS-TAX-WITHHELD         PIC S9(9)V99 COMP-3.
           05 DS-NET-DIST             PIC S9(11)V99 COMP-3.
           05 DS-DIST-TYPE            PIC X(12).
           05 DS-REASON               PIC X(40).

       WORKING-STORAGE SECTION.

       01 WS-TRUST-STATUS             PIC X(2).
       01 WS-DIST-STATUS              PIC X(2).
       01 WS-EOF-FLAG                 PIC X VALUE 'N'.
           88 WS-EOF                   VALUE 'Y'.

       01 WS-GROSS-AMOUNT             PIC S9(11)V99 COMP-3.
       01 WS-TAX-AMOUNT               PIC S9(9)V99 COMP-3.
       01 WS-NET-AMOUNT               PIC S9(11)V99 COMP-3.

       01 WS-MIN-DIST                 PIC S9(11)V99 COMP-3
           VALUE 100.00.

       01 WS-COUNTERS.
           05 WS-TOTAL-READ           PIC S9(7) COMP-3 VALUE 0.
           05 WS-DIST-COUNT           PIC S9(7) COMP-3 VALUE 0.
           05 WS-SKIP-COUNT           PIC S9(7) COMP-3 VALUE 0.

       01 WS-TOTALS.
           05 WS-TOT-GROSS            PIC S9(13)V99 COMP-3
               VALUE 0.
           05 WS-TOT-TAX              PIC S9(11)V99 COMP-3
               VALUE 0.
           05 WS-TOT-NET              PIC S9(13)V99 COMP-3
               VALUE 0.

       01 WS-REASON-BUF               PIC X(40).
       01 WS-REASON-PTR               PIC 9(3).
       01 WS-ALPHA-TALLY              PIC 9(3).

       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-OPEN-FILES
           PERFORM 1100-READ-FIRST
           PERFORM 2000-PROCESS-BENEFICIARY
               UNTIL WS-EOF
           PERFORM 3000-CLOSE-FILES
           PERFORM 4000-DISPLAY-SUMMARY
           STOP RUN.

       1000-OPEN-FILES.
           OPEN INPUT TRUST-FILE
           OPEN OUTPUT DIST-FILE
           MOVE 'N' TO WS-EOF-FLAG.

       1100-READ-FIRST.
           READ TRUST-FILE
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ.

       2000-PROCESS-BENEFICIARY.
           ADD 1 TO WS-TOTAL-READ
           MOVE 0 TO WS-GROSS-AMOUNT
           MOVE 0 TO WS-TAX-AMOUNT
           MOVE 0 TO WS-NET-AMOUNT
           MOVE SPACES TO WS-REASON-BUF
           MOVE 1 TO WS-REASON-PTR
           EVALUATE TRUE
               WHEN TR-MANDATORY
                   COMPUTE WS-GROSS-AMOUNT =
                       TR-TRUST-BALANCE *
                       (TR-SHARE-PCT / 100)
                   IF WS-GROSS-AMOUNT > TR-ANNUAL-LIMIT
                       AND TR-ANNUAL-LIMIT > 0
                       MOVE TR-ANNUAL-LIMIT TO
                           WS-GROSS-AMOUNT
                       STRING 'CAPPED AT ANNUAL LIMIT'
                           DELIMITED BY SIZE
                           INTO WS-REASON-BUF
                           WITH POINTER WS-REASON-PTR
                       END-STRING
                   ELSE
                       STRING 'MANDATORY DISTRIBUTION'
                           DELIMITED BY SIZE
                           INTO WS-REASON-BUF
                           WITH POINTER WS-REASON-PTR
                       END-STRING
                   END-IF
                   MOVE 'MANDATORY   ' TO DS-DIST-TYPE
               WHEN TR-INCOME-ONLY
                   COMPUTE WS-GROSS-AMOUNT =
                       TR-INCOME-EARNED *
                       (TR-SHARE-PCT / 100)
                   STRING 'INCOME DISTRIBUTION'
                       DELIMITED BY SIZE
                       INTO WS-REASON-BUF
                       WITH POINTER WS-REASON-PTR
                   END-STRING
                   MOVE 'INCOME      ' TO DS-DIST-TYPE
               WHEN TR-DISCRETIONARY
                   COMPUTE WS-GROSS-AMOUNT =
                       TR-INCOME-EARNED *
                       (TR-SHARE-PCT / 100)
                   IF WS-GROSS-AMOUNT > TR-ANNUAL-LIMIT
                       AND TR-ANNUAL-LIMIT > 0
                       MOVE TR-ANNUAL-LIMIT TO
                           WS-GROSS-AMOUNT
                   END-IF
                   STRING 'DISCRETIONARY DIST'
                       DELIMITED BY SIZE
                       INTO WS-REASON-BUF
                       WITH POINTER WS-REASON-PTR
                   END-STRING
                   MOVE 'DISCRETION  ' TO DS-DIST-TYPE
               WHEN OTHER
                   STRING 'UNKNOWN DIST TYPE'
                       DELIMITED BY SIZE
                       INTO WS-REASON-BUF
                       WITH POINTER WS-REASON-PTR
                   END-STRING
                   MOVE 'UNKNOWN     ' TO DS-DIST-TYPE
           END-EVALUATE
           IF WS-GROSS-AMOUNT >= WS-MIN-DIST
               PERFORM 2100-CALC-TAX
               PERFORM 2200-WRITE-DISTRIBUTION
           ELSE
               ADD 1 TO WS-SKIP-COUNT
           END-IF
           READ TRUST-FILE
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ.

       2100-CALC-TAX.
           COMPUTE WS-TAX-AMOUNT =
               WS-GROSS-AMOUNT * (TR-TAX-RATE / 100)
           COMPUTE WS-NET-AMOUNT =
               WS-GROSS-AMOUNT - WS-TAX-AMOUNT.

       2200-WRITE-DISTRIBUTION.
           MOVE TR-TRUST-ID TO DS-TRUST-ID
           MOVE TR-BENE-ID TO DS-BENE-ID
           MOVE WS-GROSS-AMOUNT TO DS-GROSS-DIST
           MOVE WS-TAX-AMOUNT TO DS-TAX-WITHHELD
           MOVE WS-NET-AMOUNT TO DS-NET-DIST
           MOVE WS-REASON-BUF TO DS-REASON
           WRITE DIST-RECORD
           ADD 1 TO WS-DIST-COUNT
           ADD WS-GROSS-AMOUNT TO WS-TOT-GROSS
           ADD WS-TAX-AMOUNT TO WS-TOT-TAX
           ADD WS-NET-AMOUNT TO WS-TOT-NET.

       3000-CLOSE-FILES.
           CLOSE TRUST-FILE
           CLOSE DIST-FILE.

       4000-DISPLAY-SUMMARY.
           MOVE 0 TO WS-ALPHA-TALLY
           INSPECT WS-REASON-BUF
               TALLYING WS-ALPHA-TALLY FOR ALL 'A'
           DISPLAY 'TRUST DISTRIBUTION COMPLETE'
           DISPLAY 'RECORDS READ:       ' WS-TOTAL-READ
           DISPLAY 'DISTRIBUTIONS:      ' WS-DIST-COUNT
           DISPLAY 'SKIPPED (MIN):      ' WS-SKIP-COUNT
           DISPLAY 'TOTAL GROSS:        ' WS-TOT-GROSS
           DISPLAY 'TOTAL TAX:          ' WS-TOT-TAX
           DISPLAY 'TOTAL NET:          ' WS-TOT-NET.
