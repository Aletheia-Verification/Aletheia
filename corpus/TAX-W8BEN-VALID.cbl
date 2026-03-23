       IDENTIFICATION DIVISION.
       PROGRAM-ID. TAX-W8BEN-VALID.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-FORM-DATA.
           05 WS-BENE-NAME           PIC X(30).
           05 WS-COUNTRY-CITIZEN     PIC X(3).
           05 WS-COUNTRY-RESIDENCE   PIC X(3).
           05 WS-TIN-VALUE           PIC X(15).
           05 WS-TREATY-COUNTRY      PIC X(3).
           05 WS-TREATY-RATE         PIC X(5).
       01 WS-VALID-FLAG              PIC X VALUE 'N'.
           88 WS-IS-VALID            VALUE 'Y'.
       01 WS-ERROR-MSG               PIC X(40).
       01 WS-NAME-PARTS.
           05 WS-FIRST               PIC X(15).
           05 WS-LAST                PIC X(20).
       01 WS-DASH-COUNT              PIC 9(2).
       01 WS-SPACE-COUNT             PIC 9(2).
       01 WS-FORMATTED-MSG           PIC X(60).
       01 WS-US-FLAG                 PIC X VALUE 'N'.
           88 WS-IS-US-PERSON        VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-VALIDATE-NAME
           IF WS-IS-VALID
               PERFORM 3000-VALIDATE-COUNTRY
           END-IF
           IF WS-IS-VALID
               PERFORM 4000-CHECK-TREATY
           END-IF
           PERFORM 5000-FORMAT-RESULT
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'N' TO WS-VALID-FLAG
           MOVE 'N' TO WS-US-FLAG
           MOVE SPACES TO WS-ERROR-MSG
           MOVE 0 TO WS-DASH-COUNT
           MOVE 0 TO WS-SPACE-COUNT.
       2000-VALIDATE-NAME.
           IF WS-BENE-NAME = SPACES
               MOVE 'BENEFICIARY NAME REQUIRED' TO
                   WS-ERROR-MSG
           ELSE
               UNSTRING WS-BENE-NAME
                   DELIMITED BY ' '
                   INTO WS-FIRST
                        WS-LAST
               END-UNSTRING
               IF WS-LAST = SPACES
                   MOVE 'LAST NAME REQUIRED' TO
                       WS-ERROR-MSG
               ELSE
                   MOVE 'Y' TO WS-VALID-FLAG
               END-IF
           END-IF.
       3000-VALIDATE-COUNTRY.
           IF WS-COUNTRY-CITIZEN = 'USA'
               MOVE 'US PERSON - USE W-9' TO WS-ERROR-MSG
               MOVE 'N' TO WS-VALID-FLAG
               MOVE 'Y' TO WS-US-FLAG
           END-IF
           IF WS-COUNTRY-CITIZEN = SPACES
               MOVE 'CITIZENSHIP REQUIRED' TO WS-ERROR-MSG
               MOVE 'N' TO WS-VALID-FLAG
           END-IF
           IF WS-IS-VALID
               INSPECT WS-TIN-VALUE
                   TALLYING WS-DASH-COUNT FOR ALL '-'
               INSPECT WS-TIN-VALUE
                   TALLYING WS-SPACE-COUNT FOR ALL ' '
           END-IF.
       4000-CHECK-TREATY.
           IF WS-TREATY-COUNTRY NOT = SPACES
               IF WS-TREATY-RATE IS NUMERIC
                   DISPLAY 'TREATY RATE CLAIMED'
               ELSE
                   IF WS-TREATY-RATE = SPACES
                       DISPLAY 'NO TREATY RATE'
                   ELSE
                       MOVE 'INVALID TREATY RATE' TO
                           WS-ERROR-MSG
                       MOVE 'N' TO WS-VALID-FLAG
                   END-IF
               END-IF
           END-IF.
       5000-FORMAT-RESULT.
           IF WS-IS-VALID
               STRING 'W8BEN VALID: ' DELIMITED BY SIZE
                      WS-BENE-NAME DELIMITED BY '  '
                      ' COUNTRY=' DELIMITED BY SIZE
                      WS-COUNTRY-CITIZEN DELIMITED BY SIZE
                      INTO WS-FORMATTED-MSG
               END-STRING
           ELSE
               STRING 'W8BEN INVALID: ' DELIMITED BY SIZE
                      WS-ERROR-MSG DELIMITED BY '  '
                      INTO WS-FORMATTED-MSG
               END-STRING
           END-IF.
       6000-DISPLAY-RESULTS.
           DISPLAY 'W-8BEN VALIDATION'
           DISPLAY '================='
           DISPLAY 'NAME:      ' WS-BENE-NAME
           DISPLAY 'COUNTRY:   ' WS-COUNTRY-CITIZEN
           IF WS-IS-VALID
               DISPLAY 'STATUS: VALID'
           ELSE
               DISPLAY 'STATUS: INVALID'
               DISPLAY 'ERROR:  ' WS-ERROR-MSG
           END-IF
           DISPLAY WS-FORMATTED-MSG.
