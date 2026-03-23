       IDENTIFICATION DIVISION.
       PROGRAM-ID. PAY-ADDENDA-PARSE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ADDENDA-RECORD          PIC X(80).
       01 WS-PARSED-FIELDS.
           05 WS-RECORD-TYPE         PIC X(2).
           05 WS-ADDENDA-TYPE        PIC X(2).
           05 WS-PAYMENT-INFO        PIC X(40).
           05 WS-TRACE-NUM           PIC X(15).
           05 WS-SEQUENCE-NUM        PIC X(4).
       01 WS-PAYMENT-DETAIL.
           05 WS-REF-NUM             PIC X(20).
           05 WS-INVOICE-NUM         PIC X(15).
           05 WS-DATE-FIELD          PIC X(8).
           05 WS-MEMO-TEXT           PIC X(30).
       01 WS-PARSE-STATUS            PIC X(1).
           88 WS-PARSE-OK            VALUE 'Y'.
           88 WS-PARSE-FAIL          VALUE 'N'.
       01 WS-ADDENDA-CODE            PIC X(2).
           88 WS-RETURNS             VALUE '99'.
           88 WS-PAYMENT-REL         VALUE '05'.
           88 WS-ADDENDA-CTX         VALUE '06'.
       01 WS-FORMATTED-OUTPUT        PIC X(80).
       01 WS-ERROR-MSG               PIC X(40).
       01 WS-FIELD-COUNT             PIC 9(2).
       01 WS-TEMP-FIELD              PIC X(40).
       01 WS-VALID-FLAG              PIC X VALUE 'N'.
           88 WS-IS-VALID-REC        VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-EXTRACT-FIELDS
           PERFORM 3000-VALIDATE-TYPE
           IF WS-PARSE-OK
               PERFORM 4000-PARSE-PAYMENT-INFO
               PERFORM 5000-FORMAT-OUTPUT
           END-IF
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE SPACES TO WS-PARSED-FIELDS
           MOVE SPACES TO WS-PAYMENT-DETAIL
           MOVE SPACES TO WS-ERROR-MSG
           SET WS-PARSE-FAIL TO TRUE
           MOVE 0 TO WS-FIELD-COUNT.
       2000-EXTRACT-FIELDS.
           IF WS-ADDENDA-RECORD = SPACES
               MOVE 'EMPTY ADDENDA RECORD' TO WS-ERROR-MSG
           ELSE
               MOVE WS-ADDENDA-RECORD(1:2) TO
                   WS-RECORD-TYPE
               MOVE WS-ADDENDA-RECORD(3:2) TO
                   WS-ADDENDA-TYPE
               MOVE WS-ADDENDA-RECORD(5:40) TO
                   WS-PAYMENT-INFO
               MOVE WS-ADDENDA-RECORD(45:15) TO
                   WS-TRACE-NUM
               MOVE WS-ADDENDA-RECORD(60:4) TO
                   WS-SEQUENCE-NUM
           END-IF.
       3000-VALIDATE-TYPE.
           IF WS-RECORD-TYPE = '07'
               MOVE WS-ADDENDA-TYPE TO WS-ADDENDA-CODE
               IF WS-RETURNS OR WS-PAYMENT-REL
                   OR WS-ADDENDA-CTX
                   SET WS-PARSE-OK TO TRUE
               ELSE
                   MOVE 'UNKNOWN ADDENDA TYPE' TO
                       WS-ERROR-MSG
               END-IF
           ELSE
               MOVE 'NOT AN ADDENDA RECORD' TO
                   WS-ERROR-MSG
           END-IF.
       4000-PARSE-PAYMENT-INFO.
           UNSTRING WS-PAYMENT-INFO
               DELIMITED BY '*'
               INTO WS-REF-NUM
                    WS-INVOICE-NUM
                    WS-DATE-FIELD
           END-UNSTRING
           IF WS-REF-NUM NOT = SPACES
               ADD 1 TO WS-FIELD-COUNT
           END-IF
           IF WS-INVOICE-NUM NOT = SPACES
               ADD 1 TO WS-FIELD-COUNT
           END-IF
           IF WS-DATE-FIELD NOT = SPACES
               IF WS-DATE-FIELD IS NUMERIC
                   ADD 1 TO WS-FIELD-COUNT
               END-IF
           END-IF.
       5000-FORMAT-OUTPUT.
           STRING 'TYPE=' DELIMITED BY SIZE
                  WS-ADDENDA-CODE DELIMITED BY SIZE
                  ' REF=' DELIMITED BY SIZE
                  WS-REF-NUM DELIMITED BY SIZE
                  ' INV=' DELIMITED BY SIZE
                  WS-INVOICE-NUM DELIMITED BY SIZE
                  INTO WS-FORMATTED-OUTPUT
           END-STRING.
       6000-DISPLAY-RESULTS.
           DISPLAY 'ACH ADDENDA PARSER'
           DISPLAY '=================='
           IF WS-PARSE-OK
               DISPLAY 'STATUS: PARSED'
               DISPLAY 'TYPE:      ' WS-ADDENDA-CODE
               DISPLAY 'REF NUM:   ' WS-REF-NUM
               DISPLAY 'INVOICE:   ' WS-INVOICE-NUM
               DISPLAY 'DATE:      ' WS-DATE-FIELD
               DISPLAY 'TRACE:     ' WS-TRACE-NUM
               DISPLAY 'FIELDS:    ' WS-FIELD-COUNT
               DISPLAY 'OUTPUT:    ' WS-FORMATTED-OUTPUT
           ELSE
               DISPLAY 'STATUS: FAILED'
               DISPLAY 'ERROR: ' WS-ERROR-MSG
           END-IF.
