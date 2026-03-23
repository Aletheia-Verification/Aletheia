       IDENTIFICATION DIVISION.
       PROGRAM-ID. UNSTRING-DELIM-PARSER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-INPUT-RECORD            PIC X(120).
       01 WS-FIELD-1                 PIC X(20).
       01 WS-FIELD-2                 PIC X(20).
       01 WS-FIELD-3                 PIC X(20).
       01 WS-FIELD-4                 PIC X(20).
       01 WS-DELIM-1                 PIC X(1).
       01 WS-DELIM-2                 PIC X(1).
       01 WS-DELIM-3                 PIC X(1).
       01 WS-COUNT-1                 PIC 9(3).
       01 WS-COUNT-2                 PIC 9(3).
       01 WS-COUNT-3                 PIC 9(3).
       01 WS-COUNT-4                 PIC 9(3).
       01 WS-TOTAL-FIELDS            PIC 9(2).
       01 WS-VALID-FLAG              PIC X VALUE 'N'.
           88 WS-IS-VALID            VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PARSE-RECORD
           PERFORM 3000-VALIDATE
           PERFORM 4000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE SPACES TO WS-FIELD-1
           MOVE SPACES TO WS-FIELD-2
           MOVE SPACES TO WS-FIELD-3
           MOVE SPACES TO WS-FIELD-4
           MOVE 0 TO WS-COUNT-1
           MOVE 0 TO WS-COUNT-2
           MOVE 0 TO WS-COUNT-3
           MOVE 0 TO WS-COUNT-4
           MOVE 0 TO WS-TOTAL-FIELDS.
       2000-PARSE-RECORD.
           UNSTRING WS-INPUT-RECORD
               DELIMITED BY ','
               INTO WS-FIELD-1
                   DELIMITER IN WS-DELIM-1
                   COUNT IN WS-COUNT-1
                    WS-FIELD-2
                   DELIMITER IN WS-DELIM-2
                   COUNT IN WS-COUNT-2
                    WS-FIELD-3
                   DELIMITER IN WS-DELIM-3
                   COUNT IN WS-COUNT-3
                    WS-FIELD-4
                   COUNT IN WS-COUNT-4
           END-UNSTRING.
       3000-VALIDATE.
           IF WS-COUNT-1 > 0
               ADD 1 TO WS-TOTAL-FIELDS
           END-IF
           IF WS-COUNT-2 > 0
               ADD 1 TO WS-TOTAL-FIELDS
           END-IF
           IF WS-COUNT-3 > 0
               ADD 1 TO WS-TOTAL-FIELDS
           END-IF
           IF WS-COUNT-4 > 0
               ADD 1 TO WS-TOTAL-FIELDS
           END-IF
           IF WS-TOTAL-FIELDS >= 2
               MOVE 'Y' TO WS-VALID-FLAG
           END-IF
           IF WS-FIELD-1 IS NUMERIC
               DISPLAY 'FIELD 1 IS NUMERIC'
           END-IF.
       4000-DISPLAY-RESULTS.
           DISPLAY 'UNSTRING DELIMITER PARSER'
           DISPLAY '========================='
           DISPLAY 'FIELD 1: ' WS-FIELD-1
               ' LEN=' WS-COUNT-1
           DISPLAY 'FIELD 2: ' WS-FIELD-2
               ' LEN=' WS-COUNT-2
           DISPLAY 'FIELD 3: ' WS-FIELD-3
               ' LEN=' WS-COUNT-3
           DISPLAY 'FIELD 4: ' WS-FIELD-4
               ' LEN=' WS-COUNT-4
           DISPLAY 'TOTAL FIELDS: ' WS-TOTAL-FIELDS
           IF WS-IS-VALID
               DISPLAY 'STATUS: VALID'
           ELSE
               DISPLAY 'STATUS: INSUFFICIENT FIELDS'
           END-IF.
