       IDENTIFICATION DIVISION.
       PROGRAM-ID. FRAUD-ALERT-FORMAT.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ALERT-INPUT.
           05 WS-RAW-DATA            PIC X(120).
       01 WS-PARSED-FIELDS.
           05 WS-ALERT-TYPE          PIC X(10).
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-AMOUNT              PIC X(12).
           05 WS-RISK-LEVEL          PIC X(6).
           05 WS-TIMESTAMP           PIC X(20).
       01 WS-ALERT-CODE              PIC X(3).
           88 WS-HIGH-VALUE          VALUE 'HVT'.
           88 WS-INTL-TXN            VALUE 'INT'.
           88 WS-VELOCITY            VALUE 'VEL'.
           88 WS-COMPROMISED         VALUE 'CMP'.
       01 WS-VALID-FLAG              PIC X VALUE 'N'.
           88 WS-IS-VALID            VALUE 'Y'.
       01 WS-ERROR-MSG               PIC X(30).
       01 WS-FORMATTED-ALERT         PIC X(80).
       01 WS-SHORT-MSG               PIC X(40).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PARSE-INPUT
           PERFORM 3000-VALIDATE
           IF WS-IS-VALID
               PERFORM 4000-FORMAT-ALERT
           END-IF
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE SPACES TO WS-ERROR-MSG
           MOVE 'N' TO WS-VALID-FLAG.
       2000-PARSE-INPUT.
           UNSTRING WS-RAW-DATA
               DELIMITED BY '|'
               INTO WS-ALERT-TYPE
                    WS-ACCT-NUM
                    WS-AMOUNT
                    WS-RISK-LEVEL
                    WS-TIMESTAMP
           END-UNSTRING.
       3000-VALIDATE.
           IF WS-ACCT-NUM = SPACES
               MOVE 'MISSING ACCOUNT NUMBER' TO
                   WS-ERROR-MSG
           ELSE
               IF WS-AMOUNT IS NUMERIC
                   MOVE 'Y' TO WS-VALID-FLAG
               ELSE
                   IF WS-AMOUNT = SPACES
                       MOVE 'MISSING AMOUNT' TO
                           WS-ERROR-MSG
                   ELSE
                       MOVE 'Y' TO WS-VALID-FLAG
                   END-IF
               END-IF
           END-IF.
       4000-FORMAT-ALERT.
           STRING 'FRAUD|' DELIMITED BY SIZE
                  WS-ALERT-TYPE DELIMITED BY '  '
                  '|' DELIMITED BY SIZE
                  WS-ACCT-NUM DELIMITED BY SIZE
                  '|' DELIMITED BY SIZE
                  WS-AMOUNT DELIMITED BY '  '
                  '|' DELIMITED BY SIZE
                  WS-RISK-LEVEL DELIMITED BY '  '
                  INTO WS-FORMATTED-ALERT
           END-STRING
           STRING WS-ALERT-TYPE DELIMITED BY '  '
                  ' ' DELIMITED BY SIZE
                  WS-ACCT-NUM DELIMITED BY SIZE
                  INTO WS-SHORT-MSG
           END-STRING.
       5000-DISPLAY-RESULTS.
           DISPLAY 'FRAUD ALERT FORMATTING'
           DISPLAY '======================'
           IF WS-IS-VALID
               DISPLAY 'STATUS: FORMATTED'
               DISPLAY 'TYPE:    ' WS-ALERT-TYPE
               DISPLAY 'ACCOUNT: ' WS-ACCT-NUM
               DISPLAY 'AMOUNT:  ' WS-AMOUNT
               DISPLAY 'RISK:    ' WS-RISK-LEVEL
               DISPLAY 'OUTPUT:  ' WS-FORMATTED-ALERT
               DISPLAY 'SHORT:   ' WS-SHORT-MSG
           ELSE
               DISPLAY 'STATUS: INVALID'
               DISPLAY 'ERROR:   ' WS-ERROR-MSG
           END-IF.
