       IDENTIFICATION DIVISION.
       PROGRAM-ID. PAY-PRENOTE-VALID.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-PRENOTE-DATA.
           05 WS-ROUTING-NUM         PIC X(9).
           05 WS-ACCT-NUM            PIC X(17).
           05 WS-ACCT-TYPE           PIC X(1).
           05 WS-COMPANY-NAME        PIC X(30).
           05 WS-INDIVIDUAL-NAME     PIC X(30).
       01 WS-ACCT-TYPE-FLAG          PIC X(1).
           88 WS-CHECKING            VALUE 'C'.
           88 WS-SAVINGS             VALUE 'S'.
       01 WS-VALIDATION-RESULT       PIC X(1).
           88 WS-VALID               VALUE 'V'.
           88 WS-INVALID             VALUE 'I'.
       01 WS-ERROR-MSG               PIC X(60).
       01 WS-ROUTING-VALID           PIC X VALUE 'N'.
           88 WS-ROUTE-OK            VALUE 'Y'.
       01 WS-ACCT-VALID              PIC X VALUE 'N'.
           88 WS-ACCT-OK             VALUE 'Y'.
       01 WS-CHECK-DIGIT             PIC 9(1).
       01 WS-CALC-DIGIT              PIC 9(2).
       01 WS-RT-CHAR                 PIC X(1).
       01 WS-RT-IDX                  PIC 9(1).
       01 WS-DIGIT-SUM               PIC 9(3).
       01 WS-WEIGHTS                 PIC X(8) VALUE '37137137'.
       01 WS-WEIGHT-CHAR             PIC X(1).
       01 WS-WEIGHT-NUM              PIC 9(1).
       01 WS-PROD                    PIC 9(2).
       01 WS-FORMATTED-MSG           PIC X(80).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-VALIDATE-ROUTING
           PERFORM 3000-VALIDATE-ACCOUNT
           PERFORM 4000-FINAL-RESULT
           PERFORM 5000-FORMAT-MESSAGE
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE SPACES TO WS-ERROR-MSG
           SET WS-INVALID TO TRUE
           MOVE 'N' TO WS-ROUTING-VALID
           MOVE 'N' TO WS-ACCT-VALID
           MOVE 0 TO WS-DIGIT-SUM.
       2000-VALIDATE-ROUTING.
           IF WS-ROUTING-NUM IS NUMERIC
               PERFORM 2100-CHECK-DIGIT-CALC
           ELSE
               MOVE 'ROUTING NUMBER NOT NUMERIC' TO
                   WS-ERROR-MSG
           END-IF.
       2100-CHECK-DIGIT-CALC.
           MOVE 0 TO WS-DIGIT-SUM
           PERFORM VARYING WS-RT-IDX FROM 1 BY 1
               UNTIL WS-RT-IDX > 8
               MOVE WS-ROUTING-NUM(WS-RT-IDX:1)
                   TO WS-RT-CHAR
               MOVE WS-WEIGHTS(WS-RT-IDX:1)
                   TO WS-WEIGHT-CHAR
               IF WS-RT-CHAR IS NUMERIC
                   MOVE WS-RT-CHAR TO WS-CHECK-DIGIT
                   MOVE WS-WEIGHT-CHAR TO WS-WEIGHT-NUM
                   COMPUTE WS-PROD =
                       WS-CHECK-DIGIT * WS-WEIGHT-NUM
                   ADD WS-PROD TO WS-DIGIT-SUM
               END-IF
           END-PERFORM
           COMPUTE WS-CALC-DIGIT =
               10 - (WS-DIGIT-SUM - (WS-DIGIT-SUM / 10)
               * 10)
           IF WS-CALC-DIGIT = 10
               MOVE 0 TO WS-CALC-DIGIT
           END-IF
           MOVE WS-ROUTING-NUM(9:1) TO WS-RT-CHAR
           IF WS-RT-CHAR IS NUMERIC
               MOVE WS-RT-CHAR TO WS-CHECK-DIGIT
               IF WS-CHECK-DIGIT = WS-CALC-DIGIT
                   MOVE 'Y' TO WS-ROUTING-VALID
               ELSE
                   MOVE 'ROUTING CHECK DIGIT INVALID'
                       TO WS-ERROR-MSG
               END-IF
           ELSE
               MOVE 'ROUTING DIGIT NOT NUMERIC'
                   TO WS-ERROR-MSG
           END-IF.
       3000-VALIDATE-ACCOUNT.
           IF WS-ACCT-NUM = SPACES
               MOVE 'ACCOUNT NUMBER BLANK' TO WS-ERROR-MSG
           ELSE
               IF WS-ACCT-NUM(1:1) IS NUMERIC
                   MOVE 'Y' TO WS-ACCT-VALID
               ELSE
                   MOVE 'ACCOUNT MUST START NUMERIC'
                       TO WS-ERROR-MSG
               END-IF
           END-IF.
       4000-FINAL-RESULT.
           IF WS-ROUTE-OK
               IF WS-ACCT-OK
                   SET WS-VALID TO TRUE
               END-IF
           END-IF.
       5000-FORMAT-MESSAGE.
           IF WS-VALID
               STRING 'PRENOTE VALID RT='
                          DELIMITED BY SIZE
                      WS-ROUTING-NUM DELIMITED BY SIZE
                      ' ACCT=' DELIMITED BY SIZE
                      WS-ACCT-NUM DELIMITED BY SIZE
                      INTO WS-FORMATTED-MSG
               END-STRING
           ELSE
               STRING 'PRENOTE INVALID: '
                          DELIMITED BY SIZE
                      WS-ERROR-MSG DELIMITED BY SIZE
                      INTO WS-FORMATTED-MSG
               END-STRING
           END-IF.
       6000-DISPLAY-RESULTS.
           DISPLAY 'ACH PRENOTE VALIDATION'
           DISPLAY '======================'
           DISPLAY 'ROUTING:   ' WS-ROUTING-NUM
           DISPLAY 'ACCOUNT:   ' WS-ACCT-NUM
           DISPLAY 'NAME:      ' WS-INDIVIDUAL-NAME
           IF WS-VALID
               DISPLAY 'RESULT: VALID'
           ELSE
               DISPLAY 'RESULT: INVALID'
               DISPLAY 'ERROR:  ' WS-ERROR-MSG
           END-IF
           DISPLAY 'MSG: ' WS-FORMATTED-MSG.
