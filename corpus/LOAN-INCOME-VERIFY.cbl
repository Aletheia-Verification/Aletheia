       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOAN-INCOME-VERIFY.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-APPLICANT.
           05 WS-APP-ID          PIC X(10).
           05 WS-APP-NAME        PIC X(30).
           05 WS-STATED-INCOME   PIC S9(9)V99 COMP-3.
           05 WS-EMPLOYMENT-TYPE PIC X(1).
               88 ET-W2          VALUE 'W'.
               88 ET-SELF-EMP    VALUE 'S'.
               88 ET-RETIRED     VALUE 'R'.
               88 ET-OTHER       VALUE 'O'.
       01 WS-DOC-TABLE.
           05 WS-DOC OCCURS 6 TIMES.
               10 WS-DOC-TYPE    PIC X(2).
               10 WS-DOC-AMT     PIC S9(9)V99 COMP-3.
               10 WS-DOC-VALID   PIC X.
                   88 DOC-VALID  VALUE 'Y'.
               10 WS-DOC-DATE    PIC 9(8).
       01 WS-DOC-COUNT           PIC 9 VALUE 6.
       01 WS-IDX                 PIC 9.
       01 WS-VERIFIED-INCOME     PIC S9(9)V99 COMP-3.
       01 WS-DOC-INCOME-SUM      PIC S9(9)V99 COMP-3.
       01 WS-VALID-DOC-COUNT     PIC 9.
       01 WS-VARIANCE            PIC S9(3)V99 COMP-3.
       01 WS-MAX-VARIANCE        PIC S9(3)V99 COMP-3
           VALUE 10.00.
       01 WS-VERIFY-STATUS       PIC X(15).
       01 WS-DOCS-REQUIRED       PIC 9.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-DETERMINE-REQS
           PERFORM 2000-VALIDATE-DOCS
           PERFORM 3000-CALC-VERIFIED
           PERFORM 4000-COMPARE
           PERFORM 5000-OUTPUT
           STOP RUN.
       1000-DETERMINE-REQS.
           EVALUATE TRUE
               WHEN ET-W2
                   MOVE 2 TO WS-DOCS-REQUIRED
               WHEN ET-SELF-EMP
                   MOVE 3 TO WS-DOCS-REQUIRED
               WHEN ET-RETIRED
                   MOVE 2 TO WS-DOCS-REQUIRED
               WHEN OTHER
                   MOVE 4 TO WS-DOCS-REQUIRED
           END-EVALUATE.
       2000-VALIDATE-DOCS.
           MOVE 0 TO WS-VALID-DOC-COUNT
           MOVE 0 TO WS-DOC-INCOME-SUM
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-DOC-COUNT
               IF DOC-VALID(WS-IDX)
                   ADD 1 TO WS-VALID-DOC-COUNT
                   ADD WS-DOC-AMT(WS-IDX) TO
                       WS-DOC-INCOME-SUM
               END-IF
           END-PERFORM.
       3000-CALC-VERIFIED.
           IF WS-VALID-DOC-COUNT > 0
               COMPUTE WS-VERIFIED-INCOME =
                   WS-DOC-INCOME-SUM / WS-VALID-DOC-COUNT
           ELSE
               MOVE 0 TO WS-VERIFIED-INCOME
           END-IF.
       4000-COMPARE.
           IF WS-VALID-DOC-COUNT < WS-DOCS-REQUIRED
               MOVE 'INSUFFICIENT   ' TO WS-VERIFY-STATUS
           ELSE
               IF WS-STATED-INCOME > 0
                   COMPUTE WS-VARIANCE =
                       ((WS-STATED-INCOME -
                         WS-VERIFIED-INCOME) /
                        WS-STATED-INCOME) * 100
                   IF WS-VARIANCE < 0
                       MULTIPLY -1 BY WS-VARIANCE
                   END-IF
                   IF WS-VARIANCE <= WS-MAX-VARIANCE
                       MOVE 'VERIFIED       ' TO
                           WS-VERIFY-STATUS
                   ELSE
                       MOVE 'DISCREPANCY    ' TO
                           WS-VERIFY-STATUS
                   END-IF
               ELSE
                   MOVE 'NO STATED INC  ' TO
                       WS-VERIFY-STATUS
               END-IF
           END-IF.
       5000-OUTPUT.
           DISPLAY 'INCOME VERIFICATION'
           DISPLAY '==================='
           DISPLAY 'APPLICANT:  ' WS-APP-NAME
           DISPLAY 'EMP TYPE:   ' WS-EMPLOYMENT-TYPE
           DISPLAY 'STATED INC: $' WS-STATED-INCOME
           DISPLAY 'VERIFIED:   $' WS-VERIFIED-INCOME
           DISPLAY 'DOCS VALID: ' WS-VALID-DOC-COUNT
               '/' WS-DOCS-REQUIRED
           DISPLAY 'VARIANCE:   ' WS-VARIANCE '%'
           DISPLAY 'STATUS:     ' WS-VERIFY-STATUS.
