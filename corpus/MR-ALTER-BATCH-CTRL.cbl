       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-ALTER-BATCH-CTRL.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-BATCH-STATUS          PIC X(1).
           88 BATCH-INIT            VALUE 'I'.
           88 BATCH-RUNNING         VALUE 'R'.
           88 BATCH-COMPLETE        VALUE 'C'.
           88 BATCH-ERROR           VALUE 'E'.
       01 WS-STEP-NUMBER           PIC 9(2).
       01 WS-MAX-STEPS             PIC 9(2) VALUE 5.
       01 WS-STEP-RESULT           PIC X(4).
       01 WS-RECORD-COUNT          PIC 9(5).
       01 WS-ERROR-COUNT           PIC 9(3).
       01 WS-ERROR-MSG             PIC X(50).
       01 WS-BATCH-ID              PIC X(10).
       01 WS-START-TIME            PIC 9(8).
       01 WS-END-TIME              PIC 9(8).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           ALTER 2000-DISPATCH TO PROCEED TO 2100-STEP-1
           PERFORM 2000-DISPATCH
           DISPLAY 'BATCH ' WS-BATCH-ID ' COMPLETE'
           DISPLAY 'RECORDS: ' WS-RECORD-COUNT
           DISPLAY 'ERRORS:  ' WS-ERROR-COUNT
           STOP RUN.
       1000-INIT.
           MOVE 'I' TO WS-BATCH-STATUS
           MOVE 0 TO WS-STEP-NUMBER
           MOVE 0 TO WS-RECORD-COUNT
           MOVE 0 TO WS-ERROR-COUNT
           ACCEPT WS-START-TIME FROM TIME.
       2000-DISPATCH.
           GO TO 2100-STEP-1.
       2100-STEP-1.
           MOVE 1 TO WS-STEP-NUMBER
           MOVE 'R' TO WS-BATCH-STATUS
           ADD 100 TO WS-RECORD-COUNT
           MOVE 'PASS' TO WS-STEP-RESULT
           IF WS-STEP-RESULT = 'PASS'
               ALTER 2000-DISPATCH TO PROCEED TO 2200-STEP-2
               PERFORM 2000-DISPATCH
           ELSE
               MOVE 'E' TO WS-BATCH-STATUS
           END-IF.
       2200-STEP-2.
           MOVE 2 TO WS-STEP-NUMBER
           ADD 200 TO WS-RECORD-COUNT
           MOVE 'PASS' TO WS-STEP-RESULT
           IF WS-STEP-RESULT = 'PASS'
               ALTER 2000-DISPATCH TO PROCEED TO 2300-STEP-3
               PERFORM 2000-DISPATCH
           ELSE
               ADD 1 TO WS-ERROR-COUNT
               MOVE 'STEP 2 FAILED' TO WS-ERROR-MSG
           END-IF.
       2300-STEP-3.
           MOVE 3 TO WS-STEP-NUMBER
           ADD 150 TO WS-RECORD-COUNT
           MOVE 'C' TO WS-BATCH-STATUS
           ACCEPT WS-END-TIME FROM TIME
           DISPLAY 'STEP 3 FINAL: RECORDS=' WS-RECORD-COUNT.
