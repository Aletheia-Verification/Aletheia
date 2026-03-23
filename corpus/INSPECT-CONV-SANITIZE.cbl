       IDENTIFICATION DIVISION.
       PROGRAM-ID. INSPECT-CONV-SANITIZE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-INPUT-DATA              PIC X(80).
       01 WS-CLEANED-DATA            PIC X(80).
       01 WS-UPPER-DATA              PIC X(80).
       01 WS-DIGIT-COUNT             PIC 9(3).
       01 WS-ALPHA-COUNT             PIC 9(3).
       01 WS-SPECIAL-COUNT           PIC 9(3).
       01 WS-SPACE-COUNT             PIC 9(3).
       01 WS-TOTAL-CHARS             PIC 9(3).
       01 WS-CLEAN-FLAG              PIC X VALUE 'N'.
           88 WS-IS-CLEAN            VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-COUNT-CHARS
           PERFORM 3000-CONVERT-UPPER
           PERFORM 4000-CLEAN-SPECIALS
           PERFORM 5000-ASSESS
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE WS-INPUT-DATA TO WS-CLEANED-DATA
           MOVE WS-INPUT-DATA TO WS-UPPER-DATA
           MOVE 0 TO WS-DIGIT-COUNT
           MOVE 0 TO WS-ALPHA-COUNT
           MOVE 0 TO WS-SPECIAL-COUNT
           MOVE 0 TO WS-SPACE-COUNT.
       2000-COUNT-CHARS.
           INSPECT WS-INPUT-DATA
               TALLYING WS-DIGIT-COUNT
               FOR ALL '0' '1' '2' '3' '4'
                       '5' '6' '7' '8' '9'
           INSPECT WS-INPUT-DATA
               TALLYING WS-SPACE-COUNT FOR ALL ' '
           INSPECT WS-INPUT-DATA
               TALLYING WS-SPECIAL-COUNT FOR ALL '-'.
       3000-CONVERT-UPPER.
           INSPECT WS-UPPER-DATA
               CONVERTING
                   'abcdefghijklmnopqrstuvwxyz'
               TO  'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.
       4000-CLEAN-SPECIALS.
           INSPECT WS-CLEANED-DATA
               REPLACING ALL '-' BY ' '
           INSPECT WS-CLEANED-DATA
               REPLACING ALL '/' BY ' '.
       5000-ASSESS.
           COMPUTE WS-TOTAL-CHARS =
               WS-DIGIT-COUNT + WS-SPECIAL-COUNT
           IF WS-SPECIAL-COUNT = 0
               MOVE 'Y' TO WS-CLEAN-FLAG
           END-IF.
       6000-DISPLAY-RESULTS.
           DISPLAY 'DATA SANITIZATION'
           DISPLAY '================='
           DISPLAY 'INPUT:    ' WS-INPUT-DATA
           DISPLAY 'UPPER:    ' WS-UPPER-DATA
           DISPLAY 'CLEANED:  ' WS-CLEANED-DATA
           DISPLAY 'DIGITS:   ' WS-DIGIT-COUNT
           DISPLAY 'SPECIALS: ' WS-SPECIAL-COUNT
           DISPLAY 'SPACES:   ' WS-SPACE-COUNT
           IF WS-IS-CLEAN
               DISPLAY 'STATUS: CLEAN'
           ELSE
               DISPLAY 'STATUS: SANITIZED'
           END-IF.
