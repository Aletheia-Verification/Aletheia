       IDENTIFICATION DIVISION.
       PROGRAM-ID. SANCTION-SCREEN.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT CUSTOMER-FILE ASSIGN TO 'CUSTFILE'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-CUST-STATUS.
           SELECT ALERT-FILE ASSIGN TO 'ALERTOUT'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-ALERT-STATUS.

       DATA DIVISION.
       FILE SECTION.

       FD CUSTOMER-FILE.
       01 CUST-RECORD.
           05 CST-ID                   PIC X(12).
           05 CST-FIRST-NAME           PIC X(25).
           05 CST-LAST-NAME            PIC X(25).
           05 CST-COUNTRY              PIC X(3).
           05 CST-DOB                  PIC 9(8).
           05 CST-PASSPORT-NUM         PIC X(12).
           05 CST-RISK-RATING          PIC X(1).
               88 CST-LOW-RISK         VALUE 'L'.
               88 CST-MEDIUM-RISK      VALUE 'M'.
               88 CST-HIGH-RISK        VALUE 'H'.

       FD ALERT-FILE.
       01 ALERT-RECORD.
           05 ALT-CUST-ID             PIC X(12).
           05 ALT-NAME-MATCHED        PIC X(50).
           05 ALT-LIST-CODE           PIC X(4).
           05 ALT-MATCH-SCORE         PIC 9(3).
           05 ALT-ACTION-CODE         PIC X(2).
               88 ALT-BLOCK           VALUE 'BL'.
               88 ALT-REVIEW          VALUE 'RV'.
               88 ALT-PASS            VALUE 'OK'.
           05 ALT-REASON              PIC X(60).

       WORKING-STORAGE SECTION.

       01 WS-CUST-STATUS              PIC X(2).
       01 WS-ALERT-STATUS             PIC X(2).

       01 WS-EOF-FLAG                 PIC X VALUE 'N'.
           88 WS-EOF                   VALUE 'Y'.

       01 WS-SANCTION-LIST.
           05 WS-SDN OCCURS 15.
               10 WS-SDN-LAST         PIC X(25).
               10 WS-SDN-FIRST        PIC X(25).
               10 WS-SDN-COUNTRY      PIC X(3).
               10 WS-SDN-LIST-CODE    PIC X(4).
       01 WS-SDN-COUNT                PIC 9(2) VALUE 0.
       01 WS-SDN-IDX                  PIC 9(2).

       01 WS-MATCH-WORK.
           05 WS-BEST-SCORE           PIC 9(3) VALUE 0.
           05 WS-BEST-IDX             PIC 9(2) VALUE 0.
           05 WS-CURR-SCORE           PIC 9(3) VALUE 0.
           05 WS-NAME-MATCH-FLAG      PIC X VALUE 'N'.
               88 WS-NAME-HIT         VALUE 'Y'.
           05 WS-COUNTRY-MATCH-FLAG   PIC X VALUE 'N'.
               88 WS-COUNTRY-HIT      VALUE 'Y'.

       01 WS-NORMALIZED-LAST          PIC X(25).
       01 WS-NORMALIZED-FIRST         PIC X(25).
       01 WS-TALLY-CHARS              PIC 9(3).
       01 WS-THRESHOLD                PIC 9(3) VALUE 060.

       01 WS-COUNTERS.
           05 WS-SCREENED              PIC S9(7) COMP-3 VALUE 0.
           05 WS-BLOCKED               PIC S9(7) COMP-3 VALUE 0.
           05 WS-REVIEWED              PIC S9(7) COMP-3 VALUE 0.
           05 WS-PASSED                PIC S9(7) COMP-3 VALUE 0.

       01 WS-REASON-BUF               PIC X(60).
       01 WS-REASON-PTR               PIC 9(3).

       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-LOAD-SANCTIONS
           PERFORM 1100-OPEN-FILES
           PERFORM 1200-READ-FIRST
           PERFORM 2000-SCREEN-CUSTOMER
               UNTIL WS-EOF
           PERFORM 3000-CLOSE-FILES
           PERFORM 4000-DISPLAY-SUMMARY
           STOP RUN.

       1000-LOAD-SANCTIONS.
           MOVE 3 TO WS-SDN-COUNT
           MOVE 'SMITH' TO WS-SDN-LAST(1)
           MOVE 'JOHN' TO WS-SDN-FIRST(1)
           MOVE 'IRN' TO WS-SDN-COUNTRY(1)
           MOVE 'OFAC' TO WS-SDN-LIST-CODE(1)
           MOVE 'JONES' TO WS-SDN-LAST(2)
           MOVE 'ALICE' TO WS-SDN-FIRST(2)
           MOVE 'PRK' TO WS-SDN-COUNTRY(2)
           MOVE 'EU  ' TO WS-SDN-LIST-CODE(2)
           MOVE 'CHEN' TO WS-SDN-LAST(3)
           MOVE 'WEI' TO WS-SDN-FIRST(3)
           MOVE 'SYR' TO WS-SDN-COUNTRY(3)
           MOVE 'UN  ' TO WS-SDN-LIST-CODE(3).

       1100-OPEN-FILES.
           OPEN INPUT CUSTOMER-FILE
           OPEN OUTPUT ALERT-FILE.

       1200-READ-FIRST.
           READ CUSTOMER-FILE
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ.

       2000-SCREEN-CUSTOMER.
           ADD 1 TO WS-SCREENED
           MOVE 0 TO WS-BEST-SCORE
           MOVE 0 TO WS-BEST-IDX
           PERFORM 2100-NORMALIZE-NAMES
           PERFORM VARYING WS-SDN-IDX FROM 1 BY 1
               UNTIL WS-SDN-IDX > WS-SDN-COUNT
               MOVE 0 TO WS-CURR-SCORE
               MOVE 'N' TO WS-NAME-MATCH-FLAG
               MOVE 'N' TO WS-COUNTRY-MATCH-FLAG
               IF WS-NORMALIZED-LAST = WS-SDN-LAST(WS-SDN-IDX)
                   ADD 50 TO WS-CURR-SCORE
                   MOVE 'Y' TO WS-NAME-MATCH-FLAG
               ELSE
                   MOVE 0 TO WS-TALLY-CHARS
                   INSPECT WS-SDN-LAST(WS-SDN-IDX)
                       TALLYING WS-TALLY-CHARS
                       FOR ALL WS-NORMALIZED-LAST
                   IF WS-TALLY-CHARS > 0
                       ADD 30 TO WS-CURR-SCORE
                   END-IF
               END-IF
               IF WS-NORMALIZED-FIRST =
                   WS-SDN-FIRST(WS-SDN-IDX)
                   ADD 30 TO WS-CURR-SCORE
               END-IF
               IF CST-COUNTRY = WS-SDN-COUNTRY(WS-SDN-IDX)
                   ADD 20 TO WS-CURR-SCORE
                   MOVE 'Y' TO WS-COUNTRY-MATCH-FLAG
               END-IF
               IF WS-CURR-SCORE > WS-BEST-SCORE
                   MOVE WS-CURR-SCORE TO WS-BEST-SCORE
                   MOVE WS-SDN-IDX TO WS-BEST-IDX
               END-IF
           END-PERFORM
           PERFORM 2200-DETERMINE-ACTION
           PERFORM 2300-WRITE-ALERT
           READ CUSTOMER-FILE
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ.

       2100-NORMALIZE-NAMES.
           MOVE CST-LAST-NAME TO WS-NORMALIZED-LAST
           MOVE CST-FIRST-NAME TO WS-NORMALIZED-FIRST
           INSPECT WS-NORMALIZED-LAST
               REPLACING ALL '-' BY ' '.

       2200-DETERMINE-ACTION.
           MOVE CST-ID TO ALT-CUST-ID
           MOVE WS-BEST-SCORE TO ALT-MATCH-SCORE
           MOVE SPACES TO WS-REASON-BUF
           MOVE 1 TO WS-REASON-PTR
           IF WS-BEST-SCORE >= 80
               MOVE 'BL' TO ALT-ACTION-CODE
               ADD 1 TO WS-BLOCKED
               IF WS-BEST-IDX > 0
                   MOVE WS-SDN-LIST-CODE(WS-BEST-IDX)
                       TO ALT-LIST-CODE
                   STRING 'EXACT MATCH ON '
                       WS-SDN-LIST-CODE(WS-BEST-IDX)
                       ' LIST'
                       DELIMITED BY SIZE
                       INTO WS-REASON-BUF
                       WITH POINTER WS-REASON-PTR
                   END-STRING
               END-IF
           ELSE
               IF WS-BEST-SCORE >= WS-THRESHOLD
                   MOVE 'RV' TO ALT-ACTION-CODE
                   ADD 1 TO WS-REVIEWED
                   STRING 'PARTIAL MATCH SCORE='
                       WS-BEST-SCORE
                       DELIMITED BY SIZE
                       INTO WS-REASON-BUF
                       WITH POINTER WS-REASON-PTR
                   END-STRING
               ELSE
                   MOVE 'OK' TO ALT-ACTION-CODE
                   ADD 1 TO WS-PASSED
                   STRING 'NO SIGNIFICANT MATCH'
                       DELIMITED BY SIZE
                       INTO WS-REASON-BUF
                       WITH POINTER WS-REASON-PTR
                   END-STRING
               END-IF
           END-IF
           MOVE WS-REASON-BUF TO ALT-REASON.

       2300-WRITE-ALERT.
           IF WS-BEST-IDX > 0
               STRING WS-SDN-LAST(WS-BEST-IDX) ' '
                   WS-SDN-FIRST(WS-BEST-IDX)
                   DELIMITED BY SIZE
                   INTO ALT-NAME-MATCHED
               END-STRING
           ELSE
               MOVE SPACES TO ALT-NAME-MATCHED
           END-IF
           WRITE ALERT-RECORD.

       3000-CLOSE-FILES.
           CLOSE CUSTOMER-FILE
           CLOSE ALERT-FILE.

       4000-DISPLAY-SUMMARY.
           DISPLAY 'SANCTIONS SCREENING COMPLETE'
           DISPLAY 'CUSTOMERS SCREENED: ' WS-SCREENED
           DISPLAY 'BLOCKED:            ' WS-BLOCKED
           DISPLAY 'SENT TO REVIEW:     ' WS-REVIEWED
           DISPLAY 'PASSED:             ' WS-PASSED.
