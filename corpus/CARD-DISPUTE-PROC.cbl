       IDENTIFICATION DIVISION.
       PROGRAM-ID. CARD-DISPUTE-PROC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-DISPUTE.
           05 WS-DISP-ID          PIC X(12).
           05 WS-CARD-NUM         PIC X(16).
           05 WS-TXN-DATE         PIC 9(8).
           05 WS-TXN-AMT          PIC S9(7)V99 COMP-3.
           05 WS-MERCHANT-NAME    PIC X(25).
           05 WS-MERCHANT-MCC     PIC X(4).
           05 WS-REASON-CODE      PIC X(2).
               88 RC-FRAUD        VALUE 'FR'.
               88 RC-NOT-RECEIVED VALUE 'NR'.
               88 RC-DEFECTIVE    VALUE 'DF'.
               88 RC-DUPLICATE    VALUE 'DU'.
               88 RC-WRONG-AMT    VALUE 'WA'.
           05 WS-CUST-STATEMENT   PIC X(80).
       01 WS-PROCESSING.
           05 WS-PROV-CREDIT      PIC X VALUE 'N'.
               88 GIVE-CREDIT     VALUE 'Y'.
           05 WS-CREDIT-AMT       PIC S9(7)V99 COMP-3.
           05 WS-DAYS-SINCE-TXN   PIC 9(3).
           05 WS-WITHIN-WINDOW    PIC X VALUE 'N'.
               88 IN-WINDOW       VALUE 'Y'.
           05 WS-AUTO-RESOLVE     PIC X VALUE 'N'.
               88 CAN-AUTO        VALUE 'Y'.
       01 WS-CURRENT-DATE         PIC 9(8).
       01 WS-MAX-DAYS             PIC 9(3) VALUE 120.
       01 WS-AUTO-THRESHOLD       PIC S9(5)V99 COMP-3
           VALUE 50.00.
       01 WS-RESULT               PIC X(15).
       01 WS-LETTER-TYPE          PIC X(2).
       01 WS-AUDIT-REC            PIC X(80).
       01 WS-TALLY-SP             PIC 9(3).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-VALIDATE-WINDOW
           IF IN-WINDOW
               PERFORM 3000-EVALUATE-DISPUTE
               PERFORM 4000-DETERMINE-CREDIT
               PERFORM 5000-SET-LETTER
           ELSE
               MOVE 'EXPIRED        ' TO WS-RESULT
           END-IF
           PERFORM 6000-AUDIT-AND-REPORT
           STOP RUN.
       1000-INIT.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           COMPUTE WS-DAYS-SINCE-TXN =
               WS-CURRENT-DATE - WS-TXN-DATE
           MOVE 0 TO WS-CREDIT-AMT.
       2000-VALIDATE-WINDOW.
           IF WS-DAYS-SINCE-TXN <= WS-MAX-DAYS
               MOVE 'Y' TO WS-WITHIN-WINDOW
           ELSE
               MOVE 'N' TO WS-WITHIN-WINDOW
           END-IF.
       3000-EVALUATE-DISPUTE.
           EVALUATE TRUE
               WHEN RC-FRAUD
                   MOVE 'Y' TO WS-PROV-CREDIT
                   MOVE WS-TXN-AMT TO WS-CREDIT-AMT
               WHEN RC-NOT-RECEIVED
                   IF WS-DAYS-SINCE-TXN > 15
                       MOVE 'Y' TO WS-PROV-CREDIT
                       MOVE WS-TXN-AMT TO WS-CREDIT-AMT
                   END-IF
               WHEN RC-DEFECTIVE
                   MOVE 'Y' TO WS-PROV-CREDIT
                   MOVE WS-TXN-AMT TO WS-CREDIT-AMT
               WHEN RC-DUPLICATE
                   MOVE 'Y' TO WS-PROV-CREDIT
                   MOVE WS-TXN-AMT TO WS-CREDIT-AMT
                   IF WS-TXN-AMT <= WS-AUTO-THRESHOLD
                       MOVE 'Y' TO WS-AUTO-RESOLVE
                   END-IF
               WHEN RC-WRONG-AMT
                   MOVE 0 TO WS-TALLY-SP
                   INSPECT WS-CUST-STATEMENT
                       TALLYING WS-TALLY-SP
                       FOR ALL '$'
                   IF WS-TALLY-SP > 0
                       MOVE 'Y' TO WS-PROV-CREDIT
                       MOVE WS-TXN-AMT TO WS-CREDIT-AMT
                   END-IF
               WHEN OTHER
                   MOVE 'INVALID CODE   ' TO WS-RESULT
           END-EVALUATE.
       4000-DETERMINE-CREDIT.
           IF GIVE-CREDIT
               IF CAN-AUTO
                   MOVE 'AUTO-RESOLVED  ' TO WS-RESULT
               ELSE
                   MOVE 'PROV-CREDIT    ' TO WS-RESULT
               END-IF
           ELSE
               MOVE 'UNDER-REVIEW   ' TO WS-RESULT
           END-IF.
       5000-SET-LETTER.
           IF GIVE-CREDIT
               MOVE 'AC' TO WS-LETTER-TYPE
           ELSE
               MOVE 'RV' TO WS-LETTER-TYPE
           END-IF.
       6000-AUDIT-AND-REPORT.
           STRING 'DISP ' DELIMITED BY SIZE
               WS-DISP-ID DELIMITED BY ' '
               ' RC=' DELIMITED BY SIZE
               WS-REASON-CODE DELIMITED BY SIZE
               ' $' DELIMITED BY SIZE
               WS-TXN-AMT DELIMITED BY SIZE
               ' ' DELIMITED BY SIZE
               WS-RESULT DELIMITED BY SIZE
               INTO WS-AUDIT-REC
           END-STRING
           DISPLAY 'DISPUTE PROCESSING RESULT'
           DISPLAY '========================='
           DISPLAY 'DISPUTE ID: ' WS-DISP-ID
           DISPLAY 'CARD:       ' WS-CARD-NUM
           DISPLAY 'MERCHANT:   ' WS-MERCHANT-NAME
           DISPLAY 'AMOUNT:     $' WS-TXN-AMT
           DISPLAY 'REASON:     ' WS-REASON-CODE
           DISPLAY 'RESULT:     ' WS-RESULT
           IF GIVE-CREDIT
               DISPLAY 'CREDIT:     $' WS-CREDIT-AMT
           END-IF
           DISPLAY 'LETTER:     ' WS-LETTER-TYPE.
