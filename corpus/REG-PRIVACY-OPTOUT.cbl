       IDENTIFICATION DIVISION.
       PROGRAM-ID. REG-PRIVACY-OPTOUT.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CUSTOMER.
           05 WS-CUST-ID         PIC X(12).
           05 WS-CUST-NAME       PIC X(30).
           05 WS-CUST-STATE      PIC X(2).
       01 WS-CONSENT-FLAGS.
           05 WS-MARKETING       PIC X VALUE 'Y'.
               88 OPT-IN-MKT    VALUE 'Y'.
           05 WS-AFFILIATE       PIC X VALUE 'Y'.
               88 OPT-IN-AFF    VALUE 'Y'.
           05 WS-THIRD-PARTY     PIC X VALUE 'Y'.
               88 OPT-IN-TP     VALUE 'Y'.
           05 WS-DATA-SALE       PIC X VALUE 'N'.
               88 OPT-IN-SALE   VALUE 'Y'.
       01 WS-OPT-ACTION         PIC X(2).
           88 ACT-OPTOUT-ALL    VALUE 'OA'.
           88 ACT-OPTOUT-MKT    VALUE 'OM'.
           88 ACT-OPTOUT-AFF    VALUE 'OF'.
           88 ACT-OPTOUT-TP     VALUE 'OT'.
           88 ACT-OPTIN-ALL     VALUE 'IA'.
       01 WS-CHANGED-COUNT      PIC 9.
       01 WS-CCPA-APPLIES       PIC X VALUE 'N'.
           88 IS-CCPA           VALUE 'Y'.
       01 WS-GDPR-APPLIES       PIC X VALUE 'N'.
           88 IS-GDPR           VALUE 'Y'.
       01 WS-AUDIT-MSG          PIC X(80).
       01 WS-PROCESS-DATE       PIC 9(8).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-CHECK-REGULATIONS
           PERFORM 2000-APPLY-OPTOUT
           PERFORM 3000-ENFORCE-REGULATIONS
           PERFORM 4000-AUDIT
           PERFORM 5000-OUTPUT
           STOP RUN.
       1000-CHECK-REGULATIONS.
           ACCEPT WS-PROCESS-DATE FROM DATE YYYYMMDD
           IF WS-CUST-STATE = 'CA'
               MOVE 'Y' TO WS-CCPA-APPLIES
           END-IF.
       2000-APPLY-OPTOUT.
           MOVE 0 TO WS-CHANGED-COUNT
           EVALUATE TRUE
               WHEN ACT-OPTOUT-ALL
                   IF OPT-IN-MKT
                       MOVE 'N' TO WS-MARKETING
                       ADD 1 TO WS-CHANGED-COUNT
                   END-IF
                   IF OPT-IN-AFF
                       MOVE 'N' TO WS-AFFILIATE
                       ADD 1 TO WS-CHANGED-COUNT
                   END-IF
                   IF OPT-IN-TP
                       MOVE 'N' TO WS-THIRD-PARTY
                       ADD 1 TO WS-CHANGED-COUNT
                   END-IF
                   IF OPT-IN-SALE
                       MOVE 'N' TO WS-DATA-SALE
                       ADD 1 TO WS-CHANGED-COUNT
                   END-IF
               WHEN ACT-OPTOUT-MKT
                   IF OPT-IN-MKT
                       MOVE 'N' TO WS-MARKETING
                       ADD 1 TO WS-CHANGED-COUNT
                   END-IF
               WHEN ACT-OPTOUT-AFF
                   IF OPT-IN-AFF
                       MOVE 'N' TO WS-AFFILIATE
                       ADD 1 TO WS-CHANGED-COUNT
                   END-IF
               WHEN ACT-OPTOUT-TP
                   IF OPT-IN-TP
                       MOVE 'N' TO WS-THIRD-PARTY
                       ADD 1 TO WS-CHANGED-COUNT
                   END-IF
               WHEN ACT-OPTIN-ALL
                   MOVE 'Y' TO WS-MARKETING
                   MOVE 'Y' TO WS-AFFILIATE
                   MOVE 'Y' TO WS-THIRD-PARTY
                   MOVE 4 TO WS-CHANGED-COUNT
           END-EVALUATE.
       3000-ENFORCE-REGULATIONS.
           IF IS-CCPA
               MOVE 'N' TO WS-DATA-SALE
           END-IF.
       4000-AUDIT.
           STRING 'PRIVACY ' DELIMITED BY SIZE
               WS-CUST-ID DELIMITED BY ' '
               ' ACT=' DELIMITED BY SIZE
               WS-OPT-ACTION DELIMITED BY SIZE
               ' CHG=' DELIMITED BY SIZE
               WS-CHANGED-COUNT DELIMITED BY SIZE
               INTO WS-AUDIT-MSG
           END-STRING.
       5000-OUTPUT.
           DISPLAY 'PRIVACY OPT-OUT PROCESSING'
           DISPLAY '=========================='
           DISPLAY 'CUSTOMER: ' WS-CUST-ID
           DISPLAY 'NAME:     ' WS-CUST-NAME
           DISPLAY 'STATE:    ' WS-CUST-STATE
           DISPLAY 'ACTION:   ' WS-OPT-ACTION
           DISPLAY 'CHANGES:  ' WS-CHANGED-COUNT
           DISPLAY 'MARKETING:' WS-MARKETING
           DISPLAY 'AFFILIATE:' WS-AFFILIATE
           DISPLAY '3RD PARTY:' WS-THIRD-PARTY
           DISPLAY 'DATA SALE:' WS-DATA-SALE
           IF IS-CCPA
               DISPLAY 'CCPA ENFORCED'
           END-IF.
