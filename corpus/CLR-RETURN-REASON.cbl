       IDENTIFICATION DIVISION.
       PROGRAM-ID. CLR-RETURN-REASON.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-RETURN-DATA.
           05 WS-ITEM-NUM            PIC X(15).
           05 WS-AMOUNT              PIC S9(9)V99 COMP-3.
           05 WS-RETURN-CODE         PIC X(2).
       01 WS-REASON-CODE             PIC X(2).
           88 WS-REASON-NSF          VALUE '01'.
           88 WS-REASON-CLOSED       VALUE '02'.
           88 WS-REASON-NO-ACCT      VALUE '03'.
           88 WS-REASON-STOP-PAY     VALUE '06'.
           88 WS-REASON-STALE        VALUE '08'.
       01 WS-REASON-DESC             PIC X(30).
       01 WS-CATEGORY                PIC X(1).
           88 WS-ADMIN               VALUE 'A'.
           88 WS-CUSTOMER            VALUE 'C'.
           88 WS-FRAUD-CAT           VALUE 'F'.
       01 WS-RETRY-FLAG              PIC X VALUE 'N'.
           88 WS-CAN-RETRY           VALUE 'Y'.
       01 WS-OUTPUT-MSG              PIC X(60).
       01 WS-DASH-COUNT              PIC 9(2).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CLASSIFY-REASON
           PERFORM 3000-CHECK-RETRY
           PERFORM 4000-FORMAT-OUTPUT
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE SPACES TO WS-REASON-DESC
           MOVE 'N' TO WS-RETRY-FLAG
           MOVE 0 TO WS-DASH-COUNT
           MOVE WS-RETURN-CODE TO WS-REASON-CODE.
       2000-CLASSIFY-REASON.
           EVALUATE TRUE
               WHEN WS-REASON-NSF
                   MOVE 'INSUFFICIENT FUNDS' TO
                       WS-REASON-DESC
                   SET WS-CUSTOMER TO TRUE
               WHEN WS-REASON-CLOSED
                   MOVE 'ACCOUNT CLOSED' TO WS-REASON-DESC
                   SET WS-ADMIN TO TRUE
               WHEN WS-REASON-NO-ACCT
                   MOVE 'NO ACCOUNT FOUND' TO WS-REASON-DESC
                   SET WS-ADMIN TO TRUE
               WHEN WS-REASON-STOP-PAY
                   MOVE 'STOP PAYMENT' TO WS-REASON-DESC
                   SET WS-CUSTOMER TO TRUE
               WHEN WS-REASON-STALE
                   MOVE 'STALE DATED' TO WS-REASON-DESC
                   SET WS-ADMIN TO TRUE
               WHEN OTHER
                   MOVE 'OTHER REASON' TO WS-REASON-DESC
                   SET WS-ADMIN TO TRUE
           END-EVALUATE
           INSPECT WS-ITEM-NUM
               TALLYING WS-DASH-COUNT FOR ALL '-'.
       3000-CHECK-RETRY.
           IF WS-REASON-NSF
               MOVE 'Y' TO WS-RETRY-FLAG
           END-IF.
       4000-FORMAT-OUTPUT.
           STRING 'RTN ' DELIMITED BY SIZE
                  WS-ITEM-NUM DELIMITED BY SIZE
                  ' R' DELIMITED BY SIZE
                  WS-REASON-CODE DELIMITED BY SIZE
                  ' ' DELIMITED BY SIZE
                  WS-REASON-DESC DELIMITED BY '  '
                  INTO WS-OUTPUT-MSG
           END-STRING.
       5000-DISPLAY-RESULTS.
           DISPLAY 'RETURN REASON PROCESSING'
           DISPLAY '========================'
           DISPLAY 'ITEM:    ' WS-ITEM-NUM
           DISPLAY 'AMOUNT:  ' WS-AMOUNT
           DISPLAY 'CODE:    ' WS-REASON-CODE
           DISPLAY 'REASON:  ' WS-REASON-DESC
           IF WS-CAN-RETRY
               DISPLAY 'RETRY: ELIGIBLE'
           ELSE
               DISPLAY 'RETRY: NOT ELIGIBLE'
           END-IF
           DISPLAY WS-OUTPUT-MSG.
