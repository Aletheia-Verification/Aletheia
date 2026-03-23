       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-EXEC-CICS-QUEUE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-QUEUE-NAME              PIC X(8).
       01 WS-MSG-DATA.
           05 WS-MSG-TYPE            PIC X(3).
           05 WS-MSG-ACCT            PIC X(12).
           05 WS-MSG-AMOUNT          PIC S9(9)V99 COMP-3.
           05 WS-MSG-TIMESTAMP       PIC X(20).
           05 WS-MSG-STATUS          PIC X(2).
       01 WS-MSG-LENGTH              PIC S9(4) COMP VALUE 47.
       01 WS-MSG-TYPE-FLAG           PIC X(3).
           88 WS-ALERT               VALUE 'ALT'.
           88 WS-NOTIFY              VALUE 'NTF'.
           88 WS-CONFIRM             VALUE 'CNF'.
       01 WS-RESP-CODE               PIC S9(8) COMP.
       01 WS-PROCESS-COUNT           PIC S9(5) COMP-3.
       01 WS-ERROR-COUNT             PIC S9(5) COMP-3.
       01 WS-TOTAL-AMOUNT            PIC S9(11)V99 COMP-3.
       01 WS-EOF-FLAG                PIC X VALUE 'N'.
           88 WS-EOF                  VALUE 'Y'.
       01 WS-ALERT-MSG               PIC X(80).
       01 WS-THRESHOLD               PIC S9(9)V99 COMP-3
           VALUE 50000.00.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-READ-QUEUE UNTIL WS-EOF
           PERFORM 3000-WRITE-SUMMARY
           PERFORM 4000-DISPLAY-RESULTS
           EXEC CICS RETURN
           END-EXEC.
       1000-INITIALIZE.
           MOVE 0 TO WS-PROCESS-COUNT
           MOVE 0 TO WS-ERROR-COUNT
           MOVE 0 TO WS-TOTAL-AMOUNT
           MOVE 'N' TO WS-EOF-FLAG
           MOVE 'TXNQUEUE' TO WS-QUEUE-NAME.
       2000-READ-QUEUE.
           EXEC CICS READQ TD
               QUEUE(WS-QUEUE-NAME)
               INTO(WS-MSG-DATA)
               LENGTH(WS-MSG-LENGTH)
               RESP(WS-RESP-CODE)
           END-EXEC
           IF WS-RESP-CODE = 0
               PERFORM 2100-PROCESS-MESSAGE
           ELSE
               SET WS-EOF TO TRUE
           END-IF.
       2100-PROCESS-MESSAGE.
           ADD 1 TO WS-PROCESS-COUNT
           MOVE WS-MSG-TYPE TO WS-MSG-TYPE-FLAG
           EVALUATE TRUE
               WHEN WS-ALERT
                   IF WS-MSG-AMOUNT > WS-THRESHOLD
                       PERFORM 2200-HIGH-VALUE-ALERT
                   END-IF
                   ADD WS-MSG-AMOUNT TO WS-TOTAL-AMOUNT
               WHEN WS-NOTIFY
                   ADD WS-MSG-AMOUNT TO WS-TOTAL-AMOUNT
               WHEN WS-CONFIRM
                   ADD WS-MSG-AMOUNT TO WS-TOTAL-AMOUNT
               WHEN OTHER
                   ADD 1 TO WS-ERROR-COUNT
           END-EVALUATE.
       2200-HIGH-VALUE-ALERT.
           STRING 'HV-ALERT ACCT=' DELIMITED BY SIZE
                  WS-MSG-ACCT DELIMITED BY SIZE
                  ' AMT=' DELIMITED BY SIZE
                  WS-MSG-AMOUNT DELIMITED BY SIZE
                  INTO WS-ALERT-MSG
           END-STRING
           DISPLAY WS-ALERT-MSG.
       3000-WRITE-SUMMARY.
           MOVE 'CNF' TO WS-MSG-TYPE
           MOVE 'SUMMARY' TO WS-MSG-ACCT
           MOVE WS-TOTAL-AMOUNT TO WS-MSG-AMOUNT
           MOVE 'OK' TO WS-MSG-STATUS
           EXEC CICS WRITEQ TD
               QUEUE('AUDITQ')
               FROM(WS-MSG-DATA)
               LENGTH(WS-MSG-LENGTH)
               RESP(WS-RESP-CODE)
           END-EXEC
           IF WS-RESP-CODE NOT = 0
               ADD 1 TO WS-ERROR-COUNT
               DISPLAY 'WRITE ERROR: ' WS-RESP-CODE
           END-IF.
       4000-DISPLAY-RESULTS.
           DISPLAY 'CICS QUEUE PROCESSING'
           DISPLAY '====================='
           DISPLAY 'MESSAGES READ:  ' WS-PROCESS-COUNT
           DISPLAY 'ERRORS:         ' WS-ERROR-COUNT
           DISPLAY 'TOTAL AMOUNT:   ' WS-TOTAL-AMOUNT.
