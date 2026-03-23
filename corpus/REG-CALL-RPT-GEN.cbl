       IDENTIFICATION DIVISION.
       PROGRAM-ID. REG-CALL-RPT-GEN.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CALL-RPT.
           05 WS-REPORT-DATE         PIC 9(8).
           05 WS-BANK-ID             PIC X(10).
       01 WS-SCHEDULE-TABLE.
           05 WS-SCHED OCCURS 10.
               10 WS-SC-CODE         PIC X(4).
               10 WS-SC-DESC         PIC X(20).
               10 WS-SC-AMOUNT       PIC S9(13)V99 COMP-3.
       01 WS-SC-IDX                  PIC 9(2).
       01 WS-TOTAL-ASSETS            PIC S9(13)V99 COMP-3.
       01 WS-TOTAL-LIAB              PIC S9(13)V99 COMP-3.
       01 WS-TOTAL-EQUITY            PIC S9(13)V99 COMP-3.
       01 WS-REPORT-LINE             PIC X(60).
       01 WS-VALID-FLAG              PIC X VALUE 'Y'.
           88 WS-IS-VALID            VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-SCHEDULES
           PERFORM 3000-CALC-TOTALS
           PERFORM 4000-VALIDATE
           PERFORM 5000-FORMAT-OUTPUT
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-ASSETS
           MOVE 0 TO WS-TOTAL-LIAB
           MOVE 0 TO WS-TOTAL-EQUITY.
       2000-LOAD-SCHEDULES.
           MOVE 'RC-A' TO WS-SC-CODE(1)
           MOVE 'CASH & DUE' TO WS-SC-DESC(1)
           MOVE 'RC-B' TO WS-SC-CODE(2)
           MOVE 'SECURITIES' TO WS-SC-DESC(2)
           MOVE 'RC-C' TO WS-SC-CODE(3)
           MOVE 'LOANS' TO WS-SC-DESC(3)
           MOVE 'RC-D' TO WS-SC-CODE(4)
           MOVE 'DEPOSITS' TO WS-SC-DESC(4)
           MOVE 'RC-E' TO WS-SC-CODE(5)
           MOVE 'BORROWINGS' TO WS-SC-DESC(5).
       3000-CALC-TOTALS.
           PERFORM VARYING WS-SC-IDX FROM 1 BY 1
               UNTIL WS-SC-IDX > 5
               IF WS-SC-IDX <= 3
                   ADD WS-SC-AMOUNT(WS-SC-IDX) TO
                       WS-TOTAL-ASSETS
               ELSE
                   ADD WS-SC-AMOUNT(WS-SC-IDX) TO
                       WS-TOTAL-LIAB
               END-IF
           END-PERFORM
           COMPUTE WS-TOTAL-EQUITY =
               WS-TOTAL-ASSETS - WS-TOTAL-LIAB.
       4000-VALIDATE.
           IF WS-TOTAL-EQUITY < 0
               MOVE 'N' TO WS-VALID-FLAG
               DISPLAY 'WARNING: NEGATIVE EQUITY'
           END-IF.
       5000-FORMAT-OUTPUT.
           STRING 'CALL RPT ' DELIMITED BY SIZE
                  WS-BANK-ID DELIMITED BY SIZE
                  ' DATE=' DELIMITED BY SIZE
                  WS-REPORT-DATE DELIMITED BY SIZE
                  ' ASSETS=' DELIMITED BY SIZE
                  WS-TOTAL-ASSETS DELIMITED BY SIZE
                  INTO WS-REPORT-LINE
           END-STRING.
       6000-DISPLAY-RESULTS.
           DISPLAY 'CALL REPORT GENERATION'
           DISPLAY '======================'
           DISPLAY 'BANK:        ' WS-BANK-ID
           DISPLAY 'DATE:        ' WS-REPORT-DATE
           DISPLAY 'TOTAL ASSETS:' WS-TOTAL-ASSETS
           DISPLAY 'TOTAL LIAB:  ' WS-TOTAL-LIAB
           DISPLAY 'EQUITY:      ' WS-TOTAL-EQUITY
           PERFORM VARYING WS-SC-IDX FROM 1 BY 1
               UNTIL WS-SC-IDX > 5
               DISPLAY '  ' WS-SC-CODE(WS-SC-IDX)
                   ' ' WS-SC-DESC(WS-SC-IDX)
                   ' = ' WS-SC-AMOUNT(WS-SC-IDX)
           END-PERFORM
           DISPLAY WS-REPORT-LINE.
