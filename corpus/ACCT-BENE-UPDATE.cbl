       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCT-BENE-UPDATE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ACCT-NUM                PIC X(12).
       01 WS-BENE-CURRENT.
           05 WS-BENE-NAME           PIC X(30).
           05 WS-BENE-SSN            PIC X(9).
           05 WS-BENE-PCT            PIC 9(3).
           05 WS-BENE-RELATION       PIC X(10).
       01 WS-BENE-NEW.
           05 WS-NEW-BENE-NAME       PIC X(30).
           05 WS-NEW-BENE-SSN        PIC X(9).
           05 WS-NEW-BENE-PCT        PIC 9(3).
           05 WS-NEW-BENE-RELATION   PIC X(10).
       01 WS-ACTION-TYPE             PIC X(1).
           88 WS-ADD-BENE            VALUE 'A'.
           88 WS-CHANGE-BENE         VALUE 'C'.
           88 WS-REMOVE-BENE         VALUE 'R'.
       01 WS-VALID-FLAG              PIC X VALUE 'N'.
           88 WS-IS-VALID            VALUE 'Y'.
       01 WS-ERROR-MSG               PIC X(40).
       01 WS-TOTAL-PCT               PIC 9(3).
       01 WS-AUDIT-RECORD            PIC X(80).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-VALIDATE-INPUT
           IF WS-IS-VALID
               PERFORM 3000-PROCESS-CHANGE
               PERFORM 4000-BUILD-AUDIT
           END-IF
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'N' TO WS-VALID-FLAG
           MOVE SPACES TO WS-ERROR-MSG
           MOVE 0 TO WS-TOTAL-PCT.
       2000-VALIDATE-INPUT.
           EVALUATE TRUE
               WHEN WS-ADD-BENE
                   IF WS-NEW-BENE-NAME = SPACES
                       MOVE 'BENEFICIARY NAME REQUIRED'
                           TO WS-ERROR-MSG
                   ELSE
                       IF WS-NEW-BENE-SSN IS NUMERIC
                           IF WS-NEW-BENE-PCT > 0
                               IF WS-NEW-BENE-PCT <= 100
                                   MOVE 'Y' TO WS-VALID-FLAG
                               ELSE
                                   MOVE 'PCT EXCEEDS 100'
                                       TO WS-ERROR-MSG
                               END-IF
                           ELSE
                               MOVE 'PCT MUST BE > 0'
                                   TO WS-ERROR-MSG
                           END-IF
                       ELSE
                           MOVE 'SSN MUST BE NUMERIC'
                               TO WS-ERROR-MSG
                       END-IF
                   END-IF
               WHEN WS-CHANGE-BENE
                   IF WS-BENE-NAME NOT = SPACES
                       MOVE 'Y' TO WS-VALID-FLAG
                   ELSE
                       MOVE 'CURRENT BENE NOT FOUND'
                           TO WS-ERROR-MSG
                   END-IF
               WHEN WS-REMOVE-BENE
                   IF WS-BENE-NAME NOT = SPACES
                       MOVE 'Y' TO WS-VALID-FLAG
                   ELSE
                       MOVE 'NO BENE TO REMOVE'
                           TO WS-ERROR-MSG
                   END-IF
               WHEN OTHER
                   MOVE 'INVALID ACTION TYPE' TO
                       WS-ERROR-MSG
           END-EVALUATE.
       3000-PROCESS-CHANGE.
           IF WS-ADD-BENE
               MOVE WS-NEW-BENE-NAME TO WS-BENE-NAME
               MOVE WS-NEW-BENE-SSN TO WS-BENE-SSN
               MOVE WS-NEW-BENE-PCT TO WS-BENE-PCT
               MOVE WS-NEW-BENE-RELATION TO
                   WS-BENE-RELATION
               DISPLAY 'BENEFICIARY ADDED'
           END-IF
           IF WS-CHANGE-BENE
               MOVE WS-NEW-BENE-NAME TO WS-BENE-NAME
               DISPLAY 'BENEFICIARY CHANGED'
           END-IF
           IF WS-REMOVE-BENE
               MOVE SPACES TO WS-BENE-NAME
               MOVE SPACES TO WS-BENE-SSN
               MOVE 0 TO WS-BENE-PCT
               DISPLAY 'BENEFICIARY REMOVED'
           END-IF.
       4000-BUILD-AUDIT.
           STRING 'BENE ' DELIMITED BY SIZE
                  WS-ACTION-TYPE DELIMITED BY SIZE
                  ' ACCT=' DELIMITED BY SIZE
                  WS-ACCT-NUM DELIMITED BY SIZE
                  ' NAME=' DELIMITED BY SIZE
                  WS-BENE-NAME DELIMITED BY '  '
                  INTO WS-AUDIT-RECORD
           END-STRING.
       5000-DISPLAY-RESULTS.
           DISPLAY 'BENEFICIARY UPDATE'
           DISPLAY '=================='
           DISPLAY 'ACCOUNT:    ' WS-ACCT-NUM
           IF WS-IS-VALID
               DISPLAY 'STATUS: PROCESSED'
               DISPLAY 'NAME:       ' WS-BENE-NAME
               DISPLAY 'PERCENTAGE: ' WS-BENE-PCT
               DISPLAY 'AUDIT: ' WS-AUDIT-RECORD
           ELSE
               DISPLAY 'STATUS: REJECTED'
               DISPLAY 'ERROR: ' WS-ERROR-MSG
           END-IF.
