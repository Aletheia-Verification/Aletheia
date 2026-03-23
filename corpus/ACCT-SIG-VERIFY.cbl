       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCT-SIG-VERIFY.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-SIG-RECORD.
           05 WS-ACCT-NUM             PIC X(12).
           05 WS-SIG-TYPE             PIC X(1).
               88 SIG-SINGLE          VALUE 'S'.
               88 SIG-JOINT           VALUE 'J'.
               88 SIG-CORPORATE       VALUE 'C'.
           05 WS-SIG-COUNT-REQ        PIC 9.
           05 WS-SIG-COUNT-GOT        PIC 9.
           05 WS-TXN-THRESHOLD        PIC S9(9)V99 COMP-3.
       01 WS-TXN-AMOUNT               PIC S9(9)V99 COMP-3.
       01 WS-AUTH-STATUS               PIC X(10).
       01 WS-SIGNERS.
           05 WS-SIGNER OCCURS 5 TIMES.
               10 WS-SIGNER-NAME      PIC X(20).
               10 WS-SIGNER-ROLE      PIC X(10).
               10 WS-SIGNER-VALID     PIC X.
                   88 SIGNER-OK       VALUE 'Y'.
       01 WS-SIG-IDX                  PIC 9.
       01 WS-VALID-SIGS               PIC 9.
       01 WS-NEEDS-DUAL               PIC X VALUE 'N'.
           88 DUAL-REQUIRED           VALUE 'Y'.
       01 WS-AUDIT-LINE               PIC X(80).
       01 WS-TALLY-COUNT              PIC 9(3).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-DETERMINE-REQUIREMENTS
           PERFORM 3000-VALIDATE-SIGNATURES
           PERFORM 4000-AUTHORIZE
           PERFORM 5000-AUDIT-LOG
           STOP RUN.
       1000-INIT.
           MOVE 0 TO WS-VALID-SIGS
           MOVE SPACES TO WS-AUTH-STATUS
           MOVE 'N' TO WS-NEEDS-DUAL.
       2000-DETERMINE-REQUIREMENTS.
           EVALUATE TRUE
               WHEN SIG-SINGLE
                   MOVE 1 TO WS-SIG-COUNT-REQ
                   IF WS-TXN-AMOUNT > 10000.00
                       MOVE 'Y' TO WS-NEEDS-DUAL
                       MOVE 2 TO WS-SIG-COUNT-REQ
                   END-IF
               WHEN SIG-JOINT
                   IF WS-TXN-AMOUNT > 5000.00
                       MOVE 2 TO WS-SIG-COUNT-REQ
                   ELSE
                       MOVE 1 TO WS-SIG-COUNT-REQ
                   END-IF
               WHEN SIG-CORPORATE
                   IF WS-TXN-AMOUNT > WS-TXN-THRESHOLD
                       MOVE 3 TO WS-SIG-COUNT-REQ
                   ELSE
                       IF WS-TXN-AMOUNT > 25000.00
                           MOVE 2 TO WS-SIG-COUNT-REQ
                       ELSE
                           MOVE 1 TO WS-SIG-COUNT-REQ
                       END-IF
                   END-IF
               WHEN OTHER
                   MOVE 'INVALID   ' TO WS-AUTH-STATUS
           END-EVALUATE.
       3000-VALIDATE-SIGNATURES.
           PERFORM VARYING WS-SIG-IDX FROM 1 BY 1
               UNTIL WS-SIG-IDX > 5
               IF SIGNER-OK(WS-SIG-IDX)
                   ADD 1 TO WS-VALID-SIGS
               END-IF
           END-PERFORM
           MOVE 0 TO WS-TALLY-COUNT
           INSPECT WS-AUTH-STATUS
               TALLYING WS-TALLY-COUNT
               FOR ALL 'I'.
       4000-AUTHORIZE.
           IF WS-AUTH-STATUS = 'INVALID   '
               DISPLAY 'INVALID SIGNATURE TYPE'
           ELSE
               IF WS-VALID-SIGS >= WS-SIG-COUNT-REQ
                   MOVE 'AUTHORIZED' TO WS-AUTH-STATUS
                   DISPLAY 'TRANSACTION AUTHORIZED'
               ELSE
                   MOVE 'DENIED    ' TO WS-AUTH-STATUS
                   DISPLAY 'INSUFFICIENT SIGNATURES'
                   DISPLAY 'REQUIRED: ' WS-SIG-COUNT-REQ
                   DISPLAY 'RECEIVED: ' WS-VALID-SIGS
               END-IF
           END-IF.
       5000-AUDIT-LOG.
           STRING 'SIG-AUTH ACCT=' DELIMITED BY SIZE
               WS-ACCT-NUM DELIMITED BY ' '
               ' STATUS=' DELIMITED BY SIZE
               WS-AUTH-STATUS DELIMITED BY SIZE
               INTO WS-AUDIT-LINE
           END-STRING
           DISPLAY WS-AUDIT-LINE.
