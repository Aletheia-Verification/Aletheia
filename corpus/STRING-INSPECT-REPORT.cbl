       IDENTIFICATION DIVISION.
       PROGRAM-ID. STRING-INSPECT-REPORT.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01 WS-RAW-INPUT.
          05 WS-RAW-TXN-LINE         PIC X(120).
          05 WS-RAW-FIELD-1           PIC X(30).
          05 WS-RAW-FIELD-2           PIC X(30).
          05 WS-RAW-FIELD-3           PIC X(30).
          05 WS-RAW-FIELD-4           PIC X(20).

       01 WS-PARSED-FIELDS.
          05 WS-ACCT-NUM              PIC X(12).
          05 WS-TXN-DATE              PIC X(10).
          05 WS-TXN-DESC              PIC X(40).
          05 WS-TXN-AMOUNT-STR        PIC X(15).
          05 WS-TXN-AMOUNT            PIC S9(9)V99 COMP-3.

       01 WS-CLEAN-FIELDS.
          05 WS-CLEAN-DESC            PIC X(40).
          05 WS-CLEAN-ACCT            PIC X(12).
          05 WS-CLEAN-DATE            PIC X(10).

       01 WS-INSPECT-COUNTS.
          05 WS-DIGIT-COUNT           PIC 9(3).
          05 WS-ALPHA-COUNT           PIC 9(3).
          05 WS-SPACE-COUNT           PIC 9(3).
          05 WS-SPECIAL-COUNT         PIC 9(3).
          05 WS-STAR-COUNT            PIC 9(3).
          05 WS-HASH-COUNT            PIC 9(3).

       01 WS-REPORT-LINE.
          05 WS-RPT-ACCT              PIC X(14).
          05 WS-RPT-DATE              PIC X(12).
          05 WS-RPT-DESC              PIC X(42).
          05 WS-RPT-AMOUNT            PIC X(16).

       01 WS-FORMATTED-LINE          PIC X(100).
       01 WS-HEADER-LINE             PIC X(100).
       01 WS-SEPARATOR-LINE          PIC X(100).

       01 WS-RUNNING-TOTALS.
          05 WS-DEBIT-TOTAL           PIC S9(11)V99 COMP-3.
          05 WS-CREDIT-TOTAL          PIC S9(11)V99 COMP-3.
          05 WS-NET-TOTAL             PIC S9(11)V99 COMP-3.
          05 WS-RECORD-COUNT          PIC 9(6).
          05 WS-CLEAN-COUNT           PIC 9(6).
          05 WS-DIRTY-COUNT           PIC 9(6).

       01 WS-CONTROL.
          05 WS-MAX-RECORDS           PIC 9(4) VALUE 1000.
          05 WS-PROCESS-IDX           PIC 9(4).
          05 WS-VALID-FLAG            PIC X(1).
             88 IS-VALID-RECORD       VALUE 'Y'.
             88 NOT-VALID-RECORD      VALUE 'N'.

       01 WS-WORK-FIELDS.
          05 WS-TEMP-STR              PIC X(80).
          05 WS-TEMP-NUM              PIC S9(9)V99 COMP-3.
          05 WS-DELIM-POS             PIC 9(3).

       PROCEDURE DIVISION.

       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-BUILD-HEADER
           PERFORM 3000-PROCESS-RECORD
           PERFORM 4000-BUILD-TOTALS-LINE
           PERFORM 5000-DISPLAY-SUMMARY
           STOP RUN.

       1000-INITIALIZE.
           INITIALIZE WS-PARSED-FIELDS
           INITIALIZE WS-CLEAN-FIELDS
           INITIALIZE WS-INSPECT-COUNTS
           INITIALIZE WS-RUNNING-TOTALS
           MOVE 0 TO WS-RECORD-COUNT
           MOVE 0 TO WS-CLEAN-COUNT
           MOVE 0 TO WS-DIRTY-COUNT
           SET IS-VALID-RECORD TO TRUE.

       2000-BUILD-HEADER.
           INITIALIZE WS-HEADER-LINE
           STRING "ACCOUNT" DELIMITED BY SIZE
              "       " DELIMITED BY SIZE
              "DATE" DELIMITED BY SIZE
              "        " DELIMITED BY SIZE
              "DESCRIPTION" DELIMITED BY SIZE
              INTO WS-HEADER-LINE
           END-STRING
           DISPLAY WS-HEADER-LINE
           INITIALIZE WS-SEPARATOR-LINE
           STRING "============" DELIMITED BY SIZE
              "  " DELIMITED BY SIZE
              "==========" DELIMITED BY SIZE
              "  " DELIMITED BY SIZE
              "========================================" DELIMITED BY SIZE
              INTO WS-SEPARATOR-LINE
           END-STRING
           DISPLAY WS-SEPARATOR-LINE.

       3000-PROCESS-RECORD.
           PERFORM 3100-PARSE-INPUT
           PERFORM 3200-CLEAN-DATA
           PERFORM 3300-VALIDATE-FIELDS
           PERFORM 3400-FORMAT-OUTPUT
           ADD 1 TO WS-RECORD-COUNT
           IF IS-VALID-RECORD
              ADD 1 TO WS-CLEAN-COUNT
           ELSE
              ADD 1 TO WS-DIRTY-COUNT
           END-IF
           IF WS-TXN-AMOUNT > 0
              ADD WS-TXN-AMOUNT TO WS-CREDIT-TOTAL
           ELSE
              ADD WS-TXN-AMOUNT TO WS-DEBIT-TOTAL
           END-IF.

       3100-PARSE-INPUT.
           INITIALIZE WS-PARSED-FIELDS
           UNSTRING WS-RAW-TXN-LINE
              DELIMITED BY '|'
              INTO WS-ACCT-NUM
                   WS-TXN-DATE
                   WS-TXN-DESC
                   WS-TXN-AMOUNT-STR
           END-UNSTRING.

       3200-CLEAN-DATA.
           MOVE WS-TXN-DESC TO WS-CLEAN-DESC
           INSPECT WS-CLEAN-DESC
              REPLACING ALL '*' BY ' '
           INSPECT WS-CLEAN-DESC
              REPLACING ALL '#' BY ' '
           INSPECT WS-CLEAN-DESC
              REPLACING ALL '@' BY ' '
           MOVE WS-ACCT-NUM TO WS-CLEAN-ACCT
           INSPECT WS-CLEAN-ACCT
              REPLACING ALL '-' BY ' '
           MOVE WS-TXN-DATE TO WS-CLEAN-DATE
           INSPECT WS-CLEAN-DATE
              REPLACING ALL '/' BY '-'.

       3300-VALIDATE-FIELDS.
           SET IS-VALID-RECORD TO TRUE
           MOVE 0 TO WS-DIGIT-COUNT
           MOVE 0 TO WS-STAR-COUNT
           MOVE 0 TO WS-HASH-COUNT
           INSPECT WS-ACCT-NUM
              TALLYING WS-DIGIT-COUNT FOR ALL '0'
           INSPECT WS-ACCT-NUM
              TALLYING WS-DIGIT-COUNT FOR ALL '1'
           INSPECT WS-ACCT-NUM
              TALLYING WS-DIGIT-COUNT FOR ALL '2'
           INSPECT WS-ACCT-NUM
              TALLYING WS-DIGIT-COUNT FOR ALL '3'
           INSPECT WS-ACCT-NUM
              TALLYING WS-DIGIT-COUNT FOR ALL '4'
           INSPECT WS-ACCT-NUM
              TALLYING WS-DIGIT-COUNT FOR ALL '5'
           INSPECT WS-ACCT-NUM
              TALLYING WS-DIGIT-COUNT FOR ALL '6'
           INSPECT WS-ACCT-NUM
              TALLYING WS-DIGIT-COUNT FOR ALL '7'
           INSPECT WS-ACCT-NUM
              TALLYING WS-DIGIT-COUNT FOR ALL '8'
           INSPECT WS-ACCT-NUM
              TALLYING WS-DIGIT-COUNT FOR ALL '9'
           IF WS-DIGIT-COUNT < 6
              SET NOT-VALID-RECORD TO TRUE
           END-IF
           INSPECT WS-TXN-DESC
              TALLYING WS-STAR-COUNT FOR ALL '*'
           INSPECT WS-TXN-DESC
              TALLYING WS-HASH-COUNT FOR ALL '#'
           COMPUTE WS-SPECIAL-COUNT =
              WS-STAR-COUNT + WS-HASH-COUNT
           IF WS-SPECIAL-COUNT > 5
              SET NOT-VALID-RECORD TO TRUE
           END-IF.

       3400-FORMAT-OUTPUT.
           INITIALIZE WS-FORMATTED-LINE
           STRING WS-CLEAN-ACCT DELIMITED BY SIZE
              "  " DELIMITED BY SIZE
              WS-CLEAN-DATE DELIMITED BY SIZE
              "  " DELIMITED BY SIZE
              WS-CLEAN-DESC DELIMITED BY SIZE
              INTO WS-FORMATTED-LINE
           END-STRING
           DISPLAY WS-FORMATTED-LINE.

       4000-BUILD-TOTALS-LINE.
           COMPUTE WS-NET-TOTAL =
              WS-CREDIT-TOTAL + WS-DEBIT-TOTAL
           DISPLAY WS-SEPARATOR-LINE.

       5000-DISPLAY-SUMMARY.
           DISPLAY "===== REPORT SUMMARY ====="
           DISPLAY "TOTAL RECORDS: " WS-RECORD-COUNT
           DISPLAY "CLEAN RECORDS: " WS-CLEAN-COUNT
           DISPLAY "DIRTY RECORDS: " WS-DIRTY-COUNT
           DISPLAY "CREDITS: " WS-CREDIT-TOTAL
           DISPLAY "DEBITS: " WS-DEBIT-TOTAL
           DISPLAY "NET: " WS-NET-TOTAL.
