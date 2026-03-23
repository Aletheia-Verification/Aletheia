       IDENTIFICATION DIVISION.
       PROGRAM-ID. MISC-SAFE-BOX-BILL.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-BOX-DATA.
           05 WS-BOX-NUM             PIC X(8).
           05 WS-CUSTOMER-NAME       PIC X(30).
           05 WS-BOX-SIZE            PIC X(1).
               88 WS-SMALL           VALUE 'S'.
               88 WS-MEDIUM          VALUE 'M'.
               88 WS-LARGE           VALUE 'L'.
               88 WS-EXTRA-LARGE     VALUE 'X'.
       01 WS-ANNUAL-FEE              PIC S9(5)V99 COMP-3.
       01 WS-TAX-AMOUNT              PIC S9(5)V99 COMP-3.
       01 WS-TOTAL-DUE               PIC S9(5)V99 COMP-3.
       01 WS-TAX-RATE                PIC S9(1)V9(4) COMP-3
           VALUE 0.0825.
       01 WS-WAIVER-FLAG             PIC X VALUE 'N'.
           88 WS-WAIVED              VALUE 'Y'.
       01 WS-BILL-MSG                PIC X(60).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-SET-FEE
           PERFORM 2000-CALC-TOTAL
           PERFORM 3000-BUILD-BILL
           PERFORM 4000-DISPLAY-RESULTS
           STOP RUN.
       1000-SET-FEE.
           EVALUATE TRUE
               WHEN WS-SMALL
                   MOVE 75.00 TO WS-ANNUAL-FEE
               WHEN WS-MEDIUM
                   MOVE 150.00 TO WS-ANNUAL-FEE
               WHEN WS-LARGE
                   MOVE 300.00 TO WS-ANNUAL-FEE
               WHEN WS-EXTRA-LARGE
                   MOVE 500.00 TO WS-ANNUAL-FEE
               WHEN OTHER
                   MOVE 100.00 TO WS-ANNUAL-FEE
           END-EVALUATE.
       2000-CALC-TOTAL.
           IF WS-WAIVED
               MOVE 0 TO WS-ANNUAL-FEE
           END-IF
           COMPUTE WS-TAX-AMOUNT =
               WS-ANNUAL-FEE * WS-TAX-RATE
           COMPUTE WS-TOTAL-DUE =
               WS-ANNUAL-FEE + WS-TAX-AMOUNT.
       3000-BUILD-BILL.
           STRING 'SAFE BOX ' DELIMITED BY SIZE
                  WS-BOX-NUM DELIMITED BY SIZE
                  ' DUE=' DELIMITED BY SIZE
                  WS-TOTAL-DUE DELIMITED BY SIZE
                  INTO WS-BILL-MSG
           END-STRING.
       4000-DISPLAY-RESULTS.
           DISPLAY 'SAFE DEPOSIT BOX BILLING'
           DISPLAY '========================'
           DISPLAY 'BOX:      ' WS-BOX-NUM
           DISPLAY 'CUSTOMER: ' WS-CUSTOMER-NAME
           DISPLAY 'FEE:      ' WS-ANNUAL-FEE
           DISPLAY 'TAX:      ' WS-TAX-AMOUNT
           DISPLAY 'TOTAL:    ' WS-TOTAL-DUE
           DISPLAY WS-BILL-MSG.
