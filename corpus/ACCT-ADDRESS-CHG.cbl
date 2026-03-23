       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCT-ADDRESS-CHG.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ADDR-OLD.
           05 WS-OLD-LINE1         PIC X(30).
           05 WS-OLD-LINE2         PIC X(30).
           05 WS-OLD-CITY          PIC X(20).
           05 WS-OLD-STATE         PIC X(2).
           05 WS-OLD-ZIP           PIC X(10).
       01 WS-ADDR-NEW.
           05 WS-NEW-LINE1         PIC X(30).
           05 WS-NEW-LINE2         PIC X(30).
           05 WS-NEW-CITY          PIC X(20).
           05 WS-NEW-STATE         PIC X(2).
           05 WS-NEW-ZIP           PIC X(10).
       01 WS-VALIDATION.
           05 WS-VALID-ADDR        PIC X VALUE 'N'.
               88 ADDR-VALID       VALUE 'Y'.
           05 WS-ERR-MSG           PIC X(40).
           05 WS-ZIP-NUMERIC       PIC X VALUE 'N'.
       01 WS-ZIP-FIRST5            PIC X(5).
       01 WS-CHG-REASON            PIC X(1).
           88 REASON-RELOC          VALUE 'R'.
           88 REASON-CORRECT        VALUE 'C'.
           88 REASON-SEASONAL       VALUE 'S'.
       01 WS-CONFIRMATION          PIC X(15).
       01 WS-LETTER-FLAG           PIC X VALUE 'N'.
           88 SEND-LETTER           VALUE 'Y'.
       01 WS-ACCT-NUMBER           PIC X(12).
       01 WS-CUST-NAME             PIC X(30).
       01 WS-CHANGE-DATE           PIC 9(8).
       01 WS-AUDIT-REC             PIC X(80).
       01 WS-TALLY-DIGITS          PIC 99.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-VALIDATE-INPUT
           IF ADDR-VALID
               PERFORM 2000-APPLY-CHANGE
               PERFORM 3000-DETERMINE-LETTER
               PERFORM 4000-BUILD-AUDIT
           END-IF
           PERFORM 5000-OUTPUT
           STOP RUN.
       1000-VALIDATE-INPUT.
           MOVE 'N' TO WS-VALID-ADDR
           IF WS-NEW-LINE1 = SPACES
               MOVE 'ADDRESS LINE 1 REQUIRED' TO WS-ERR-MSG
           ELSE
               IF WS-NEW-CITY = SPACES
                   MOVE 'CITY REQUIRED' TO WS-ERR-MSG
               ELSE
                   IF WS-NEW-STATE = SPACES
                       MOVE 'STATE REQUIRED' TO WS-ERR-MSG
                   ELSE
                       PERFORM 1100-CHECK-ZIP
                   END-IF
               END-IF
           END-IF.
       1100-CHECK-ZIP.
           MOVE WS-NEW-ZIP(1:5) TO WS-ZIP-FIRST5
           MOVE 0 TO WS-TALLY-DIGITS
           INSPECT WS-ZIP-FIRST5
               TALLYING WS-TALLY-DIGITS
               FOR ALL '0' '1' '2' '3' '4'
                       '5' '6' '7' '8' '9'
           IF WS-TALLY-DIGITS = 5
               MOVE 'Y' TO WS-VALID-ADDR
           ELSE
               MOVE 'INVALID ZIP CODE' TO WS-ERR-MSG
           END-IF.
       2000-APPLY-CHANGE.
           MOVE WS-NEW-LINE1 TO WS-OLD-LINE1
           MOVE WS-NEW-LINE2 TO WS-OLD-LINE2
           MOVE WS-NEW-CITY TO WS-OLD-CITY
           MOVE WS-NEW-STATE TO WS-OLD-STATE
           MOVE WS-NEW-ZIP TO WS-OLD-ZIP
           ACCEPT WS-CHANGE-DATE FROM DATE YYYYMMDD
           MOVE 'CHG-CONFIRMED  ' TO WS-CONFIRMATION.
       3000-DETERMINE-LETTER.
           EVALUATE TRUE
               WHEN REASON-RELOC
                   MOVE 'Y' TO WS-LETTER-FLAG
               WHEN REASON-CORRECT
                   MOVE 'N' TO WS-LETTER-FLAG
               WHEN REASON-SEASONAL
                   MOVE 'Y' TO WS-LETTER-FLAG
               WHEN OTHER
                   MOVE 'Y' TO WS-LETTER-FLAG
           END-EVALUATE.
       4000-BUILD-AUDIT.
           STRING 'ADDR-CHG ' DELIMITED BY SIZE
               WS-ACCT-NUMBER DELIMITED BY ' '
               ' DT=' DELIMITED BY SIZE
               WS-CHANGE-DATE DELIMITED BY SIZE
               ' RSN=' DELIMITED BY SIZE
               WS-CHG-REASON DELIMITED BY SIZE
               INTO WS-AUDIT-REC
           END-STRING.
       5000-OUTPUT.
           DISPLAY 'ADDRESS CHANGE PROCESSING'
           DISPLAY '========================='
           DISPLAY 'ACCOUNT: ' WS-ACCT-NUMBER
           IF ADDR-VALID
               DISPLAY 'STATUS: ' WS-CONFIRMATION
               IF SEND-LETTER
                   DISPLAY 'CONFIRMATION LETTER QUEUED'
               END-IF
           ELSE
               DISPLAY 'STATUS: REJECTED'
               DISPLAY 'ERROR:  ' WS-ERR-MSG
           END-IF.
