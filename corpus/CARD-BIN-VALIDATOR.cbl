       IDENTIFICATION DIVISION.
       PROGRAM-ID. CARD-BIN-VALIDATOR.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CARD-INPUT.
           05 WS-FULL-PAN        PIC X(16).
           05 WS-BIN             PIC X(6).
           05 WS-ACCT-DIGITS     PIC X(9).
           05 WS-CHECK-DIGIT     PIC X(1).
       01 WS-BIN-TABLE.
           05 WS-BIN-ENTRY OCCURS 10 TIMES.
               10 WS-BE-PREFIX   PIC X(6).
               10 WS-BE-ISSUER   PIC X(20).
               10 WS-BE-TYPE     PIC X(2).
                   88 BT-VISA    VALUE 'VI'.
                   88 BT-MC      VALUE 'MC'.
                   88 BT-AMEX    VALUE 'AX'.
                   88 BT-DISC    VALUE 'DS'.
               10 WS-BE-COUNTRY  PIC X(2).
               10 WS-BE-DEBIT    PIC X.
                   88 IS-DEBIT   VALUE 'Y'.
       01 WS-BIN-COUNT           PIC 99 VALUE 10.
       01 WS-IDX                 PIC 99.
       01 WS-BIN-FOUND           PIC X VALUE 'N'.
           88 FOUND-BIN          VALUE 'Y'.
       01 WS-MATCH-IDX           PIC 99.
       01 WS-LUHN-VALID          PIC X VALUE 'N'.
           88 LUHN-OK            VALUE 'Y'.
       01 WS-LUHN-SUM            PIC 9(3).
       01 WS-LUHN-DIGIT          PIC 9.
       01 WS-LUHN-DOUBLE         PIC 99.
       01 WS-LUHN-IDX            PIC 99.
       01 WS-LUHN-MOD            PIC 9.
       01 WS-VALIDATION-RESULT   PIC X(12).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-EXTRACT-BIN
           PERFORM 2000-LOOKUP-BIN
           PERFORM 3000-LUHN-CHECK
           PERFORM 4000-DETERMINE-RESULT
           PERFORM 5000-OUTPUT
           STOP RUN.
       1000-EXTRACT-BIN.
           MOVE WS-FULL-PAN(1:6) TO WS-BIN
           MOVE WS-FULL-PAN(7:9) TO WS-ACCT-DIGITS
           MOVE WS-FULL-PAN(16:1) TO WS-CHECK-DIGIT.
       2000-LOOKUP-BIN.
           MOVE 'N' TO WS-BIN-FOUND
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-BIN-COUNT
               IF WS-BIN = WS-BE-PREFIX(WS-IDX)
                   MOVE 'Y' TO WS-BIN-FOUND
                   MOVE WS-IDX TO WS-MATCH-IDX
               END-IF
           END-PERFORM.
       3000-LUHN-CHECK.
           MOVE 0 TO WS-LUHN-SUM
           PERFORM VARYING WS-LUHN-IDX FROM 1 BY 1
               UNTIL WS-LUHN-IDX > 16
               IF WS-FULL-PAN(WS-LUHN-IDX:1) IS NUMERIC
                   MOVE WS-FULL-PAN(WS-LUHN-IDX:1)
                       TO WS-LUHN-DIGIT
                   ADD WS-LUHN-DIGIT TO WS-LUHN-SUM
               END-IF
           END-PERFORM
           DIVIDE WS-LUHN-SUM BY 10
               GIVING WS-LUHN-DOUBLE
               REMAINDER WS-LUHN-MOD
           IF WS-LUHN-MOD = 0
               MOVE 'Y' TO WS-LUHN-VALID
           END-IF.
       4000-DETERMINE-RESULT.
           IF NOT FOUND-BIN
               MOVE 'UNKNOWN BIN ' TO WS-VALIDATION-RESULT
           ELSE
               IF NOT LUHN-OK
                   MOVE 'LUHN FAIL   ' TO
                       WS-VALIDATION-RESULT
               ELSE
                   MOVE 'VALID       ' TO
                       WS-VALIDATION-RESULT
               END-IF
           END-IF.
       5000-OUTPUT.
           DISPLAY 'CARD BIN VALIDATION'
           DISPLAY '==================='
           DISPLAY 'PAN:    ' WS-FULL-PAN
           DISPLAY 'BIN:    ' WS-BIN
           DISPLAY 'RESULT: ' WS-VALIDATION-RESULT
           IF FOUND-BIN
               DISPLAY 'ISSUER: '
                   WS-BE-ISSUER(WS-MATCH-IDX)
               DISPLAY 'NETWORK:'
                   WS-BE-TYPE(WS-MATCH-IDX)
               DISPLAY 'COUNTRY:'
                   WS-BE-COUNTRY(WS-MATCH-IDX)
               IF IS-DEBIT(WS-MATCH-IDX)
                   DISPLAY 'TYPE:   DEBIT'
               ELSE
                   DISPLAY 'TYPE:   CREDIT'
               END-IF
           END-IF.
