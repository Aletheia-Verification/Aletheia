       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCT-POA-MGMT.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-POA-RECORD.
           05 WS-PRINCIPAL-NAME    PIC X(30).
           05 WS-AGENT-NAME        PIC X(30).
           05 WS-POA-TYPE          PIC X(1).
               88 POA-GENERAL       VALUE 'G'.
               88 POA-LIMITED       VALUE 'L'.
               88 POA-DURABLE       VALUE 'D'.
           05 WS-EFFECTIVE-DATE    PIC 9(8).
           05 WS-EXPIRY-DATE       PIC 9(8).
           05 WS-DAILY-LIMIT       PIC S9(9)V99 COMP-3.
           05 WS-AUTH-ACTIONS      PIC X(10).
       01 WS-CURRENT-DATE          PIC 9(8).
       01 WS-ACTION-CODE           PIC X(2).
           88 ACT-WITHDRAW         VALUE 'WD'.
           88 ACT-TRANSFER         VALUE 'TR'.
           88 ACT-CLOSE            VALUE 'CL'.
           88 ACT-INVEST           VALUE 'IN'.
       01 WS-REQUEST-AMT           PIC S9(9)V99 COMP-3.
       01 WS-RESULT                PIC X(12).
       01 WS-DENY-REASON           PIC X(40).
       01 WS-ACTION-ALLOWED        PIC X VALUE 'N'.
           88 IS-ALLOWED            VALUE 'Y'.
       01 WS-TALLY-CTR             PIC 9(3).
       01 WS-ACCT-ID               PIC X(12).
       01 WS-LOG-MSG               PIC X(80).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-CHECK-VALIDITY
           IF WS-RESULT NOT = 'EXPIRED     '
               AND WS-RESULT NOT = 'INVALID     '
               PERFORM 2000-CHECK-AUTHORIZATION
               PERFORM 3000-CHECK-LIMITS
           END-IF
           PERFORM 4000-RECORD-DECISION
           STOP RUN.
       1000-CHECK-VALIDITY.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           IF WS-EFFECTIVE-DATE > WS-CURRENT-DATE
               MOVE 'NOT-ACTIVE  ' TO WS-RESULT
               MOVE 'POA NOT YET EFFECTIVE' TO WS-DENY-REASON
           ELSE
               IF WS-EXPIRY-DATE < WS-CURRENT-DATE
                   AND WS-EXPIRY-DATE > 0
                   MOVE 'EXPIRED     ' TO WS-RESULT
                   MOVE 'POA HAS EXPIRED' TO WS-DENY-REASON
               ELSE
                   MOVE 'VALID       ' TO WS-RESULT
               END-IF
           END-IF.
       2000-CHECK-AUTHORIZATION.
           MOVE 'N' TO WS-ACTION-ALLOWED
           EVALUATE TRUE
               WHEN POA-GENERAL
                   MOVE 'Y' TO WS-ACTION-ALLOWED
               WHEN POA-LIMITED
                   IF ACT-WITHDRAW OR ACT-TRANSFER
                       MOVE 0 TO WS-TALLY-CTR
                       INSPECT WS-AUTH-ACTIONS
                           TALLYING WS-TALLY-CTR
                           FOR ALL WS-ACTION-CODE
                       IF WS-TALLY-CTR > 0
                           MOVE 'Y' TO WS-ACTION-ALLOWED
                       ELSE
                           MOVE 'ACTION NOT IN POA SCOPE'
                               TO WS-DENY-REASON
                       END-IF
                   ELSE
                       MOVE 'LIMITED POA CANNOT DO THIS'
                           TO WS-DENY-REASON
                   END-IF
               WHEN POA-DURABLE
                   IF ACT-CLOSE
                       MOVE 'DURABLE POA CANNOT CLOSE'
                           TO WS-DENY-REASON
                   ELSE
                       MOVE 'Y' TO WS-ACTION-ALLOWED
                   END-IF
               WHEN OTHER
                   MOVE 'INVALID     ' TO WS-RESULT
                   MOVE 'UNKNOWN POA TYPE' TO WS-DENY-REASON
           END-EVALUATE.
       3000-CHECK-LIMITS.
           IF IS-ALLOWED
               IF WS-REQUEST-AMT > WS-DAILY-LIMIT
                   AND WS-DAILY-LIMIT > 0
                   MOVE 'N' TO WS-ACTION-ALLOWED
                   MOVE 'EXCEEDS DAILY LIMIT' TO
                       WS-DENY-REASON
                   MOVE 'OVER-LIMIT  ' TO WS-RESULT
               ELSE
                   MOVE 'APPROVED    ' TO WS-RESULT
               END-IF
           ELSE
               IF WS-RESULT = 'VALID       '
                   MOVE 'DENIED      ' TO WS-RESULT
               END-IF
           END-IF.
       4000-RECORD-DECISION.
           STRING 'POA ' DELIMITED BY SIZE
               WS-ACCT-ID DELIMITED BY ' '
               ' AGENT=' DELIMITED BY SIZE
               WS-AGENT-NAME DELIMITED BY '  '
               ' ' DELIMITED BY SIZE
               WS-RESULT DELIMITED BY SIZE
               INTO WS-LOG-MSG
           END-STRING
           DISPLAY 'POA AUTHORIZATION RESULT'
           DISPLAY '========================'
           DISPLAY 'ACCOUNT:   ' WS-ACCT-ID
           DISPLAY 'PRINCIPAL: ' WS-PRINCIPAL-NAME
           DISPLAY 'AGENT:     ' WS-AGENT-NAME
           DISPLAY 'ACTION:    ' WS-ACTION-CODE
           DISPLAY 'RESULT:    ' WS-RESULT
           IF WS-RESULT NOT = 'APPROVED    '
               DISPLAY 'REASON:    ' WS-DENY-REASON
           END-IF.
