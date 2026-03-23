       IDENTIFICATION DIVISION.
       PROGRAM-ID. CHECK-DIGIT-VALIDATOR.
      *================================================================*
      * ABA Routing Number and Account Number Validator                *
      * Implements mod-10 weighted check digit (ABA), Luhn algorithm   *
      * for card numbers, MICR field extraction.                       *
      *================================================================*

       DATA DIVISION.
       WORKING-STORAGE SECTION.

      *--- ABA Routing Number Fields ---*
       01  WS-ROUTING-NUMBER          PIC X(9).
       01  WS-ROUTING-DIGITS.
           05  WS-RT-DIGIT           PIC 9 OCCURS 9.
       01  WS-RT-WEIGHTED-SUM        PIC S9(5) COMP-3.
       01  WS-RT-REMAINDER           PIC S9(3) COMP-3.
       01  WS-RT-CHECK               PIC S9(3) COMP-3.
       01  WS-RT-VALID               PIC 9.
       01  WS-RT-PRODUCT             PIC S9(5) COMP-3.

      *--- Account Number Fields ---*
       01  WS-ACCOUNT-NUMBER          PIC X(12).
       01  WS-ACCT-DIGITS.
           05  WS-AC-DIGIT           PIC 9 OCCURS 12.
       01  WS-AC-SUM                  PIC S9(7) COMP-3.
       01  WS-AC-REMAINDER           PIC S9(3) COMP-3.
       01  WS-AC-VALID               PIC 9.
       01  WS-AC-LENGTH              PIC S9(3) COMP-3.

      *--- Luhn Card Validation Fields ---*
       01  WS-CARD-NUMBER             PIC X(16).
       01  WS-CARD-DIGITS.
           05  WS-CD-DIGIT           PIC 9 OCCURS 16.
       01  WS-LUHN-SUM               PIC S9(7) COMP-3.
       01  WS-LUHN-DOUBLE            PIC S9(3) COMP-3.
       01  WS-LUHN-REMAINDER         PIC S9(3) COMP-3.
       01  WS-LUHN-VALID             PIC 9.
       01  WS-CARD-TYPE              PIC X(10).

      *--- MICR Line Fields ---*
       01  WS-MICR-LINE              PIC X(45).
       01  WS-MICR-ROUTING           PIC X(9).
       01  WS-MICR-ACCOUNT           PIC X(12).
       01  WS-MICR-CHECK-NUM         PIC X(6).
       01  WS-MICR-AMOUNT            PIC X(10).

      *--- Loop and Work Fields ---*
       01  WS-INDEX                   PIC S9(3) COMP-3.
       01  WS-WEIGHT-INDEX            PIC S9(3) COMP-3.
       01  WS-TEMP-VALUE              PIC S9(5) COMP-3.
       01  WS-TEMP-DIGIT              PIC S9(3) COMP-3.
       01  WS-POSITION                PIC S9(3) COMP-3.
       01  WS-DOUBLE-FLAG             PIC 9.

      *--- ABA Weights ---*
       01  WS-ABA-WEIGHTS.
           05  WS-ABA-WT             PIC 9 OCCURS 8.

      *--- Results ---*
       01  WS-TOTAL-VALIDATED         PIC S9(5) COMP-3.
       01  WS-TOTAL-PASSED            PIC S9(5) COMP-3.
       01  WS-TOTAL-FAILED            PIC S9(5) COMP-3.

      *--- Display ---*
       01  WS-DISP-COUNT              PIC Z,ZZ9.

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-VALIDATE-ROUTING
           PERFORM 3000-VALIDATE-ACCOUNT
           PERFORM 4000-VALIDATE-CARD
           PERFORM 5000-PARSE-MICR
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.

       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-VALIDATED
           MOVE 0 TO WS-TOTAL-PASSED
           MOVE 0 TO WS-TOTAL-FAILED
           MOVE 0 TO WS-RT-VALID
           MOVE 0 TO WS-AC-VALID
           MOVE 0 TO WS-LUHN-VALID
           MOVE 3 TO WS-ABA-WT(1)
           MOVE 7 TO WS-ABA-WT(2)
           MOVE 1 TO WS-ABA-WT(3)
           MOVE 3 TO WS-ABA-WT(4)
           MOVE 7 TO WS-ABA-WT(5)
           MOVE 1 TO WS-ABA-WT(6)
           MOVE 3 TO WS-ABA-WT(7)
           MOVE 7 TO WS-ABA-WT(8)
           MOVE "021000021" TO WS-ROUTING-NUMBER
           MOVE "123456789012" TO WS-ACCOUNT-NUMBER
           MOVE 12 TO WS-AC-LENGTH
           MOVE "4532015112830366" TO WS-CARD-NUMBER
           MOVE "T021000021T 123456789012O 001523O"
               TO WS-MICR-LINE.

       2000-VALIDATE-ROUTING.
           ADD 1 TO WS-TOTAL-VALIDATED
           IF WS-ROUTING-NUMBER IS NUMERIC
               PERFORM 2100-EXTRACT-RT-DIGITS
               PERFORM 2200-COMPUTE-RT-CHECKSUM
           ELSE
               MOVE 0 TO WS-RT-VALID
               ADD 1 TO WS-TOTAL-FAILED
               DISPLAY "ROUTING: NON-NUMERIC INPUT"
           END-IF.

       2100-EXTRACT-RT-DIGITS.
           MOVE WS-ROUTING-NUMBER TO WS-ROUTING-DIGITS.

       2200-COMPUTE-RT-CHECKSUM.
           MOVE 0 TO WS-RT-WEIGHTED-SUM
           PERFORM VARYING WS-INDEX FROM 1 BY 1
               UNTIL WS-INDEX > 8
               COMPUTE WS-RT-PRODUCT =
                   WS-RT-DIGIT(WS-INDEX)
                   * WS-ABA-WT(WS-INDEX)
               ADD WS-RT-PRODUCT TO WS-RT-WEIGHTED-SUM
           END-PERFORM
           ADD WS-RT-DIGIT(9) TO WS-RT-WEIGHTED-SUM
           DIVIDE WS-RT-WEIGHTED-SUM BY 10
               GIVING WS-RT-CHECK
               REMAINDER WS-RT-REMAINDER
           END-DIVIDE
           IF WS-RT-REMAINDER = 0
               MOVE 1 TO WS-RT-VALID
               ADD 1 TO WS-TOTAL-PASSED
               DISPLAY "ROUTING " WS-ROUTING-NUMBER " VALID"
           ELSE
               MOVE 0 TO WS-RT-VALID
               ADD 1 TO WS-TOTAL-FAILED
               DISPLAY "ROUTING " WS-ROUTING-NUMBER " INVALID"
           END-IF.

       3000-VALIDATE-ACCOUNT.
           ADD 1 TO WS-TOTAL-VALIDATED
           IF WS-ACCOUNT-NUMBER IS NUMERIC
               PERFORM 3100-COMPUTE-ACCT-CHECK
           ELSE
               MOVE 0 TO WS-AC-VALID
               ADD 1 TO WS-TOTAL-FAILED
               DISPLAY "ACCOUNT: NON-NUMERIC INPUT"
           END-IF.

       3100-COMPUTE-ACCT-CHECK.
           MOVE WS-ACCOUNT-NUMBER TO WS-ACCT-DIGITS
           MOVE 0 TO WS-AC-SUM
           PERFORM VARYING WS-INDEX FROM 1 BY 1
               UNTIL WS-INDEX > WS-AC-LENGTH
               ADD WS-AC-DIGIT(WS-INDEX) TO WS-AC-SUM
           END-PERFORM
           DIVIDE WS-AC-SUM BY 10
               GIVING WS-TEMP-VALUE
               REMAINDER WS-AC-REMAINDER
           END-DIVIDE
           IF WS-AC-REMAINDER = 0
               MOVE 1 TO WS-AC-VALID
               ADD 1 TO WS-TOTAL-PASSED
           ELSE
               MOVE 0 TO WS-AC-VALID
               ADD 1 TO WS-TOTAL-FAILED
           END-IF
           DISPLAY "ACCOUNT CHECK REMAINDER: " WS-AC-REMAINDER.

       4000-VALIDATE-CARD.
           ADD 1 TO WS-TOTAL-VALIDATED
           IF WS-CARD-NUMBER IS NUMERIC
               PERFORM 4100-DETERMINE-CARD-TYPE
               PERFORM 4200-LUHN-ALGORITHM
           ELSE
               MOVE 0 TO WS-LUHN-VALID
               ADD 1 TO WS-TOTAL-FAILED
               DISPLAY "CARD: NON-NUMERIC INPUT"
           END-IF.

       4100-DETERMINE-CARD-TYPE.
           MOVE WS-CARD-NUMBER TO WS-CARD-DIGITS
           EVALUATE TRUE
               WHEN WS-CD-DIGIT(1) = 4
                   MOVE "VISA" TO WS-CARD-TYPE
               WHEN WS-CD-DIGIT(1) = 5
                   MOVE "MASTERCARD" TO WS-CARD-TYPE
               WHEN WS-CD-DIGIT(1) = 3
                   MOVE "AMEX" TO WS-CARD-TYPE
               WHEN WS-CD-DIGIT(1) = 6
                   MOVE "DISCOVER" TO WS-CARD-TYPE
               WHEN OTHER
                   MOVE "UNKNOWN" TO WS-CARD-TYPE
           END-EVALUATE
           DISPLAY "CARD TYPE: " WS-CARD-TYPE.

       4200-LUHN-ALGORITHM.
           MOVE 0 TO WS-LUHN-SUM
           MOVE 0 TO WS-DOUBLE-FLAG
           PERFORM VARYING WS-INDEX FROM 16 BY -1
               UNTIL WS-INDEX < 1
               MOVE WS-CD-DIGIT(WS-INDEX) TO WS-TEMP-DIGIT
               IF WS-DOUBLE-FLAG = 1
                   MULTIPLY 2 BY WS-TEMP-DIGIT
                   IF WS-TEMP-DIGIT > 9
                       SUBTRACT 9 FROM WS-TEMP-DIGIT
                   END-IF
                   MOVE 0 TO WS-DOUBLE-FLAG
               ELSE
                   MOVE 1 TO WS-DOUBLE-FLAG
               END-IF
               ADD WS-TEMP-DIGIT TO WS-LUHN-SUM
           END-PERFORM
           DIVIDE WS-LUHN-SUM BY 10
               GIVING WS-TEMP-VALUE
               REMAINDER WS-LUHN-REMAINDER
           END-DIVIDE
           IF WS-LUHN-REMAINDER = 0
               MOVE 1 TO WS-LUHN-VALID
               ADD 1 TO WS-TOTAL-PASSED
               DISPLAY "LUHN CHECK: PASS"
           ELSE
               MOVE 0 TO WS-LUHN-VALID
               ADD 1 TO WS-TOTAL-FAILED
               DISPLAY "LUHN CHECK: FAIL"
           END-IF.

       5000-PARSE-MICR.
           MOVE WS-MICR-LINE(2:9) TO WS-MICR-ROUTING
           MOVE WS-MICR-LINE(13:12) TO WS-MICR-ACCOUNT
           MOVE WS-MICR-LINE(27:6) TO WS-MICR-CHECK-NUM
           DISPLAY "MICR ROUTING:  " WS-MICR-ROUTING
           DISPLAY "MICR ACCOUNT:  " WS-MICR-ACCOUNT
           DISPLAY "MICR CHECK#:   " WS-MICR-CHECK-NUM.

       6000-DISPLAY-RESULTS.
           DISPLAY "=== CHECK DIGIT VALIDATION SUMMARY ==="
           MOVE WS-TOTAL-VALIDATED TO WS-DISP-COUNT
           DISPLAY "TOTAL VALIDATED: " WS-DISP-COUNT
           MOVE WS-TOTAL-PASSED TO WS-DISP-COUNT
           DISPLAY "PASSED:          " WS-DISP-COUNT
           MOVE WS-TOTAL-FAILED TO WS-DISP-COUNT
           DISPLAY "FAILED:          " WS-DISP-COUNT
           DISPLAY "RT VALID:        " WS-RT-VALID
           DISPLAY "ACCT VALID:      " WS-AC-VALID
           DISPLAY "CARD VALID:      " WS-LUHN-VALID
           DISPLAY "=== END VALIDATION SUMMARY ===".
