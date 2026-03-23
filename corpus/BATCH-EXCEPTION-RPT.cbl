       IDENTIFICATION DIVISION.
       PROGRAM-ID. BATCH-EXCEPTION-RPT.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-EXCEPTION-TABLE.
           05 WS-EXC OCCURS 30 TIMES.
               10 WS-EX-CODE     PIC X(4).
               10 WS-EX-ACCT     PIC X(12).
               10 WS-EX-DESC     PIC X(30).
               10 WS-EX-AMOUNT   PIC S9(9)V99 COMP-3.
               10 WS-EX-DATE     PIC 9(8).
               10 WS-EX-SEVERITY PIC 9.
                   88 SV-INFO    VALUE 1.
                   88 SV-WARN    VALUE 2.
                   88 SV-ERROR   VALUE 3.
                   88 SV-CRIT    VALUE 4.
               10 WS-EX-RESOLVED PIC X VALUE 'N'.
                   88 IS-RESOLVED VALUE 'Y'.
       01 WS-EXC-COUNT          PIC 99 VALUE 30.
       01 WS-IDX                PIC 99.
       01 WS-INFO-COUNT         PIC 99.
       01 WS-WARN-COUNT         PIC 99.
       01 WS-ERROR-COUNT        PIC 99.
       01 WS-CRIT-COUNT         PIC 99.
       01 WS-RESOLVED-COUNT     PIC 99.
       01 WS-OPEN-COUNT         PIC 99.
       01 WS-TOTAL-AMOUNT       PIC S9(11)V99 COMP-3.
       01 WS-REPORT-DATE        PIC 9(8).
       01 WS-RPT-LINE           PIC X(80).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-CATEGORIZE
           PERFORM 3000-OUTPUT
           STOP RUN.
       1000-INIT.
           ACCEPT WS-REPORT-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-INFO-COUNT
           MOVE 0 TO WS-WARN-COUNT
           MOVE 0 TO WS-ERROR-COUNT
           MOVE 0 TO WS-CRIT-COUNT
           MOVE 0 TO WS-RESOLVED-COUNT
           MOVE 0 TO WS-OPEN-COUNT
           MOVE 0 TO WS-TOTAL-AMOUNT.
       2000-CATEGORIZE.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-EXC-COUNT
               EVALUATE TRUE
                   WHEN SV-INFO(WS-IDX)
                       ADD 1 TO WS-INFO-COUNT
                   WHEN SV-WARN(WS-IDX)
                       ADD 1 TO WS-WARN-COUNT
                   WHEN SV-ERROR(WS-IDX)
                       ADD 1 TO WS-ERROR-COUNT
                   WHEN SV-CRIT(WS-IDX)
                       ADD 1 TO WS-CRIT-COUNT
               END-EVALUATE
               IF IS-RESOLVED(WS-IDX)
                   ADD 1 TO WS-RESOLVED-COUNT
               ELSE
                   ADD 1 TO WS-OPEN-COUNT
                   ADD WS-EX-AMOUNT(WS-IDX) TO
                       WS-TOTAL-AMOUNT
               END-IF
           END-PERFORM.
       3000-OUTPUT.
           DISPLAY 'EXCEPTION REPORT'
           DISPLAY '================'
           DISPLAY 'DATE:     ' WS-REPORT-DATE
           DISPLAY 'TOTAL:    ' WS-EXC-COUNT
           DISPLAY 'OPEN:     ' WS-OPEN-COUNT
           DISPLAY 'RESOLVED: ' WS-RESOLVED-COUNT
           DISPLAY 'INFO:     ' WS-INFO-COUNT
           DISPLAY 'WARNING:  ' WS-WARN-COUNT
           DISPLAY 'ERROR:    ' WS-ERROR-COUNT
           DISPLAY 'CRITICAL: ' WS-CRIT-COUNT
           DISPLAY 'OPEN AMT: $' WS-TOTAL-AMOUNT
           DISPLAY 'OPEN EXCEPTIONS:'
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-EXC-COUNT
               IF NOT IS-RESOLVED(WS-IDX)
                   STRING WS-EX-CODE(WS-IDX)
                       DELIMITED BY SIZE
                       ' ' DELIMITED BY SIZE
                       WS-EX-ACCT(WS-IDX) DELIMITED BY ' '
                       ' ' DELIMITED BY SIZE
                       WS-EX-DESC(WS-IDX) DELIMITED BY '  '
                       INTO WS-RPT-LINE
                   END-STRING
                   DISPLAY '  ' WS-RPT-LINE
               END-IF
           END-PERFORM.
