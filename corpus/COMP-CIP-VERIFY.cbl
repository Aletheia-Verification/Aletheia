       IDENTIFICATION DIVISION.
       PROGRAM-ID. COMP-CIP-VERIFY.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-APPLICANT.
           05 WS-APP-NAME        PIC X(40).
           05 WS-APP-DOB         PIC 9(8).
           05 WS-APP-SSN         PIC X(9).
           05 WS-APP-ADDRESS     PIC X(40).
           05 WS-APP-ID-TYPE     PIC X(2).
               88 ID-DRIVERS     VALUE 'DL'.
               88 ID-PASSPORT    VALUE 'PP'.
               88 ID-STATE-ID    VALUE 'SI'.
               88 ID-MILITARY    VALUE 'MI'.
           05 WS-APP-ID-NUM      PIC X(15).
           05 WS-APP-ID-EXPIRY   PIC 9(8).
       01 WS-VERIFICATION.
           05 WS-NAME-MATCH      PIC X VALUE 'N'.
               88 NAME-OK        VALUE 'Y'.
           05 WS-DOB-MATCH       PIC X VALUE 'N'.
               88 DOB-OK         VALUE 'Y'.
           05 WS-SSN-MATCH       PIC X VALUE 'N'.
               88 SSN-OK         VALUE 'Y'.
           05 WS-ADDR-MATCH      PIC X VALUE 'N'.
               88 ADDR-OK        VALUE 'Y'.
           05 WS-ID-VALID        PIC X VALUE 'N'.
               88 ID-OK          VALUE 'Y'.
       01 WS-MATCH-COUNT         PIC 9.
       01 WS-REQUIRED-MATCHES    PIC 9 VALUE 4.
       01 WS-CIP-STATUS          PIC X(15).
       01 WS-CURRENT-DATE        PIC 9(8).
       01 WS-SSN-TALLY           PIC 9(3).
       01 WS-RISK-FLAG           PIC X VALUE 'N'.
           88 HAS-RISK           VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-VALIDATE-ID
           PERFORM 3000-VERIFY-ELEMENTS
           PERFORM 4000-DETERMINE-STATUS
           PERFORM 5000-OUTPUT
           STOP RUN.
       1000-INIT.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-MATCH-COUNT.
       2000-VALIDATE-ID.
           IF WS-APP-ID-EXPIRY >= WS-CURRENT-DATE
               EVALUATE TRUE
                   WHEN ID-DRIVERS
                       MOVE 'Y' TO WS-ID-VALID
                   WHEN ID-PASSPORT
                       MOVE 'Y' TO WS-ID-VALID
                   WHEN ID-STATE-ID
                       MOVE 'Y' TO WS-ID-VALID
                   WHEN ID-MILITARY
                       MOVE 'Y' TO WS-ID-VALID
                   WHEN OTHER
                       MOVE 'N' TO WS-ID-VALID
               END-EVALUATE
           ELSE
               MOVE 'N' TO WS-ID-VALID
               MOVE 'Y' TO WS-RISK-FLAG
           END-IF.
       3000-VERIFY-ELEMENTS.
           IF NAME-OK
               ADD 1 TO WS-MATCH-COUNT
           END-IF
           IF DOB-OK
               ADD 1 TO WS-MATCH-COUNT
           END-IF
           IF SSN-OK
               ADD 1 TO WS-MATCH-COUNT
               MOVE 0 TO WS-SSN-TALLY
               INSPECT WS-APP-SSN
                   TALLYING WS-SSN-TALLY
                   FOR ALL '0'
               IF WS-SSN-TALLY >= 7
                   MOVE 'Y' TO WS-RISK-FLAG
               END-IF
           END-IF
           IF ADDR-OK
               ADD 1 TO WS-MATCH-COUNT
           END-IF
           IF ID-OK
               ADD 1 TO WS-MATCH-COUNT
           END-IF.
       4000-DETERMINE-STATUS.
           IF WS-MATCH-COUNT >= WS-REQUIRED-MATCHES
               IF HAS-RISK
                   MOVE 'VERIFIED-RISK  ' TO WS-CIP-STATUS
               ELSE
                   MOVE 'VERIFIED       ' TO WS-CIP-STATUS
               END-IF
           ELSE
               IF WS-MATCH-COUNT >= 2
                   MOVE 'PARTIAL        ' TO WS-CIP-STATUS
               ELSE
                   MOVE 'FAILED         ' TO WS-CIP-STATUS
               END-IF
           END-IF.
       5000-OUTPUT.
           DISPLAY 'CIP VERIFICATION REPORT'
           DISPLAY '======================='
           DISPLAY 'NAME:     ' WS-APP-NAME
           DISPLAY 'ID TYPE:  ' WS-APP-ID-TYPE
           DISPLAY 'MATCHES:  ' WS-MATCH-COUNT
               '/' WS-REQUIRED-MATCHES
           DISPLAY 'NAME:     ' WS-NAME-MATCH
           DISPLAY 'DOB:      ' WS-DOB-MATCH
           DISPLAY 'SSN:      ' WS-SSN-MATCH
           DISPLAY 'ADDRESS:  ' WS-ADDR-MATCH
           DISPLAY 'ID:       ' WS-ID-VALID
           DISPLAY 'STATUS:   ' WS-CIP-STATUS
           IF HAS-RISK
               DISPLAY 'RISK FLAG ACTIVE'
           END-IF.
