       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCT-TITLE-CHANGE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ACCT-DATA.
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-CURRENT-TITLE       PIC X(60).
           05 WS-NEW-TITLE           PIC X(60).
       01 WS-NAME-PARTS.
           05 WS-FIRST-NAME          PIC X(20).
           05 WS-MIDDLE-NAME         PIC X(20).
           05 WS-LAST-NAME           PIC X(30).
           05 WS-SUFFIX              PIC X(5).
       01 WS-NEW-PARTS.
           05 WS-NEW-FIRST           PIC X(20).
           05 WS-NEW-MIDDLE          PIC X(20).
           05 WS-NEW-LAST            PIC X(30).
           05 WS-NEW-SUFFIX          PIC X(5).
       01 WS-CHANGE-REASON           PIC X(1).
           88 WS-MARRIAGE            VALUE 'M'.
           88 WS-DIVORCE             VALUE 'D'.
           88 WS-COURT-ORDER         VALUE 'C'.
           88 WS-CORRECTION          VALUE 'X'.
       01 WS-VALID-FLAG              PIC X VALUE 'N'.
           88 WS-IS-VALID            VALUE 'Y'.
       01 WS-ERROR-MSG               PIC X(40).
       01 WS-FORMATTED-NAME          PIC X(60).
       01 WS-AUDIT-MSG               PIC X(80).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PARSE-CURRENT-NAME
           PERFORM 3000-VALIDATE-NEW-NAME
           IF WS-IS-VALID
               PERFORM 4000-FORMAT-NEW-TITLE
               PERFORM 5000-BUILD-AUDIT
           END-IF
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE SPACES TO WS-ERROR-MSG
           MOVE 'N' TO WS-VALID-FLAG
           MOVE SPACES TO WS-FORMATTED-NAME
           MOVE SPACES TO WS-AUDIT-MSG.
       2000-PARSE-CURRENT-NAME.
           UNSTRING WS-CURRENT-TITLE
               DELIMITED BY ' '
               INTO WS-FIRST-NAME
                    WS-MIDDLE-NAME
                    WS-LAST-NAME
           END-UNSTRING.
       3000-VALIDATE-NEW-NAME.
           IF WS-NEW-LAST = SPACES
               MOVE 'LAST NAME REQUIRED' TO WS-ERROR-MSG
           ELSE
               IF WS-NEW-FIRST = SPACES
                   MOVE 'FIRST NAME REQUIRED' TO
                       WS-ERROR-MSG
               ELSE
                   MOVE 'Y' TO WS-VALID-FLAG
               END-IF
           END-IF
           IF WS-IS-VALID
               IF WS-NEW-FIRST(1:1) IS NUMERIC
                   MOVE 'NAME CANNOT START NUMERIC'
                       TO WS-ERROR-MSG
                   MOVE 'N' TO WS-VALID-FLAG
               END-IF
           END-IF.
       4000-FORMAT-NEW-TITLE.
           STRING WS-NEW-LAST DELIMITED BY '  '
                  ', ' DELIMITED BY SIZE
                  WS-NEW-FIRST DELIMITED BY '  '
                  ' ' DELIMITED BY SIZE
                  WS-NEW-MIDDLE DELIMITED BY '  '
                  INTO WS-FORMATTED-NAME
           END-STRING
           MOVE WS-FORMATTED-NAME TO WS-NEW-TITLE.
       5000-BUILD-AUDIT.
           STRING 'TITLE CHG ' DELIMITED BY SIZE
                  WS-ACCT-NUM DELIMITED BY SIZE
                  ' FROM=' DELIMITED BY SIZE
                  WS-CURRENT-TITLE DELIMITED BY '  '
                  ' TO=' DELIMITED BY SIZE
                  WS-NEW-TITLE DELIMITED BY '  '
                  INTO WS-AUDIT-MSG
           END-STRING.
       6000-DISPLAY-RESULTS.
           DISPLAY 'ACCOUNT TITLE CHANGE'
           DISPLAY '===================='
           DISPLAY 'ACCOUNT:  ' WS-ACCT-NUM
           DISPLAY 'CURRENT:  ' WS-CURRENT-TITLE
           IF WS-IS-VALID
               DISPLAY 'NEW:      ' WS-NEW-TITLE
               DISPLAY 'STATUS: CHANGED'
               DISPLAY 'AUDIT: ' WS-AUDIT-MSG
           ELSE
               DISPLAY 'STATUS: REJECTED'
               DISPLAY 'ERROR:  ' WS-ERROR-MSG
           END-IF.
