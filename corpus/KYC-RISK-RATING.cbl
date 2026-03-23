       IDENTIFICATION DIVISION.
       PROGRAM-ID. KYC-RISK-RATING.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT CUST-FILE ASSIGN TO 'CUSTFILE'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-CUST-STATUS.
           SELECT RATING-FILE ASSIGN TO 'RATEOUT'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-RATE-STATUS.

       DATA DIVISION.
       FILE SECTION.

       FD CUST-FILE.
       01 CUST-RECORD.
           05 CR-CUST-ID              PIC X(12).
           05 CR-CUST-TYPE            PIC X(2).
               88 CR-INDIVIDUAL       VALUE 'IN'.
               88 CR-CORPORATE        VALUE 'CO'.
               88 CR-TRUST            VALUE 'TR'.
               88 CR-CHARITY          VALUE 'CH'.
           05 CR-COUNTRY              PIC X(3).
           05 CR-INDUSTRY             PIC X(4).
           05 CR-ANNUAL-REVENUE       PIC S9(13)V99 COMP-3.
           05 CR-YEARS-RELATION       PIC 9(2).
           05 CR-PRODUCTS-USED        PIC 9(2).
           05 CR-PEP-FLAG             PIC X VALUE 'N'.
               88 CR-IS-PEP           VALUE 'Y'.
           05 CR-ADVERSE-MEDIA        PIC X VALUE 'N'.
               88 CR-HAS-ADVERSE      VALUE 'Y'.
           05 CR-SAR-HISTORY          PIC 9(2).

       FD RATING-FILE.
       01 RATING-RECORD.
           05 RR-CUST-ID              PIC X(12).
           05 RR-RISK-SCORE           PIC S9(3) COMP-3.
           05 RR-RISK-LEVEL           PIC X(6).
           05 RR-REVIEW-FREQ          PIC X(8).
           05 RR-EDD-REQUIRED         PIC X VALUE 'N'.
           05 RR-FACTORS              PIC X(60).

       WORKING-STORAGE SECTION.

       01 WS-CUST-STATUS              PIC X(2).
       01 WS-RATE-STATUS              PIC X(2).
       01 WS-EOF-FLAG                 PIC X VALUE 'N'.
           88 WS-EOF                   VALUE 'Y'.

       01 WS-RISK-SCORE               PIC S9(3) COMP-3.

       01 WS-HIGH-RISK-COUNTRIES.
           05 WS-HR OCCURS 8          PIC X(3).
       01 WS-HR-USED                  PIC 9(1) VALUE 8.
       01 WS-HR-IDX                   PIC 9(1).
       01 WS-HR-MATCH                 PIC X VALUE 'N'.
           88 WS-IS-HR-COUNTRY        VALUE 'Y'.

       01 WS-HIGH-RISK-INDUSTRIES.
           05 WS-HRI OCCURS 5         PIC X(4).
       01 WS-HRI-USED                 PIC 9(1) VALUE 5.
       01 WS-HRI-IDX                  PIC 9(1).
       01 WS-HRI-MATCH                PIC X VALUE 'N'.
           88 WS-IS-HRI               VALUE 'Y'.

       01 WS-FACTOR-BUF               PIC X(60).
       01 WS-FACTOR-PTR               PIC 9(3).

       01 WS-COUNTERS.
           05 WS-TOTAL-RATED          PIC S9(7) COMP-3 VALUE 0.
           05 WS-HIGH-COUNT           PIC S9(7) COMP-3 VALUE 0.
           05 WS-MEDIUM-COUNT         PIC S9(7) COMP-3 VALUE 0.
           05 WS-LOW-COUNT            PIC S9(7) COMP-3 VALUE 0.
           05 WS-EDD-COUNT            PIC S9(7) COMP-3 VALUE 0.

       01 WS-DIGIT-TALLY              PIC 9(3).

       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INIT-LISTS
           PERFORM 1100-OPEN-FILES
           PERFORM 1200-READ-FIRST
           PERFORM 2000-RATE-CUSTOMER
               UNTIL WS-EOF
           PERFORM 3000-CLOSE-FILES
           PERFORM 4000-DISPLAY-SUMMARY
           STOP RUN.

       1000-INIT-LISTS.
           MOVE 'IRN' TO WS-HR(1)
           MOVE 'PRK' TO WS-HR(2)
           MOVE 'SYR' TO WS-HR(3)
           MOVE 'CUB' TO WS-HR(4)
           MOVE 'MMR' TO WS-HR(5)
           MOVE 'VEN' TO WS-HR(6)
           MOVE 'LBY' TO WS-HR(7)
           MOVE 'SDN' TO WS-HR(8)
           MOVE 'GAMB' TO WS-HRI(1)
           MOVE 'ARMS' TO WS-HRI(2)
           MOVE 'PREC' TO WS-HRI(3)
           MOVE 'CRYP' TO WS-HRI(4)
           MOVE 'CASH' TO WS-HRI(5)
           MOVE 'N' TO WS-EOF-FLAG.

       1100-OPEN-FILES.
           OPEN INPUT CUST-FILE
           OPEN OUTPUT RATING-FILE.

       1200-READ-FIRST.
           READ CUST-FILE
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ.

       2000-RATE-CUSTOMER.
           ADD 1 TO WS-TOTAL-RATED
           MOVE 0 TO WS-RISK-SCORE
           MOVE SPACES TO WS-FACTOR-BUF
           MOVE 1 TO WS-FACTOR-PTR
           PERFORM 2100-CHECK-COUNTRY
           PERFORM 2200-CHECK-INDUSTRY
           PERFORM 2300-CHECK-ENTITY-TYPE
           PERFORM 2400-CHECK-PEP-ADVERSE
           PERFORM 2500-CHECK-SAR-HISTORY
           PERFORM 2600-CHECK-RELATIONSHIP
           PERFORM 2700-ASSIGN-LEVEL
           MOVE CR-CUST-ID TO RR-CUST-ID
           MOVE WS-RISK-SCORE TO RR-RISK-SCORE
           MOVE WS-FACTOR-BUF TO RR-FACTORS
           WRITE RATING-RECORD
           READ CUST-FILE
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ.

       2100-CHECK-COUNTRY.
           MOVE 'N' TO WS-HR-MATCH
           PERFORM VARYING WS-HR-IDX FROM 1 BY 1
               UNTIL WS-HR-IDX > WS-HR-USED
               OR WS-IS-HR-COUNTRY
               IF CR-COUNTRY = WS-HR(WS-HR-IDX)
                   MOVE 'Y' TO WS-HR-MATCH
               END-IF
           END-PERFORM
           IF WS-IS-HR-COUNTRY
               ADD 30 TO WS-RISK-SCORE
               STRING 'HR-CTY '
                   DELIMITED BY SIZE
                   INTO WS-FACTOR-BUF
                   WITH POINTER WS-FACTOR-PTR
               END-STRING
           END-IF.

       2200-CHECK-INDUSTRY.
           MOVE 'N' TO WS-HRI-MATCH
           PERFORM VARYING WS-HRI-IDX FROM 1 BY 1
               UNTIL WS-HRI-IDX > WS-HRI-USED
               OR WS-IS-HRI
               IF CR-INDUSTRY = WS-HRI(WS-HRI-IDX)
                   MOVE 'Y' TO WS-HRI-MATCH
               END-IF
           END-PERFORM
           IF WS-IS-HRI
               ADD 20 TO WS-RISK-SCORE
               STRING 'HR-IND '
                   DELIMITED BY SIZE
                   INTO WS-FACTOR-BUF
                   WITH POINTER WS-FACTOR-PTR
               END-STRING
           END-IF.

       2300-CHECK-ENTITY-TYPE.
           EVALUATE TRUE
               WHEN CR-CORPORATE
                   ADD 5 TO WS-RISK-SCORE
               WHEN CR-TRUST
                   ADD 15 TO WS-RISK-SCORE
                   STRING 'TRUST '
                       DELIMITED BY SIZE
                       INTO WS-FACTOR-BUF
                       WITH POINTER WS-FACTOR-PTR
                   END-STRING
               WHEN CR-CHARITY
                   ADD 10 TO WS-RISK-SCORE
               WHEN CR-INDIVIDUAL
                   CONTINUE
               WHEN OTHER
                   ADD 5 TO WS-RISK-SCORE
           END-EVALUATE.

       2400-CHECK-PEP-ADVERSE.
           IF CR-IS-PEP
               ADD 25 TO WS-RISK-SCORE
               STRING 'PEP '
                   DELIMITED BY SIZE
                   INTO WS-FACTOR-BUF
                   WITH POINTER WS-FACTOR-PTR
               END-STRING
           END-IF
           IF CR-HAS-ADVERSE
               ADD 20 TO WS-RISK-SCORE
               STRING 'ADV-MEDIA '
                   DELIMITED BY SIZE
                   INTO WS-FACTOR-BUF
                   WITH POINTER WS-FACTOR-PTR
               END-STRING
           END-IF.

       2500-CHECK-SAR-HISTORY.
           IF CR-SAR-HISTORY > 0
               COMPUTE WS-RISK-SCORE =
                   WS-RISK-SCORE +
                   (CR-SAR-HISTORY * 15)
               STRING 'SAR-HIST '
                   DELIMITED BY SIZE
                   INTO WS-FACTOR-BUF
                   WITH POINTER WS-FACTOR-PTR
               END-STRING
           END-IF.

       2600-CHECK-RELATIONSHIP.
           IF CR-YEARS-RELATION >= 10
               SUBTRACT 10 FROM WS-RISK-SCORE
           ELSE
               IF CR-YEARS-RELATION < 2
                   ADD 10 TO WS-RISK-SCORE
                   STRING 'NEW-REL '
                       DELIMITED BY SIZE
                       INTO WS-FACTOR-BUF
                       WITH POINTER WS-FACTOR-PTR
                   END-STRING
               END-IF
           END-IF
           IF WS-RISK-SCORE < 0
               MOVE 0 TO WS-RISK-SCORE
           END-IF.

       2700-ASSIGN-LEVEL.
           EVALUATE TRUE
               WHEN WS-RISK-SCORE >= 70
                   MOVE 'HIGH  ' TO RR-RISK-LEVEL
                   MOVE 'ANNUAL  ' TO RR-REVIEW-FREQ
                   MOVE 'Y' TO RR-EDD-REQUIRED
                   ADD 1 TO WS-HIGH-COUNT
                   ADD 1 TO WS-EDD-COUNT
               WHEN WS-RISK-SCORE >= 40
                   MOVE 'MEDIUM' TO RR-RISK-LEVEL
                   MOVE 'BIANNUAL' TO RR-REVIEW-FREQ
                   MOVE 'N' TO RR-EDD-REQUIRED
                   ADD 1 TO WS-MEDIUM-COUNT
               WHEN OTHER
                   MOVE 'LOW   ' TO RR-RISK-LEVEL
                   MOVE 'TRIANNUL' TO RR-REVIEW-FREQ
                   MOVE 'N' TO RR-EDD-REQUIRED
                   ADD 1 TO WS-LOW-COUNT
           END-EVALUATE.

       3000-CLOSE-FILES.
           CLOSE CUST-FILE
           CLOSE RATING-FILE.

       4000-DISPLAY-SUMMARY.
           MOVE 0 TO WS-DIGIT-TALLY
           INSPECT WS-FACTOR-BUF
               TALLYING WS-DIGIT-TALLY FOR ALL '-'
           DISPLAY 'KYC RISK RATING COMPLETE'
           DISPLAY 'CUSTOMERS RATED:  ' WS-TOTAL-RATED
           DISPLAY 'HIGH RISK:        ' WS-HIGH-COUNT
           DISPLAY 'MEDIUM RISK:      ' WS-MEDIUM-COUNT
           DISPLAY 'LOW RISK:         ' WS-LOW-COUNT
           DISPLAY 'EDD REQUIRED:     ' WS-EDD-COUNT.
