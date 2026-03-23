       IDENTIFICATION DIVISION.
       PROGRAM-ID. TREAS-LOCKBOX-PROC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-LOCKBOX-DATA.
           05 WS-LOCKBOX-ID          PIC X(8).
           05 WS-RAW-RECORD          PIC X(120).
       01 WS-PARSED-FIELDS.
           05 WS-REMITTER-NAME       PIC X(30).
           05 WS-INVOICE-NUM         PIC X(15).
           05 WS-PAY-AMOUNT          PIC X(12).
           05 WS-CHECK-NUM           PIC X(10).
       01 WS-AMOUNT-NUM              PIC S9(9)V99 COMP-3.
       01 WS-VALID-FLAG              PIC X VALUE 'N'.
           88 WS-IS-VALID            VALUE 'Y'.
       01 WS-ERROR-MSG               PIC X(40).
       01 WS-MATCH-STATUS            PIC X(1).
           88 WS-MATCHED             VALUE 'M'.
           88 WS-UNMATCHED           VALUE 'U'.
           88 WS-PARTIAL             VALUE 'P'.
       01 WS-EXPECTED-AMT            PIC S9(9)V99 COMP-3.
       01 WS-VARIANCE                PIC S9(7)V99 COMP-3.
       01 WS-FORMATTED-MSG           PIC X(80).
       01 WS-TOTAL-APPLIED           PIC S9(11)V99 COMP-3.
       01 WS-TOTAL-UNAPPLIED         PIC S9(9)V99 COMP-3.
       01 WS-ITEM-COUNT              PIC S9(5) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PARSE-RECORD
           PERFORM 3000-VALIDATE-FIELDS
           IF WS-IS-VALID
               PERFORM 4000-MATCH-INVOICE
               PERFORM 5000-FORMAT-OUTPUT
           END-IF
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE SPACES TO WS-ERROR-MSG
           MOVE 'N' TO WS-VALID-FLAG
           MOVE 0 TO WS-TOTAL-APPLIED
           MOVE 0 TO WS-TOTAL-UNAPPLIED
           MOVE 0 TO WS-ITEM-COUNT.
       2000-PARSE-RECORD.
           UNSTRING WS-RAW-RECORD
               DELIMITED BY '|'
               INTO WS-REMITTER-NAME
                    WS-INVOICE-NUM
                    WS-PAY-AMOUNT
                    WS-CHECK-NUM
           END-UNSTRING.
       3000-VALIDATE-FIELDS.
           IF WS-REMITTER-NAME = SPACES
               MOVE 'MISSING REMITTER NAME' TO WS-ERROR-MSG
           ELSE
               IF WS-PAY-AMOUNT IS NUMERIC
                   MOVE 'Y' TO WS-VALID-FLAG
               ELSE
                   MOVE 'INVALID PAYMENT AMOUNT' TO
                       WS-ERROR-MSG
               END-IF
           END-IF.
       4000-MATCH-INVOICE.
           ADD 1 TO WS-ITEM-COUNT
           IF WS-INVOICE-NUM NOT = SPACES
               COMPUTE WS-VARIANCE =
                   WS-AMOUNT-NUM - WS-EXPECTED-AMT
               IF WS-VARIANCE = 0
                   SET WS-MATCHED TO TRUE
                   ADD WS-AMOUNT-NUM TO WS-TOTAL-APPLIED
               ELSE
                   IF WS-AMOUNT-NUM > 0
                       SET WS-PARTIAL TO TRUE
                       ADD WS-AMOUNT-NUM TO WS-TOTAL-APPLIED
                   ELSE
                       SET WS-UNMATCHED TO TRUE
                       ADD WS-AMOUNT-NUM TO
                           WS-TOTAL-UNAPPLIED
                   END-IF
               END-IF
           ELSE
               SET WS-UNMATCHED TO TRUE
               ADD WS-AMOUNT-NUM TO WS-TOTAL-UNAPPLIED
           END-IF.
       5000-FORMAT-OUTPUT.
           STRING 'LBX ' DELIMITED BY SIZE
                  WS-LOCKBOX-ID DELIMITED BY SIZE
                  ' INV=' DELIMITED BY SIZE
                  WS-INVOICE-NUM DELIMITED BY SIZE
                  ' AMT=' DELIMITED BY SIZE
                  WS-PAY-AMOUNT DELIMITED BY SIZE
                  INTO WS-FORMATTED-MSG
           END-STRING.
       6000-DISPLAY-RESULTS.
           DISPLAY 'LOCKBOX PROCESSING'
           DISPLAY '=================='
           DISPLAY 'LOCKBOX:      ' WS-LOCKBOX-ID
           DISPLAY 'REMITTER:     ' WS-REMITTER-NAME
           DISPLAY 'INVOICE:      ' WS-INVOICE-NUM
           DISPLAY 'AMOUNT:       ' WS-PAY-AMOUNT
           IF WS-MATCHED
               DISPLAY 'MATCH: EXACT'
           END-IF
           IF WS-PARTIAL
               DISPLAY 'MATCH: PARTIAL'
               DISPLAY 'VARIANCE:     ' WS-VARIANCE
           END-IF
           IF WS-UNMATCHED
               DISPLAY 'MATCH: UNMATCHED'
           END-IF
           DISPLAY 'APPLIED:      ' WS-TOTAL-APPLIED
           DISPLAY 'UNAPPLIED:    ' WS-TOTAL-UNAPPLIED
           DISPLAY 'MSG: ' WS-FORMATTED-MSG.
