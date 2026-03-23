       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOAN-TITLE-SEARCH.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-PROPERTY.
           05 WS-PARCEL-ID       PIC X(15).
           05 WS-ADDRESS          PIC X(40).
           05 WS-COUNTY           PIC X(20).
           05 WS-STATE            PIC X(2).
       01 WS-LIENS.
           05 WS-LIEN OCCURS 10 TIMES.
               10 WS-LN-TYPE     PIC X(2).
                   88 LN-MORTGAGE VALUE 'MG'.
                   88 LN-TAX     VALUE 'TX'.
                   88 LN-MECHAN  VALUE 'MC'.
                   88 LN-JUDGMNT VALUE 'JD'.
                   88 LN-HOA     VALUE 'HA'.
               10 WS-LN-HOLDER   PIC X(25).
               10 WS-LN-AMOUNT   PIC S9(9)V99 COMP-3.
               10 WS-LN-DATE     PIC 9(8).
               10 WS-LN-PRIORITY PIC 9.
       01 WS-LIEN-COUNT          PIC 99 VALUE 10.
       01 WS-IDX                 PIC 99.
       01 WS-TOTAL-LIENS         PIC S9(11)V99 COMP-3.
       01 WS-FIRST-LIEN-AMT     PIC S9(9)V99 COMP-3.
       01 WS-TAX-LIENS           PIC S9(7)V99 COMP-3.
       01 WS-JUDGMENTS           PIC S9(7)V99 COMP-3.
       01 WS-PROPERTY-VALUE      PIC S9(11)V99 COMP-3.
       01 WS-EQUITY              PIC S9(11)V99 COMP-3.
       01 WS-TITLE-STATUS        PIC X(12).
       01 WS-CLEAR-TO-CLOSE      PIC X VALUE 'N'.
           88 CAN-CLOSE          VALUE 'Y'.
       01 WS-ISSUE-COUNT         PIC 9.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-ANALYZE-LIENS
           PERFORM 3000-CALC-EQUITY
           PERFORM 4000-DETERMINE-STATUS
           PERFORM 5000-OUTPUT
           STOP RUN.
       1000-INIT.
           MOVE 0 TO WS-TOTAL-LIENS
           MOVE 0 TO WS-FIRST-LIEN-AMT
           MOVE 0 TO WS-TAX-LIENS
           MOVE 0 TO WS-JUDGMENTS
           MOVE 0 TO WS-ISSUE-COUNT.
       2000-ANALYZE-LIENS.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-LIEN-COUNT
               ADD WS-LN-AMOUNT(WS-IDX) TO WS-TOTAL-LIENS
               IF LN-MORTGAGE(WS-IDX)
                   IF WS-LN-PRIORITY(WS-IDX) = 1
                       ADD WS-LN-AMOUNT(WS-IDX) TO
                           WS-FIRST-LIEN-AMT
                   END-IF
               END-IF
               IF LN-TAX(WS-IDX)
                   ADD WS-LN-AMOUNT(WS-IDX) TO WS-TAX-LIENS
                   ADD 1 TO WS-ISSUE-COUNT
               END-IF
               IF LN-JUDGMNT(WS-IDX)
                   ADD WS-LN-AMOUNT(WS-IDX) TO WS-JUDGMENTS
                   ADD 1 TO WS-ISSUE-COUNT
               END-IF
           END-PERFORM.
       3000-CALC-EQUITY.
           COMPUTE WS-EQUITY =
               WS-PROPERTY-VALUE - WS-TOTAL-LIENS.
       4000-DETERMINE-STATUS.
           IF WS-TAX-LIENS > 0
               MOVE 'TAX LIEN    ' TO WS-TITLE-STATUS
           ELSE
               IF WS-JUDGMENTS > 0
                   MOVE 'JUDGMENT    ' TO WS-TITLE-STATUS
               ELSE
                   IF WS-EQUITY < 0
                       MOVE 'UNDERWATER  ' TO WS-TITLE-STATUS
                   ELSE
                       MOVE 'CLEAR       ' TO WS-TITLE-STATUS
                       MOVE 'Y' TO WS-CLEAR-TO-CLOSE
                   END-IF
               END-IF
           END-IF.
       5000-OUTPUT.
           DISPLAY 'TITLE SEARCH REPORT'
           DISPLAY '==================='
           DISPLAY 'PARCEL:    ' WS-PARCEL-ID
           DISPLAY 'ADDRESS:   ' WS-ADDRESS
           DISPLAY 'VALUE:     $' WS-PROPERTY-VALUE
           DISPLAY 'TOTAL LIENS:$' WS-TOTAL-LIENS
           DISPLAY 'FIRST LIEN:$' WS-FIRST-LIEN-AMT
           DISPLAY 'TAX LIENS: $' WS-TAX-LIENS
           DISPLAY 'JUDGMENTS: $' WS-JUDGMENTS
           DISPLAY 'EQUITY:    $' WS-EQUITY
           DISPLAY 'STATUS:    ' WS-TITLE-STATUS
           IF CAN-CLOSE
               DISPLAY 'CLEAR TO CLOSE'
           ELSE
               DISPLAY 'ISSUES: ' WS-ISSUE-COUNT
           END-IF.
