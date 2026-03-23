       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-ALTER-RECOVERY.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-BATCH-DATA.
           05 WS-BATCH-ID            PIC X(10).
           05 WS-RECORD-COUNT        PIC S9(5) COMP-3.
           05 WS-PROCESSED           PIC S9(5) COMP-3.
           05 WS-ERRORS              PIC S9(5) COMP-3.
           05 WS-AMOUNT              PIC S9(9)V99 COMP-3.
           05 WS-TOTAL-PROCESSED     PIC S9(11)V99 COMP-3.
       01 WS-ERROR-TYPE              PIC X(1).
           88 WS-TIMEOUT             VALUE 'T'.
           88 WS-DATA-ERROR          VALUE 'D'.
           88 WS-CONN-FAIL           VALUE 'C'.
           88 WS-NO-ERROR            VALUE 'N'.
       01 WS-RETRY-COUNT             PIC 9(1).
       01 WS-MAX-RETRIES             PIC 9(1) VALUE 3.
       01 WS-RECOVERY-STATUS         PIC X(1).
           88 WS-RECOVERED           VALUE 'R'.
           88 WS-ABORT               VALUE 'A'.
           88 WS-PROCESSING          VALUE 'P'.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM INIT-BATCH
           PERFORM SETUP-ERROR-HANDLER
           PERFORM PROCESS-RECORD THRU PROCESS-RECORD-EXIT
           PERFORM DISPLAY-RESULTS
           STOP RUN.
       INIT-BATCH.
           MOVE 0 TO WS-PROCESSED
           MOVE 0 TO WS-ERRORS
           MOVE 0 TO WS-TOTAL-PROCESSED
           MOVE 0 TO WS-RETRY-COUNT
           SET WS-PROCESSING TO TRUE.
       SETUP-ERROR-HANDLER.
           IF WS-TIMEOUT
               ALTER ERROR-HANDLER TO PROCEED TO
                   HANDLE-TIMEOUT
           ELSE
               IF WS-DATA-ERROR
                   ALTER ERROR-HANDLER TO PROCEED TO
                       HANDLE-DATA-ERR
               ELSE
                   IF WS-CONN-FAIL
                       ALTER ERROR-HANDLER TO PROCEED TO
                           HANDLE-CONN-FAIL
                   END-IF
               END-IF
           END-IF.
       PROCESS-RECORD.
           IF WS-NO-ERROR
               ADD WS-AMOUNT TO WS-TOTAL-PROCESSED
               ADD 1 TO WS-PROCESSED
               SET WS-RECOVERED TO TRUE
           ELSE
               PERFORM ERROR-HANDLER THRU
                   ERROR-HANDLER-EXIT
           END-IF.
       PROCESS-RECORD-EXIT.
           EXIT.
       ERROR-HANDLER.
           GO TO HANDLE-TIMEOUT.
       ERROR-HANDLER-EXIT.
           EXIT.
       HANDLE-TIMEOUT.
           ADD 1 TO WS-RETRY-COUNT
           IF WS-RETRY-COUNT > WS-MAX-RETRIES
               ADD 1 TO WS-ERRORS
               SET WS-ABORT TO TRUE
               DISPLAY 'TIMEOUT: MAX RETRIES EXCEEDED'
           ELSE
               SET WS-RECOVERED TO TRUE
               DISPLAY 'TIMEOUT: RETRY ' WS-RETRY-COUNT
           END-IF
           GO TO ERROR-HANDLER-EXIT.
       HANDLE-DATA-ERR.
           ADD 1 TO WS-ERRORS
           DISPLAY 'DATA ERROR: RECORD SKIPPED'
           SET WS-RECOVERED TO TRUE
           GO TO ERROR-HANDLER-EXIT.
       HANDLE-CONN-FAIL.
           ADD 1 TO WS-ERRORS
           SET WS-ABORT TO TRUE
           DISPLAY 'CONNECTION FAILED: BATCH ABORTED'
           GO TO ERROR-HANDLER-EXIT.
       DISPLAY-RESULTS.
           DISPLAY 'ALTER RECOVERY REPORT'
           DISPLAY '====================='
           DISPLAY 'BATCH:     ' WS-BATCH-ID
           DISPLAY 'RECORDS:   ' WS-RECORD-COUNT
           DISPLAY 'PROCESSED: ' WS-PROCESSED
           DISPLAY 'ERRORS:    ' WS-ERRORS
           DISPLAY 'TOTAL AMT: ' WS-TOTAL-PROCESSED
           IF WS-RECOVERED
               DISPLAY 'STATUS: RECOVERED'
           END-IF
           IF WS-ABORT
               DISPLAY 'STATUS: ABORTED'
           END-IF.
