       IDENTIFICATION DIVISION.
       PROGRAM-ID. DATA-MASKING-ENGINE.
      *================================================================*
      * PCI COMPLIANCE DATA MASKING ENGINE                             *
      * Masks sensitive card data, converts names to uppercase,        *
      * tallies sensitive markers, assembles masked output using       *
      * STRING with POINTER for progressive output assembly.           *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- Input Fields ---
       01  WS-CARD-NUMBER             PIC X(16).
       01  WS-CARD-FIRST-4            PIC X(4).
       01  WS-CARD-LAST-4             PIC X(4).
       01  WS-CARD-MASKED             PIC X(16).
       01  WS-CUSTOMER-NAME           PIC X(30).
       01  WS-CUSTOMER-SSN            PIC X(11).
       01  WS-SSN-MASKED              PIC X(11).
       01  WS-SSN-LAST-4              PIC X(4).
       01  WS-CUSTOMER-EMAIL          PIC X(40).
       01  WS-EMAIL-MASKED            PIC X(40).
      *--- Masking Constants ---
       01  WS-MASK-CHAR               PIC X(1) VALUE '*'.
       01  WS-CARD-MASK-MID           PIC X(8) VALUE '********'.
       01  WS-SSN-MASK-PREFIX         PIC X(7) VALUE '***-**-'.
      *--- Output Assembly ---
       01  WS-OUTPUT-BUFFER           PIC X(200).
       01  WS-OUTPUT-PTR              PIC 9(3).
       01  WS-FIELD-SEPARATOR         PIC X(3) VALUE ' | '.
       01  WS-LABEL-NAME              PIC X(6) VALUE 'NAME: '.
       01  WS-LABEL-CARD              PIC X(6) VALUE 'CARD: '.
       01  WS-LABEL-SSN               PIC X(5) VALUE 'SSN: '.
      *--- Tallying Fields ---
       01  WS-SENSITIVE-MARKERS       PIC S9(5) COMP-3.
       01  WS-CARD-PATTERNS           PIC S9(5) COMP-3.
       01  WS-SSN-PATTERNS            PIC S9(5) COMP-3.
       01  WS-AUDIT-LOG               PIC X(80).
       01  WS-MARKER-STRING           PIC X(80).
      *--- Processing Flags ---
       01  WS-MASK-CARD-FLAG          PIC X(1).
       01  WS-MASK-SSN-FLAG           PIC X(1).
       01  WS-MASK-EMAIL-FLAG         PIC X(1).
       01  WS-FIELDS-MASKED           PIC 9(3).
       01  WS-FIELDS-TOTAL            PIC 9(3).
       01  WS-COMPLIANCE-STATUS       PIC X(15).
      *--- Work Fields ---
       01  WS-WORK-IDX                PIC 9(3).
       01  WS-AT-SIGN-COUNT           PIC 9(3).
       01  WS-EMAIL-PREFIX            PIC X(5).
       01  WS-EMAIL-MASKED-PFX        PIC X(5) VALUE '*****'.
       01  WS-EMAIL-DOMAIN            PIC X(35).
      *--- Masking Statistics ---
       01  WS-TOTAL-FIELDS-SCANNED    PIC 9(5).
       01  WS-CHARS-MASKED            PIC 9(7).
       01  WS-CARD-DIGITS-MASKED      PIC 9(3).
       01  WS-SSN-DIGITS-MASKED       PIC 9(3).
       01  WS-MASKING-RATIO           PIC S9(3)V9(4) COMP-3.
       01  WS-PROCESSING-TIME         PIC X(10).
       01  WS-BATCH-ID                PIC X(12).

       PROCEDURE DIVISION.
       MAIN-PROGRAM.
           PERFORM INITIALIZE-FIELDS
           PERFORM LOAD-TEST-DATA
           PERFORM COUNT-SENSITIVE-DATA
           PERFORM MASK-CARD-NUMBER THRU
                   MASK-CARD-NUMBER-EXIT
           PERFORM MASK-SSN THRU
                   MASK-SSN-EXIT
           PERFORM MASK-CUSTOMER-NAME THRU
                   MASK-CUSTOMER-NAME-EXIT
           PERFORM ASSEMBLE-OUTPUT
           PERFORM COMPUTE-STATISTICS
           PERFORM DISPLAY-RESULTS
           STOP RUN.

       INITIALIZE-FIELDS.
           MOVE SPACES TO WS-OUTPUT-BUFFER
           MOVE 1 TO WS-OUTPUT-PTR
           MOVE 0 TO WS-SENSITIVE-MARKERS
           MOVE 0 TO WS-CARD-PATTERNS
           MOVE 0 TO WS-SSN-PATTERNS
           MOVE 0 TO WS-FIELDS-MASKED
           MOVE 3 TO WS-FIELDS-TOTAL
           MOVE 'Y' TO WS-MASK-CARD-FLAG
           MOVE 'Y' TO WS-MASK-SSN-FLAG
           MOVE 'Y' TO WS-MASK-EMAIL-FLAG
           MOVE SPACES TO WS-CARD-MASKED
           MOVE SPACES TO WS-SSN-MASKED
           MOVE SPACES TO WS-EMAIL-MASKED
           MOVE 0 TO WS-TOTAL-FIELDS-SCANNED
           MOVE 0 TO WS-CHARS-MASKED
           MOVE 0 TO WS-CARD-DIGITS-MASKED
           MOVE 0 TO WS-SSN-DIGITS-MASKED
           MOVE 'BATCH-00001' TO WS-BATCH-ID
           MOVE '00:00:00' TO WS-PROCESSING-TIME.

       LOAD-TEST-DATA.
           MOVE '4532015112830366' TO WS-CARD-NUMBER
           MOVE 'john q. public' TO WS-CUSTOMER-NAME
           MOVE '123-45-6789' TO WS-CUSTOMER-SSN
           MOVE 'john@example.com' TO WS-CUSTOMER-EMAIL
           MOVE 'CC:4532 SSN:123 CC:9876 SSN:456 CC:5555'
               TO WS-MARKER-STRING.

       COUNT-SENSITIVE-DATA.
           MOVE 0 TO WS-CARD-PATTERNS
           MOVE 0 TO WS-SSN-PATTERNS
           INSPECT WS-MARKER-STRING
               TALLYING WS-CARD-PATTERNS
               FOR ALL 'CC:'
           INSPECT WS-MARKER-STRING
               TALLYING WS-SSN-PATTERNS
               FOR ALL 'SSN:'
           COMPUTE WS-SENSITIVE-MARKERS =
               WS-CARD-PATTERNS + WS-SSN-PATTERNS.

       MASK-CARD-NUMBER.
           IF WS-MASK-CARD-FLAG = 'Y'
               MOVE WS-CARD-NUMBER(1:4) TO WS-CARD-FIRST-4
               MOVE WS-CARD-NUMBER(13:4) TO WS-CARD-LAST-4
               STRING WS-CARD-FIRST-4 DELIMITED BY SIZE
                      WS-CARD-MASK-MID DELIMITED BY SIZE
                      WS-CARD-LAST-4 DELIMITED BY SIZE
                   INTO WS-CARD-MASKED
               END-STRING
               ADD 1 TO WS-FIELDS-MASKED
           ELSE
               MOVE WS-CARD-NUMBER TO WS-CARD-MASKED
           END-IF.

       MASK-CARD-NUMBER-EXIT.
           EXIT.

       MASK-SSN.
           IF WS-MASK-SSN-FLAG = 'Y'
               MOVE WS-CUSTOMER-SSN(8:4) TO WS-SSN-LAST-4
               STRING WS-SSN-MASK-PREFIX DELIMITED BY SIZE
                      WS-SSN-LAST-4 DELIMITED BY SIZE
                   INTO WS-SSN-MASKED
               END-STRING
               ADD 1 TO WS-FIELDS-MASKED
           ELSE
               MOVE WS-CUSTOMER-SSN TO WS-SSN-MASKED
           END-IF.

       MASK-SSN-EXIT.
           EXIT.

       MASK-CUSTOMER-NAME.
           INSPECT WS-CUSTOMER-NAME
               CONVERTING 'abcdefghijklmnopqrstuvwxyz'
               TO         'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
           ADD 1 TO WS-FIELDS-MASKED.

       MASK-CUSTOMER-NAME-EXIT.
           EXIT.

       ASSEMBLE-OUTPUT.
           MOVE SPACES TO WS-OUTPUT-BUFFER
           MOVE 1 TO WS-OUTPUT-PTR
           STRING WS-LABEL-NAME DELIMITED BY SIZE
                  WS-CUSTOMER-NAME DELIMITED BY SIZE
                  WS-FIELD-SEPARATOR DELIMITED BY SIZE
                  WS-LABEL-CARD DELIMITED BY SIZE
                  WS-CARD-MASKED DELIMITED BY SIZE
                  WS-FIELD-SEPARATOR DELIMITED BY SIZE
                  WS-LABEL-SSN DELIMITED BY SIZE
                  WS-SSN-MASKED DELIMITED BY SIZE
               INTO WS-OUTPUT-BUFFER
               WITH POINTER WS-OUTPUT-PTR
           END-STRING
           IF WS-FIELDS-MASKED = WS-FIELDS-TOTAL
               MOVE 'FULLY MASKED' TO WS-COMPLIANCE-STATUS
           ELSE
               MOVE 'PARTIAL MASK' TO WS-COMPLIANCE-STATUS
           END-IF.

       COMPUTE-STATISTICS.
           MOVE 8 TO WS-CARD-DIGITS-MASKED
           MOVE 7 TO WS-SSN-DIGITS-MASKED
           COMPUTE WS-CHARS-MASKED =
               WS-CARD-DIGITS-MASKED + WS-SSN-DIGITS-MASKED
           ADD 3 TO WS-TOTAL-FIELDS-SCANNED
           IF WS-TOTAL-FIELDS-SCANNED > 0
               COMPUTE WS-MASKING-RATIO =
                   WS-FIELDS-MASKED / WS-TOTAL-FIELDS-SCANNED
           ELSE
               MOVE 0 TO WS-MASKING-RATIO
           END-IF.

       DISPLAY-RESULTS.
           DISPLAY 'DATA MASKING REPORT'
           DISPLAY '==================='
           DISPLAY 'MASKED RECORD:'
           DISPLAY WS-OUTPUT-BUFFER
           DISPLAY ' '
           DISPLAY 'CARD MASKED:    ' WS-CARD-MASKED
           DISPLAY 'SSN MASKED:     ' WS-SSN-MASKED
           DISPLAY 'NAME UPPER:     ' WS-CUSTOMER-NAME
           DISPLAY ' '
           DISPLAY 'SENSITIVE MARKERS FOUND: '
                   WS-SENSITIVE-MARKERS
           DISPLAY 'CARD PATTERNS:   ' WS-CARD-PATTERNS
           DISPLAY 'SSN PATTERNS:    ' WS-SSN-PATTERNS
           DISPLAY 'FIELDS MASKED:   ' WS-FIELDS-MASKED
           DISPLAY 'COMPLIANCE:      ' WS-COMPLIANCE-STATUS
           DISPLAY ' '
           DISPLAY 'MASKING STATISTICS:'
           DISPLAY 'BATCH ID:        ' WS-BATCH-ID
           DISPLAY 'FIELDS SCANNED:  ' WS-TOTAL-FIELDS-SCANNED
           DISPLAY 'CHARS MASKED:    ' WS-CHARS-MASKED
           DISPLAY 'CARD DIGITS:     ' WS-CARD-DIGITS-MASKED
           DISPLAY 'SSN DIGITS:      ' WS-SSN-DIGITS-MASKED
           DISPLAY 'MASKING RATIO:   ' WS-MASKING-RATIO.
