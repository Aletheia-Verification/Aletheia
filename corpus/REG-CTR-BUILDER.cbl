       IDENTIFICATION DIVISION.
       PROGRAM-ID. REG-CTR-BUILDER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-TXN-DATA.
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-CUST-NAME           PIC X(30).
           05 WS-CUST-SSN            PIC X(9).
           05 WS-TXN-AMOUNT          PIC S9(9)V99 COMP-3.
           05 WS-TXN-TYPE            PIC X(2).
           05 WS-TXN-DATE            PIC 9(8).
       01 WS-CTR-THRESHOLD           PIC S9(7)V99 COMP-3
           VALUE 10000.00.
       01 WS-CTR-FIELDS.
           05 WS-CTR-REQUIRED        PIC X VALUE 'N'.
               88 WS-NEEDS-CTR       VALUE 'Y'.
           05 WS-CTR-TYPE            PIC X(1).
               88 WS-CASH-IN         VALUE 'I'.
               88 WS-CASH-OUT        VALUE 'O'.
               88 WS-BOTH            VALUE 'B'.
           05 WS-AGGREGATE-AMT       PIC S9(9)V99 COMP-3.
       01 WS-CTR-RECORD              PIC X(80).
       01 WS-PARSED-SSN.
           05 WS-SSN-PART1           PIC X(3).
           05 WS-SSN-PART2           PIC X(2).
           05 WS-SSN-PART3           PIC X(4).
       01 WS-FORMATTED-SSN           PIC X(11).
       01 WS-EXEMPT-FLAG             PIC X VALUE 'N'.
           88 WS-IS-EXEMPT           VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CHECK-THRESHOLD
           PERFORM 3000-CHECK-EXEMPTION
           IF WS-NEEDS-CTR
               PERFORM 4000-FORMAT-SSN
               PERFORM 5000-BUILD-CTR-RECORD
           END-IF
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'N' TO WS-CTR-REQUIRED
           MOVE 'N' TO WS-EXEMPT-FLAG
           MOVE 0 TO WS-AGGREGATE-AMT.
       2000-CHECK-THRESHOLD.
           IF WS-TXN-AMOUNT > WS-CTR-THRESHOLD
               MOVE 'Y' TO WS-CTR-REQUIRED
               EVALUATE WS-TXN-TYPE
                   WHEN 'CI'
                       SET WS-CASH-IN TO TRUE
                   WHEN 'CO'
                       SET WS-CASH-OUT TO TRUE
                   WHEN OTHER
                       SET WS-BOTH TO TRUE
               END-EVALUATE
           END-IF
           ADD WS-TXN-AMOUNT TO WS-AGGREGATE-AMT
           IF WS-AGGREGATE-AMT > WS-CTR-THRESHOLD
               MOVE 'Y' TO WS-CTR-REQUIRED
           END-IF.
       3000-CHECK-EXEMPTION.
           IF WS-IS-EXEMPT
               MOVE 'N' TO WS-CTR-REQUIRED
               DISPLAY 'CTR EXEMPT'
           END-IF.
       4000-FORMAT-SSN.
           UNSTRING WS-CUST-SSN
               DELIMITED BY SIZE
               INTO WS-SSN-PART1
                    WS-SSN-PART2
                    WS-SSN-PART3
           END-UNSTRING
           STRING WS-SSN-PART1 DELIMITED BY SIZE
                  '-' DELIMITED BY SIZE
                  WS-SSN-PART2 DELIMITED BY SIZE
                  '-' DELIMITED BY SIZE
                  WS-SSN-PART3 DELIMITED BY SIZE
                  INTO WS-FORMATTED-SSN
           END-STRING.
       5000-BUILD-CTR-RECORD.
           STRING 'CTR|' DELIMITED BY SIZE
                  WS-ACCT-NUM DELIMITED BY SIZE
                  '|' DELIMITED BY SIZE
                  WS-CUST-NAME DELIMITED BY '  '
                  '|' DELIMITED BY SIZE
                  WS-TXN-AMOUNT DELIMITED BY SIZE
                  '|' DELIMITED BY SIZE
                  WS-TXN-DATE DELIMITED BY SIZE
                  INTO WS-CTR-RECORD
           END-STRING.
       6000-DISPLAY-RESULTS.
           DISPLAY 'CTR BUILDER'
           DISPLAY '==========='
           DISPLAY 'ACCOUNT:      ' WS-ACCT-NUM
           DISPLAY 'CUSTOMER:     ' WS-CUST-NAME
           DISPLAY 'AMOUNT:       ' WS-TXN-AMOUNT
           DISPLAY 'AGGREGATE:    ' WS-AGGREGATE-AMT
           IF WS-NEEDS-CTR
               DISPLAY 'CTR: REQUIRED'
               DISPLAY 'RECORD: ' WS-CTR-RECORD
           ELSE
               DISPLAY 'CTR: NOT REQUIRED'
           END-IF.
