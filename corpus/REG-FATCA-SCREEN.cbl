       IDENTIFICATION DIVISION.
       PROGRAM-ID. REG-FATCA-SCREEN.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CUSTOMER-DATA.
           05 WS-CUST-ID          PIC X(12).
           05 WS-CUST-NAME        PIC X(40).
           05 WS-CITIZENSHIP       PIC X(2).
           05 WS-TAX-ID           PIC X(11).
           05 WS-RESIDENCE-COUNTRY PIC X(2).
           05 WS-US-INDICATOR      PIC X(1).
               88 IS-US-PERSON    VALUE 'Y'.
           05 WS-W9-ON-FILE       PIC X(1).
               88 HAS-W9          VALUE 'Y'.
           05 WS-W8BEN-ON-FILE    PIC X(1).
               88 HAS-W8BEN       VALUE 'Y'.
       01 WS-ACCT-TABLE.
           05 WS-ACCT-ENTRY OCCURS 10 TIMES.
               10 WS-FA-ACCT-NUM  PIC X(12).
               10 WS-FA-BALANCE   PIC S9(11)V99 COMP-3.
               10 WS-FA-INCOME    PIC S9(9)V99 COMP-3.
               10 WS-FA-ACCT-TYPE PIC X(2).
       01 WS-ACCT-COUNT           PIC 99 VALUE 10.
       01 WS-FA-IDX               PIC 99.
       01 WS-TOTAL-BALANCE        PIC S9(13)V99 COMP-3.
       01 WS-TOTAL-INCOME         PIC S9(11)V99 COMP-3.
       01 WS-REPORTING-THRESHOLD  PIC S9(7)V99 COMP-3
           VALUE 50000.00.
       01 WS-FATCA-STATUS         PIC X(12).
       01 WS-ACTION-REQUIRED      PIC X(30).
       01 WS-INDICIA-COUNT        PIC 9.
       01 WS-TALLY-US             PIC 9(3).
       01 WS-REPORT-LINE          PIC X(80).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-CHECK-INDICIA
           PERFORM 3000-CALC-TOTALS
           PERFORM 4000-DETERMINE-STATUS
           PERFORM 5000-OUTPUT
           STOP RUN.
       1000-INIT.
           MOVE 0 TO WS-TOTAL-BALANCE
           MOVE 0 TO WS-TOTAL-INCOME
           MOVE 0 TO WS-INDICIA-COUNT.
       2000-CHECK-INDICIA.
           IF WS-CITIZENSHIP = 'US'
               ADD 1 TO WS-INDICIA-COUNT
           END-IF
           IF WS-RESIDENCE-COUNTRY = 'US'
               ADD 1 TO WS-INDICIA-COUNT
           END-IF
           IF IS-US-PERSON
               ADD 1 TO WS-INDICIA-COUNT
           END-IF
           MOVE 0 TO WS-TALLY-US
           INSPECT WS-TAX-ID
               TALLYING WS-TALLY-US FOR ALL '-'
           IF WS-TALLY-US = 2
               ADD 1 TO WS-INDICIA-COUNT
           END-IF.
       3000-CALC-TOTALS.
           PERFORM VARYING WS-FA-IDX FROM 1 BY 1
               UNTIL WS-FA-IDX > WS-ACCT-COUNT
               ADD WS-FA-BALANCE(WS-FA-IDX) TO
                   WS-TOTAL-BALANCE
               ADD WS-FA-INCOME(WS-FA-IDX) TO
                   WS-TOTAL-INCOME
           END-PERFORM.
       4000-DETERMINE-STATUS.
           EVALUATE TRUE
               WHEN WS-INDICIA-COUNT = 0
                   MOVE 'NON-US      ' TO WS-FATCA-STATUS
                   MOVE SPACES TO WS-ACTION-REQUIRED
               WHEN WS-INDICIA-COUNT >= 1
                   AND WS-INDICIA-COUNT <= 2
                   IF WS-TOTAL-BALANCE >
                       WS-REPORTING-THRESHOLD
                       MOVE 'REPORTABLE  ' TO WS-FATCA-STATUS
                       IF NOT HAS-W9
                           MOVE 'OBTAIN W-9 FORM'
                               TO WS-ACTION-REQUIRED
                       ELSE
                           MOVE 'REPORT TO IRS'
                               TO WS-ACTION-REQUIRED
                       END-IF
                   ELSE
                       MOVE 'MONITOR     ' TO WS-FATCA-STATUS
                       MOVE 'ANNUAL REVIEW'
                           TO WS-ACTION-REQUIRED
                   END-IF
               WHEN WS-INDICIA-COUNT >= 3
                   MOVE 'US-PERSON   ' TO WS-FATCA-STATUS
                   IF HAS-W9
                       MOVE 'REPORT - W9 ON FILE'
                           TO WS-ACTION-REQUIRED
                   ELSE
                       MOVE 'URGENT: OBTAIN W-9'
                           TO WS-ACTION-REQUIRED
                   END-IF
           END-EVALUATE.
       5000-OUTPUT.
           DISPLAY 'FATCA SCREENING REPORT'
           DISPLAY '======================'
           DISPLAY 'CUSTOMER:  ' WS-CUST-ID
           DISPLAY 'NAME:      ' WS-CUST-NAME
           DISPLAY 'CITIZEN:   ' WS-CITIZENSHIP
           DISPLAY 'RESIDENCE: ' WS-RESIDENCE-COUNTRY
           DISPLAY 'INDICIA:   ' WS-INDICIA-COUNT
           DISPLAY 'STATUS:    ' WS-FATCA-STATUS
           DISPLAY 'TOTAL BAL: $' WS-TOTAL-BALANCE
           DISPLAY 'TOTAL INC: $' WS-TOTAL-INCOME
           IF WS-ACTION-REQUIRED NOT = SPACES
               DISPLAY 'ACTION:    ' WS-ACTION-REQUIRED
           END-IF.
