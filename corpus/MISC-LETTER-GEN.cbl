       IDENTIFICATION DIVISION.
       PROGRAM-ID. MISC-LETTER-GEN.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CUSTOMER-DATA.
           05 WS-FULL-NAME           PIC X(40).
           05 WS-ADDRESS             PIC X(60).
           05 WS-ACCT-NUM            PIC X(12).
       01 WS-NAME-PARTS.
           05 WS-FIRST-NAME          PIC X(20).
           05 WS-LAST-NAME           PIC X(20).
       01 WS-LETTER-TYPE             PIC X(1).
           88 WS-WELCOME             VALUE 'W'.
           88 WS-STMT-NOTICE         VALUE 'S'.
           88 WS-OVERDUE             VALUE 'O'.
       01 WS-GREETING                PIC X(40).
       01 WS-BODY-LINE               PIC X(60).
       01 WS-CLOSING-LINE            PIC X(40).
       01 WS-VALID-FLAG              PIC X VALUE 'N'.
           88 WS-IS-VALID            VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PARSE-NAME
           PERFORM 3000-BUILD-GREETING
           PERFORM 4000-BUILD-BODY
           PERFORM 5000-DISPLAY-LETTER
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'N' TO WS-VALID-FLAG
           MOVE SPACES TO WS-GREETING
           MOVE SPACES TO WS-BODY-LINE.
       2000-PARSE-NAME.
           IF WS-FULL-NAME NOT = SPACES
               UNSTRING WS-FULL-NAME
                   DELIMITED BY ' '
                   INTO WS-FIRST-NAME
                        WS-LAST-NAME
               END-UNSTRING
               IF WS-LAST-NAME NOT = SPACES
                   MOVE 'Y' TO WS-VALID-FLAG
               END-IF
           END-IF.
       3000-BUILD-GREETING.
           IF WS-IS-VALID
               STRING 'Dear ' DELIMITED BY SIZE
                      WS-FIRST-NAME DELIMITED BY '  '
                      ' ' DELIMITED BY SIZE
                      WS-LAST-NAME DELIMITED BY '  '
                      ',' DELIMITED BY SIZE
                      INTO WS-GREETING
               END-STRING
           END-IF.
       4000-BUILD-BODY.
           EVALUATE TRUE
               WHEN WS-WELCOME
                   STRING 'Welcome to our bank. Account '
                              DELIMITED BY SIZE
                          WS-ACCT-NUM DELIMITED BY SIZE
                          ' is active.' DELIMITED BY SIZE
                          INTO WS-BODY-LINE
                   END-STRING
               WHEN WS-STMT-NOTICE
                   STRING 'Your statement for account '
                              DELIMITED BY SIZE
                          WS-ACCT-NUM DELIMITED BY SIZE
                          ' is ready.' DELIMITED BY SIZE
                          INTO WS-BODY-LINE
                   END-STRING
               WHEN WS-OVERDUE
                   STRING 'Account ' DELIMITED BY SIZE
                          WS-ACCT-NUM DELIMITED BY SIZE
                          ' has a past due balance.'
                              DELIMITED BY SIZE
                          INTO WS-BODY-LINE
                   END-STRING
           END-EVALUATE
           MOVE 'Sincerely, Customer Service' TO
               WS-CLOSING-LINE.
       5000-DISPLAY-LETTER.
           DISPLAY WS-GREETING
           DISPLAY WS-BODY-LINE
           DISPLAY WS-CLOSING-LINE.
