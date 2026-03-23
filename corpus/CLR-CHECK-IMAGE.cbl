       IDENTIFICATION DIVISION.
       PROGRAM-ID. CLR-CHECK-IMAGE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CHECK-DATA.
           05 WS-MICR-LINE           PIC X(60).
           05 WS-CHECK-NUM           PIC X(10).
           05 WS-ROUTING-NUM         PIC X(9).
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-AMOUNT-FIELD        PIC X(10).
       01 WS-VALID-FLAG              PIC X VALUE 'N'.
           88 WS-IS-VALID            VALUE 'Y'.
       01 WS-ERROR-MSG               PIC X(30).
       01 WS-PARSED-AMT              PIC S9(7)V99 COMP-3.
       01 WS-FORMATTED-MSG           PIC X(60).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PARSE-MICR
           PERFORM 3000-VALIDATE
           PERFORM 4000-FORMAT-OUTPUT
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'N' TO WS-VALID-FLAG
           MOVE SPACES TO WS-ERROR-MSG.
       2000-PARSE-MICR.
           UNSTRING WS-MICR-LINE
               DELIMITED BY ' '
               INTO WS-ROUTING-NUM
                    WS-ACCT-NUM
                    WS-CHECK-NUM
           END-UNSTRING.
       3000-VALIDATE.
           IF WS-ROUTING-NUM IS NUMERIC
               IF WS-ACCT-NUM NOT = SPACES
                   IF WS-AMOUNT-FIELD IS NUMERIC
                       MOVE 'Y' TO WS-VALID-FLAG
                   ELSE
                       MOVE 'INVALID AMOUNT' TO WS-ERROR-MSG
                   END-IF
               ELSE
                   MOVE 'MISSING ACCOUNT' TO WS-ERROR-MSG
               END-IF
           ELSE
               MOVE 'INVALID ROUTING' TO WS-ERROR-MSG
           END-IF.
       4000-FORMAT-OUTPUT.
           IF WS-IS-VALID
               STRING 'CHK ' DELIMITED BY SIZE
                      WS-CHECK-NUM DELIMITED BY SIZE
                      ' RT=' DELIMITED BY SIZE
                      WS-ROUTING-NUM DELIMITED BY SIZE
                      ' ACCT=' DELIMITED BY SIZE
                      WS-ACCT-NUM DELIMITED BY SIZE
                      INTO WS-FORMATTED-MSG
               END-STRING
           END-IF.
       5000-DISPLAY-RESULTS.
           DISPLAY 'CHECK IMAGE PROCESSING'
           DISPLAY '======================'
           IF WS-IS-VALID
               DISPLAY 'STATUS: VALID'
               DISPLAY WS-FORMATTED-MSG
           ELSE
               DISPLAY 'STATUS: INVALID'
               DISPLAY 'ERROR: ' WS-ERROR-MSG
           END-IF.
