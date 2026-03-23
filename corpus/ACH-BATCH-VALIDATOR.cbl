       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACH-BATCH-VALIDATOR.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ACH-FILE ASSIGN TO 'ACH.DAT'
               FILE STATUS IS WS-ACH-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD ACH-FILE.
       01 ACH-RECORD.
           05 ACH-REC-TYPE        PIC X(1).
           05 ACH-ROUTING         PIC X(9).
           05 ACH-ACCOUNT         PIC X(17).
           05 ACH-AMOUNT          PIC 9(10)V99.
           05 ACH-TRAN-CODE       PIC X(2).
           05 ACH-COMPANY-ID      PIC X(10).
           05 ACH-ENTRY-DESC      PIC X(10).
           05 ACH-TRACE-NUM       PIC X(15).
           05 ACH-FILLER          PIC X(14).
       WORKING-STORAGE SECTION.
       01 WS-ACH-STATUS           PIC XX.
       01 WS-EOF-FLAG             PIC X VALUE 'N'.
           88 WS-EOF              VALUE 'Y'.
       01 WS-REC-TYPE-FLAG        PIC X.
           88 WS-BATCH-HEADER     VALUE '5'.
           88 WS-DETAIL-REC       VALUE '6'.
           88 WS-BATCH-TRAILER    VALUE '8'.
           88 WS-FILE-HEADER      VALUE '1'.
           88 WS-FILE-TRAILER     VALUE '9'.
       01 WS-TRAN-TYPE            PIC X(2).
           88 WS-IS-DEBIT         VALUE '27' '37'.
           88 WS-IS-CREDIT        VALUE '22' '32'.
       01 WS-COUNTERS.
           05 WS-RECORD-COUNT     PIC S9(7) COMP-3.
           05 WS-DETAIL-COUNT     PIC S9(7) COMP-3.
           05 WS-BATCH-COUNT      PIC S9(5) COMP-3.
           05 WS-ERROR-COUNT      PIC S9(5) COMP-3.
           05 WS-DEBIT-COUNT      PIC S9(7) COMP-3.
           05 WS-CREDIT-COUNT     PIC S9(7) COMP-3.
       01 WS-AMOUNTS.
           05 WS-TOTAL-DEBITS     PIC S9(11)V99 COMP-3.
           05 WS-TOTAL-CREDITS    PIC S9(11)V99 COMP-3.
           05 WS-BATCH-DEBITS     PIC S9(11)V99 COMP-3.
           05 WS-BATCH-CREDITS    PIC S9(11)V99 COMP-3.
           05 WS-NET-AMOUNT       PIC S9(11)V99 COMP-3.
           05 WS-IMBALANCE        PIC S9(11)V99 COMP-3.
       01 WS-HASH-FIELDS.
           05 WS-HASH-TOTAL       PIC S9(13) COMP-3.
           05 WS-BATCH-HASH       PIC S9(13) COMP-3.
           05 WS-ROUTING-NUM      PIC 9(9).
           05 WS-ROUTING-BODY     PIC 9(8).
           05 WS-CHECK-DIGIT      PIC 9(1).
           05 WS-CALC-CHECK       PIC S9(3) COMP-3.
           05 WS-DIGIT-1          PIC 9(1).
           05 WS-DIGIT-2          PIC 9(1).
           05 WS-DIGIT-3          PIC 9(1).
           05 WS-DIGIT-4          PIC 9(1).
           05 WS-DIGIT-5          PIC 9(1).
           05 WS-DIGIT-6          PIC 9(1).
           05 WS-DIGIT-7          PIC 9(1).
           05 WS-DIGIT-8          PIC 9(1).
           05 WS-DIGIT-SUM        PIC S9(5) COMP-3.
           05 WS-REMAINDER        PIC S9(3) COMP-3.
           05 WS-EXPECTED-CHECK   PIC S9(3) COMP-3.
       01 WS-CLEAN-ACCOUNT        PIC X(17).
       01 WS-SPACE-COUNT          PIC S9(3) COMP-3.
       01 WS-DASH-COUNT           PIC S9(3) COMP-3.
       01 WS-ERROR-MSG            PIC X(80).
       01 WS-ERROR-DETAIL         PIC X(40).
       01 WS-ERROR-CODE           PIC X(4).
       01 WS-ERROR-LINE           PIC X(80).
       01 WS-VALID-FLAG           PIC X VALUE 'Y'.
           88 WS-VALID            VALUE 'Y'.
           88 WS-INVALID          VALUE 'N'.
       01 WS-BATCH-ACTIVE         PIC X VALUE 'N'.
           88 WS-IN-BATCH         VALUE 'Y'.
       01 WS-BATCH-DETAIL-CT      PIC S9(7) COMP-3.
       01 WS-BATCH-ENTRY-HASH     PIC S9(13) COMP-3.
       01 WS-VELOCITY-TABLE.
           05 WS-VEL-ENTRY OCCURS 20.
               10 WS-VEL-ROUTING  PIC X(9).
               10 WS-VEL-COUNT    PIC S9(5) COMP-3.
               10 WS-VEL-AMOUNT   PIC S9(11)V99 COMP-3.
       01 WS-VEL-IDX              PIC 9(2).
       01 WS-VEL-FOUND            PIC X VALUE 'N'.
           88 WS-VEL-MATCH        VALUE 'Y'.
       01 WS-VEL-LIMIT            PIC S9(5) VALUE 100.
       01 WS-AMT-LIMIT            PIC S9(11)V99 VALUE 100000.00.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 0100-INITIALIZE
           PERFORM 0200-OPEN-ACH
           PERFORM 0300-READ-ACH UNTIL WS-EOF
           PERFORM 0400-FINAL-VALIDATION
           PERFORM 0500-PRINT-RESULTS
           PERFORM 0600-CLOSE-ACH
           STOP RUN.
       0100-INITIALIZE.
           INITIALIZE WS-COUNTERS
           INITIALIZE WS-AMOUNTS
           INITIALIZE WS-HASH-FIELDS
           MOVE 0 TO WS-RECORD-COUNT
           MOVE 0 TO WS-DETAIL-COUNT
           MOVE 0 TO WS-BATCH-COUNT
           MOVE 0 TO WS-ERROR-COUNT
           MOVE 0 TO WS-TOTAL-DEBITS
           MOVE 0 TO WS-TOTAL-CREDITS
           MOVE 0 TO WS-HASH-TOTAL
           PERFORM VARYING WS-VEL-IDX FROM 1 BY 1
               UNTIL WS-VEL-IDX > 20
               MOVE SPACES TO WS-VEL-ROUTING(WS-VEL-IDX)
               MOVE 0 TO WS-VEL-COUNT(WS-VEL-IDX)
               MOVE 0 TO WS-VEL-AMOUNT(WS-VEL-IDX)
           END-PERFORM.
       0200-OPEN-ACH.
           OPEN INPUT ACH-FILE.
       0300-READ-ACH.
           READ ACH-FILE
               AT END SET WS-EOF TO TRUE
               NOT AT END PERFORM 1000-PROCESS-RECORD.
       1000-PROCESS-RECORD.
           ADD 1 TO WS-RECORD-COUNT
           MOVE ACH-REC-TYPE TO WS-REC-TYPE-FLAG
           EVALUATE TRUE
               WHEN WS-FILE-HEADER
                   PERFORM 1100-PROCESS-FILE-HDR
               WHEN WS-BATCH-HEADER
                   PERFORM 1200-PROCESS-BATCH-HDR
               WHEN WS-DETAIL-REC
                   PERFORM 1300-PROCESS-DETAIL
               WHEN WS-BATCH-TRAILER
                   PERFORM 1400-PROCESS-BATCH-TRL
               WHEN WS-FILE-TRAILER
                   PERFORM 1500-PROCESS-FILE-TRL
               WHEN OTHER
                   ADD 1 TO WS-ERROR-COUNT
                   DISPLAY 'UNKNOWN REC TYPE: ' ACH-REC-TYPE
           END-EVALUATE.
       1100-PROCESS-FILE-HDR.
           DISPLAY 'FILE HEADER RECEIVED'.
       1200-PROCESS-BATCH-HDR.
           ADD 1 TO WS-BATCH-COUNT
           MOVE 'Y' TO WS-BATCH-ACTIVE
           MOVE 0 TO WS-BATCH-DEBITS
           MOVE 0 TO WS-BATCH-CREDITS
           MOVE 0 TO WS-BATCH-DETAIL-CT
           MOVE 0 TO WS-BATCH-ENTRY-HASH.
       1300-PROCESS-DETAIL.
           ADD 1 TO WS-DETAIL-COUNT
           ADD 1 TO WS-BATCH-DETAIL-CT
           MOVE ACH-TRAN-CODE TO WS-TRAN-TYPE
           PERFORM 2000-VALIDATE-ROUTING
           PERFORM 2100-CLEAN-ACCOUNT
           PERFORM 2200-UPDATE-HASH
           PERFORM 2300-ACCUMULATE-AMOUNTS
           PERFORM 2400-CHECK-VELOCITY.
       1400-PROCESS-BATCH-TRL.
           IF WS-IN-BATCH
               MOVE 'N' TO WS-BATCH-ACTIVE
               COMPUTE WS-IMBALANCE =
                   WS-BATCH-DEBITS - WS-BATCH-CREDITS
               IF WS-IMBALANCE NOT = 0
                   ADD 1 TO WS-ERROR-COUNT
                   DISPLAY 'BATCH IMBALANCE: ' WS-IMBALANCE
               END-IF
           ELSE
               ADD 1 TO WS-ERROR-COUNT
               DISPLAY 'TRAILER WITHOUT HEADER'
           END-IF.
       1500-PROCESS-FILE-TRL.
           DISPLAY 'FILE TRAILER RECEIVED'
           DISPLAY 'TOTAL RECORDS: ' WS-RECORD-COUNT.
       2000-VALIDATE-ROUTING.
           MOVE ACH-ROUTING TO WS-ROUTING-NUM
           MOVE WS-ROUTING-NUM TO WS-ROUTING-BODY
           COMPUTE WS-DIGIT-1 =
               WS-ROUTING-NUM / 100000000
           COMPUTE WS-DIGIT-2 =
               WS-ROUTING-NUM / 10000000
           SUBTRACT WS-DIGIT-1 FROM WS-DIGIT-2
           COMPUTE WS-DIGIT-SUM =
               WS-DIGIT-1 * 3
               + WS-DIGIT-2 * 7
           DIVIDE WS-DIGIT-SUM BY 10
               GIVING WS-CALC-CHECK
               REMAINDER WS-REMAINDER
           IF WS-REMAINDER NOT = 0
               COMPUTE WS-EXPECTED-CHECK =
                   10 - WS-REMAINDER
           ELSE
               MOVE 0 TO WS-EXPECTED-CHECK
           END-IF
           ADD WS-ROUTING-NUM TO WS-HASH-TOTAL
           ADD WS-ROUTING-NUM TO WS-BATCH-ENTRY-HASH.
       2100-CLEAN-ACCOUNT.
           MOVE ACH-ACCOUNT TO WS-CLEAN-ACCOUNT
           INSPECT WS-CLEAN-ACCOUNT
               REPLACING ALL '-' BY ' '
           MOVE 0 TO WS-SPACE-COUNT
           INSPECT WS-CLEAN-ACCOUNT
               TALLYING WS-SPACE-COUNT FOR ALL ' '
           MOVE 0 TO WS-DASH-COUNT
           INSPECT ACH-ACCOUNT
               TALLYING WS-DASH-COUNT FOR ALL '-'
           IF WS-DASH-COUNT > 3
               ADD 1 TO WS-ERROR-COUNT
               MOVE 'E201' TO WS-ERROR-CODE
               MOVE 'EXCESS DASHES IN ACCOUNT' TO
                   WS-ERROR-DETAIL
               PERFORM 3000-BUILD-ERROR-MSG
           END-IF.
       2200-UPDATE-HASH.
           ADD WS-ROUTING-NUM TO WS-BATCH-HASH.
       2300-ACCUMULATE-AMOUNTS.
           IF WS-IS-DEBIT
               ADD ACH-AMOUNT TO WS-TOTAL-DEBITS
               ADD ACH-AMOUNT TO WS-BATCH-DEBITS
               ADD 1 TO WS-DEBIT-COUNT
           ELSE
               IF WS-IS-CREDIT
                   ADD ACH-AMOUNT TO WS-TOTAL-CREDITS
                   ADD ACH-AMOUNT TO WS-BATCH-CREDITS
                   ADD 1 TO WS-CREDIT-COUNT
               ELSE
                   ADD 1 TO WS-ERROR-COUNT
                   MOVE 'E301' TO WS-ERROR-CODE
                   MOVE 'INVALID TRANSACTION CODE' TO
                       WS-ERROR-DETAIL
                   PERFORM 3000-BUILD-ERROR-MSG
               END-IF
           END-IF
           IF ACH-AMOUNT > WS-AMT-LIMIT
               ADD 1 TO WS-ERROR-COUNT
               MOVE 'E302' TO WS-ERROR-CODE
               MOVE 'AMOUNT EXCEEDS LIMIT' TO
                   WS-ERROR-DETAIL
               PERFORM 3000-BUILD-ERROR-MSG
           END-IF.
       2400-CHECK-VELOCITY.
           MOVE 'N' TO WS-VEL-FOUND
           PERFORM VARYING WS-VEL-IDX FROM 1 BY 1
               UNTIL WS-VEL-IDX > 20 OR WS-VEL-MATCH
               IF WS-VEL-ROUTING(WS-VEL-IDX) =
                   ACH-ROUTING
                   ADD 1 TO WS-VEL-COUNT(WS-VEL-IDX)
                   ADD ACH-AMOUNT TO
                       WS-VEL-AMOUNT(WS-VEL-IDX)
                   MOVE 'Y' TO WS-VEL-FOUND
                   IF WS-VEL-COUNT(WS-VEL-IDX) >
                       WS-VEL-LIMIT
                       ADD 1 TO WS-ERROR-COUNT
                       MOVE 'E401' TO WS-ERROR-CODE
                       MOVE 'VELOCITY LIMIT EXCEEDED' TO
                           WS-ERROR-DETAIL
                       PERFORM 3000-BUILD-ERROR-MSG
                   END-IF
               END-IF
               IF WS-VEL-ROUTING(WS-VEL-IDX) = SPACES
                   MOVE ACH-ROUTING TO
                       WS-VEL-ROUTING(WS-VEL-IDX)
                   MOVE 1 TO WS-VEL-COUNT(WS-VEL-IDX)
                   MOVE ACH-AMOUNT TO
                       WS-VEL-AMOUNT(WS-VEL-IDX)
                   MOVE 'Y' TO WS-VEL-FOUND
               END-IF
           END-PERFORM.
       3000-BUILD-ERROR-MSG.
           STRING WS-ERROR-CODE DELIMITED BY SIZE
                  ': ' DELIMITED BY SIZE
                  WS-ERROR-DETAIL DELIMITED BY SIZE
                  INTO WS-ERROR-LINE
           END-STRING
           DISPLAY WS-ERROR-LINE.
       0400-FINAL-VALIDATION.
           COMPUTE WS-NET-AMOUNT =
               WS-TOTAL-DEBITS - WS-TOTAL-CREDITS
           IF WS-NET-AMOUNT NOT = 0
               ADD 1 TO WS-ERROR-COUNT
               DISPLAY 'FILE IMBALANCE: ' WS-NET-AMOUNT
           END-IF
           IF WS-ERROR-COUNT > 0
               MOVE 'N' TO WS-VALID-FLAG
           ELSE
               MOVE 'Y' TO WS-VALID-FLAG
           END-IF.
       0500-PRINT-RESULTS.
           DISPLAY 'ACH VALIDATION COMPLETE'
           DISPLAY 'TOTAL RECORDS:   ' WS-RECORD-COUNT
           DISPLAY 'DETAIL RECORDS:  ' WS-DETAIL-COUNT
           DISPLAY 'BATCHES:         ' WS-BATCH-COUNT
           DISPLAY 'TOTAL DEBITS:    ' WS-TOTAL-DEBITS
           DISPLAY 'TOTAL CREDITS:   ' WS-TOTAL-CREDITS
           DISPLAY 'NET AMOUNT:      ' WS-NET-AMOUNT
           DISPLAY 'HASH TOTAL:      ' WS-HASH-TOTAL
           DISPLAY 'ERRORS FOUND:    ' WS-ERROR-COUNT
           IF WS-VALID
               DISPLAY 'STATUS: VALID'
           ELSE
               DISPLAY 'STATUS: INVALID'
           END-IF
           PERFORM VARYING WS-VEL-IDX FROM 1 BY 1
               UNTIL WS-VEL-IDX > 20
               IF WS-VEL-ROUTING(WS-VEL-IDX) NOT = SPACES
                   DISPLAY 'ROUTING ' WS-VEL-ROUTING(
                       WS-VEL-IDX)
                       ' COUNT: ' WS-VEL-COUNT(WS-VEL-IDX)
                       ' TOTAL: ' WS-VEL-AMOUNT(WS-VEL-IDX)
               END-IF
           END-PERFORM.
       0600-CLOSE-ACH.
           CLOSE ACH-FILE.
